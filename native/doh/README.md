# HarmonyX DoH / ECH transport

The optional direct HTTPS transport resolves addresses and HTTPS/ECH records
through the selected RFC 8484 endpoint, then connects to the origin with rustls.
It does not forward HTTP requests through the DNS service. Certificate and
hostname verification remain enabled. ECH rejection is an error, not an
automatic plaintext ClientHello retry. Endpoints without ECH records use normal
verified TLS. The endpoint hostname itself needs bootstrap system resolution.

`src/lib.rs` contains DNS wire parsing and TLS configuration;
`src/transport.rs` implements HTTPS, pooling, streaming and cancellation;
`napi.cpp` bridges a bounded event queue and completion promise to ArkTS.
`entry/src/main/ets/services/DohHttpRequest.ets` selects this implementation only
for explicitly direct HTTPS requests with DoH enabled. Other options retain
system HTTP, including app proxies, custom certificates and multipart bodies.

## Build on Windows

Install Rust with the `aarch64-unknown-linux-ohos` and
`x86_64-unknown-linux-ohos` targets, and the DevEco native SDK. From the project
root in PowerShell:

```powershell
./native/doh/build-local.ps1 -Abi @('arm64-v8a', 'x86_64')
devecocli build
```

Pass `-SdkNative` when the SDK is outside the script's default location.
Cargo.lock pins the dependency tree. The script compiles Rust, links the N-API
bridge, and writes `entry/libs/<ABI>/libharmonyx_doh.so`. Rebuild these libraries
after native source changes; `devecocli build` packages the existing libraries.
The libraries link the C++ runtime statically and use a 16 KB maximum page size.

```powershell
cargo test --manifest-path native/doh/Cargo.toml --locked
node --test tests/doh-http-request.test.cjs tests/dns-settings.test.cjs tests/video-range-source.test.cjs
```

The desktop-only probe uses public URLs and no account credentials:

```powershell
cargo run --manifest-path native/doh/Cargo.toml --example probe -- https://cloudflare-dns.com/dns-query https://x.com/robots.txt
```

Network behavior, system Web login and separately implemented native chat must
be assessed on their actual paths. See `docs/dns-over-https.md` for device
evidence and the settings workflow.
