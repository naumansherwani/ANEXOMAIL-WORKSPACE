//! Executor: Tokio `LocalSet` ko browser ke event loop par chalata hai (wasm mein thread nahi; `block_on` kabhi nahi).
//!  - JS `kernel_tick()` bulata hai -> LocalSet ek dafa poll hota hai (sab ready tasks chalte hain).
//!  - Koi task kisi cheez ka intezar kare (host ka jawab, timer) to `oneshot` par soti hai; JS `kernel_host_complete()` jagata hai;
//!    waker `host_wake()` bulata hai aur JS agla tick microtask mein lagata hai. Poll ke andar kabhi tick nahi (re-entrancy nahi).
use std::cell::{Cell, RefCell};
use std::collections::HashMap;
use std::future::Future;
use std::pin::Pin;
use std::rc::Rc;
use std::sync::Arc;
use std::task::{Context, Wake, Waker};
use tokio::sync::oneshot;
use tokio::task::LocalSet;

pub struct Reply {
    pub status: i32,
    pub data: Vec<u8>,
}

struct Exec {
    local: Rc<LocalSet>,
    driver: Pin<Box<dyn Future<Output = ()>>>,
}

thread_local! {
    static EXEC: RefCell<Option<Exec>> = const { RefCell::new(None) };
    static PENDING: RefCell<HashMap<u32, oneshot::Sender<Reply>>> = RefCell::new(HashMap::new());
    static NEXT_ID: Cell<u32> = const { Cell::new(1) };
    static TICKS: Cell<u64> = const { Cell::new(0) };
}

struct HostWaker;
impl Wake for HostWaker {
    fn wake(self: Arc<Self>) {
        crate::sys::wake();
    }
    fn wake_by_ref(self: &Arc<Self>) {
        crate::sys::wake();
    }
}

fn with_exec<R>(f: impl FnOnce(&mut Exec) -> R) -> R {
    EXEC.with(|e| {
        let mut e = e.borrow_mut();
        let ex = e.get_or_insert_with(|| {
            let local = Rc::new(LocalSet::new());
            let l2 = local.clone();
            // run_until(pending) = LocalSet ko hamesha chalata rehta hai, kabhi complete nahi hota.
            let driver: Pin<Box<dyn Future<Output = ()>>> = Box::pin(async move { l2.run_until(std::future::pending::<()>()).await });
            Exec { local, driver }
        });
        f(ex)
    })
}

/// Task shuru karo (jagane ke liye ek tick maangta hai).
pub fn spawn(fut: impl Future<Output = ()> + 'static) {
    with_exec(|ex| {
        ex.local.spawn_local(fut);
    });
    crate::sys::wake();
}

/// Ek poll. true = abhi kaam baqi ho sakta hai (JS ko dobara tick lagana chahiye) — hamesha false: jagana waker ka kaam hai.
pub fn tick() {
    TICKS.with(|t| t.set(t.get() + 1));
    let waker = Waker::from(Arc::new(HostWaker));
    let mut cx = Context::from_waker(&waker);
    // Tasks poll karte waqt naye tasks spawn ho sakte hain (EXEC dobara borrow) — isliye driver ko bahar nikal kar poll karo.
    let mut driver = with_exec(|ex| std::mem::replace(&mut ex.driver, Box::pin(std::future::pending())));
    let _ = driver.as_mut().poll(&mut cx);
    with_exec(|ex| ex.driver = driver);
}

pub fn ticks() -> u64 {
    TICKS.with(|t| t.get())
}

/// Host ko kaam do aur jawab ka intezar karo. `start(id)` mein host call hoti hai (jawab `complete(id, ..)` se aata hai).
pub async fn host_call(start: impl FnOnce(u32)) -> Reply {
    let (tx, rx) = oneshot::channel();
    let id = NEXT_ID.with(|n| {
        let id = n.get();
        n.set(if id == u32::MAX { 1 } else { id + 1 });
        id
    });
    PENDING.with(|p| p.borrow_mut().insert(id, tx));
    start(id);
    rx.await.unwrap_or(Reply { status: -1, data: Vec::new() })
}

/// JS ne kaam poora kiya. false = anjaan id (dobara jawab / purana).
pub fn complete(id: u32, status: i32, data: Vec<u8>) -> bool {
    match PENDING.with(|p| p.borrow_mut().remove(&id)) {
        Some(tx) => {
            let _ = tx.send(Reply { status, data });
            true
        }
        None => false,
    }
}

pub fn pending_count() -> usize {
    PENDING.with(|p| p.borrow().len())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn task_waits_for_host_and_finishes_after_complete() {
        let done = Rc::new(Cell::new(0i32));
        let d = done.clone();
        let started = Rc::new(Cell::new(0u32));
        let s = started.clone();
        spawn(async move {
            let r = host_call(|id| s.set(id)).await;
            d.set(r.status * 10 + r.data.len() as i32);
        });
        tick();
        assert_ne!(started.get(), 0, "host call was issued");
        assert_eq!(done.get(), 0, "still waiting");
        assert_eq!(pending_count(), 1);
        assert!(complete(started.get(), 7, vec![1, 2, 3]));
        tick();
        assert_eq!(done.get(), 73);
        assert_eq!(pending_count(), 0);
        assert!(!complete(started.get(), 0, vec![]), "second completion is ignored");
    }

    #[test]
    fn many_concurrent_tasks_complete_independently_and_out_of_order() {
        let out = Rc::new(RefCell::new(Vec::<u32>::new()));
        let ids = Rc::new(RefCell::new(Vec::<u32>::new()));
        for n in 0..50u32 {
            let (o, i) = (out.clone(), ids.clone());
            spawn(async move {
                let r = host_call(|id| i.borrow_mut().push(id)).await;
                o.borrow_mut().push(n * 1000 + r.status as u32);
            });
        }
        tick();
        assert_eq!(ids.borrow().len(), 50);
        for (k, id) in ids.borrow().iter().rev().enumerate() {
            complete(*id, k as i32, vec![]);
        }
        tick();
        assert_eq!(out.borrow().len(), 50);
        let mut sorted = out.borrow().clone();
        sorted.sort();
        assert_eq!(sorted.iter().map(|v| v / 1000).collect::<Vec<_>>(), (0..50).collect::<Vec<_>>());
    }

    #[test]
    fn a_task_can_spawn_another_task_while_polled() {
        let hit = Rc::new(Cell::new(false));
        let h = hit.clone();
        spawn(async move {
            spawn(async move { h.set(true) });
        });
        tick();
        tick();
        assert!(hit.get());
    }
}
