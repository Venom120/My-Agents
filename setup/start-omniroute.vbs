Set WshShell = CreateObject("WScript.Shell")

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
ps = ps & "" & vbCrLf

' ============================================================
' SINGLE INSTANCE
'
' Only one tray application instance is allowed to run.
'
' If this script is launched again while the existing tray
' instance is alive, the second instance exits immediately.
'
' The mutex is created BEFORE Docker/WSL startup so launching
' the VBS twice does not cause a second initialization attempt.
' ============================================================

ps = ps & "$scriptMutex = New-Object System.Threading.Mutex($false, 'Global\OmniRouteTray')" & vbCrLf
ps = ps & "$mutexAcquired = $false" & vbCrLf
ps = ps & "try {" & vbCrLf
ps = ps & "    $mutexAcquired = $scriptMutex.WaitOne(0, $false)" & vbCrLf
ps = ps & "    if (-not $mutexAcquired) {" & vbCrLf
ps = ps & "        exit" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "} catch {" & vbCrLf
ps = ps & "    exit" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf

' ============================================================
' START DOCKER DESKTOP, THEN WSL - $WSLDistro
'
' Docker Desktop must be fully ready before the WSL distro
' starts. This prevents systemd from starting
' OpenCode/OmniRoute/DSH before Docker Desktop's WSL
' integration is initialized.
' ============================================================

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

ps = ps & "if ($dockerReady) {" & vbCrLf
ps = ps & "    Start-Sleep -Seconds 2" & vbCrLf
ps = ps & "    Start-Process wsl.exe -ArgumentList '-d',$WSLDistro,'--exec','dbus-launch','true' -WindowStyle Hidden -PassThru" & vbCrLf
ps = ps & "} else {" & vbCrLf
ps = ps & "    [System.Windows.Forms.MessageBox]::Show('Docker Desktop did not become ready within 120 seconds. ' + $WSLDistro + ' services were not started.','AI Services', 'OK', 'Error')" & vbCrLf
ps = ps & "    if ($mutexAcquired) {" & vbCrLf
ps = ps & "        try { $scriptMutex.ReleaseMutex() } catch {}" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "    try { $scriptMutex.Dispose() } catch {}" & vbCrLf
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
'             ↓
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
ps = ps & "" & vbCrLf

' ============================================================
' START SERVICES ENABLED FOR THIS SCRIPT INSTANCE
' ============================================================

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
'     Startup ✓
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
'   Startup [✓]
'
' OmniRoute
'   Open
'   Start
'   Restart
'   Stop
'   Startup [✓]
'
' DeepSeek Harness
'   Open
'   Start
'   Restart
'   Stop
'   Startup [✓]
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
ps = ps & "    # Release the single-instance mutex so the tray can" & vbCrLf
ps = ps & "    # be started again normally." & vbCrLf
ps = ps & "    if ($mutexAcquired) {" & vbCrLf
ps = ps & "        try { $scriptMutex.ReleaseMutex() } catch {}" & vbCrLf
ps = ps & "    }" & vbCrLf
ps = ps & "" & vbCrLf
ps = ps & "    try { $scriptMutex.Dispose() } catch {}" & vbCrLf
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
ps = ps & "if ($mutexAcquired) {" & vbCrLf
ps = ps & "    try { $scriptMutex.ReleaseMutex() } catch {}" & vbCrLf
ps = ps & "}" & vbCrLf
ps = ps & "" & vbCrLf
ps = ps & "try { $scriptMutex.Dispose() } catch {}" & vbCrLf

WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command " & Chr(34) & ps & Chr(34), 0, False