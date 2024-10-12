function Clear-DbaiProvider {
    <#
    .SYNOPSIS
        Clears the OpenAI provider configuration.

    .DESCRIPTION
        The Clear-DbaiProvider function clears the OpenAI provider configuration by removing the persisted configuration file and resetting the module-scoped configuration object.

        It removes the persisted configuration file, if it exists, and clears the PSDefaultParameterValues object to its default values.

        This function also removes any environment variables and global scope variables related to the OpenAI provider.

    .EXAMPLE
        PS C:\> Clear-DbaiProvider

        This example clears the OpenAI provider configuration, removing any persisted configuration files and resetting the environment and global scope variables.

    #>
    [CmdletBinding()]
    param ()

    $configFile = Join-Path -Path $script:configdir -ChildPath config.json

    if (Test-Path -Path $configFile) {
        Remove-Item -Path $configFile -Force
    }
    $null = Clear-OpenAIContext
    $env:OPENAI_API_KEY = $null
    $env:OPENAI_API_BASE = $null

    if ($global:OPENAI_API_BASE) {
        Write-Verbose "Removing OPENAI_API_KEY from global scope."
        $null = Remove-Variable -Name OPENAI_API_BASE -Scope Global -Force
    }
    if ($global:OPENAI_API_KEY) {
        Write-Verbose "Removing OPENAI_API_KEY from global scope."
        $null = Remove-Variable -Name OPENAI_API_KEY -Scope Global -Force
    }
    if ($env:OPENAI_API_KEY) {
        Write-Verbose "Removing OPENAI_API_KEY from environment."
        $null = Remove-Variable -Name OPENAI_API_KEY -Scope Environment -Force
    }
    if ($env:OPENAI_API_BASE) {
        Write-Verbose "Removing OPENAI_API_BASE from environment."
        $null = Remove-Variable -Name OPENAI_API_BASE -Scope Environment -Force
    }
    $defaults = Get-Variable -Name PSDefaultParameterValues -Scope Global -ValueOnly
    if ($defaults["*:ApiKey"]) {
        Write-Verbose "Removing default ApiKey from PSDefaultParameterValues."
        $null = $defaults.Remove("*:ApiKey")
    }
    if ($PSDefaultParameterValues["*:Deployment"]) {
        Write-Verbose "Removing default Deployment from PSDefaultParameterValues."
        $null = $PSDefaultParameterValues.Remove("*:Deployment")
        $null = $PSDefaultParameterValues.Remove("*:Model")
    }

    Write-Verbose "OpenAI provider configuration reset to default."
    Get-DbaiProvider
}