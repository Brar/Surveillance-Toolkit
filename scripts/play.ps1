###############################################
# NeoIPC bootstrap script for a play instance #
###############################################
#
# This PowerShell script can initialize a new dummy NeoIPC installation in DHIS2
# that you can use to play with.
[CmdletBinding(DefaultParameterSetName = 'UsernamePassword')]
param (
    [Parameter(ParameterSetName = 'JSON', Position = 0, Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'Specifies the path to the JSON output file.')]
    [string] $LiteralPath,

    [Parameter(ParameterSetName = 'PersonalAccessToken', Position = 0, ValueFromPipelineByPropertyName, HelpMessage = 'DHIS2 API base URL')]
    [Parameter(ParameterSetName = 'UsernamePassword', Position = 0, ValueFromPipelineByPropertyName, HelpMessage = 'DHIS2 API base URL')]
    [Alias('ApiBase')]
    [string] $Dhis2ApiBase,

    [Parameter(ParameterSetName = 'PersonalAccessToken', Position = 1, ValueFromPipelineByPropertyName, HelpMessage = 'Your personal access token for the DHIS2 API')]
    [securestring] $PersonalAccessToken,

    [Parameter(ParameterSetName = 'UsernamePassword', Position = 1, ValueFromPipelineByPropertyName, HelpMessage = 'Your username for the DHIS2 API')]
    [string] $UserName,

    [Parameter(ParameterSetName = 'UsernamePassword', Position = 2, ValueFromPipelineByPropertyName, HelpMessage = 'Your password for the DHIS2 API')]
    [securestring] $Password,

    [Parameter(ValueFromPipelineByPropertyName, HelpMessage = 'The location of the metadata CSV files.')]
    [string] $CsvPath
)

Import-Module $PSScriptRoot/modules/Dhis2-Api -Force

if (-not (Get-Module Dhis2-Api -ErrorAction Ignore)) { Import-Module $PSScriptRoot/modules/Dhis2-Api }
if ($Dhis2ApiBase) { Set-Dhis2Defaults -ApiBase $Dhis2ApiBase }
if ($PersonalAccessToken) { Set-Dhis2Defaults -PersonalAccessToken $PersonalAccessToken }
elseif ($UserName -or $Password) { Set-Dhis2Defaults -UserName $UserName -Password $Password }

Get-Dhis2Object -Id bjDvmb4bfuf -Verbose