function Enter-DbaiDatabase {
<#
    .SYNOPSIS
    Enters an interactive session to execute natural language queries on a SQL Server database.

    .DESCRIPTION
    This command allows you to enter an interactive session where you can execute natural language queries on a specified SQL Server database. It utilizes the Invoke-DbaiQuery function to generate and execute the corresponding SQL queries based on your input.

    - Press Enter twice to execute the query after entering your natural language input.
    - Type "exit" or press Enter on an empty line to exit the interactive session.

    This command is based off of PSOpenAI's Enter-ChatGPT.

    .PARAMETER SqlInstance
    The SQL Server instance hosting the database. Default is "localhost".

    .PARAMETER SqlCredential
    The SQL Server credential to use for authentication.

    .PARAMETER Database
    The name of the database to query. Default is "Northwind".

    .PARAMETER AssistantName
    The name of the AI assistant to use for query generation.

    .PARAMETER SkipSafetyCheck
    Allows execution of potentially unsafe SQL queries.

    .EXAMPLE
    PS C:\> Enter-DbaiDatabase -Database AdventureWorks2019

    This example enters an interactive session to execute natural language queries on the AdventureWorks2019 database.

    .EXAMPLE
    PS C:\> Enter-DbaiDatabase -SqlInstance "SQLSERVER01" -Database "SalesDB" -SqlCredential sqluser

    This example enters an interactive session to execute natural language queries on the SalesDB database hosted on the SQLSERVER01 instance, using the provided SQL Server credential for authentication.

    .EXAMPLE
    PS C:\> Enter-DbaiDatabase -AssistantName "DataExplorer" -SkipSafetyCheck

    This example enters an interactive session using the "DataExplorer" AI assistant and allows execution of potentially unsafe SQL queries.

    .NOTES
    - Press Enter twice to execute the query after entering your natural language input.
    - Type "exit" or press Enter on an empty line to exit the interactive session.
    #>
    [CmdletBinding()]
    param (
        [string]$SqlInstance = "localhost",
        [pscredential]$SqlCredential,
        [string]$Database = "Northwind",
        [string]$AssistantName,
        [switch]$SkipSafetyCheck,
        [switch]$NoHeader,
        [switch]$NoClear
    )
    begin {
        $script:status = $null

        #region Display header
        if (-not $NoHeader) {
            if (-not $NoClear) {
                Clear-Host
            }
            (1..51) | ForEach-Object { Write-Host '/' -NoNewline }
            Write-Host ''
            Write-Host @"
      _ _           _              _            _
     | | |         | |            | |          (_)
   __| | |__   __ _| |_ ___   ___ | |___   __ _ _
  / _  | '_ \ / _  | __/ _ \ / _ \| / __| / _  | |
 | (_| | |_) | (_| | || (_) | (_) | \__ \| (_| | |
  \__,_|_.__/ \__,_|\__\___/ \___/|_|___(_)__,_|_|

"@
            Write-Host "Connected to: $Database"
            (1..51) | ForEach-Object { Write-Host '/' -NoNewline }
            Write-Host ''
            Write-Host ''
        }
        #endregion
    }
    process {
        while ($true) {
            #User prompt
            Write-Host "me> " -NoNewLine
            [string]$userPrompt = Get-UserPrompt

            #Parse special commands
            if ($script:status -eq 'exit' -or $userPrompt -eq 'exit' -or -not $userPrompt) {
                break
            }

            #Request to ChatGPT
            Write-Host "db> " -NoNewLine
            # this could use a stream but i dont know how to do streams and functions
            $parms = @{
                SqlInstance         = $SqlInstance
                SqlCredential       = $SqlCredential
                Database            = $Database
                AssistantName       = $AssistantName
                SkipSafetyCheck     = $SkipSafetyCheck
                Message             = $userPrompt
                InformationVariable = "answer"
            }

            Invoke-DbaiQuery @parms | Write-Host -NoNewline
            Write-Host "`r`n"
        }
    }
}