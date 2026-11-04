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
 public static int Apply(DEVMODE d){return ChangeDisplaySettingsEx(null,ref d,IntPtr.Zero,1,IntPtr.Zero);}
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
$dmHz=New-Object Windows.Forms.ComboBox;$dmHz.DropDownStyle='DropDownList';$dmHz.Location=[Drawing.Point]::new(325,238);$dmHz.Width=140;$displayTab.Controls.Add($dmHz)
[void](DMLabel 'Custom entries require driver support. Unsupported modes will not be forced.' 24 286)
$dmStatus=DMLabel 'Ready.' 24 328
$dmRefresh=New-Object Windows.Forms.Button;$dmRefresh.Text='Refresh modes';$dmRefresh.Location=[Drawing.Point]::new(24,380);$dmRefresh.Size=[Drawing.Size]::new(150,38);$displayTab.Controls.Add($dmRefresh)
$dmApply=New-Object Windows.Forms.Button;$dmApply.Text='Apply and confirm';$dmApply.Location=[Drawing.Point]::new(195,380);$dmApply.Size=[Drawing.Size]::new(180,38);$displayTab.Controls.Add($dmApply)
$script:DMModes=@();$script:DMBusy=$false
function DMRefresh {
 try{
  $old=[TayDisplay]::Current();$dmCurrent.Text="Current: $($old.dmPelsWidth) x $($old.dmPelsHeight) @ $($old.dmDisplayFrequency) Hz"
  $script:DMModes=@();$seen=@{}
  for($i=0;$i -lt 4096;$i++){
   $d=[TayDisplay]::Blank();if(-not [TayDisplay]::EnumDisplaySettings($null,$i,[ref]$d)){break}
   if($d.dmBitsPerPel -lt 24){continue}
   $key="$($d.dmPelsWidth)x$($d.dmPelsHeight)@$($d.dmDisplayFrequency)"
   if(-not $seen.ContainsKey($key)){$seen[$key]=$true;$script:DMModes+=,$d}
  }
  $dmHz.Items.Clear()
  foreach($hz in @($script:DMModes | ForEach-Object {$_.dmDisplayFrequency} | Sort-Object -Unique)){[void]$dmHz.Items.Add([string]$hz)}
  if($dmHz.Items.Contains([string]$old.dmDisplayFrequency)){$dmHz.SelectedItem=[string]$old.dmDisplayFrequency}
  elseif($dmHz.Items.Count){$dmHz.SelectedIndex=0}
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
  if($dmHz.Items.Contains([string]$d.dmDisplayFrequency)){$dmHz.SelectedItem=[string]$d.dmDisplayFrequency}
 }elseif($dmKind.SelectedIndex -eq 1){
  $p=([string]$dmMode.SelectedItem).Split('x');$dmW.Value=[decimal][int]$p[0];$dmH.Value=[decimal][int]$p[1]
 }
})
$dmRefresh.Add_Click({DMRefresh})
$dmApply.Add_Click({
 if($script:DMBusy){return};$script:DMBusy=$true
 try{
  $old=[TayDisplay]::Current()
  $w=[uint32][int]$dmW.Value;$h=[uint32][int]$dmH.Value
  if($null -eq $dmHz.SelectedItem){throw 'Select a refresh rate.'}
  $hz=[uint32][int]([string]$dmHz.SelectedItem);$target=$null
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
  if($accepted){$dmStatus.Text="Saved $w x $h @ $hz Hz; persists after closing Tay-Tweaks.";Log $dmStatus.Text}
  else{$revert=[TayDisplay]::Apply($old);if($revert -ne 0){throw "Restore failed: $revert. Use Windows Display settings."};$dmStatus.Text='Previous resolution restored.'}
  DMRefresh
 }catch{$dmStatus.Text="Display Manager: $($_.Exception.Message)";Log $dmStatus.Text;[Windows.Forms.MessageBox]::Show($dmStatus.Text,'Display Manager')|Out-Null}
 finally{$script:DMBusy=$false}
})
$dmKind.SelectedIndex=0;DMRefresh
