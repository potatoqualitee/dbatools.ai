# do it
Write-Output "Installing PowerShell dependencies..."
$PSDefaultParameterValues["*:Confirm"] = $false
$PSDefaultParameterValues["*:Force"] = $true
$PSDefaultParameterValues["*:Verbose"] = $true
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module dbatools, psopenai
Invoke-WebRequest https://raw.githubusercontent.com/microsoft/sql-server-samples/refs/heads/master/samples/databases/northwind-pubs/instnwnd.sql -OutFile /home/mssql/instnwnd.sql
. $profile
Invoke-DbaQuery -SqlInstance localhost -Database master -Query "CREATE DATABASE Northwind"
Invoke-DbaQuery -SqlInstance localhost -Database Northwind -InputFile /home/mssql/instnwnd.sql