function Import-DbaiFile {
    <#
    .SYNOPSIS
    Imports structured data from files into a SQL Server database and provides progress feedback.

    .DESCRIPTION
    The Import-DbaiFile function processes files (typically PDFs but could be images or Word docs), converts them to structured data based on a provided JSON schema, and imports the data into SQL Server tables. It handles nested data structures, supports batch processing of multiple files, and provides progress feedback using Write-Progress.

    .PARAMETER Path
    Specifies the path(s) to the file(s) to be imported. Defaults to an 'immunization.pdf' file in the module's lib directory.

    .PARAMETER JsonSchemaPath
    Specifies the path to the JSON schema file. Defaults to an 'immunization.json' file in the module's lib directory.

    .PARAMETER JsonSchema
    Specifies the JSON schema as a string. If provided, this takes precedence over JsonSchemaPath.

    .PARAMETER SqlInstance
    Specifies the SQL Server instance to connect to. Defaults to "localhost".

    .PARAMETER SqlCredential
    Specifies the credentials for SQL Server authentication.

    .PARAMETER Database
    Specifies the target database name. Defaults to "tempdb".

    .PARAMETER Schema
    Specifies the database schema to use. Defaults to "dbo".

    .PARAMETER SystemMessage
    Specifies a system message for data conversion. Defaults to "Convert text to structured data."

    .PARAMETER RequiredText
    An array of strings that must be present in the output. If any of these strings are missing, the function will request the AI to try again.

    .PARAMETER Model
    Specifies the model to use for data conversion. If not provided, uses the deployment set in Set-DbaiProvider.

    .EXAMPLE
    PS C:\> Import-DbaiFile

    This example uses all default values. It imports data from the included 'immunization.pdf' file in the module's lib directory into the 'tempdb' database on the local SQL Server instance. It uses the default 'immunization.json' schema file, also located in the lib directory, to structure the data. The data is imported into the 'dbo' schema in SQL Server.

    .EXAMPLE
    PS C:\> $params = @{
        Path           = "C:\Logs\ServerLogs.txt"
        JsonSchemaPath = "C:\Schemas\server_log_schema.json"
        SqlInstance    = "SQLMON01"
        Database       = "LogAnalysis"
        Schema         = "monitor"
        SystemMessage  = "Extract server log entries with timestamps, severity, and messages"
    }
    PS C:\> Import-DbaiFile @params

    This example processes a server log file. It uses a custom JSON schema to structure the log data, then imports it into the LogAnalysis database on the SQLMON01 instance. The data is stored in the 'monitor' schema.

    This setup allows IT pros to easily import various log files into SQL Server for centralized analysis. The custom schema ensures that the log data is correctly structured, while the SystemMessage parameter guides the AI in extracting relevant information from the logs.

    .EXAMPLE
    PS C:\> $params = @{
        Path           = "C:\DevDocs\APISpecification.md"
        JsonSchemaPath = "C:\Schemas\api_spec_schema.json"
        SqlInstance    = "DEVDB01"
        Database       = "API_Documentation"
        Schema         = "dev"
        SystemMessage  = "Extract API endpoints, parameters, and response structures"
        RequiredText   = @("Endpoint", "Method", "Parameters", "Response")
    }
    PS C:\> Import-DbaiFile @params

    This example extracts API specifications from a Markdown file. It uses a custom schema to structure the API data, then imports it into the API_Documentation database on the DEVDB01 instance. The data is stored in the 'dev' schema.

    This approach allows developers to maintain API docs in Markdown and automatically sync them to a queryable database. They can then easily generate reports, track changes over time, or even auto-generate client libraries based on the structured API data in SQL Server.

    The RequiredText parameter ensures that key elements of the API spec are present in the extracted data.

    .EXAMPLE
    PS C:\> $params = @{
        Path           = "C:\Reports\FinancialReport.pdf"
        JsonSchemaPath = "C:\Schemas\financial_report_schema.json"
        Model          = "gpt-4"
        SqlInstance    = "FINDB01"
        Database       = "FinancialReports"
        Schema         = "reports"
        SystemMessage  = "Extract financial metrics, dates, and analysis"
    }
    PS C:\> Import-DbaiFile @params

    This example uses GPT-4 specifically for processing a financial report, overriding any default model set via Set-DbaiProvider. This allows using more capable models for complex documents while maintaining the ability to use other models for simpler tasks.

#>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$Path = (Join-Path $script:ModuleRootLib -ChildPath immunization.pdf),
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$JsonSchemaPath = (Join-Path $script:ModuleRootLib -ChildPath immunization.json),
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$JsonSchema,
        [Parameter(ValueFromPipelineByPropertyName)]
        [DbaInstanceParameter]$SqlInstance = "localhost",
        [Parameter(ValueFromPipelineByPropertyName)]
        [PSCredential]$SqlCredential,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Database = "tempdb",
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Schema = "dbo",
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$SystemMessage = "Convert text to structured data.",
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$RequiredText
    )
    begin {
        $PSDefaultParameterValues["*:SqlInstance"] = $SqlInstance
        $PSDefaultParameterValues["*:SqlCredential"] = $SqlCredential
        $PSDefaultParameterValues["*DbaDatabase:Database"] = $Database
        $PSDefaultParameterValues["*DbaQuery:Database"] = $Database

        try {
            $null = Connect-DbaInstance
            Write-Verbose "Successfully connected to $SqlInstance"
        } catch {
            throw "Error occurred while establishing connection to $SqlInstance | $PSItem"
        }

        if ($JsonSchemaPath -and -not $JsonSchema) {
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
            $schemaObject = $JsonSchema | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "Invalid JSON schema: $PSItem"
        }

        $filesToProcess = @()
    }
    process {
        # if path matches immunization.pdf and the schema is not immunization.json then throw
        # say cant use the default schema with a different file
        if ("$Path" -match "immunization" -and "$JsonSchemaPath" -notmatch "immunization.json") {
            Write-Warning "Invalid schema for immunization.pdf. Please provide immunization.json schema."
            continue
        }
        # same for jsonschema back to path
        if ("$JsonSchemaPath" -match "immunization.json" -and "$Path" -notmatch "immunization") {
            Write-Warning "Invalid file for immunization.json schema. Please provide immunization.pdf file."
            continue
        }
        $filesToProcess += $Path
    }
    end {
        $fileCounter = 0
        $totalFiles = $filesToProcess.Count
        foreach ($file in $filesToProcess) {
            $fileCounter++
            Write-Progress -Activity "Processing files" -Status "File $fileCounter of $totalFiles" -PercentComplete (($fileCounter / $totalFiles) * 100)

            if (-not (Test-Path -Path $file)) {
                Write-Warning "File not found: $file"
                continue
            }

            Write-Progress -Activity "Processing file: $file" -Status "Reading file content" -PercentComplete 0

            try {
                if ($file -match '\.xml|\.md|\.txt|\.json') {
                    $content = Get-Content -Path $file -Raw
                } else {
                    $content = ConvertTo-DbaiMarkdown -Path $file -Raw
                }
            } catch {
                Write-Warning "Failed to convert $file | $PSItem"
                continue
            }

            Write-Progress -Activity "Processing file: $file" -Status "Converting to structured data" -PercentComplete 25

            if ($file -match '\.json') {
                $structuredData = Get-Content -Path $file -Raw | ConvertFrom-Json
            } else {
                $splat = @{
                    Content       = $content
                    JsonSchema    = $JsonSchema
                    SystemMessage = $SystemMessage
                }
                $structuredData = ConvertTo-DbaiStructuredObject @splat
                $structuredData | ConvertTo-Json -Depth 10 | Write-Debug
            }

            $tableNames = @()
            $selectStatements = @()
            $sqlResults = @()

            Write-Progress -Activity "Processing file: $file" -Status "Creating and populating tables" -PercentComplete 50

            foreach ($item in $structuredData) {
                $mainTableName = $schemaObject.name
                if (-not $mainTableName) {
                    $mainTableName = (Get-Item -Path $file).BaseName
                }
                $tableNames += $mainTableName
                Write-Verbose "Processing main table: $mainTableName"

                $columns = $item.PSObject.Properties | Where-Object { $_.Value -isnot [Array] } | ForEach-Object { "[$($_.Name)] NVARCHAR(MAX)" }
                $createTableSql = "IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = @tableName AND schema_id = SCHEMA_ID(@schema)) CREATE TABLE $Schema.$mainTableName (Id INT IDENTITY(1,1) PRIMARY KEY, $($columns -join ', '))"
                $createTableParams = @{
                    Query         = $createTableSql
                    SqlParameters = @{
                        tableName = $mainTableName
                        schema    = $Schema
                    }
                }
                Invoke-DbaQuery @createTableParams

                $insertColumns = ($item.PSObject.Properties | Where-Object { $_.Value -isnot [Array] }).Name
                $insertParams = @{}
                $insertParamNames = @()
                foreach ($prop in ($item.PSObject.Properties | Where-Object { $_.Value -isnot [Array] })) {
                    $paramName = "@" + $prop.Name
                    $insertParams[$prop.Name] = $prop.Value
                    $insertParamNames += $paramName
                }
                $insertSql = "INSERT INTO $Schema.$mainTableName ($($insertColumns -join ', ')) VALUES ($($insertParamNames -join ', ')); SELECT SCOPE_IDENTITY() AS Id"
                $insertParams = @{
                    Query         = $insertSql
                    SqlParameters = $insertParams
                }
                $mainId = (Invoke-DbaQuery @insertParams).Id

                $selectStatements += "SELECT TOP 10 * FROM $Schema.$mainTableName"
                $sqlResults += Invoke-DbaQuery -Query "SELECT TOP 10 * FROM $Schema.$mainTableName"

                $item.PSObject.Properties | Where-Object { $_.Value -is [Array] } | ForEach-Object {
                    $childTableName = "${mainTableName}_$($_.Name)"
                    $tableNames += $childTableName
                    Write-Verbose "Processing child table: $childTableName"

                    $childColumns = $_.Value[0].PSObject.Properties | ForEach-Object { "[$($_.Name)] NVARCHAR(MAX)" }
                    $createChildTableSql = "IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = @tableName AND schema_id = SCHEMA_ID(@schema)) CREATE TABLE $Schema.$childTableName (Id INT IDENTITY(1,1) PRIMARY KEY, ${mainTableName}Id INT, $($childColumns -join ', '))"

                    $createChildTableParams = @{
                        Query         = $createChildTableSql
                        SqlParameters = @{
                            tableName = $childTableName
                            schema    = $Schema
                        }
                    }
                    Invoke-DbaQuery @createChildTableParams

                    foreach ($childItem in $_.Value) {
                        $childInsertColumns = @("${mainTableName}Id") + $childItem.PSObject.Properties.Name
                        $childInsertParams = @{
                            "${mainTableName}Id" = $mainId
                        }
                        $childInsertParamNames = @("@${mainTableName}Id")
                        foreach ($prop in $childItem.PSObject.Properties) {
                            $paramName = "@" + $prop.Name
                            $childInsertParams[$prop.Name] = $prop.Value
                            $childInsertParamNames += $paramName
                        }
                        $childInsertSql = "INSERT INTO $Schema.$childTableName ($($childInsertColumns -join ', ')) VALUES ($($childInsertParamNames -join ', '))"
                        $childInsertParams = @{
                            Query         = $childInsertSql
                            SqlParameters = $childInsertParams
                        }
                        Invoke-DbaQuery @childInsertParams
                    }

                    $selectStatements += "SELECT TOP 10 * FROM $Schema.$childTableName"
                    $sqlResults += Invoke-DbaQuery -Query "SELECT TOP 10 * FROM $Schema.$childTableName"
                }
            }

            Write-Progress -Activity "Processing file: $file" -Status "Generating output" -PercentComplete 90

            [pscustomobject]@{
                ProcessedFile    = (Get-Item $file).Name
                Markdown         = $content
                StructuredData   = $structuredData
                TableNames       = $tableNames
                SelectStatements = $selectStatements
                SqlResults       = $sqlResults
            }

            Write-Progress -Activity "Processing file: $file" -Status "Complete" -PercentComplete 100
        }
        Write-Progress -Activity "Processing files" -Status "Complete" -PercentComplete 100
    }
}