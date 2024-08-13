function ConvertTo-DbaiMarkdown {
    <#
    .SYNOPSIS
    Converts various files to Markdown format using AI assistance.

    .DESCRIPTION
    This command converts various filetypes (PDF, Word) to Markdown format using an AI assistant. It supports processing multiple files through pipeline input.

    .PARAMETER Path
    Specifies the path to the file(s) to be converted. Accepts pipeline input.

    .PARAMETER Raw
    If specified, outputs only the Markdown content without additional metadata.

    .EXAMPLE
    PS C:\> ConvertTo-DbaiMarkdown -Path C:\Documents\file.pdf

    Converts the specified PDF file to Markdown format.

    .EXAMPLE
    PS C:\> Get-ChildItem -Path C:\Documents -Filter *.pdf | ConvertTo-DbaiMarkdown

    Converts all PDF files in the specified directory to Markdown format.

    .EXAMPLE
    PS C:\> ConvertTo-DbaiMarkdown -Path C:\Documents\file.jpg -Raw

    Converts text in the specified jpg file to Markdown format and outputs only the content.

    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("FullName")]
        [string[]]$Path = (Join-Path $script:ModuleRootLib -ChildPath immunization.pdf),
        [switch]$Raw
    )
    begin {
        Write-Verbose "Starting ConvertTo-DbaiMarkdown function"
        $PSDefaultParameterValues['Write-Progress:Activity'] = "Converting PDFs to Markdown"

        Write-Verbose "Creating AI Assistant"
        $assistantName = "TextExtractor"
        $instructionsfile = Join-Path -Path $script:ModuleRootLib -Childpath instruct-markdown.txt
        $assistantInstructions = Get-Content $instructionsfile -Raw

        try {
            $splat = @{
                Name               = $assistantName
                Instructions       = $assistantInstructions
                Model              = "gpt-4o-2024-08-06"
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
                Write-Error "File not found: $filePath"
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

                Write-Verbose "Checking for failure"
                if ($result.Content.StartsWith("Failure")) {
                    throw $convertedResult.Content
                }

                Write-Verbose "Outputting result"
                if ($Raw) {
                    $result.Content
                } else {
                    $result
                }
            } catch {
                Write-Error "Failed to process file $filePath | $PSItem"
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
        try {
            $null = Remove-Thread -ThreadId $thread.id
            Write-Verbose "Thread removed successfully"
            $null = Remove-Assistant -AssistantId $assistant.id
            Write-Verbose "Assistant removed successfully"
        } catch {
            Write-Warning "Failed to clean up resources: $PSItem"
        }
        Write-Verbose "ConvertTo-DbaiMarkdown function completed"
    }
}