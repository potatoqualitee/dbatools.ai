function ConvertTo-DbaiStructuredObject {
    <#
.SYNOPSIS
Converts Markdown content to structured objects based on a JSON schema.

.DESCRIPTION
This command takes Markdown content and a JSON schema, and uses AI to extract structured information based on the schema.

.PARAMETER Content
Specifies the Markdown content to be processed. This can be an array of strings piped in from ConvertTo-DbaiMarkdown.

.PARAMETER JsonSchemaPath
Specifies the path to the JSON schema file that defines the structure for the output.

.PARAMETER JsonSchema
Specifies the JSON schema directly as a string.

.PARAMETER SystemMessage
Specifies the system message to guide the AI in processing the content.

.EXAMPLE
PS C:\> $content = ConvertTo-DbaiMarkdown -Path C:\Documents\vaccine_record.pdf -Raw
PS C:\> $splat = @{
    Content         = $content
    JsonSchemaPath  = "C:\Schemas\immunization.json"
    SystemMessage   = "You are an assistant that extracts information from pet vaccination records."
}
PS C:\> ConvertTo-DbaiStructuredObject @splat

Converts a PDF to Markdown, then extracts structured information based on the specified JSON schema.

.EXAMPLE
PS C:\> Get-ChildItem -Path "C:\Documents" -Filter *.pdf | ConvertTo-DbaiMarkdown | ConvertTo-DbaiStructuredObject -JsonSchemaPath "C:\Schemas\immunization.json" -SystemMessage "Extract pet vaccination information."

Processes multiple PDF files, converting them to Markdown and then to structured objects.

#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias("Markdown")]
        [string[]]$Content,
        [Parameter()]
        [string]$JsonSchemaPath = (Join-Path $script:ModuleRootLib -ChildPath immunization.json),
        [Parameter()]
        [string]$JsonSchema,
        [Parameter()]
        [string]$SystemMessage = "You are an assistant that extracts structured information from the content."
    )
    begin {
        Write-Verbose "Starting ConvertTo-StructuredObject function"
        $PSDefaultParameterValues['Write-Progress:Activity'] = "Converting to Structured Object"

        Write-Verbose "Checking for JSON schema"
        if ($JsonSchemaPath -and -not $JsonSchema) {
            Write-Verbose "JsonSchemaPath provided: $JsonSchemaPath"
            if (-not (Test-Path -Path $JsonSchemaPath)) {
                Write-Verbose "JSON schema file not found at path: $JsonSchemaPath"
                throw "JSON schema file not found at path: $JsonSchemaPath"
            }
            try {
                Write-Verbose "Reading JSON schema from file"
                $JsonSchema = Get-Content -Path $JsonSchemaPath -Raw
                Write-Verbose "JSON schema successfully read from file"
            } catch {
                Write-Verbose "Failed to read JSON schema file: $PSItem"
                throw "Failed to read JSON schema file: $PSItem"
            }
        }

        try {
            Write-Verbose "Validating JSON schema"
            $null = $JsonSchema | ConvertFrom-Json -ErrorAction Stop
            Write-Verbose "JSON schema is valid"
        } catch {
            Write-Verbose "Invalid JSON schema: $PSItem"
            throw "Invalid JSON schema: $PSItem"
        }
    }
    process {
        Write-Verbose "Processing $($Content.Count) content items"
        foreach ($item in $Content) {
            Write-Progress -Status "Processing content"
            Write-Verbose "Processing content item"

            try {
                Write-Verbose "Preparing parameters for Request-ChatCompletion"
                $params = @{
                    Model         = "gpt-4o-2024-08-06"
                    SystemMessage = $SystemMessage
                    Message       = $item
                    Format        = "json_schema"
                    JsonSchema    = $JsonSchema
                }

                Write-Verbose "Calling Request-ChatCompletion"
                $result = Request-ChatCompletion @params

                if (-not $result -or -not $result.Answer) {
                    Write-Verbose "No valid response received from AI"
                    throw "No valid response received from AI"
                }
                Write-Verbose "Valid response received from AI"

                Write-Verbose "Setting ConvertFrom-Json depth to 10"
                $PSDefaultParameterValues['ConvertFrom-Json:Depth'] = 10

                Write-Verbose "Converting AI response to JSON"
                $convertedResult = $result.Answer[0] | ConvertFrom-Json
                Write-Verbose "Successfully converted AI response to JSON"

                Write-Verbose "Outputting converted result"
                $convertedResult

            } catch {
                throw "Failed to process content: $PSItem"
            }
        }
    }
    end {
        Write-Verbose "Completing progress bar"
        Write-Progress -Completed
        Write-Verbose "ConvertTo-StructuredObject function completed"
    }
}