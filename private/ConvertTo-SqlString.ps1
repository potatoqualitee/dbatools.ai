function ConvertTo-SqlString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Microsoft.SqlServer.Management.Smo.Database[]]$Database,
        [ValidateSet('JSON', 'SQL', 'Text')]
        [string]$Type = 'Text',
        [string]$Model = 'gpt-4o',
        [switch]$Force
    )
    begin {
        function Compress-SqlSchema {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory, ValueFromPipeline)]
                [string[]]$Schema
            )
            process {
                # Remove leading/trailing whitespace and newline characters
                $compressedSchema = "$Schema".Trim()

                # Remove unnecessary whitespace between keywords, parentheses, commas, and semicolons
                $compressedSchema = $compressedSchema -replace '(\s+|\n+)(?=[\(\),;])', ''

                # Remove unnecessary whitespace between square brackets and table/column names
                $compressedSchema = $compressedSchema -replace '(\[|\])\s+', '$1'

                # Remove unnecessary whitespace between data types and column names
                $compressedSchema = $compressedSchema -replace '\]\s+(\w+)', '] $1'

                # Replace multiple consecutive whitespace characters with a single space
                $compressedSchema = $compressedSchema -replace '\s+', ' '

                # Output the compressed schema
                $compressedSchema
            }
        }
    }
    process {
        foreach ($db in $Database) {
            $dbName = $db.Name

            if ($script:dbSchema.ContainsKey($dbName) -and -not $Force) {
                Write-Verbose "Using cached schema for database $dbName"
                $script:dbSchema[$dbName]
                continue
            }

            Write-Verbose "Refreshing database $dbName to ensure we have the latest schema"
            $null = $db.Refresh()
            $schema = @()
            $tableIndex = 0

            switch ($Type) {
                'JSON' {
                    $schemaInfo = @{
                        Tables        = [System.Collections.Generic.List[object]]::new()
                        Views         = [System.Collections.Generic.List[object]]::new()
                        Relationships = [System.Collections.Generic.List[object]]::new()
                    }

                    # Retrieve tables, columns, and foreign keys in a single loop
                    $tables = $database.Tables | Where-Object IsSystemObject -eq $false

                    $tables = $database.Tables | Where-Object IsSystemObject -eq $false
                    $totalTables = ($tables.Count) + 1
                    foreach ($table in $tables) {
                        $tableIndex++
                        $progressParams = @{
                            Activity         = "Processing Tables"
                            Status           = "Table: $($table.Name)"
                            PercentComplete  = ($tableIndex / $totalTables) * 100
                            CurrentOperation = "Database: $dbName"
                        }
                        Write-Progress @progressParams
                        Write-Verbose "Adding table $($table.Name) to schema"

                        $tableInfo = @{
                            Schema  = $table.Schema
                            Name    = $table.Name
                            Columns = [System.Collections.Generic.List[object]]::new()
                        }
                        foreach ($column in $table.Columns) {
                            $columnInfo = @{
                                Name     = $column.Name
                                DataType = $column.DataType.Name
                            }
                            $tableInfo.Columns.Add($columnInfo)
                        }
                        $schemaInfo.Tables.Add($tableInfo)

                        # Cache foreign keys for the current table, using a combination of database name and table Urn as the key
                        $fkCacheKey = "$dbName-$($table.Urn)"
                        if (-not $script:foreignKeyCache.ContainsKey($fkCacheKey)) {
                            $script:foreignKeyCache[$fkCacheKey] = $table.ForeignKeys
                        }
                    }

                    # Retrieve views and their columns
                    $views = $database.Views | Where-Object IsSystemObject -eq $false
                    foreach ($view in $views) {
                        Write-Verbose "Adding view $view to schema"
                        $viewInfo = @{
                            Schema  = $view.Schema
                            Name    = $view.Name
                            Columns = [System.Collections.Generic.List[object]]::new()
                        }
                        foreach ($column in $view.Columns) {
                            $columnInfo = @{
                                Name     = $column.Name
                                DataType = $column.DataType.Name
                            }
                            $viewInfo.Columns.Add($columnInfo)
                        }
                        $schemaInfo.Views.Add($viewInfo)
                    }

                    # Retrieve table relationships using cached foreign keys
                    foreach ($table in $tables) {
                        Write-Verbose "Adding Foreign Keys to schema"
                        $fkCacheKey = "$dbName-$($table.Urn)"
                        $foreignKeys = $script:foreignKeyCache[$fkCacheKey]
                        foreach ($foreignKey in $foreignKeys) {
                            if ($foreignKey.Parent) {
                                $reftable = $foreignKey.ReferencedTable
                                $refschema = $foreignKey.ReferencedTableSchema
                                $refcolumn = $db.Tables[$reftable, $refschema].Columns | Where-Object { $_.InPrimaryKey }

                                $relationshipInfo = @{
                                    ParentTable      = $foreignKey.Parent.Name
                                    ParentColumn     = $foreignKey.Columns[0].Name
                                    ReferencedTable  = $foreignKey.ReferencedTable
                                    ReferencedColumn = ($refcolumn | ForEach-Object { $PSItem.Name }) -join ', '
                                }

                                $schemaInfo.Relationships.Add($relationshipInfo)
                            }
                        }
                    }

                    $tableIndex++
                    $progressParams = @{
                        Activity         = "Processing Tables"
                        Status           = "Compressing JSON"
                        PercentComplete  = ($tableIndex / $totalTables) * 100
                        CurrentOperation = "Database: $dbName"
                    }

                    Write-Progress @progressParams
                    $schema = $schemaInfo | ConvertTo-Json -Depth 100 -Compress
                }
                'SQL' {
                    # Retrieve tables and their columns
                    $tables = $database.Tables | Where-Object IsSystemObject -eq $false

                    $totalTables = ($tables.Count) + 1
                    $tableIndex = 0
                    foreach ($table in $tables) {
                        $tableIndex++
                        $progressParams = @{
                            Activity         = "Processing Tables"
                            Status           = "Table: $($table.Name)"
                            PercentComplete  = ($tableIndex / $totalTables) * 100
                            CurrentOperation = "Database: $dbName"
                        }
                        Write-Progress @progressParams
                        Write-Verbose "Adding table $($table.Name) to schema"

                        $tableDefinition = "CREATE TABLE [$($table.Schema)].[$($table.Name)] ("
                        $columnDefinitions = foreach ($column in $table.Columns) {
                            "[$($column.Name)] $($column.DataType.Name)"
                        }
                        $tableDefinition += $columnDefinitions -join ", "
                        $tableDefinition += ");"
                        $schema += $tableDefinition

                        # Cache foreign keys for the current table, using a combination of database name and table Urn as the key
                        $fkCacheKey = "$dbName-$($table.Urn)"
                        if (-not $script:foreignKeyCache.ContainsKey($fkCacheKey)) {
                            $script:foreignKeyCache[$fkCacheKey] = $table.ForeignKeys
                        }
                    }

                    # Retrieve views and their columns
                    $views = $database.Views | Where-Object IsSystemObject -eq $false
                    foreach ($view in $views) {
                        Write-Verbose "Adding view $view to schema"
                        $viewDefinition = "CREATE VIEW [$($view.Schema)].[$($view.Name)] AS $($view.Definition)"
                        $schema += $viewDefinition
                    }

                    # Retrieve table relationships using cached foreign keys
                    foreach ($table in $tables) {
                        Write-Verbose "Adding Foreign Keys to schema"
                        $fkCacheKey = "$dbName-$($table.Urn)"
                        $foreignKeys = $script:foreignKeyCache[$fkCacheKey]
                        foreach ($foreignKey in $foreignKeys) {
                            if ($foreignKey.Parent) {
                                $reftable = $foreignKey.ReferencedTable
                                $refschema = $foreignKey.ReferencedTableSchema
                                $refcolumn = $db.Tables[$reftable, $refschema].Columns | Where-Object { $_.InPrimaryKey }

                                $fkDefinition = "ALTER TABLE [$($foreignKey.Parent.Schema)].[$($foreignKey.Parent.Name)] "
                                $fkDefinition += "ADD CONSTRAINT [$($foreignKey.Name)] FOREIGN KEY ([$($foreignKey.Columns[0].Name)]) "
                                $fkDefinition += "REFERENCES [$($refschema)].[$($reftable)] ([$($refcolumn.Name)]);"
                                $schema += $fkDefinition
                            }
                        }
                    }

                    $tableIndex++
                    $progressParams = @{
                        Activity         = "Processing Tables"
                        Status           = "Generating SQL"
                        PercentComplete  = ($tableIndex / $totalTables) * 100
                        CurrentOperation = "Database: $dbName"
                    }

                    Write-Progress @progressParams

                    $compressed = Compress-SqlSchema -Schema $schema
                    $schema = $compressed -join "`n"
                }
                'Text' {
                    # Retrieve tables and their columns
                    $tables = $database.Tables | Where-Object IsSystemObject -eq $false

                    $totalTables = $tables.Count
                    foreach ($table in $tables) {
                        Write-Verbose "Processing table: $($table.Name)"
                        $tableString = "Table: $($table.Schema).$($table.Name)`nColumns: "

                        $tableIndex++
                        $progressParams = @{
                            Activity         = "Processing Tables"
                            Status           = "Table: $($table.Name)"
                            PercentComplete  = ($tableIndex / $totalTables) * 100
                            CurrentOperation = "Database: $dbName"
                        }
                        Write-Progress @progressParams

                        if ($Model -match 'gpt-4') {
                            # big enough for datatypes too
                            $columnStrings = $table.Columns | ForEach-Object { "$($_.Name) ($($_.DataType.Name))" }
                        } else {
                            $columnStrings = $table.Columns.Name -join ", "
                        }
                        $tableString += $columnStrings

                        # Cache foreign keys for the current table, using a combination of database name and table Urn as the key
                        $fkCacheKey = "$dbName-$($table.Urn)"
                        if (-not $script:foreignKeyCache.ContainsKey($fkCacheKey)) {
                            $script:foreignKeyCache[$fkCacheKey] = $table.ForeignKeys
                        }

                        $foreignKeys = $script:foreignKeyCache[$fkCacheKey]
                        if ($foreignKeys) {
                            Write-Verbose "Adding Foreign Keys to schema"
                            $fkString = @()
                            foreach ($foreignKey in $foreignKeys) {
                                $refTable = $foreignKey.ReferencedTable
                                $refSchema = $foreignKey.ReferencedTableSchema
                                $refColumn = $db.Tables[$refTable, $refSchema].Columns | Where-Object { $_.InPrimaryKey }
                                $fkString += "$($foreignKey.Columns[0].Name) -> $refSchema.$refTable($($refColumn.Name))"
                            }
                            if ($fkString) {
                                $tableString += "`nForeign Keys: $($fkString -join ', ')"
                            }
                        }
                        $schema += $tableString.TrimEnd() + "`n"
                    }

                    # Retrieve views and their columns
                    $views = $database.Views | Where-Object IsSystemObject -eq $false

                    foreach ($view in $views) {
                        Write-Verbose "Processing view: $($view.Name)"

                        $viewString = "View: $($view.Schema).$($view.Name)`nColumns: "
                        if ($Model -match 'gpt-4') {
                            # big enough for datatypes too
                            $columnStrings = $view.Columns | ForEach-Object { "$($_.Name) ($($_.DataType.Name))" }
                        } else {
                            $columnStrings = $view.Columns.Name -join ", "
                        }
                        $viewString += $columnStrings
                        $schema += $viewString + "`n"
                    }

                    $schema = $schema -join "`n"
                }
            }

            $script:dbSchema[$dbName] = $schema
            $tokens = (Measure-TuneToken -InputObject "$schema" -Model cl100k_base).TokenCount
            Write-Verbose "Token count for schema: $tokens"
            $schema
        }

        # Finally, mark the entire process as complete
        Write-Progress -Activity "Processing Tables" -Status "All databases processed" -Completed
    }
}