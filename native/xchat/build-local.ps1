param(
  [string]$SdkNative = 'D:\DevEco Studio\sdk\default\openharmony\native',
  [ValidateSet('arm64-v8a', 'x86_64')]
  [string[]]$Abi = @('arm64-v8a')
)
$ErrorActionPreference = 'Stop'
$chatWorkspace = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$chatLlvm = Join-Path $SdkNative 'llvm/bin'
$chatSysroot = (Join-Path $SdkNative 'sysroot').Replace('\','/')
$env:CC_SHELL_ESCAPED_FLAGS = '1'

# Reuse the checked-out, patched dependencies. This script never resets them.
Push-Location $chatWorkspace
try {
  foreach ($chatAbi in $Abi) {
    $chatTarget = if ($chatAbi -eq 'x86_64') { 'x86_64-unknown-linux-ohos' } else { 'aarch64-unknown-linux-ohos' }
    $chatClangTarget = if ($chatAbi -eq 'x86_64') { 'x86_64-linux-ohos' } else { 'aarch64-linux-ohos' }
    $chatEnvTarget = $chatTarget.Replace('-', '_')
    [Environment]::SetEnvironmentVariable("CC_$chatEnvTarget", (Join-Path $chatLlvm 'clang.exe'), 'Process')
    [Environment]::SetEnvironmentVariable("AR_$chatEnvTarget", (Join-Path $chatLlvm 'llvm-ar.exe'), 'Process')
    [Environment]::SetEnvironmentVariable("CFLAGS_$chatEnvTarget",
      "--target=$chatClangTarget --sysroot=`"$chatSysroot`" -D__MUSL__", 'Process')
    & cargo build --release --locked --target $chatTarget --manifest-path native/xchat/Cargo.toml
    if ($LASTEXITCODE) { throw 'Chat XDK native build failed' }
    $chatOutput = Join-Path $chatWorkspace "entry/libs/$chatAbi/libharmonyx_chat.so"
    New-Item -ItemType Directory -Path (Split-Path $chatOutput) -Force | Out-Null
    $chatLinkArgs = @("--target=$chatClangTarget","--sysroot=$chatSysroot",'-std=c++17','-shared','-fPIC','-O2',
      '-static-libstdc++','-Wl,--exclude-libs,ALL','-Wl,--gc-sections','-Wl,-z,max-page-size=16384',
      '-Wl,-soname,libharmonyx_chat.so','native/xchat/napi.cpp',
      "native/xchat/target/$chatTarget/release/libharmonyx_chat.a",
      '-lace_napi.z','-ldl','-lm','-o',$chatOutput)
    & (Join-Path $chatLlvm 'clang++.exe') @chatLinkArgs
    if ($LASTEXITCODE) { throw 'Chat NAPI link failed' }
    & (Join-Path $chatLlvm 'llvm-strip.exe') --strip-debug $chatOutput
    if ($LASTEXITCODE) { throw 'Chat native strip failed' }
    Get-Item -LiteralPath $chatOutput | Select-Object FullName,Length,LastWriteTime
  }
} finally { Pop-Location }
