# WIRE 16 — HETZNER STORAGE BOX 1TB (copy-paste)

Rule: **Supabase = truth · Storage Box = weight · Hetzner = egress (free)**.
Mail body local NVMe par (fast), attachments Box par (sasta).

## A · Robot panel (aap ka hissa, 2 toggle)

Storage Box → Settings → **SSH support = ON**, **External reachability = ON**.
Username note karo (`u123456`).

## B · key + mount (server terminal, ek command — `u123456` apna daalo)

```bash
BOX=u123456; export BOX && cd /opt/anexomail-web && bash server/storage/mount-box.sh "$BOX"
```

Script khud: sshfs install → key banata (`/root/.ssh/storagebox`) → key Box par install
→ systemd mount `/mnt/anexomail-box` (reboot-safe) → `attachments/` folder → `df -h` reading.
Pehli dafa key install par Box ka password ek dafa poochha jayega (kahin save nahi hota).

## C · volume register (Supabase = truth)

```bash
cd /opt/anexomail-web && bash server/storage/register-box.sh u123456
```

Purana `server2-local` volume `accepts_new=false` ho jata hai — naye attachments Box par,
purana data jahan hai wahin readable. Zero migration.

## D · gate

```bash
cd /opt/anexomail-web && bash server/gates/storage-gate.sh
```
