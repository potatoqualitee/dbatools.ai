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
            Write-Error "Error occurred while establishing connection to $SqlInstance | $PSItem"
            return
        }

        if (-not $JsonSchema) {
            Write-Verbose "Reading JSON schema from: $JsonSchemaPath"
            if (-not (Test-Path -Path $JsonSchemaPath)) {
                Write-Error "JSON schema file not found at path: $JsonSchemaPath"
                return
            }
            try {
                $JsonSchema = Get-Content -Path $JsonSchemaPath -Raw
                Write-Verbose "Successfully read JSON schema"
            } catch {
                Write-Error "Failed to read JSON schema file: $PSItem"
                return
            }
        }

        if (-not $JsonSchema) {
            Write-Error "Either JsonSchemaPath or JsonSchema must be provided."
            return
        }

        Write-Verbose "Parsing JSON schema"
        try {
            $schemaObject = $JsonSchema | ConvertFrom-Json -ErrorAction Stop
            Write-Verbose "Successfully parsed JSON schema"
        } catch {
            Write-Error "Invalid JSON schema: $PSItem"
            return
        }

        $tables = @{}
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

            try {
                Write-Verbose "Converting file to markdown"
                $content = ConvertTo-DbaiMarkdown -Path $file -Raw
                $splat = @{
                    Content       = $content
                    JsonSchema    = $JsonSchema
                    SystemMessage = $SystemMessage
                }
                Write-Verbose "Converting content to structured object"
                $structuredData = ConvertTo-DbaiStructuredObject @splat

                foreach ($item in $structuredData) {
                    Write-Verbose "Processing structured data item"
                    $flattenedData = @{}
                    $arrayData = @{}

                    # Flatten the object and separate array properties
                    foreach ($prop in $item.PSObject.Properties) {
                        if ($prop.Value -is [Array]) {
                            $arrayData[$prop.Name] = $prop.Value
                        } else {
                            $flattenedData[$prop.Name] = $prop.Value
                        }
                    }

                    # Handle the main table
                    $mainTableName = $schemaObject.name
                    Write-Verbose "Processing main table: $mainTableName"
                    if (-not $tables.ContainsKey($mainTableName)) {
                        Write-Verbose "Creating main table if not exists"
                        $columns = $flattenedData.Keys | ForEach-Object { "[$PSItem] NVARCHAR(MAX)" }
                        $createTableSql = "IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = '$mainTableName' AND schema_id = SCHEMA_ID('$Schema'))
                                           CREATE TABLE $Schema.$mainTableName (Id INT IDENTITY(1,1) PRIMARY KEY, $($columns -join ', '))"
                        Invoke-DbaQuery -SqlInstance $server -Database $Database -Query $createTableSql
                        $tables[$mainTableName] = $true
                        Write-Verbose "Main table created or verified"
                    }

                    # Insert main data and get the ID
                    Write-Verbose "Inserting data into main table"
                    $insertColumns = $flattenedData.Keys -join ', '
                    $insertValues = $flattenedData.Values | ForEach-Object {
                        if ($null -eq $_) { "NULL" } else { "'$($_ -replace "'", "''")'" }
                    }
                    $insertSql = "INSERT INTO $Schema.$mainTableName ($insertColumns) VALUES ($($insertValues -join ', ')); SELECT SCOPE_IDENTITY() AS Id"
                    $mainId = (Invoke-DbaQuery -SqlInstance $server -Database $Database -Query $insertSql).Id
                    Write-Verbose "Data inserted into main table with ID: $mainId"

                    # Handle array properties
                    foreach ($arrayProp in $arrayData.Keys) {
                        $childTableName = "${mainTableName}_$arrayProp"
                        Write-Verbose "Processing child table: $childTableName"
                        if (-not $tables.ContainsKey($childTableName)) {
                            Write-Verbose "Creating child table if not exists"
                            $childColumns = $arrayData[$arrayProp][0].PSObject.Properties.Name |
                                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                                ForEach-Object {
                                    $columnName = $_ -replace '[^a-zA-Z0-9_]', ''
                                    if ([string]::IsNullOrWhiteSpace($columnName)) {
                                        $columnName = "Column_$([Guid]::NewGuid().ToString('N'))"
                                    }
                                    "[$columnName] NVARCHAR(MAX)"
                                }

                            if ($childColumns.Count -eq 0) {
                                Write-Warning "No valid columns found for child table: $childTableName"
                                continue
                            }

                            $createChildTableSql = "IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = '$childTableName' AND schema_id = SCHEMA_ID('$Schema'))
                                                    CREATE TABLE $Schema.$childTableName (Id INT IDENTITY(1,1) PRIMARY KEY, ${mainTableName}Id INT, $($childColumns -join ', '))"

                            try {
                                Invoke-DbaQuery -SqlInstance $server -Database $Database -Query $createChildTableSql -ErrorAction Stop
                                $tables[$childTableName] = $true
                                Write-Verbose "Child table created or verified"
                            } catch {
                                Write-Error "Failed to create child table $childTableName | $PSItem"
                                continue
                            }
                        }

                        Write-Verbose "Inserting data into child table"
                        foreach ($childItem in $arrayData[$arrayProp]) {
                            $validColumns = $childItem.PSObject.Properties.Name |
                                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                                ForEach-Object { $_ -replace '[^a-zA-Z0-9_]', '' }

                            if ($validColumns.Count -eq 0) {
                                Write-Warning "No valid columns found for child item in table: $childTableName"
                                continue
                            }

                            $childColumns = $validColumns -join ', '
                            $childValues = $validColumns | ForEach-Object {
                                $value = $childItem.$_
                                if ($null -eq $value) {
                                    "NULL"
                                } else {
                                    "'$($value -replace "'", "''")'"
                                }
                            }
                            $insertChildSql = "INSERT INTO $Schema.$childTableName (${mainTableName}Id, $childColumns) VALUES ($mainId, $($childValues -join ', '))"

                            try {
                                Invoke-DbaQuery -SqlInstance $server -Database $Database -Query $insertChildSql -ErrorAction Stop
                                Write-Verbose "Data inserted into child table"
                            } catch {
                                Write-Error "Failed to insert data into child table $childTableName | $PSItem"
                            }
                        }
                    }
                }
                Write-Verbose "File processing complete: $file"
            } catch {
                Write-Error "Error processing file $file | $PSItem"
            }
        }
    }
    end {
        Write-Progress -Completed -Status "Import complete"
        Write-Verbose "Import-DbaiStructuredObject completed"
    }
}