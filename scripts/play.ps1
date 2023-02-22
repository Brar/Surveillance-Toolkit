###############################################
# NeoIPC bootstrap script for a play instance #
###############################################
#
# This PowerShell script can initialize a new dummy NeoIPC installation in DHIS2
# that you can use to play with.
[CmdletBinding(DefaultParameterSetName = 'PersonalAccessToken')]
param (
    [Parameter(Position = 1, ValueFromPipelineByPropertyName, HelpMessage = 'DHIS2 API base URL')]
    [Alias('ApiBase')]
    [string] $Dhis2ApiBase,

    [Parameter(Position = 2, ParameterSetName = 'PersonalAccessToken', ValueFromPipelineByPropertyName, HelpMessage = 'Your personal access token for the DHIS2 API')]
    [securestring] $PersonalAccessToken,

    [Parameter(Position = 2, ParameterSetName = 'UsernamePassword', ValueFromPipelineByPropertyName, HelpMessage = 'Your username for the DHIS2 API')]
    [string] $UserName,

    [Parameter(Position = 3, ParameterSetName = 'UsernamePassword', ValueFromPipelineByPropertyName, HelpMessage = 'Your password for the DHIS2 API')]
    [securestring] $Password,

    [Parameter(ValueFromPipelineByPropertyName, HelpMessage = 'The location of the metadata CSV files.')]
    [string] $MetadataPath
)

Import-Module $PSScriptRoot/modules/Dhis2-Api -Force

if (-not (Get-Module Dhis2-Api)) { Import-Module $PSScriptRoot/modules/Dhis2-Api }
if ($Dhis2ApiBase) { Set-Dhis2Defaults -ApiBase $Dhis2ApiBase }
if ($PersonalAccessToken) { Set-Dhis2Defaults -PersonalAccessToken $PersonalAccessToken }
elseif ($UserName -or $Password) { Set-Dhis2Defaults -UserName $UserName -Password $Password }

Get-Dhis2Object categoryCombos/bjDvmb4bfuf -Dhis2ApiBase 'https://neoipc.charite.de/api' -PersonalAccessToken (Read-Host -AsSecureString)
