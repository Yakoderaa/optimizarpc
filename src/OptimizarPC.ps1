# OptimizarPC
$ErrorActionPreference = 'Stop'
$CurrentVersion = '1.0.0'
$Repo = 'Yakoderaa/optimizarpc'
$ManifestUrl = "https://raw.githubusercontent.com/$Repo/main/update.json"
$AppRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $env:LOCALAPPDATA 'OptimizarPC'
$LogFile = Join-Path $LogDir 'optimizarpc.log'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Log($m) { try { Add-Content -Path $LogFile -Value "$(Get-Date -Format s) $m" } catch {} }
function Format-Bytes([double]$n) {
  if ($n -ge 1TB) { return ('{0:N2} TB' -f ($n/1TB)) }
  if ($n -ge 1GB) { return ('{0:N2} GB' -f ($n/1GB)) }
  if ($n -ge 1MB) { return ('{0:N1} MB' -f ($n/1MB)) }
  return ('{0:N0} KB' -f ($n/1KB))
}
function Is-Admin {
  $p=[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function NL { return [Environment]::NewLine }
function Set-Status($t) { $status.Text=$t; $status.Refresh() }

function Get-Diagnostics {
  $os=Get-CimInstance Win32_OperatingSystem
  $cpu=Get-CimInstance Win32_Processor | Select-Object -First 1
  $gpus=Get-CimInstance Win32_VideoController | Where-Object {$_.Name}
  $disks=Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
  $ramTotal=[double]$os.TotalVisibleMemorySize*1KB
  $ramFree=[double]$os.FreePhysicalMemory*1KB
  $ramUsed=$ramTotal-$ramFree
  $textBox.Clear()
  $textBox.AppendText("OPTIMIZARPC - DIAGNOSTICO"+(NL)+(NL))
  $textBox.AppendText("Windows: $($os.Caption) | Build $($os.BuildNumber)"+(NL))
  $textBox.AppendText("CPU: $($cpu.Name)"+(NL))
  $textBox.AppendText("RAM: $(Format-Bytes $ramUsed) usada / $(Format-Bytes $ramTotal) total ($([math]::Round($ramUsed/$ramTotal*100))%)"+(NL))
  $textBox.AppendText("GPU(s): "+(($gpus | Select-Object -Expand Name) -join '; ')+(NL)+(NL))
  $textBox.AppendText("DISCOS:"+(NL))
  foreach($d in $disks) { $textBox.AppendText("  $($d.DeviceID) Libre $(Format-Bytes $d.FreeSpace) / $(Format-Bytes $d.Size)"+(NL)) }
  $textBox.AppendText((NL)+"PROCESOS CON MAYOR CPU ACUMULADA:"+(NL))
  Get-Process | Sort-Object CPU -Descending | Select-Object -First 12 | ForEach-Object {
    $textBox.AppendText(("  {0,-28} CPU {1,8} RAM {2}" -f $_.ProcessName,$_.CPU,(Format-Bytes $_.WorkingSet64))+(NL))
  }
  Set-Status "Diagnostico completado."
  Log "Diagnostics executed"
}

function Clean-Safe {
  $paths=@($env:TEMP,(Join-Path $env:WINDIR 'Temp')); $deleted=0
  foreach($p in $paths) {
    if(Test-Path $p) {
      Get-ChildItem $p -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try { Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop; $script:deleted++ } catch {}
      }
    }
  }
  try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch {}
  Set-Status "Limpieza terminada. Elementos eliminados: $deleted"
  [Windows.Forms.MessageBox]::Show(("Limpieza segura terminada."+(NL)+"Elementos eliminados: $deleted"),"OptimizarPC")
  Log "Safe cleanup: $deleted items"
}

function Get-StartupItems {
  $locations=@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run')
  $rows=@()
  foreach($loc in $locations) {
    if(Test-Path $loc) {
      $p=Get-ItemProperty $loc
      foreach($x in $p.PSObject.Properties | Where-Object {$_.Name -notmatch '^PS'}) {
        $rows += [pscustomobject]@{Ubicacion=$loc;Nombre=$x.Name;Comando=[string]$x.Value}
      }
    }
  }
  return $rows
}
function Show-Startup {
  $textBox.Clear();$textBox.AppendText("PROGRAMAS DE INICIO"+(NL)+(NL))
  foreach($x in Get-StartupItems) {
    $textBox.AppendText("$($x.Nombre)"+(NL))
    $textBox.AppendText("  $($x.Comando)"+(NL))
    $textBox.AppendText("  $($x.Ubicacion)"+(NL)+(NL))
  }
}
function Show-Services {
  $textBox.Clear();$textBox.AppendText("SERVICIOS - INVENTARIO"+(NL)+(NL))
  Get-CimInstance Win32_Service | Sort-Object Name | ForEach-Object {
    $textBox.AppendText(("{0,-38} {1,-10} {2,-12}" -f $_.Name,$_.State,$_.StartMode)+(NL))
  }
}
function Repair-Network {
  if(-not(Is-Admin)){[Windows.Forms.MessageBox]::Show("Necesitas ejecutar OptimizarPC como administrador.","OptimizarPC");return}
  Set-Status "Reparando DNS, Winsock y TCP/IP..."
  ipconfig /flushdns | Out-Null; netsh winsock reset | Out-Null; netsh int ip reset | Out-Null
  Set-Status "Reparacion de red completada."
  [Windows.Forms.MessageBox]::Show(("Se ejecutaron Flush DNS, Winsock reset y TCP/IP reset."+(NL)+"Reinicia Windows si es necesario."),"OptimizarPC")
  Log "Network repair executed"
}
function Set-HighPerformance {
  if(-not(Is-Admin)){[Windows.Forms.MessageBox]::Show("Necesitas ejecutar como administrador.","OptimizarPC");return}
  powercfg /setactive SCHEME_MIN | Out-Null
  Set-Status "Perfil Alto rendimiento aplicado."; Log "High performance profile applied"
}
function Create-RestorePoint {
  if(-not(Is-Admin)){[Windows.Forms.MessageBox]::Show("Necesitas ejecutar como administrador.","OptimizarPC");return}
  try {
    Checkpoint-Computer -Description "OptimizarPC - Antes de optimizar" -RestorePointType MODIFY_SETTINGS
    [Windows.Forms.MessageBox]::Show("Punto de restauracion creado.","OptimizarPC");Log "Restore point created"
  } catch { [Windows.Forms.MessageBox]::Show("No se pudo crear el punto de restauracion."+(NL)+$_.Exception.Message,"OptimizarPC") }
}

function Update-App {
  Set-Status "Buscando actualizacion..."
  try {
    $m=Invoke-RestMethod -Uri $ManifestUrl -UseBasicParsing -TimeoutSec 15
    $latest=[version]$m.version
    if($latest -le [version]$CurrentVersion) {
      Set-Status "Ya estas actualizado ($CurrentVersion)"
      [Windows.Forms.MessageBox]::Show("Ya tenes la ultima version ($CurrentVersion).","Actualizaciones");return
    }
    $answer=[Windows.Forms.MessageBox]::Show(("Nueva version: $($m.version)."+(NL)+(NL)+$m.notes+(NL)+(NL)+"Descargar e instalar ahora?"),"Actualizacion disponible",[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Information)
    if($answer -ne [Windows.Forms.DialogResult]::Yes){return}
    $tmp=Join-Path $env:TEMP ("OptimizarPC-update-"+[guid]::NewGuid());New-Item -ItemType Directory -Force $tmp | Out-Null
    $zip=Join-Path $tmp 'package.zip';Invoke-WebRequest -Uri $m.packageUrl -OutFile $zip -UseBasicParsing
    if($m.sha256){$hash=(Get-FileHash $zip -Algorithm SHA256).Hash.ToLower();if($hash -ne $m.sha256.ToLower()){throw "La verificacion SHA-256 del paquete fallo."}}
    $stage=Join-Path $tmp 'package';Expand-Archive -Path $zip -DestinationPath $stage -Force
    $root=Get-ChildItem $stage -Directory | Select-Object -First 1;if(-not $root){throw "Paquete invalido."}
    $updater=Join-Path $tmp 'updater.ps1';$scriptPath=Join-Path $root.FullName 'src\OptimizarPC.ps1'
    $updaterCode=@'
param([string]$Source,[string]$Target,[string]$ScriptPath,[string]$Tmp)
Start-Sleep -Seconds 2
New-Item -ItemType Directory -Force $Target | Out-Null
robocopy $Source $Target /E /R:2 /W:1 /NFL /NDL /NJH /NJS | Out-Null
Start-Process -FilePath powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$ScriptPath)
Remove-Item $Tmp -Recurse -Force -ErrorAction SilentlyContinue
'@
    Set-Content -Path $updater -Value $updaterCode -Encoding UTF8
    Start-Process -FilePath powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$updater,'-Source',$root.FullName,'-Target',$AppRoot,'-ScriptPath',$scriptPath,'-Tmp',$tmp) -Verb RunAs
    $form.Close()
  } catch {
    Set-Status "Error al actualizar."
    [Windows.Forms.MessageBox]::Show("No se pudo actualizar."+(NL)+$_.Exception.Message,"Actualizacion")
    Log "Update failed: $($_.Exception.Message)"
  }
}

$form=New-Object Windows.Forms.Form
$form.Text="OptimizarPC $CurrentVersion";$form.Size=New-Object Drawing.Size(1050,680);$form.StartPosition='CenterScreen';$form.MinimumSize=New-Object Drawing.Size(900,600)
$menu=New-Object Windows.Forms.Panel;$menu.Dock='Left';$menu.Width=220;$menu.BackColor=[Drawing.Color]::FromArgb(28,30,34);$form.Controls.Add($menu)
$title=New-Object Windows.Forms.Label;$title.Text="OPTIMIZARPC";$title.ForeColor=[Drawing.Color]::White;$title.Font=New-Object Drawing.Font('Segoe UI',18,[Drawing.FontStyle]::Bold);$title.Location=New-Object Drawing.Point(25,25);$title.AutoSize=$true;$menu.Controls.Add($title)
function Add-MenuButton($text,$top,$action) {
  $b=New-Object Windows.Forms.Button;$b.Text=$text;$b.Location=New-Object Drawing.Point(18,$top);$b.Size=New-Object Drawing.Size(184,42)
  $b.FlatStyle='Flat';$b.ForeColor=[Drawing.Color]::White;$b.BackColor=[Drawing.Color]::FromArgb(40,43,48);$b.Add_Click($action);$menu.Controls.Add($b)
}
Add-MenuButton 'Diagnostico' 90 {Get-Diagnostics}
Add-MenuButton 'Limpieza segura' 140 {Clean-Safe}
Add-MenuButton 'Programas de inicio' 190 {Show-Startup}
Add-MenuButton 'Servicios' 240 {Show-Services}
Add-MenuButton 'Alto rendimiento' 290 {Set-HighPerformance}
Add-MenuButton 'Reparar red' 340 {Repair-Network}
Add-MenuButton 'Punto de restauracion' 390 {Create-RestorePoint}
Add-MenuButton 'Buscar actualizaciones' 440 {Update-App}
$textBox=New-Object Windows.Forms.TextBox;$textBox.Multiline=$true;$textBox.ReadOnly=$true;$textBox.ScrollBars='Both';$textBox.Font=New-Object Drawing.Font('Consolas',10);$textBox.Dock='Fill';$textBox.BackColor=[Drawing.Color]::FromArgb(245,246,248);$form.Controls.Add($textBox);$textBox.BringToFront()
$status=New-Object Windows.Forms.Label;$status.Text="Listo. Ejecuta Diagnostico para comenzar.";$status.Dock='Bottom';$status.Height=30;$status.Padding=New-Object Windows.Forms.Padding(12,6,0,0);$form.Controls.Add($status)
$form.Add_Shown({Get-Diagnostics});[void]$form.ShowDialog()
