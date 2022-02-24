param([switch]$Elevated)
function Test-Admin {
  $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())

  $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
if ((Test-Admin) -eq $false) {
  if ($elevated) {
    # tried to elevate, did not work, aborting
  }
  else {
    Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
  }
  Exit
}

if (-not(Get-Command "choco -v" -errorAction SilentlyContinue)) {
  Write-Output "Chololatey does not exist! Installing..."
  # install chocolatey
  Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}
else {
  Write-Output "Chocolatey is already installed. Continueing..."
}

if (-not(Get-Command "vboxmanage --version" -errorAction SilentlyContinue)) {
  Write-Output "Virtual-Box does not exist! Installing..."
  # install virtualbox
  choco install virtualbox -y
}
else {
  Write-Output "Virtual-Box is already installed. Continueing..."
}


if (-not(Get-Command "vagrant -v" -errorAction SilentlyContinue)) {
  Write-Output "Vagrant does not exist! Installing..."
  choco install vagrant -y
}
else {
  Write-Output "Vagrant is already isntalled. Continueing..."
}

#! has to be run after reboot SOLUTION not found
vboxmanage hostonlyif remove "VirtualBox Host-Only Ethernet Adapter";
vboxmanage hostonlyif create;
vboxmanage dhcpserver remove --interface="VirtualBox Host-Only Ethernet Adapter";
vboxmanage hostonlyif ipconfig "VirtualBox Host-Only Ethernet Adapter" --ip 192.168.56.1;
