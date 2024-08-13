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
    PS C:\> ConvertTo-DbaiMarkdown -Path C:\Documents\file.pdf -Raw

    Converts the specified PDF file to Markdown format and outputs only the content.

    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("FullName")]
        [string[]]$Path = (Join-Path $script:ModuleRootLib -ChildPath immunization.pdf),
        [switch]$Raw
    )
    begin {
        $PSDefaultParameterValues['Write-Progress:Activity'] = "Converting PDFs to Markdown"

        # Create the AI Assistant
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
        }
        catch {
            throw "Failed to create AI Assistant: $PSItem"
        }

        # Create a Thread
        try {
            $thread = New-Thread
        }
        catch {
            throw "Failed to create Thread: $PSItem"
        }

        $totalFiles = 0
        $processedFiles = 0
    }

    process {
        $totalFiles += $Path.Count

        foreach ($filePath in $Path) {
            $processedFiles++
            Write-Progress -Status "Processing file $processedFiles of $totalFiles" -PercentComplete (($processedFiles / $totalFiles) * 100)

            try {
                # Upload the PDF
                $file = Add-OpenAIFile -File $filePath -Purpose assistants

                # Wait for file processing to complete
                do {
                    $fileStatus = Get-OpenAIFile -FileId $file.id
                    if ($fileStatus.status -eq 'processed') {
                        break
                    }
                    elseif ($fileStatus.status -in 'failed', 'cancelled') {
                        throw "File processing $($fileStatus.status)"
                    }
                    Start-Sleep -Seconds 3
                } while ($true)

                # Add a Message to the Thread and Reference the Uploaded File
                $splat = @{
                    ThreadId                  = $thread.id
                    Message                   = "Please extract the text from the uploaded file."
                    FileIdsForCodeInterpreter = $file.id
                }
                $null = Add-ThreadMessage @splat

                # Start a Run to Invoke the Assistant
                $run = Start-ThreadRun -ThreadId $thread.id -Assistant $assistant.id | Wait-ThreadRun

                # Process the Run Response
                $response = Get-ThreadMessage -ThreadId $thread.id -RunId $run.id | Select-Object -Last 1

                $result = [PSCustomObject]@{
                    FileName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
                    Content  = $response.SimpleContent.Content
                }

                if ($Raw) {
                    $result.Content
                }
                else {
                    $result
                }
            }
            catch {
                Write-Error "Failed to process file $filePath : $PSItem"
            }
            finally {
                # Delete the uploaded file
                if ($file) {
                    try {
                        $null = Remove-OpenAIFile -FileId $file.id
                    }
                    catch {
                        Write-Warning "Failed to delete uploaded file: $PSItem"
                    }
                }
            }
        }
    }
    end {
        # Clean up
        try {
            $null = Remove-Thread -ThreadId $thread.id
            $null = Remove-Assistant -AssistantId $assistant.id
        }
        catch {
            Write-Warning "Failed to clean up resources: $PSItem"
        }
    }
}