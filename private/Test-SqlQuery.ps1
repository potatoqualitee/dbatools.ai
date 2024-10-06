function Test-SqlQuery {
    param (
        [string]$SqlStatement
    )
    # Define JSON schema for validation
    $json = @{
        name   = "examine_sql"
        strict = $true
        schema = @{
            type                 = "object"
            properties           = @{
                dangerous     = @{
                    type        = "boolean"
                    description = "Does this SQL query modify data or is it potentially dangerous?"
                }
                danger_reason = @{
                    type        = "string"
                    description = "If the query is dangerous, why?"
                }
                valid_sql     = @{
                    type        = "boolean"
                    description = "Is this a valid SQL statement?"
                }
            }
            required             = @("dangerous", "valid_sql", "danger_reason")
            additionalProperties = $false
        }
    } | ConvertTo-Json -Depth 5

    # Request parameters for chat completion
    $splat = @{
        Model      = "gpt-4o-mini"
        Message    = "Is this a valid SQL query: $SqlStatement. Also, please determine if it is potentially dangerous and explain why if it is."
        Format     = "json_schema"
        JsonSchema = $json
    }

    # Request to chat completion
    $validationResult = (Request-ChatCompletion @splat).Answer | ConvertFrom-Json

    # Output validation results
    [PSCustomObject]@{
        Valid        = $validationResult.valid_sql
        Dangerous    = $validationResult.dangerous
        DangerReason = $validationResult.danger_reason
    }
}