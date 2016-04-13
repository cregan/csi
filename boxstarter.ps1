# A simple BoxStarter script for use with http://boxstarter.org/WebLauncher
# Updates a Windows machine and installs a range of developer tools

# Show more info for files in Explorer
Set-WindowsExplorerOptions -EnableShowFileExtensions -EnableShowFullPathInTitleBar

# Default to the desktop rather than application launcher
Set-StartScreenOptions -EnableBootToDesktop -EnableDesktopBackgroundOnStart -EnableShowStartOnActiveScreen -EnableShowAppsViewOnStartScreen -EnableSearchEverywhereInAppsView -EnableListDesktopAppsFirst

# Allow running PowerShell scripts
Update-ExecutionPolicy Unrestricted

# Allow unattended reboots
$Boxstarter.RebootOk=$true
$Boxstarter.AutoLogin=$true

# Update Windows and reboot if necessary
Install-WindowsUpdate -AcceptEula
#if (Test-PendingReboot) { Invoke-Reboot }

# Install software

choco install flashplayerplugin -y
choco install googlechrome -y
choco install 7zip.install -y
choco install adobereader -y
choco install vlc -y
choco install dotnet4.5.1 -y
choco install dotnet3.5 -y
choco install vcredist2008 -y
choco install vcredist2012 -y
choco install vcredist2013 -y
choco install quicktime -y
choco install adobeshockwaveplayer -y
choco install wget -y
choco install audacity -y
choco install powershell4 -y
