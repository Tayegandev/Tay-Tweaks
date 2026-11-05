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
$form=New-Object System.Windows.Forms.Form;$form.Text="Tay-Tweaks";try{if(Test-Path $script:TayIconPath){$form.Icon=New-Object System.Drawing.Icon($script:TayIconPath)}else{$exePath=[System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName;if([IO.Path]::GetFileName($exePath) -ieq 'TayTweaks.exe'){$form.Icon=[System.Drawing.Icon]::ExtractAssociatedIcon($exePath)}}}catch{};$form.Size=New-Object System.Drawing.Size(1100,820);$form.MinimumSize=New-Object System.Drawing.Size(940,700);$form.StartPosition="CenterScreen";$form.WindowState="Normal";$form.MaximizeBox=$true;$form.MinimizeBox=$true;$form.BackColor=[System.Drawing.Color]::FromArgb(8,8,10);$form.ForeColor=[System.Drawing.Color]::FromArgb(235,238,244);$form.Font=New-Object System.Drawing.Font("Segoe UI",9)
$head=New-Object System.Windows.Forms.Panel;$head.Dock="Top";$head.Height=92;$head.BackColor=[System.Drawing.Color]::FromArgb(18,10,12);$form.Controls.Add($head)
$ttl=New-Object System.Windows.Forms.Label;$ttl.Text="TAY TWEAKS";$ttl.Font=New-Object System.Drawing.Font("Segoe UI",22,[System.Drawing.FontStyle]::Bold);$ttl.ForeColor=[System.Drawing.Color]::FromArgb(255,92,35);$ttl.Location=[System.Drawing.Point]::new(22,10);$ttl.AutoSize=$true;$head.Controls.Add($ttl)
$sub=New-Object System.Windows.Forms.Label;$sub.Text="CPU  •  RAM  •  GPU  •  GAMING  •  WINDOWS  •  DIAGNOSTICS";$sub.ForeColor=[System.Drawing.Color]::FromArgb(190,195,207);$sub.Location=[System.Drawing.Point]::new(25,55);$sub.AutoSize=$true;$head.Controls.Add($sub)
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
# Display Manager: supported modes only; custom requests must match a driver-advertised mode.
$displayTab=Tab "Display Manager";$displayTab.AutoScroll=$true
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class TayDisplay {
 [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
 public struct DEVMODE {
 [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string dmDeviceName;
 public ushort dmSpecVersion,dmDriverVersion,dmSize,dmDriverExtra;
 public uint dmFields;
 public int dmPositionX,dmPositionY;
 public uint dmDisplayOrientation,dmDisplayFixedOutput;
 public short dmColor,dmDuplex,dmYResolution,dmTTOption,dmCollate;
 [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string dmFormName;
 public ushort dmLogPixels;
 public uint dmBitsPerPel,dmPelsWidth,dmPelsHeight,dmDisplayFlags,dmDisplayFrequency,dmICMMethod,dmICMIntent,dmMediaType,dmDitherType,dmReserved1,dmReserved2,dmPanningWidth,dmPanningHeight;
 }
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern bool EnumDisplaySettings(string device,int index,ref DEVMODE mode);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int ChangeDisplaySettingsEx(string device,ref DEVMODE mode,IntPtr hwnd,uint flags,IntPtr param);
 public static DEVMODE Blank(){var d=new DEVMODE();d.dmSize=(ushort)Marshal.SizeOf(typeof(DEVMODE));return d;}
 public static DEVMODE Current(){var d=Blank();if(!EnumDisplaySettings(null,-1,ref d))throw new Exception("Cannot read current display mode");return d;}
 public static int Test(DEVMODE d){return ChangeDisplaySettingsEx(null,ref d,IntPtr.Zero,2,IntPtr.Zero);}
 public static int Apply(DEVMODE d){return ChangeDisplaySettingsEx(null,ref d,IntPtr.Zero,0,IntPtr.Zero);}
 public static int Persist(DEVMODE d){return ChangeDisplaySettingsEx(null,ref d,IntPtr.Zero,1,IntPtr.Zero);}
}
'@ -ErrorAction Stop
function DMLabel($text,$x,$y,$w=800){
 $l=New-Object Windows.Forms.Label;$l.Text=$text;$l.Location=[Drawing.Point]::new($x,$y);$l.Size=[Drawing.Size]::new($w,30);$l.ForeColor=[Drawing.Color]::Gainsboro;$displayTab.Controls.Add($l);return $l
}
$dmTitle=DMLabel 'DISPLAY MANAGER' 24 18;$dmTitle.Font=New-Object Drawing.Font('Segoe UI',16,[Drawing.FontStyle]::Bold)
$dmCurrent=DMLabel 'Current display: detecting...' 24 62
[void](DMLabel 'Mode selection' 24 108)
$dmKind=New-Object Windows.Forms.ComboBox;$dmKind.DropDownStyle='DropDownList';$dmKind.Location=[Drawing.Point]::new(24,142);$dmKind.Width=230
[void]$dmKind.Items.AddRange([object[]]@('Windows supported modes','Popular low-FPS presets','Add custom resolution'));$displayTab.Controls.Add($dmKind)
$dmMode=New-Object Windows.Forms.ComboBox;$dmMode.DropDownStyle='DropDownList';$dmMode.Location=[Drawing.Point]::new(275,142);$dmMode.Width=330;$displayTab.Controls.Add($dmMode)
[void](DMLabel 'Width' 24 203 110);[void](DMLabel 'Height' 175 203 110);[void](DMLabel 'Refresh rate' 325 203 180)
$dmW=New-Object Windows.Forms.NumericUpDown;$dmW.Minimum=320;$dmW.Maximum=7680;$dmW.Value=1280;$dmW.Location=[Drawing.Point]::new(24,238);$dmW.Width=120;$displayTab.Controls.Add($dmW)
$dmH=New-Object Windows.Forms.NumericUpDown;$dmH.Minimum=200;$dmH.Maximum=4320;$dmH.Value=720;$dmH.Location=[Drawing.Point]::new(175,238);$dmH.Width=120;$displayTab.Controls.Add($dmH)
$dmHz=New-Object Windows.Forms.NumericUpDown;$dmHz.Minimum=1;$dmHz.Maximum=240;$dmHz.Increment=1;$dmHz.Value=60;$dmHz.Location=[Drawing.Point]::new(325,238);$dmHz.Width=140;$displayTab.Controls.Add($dmHz)
[void](DMLabel 'Custom resolution requests must already be driver-advertised. Unsupported modes are blocked.' 24 286)
$dmStatus=DMLabel 'Ready.' 24 328
$dmProfile=DMLabel 'Hardware: not scanned yet' 24 442 800
$dmInternet=DMLabel 'Internet: not checked' 24 476 800
$dmScan=New-Object Windows.Forms.Button;$dmScan.Text='Detect my PC + internet';$dmScan.Location=[Drawing.Point]::new(395,380);$dmScan.Size=[Drawing.Size]::new(200,38);$displayTab.Controls.Add($dmScan)
$dmRefresh=New-Object Windows.Forms.Button;$dmRefresh.Text='Refresh modes';$dmRefresh.Location=[Drawing.Point]::new(24,380);$dmRefresh.Size=[Drawing.Size]::new(150,38);$displayTab.Controls.Add($dmRefresh)
$dmApply=New-Object Windows.Forms.Button;$dmApply.Text='Apply and confirm';$dmApply.Location=[Drawing.Point]::new(195,380);$dmApply.Size=[Drawing.Size]::new(180,38);$displayTab.Controls.Add($dmApply)
$script:DMModes=@();$script:DMBusy=$false
function DMRefresh {
 try{
  $old=[TayDisplay]::Current();$dmCurrent.Text="Current: $($old.dmPelsWidth) x $($old.dmPelsHeight) @ $($old.dmDisplayFrequency) Hz"
  $script:DMModes=@();$seen=@{}
  for($i=0;$i -lt 2048;$i++){
   $d=[TayDisplay]::Blank();if(-not [TayDisplay]::EnumDisplaySettings($null,$i,[ref]$d)){break}
   if($d.dmBitsPerPel -lt 24){continue}
   $key="$($d.dmPelsWidth)x$($d.dmPelsHeight)@$($d.dmDisplayFrequency)"
   if(-not $seen.ContainsKey($key)){$seen[$key]=$true;$script:DMModes+=,$d}
  }
  $dmHz.Maximum=[decimal][math]::Max(240,[int]$old.dmDisplayFrequency)
  $dmHz.Value=[decimal][math]::Max(1,[int]$old.dmDisplayFrequency)
  $dmStatus.Text=if($script:DMModes.Count -eq 0){'No driver-advertised modes found. Check your GPU driver.'}else{"$($script:DMModes.Count) driver-advertised modes. Only compatible combinations can be applied."}
  $dmW.Value=[decimal][Math]::Max(320,[Math]::Min(7680,[int]$old.dmPelsWidth))
  $dmH.Value=[decimal][Math]::Max(200,[Math]::Min(4320,[int]$old.dmPelsHeight))
  DMFillModes
 }catch{$dmStatus.Text="Display scan failed: $($_.Exception.Message)";Log $dmStatus.Text}
}
function DMFillModes {
 $dmMode.Items.Clear()
 if($dmKind.SelectedIndex -eq 0){foreach($d in $script:DMModes){[void]$dmMode.Items.Add("$($d.dmPelsWidth) x $($d.dmPelsHeight) @ $($d.dmDisplayFrequency) Hz")}}
 if($dmKind.SelectedIndex -eq 1){foreach($p in @('1280x720','1152x648','1024x768','960x540','800x600','640x480')){[void]$dmMode.Items.Add($p)}}
 $dmMode.Enabled=($dmKind.SelectedIndex -ne 2)
 $dmW.Enabled=($dmKind.SelectedIndex -eq 2);$dmH.Enabled=($dmKind.SelectedIndex -eq 2)
 if($dmMode.Items.Count){$dmMode.SelectedIndex=0}
}
$dmKind.Add_SelectedIndexChanged({DMFillModes})
$dmMode.Add_SelectedIndexChanged({
 if($dmMode.SelectedIndex -lt 0){return}
 if($dmKind.SelectedIndex -eq 0){
  $d=$script:DMModes[$dmMode.SelectedIndex]
  $dmW.Value=[decimal][Math]::Max(320,[Math]::Min(7680,[int]$d.dmPelsWidth))
  $dmH.Value=[decimal][Math]::Max(200,[Math]::Min(4320,[int]$d.dmPelsHeight))
  $dmHz.Maximum=[decimal][math]::Max([int]$dmHz.Maximum,[int]$d.dmDisplayFrequency);$dmHz.Value=[decimal][math]::Max(1,[int]$d.dmDisplayFrequency)
 }elseif($dmKind.SelectedIndex -eq 1){
  $p=([string]$dmMode.SelectedItem).Split('x');$dmW.Value=[decimal][int]$p[0];$dmH.Value=[decimal][int]$p[1]
 }
})
$dmRefresh.Add_Click({DMRefresh})
$dmScan.Add_Click({
 $dmScan.Enabled=$false
 try {
  $script:HardwareProfile=GetTayHardwareProfile
  $p=$script:HardwareProfile
  $names=(@($p.GPU|ForEach-Object {$_.Name+' (driver '+$_.Driver+')'})) -join '; '
  $dmProfile.Text="CPU: $($p.CPU) | RAM: $($p.RAM_GB) GB | GPU: $names"
  $dmProfile.AutoEllipsis=$true
  DMRefresh
 }catch{$dmProfile.Text="Hardware detection unavailable: $($_.Exception.Message)"}
 $dmInternet.Text=if(TestTayInternet){'Internet: GitHub update endpoint reachable'}else{'Internet: offline, blocked or endpoint unavailable'}
 $dmScan.Enabled=$true
})
$dmApply.Add_Click({
 if($script:DMBusy){return};$script:DMBusy=$true
 try{
  $old=[TayDisplay]::Current()
  $w=[uint32][int]$dmW.Value;$h=[uint32][int]$dmH.Value

  $hz=[uint32][int]$dmHz.Value;$target=$null
  foreach($d in $script:DMModes){if($d.dmPelsWidth -eq $w -and $d.dmPelsHeight -eq $h -and $d.dmDisplayFrequency -eq $hz){$target=$d;break}}
  if($null -eq $target){throw "Unsupported mode: $w x $h @ $hz Hz. Your driver must advertise the mode before Windows can apply it."}
  $test=[TayDisplay]::Test($target);if($test -ne 0){throw "Windows mode test failed: $test"}
  if($old.dmPelsWidth -eq $w -and $old.dmPelsHeight -eq $h -and $old.dmDisplayFrequency -eq $hz){$dmStatus.Text='Already using this display mode.';return}
  $change=[TayDisplay]::Apply($target);if($change -ne 0){throw "Windows rejected mode: $change"}
  $dialog=New-Object Windows.Forms.Form;$dialog.Text='Keep display settings?';$dialog.StartPosition='CenterScreen';$dialog.TopMost=$true;$dialog.Size=[Drawing.Size]::new(420,190)
  $notice=New-Object Windows.Forms.Label;$notice.Location=[Drawing.Point]::new(20,20);$notice.Size=[Drawing.Size]::new(375,65);$dialog.Controls.Add($notice)
  $yes=New-Object Windows.Forms.Button;$yes.Text='Keep changes';$yes.Location=[Drawing.Point]::new(30,100);$yes.Size=[Drawing.Size]::new(150,35);$dialog.Controls.Add($yes)
  $no=New-Object Windows.Forms.Button;$no.Text='Revert';$no.Location=[Drawing.Point]::new(215,100);$no.Size=[Drawing.Size]::new(150,35);$dialog.Controls.Add($no)
  $seconds=15;$accepted=$false;$timer=New-Object Windows.Forms.Timer;$timer.Interval=1000
  $timer.Add_Tick({$seconds--;$notice.Text="Keep $w x $h @ $hz Hz? Reverting in $seconds seconds.";if($seconds -le 0){$dialog.Close()}})
  $yes.Add_Click({$accepted=$true;$dialog.Close()});$no.Add_Click({$dialog.Close()})
  $notice.Text="Keep $w x $h @ $hz Hz? Reverting in 15 seconds."
  $timer.Start();try{[void]$dialog.ShowDialog($form)}finally{$timer.Stop();$timer.Dispose();$dialog.Dispose()}
  if($accepted){$saved=[TayDisplay]::Persist($target);if($saved -ne 0){[void][TayDisplay]::Apply($old);throw "Windows could not save the selected mode ($saved); the previous resolution was restored."};$dmStatus.Text="Saved $w x $h @ $hz Hz; persists after closing Tay-Tweaks.";Log $dmStatus.Text}
  else{$revert=[TayDisplay]::Apply($old);if($revert -ne 0){throw "Restore failed: $revert. Use Windows Display settings."};$dmStatus.Text='Previous resolution restored.'}
  DMRefresh
 }catch{$dmStatus.Text="Display Manager: $($_.Exception.Message)";Log $dmStatus.Text;[Windows.Forms.MessageBox]::Show($dmStatus.Text,'Display Manager')|Out-Null}
 finally{$script:DMBusy=$false}
})
$dmKind.SelectedIndex=0
# Avoid expensive display enumeration and hardware/network probes during app startup.
$displayTab.Add_Enter({if($script:DMModes.Count -eq 0){DMRefresh}})

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
$tabs.Location=[System.Drawing.Point]::new(192,105);$tabs.Size=[System.Drawing.Size]::new(875,570)
$nav=New-Object System.Windows.Forms.Panel;$nav.Location=[System.Drawing.Point]::new(0,94);$nav.Size=[System.Drawing.Size]::new(186,590);$nav.AutoScroll=$true;$nav.Anchor='Top,Bottom,Left';$nav.BackColor=[System.Drawing.Color]::FromArgb(21,17,20);$form.Controls.Add($nav)
$navY=12
foreach($page in @($tabs.TabPages)){
 $b=New-Object System.Windows.Forms.Button;$b.Text='  '+$page.Text;$b.Tag=$page;$b.TextAlign='MiddleLeft';$b.Location=[System.Drawing.Point]::new(8,$navY);$b.Size=[System.Drawing.Size]::new(169,43);$b.FlatStyle='Flat';$b.FlatAppearance.BorderSize=0;$b.BackColor=[System.Drawing.Color]::FromArgb(32,25,28);$b.ForeColor=[System.Drawing.Color]::FromArgb(255,142,75);$b.Font=New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold);$b.Add_Click({$tabs.SelectedTab=$this.Tag});$nav.Controls.Add($b);$navY+=49
}
$nav.AutoScrollMinSize=[System.Drawing.Size]::new(178,$navY+8)
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

# Live usage: use PerformanceCounter sampling rather than synchronous WMI queries every tick.
# WMI on the UI thread caused hangs/non-responsive clicks on some systems.
$usageTab.AutoScroll=$true
$usageIntro=New-Object System.Windows.Forms.Label;$usageIntro.Text='SYSTEM USAGE   /   LIVE MONITORING';$usageIntro.Location=[System.Drawing.Point]::new(20,12);$usageIntro.Size=[System.Drawing.Size]::new(820,36);$usageIntro.Font=New-Object System.Drawing.Font('Segoe UI',18,[System.Drawing.FontStyle]::Bold);$usageIntro.ForeColor=[System.Drawing.Color]::FromArgb(255,112,0);$usageTab.Controls.Add($usageIntro)
$usageLabels=@{};$usageBars=@{};$usageGaugePanels=@{};$script:usageGaugeValues=@{cpu=0;ram=0;gpu=0;cputemp=0};$script:usageAvailable=@{cpu=$false;ram=$false;gpu=$false;cputemp=$false}
function AddUsageMeter([string]$key,[string]$title,[int]$x,[int]$y){
 $panel=New-Object System.Windows.Forms.Panel;$panel.Location=[System.Drawing.Point]::new($x,$y);$panel.Size=[System.Drawing.Size]::new(194,211);$panel.BackColor=[System.Drawing.Color]::FromArgb(22,17,17);$panel.Tag=$key
 $panel.Add_Paint({param($sender,$e)
  $g=$e.Graphics;$g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias;$key=[string]$sender.Tag;$value=[int]$script:usageGaugeValues[$key]
  $track=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(60,58,58),12);$track.StartCap='Round';$track.EndCap='Round'
  $ringColor=[System.Drawing.ColorTranslator]::FromHtml($script:Themes[$script:ThemeName]);$accent=New-Object System.Drawing.Pen($ringColor,12);$accent.StartCap='Round';$accent.EndCap='Round'
  $rect=[System.Drawing.Rectangle]::new(24,15,146,146);$g.DrawArc($track,$rect,-90,359)
  if($script:usageAvailable[$key] -and $value -gt 0){$g.DrawArc($accent,$rect,-90,[single](359*$value/100))}
  $font=New-Object System.Drawing.Font('Segoe UI',20,[System.Drawing.FontStyle]::Bold);$small=New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold)
  $gaugeText=if($script:ThemeName -in @('Light','Pure White')){[System.Drawing.Color]::Black}else{[System.Drawing.Color]::White};$white=New-Object System.Drawing.SolidBrush($gaugeText);$orange=New-Object System.Drawing.SolidBrush($ringColor)
  $format=New-Object System.Drawing.StringFormat;$format.Alignment='Center'
  $caption= switch($key){'cpu'{'CPU'}'gpu'{'GPU'}'ram'{'RAM'}'cputemp'{'TEMP'}}
  $display='N/A';if($script:usageAvailable[$key]){if($key -eq 'cputemp'){$display="$value$([char]176)C"}else{$display="$value%"}}
  $g.DrawString($caption,$small,$orange,[System.Drawing.RectangleF]::new(20,65,154,25),$format)
  $g.DrawString($display,$font,$white,[System.Drawing.RectangleF]::new(15,91,164,46),$format)
  foreach($o in @($track,$accent,$font,$small,$white,$orange,$format)){$o.Dispose()}
 });$usageTab.Controls.Add($panel);$usageGaugePanels[$key]=$panel
 $detail=New-Object System.Windows.Forms.Label;$detail.Text='Waiting for data...';$detail.Location=[System.Drawing.Point]::new(7,174);$detail.Size=[System.Drawing.Size]::new(180,30);$detail.TextAlign='MiddleCenter';$detail.ForeColor=[System.Drawing.Color]::Gainsboro;$panel.Controls.Add($detail);$usageLabels[$key]=$detail
}
AddUsageMeter 'cpu' 'CPU' 15 55
AddUsageMeter 'gpu' 'GPU' 224 55
AddUsageMeter 'ram' 'RAM' 433 55
AddUsageMeter 'cputemp' 'TEMP' 642 55
$usageChart=New-Object System.Windows.Forms.Panel;$usageChart.Location=[System.Drawing.Point]::new(15,278);$usageChart.Size=[System.Drawing.Size]::new(535,228);$usageChart.BackColor=[System.Drawing.Color]::FromArgb(20,15,16);$usageTab.Controls.Add($usageChart)
$script:usageHistory=@{CPU=(New-Object System.Collections.ArrayList);GPU=(New-Object System.Collections.ArrayList);RAM=(New-Object System.Collections.ArrayList)}
$usageChartChoice=New-Object System.Windows.Forms.ComboBox;$usageChartChoice.DropDownStyle='DropDownList';$usageChartChoice.Items.AddRange(@('CPU','GPU','RAM'));$usageChartChoice.SelectedIndex=0;$usageChartChoice.Location=[System.Drawing.Point]::new(424,10);$usageChartChoice.Size=[System.Drawing.Size]::new(100,25);$usageChart.Controls.Add($usageChartChoice)
$usageChart.Add_Paint({param($sender,$e)
 $g=$e.Graphics;$g.SmoothingMode='AntiAlias';$pen=New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml($script:Themes[$script:ThemeName]),2);$gridPen=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(48,48,48),1)
 for($i=0;$i -le 4;$i++){$y=50+$i*39;$g.DrawLine($gridPen,15,$y,520,$y)}
 $samples=@($script:usageHistory[[string]$usageChartChoice.SelectedItem]);if($samples.Count -gt 1){$pts=New-Object 'System.Collections.Generic.List[System.Drawing.PointF]';for($i=0;$i -lt $samples.Count;$i++){$xx=15+($i*505.0/79);$yy=206-([double]$samples[$i]*1.56);$pts.Add([System.Drawing.PointF]::new([single]$xx,[single]$yy))};if($pts.Count -gt 1){$g.DrawLines($pen,$pts.ToArray())}}
 $pen.Dispose();$gridPen.Dispose()
})
$usageChartChoice.Add_SelectedIndexChanged({$usageChart.Invalidate()})
$usageInfo=New-Object System.Windows.Forms.Label;$usageInfo.Location=[System.Drawing.Point]::new(565,278);$usageInfo.Size=[System.Drawing.Size]::new(270,228);$usageInfo.BackColor=[System.Drawing.Color]::FromArgb(23,18,18);$usageInfo.ForeColor=[System.Drawing.Color]::Gainsboro;$usageInfo.Font=New-Object System.Drawing.Font('Segoe UI',10);$usageInfo.Padding=New-Object System.Windows.Forms.Padding(12);$usageInfo.Text='SYSTEM INFO';$usageTab.Controls.Add($usageInfo)
$usageInfo.Text="SYSTEM INFO`r`n`r`nOpen Task Manager for CPU/GPU device details.`r`n`r`nUsage sampling runs only while this page is visible."
$usageFoot=New-Object System.Windows.Forms.Label;$usageFoot.Text='Live readings depend on Windows drivers. Missing temperature sensors display N/A rather than an estimated value.';$usageFoot.Location=[System.Drawing.Point]::new(18,519);$usageFoot.Size=[System.Drawing.Size]::new(800,42);$usageFoot.ForeColor=[System.Drawing.Color]::Silver;$usageTab.Controls.Add($usageFoot)
$usageTab.AutoScrollMinSize=[System.Drawing.Size]::new(850,570)
function SetUsageReading([string]$key,[int]$value,[string]$description){$script:usageGaugeValues[$key]=[math]::Max(0,[math]::Min(100,$value));$script:usageAvailable[$key]=$true;$usageLabels[$key].Text=$description;$usageGaugePanels[$key].Invalidate();$series=switch($key){'cpu'{'CPU'}'gpu'{'GPU'}'ram'{'RAM'}default{''}};if($series){$hist=$script:usageHistory[$series];[void]$hist.Add($value);if($hist.Count -gt 80){$hist.RemoveAt(0)}}}
$script:cpuCounter=$null;$script:memCounter=$null;$script:gpuCounters=@();$script:totalMemoryGB=0.0;$script:lastTempCheck=[datetime]::MinValue
try{$script:cpuCounter=[System.Diagnostics.PerformanceCounter]::new("Processor","% Processor Time","_Total");[void]$script:cpuCounter.NextValue()}catch{}
try{$script:memCounter=[System.Diagnostics.PerformanceCounter]::new("Memory","Available MBytes");[void]$script:memCounter.NextValue()}catch{}
try{$os0=Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop;$script:totalMemoryGB=[math]::Round(([double]$os0.TotalVisibleMemorySize/1MB),1)}catch{}
try{$cat=[System.Diagnostics.PerformanceCounterCategory]::new("GPU Engine");$instances=@($cat.GetInstanceNames() | Where-Object {$_ -match "engtype_3D"});foreach($inst in $instances){try{$script:gpuCounters+=[System.Diagnostics.PerformanceCounter]::new("GPU Engine","Utilization Percentage",$inst)}catch{}}}catch{}
function UpdateUsage {
 try {if($script:cpuCounter){$n=[int][math]::Max(0,[math]::Min(100,$script:cpuCounter.NextValue()));SetUsageReading 'cpu' $n "$n% usage"}else{$usageLabels['cpu'].Text='N/A'}}catch{$usageLabels['cpu'].Text='N/A'}
 try {if($script:memCounter -and $script:totalMemoryGB -gt 0){$freeMB=[double]$script:memCounter.NextValue();$usedGB=[math]::Max(0,$script:totalMemoryGB-($freeMB/1024));$pct=[int][math]::Max(0,[math]::Min(100,(100*$usedGB/$script:totalMemoryGB)));SetUsageReading 'ram' $pct ("{0:N1} / {1:N1} GB" -f $usedGB,$script:totalMemoryGB)}else{$usageLabels['ram'].Text='N/A'}}catch{$usageLabels['ram'].Text='N/A'}
 try {if($script:gpuCounters.Count -gt 0){$sum=0.0;foreach($gc in $script:gpuCounters){try{$sum += [math]::Max(0,$gc.NextValue())}catch{}};$n=[int][math]::Max(0,[math]::Min(100,$sum));SetUsageReading 'gpu' $n "$n% 3D (approx.)"}else{$usageLabels['gpu'].Text='N/A (driver)'}}catch{$usageLabels['gpu'].Text='N/A (driver)'}
 $usageLabels['cputemp'].Text='Sensor unavailable';$script:usageAvailable['cputemp']=$false;if($tabs.SelectedTab -eq $usageTab){$usageChart.Invalidate()}
}
$usageTimer=New-Object System.Windows.Forms.Timer;$usageTimer.Interval=1200;$usageTimer.Add_Tick({UpdateUsage});$usageTab.Add_Enter({UpdateUsage;$usageTimer.Start()});$usageTab.Add_Leave({$usageTimer.Stop()})


# User settings and color themes
$script:SettingsFile=Join-Path $env:APPDATA 'TayTweaks\settings.json';$script:ThemeName='Tay Orange'
$script:Themes=@{'Tay Orange'='#FF7900';'Crimson Red'='#F04452';'Royal Purple'='#A66BFF';'Neon Green'='#48D978';'Ocean Blue'='#4B9FFF';'Midnight'='#9299AA';'Light'='#F28724';'Pure White'='#4B85E8'}
try{if(Test-Path $script:SettingsFile){$saved=Get-Content $script:SettingsFile -Raw|ConvertFrom-Json;if($script:Themes.ContainsKey([string]$saved.theme)){$script:ThemeName=[string]$saved.theme}}}catch{Log "Theme settings load: $($_.Exception.Message)"}
function SaveTheme {try{New-Item -ItemType Directory -Force -Path (Split-Path $script:SettingsFile)|Out-Null;@{theme=$script:ThemeName}|ConvertTo-Json|Set-Content -LiteralPath $script:SettingsFile -Encoding UTF8}catch{Log "Save theme: $($_.Exception.Message)"}}
function ApplyTheme {
 $accent=[System.Drawing.ColorTranslator]::FromHtml($script:Themes[$script:ThemeName]);$light=$script:ThemeName -in @('Light','Pure White');$base=if($light){[System.Drawing.Color]::FromArgb(245,246,249)}else{[System.Drawing.Color]::FromArgb(12,10,12)};$fg=if($light){[System.Drawing.Color]::FromArgb(28,30,35)}else{[System.Drawing.Color]::FromArgb(238,239,243)}
 $form.BackColor=$base;$form.ForeColor=$fg;$head.BackColor=if($light){[System.Drawing.Color]::White}else{[System.Drawing.Color]::FromArgb(18,10,12)};$nav.BackColor=if($light){[System.Drawing.Color]::FromArgb(230,233,239)}else{[System.Drawing.Color]::FromArgb(21,17,20)};$ttl.ForeColor=$accent
 foreach($page in @($tabs.TabPages)){$page.BackColor=$base;$page.ForeColor=$fg}
 function ColorChildren($parent){foreach($c in $parent.Controls){if($c -is [System.Windows.Forms.Button]){$c.BackColor=$accent;$c.ForeColor=[System.Drawing.Color]::Black}elseif($c -is [System.Windows.Forms.Label]){if($c -ne $ttl -and $c -ne $sub -and $c -ne $usageInfo){$c.ForeColor=$fg}};if($c.HasChildren){ColorChildren $c}}}
 foreach($page in @($tabs.TabPages)){ColorChildren $page}
 foreach($b in $nav.Controls){if($b -is [System.Windows.Forms.Button]){$b.ForeColor=$fg;$b.BackColor=if($light){[System.Drawing.Color]::White}else{[System.Drawing.Color]::FromArgb(32,25,28)}}}
 foreach($b in @($apply,$restore,$undo,$logs,$exit)){$b.BackColor=$accent}
 $usageIntro.ForeColor=$accent
 $surface=if($light){[System.Drawing.Color]::White}else{[System.Drawing.Color]::FromArgb(23,20,25)}
 $usageChart.BackColor=$surface;$usageInfo.BackColor=$surface;$usageInfo.ForeColor=$fg
 foreach($meter in $usageGaugePanels.Values){$meter.BackColor=$surface;$meter.Invalidate()}
 foreach($label in $usageLabels.Values){$label.ForeColor=$fg}
 $usageFoot.ForeColor=$fg
 $usageTab.Invalidate();$usageChart.Invalidate()
}
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
$themePicker=New-Object System.Windows.Forms.ComboBox;$themePicker.DropDownStyle='DropDownList';$themePicker.Location=[System.Drawing.Point]::new(24,100);$themePicker.Size=[System.Drawing.Size]::new(280,30);$themePicker.Items.AddRange(@('Tay Orange','Crimson Red','Royal Purple','Neon Green','Ocean Blue','Midnight','Light','Pure White'));$themePicker.SelectedItem=$script:ThemeName;$settingsTab.Controls.Add($themePicker)
$themePicker.Add_SelectedIndexChanged({$script:ThemeName=[string]$themePicker.SelectedItem;SaveTheme;ApplyTheme})
PageLabel $settingsTab 'UPDATES / GITHUB' 24 162 | Out-Null
$updateStatus=PageLabel $settingsTab 'Update status: Not checked' 24 205
$script:AppVersion=[version]'6.1.6';$script:UpdateUrl='https://raw.githubusercontent.com/Tayegandev/Tay-Tweaks/main/latest.json';$script:UpdateBusy=$false
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
$about.Text="TAY TWEAKS v6.1.6`r`n`r`nBuilt for Windows 10/11, including older systems such as Intel Core i5-4590 / 16 GB RAM / Intel HD 4600.`r`n`r`nInspired by common categories found in public PC optimization tools; this is an original implementation, not copied proprietary code.`r`n`r`nSafety:`r`n• Administrator mode for system actions.`r`n• A successful restore point is required before registry tweaks.`r`n• Previous values of modified registry entries are saved for Undo.`r`n• Cleanup/network actions confirm potentially destructive actions.`r`n`r`nReality check:`r`n• No tweak guarantees more FPS or lower ping.`r`n• Avoid disabling Defender, Windows Update, or random services.`r`n• Intel HD 4600 is an older integrated GPU; in-game settings and background apps usually matter more than obscure registry edits.`r`n• Usage readings depend on Windows drivers; CPU/GPU temperatures may not be exposed.`r`n`r`nBackup/log path: $DataDir"
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
$exit.Add_Click({$usageTimer.Stop();$homeClockTimer.Stop();try{$script:cpuCounter.Dispose();$script:memCounter.Dispose();foreach($gc in $script:gpuCounters){$gc.Dispose()}}catch{};$form.Close()})
ApplyTheme
Log "Tay-Tweaks launched."
[void]$form.ShowDialog()
