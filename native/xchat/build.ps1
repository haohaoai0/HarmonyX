param(
  [string]$SdkNative = 'D:\DevEco Studio\sdk\default\openharmony\native',
  [string]$DownloadProxy = ''
)
$ErrorActionPreference = 'Stop'
$dmWorkspace = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$dmReferences = Join-Path $dmWorkspace '.codex/dm-reference'
New-Item -ItemType Directory -Path $dmReferences -Force | Out-Null

function Get-ChatDependency {
  param([string]$Name, [string]$Url, [string]$Commit, [string[]]$SparsePaths)
  $dmCheckout = [System.IO.Path]::GetFullPath((Join-Path $dmReferences $Name))
  if (!$dmCheckout.StartsWith($dmReferences + [System.IO.Path]::DirectorySeparatorChar)) {
    throw 'Dependency path must stay in the task reference directory.'
  }
  $dmGitArgs = @()
  if ($DownloadProxy) { $dmGitArgs += @('-c', "http.proxy=$DownloadProxy") }
  if (!(Test-Path -LiteralPath (Join-Path $dmCheckout '.git'))) {
    & git @dmGitArgs clone --filter=blob:none --no-checkout $Url $dmCheckout
    if ($LASTEXITCODE) { throw "Failed to fetch $Name" }
  }
  & git @dmGitArgs -C $dmCheckout sparse-checkout set @SparsePaths
  & git @dmGitArgs -C $dmCheckout checkout --detach $Commit
  if ($LASTEXITCODE) { throw "Failed to select pinned $Name commit" }
  $dmHead = & git -C $dmCheckout rev-parse HEAD
  if ($dmHead -ne $Commit) { throw "Unexpected $Name commit" }
}

Get-ChatDependency 'chat-xdk-source' 'https://github.com/xdevplatform/chat-xdk.git' '84acbd482579002d074bd4524135bf0e9bafd53e' @('crates','tests','docs')

# Apply the stable media-upload message ID before building the pinned SDK.
# Keep the Go API and tests in the patch without fetching packaged Go binaries.
$dmChatSdk = Join-Path $dmReferences 'chat-xdk-source'
foreach ($dmGoFile in @('go/chatxdk/types.go','go/chatxdk/chatxdk_test.go')) {
  $dmGoPath = Join-Path $dmChatSdk $dmGoFile
  if (!(Test-Path -LiteralPath $dmGoPath)) {
    $dmGoSource = & git -C $dmChatSdk show "HEAD:$dmGoFile"
    if ($LASTEXITCODE) { throw "Cannot read pinned SDK file $dmGoFile" }
    New-Item -ItemType Directory -Path (Split-Path $dmGoPath) -Force | Out-Null
    [System.IO.File]::WriteAllText($dmGoPath, ($dmGoSource -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
  }
  & git -C $dmChatSdk update-index --no-skip-worktree $dmGoFile
  if ($LASTEXITCODE) { throw "Cannot include SDK file $dmGoFile" }
}
$dmSdkPatch = Join-Path $PSScriptRoot 'patches/media-message-id.patch'
$dmPatchApplied = $false
$dmApplyErrorPreference = $ErrorActionPreference
try {
  $ErrorActionPreference = 'Continue'
  & git -C $dmChatSdk apply --reverse --check $dmSdkPatch 2>$null
  $dmPatchApplied = $LASTEXITCODE -eq 0
} finally { $ErrorActionPreference = $dmApplyErrorPreference }
if (!$dmPatchApplied) {
  & git -C $dmChatSdk apply --check $dmSdkPatch
  if ($LASTEXITCODE) { throw 'Chat SDK media message ID patch does not match the pinned source' }
  & git -C $dmChatSdk apply $dmSdkPatch
  if ($LASTEXITCODE) { throw 'Cannot apply the Chat SDK media message ID patch' }
}

$dmActionsPatch = Join-Path $PSScriptRoot 'patches/chat-actions.patch'
$dmActionsApplied = $false
try {
  $ErrorActionPreference = 'Continue'
  & git -C $dmChatSdk apply --reverse --check $dmActionsPatch 2>$null
  $dmActionsApplied = $LASTEXITCODE -eq 0
} finally { $ErrorActionPreference = $dmApplyErrorPreference }
if (!$dmActionsApplied) {
  & git -C $dmChatSdk apply --check $dmActionsPatch
  if ($LASTEXITCODE) { throw 'Chat SDK actions patch does not match the pinned source' }
  & git -C $dmChatSdk apply $dmActionsPatch
  if ($LASTEXITCODE) { throw 'Cannot apply the Chat SDK actions patch' }
}

Get-ChatDependency 'juicebox-sdk' 'https://github.com/juicebox-systems/juicebox-sdk.git' '2e0f544e3fd0bd0997a034f73c8efb6fade3690c' @('rust')
Get-ChatDependency 'thrift' 'https://github.com/apache/thrift.git' 'deb36fa409849de45973b04ffc3ce49d277ca90a' @('lib/rs')

$dmLlvm = Join-Path $SdkNative 'llvm/bin'
$env:CC_SHELL_ESCAPED_FLAGS = '1'
$env:CC_aarch64_unknown_linux_ohos = Join-Path $dmLlvm 'clang.exe'
$env:AR_aarch64_unknown_linux_ohos = Join-Path $dmLlvm 'llvm-ar.exe'
$dmSysroot = (Join-Path $SdkNative 'sysroot').Replace('\','/')
$env:CFLAGS_aarch64_unknown_linux_ohos = "--target=aarch64-linux-ohos --sysroot=`"$dmSysroot`" -D__MUSL__"
if ($DownloadProxy) { $env:HTTPS_PROXY = $DownloadProxy; $env:HTTP_PROXY = $DownloadProxy }
Push-Location $dmWorkspace
try {
  & cargo build --release --locked --target aarch64-unknown-linux-ohos --manifest-path native/xchat/Cargo.toml
  if ($LASTEXITCODE) { throw 'Chat XDK native build failed' }
  $dmOutput = Join-Path $dmWorkspace 'entry/libs/arm64-v8a/libharmonyx_chat.so'
  New-Item -ItemType Directory -Path (Split-Path $dmOutput) -Force | Out-Null
  $dmLinkArgs = @('--target=aarch64-linux-ohos',"--sysroot=$dmSysroot",'-std=c++17','-shared','-fPIC','-O2',
    '-static-libstdc++','-Wl,--exclude-libs,ALL','-Wl,--gc-sections','-Wl,-z,max-page-size=16384',
    '-Wl,-soname,libharmonyx_chat.so','native/xchat/napi.cpp',
    'native/xchat/target/aarch64-unknown-linux-ohos/release/libharmonyx_chat.a',
    '-lace_napi.z','-ldl','-lm','-o',$dmOutput)
  & (Join-Path $dmLlvm 'clang++.exe') @dmLinkArgs
  if ($LASTEXITCODE) { throw 'Chat NAPI link failed' }
  & (Join-Path $dmLlvm 'llvm-strip.exe') --strip-debug $dmOutput
  if ($LASTEXITCODE) { throw 'Chat native strip failed' }
  Get-Item -LiteralPath $dmOutput | Select-Object FullName,Length
} finally { Pop-Location }
