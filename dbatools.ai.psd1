#
# Module manifest for module 'dbatools.ai'
#
# Generated by: Chrissy LeMaire
#
# Generated on: 4/3/2024
#
@{

    # Script module or binary module file associated with this manifest.
    RootModule = 'dbatools.ai.psm1'

    # Version number of this module.
    ModuleVersion = '1.4'

    # ID used to uniquely identify this module
    GUID = '1c4f2db2-5cff-4179-b755-ea7d228153ae'

    # Author of this module
    Author = 'Chrissy LeMaire'

    # Company or vendor of this module
    CompanyName = 'cl'

    # Copyright statement for this module
    Copyright = '(c) 2024 Chrissy LeMaire. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'dbatools.ai is a copilot for SQL Server databases'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules   = @(
        'dbatools',
        @{ModuleName = 'finetuna'; ModuleVersion = '2.0' },
        @{ModuleName = 'PSOpenAI'; ModuleVersion = '4.7.0' }
    )

    FunctionsToExport = @(
        'Clear-DbaiProvider',
        'ConvertTo-DbaiInstruction',
        'ConvertTo-DbaiMarkdown',
        'ConvertTo-DbaiStructuredObject',
        'Enter-DbaiDatabase',
        'Get-DbaiProvider',
        'Import-DbaiFile',
        'Invoke-DbatoolsAI',
        'Invoke-DbaiQuery',
        'New-DbaiAssistant',
        'Set-DbaiProvider'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport   = @('dbai', 'dtai')

    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('openai', 'gpt', 'ai', 'dbatools', 'sqlserver', 'database', 'schema', 'prompt', 'assistant', 'dbai', 'dbassistant')

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/potatoqualitee/dbatools.ai'

            # A URL to an icon representing this module.
            # IconUri = ''
        }
    }
}