function Invoke-DbaiQuery {
    <#
    .SYNOPSIS
    Executes a natural language query on a SQL Server database.

    .DESCRIPTION
    The Invoke-DbaiQuery function allows you to execute a natural language query on a specified SQL Server database. It utilizes an AI assistant to generate the corresponding SQL query and returns the result.

    .PARAMETER Message
    The natural language query to execute on the database.

    .PARAMETER SqlInstance
    The SQL Server instance hosting the database. Default is "localhost".

    .PARAMETER SqlCredential
    The SQL Server credential to use for authentication.

    .PARAMETER Database
    The name of the database to query. Default is "Northwind".

    .PARAMETER AssistantName
    The name of the AI assistant to use for query generation.

    .PARAMETER As
    The output format of the result. Supported values are 'PSObject' and 'String'. Default is 'String'.

    .PARAMETER SkipSafetyCheck
    Allows execution of potentially SkipSafetyCheck SQL queries.

    .EXAMPLE
    PS C:\> Invoke-DbaiQuery -Message "Get the top 10 customers by total sales amount" -Database AdventureWorks2019

    This example executes a natural language query on the AdventureWorks2019 database to retrieve the top 10 customers by total sales amount.

#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromRemainingArguments, Position = 0)]
        [string[]]$Message,
        [string]$SqlInstance,
        [pscredential]$SqlCredential,
        [string]$Database,
        [string]$AssistantName,
        [ValidateSet("PSObject", "String")]
        [string]$As = "String",
        [switch]$SkipSafetyCheck
    )
    begin {
        Write-Verbose "Starting Invoke-DbaiQuery function"
        $PSDefaultParameterValues['Write-Progress:Activity'] = "Getting answer"

        Write-Verbose "Initializing SQL Server instance and credentials"
        $servername = $SqlInstance
        if (-not $SqlCredential) {
            Write-Verbose "No SQL credential provided, using current environment username"
            $username = $env:USERNAME
        } else {
            $username = $SqlCredential.UserName
        }
        if ($SqlInstance -match '\\') {
            Write-Verbose "Replacing backslashes in SQL instance name"
            $servername = $servername -replace '\\', '-'
        }

        if (-not $SqlInstance) {
            Write-Verbose "No SQL instance specified, defaulting to localhost"
            $SqlInstance = "localhost"
        }
        if (-not $Database) {
            Write-Verbose "No database specified, defaulting to Northwind"
            $Database = "Northwind"
        }

        Write-Verbose "Setting default parameter values for SQL instance and credentials"
        if (-not $PSDefaultParameterValues["*:Sqlinstance"]) {
            $PSDefaultParameterValues["*:Sqlinstance"] = $SqlInstance
        }
        if (-not $PSDefaultParameterValues["*:SqlCredential"]) {
            $PSDefaultParameterValues["*:SqlCredential"] = $SqlCredential
        }
        if (-not $PSDefaultParameterValues["*DbaDatabase:Database"]) {
            $PSDefaultParameterValues["*DbaDatabase:Database"] = $Database
        }
        if (-not $PSDefaultParameterValues["*DbaQuery:Database"]) {
            $PSDefaultParameterValues["*DbaQuery:Database"] = $Database
        }

        $querykey = "$servername-$username-$Database"

        if (-not $AssistantName) {
            Write-Verbose "No assistant name provided, generating default assistant name"
            $AssistantName = "query-$Database"
        }
        Write-Verbose "Using Assistant Name: $AssistantName"

        if (-not $script:threadcache[$querykey]) {
            Write-Verbose "Creating new thread cache object for key $querykey"
            $assistant = Get-Assistant -All | Where-Object Name -eq $AssistantName | Select-Object -First 1
            $cacheobject = [PSCustomObject]@{
                thread    = PSOpenAI\New-Thread
                assistant = $assistant
            }
            $script:threadcache[$querykey] = $cacheobject
        } else {
            Write-Verbose "Retrieving existing thread and assistant from cache"
            $thread = $script:threadcache[$querykey].thread
            $assistant = $script:threadcache[$querykey].assistant
        }

        $thread = $script:threadcache[$querykey].thread

        if (-not $assistant) {
            Write-Progress -Status "Retrieving or creating assistant" -PercentComplete ((2 / 10) * 100)
            Write-Verbose "Attempting to retrieve existing assistant named $AssistantName"
            $assistant = PSOpenAI\Get-Assistant -All | Where-Object Name -eq $AssistantName | Select-Object -First 1

            if (-not $assistant) {
                Write-Verbose "Assistant not found, creating a new assistant"
                try {
                    $assistant = Get-DbaDatabase -EnableException | New-DbaiAssistant -ErrorAction Stop
                } catch {
                    Write-Verbose "Error creating assistant: $_"
                    throw $PSItem
                }
            }

            $script:threadcache[$querykey].assistant = $assistant
        }

        $totalMessages = $Message.Count
        $processedMessages = 0
        $sentence = @()
        $msgs = @()
    }
    process {
        Write-Verbose "Processing input message"
        if ($Message -match '^\w+$' -or $Message -match '^\w{1}$') {
            Write-Verbose "Message is a single word or character, adding to sentence array"
            $sentence += "$Message"
        } else {
            Write-Verbose "Message is a full sentence, adding to message array"
            $msgs += $Message
        }
    }
    end {
        Write-Verbose "Finalizing message processing"
        if ($sentence.Length -gt 0) {
            Write-Verbose "Combining sentence array into a single message"
            $msgs += "$sentence"
        }

        foreach ($msg in $msgs) {
            Write-Verbose "Processing message: $msg"
            $messages = $rundata = $null
            Write-Progress -Status "Processing message $($processedMessages + 1) of $totalMessages" -PercentComplete ((1 / 10) * 100)

            Write-Verbose "Stopping any existing thread runs"
            $null = PSOpenAI\Get-ThreadRun -ThreadId $thread.id -ErrorAction SilentlyContinue | Where-Object status -in "queued", "in_progress",  "requires_action" | Stop-ThreadRun -ErrorAction SilentlyContinue
            Write-Verbose "Adding user message to thread"
            $null = PSOpenAI\Add-ThreadMessage -ThreadId $thread.id -Role user -Message $msg
            Write-Verbose "Starting new thread run with assistant $($assistant.Id)"
            $run = PSOpenAI\Start-ThreadRun -ThreadId $thread.id -Assistant $assistant.Id
            $PSDefaultParameterValues["*:RunId"] = $run.id

            Write-Progress -Status "Waiting for run to complete" -PercentComplete ((3 / 10) * 100)
            $rundata = PSOpenAI\Wait-ThreadRun -Run $run

            Write-Progress -Status "Current status: $($rundata.status)" -PercentComplete ((4 / 10) * 100)
            $rundata = PSOpenAI\Wait-ThreadRun -Run $rundata -StatusForWait @('queued', 'in_progress') -StatusForExit @('requires_action', 'completed')

            if ($rundata.status -eq "requires_action") {
                Write-Verbose "Run requires action: $($rundata.required_action.type)"
                $requiredAction = $rundata.required_action

                if ($requiredAction.type -eq "submit_tool_outputs") {
                    Write-Verbose "Submitting tool outputs"
                    $toolOutputs = $rundata.required_action.submit_tool_outputs.tool_calls
                    $arguments = "$($toolOutputs.function.arguments)".Replace('""', '"_empty"')
                    $arguments = $arguments | Select-Object -First 1

                    try {
                        if ($arguments -match '"query"') {
                            Write-Verbose "Parsed output is a SQL query"
                            $arguments = $arguments.replace('query:', '').Trim()
                            $sql = ($arguments | ConvertFrom-Json -ErrorAction Stop).query
                            $result = $null
                        } else {
                            Write-Verbose "Parsed output is an assistant answer"
                            $result = ($arguments | ConvertFrom-Json -ErrorAction Stop).answer
                            $sql = $null
                        }
                    } catch {
                        Write-Warning "Error parsing arguments: $_ Failed to parse arguments: $arguments"
                        continue
                    }

                    if ($sql) {
                        Write-Verbose "Executing SQL query: $sql"

                        if (-not $SkipSafetyCheck) {
                            Write-Progress -Status "Checking SQL query validity" -PercentComplete ((5 / 10) * 100)
                            $output = Test-SqlQuery -SqlStatement $sql

                            if (-not $output.Valid) {
                                Write-Warning "The SQL query ($sql) is not valid."
                                continue
                            }

                            if ($output.Dangerous) {
                                Write-Warning "The resulting SQL query ($sql) is dangerous because: $($output.DangerReason)"
                                continue
                            }

                            Write-Verbose "SQL query is valid and safe to execute"
                        }

                        Write-Progress -Status "Executing SQL query" -PercentComplete ((6 / 10) * 100)
                        $params = @{
                            "Query"           = $sql
                            "As"              = "PSObject"
                            "EnableException" = $true
                            "Database"        = $Database
                        }
                        try {
                            $result = Invoke-DbaQuery @params
                        } catch {
                            Write-Warning $_.Exception.Message
                            continue
                        }
                    } else {
                        Write-Verbose "No SQL query to execute, returning assistant's answer"
                        $result = $sql
                    }

                    if ($null -eq $result) {
                        Write-Verbose "No data returned from SQL query"
                        $output = "No data returned."
                    } else {
                        Write-Verbose "Converting result to JSON format"
                        $output = $result | Out-String | ConvertTo-Json -Depth 10
                    }

                    $innerToolOutputs = @()
                    foreach ($to in $toolOutputs) {
                        if ($to.id -as [string]) {
                            Write-Verbose "Adding tool output with ID $($to.id)"
                            $innerToolOutputs += @{
                                tool_call_id = [string]$to.id
                                output       = $output
                            }
                        }
                    }
                    $innerToolOutputs | ConvertTo-Json -Depth 10 | Write-Verbose
                    try {
                        Write-Verbose "Submitting tool outputs to assistant"
                        $null = PSOpenAI\Submit-ToolOutput -Run $rundata -ToolOutput $innerToolOutputs -ErrorAction Stop
                    } catch {
                        Write-Warning $_.Exception.Message
                        return
                    }

                    Write-Progress -Status "Waiting for run to complete" -PercentComplete ((7 / 10) * 100)
                    $rundata = PSOpenAI\Wait-ThreadRun -Run $rundata
                } else {
                    Write-Verbose "Unsupported required action type: $($requiredAction.type)"
                    throw "Unsupported required action type: $($requiredAction.type)"
                    break
                }
            }

            Write-Progress -Status "Run completed, waiting for answer" -PercentComplete ((8 / 10) * 100)
            $rundata = PSOpenAI\Wait-ThreadRun -Run $rundata
            Write-Verbose "Fetching assistant response message"
            $messages = PSOpenAI\Get-ThreadMessage -ThreadId $thread.id | Where-Object role -eq assistant | Select-Object -First 1

            if ($As -eq "String") {
                Write-Verbose "Returning result as string"
                $messages.content.text.value
            } elseif ($As -eq "PSObject") {
                Write-Verbose "Returning result as PSObject"
                [PSCustomObject]@{
                    Question     = $msg
                    Answer       = $messages.content.text.value
                    PromptTokens = $rundata.usage.prompt_tokens
                    Completion   = $rundata.usage.completion_tokens
                    TotalTokens  = $rundata.usage.total_tokens
                    SqlQuery     = $sql
                }
            }
        }
    }
}