param(
  [string]$SdkNative = 'D:/DevEco Studio/sdk/default/openharmony/native',
  [ValidateSet('arm64-v8a', 'x86_64')]
  [string[]]$Abi = @('arm64-v8a'),
  [switch]$ProbeOnly
)
$ErrorActionPreference = 'Stop'
$dohWorkspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$dohLlvm = Join-Path $SdkNative 'llvm/bin'
$dohSysroot = (Join-Path $SdkNative 'sysroot').Replace('\', '/')
$env:CC_SHELL_ESCAPED_FLAGS = '1'
$env:OHOS_SDK_NATIVE = $SdkNative
$env:CMAKE = Join-Path $SdkNative 'build-tools/cmake/bin/cmake.exe'
$env:CMAKE_GENERATOR = 'Ninja'
$env:PATH = (Join-Path $SdkNative 'build-tools/cmake/bin') + ';' + $env:PATH
Push-Location $dohWorkspace
try {
  foreach ($dohAbi in $Abi) {
    $dohTarget = if ($dohAbi -eq 'x86_64') { 'x86_64-unknown-linux-ohos' } else { 'aarch64-unknown-linux-ohos' }
    $dohClangTarget = if ($dohAbi -eq 'x86_64') { 'x86_64-linux-ohos' } else { 'aarch64-linux-ohos' }
    $dohEnvTarget = $dohTarget.Replace('-', '_')
    [Environment]::SetEnvironmentVariable("CC_$dohEnvTarget", (Join-Path $dohLlvm 'clang.exe'), 'Process')
    [Environment]::SetEnvironmentVariable("CXX_$dohEnvTarget", (Join-Path $dohLlvm 'clang++.exe'), 'Process')
    [Environment]::SetEnvironmentVariable("AR_$dohEnvTarget", (Join-Path $dohLlvm 'llvm-ar.exe'), 'Process')
    # The OHOS CMake toolchain already supplies the target and quoted sysroot.
    # Passing the spaced SDK path through CFLAGS loses its quoting in cmake-rs.
    [Environment]::SetEnvironmentVariable("CFLAGS_$dohEnvTarget", '-D__MUSL__', 'Process')
    & cargo build --release --locked --target $dohTarget --manifest-path native/doh/Cargo.toml --lib
    if ($LASTEXITCODE) { throw 'DoH/ECH native build failed' }
    if ($ProbeOnly) { continue }
    $dohOutput = Join-Path $dohWorkspace "entry/libs/$dohAbi/libharmonyx_doh.so"
    New-Item -ItemType Directory -Path (Split-Path $dohOutput) -Force | Out-Null
    $dohLinkArgs = @("--target=$dohClangTarget", "--sysroot=$dohSysroot", '-std=c++17', '-shared', '-fPIC', '-O2',
      '-static-libstdc++', '-Wl,--exclude-libs,ALL', '-Wl,--gc-sections', '-Wl,-z,max-page-size=16384',
      '-Wl,-soname,libharmonyx_doh.so', 'native/doh/napi.cpp',
      "native/doh/target/$dohTarget/release/libharmonyx_doh.a", '-lace_napi.z', '-ldl', '-lm', '-o', $dohOutput)
    & (Join-Path $dohLlvm 'clang++.exe') @dohLinkArgs
    if ($LASTEXITCODE) { throw 'DoH/ECH NAPI link failed' }
    & (Join-Path $dohLlvm 'llvm-strip.exe') --strip-debug $dohOutput
    if ($LASTEXITCODE) { throw 'DoH/ECH strip failed' }
    Get-Item -LiteralPath $dohOutput | Select-Object FullName, Length, LastWriteTime
  }
} finally { Pop-Location }
