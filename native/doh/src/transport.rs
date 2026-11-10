//! Direct HTTPS transport with RFC 8484 resolution and authenticated ECH.
//! No TLS verification bypass, proxy relay, account cookies in DoH, or local-DNS fallback.
use crate::{resolve, tls};
use reqwest::{Client, Method, Url};
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::ffi::{c_char, c_void, CStr, CString};
use std::net::SocketAddr;
use std::sync::{Arc, Mutex, OnceLock};
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, Instant};

type Emit = extern "C" fn(*mut c_void, i32, *const c_char, *const u8, usize);

#[derive(Clone, Copy)]
struct Events { callback: Option<Emit>, context: usize }
impl Events {
    fn send(&self, kind: i32, metadata: &Value, bytes: &[u8]) {
        if let Some(callback) = self.callback {
            if let Ok(text) = CString::new(metadata.to_string()) {
                callback(self.context as *mut c_void, kind, text.as_ptr(), bytes.as_ptr(), bytes.len());
            }
        }
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct Request {
    id: u64,
    endpoint: String,
    url: String,
    method: String,
    #[serde(default)] headers: HashMap<String, Value>,
    #[serde(default)] stream: bool,
    #[serde(default = "default_limit")] max_limit: usize,
    #[serde(default = "default_connect")] connect_timeout: u64,
    #[serde(default = "default_read")] read_timeout: u64,
}
fn default_limit() -> usize { 5 * 1024 * 1024 }
fn default_connect() -> u64 { 20_000 }
fn default_read() -> u64 { 60_000 }

struct Cancellation { cancelled: AtomicBool, notify: tokio::sync::Notify }
impl Cancellation {
    fn new() -> Self { Self { cancelled: AtomicBool::new(false), notify: tokio::sync::Notify::new() } }
    async fn wait(&self) {
        if self.cancelled.load(Ordering::Acquire) { return; }
        self.notify.notified().await;
    }
}
fn cancellations() -> &'static Mutex<HashMap<u64, Arc<Cancellation>>> {
    static VALUE: OnceLock<Mutex<HashMap<u64, Arc<Cancellation>>>> = OnceLock::new();
    VALUE.get_or_init(|| Mutex::new(HashMap::new()))
}
#[no_mangle]
pub extern "C" fn hx_http_register(id: u64) {
    if let Ok(mut map) = cancellations().lock() { map.insert(id, Arc::new(Cancellation::new())); }
}
#[no_mangle]
pub extern "C" fn hx_http_cancel(id: u64) {
    if let Ok(map) = cancellations().lock() {
        if let Some(state) = map.get(&id) {
            state.cancelled.store(true, Ordering::Release);
            state.notify.notify_one();
        }
    }
}
#[no_mangle]
pub extern "C" fn hx_http_forget(id: u64) {
    if let Ok(mut map) = cancellations().lock() { map.remove(&id); }
}

#[derive(Clone)]
struct CachedClient { client: Client, expires: Instant, ech: bool }
type ClientSlot = Arc<tokio::sync::Mutex<Option<CachedClient>>>;
fn slots() -> &'static Mutex<HashMap<String, ClientSlot>> {
    static VALUE: OnceLock<Mutex<HashMap<String, ClientSlot>>> = OnceLock::new();
    VALUE.get_or_init(|| Mutex::new(HashMap::new()))
}
fn dns_client() -> Result<Client, String> {
    static VALUE: OnceLock<Client> = OnceLock::new();
    if let Some(client) = VALUE.get() { return Ok(client.clone()); }
    let client = Client::builder().use_preconfigured_tls(tls(&[])?).no_proxy().https_only(true)
        .redirect(reqwest::redirect::Policy::none()).timeout(Duration::from_secs(10))
        .pool_max_idle_per_host(4).build().map_err(|_| "DoH client initialization failed")?;
    let _ = VALUE.set(client.clone());
    Ok(client)
}

async fn client_for(request: &Request, host: &str, refresh: bool) -> Result<CachedClient, String> {
    let key = format!("{}|{}|{}|{}", request.endpoint, host, request.connect_timeout, request.read_timeout);
    let slot = {
        let mut map = slots().lock().map_err(|_| "DoH cache lock failed")?;
        if map.len() >= 96 && !map.contains_key(&key) { map.clear(); }
        map.entry(key).or_insert_with(|| Arc::new(tokio::sync::Mutex::new(None))).clone()
    };
    // One resolver lookup per host/endpoint; simultaneous API/image loads share it.
    let mut cached = slot.lock().await;
    if !refresh {
        if let Some(entry) = cached.as_ref() {
            if entry.expires > Instant::now() { return Ok(entry.clone()); }
        }
    }
    let dns = dns_client()?;
    let (a, https) = tokio::join!(resolve(&dns, &request.endpoint, host, 1), resolve(&dns, &request.endpoint, host, 65));
    let mut a = a?;
    let https = https?;
    if a.addresses.is_empty() {
        let aaaa = resolve(&dns, &request.endpoint, host, 28).await?;
        a.addresses = aaaa.addresses;
        a.ttl = a.ttl.min(aaaa.ttl);
    }
    if a.addresses.is_empty() { return Err("DoH returned no address".into()); }
    let addresses: Vec<SocketAddr> = a.addresses.iter().map(|ip| SocketAddr::new(*ip, 0)).collect();
    let client = Client::builder().use_preconfigured_tls(tls(&https.ech)?).no_proxy().https_only(true)
        .redirect(reqwest::redirect::Policy::none()).resolve_to_addrs(host, &addresses)
        .connect_timeout(Duration::from_millis(request.connect_timeout.max(1)))
        .read_timeout(Duration::from_millis(request.read_timeout.max(1)))
        .pool_max_idle_per_host(4).pool_idle_timeout(Duration::from_secs(45))
        .build().map_err(|_| "HTTPS client initialization failed")?;
    let result = CachedClient { client, ech: !https.ech.is_empty(),
        expires: Instant::now() + Duration::from_secs(a.ttl.min(https.ttl).min(300) as u64) };
    *cached = Some(result.clone());
    Ok(result)
}

fn checked_url(input: &str) -> Result<Url, String> {
    let url = Url::parse(input).map_err(|_| "Invalid HTTPS URL")?;
    if url.scheme() != "https" || url.host_str().is_none() || !url.username().is_empty() || url.password().is_some() {
        return Err("Only HTTPS URLs without credentials are supported".into());
    }
    Ok(url)
}
fn redirect_headers(headers: &mut HashMap<String, Value>, old: &Url, new: &Url) {
    if old.origin() != new.origin() {
        headers.retain(|name, _| !matches!(name.to_ascii_lowercase().as_str(),
            "authorization" | "cookie" | "proxy-authorization" | "x-csrf-token" | "x-client-transaction-id"));
    }
}

async fn execute(request: &Request, body: Vec<u8>, events: Events) -> Result<(Value, Vec<u8>), String> {
    checked_url(&request.endpoint)?;
    let mut url = checked_url(&request.url)?;
    let mut method = Method::from_bytes(request.method.as_bytes()).map_err(|_| "Invalid HTTP method")?;
    let mut headers = request.headers.clone();
    let mut body = Arc::new(body);
    let started = Instant::now();
    for redirect in 0..=10 {
        let host = url.host_str().ok_or("Missing host")?;
        let cached = client_for(request, host, false).await?;
        let mut builder = cached.client.request(method.clone(), url.clone());
        for (name, value) in &headers {
            if matches!(name.to_ascii_lowercase().as_str(), "host" | "content-length" | "connection" | "proxy-authorization") { continue; }
            let value = match value { Value::String(v) => v.clone(), Value::Number(v) => v.to_string(), _ => continue };
            builder = builder.header(name, value);
        }
        if !body.is_empty() {
            let payload = body.clone();
            let length = payload.len();
            let stream = futures_util::stream::unfold((payload, 0), move |(payload, offset)| async move {
                if offset >= payload.len() { return None; }
                let end = (offset + 65536).min(payload.len());
                let chunk = payload[offset..end].to_vec();
                events.send(3, &json!({"sendSize":end,"totalSize":length}), &[]);
                Some((Ok::<_, std::io::Error>(chunk), (payload, end)))
            });
            builder = builder.header("Content-Length", length).body(reqwest::Body::wrap_stream(stream));
        }
        let sent = builder.send().await;
        let mut response = match sent {
            Ok(response) => response,
            Err(error) => {
                // Never replay a dispatched write. A future request re-resolves
                // expired/rotated ECH keys, while this failure stays observable.
                if cached.ech && error.is_connect() { let _ = client_for(request, host, true).await; }
                return Err(if error.is_timeout() { "HTTPS request timed out" } else if error.is_connect() {
                    "HTTPS/ECH handshake or connection failed"
                } else { "HTTPS request failed" }.into());
            }
        };
        let status = response.status().as_u16();
        if matches!(status, 301 | 302 | 303 | 307 | 308) {
            if let Some(location) = response.headers().get("location").and_then(|v| v.to_str().ok()) {
                if redirect == 10 { return Err("Too many HTTPS redirects".into()); }
                let next = url.join(location).map_err(|_| "Invalid HTTPS redirect")?;
                checked_url(next.as_str())?;
                redirect_headers(&mut headers, &url, &next);
                if status == 303 || (matches!(status, 301 | 302) && method == Method::POST) {
                    if method != Method::HEAD { method = Method::GET; }
                    body = Arc::new(Vec::new());
                    headers.retain(|name, _| !matches!(name.to_ascii_lowercase().as_str(), "content-type" | "content-length"));
                }
                url = next;
                continue;
            }
        }
        let total = response.content_length().unwrap_or(0);
        if !request.stream && total > request.max_limit as u64 { return Err("HTTP response exceeds maxLimit".into()); }
        let mut response_headers = serde_json::Map::new();
        for (name, value) in response.headers() {
            if let Ok(value) = value.to_str() { response_headers.insert(name.to_string(), json!(value)); }
        }
        response_headers.insert("status-line".into(), json!(format!("{:?} {status}", response.version())));
        let cookies = response.headers().get_all("set-cookie").iter()
            .filter_map(|value| value.to_str().ok()).collect::<Vec<_>>().join("\r\n");
        let header = Value::Object(response_headers);
        events.send(1, &header, &[]);
        let mut bytes = Vec::new();
        let mut received: u64 = 0;
        while let Some(chunk) = response.chunk().await.map_err(|_| "HTTPS body transfer failed")? {
            received = received.checked_add(chunk.len() as u64).ok_or("HTTP body size overflow")?;
            if !request.stream && received > request.max_limit as u64 { return Err("HTTP response exceeds maxLimit".into()); }
            if request.stream { events.send(2, &Value::Null, &chunk); }
            else { bytes.extend_from_slice(&chunk); }
            events.send(4, &json!({"receiveSize":received,"totalSize":total}), &[]);
        }
        return Ok((json!({"ok":true,"responseCode":status,"header":header,"cookies":cookies,"ech":cached.ech,
            "receivedBytes":received,"totalMs":started.elapsed().as_millis()}), bytes));
    }
    Err("Too many HTTPS redirects".into())
}

pub async fn request_json(metadata: &str, body: Vec<u8>) -> Result<(Value, Vec<u8>), String> {
    let request: Request = serde_json::from_str(metadata).map_err(|_| "Invalid request metadata")?;
    execute(&request, body, Events { callback: None, context: 0 }).await
}

#[repr(C)]
pub struct NativeResponse { pub metadata: *mut c_char, pub body: *mut u8, pub length: usize }

#[no_mangle]
pub unsafe extern "C" fn hx_http_request(metadata: *const c_char, data: *const u8, length: usize,
    callback: Option<Emit>, context: *mut c_void) -> *mut NativeResponse {
    let outcome = std::panic::catch_unwind(|| {
        let input = CStr::from_ptr(metadata).to_str().map_err(|_| "Invalid request metadata")?;
        let request: Request = serde_json::from_str(input).map_err(|_| "Invalid request metadata")?;
        let cancellation = cancellations().lock().map_err(|_| "Cancellation lock failed")?
            .get(&request.id).cloned().ok_or("Request was not registered")?;
        let body = if length == 0 { Vec::new() } else { std::slice::from_raw_parts(data, length).to_vec() };
        static RUNTIME: OnceLock<tokio::runtime::Runtime> = OnceLock::new();
        let runtime = RUNTIME.get_or_init(|| tokio::runtime::Builder::new_multi_thread().worker_threads(4)
            .enable_all().build().expect("HTTP runtime initialization failed"));
        let result = runtime.block_on(async {
            tokio::select! {
                _ = cancellation.wait() => Err("HTTP request cancelled".into()),
                result = tokio::time::timeout(Duration::from_millis(request.connect_timeout.saturating_add(request.read_timeout).max(1)),
                    execute(&request, body, Events { callback, context: context as usize })) =>
                    result.unwrap_or_else(|_| Err("HTTPS request timed out".into()))
            }
        });
        if let Ok(mut map) = cancellations().lock() { map.remove(&request.id); }
        result
    });
    let (metadata, body) = match outcome {
        Ok(Ok(result)) => result,
        Ok(Err(error)) => (json!({"ok":false,"error":error,"code":2300999}), Vec::new()),
        Err(_) => (json!({"ok":false,"error":"Native HTTP failure","code":2300999}), Vec::new())
    };
    let metadata = CString::new(metadata.to_string()).unwrap().into_raw();
    let mut body = body.into_boxed_slice();
    let response = NativeResponse { metadata, body: body.as_mut_ptr(), length: body.len() };
    std::mem::forget(body);
    Box::into_raw(Box::new(response))
}

#[no_mangle]
pub unsafe extern "C" fn hx_http_free(value: *mut NativeResponse) {
    if value.is_null() { return; }
    let value = Box::from_raw(value);
    if !value.metadata.is_null() { drop(CString::from_raw(value.metadata)); }
    if !value.body.is_null() { drop(Box::from_raw(std::ptr::slice_from_raw_parts_mut(value.body, value.length))); }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn credentials_are_stripped_only_on_cross_origin_redirects() {
        let mut headers = HashMap::from([("Cookie".into(), json!("secret")), ("Authorization".into(), json!("token")),
            ("x-csrf-token".into(), json!("csrf")), ("Range".into(), json!("bytes=0-15"))]);
        let old = Url::parse("https://x.com/a").unwrap();
        redirect_headers(&mut headers, &old, &Url::parse("https://x.com/b").unwrap());
        assert_eq!(headers.len(), 4);
        redirect_headers(&mut headers, &old, &Url::parse("https://pbs.twimg.com/b").unwrap());
        assert_eq!(headers.len(), 1);
        assert!(headers.contains_key("Range"));
    }
    #[test]
    fn plaintext_and_embedded_credentials_are_rejected() {
        assert!(checked_url("http://x.com/").is_err());
        assert!(checked_url("https://user:secret@x.com/").is_err());
        assert!(checked_url("https://x.com/a?q=b").is_ok());
    }
}
