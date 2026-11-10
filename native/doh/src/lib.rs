use std::net::{IpAddr, SocketAddr};
use std::sync::Arc;
use std::time::Duration;
use rustls::client::{EchConfig, EchMode};
use rustls::pki_types::EchConfigListBytes;
pub mod transport;

fn word(bytes: &[u8], pos: usize) -> Result<u16, String> {
    let pair = bytes.get(pos..pos + 2).ok_or("truncated DNS word")?;
    Ok(u16::from_be_bytes([pair[0], pair[1]]))
}

fn skip_name(bytes: &[u8], mut pos: usize) -> Result<usize, String> {
    for _ in 0..128 {
        let len = *bytes.get(pos).ok_or("truncated DNS name")?;
        if len == 0 { return Ok(pos + 1); }
        if len & 0xc0 == 0xc0 {
            if word(bytes, pos)? as usize & 0x3fff >= bytes.len() { return Err("invalid DNS pointer".into()); }
            return Ok(pos + 2);
        }
        if len > 63 || pos + 1 + len as usize >= bytes.len() { return Err("invalid DNS label".into()); }
        pos += 1 + len as usize;
    }
    Err("DNS name too long".into())
}

pub fn query(host: &str, kind: u16) -> Result<Vec<u8>, String> {
    let mut data = vec![0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0];
    if host.is_empty() || host.len() > 253 { return Err("invalid DNS hostname".into()); }
    for label in host.trim_end_matches('.').split('.') {
        if label.is_empty() || label.len() > 63 { return Err("invalid DNS hostname".into()); }
        data.push(label.len() as u8);
        data.extend_from_slice(label.as_bytes());
    }
    data.push(0); data.extend_from_slice(&kind.to_be_bytes()); data.extend_from_slice(&[0, 1]);
    Ok(data)
}

#[derive(Debug, Default)]
pub struct Records {
    pub addresses: Vec<IpAddr>,
    pub ech: Vec<u8>,
    pub ttl: u32,
}

pub fn parse_records(bytes: &[u8], question: &[u8]) -> Result<Records, String> {
    if bytes.len() < question.len() || bytes.get(..2) != question.get(..2) ||
        bytes[2] & 0xfa != 0x80 || bytes[3] & 0x0f != 0 || word(bytes, 4)? != 1 ||
        bytes.get(12..question.len()) != question.get(12..) {
        return Err("invalid DNS answer".into());
    }
    let mut result = Records { ttl: 300, ..Records::default() };
    let mut pos = question.len();
    for _ in 0..word(bytes, 6)? {
        pos = skip_name(bytes, pos)?;
        let kind = word(bytes, pos)?;
        let class = word(bytes, pos + 2)?;
        let ttl = u32::from_be_bytes(bytes.get(pos + 4..pos + 8).ok_or("truncated DNS TTL")?.try_into().unwrap());
        let len = word(bytes, pos + 8)? as usize;
        pos += 10;
        let end = pos.checked_add(len).ok_or("DNS length overflow")?;
        let data = bytes.get(pos..end).ok_or("truncated DNS record")?;
        if class == 1 {
            result.ttl = result.ttl.min(ttl);
            match kind {
                1 if len == 4 => result.addresses.push(IpAddr::from(<[u8; 4]>::try_from(data).unwrap())),
                28 if len == 16 => result.addresses.push(IpAddr::from(<[u8; 16]>::try_from(data).unwrap())),
                65 if len >= 3 => {
                    let mut param = skip_name(bytes, pos + 2)?;
                    if param > end { return Err("invalid HTTPS target".into()); }
                    while param < end {
                        let key = word(bytes, param)?;
                        let size = word(bytes, param + 2)? as usize;
                        param += 4;
                        if param + size > end { return Err("invalid HTTPS parameter".into()); }
                        if key == 5 { result.ech = bytes[param..param + size].to_vec(); }
                        param += size;
                    }
                }
                _ => {}
            }
        }
        pos = end;
    }
    Ok(result)
}

fn roots() -> rustls::RootCertStore {
    rustls::RootCertStore { roots: webpki_roots::TLS_SERVER_ROOTS.to_vec() }
}

fn tls(ech: &[u8]) -> Result<rustls::ClientConfig, String> {
    let provider = Arc::new(rustls::crypto::aws_lc_rs::default_provider());
    let builder = rustls::ClientConfig::builder_with_provider(provider);
    let builder = if ech.is_empty() {
        builder.with_safe_default_protocol_versions()
    } else {
        let config = EchConfig::new(EchConfigListBytes::from(ech), rustls::crypto::aws_lc_rs::hpke::ALL_SUPPORTED_SUITES)
            .map_err(|e| format!("ECH configuration: {e}"))?;
        builder.with_ech(EchMode::Enable(config))
    }.map_err(|e| e.to_string())?;
    Ok(builder.with_root_certificates(roots()).with_no_client_auth())
}

async fn resolve(client: &reqwest::Client, endpoint: &str, host: &str, kind: u16) -> Result<Records, String> {
    let query = query(host, kind)?;
    let response = client.post(endpoint).header("Content-Type", "application/dns-message")
        .header("Accept", "application/dns-message").body(query.clone()).send().await.map_err(|e| format!("DoH: {e}"))?;
    if response.status() != 200 { return Err(format!("DoH HTTP {}", response.status())); }
    let data = response.bytes().await.map_err(|e| e.to_string())?;
    if data.len() > 65535 { return Err("oversized DNS response".into()); }
    parse_records(&data, &query)
}

pub async fn probe(endpoint: &str, target: &str) -> Result<String, String> {
    let url = reqwest::Url::parse(target).map_err(|e| e.to_string())?;
    let host = url.host_str().ok_or("missing host")?;
    let dns = reqwest::Client::builder().use_preconfigured_tls(tls(&[])?).no_proxy()
        .timeout(Duration::from_secs(15)).build().map_err(|e| e.to_string())?;
    let (a, https) = tokio::join!(resolve(&dns, endpoint, host, 1), resolve(&dns, endpoint, host, 65));
    let a = a?;
    let https = https?;
    let addresses: Vec<SocketAddr> = a.addresses.iter().map(|ip| SocketAddr::new(*ip, 0)).collect();
    if addresses.is_empty() { return Err("no DoH address".into()); }
    let client = reqwest::Client::builder().use_preconfigured_tls(tls(&https.ech)?).no_proxy()
        .resolve_to_addrs(host, &addresses).timeout(Duration::from_secs(20)).build().map_err(|e| e.to_string())?;
    let response = client.get(url.clone()).send().await.map_err(|e| format!("HTTPS request: {e:?}"))?;
    let status = response.status();
    let body = response.text().await.map_err(|e| e.to_string())?;
    Ok(format!("host={host} ech_config_bytes={} addresses={} status={status} body_bytes={} preview={}",
        https.ech.len(), addresses.len(), body.len(), body.chars().take(120).collect::<String>()))
}

#[cfg(test)]
mod tests {
    use super::*;
    fn answer(kind: u16, rdata: &[u8]) -> (Vec<u8>, Vec<u8>) {
        let question = query("x.com", kind).unwrap();
        let mut response = question.clone();
        response[2] = 0x81; response[3] = 0x80; response[7] = 1;
        response.extend_from_slice(&[0xc0, 0x0c]);
        response.extend_from_slice(&kind.to_be_bytes());
        response.extend_from_slice(&[0, 1, 0, 0, 0, 60]);
        response.extend_from_slice(&(rdata.len() as u16).to_be_bytes());
        response.extend_from_slice(rdata);
        (question, response)
    }
    #[test]
    fn wire_query_and_addresses_match_rfc8484() {
        assert_eq!(query("x.com", 1).unwrap(), [0,0,1,0,0,1,0,0,0,0,0,0,1,120,3,99,111,109,0,0,1,0,1]);
        let (question, response) = answer(1, &[1,2,3,4]);
        let parsed = parse_records(&response, &question).unwrap();
        assert_eq!(parsed.addresses, ["1.2.3.4".parse::<IpAddr>().unwrap()]);
        assert_eq!(parsed.ttl, 60);
        for size in 0..response.len() { assert!(parse_records(&response[..size], &question).is_err()); }
    }
    #[test]
    fn https_ech_parameter_is_extracted_without_silently_accepting_bad_lengths() {
        let (question, mut response) = answer(65, &[0,1,0,0,5,0,3,1,2,3]);
        assert_eq!(parse_records(&response, &question).unwrap().ech, [1,2,3]);
        let last = response.len() - 4;
        response[last] = 255;
        assert!(parse_records(&response, &question).is_err());
        assert!(tls(&[1,2,3]).is_err());
    }
    #[test]
    fn failed_dns_wrong_questions_and_invalid_pointers_are_rejected() {
        let (question, response) = answer(1, &[1,2,3,4]);
        for (offset, value) in [(3,0x83),(2,0x83),(13,b'y'),(23,0xff),(24,0xff)] {
            let mut malformed = response.clone(); malformed[offset] = value;
            if offset == 24 { malformed[23] = 0xff; }
            assert!(parse_records(&malformed, &question).is_err());
        }
    }
}
