function ConvertTo-DbaiInstruction {
<#
    .SYNOPSIS
    Converts a SQL Server database schema to a specified format.

    .DESCRIPTION
    The ConvertTo-DbaiInstruction function converts the schema of a SQL Server database to a specified format, such as JSON, SQL, or plain text. It also measures the token count of the provided instructions.

    .PARAMETER Database
    The SQL Server database object(s) for which to convert the schema.

    .PARAMETER Instructions
    Instructions to include with the converted schema.

    .PARAMETER FunctionDescription
    Description of the function used to answer user questions about the database.

    .PARAMETER Type
    The format to which the database schema should be converted. Supported values are 'JSON', 'SQL', and 'Text'. Default is 'Text'.

    .PARAMETER Model
    The name of the AI model to use for token count measurement. Default is 'gpt-4o'.

    .PARAMETER Force
    Forces the conversion of the schema, even if it has been previously converted.

    .EXAMPLE
    PS C:\> $db = Get-DbaDatabase -SqlInstance localhost -Database AdventureWorks2019
    PS C:\> $db | ConvertTo-DbaiInstruction -Type SQL

    This example converts the schema of the AdventureWorks2019 database to SQL format.

#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Microsoft.SqlServer.Management.Smo.Database[]]$Database,
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
            $schema = ConvertTo-SqlString -Database $db -Force:$Force -Model $Model
            [PSCustomObject]@{
                Database     = $db.Name
                SystemPrompt = $SystemPrompt
                Schema       = $schema
                Instructions = $Instructions
                TokenCount   = (Measure-TuneToken -InputObject $Instructions -Model cl100k_base).TokenCount
            }
        }
    }
}