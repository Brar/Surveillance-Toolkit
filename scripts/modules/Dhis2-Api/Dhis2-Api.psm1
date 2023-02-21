#########################
# Dhis2-Api root module #
#########################
#
# This is the root module which contains all
# common functions and objects

# Constants for the hard-coded defaults
if (-not (Get-Variable -Name HardCodedDhis2DefaultApiBase -ErrorAction SilentlyContinue)) {
      Set-Variable -Name HardCodedDhis2DefaultApiBase -Value 'http://localhost:8080/api' -Option Constant -Description 'The hard-coded default for the Dhis2-Api API base URL'
}
if (-not (Get-Variable -Name HardCodedDhis2DefaultToken -ErrorAction SilentlyContinue)) {
      Set-Variable -Name HardCodedDhis2DefaultToken -Value $null -Option Constant -Description 'The hard-coded default for the Dhis2-Api personal access token'
}
if (-not (Get-Variable -Name HardCodedDhis2DefaultUserName -ErrorAction SilentlyContinue)) {
      Set-Variable -Name HardCodedDhis2DefaultUserName -Value 'admin' -Option Constant -Description 'The hard-coded default for the Dhis2-Api user name'
}
if (-not (Get-Variable -Name HardCodedDhis2DefaultPassword -ErrorAction SilentlyContinue)) {
      Set-Variable -Name HardCodedDhis2DefaultPassword -Value (ConvertTo-SecureString 'district' -AsPlainText) -Option Constant -Description 'The hard-coded default for the Dhis2-Api password'
}

# Private variables to hold the default values
# to be used for DHIS2 API access if the values
# are not specified as function parameters
[string]$Dhis2DefaultApiBase = $HardCodedDhis2DefaultApiBase
[securestring]$Dhis2DefaultToken = $HardCodedDhis2DefaultToken
[string]$Dhis2DefaultUserName = $HardCodedDhis2DefaultUserName
[securestring]$Dhis2DefaultPassword = $HardCodedDhis2DefaultPassword

<#
.SYNOPSIS

Resets Dhis2-Api default values.

.DESCRIPTION

Resets individual or all Dhis2-Api default values
to their hard-coded defaults.

.PARAMETER ApiBase
Use this switch to reset the Dhis2-Api default
API base URL to it's hard-coded default.

.PARAMETER PersonalAccessToken
Use this switch to reset the Dhis2-Api default
personal access token to it's hard-coded default.

.PARAMETER UserName
Use this switch to reset the Dhis2-Api default
user name to it's hard-coded default.

.PARAMETER Password
Use this switch to reset the Dhis2-Api default
user name to it''s hard-coded default.

.PARAMETER All
Use this switch to reset all Dhis2-Api default
values to their hard-coded defaults.

.INPUTS

None. You cannot pipe objects to Reset-Dhis2Defaults.

.OUTPUTS

None.

.EXAMPLE

PS> Reset-Dhis2Defaults -All

.EXAMPLE

PS> Reset-Dhis2Defaults -ApiBase -PersonalAccessToken

.EXAMPLE

PS> Reset-Dhis2Defaults -UserName -Password
#>
function Reset-Dhis2Defaults {
      param (
            [Parameter(Mandatory, ParameterSetName = 'ApiBase', HelpMessage = 'Use this switch to reset the Dhis2-Api default API base URL to it''s hard-coded default.')]
            [Parameter(ParameterSetName = 'PersonalAccessToken', HelpMessage = 'Use this switch to reset the Dhis2-Api default API base URL to it''s hard-coded default.')]
            [Parameter(ParameterSetName = 'UserName', HelpMessage = 'Use this switch to reset the Dhis2-Api default API base URL to it''s hard-coded default.')]
            [Parameter(ParameterSetName = 'Password', HelpMessage = 'Use this switch to reset the Dhis2-Api default API base URL to it''s hard-coded default.')]
            [switch] $ApiBase,

            [Parameter(Mandatory, ParameterSetName = 'PersonalAccessToken', HelpMessage = 'Use this switch to reset the Dhis2-Api default personal access token to it''s hard-coded default.')]
            [Parameter(ParameterSetName = 'ApiBase', HelpMessage = 'Use this switch to reset the Dhis2-Api default personal access token to it''s hard-coded default.')]
            [Parameter(ParameterSetName = 'UserName', HelpMessage = 'Use this switch to reset the Dhis2-Api default personal access token to it''s hard-coded default.')]
            [Parameter(ParameterSetName = 'Password', HelpMessage = 'Use this switch to reset the Dhis2-Api default personal access token to it''s hard-coded default.')]
            [switch] $PersonalAccessToken,

            [Parameter(Mandatory, ParameterSetName = 'UserName', HelpMessage = 'Use this switch to reset the Dhis2-Api default user name to it''s hard-coded default.')]
            [Parameter(ParameterSetName = 'ApiBase', HelpMessage = 'Use this switch to reset the Dhis2-Api default user name to it''s hard-coded default.')]
            [Parameter(ParameterSetName = 'PersonalAccessToken', HelpMessage = 'Use this switch to reset the Dhis2-Api default user name to it''s hard-coded default.')]
            [Parameter(ParameterSetName = 'Password', HelpMessage = 'Use this switch to reset the Dhis2-Api default user name to it''s hard-coded default.')]
            [switch] $UserName,

            [Parameter(Mandatory, ParameterSetName = 'Password', HelpMessage = 'Use this switch to reset the Dhis2-Api default user name to it''s hard-coded default.')]
            [Parameter(ParameterSetName = 'ApiBase', HelpMessage = 'Use this switch to reset the Dhis2-Api default user name to it''s hard-coded default.')]
            [Parameter(ParameterSetName = 'PersonalAccessToken', HelpMessage = 'Use this switch to reset the Dhis2-Api default user name to it''s hard-coded default.')]
            [Parameter(ParameterSetName = 'UserName', HelpMessage = 'Use this switch to reset the Dhis2-Api default user name to it''s hard-coded default.')]
            [switch] $Password,

            [Parameter(Mandatory, ParameterSetName = 'All', HelpMessage = 'Use this switch to reset all Dhis2-Api default values to their hard-coded defaults.')]
            [switch] $All
      )
      if ($All) {
            Write-Verbose "Resetting all Dhis2-Api default values to their hard-coded defaults"
            $script:Dhis2DefaultApiBase = $HardCodedDhis2DefaultApiBase
            Write-Debug "The Dhis2-Api default ApiBase is reset to '$HardCodedDhis2DefaultApiBase'"
            $script:Dhis2DefaultToken = $HardCodedDhis2DefaultToken
            Write-Debug "The Dhis2-Api default PersonalAccessToken is reset"
            $script:Dhis2DefaultUserName = $HardCodedDhis2DefaultUserName
            Write-Debug "The Dhis2-Api default UserName is reset to '$HardCodedDhis2DefaultUserName'"
            $script:Dhis2DefaultPassword = $HardCodedDhis2DefaultPassword
            Write-Debug "The Dhis2-Api default Password is reset"
      } else {
            if ($ApiBase) {
                  Write-Verbose "Resetting the Dhis2-Api default ApiBase to it's hard-coded default"
                  $script:Dhis2DefaultApiBase = $HardCodedDhis2DefaultApiBase
                  Write-Debug "The Dhis2-Api default ApiBase is reset to '$HardCodedDhis2DefaultApiBase'"
            }
            if ($PersonalAccessToken) {
                  Write-Verbose "Resetting the Dhis2-Api default PersonalAccessToken to it's hard-coded default"
                  $script:Dhis2DefaultToken = $HardCodedDhis2DefaultToken
                  Write-Debug "The Dhis2-Api default PersonalAccessToken is reset"
            }
            if ($UserName) {
                  Write-Verbose "Resetting the Dhis2-Api default UserName to it's hard-coded default"
                  $script:Dhis2DefaultUserName = $HardCodedDhis2DefaultUserName
                  Write-Debug "The Dhis2-Api default UserName is reset to '$HardCodedDhis2DefaultUserName'"
            }
            if ($Password) {
                  Write-Verbose "Resetting the Dhis2-Api default Password to it's hard-coded default"
                  $script:Dhis2DefaultPassword = $HardCodedDhis2DefaultPassword
                  Write-Debug "The Dhis2-Api default Password is reset"
            }
      }
}

<#
.SYNOPSIS

Private function to test wether an url is a valid DHIS2 API url.
#>
function Test-ApiBase {
      param (
            [Parameter(Mandatory, Position = 0)]
            [string] $url
      )
      Write-Debug "Testing whether the url '$url' is a valid DHIS2 API url."
      if (-not [uri]::IsWellFormedUriString($url, [System.UriKind]::Absolute)) {
            throw "'$url' is not a well-formed URI string."
      }
      New-Variable -Name uri
      if (-not [uri]::TryCreate($url, [System.UriKind]::Absolute, [ref]$uri)) {
            throw "Failed to parse the URI '$url'"
      }
      if (-not [string]::IsNullOrEmpty($uri.Query)) {
            throw "The DHIS2 API base must not contain a query string."
      }
      if (-not [System.Text.RegularExpressions.Regex]::IsMatch($uri.AbsolutePath, '^/api(/\d\d)?/?')) {
            throw "The path '$($uri.AbsolutePath)' is not a valid DHIS2 API path."
      }
}

<#
.SYNOPSIS

Private function to test wether a secure string is a valid DHIS2 personal access token.
#>
function Test-PersonalAccessToken {
      param (
            [Parameter(Mandatory, Position = 0)]
            [securestring] $pat
      )
      Write-Debug "Testing whether the supplied string is a valid DHIS2 personal access token."
      if ((ConvertFrom-SecureString $pat -AsPlainText) -notmatch '^d2pat_[A-Za-z0-9+/-_]+\d{10}$') {
            throw "The supplied string is not a DHIS2 personal access token."
      }
}

<#
.SYNOPSIS

Sets Dhis2-Api default values.

.DESCRIPTION

Sets Dhis2-Api default values to the supplied
values or inquires default values from the console.

.PARAMETER ApiBase
The DHIS2 API base URL to use as default.

.PARAMETER PersonalAccessToken
The DHIS2 personal access token to use as default.

.PARAMETER UserName
The DHIS2 user name to use as default.

.PARAMETER Password
The DHIS2 password to use as default.

.PARAMETER Inquire
Use this switch to inquire all Dhis2-Api default
values from the console.

.INPUTS

None. You cannot pipe objects to Set-Dhis2Defaults.

.OUTPUTS

None.

.EXAMPLE

PS> Set-Dhis2Defaults -ApiBase 'https://play.dhis2.org/2.39.1.1/api/39'

.EXAMPLE

PS> Set-Dhis2Defaults -PersonalAccessToken (Read-Host -Prompt 'Enter the personal access token' -AsSecureString)

.EXAMPLE

PS> Set-Dhis2Defaults -UserName 'dhis2user' -Password (Read-Host -Prompt 'Enter the password' -AsSecureString)

.EXAMPLE

PS> Set-Dhis2Defaults -Inquire
#>
function Set-Dhis2Defaults {
      param (
            [Parameter(Mandatory, ParameterSetName = 'ApiBase', HelpMessage = 'The DHIS2 API base URL to use as default.')]
            [Parameter(ParameterSetName = 'PersonalAccessToken', HelpMessage = 'The DHIS2 API base URL to use as default.')]
            [Parameter(ParameterSetName = 'UserName', HelpMessage = 'The DHIS2 API base URL to use as default.')]
            [Parameter(ParameterSetName = 'Password', HelpMessage = 'The DHIS2 API base URL to use as default.')]
            [string] $ApiBase,

            [Parameter(Mandatory, ParameterSetName = 'PersonalAccessToken', HelpMessage = 'The DHIS2 personal access token to use as default.')]
            [Parameter(ParameterSetName = 'ApiBase', HelpMessage = 'The DHIS2 personal access token to use as default.')]
            [Parameter(ParameterSetName = 'UserName', HelpMessage = 'The DHIS2 personal access token to use as default.')]
            [Parameter(ParameterSetName = 'Password', HelpMessage = 'The DHIS2 personal access token to use as default.')]
            [securestring] $PersonalAccessToken,

            [Parameter(Mandatory, ParameterSetName = 'UserName', HelpMessage = 'The DHIS2 user name to use as default.')]
            [Parameter(ParameterSetName = 'ApiBase', HelpMessage = 'The DHIS2 user name to use as default.')]
            [Parameter(ParameterSetName = 'PersonalAccessToken', HelpMessage = 'The DHIS2 user name to use as default.')]
            [Parameter(ParameterSetName = 'Password', HelpMessage = 'The DHIS2 user name to use as default.')]
            [string] $UserName,

            [Parameter(Mandatory, ParameterSetName = 'Password', HelpMessage = 'The DHIS2 password to use as default.')]
            [Parameter(ParameterSetName = 'ApiBase', HelpMessage = 'The DHIS2 password to use as default.')]
            [Parameter(ParameterSetName = 'PersonalAccessToken', HelpMessage = 'The DHIS2 password to use as default.')]
            [Parameter(ParameterSetName = 'UserName', HelpMessage = 'The DHIS2 password to use as default.')]
            [securestring] $Password,

            [Parameter(Mandatory, ParameterSetName = 'Inquire', HelpMessage = 'Use this switch to interactively inquire all Dhis2-Api default values via the console.')]
            [switch] $Inquire
      )

      if ($Inquire) {
            Write-Verbose "Inquiring the Dhis2-Api default ApiBase."
            $Apibase = Read-Host -Prompt "Enter the DHIS2 API base URL or press <ENTER> to keep the existing value ('$Dhis2DefaultApiBase')"
            if (-not [string]::IsNullOrWhiteSpace($Apibase)) {
                  Test-ApiBase $Apibase
                  $script:Dhis2DefaultApiBase = $Apibase
                  Write-Debug "The Dhis2-Api default ApiBase is set to '$Apibase'"
            } else {
                  Write-Debug "Keeping the existing Dhis2-Api default ApiBase ('$Dhis2DefaultApiBase')"
            }

            Write-Verbose "Inquiring the Dhis2-Api default PersonalAccessToken."
            $PersonalAccessToken = Read-Host -Prompt "Enter your personal access token or press <ENTER> to keep the existing value" -AsSecureString
            if ($PersonalAccessToken.Length -gt 0) {
                  Test-PersonalAccessToken $PersonalAccessToken
                  $script:Dhis2DefaultToken = $PersonalAccessToken
                  Write-Debug "The Dhis2-Api default PersonalAccessToken is set"
            } else {
                  Write-Debug "Keeping the existing Dhis2-Api default PersonalAccessToken"
            }

            Write-Verbose "Inquiring the Dhis2-Api default UserName."
            $UserName = Read-Host -Prompt "Enter your user name or press <ENTER> to keep the existing value ('$Dhis2DefaultUserName')"
            if (-not [string]::IsNullOrWhiteSpace($UserName)) {
                  $script:Dhis2DefaultUserName = $UserName
                  Write-Debug "The Dhis2-Api default UserName is set to '$UserName'"
            } else {
                  Write-Debug "Keeping the existing Dhis2-Api default UserName ('$Dhis2DefaultApiBase')"
            }

            Write-Verbose "Inquiring the Dhis2-Api default Password."
            $Password = Read-Host -Prompt "Enter your password or press <ENTER> to keep the existing value" -AsSecureString
            if ($Password.Length -gt 0) {
                  $script:Dhis2DefaultPassword = $Password
                  Write-Debug "The Dhis2-Api default Password is set"
            } else {
                  Write-Debug "Keeping the existing Dhis2-Api default Password"
            }
}
      else {
            if ($Apibase) {
                  Write-Verbose "Setting the Dhis2-Api default ApiBase."
                  Test-ApiBase $Apibase
                  $script:Dhis2DefaultApiBase = $Apibase
                  Write-Debug "The Dhis2-Api default ApiBase is set to '$Apibase'"
            }
            if ($PersonalAccessToken) {
                  Write-Verbose "Setting the Dhis2-Api default PersonalAccessToken."
                  Test-PersonalAccessToken $PersonalAccessToken
                  $script:Dhis2DefaultToken = $PersonalAccessToken
                  Write-Debug "The Dhis2-Api default PersonalAccessToken is set"
            }
            if ($UserName) {
                  Write-Verbose "Setting the Dhis2-Api default UserName."
                  $script:Dhis2DefaultUserName = $UserName
                  Write-Debug "The Dhis2-Api default UserName is set to '$UserName'"
            }
            if ($Password) {
                  Write-Verbose "Setting the Dhis2-Api default Password."
                  $script:Dhis2DefaultPassword = $Password
                  Write-Debug "The Dhis2-Api default Password is set"
            }
      }
}

<#
.SYNOPSIS

Gets the current Dhis2-Api default values.

.DESCRIPTION

Returns the current Dhis2-Api default values as PSCustomObject.

.INPUTS

None. You cannot pipe objects to Get-Dhis2Defaults.

.OUTPUTS

PSCustomObject. Get-Dhis2Defaults returns a PSCustomObject containing the
current Dhis2-Api default values.

.EXAMPLE

PS> Get-Dhis2Defaults

.EXAMPLE

PS> Get-Dhis2Defaults | ./play.ps1
#>
function Get-Dhis2Defaults {
      return [PSCustomObject]@{
            ApiBase = $Dhis2DefaultApiBase
            PersonalAccessToken = $Dhis2DefaultToken
            UserName = $Dhis2DefaultUserName
            Password = $Dhis2DefaultPassword
      }
}

<#
.SYNOPSIS

Private function to create a HttpClient with the base address
and the authentication header set.
#>
function New-Client {
      param (
            [Parameter(Mandatory, Position = 0)]
            [string] $Dhis2ApiBase,

            [Parameter(Mandatory, Position = 1, ParameterSetName = 'UsernamePassword')]
            [string] $UserName,

            [Parameter(Mandatory, Position = 2, ParameterSetName = 'UsernamePassword')]
            [securestring] $Password,

            [Parameter(Mandatory, Position = 1, ParameterSetName = 'PersonalAccessToken')]
            [securestring] $PersonalAccessToken
      )

      $client = [System.Net.Http.HttpClient]::new()
      $client.BaseAddress = $Dhis2ApiBase
      Write-Debug "BaseAddress is $Dhis2ApiBase"
      $client.DefaultRequestHeaders.Accept.Add([System.Net.Http.Headers.MediaTypeWithQualityHeaderValue]::new('application/json'))
      if ($personalAccessToken) {
            Write-Debug "Authenticating via personal access token"
            $client.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('ApiToken', (ConvertFrom-SecureString $PersonalAccessToken -AsPlainText));
      }
      else {
            Write-Debug "Authenticating via username and password"
            $client.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Basic', [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$($UserName):$(ConvertFrom-SecureString $Password -AsPlainText)")));
      }
      return $client
}

<#
.SYNOPSIS

Gets an object from the DHIS2 API.

.DESCRIPTION

Gets a DHIS2 API object from a DHIS2 server.

.PARAMETER RelativeApiEndpoint
The relative endpoint in the DHIS2 API.

.PARAMETER QueryParameterHash
The query parameters as HashTable.

.PARAMETER QueryParametersArray
The query parameters as array of ValueTuple<string,string>
(e.g., if you want to use multiple filters).

.PARAMETER UserName
The DHIS2 user name to use for this query.

.PARAMETER Password
The DHIS2 password to use for this query.

.PARAMETER PersonalAccessToken
The DHIS2 personal access token to use for this query.

.PARAMETER Dhis2ApiBase
The DHIS2 API base URL to use for this query.

.PARAMETER Unwrap
Unwrap the first property of the returned object.

.INPUTS

None. You cannot pipe objects to Set-Dhis2Defaults.

.OUTPUTS

System.Management.Automation.PSObject.

.EXAMPLE

PS> Get-Dhis2Object dataElements @{paging='false';fields='*';filter='code:$like:NEOIPC'}

.EXAMPLE

PS> Get-Dhis2Object categoryCombos/bjDvmb4bfuf

.EXAMPLE

PS> Get-Dhis2Object @([System.ValueTuple]::Create('paging','false'),[System.ValueTuple]::Create('fields','*'),[System.ValueTuple]::Create('filter','name:$ilike:NeoIPC'),[System.ValueTuple]::Create('filter','name:!ilike:BSI'))

.LINK

https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/introduction.html
#>
function Get-Dhis2Object {
      [CmdletBinding(DefaultParameterSetName = 'UsernamePasswordHash')]
      param (
            [Parameter(Position = 0, Mandatory, HelpMessage = 'The relative endpoint in the DHIS2 API')]
            [ArgumentCompletions('aggregateDataExchanges', 'analyticsTableHooks', 'apiToken', 'attributes', 'categories', 'categoryCombos', `
                        'categoryOptionCombos', 'categoryOptionGroups', 'categoryOptionGroupSets', 'categoryOptions', 'constants', 'dashboardItems', `
                        'dashboards', 'dataApprovalLevels', 'dataApprovalWorkflows', 'dataElementGroups', 'dataElementGroupSets', 'dataElementOperands', `
                        'dataElements', 'dataEntryForms', 'dataSetNotificationTemplates', 'dataSets', 'dataStore', 'documents', 'eventCharts', 'eventFilters', `
                        'eventReports', 'eventVisualizations', 'externalFileResources', 'externalMapLayers', 'fileResources', 'icons', 'indicatorGroups', `
                        'indicatorGroupSets', 'indicators', 'indicatorTypes', 'interpretations', 'jobConfigurations', 'legendSets', 'maps', 'mapViews', `
                        'messageConversations', 'metadata/proposals', 'metadata/version', 'minMaxDataElements', 'oAuth2Clients', 'optionGroups', `
                        'optionGroupSets', 'options', 'optionSets', 'organisationUnitGroups', 'organisationUnitGroupSets', 'organisationUnitLevels', `
                        'organisationUnits', 'predictorGroups', 'predictors', 'programDataElements', 'programIndicatorGroups', 'programIndicators', `
                        'programNotificationTemplates', 'programRuleActions', 'programRules', 'programRuleVariables', 'programs', 'programSections', `
                        'programStages', 'programStageSections', 'programTrackedEntityAttributeGroups', 'pushAnalysis', 'relationships', 'relationshipTypes', `
                        'reports', 'schemas', 'schemas/aggregateDataExchange', 'schemas/analyticsTableHook', 'schemas/apiToken', 'schemas/attribute', `
                        'schemas/category', 'schemas/categoryCombo', 'schemas/categoryOption', 'schemas/categoryOptionCombo', 'schemas/categoryOptionGroup', `
                        'schemas/categoryOptionGroupSet', 'schemas/constant', 'schemas/dashboard', 'schemas/dashboardItem', 'schemas/dataApprovalLevel', `
                        'schemas/dataApprovalWorkflow', 'schemas/dataElement', 'schemas/dataElementGroup', 'schemas/dataElementGroupSet', 'schemas/dataElementOperand', `
                        'schemas/dataEntryForm', 'schemas/dataSet', 'schemas/dataSetNotificationTemplate', 'schemas/dataStore', 'schemas/document', `
                        'schemas/eventChart', 'schemas/eventFilter', 'schemas/eventReport', 'schemas/eventVisualization', 'schemas/externalFileResource', `
                        'schemas/externalMapLayer', 'schemas/fileResource', 'schemas/icon', 'schemas/indicator', 'schemas/indicatorGroup', 'schemas/indicatorGroupSet', `
                        'schemas/indicatorType', 'schemas/interpretation', 'schemas/jobConfiguration', 'schemas/legendSet', 'schemas/map', 'schemas/mapView', `
                        'schemas/messageConversation', 'schemas/metadataVersion', 'schemas/minMaxDataElement', 'schemas/oAuth2Client', 'schemas/option', `
                        'schemas/optionGroup', 'schemas/optionGroupSet', 'schemas/optionSet', 'schemas/organisationUnit', 'schemas/organisationUnitGroup', `
                        'schemas/organisationUnitGroupSet', 'schemas/organisationUnitLevel', 'schemas/predictor', 'schemas/predictorGroup', 'schemas/program', `
                        'schemas/programDataElement', 'schemas/programIndicator', 'schemas/programIndicatorGroup', 'schemas/programNotificationTemplate', `
                        'schemas/programRule', 'schemas/programRuleAction', 'schemas/programRuleVariable', 'schemas/programSection', 'schemas/programStage', `
                        'schemas/programStageSection', 'schemas/programTrackedEntityAttributeGroup', 'schemas/proposal', 'schemas/pushAnalysis', 'schemas/relationship', `
                        'schemas/relationshipType', 'schemas/report', 'schemas/section', 'schemas/smsCommand', 'schemas/sqlView', 'schemas/trackedEntityAttribute', `
                        'schemas/trackedEntityInstance', 'schemas/trackedEntityInstanceFilter', 'schemas/trackedEntityType', 'schemas/user', 'schemas/userGroup', `
                        'schemas/userRole', 'schemas/validationNotificationTemplate', 'schemas/validationResult', 'schemas/validationRule', 'schemas/validationRuleGroup', `
                        'schemas/visualization', 'sections', 'smsCommands', 'sqlViews', 'trackedEntityAttributes', 'trackedEntityInstanceFilters', `
                        'trackedEntityInstances', 'trackedEntityTypes', 'userGroups', 'userRoles', 'users', 'validationNotificationTemplates', 'validationResults', `
                        'validationRuleGroups', 'validationRules', 'visualizations', `
                        'me', 'me/authorities', 'me/authorities/ALL', 'system/id', 'system/info')]
            [string] $RelativeApiEndpoint,

            [Parameter(Position = 1, ParameterSetName = 'PersonalAccessTokenHash', HelpMessage = 'The query parameters as HashTable')]
            [Parameter(Position = 1, ParameterSetName = 'UsernamePasswordHash', HelpMessage = 'Enter the query parameters as HashTable')]
            [ArgumentCompletions('@{paging=''false'';fields=''*''}', '@{paging=''false'';fields=''*'';filter=''code:eq:TODO''}')]
            [hashtable] $QueryParameterHash,

            [Parameter(Position = 1, ParameterSetName = 'PersonalAccessTokenArray',
                  HelpMessage = 'Enter the query parameters as array of ValueTuple<string,string> (e.g., if you want to use multiple filters)')]
            [Parameter(Position = 1, ParameterSetName = 'UsernamePasswordArray',
                  HelpMessage = 'Enter the query parameters as array of ValueTuple<string,string> (e.g., if you want to use multiple filters).')]
            [ArgumentCompletions('@([System.ValueTuple]::Create(''paging'',''false''),[System.ValueTuple]::Create(''fields'',''*''),[System.ValueTuple]::Create(''filter'',''name:$ilike:NeoIPC''),[System.ValueTuple]::Create(''filter'',''name:!ilike:BSI''))')]
            [System.ValueTuple[string, string][]] $QueryParametersArray,

            [Parameter(ParameterSetName = 'UsernamePasswordHash', HelpMessage = 'Enter your username')]
            [Parameter(ParameterSetName = 'UsernamePasswordArray', HelpMessage = 'Enter your username')]
            [string] $UserName = $Dhis2DefaultUserName,

            [Parameter(ParameterSetName = 'UsernamePasswordHash', HelpMessage = 'Enter your password')]
            [Parameter(ParameterSetName = 'UsernamePasswordArray', HelpMessage = 'Enter your password')]
            [securestring] $Password = $Dhis2DefaultPassword,

            [Parameter(Mandatory, ParameterSetName = 'PersonalAccessTokenHash', HelpMessage = 'Enter your personal access token for the DHIS2 API')]
            [Parameter(Mandatory, ParameterSetName = 'PersonalAccessTokenArray', HelpMessage = 'Enter your personal access token for the DHIS2 API')]
            [securestring] $PersonalAccessToken = $Dhis2DefaultToken,

            [Parameter(HelpMessage = 'Enter the DHIS2 API base URL')]
            [ArgumentCompletions('http://localhost/api', 'http://localhost:8080/api/39', 'https://play.dhis2.org/2.39.1.1/api')]
            [string] $Dhis2ApiBase = $Dhis2DefaultApiBase,

            [Parameter(HelpMessage = 'Set this switch to unwrap the list returned from DHIS2')]
            [switch] $Unwrap)
      begin {
            if ($PersonalAccessToken) {
                  $client = New-Client $Dhis2ApiBase $PersonalAccessToken
            }
            else {
                  $client = New-Client $Dhis2ApiBase $UserName $Password
            }
      }
      process {
            try {
                  Write-Verbose "Getting $RelativeApiEndpoint"
                  $requestUri = $RelativeApiEndpoint
                  if ($QueryParametersArray.Count -gt 0) {
                        $sb = [System.Text.StringBuilder]::new('?')
                        foreach ($tuple in $QueryParametersArray) {
                              $sb.Append([System.Web.HttpUtility]::UrlEncode($tuple.Item1)).Append('=').Append([System.Web.HttpUtility]::UrlEncode($tuple.Item2)).Append('&') > $null
                        }
                        $sb.Length = $sb.Length - 1
                        $requestUri += $sb.ToString()
                  }
                  elseif ($QueryParameterHash.Count -gt 0) {
                        $sb = [System.Text.StringBuilder]::new('?')
                        foreach ($key in $QueryParameterHash.Keys) {
                              $value = $QueryParameterHash[$key]
                              if ($value -isnot [string]) {
                                    Write-Warning "The value of the QueryParameterHash parameter is not a string. This is unsupported and may lead to unexpected results."
                              }
                              $sb.Append([System.Web.HttpUtility]::UrlEncode($key)).Append('=').Append([System.Web.HttpUtility]::UrlEncode($value)).Append('&') > $null
                        }
                        $sb.Length = $sb.Length - 1
                        $requestUri += $sb.ToString()
                  }
                  Write-Debug "Query: $requestUri"
                  $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $requestUri)
                  $response = $client.Send($request)
                  $ms = [System.IO.MemoryStream]::new()
                  $response.Content.CopyTo($ms, $null, [System.Threading.CancellationToken]::None) > $null
                  $contentString = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
                  Write-Debug "Response content: $contentString"
                  if (-not $response.IsSuccessStatusCode) {
                        if ($contentString) {
                              throw $contentString | ConvertFrom-Json
                        }
                        elseif ($response.ReasonPhrase) {
                              throw "Error: Status: $($response.StatusCode), Reason: $($response.ReasonPhrase)"
                        }
                        else {
                              throw "Error: Status: $($response.StatusCode)"
                        }
                  }
                  else {
                        $contentObject = $contentString | ConvertFrom-Json
                        if ($Unwrap) {
                              return $contentObject.PSObject.Properties | Select-Object -First 1 | ForEach-Object { $_.Value }
                        }
                        else {
                              return $contentObject
                        }
                  }
            }
            finally {
                  if ($request) { $request.Dispose() }
                  if ($response) { $response.Dispose() }
            }
      }
      clean { if ($client) { $client.Dispose() } }
}

# The id generator class
if (-not ("Dhis2Api.IdGenerator" -as [type])) {
      Add-Type -Language CSharp -TypeDefinition @"
            namespace Dhis2Api
            {
                  /// <summary>
                  /// A class that can be used to generate random unique ids that satisfy the
                  /// criteria of DHIS2 (11 characters long, alphanumeric characters only,
                  /// tart with an alphabetic character)
                  /// </summary>
                  /// <remarks>
                  /// The uniqueness of the generated ids is guaranteed per object instance.
                  /// When using multiple instances, there is a (very theoretical) risk that
                  /// the same id is generated multiple times
                  /// </remarks>
                  public class IdGenerator
                  {
                        const string Values = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
                        const int FirstLength = 52;
                        const int RestLength = 62;
                        readonly System.Collections.Generic.HashSet<string> _existing = new();

                        /// <summary>
                        /// Generates multiple ids
                        /// </summary>
                        /// <param name="count">The number of ids to generate</param>
                        /// <returns>The generated ids as array of <see cref="string"/></returns>
                        public string[] GenerateIds(int count)
                        {
                              var ids = new string[count];
                              for (var i = 0; i < count; i++)
                              ids[i] = GenerateId();
                              return ids;
                        }

                        /// <summary>
                        /// Generates a single id
                        /// </summary>
                        /// <returns>The generated id as <see cref="string"/></returns>
                        public string GenerateId()
                        {
                              string id;
                              do
                              {
                              System.Span<char> buffer = stackalloc char[11];
                              buffer[0] = Values[System.Security.Cryptography.RandomNumberGenerator.GetInt32(FirstLength)];
                              for (var i = buffer.Length - 1; i >= 1; i--)
                                    buffer[i] = Values[System.Security.Cryptography.RandomNumberGenerator.GetInt32(RestLength)];
                              id = new(buffer);
                              } while (_existing.Contains(id));

                              _existing.Add(id);
                              return id;
                        }
                  }
            }
"@
}

Export-ModuleMember -Function @(
      'Reset-Dhis2Defaults'
      'Set-Dhis2Defaults'
      'Get-Dhis2Defaults'
      # 'Get-Dhis2Object'
      # 'Add-Dhis2Object'
      # 'Set-Dhis2Object'
      # 'Update-Dhis2Object'
      # 'Remove-Dhis2Object'
      # 'ConvertTo-Dhis2DataElement'
      # 'ConvertTo-Dhis2Option'
      # 'ConvertTo-Dhis2Program'
      # 'ConvertTo-Dhis2ProgramStage'
      # 'ConvertTo-Dhis2ProgramStageDataElement'
      # 'ConvertTo-Dhis2ProgramStageSection'
      # 'Reset-Dhis2Defaults'
      # 'New-Dhis2DataElement'
      # 'New-Dhis2Program'
      # 'New-Dhis2ProgramStage'
      # 'New-Dhis2ProgramStageDataElement'
      # 'New-Dhis2ProgramStageSection'
      # 'New-Dhis2ProgramTrackedEntityAttribute'
      # 'New-Dhis2ProgramRule'
      # 'New-Dhis2ProgramRuleAction'
      # 'New-Dhis2ProgramRuleVariable'
      # 'New-Dhis2Option'
      # 'New-Dhis2OptionSet'
  )
