# do it
Write-Output "Installing PowerShell dependencies..."
$PSDefaultParameterValues["*:Confirm"] = $false
$PSDefaultParameterValues["*:Force"] = $true
$PSDefaultParameterValues["*:Scope"] = "CurrentUser"
Install-PackageProvider -Name NuGet
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module dbatools, psopenai, PSReadLine