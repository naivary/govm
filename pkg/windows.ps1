param([switch]$Elevated)
function Test-Admin {
$currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())

$currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
if ((Test-Admin) -eq $false)
{
if ($elevated) {
# tried to elevate, did not work, aborting
} else {
Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
}
Exit
}

if (-not(Get-Command "choco -v" -errorAction SilentlyContinue))
{
  Write-Output "Chololatey does not exist! Installing..."
  # install chocolatey
  Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
} else {
  Write-Output "Chocolatey is already installed. Continueing..."
}

if (-not(Get-Command "vboxmanage --version" -errorAction SilentlyContinue))
{
  Write-Output "Virtual-Box does not exist! Installing..."
  # install virtualbox
  choco install virtualbox -y
} else {
  Write-Output "Virtual-Box is already installed. Continueing..."
}


if (-not(Get-Command "vagrant -v" -errorAction SilentlyContinue)) 
{
  Write-Output "Vagrant does not exist! Installing..."
  choco install vagrant
} else {
  Write-Output "Vagrant is already isntalled. Continueing..."
}