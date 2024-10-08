function ConvertTo-DbaiMarkdown {
    <#
    .SYNOPSIS
    Converts various files to Markdown format using AI assistance.

    .DESCRIPTION
    This command converts various filetypes (PDF, Word) to Markdown format using an AI assistant. It supports processing multiple files through pipeline input and can check for required content in the output.

    .PARAMETER Path
    Specifies the path to the file(s) to be converted. Accepts pipeline input.

    .PARAMETER RequiredText
    An array of strings that must be present in the output. If any of these strings are missing, the function will request the AI to try again.

    .PARAMETER Raw
    If specified, outputs only the Markdown content without additional metadata.

    .PARAMETER Retry
    Specifies the number of times to retry when a required phrase is not found. Default is 1.

    .EXAMPLE
    PS C:\> ConvertTo-DbaiMarkdown -Path C:\Documents\file.pdf

    Converts the specified PDF file to Markdown format.

    .EXAMPLE
    PS C:\> Get-ChildItem -Path C:\Documents -Filter *.pdf | ConvertTo-DbaiMarkdown

    Converts all PDF files in the specified directory to Markdown format.

    .EXAMPLE
    PS C:\> ConvertTo-DbaiMarkdown -Path C:\Documents\file.jpg -Raw

    Converts text in the specified jpg file to Markdown format and outputs only the content.

    .EXAMPLE
    PS C:\> ConvertTo-DbaiMarkdown -Path C:\Documents\file.pdf -RequiredText "lyme disease", "vaccination" -Retry 3

    Converts the specified PDF file to Markdown format, ensuring that the phrases "lyme disease" and "vaccination" are present in the output. It will retry up to 3 times for each phrase if not found.

    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("FullName")]
        [string[]]$Path = (Join-Path $script:ModuleRootLib -ChildPath immunization.pdf),
        [string]$Model,
        [string[]]$RequiredText,
        [switch]$Raw,
        [int]$Retry = 1
    )
    begin {
        if (-not $Model) {
            if ($PSDefaultParameterValues['*:Deployment']) {
                $Model = $PSDefaultParameterValues['*:Deployment']
            } else {
                $Model = "gpt-4o-mini"
            }
        }
        Write-Verbose "Starting ConvertTo-DbaiMarkdown function"
        $PSDefaultParameterValues['Write-Progress:Activity'] = "Converting file text to markdown"

        Write-Verbose "Creating AI Assistant"
        $assistantName = "TextExtractor"
        $instructionsfile = Join-Path -Path $script:ModuleRootLib -Childpath instruct-markdown.txt
        $assistantInstructions = Get-Content $instructionsfile -Raw

        try {
            $splat = @{
                Name               = $assistantName
                Instructions       = $assistantInstructions
                Model              = $Model
                UseCodeInterpreter = $true
            }
            $assistant = New-Assistant @splat
            Write-Verbose "AI Assistant created successfully with ID: $($assistant.id)"
        } catch {
            Write-Verbose "Failed to create AI Assistant: $PSItem"
            throw "Failed to create AI Assistant: $PSItem"
        }

        Write-Verbose "Creating Thread"
        try {
            $thread = New-Thread
            Write-Verbose "Thread created successfully with ID: $($thread.id)"
        } catch {
            Write-Verbose "Failed to create Thread: $PSItem"
            throw "Failed to create Thread: $PSItem"
        }

        $totalFiles = 0
        $processedFiles = 0
    }
    process {
        $totalFiles += $Path.Count
        Write-Verbose "Total files to process: $totalFiles"

        foreach ($filePath in $Path) {
            $processedFiles++
            try {
                $filename = (Get-ChildItem -Path $filePath -ErrorAction Stop).Name
            } catch {
                throw "File not found: $filePath"
                continue
            }
            Write-Verbose "Processing file $processedFiles of $totalFiles -- $filePath"
            Write-Progress -Status "Processing file $processedFiles of $totalFiles" -PercentComplete (($processedFiles / $totalFiles) * 100)

            try {
                Write-Verbose "Uploading file: $filePath"
                $file = Add-OpenAIFile -File $filePath -Purpose assistants
                Write-Verbose "File uploaded successfully with ID: $($file.id)"

                Write-Verbose "Waiting for file processing to complete"
                do {
                    $fileStatus = Get-OpenAIFile -FileId $file.id
                    Write-Verbose "Current file status: $($fileStatus.status)"
                    if ($fileStatus.status -eq 'processed') {
                        Write-Verbose "File processing completed"
                        break
                    } elseif ($fileStatus.status -in 'failed', 'cancelled') {
                        throw "File processing $($fileStatus.status)"
                    }
                    Start-Sleep -Seconds 3
                } while ($true)

                Write-Verbose "Adding message to thread"
                $splat = @{
                    ThreadId                  = $thread.id
                    Message                   = "Filename: $filename"
                    FileIdsForCodeInterpreter = $file.id
                }
                $null = Add-ThreadMessage @splat

                Write-Verbose "Starting thread run"
                $run = Start-ThreadRun -ThreadId $thread.id -Assistant $assistant.id | Wait-ThreadRun
                Write-Verbose "Thread run completed with status: $($run.status)"

                Write-Verbose "Processing run response"
                $response = Get-ThreadMessage -ThreadId $thread.id -RunId $run.id | Select-Object -Last 1

                $result = [PSCustomObject]@{
                    FileName = $filename
                    Content  = $response.SimpleContent.Content
                }

                if ($result.Content) {
                    if ($result.Content.ToLower().StartsWith("failure")) {
                        Write-Verbose "Failure detected in response. Starting retry run"
                        $run = Start-ThreadRun -ThreadId $thread.id -Assistant $assistant.id | Wait-ThreadRun
                        $response = Get-ThreadMessage -ThreadId $thread.id -RunId $run.id | Select-Object -Last 1
                        $result.Content = $response.SimpleContent.Content
                    }
                }

                if ($RequiredText) {
                    Write-Verbose "Checking for required text phrases"
                    foreach ($phrase in $RequiredText) {
                        Write-Verbose "Checking for phrase: '$phrase'"
                        $retryCount = 0
                        while ($result.Content -notmatch [regex]::Escape($phrase) -and $retryCount -lt $Retry) {
                            $retryCount++
                            Write-Verbose "Required phrase '$phrase' not found in the output. Retry attempt $retryCount of $Retry"
                            Write-Verbose "Output: $($result.Content)"
                            Write-Verbose "Retry attempt $retryCount of $Retry"
                            $message = "The output seems incomplete. Please try again and ensure all relevant information is included."
                            Write-Verbose "Sending message to AI: $message"
                            $null = Add-ThreadMessage -ThreadId $thread.id -Message $message
                            Write-Verbose "Starting retry run"
                            $run = Start-ThreadRun -ThreadId $thread.id -Assistant $assistant.id | Wait-ThreadRun
                            Write-Verbose "Retry run completed with status: $($run.status)"
                            Write-Verbose "Retrieving updated response"
                            $response = Get-ThreadMessage -ThreadId $thread.id -RunId $run.id | Select-Object -Last 1
                            $result.Content = $response.SimpleContent.Content
                            Write-Verbose "Updated content received"
                            $result.Content | ConvertTo-Json -Depth 3 | Write-Verbose
                        }

                        if ($result.Content -notmatch [regex]::Escape($phrase)) {
                            Write-Verbose "Required phrase '$phrase' still missing after $Retry retry attempts"
                            throw "Failed to include required content after $Retry retry attempts: $phrase"
                        } else {
                            Write-Verbose "Required phrase '$phrase' found after $retryCount retry attempts"
                        }
                    }
                    Write-Verbose "All required phrases have been checked"
                }

                Write-Verbose "Checking for failure once more"
                if ($result.Content) {
                    if ($result.Content.ToLower().StartsWith("failure")) {
                        throw $result.Content
                    }
                }

                Write-Verbose "Outputing result"
                if ($Raw) {
                    $result.Content
                } else {
                    $result
                }
            } catch {
                throw "Failed to process file $filePath | $PSItem"
            } finally {
                if ($file) {
                    Write-Verbose "Attempting to delete uploaded file: $($file.id)"
                    try {
                        $null = Remove-OpenAIFile -FileId $file.id
                        Write-Verbose "File deleted successfully"
                    } catch {
                        Write-Warning "Failed to delete uploaded file: $PSItem"
                    }
                }
            }
        }
    }
    end {
        Write-Verbose "Cleaning up resources"
        if ($thread) {
            Write-Verbose "Attempting to delete thread: $($thread.id)"
            try {
                $null = Remove-Thread -ThreadId $thread.id
                Write-Verbose "Thread deleted successfully"
            } catch {
                Write-Verbose "Failed to delete thread: $PSItem"
            }
        }

        if ($assistant) {
            Write-Verbose "Attempting to delete assistant: $($assistant.id)"
            try {
                $null = Remove-Assistant -AssistantId $assistant.id
                Write-Verbose "Assistant deleted successfully"
            } catch {
                Write-Verbose "Failed to delete assistant: $PSItem"
            }
        }

        Write-Verbose "ConvertTo-DbaiMarkdown function completed"
        Write-Progress -Completed
    }
}