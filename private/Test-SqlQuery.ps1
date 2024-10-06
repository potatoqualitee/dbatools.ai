function Test-SqlQuery {
    param (
        [string]$SqlStatement
    )

    # Define JSON schema
    $json = @{
        name   = "sql_query_validation"
        strict = $true
        schema = @{
            type                 = "object"
            properties           = @{
                valid  = @{
                    type = "boolean"
                }
                issues = @{
                    type  = "array"
                    items = @{
                        type = "string"
                    }
                }
            }
            required             = @("valid", "issues")
            additionalProperties = $false
        }
    } | ConvertTo-Json -Depth 5

    # Request parameters for chat completion
    $splat = @{
        Model      = "gpt-4o-mini"
        Message    = "Is this a valid SQL query: $SqlStatement"
        Format     = "json_schema"
        JsonSchema = $json
    }

    # Request to chat completion
    (Request-ChatCompletion @splat).Answer | ConvertFrom-Json
}
