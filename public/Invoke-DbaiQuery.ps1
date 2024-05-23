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
        [string]$SqlInstance = "localhost",
        [pscredential]$SqlCredential,
        [string]$Database = "Northwind",
        [string]$AssistantName,
        [ValidateSet("PSObject", "String")]
        [string]$As = "String",
        [switch]$SkipSafetyCheck
    )
    begin {
        $PSDefaultParameterValues['Write-Progress:Activity'] = "Getting answer"
        $servername = $SqlInstance
        if (-not $SqlCredential) {
            $username = $env:USERNAME
        } else {
            $username = $SqlCredential.UserName
        }
        if ($SqlInstance -match '\\') {
            $servername = $servername -replace '\\', '-'
        }

        $querykey = "$servername-$username-$Database"

        if (-not $AssistantName) {
            $AssistantName = "query-$Database"
        }

        if (-not $script:threadcache[$querykey]) {
            $cacheobject = [PSCustomObject]@{
                thread    =  PSOpenAI\New-Thread
                assistant = $null
            }
            $script:threadcache[$querykey] = $cacheobject
        } else {
            $thread = $script:threadcache[$querykey].thread
            $assistant = $script:threadcache[$querykey].assistant
        }

        $thread = $script:threadcache[$querykey].thread
        $totalMessages = $Message.Count
        $processedMessages = 0
        $sentence = @()
        $msgs = @()

        $PSDefaultParameterValues["*:Sqlinstance"] = $SqlInstance
        $PSDefaultParameterValues["*:SqlCredential"] = $SqlCredential
        $PSDefaultParameterValues["Get-DbaDatabase:Database"] = $Database
        $PSDefaultParameterValues["Invoke-DbaQuery:Database"] = $Database

    }
    process {
        # test for single word or single character messages
        if ($Message -match '^\w+$' -or $Message -match '^\w{1}$') {
            $sentence += "$Message"
        } else {
            $msgs += $Message
        }
    }
    end {
        if ($sentence.Length -gt 0) {
            $msgs += "$sentence"
        }

        foreach ($msg in $msgs) {
            $messages = $rundata = $null
            Write-Progress -Status "Processing message $($processedMessages + 1) of $totalMessages" -PercentComplete ((1 / 10) * 100)

            if (-not $assistant) {
                Write-Progress -Status "Retrieving or creating assistant" -PercentComplete ((2 / 10) * 100)
                $assistant = PSOpenAI\Get-Assistant -All | Where-Object Name -eq $AssistantName | Select-Object -First 1

                if (-not $assistant) {
                    $assistant = Get-DbaDatabase | New-DbaiAssistant
                }
                $script:threadcache[$querykey].assistant = $assistant
            }

            $null = PSOpenAI\Add-ThreadMessage -ThreadId $thread.id -Role user -Message $msg
            $run = PSOpenAI\Start-ThreadRun -ThreadId $thread.id -Assistant $assistant.Id
            $PSDefaultParameterValues["*:RunId"] = $run.id

            Write-Progress -Status "Waiting for run to complete" -PercentComplete ((3 / 10) * 100)
            $runcount = 0
            while ($null -eq $rundata -and $runcount -lt 25) {
                $rundata = PSOpenAI\Get-ThreadRun -ThreadId $thread.id
                Start-Sleep -Milliseconds 300
                $runcount++
            }

            if ($runcount -ge 25) {
                if ($rundata.status) {
                    throw "Run did not complete in a reasonable amount of time. Failed with status $($rundata.status)"
                } else {
                    throw "Run did not complete in a reasonable amount of time."
                }
            }

            Write-Progress -Status "Current status: $($rundata.status)" -PercentComplete ((4 / 10) * 100)
            $runcount = 0
            while ($rundata.status -notin "requires_action", "completed" -and $runcount -lt 25) {
                Start-Sleep -Milliseconds 300
                $rundata = PSOpenAI\Get-ThreadRun -ThreadId $thread.id
                $runcount++
            }

            if ($runcount -ge 25) {
                if ($rundata.status) {
                    throw "Run did not require action in a reasonable amount of time. Failed with status $($rundata.status)"
                } else {
                    throw "Run did not require action in a reasonable amount of time."
                }
            }

            if ($rundata.status -eq "requires_action") {
                $requiredAction = $rundata.required_action

                if ($requiredAction.type -eq "submit_tool_outputs") {
                    $toolOutputs = $rundata.required_action.submit_tool_outputs.tool_calls
                    $arguments = "$($toolOutputs.function.arguments)".Replace('""', '"_empty"')
                    $arguments = $arguments | Select-Object -First 1

                    try {
                        if ($arguments -match '"query"') {
                            Write-Verbose "It's a sql query"
                            $arguments = $arguments.replace('query:', '').Trim()
                            $sql = ($arguments | ConvertFrom-Json -ErrorAction Stop).query
                            $result = $null
                        } else {
                            Write-Verbose "It's an answer from Assistant context"
                            $result = ($arguments | ConvertFrom-Json -ErrorAction Stop).answer
                            $sql = $null
                        }
                    } catch {
                        Write-Warning "Error: $_ Failed to parse arguments: $arguments"
                        continue
                    }

                    if ($sql) {
                        Write-Verbose "SQL query: $sql"

                        if (-not $SkipSafetyCheck) {
                            Write-Progress -Status "Checking SQL query validity" -PercentComplete ((5 / 10) * 100)
                            $output = Test-SqlQuery -SqlStatement $sql -Tools $assistant.tools

                            if ($output.valid_sql) {
                                Write-Verbose "$sql is a valid SQL statement."

                                if (-not $output.dangerous) {
                                    Write-Verbose "The SQL query is safe."
                                } else {
                                    Write-Warning "The resulting SQL query ($sql) is dangerous because: $($output.danger_reason)"
                                    continue
                                }
                            }
                        }

                        Write-Progress -Status "Executing SQL query" -PercentComplete ((6 / 10) * 100)
                        $params = @{
                            "Query"           = $sql
                            "As"              = "PSObject"
                            "EnableException" = $true
                        }
                        try {
                            $result = Invoke-DbaQuery @params
                        } catch {
                            Write-Warning $_.Exception.Message
                            continue
                        }
                    } else {
                        $result = $sql
                    }

                    if ($null -eq $result) {
                        $output = "No data returned."
                    } else {
                        $output = $result | Out-String | ConvertTo-Json -Depth 10
                    }

                    $innerToolOutputs = @()
                    foreach ($to in $toolOutputs) {
                        if ($to.id -as [string]) {
                            $innerToolOutputs += @{
                                tool_call_id = [string]$to.id
                                output       = $output
                            }
                        }
                    }
                    $innerToolOutputs | ConvertTo-Json -Depth 10 | Write-Verbose
                    try {
                        $null = PSOpenAI\Submit-ToolOutput -Run $rundata -ToolOutput $innerToolOutputs -ErrorAction Stop
                    } catch {
                        Write-Warning $_.Exception.Message
                        return
                    }

                    Write-Progress -Status "Waiting for run to complete" -PercentComplete ((7 / 10) * 100)
                    $runcount = 0
                    while (($null -eq $rundata.usage.completion_tokens -and $runcount -lt 45) -or $rundata.status -eq "in_progress") {
                        Start-Sleep -Milliseconds 300
                        $rundata = PSOpenAI\Get-ThreadRun -ThreadId $thread.id
                        $runcount++
                    }

                    if ($runcount -ge 45) {
                        throw "Run did not complete in a reasonable amount of time while waiting for completion. Status = $($rundata.status)"
                    }

                    Write-Verbose "Prompt tokens: $($rundata.usage.prompt_tokens)"
                    Write-Verbose "Completion: $($rundata.usage.completion_tokens)"
                    Write-Verbose "Total tokens: $($rundata.usage.total_tokens)"
                } else {
                    Write-Error "Unsupported required action type: $($requiredAction.type)"
                    break
                }
            }

            Write-Progress -Status "Run completed, waiting for answer" -PercentComplete ((8 / 10) * 100)

            $runcount = 0
            while (($null -eq $messages.content.text.value -and $runcount -lt 25) -or $rundata.status -eq "in_progress") {
                Start-Sleep -Milliseconds 300
                $messages = PSOpenAI\Get-ThreadMessage -ThreadId $thread.id |
                    Where-Object role -eq assistant |
                    Select-Object -First 1
                $runcount++
            }

            if ($runcount -ge 25) {
                if ($rundata.status) {
                    throw "Run completed, but answer was not received in a reasonable amount of time. Failed with status $($rundata.status)"
                } else {
                    throw "Run completed, but answer was not received in a reasonable amount of time."
                }
            }

            if ($As -eq "String") {
                $messages.content.text.value
            } elseif ($As -eq "PSObject") {
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