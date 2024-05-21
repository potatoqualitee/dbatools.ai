function New-DbaiAssistant {
<#
    .SYNOPSIS
    Creates a new AI assistant for a SQL Server database.

    .DESCRIPTION
    The New-DbaiAssistant function generates an AI assistant for a specified SQL Server database. It converts the database schema to a specified format and creates an assistant with the provided name, description, and instructions.

    .PARAMETER Database
    The SQL Server database object(s) for which to create the AI assistant.

    .PARAMETER Name
    The name of the AI assistant.

    .PARAMETER Description
    A description of the AI assistant.

    .PARAMETER Instructions
    Instructions for the AI assistant.

    .PARAMETER FunctionDescription
    Description of the function used to answer user questions about the database.

    .PARAMETER Type
    The format to which the database schema should be converted. Supported values are 'JSON', 'SQL', and 'Text'. Default is 'Text'.

    .PARAMETER Model
    The name of the AI model to use for the assistant. Default is 'gpt-4o'.

    .PARAMETER Force
    Forces the creation of a new assistant, even if one already exists for the specified database.

    .NOTES
    Requires the dbatools and PSOpenAI modules to be installed.

    .EXAMPLE
    Get-DbaDatabase -SqlInstance localhost -Database WideWorldImporters | New-DbaiAssistant

    This example creates a new AI assistant named "WWI-Assistant" for the WideWorldImporters database.

    .EXAMPLE
    $db = Get-DbaDatabase -SqlInstance localhost -Database WideWorldImporters
    $db | New-DbaiAssistant -Name "WW DB Copilot" -Description "AI assistant for the WideWorldImporters database"

    This example creates a new AI assistant named WW DB Copilot for the WideWorldImporters database.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Microsoft.SqlServer.Management.Smo.Database[]]$Database,
        [string]$Name,
        [string]$Description,
        [string]$Instructions,
        [string]$FunctionDescription = "Use this function to answer user questions about the database. Input should be a fully formed SQL query.",
        [ValidateSet('JSON', 'SQL', 'Text')]
        [string]$Type = 'Text',
        [string]$Model = 'gpt-4o',
        [switch]$Force
    )
    begin {
        if (-not $Instructions) {
            $instructionsfile = Join-Path -Path $script:ModuleRoot -Childpath instructions.txt
            $Instructions = Get-Content $instructionsfile -Raw
        }
    }
    process {
        foreach ($db in $Database) {
            Write-Verbose "Processing database: $($db.Name)"
            $schema = ConvertTo-SqlString -Database $db -Force:$Force -Model $Model
            $tokenCount   = (Measure-TuneToken -InputObject $instructions -Model cl100k_base).TokenCount
            Write-Verbose "Token count for instructions: $tokenCount"

            $toolList = @(
                @{
                    "name"        = "ask_database"
                    "description" = $FunctionDescription
                    "parameters"  = @{
                        "properties" = @{
                            "query" = @{
                                "type" = "string"
                                "description" = "SQL query extracting info to answer the user's question. SQL should be written using this database schema:
                                $schema
                                The query should be returned in plain text, not in JSON."
                            }
                        }
                        "type"       = "object"
                        "required"   = @("query")
                    }
                },
                @{
                    "name"        = "examine_sql"
                    "description" = "Check if a SQL query is valid and if potentially dangerous."
                    "parameters"  = @{
                        "type"       = "object"
                        "properties" = @{
                            "dangerous"     = @{
                                "type"        = "boolean"
                                "description" = "Does this sql query modify data or is it potentially dangerous?"
                            }
                            "danger_reason" = @{
                                "type"        = "string"
                                "description" = "If the query is dangerous, why?"
                            }
                            "valid_sql"     = @{
                                "type"        = "boolean"
                                "description" = "Is this a valid SQL statement?"
                            }
                        }
                        "required"   = @("dangerous", "valid_sql")
                    }
                }
            )

            $dbname = $db.Name

            if (-not $PSBoundParameters.Name) {
                $Name = "query-$dbname"
            }

            if (-not $PSBoundParameters.Description) {
                $Description = "Copilot for the $dbname database."
            }

            $params = @{
                Name         = $Name
                Functions    = $toolList
                Model        = $Model
                Description  = $Description
                Instructions = $instructions
            }
            Write-Verbose "Creating AI assistant for database: $($db.Name)"
            PSOpenAI\New-Assistant @params
        }
    }
}