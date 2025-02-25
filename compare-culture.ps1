### Kinda like PowerShell params? But it's output and not input.
    
```powershell
[Parameter(Mandatory)]
[ValidateSet("USA", "Belgium", "Germany")]
[string]$country
```

Let's look at this in a fun command
function Compare-CountryCulture {
<#
    .SYNOPSIS
    Determines if a topic is more American, Belgian or German using AI.

    .DESCRIPTION
    Uses an AI model to determine whether a given topic is more associated with the USA or Belgium and provides the reasoning.

    .PARAMETER Topic
    The topic to be analyzed.

    .PARAMETER Model
    The name of the AI model to use. Default is 'gpt-4o-mini'.

    .EXAMPLE
    PS C:\> Compare-CountryCulture -Topic "beer"
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromRemainingArguments, Position = 0)]
        [string]$Topic,
        [string]$Model = 'gpt-4o-mini'
    )
    begin {
        # Define the JSON schema as a PowerShell object
        $schema = @{
            name   = "cultural_comparison_schema"
            strict = $true
            schema = @{
                type       = "object"
                properties = @{
                    country = @{
                        type = "string"
                        enum = @("USA", "Belgium", "Germany")
                        description = "Is the topic more American, Belgian or German?"
                    }
                    reasoning = @{
                        type        = "string"
                        description = "What is the reasoning behind this conclusion?"
                    }
                }
                required            = @("country", "reasoning")
                additionalProperties = $false
            }
        }

        # Convert the PowerShell object to JSON
        $json = $schema | ConvertTo-Json -Depth 5
    }

    process {
        # Splat parameters for Request-ChatCompletion
        $splat = @{
            Model      = $Model
            Message    = $Topic
            Format     = "json_schema"
            JsonSchema = $json
        }

        # Make the request and output to console
        $result = Request-ChatCompletion @splat
        $parsedResult = $result.Answer | ConvertFrom-Json

        [PSCustomObject]@{
            Topic     = $Topic
            Country   = $parsedResult.country
            Reasoning = $parsedResult.reasoning
        } | Format-List *
    }
}

Compare-CountryCulture beer
Compare-CountryCulture food
Compare-CountryCulture healthcare
Compare-CountryCulture olympics
Compare-CountryCulture artificial intelligence