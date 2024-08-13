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
        [string]$JsonSchemaPath,
        [Parameter()]
        [string]$JsonSchema,
        [Parameter(Mandatory)]
        [string]$SystemMessage
    )
    begin {
        $PSDefaultParameterValues['Write-Progress:Activity'] = "Converting to Structured Object"

        if (-not $JsonSchemaPath -and -not $JsonSchema) {
            throw "Either JsonSchemaPath or JsonSchema must be provided."
        }

        if ($JsonSchemaPath) {
            if (-not (Test-Path -Path $JsonSchemaPath)) {
                throw "JSON schema file not found at path: $JsonSchemaPath"
            }
            try {
                $JsonSchema = Get-Content -Path $JsonSchemaPath -Raw
            } catch {
                throw "Failed to read JSON schema file: $PSItem"
            }
        }

        try {
            $null = $JsonSchema | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "Invalid JSON schema: $PSItem"
        }
    }
    process {
        foreach ($item in $Content) {
            Write-Progress -Status "Processing content"

            try {
                $params = @{
                    Model         = "gpt-4o-2024-08-06"
                    SystemMessage = $SystemMessage
                    Message       = $item
                    Format        = "json_schema"
                    JsonSchema    = $JsonSchema
                }

                $result = Request-ChatCompletion @params

                if (-not $result -or -not $result.Answer) {
                    throw "No valid response received from AI"
                }
                $PSDefaultParameterValues['ConvertFrom-Json:Depth'] = 10
                $result.Answer[0] | ConvertFrom-Json
            } catch {
                Write-Error "Failed to process content: $PSItem"
            }
        }
    }
    end {
        Write-Progress -Completed
    }
}