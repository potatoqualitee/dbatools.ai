function Test-ValidSqlQuery {
    param (
        [string]$SqlStatement,
        [PSCustomObject[]]$Tools
    )

    $body = @{
        model       = "gpt-3.5-turbo"
        messages    = @(
            @{
                "role"    = "system"
                "content" = "You are a helpful assistant and SQL expert that checks if the given text is a valid SQL statement."
            },
            @{
                "role"    = "user"
                "content" = "Is the following a valid SQL statement: $SqlStatement"
            }
        )
        tools       = $Tools
        tool_choice = @{
            type     = "function"
            function = @{
                name = "examine_sql"
            }
        }
    } | ConvertTo-Json -Compress -Depth 10

    $splat = @{
        Uri     = "https://api.openai.com/v1/chat/completions"
        Method  = "POST"
        Body    = $body
        Headers = @{
            "Content-Type"  = "application/json"
            "Authorization" = "Bearer $env:OpenAIKey"
            "OpenAI-Beta"   = "assistants=v2"
        }
    }
    $results = Invoke-RestMethod @splat

    $results.choices.message.tool_calls.function.arguments | ConvertFrom-Json
}