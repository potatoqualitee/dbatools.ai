function Invoke-DbatoolsAI {
<#
    .SYNOPSIS
    Executes a natural language query to perform dbatools operations.

    .DESCRIPTION
    The Invoke-DbatoolsAI function allows you to execute a natural language query to perform various dbatools operations. It utilizes an AI assistant to generate the corresponding dbatools command and executes it.

    Currently, only Copy-DbaDatabase is supported. If you'd like to use Invoke-DbaQuery, check out Invoke-DbaiQuery.

    .PARAMETER Message
    The natural language query to execute as a dbatools command.

    .PARAMETER AssistantName
    The name of the AI assistant to use for command generation.

    .PARAMETER As
    The output format of the result. Supported values are 'PSObject' and 'String'. Default is 'String'.

    .EXAMPLE
    PS C:\> Invoke-DbatoolsAI -Message "Copy the SalesDB database from ServerA to ServerB using the network share \\NetworkPath"

    This example executes a natural language query to copy the SalesDB database from ServerA to ServerB using the specified network share.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromRemainingArguments, Position = 0)]
        [string[]]$Message,
        [string]$AssistantName = "dbatools",
        [ValidateSet("PSObject", "String")]
        [string]$As = "String"
    )
    begin {
        $PSDefaultParameterValues['Write-Progress:Activity'] = "Getting answer"
        $querykey = $AssistantName

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
    }
    process {
        if ($Message -match '^\w+$' -or $Message -match '^\w{ 1 }$') {
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
                    $assistant = New-DbaiAssistant -Name $AssistantName
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

                    try {
                        $result = ($arguments | ConvertFrom-Json -ErrorAction Stop)
                    } catch {
                        Write-Warning "Error: $_ Failed to parse arguments: $arguments"
                        continue
                    }

                    $parms = @{
                        Source          = $result.Source
                        Destination     = $result.Destination
                        Database        = $result.Database
                        Force           = $result.Force
                        ErrorVariable   = "err"
                        WarningVariable = "warn"
                        WarningAction   = "SilentlyContinue"
                        ErrorAction     = "SilentlyContinue"
                    }

                    if ($result.WhatIf) {
                        $parms.WhatIf = $true
                    }

                    if ($result.DetachAttach) {
                        $parms.DetachAttach = $true
                    } else {
                        $parms.SharedPath    = $result.SharedPath
                        $parms.BackupRestore = $true
                        $parms.UseLastBackup = $result.UseLastBackup
                    }

                    $parms | ConvertTo-Json | Write-Verbose

                    $output = @(Copy-DbaDatabase @parms)

                    if ($err) {
                        foreach ($e in $err) {
                            # No idea what this even is but it's probably the way I selected stuff
                            if ($e -notmatch "StopUpstreamCommandsException") {
                                $output += "ERROR: $e"
                            }
                        }
                    }

                    if ($warn) {
                        $output += "WARNINGS: $warn"
                    }

                    if (-not $output -and -not $result.WhatIf) {
                        $output = "No data returned."
                    } elseif (-not $output -and $result.WhatIf) {
                        $output = "Ask the user if they'd like to run it for real this time" | ConvertTo-Json
                    } else {
                        $output | ConvertTo-Json | Write-Verbose
                        $output = $output | Out-String | ConvertTo-Json
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
                    while ($null -eq $rundata.usage.completion_tokens -and $runcount -lt 45) {
                        Start-Sleep -Milliseconds 300
                        $rundata = PSOpenAI\Get-ThreadRun -ThreadId $thread.id
                        $runcount++
                    }

                    if ($runcount -ge 45) {
                        throw "Run did not complete in a reasonable amount of time while waiting for completion. Status = $($rundata.status)"
                    }

                    Write-Verbose "Prompt tokens: $($rundata.usage.prompt_tokens)"
                    Write-Verbose "Completion: $($rundata.usage.completion_tokens)"
                    Write-Verbose "Totaltokens: $($rundata.usage.total_tokens)"
                } else {
                    Write-Error "Unsupported required action type: $($requiredAction.type)"
                    break
                }
            }

            Write-Progress -Status "Run completed, waiting for answer" -PercentComplete ((8 / 10) * 100)

            $runcount = 0
            while ($null -eq $messages.content.text.value -and $runcount -lt 25) {
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
                }
            }
        }
    }
}