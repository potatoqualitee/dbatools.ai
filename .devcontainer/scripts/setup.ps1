Write-Output "Installing PowerShell dependencies..."
$PSDefaultParameterValues["*:Confirm"] = $false
$PSDefaultParameterValues["*:Force"] = $true
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module dbatools, psopenai
Install-Module finetuna

Write-Output "Setting up Northwind..."
Write-Output "Downloading Northwind..."
Invoke-WebRequest https://raw.githubusercontent.com/microsoft/sql-server-samples/refs/heads/master/samples/databases/northwind-pubs/instnwnd.sql -OutFile /home/mssql/instnwnd.sql

# Reload profile with some settings with need
. $profile

Write-Output "Importing Northwind..."
Invoke-DbaQuery -SqlInstance localhost -Database master -Query "CREATE DATABASE Northwind"
Invoke-DbaQuery -SqlInstance localhost -Database Northwind -InputFile /home/mssql/instnwnd.sql