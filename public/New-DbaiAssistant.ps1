function New-DbaiAssistant {
<#
    .SYNOPSIS
    Creates an AI assistant for querying SQL databases or executing dbatools commands.

    .DESCRIPTION
    This function generates an AI assistant that can translate natural language queries into SQL queries or dbatools commands. The assistant can be customized for specific databases or used generally for dbatools.

    .PARAMETER Database
    The SQL Server database object(s) for which to create the AI assistant. If this parameter is not provided, the function creates a general AI assistant for dbatools.

    .PARAMETER Name
    The name of the AI assistant. This parameter is optional. If not provided, the function uses a default name.

    For databases, the default name is "query-<database name>". For dbatools, the default name is "dbatools".

    .PARAMETER Description
    A description of the AI assistant.

    .PARAMETER Instructions
    Instructions for the AI assistant.

    .PARAMETER FunctionDescription
    Description of the function used to answer user questions about the database.

    .PARAMETER Model
    The name of the AI model to use for the assistant. Default is "gpt-4o-mini".

    .PARAMETER Force
    Forces the creation of a new assistant, even if one already exists for the specified database.

    .EXAMPLE
    New-DbaiAssistant

    This example creates a new general AI assistant for executing dbatools commands.

    .EXAMPLE
    New-DbaiAssistant -Name "dbatools" -Description "Copilot for dbatools" -Instructions "Translate natural language queries into dbatools commands" -FunctionDescription "Use this function to execute dbatools commands."

    This example creates a new general AI assistant for executing dbatools commands.

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
        [Parameter(ValueFromPipeline)]
        [Microsoft.SqlServer.Management.Smo.Database[]]$Database,
        [string]$Name,
        [string]$Description,
        [string]$Instructions,
        [string]$FunctionDescription,
        [string]$Model,
        [switch]$Force
    )
    process {
        if (-not $Model) {
            Write-Verbose "No model specified. Using default model."
            if ($PSDefaultParameterValues['*:Deployment']) {
                Write-Verbose "Using default model from PSDefaultParameterValues"
                $Model = $PSDefaultParameterValues['*:Deployment']
            } else {
                Write-Verbose "Using default model from function"
                $Model = "gpt-4o-mini"
            }
        }
        if ($Database) {
            Write-Verbose "Creating query function"
            $type = "database"
        } else {
            Write-Verbose "Creating dbatools function"
            $type = "general"
        }
        switch ($type) {
            "database" {
                foreach ($db in $Database) {
                    if (-not $PSBoundParameters.Instructions) {
                        $instructionsfile = Join-Path -Path $script:ModuleRootLib -Childpath instruct-query.txt
                        $Instructions = Get-Content $instructionsfile -Raw
                    }
                    if (-not $PSBoundParameters.FunctionDescription) {
                        $FunctionDescription = "Use this function to answer user questions about the database. Input should be a fully formed SQL query."
                    }

                    Write-Verbose "Processing database: $($db.Name)"
                    $schema = ConvertTo-SqlString -Database $db -Force:$Force -Model $Model
                    $tokenCount = (Measure-TuneToken -InputObject $Instructions -Model cl100k_base).TokenCount
                    Write-Verbose "Token count for instructions: $tokenCount"

                    $toolList = @(
                        @{
                            "name"        = "ask_database"
                            "description" = $FunctionDescription
                            "parameters"  = @{
                                "properties" = @{
                                    "query" = @{
                                        "type"        = "string"
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
                        Instructions = $Instructions
                    }
                    Write-Verbose "Creating AI assistant for database: $($db.Name)"
                    PSOpenAI\New-Assistant @params
                }
            }
            "general" {
                if (-not $PSBoundParameters.Name) {
                    $Name = "dbatools"
                }

                if (-not $PSBoundParameters.Description) {
                    $Description = "Copilot for dbatools."
                }
                if (-not $PSBoundParameters.Instructions) {
                    $instructionsfile = Join-Path -Path $script:ModuleRootLib -Childpath instruct-dbatools.txt
                    $Instructions = Get-Content $instructionsfile -Raw
                }
                if (-not $PSBoundParameters.FunctionDescription) {
                    $FunctionDescription = "Use this function to execute dbatools commands."
                }

                $toolList = @(
                    @{
                        "name"        = "copy_database"
                        "description" = "Migrate one or more SQL Server databases to another server."
                        "parameters"  = @{
                            "type"       = "object"
                            "properties" = @{
                                "Source"       = @{
                                    "type"        = "string"
                                    "description" = "What is the source server name?"
                                }
                                "Destination"  = @{
                                    "type"        = "array"
                                    "items"       = @{
                                        "type" = "string"
                                    }
                                    "description" = "What is the destination server name?"
                                }
                                "Database"     = @{
                                    "type"        = "array"
                                    "items"       = @{
                                        "type" = "string"
                                    }
                                    "description" = "What is the name of the database(s) to copy?"
                                }
                                "DetachAttach" = @{
                                    "type"        = "boolean"
                                    "description" = "Did they ask to detach and attach the database?"
                                }
                                "AllDatabases"    = @{
                                    "type"        = "boolean"
                                    "description" = "Do they want all databases to be copied?"
                                }
                                "Force" = @{
                                    "type"        = "boolean"
                                    "description" = "Do they want to force the copy? No cares, just go for it."
                                }
                                "SharedPath" = @{
                                    "type"        = "string"
                                    "description" = "What is the network share/shared path/directory to use for the copy?"
                                }
                                "UseLastBackup"   = @{
                                    "type"        = "boolean"
                                    "description" = "Do they just want to use the last backup instead of a sharedpath?"
                                }
                                "WhatIf" = @{
                                    "type"        = "boolean"
                                    "description" = "Does the user want to see what would happen without actually doing it? Or just wonder what would happen?"
                                }
                            }
                            "required"   = @("Source", "Destination")
                        }
                    })

                    $params = @{
                        Name         = $Name
                        Functions    = $toolList
                        Model        = $Model
                        Description  = $Description
                        Instructions = $Instructions
                    }
                    Write-Verbose "Creating AI assistant for dbatools"
                    PSOpenAI\New-Assistant @params
            }
        }
    }
}