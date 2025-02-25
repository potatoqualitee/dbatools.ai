### dbatools.ai has an example command, Import-DbaiFile, that shows you how to do this
Import-Module ./dbatools.ai.psd1 -Force

$splat = @{
    Path            = './lib/immunization.md'
    JsonSchemaPath  = './lib/immunization.json'
    SqlInstance     = 'localhost'
    Database        = 'tempdb'
    Schema          = 'dbo'
    SystemMessage   = 'Convert text to structured data.'
}

Import-DbaiFile @splat

### See the output!
Invoke-DbaQuery -SqlInstance localhost -Query "SELECT * FROM tempdb.dbo.pet_vaccinations"

## Structured Output's JSON in-depth
# Define the JSON schema as a PowerShell object
# You can use ChatGPT for this part, I do
$schema = @{
    name   = "cultural_comparison_schema"
    strict = $true
    schema = @{
        type       = "object"
        properties = @{
            country = @{
                type = "string"
                enum = @("USA", "Belgium", "Germany")
                description = "Is the topic more American, Belgian or German?"
            }
            reasoning = @{
                type        = "string"
                description = "What is the reasoning behind this conclusion?"
            }
        }
        required            = @("country", "reasoning")
        additionalProperties = $false
    }
}

# Convert the PowerShell object to JSON
$json = $schema | ConvertTo-Json -Depth 5

# Splat parameters for Request-ChatCompletion
$splat = @{
    Model      = "gpt-4o-mini"
    Message    = "Is beer more American, Belgian or German?"
    Format     = "json_schema"
    JsonSchema = $json
}

# Make the request and output to console
((Request-ChatCompletion @splat).Answer | ConvertFrom-Json).reasoning