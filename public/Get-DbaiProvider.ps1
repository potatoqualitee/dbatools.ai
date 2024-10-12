function Get-DbaiProvider {
    <#
    .SYNOPSIS
        Retrieves the current OpenAI provider configuration.

    .DESCRIPTION
        The Get-DbaiProvider function retrieves the current OpenAI provider configuration.

        It retrieves the configuration from the persisted configuration file if the -Persisted switch is used.

    .PARAMETER Persisted
        A switch parameter that determines whether to retrieve only the persisted configuration. By default, the function retrieves the session configuration.

    .PARAMETER PlainText
        A switch parameter that determines whether to return the API key in plain text. By default, the function masks the API key.

    .EXAMPLE
        Get-DbaiProvider

        This example retrieves the current session's OpenAI provider configuration.

    .EXAMPLE
        Get-DbaiProvider -Persisted

        This example retrieves the persisted OpenAI provider configuration.
    #>
    [CmdletBinding()]
    param(
        [switch]$Persisted,
        [switch]$PlainText
    )

    $configFile = Join-Path -Path $script:configdir -ChildPath config.json

    if ($Persisted) {
        Write-Verbose "Persisted switch used. Retrieving persisted configuration."
        if (Test-Path -Path $configFile) {
            Write-Verbose "Persisted configuration file found. Reading configuration."
            Get-Content -Path $configFile -Raw | ConvertFrom-Json
        } else {
            Write-Warning "No persisted configuration found."
        }
    } else {
        Write-Verbose "Retrieving current session's OpenAI provider configuration."
        $context = Get-OpenAIContext

        if ($context.ApiKey) {
            Write-Verbose "Context found. Processing configuration."

            if ($context.ApiKey) {
                Write-Verbose "ApiKey found in context. Decrypting ApiKey."
                $decryptedkey = Get-DecryptedString -SecureString $context.ApiKey

                if ($decryptedkey) {
                    Write-Verbose "ApiKey decrypted successfully. Masking ApiKey."
                    $splat = @{
                        Source               = $decryptedkey
                        First                = $first
                        Last                 = 2
                        MaxNumberOfAsterisks = 45
                    }
                    $maskedkey = Get-MaskedKeyString @splat
                } else {
                    Write-Verbose "Failed to decrypt ApiKey."
                    $maskedkey = $null
                }
            }

            if ($PlainText) {
                Write-Verbose "PlainText switch used. Returning ApiKey in plain text."
                $maskedkey = $decryptedkey
            }

            Write-Verbose "Creating configuration object."
            [pscustomobject]@{
                ApiKey       = $maskedkey
                AuthType     = $context.AuthType
                ApiType      = $context.ApiType
                Deployment   = $PSDefaultParameterValues['*:Deployment']
                ApiBase      = $context.ApiBase
                ApiVersion   = $context.ApiVersion
                Organization = $context.Organization
            }
        } else {
            Write-Verbose "No context found. Attempting to retrieve ApiKey from environment."
            $maskedkey = Get-ApiKey

            if ($maskedkey) {
                Write-Verbose "ApiKey found in environment. Setting AuthType to 'openai'."
                $auth = "openai"
            } else {
                Write-Verbose "No ApiKey found. Setting AuthType to null."
                $auth = $null
            }

            Write-Verbose "Creating default configuration object."
            [pscustomobject]@{
                ApiKey       = $maskedkey
                AuthType     = $auth
                ApiType      = $auth
                Deployment   = $PSDefaultParameterValues['*:Deployment']
                ApiBase      = $null
                ApiVersion   = $null
                Organization = $null
            }
        }
    }
}