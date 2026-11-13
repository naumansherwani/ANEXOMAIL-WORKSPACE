//! The zone: built from plain config (later from the PostgreSQL zone table + ledger). Only these names exist; everything else under the origin is NXDOMAIN.
use hickory_proto::rr::rdata::caa::CAA;
use hickory_proto::rr::rdata::svcb::{Alpn, SvcParamKey, SvcParamValue, SVCB};
use hickory_proto::rr::rdata::{A, AAAA, HTTPS, NS, SOA};
use hickory_proto::rr::{LowerName, Name, RData, Record, RecordType};
use std::net::{Ipv4Addr, Ipv6Addr};
use std::str::FromStr;

#[derive(Clone, Debug)]
pub struct ZoneConfig {
    pub origin: String,        // founderworkspace.anexomail.com.
    pub ns: Vec<String>,       // ns1.anexomail.com. ns2.anexomail.com.
    pub hostmaster: String,    // hostmaster.anexomail.com.
    pub serial: u32,
    pub v4: Vec<Ipv4Addr>,
    pub v6: Vec<Ipv6Addr>,
    pub alpn: Vec<String>,     // ["h3"]  (HTTP/3 only, his 13 Nov 20:30 law)
    pub caa_issuers: Vec<String>, // ["letsencrypt.org"] etc.; empty = no CAA at this name
    pub ttl: u32,
}

impl ZoneConfig {
    pub fn from_env() -> Result<Self, String> {
        let g = |k: &str| std::env::var(k).map_err(|_| format!("env {k} is missing"));
        let list = |s: String| s.split(',').map(|x| x.trim().to_string()).filter(|x| !x.is_empty()).collect::<Vec<_>>();
        let v4 = list(g("DNS_V4")?).iter().map(|x| x.parse().map_err(|e| format!("DNS_V4 {x}: {e}"))).collect::<Result<Vec<Ipv4Addr>, _>>()?;
        let v6 = list(std::env::var("DNS_V6").unwrap_or_default()).iter().map(|x| x.parse().map_err(|e| format!("DNS_V6 {x}: {e}"))).collect::<Result<Vec<Ipv6Addr>, _>>()?;
        Ok(ZoneConfig {
            origin: g("DNS_ZONE")?, ns: list(g("DNS_NS")?), hostmaster: g("DNS_HOSTMASTER")?,
            serial: g("DNS_SERIAL")?.parse().map_err(|e| format!("DNS_SERIAL: {e}"))?,
            v4, v6, alpn: list(std::env::var("DNS_ALPN").unwrap_or_else(|_| "h3".into())),
            caa_issuers: list(std::env::var("DNS_CAA").unwrap_or_default()), ttl: std::env::var("DNS_TTL").ok().and_then(|x| x.parse().ok()).unwrap_or(300),
        })
    }
}

pub struct Zone { pub origin: LowerName, pub cfg: ZoneConfig, soa: Record, ns: Vec<Record>, a: Vec<Record>, aaaa: Vec<Record>, https: Vec<Record>, caa: Vec<Record> }

fn nm(s: &str) -> Result<Name, String> { Name::from_str(s).map_err(|e| format!("name {s}: {e}")) }

impl Zone {
    pub fn build(cfg: ZoneConfig) -> Result<Zone, String> {
        let origin = nm(&cfg.origin)?;
        let t = cfg.ttl;
        let soa = Record::from_rdata(origin.clone(), t, RData::SOA(SOA::new(nm(cfg.ns.first().ok_or("DNS_NS is empty")?)?, nm(&cfg.hostmaster)?, cfg.serial, 3600, 600, 1_209_600, t)));
        let ns = cfg.ns.iter().map(|n| Ok(Record::from_rdata(origin.clone(), t, RData::NS(NS(nm(n)?))))).collect::<Result<Vec<_>, String>>()?;
        let a = cfg.v4.iter().map(|ip| Record::from_rdata(origin.clone(), t, RData::A(A(*ip)))).collect();
        let aaaa = cfg.v6.iter().map(|ip| Record::from_rdata(origin.clone(), t, RData::AAAA(AAAA(*ip)))).collect();
        // RFC 9460: HTTPS, priority 1 (ServiceMode), target "." = this name itself, alpn list. HTTP/3 only means alpn="h3".
        let https = if cfg.alpn.is_empty() { vec![] } else {
            let params = vec![(SvcParamKey::Alpn, SvcParamValue::Alpn(Alpn(cfg.alpn.clone())))];
            vec![Record::from_rdata(origin.clone(), t, RData::HTTPS(HTTPS(SVCB::new(1, Name::root(), params))))]
        };
        let caa = cfg.caa_issuers.iter().map(|i| Ok(Record::from_rdata(origin.clone(), t, RData::CAA(CAA::new_issue(false, Some(nm(i)?), vec![]))))).collect::<Result<Vec<_>, String>>()?;
        Ok(Zone { origin: LowerName::new(&origin), cfg, soa, ns, a, aaaa, https, caa })
    }
    pub fn soa(&self) -> &Record { &self.soa }
    /// Records of `rtype` at the apex; None = the type is not served here (NODATA), Some(empty) never returned.
    pub fn apex(&self, rtype: RecordType) -> Option<&Vec<Record>> {
        let v = match rtype { RecordType::NS => &self.ns, RecordType::A => &self.a, RecordType::AAAA => &self.aaaa, RecordType::HTTPS => &self.https, RecordType::CAA => &self.caa, _ => return None };
        if v.is_empty() { None } else { Some(v) }
    }
    pub fn soa_only(&self, rtype: RecordType) -> bool { rtype == RecordType::SOA }
}
