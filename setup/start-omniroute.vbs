Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' ============================================================
' CONFIGURATION
'
' WSL_DISTRO is the name of the WSL distribution that hosts
' OmniRoute, OpenCode, and DSH. The original tray was written
' for "ArchLinux". Any user with any Linux distro installed
' under WSL can change this constant and the tray will work
' against their distro.
'
' To find your distro name, run in PowerShell:
'
'     wsl -l -q
'
' Examples:
'   - Ubuntu
'   - Ubuntu-22.04
'   - Debian
'   - archlinux
'   - openSUSE-Leap-15
'   - kali-linux
' ============================================================

WSL_DISTRO = "ArchLinux"

ps = ""
ps = ps & "Add-Type -AssemblyName System.Windows.Forms" & vbCrLf
ps = ps & "Add-Type -AssemblyName System.Drawing" & vbCrLf
ps = ps & "" & vbCrLf
ps = ps & "$WSLDistro = '" & WSL_DISTRO & "'" & vbCrLf
ps = ps & "$ErrorActionPreference = 'Continue'" & vbCrLf
ps = ps & "$debugLog = Join-Path $env:TEMP 'omniroute-tray-debug.log'" & vbCrLf
ps = ps & "function Debug-Trace { param([string]$Message); $line = '[' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') + '] ' + $Message; Write-Host $line; try { Add-Content -Path $debugLog -Value $line -ErrorAction SilentlyContinue } catch {} }" & vbCrLf
ps = ps & "Debug-Trace 'PowerShell payload entered'" & vbCrLf
ps = ps & "Debug-Trace ('WSL distro = ' + $WSLDistro)" & vbCrLf
ps = ps & "" & vbCrLf

' ============================================================
' START DOCKER DESKTOP, THEN WSL - $WSLDistro
'
' Docker Desktop must be fully ready before the WSL distro
' starts. This prevents systemd from starting
' OpenCode/OmniRoute/DSH before Docker Desktop's WSL
' integration is initialized.
' ============================================================

ps = ps & "Debug-Trace 'Checking Docker Desktop'" & vbCrLf
ps = ps & "$dockerExe = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'" & vbCrLf
ps = ps & "$dockerDesktopExe = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "if (-not (Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue)) {" & vbCrLf
ps = ps & "    Start-Process $dockerDesktopExe -WindowStyle Hidden" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "$dockerReady = $false" & vbCrLf
ps = ps & "for ($i = 0; $i -lt 120; $i++) {" & vbCrLf
ps = ps & "    if (Test-Path $dockerExe) {" & vbCrLf
ps = ps & "        & $dockerExe info --format '{{.ServerVersion}}' *> $null" & vbCrLf
ps = ps & "        if ($LASTEXITCODE -eq 0) {" & vbCrLf
ps = ps & "            $dockerReady = $true" & vbCrLf
ps = ps & "            break" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    Start-Sleep -Seconds 1" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "Debug-Trace ('Docker ready = ' + $dockerReady)" & vbCrLf
ps = ps & "if ($dockerReady) {" & vbCrLf
ps = ps & "    Start-Sleep -Seconds 2" & vbCrLf
ps = ps & "    Start-Process wsl.exe -ArgumentList '-d',$WSLDistro,'--exec','dbus-launch','true' -WindowStyle Hidden -PassThru" & vbCrLf
ps = ps & "} else {" & vbCrLf
ps = ps & "    [System.Windows.Forms.MessageBox]::Show('Docker Desktop did not become ready within 120 seconds. ' + $WSLDistro + ' services were not started.','AI Services', 'OK', 'Error')" & vbCrLf
ps = ps & "    exit" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

' ============================================================
' SYSTEMD HELPERS
' ============================================================

' ------------------------------------------------------------
' Run systemctl inside Arch WSL without showing a terminal.
' ------------------------------------------------------------

ps = ps & "function Invoke-WslSystemctl {" & vbCrLf
ps = ps & "    param([string[]]$Arguments)" & vbCrLf
ps = ps & "" & vbCrLf
ps = ps & "    Start-Process wsl.exe -ArgumentList (@('-d',$WSLDistro,'--exec','systemctl') + $Arguments) -WindowStyle Hidden -Wait" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

' ------------------------------------------------------------
' Get systemd ActiveState.
'
' active       = running
' activating   = starting
' deactivating = stopping
' failed       = failed
' inactive     = stopped
' ------------------------------------------------------------

ps = ps & "function Get-WslServiceState {" & vbCrLf
ps = ps & "    param([string]$Service)" & vbCrLf
ps = ps & "" & vbCrLf
ps = ps & "    $state = & wsl.exe -d $WSLDistro --exec systemctl show -p ActiveState --value $Service 2>$null" & vbCrLf
ps = ps & "" & vbCrLf
ps = ps & "    if ($null -eq $state) {" & vbCrLf
ps = ps & "        return 'unknown'" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "" & vbCrLf
ps = ps & "    return ($state | Out-String).Trim()" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

' ------------------------------------------------------------
' Get systemd EnabledState.
'
' This is intentionally based on:
'
'     systemctl is-enabled SERVICE
'
' so the tray menu always reflects the real systemd state.
' ------------------------------------------------------------

ps = ps & "function Get-WslServiceEnabled {" & vbCrLf
ps = ps & "    param([string]$Service)" & vbCrLf
ps = ps & "" & vbCrLf
ps = ps & "    $state = & wsl.exe -d $WSLDistro --exec systemctl is-enabled $Service 2>$null" & vbCrLf
ps = ps & "" & vbCrLf
ps = ps & "    if ($null -eq $state) {" & vbCrLf
ps = ps & "        return $false" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "" & vbCrLf
ps = ps & "    return (($state | Out-String).Trim() -eq 'enabled')" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

' ============================================================
' ENSURE OMNIROUTE
'
' OmniRoute is the shared dependency for both OpenCode and DSH.
'
' Starting either agent:
'
'     ensure OmniRoute
'             v
'     start requested agent
'
' We intentionally do NOT restart OmniRoute when restarting an
' individual agent.
' ============================================================

ps = ps & "function Ensure-OmniRoute {" & vbCrLf
ps = ps & "    $state = Get-WslServiceState 'omniroute'" & vbCrLf
ps = ps & "" & vbCrLf
ps = ps & "    if ($state -ne 'active') {" & vbCrLf
ps = ps & "        Invoke-WslSystemctl @('start','omniroute')" & vbCrLf
ps = ps & "" & vbCrLf
ps = ps & "        # Give OmniRoute a moment to initialize." & vbCrLf
ps = ps & "        for ($i = 0; $i -lt 20; $i++) {" & vbCrLf
ps = ps & "            Start-Sleep -Milliseconds 250" & vbCrLf
ps = ps & "            if ((Get-WslServiceState 'omniroute') -eq 'active') {" & vbCrLf
ps = ps & "                break" & vbCrLf
ps = ps & "            }" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

' ============================================================
' START SERVICES ENABLED IN SYSTEMD
'
' The Startup checkbox/menu item is synchronized directly with:
'
'     systemctl enable SERVICE
'     systemctl disable SERVICE
'
' On script startup we check the enabled state of all three.
'
' If none are enabled:
'
'     NOTHING is started.
'
' If OmniRoute is enabled:
'
'     OmniRoute is started.
'
' If OpenCode is enabled:
'
'     OmniRoute is ensured first, then OpenCode starts.
'
' If DSH is enabled:
'
'     OmniRoute is ensured first, then DSH starts.
'
' This means the Windows tray script does NOT maintain a second
' startup configuration. systemd remains the source of truth.
' ============================================================

ps = ps & "function Start-EnabledServices {" & vbCrLf
ps = ps & "    $omniEnabled = Get-WslServiceEnabled 'omniroute'" & vbCrLf
ps = ps & "    $openCodeEnabled = Get-WslServiceEnabled 'opencode'" & vbCrLf
ps = ps & "    $dshEnabled = Get-WslServiceEnabled 'dsh'" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    # Start OmniRoute first whenever it is enabled or" & vbCrLf
ps = ps & "    # an enabled agent requires it." & vbCrLf
ps = ps & "    if ($omniEnabled -or $openCodeEnabled -or $dshEnabled) {" & vbCrLf
ps = ps & "        Ensure-OmniRoute" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    if ($openCodeEnabled) {" & vbCrLf
ps = ps & "        Invoke-WslSystemctl @('start','opencode')" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    if ($dshEnabled) {" & vbCrLf
ps = ps & "        Invoke-WslSystemctl @('start','dsh')" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

' ============================================================
' OPENCODE PROFILE TOGGLE
'
' The active OpenCode config is:
'
'     $HOME/.config/opencode/opencode.jsonc   (or $XDG_CONFIG_HOME/opencode)
'
' We keep two profile templates side by side:
'
'     profile.my-agents.jsonc   (always points at the My-Agents 6-stage plugin)
'     profile.ecc.jsonc         (always points at the ecc-universal npm plugin)
'
' Switching is a single file copy + systemctl restart opencode.
'
' For the ECC profile we additionally ensure the `ecc-universal`
' npm package is installed globally inside WSL and that its dist/
' build is present. Both steps run with full logging and can be
' aborted by the user.
'
' See PLAN-OPENCODE-PROFILE-TOGGLE.md for the full design.
' ============================================================

ps = ps & "$trayLogDir = Join-Path $env:LOCALAPPDATA 'My-Agents'" & vbCrLf
ps = ps & "if (-not (Test-Path $trayLogDir)) { [void](New-Item -ItemType Directory -Path $trayLogDir) }" & vbCrLf
ps = ps & "$trayLogPath = Join-Path $trayLogDir 'tray.log'" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Write-TrayLog {" & vbCrLf
ps = ps & "    param([string]$Message)" & vbCrLf
ps = ps & "    $line = '[' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '] ' + $Message" & vbCrLf
ps = ps & "    try { Add-Content -Path $trayLogPath -Value $line -ErrorAction SilentlyContinue } catch {}" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Rotate-TrayLog {" & vbCrLf
ps = ps & "    if (-not (Test-Path $trayLogPath)) { return }" & vbCrLf
ps = ps & "    $size = (Get-Item $trayLogPath -ErrorAction SilentlyContinue).Length" & vbCrLf
ps = ps & "    if ($null -eq $size) { return }" & vbCrLf
ps = ps & "    if ($size -lt 5MB) { return }" & vbCrLf
ps = ps & "    try {" & vbCrLf
ps = ps & "        $tail = Get-Content $trayLogPath -Tail 2000 -ErrorAction SilentlyContinue" & vbCrLf
ps = ps & "        if ($null -ne $tail -and $tail.Count -gt 0) {" & vbCrLf
ps = ps & "            Set-Content -Path $trayLogPath -Value $tail -ErrorAction SilentlyContinue" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "    } catch {}" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Show-TrayError {" & vbCrLf
ps = ps & "    param([string]$Title, [string]$Message)" & vbCrLf
ps = ps & "    Write-TrayLog ('ERROR: ' + $Title + ' - ' + $Message)" & vbCrLf
ps = ps & "    $answer = [System.Windows.Forms.MessageBox]::Show(" & vbCrLf
ps = ps & "        $Message + [Environment]::NewLine + [Environment]::NewLine + 'Open the tray log?'," & vbCrLf
ps = ps & "        'AI Services - ' + $Title," & vbCrLf
ps = ps & "        'YesNo'," & vbCrLf
ps = ps & "        'Warning')" & vbCrLf
ps = ps & "    if ($answer -eq 'Yes') { Start-Process notepad.exe $trayLogPath }" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Convert-ToWslPath {" & vbCrLf
ps = ps & "    param([string]$Path)" & vbCrLf
ps = ps & "    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }" & vbCrLf
ps = ps & "    $Path = $Path.Trim()" & vbCrLf
ps = ps & "    if ($Path -match '^[A-Za-z]:[\\/]') {" & vbCrLf
ps = ps & "        $drive = $Path.Substring(0,1).ToLowerInvariant()" & vbCrLf
ps = ps & "        $rest = $Path.Substring(2) -replace '\\','/'" & vbCrLf
ps = ps & "        return ('/mnt/' + $drive + $rest)" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    return $Path" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Get-WslConfigRoot {" & vbCrLf
ps = ps & "    $root = & wsl.exe -d $WSLDistro -- printenv OPENCODE_CONFIG_DIR 2>$null" & vbCrLf
ps = ps & "    $root = ($root | Out-String).Trim()" & vbCrLf
ps = ps & "    Write-TrayLog ('OPENCODE_CONFIG_DIR raw = [' + $root + ']')" & vbCrLf
ps = ps & "    if (-not [string]::IsNullOrEmpty($root)) {" & vbCrLf
ps = ps & "        $root = Convert-ToWslPath $root" & vbCrLf
ps = ps & "        Write-TrayLog ('OpenCode config root resolved from OPENCODE_CONFIG_DIR = [' + $root + ']')" & vbCrLf
ps = ps & "        return $root" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "" & vbCrLf
ps = ps & "    $xdg = & wsl.exe -d $WSLDistro -- printenv XDG_CONFIG_HOME 2>$null" & vbCrLf
ps = ps & "    $xdg = ($xdg | Out-String).Trim()" & vbCrLf
ps = ps & "    Write-TrayLog ('XDG_CONFIG_HOME raw = [' + $xdg + ']')" & vbCrLf
ps = ps & "    if (-not [string]::IsNullOrEmpty($xdg)) {" & vbCrLf
ps = ps & "        $xdg = Convert-ToWslPath $xdg" & vbCrLf
ps = ps & "        return ($xdg.TrimEnd('/') + '/opencode')" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "" & vbCrLf
ps = ps & "    $linuxUser = & wsl.exe -d $WSLDistro -- id -un 2>$null" & vbCrLf
ps = ps & "    $linuxUser = ($linuxUser | Out-String).Trim()" & vbCrLf
ps = ps & "    Write-TrayLog ('WSL Linux user = [' + $linuxUser + ']')" & vbCrLf
ps = ps & "    $linuxHome = & wsl.exe -d $WSLDistro -- bash -c 'getent passwd ""$(id -un)"" | cut -d: -f6' 2>$null" & vbCrLf
ps = ps & "    $linuxHome = ($linuxHome | Out-String).Trim()" & vbCrLf
ps = ps & "    Write-TrayLog ('WSL Linux home = [' + $linuxHome + ']')" & vbCrLf
ps = ps & "    if ([string]::IsNullOrWhiteSpace($linuxHome)) { return $null }" & vbCrLf
ps = ps & "    return ($linuxHome.TrimEnd('/') + '/.config/opencode')" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Invoke-WslBash {" & vbCrLf
ps = ps & "    param([string]$Command)" & vbCrLf
ps = ps & "    $output = & wsl.exe -d $WSLDistro -- bash -lc $Command 2>&1" & vbCrLf
ps = ps & "    return ($output | Out-String).Trim()" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Get-WslFileHash {" & vbCrLf
ps = ps & "    param([string]$WslPath)" & vbCrLf
ps = ps & "    $b64 = & wsl.exe -d $WSLDistro -- base64 -w0 -- $WslPath 2>$null" & vbCrLf
ps = ps & "    if ($null -eq $b64) { return $null }" & vbCrLf
ps = ps & "    $b64 = ($b64 | Out-String).Trim()" & vbCrLf
ps = ps & "    if ($b64.Length -eq 0) { return $null }" & vbCrLf
ps = ps & "    try {" & vbCrLf
ps = ps & "        $raw = [Convert]::FromBase64String($b64)" & vbCrLf
ps = ps & "        $sha = [System.Security.Cryptography.SHA256]::Create()" & vbCrLf
ps = ps & "        $h = $sha.ComputeHash($raw)" & vbCrLf
ps = ps & "        return ([BitConverter]::ToString($h) -replace '-','').ToLowerInvariant()" & vbCrLf
ps = ps & "    } catch { return $null }" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

' --- Fallback template for my-agents (used when repo files are absent).
ps = ps & "$profileMyAgentsFallback = @'" & vbCrLf
ps = ps & "{" & vbCrLf
ps = ps & "  ""$schema"": ""https://opencode.ai/config.json""," & vbCrLf
ps = ps & "  ""plugin"": [[" & vbCrLf
ps = ps & "    ""my-agents@git+https://github.com/Venom120/My-Agents.git#main""," & vbCrLf
ps = ps & "    {" & vbCrLf
ps = ps & "      ""externalSkills"": []" & vbCrLf
ps = ps & "    }]" & vbCrLf
ps = ps & "  ]," & vbCrLf
ps = ps & "  ""provider"": {" & vbCrLf
ps = ps & "    ""omniroute"": {" & vbCrLf
ps = ps & "      ""name"": ""OmniRoute""," & vbCrLf
ps = ps & "      ""npm"": ""@ai-sdk/openai-compatible""," & vbCrLf
ps = ps & "      ""options"": {" & vbCrLf
ps = ps & "        ""baseURL"": ""http://127.0.0.1:20128/v1""," & vbCrLf
ps = ps & "        ""apiKey"": ""{env:OMNIROUTE_API_KEY}""" & vbCrLf
ps = ps & "      }," & vbCrLf
ps = ps & "      ""models"": {" & vbCrLf
ps = ps & "        ""free-reasoning"":        { ""name"": ""OmniRoute - Reasoning"" }," & vbCrLf
ps = ps & "        ""free-coding-deep"":      { ""name"": ""OmniRoute - Deep Coding"" }," & vbCrLf
ps = ps & "        ""free-coding-standard"":  { ""name"": ""OmniRoute - Standard Coding"" }," & vbCrLf
ps = ps & "        ""free-coding-fast"":      { ""name"": ""OmniRoute - Fast Coding"" }," & vbCrLf
ps = ps & "        ""free-context"":          { ""name"": ""OmniRoute - Large Context"" }," & vbCrLf
ps = ps & "        ""free-vision"":           { ""name"": ""OmniRoute - Vision"" }" & vbCrLf
ps = ps & "      }" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "  }" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "'@" & vbCrLf
ps = ps & "" & vbCrLf

' --- Fallback template for ecc (used when repo files are absent).
ps = ps & "$profileEccFallback = @'" & vbCrLf
ps = ps & "{" & vbCrLf
ps = ps & "  ""$schema"": ""https://opencode.ai/config.json""," & vbCrLf
ps = ps & "  ""plugin"": [""ecc-universal""]," & vbCrLf
ps = ps & "  ""provider"": {" & vbCrLf
ps = ps & "    ""omniroute"": {" & vbCrLf
ps = ps & "      ""name"": ""OmniRoute""," & vbCrLf
ps = ps & "      ""npm"": ""@ai-sdk/openai-compatible""," & vbCrLf
ps = ps & "      ""options"": {" & vbCrLf
ps = ps & "        ""baseURL"": ""http://127.0.0.1:20128/v1""," & vbCrLf
ps = ps & "        ""apiKey"": ""{env:OMNIROUTE_API_KEY}""" & vbCrLf
ps = ps & "      }," & vbCrLf
ps = ps & "      ""models"": {" & vbCrLf
ps = ps & "        ""free-reasoning"":        { ""name"": ""OmniRoute - Reasoning"" }," & vbCrLf
ps = ps & "        ""free-coding-deep"":      { ""name"": ""OmniRoute - Deep Coding"" }," & vbCrLf
ps = ps & "        ""free-coding-standard"":  { ""name"": ""OmniRoute - Standard Coding"" }," & vbCrLf
ps = ps & "        ""free-coding-fast"":      { ""name"": ""OmniRoute - Fast Coding"" }," & vbCrLf
ps = ps & "        ""free-context"":          { ""name"": ""OmniRoute - Large Context"" }," & vbCrLf
ps = ps & "        ""free-vision"":           { ""name"": ""OmniRoute - Vision"" }" & vbCrLf
ps = ps & "      }" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "  }" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "'@" & vbCrLf
ps = ps & "" & vbCrLf

' --- Well-known path to the repo on this machine.
ps = ps & "$repoRoot = '/mnt/d/Github/My-Agents'" & vbCrLf
ps = ps & "$repoMyAgentsTemplate = $repoRoot + '/opencode.my-agents.jsonc'" & vbCrLf
ps = ps & "$repoEccTemplate = $repoRoot + '/opencode.ecc.jsonc'" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Get-ProfileTemplateBody {" & vbCrLf
ps = ps & "    param([string]$ProfileName)" & vbCrLf
ps = ps & "    $repoFile = if ($ProfileName -eq 'my-agents') { $repoMyAgentsTemplate } else { $repoEccTemplate }" & vbCrLf
ps = ps & "    $fallback = if ($ProfileName -eq 'my-agents') { $profileMyAgentsFallback } else { $profileEccFallback }" & vbCrLf
ps = ps & "    $exists = & wsl.exe -d $WSLDistro -- test -f $repoFile 2>$null" & vbCrLf
ps = ps & "    if ($LASTEXITCODE -eq 0) {" & vbCrLf
ps = ps & "        $body = & wsl.exe -d $WSLDistro -- cat $repoFile 2>$null" & vbCrLf
ps = ps & "        if ($null -ne $body -and $body.Length -gt 0) {" & vbCrLf
ps = ps & "            Write-TrayLog ('deployed ' + $ProfileName + ' from repo (' + $repoFile + ')')" & vbCrLf
ps = ps & "            return ($body | Out-String)" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    Write-TrayLog ('deployed ' + $ProfileName + ' from embedded fallback (repo file missing or unreadable)')" & vbCrLf
ps = ps & "    return $fallback" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Deploy-ProfileTemplates {" & vbCrLf
ps = ps & "    $root = Get-WslConfigRoot" & vbCrLf
ps = ps & "    if ([string]::IsNullOrEmpty($root)) {" & vbCrLf
ps = ps & "        Show-TrayError 'Config root' 'Could not resolve the OpenCode config root inside WSL.'" & vbCrLf
ps = ps & "        return $null" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    Write-TrayLog ('deploying profile templates to ' + $root)" & vbCrLf
ps = ps & "    foreach ($p in @('my-agents','ecc')) {" & vbCrLf
ps = ps & "        $dest = $root + '/profile.' + $p + '.jsonc'" & vbCrLf
ps = ps & "        $body = Get-ProfileTemplateBody $p" & vbCrLf
ps = ps & "        if ($null -eq $body -or $body.Length -lt 5) {" & vbCrLf
ps = ps & "            Show-TrayError 'Templates missing' ('The ' + $p + ' profile template is empty. Re-install the latest start-omniroute.vbs.')" & vbCrLf
ps = ps & "            return $null" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "        Write-TrayLog ('writing template to ' + $dest)" & vbCrLf
ps = ps & "        $null = & wsl.exe -d $WSLDistro -- mkdir -p $root 2>&1" & vbCrLf
ps = ps & "        if ($LASTEXITCODE -ne 0) {" & vbCrLf
ps = ps & "            Show-TrayError 'Template directory failed' ('Could not create ' + $root + ' inside WSL.')" & vbCrLf
ps = ps & "            return $null" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "        $tmp = [IO.Path]::GetTempFileName()" & vbCrLf
ps = ps & "        [IO.File]::WriteAllText($tmp, $body, (New-Object System.Text.UTF8Encoding($false)))" & vbCrLf
ps = ps & "        $wslTmp = Convert-ToWslPath $tmp" & vbCrLf
ps = ps & "        Write-TrayLog ('temporary template = ' + $tmp)" & vbCrLf
ps = ps & "        Write-TrayLog ('WSL temporary template = ' + $wslTmp)" & vbCrLf
ps = ps & "        Write-TrayLog ('temporary template exists = ' + (Test-Path $tmp))" & vbCrLf
ps = ps & "        if ([string]::IsNullOrWhiteSpace($wslTmp)) { Remove-Item $tmp -ErrorAction SilentlyContinue; Show-TrayError 'Template path failed' 'Could not convert the temporary Windows template path to a WSL path.'; return $null }" & vbCrLf
ps = ps & "        $writeOutput = (& wsl.exe -d $WSLDistro -- cp -- $wslTmp $dest 2>&1 | Out-String).Trim()" & vbCrLf
ps = ps & "        $writeExit = $LASTEXITCODE" & vbCrLf
ps = ps & "        Remove-Item $tmp -ErrorAction SilentlyContinue" & vbCrLf
ps = ps & "        Write-TrayLog ('template copy command = cp ' + $wslTmp + ' ' + $dest)" & vbCrLf
ps = ps & "        if ($writeOutput) { Write-TrayLog ('template write output: ' + (($writeOutput | Out-String).Trim())) }" & vbCrLf
ps = ps & "        Write-TrayLog ('template write exit = ' + $writeExit)" & vbCrLf
ps = ps & "        if ($writeExit -ne 0) {" & vbCrLf
ps = ps & "            Show-TrayError 'Template write failed' ('Failed to write ' + $dest + ' inside WSL.')" & vbCrLf
ps = ps & "            return $null" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    return $root" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Test-WslDistroReady {" & vbCrLf
ps = ps & "    $null = & wsl.exe -d $WSLDistro -- true 2>$null" & vbCrLf
ps = ps & "    if ($LASTEXITCODE -ne 0) {" & vbCrLf
ps = ps & "        Write-TrayLog ('WSL distro ' + $WSLDistro + ' not ready')" & vbCrLf
ps = ps & "        return $false" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    return $true" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Test-EccInstallReady {" & vbCrLf
ps = ps & "    $lsOut = Invoke-WslBash 'npm ls -g ecc-universal --depth=0 2>&1'" & vbCrLf
ps = ps & "    if ($LASTEXITCODE -ne 0) { return $false }" & vbCrLf
ps = ps & "    $globalRoot = Invoke-WslBash 'npm root -g'" & vbCrLf
ps = ps & "    if ([string]::IsNullOrEmpty($globalRoot)) { return $false }" & vbCrLf
ps = ps & "    $distFile = $globalRoot + '/ecc-universal/dist/index.js'" & vbCrLf
ps = ps & "    $null = Invoke-WslBash ('test -f ""' + $distFile + '""')" & vbCrLf
ps = ps & "    return ($LASTEXITCODE -eq 0)" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Install-EccPackage {" & vbCrLf
ps = ps & "    Write-TrayLog 'installing ecc-universal globally'" & vbCrLf
ps = ps & "    $out = Invoke-WslBash 'npm install -g ecc-universal 2>&1'" & vbCrLf
ps = ps & "    if ($LASTEXITCODE -ne 0) {" & vbCrLf
ps = ps & "        Write-TrayLog ('npm install -g ecc-universal FAILED: ' + $out)" & vbCrLf
ps = ps & "        Show-TrayError 'npm install failed' ('Failed to install ecc-universal inside WSL.' + [Environment]::NewLine + $out)" & vbCrLf
ps = ps & "        return $false" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    Write-TrayLog 'ecc-universal installed'" & vbCrLf
ps = ps & "    return $true" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Build-EccPlugin {" & vbCrLf
ps = ps & "    Write-TrayLog 'building ecc-universal dist'" & vbCrLf
ps = ps & "    $globalRoot = Invoke-WslBash 'npm root -g'" & vbCrLf
ps = ps & "    $eccDir = '""' + $globalRoot + '/ecc-universal""'" & vbCrLf
ps = ps & "    $out = Invoke-WslBash ('cd ' + $eccDir + ' && npm run build 2>&1')" & vbCrLf
ps = ps & "    if ($LASTEXITCODE -ne 0) {" & vbCrLf
ps = ps & "        Write-TrayLog ('npm run build for ecc-universal FAILED: ' + $out)" & vbCrLf
ps = ps & "        Show-TrayError 'Build failed' ('ecc-universal build failed inside WSL.' + [Environment]::NewLine + $out)" & vbCrLf
ps = ps & "        return $false" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    Write-TrayLog 'ecc-universal build complete'" & vbCrLf
ps = ps & "    return $true" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Wait-OpenCodeActive {" & vbCrLf
ps = ps & "    param([int]$TimeoutSeconds = 30)" & vbCrLf
ps = ps & "    for ($i = 0; $i -lt ($TimeoutSeconds * 2); $i++) {" & vbCrLf
ps = ps & "        $state = Get-WslServiceState 'opencode'" & vbCrLf
ps = ps & "        if ($state -eq 'active') { return $true }" & vbCrLf
ps = ps & "        if ($state -eq 'failed') { return $false }" & vbCrLf
ps = ps & "        Start-Sleep -Milliseconds 500" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    return $false" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf


ps = ps & "function Read-JsonFile {" & vbCrLf
ps = ps & "    param([string]$Path)" & vbCrLf
ps = ps & "    $b64 = & wsl.exe -d $WSLDistro -- base64 -w0 -- $Path 2>$null" & vbCrLf
ps = ps & "    if ($null -eq $b64) { return $null }" & vbCrLf
ps = ps & "    $b64 = ($b64 | Out-String).Trim()" & vbCrLf
ps = ps & "    if ($b64.Length -eq 0) { return $null }" & vbCrLf
ps = ps & "    try {" & vbCrLf
ps = ps & "        $raw = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))" & vbCrLf
ps = ps & "        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }" & vbCrLf
ps = ps & "        return ($raw | ConvertFrom-Json)" & vbCrLf
ps = ps & "    } catch {" & vbCrLf
ps = ps & "        Write-TrayLog ('read-Json failed for ' + $Path + ': ' + $_.Exception.Message)" & vbCrLf
ps = ps & "        return $null" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function PluginEntryToComparableString {" & vbCrLf
ps = ps & "    param($Entry)" & vbCrLf
ps = ps & "    if ($null -eq $Entry) { return '' }" & vbCrLf
ps = ps & "    if ($Entry -is [string]) { return 'S|' + $Entry }" & vbCrLf
ps = ps & "    if ($Entry -is [array]) {" & vbCrLf
ps = ps & "        $parts = @()" & vbCrLf
ps = ps & "        foreach ($e in $Entry) { $parts += (PluginEntryToComparableString $e) }" & vbCrLf
ps = ps & "        return 'A|' + ($parts -join '||')" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    if ($Entry -is [PSCustomObject]) {" & vbCrLf
ps = ps & "        $keys = @($Entry.PSObject.Properties | ForEach-Object { $_.Name } | Sort-Object)" & vbCrLf
ps = ps & "        $parts = @()" & vbCrLf
ps = ps & "        foreach ($k in $keys) {" & vbCrLf
ps = ps & "            $v = $Entry.$k" & vbCrLf
ps = ps & "            $parts += ($k + '=' + (PluginEntryToComparableString $v))" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "        return 'O|' + ($parts -join ';')" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    return 'V|' + [string]$Entry" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Get-PluginEntryKey {" & vbCrLf
ps = ps & "    param($Entry)" & vbCrLf
ps = ps & "    if ($null -eq $Entry) { return '' }" & vbCrLf
ps = ps & "    if ($Entry -is [string]) { return $Entry }" & vbCrLf
ps = ps & "    if ($Entry -is [array] -and $Entry.Count -ge 1) { return [string]$Entry[0] }" & vbCrLf
ps = ps & "    return $null" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Split-PluginBlock {" & vbCrLf
ps = ps & "    param($Live, $TemplateBase)" & vbCrLf
ps = ps & "    $liveList = if ($null -eq $Live) { @() } elseif ($Live -is [array]) { $Live } else { @($Live) }" & vbCrLf
ps = ps & "    $tmplList = if ($null -eq $TemplateBase) { @() } elseif ($TemplateBase -is [array]) { $TemplateBase } else { @($TemplateBase) }" & vbCrLf
ps = ps & "    $tmplKeys = @()" & vbCrLf
ps = ps & "    foreach ($t in $tmplList) { $k = Get-PluginEntryKey $t; if ($null -ne $k) { $tmplKeys += $k } }" & vbCrLf
ps = ps & "    $matched = New-Object System.Collections.ArrayList" & vbCrLf
ps = ps & "    $extras  = New-Object System.Collections.ArrayList" & vbCrLf
ps = ps & "    foreach ($e in $liveList) {" & vbCrLf
ps = ps & "        $k = Get-PluginEntryKey $e" & vbCrLf
ps = ps & "        if ($null -eq $k) { [void]$extras.Add($e); continue }" & vbCrLf
ps = ps & "        if ($tmplKeys -contains $k) { [void]$matched.Add($e) } else { [void]$extras.Add($e) }" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    return ,@($matched.ToArray(), $extras.ToArray())" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function PluginBlockEqual {" & vbCrLf
ps = ps & "    param($A, $B)" & vbCrLf
ps = ps & "    $aList = if ($null -eq $A) { @() } elseif ($A -is [array]) { $A } else { @($A) }" & vbCrLf
ps = ps & "    $bList = if ($null -eq $B) { @() } elseif ($B -is [array]) { $B } else { @($B) }" & vbCrLf
ps = ps & "    if ($aList.Count -ne $bList.Count) { return $false }" & vbCrLf
ps = ps & "    $bKeys = @()" & vbCrLf
ps = ps & "    foreach ($x in $bList) { $k = Get-PluginEntryKey $x; if ($null -ne $k) { $bKeys += $k } }" & vbCrLf
ps = ps & "    foreach ($x in $aList) {" & vbCrLf
ps = ps & "        $k = Get-PluginEntryKey $x" & vbCrLf
ps = ps & "        if ($null -eq $k -or -not ($bKeys -contains $k)) { return $false }" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    return $true" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Merge-ProviderBlock {" & vbCrLf
ps = ps & "    param($TemplateProviders, $LiveProviders)" & vbCrLf
ps = ps & "    $merged = [ordered]@{}" & vbCrLf
ps = ps & "    if ($null -ne $TemplateProviders) {" & vbCrLf
ps = ps & "        foreach ($p in $TemplateProviders.PSObject.Properties) { $merged[$p.Name] = $p.Value }" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    if ($null -ne $LiveProviders) {" & vbCrLf
ps = ps & "        foreach ($p in $LiveProviders.PSObject.Properties) {" & vbCrLf
ps = ps & "            if (-not $merged.Contains($p.Name)) { $merged[$p.Name] = $p.Value }" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    return $merged" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Write-MergedConfig {" & vbCrLf
ps = ps & "    param([string]$Path, [hashtable]$Config)" & vbCrLf
ps = ps & "    $ordered = [ordered]@{}" & vbCrLf
ps = ps & "    foreach ($k in $Config.Keys) { $ordered[$k] = $Config[$k] }" & vbCrLf
ps = ps & "    $json = $ordered | ConvertTo-Json -Depth 20" & vbCrLf
ps = ps & "    if ($null -eq $json) { $json = '' }" & vbCrLf
ps = ps & "    $tmp = [IO.Path]::GetTempFileName()" & vbCrLf
ps = ps & "    try {" & vbCrLf
ps = ps & "        [IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))" & vbCrLf
ps = ps & "        $wslTmp = Convert-ToWslPath $tmp" & vbCrLf
ps = ps & "        if ([string]::IsNullOrWhiteSpace($wslTmp)) {" & vbCrLf
ps = ps & "            Remove-Item $tmp -ErrorAction SilentlyContinue" & vbCrLf
ps = ps & "            Write-TrayLog ('write-merged failed: could not convert temp path for ' + $Path)" & vbCrLf
ps = ps & "            return $false" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "        $null = & wsl.exe -d $WSLDistro -- mkdir -p ($(Split-Path -Parent $Path)) 2>&1" & vbCrLf
ps = ps & "        $cpOut = (& wsl.exe -d $WSLDistro -- cp -- $wslTmp $Path 2>&1 | Out-String).Trim()" & vbCrLf
ps = ps & "        $cpExit = $LASTEXITCODE" & vbCrLf
ps = ps & "        Remove-Item $tmp -ErrorAction SilentlyContinue" & vbCrLf
ps = ps & "        if ($cpExit -ne 0) {" & vbCrLf
ps = ps & "            Write-TrayLog ('write-merged failed for ' + $Path + ': ' + $cpOut)" & vbCrLf
ps = ps & "            return $false" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "        return $true" & vbCrLf
ps = ps & "    } catch {" & vbCrLf
ps = ps & "        Write-TrayLog ('write-merged failed for ' + $Path + ': ' + $_.Exception.Message)" & vbCrLf
ps = ps & "        if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }" & vbCrLf
ps = ps & "        return $false" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "function Switch-OpenCodeProfile {" & vbCrLf
ps = ps & "    param([string]$ProfileName)" & vbCrLf
ps = ps & "    if ($ProfileName -ne 'my-agents' -and $ProfileName -ne 'ecc') {" & vbCrLf
ps = ps & "        Show-TrayError 'Invalid profile' ('Unknown profile: ' + $ProfileName)" & vbCrLf
ps = ps & "        return" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    if (-not (Test-WslDistroReady)) {" & vbCrLf
ps = ps & "        Show-TrayError 'WSL not ready' ('WSL distro ' + $WSLDistro + ' is not running. Start it first.')" & vbCrLf
ps = ps & "        return" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    $currentState = Get-WslServiceState 'opencode'" & vbCrLf
ps = ps & "    if ($currentState -eq 'activating' -or $currentState -eq 'deactivating') {" & vbCrLf
ps = ps & "        Write-TrayLog ('switch ignored: opencode.service is ' + $currentState)" & vbCrLf
ps = ps & "        return" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    $root = Deploy-ProfileTemplates" & vbCrLf
ps = ps & "    if ($null -eq $root) { return }" & vbCrLf
ps = ps & "    $livePath   = $root + '/opencode.jsonc'" & vbCrLf
ps = ps & "    $tmplPath   = $root + '/profile.' + $ProfileName + '.jsonc'" & vbCrLf
ps = ps & "    $backupPath = $root + '/opencode.jsonc.bak'" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    $live = Read-JsonFile $livePath" & vbCrLf
ps = ps & "    $tmpl = Read-JsonFile $tmplPath" & vbCrLf
ps = ps & "    if ($null -eq $tmpl) {" & vbCrLf
ps = ps & "        Show-TrayError 'Template unreadable' ('Could not read ' + $tmplPath + '. Re-deploy templates from the Profile submenu.')" & vbCrLf
ps = ps & "        return" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    $livePlugin  = if ($null -ne $live) { $live.plugin }  else { $null }" & vbCrLf
ps = ps & "    $tmplPlugin  = $tmpl.plugin" & vbCrLf
ps = ps & "    $split = Split-PluginBlock $livePlugin $tmplPlugin" & vbCrLf
ps = ps & "    $matched = $split[0]" & vbCrLf
ps = ps & "    $extras  = $split[1]" & vbCrLf
ps = ps & "    $extrasCount = $extras.Count" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    if ($extrasCount -eq 0 -and (PluginBlockEqual $matched $tmplPlugin)) {" & vbCrLf
ps = ps & "        Write-TrayLog ('profile ' + $ProfileName + ' already active, no action')" & vbCrLf
ps = ps & "        return" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    # Recovery: re-attach orphan externalSkills object to a my-agents entry" & vbCrLf
ps = ps & "    $recoveredExtras = New-Object System.Collections.ArrayList" & vbCrLf
ps = ps & "    foreach ($e in $extras) {" & vbCrLf
ps = ps & "        $k = Get-PluginEntryKey $e" & vbCrLf
ps = ps & "        if ($null -eq $k -and $e -is [PSCustomObject] -and $e.PSObject.Properties.Name -contains 'externalSkills') {" & vbCrLf
ps = ps & "            Write-TrayLog ('recovery: re-attaching orphan externalSkills to my-agents')" & vbCrLf
ps = ps & "            foreach ($src in @($matched) + @($extras)) {" & vbCrLf
ps = ps & "                $sk = Get-PluginEntryKey $src" & vbCrLf
ps = ps & "                if ($null -ne $sk -and $sk -like 'my-agents@*') {" & vbCrLf
ps = ps & "                    if ($src -is [array] -and $src.Count -ge 2) {" & vbCrLf
ps = ps & "                        $opts = $src[1]" & vbCrLf
ps = ps & "                        if ($opts -is [PSCustomObject]) { $opts | Add-Member -NotePropertyName externalSkills -NotePropertyValue $e.externalSkills -Force; $src[1] = $opts }" & vbCrLf
ps = ps & "                    }" & vbCrLf
ps = ps & "                    break" & vbCrLf
ps = ps & "                }" & vbCrLf
ps = ps & "            }" & vbCrLf
ps = ps & "        } else {" & vbCrLf
ps = ps & "            [void]$recoveredExtras.Add($e)" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    $extras = $recoveredExtras.ToArray()" & vbCrLf
ps = ps & "    $extrasCount = $extras.Count" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    if ($ProfileName -eq 'ecc') {" & vbCrLf
ps = ps & "        Write-TrayLog 'checking ecc-universal install inside WSL'" & vbCrLf
ps = ps & "        if (-not (Test-EccInstallReady)) {" & vbCrLf
ps = ps & "            if (-not (Install-EccPackage)) { return }" & vbCrLf
ps = ps & "            if (-not (Test-EccInstallReady)) {" & vbCrLf
ps = ps & "                if (-not (Build-EccPlugin)) { return }" & vbCrLf
ps = ps & "            }" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    Write-TrayLog ('activating ' + $ProfileName + ' (keeping ' + $extrasCount + ' user plugin(s))')" & vbCrLf
ps = ps & "    $mergedConfig = [ordered]@{}" & vbCrLf
ps = ps & "    if ($null -ne $live) {" & vbCrLf
ps = ps & "        foreach ($p in $live.PSObject.Properties) { $mergedConfig[$p.Name] = $p.Value }" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    foreach ($p in $tmpl.PSObject.Properties) { $mergedConfig[$p.Name] = $p.Value }" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    $mergedPlugin = New-Object System.Collections.ArrayList" & vbCrLf
ps = ps & "    $seenPluginKeys = @()" & vbCrLf
ps = ps & "    foreach ($e in $extras) {" & vbCrLf
ps = ps & "        $k = Get-PluginEntryKey $e" & vbCrLf
ps = ps & "        if ($null -ne $k) { $seenPluginKeys += $k; [void]$mergedPlugin.Add($e) }" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    if ($null -ne $tmplPlugin) {" & vbCrLf
ps = ps & "        if ($tmplPlugin -is [array]) { $tmplLoop = $tmplPlugin } else { $tmplLoop = @($tmplPlugin) }" & vbCrLf
ps = ps & "        foreach ($e in $tmplLoop) {" & vbCrLf
ps = ps & "            $k = Get-PluginEntryKey $e" & vbCrLf
ps = ps & "            if ($null -ne $k -and $seenPluginKeys -notcontains $k) { $seenPluginKeys += $k; [void]$mergedPlugin.Add($e) }" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    $mergedConfig['plugin'] = $mergedPlugin" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    $liveProviders   = if ($null -ne $live)  { $live.provider }   else { $null }" & vbCrLf
ps = ps & "    $tmplProviders   = $tmpl.provider" & vbCrLf
ps = ps & "    $mergedProviders = Merge-ProviderBlock $tmplProviders $liveProviders" & vbCrLf
ps = ps & "    $mergedConfig['provider'] = $mergedProviders" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    $backupOut = (& wsl.exe -d $WSLDistro -- cp -- $livePath $backupPath 2>&1 | Out-String).Trim()" & vbCrLf
ps = ps & "    if ($LASTEXITCODE -ne 0) { Write-TrayLog ('backup warn: ' + $backupOut) }" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    if (-not (Write-MergedConfig $livePath $mergedConfig)) {" & vbCrLf
ps = ps & "        Show-TrayError 'Write failed' ('Could not write ' + $livePath + '. Check WSL disk and tray.log.')" & vbCrLf
ps = ps & "        return" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    if ($extrasCount -gt 0) {" & vbCrLf
ps = ps & "        $names = @()" & vbCrLf
ps = ps & "        foreach ($e in $extras) {" & vbCrLf
ps = ps & "            if ($e -is [string]) { $names += $e }" & vbCrLf
ps = ps & "            elseif ($e -is [array] -and $e.Count -gt 0) { $names += [string]$e[0] }" & vbCrLf
ps = ps & "            elseif ($e -is [PSCustomObject] -and $e.PSObject.Properties.Name -contains 'name') { $names += [string]$e.name }" & vbCrLf
ps = ps & "            else { $names += '<entry>' }" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "        Write-TrayLog ('merge: kept ' + $extrasCount + ' user plugin(s): ' + ($names -join ', '))" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    Write-TrayLog ('cp profile.' + $ProfileName + '.jsonc + extras -> opencode.jsonc')" & vbCrLf
ps = ps & "    Write-TrayLog 'systemctl restart opencode'" & vbCrLf
ps = ps & "    Invoke-WslSystemctl @('restart','opencode')" & vbCrLf
ps = ps & "    $ok = Wait-OpenCodeActive -TimeoutSeconds 30" & vbCrLf
ps = ps & "    if ($ok) {" & vbCrLf
ps = ps & "        Write-TrayLog 'opencode.service -> active'" & vbCrLf
ps = ps & "        Write-TrayLog 'profile switch complete'" & vbCrLf
ps = ps & "    } else {" & vbCrLf
ps = ps & "        $state = Get-WslServiceState 'opencode'" & vbCrLf
ps = ps & "        if ($state -eq 'failed') {" & vbCrLf
ps = ps & "            Write-TrayLog 'opencode.service -> failed'" & vbCrLf
ps = ps & "            Show-TrayError 'OpenCode failed' 'opencode.service did not start. Check OMNIROUTE_API_KEY and journalctl -u opencode inside WSL.'" & vbCrLf
ps = ps & "        } else {" & vbCrLf
ps = ps & "            Write-TrayLog 'opencode.service restart timed out after 30s'" & vbCrLf
ps = ps & "            Show-TrayError 'Timeout' 'opencode.service did not become active within 30 seconds. Check journalctl -u opencode inside WSL.'" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf


' Rotate any oversized log from a previous run on startup.
ps = ps & "Debug-Trace 'Reached tray initialization'" & vbCrLf
ps = ps & "Rotate-TrayLog" & vbCrLf
ps = ps & "Write-TrayLog ('[my-agents] tray launched')" & vbCrLf
ps = ps & "" & vbCrLf

' ============================================================
' TRAY ICON
' ============================================================

ps = ps & "$notifyIcon = New-Object System.Windows.Forms.NotifyIcon" & vbCrLf

' Use OmniRoute icon.

ps = ps & "$iconPath = [IO.Path]::Combine($env:USERPROFILE,'omniroute.ico')" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "if (Test-Path $iconPath) {" & vbCrLf
ps = ps & "    $notifyIcon.Icon = New-Object System.Drawing.Icon($iconPath)" & vbCrLf
ps = ps & "} else {" & vbCrLf
ps = ps & "    $notifyIcon.Icon = [System.Drawing.SystemIcons]::Application" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "$notifyIcon.Text = 'OpenCode + OmniRoute + DeepSeek Harness'" & vbCrLf
ps = ps & "$notifyIcon.Visible = $true" & vbCrLf
ps = ps & "Debug-Trace 'NotifyIcon.Visible = true'" & vbCrLf
ps = ps & "" & vbCrLf

' ============================================================
' START SERVICES ENABLED FOR THIS SCRIPT INSTANCE
' ============================================================

ps = ps & "Debug-Trace 'Starting enabled services'" & vbCrLf
ps = ps & "Start-EnabledServices" & vbCrLf
ps = ps & "" & vbCrLf

' ============================================================
' STARTUP MENU ITEM HELPER
'
' IMPORTANT:
'
' There is NO submenu here.
'
' Each service gets exactly ONE item:
'
'     Startup [check]
'
' when enabled, or:
'
'     Startup
'
' when disabled.
'
' Clicking the item toggles:
'
'     systemctl enable SERVICE
'
' or:
'
'     systemctl disable SERVICE
'
' The text always remains "Startup".
' ============================================================

ps = ps & "function New-StartupItem {" & vbCrLf
ps = ps & "    param([string]$Service)" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    $startupItem = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "    $startupItem.Text = 'Startup'" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    # Update the checkmark from the actual systemd state." & vbCrLf
ps = ps & "    $updateStartupItem = {" & vbCrLf
ps = ps & "        try {" & vbCrLf
ps = ps & "            $startupItem.Checked = Get-WslServiceEnabled $Service" & vbCrLf
ps = ps & "        } catch {" & vbCrLf
ps = ps & "            $startupItem.Checked = $false" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "    }.GetNewClosure()" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    $startupItem.Add_Click({" & vbCrLf
ps = ps & "        try {" & vbCrLf
ps = ps & "            $currentlyEnabled = Get-WslServiceEnabled $Service" & vbCrLf
ps = ps & "" & vbCrLf
ps = ps & "            if ($currentlyEnabled) {" & vbCrLf
ps = ps & "                Invoke-WslSystemctl @('disable',$Service)" & vbCrLf
ps = ps & "            } else {" & vbCrLf
ps = ps & "                Invoke-WslSystemctl @('enable',$Service)" & vbCrLf
ps = ps & "            }" & vbCrLf
ps = ps & "" & vbCrLf
ps = ps & "            & $updateStartupItem" & vbCrLf
ps = ps & "        } catch {" & vbCrLf
ps = ps & "            & $updateStartupItem" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "    }.GetNewClosure())" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    & $updateStartupItem" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    return $startupItem" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

' ============================================================
' CONTEXT MENU
'
' OpenCode
'   Open
'   Start
'   Restart
'   Stop
'   Startup [check]
'
' OmniRoute
'   Open
'   Start
'   Restart
'   Stop
'   Startup [check]
'
' DeepSeek Harness
'   Open
'   Start
'   Restart
'   Stop
'   Startup [check]
'
' Exit
'
' No global Start / Restart / Stop.
' ============================================================

ps = ps & "$menu = New-Object System.Windows.Forms.ContextMenuStrip" & vbCrLf
ps = ps & "" & vbCrLf

' ============================================================
' OPENCODE
' ============================================================

ps = ps & "$openCodeMenu = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$openCodeMenu.Text = 'OpenCode'" & vbCrLf
ps = ps & "" & vbCrLf

' OpenCode -> Open

ps = ps & "$openCodeOpen = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$openCodeOpen.Text = 'Open'" & vbCrLf
ps = ps & "$openCodeOpen.Add_Click({" & vbCrLf
ps = ps & "    Start-Process 'http://localhost:4096'" & vbCrLf
ps = ps & "})" & vbCrLf
ps = ps & "" & vbCrLf

' OpenCode -> Start

ps = ps & "$openCodeStart = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$openCodeStart.Text = 'Start'" & vbCrLf
ps = ps & "$openCodeStart.Add_Click({" & vbCrLf
ps = ps & "    Ensure-OmniRoute" & vbCrLf
ps = ps & "    Invoke-WslSystemctl @('start','opencode')" & vbCrLf
ps = ps & "})" & vbCrLf
ps = ps & "" & vbCrLf

' OpenCode -> Restart

ps = ps & "$openCodeRestart = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$openCodeRestart.Text = 'Restart'" & vbCrLf
ps = ps & "$openCodeRestart.Add_Click({" & vbCrLf
ps = ps & "    # Restart OpenCode only." & vbCrLf
ps = ps & "    Invoke-WslSystemctl @('restart','opencode')" & vbCrLf
ps = ps & "})" & vbCrLf
ps = ps & "" & vbCrLf

' OpenCode -> Stop

ps = ps & "$openCodeStop = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$openCodeStop.Text = 'Stop'" & vbCrLf
ps = ps & "$openCodeStop.Add_Click({" & vbCrLf
ps = ps & "    Invoke-WslSystemctl @('stop','opencode')" & vbCrLf
ps = ps & "})" & vbCrLf
ps = ps & "" & vbCrLf

' OpenCode -> Startup

ps = ps & "$openCodeStartup = New-StartupItem 'opencode'" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "[void]$openCodeMenu.DropDownItems.Add($openCodeOpen)" & vbCrLf
ps = ps & "[void]$openCodeMenu.DropDownItems.Add($openCodeStart)" & vbCrLf
ps = ps & "[void]$openCodeMenu.DropDownItems.Add($openCodeRestart)" & vbCrLf
ps = ps & "[void]$openCodeMenu.DropDownItems.Add($openCodeStop)" & vbCrLf

' OpenCode -> Profile (submenu for switching agent profiles)

ps = ps & "$openCodeProfileMenu = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$openCodeProfileMenu.Text = 'Profile'" & vbCrLf

ps = ps & "$openCodeProfileMyAgents = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$openCodeProfileMyAgents.Text = 'My-Agents'" & vbCrLf
ps = ps & "$openCodeProfileMyAgents.Add_Click({" & vbCrLf
ps = ps & "    Switch-OpenCodeProfile 'my-agents'" & vbCrLf
ps = ps & "})" & vbCrLf

ps = ps & "$openCodeProfileEcc = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$openCodeProfileEcc.Text = 'ECC'" & vbCrLf
ps = ps & "$openCodeProfileEcc.Add_Click({" & vbCrLf
ps = ps & "    Switch-OpenCodeProfile 'ecc'" & vbCrLf
ps = ps & "})" & vbCrLf

ps = ps & "$openCodeProfileRedeploy = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$openCodeProfileRedeploy.Text = 'Re-deploy templates'" & vbCrLf
ps = ps & "$openCodeProfileRedeploy.Add_Click({" & vbCrLf
ps = ps & "    $null = Deploy-ProfileTemplates" & vbCrLf
ps = ps & "})" & vbCrLf

ps = ps & "[void]$openCodeProfileMenu.DropDownItems.Add($openCodeProfileMyAgents)" & vbCrLf
ps = ps & "[void]$openCodeProfileMenu.DropDownItems.Add($openCodeProfileEcc)" & vbCrLf
ps = ps & "$openCodeProfileRedeploySep = New-Object System.Windows.Forms.ToolStripSeparator" & vbCrLf
ps = ps & "[void]$openCodeProfileMenu.DropDownItems.Add($openCodeProfileRedeploySep)" & vbCrLf
ps = ps & "[void]$openCodeProfileMenu.DropDownItems.Add($openCodeProfileRedeploy)" & vbCrLf

ps = ps & "$openCodeProfileSep = New-Object System.Windows.Forms.ToolStripSeparator" & vbCrLf
ps = ps & "[void]$openCodeMenu.DropDownItems.Add($openCodeProfileSep)" & vbCrLf
ps = ps & "[void]$openCodeMenu.DropDownItems.Add($openCodeProfileMenu)" & vbCrLf

ps = ps & "[void]$openCodeMenu.DropDownItems.Add($openCodeStartup)" & vbCrLf
ps = ps & "" & vbCrLf

' ============================================================
' OMNIROUTE
' ============================================================

ps = ps & "$omniRouteMenu = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$omniRouteMenu.Text = 'OmniRoute'" & vbCrLf
ps = ps & "" & vbCrLf

' OmniRoute -> Open

ps = ps & "$omniRouteOpen = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$omniRouteOpen.Text = 'Open'" & vbCrLf
ps = ps & "$omniRouteOpen.Add_Click({" & vbCrLf
ps = ps & "    Start-Process 'http://localhost:20128'" & vbCrLf
ps = ps & "})" & vbCrLf
ps = ps & "" & vbCrLf

' OmniRoute -> Start

ps = ps & "$omniRouteStart = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$omniRouteStart.Text = 'Start'" & vbCrLf
ps = ps & "$omniRouteStart.Add_Click({" & vbCrLf
ps = ps & "    Invoke-WslSystemctl @('start','omniroute')" & vbCrLf
ps = ps & "})" & vbCrLf
ps = ps & "" & vbCrLf

' OmniRoute -> Restart

ps = ps & "$omniRouteRestart = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$omniRouteRestart.Text = 'Restart'" & vbCrLf
ps = ps & "$omniRouteRestart.Add_Click({" & vbCrLf
ps = ps & "    Invoke-WslSystemctl @('restart','omniroute')" & vbCrLf
ps = ps & "})" & vbCrLf
ps = ps & "" & vbCrLf

' OmniRoute -> Stop
'
' OmniRoute is shared by OpenCode and DSH.
'
' Stop order:
'
'     OpenCode
'     DSH
'     OmniRoute
'
' This guarantees that no agent is left running against a
' deliberately stopped backend.

ps = ps & "$omniRouteStop = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$omniRouteStop.Text = 'Stop'" & vbCrLf
ps = ps & "$omniRouteStop.Add_Click({" & vbCrLf
ps = ps & "    Invoke-WslSystemctl @('stop','opencode')" & vbCrLf
ps = ps & "    Invoke-WslSystemctl @('stop','dsh')" & vbCrLf
ps = ps & "    Invoke-WslSystemctl @('stop','omniroute')" & vbCrLf
ps = ps & "})" & vbCrLf
ps = ps & "" & vbCrLf

' OmniRoute -> Startup

ps = ps & "$omniRouteStartup = New-StartupItem 'omniroute'" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "[void]$omniRouteMenu.DropDownItems.Add($omniRouteOpen)" & vbCrLf
ps = ps & "[void]$omniRouteMenu.DropDownItems.Add($omniRouteStart)" & vbCrLf
ps = ps & "[void]$omniRouteMenu.DropDownItems.Add($omniRouteRestart)" & vbCrLf
ps = ps & "[void]$omniRouteMenu.DropDownItems.Add($omniRouteStop)" & vbCrLf
ps = ps & "[void]$omniRouteMenu.DropDownItems.Add($omniRouteStartup)" & vbCrLf
ps = ps & "" & vbCrLf

' ============================================================
' DEEPSEEK HARNESS
' ============================================================

ps = ps & "$dshMenu = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$dshMenu.Text = 'DeepSeek Harness'" & vbCrLf
ps = ps & "" & vbCrLf

' DSH -> Open

ps = ps & "$dshOpen = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$dshOpen.Text = 'Open'" & vbCrLf
ps = ps & "$dshOpen.Add_Click({" & vbCrLf
ps = ps & "    Start-Process 'http://localhost:3080'" & vbCrLf
ps = ps & "})" & vbCrLf
ps = ps & "" & vbCrLf

' DSH -> Start
'
' DSH shares OmniRoute.
' Ensure OmniRoute is available before starting DSH.

ps = ps & "$dshStart = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$dshStart.Text = 'Start'" & vbCrLf
ps = ps & "$dshStart.Add_Click({" & vbCrLf
ps = ps & "    Ensure-OmniRoute" & vbCrLf
ps = ps & "    Invoke-WslSystemctl @('start','dsh')" & vbCrLf
ps = ps & "})" & vbCrLf
ps = ps & "" & vbCrLf

' DSH -> Restart
'
' Restart DSH only.
' OmniRoute remains untouched.

ps = ps & "$dshRestart = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$dshRestart.Text = 'Restart'" & vbCrLf
ps = ps & "$dshRestart.Add_Click({" & vbCrLf
ps = ps & "    Invoke-WslSystemctl @('restart','dsh')" & vbCrLf
ps = ps & "})" & vbCrLf
ps = ps & "" & vbCrLf

' DSH -> Stop

ps = ps & "$dshStop = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$dshStop.Text = 'Stop'" & vbCrLf
ps = ps & "$dshStop.Add_Click({" & vbCrLf
ps = ps & "    Invoke-WslSystemctl @('stop','dsh')" & vbCrLf
ps = ps & "})" & vbCrLf
ps = ps & "" & vbCrLf

' DSH -> Startup

ps = ps & "$dshStartup = New-StartupItem 'dsh'" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "[void]$dshMenu.DropDownItems.Add($dshOpen)" & vbCrLf
ps = ps & "[void]$dshMenu.DropDownItems.Add($dshStart)" & vbCrLf
ps = ps & "[void]$dshMenu.DropDownItems.Add($dshRestart)" & vbCrLf
ps = ps & "[void]$dshMenu.DropDownItems.Add($dshStop)" & vbCrLf
ps = ps & "[void]$dshMenu.DropDownItems.Add($dshStartup)" & vbCrLf
ps = ps & "" & vbCrLf

' ============================================================
' EXIT
' ============================================================

ps = ps & "$separatorExit = New-Object System.Windows.Forms.ToolStripSeparator" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem" & vbCrLf
ps = ps & "$exitItem.Text = 'Exit'" & vbCrLf
ps = ps & "$exitItem.Add_Click({" & vbCrLf
ps = ps & "    $notifyIcon.Visible = $false" & vbCrLf
ps = ps & "    $notifyIcon.Dispose()" & vbCrLf
ps = ps & "" & vbCrLf
ps = ps & "" & vbCrLf
ps = ps & "    [System.Windows.Forms.Application]::Exit()" & vbCrLf
ps = ps & "})" & vbCrLf
ps = ps & "" & vbCrLf

' ============================================================
' BUILD TOP-LEVEL MENU
' ============================================================

ps = ps & "[void]$menu.Items.Add($openCodeMenu)" & vbCrLf
ps = ps & "[void]$menu.Items.Add($omniRouteMenu)" & vbCrLf
ps = ps & "[void]$menu.Items.Add($dshMenu)" & vbCrLf
ps = ps & "[void]$menu.Items.Add($separatorExit)" & vbCrLf
ps = ps & "[void]$menu.Items.Add($exitItem)" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "$notifyIcon.ContextMenuStrip = $menu" & vbCrLf
ps = ps & "" & vbCrLf

' ============================================================
' LIVE STATUS COLORS
'
' The actual top-level menu entry text changes color.
'
' Running:
'     Green
'
' Starting / stopping / unknown:
'     Orange
'
' Stopped / failed:
'     Red
'
' Status is refreshed every 2 seconds.
' ============================================================

ps = ps & "$statusTimer = New-Object System.Windows.Forms.Timer" & vbCrLf
ps = ps & "$statusTimer.Interval = 2000" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "$updateStatus = {" & vbCrLf
ps = ps & "    try {" & vbCrLf
ps = ps & "        $openCodeState = Get-WslServiceState 'opencode'" & vbCrLf
ps = ps & "        $omniRouteState = Get-WslServiceState 'omniroute'" & vbCrLf
ps = ps & "        $dshState = Get-WslServiceState 'dsh'" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "        # ------------------------------------------------" & vbCrLf
ps = ps & "        # OpenCode color" & vbCrLf
ps = ps & "        # ------------------------------------------------" & vbCrLf
ps = ps & "        switch ($openCodeState) {" & vbCrLf
ps = ps & "            'active' {" & vbCrLf
ps = ps & "                $openCodeMenu.ForeColor = [System.Drawing.Color]::ForestGreen" & vbCrLf
ps = ps & "            }" & vbCrLf
ps = ps & "            'activating' {" & vbCrLf
ps = ps & "                $openCodeMenu.ForeColor = [System.Drawing.Color]::DarkOrange" & vbCrLf
ps = ps & "            }" & vbCrLf
ps = ps & "            'deactivating' {" & vbCrLf
ps = ps & "                $openCodeMenu.ForeColor = [System.Drawing.Color]::DarkOrange" & vbCrLf
ps = ps & "            }" & vbCrLf
ps = ps & "            default {" & vbCrLf
ps = ps & "                $openCodeMenu.ForeColor = [System.Drawing.Color]::Firebrick" & vbCrLf
ps = ps & "            }" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "        # ------------------------------------------------" & vbCrLf
ps = ps & "        # OmniRoute color" & vbCrLf
ps = ps & "        # ------------------------------------------------" & vbCrLf
ps = ps & "        switch ($omniRouteState) {" & vbCrLf
ps = ps & "            'active' {" & vbCrLf
ps = ps & "                $omniRouteMenu.ForeColor = [System.Drawing.Color]::ForestGreen" & vbCrLf
ps = ps & "            }" & vbCrLf
ps = ps & "            'activating' {" & vbCrLf
ps = ps & "                $omniRouteMenu.ForeColor = [System.Drawing.Color]::DarkOrange" & vbCrLf
ps = ps & "            }" & vbCrLf
ps = ps & "            'deactivating' {" & vbCrLf
ps = ps & "                $omniRouteMenu.ForeColor = [System.Drawing.Color]::DarkOrange" & vbCrLf
ps = ps & "            }" & vbCrLf
ps = ps & "            default {" & vbCrLf
ps = ps & "                $omniRouteMenu.ForeColor = [System.Drawing.Color]::Firebrick" & vbCrLf
ps = ps & "            }" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "        # ------------------------------------------------" & vbCrLf
ps = ps & "        # DeepSeek Harness color" & vbCrLf
ps = ps & "        # ------------------------------------------------" & vbCrLf
ps = ps & "        switch ($dshState) {" & vbCrLf
ps = ps & "            'active' {" & vbCrLf
ps = ps & "                $dshMenu.ForeColor = [System.Drawing.Color]::ForestGreen" & vbCrLf
ps = ps & "            }" & vbCrLf
ps = ps & "            'activating' {" & vbCrLf
ps = ps & "                $dshMenu.ForeColor = [System.Drawing.Color]::DarkOrange" & vbCrLf
ps = ps & "            }" & vbCrLf
ps = ps & "            'deactivating' {" & vbCrLf
ps = ps & "                $dshMenu.ForeColor = [System.Drawing.Color]::DarkOrange" & vbCrLf
ps = ps & "            }" & vbCrLf
ps = ps & "            default {" & vbCrLf
ps = ps & "                $dshMenu.ForeColor = [System.Drawing.Color]::Firebrick" & vbCrLf
ps = ps & "            }" & vbCrLf
ps = ps & "        }" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "        # ------------------------------------------------" & vbCrLf
ps = ps & "        # Refresh Startup checkmarks" & vbCrLf
ps = ps & "        #" & vbCrLf
ps = ps & "        # This means that if systemctl enable/disable is" & vbCrLf
ps = ps & "        # changed outside the tray, the menu eventually" & vbCrLf
ps = ps & "        # reflects the real state." & vbCrLf
ps = ps & "        # ------------------------------------------------" & vbCrLf
ps = ps & "        $openCodeStartup.Checked = Get-WslServiceEnabled 'opencode'" & vbCrLf
ps = ps & "        $omniRouteStartup.Checked = Get-WslServiceEnabled 'omniroute'" & vbCrLf
ps = ps & "        $dshStartup.Checked = Get-WslServiceEnabled 'dsh'" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "        # ------------------------------------------------" & vbCrLf
ps = ps & "        # Tray tooltip" & vbCrLf
ps = ps & "        # ------------------------------------------------" & vbCrLf
ps = ps & "        $notifyIcon.Text = 'OpenCode: ' + $openCodeState + ' | OmniRoute: ' + $omniRouteState + ' | DSH: ' + $dshState" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "    } catch {" & vbCrLf
ps = ps & "        # A status-check failure must never terminate the tray." & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

ps = ps & "$statusTimer.Add_Tick($updateStatus)" & vbCrLf
ps = ps & "$statusTimer.Start()" & vbCrLf
ps = ps & "" & vbCrLf

' Run immediately instead of waiting for the first timer tick.

ps = ps & "& $updateStatus" & vbCrLf
ps = ps & "" & vbCrLf

' ============================================================
' KEEP TRAY APPLICATION ALIVE
' ============================================================

ps = ps & "Debug-Trace 'Entering Application.Run'" & vbCrLf
ps = ps & "[System.Windows.Forms.Application]::Run()" & vbCrLf

' ============================================================
' CLEANUP
'
' Normally Exit uses the handler above. This also provides a
' cleanup path if Application.Run() returns unexpectedly.
' ============================================================

ps = ps & "" & vbCrLf
ps = ps & "try {" & vbCrLf
ps = ps & "    $notifyIcon.Visible = $false" & vbCrLf
ps = ps & "    $notifyIcon.Dispose()" & vbCrLf
ps = ps & "} catch {}" & vbCrLf
ps = ps & "" & vbCrLf

'
' ============================================================
' LAUNCH POWERSHELL ROBUSTLY
'
' IMPORTANT:
'
' Do not use MSXML nodeTypedValue/Base64 here.
'
' Some Windows installations return:
'
'     80070057 - The parameter is incorrect
'
' when the byte array returned by ADODB.Stream is passed to
' MSXML's nodeTypedValue.
'
' Instead, write the complete PowerShell payload to a temporary
' UTF-16LE .ps1 file and launch PowerShell with -File.
'
' The VBS remains completely self-contained. No permanent second
' configuration/script file is required.
' ============================================================

Function WritePowerShellTempFile(ByVal source)

    Dim tempFolder
    Dim tempName
    Dim tempPath
    Dim stream

    tempFolder = fso.GetSpecialFolder(2)

    tempName = "omniroute-tray-" & _
               CStr(Int(Timer * 1000)) & "-" & _
               CStr(Int(Rnd() * 1000000)) & ".ps1"

    tempPath = fso.BuildPath(tempFolder, tempName)

    Set stream = CreateObject("ADODB.Stream")

    stream.Type = 2
    stream.Charset = "unicode"
    stream.Open

    stream.WriteText source

    stream.SaveToFile tempPath, 2

    stream.Close
    Set stream = Nothing

    WritePowerShellTempFile = tempPath

End Function

Randomize

Dim psTempFile

psTempFile = WritePowerShellTempFile(ps)

If Len(psTempFile) = 0 Then

    MsgBox _
        "Could not create the temporary PowerShell script.", _
        vbCritical, _
        "AI Services"

    WScript.Quit 1

End If

' ============================================================
' START POWERSHELL
' ============================================================

WScript.Echo "DEBUG: temporary PowerShell script: " & psTempFile
WScript.Echo "DEBUG: launching PowerShell visibly..."
WScript.Echo "DEBUG: if there is a PowerShell parse/runtime error, it should appear in the window."

Dim psExitCode

psExitCode = WshShell.Run( _
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -File " & _
    Chr(34) & psTempFile & Chr(34), _
    1, _
    True)

WScript.Echo "DEBUG: PowerShell exited with code " & CStr(psExitCode)
WScript.Echo "DEBUG: debug log (if created): " & _
             fso.BuildPath(fso.GetSpecialFolder(2), "omniroute-tray-debug.log")

Set WshShell = Nothing
Set fso = Nothing

WScript.Quit psExitCode

