Write-Output "Installing PowerShell dependencies..."
$PSDefaultParameterValues["*:Confirm"] = $false
$PSDefaultParameterValues["*:Force"] = $true
Set-PSRepository PSGallery -InstallationPolicy Trusted

# Check if modules are already installed
if (-not (Get-Module -ListAvailable -Name dbatools)) {
    Install-Module dbatools, Pester, aitoolkit
    Install-Module psopenai
    Install-Module finetuna
}

# Reload profile with some settings we need
. $profile

# Check if the Northwind database already exists
if (-not (Get-DbaDatabase -SqlInstance localhost -Database Northwind)) {
    Write-Output "Importing Northwind..."
    Invoke-WebRequest https://raw.githubusercontent.com/microsoft/sql-server-samples/refs/heads/master/samples/databases/northwind-pubs/instnwnd.sql -OutFile /home/mssql/instnwnd.sql
    Invoke-DbaQuery -SqlInstance localhost -Database master -Query "CREATE DATABASE Northwind"
    Invoke-DbaQuery -SqlInstance localhost -Database Northwind -InputFile /home/mssql/instnwnd.sql
}