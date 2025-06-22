$PSDefaultParameterValues["*:Confirm"] = $false
$PSDefaultParameterValues["*:Force"] = $true

# Check if modules are already installed
if (-not (Get-Module -ListAvailable -Name dbatools)) {
    Write-Output "Installing PowerShell dependencies..."
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module dbatools, Pester, aitoolkit
    Install-Module psopenai
    Install-Module finetuna
}

# Fix PSOpenAI ApiBase bug
$psopenaiModule = Get-Module -ListAvailable -Name PSOpenAI | Select-Object -First 1
if ($psopenaiModule) {
    $parameterPath = Join-Path $psopenaiModule.ModuleBase "Private/Get-OpenAIAPIParameter.ps1"
    $content = Get-Content $parameterPath
    $content = $content -replace '\$OpenAIParameter\.ApiBase = \$null', '#$OpenAIParameter.ApiBase = $null'
    Set-Content $parameterPath $content
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

# if tempdb.dbo.pet_vaccinations exists, drop it
$params = @{
    SqlInstance = "localhost"
    Database    = "tempdb"
    Table       = "pet_vaccinations"
    Confirm     = $false
}

Remove-DbaDbTable @params
