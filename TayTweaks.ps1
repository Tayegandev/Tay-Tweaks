Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$DataDir = Join-Path $env:ProgramData "TayTweaks"
$BackupFile = Join-Path $DataDir "last-session.json"
$AppliedFile = Join-Path $DataDir "last-applied.json"
$LogFile = Join-Path $DataDir "tay-tweaks.log"
function Log([string]$m) { try { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null; Add-Content $LogFile ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$m) } catch {} }

$p = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  # When launched as a .ps1, request UAC elevation instead of merely exiting.
  # The compiled EXE also carries a requireAdministrator manifest via the builder.
  try {
    $hostExe = (Get-Process -Id $PID).Path
    $scriptPath = $MyInvocation.MyCommand.Path
    if ($scriptPath) {
      Start-Process -FilePath $hostExe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $scriptPath + '"')) -Verb RunAs
    } else {
      [System.Windows.Forms.MessageBox]::Show("Tay Tweaks needs Administrator permission. Close it and approve the Windows UAC prompt.", "Tay Tweaks") | Out-Null
    }
  } catch {
    [System.Windows.Forms.MessageBox]::Show("Administrator permission was not granted. No changes were made.`r`n$($_.Exception.Message)", "Tay Tweaks") | Out-Null
  }
  exit
}

$Tweaks = @(
 [pscustomobject]@{Id="gamedvr";Name="Disable background Game DVR capture";Group="Gaming";Default=$true;Advanced=$false;Desc="Disables Windows background game recording; does not disable Fortnite.";Changes=@(
  @{Path="HKCU:\System\GameConfigStore";Name="GameDVR_Enabled";Type="DWord";Value=0},
  @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR";Name="AppCaptureEnabled";Type="DWord";Value=0})},
 [pscustomobject]@{Id="gamemode";Name="Enable Windows Game Mode";Group="Gaming";Default=$true;Advanced=$false;Desc="Enables Game Mode settings. Results vary by game and system.";Changes=@(
  @{Path="HKCU:\Software\Microsoft\GameBar";Name="AutoGameModeEnabled";Type="DWord";Value=1},
  @{Path="HKCU:\Software\Microsoft\GameBar";Name="AllowAutoGameMode";Type="DWord";Value=1})},
 [pscustomobject]@{Id="mouse";Name="Disable mouse acceleration";Group="Input";Default=$false;Advanced=$false;Desc="Disables Enhance pointer precision. Changes desktop pointer behavior, not FPS.";Changes=@(
  @{Path="HKCU:\Control Panel\Mouse";Name="MouseSpeed";Type="String";Value="0"},
  @{Path="HKCU:\Control Panel\Mouse";Name="MouseThreshold1";Type="String";Value="0"},
  @{Path="HKCU:\Control Panel\Mouse";Name="MouseThreshold2";Type="String";Value="0"})},
 [pscustomobject]@{Id="transparency";Name="Turn off transparency effects";Group="Windows";Default=$false;Advanced=$false;Desc="Turns off transparency effects; a small UI preference, not a guaranteed FPS boost.";Changes=@(
  @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize";Name="EnableTransparency";Type="DWord";Value=0})},
 [pscustomobject]@{Id="visualfx";Name="Prefer performance over visual effects";Group="Windows";Default=$false;Advanced=$false;Desc="Selects Windows visual-effects performance mode. UI may look simpler.";Changes=@(
  @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects";Name="VisualFXSetting";Type="DWord";Value=2})},
 [pscustomobject]@{Id="suggestions";Name="Reduce Windows tips and consumer suggestions";Group="Windows";Default=$false;Advanced=$false;Desc="Reduces some suggested content and auto-installed app prompts; it will not remove core Windows components.";Changes=@(
  @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager";Name="SystemPaneSuggestionsEnabled";Type="DWord";Value=0},
  @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager";Name="SilentInstalledAppsEnabled";Type="DWord";Value=0},
  @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager";Name="SubscribedContent-338389Enabled";Type="DWord";Value=0},
  @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager";Name="SubscribedContent-353694Enabled";Type="DWord";Value=0})},
 [pscustomobject]@{Id="privacyads";Name="Turn off advertising ID and tailored experiences";Group="Privacy";Default=$false;Advanced=$false;Desc="Privacy preference; not an FPS tweak. Some settings may vary by Windows edition.";Changes=@(
  @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo";Name="Enabled";Type="DWord";Value=0},
  @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy";Name="TailoredExperiencesWithDiagnosticDataEnabled";Type="DWord";Value=0})},
 [pscustomobject]@{Id="gametips";Name="Disable Xbox Game Bar startup tips";Group="Gaming";Default=$false;Advanced=$false;Desc="Hides Game Bar welcome tips; it does not disable the Game Bar itself.";Changes=@(
  @{Path="HKCU:\Software\Microsoft\GameBar";Name="ShowStartupPanel";Type="DWord";Value=0},
  @{Path="HKCU:\Software\Microsoft\GameBar";Name="GamePanelStartupTipIndex";Type="DWord";Value=3})},
 [pscustomobject]@{Id="launchtracking";Name="Disable Start menu app launch tracking";Group="Privacy";Default=$false;Advanced=$false;Desc="Privacy preference that reduces Start menu app-usage tracking; may change Start menu suggestions.";Changes=@(
  @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";Name="Start_TrackProgs";Type="DWord";Value=0})},
 [pscustomobject]@{Id="notifications";Name="Disable toast notifications";Group="Windows";Default=$false;Advanced=$false;Desc="Hides Windows app toast notifications. You may miss useful alerts.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications";Name="ToastEnabled";Type="DWord";Value=0})},
 [pscustomobject]@{Id="locktips";Name="Disable lock-screen tips";Group="Privacy";Default=$false;Advanced=$false;Desc="Removes promotional tips from the lock screen.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager";Name="RotatingLockScreenOverlayEnabled";Type="DWord";Value=0})},
 [pscustomobject]@{Id="lockstatus";Name="Disable lock-screen fun facts";Group="Privacy";Default=$false;Advanced=$false;Desc="Turns off lock-screen consumer suggestions.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager";Name="SubscribedContent-338387Enabled";Type="DWord";Value=0})},
 [pscustomobject]@{Id="searchhighlights";Name="Disable Search highlights";Group="Windows";Default=$false;Advanced=$false;Desc="Removes Search highlights from Windows Search.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings";Name="IsDynamicSearchBoxEnabled";Type="DWord";Value=0})},
 [pscustomobject]@{Id="quickaccessrecent";Name="Hide recent files in Quick Access";Group="Explorer";Default=$false;Advanced=$false;Desc="Privacy/UI preference; recent files will no longer be listed.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer";Name="ShowRecent";Type="DWord";Value=0})},
 [pscustomobject]@{Id="quickaccessfrequent";Name="Hide frequent folders in Quick Access";Group="Explorer";Default=$false;Advanced=$false;Desc="Privacy/UI preference; frequent folders will no longer be listed.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer";Name="ShowFrequent";Type="DWord";Value=0})},
 [pscustomobject]@{Id="explorerthispc";Name="Open File Explorer to This PC";Group="Explorer";Default=$false;Advanced=$false;Desc="Opens File Explorer to This PC instead of Home/Quick Access.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";Name="LaunchTo";Type="DWord";Value=1})},
 [pscustomobject]@{Id="fileextensions";Name="Show file extensions";Group="Explorer";Default=$false;Advanced=$false;Desc="Makes .exe, .zip and other file extensions visible.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";Name="HideFileExt";Type="DWord";Value=0})},
 [pscustomobject]@{Id="fullpath";Name="Show full path in Explorer title bar";Group="Explorer";Default=$false;Advanced=$false;Desc="Displays the full folder path in File Explorer title bars.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState";Name="FullPath";Type="DWord";Value=1})},
 [pscustomobject]@{Id="statusbar";Name="Show Explorer status bar";Group="Explorer";Default=$false;Advanced=$false;Desc="Shows the status bar at the bottom of File Explorer windows.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";Name="ShowStatusBar";Type="DWord";Value=1})},
 [pscustomobject]@{Id="taskbarwidgets";Name="Hide taskbar Widgets button";Group="Windows";Default=$false;Advanced=$false;Desc="Hides the Widgets taskbar button on supported Windows 11 builds.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";Name="TaskbarDa";Type="DWord";Value=0})},
 [pscustomobject]@{Id="taskbarchat";Name="Hide taskbar Chat/Meet button";Group="Windows";Default=$false;Advanced=$false;Desc="Hides the Chat/Meet taskbar button on supported Windows builds.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";Name="TaskbarMn";Type="DWord";Value=0})},
 [pscustomobject]@{Id="taskview";Name="Hide Task View button";Group="Windows";Default=$false;Advanced=$false;Desc="Hides the Task View taskbar button; it does not uninstall features.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";Name="ShowTaskViewButton";Type="DWord";Value=0})},
 [pscustomobject]@{Id="searchbutton";Name="Hide taskbar Search button";Group="Windows";Default=$false;Advanced=$false;Desc="Hides the taskbar Search button; Windows Search remains available.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Search";Name="SearchboxTaskbarMode";Type="DWord";Value=0})},
 [pscustomobject]@{Id="autoplay";Name="Disable AutoPlay";Group="Security";Default=$false;Advanced=$false;Desc="Prevents removable media from automatically launching content.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers";Name="DisableAutoplay";Type="DWord";Value=1})},
 [pscustomobject]@{Id="autorun";Name="Disable AutoRun for removable drives";Group="Security";Default=$false;Advanced=$false;Desc="Reduces automatic execution from removable media; a security preference.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer";Name="NoDriveTypeAutoRun";Type="DWord";Value=255})},
 [pscustomobject]@{Id="menuanimation";Name="Disable menu animation";Group="Windows";Default=$false;Advanced=$false;Desc="Reduces menu animations; visual preference, not a guaranteed FPS boost.";Changes=@(@{Path="HKCU:\Control Panel\Desktop\WindowMetrics";Name="MinAnimate";Type="String";Value="0"})},
 [pscustomobject]@{Id="menushowdelay";Name="Shorten menu show delay";Group="Windows";Default=$false;Advanced=$false;Desc="Makes menus appear more quickly. Set to 100 ms rather than zero.";Changes=@(@{Path="HKCU:\Control Panel\Desktop";Name="MenuShowDelay";Type="String";Value="100"})},
 [pscustomobject]@{Id="dragfullwindows";Name="Show window contents while dragging";Group="Windows";Default=$false;Advanced=$false;Desc="Keeps window contents visible while dragging; may use slightly more UI rendering.";Changes=@(@{Path="HKCU:\Control Panel\Desktop";Name="DragFullWindows";Type="String";Value="1"})},
 [pscustomobject]@{Id="keyboarddelay";Name="Reduce keyboard repeat delay";Group="Input";Default=$false;Advanced=$false;Desc="Changes keyboard repeat delay to a faster setting; preference only.";Changes=@(@{Path="HKCU:\Control Panel\Keyboard";Name="KeyboardDelay";Type="String";Value="1"})},
 [pscustomobject]@{Id="keyboardrate";Name="Increase keyboard repeat rate";Group="Input";Default=$false;Advanced=$false;Desc="Sets a faster keyboard repeat rate; preference only.";Changes=@(@{Path="HKCU:\Control Panel\Keyboard";Name="KeyboardSpeed";Type="String";Value="31"})},
 [pscustomobject]@{Id="stickykeys";Name="Disable Sticky Keys shortcut";Group="Input";Default=$false;Advanced=$false;Desc="Stops the Shift-key shortcut from enabling Sticky Keys accidentally.";Changes=@(@{Path="HKCU:\Control Panel\Accessibility\StickyKeys";Name="Flags";Type="String";Value="506"})},
 [pscustomobject]@{Id="filterkeys";Name="Disable Filter Keys shortcut";Group="Input";Default=$false;Advanced=$false;Desc="Reduces accidental Filter Keys activation from long key presses.";Changes=@(@{Path="HKCU:\Control Panel\Accessibility\Keyboard Response";Name="Flags";Type="String";Value="122"})},
 [pscustomobject]@{Id="togglekeys";Name="Disable Toggle Keys shortcut";Group="Input";Default=$false;Advanced=$false;Desc="Reduces accidental Toggle Keys activation.";Changes=@(@{Path="HKCU:\Control Panel\Accessibility\ToggleKeys";Name="Flags";Type="String";Value="58"})},
 [pscustomobject]@{Id="disableappbackground";Name="Limit legacy background apps";Group="Privacy";Default=$false;Advanced=$false;Desc="Requests Windows to restrict background apps where this policy is supported. App behavior varies.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications";Name="GlobalUserDisabled";Type="DWord";Value=1})},
 [pscustomobject]@{Id="disableactivityhistory";Name="Disable activity history publishing";Group="Privacy";Default=$false;Advanced=$false;Desc="Privacy preference; supported behavior varies by Windows build.";Changes=@(@{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System";Name="PublishUserActivities";Type="DWord";Value=0})},
 [pscustomobject]@{Id="disableactivityupload";Name="Disable activity history upload";Group="Privacy";Default=$false;Advanced=$false;Desc="Privacy preference; supported behavior varies by Windows build.";Changes=@(@{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System";Name="UploadUserActivities";Type="DWord";Value=0})},
 [pscustomobject]@{Id="disabletailored";Name="Disable tailored experiences";Group="Privacy";Default=$false;Advanced=$false;Desc="Turns off tailored Windows experiences where supported.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy";Name="TailoredExperiencesWithDiagnosticDataEnabled";Type="DWord";Value=0})},
 [pscustomobject]@{Id="disablefeedback";Name="Reduce feedback prompts";Group="Privacy";Default=$false;Advanced=$false;Desc="Reduces Windows feedback request prompts.";Changes=@(@{Path="HKCU:\Software\Microsoft\Siuf\Rules";Name="NumberOfSIUFInPeriod";Type="DWord";Value=0})},
 [pscustomobject]@{Id="disableink";Name="Disable automatic inking personalization";Group="Privacy";Default=$false;Advanced=$false;Desc="Privacy preference for handwriting/inking data; applies only where supported.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\PenWorkspace";Name="PenWorkspaceAppSuggestionsEnabled";Type="DWord";Value=0})},
 [pscustomobject]@{Id="disablecloudclipboard";Name="Disable clipboard history sync";Group="Privacy";Default=$false;Advanced=$false;Desc="Disables clipboard history/sync settings; you may lose clipboard history convenience.";Changes=@(@{Path="HKCU:\Software\Microsoft\Clipboard";Name="EnableClipboardHistory";Type="DWord";Value=0})},
 [pscustomobject]@{Id="disableclipboardsync";Name="Disable clipboard sync across devices";Group="Privacy";Default=$false;Advanced=$false;Desc="Stops clipboard sync across devices where supported.";Changes=@(@{Path="HKCU:\Software\Microsoft\Clipboard";Name="EnableCloudClipboard";Type="DWord";Value=0})},
 [pscustomobject]@{Id="disablewebsearch";Name="Reduce web results in Start search";Group="Privacy";Default=$false;Advanced=$false;Desc="Disables web search suggestions in Start where the policy is honored.";Changes=@(@{Path="HKCU:\Software\Policies\Microsoft\Windows\Explorer";Name="DisableSearchBoxSuggestions";Type="DWord";Value=1})},
 [pscustomobject]@{Id="disableconsumerfeatures";Name="Disable consumer experience suggestions";Group="Privacy";Default=$false;Advanced=$false;Desc="Reduces consumer content suggestions; does not remove Windows components.";Changes=@(@{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent";Name="DisableWindowsConsumerFeatures";Type="DWord";Value=1})},
 [pscustomobject]@{Id="disablewindowsink";Name="Disable online speech recognition";Group="Privacy";Default=$false;Advanced=$false;Desc="Turns off online speech recognition where supported; voice features may change.";Changes=@(@{Path="HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy";Name="HasAccepted";Type="DWord";Value=0})},
 [pscustomobject]@{Id="disabletailoredads";Name="Disable suggested content in Settings";Group="Privacy";Default=$false;Advanced=$false;Desc="Reduces suggested content in Settings; privacy/UI preference.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager";Name="SubscribedContent-353698Enabled";Type="DWord";Value=0})},
 [pscustomobject]@{Id="disablecloudcontent";Name="Disable content delivery suggestions";Group="Privacy";Default=$false;Advanced=$false;Desc="Reduces Windows content delivery suggestions where supported.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager";Name="ContentDeliveryAllowed";Type="DWord";Value=0})},
 [pscustomobject]@{Id="disablesoftlanding";Name="Disable Windows welcome experience tips";Group="Privacy";Default=$false;Advanced=$false;Desc="Turns off Windows welcome/soft-landing suggestions.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager";Name="SoftLandingEnabled";Type="DWord";Value=0})},
 [pscustomobject]@{Id="disablestartrecents";Name="Hide recently added apps in Start";Group="Windows";Default=$false;Advanced=$false;Desc="Hides recently added apps in Start where supported.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";Name="Start_TrackProgs";Type="DWord";Value=0})},
 [pscustomobject]@{Id="disabletaskbarbadges";Name="Disable taskbar app badges";Group="Windows";Default=$false;Advanced=$false;Desc="Hides notification badges on taskbar apps.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";Name="TaskbarBadges";Type="DWord";Value=0})},
 [pscustomobject]@{Id="disabletaskbarflashing";Name="Disable taskbar app flashing";Group="Windows";Default=$false;Advanced=$false;Desc="Reduces taskbar flashing alerts; you may miss visual notifications.";Changes=@(@{Path="HKCU:\Control Panel\Desktop";Name="ForegroundFlashCount";Type="DWord";Value=0})},
 [pscustomobject]@{Id="disablewindowshakes";Name="Disable title-bar shake minimize";Group="Windows";Default=$false;Advanced=$false;Desc="Prevents shaking a window title bar from minimizing other windows.";Changes=@(@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";Name="DisallowShaking";Type="DWord";Value=1})}
)

# v5: conservative, documented user-facing performance preferences. Hardware protections are untouched.
$Tweaks += @(
 [pscustomobject]@{Id='backgroundapps';Name='Reduce background app activity';Group='RAM';Default=$false;Advanced=$true;Desc='Restricts some Windows Store background apps for the current user. May affect notifications.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications';Name='GlobalUserDisabled';Type='DWord';Value=1})},
 [pscustomobject]@{Id='gamebarcapture';Name='Disable additional background capture';Group='GPU';Default=$false;Advanced=$false;Desc='Turns off Windows game capture settings; does not change GPU clocks.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR';Name='HistoricalCaptureEnabled';Type='DWord';Value=0})}
)

# v6.1.3: 60 NEW OPT-IN NICHE SETTINGS. All use the existing snapshot/restore and per-tweak reporting engine.
# Behaviour varies with Windows version; none are a guaranteed frame-rate improvement.
$Tweaks += @(
 [pscustomobject]@{Id='t613_showhidden';Name='Show hidden files and folders';Group='Explorer';Default=$false;Advanced=$true;Desc='Displays hidden user files. Hidden system files remain separately protected.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='Hidden';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_compactview';Name='Use compact File Explorer spacing';Group='Explorer';Default=$false;Advanced=$true;Desc='Reduces row spacing where the Explorer compact view is supported.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='UseCompactMode';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_expandtree';Name='Auto-expand Explorer navigation tree';Group='Explorer';Default=$false;Advanced=$true;Desc='Expands the folder tree to the currently open location.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='NavPaneExpandToCurrentFolder';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_allfolders';Name='Show all folders in navigation pane';Group='Explorer';Default=$false;Advanced=$true;Desc='Adds more shell folders to the Explorer navigation pane.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='NavPaneShowAllFolders';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_itemcheckboxes';Name='Use checkboxes for selecting files';Group='Explorer';Default=$false;Advanced=$true;Desc='Displays selection checkboxes beside files and folders.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='AutoCheckSelect';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_expsyncads';Name='Hide Explorer sync-provider promotions';Group='Explorer';Default=$false;Advanced=$true;Desc='Reduces sync-provider notifications and promotional messages in Explorer.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='ShowSyncProviderNotifications';Type='DWord';Value=0})},
 [pscustomobject]@{Id='t613_advancedsharing';Name='Use advanced file sharing instead of wizard';Group='Explorer';Default=$false;Advanced=$true;Desc='Turns off the legacy sharing wizard; advanced sharing can be more complex.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='SharingWizardOn';Type='DWord';Value=0})},
 [pscustomobject]@{Id='t613_hideinfotips';Name='Disable Explorer file hover tooltips';Group='Explorer';Default=$false;Advanced=$true;Desc='Stops some Explorer item information popups.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='ShowInfoTip';Type='DWord';Value=0})},
 [pscustomobject]@{Id='t613_iconsnotthumbs';Name='Use icons instead of thumbnails';Group='Explorer';Default=$false;Advanced=$true;Desc='Hides thumbnail previews to reduce thumbnail generation; images are harder to identify.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='IconsOnly';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_separateexplorer';Name='Run folder windows in separate Explorer process';Group='Explorer';Default=$false;Advanced=$true;Desc='Isolates folder windows from parts of the shell; consumes additional RAM.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='SeparateProcess';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_mergeconflicts';Name='Display folder merge conflict prompts';Group='Explorer';Default=$false;Advanced=$true;Desc='Displays merge warnings rather than hiding them where supported.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='HideMergeConflicts';Type='DWord';Value=0})},
 [pscustomobject]@{Id='t613_alwaysmenus';Name='Show classic menu bar when supported';Group='Explorer';Default=$false;Advanced=$true;Desc='Legacy Explorer preference; current Windows 11 may ignore it.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='AlwaysShowMenus';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_nolabelshadow';Name='Disable desktop icon label shadows';Group='Explorer';Default=$false;Advanced=$true;Desc='Changes desktop icon label visual effects.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='ListviewShadow';Type='DWord';Value=0})},
 [pscustomobject]@{Id='t613_noalphaselect';Name='Disable translucent Explorer selection box';Group='Explorer';Default=$false;Advanced=$true;Desc='Changes the folder/desktop selection rectangle appearance.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='ListviewAlphaSelect';Type='DWord';Value=0})},
 [pscustomobject]@{Id='t613_confirmdelete';Name='Confirm deletions in File Explorer';Group='Explorer';Default=$false;Advanced=$true;Desc='Prompts for confirmation when supported; helps prevent accidental deletions.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer';Name='ConfirmFileDelete';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_copydetails';Name='Expand Explorer copy-operation details';Group='Explorer';Default=$false;Advanced=$true;Desc='Shows detailed progress in the legacy file copy dialogue.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager';Name='EnthusiastMode';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_recentdocshistory';Name='Stop saving legacy recent-document history';Group='Explorer';Default=$false;Advanced=$true;Desc='Disables legacy recent-doc history, separate from Quick Access recent-file visibility.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer';Name='NoRecentDocsHistory';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_recentdocsmenu';Name='Hide legacy recent-documents menu';Group='Explorer';Default=$false;Advanced=$true;Desc='Hides the legacy recent-documents menu; Windows 11 may ignore this setting.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer';Name='NoRecentDocsMenu';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_secondsclock';Name='Show seconds on taskbar clock';Group='Windows';Default=$false;Advanced=$true;Desc='Adds seconds to supported Windows taskbar clocks; may increase wakeups.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='ShowSecondsInSystemClock';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_taskbarendtask';Name='Show End Task in app taskbar context menu';Group='Windows';Default=$false;Advanced=$true;Desc='Provides a faster force-close shortcut on supported Windows 11 builds; unsaved work can be lost.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings';Name='TaskbarEndTask';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_morestartpins';Name='Use more pinned apps in Start';Group='Windows';Default=$false;Advanced=$true;Desc='Prefers more pinned apps versus recommendations where supported.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='Start_Layout';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_startrecommendations';Name='Reduce Start recommendations';Group='Windows';Default=$false;Advanced=$true;Desc='Reduces some recommendations on supported Windows 11 versions.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='Start_IrisRecommendations';Type='DWord';Value=0})},
 [pscustomobject]@{Id='t613_notaskbaranimation';Name='Disable taskbar animation';Group='Windows';Default=$false;Advanced=$true;Desc='Turns off supported taskbar animations; visual preference only.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='TaskbarAnimations';Type='DWord';Value=0})},
 [pscustomobject]@{Id='t613_multimonitortaskbar';Name='Show taskbar on multiple monitors';Group='Windows';Default=$false;Advanced=$true;Desc='Shows taskbar on secondary monitors where supported.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='MMTaskbarEnabled';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_nopeek';Name='Disable desktop Peek gesture';Group='Windows';Default=$false;Advanced=$true;Desc='Disables desktop peek; does not stop normal window switching.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='DisablePreviewDesktop';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_nosnap';Name='Disable automatic window snapping';Group='Windows';Default=$false;Advanced=$true;Desc='Turns off snap arrangement triggered by dragging windows.';Changes=@(@{Path='HKCU:\Control Panel\Desktop';Name='WindowArrangementActive';Type='String';Value='0'})},
 [pscustomobject]@{Id='t613_darkapps';Name='Use dark mode for applications';Group='Windows';Default=$false;Advanced=$true;Desc='Requests dark mode in apps that follow Windows theme preference.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize';Name='AppsUseLightTheme';Type='DWord';Value=0})},
 [pscustomobject]@{Id='t613_darksystem';Name='Use dark system shell';Group='Windows';Default=$false;Advanced=$true;Desc='Requests dark taskbar and system UI on supported Windows builds.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize';Name='SystemUsesLightTheme';Type='DWord';Value=0})},
 [pscustomobject]@{Id='t613_alwaysscrollbars';Name='Always display available scrollbars';Group='Windows';Default=$false;Advanced=$true;Desc='Prevents automatic hiding of accessibility scrollbars where supported.';Changes=@(@{Path='HKCU:\Control Panel\Accessibility';Name='DynamicScrollbars';Type='DWord';Value=0})},
 [pscustomobject]@{Id='t613_nobackgroundscroll';Name='Disable scrolling inactive windows';Group='Windows';Default=$false;Advanced=$true;Desc='Requires selecting a window before using the mouse wheel on it.';Changes=@(@{Path='HKCU:\Control Panel\Desktop';Name='ScrollInactiveWindows';Type='DWord';Value=0})},
 [pscustomobject]@{Id='t613_accenttitle';Name='Show accent colour on title bars';Group='Windows';Default=$false;Advanced=$true;Desc='Applies an accent colour to eligible window borders and title bars.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\DWM';Name='ColorPrevalence';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_desktopversion';Name='Show Windows build on desktop';Group='Windows';Default=$false;Advanced=$true;Desc='Displays the Windows version/build watermark on supported desktops.';Changes=@(@{Path='HKCU:\Control Panel\Desktop';Name='PaintDesktopVersion';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_nologonacrylic';Name='Disable blurred sign-in background';Group='Windows';Default=$false;Advanced=$true;Desc='Uses a clear login background instead of acrylic blur.';Changes=@(@{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System';Name='DisableAcrylicBackgroundOnLogon';Type='DWord';Value=1})},
 [pscustomobject]@{Id='t613_lefttaskbar';Name='Left-align Windows 11 taskbar icons';Group='Windows';Default=$false;Advanced=$true;Desc='Moves supported Windows 11 taskbar icons to the left.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='TaskbarAl';Type='DWord';Value=0})},
 [pscustomobject]@{Id='t613_taskbarnevercombine';Name='Do not combine primary taskbar buttons';Group='Windows';Default=$false;Advanced=$true;Desc='Keeps separate app buttons on compatible Windows taskbars.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='TaskbarGlomLevel';Type='DWord';Value=2})},
 [pscustomobject]@{Id='t613_secondarynevercombine';Name='Do not combine secondary taskbar buttons';Group='Windows';Default=$false;Advanced=$true;Desc='Keeps separate app buttons on secondary monitors where supported.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Name='MMTaskbarGlomLevel';Type='DWord';Value=2})},
 [pscustomobject]@{Id='t613_mousehovertime';Name='Shorten mouse hover detection';Group='Input';Default=$false;Advanced=$true;Desc='Controls how long the pointer must hover to trigger selected UI actions.';Changes=@(@{Path='HKCU:\Control Panel\Mouse';Name='MouseHoverTime';Type='String';Value='250'})},
 [pscustomobject]@{Id='t613_mousehoverwidth';Name='Use precise mouse hover width';Group='Input';Default=$false;Advanced=$true;Desc='Sets a smaller horizontal mouse hover rectangle.';Changes=@(@{Path='HKCU:\Control Panel\Mouse';Name='MouseHoverWidth';Type='String';Value='4'})},
 [pscustomobject]@{Id='t613_mousehoverheight';Name='Use precise mouse hover height';Group='Input';Default=$false;Advanced=$true;Desc='Sets a smaller vertical mouse hover rectangle.';Changes=@(@{Path='HKCU:\Control Panel\Mouse';Name='MouseHoverHeight';Type='String';Value='4'})},
 [pscustomobject]@{Id='t613_doubleclick';Name='Set desktop double-click interval to 350 ms';Group='Input';Default=$false;Advanced=$true;Desc='Changes the Windows desktop double-click timing, not game inputs.';Changes=@(@{Path='HKCU:\Control Panel\Mouse';Name='DoubleClickSpeed';Type='String';Value='350'})},
 [pscustomobject]@{Id='t613_wheellines';Name='Scroll four lines per mouse-wheel notch';Group='Input';Default=$false;Advanced=$true;Desc='Sets a predictable vertical mouse-wheel scroll amount.';Changes=@(@{Path='HKCU:\Control Panel\Desktop';Name='WheelScrollLines';Type='String';Value='4'})},
 [pscustomobject]@{Id='t613_wheelchars';Name='Scroll three characters horizontally';Group='Input';Default=$false;Advanced=$true;Desc='Adjusts horizontal mouse wheel/tilt scrolling.';Changes=@(@{Path='HKCU:\Control Panel\Desktop';Name='WheelScrollChars';Type='String';Value='3'})},
 [pscustomobject]@{Id='t613_caretwidth';Name='Use wider text cursor';Group='Input';Default=$false;Advanced=$true;Desc='Makes the text insertion caret easier to see.';Changes=@(@{Path='HKCU:\Control Panel\Desktop';Name='CaretWidth';Type='DWord';Value=2})},
 [pscustomobject]@{Id='t613_caretblink';Name='Set text cursor blink interval';Group='Input';Default=$false;Advanced=$true;Desc='Changes text caret blinking frequency on supported controls.';Changes=@(@{Path='HKCU:\Control Panel\Desktop';Name='CursorBlinkRate';Type='String';Value='450'})},
 [pscustomobject]@{Id='t613_nomousetrails';Name='Turn off pointer trails';Group='Input';Default=$false;Advanced=$true;Desc='Removes pointer trails where enabled; does not change mouse polling.';Changes=@(@{Path='HKCU:\Control Panel\Mouse';Name='MouseTrails';Type='String';Value='0'})},
 [pscustomobject]@{Id='t613_nomouseclicklock';Name='Turn off Mouse ClickLock';Group='Input';Default=$false;Advanced=$true;Desc='Requires holding the mouse button while dragging.';Changes=@(@{Path='HKCU:\Control Panel\Mouse';Name='MouseClickLock';Type='String';Value='0'})},
 [pscustomobject]@{Id='t613_camera';Name='Restrict app access to camera';Group='Privacy';Default=$false;Advanced=$true;Desc='May disable camera access for apps; video calls can stop working.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam';Name='Value';Type='String';Value='Deny'})},
 [pscustomobject]@{Id='t613_microphone';Name='Restrict app access to microphone';Group='Privacy';Default=$false;Advanced=$true;Desc='Can stop voice chat and recordings in affected apps.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone';Name='Value';Type='String';Value='Deny'})},
 [pscustomobject]@{Id='t613_location';Name='Restrict app access to location';Group='Privacy';Default=$false;Advanced=$true;Desc='May disable location-based app features.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location';Name='Value';Type='String';Value='Deny'})},
 [pscustomobject]@{Id='t613_contacts';Name='Restrict app access to contacts';Group='Privacy';Default=$false;Advanced=$true;Desc='Blocks supported apps from reading contacts.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\contacts';Name='Value';Type='String';Value='Deny'})},
 [pscustomobject]@{Id='t613_calendar';Name='Restrict app access to calendar';Group='Privacy';Default=$false;Advanced=$true;Desc='Blocks supported apps from reading calendar data.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appointments';Name='Value';Type='String';Value='Deny'})},
 [pscustomobject]@{Id='t613_callhistory';Name='Restrict app access to call history';Group='Privacy';Default=$false;Advanced=$true;Desc='Restricts call-history access on supported devices.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCallHistory';Name='Value';Type='String';Value='Deny'})},
 [pscustomobject]@{Id='t613_email';Name='Restrict app access to email';Group='Privacy';Default=$false;Advanced=$true;Desc='May prevent supported apps from reading account email data.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\email';Name='Value';Type='String';Value='Deny'})},
 [pscustomobject]@{Id='t613_accountinfo';Name='Restrict app access to account information';Group='Privacy';Default=$false;Advanced=$true;Desc='Limits user account-information access for affected apps.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userAccountInformation';Name='Value';Type='String';Value='Deny'})},
 [pscustomobject]@{Id='t613_notificationsaccess';Name='Restrict app notification access';Group='Privacy';Default=$false;Advanced=$true;Desc='May disable notification-reading functionality in supported apps.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userNotificationListener';Name='Value';Type='String';Value='Deny'})},
 [pscustomobject]@{Id='t613_appdiagnostics';Name='Restrict app diagnostic information';Group='Privacy';Default=$false;Advanced=$true;Desc='Limits apps reading diagnostic details about other apps.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appDiagnostics';Name='Value';Type='String';Value='Deny'})},
 [pscustomobject]@{Id='t613_documents';Name='Restrict app access to Documents library';Group='Privacy';Default=$false;Advanced=$true;Desc='May block document access for supported Store apps.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\documentsLibrary';Name='Value';Type='String';Value='Deny'})},
 [pscustomobject]@{Id='t613_pictures';Name='Restrict app access to Pictures library';Group='Privacy';Default=$false;Advanced=$true;Desc='May block photo access for supported Store apps.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\picturesLibrary';Name='Value';Type='String';Value='Deny'})},
 [pscustomobject]@{Id='t613_videos';Name='Restrict app access to Videos library';Group='Privacy';Default=$false;Advanced=$true;Desc='May block video-library access for supported Store apps.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\videosLibrary';Name='Value';Type='String';Value='Deny'})},
 [pscustomobject]@{Id='t613_music';Name='Restrict app access to Music library';Group='Privacy';Default=$false;Advanced=$true;Desc='May block music-library access for supported Store apps.';Changes=@(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\musicLibrary';Name='Value';Type='String';Value='Deny'})}
)

$Tweaks = @($Tweaks | Sort-Object Group, Name)

function Snapshot([array]$changes) {
 $out=@()
 foreach($c in $changes) {
  $exists=$false;$v=$null;$k=$null
  try { if(Test-Path -LiteralPath $c.Path) { $key=Get-Item -LiteralPath $c.Path; if($key.GetValueNames() -contains $c.Name) {$exists=$true;$v=$key.GetValue($c.Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);$k=[string]$key.GetValueKind($c.Name)} } } catch {}
  $out += [pscustomobject]@{Path=$c.Path;Name=$c.Name;Exists=$exists;Value=$v;Kind=$k}
 }
 return ,$out
}
function ApplyValue($c) {
 if(-not(Test-Path -LiteralPath $c.Path)){New-Item -Path $c.Path -Force -ErrorAction Stop|Out-Null}
 New-ItemProperty -LiteralPath $c.Path -Name $c.Name -PropertyType $c.Type -Value $c.Value -Force -ErrorAction Stop|Out-Null
}
function UndoSnapshot([array]$snap) {
 foreach($s in $snap) { try {
  if($s.Exists) { if(-not(Test-Path -LiteralPath $s.Path)){New-Item -Path $s.Path -Force|Out-Null};$kind=if($s.Kind){[string]$s.Kind}else{"String"};New-ItemProperty -LiteralPath $s.Path -Name $s.Name -PropertyType $kind -Value $s.Value -Force|Out-Null }
  elseif(Test-Path -LiteralPath $s.Path){Remove-ItemProperty -LiteralPath $s.Path -Name $s.Name -ErrorAction SilentlyContinue}
 } catch {Log "Undo issue: $($_.Exception.Message)"} }
}
function RestorePoint {
 try { Checkpoint-Computer -Description "Tay Tweaks safety point" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop; return $true }
 catch { Log "Restore point failed: $($_.Exception.Message)";[System.Windows.Forms.MessageBox]::Show("Windows could not create a restore point, so no tweaks will be applied.`r`nEnable System Protection for the Windows drive. Windows may also limit restore points to one per 24 hours.`r`n`r`n$($_.Exception.Message)","Restore point required","OK","Warning")|Out-Null;return $false }
}
function ShowOutput([string]$title,[string]$content) {
 $w=New-Object System.Windows.Forms.Form;$w.Text=$title;$w.Size=New-Object System.Drawing.Size(800,560);$w.StartPosition="CenterParent";$w.BackColor=[System.Drawing.Color]::FromArgb(8,8,10)
 $tb=New-Object System.Windows.Forms.TextBox;$tb.Multiline=$true;$tb.ReadOnly=$true;$tb.ScrollBars="Both";$tb.WordWrap=$false;$tb.Dock="Fill";$tb.Font=New-Object System.Drawing.Font("Consolas",9);$tb.BackColor=[System.Drawing.Color]::FromArgb(20,12,14);$tb.ForeColor=[System.Drawing.Color]::FromArgb(230,232,238);$tb.Text=$content;$w.Controls.Add($tb);[void]$w.ShowDialog($form)
}
function RunOutput([string]$title,[string]$cmd) { try {$o=& powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $cmd 2>&1|Out-String;ShowOutput $title $o} catch {ShowOutput $title $_.Exception.Message} }

# Load custom window icon when a companion ICO is present; EXE icon is embedded at build time.
$script:TayIconPath=Join-Path ([AppDomain]::CurrentDomain.BaseDirectory) 'TayTweaks.ico'
$form=New-Object System.Windows.Forms.Form;$form.Text="Tay Tweaks";try{if(Test-Path $script:TayIconPath){$form.Icon=New-Object System.Drawing.Icon($script:TayIconPath)}else{$exePath=[System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName;if([IO.Path]::GetFileName($exePath) -ieq 'TayTweaks.exe'){$form.Icon=[System.Drawing.Icon]::ExtractAssociatedIcon($exePath)}}}catch{};$form.Size=New-Object System.Drawing.Size(1150,835);$form.MinimumSize=New-Object System.Drawing.Size(1060,730);$form.StartPosition="CenterScreen";$form.WindowState="Normal";$form.MaximizeBox=$true;$form.MinimizeBox=$true;$form.BackColor=[System.Drawing.Color]::FromArgb(8,8,10);$form.ForeColor=[System.Drawing.Color]::FromArgb(235,238,244);$form.Font=New-Object System.Drawing.Font("Segoe UI",9)
# v7 design draft: custom frame replaces the OS caption, while retaining the ordinary WinForms backend.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class TayWindowNative {
 [DllImport("user32.dll")] public static extern bool ReleaseCapture();
 [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);
 [DllImport("user32.dll")] public static extern bool ShowScrollBar(IntPtr hwnd, int wBar, bool bShow);
}
'@
$form.FormBorderStyle=[Windows.Forms.FormBorderStyle]::None
$form.Padding=New-Object Windows.Forms.Padding(1)
$form.KeyPreview=$true
function SetTayWindowCorners {
 if(-not $form.IsHandleCreated){return}
 $radius=if($form.WindowState -eq [Windows.Forms.FormWindowState]::Maximized){0}else{12}
 if($form.Width -le 20 -or $form.Height -le 20){return}
 $path=New-Object Drawing.Drawing2D.GraphicsPath
 if($radius -le 0){$path.AddRectangle([Drawing.Rectangle]::new(0,0,$form.Width,$form.Height))}else{
  $d=$radius*2
  $path.AddArc(0,0,$d,$d,180,90);$path.AddArc(($form.Width-$d),0,$d,$d,270,90)
  $path.AddArc(($form.Width-$d),($form.Height-$d),$d,$d,0,90)
  $path.AddArc(0,($form.Height-$d),$d,$d,90,90);$path.CloseFigure()
 }
 $old=$form.Region;$form.Region=New-Object Drawing.Region($path);$path.Dispose();if($old){$old.Dispose()}
}
$form.Add_Shown({SetTayWindowCorners})
$form.Add_Resize({SetTayWindowCorners})
$script:TayDragWindow={
 param($sender,$e)
 if($e.Button -ne [Windows.Forms.MouseButtons]::Left){return}
 if($form.WindowState -eq [Windows.Forms.FormWindowState]::Maximized){return}
 [void][TayWindowNative]::ReleaseCapture()
 [void][TayWindowNative]::SendMessage($form.Handle,0xA1,[IntPtr]2,[IntPtr]::Zero)
}
function AddTayWindowDot([string]$action,[Drawing.Color]$color,[int]$x,[string]$symbol) {
 $btn=New-Object Windows.Forms.Button
 $btn.Name='TayFrame'+$action;$btn.Text='';$btn.Tag=$color
 $btn.Location=[Drawing.Point]::new($x,28);$btn.Size=[Drawing.Size]::new(16,16)
 $btn.FlatStyle='Flat';$btn.FlatAppearance.BorderSize=0;$btn.BackColor=$color
 $btn.ForeColor=[Drawing.Color]::FromArgb(35,35,45);$btn.Font=New-Object Drawing.Font('Segoe UI',8,[Drawing.FontStyle]::Bold)
 $btn.Add_MouseEnter({$original=[Drawing.Color]$this.Tag;$this.BackColor=[Drawing.Color]::FromArgb([int]($original.R*0.82),[int]($original.G*0.82),[int]($original.B*0.82));$this.Text=[string]$this.AccessibleDescription})
 $btn.Add_MouseLeave({$this.BackColor=[Drawing.Color]$this.Tag;$this.Text=''})
 $btn.AccessibleDescription=$symbol
 $btn.Add_Click({
  switch($this.Name){
   'TayFrameClose' {$form.Close()}
   'TayFrameMinimize' {$form.WindowState=[Windows.Forms.FormWindowState]::Minimized}
   'TayFrameMaximize' {if($form.WindowState -eq [Windows.Forms.FormWindowState]::Maximized){$form.WindowState=[Windows.Forms.FormWindowState]::Normal}else{$form.WindowState=[Windows.Forms.FormWindowState]::Maximized}}
  }
 })
 $head.Controls.Add($btn)
 return $btn
}
$head=New-Object System.Windows.Forms.Panel;$head.Dock="Top";$head.Height=84;$head.BackColor=[System.Drawing.Color]::FromArgb(16,16,26);$form.Controls.Add($head)
$ttl=New-Object System.Windows.Forms.Label;$ttl.Text="Tay Tweaks";$ttl.Font=New-Object System.Drawing.Font("Segoe UI",20,[System.Drawing.FontStyle]::Bold);$ttl.ForeColor=[System.Drawing.Color]::FromArgb(255,92,35);$ttl.Location=[System.Drawing.Point]::new(130,12);$ttl.AutoSize=$true;$head.Controls.Add($ttl)
$sub=New-Object System.Windows.Forms.Label;$sub.Text="Your performance dashboard  •  System tools  •  Gaming settings";$sub.ForeColor=[System.Drawing.Color]::FromArgb(190,195,207);$sub.Location=[System.Drawing.Point]::new(131,53);$sub.AutoSize=$true;$head.Controls.Add($sub)
# macOS-inspired traffic-light window buttons; dot controls remain separate from page styling.
$frameClose=AddTayWindowDot 'Close' ([Drawing.Color]::FromArgb(255,95,86)) 23 '×'
$frameMin=AddTayWindowDot 'Minimize' ([Drawing.Color]::FromArgb(255,189,46)) 48 '−'
$frameMax=AddTayWindowDot 'Maximize' ([Drawing.Color]::FromArgb(39,201,63)) 73 '+'
$head.Add_MouseDown($script:TayDragWindow)
$ttl.Add_MouseDown($script:TayDragWindow)
$sub.Add_MouseDown($script:TayDragWindow)
$head.Add_DoubleClick({if($form.WindowState -eq [Windows.Forms.FormWindowState]::Maximized){$form.WindowState=[Windows.Forms.FormWindowState]::Normal}else{$form.WindowState=[Windows.Forms.FormWindowState]::Maximized}})
# Bottom-right resize grip, while respecting the window's MinimumSize.
$resizeGrip=New-Object Windows.Forms.Panel;$resizeGrip.Size=[Drawing.Size]::new(19,19);$resizeGrip.Anchor='Bottom,Right';$resizeGrip.Location=[Drawing.Point]::new(($form.ClientSize.Width-21),($form.ClientSize.Height-21))
$resizeGrip.Cursor=[Windows.Forms.Cursors]::SizeNWSE;$resizeGrip.BackColor=[Drawing.Color]::Transparent;$form.Controls.Add($resizeGrip);$resizeGrip.BringToFront()
$resizeGrip.Add_MouseDown({param($sender,$e);if($e.Button -eq [Windows.Forms.MouseButtons]::Left -and $form.WindowState -eq [Windows.Forms.FormWindowState]::Normal){[void][TayWindowNative]::ReleaseCapture();[void][TayWindowNative]::SendMessage($form.Handle,0xA1,[IntPtr]17,[IntPtr]::Zero)}})
$tabs=New-Object System.Windows.Forms.TabControl;$tabs.Location=[System.Drawing.Point]::new(18,105);$tabs.Size=New-Object System.Drawing.Size(1048,570);$tabs.Anchor="Top,Bottom,Left,Right";$form.Controls.Add($tabs)
function Tab([string]$name){$p=New-Object System.Windows.Forms.TabPage;$p.Text=$name;$p.BackColor=[System.Drawing.Color]::FromArgb(12,10,12);$p.ForeColor=[System.Drawing.Color]::FromArgb(235,238,244);[void]$tabs.TabPages.Add($p);return $p}
$homeTab=Tab "Home";$tweakTab=Tab "Tweaks";$boostTab=Tab "Game Boost";$usageTab=Tab "Usage";$cleanTab=Tab "Cleanup";$diagTab=Tab "Diagnostics";$netTab=Tab "Network";$aboutTab=Tab "More"
$advancedTab=Tab "CPU / RAM / GPU"
$inputTab=Tab "Keyboard / Input"
$filterTab=Tab "FilterKeys Pro"
$tcpTab=Tab "TCP / Network"
$settingsTab=Tab "Settings"
# Device-specific detection is read-only. Display changes are tested by Windows, not guessed from vendor.
$script:HardwareProfile=$null
function GetTayHardwareProfile {
 $os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
 $cpu=Get-CimInstance Win32_Processor -ErrorAction Stop|Select-Object -First 1
 $gpu=@(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
 $memory=[math]::Round(([double]$os.TotalVisibleMemorySize/1MB),1)
 $graphics=@($gpu|ForEach-Object { [pscustomobject]@{Name=[string]$_.Name;Driver=[string]$_.DriverVersion;Status=[string]$_.Status} })
 return [pscustomobject]@{Windows=[string]$os.Caption;Build=[string]$os.BuildNumber;CPU=[string]$cpu.Name;RAM_GB=$memory;GPU=$graphics;Detected=(Get-Date)}
}
function TestTayInternet {
 try {
  $request=[System.Net.HttpWebRequest]::Create('https://raw.githubusercontent.com/Tayegandev/Tay-Tweaks/main/latest.json')
  $request.Method='HEAD';$request.Timeout=3500;$request.ReadWriteTimeout=3500;$request.UserAgent='TayTweaks-Connectivity/6.1.5'
  $response=$request.GetResponse();try {return [int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -lt 400}finally{$response.Close()}
 }catch{return $false}
}
# v7: Display Manager removed at user request; Windows Display Settings remain available through Windows.
$advancedTab.AutoScroll=$true
$advIntro=New-Object System.Windows.Forms.Label
$advIntro.Text='ADVANCED PERFORMANCE LAB'
$advIntro.Location=[System.Drawing.Point]::new(22,18)
$advIntro.Size=[System.Drawing.Size]::new(760,34)
$advIntro.Font=New-Object System.Drawing.Font('Segoe UI',17,[System.Drawing.FontStyle]::Bold)
$advIntro.ForeColor=[System.Drawing.Color]::Orange
$advancedTab.Controls.Add($advIntro)
$advHelp=New-Object System.Windows.Forms.Label
$advHelp.Text='Supported CPU, RAM and GPU controls. Changes are optional; thermal safeguards remain active. Plug in your PC for the power plan.'
$advHelp.Location=[System.Drawing.Point]::new(24,58)
$advHelp.Size=[System.Drawing.Size]::new(790,48)
$advHelp.ForeColor=[System.Drawing.Color]::Gainsboro
$advancedTab.Controls.Add($advHelp)
function AdvButton([string]$name,[int]$x,[int]$y,[scriptblock]$action){
 $b=New-Object System.Windows.Forms.Button;$b.Text=$name;$b.Location=[System.Drawing.Point]::new($x,$y);$b.Size=[System.Drawing.Size]::new(365,39);$b.FlatStyle='Flat';$b.FlatAppearance.BorderSize=0;$b.BackColor=[System.Drawing.Color]::FromArgb(255,92,35);$b.ForeColor=[System.Drawing.Color]::Black;$b.Font=New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold);$b.Add_Click($action);$advancedTab.Controls.Add($b)
}
function AdvSection([string]$name,[int]$y){$l=New-Object System.Windows.Forms.Label;$l.Text=$name;$l.Location=[System.Drawing.Point]::new(24,$y);$l.Size=[System.Drawing.Size]::new(770,27);$l.Font=New-Object System.Drawing.Font('Segoe UI',12,[System.Drawing.FontStyle]::Bold);$l.ForeColor=[System.Drawing.Color]::FromArgb(255,168,99);$advancedTab.Controls.Add($l)}
function PowercfgRun([string[]]$arguments){
 $output=& powercfg.exe @arguments 2>&1 | Out-String
 if($LASTEXITCODE -ne 0){throw "powercfg $($arguments -join ' ') failed: $output"}
 return $output
}
$script:TayPowerPlanFile=Join-Path $DataDir 'power-plan-state.json'
AdvSection 'CPU + CUSTOM POWER PLAN' 115
AdvButton 'Activate Tay MAX Performance (AC)' 24 148 {
 try {
  $answer=[System.Windows.Forms.MessageBox]::Show('Create and activate Tay MAX Performance? This clones Windows High Performance, keeps maximum processor state at 100%, reduces PCIe power saving and preserves thermal protection. It may use more electricity and produce more heat.','Tay MAX Performance','YesNo','Warning')
  if($answer -ne 'Yes'){return}
  $active=PowercfgRun @('/getactivescheme')
  $previous=[regex]::Match($active,'[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}').Value
  if(-not $previous){throw 'Could not read your current power plan.'}
  $duplicate=PowercfgRun @('/duplicatescheme','8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c')
  $guid=[regex]::Match($duplicate,'[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}').Value
  if(-not $guid){throw "Could not create new power plan: $duplicate"}
  try {
   [void](PowercfgRun @('/changename',$guid,'Tay MAX Performance','Tay Tweaks high performance AC profile; thermal safeguards enabled'))
   [void](PowercfgRun @('/setacvalueindex',$guid,'SUB_PROCESSOR','PROCTHROTTLEMAX','100'))
   [void](PowercfgRun @('/setacvalueindex',$guid,'SUB_PROCESSOR','PROCTHROTTLEMIN','5'))
   [void](PowercfgRun @('/setacvalueindex',$guid,'SUB_PCIEXPRESS','ASPM','0'))
   [void](PowercfgRun @('/setactive',$guid))
  } catch { & powercfg.exe /delete $guid 2>$null | Out-Null;throw }
  [pscustomobject]@{Previous=$previous;Created=$guid;Date=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $script:TayPowerPlanFile -Encoding UTF8
  Log "Activated Tay MAX Performance $guid (previous $previous)"
  [System.Windows.Forms.MessageBox]::Show('Tay MAX Performance is now active. It does not bypass CPU thermal safeguards. The prior plan is saved for restore.','Tay Tweaks')|Out-Null
 }catch{Log "Power plan failed: $($_.Exception.Message)";[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Power plan error','OK','Error')|Out-Null}
}
AdvButton 'Restore previous power plan' 408 148 {
 try {
  if(-not(Test-Path -LiteralPath $script:TayPowerPlanFile)){throw 'No previous Tay power plan backup found.'}
  $state=Get-Content -LiteralPath $script:TayPowerPlanFile -Raw|ConvertFrom-Json
  [void](PowercfgRun @('/setactive',[string]$state.Previous))
  Log "Restored previous power plan $($state.Previous)"
  [System.Windows.Forms.MessageBox]::Show('Your previous power plan is active again.','Tay Tweaks')|Out-Null
 }catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Restore error','OK','Error')|Out-Null}
}
AdvButton 'CPU clocks / core report' 24 196 {try{$cpu=Get-CimInstance Win32_Processor|Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,CurrentClockSpeed,MaxClockSpeed,LoadPercentage;ShowOutput 'CPU clocks' ($cpu|Format-List|Out-String)}catch{ShowOutput 'CPU error' $_.Exception.Message}}
AdvButton 'Power plan settings / status' 408 196 {try{ShowOutput 'Power plan' ((& powercfg.exe /getactivescheme 2>&1|Out-String)+"`r`n"+(& powercfg.exe /list 2>&1|Out-String))}catch{ShowOutput 'Power error' $_.Exception.Message}}
AdvSection 'RAM + MEMORY' 250
AdvButton 'RAM hardware + available memory' 24 283 {try{$ram=Get-CimInstance Win32_PhysicalMemory|Select-Object Manufacturer,Capacity,Speed,ConfiguredClockSpeed; $os=Get-CimInstance Win32_OperatingSystem;ShowOutput 'RAM report' ("Available RAM: $([math]::Round($os.FreePhysicalMemory/1MB,2)) GB`r`nTotal RAM: $([math]::Round($os.TotalVisibleMemorySize/1MB,2)) GB`r`n`r`n"+($ram|Format-Table -AutoSize|Out-String))}catch{ShowOutput 'RAM error' $_.Exception.Message}}
AdvButton 'Open startup apps (free RAM)' 408 283 {Start-Process 'ms-settings:startupapps'}
AdvButton 'Top memory-consuming processes' 24 331 {try{ShowOutput 'Top RAM processes' (Get-Process|Sort-Object WorkingSet64 -Descending|Select-Object -First 25 ProcessName,Id,@{N='RAM_MB';E={[math]::Round($_.WorkingSet64/1MB)}}|Format-Table -AutoSize|Out-String)}catch{ShowOutput 'RAM error' $_.Exception.Message}}
AdvButton 'Open virtual memory settings' 408 331 {Start-Process SystemPropertiesAdvanced.exe}
AdvSection 'GPU + GRAPHICS' 385
AdvButton 'GPU driver / adapter report' 24 418 {try{ShowOutput 'GPU report' (Get-CimInstance Win32_VideoController|Select-Object Name,DriverVersion,AdapterRAM,VideoProcessor,CurrentHorizontalResolution,CurrentVerticalResolution|Format-List|Out-String)}catch{ShowOutput 'GPU error' $_.Exception.Message}}
AdvButton 'Windows graphics preferences' 408 418 {Start-Process 'ms-settings:display-advancedgraphics'}
AdvButton 'Set game EXE to High Performance GPU' 24 466 {
 $picker=New-Object System.Windows.Forms.OpenFileDialog;$picker.Filter='Executable (*.exe)|*.exe';$picker.Title='Choose a game executable'
 if($picker.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){return}
 try {
  $path=$picker.FileName
  $key='HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
  if(-not(Test-Path -LiteralPath $key)){New-Item -Path $key -Force -ErrorAction Stop|Out-Null}
  New-ItemProperty -LiteralPath $key -Name $path -PropertyType String -Value 'GpuPreference=2;' -Force -ErrorAction Stop|Out-Null
  Log "Requested high-performance graphics preference for $path"
  [System.Windows.Forms.MessageBox]::Show('Windows high-performance GPU preference saved for this executable. On a single-GPU system, this may not change performance.','GPU preference')|Out-Null
 }catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'GPU error','OK','Error')|Out-Null}
}
AdvButton 'Open Game Mode settings' 408 466 {Start-Process 'ms-settings:gaming-gamemode'}
$advancedTab.AutoScrollMinSize=[System.Drawing.Size]::new(810,550)
# Sidebar navigation replaces the default horizontal tab strip.
$tabs.Appearance='FlatButtons';$tabs.ItemSize=[System.Drawing.Size]::new(0,1);$tabs.SizeMode='Fixed'
$tabs.Location=[System.Drawing.Point]::new(204,94);$tabs.Size=[System.Drawing.Size]::new(917,572)
$nav=New-Object System.Windows.Forms.Panel;$nav.Location=[System.Drawing.Point]::new(0,84);$nav.Size=[System.Drawing.Size]::new(194,590);$nav.AutoScroll=$true;$nav.Anchor='Top,Bottom,Left';$nav.BackColor=[System.Drawing.Color]::FromArgb(21,17,20);$form.Controls.Add($nav)
$navY=12
foreach($page in @($tabs.TabPages)){
 $b=New-Object System.Windows.Forms.Button;$b.Text='  '+$page.Text;$b.Tag=$page;$b.TextAlign='MiddleLeft';$b.Location=[System.Drawing.Point]::new(8,$navY);$b.Size=[System.Drawing.Size]::new(175,39);$b.FlatStyle='Flat';$b.FlatAppearance.BorderSize=0;$b.BackColor=[System.Drawing.Color]::FromArgb(32,25,28);$b.ForeColor=[System.Drawing.Color]::FromArgb(255,142,75);$b.Font=New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold);$b.Add_Click({$tabs.SelectedTab=$this.Tag});$nav.Controls.Add($b);$navY+=45
}
$nav.AutoScrollMinSize=[System.Drawing.Size]::new(185,$navY+8)
# Game Boost: temporary per-process priority only. Windows still manages memory allocation.
$boostTitle=New-Object System.Windows.Forms.Label;$boostTitle.Text="TEMPORARY GAME PRIORITY";$boostTitle.Location=[System.Drawing.Point]::new(24,22);$boostTitle.Size=[System.Drawing.Size]::new(700,34);$boostTitle.Font=New-Object System.Drawing.Font("Segoe UI",18,[System.Drawing.FontStyle]::Bold);$boostTitle.ForeColor=[System.Drawing.Color]::FromArgb(255,92,35);$boostTab.Controls.Add($boostTitle)
$boostInfo=New-Object System.Windows.Forms.Label;$boostInfo.Text="Choose a running game and set High priority while it runs. This is temporary and resets when the process closes. Do not use Realtime priority. Windows automatically manages RAM; forcing extra RAM allocation can make crashes and stutters worse.";$boostInfo.Location=[System.Drawing.Point]::new(26,68);$boostInfo.Size=[System.Drawing.Size]::new(930,64);$boostInfo.ForeColor=[System.Drawing.Color]::FromArgb(205,205,215);$boostTab.Controls.Add($boostInfo)
$gameList=New-Object System.Windows.Forms.ComboBox;$gameList.Location=[System.Drawing.Point]::new(28,155);$gameList.Size=[System.Drawing.Size]::new(470,36);$gameList.DropDownStyle='DropDownList';$gameList.Font=New-Object System.Drawing.Font("Segoe UI",11);$boostTab.Controls.Add($gameList)
$gameStatus=New-Object System.Windows.Forms.Label;$gameStatus.Location=[System.Drawing.Point]::new(28,270);$gameStatus.Size=[System.Drawing.Size]::new(900,60);$gameStatus.ForeColor=[System.Drawing.Color]::FromArgb(255,145,90);$gameStatus.Font=New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold);$boostTab.Controls.Add($gameStatus)
$refreshGames=New-Object System.Windows.Forms.Button;$refreshGames.Text="REFRESH RUNNING APPS";$refreshGames.Location=[System.Drawing.Point]::new(520,150);$refreshGames.Size=[System.Drawing.Size]::new(210,42);$refreshGames.BackColor=[System.Drawing.Color]::FromArgb(255,92,35);$refreshGames.ForeColor=[System.Drawing.Color]::Black;$refreshGames.FlatStyle='Flat';$boostTab.Controls.Add($refreshGames)
$setHigh=New-Object System.Windows.Forms.Button;$setHigh.Text="SET HIGH PRIORITY";$setHigh.Location=[System.Drawing.Point]::new(28,215);$setHigh.Size=[System.Drawing.Size]::new(220,44);$setHigh.BackColor=[System.Drawing.Color]::FromArgb(255,92,35);$setHigh.ForeColor=[System.Drawing.Color]::Black;$setHigh.FlatStyle='Flat';$boostTab.Controls.Add($setHigh)
$setNormal=New-Object System.Windows.Forms.Button;$setNormal.Text="RESTORE NORMAL PRIORITY";$setNormal.Location=[System.Drawing.Point]::new(265,215);$setNormal.Size=[System.Drawing.Size]::new(250,44);$setNormal.BackColor=[System.Drawing.Color]::FromArgb(55,35,38);$setNormal.ForeColor=[System.Drawing.Color]::White;$setNormal.FlatStyle='Flat';$boostTab.Controls.Add($setNormal)
$refreshGames.Add_Click({$gameList.Items.Clear();$procs=@(Get-Process -ErrorAction SilentlyContinue|Sort-Object ProcessName,Id);foreach($pr in $procs){[void]$gameList.Items.Add(("{0}  (PID {1})" -f $pr.ProcessName,$pr.Id))};if($gameList.Items.Count -gt 0){$gameList.SelectedIndex=0};$gameStatus.Text="Found $($gameList.Items.Count) running processes. Select your game."})
$setHigh.Add_Click({if($gameList.SelectedItem -notmatch '\(PID (\d+)\)'){ $gameStatus.Text="Select a running process first.";return };$pidGame=[int]$Matches[1];try{$pr=Get-Process -Id $pidGame -ErrorAction Stop;if($pr.ProcessName -match '^(System|csrss|wininit|services|lsass|smss|winlogon|dwm|explorer)$'){throw "This Windows process is protected from priority changes."};$pr.PriorityClass=[System.Diagnostics.ProcessPriorityClass]::High;$gameStatus.Text="$($pr.ProcessName) is now High priority. This is temporary; monitor stability and temperatures.";Log "Set High priority for $($pr.ProcessName) PID $pidGame"}catch{$gameStatus.Text="Could not change priority: $($_.Exception.Message)"}})
$setNormal.Add_Click({if($gameList.SelectedItem -notmatch '\(PID (\d+)\)'){ $gameStatus.Text="Select a running process first.";return };$pidGame=[int]$Matches[1];try{$pr=Get-Process -Id $pidGame -ErrorAction Stop;$pr.PriorityClass=[System.Diagnostics.ProcessPriorityClass]::Normal;$gameStatus.Text="$($pr.ProcessName) restored to Normal priority.";Log "Restored Normal priority for $($pr.ProcessName) PID $pidGame"}catch{$gameStatus.Text="Could not restore priority: $($_.Exception.Message)"}})
$refreshGames.PerformClick()

$homeTitle=New-Object System.Windows.Forms.Label;$homeTitle.Text="TAY TWEAKS";$homeTitle.Location=[System.Drawing.Point]::new(28,24);$homeTitle.Size=[System.Drawing.Size]::new(800,50);$homeTitle.Font=New-Object System.Drawing.Font("Segoe UI",26,[System.Drawing.FontStyle]::Bold);$homeTitle.ForeColor=[System.Drawing.Color]::FromArgb(255,92,35);$homeTab.Controls.Add($homeTitle)
$homeClock=New-Object System.Windows.Forms.Label;$homeClock.Text=(Get-Date -Format "HH:mm:ss");$homeClock.Location=[System.Drawing.Point]::new(28,88);$homeClock.Size=[System.Drawing.Size]::new(800,100);$homeClock.Font=New-Object System.Drawing.Font("Segoe UI",48,[System.Drawing.FontStyle]::Bold);$homeClock.ForeColor=[System.Drawing.Color]::FromArgb(245,245,248);$homeTab.Controls.Add($homeClock)
$homeDate=New-Object System.Windows.Forms.Label;$homeDate.Text=(Get-Date -Format "dddd, dd MMMM yyyy");$homeDate.Location=[System.Drawing.Point]::new(34,190);$homeDate.Size=[System.Drawing.Size]::new(800,32);$homeDate.Font=New-Object System.Drawing.Font("Segoe UI",14);$homeDate.ForeColor=[System.Drawing.Color]::FromArgb(255,125,55);$homeTab.Controls.Add($homeDate)
$homeStatus=New-Object System.Windows.Forms.Label;$homeStatus.Text="READY  •  Restore point before changes  •  Undo available";$homeStatus.Location=[System.Drawing.Point]::new(34,246);$homeStatus.Size=[System.Drawing.Size]::new(850,32);$homeStatus.Font=New-Object System.Drawing.Font("Segoe UI",12,[System.Drawing.FontStyle]::Bold);$homeStatus.ForeColor=[System.Drawing.Color]::FromArgb(190,195,207);$homeTab.Controls.Add($homeStatus)
$homePrevious=New-Object System.Windows.Forms.Label;$homePrevious.Text="PREVIOUSLY APPLIED TWEAKS`r`nNo saved tweak session yet.";$homePrevious.Location=[System.Drawing.Point]::new(34,300);$homePrevious.Size=[System.Drawing.Size]::new(850,210);$homePrevious.Font=New-Object System.Drawing.Font("Segoe UI",11);$homePrevious.ForeColor=[System.Drawing.Color]::FromArgb(235,238,244);$homeTab.Controls.Add($homePrevious)
try{if(Test-Path $AppliedFile){$last=Get-Content $AppliedFile -Raw|ConvertFrom-Json;$names=@();foreach($id in @($last.Tweaks)){$t=$Tweaks|Where-Object{$_.Id -eq [string]$id}|Select-Object -First 1;if($t){$names+="• "+$t.Name}};if($names.Count -gt 0){$homePrevious.Text="PREVIOUSLY APPLIED / SELECTED`r`n"+($names -join "`r`n")}}}catch{}
$homeClockTimer=New-Object System.Windows.Forms.Timer;$homeClockTimer.Interval=1000;$homeClockTimer.Add_Tick({$homeClock.Text=Get-Date -Format "HH:mm:ss";$homeDate.Text=Get-Date -Format "dddd, dd MMMM yyyy"});$homeClockTimer.Start()
$tweakPanel=New-Object System.Windows.Forms.Panel;$tweakPanel.Dock="Fill";$tweakPanel.AutoScroll=$true;$tweakTab.Controls.Add($tweakPanel)
$note=New-Object System.Windows.Forms.Label;$note.Text="Select settings. A restore point and registry backup are required before applying changes."; $note.Location=[System.Drawing.Point]::new(18,14);$note.Size=New-Object System.Drawing.Size(880,30);$note.ForeColor=[System.Drawing.Color]::FromArgb(255,115,65);$tweakPanel.Controls.Add($note)
$checks=@{};$y=106;$lastGroup=""
foreach($t in $Tweaks){
 if($t.Group -ne $lastGroup){$gh=New-Object System.Windows.Forms.Label;$gh.Text=("  " + $t.Group.ToUpper());$gh.Location=[System.Drawing.Point]::new(18,$y);$gh.Size=New-Object System.Drawing.Size(900,25);$gh.BackColor=[System.Drawing.Color]::FromArgb(38,13,17);$gh.ForeColor=[System.Drawing.Color]::FromArgb(255,125,55);$gh.Font=New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold);$tweakPanel.Controls.Add($gh);$y+=30;$lastGroup=$t.Group}
 $cb=New-Object System.Windows.Forms.CheckBox;$cb.Text=$t.Name;$cb.Checked=$t.Default;$cb.Location=[System.Drawing.Point]::new(20,$y);$cb.Size=New-Object System.Drawing.Size(870,24);$cb.Font=New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold);$cb.ForeColor=if($t.Advanced){[System.Drawing.Color]::FromArgb(255,190,95)}else{[System.Drawing.Color]::FromArgb(255,72,45)};$tweakPanel.Controls.Add($cb);$checks[$t.Id]=$cb
 $d=New-Object System.Windows.Forms.Label;$d.Text=$t.Desc;$d.Location=[System.Drawing.Point]::new(42,($y+24));$d.Size=New-Object System.Drawing.Size(850,34);$d.ForeColor=[System.Drawing.Color]::FromArgb(195,199,210);$tweakPanel.Controls.Add($d);$y+=78
}
try { if(Test-Path $AppliedFile){$saved=Get-Content $AppliedFile -Raw | ConvertFrom-Json; foreach($id in @($saved.Tweaks)){if($checks.ContainsKey([string]$id)){$checks[[string]$id].Checked=$true}}} } catch { Log "Could not load prior selected tweaks: $($_.Exception.Message)" }

# Presets only select checkboxes; the user must still review and click Apply.
$presetLabel=New-Object System.Windows.Forms.Label;$presetLabel.Text="QUICK PRESETS  •  select a profile, review the checked tweaks, then Apply";$presetLabel.Location=[System.Drawing.Point]::new(18,43);$presetLabel.Size=[System.Drawing.Size]::new(820,20);$presetLabel.ForeColor=[System.Drawing.Color]::FromArgb(255,115,65);$tweakPanel.Controls.Add($presetLabel)
function PresetButton([string]$label,[int]$x,[scriptblock]$action){$b=New-Object System.Windows.Forms.Button;$b.Text=$label;$b.Location=[System.Drawing.Point]::new($x,64);$b.Size=[System.Drawing.Size]::new(170,28);$b.FlatStyle="Flat";$b.FlatAppearance.BorderColor=[System.Drawing.Color]::FromArgb(255,72,45);$b.BackColor=[System.Drawing.Color]::FromArgb(32,13,15);$b.ForeColor=[System.Drawing.Color]::FromArgb(255,145,90);$b.Add_Click($action);$tweakPanel.Controls.Add($b)}
PresetButton "LIGHT" 18 { foreach($t in $Tweaks){$checks[$t.Id].Checked=($t.Id -in @('gamedvr','gamemode','transparency','visualfx','suggestions','gametips','searchhighlights','locktips','disablesoftlanding'))} }
PresetButton "MEDIUM" 198 { foreach($t in $Tweaks){$checks[$t.Id].Checked=($t.Id -in @('gamedvr','gamemode','transparency','visualfx','suggestions','gametips','searchhighlights','locktips','disablesoftlanding','privacyads','launchtracking','notifications','quickaccessrecent','quickaccessfrequent','taskbarwidgets','taskbarchat','disablewebsearch','disableconsumerfeatures','disablefeedback','disabletailored'))} }
PresetButton "PRO PERFORMANCE" 378 { foreach($t in $Tweaks){$checks[$t.Id].Checked=($t.Id -in @('gamedvr','gamemode','transparency','visualfx','suggestions','gametips','searchhighlights','locktips','disablesoftlanding','privacyads','launchtracking','notifications','quickaccessrecent','quickaccessfrequent','taskbarwidgets','taskbarchat','disablewebsearch','disableconsumerfeatures','disablefeedback','disabletailored','menuanimation','menushowdelay','taskview','searchbutton','disabletaskbarbadges','disablewindowshakes','disableappbackground','disableactivityhistory','disableactivityupload','disablecloudclipboard','disableclipboardsync','disabletaskbarflashing'))} }


# v7 Performance dashboard - use lightweight counters; enumerate hardware in a background job.
$usageTab.AutoScroll=$true
$usageIntro=New-Object Windows.Forms.Label;$usageIntro.Text='Performance';$usageIntro.Location=[Drawing.Point]::new(14,10);$usageIntro.Size=[Drawing.Size]::new(570,38);$usageIntro.Font=New-Object Drawing.Font('Segoe UI',19,[Drawing.FontStyle]::Bold);$usageTab.Controls.Add($usageIntro)
$usageSubtitle=New-Object Windows.Forms.Label;$usageSubtitle.Text='Live system readings and detected PC components';$usageSubtitle.Location=[Drawing.Point]::new(16,47);$usageSubtitle.Size=[Drawing.Size]::new(700,25);$usageSubtitle.ForeColor=[Drawing.Color]::Silver;$usageTab.Controls.Add($usageSubtitle)
$usageLabels=@{};$usageBars=@{};$usageGaugePanels=@{};$usageValues=@{};$script:usageGaugeValues=@{cpu=0;ram=0;gpu=0;cputemp=0};$script:usageAvailable=@{cpu=$false;ram=$false;gpu=$false;cputemp=$false}
$script:usageHistory=@{CPU=(New-Object System.Collections.ArrayList);GPU=(New-Object System.Collections.ArrayList);RAM=(New-Object System.Collections.ArrayList)}
function NewUsageCard([string]$key,[string]$caption,[int]$x,[int]$y) {
 $p=New-Object Windows.Forms.Panel;$p.Location=[Drawing.Point]::new($x,$y);$p.Size=[Drawing.Size]::new(264,168);$p.BackColor=[Drawing.Color]::FromArgb(20,21,34);$p.Tag='TayCard';$usageTab.Controls.Add($p);$usageGaugePanels[$key]=$p
 $heading=New-Object Windows.Forms.Label;$heading.Text=$caption;$heading.Location=[Drawing.Point]::new(18,13);$heading.Size=[Drawing.Size]::new(226,22);$heading.ForeColor=[Drawing.Color]::FromArgb(170,174,194);$heading.Font=New-Object Drawing.Font('Segoe UI',9,[Drawing.FontStyle]::Bold);$p.Controls.Add($heading)
 $big=New-Object Windows.Forms.Label;$big.Text='--%';$big.Location=[Drawing.Point]::new(18,43);$big.Size=[Drawing.Size]::new(225,58);$big.Font=New-Object Drawing.Font('Segoe UI',29,[Drawing.FontStyle]::Bold);$big.ForeColor=[Drawing.Color]::White;$p.Controls.Add($big);$usageValues[$key]=$big
 $detail=New-Object Windows.Forms.Label;$detail.Text='Waiting for sensor...';$detail.Location=[Drawing.Point]::new(18,104);$detail.Size=[Drawing.Size]::new(225,23);$detail.ForeColor=[Drawing.Color]::Silver;$p.Controls.Add($detail);$usageLabels[$key]=$detail
 $track=New-Object Windows.Forms.Panel;$track.Location=[Drawing.Point]::new(18,140);$track.Size=[Drawing.Size]::new(227,7);$track.BackColor=[Drawing.Color]::FromArgb(53,56,76);$p.Controls.Add($track)
 $fill=New-Object Windows.Forms.Panel;$fill.Location=[Drawing.Point]::new(0,0);$fill.Size=[Drawing.Size]::new(0,7);$fill.BackColor=[Drawing.Color]::FromArgb(138,95,255);$track.Controls.Add($fill);$usageBars[$key]=$fill
}
NewUsageCard 'cpu' 'CPU' 14 82
NewUsageCard 'gpu' 'GPU' 291 82
NewUsageCard 'ram' 'MEMORY' 568 82
$usageInfo=New-Object Windows.Forms.Panel;$usageInfo.Location=[Drawing.Point]::new(14,263);$usageInfo.Size=[Drawing.Size]::new(322,281);$usageInfo.BackColor=[Drawing.Color]::FromArgb(20,21,34);$usageInfo.Tag='TayCard';$usageTab.Controls.Add($usageInfo)
$sysTitle=New-Object Windows.Forms.Label;$sysTitle.Text='System';$sysTitle.Location=[Drawing.Point]::new(18,13);$sysTitle.Size=[Drawing.Size]::new(270,30);$sysTitle.Font=New-Object Drawing.Font('Segoe UI',13,[Drawing.FontStyle]::Bold);$usageInfo.Controls.Add($sysTitle)
$script:specLabels=@{}
$specRows=@(@('CPU',49),@('GPU',105),@('MEMORY',161),@('OS',217))
foreach($item in $specRows){
 $k=[string]$item[0];$y=[int]$item[1]
 $h=New-Object Windows.Forms.Label;$h.Text=$k;$h.Location=[Drawing.Point]::new(19,$y);$h.Size=[Drawing.Size]::new(284,19);$h.Font=New-Object Drawing.Font('Segoe UI',8,[Drawing.FontStyle]::Bold);$h.ForeColor=[Drawing.Color]::FromArgb(141,146,170);$usageInfo.Controls.Add($h)
 $v=New-Object Windows.Forms.Label;$v.Text='Detecting...';$v.Location=[Drawing.Point]::new(19,($y+19));$v.Size=[Drawing.Size]::new(284,36);$v.Font=New-Object Drawing.Font('Segoe UI',9);$v.ForeColor=[Drawing.Color]::White;$usageInfo.Controls.Add($v);$script:specLabels[$k]=$v
}
$usageChart=New-Object Windows.Forms.Panel;$usageChart.Location=[Drawing.Point]::new(349,263);$usageChart.Size=[Drawing.Size]::new(483,281);$usageChart.BackColor=[Drawing.Color]::FromArgb(20,21,34);$usageChart.Tag='TayCard';$usageTab.Controls.Add($usageChart)
$usageGraphTitle=New-Object Windows.Forms.Label;$usageGraphTitle.Text='Activity history';$usageGraphTitle.Location=[Drawing.Point]::new(19,13);$usageGraphTitle.Size=[Drawing.Size]::new(220,29);$usageGraphTitle.Font=New-Object Drawing.Font('Segoe UI',13,[Drawing.FontStyle]::Bold);$usageChart.Controls.Add($usageGraphTitle)
$usageChartChoice=New-Object Windows.Forms.ComboBox;$usageChartChoice.DropDownStyle='DropDownList';$usageChartChoice.Items.AddRange([object[]]@('CPU','GPU','RAM'));$usageChartChoice.SelectedIndex=0;$usageChartChoice.Location=[Drawing.Point]::new(353,14);$usageChartChoice.Size=[Drawing.Size]::new(110,28);$usageChart.Controls.Add($usageChartChoice)
$usageChart.Add_Paint({param($sender,$e)
 $g=$e.Graphics;$g.SmoothingMode='AntiAlias'
 $gridPen=New-Object Drawing.Pen([Drawing.Color]::FromArgb(47,50,69),1)
 for($i=0;$i -lt 5;$i++){$y=70+$i*46;$g.DrawLine($gridPen,17,$y,464,$y)}
 $samples=@($script:usageHistory[[string]$usageChartChoice.SelectedItem])
 if($samples.Count -gt 1){
  $accent=[Drawing.ColorTranslator]::FromHtml($script:Themes[$script:ThemeName]);$pen=New-Object Drawing.Pen($accent,2)
  $pts=New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
  for($i=0;$i -lt $samples.Count;$i++){$xx=18+($i*446.0/79);$yy=254-([double]$samples[$i]*1.84);$pts.Add([Drawing.PointF]::new([single]$xx,[single]$yy))}
  if($pts.Count -gt 1){$g.DrawLines($pen,$pts.ToArray())}
  $pen.Dispose()
 }
 $gridPen.Dispose()
})
$usageChartChoice.Add_SelectedIndexChanged({$usageChart.Invalidate()})
$usageFoot=New-Object Windows.Forms.Label;$usageFoot.Text='GPU and temperature readings depend on Windows driver support. Hardware details are read separately.';$usageFoot.Location=[Drawing.Point]::new(18,552);$usageFoot.Size=[Drawing.Size]::new(800,30);$usageFoot.ForeColor=[Drawing.Color]::Silver;$usageTab.Controls.Add($usageFoot)
$usageTab.AutoScrollMinSize=[Drawing.Size]::new(858,588)
function SetUsageReading([string]$key,[int]$value,[string]$description){
 $value=[math]::Max(0,[math]::Min(100,$value));$script:usageGaugeValues[$key]=$value;$script:usageAvailable[$key]=$true
 $usageLabels[$key].Text=$description;$usageValues[$key].Text="$value%";$usageBars[$key].Width=[int](227*$value/100)
 $series=switch($key){'cpu'{'CPU'}'gpu'{'GPU'}'ram'{'RAM'}default{''}}
 if($series){$hist=$script:usageHistory[$series];[void]$hist.Add($value);if($hist.Count -gt 80){$hist.RemoveAt(0)}}
}
$script:cpuCounter=$null;$script:memCounter=$null;$script:gpuCounters=@();$script:totalMemoryGB=0.0
try{$script:cpuCounter=[Diagnostics.PerformanceCounter]::new('Processor','% Processor Time','_Total');[void]$script:cpuCounter.NextValue()}catch{}
try{$script:memCounter=[Diagnostics.PerformanceCounter]::new('Memory','Available MBytes');[void]$script:memCounter.NextValue()}catch{}
try{$os0=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop;$script:totalMemoryGB=[math]::Round(([double]$os0.TotalVisibleMemorySize/1MB),1)}catch{}
try{$cat=[Diagnostics.PerformanceCounterCategory]::new('GPU Engine');foreach($inst in @($cat.GetInstanceNames() | Where-Object {$_ -match 'engtype_3D'})){try{$script:gpuCounters+=[Diagnostics.PerformanceCounter]::new('GPU Engine','Utilization Percentage',$inst)}catch{}}}catch{}
function UpdateUsage {
 try{if($script:cpuCounter){$n=[int][math]::Max(0,[math]::Min(100,$script:cpuCounter.NextValue()));SetUsageReading 'cpu' $n "$n% processor load"}else{$usageLabels['cpu'].Text='Counter unavailable'}}catch{$usageLabels['cpu'].Text='Counter unavailable'}
 try{if($script:memCounter -and $script:totalMemoryGB -gt 0){$freeMB=[double]$script:memCounter.NextValue();$usedGB=[math]::Max(0,$script:totalMemoryGB-($freeMB/1024));$pct=[int][math]::Max(0,[math]::Min(100,(100*$usedGB/$script:totalMemoryGB)));SetUsageReading 'ram' $pct ("{0:N1} / {1:N1} GB used" -f $usedGB,$script:totalMemoryGB)}else{$usageLabels['ram'].Text='Counter unavailable'}}catch{$usageLabels['ram'].Text='Counter unavailable'}
 try{if($script:gpuCounters.Count -gt 0){$sum=0.0;foreach($c in $script:gpuCounters){try{$sum+=[math]::Max(0,$c.NextValue())}catch{}};$n=[int][math]::Max(0,[math]::Min(100,$sum));SetUsageReading 'gpu' $n "$n% 3D engine (approx.)"}else{$usageLabels['gpu'].Text='3D counter unavailable';$usageValues['gpu'].Text='N/A'}}catch{$usageLabels['gpu'].Text='3D counter unavailable';$usageValues['gpu'].Text='N/A'}
 if($tabs.SelectedTab -eq $usageTab){$usageChart.Invalidate()}
}
$script:usageSpecsLoaded=$false;$script:specJob=$null
$specPoll=New-Object Windows.Forms.Timer;$specPoll.Interval=500
$specPoll.Add_Tick({
 if(-not $script:specJob){$specPoll.Stop();return}
 if($script:specJob.State -notin @('Completed','Failed','Stopped')){return}
 try{
  $data=Receive-Job -Job $script:specJob -ErrorAction Stop|Select-Object -First 1
  if($data){
   $script:specLabels['CPU'].Text=[string]$data.CPU
   $script:specLabels['GPU'].Text=[string]$data.GPU
   $script:specLabels['MEMORY'].Text=[string]$data.Memory
   $script:specLabels['OS'].Text=[string]$data.OS
   $script:usageSpecsLoaded=$true
  }else{throw 'Empty hardware result'}
 }catch{foreach($v in $script:specLabels.Values){$v.Text='Detection unavailable'};Log "Usage hardware discovery: $($_.Exception.Message)"}
 $specPoll.Stop();Remove-Job -Job $script:specJob -Force -ErrorAction SilentlyContinue;$script:specJob=$null
})
function UpdateUsageSpecs {
 if($script:usageSpecsLoaded -or $script:specJob){return}
 try{$script:specJob=Start-Job -ScriptBlock {
  $cpu='Unavailable';$gpu='Unavailable';$mem='Unavailable';$os='Unavailable'
  try{$c=Get-CimInstance Win32_Processor -ErrorAction Stop|Select-Object -First 1;if($c){$cpu=([string]$c.Name).Trim()}}catch{}
  try{$g=Get-CimInstance Win32_VideoController -ErrorAction Stop|Where-Object {$_.Name}|Select-Object -First 1;if($g){$gpu=([string]$g.Name).Trim()}}catch{}
  try{$o=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop;if($o){$os=[string]$o.Caption;if($o.TotalVisibleMemorySize){$mem=('{0:N1} GB' -f ([double]$o.TotalVisibleMemorySize/1MB))}}}catch{}
  [pscustomobject]@{CPU=$cpu;GPU=$gpu;Memory=$mem;OS=$os}
 };$specPoll.Start()}catch{Log "Usage hardware job failed: $($_.Exception.Message)";foreach($v in $script:specLabels.Values){$v.Text='Detection unavailable'}}
}
$usageTimer=New-Object Windows.Forms.Timer;$usageTimer.Interval=1400;$usageTimer.Add_Tick({UpdateUsage})
$usageTab.Add_Enter({UpdateUsageSpecs;UpdateUsage;$usageTimer.Start()})
$usageTab.Add_Leave({$usageTimer.Stop()})

# User settings and color themes
$script:SettingsFile=Join-Path $env:APPDATA 'TayTweaks\settings.json';$script:ThemeName='Royal Purple'
$script:Themes=@{'Tay Orange'='#FF7900';'Crimson Red'='#F04452';'Royal Purple'='#A66BFF';'Neon Green'='#48D978';'Ocean Blue'='#4B9FFF';'Midnight'='#9299AA';'Light'='#F28724';'Pure White'='#4B85E8';'Aurora Teal'='#37D7C5';'Electric Blue'='#448BFF'}
try{if(Test-Path $script:SettingsFile){$saved=Get-Content $script:SettingsFile -Raw|ConvertFrom-Json;if($script:Themes.ContainsKey([string]$saved.theme)){$script:ThemeName=[string]$saved.theme}}}catch{Log "Theme settings load: $($_.Exception.Message)"}
function SaveTheme {try{New-Item -ItemType Directory -Force -Path (Split-Path $script:SettingsFile)|Out-Null;@{theme=$script:ThemeName}|ConvertTo-Json|Set-Content -LiteralPath $script:SettingsFile -Encoding UTF8}catch{Log "Save theme: $($_.Exception.Message)"}}

# Smooth, consistent theme application across pages, cards, controls and navigation.
function SetTayRounded($control,[int]$radius=12) {
 try{
  $w=$control.Width;$h=$control.Height;if($w -lt 8 -or $h -lt 8){return}
  $r=[math]::Min($radius,[int]([math]::Min($w,$h)/2));$d=$r*2
  $p=New-Object Drawing.Drawing2D.GraphicsPath
  $p.AddArc(0,0,$d,$d,180,90);$p.AddArc(($w-$d),0,$d,$d,270,90)
  $p.AddArc(($w-$d),($h-$d),$d,$d,0,90);$p.AddArc(0,($h-$d),$d,$d,90,90)
  $p.CloseFigure();$control.Region=New-Object Drawing.Region($p);$p.Dispose()
 }catch{}
}
function HighlightTayNav {
 if(-not $script:Themes){return}
 $accent=[Drawing.ColorTranslator]::FromHtml($script:Themes[$script:ThemeName])
 $light=$script:ThemeName -in @('Light','Pure White')
 foreach($btn in @($nav.Controls)){
  if($btn -isnot [Windows.Forms.Button]){continue}
  $active=($btn.Tag -eq $tabs.SelectedTab)
  $btn.BackColor=if($active){$accent}elseif($light){[Drawing.Color]::White}else{[Drawing.Color]::FromArgb(26,26,42)}
  $btn.ForeColor=if($active){[Drawing.Color]::FromArgb(17,17,25)}elseif($light){[Drawing.Color]::FromArgb(38,42,55)}else{[Drawing.Color]::FromArgb(196,199,218)}
  $btn.FlatAppearance.BorderSize=0
  SetTayRounded $btn 10
 }
}
function ApplyTheme {
 $accent=[Drawing.ColorTranslator]::FromHtml($script:Themes[$script:ThemeName])
 $light=$script:ThemeName -in @('Light','Pure White')
 $base=if($light){[Drawing.Color]::FromArgb(244,246,252)}else{[Drawing.Color]::FromArgb(12,11,21)}
 $surface=if($light){[Drawing.Color]::White}else{[Drawing.Color]::FromArgb(21,21,35)}
 $fg=if($light){[Drawing.Color]::FromArgb(29,35,50)}else{[Drawing.Color]::FromArgb(240,241,250)}
 $muted=if($light){[Drawing.Color]::FromArgb(90,99,120)}else{[Drawing.Color]::FromArgb(159,165,189)}
 $form.BackColor=$base;$form.ForeColor=$fg
 $head.BackColor=$base;$nav.BackColor=$base;$ttl.ForeColor=$accent;$sub.ForeColor=$muted
 foreach($page in @($tabs.TabPages)){$page.BackColor=$base;$page.ForeColor=$fg}
 function StyleTayControls($parent){
  foreach($control in @($parent.Controls)){
   if($control -is [Windows.Forms.Button]){
    $control.FlatStyle='Flat';$control.FlatAppearance.BorderSize=0
    $secondary=($control.Text -match '(Restore|Undo|Exit|Cancel|Logs|Normal|Back|Reset)')
    $control.BackColor=if($secondary){$surface}else{$accent}
    $control.ForeColor=if($secondary){$fg}else{[Drawing.Color]::FromArgb(18,18,28)}
    if($control.Height -ge 25){SetTayRounded $control 12}
   }elseif($control -is [Windows.Forms.Label]){
    if($control -ne $ttl -and $control -ne $sub){$control.ForeColor=$fg}
   }elseif($control -is [Windows.Forms.Panel] -and $control.Tag -eq 'TayCard'){
    $control.BackColor=$surface;SetTayRounded $control 17
   }elseif($control -is [Windows.Forms.ComboBox]){
    $control.BackColor=$surface;$control.ForeColor=$fg;$control.FlatStyle='Flat';SetTayRounded $control 7
   }elseif($control -is [Windows.Forms.TextBox]){
    $control.BackColor=$surface;$control.ForeColor=$fg;$control.BorderStyle='FixedSingle';if(-not $control.Multiline){SetTayRounded $control 7}
   }elseif($control -is [Windows.Forms.NumericUpDown]){
    $control.BackColor=$surface;$control.ForeColor=$fg
   }elseif($control -is [Windows.Forms.CheckBox]){
    $control.ForeColor=$fg
   }
   if($control.HasChildren){StyleTayControls $control}
  }
 }
 foreach($page in @($tabs.TabPages)){StyleTayControls $page}
 $usageIntro.ForeColor=$fg;$usageSubtitle.ForeColor=$muted
 foreach($key in @('cpu','gpu','ram')){
  $usageGaugePanels[$key].BackColor=$surface
  $usageBars[$key].BackColor=$accent
  $usageValues[$key].ForeColor=$fg
  $usageLabels[$key].ForeColor=$muted
 }
 $usageInfo.BackColor=$surface;$usageChart.BackColor=$surface
 $sysTitle.ForeColor=$fg;$usageGraphTitle.ForeColor=$fg
 foreach($entry in @($usageInfo.Controls)){if($entry -is [Windows.Forms.Label]){$entry.ForeColor=if($entry -eq $sysTitle){$fg}elseif($entry.Font.Bold){$muted}else{$fg}}}
 $usageFoot.ForeColor=$muted
 foreach($btn in @($apply,$restore,$undo,$logs,$exit)){
  if($btn){$btn.BackColor=if($btn -eq $apply){$accent}else{$surface};$btn.ForeColor=if($btn -eq $apply){[Drawing.Color]::FromArgb(18,18,28)}else{$fg};SetTayRounded $btn 11}
 }
 HighlightTayNav
 $usageChart.Invalidate()
}
$tabs.Add_SelectedIndexChanged({HighlightTayNav})

function PageLabel($page,[string]$text,[int]$x,[int]$y,[int]$w=770){$l=New-Object System.Windows.Forms.Label;$l.Text=$text;$l.Location=[System.Drawing.Point]::new($x,$y);$l.Size=[System.Drawing.Size]::new($w,32);$l.ForeColor=[System.Drawing.Color]::Gainsboro;$page.Controls.Add($l);return $l}
function PageButton($page,[string]$text,[int]$x,[int]$y,[scriptblock]$action){$b=New-Object System.Windows.Forms.Button;$b.Text=$text;$b.Location=[System.Drawing.Point]::new($x,$y);$b.Size=[System.Drawing.Size]::new(340,37);$b.FlatStyle='Flat';$b.FlatAppearance.BorderSize=0;$b.BackColor=[System.Drawing.Color]::FromArgb(255,112,0);$b.ForeColor=[System.Drawing.Color]::Black;$b.Add_Click($action);$page.Controls.Add($b);return $b}
$inputTab.AutoScroll=$true
PageLabel $inputTab 'KEYBOARD / INPUT CUSTOMIZATION' 24 16 | Out-Null
PageLabel $inputTab 'Repeat delay (0 fastest, 3 slowest):' 24 64 | Out-Null
$delay=New-Object System.Windows.Forms.NumericUpDown;$delay.Minimum=0;$delay.Maximum=3;$delay.Value=1;$delay.Location=[System.Drawing.Point]::new(24,95);$inputTab.Controls.Add($delay)
PageLabel $inputTab 'Repeat speed (0 slowest, 31 fastest):' 24 141 | Out-Null
$repeat=New-Object System.Windows.Forms.NumericUpDown;$repeat.Minimum=0;$repeat.Maximum=31;$repeat.Value=31;$repeat.Location=[System.Drawing.Point]::new(24,173);$inputTab.Controls.Add($repeat)
PageLabel $inputTab 'Mouse pointer speed (1 to 20, default 10):' 24 220 | Out-Null
$mouse=New-Object System.Windows.Forms.NumericUpDown;$mouse.Minimum=1;$mouse.Maximum=20;$mouse.Value=10;$mouse.Location=[System.Drawing.Point]::new(24,251);$inputTab.Controls.Add($mouse)
PageButton $inputTab 'Apply input preferences' 24 303 {try{Set-ItemProperty 'HKCU:\Control Panel\Keyboard' -Name KeyboardDelay -Value ([string]$delay.Value) -ErrorAction Stop;Set-ItemProperty 'HKCU:\Control Panel\Keyboard' -Name KeyboardSpeed -Value ([string]$repeat.Value) -ErrorAction Stop;Set-ItemProperty 'HKCU:\Control Panel\Mouse' -Name MouseSensitivity -Value ([string]$mouse.Value) -ErrorAction Stop;Log 'Applied input preferences';[System.Windows.Forms.MessageBox]::Show('Saved Windows input preferences. Sign out and back in if changes do not take effect. This does not alter keyboard hardware polling or game engine latency.','Input')|Out-Null}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Input error')|Out-Null}} | Out-Null
PageButton $inputTab 'Open Windows keyboard settings' 24 356 {Start-Process control.exe 'keyboard'} | Out-Null
PageLabel $inputTab 'Note: Key repeat affects held-key repetition, not first-key response time. Hardware polling and game sensitivity are controlled elsewhere.' 24 410 | Out-Null

# FilterKeys Pro - Windows accessibility settings (per-user).
if (-not ('TayFilterKeysNative' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
[StructLayout(LayoutKind.Sequential)]
public struct TayFilterKeysData { public uint cbSize, dwFlags, iWaitMSec, iDelayMSec, iRepeatMSec, iBounceMSec; }
public static class TayFilterKeysNative {
 [DllImport("user32.dll",SetLastError=true)]
 public static extern bool SystemParametersInfo(uint action,uint param,ref TayFilterKeysData data,uint flags);
 public static TayFilterKeysData Read() {
  var d=new TayFilterKeysData();d.cbSize=(uint)Marshal.SizeOf(typeof(TayFilterKeysData));
  if(!SystemParametersInfo(0x32,d.cbSize,ref d,0))throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
  return d;
 }
 public static void Write(TayFilterKeysData d) {
  d.cbSize=(uint)Marshal.SizeOf(typeof(TayFilterKeysData));
  if(!SystemParametersInfo(0x33,d.cbSize,ref d,3)) {
   int code=Marshal.GetLastWin32Error();
   throw new InvalidOperationException("Windows rejected the FilterKeys settings (error "+code+"). "+
    "Wait="+d.iWaitMSec+"ms, Delay="+d.iDelayMSec+"ms, Repeat="+d.iRepeatMSec+"ms, Bounce="+d.iBounceMSec+
    "ms, Flags="+d.dwFlags+". "+(code==0?"No additional Windows error was provided.":"Check the Windows error code."));
  }
 }
}
'@
}
$filterTab.AutoScroll=$true
PageLabel $filterTab 'FILTERKEYS PRO  |  Keyboard repeat and accessibility' 24 12 | Out-Null
PageLabel $filterTab 'Windows may reject unsupported timings. Values of 1-49 ms are blocked for safety.' 24 42 | Out-Null
$fkControls=@{}
$fkSpecs=@(
 @{Key='iWaitMSec';Label='Ignore presses shorter than (ms)';Min=0;Max=2000;Y=90},
 @{Key='iDelayMSec';Label='Repeat delay (ms)';Min=0;Max=2000;Y=143},
 @{Key='iRepeatMSec';Label='Repeat interval (ms)';Min=1;Max=2000;Y=196},
 @{Key='iBounceMSec';Label='Bounce rejection (ms)';Min=0;Max=2000;Y=249}
)
foreach($spec in $fkSpecs){
 PageLabel $filterTab $spec.Label 24 $spec.Y 400 | Out-Null
 $n=New-Object System.Windows.Forms.NumericUpDown;$n.Minimum=$spec.Min;$n.Maximum=$spec.Max;$n.Increment=1
 $n.Location=[System.Drawing.Point]::new(440,($spec.Y+2));$n.Width=130
 $filterTab.Controls.Add($n);$fkControls[$spec.Key]=$n
}
$fkFlags=@{}
$fkFlagSpecs=@(
 @{Key='On';Text='Filter Keys ON';Bit=1;X=24;Y=311},
 @{Key='Available';Text='Available';Bit=2;X=240;Y=311},
 @{Key='Shortcut';Text='Shift shortcut';Bit=4;X=450;Y=311},
 @{Key='Confirm';Text='Confirm activation';Bit=8;X=24;Y=345},
 @{Key='Sound';Text='Activation sound';Bit=16;X=240;Y=345},
 @{Key='Status';Text='Show status';Bit=32;X=450;Y=345},
 @{Key='Click';Text='Key click';Bit=64;X=24;Y=379}
)
foreach($spec in $fkFlagSpecs){
 $cb=New-Object System.Windows.Forms.CheckBox;$cb.Text=$spec.Text
 $cb.Location=[System.Drawing.Point]::new($spec.X,$spec.Y);$cb.Width=190
 $filterTab.Controls.Add($cb);$fkFlags[$spec.Key]=$cb
}
$fkStatus=PageLabel $filterTab 'Reading current keyboard settings...' 24 424 800
function LoadFilterKeysUI {
 $d=[TayFilterKeysNative]::Read()
 foreach($k in @('iWaitMSec','iDelayMSec','iRepeatMSec','iBounceMSec')){
  $n=$fkControls[$k];$n.Value=[math]::Max($n.Minimum,[math]::Min($n.Maximum,[decimal]$d.$k))
 }
 foreach($spec in $fkFlagSpecs){$fkFlags[$spec.Key].Checked=(([uint32]$d.dwFlags -band [uint32]$spec.Bit) -ne 0)}
 $fkStatus.Text='Current settings loaded. Repeat: '+[math]::Round(1000.0/[math]::Max(1,$d.iRepeatMSec),1)+' / sec'
}
PageButton $filterTab 'Load current settings' 24 462 {try{LoadFilterKeysUI}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'FilterKeys')|Out-Null}} | Out-Null
PageButton $filterTab 'Apply + save to registry' 390 462 {
 try {
  $backup=Join-Path $env:APPDATA 'TayTweaks\FilterKeys-original.json'
  $folder=Split-Path $backup
  if(-not(Test-Path $backup)){New-Item -ItemType Directory -Path $folder -Force|Out-Null;[TayFilterKeysNative]::Read()|ConvertTo-Json|Set-Content -LiteralPath $backup -Encoding UTF8}
  $d=[TayFilterKeysNative]::Read()
  foreach($k in @('iWaitMSec','iDelayMSec','iRepeatMSec','iBounceMSec')){
   $value=[uint32]$fkControls[$k].Value
   if($value -gt 0 -and $value -lt 50){throw "$k = $value ms is too low. Use 0 (where supported) or at least 50 ms. Windows may enforce stricter limits."}
   $d.$k=$value
  }
  if($d.iWaitMSec -gt 0 -and $d.iBounceMSec -gt 0){throw 'Wait and Bounce cannot both be enabled. Set one of them to 0 ms.'}
  $bits=[uint32]0
  foreach($spec in $fkFlagSpecs){if($fkFlags[$spec.Key].Checked){$bits=$bits -bor [uint32]$spec.Bit}}
  $d.dwFlags=([uint32]$d.dwFlags -band ([uint32]::MaxValue -bxor [uint32]127)) -bor $bits
  [TayFilterKeysNative]::Write($d)
  $fkStatus.Text='Applied. Windows may normalize unsupported timings.'
  LoadFilterKeysUI
  Log 'FilterKeys Pro settings saved via SystemParametersInfo.'
 }catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'FilterKeys apply error')|Out-Null}
} | Out-Null
PageButton $filterTab 'Restore original settings' 24 511 {
 try {
  $backup=Join-Path $env:APPDATA 'TayTweaks\FilterKeys-original.json'
  if(-not(Test-Path $backup)){throw 'No backup found yet.'}
  $old=Get-Content -LiteralPath $backup -Raw|ConvertFrom-Json
  $d=[TayFilterKeysNative]::Read()
  foreach($k in @('dwFlags','iWaitMSec','iDelayMSec','iRepeatMSec','iBounceMSec')){$d.$k=[uint32]$old.$k}
  [TayFilterKeysNative]::Write($d);LoadFilterKeysUI
  Log 'Restored original FilterKeys settings.'
 }catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'FilterKeys restore error')|Out-Null}
} | Out-Null
PageButton $filterTab 'Windows keyboard accessibility' 390 511 {Start-Process 'ms-settings:easeofaccess-keyboard'} | Out-Null
try{LoadFilterKeysUI}catch{$fkStatus.Text='Could not read settings: '+$_.Exception.Message}

$tcpTab.AutoScroll=$true
PageLabel $tcpTab 'TCP / NETWORK DIAGNOSTICS' 24 16 | Out-Null
PageLabel $tcpTab 'No universal TCP tweak guarantees lower ping. These tools show and restore supported Windows settings.' 24 55 | Out-Null
PageButton $tcpTab 'View TCP global settings' 24 100 {ShowOutput 'TCP global settings' (& netsh.exe int tcp show global 2>&1|Out-String)} | Out-Null
PageButton $tcpTab 'View network adapters' 390 100 {ShowOutput 'Network adapters' (Get-NetAdapter|Format-Table Name,Status,LinkSpeed,InterfaceDescription -AutoSize|Out-String)} | Out-Null
PageButton $tcpTab 'View network configuration' 24 153 {ShowOutput 'IP configuration' (& ipconfig.exe /all 2>&1|Out-String)} | Out-Null
PageButton $tcpTab 'Restore TCP autotuning to normal' 390 153 {if([System.Windows.Forms.MessageBox]::Show('Restore TCP receive window autotuning to Windows normal?','TCP','YesNo') -eq 'Yes'){try{$out=& netsh.exe int tcp set global autotuninglevel=normal 2>&1|Out-String;if($LASTEXITCODE -ne 0){throw $out};ShowOutput 'TCP restored' $out}catch{ShowOutput 'TCP error' $_.Exception.Message}}} | Out-Null
PageButton $tcpTab 'Open network troubleshooting' 24 206 {Start-Process 'ms-settings:network-status'} | Out-Null
PageLabel $tcpTab 'Avoid arbitrary MTU, TCP ACK, congestion-control or Nagle edits without testing: they can worsen connection quality.' 24 266 | Out-Null
PageLabel $settingsTab 'SETTINGS / APPEARANCE' 24 18 | Out-Null
PageLabel $settingsTab 'Choose a theme (saved automatically):' 24 64 | Out-Null
$themePicker=New-Object System.Windows.Forms.ComboBox;$themePicker.DropDownStyle='DropDownList';$themePicker.Location=[System.Drawing.Point]::new(24,100);$themePicker.Size=[System.Drawing.Size]::new(280,30);$themePicker.Items.AddRange(@('Tay Orange','Crimson Red','Royal Purple','Neon Green','Ocean Blue','Midnight','Light','Pure White','Aurora Teal','Electric Blue'));$themePicker.SelectedItem=$script:ThemeName;$settingsTab.Controls.Add($themePicker)
$themePicker.Add_SelectedIndexChanged({$script:ThemeName=[string]$themePicker.SelectedItem;SaveTheme;ApplyTheme})
PageLabel $settingsTab 'UPDATES / GITHUB' 24 162 | Out-Null
$updateStatus=PageLabel $settingsTab 'Update status: Not checked' 24 205
$script:AppVersion=[version]'7.0';$script:UpdateUrl='https://raw.githubusercontent.com/Tayegandev/Tay-Tweaks/main/latest.json';$script:UpdateBusy=$false
function CheckTayUpdates([bool]$showNoUpdates=$false){
 if($script:UpdateBusy){return};$script:UpdateBusy=$true
 try{
  $updateStatus.Text='Checking GitHub...';[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
  $web=New-Object System.Net.WebClient;$web.Headers.Add('User-Agent','TayTweaks-Updater/6.0');$json=$web.DownloadString($script:UpdateUrl)|ConvertFrom-Json;$web.Dispose()
  $latest=[version]([string]$json.version);if($latest -le $script:AppVersion){$updateStatus.Text="Up to date (v$script:AppVersion)";if($showNoUpdates){[System.Windows.Forms.MessageBox]::Show('You are running the latest version.','Tay Tweaks Updates')|Out-Null};return}
  $updateStatus.Text="New version available: $latest"
  $answer=[System.Windows.Forms.MessageBox]::Show("Tay Tweaks $latest is available.`r`n`r`nDownload, verify and install the update now?`r`nYour app will close and restart. Make sure changes are saved.",'Tay Tweaks Update','YesNo','Information')
  if($answer -ne 'Yes'){return}
  if(-not $json.sha256 -or -not $json.download_url){throw 'The update manifest is missing a download URL or SHA-256. Installation cancelled.'}
  if(([string]$json.download_url) -notmatch '^https://github\.com/Tayegandev/Tay-Tweaks/releases/download/'){throw 'Update URL is not an approved GitHub release asset.'}
  $appExe=[System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
  if([IO.Path]::GetFileName($appExe) -ine 'TayTweaks.exe'){throw 'Automatic installation requires running the compiled TayTweaks.exe.'}
  $helper=Join-Path (Split-Path $appExe) 'TayUpdater.ps1';if(-not(Test-Path $helper)){throw 'TayUpdater.ps1 missing beside TayTweaks.exe. Use the full release package.'}
  $stage=Join-Path $env:TEMP ('TayTweaks-update-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $stage|Out-Null
  $download=Join-Path $stage 'TayTweaks.exe';$wc=New-Object System.Net.WebClient;$wc.Headers.Add('User-Agent','TayTweaks-Updater/6.0');$wc.DownloadFile([string]$json.download_url,$download);$wc.Dispose()
  $hash=(Get-FileHash -Algorithm SHA256 -LiteralPath $download).Hash;if($hash -ine ([string]$json.sha256).Trim()){throw 'SHA-256 mismatch. Update rejected.'}
  $args='-NoProfile -ExecutionPolicy Bypass -File "'+$helper+'" -PidToWait '+$PID+' -Source "'+$download+'" -Destination "'+$appExe+'" -ExpectedHash '+$hash
  Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Verb RunAs -ErrorAction Stop
  $form.Close()
 }catch{$updateStatus.Text='Update check/install failed';Log "Updater: $($_.Exception.Message)";if($showNoUpdates){[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Tay Tweaks Update','OK','Warning')|Out-Null}}
 finally{$script:UpdateBusy=$false}
}
PageButton $settingsTab 'Check for updates' 24 247 {CheckTayUpdates $true} | Out-Null
PageLabel $settingsTab 'Updates install only after you click Update Now. Download integrity is checked before replacing the EXE.' 24 306 | Out-Null
$startupUpdateTimer=New-Object System.Windows.Forms.Timer;$startupUpdateTimer.Interval=2500;$startupUpdateTimer.Add_Tick({$startupUpdateTimer.Stop();CheckTayUpdates $false});$form.Add_Shown({$startupUpdateTimer.Start()})
function ToolButton($page,[string]$label,[string]$desc,[int]$x,[int]$y,[scriptblock]$action){
 $b=New-Object System.Windows.Forms.Button;$b.Text=$label;$b.Location=[System.Drawing.Point]::new($x,$y);$b.Size=New-Object System.Drawing.Size(270,40);$b.FlatStyle="Flat";$b.FlatAppearance.BorderSize=0;$b.BackColor=[System.Drawing.Color]::FromArgb(255,92,35);$b.ForeColor=[System.Drawing.Color]::FromArgb(20,20,24);$b.Font=New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold);$b.Add_Click($action);$page.Controls.Add($b)
 $l=New-Object System.Windows.Forms.Label;$l.Text=$desc;$l.Location=[System.Drawing.Point]::new($x,($y+44));$l.Size=New-Object System.Drawing.Size(270,42);$l.ForeColor=[System.Drawing.Color]::FromArgb(195,199,210);$page.Controls.Add($l)
}
ToolButton $cleanTab "Storage settings" "Review Temporary files and Storage Sense before deleting anything." 24 24 {Start-Process "ms-settings:storagesense"}
ToolButton $cleanTab "Disk Cleanup" "Built-in Windows cleanup; inspect categories before confirming." 320 24 {Start-Process cleanmgr.exe}
ToolButton $cleanTab "Startup Apps" "Disable only apps you recognize and do not need at sign-in." 24 124 {Start-Process "ms-settings:startupapps"}
ToolButton $cleanTab "Installed Apps" "Uninstall software you recognize and no longer use." 320 124 {Start-Process "ms-settings:appsfeatures"}
ToolButton $cleanTab "Clean user Temp folder" "Deletes files inside your user Temp folder only; files in use are skipped." 24 224 {
 $p=$env:TEMP;$c=[System.Windows.Forms.MessageBox]::Show("Delete contents of this Temp folder?`r`n$p","Confirm cleanup","YesNo","Warning")
 if($c -eq [System.Windows.Forms.DialogResult]::Yes){Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue|Remove-Item -Recurse -Force -ErrorAction SilentlyContinue;Log "User Temp cleanup requested.";[System.Windows.Forms.MessageBox]::Show("Cleanup finished. Some files may have been skipped.","Tay Tweaks")|Out-Null}
}
ToolButton $cleanTab "Open Recycle Bin" "Review deleted items and restore anything you still need." 320 224 {Start-Process explorer.exe "shell:RecycleBinFolder"}

$pcCmd='$os=Get-CimInstance Win32_OperatingSystem; $cpu=Get-CimInstance Win32_Processor; $gpu=Get-CimInstance Win32_VideoController; "WINDOWS`r`n-------`r`n$($os.Caption) $($os.OSArchitecture) build $($os.BuildNumber)`r`n`r`nCPU`r`n---`r`n$($cpu.Name)`r`n`r`nRAM`r`n---`r`nTotal: $([math]::Round($os.TotalVisibleMemorySize/1MB,1)) GB`r`nAvailable: $([math]::Round($os.FreePhysicalMemory/1MB,1)) GB`r`n`r`nGRAPHICS`r`n--------`r`n$($gpu | ForEach-Object { "$($_.Name) | Driver $($_.DriverVersion)" } | Out-String)`r`nDISKS`r`n-----`r`n$(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object { "$($_.DeviceID) $([math]::Round($_.FreeSpace/1GB,1)) GB free / $([math]::Round($_.Size/1GB,1)) GB total" } | Out-String)'
ToolButton $diagTab "PC quick summary" "Windows version, CPU, RAM, graphics driver and disk space." 24 24 {RunOutput "PC quick summary" $pcCmd}
$resourceCmd='$cpu=Get-CimInstance Win32_Processor|Measure-Object LoadPercentage -Average; $os=Get-CimInstance Win32_OperatingSystem; "CPU load: $([math]::Round($cpu.Average,0))%`r`nAvailable RAM: $([math]::Round($os.FreePhysicalMemory/1MB,1)) GB`r`n`r`nTop processes by RAM:`r`n$(Get-Process|Sort-Object WorkingSet64 -Descending|Select-Object -First 15 ProcessName,Id,@{N="RAM_MB";E={[math]::Round($_.WorkingSet64/1MB)}}|Format-Table -AutoSize|Out-String)'
ToolButton $diagTab "Live resource snapshot" "Quick CPU load, available RAM and top memory-using processes." 320 24 {RunOutput "Live resource snapshot" $resourceCmd}
ToolButton $diagTab "Reliability Monitor" "Review Windows app crashes and system reliability." 24 124 {Start-Process perfmon.exe "/rel"}
ToolButton $diagTab "Task Manager" "Inspect processes and startup apps." 320 124 {Start-Process taskmgr.exe}
ToolButton $diagTab "Device Manager" "Inspect devices and driver status; avoid random uninstalling." 24 224 {Start-Process devmgmt.msc}
ToolButton $diagTab "Windows repair guide" "DISM and SFC are for Windows integrity, not FPS boosts." 320 224 {ShowOutput "Windows repair guide" "In Terminal (Admin), run one at a time:`r`n`r`nDISM /Online /Cleanup-Image /RestoreHealth`r`nsfc /scannow`r`n`r`nWait for each command to finish."}

ToolButton $netTab "Flush DNS cache" "Clears local DNS cache; does not automatically lower game ping." 24 24 {
 $c=[System.Windows.Forms.MessageBox]::Show("Flush the Windows DNS resolver cache?","Confirm DNS flush","YesNo","Question")
 if($c -eq [System.Windows.Forms.DialogResult]::Yes){$o=(& ipconfig.exe /flushdns 2>&1|Out-String);Log "DNS cache flushed.";ShowOutput "DNS flush result" $o}
}
ToolButton $netTab "Show IP configuration" "Review adapter configuration; don't share output publicly without checking it." 320 24 {ShowOutput "IP configuration" (& ipconfig.exe /all 2>&1|Out-String)}
ToolButton $netTab "Ping Cloudflare DNS" "Eight pings to 1.1.1.1; game routing may differ." 24 124 {ShowOutput "Ping test" (& ping.exe -n 8 1.1.1.1 2>&1|Out-String)}
ToolButton $netTab "Trace route" "Traces route to 1.1.1.1; routers may ignore probes." 320 124 {ShowOutput "Trace route" (& tracert.exe -d -h 12 -w 800 1.1.1.1 2>&1|Out-String)}
ToolButton $netTab "Network settings" "Open Windows Ethernet/Wi-Fi settings." 24 224 {Start-Process "ms-settings:network-status"}
ToolButton $netTab "Renew DHCP address" "May briefly disconnect you; only use for network troubleshooting." 320 224 {
 $c=[System.Windows.Forms.MessageBox]::Show("Release and renew the IP address? This can briefly disconnect the network.","Confirm DHCP renew","YesNo","Warning")
 if($c -eq [System.Windows.Forms.DialogResult]::Yes){$o=(& ipconfig.exe /release 2>&1|Out-String);$o+="`r`n"+(& ipconfig.exe /renew 2>&1|Out-String);Log "DHCP renew requested.";ShowOutput "DHCP renew result" $o}
}
$about=New-Object System.Windows.Forms.Label;$about.Location=[System.Drawing.Point]::new(24,24);$about.Size=New-Object System.Drawing.Size(870,450);$about.Font=New-Object System.Drawing.Font("Segoe UI",11)
$about.Text="TAY TWEAKS v7.0`r`n`r`nBuilt for Windows 10/11, including older systems such as Intel Core i5-4590 / 16 GB RAM / Intel HD 4600.`r`n`r`nInspired by common categories found in public PC optimization tools; this is an original implementation, not copied proprietary code.`r`n`r`nSafety:`r`n• Administrator mode for system actions.`r`n• A successful restore point is required before registry tweaks.`r`n• Previous values of modified registry entries are saved for Undo.`r`n• Cleanup/network actions confirm potentially destructive actions.`r`n`r`nReality check:`r`n• No tweak guarantees more FPS or lower ping.`r`n• Avoid disabling Defender, Windows Update, or random services.`r`n• Intel HD 4600 is an older integrated GPU; in-game settings and background apps usually matter more than obscure registry edits.`r`n• Usage readings depend on Windows drivers; CPU/GPU temperatures may not be exposed.`r`n`r`nBackup/log path: $DataDir"
$about.ForeColor=[System.Drawing.Color]::FromArgb(210,214,223);$aboutTab.Controls.Add($about)
$status=New-Object System.Windows.Forms.Label;$status.Text="Ready • Administrator mode • Restore point required before tweaks";$status.Location=[System.Drawing.Point]::new(22,683);$status.Size=New-Object System.Drawing.Size(900,28);$status.Anchor="Bottom,Left,Right";$status.ForeColor=[System.Drawing.Color]::FromArgb(195,199,210);$form.Controls.Add($status)
function BottomButton([string]$text,[int]$x,[int]$width){$b=New-Object System.Windows.Forms.Button;$b.Text=$text;$b.Location=[System.Drawing.Point]::new($x,720);$b.Size=New-Object System.Drawing.Size($width,44);$b.Anchor="Bottom,Left";$b.FlatStyle="Flat";$b.FlatAppearance.BorderSize=0;$b.BackColor=[System.Drawing.Color]::FromArgb(255,92,35);$b.ForeColor=[System.Drawing.Color]::FromArgb(20,20,24);$b.Font=New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold);$form.Controls.Add($b);return $b}
$apply=BottomButton "Apply selected tweaks" 22 180;$restore=BottomButton "Create restore point" 214 170;$undo=BottomButton "Undo last session" 396 160;$logs=BottomButton "Open logs/backups" 568 160;$exit=BottomButton "Exit" 740 100
$apply.Add_Click({
 $selected=@($Tweaks|Where-Object{$checks[$_.Id].Checked})
 if($selected.Count -eq 0){[System.Windows.Forms.MessageBox]::Show("Select at least one tweak.","Tay Tweaks")|Out-Null;return}
 $summary=($selected|ForEach-Object{"• "+$_.Name}) -join "`r`n"
 $c=[System.Windows.Forms.MessageBox]::Show("Create restore point and registry backup, then apply:`r`n`r`n$summary`r`n`r`nContinue?","Confirm changes","YesNo","Warning")
 if($c -ne [System.Windows.Forms.DialogResult]::Yes){return}
 $status.Text="Creating restore point…";$form.Refresh();if(-not(RestorePoint)){$status.Text="Stopped: restore point failed.";return}
 $snap=$null
 try{
  New-Item -ItemType Directory -Path $DataDir -Force|Out-Null;$changes=@();foreach($t in $selected){$changes+=$t.Changes};$snap=Snapshot $changes
  ([pscustomobject]@{Created=(Get-Date).ToString("o");Tweaks=@($selected|ForEach-Object{$_.Id});Snapshot=$snap}|ConvertTo-Json -Depth 8)|Set-Content -Path $BackupFile -Encoding UTF8
  $succeeded=@();$failed=@()
  foreach($t in $selected){$oneSnap=Snapshot @($t.Changes);try{foreach($c in $t.Changes){ApplyValue $c};$succeeded+=$t;Log "Applied tweak: $($t.Id)"}catch{$why=$_.Exception.Message;UndoSnapshot $oneSnap;$failed+=([pscustomobject]@{Name=$t.Name;Reason=$why});Log "Tweak failed and rolled back [$($t.Id)] $($_.Exception.GetType().FullName): $why"}}
  $doneIds=@($succeeded|ForEach-Object{$_.Id});([pscustomobject]@{Updated=(Get-Date).ToString("o");Tweaks=$doneIds}|ConvertTo-Json -Depth 4)|Set-Content -Path $AppliedFile -Encoding UTF8
  if($succeeded.Count -gt 0){$homePrevious.Text="SUCCESSFULLY APPLIED`r`n"+(($succeeded|ForEach-Object{"• "+$_.Name}) -join "`r`n")}
  if($failed.Count -eq 0){$status.Text="All selected tweaks applied. Restart if needed.";[System.Windows.Forms.MessageBox]::Show("All selected tweaks applied. Use Undo last session to restore previous values.","Tay Tweaks")|Out-Null}else{$status.Text="$($succeeded.Count) applied • $($failed.Count) blocked";$details=($failed|ForEach-Object{"• $($_.Name)`r`n  $($_.Reason)"}) -join "`r`n`r`n";[System.Windows.Forms.MessageBox]::Show("Some tweaks were blocked by Windows. Successful tweaks remain applied; each failed tweak was rolled back.`r`n`r`n$details`r`n`r`nSee tay-tweaks.log for details.","Tay Tweaks - Permission report","OK","Warning")|Out-Null}
 }catch{Log "Apply error [$($_.Exception.GetType().FullName)]: $($_.Exception.ToString())";if($snap){UndoSnapshot $snap};$status.Text="Apply error; rollback attempted.";[System.Windows.Forms.MessageBox]::Show("Error applying changes; rollback attempted.`r`n$($_.Exception.Message)","Tay Tweaks")|Out-Null}
})
$restore.Add_Click({$status.Text="Creating restore point…";$form.Refresh();if(RestorePoint){$status.Text="Restore point created.";[System.Windows.Forms.MessageBox]::Show("Restore point created.","Tay Tweaks")|Out-Null}else{$status.Text="Restore point failed; no tweaks applied."}})
$undo.Add_Click({
 if(-not(Test-Path $BackupFile)){[System.Windows.Forms.MessageBox]::Show("No saved session found.","Tay Tweaks")|Out-Null;return}
 $c=[System.Windows.Forms.MessageBox]::Show("Restore registry values saved before the last apply session?","Undo last session","YesNo","Warning");if($c -ne [System.Windows.Forms.DialogResult]::Yes){return}
 try{$s=Get-Content $BackupFile -Raw|ConvertFrom-Json;UndoSnapshot @($s.Snapshot);Log "Last session undone.";Remove-Item $AppliedFile -Force -ErrorAction SilentlyContinue;$homePrevious.Text="PREVIOUSLY APPLIED / SELECTED`r`nLast session was undone."; $status.Text="Previous registry values restored.";[System.Windows.Forms.MessageBox]::Show("Previous registry values restored. Restart if needed.","Tay Tweaks")|Out-Null}catch{[System.Windows.Forms.MessageBox]::Show("Undo failed: $($_.Exception.Message)","Tay Tweaks")|Out-Null}
})
$logs.Add_Click({New-Item -ItemType Directory -Path $DataDir -Force|Out-Null;Start-Process explorer.exe $DataDir})
$exit.Add_Click({if($slimScrollTimer){$slimScrollTimer.Stop()};$usageTimer.Stop();$specPoll.Stop();if($script:specJob){Remove-Job -Job $script:specJob -Force -ErrorAction SilentlyContinue};$homeClockTimer.Stop();try{$script:cpuCounter.Dispose();$script:memCounter.Dispose();foreach($gc in $script:gpuCounters){$gc.Dispose()}}catch{};$form.Close()})
ApplyTheme

# Adaptive dashboard grid: three equal metric cards, then System / Activity cards.
function SetTayDashboardLayout {
 if(-not $usageTab -or $usageTab.IsDisposed){return}
 $w=[math]::Max(835,$usageTab.ClientSize.Width-8)
 $gap=12;$margin=14;$cardW=[int][math]::Floor(($w-2*$margin-2*$gap)/3)
 foreach($pair in @(@('cpu',0),@('gpu',1),@('ram',2))){
  $card=$usageGaugePanels[[string]$pair[0]];$card.Width=$cardW
  $card.Left=$margin+([int]$pair[1]*($cardW+$gap))
 }
 $sysW=[int][math]::Floor(($w-2*$margin-$gap)*0.39)
 $usageInfo.Left=$margin;$usageInfo.Width=$sysW
 $usageChart.Left=$margin+$sysW+$gap
 $usageChart.Width=$w-2*$margin-$gap-$sysW
 $usageChartChoice.Left=[math]::Max(215,$usageChart.Width-128)
 foreach($k in @('CPU','GPU','MEMORY','OS')){$script:specLabels[$k].Width=[math]::Max(100,$sysW-38)}
 $usageChart.Invalidate()
}
$usageTab.Add_SizeChanged({SetTayDashboardLayout})
$script:TayCardBorder={
 param($sender,$e)
 if($sender.Width -lt 16 -or $sender.Height -lt 16){return}
 $accent=[Drawing.ColorTranslator]::FromHtml($script:Themes[$script:ThemeName])
 $pen=New-Object Drawing.Pen([Drawing.Color]::FromArgb(70,$accent.R,$accent.G,$accent.B),1)
 $e.Graphics.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
 $rect=[Drawing.Rectangle]::new(1,1,($sender.Width-3),($sender.Height-3))
 $path=New-Object Drawing.Drawing2D.GraphicsPath
 $d=26
 $path.AddArc($rect.Left,$rect.Top,$d,$d,180,90)
 $path.AddArc(($rect.Right-$d),$rect.Top,$d,$d,270,90)
 $path.AddArc(($rect.Right-$d),($rect.Bottom-$d),$d,$d,0,90)
 $path.AddArc($rect.Left,($rect.Bottom-$d),$d,$d,90,90)
 $path.CloseFigure();$e.Graphics.DrawPath($pen,$path)
 $pen.Dispose();$path.Dispose()
}
foreach($panel in @($usageInfo,$usageChart)+@($usageGaugePanels.Values)){$panel.Add_Paint($script:TayCardBorder)}
$form.Add_Shown({
 $form.MaximizedBounds=[Windows.Forms.Screen]::FromControl($form).WorkingArea
 SetTayDashboardLayout
 $resizeGrip.BringToFront()
})
$frameMax.Add_Click({$form.MaximizedBounds=[Windows.Forms.Screen]::FromControl($form).WorkingArea})

# Thin theme-aware scrollbar overlay for long WinForms pages. The underlying
# AutoScroll model is retained for wheel/keyboard navigation; native bars are hidden.
$script:TayScrollers=New-Object System.Collections.ArrayList
function UpdateTayScrollbar($entry) {
 try{
  $target=$entry.Target;$track=$entry.Track;$thumb=$entry.Thumb
  if($target.IsDisposed -or -not $target.IsHandleCreated){$track.Visible=$false;return}
  if(-not $target.Visible){$track.Visible=$false;return}
  $client=[math]::Max(1,$target.ClientSize.Height)
  $content=[math]::Max([int]$target.AutoScrollMinSize.Height,[int]$target.DisplayRectangle.Height)
  $maximum=[math]::Max(0,$content-$client)
  if($maximum -lt 8){$track.Visible=$false;return}
  $track.Visible=$true
  $track.Height=[math]::Max(36,$client-12)
  $origin=$form.PointToClient($target.PointToScreen([Drawing.Point]::new(0,0)))
  $track.Location=[Drawing.Point]::new(($origin.X+$target.ClientSize.Width-12),($origin.Y+6))
  $size=[math]::Max(25,[int]($track.Height*$client/[math]::Max($content,1)))
  $thumb.Height=[math]::Min($track.Height,$size)
  if(-not $entry.Dragging){
   $offset=[math]::Max(0,-$target.AutoScrollPosition.Y)
   $travel=[math]::Max(0,$track.Height-$thumb.Height)
   $thumb.Top=if($maximum -gt 0){[int]($offset*$travel/$maximum)}else{0}
  }
  $accent=[Drawing.ColorTranslator]::FromHtml($script:Themes[$script:ThemeName])
  $thumb.BackColor=$accent
  [void][TayWindowNative]::ShowScrollBar($target.Handle,3,$false)
  $track.BringToFront()
 }catch{}
}
function AddTayScrollbar($target){
 if(-not $target -or -not $target.AutoScroll){return}
 $track=New-Object Windows.Forms.Panel;$track.Size=[Drawing.Size]::new(7,80)
 $track.BackColor=[Drawing.Color]::FromArgb(46,43,67);$track.Tag='TaySlimScrollTrack'
 $thumb=New-Object Windows.Forms.Panel;$thumb.Size=[Drawing.Size]::new(7,28)
 $thumb.BackColor=[Drawing.Color]::FromArgb(144,95,255);$thumb.Cursor=[Windows.Forms.Cursors]::Hand
 $track.Controls.Add($thumb);$track.Visible=$false;$form.Controls.Add($track);$track.BringToFront()
 $entry=[pscustomobject]@{Target=$target;Track=$track;Thumb=$thumb;Dragging=$false;GrabY=0}
 [void]$script:TayScrollers.Add($entry)
 $thumb.Add_MouseDown({param($sender,$e)
  if($e.Button -eq [Windows.Forms.MouseButtons]::Left){$entry=$sender.Tag;$entry.Dragging=$true;$entry.GrabY=$e.Y}
 })
 $thumb.Tag=$entry
 $thumb.Add_MouseUp({param($sender,$e);$sender.Tag.Dragging=$false})
 $thumb.Add_MouseMove({param($sender,$e)
  $entry=$sender.Tag;if(-not $entry.Dragging){return}
  $target=$entry.Target;$track=$entry.Track
  $content=[math]::Max([int]$target.AutoScrollMinSize.Height,[int]$target.DisplayRectangle.Height)
  $max=[math]::Max(0,$content-$target.ClientSize.Height)
  $travel=[math]::Max(1,$track.Height-$entry.Thumb.Height)
  $pos=[math]::Max(0,[math]::Min($travel,$entry.Thumb.Top+$e.Y-$entry.GrabY))
  $target.AutoScrollPosition=[Drawing.Point]::new(0,[int]($pos*$max/$travel))
  UpdateTayScrollbar $entry
 })
 $track.Add_MouseDown({param($sender,$e)
  if($e.Button -ne [Windows.Forms.MouseButtons]::Left){return}
  $entry=$sender.Tag;$target=$entry.Target
  $content=[math]::Max([int]$target.AutoScrollMinSize.Height,[int]$target.DisplayRectangle.Height)
  $max=[math]::Max(0,$content-$target.ClientSize.Height)
  $travel=[math]::Max(1,$sender.Height-$entry.Thumb.Height)
  $target.AutoScrollPosition=[Drawing.Point]::new(0,[int]([math]::Max(0,[math]::Min(1,($e.Y-$entry.Thumb.Height/2)/$travel))*$max))
  UpdateTayScrollbar $entry
 })
 $track.Tag=$entry
 $target.Add_Scroll({param($sender,$e);foreach($entry in @($script:TayScrollers)){if($entry.Target -eq $sender){UpdateTayScrollbar $entry}}})
 $target.Add_SizeChanged({param($sender,$e);foreach($entry in @($script:TayScrollers)){if($entry.Target -eq $sender){UpdateTayScrollbar $entry}}})
 UpdateTayScrollbar $entry
}
foreach($scrollPage in @($nav,$tweakPanel)+@($tabs.TabPages | Where-Object {$_.AutoScroll})){AddTayScrollbar $scrollPage}
$slimScrollTimer=New-Object Windows.Forms.Timer
$slimScrollTimer.Interval=350
$slimScrollTimer.Add_Tick({foreach($entry in @($script:TayScrollers)){UpdateTayScrollbar $entry}})
$slimScrollTimer.Start()

$resizeGrip.BringToFront()
Log "Tay-Tweaks launched."
[void]$form.ShowDialog()
