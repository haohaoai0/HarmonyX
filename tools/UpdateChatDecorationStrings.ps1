$ErrorActionPreference = 'Stop'
$taskRoot = Join-Path $PSScriptRoot '..\entry\src\main\resources'
$taskEnglish = @(
  @('chat_decoration', 'Chat decorations'),
  @('chat_decoration_subtitle', 'Avatar frames and chat bubbles, downloaded only when you choose them.'),
  @('chat_decoration_frame', 'Avatar frames'),
  @('chat_decoration_bubble', 'Chat bubbles'),
  @('chat_decoration_free', 'Free'),
  @('chat_decoration_download_preview', 'Download to preview'),
  @('chat_decoration_download', 'Download'),
  @('chat_decoration_downloading', 'Downloading...'),
  @('chat_decoration_use', 'Use'),
  @('chat_decoration_in_use', 'In use'),
  @('chat_decoration_remove', 'Stop using'),
  @('chat_decoration_installed', 'Downloaded'),
  @('chat_decoration_applied', 'Decoration applied'),
  @('chat_decoration_download_failed', 'Download failed. Try again later.'),
  @('chat_decoration_reset', 'Restore defaults'),
  @('chat_decoration_reset_done', 'Defaults restored'),
  @('chat_decoration_note', 'Decorations stay on this device. Other people see styles supported by their client.'),
  @('chat_decoration_loading', 'Loading decorations...'),
  @('chat_decoration_unavailable', 'Decorations are unavailable. Check your connection and retry.'),
  @('chat_decoration_sample_text', 'Have a lovely day.')
)
$taskSimplified = @(
  @('chat_decoration', '聊天装扮'),
  @('chat_decoration_subtitle', '头像挂件与聊天气泡，按需下载。'),
  @('chat_decoration_frame', '头像挂件'),
  @('chat_decoration_bubble', '聊天气泡'),
  @('chat_decoration_free', '免费'),
  @('chat_decoration_download_preview', '下载后可预览'),
  @('chat_decoration_download', '下载'),
  @('chat_decoration_downloading', '下载中…'),
  @('chat_decoration_use', '使用'),
  @('chat_decoration_in_use', '使用中'),
  @('chat_decoration_remove', '取消使用'),
  @('chat_decoration_installed', '已下载'),
  @('chat_decoration_applied', '装扮已应用'),
  @('chat_decoration_download_failed', '下载失败，请稍后重试'),
  @('chat_decoration_reset', '恢复默认'),
  @('chat_decoration_reset_done', '已恢复默认'),
  @('chat_decoration_note', '素材仅保存在本机；对方看到的样式仍取决于其自己的客户端和装扮。'),
  @('chat_decoration_loading', '正在获取装扮…'),
  @('chat_decoration_unavailable', '暂时无法获取装扮，请检查网络后重试。'),
  @('chat_decoration_sample_text', '今天也要开心呀。')
)
$taskTraditional = @(
  @('chat_decoration', '聊天裝扮'),
  @('chat_decoration_subtitle', '頭像掛件與聊天氣泡，按需下載。'),
  @('chat_decoration_frame', '頭像掛件'),
  @('chat_decoration_bubble', '聊天氣泡'),
  @('chat_decoration_free', '免費'),
  @('chat_decoration_download_preview', '下載後可預覽'),
  @('chat_decoration_download', '下載'),
  @('chat_decoration_downloading', '下載中…'),
  @('chat_decoration_use', '使用'),
  @('chat_decoration_in_use', '使用中'),
  @('chat_decoration_remove', '取消使用'),
  @('chat_decoration_installed', '已下載'),
  @('chat_decoration_applied', '裝扮已套用'),
  @('chat_decoration_download_failed', '下載失敗，請稍後再試'),
  @('chat_decoration_reset', '恢復預設'),
  @('chat_decoration_reset_done', '已恢復預設'),
  @('chat_decoration_note', '素材僅保存在本機；對方看到的樣式仍取決於其自己的用戶端和裝扮。'),
  @('chat_decoration_loading', '正在取得裝扮…'),
  @('chat_decoration_unavailable', '暫時無法取得裝扮，請檢查網路後再試。'),
  @('chat_decoration_sample_text', '今天也要開心呀。')
)

function Add-DecorationStrings([string]$taskPath, $taskRows) {
  $taskText = [System.IO.File]::ReadAllText($taskPath)
  $taskParsed = $taskText | ConvertFrom-Json
  $taskExisting = @{}
  foreach ($taskRow in $taskParsed.string) { $taskExisting[$taskRow.name] = $true }
  $taskBlocks = [System.Collections.Generic.List[string]]::new()
  foreach ($taskRow in $taskRows) {
    if (-not $taskExisting.ContainsKey($taskRow[0])) {
      $taskName = $taskRow[0].ToString()
      $taskValue = $taskRow[1].ToString() | ConvertTo-Json
      $taskBlocks.Add("    {`n      `"name`": `"$taskName`",`n      `"value`": $taskValue`n    }")
    }
  }
  if ($taskBlocks.Count -eq 0) { return }
  $taskClose = $taskText.LastIndexOf(']')
  if ($taskClose -lt 0) { throw "Invalid string resource: $taskPath" }
  $taskBefore = $taskText.Substring(0, $taskClose).TrimEnd()
  $taskComma = if ($taskBefore.EndsWith('[')) { '' } else { ',' }
  $taskAfter = $taskText.Substring($taskClose)
  $taskUpdated = $taskBefore + $taskComma + "`n" + ($taskBlocks -join ",`n") + "`n  " + $taskAfter
  [System.IO.File]::WriteAllText($taskPath, $taskUpdated, [System.Text.UTF8Encoding]::new($false))
}

foreach ($taskDirectory in Get-ChildItem -LiteralPath $taskRoot -Directory) {
  $taskStringPath = Join-Path $taskDirectory.FullName 'element\string.json'
  if (-not (Test-Path -LiteralPath $taskStringPath)) { continue }
  $taskLocale = $taskDirectory.Name
  if ($taskLocale -eq 'base' -or $taskLocale -eq 'zh_CN') { $taskRows = $taskSimplified }
  elseif ($taskLocale -eq 'zh_Hant') { $taskRows = $taskTraditional }
  else { $taskRows = $taskEnglish }
  Add-DecorationStrings $taskStringPath $taskRows
}
