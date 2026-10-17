//! Platform transport for the official Juicebox recovery protocol. The SDK
//! still performs all PIN hashing, secret sharing and authenticated recovery.
use async_trait::async_trait;
use chat_xdk_core::keys::juicebox::{JuiceboxApi, JuiceboxConfig, RecoverResult,
    RecoverFailureReason, RegisterResult, RegisterFailureReason, DeleteResult, DeleteFailureReason};
use juicebox_sdk::{AuthToken, AuthTokenManager, ClientBuilder, Configuration, Pin,
    RealmId, RecoverError, RegisterError, UserInfo, UserSecret, Policy, http};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use zeroize::Zeroizing;

#[derive(Default)]
pub struct Recovery {
    proxy: Mutex<String>,
    diagnostics: Arc<Mutex<Vec<Value>>>,
}

impl Recovery {
    pub fn configure(&self, proxy: String) {
        *self.proxy.lock().unwrap() = proxy;
        self.diagnostics.lock().unwrap().clear();
    }
    pub fn diagnostics(&self) -> Vec<Value> { self.diagnostics.lock().unwrap().clone() }
}

struct Tokens { tokens: HashMap<String, String> }
#[async_trait]
impl AuthTokenManager for Tokens {
    async fn get(&self, id: &RealmId) -> Option<AuthToken> {
        self.tokens.get(&hex::encode(id.0)).map(|v| AuthToken::from(v.clone()))
    }
}

struct NativeHttp {
    client: reqwest::Client,
    diagnostics: Arc<Mutex<Vec<Value>>>,
}

impl NativeHttp {
    fn record(&self, host: &str, status: u16, error: String) {
        let mut events = self.diagnostics.lock().unwrap();
        if events.len() < 24 { events.push(json!({"host": host, "status": status, "error": error})); }
    }
    fn error_description(error: reqwest::Error) -> String {
        // Remove URL, credentials and query parameters. No headers/bodies are logged.
        let error = error.without_url();
        let mut text = error.to_string();
        let mut source = std::error::Error::source(&error);
        while let Some(cause) = source {
            text.push_str(": "); text.push_str(&cause.to_string());
            source = cause.source();
        }
        text.truncate(text.floor_char_boundary(320));
        text
    }
}

#[async_trait]
impl http::Client for NativeHttp {
    async fn send(&self, request: http::Request) -> Option<http::Response> {
        let host = reqwest::Url::parse(&request.url).ok()?.host_str()?.to_string();
        let method = match request.method {
            http::Method::Get => reqwest::Method::GET,
            http::Method::Put => reqwest::Method::PUT,
            http::Method::Post => reqwest::Method::POST,
            http::Method::Delete => reqwest::Method::DELETE,
        };
        let mut builder = self.client.request(method, request.url);
        for (name, value) in request.headers { builder = builder.header(name, value); }
        if let Some(body) = request.body { builder = builder.body(body); }
        if let Some(timeout) = request.timeout { builder = builder.timeout(timeout); }
        let response = match builder.send().await {
            Ok(r) => r,
            Err(e) => { self.record(&host, 0, Self::error_description(e)); return None; }
        };
        let status_code = response.status().as_u16();
        let mut headers = HashMap::new();
        for (name, value) in response.headers() {
            if let Ok(value) = value.to_str() { headers.insert(name.to_string(), value.to_string()); }
        }
        match response.bytes().await {
            Ok(body) => {
                self.record(&host, status_code, String::new());
                Some(http::Response { status_code, headers, body: body.to_vec() })
            }
            Err(e) => { self.record(&host, status_code, Self::error_description(e)); None }
        }
    }
}

fn failed(reason: RecoverFailureReason) -> RecoverResult {
    RecoverResult::Failure { reason, guesses_remaining: None }
}

#[async_trait]
impl JuiceboxApi for Recovery {
    async fn recover_private_key(&self, pin: &[u8], config: &JuiceboxConfig) -> RecoverResult {
        let configuration = match Configuration::from_json(&config.config_json) {
            Ok(c) => c,
            Err(_) => {
                self.diagnostics.lock().unwrap().push(json!({"error": "invalid_recovery_configuration"}));
                return failed(RecoverFailureReason::Transient);
            }
        };
        // Explicit proxy selection avoids changing process-wide environment variables.
        let proxy = self.proxy.lock().unwrap().clone();
        let mut builder = reqwest::Client::builder().use_rustls_tls().no_proxy()
            .timeout(Duration::from_secs(15))
            .user_agent(format!("JuiceboxSdk-Rust/{}", juicebox_sdk::VERSION))
            .default_headers({
                let mut h = reqwest::header::HeaderMap::new();
                h.insert(juicebox_sdk::JUICEBOX_VERSION_HEADER,
                    reqwest::header::HeaderValue::from_static(juicebox_sdk::VERSION)); h
            });
        if !proxy.is_empty() {
            match reqwest::Proxy::all(&proxy) {
                Ok(p) => builder = builder.proxy(p),
                Err(_) => { return failed(RecoverFailureReason::Transient); }
            }
        }
        let client = match builder.build() {
            Ok(client) => client,
            Err(_) => { return failed(RecoverFailureReason::Transient); }
        };
        let client = ClientBuilder::new().configuration(configuration).tokio_sleeper()
            .http(NativeHttp { client, diagnostics: self.diagnostics.clone() })
            .auth_token_manager(Tokens { tokens: config.tokens.clone() }).build();
        match client.recover(&Pin::from(pin.to_vec()), &UserInfo::from(Vec::new())).await {
            Ok(secret) => RecoverResult::Success(Zeroizing::new(secret.expose_secret().to_vec())),
            Err(RecoverError::InvalidPin { guesses_remaining }) => RecoverResult::Failure {
                reason: RecoverFailureReason::InvalidPin, guesses_remaining: Some(guesses_remaining) },
            Err(e) => failed(match e {
                RecoverError::NotRegistered => RecoverFailureReason::NotRegistered,
                RecoverError::InvalidAuth => RecoverFailureReason::InvalidAuth,
                RecoverError::UpgradeRequired => RecoverFailureReason::UpgradeRequired,
                RecoverError::Assertion => RecoverFailureReason::Assertion,
                RecoverError::RateLimitExceeded => RecoverFailureReason::RateLimitExceeded,
                _ => RecoverFailureReason::Transient,
            })
        }
    }

    async fn register_private_key(&self, pin: &[u8], config: &JuiceboxConfig, key: &[u8]) -> RegisterResult {
        let configuration = match Configuration::from_json(&config.config_json) {
            Ok(c) => c, Err(_) => return RegisterResult::Failure(RegisterFailureReason::StorageFailed),
        };
        let proxy = self.proxy.lock().unwrap().clone();
        let mut builder = reqwest::Client::builder().use_rustls_tls().no_proxy()
            .timeout(Duration::from_secs(15)).user_agent(format!("JuiceboxSdk-Rust/{}", juicebox_sdk::VERSION))
            .default_headers({
                let mut h = reqwest::header::HeaderMap::new();
                h.insert(juicebox_sdk::JUICEBOX_VERSION_HEADER,
                    reqwest::header::HeaderValue::from_static(juicebox_sdk::VERSION)); h
            });
        if !proxy.is_empty() {
            match reqwest::Proxy::all(&proxy) { Ok(p) => builder = builder.proxy(p),
                Err(_) => return RegisterResult::Failure(RegisterFailureReason::StorageFailed) }
        }
        let http = match builder.build() { Ok(client) => NativeHttp { client, diagnostics: self.diagnostics.clone() },
            Err(_) => return RegisterResult::Failure(RegisterFailureReason::StorageFailed) };
        let client = ClientBuilder::new().configuration(configuration).tokio_sleeper().http(http)
            .auth_token_manager(Tokens { tokens: config.tokens.clone() }).build();
        match client.register(&Pin::from(pin.to_vec()), &UserSecret::from(key.to_vec()),
            &UserInfo::from(Vec::new()), Policy { num_guesses: config.max_guess_count }).await {
            Ok(()) => RegisterResult::Success,
            Err(e) => RegisterResult::Failure(match e {
                RegisterError::InvalidAuth => RegisterFailureReason::InvalidAuth,
                RegisterError::UpgradeRequired => RegisterFailureReason::UpgradeRequired,
                RegisterError::Assertion => RegisterFailureReason::Assertion,
                RegisterError::RateLimitExceeded => RegisterFailureReason::RateLimitExceeded,
                _ => RegisterFailureReason::StorageFailed,
            })
        }
    }
    async fn delete_keys(&self, _: &JuiceboxConfig) -> DeleteResult {
        DeleteResult::Failure(DeleteFailureReason::Transient)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use juicebox_sdk::http::Client;
    use std::io::{Read, Write};

    #[test]
    fn sdk_transport_preserves_response_and_redacts_credentials_and_body() {
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        let address = listener.local_addr().unwrap();
        let server = std::thread::spawn(move || {
            let (mut stream, _) = listener.accept().unwrap();
            stream.set_read_timeout(Some(Duration::from_secs(2))).unwrap();
            let mut bytes = [0u8; 4096];
            let count = stream.read(&mut bytes).unwrap();
            assert!(String::from_utf8_lossy(&bytes[..count]).contains("Bearer test-secret"));
            stream.write_all(b"HTTP/1.1 418 Test\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK").unwrap();
        });
        let diagnostics = Arc::new(Mutex::new(Vec::new()));
        let runtime = tokio::runtime::Runtime::new().unwrap();
        let response = runtime.block_on(async {
            let transport = NativeHttp {
                client: reqwest::Client::builder().no_proxy().build().unwrap(),
                diagnostics: diagnostics.clone(),
            };
            transport.send(http::Request {
                method: http::Method::Post, url: format!("http://{address}/secret-path"),
                headers: HashMap::from([("Authorization".into(), "Bearer test-secret".into())]),
                body: Some(b"private-recovery-body".to_vec()), timeout: Some(Duration::from_secs(2)),
            }).await.unwrap()
        });
        server.join().unwrap();
        assert_eq!(response.status_code, 418);
        assert_eq!(response.body, b"OK");
        let diagnostic = serde_json::to_string(&*diagnostics.lock().unwrap()).unwrap();
        assert!(diagnostic.contains("418"));
        assert!(!diagnostic.contains("test-secret"));
        assert!(!diagnostic.contains("private-recovery-body"));
        assert!(!diagnostic.contains("secret-path"));
    }
}
