function Test-SqlQuery {
    param (
        [string]$SqlStatement,
        [PSCustomObject[]]$Tools
    )

    $body = @{
        model           = "gpt-4o-2024-08-06"
        messages        = @(
            @{
                role    = "system"
                content = "You are a helpful assistant and SQL expert."
            },
            @{
                role    = "user"
                content = "Translate the following natural language query into a SQL query: $query"
            }
        )
        tools           = $Tools
        response_format = @{
            type        = "json_schema"
            json_schema = @{
                type       = "object"
                properties = @{
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
                required   = @("valid", "issues")
            }
            strict      = $true
        }
    } | ConvertTo-Json -Compress -Depth 10

    $splat = @{
        Uri     = "https://api.openai.com/v1/chat/completions"
        Method  = "POST"
        Body    = $body
        Headers = @{
            "Content-Type"  = "application/json"
            "Authorization" = "Bearer $env:OpenAIKey"
        }
    }
    $results = Invoke-RestMethod @splat

    $results.choices[0].message.content | ConvertFrom-Json
}