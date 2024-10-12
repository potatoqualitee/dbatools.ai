$script:ModuleRoot = $PSScriptRoot
$script:dbSchema = @{}
$script:foreignKeyCache = @{}
$script:dbassist = {}
$script:threadcache = @{}
$script:ModuleRootLib = Join-Path -Path $script:ModuleRoot -Childpath lib

switch ($PSVersionTable.Platform) {
    "Unix" {
        $script:configdir = "$home/.config/dbatools.ai"
        if (-not (Test-Path -Path $script:configdir)) {
            $null = New-Item -Path $script:configdir -ItemType Directory -Force
        }
    }
    default {
        $script:configdir = "$env:APPDATA\dbatools.ai"
        if (-not (Test-Path -Path $script:configdir)) {
            $null = New-Item -Path $script:configdir -ItemType Directory -Force
        }
    }
}

function Import-ModuleFile {
    [CmdletBinding()]
    Param (
        [string]
        $Path
    )

    if ($doDotSource) { . $Path }
    else { $ExecutionContext.InvokeCommand.InvokeScript($false, ([scriptblock]::Create([io.file]::ReadAllText($Path))), $null, $null) }
}

# Import all internal functions
foreach ($function in (Get-ChildItem "$ModuleRoot\private\" -Filter "*.ps1" -Recurse -ErrorAction Ignore)) {
    . Import-ModuleFile -Path $function.FullName
}

# Import all public functions
foreach ($function in (Get-ChildItem "$ModuleRoot\public" -Filter "*.ps1" -Recurse -ErrorAction Ignore)) {
    . Import-ModuleFile -Path $function.FullName
}

# Create powershell alias called dbai for Invoke-DbaiQuery
Set-Alias -Name dbai -Value Invoke-DbaiQuery
Set-Alias -Name dtai -Value Invoke-DbatoolsAI

$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'


Set-Alias -Name Reset-DbaiProvider -Value Clear-DbaiProvider
$configFile = Join-Path -Path $script:configdir -ChildPath config.json

if (Test-Path -Path $configFile) {
    $persisted = Get-Content -Path $configFile -Raw | ConvertFrom-Json
    $splat = @{}
    if ($persisted.ApiKey) {
        $splat.ApiKey = $persisted.ApiKey
    }
    if ($persisted.ApiBase) {
        $splat.ApiBase = $persisted.ApiBase
    }
    if ($persisted.Deployment) {
        $splat.Deployment = $persisted.Deployment
    }
    if ($persisted.ApiType) {
        $splat.ApiType = $persisted.ApiType
    }
    if ($persisted.ApiVersion) {
        $splat.ApiVersion = $persisted.ApiVersion
    }
    if ($persisted.AuthType) {
        $splat.AuthType = $persisted.AuthType
    }
    if ($persisted.Organization) {
        $splat.Organization = $persisted.Organization
    }
    $null = Set-DbaiProvider @splat
}

$PSDefaultParameterValues['Import-Module:Verbose'] = $false
$PSDefaultParameterValues['Add-Type:Verbose'] = $false

if (-not (Get-DbaiProvider).ApiKey) {
    Write-Warning "No API key found. Use Set-DbaiProvider or `$env:OPENAI_API_KEY to set the API key."
}