# psreadline loses its mind trying to save
Set-PSReadLineOption -HistorySaveStyle SaveNothing
Write-Output "Installing PowerShell dependencies..."
$PSDefaultParameterValues["*:Confirm"] = $false
$PSDefaultParameterValues["*:Force"] = $true
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module dbatools, psopenai