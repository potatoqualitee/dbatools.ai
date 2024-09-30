Write-Output "Installing PowerShell dependencies..."
$PSDefaultParameterValues["*:Confirm"] = $false
$PSDefaultParameterValues["*:Force"] = $true
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module dbatools, psopenai
Import-Module dbatools, psopenai
Write-Output "Starting SQL Server..."
Start-Job -Name mssql -ScriptBlock { /opt/mssql/bin/sqlservr }