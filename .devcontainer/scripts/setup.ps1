Write-Output "Installing PowerShell dependencies..."
$PSDefaultParameterValues["*:Confirm"] = $false
$PSDefaultParameterValues["*:Force"] = $true
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module dbatools, psopenai
Import-Module dbatools, psopenai