# do it
Write-Output "Installing PowerShell dependencies..."
$PSDefaultParameterValues["*:Confirm"] = $false
$PSDefaultParameterValues["*:Force"] = $true
$PSDefaultParameterValues["*:Verbose"] = $true
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module dbatools, psopenai
