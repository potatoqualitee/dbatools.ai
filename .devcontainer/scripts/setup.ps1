# psreadline loses its mind trying to save
Set-PSReadLineOption -HistorySaveStyle SaveNothing

# do it
Write-Output "Installing PowerShell dependencies..."
$PSDefaultParameterValues["*:Confirm"] = $false
$PSDefaultParameterValues["*:Force"] = $true
Install-PackageProvider -Name NuGet
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module dbatools, psopenai