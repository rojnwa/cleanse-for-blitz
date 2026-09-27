param(
  [switch]$Uninstall,
  [switch]$Verify,
  [int]$Port = 9333,
  [string]$BlitzExe = "$env:LOCALAPPDATA\Programs\Blitz\Blitz.exe"
)
$ErrorActionPreference = 'Stop'
$Name = 'Cleanse for Blitz'
$Version = '0.2.0'
$UpdateUrl = 'https://github.com/rojnwa/cleanse-for-blitz/releases/latest/download/cleanse.ps1'
$IconUrl = 'https://github.com/rojnwa/cleanse-for-blitz/releases/latest/download/icon.ico'
$shell = New-Object -ComObject WScript.Shell
trap { [void]$shell.Popup($_.Exception.Message, 0, $Name, 16); break }

$BlockedUrls = @(
  '*aditude.io*'
  '*dn0qt3r0xannq.cloudfront.net*'
  '*d3g98hgqjqzwq5.cloudfront.net*'
  '*prebid.cloud*'
  '*securepubads.g.doubleclick.net*'
  '*googlesyndication.com*'
  '*googletagservices.com*'
  '*kueezrtb.com*'
  '*script.ac*'
  '*primis.tech*'
  '*cpmstar.com*'
  '*cmp.inmobi.com*'
  '*inmobi-choice.io*'
  '*privacymanager.io*'
  '*google-analytics.com*'
  '*googletagmanager.com*'
)

$PageScript = @'
(() => {
  if (window.__cleanse) return;
  window.__cleanse = true;
  const style = document.createElement('style');
  style.textContent = `
    [class*="\u{1F911}"], .leaderboard-promo, .blitz3-promo, [data-primis-placement-id], [id^="qc-cmp2"]
      { display: none !important; }
    :root, main { --right-rail-width: 0px !important; --rail-gap: 0px !important; }`;
  const apply = () => style.isConnected || document.documentElement?.append(style);
  new MutationObserver(apply).observe(document, { childList: true, subtree: true });
  apply();
})();
'@

$InstallDir = "$env:LOCALAPPDATA\$Name"
$script = "$InstallDir\cleanse.ps1"
$icon = "$InstallDir\icon.ico"
$Shortcuts = 'Desktop', 'Programs', 'Startup' | ForEach-Object { Join-Path ([Environment]::GetFolderPath($_)) "$Name.lnk" }

if ($Uninstall) {
  Remove-Item ($Shortcuts + $InstallDir) -Recurse -Force -ErrorAction SilentlyContinue
  [void]$shell.Popup("$Name was removed. Blitz itself is untouched.", 0, $Name, 64)
  return
}

if (-not (Test-Path $BlitzExe)) { throw "Blitz isn't installed. Get it from blitz.gg, then try again." }

if (-not $Verify -and $PSCommandPath -ne $script) {
  $source = if ($PSCommandPath) { [IO.File]::ReadAllText($PSCommandPath) } else { Invoke-RestMethod $UpdateUrl -UseBasicParsing }
  $null = New-Item $InstallDir -ItemType Directory -Force
  [IO.File]::WriteAllText($script, $source)
  try { Invoke-WebRequest $IconUrl -OutFile $icon -UseBasicParsing -TimeoutSec 10 } catch {}

  Remove-Item $Shortcuts -ErrorAction SilentlyContinue
  $targets = $Shortcuts[0, 1]
  if ($shell.Popup('Start Blitz without ads whenever Windows starts?', 0, $Name, 4 + 32) -eq 6) { $targets = $Shortcuts }
  foreach ($path in $targets) {
    $lnk = $shell.CreateShortcut($path)
    $lnk.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
    $lnk.IconLocation = if (Test-Path $icon) { "$icon,0" } else { "$BlitzExe,0" }
    $lnk.WindowStyle = 7
    $lnk.Save()
  }
  [void]$shell.Popup("All set! Blitz will now open without ads.`n`nFrom now on, open it with the `"$Name`" shortcut on your desktop or in the Start menu.", 0, $Name, 64)
  Start-Process $targets[0]
  return
}

$none = [Threading.CancellationToken]::None
$buffer = [byte[]]::new(64KB)
$seq = 0

function Get-Json([string]$path) { Invoke-RestMethod "http://127.0.0.1:$Port$path" -UseBasicParsing -TimeoutSec 2 }

function Connect([string]$url) {
  $script:ws = [Net.WebSockets.ClientWebSocket]::new()
  $ws.ConnectAsync($url, $none).Wait()
}

function Send([string]$method, [hashtable]$params = @{}, [string]$session) {
  $msg = @{ id = ++$script:seq; method = $method; params = $params }
  if ($session) { $msg.sessionId = $session }
  $bytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $msg -Compress -Depth 5))
  $ws.SendAsync([ArraySegment[byte]]$bytes, 'Text', $true, $none).Wait()
}

function Receive {
  $stream = [IO.MemoryStream]::new()
  do {
    $r = $ws.ReceiveAsync([ArraySegment[byte]]$buffer, $none).GetAwaiter().GetResult()
    if ($r.MessageType -eq 'Close') { return }
    $stream.Write($buffer, 0, $r.Count)
  } until ($r.EndOfMessage)
  [Text.Encoding]::UTF8.GetString($stream.ToArray())
}

if ($Verify) {
  $page = (Get-Json /json/list) | Where-Object { $_.type -eq 'page' -and $_.url -match 'blitz' } | Select-Object -First 1
  if (-not $page) { throw "No Blitz page on port $Port. Start Blitz with the $Name shortcut first." }
  Connect $page.webSocketDebuggerUrl
  Send Runtime.evaluate @{ awaitPromise = $true; returnByValue = $true; expression = @'
(async () => {
  const ads = [...document.querySelectorAll('[class*="\u{1F911}"]')];
  let adHostBlocked = false;
  try { await fetch('https://securepubads.g.doubleclick.net/tag/js/gpt.js', { mode: 'no-cors', cache: 'no-store' }); }
  catch { adHostBlocked = true; }
  return {
    page: location.pathname,
    adSlots: ads.length,
    adsVisible: ads.filter((el) => el.offsetParent).length,
    railWidth: getComputedStyle(document.querySelector('main') || document.documentElement).getPropertyValue('--right-rail-width').trim(),
    cookieBanner: !!document.querySelector('#qc-cmp2-ui'),
    adHostBlocked,
  };
})()
'@ }
  $result = (Receive | ConvertFrom-Json).result.result.value
  $result | Format-List | Out-Host
  $pass = $result.adsVisible -eq 0 -and $result.railWidth -eq '0px' -and -not $result.cookieBanner -and $result.adHostBlocked
  if ($pass) { 'PASS' } else { 'FAIL' }
  exit [int](-not $pass)
}

$updated = $false
try {
  $latest = Invoke-RestMethod $UpdateUrl -UseBasicParsing -TimeoutSec 3
  if ($latest -match "\`$Version = '(.+?)'" -and [version]$Matches[1] -gt $Version) {
    $null = [scriptblock]::Create($latest)
    [IO.File]::WriteAllText($PSCommandPath, $latest)
    $updated = $true
  }
} catch {}
if ($updated) { & $PSCommandPath @PSBoundParameters; return }

$version = try { Get-Json /json/version } catch { $null }
if ($version) {
  Start-Process $BlitzExe
} else {
  Stop-Process -Name Blitz -Force -ErrorAction SilentlyContinue
  Wait-Process -Name Blitz -Timeout 10 -ErrorAction SilentlyContinue
  Start-Process $BlitzExe "--remote-debugging-port=$Port"
  for ($i = 0; -not $version -and $i -lt 60; $i++) {
    Start-Sleep -Milliseconds 500
    $version = try { Get-Json /json/version } catch { $null }
  }
  if (-not $version) { throw "Blitz didn't start in time. Please try again." }
}

Connect $version.webSocketDebuggerUrl
Send Target.setAutoAttach @{ autoAttach = $true; waitForDebuggerOnStart = $false; flatten = $true }
try {
  while ($msg = Receive) {
    if (-not $msg.Contains('"Target.attachedToTarget"')) { continue }
    $target = (ConvertFrom-Json $msg).params
    if ($target.targetInfo.type -ne 'page') { continue }
    Send Network.enable @{} $target.sessionId
    Send Network.setBlockedURLs @{ urls = $BlockedUrls } $target.sessionId
    Send Page.enable @{} $target.sessionId
    Send Page.addScriptToEvaluateOnNewDocument @{ source = $PageScript } $target.sessionId
    Send Runtime.evaluate @{ expression = $PageScript } $target.sessionId
  }
} catch {}
