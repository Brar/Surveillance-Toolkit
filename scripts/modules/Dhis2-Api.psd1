@{
ModuleVersion = '0.0.1'
Author = 'Brar Piening'
CompanyName = 'The NeoIPC Project Consortium'
Copyright = '(c) 2023 The NeoIPC Project Consortium. All rights reserved.'
RootModule = 'Dhis2-Api.psm1'
GUID = 'f2ca7aac-c884-4a17-8b42-d70b51da4d1d'
PowerShellVersion = '7.3'
NestedModules = @(
    'Dhis2Option.psm1'
    'Dhis2OptionSet.psm1'
)
FunctionsToExport = @(
    'ConvertTo-Dhis2DataElement'
    'ConvertTo-Dhis2Option'
    'ConvertTo-Dhis2Program'
    'ConvertTo-Dhis2ProgramStage'
    'ConvertTo-Dhis2ProgramStageDataElement'
    'ConvertTo-Dhis2ProgramStageSection'
    'Get-Dhis2Defaults'
    'Set-Dhis2Defaults'
    'Reset-Dhis2Defaults'
    'Get-Dhis2Object'
    'Add-Dhis2Object'
    'Set-Dhis2Object'
    'Update-Dhis2Object'
    'Remove-Dhis2Object'
    'New-Dhis2DataElement'
    'New-Dhis2Option'
    'New-Dhis2OptionSet'
    'New-Dhis2Program'
    'New-Dhis2ProgramStage'
    'New-Dhis2ProgramStageDataElement'
    'New-Dhis2ProgramStageSection'
    'New-Dhis2ProgramTrackedEntityAttribute'
    'New-Dhis2ProgramRule'
    'New-Dhis2ProgramRuleAction'
    'New-Dhis2ProgramRuleVariable'
)
VariablesToExport = @()
CmdletsToExport = @()
AliasesToExport = @()
# Don't use this until https://github.com/PowerShell/PowerShell/issues/12858
# gets fixed. Use static prefixes instead.
# DefaultCommandPrefix = 'Dhis2'
PrivateData = @{
    PSData = @{
        Tags = @('DHIS2')
        LicenseUri = 'https://github.com/NeoIPC/Surveillance-Toolkit/blob/main/LICENSE'
        ProjectUri = 'https://neoipc.org/'
        Prerelease = 'alpha1'
    }
}
}
