function Import-DbaiStructuredObject {
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
        [string]$Database = "Northwind",
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Schema = "dbo",
        [Parameter(ValueFromPipelineByPropertyName)]
        [int]$BatchSize = 50000,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$SystemMessage = "Convert text to structured data."
    )
    begin {
        $PSDefaultParameterValues['Write-Progress:Activity'] = "Importing Structured Objects"

        Write-Verbose "Establishing connection to SQL Server instance: $SqlInstance"
        try {
            $splat = @{
                SqlInstance   = $SqlInstance
                SqlCredential = $SqlCredential
                Database      = $Database
            }
            $server = Connect-DbaInstance @splat
            Write-Verbose "Successfully connected to $SqlInstance"
        } catch {
            throw "Error occurred while establishing connection to $SqlInstance | $PSItem"
        }

        if (-not $JsonSchema) {
            Write-Verbose "Reading JSON schema from: $JsonSchemaPath"
            if (-not (Test-Path -Path $JsonSchemaPath)) {
                throw "JSON schema file not found at path: $JsonSchemaPath"
            }
            try {
                $JsonSchema = Get-Content -Path $JsonSchemaPath -Raw
                Write-Verbose "Successfully read JSON schema"
            } catch {
                throw "Failed to read JSON schema file: $PSItem"
            }
        }

        if (-not $JsonSchema) {
            throw "Either JsonSchemaPath or JsonSchema must be provided."
        }

        Write-Verbose "Parsing JSON schema"
        try {
            $schemaObject = $JsonSchema | ConvertFrom-Json -ErrorAction Stop
            Write-Verbose "Successfully parsed JSON schema"
        } catch {
            throw "Invalid JSON schema: $PSItem"
        }

        Write-Verbose "Initialization complete"
    }
    process {
        $totalFiles = $Path.Count
        $processedFiles = 0

        foreach ($file in $Path) {
            $processedFiles++
            Write-Progress -Status "Processing file $processedFiles of $totalFiles" -PercentComplete (($processedFiles / $totalFiles) * 100)

            Write-Verbose "Processing file: $file"
            if (-not (Test-Path -Path $file)) {
                Write-Warning "File not found: $file"
                continue
            }

            Write-Verbose "Converting file to markdown"
            $content = ConvertTo-DbaiMarkdown -Path $file -Raw
            $content | Write-Verbose

            $splat = @{
                Content       = $content
                JsonSchema    = $JsonSchema
                SystemMessage = $SystemMessage
            }
            Write-Verbose "Converting content to structured object"
            $structuredData = ConvertTo-DbaiStructuredObject @splat
            $structuredData | ConvertTo-Json -Depth 10 | Write-Verbose
            try {
                foreach ($item in $structuredData) {
                    Write-Verbose "Processing structured data item"
                    $mainTableName = $schemaObject.name
                    Write-Verbose "Processing main table: $mainTableName"

                    # Separate main object properties and array properties
                    $mainObjectProperties = $item.PSObject.Properties | Where-Object { $_.Value -isnot [Array] }
                    $arrayProperties = $item.PSObject.Properties | Where-Object { $_.Value -is [Array] }

                    # Handle main object
                    $columns = $mainObjectProperties | ForEach-Object { "[$($_.Name)] NVARCHAR(MAX)" }
                    $createTableSql = "IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = '$mainTableName' AND schema_id = SCHEMA_ID('$Schema'))
                                       CREATE TABLE $Schema.$mainTableName (Id INT IDENTITY(1,1) PRIMARY KEY, $($columns -join ', '))"
                    Write-Verbose "Executing SQL: $createTableSql"
                    Invoke-DbaQuery -SqlInstance $server -Database $Database -Query $createTableSql

                    $insertColumns = $mainObjectProperties.Name -join ', '
                    $insertValues = $mainObjectProperties | ForEach-Object {
                        if ($null -eq $_.Value) { "NULL" } else { "'$($_.Value -replace "'", "''")'" }
                    }
                    $insertSql = "INSERT INTO $Schema.$mainTableName ($insertColumns) VALUES ($($insertValues -join ', ')); SELECT SCOPE_IDENTITY() AS Id"
                    Write-Verbose "Executing SQL: $insertSql"
                    $mainId = (Invoke-DbaQuery -SqlInstance $server -Database $Database -Query $insertSql).Id
                    Write-Verbose "Data inserted into main table with ID: $mainId"

                    # Handle array properties
                    foreach ($arrayProp in $arrayProperties) {
                        $childTableName = "${mainTableName}_$($arrayProp.Name)"
                        Write-Verbose "Processing child table: $childTableName"

                        $createChildTableSql = @"
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = '$childTableName' AND schema_id = SCHEMA_ID('$Schema'))
    CREATE TABLE $Schema.$childTableName (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        ${mainTableName}Id INT,
        [vaccine_name] NVARCHAR(MAX)
    )
"@
                        Write-Verbose "Executing SQL: $createChildTableSql"
                        Invoke-DbaQuery -SqlInstance $server -Database $Database -Query $createChildTableSql

                        $nestedTableName = "${childTableName}_administration_records"
                        $createNestedTableSql = @"
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = '$nestedTableName' AND schema_id = SCHEMA_ID('$Schema'))
    CREATE TABLE $Schema.$nestedTableName (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        ${childTableName}Id INT,
        [date_administered] NVARCHAR(MAX),
        [veterinarian] NVARCHAR(MAX)
    )
"@
                        Write-Verbose "Executing SQL: $createNestedTableSql"
                        Invoke-DbaQuery -SqlInstance $server -Database $Database -Query $createNestedTableSql

                        foreach ($childItem in $arrayProp.Value) {
                            $insertChildSql = @"
        INSERT INTO $Schema.$childTableName (${mainTableName}Id, [vaccine_name])
        VALUES ($mainId, '$($childItem.vaccine_name)');
        SELECT SCOPE_IDENTITY() AS Id
"@
                            Write-Verbose "Executing SQL: $insertChildSql"
                            $childId = (Invoke-DbaQuery -SqlInstance $server -Database $Database -Query $insertChildSql).Id
                            Write-Verbose "Data inserted into child table with ID: $childId"

                            foreach ($adminRecord in $childItem.administration_records) {
                                $insertNestedSql = @"
            INSERT INTO $Schema.$nestedTableName (${childTableName}Id, [date_administered], [veterinarian])
            VALUES ($childId, '$($adminRecord.date_administered)', '$($adminRecord.veterinarian)');
            SELECT SCOPE_IDENTITY() AS Id
"@
                                Write-Verbose "Executing SQL: $insertNestedSql"
                                $nestedId = (Invoke-DbaQuery -SqlInstance $server -Database $Database -Query $insertNestedSql).Id
                                Write-Verbose "Data inserted into nested table with ID: $nestedId"
                            }
                        }
                    }
                }
                Write-Verbose "File processing complete: $file"
            } catch {
                throw "Error processing file $file | $PSItem"
            }
        }
    }
    end {
        Write-Progress -Completed -Status "Import complete"
        Write-Verbose "Import-DbaiStructuredObject completed"
    }
}