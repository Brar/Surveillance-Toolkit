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

class QueryStringBuilder {
      [System.Text.StringBuilder] hidden $buffer = [System.Text.StringBuilder]::new('?')

      [void]Append([string]$name, [string]$value) {
            if ([string]::IsNullOrWhiteSpace($name)) { throw "Invalid query string parameter name." }
            if ($value) {
                  $this.buffer.Append([System.Web.HttpUtility]::UrlEncode($name)).Append('=').Append([System.Web.HttpUtility]::UrlEncode($value)).Append('&') > $null
            }
      }

      [void]Append([string]$name, [string[]]$values) {
            if ([string]::IsNullOrWhiteSpace($name)) { throw "Invalid query string parameter name." }
            if ($values) {
                  foreach ($value in $values) {
                        $this.buffer.Append([System.Web.HttpUtility]::UrlEncode($name)).Append('=').Append([System.Web.HttpUtility]::UrlEncode($value)).Append('&') > $null
                  }
            }
      }

      [string]BuildAndReset() {
            if ($this.buffer.Length -eq 1) {
                  return ''
            }
            else {
                  $this.buffer.Length--
                  $str = $this.buffer.ToString()
                  $this.buffer.Length = 1
                  return $str
            }
      }
}

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
      if (-not $Dhis2ApiBase.EndsWith('/')) {
            $Dhis2ApiBase += '/'
      }
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

.PARAMETER Id
The DHIS2 object id as string.

.PARAMETER Fields
The fields to return, including transformers.
See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/metadata.html#webapi_metadata_field_filter

.PARAMETER Filter
The object filters.
See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/metadata.html#webapi_metadata_object_filter

.PARAMETER Order
Order the output using a specified order, only properties that are both
persisted and simple (no collections, idObjects etc) are supported.
iasc and idesc are case insensitive sorting.

.PARAMETER Paging
Set this switch to return lists of elements in pages.

.PARAMETER Page
Defines which page number to return.

.PARAMETER PageSize
Defines the number of elements to return for each page.

.PARAMETER Translate
Translate display* properties in metadata output (displayName, displayShortName,
displayDescription, and displayFormName for data elements and tracked entity attributes).

.PARAMETER Locale
Translate metadata output using a specified locale (requires translate=true).

.PARAMETER RootJunction
Switch the root logical operator from AND to OR

.PARAMETER IndexableOnly
For tracked entity attributes, there is a special filter in addition to the previous
mentioned filtering capabilities. Some of the tracked entity attributes are candidates
for creating a trigram index for better lookup performance. Using the indexableOnly
parameter set to true, the results can be filtered to include only the attributes that
are trigram indexable.

.PARAMETER UserName
The user name to use for authentication on the DHIS2 server.

.PARAMETER Password
The password to use for authentication on the DHIS2 server.

.PARAMETER PersonalAccessToken
The personal access token to use for authentication on the DHIS2 server.

.PARAMETER Dhis2ApiBase
The DHIS2 API base URL.

.PARAMETER ExpandFirstProperty
Expand the first property of the object returned from DHIS2.

.INPUTS

None. You cannot pipe objects to Set-Dhis2Defaults.

.OUTPUTS

System.Management.Automation.PSObject.

.EXAMPLE

PS> Get-Dhis2Object dataElements '*' 'code:$like:NEOIPC'

.EXAMPLE

PS> Get-Dhis2Object -RelativeApiEndpoint dataElements -Fields '*' -Filter 'code:$like:NEOIPC' -Order 'shortName:desc'

.EXAMPLE

PS> Get-Dhis2Object categoryCombos/bjDvmb4bfuf

.EXAMPLE

PS> Get-Dhis2Object -Id bjDvmb4bfuf

.EXAMPLE

PS> Get-Dhis2Object categoryCombos bjDvmb4bfuf

.LINK

https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/introduction.html
#>
function Get-Dhis2Object {
      [CmdletBinding(DefaultParameterSetName = 'UsernamePasswordQuery')]
      param (
            [Parameter(ParameterSetName = 'UsernamePasswordId', Position = 0, HelpMessage = 'The relative endpoint in the DHIS2 API')]
            [Parameter(ParameterSetName = 'PersonalAccessTokenId', Position = 0, HelpMessage = 'The relative endpoint in the DHIS2 API')]
            [Parameter(ParameterSetName = 'UsernamePasswordQuery', Position = 0, Mandatory, HelpMessage = 'The relative endpoint in the DHIS2 API')]
            [Parameter(ParameterSetName = 'PersonalAccessTokenQuery', Position = 0, Mandatory, HelpMessage = 'The relative endpoint in the DHIS2 API')]
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

            [Parameter(ParameterSetName = 'UsernamePasswordId', Position = 1, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'The DHIS2 object id as string')]
            [Parameter(ParameterSetName = 'PersonalAccessTokenId', Position = 1, Mandatory, HelpMessage = 'The DHIS2 object id as string')]
            [ValidateScript({ [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') },
            ErrorMessage = "The value '{0}' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic "+
                  'character (A-Za-z). See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers')]
            [string] $Id,

            [Parameter(ParameterSetName = 'UsernamePasswordQuery', Position = 1, HelpMessage = 'The fields to return, including transformers. '+
                  'See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/metadata.html#webapi_metadata_field_filter')]
            [Parameter(ParameterSetName = 'PersonalAccessTokenQuery', Position = 1, HelpMessage = 'The fields to return, including transformers. '+
                  'See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/metadata.html#webapi_metadata_field_filter')]
            [string[]] $Fields,

            [Parameter(ParameterSetName = 'UsernamePasswordQuery', Position = 2, HelpMessage = 'The object filters. '+
                  'See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/metadata.html#webapi_metadata_object_filter')]
            [Parameter(ParameterSetName = 'PersonalAccessTokenQuery', Position = 2, HelpMessage = 'The object filters. '+
                  'See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/metadata.html#webapi_metadata_object_filter')]
            [string[]] $Filter,

            [Parameter(ParameterSetName = 'UsernamePasswordQuery', HelpMessage = 'Order the output using a specified order, only properties that are both persisted and simple '+
                  '(no collections, idObjects etc) are supported. iasc and idesc are case insensitive sorting.')]
            [Parameter(ParameterSetName = 'PersonalAccessTokenQuery', HelpMessage = 'Order the output using a specified order, only properties that are both persisted and simple '+
                  '(no collections, idObjects etc) are supported. iasc and idesc are case insensitive sorting.')]
            [string[]] $Order,

            [Parameter(ParameterSetName = 'UsernamePasswordQuery', HelpMessage = 'Return lists of elements in pages.')]
            [Parameter(ParameterSetName = 'PersonalAccessTokenQuery', HelpMessage = 'Return lists of elements in pages.')]
            [switch] $Paging,

            [Parameter(ParameterSetName = 'UsernamePasswordQuery', HelpMessage = 'Sets the page number to return.')]
            [Parameter(ParameterSetName = 'PersonalAccessTokenQuery', HelpMessage = 'Sets which the number to return.')]
            [uint] $Page,

            [Parameter(ParameterSetName = 'UsernamePasswordQuery', HelpMessage = 'Sets the number of elements to return for each page.')]
            [Parameter(ParameterSetName = 'PersonalAccessTokenQuery', HelpMessage = 'Sets the number of elements to return for each page.')]
            [uint] $PageSize,

            [Parameter(ParameterSetName = 'UsernamePasswordQuery', HelpMessage = 'Translate display* properties in metadata output (displayName, displayShortName, '+
                  'displayDescription, and displayFormName for data elements and tracked entity attributes).')]
            [Parameter(ParameterSetName = 'PersonalAccessTokenQuery', HelpMessage = 'Translate display* properties in metadata output (displayName, displayShortName, '+
                  'displayDescription, and displayFormName for data elements and tracked entity attributes).')]
            [switch] $Translate,

            [Parameter(ParameterSetName = 'UsernamePasswordQuery', HelpMessage = 'Translate metadata output using a specified locale (requires translate=true).')]
            [Parameter(ParameterSetName = 'PersonalAccessTokenQuery', HelpMessage = 'Translate metadata output using a specified locale (requires translate=true).')]
            [string] $Locale,

            [Parameter(ParameterSetName = 'UsernamePasswordQuery', HelpMessage = 'Switch the root logical operator from AND to OR')]
            [Parameter(ParameterSetName = 'PersonalAccessTokenQuery', HelpMessage = 'Switch the root logical operator from AND to OR')]
            [ValidateSet('OR')]
            [string] $RootJunction,

            [Parameter(ParameterSetName = 'UsernamePasswordQuery', HelpMessage = 'Include only the attributes that are trigram indexable.')]
            [Parameter(ParameterSetName = 'PersonalAccessTokenQuery', HelpMessage = 'Include only the attributes that are trigram indexable.')]
            [switch] $IndexableOnly,

            [Parameter(ParameterSetName = 'UsernamePasswordId', HelpMessage = 'The user name to use for authentication on the DHIS2 server.')]
            [Parameter(ParameterSetName = 'UsernamePasswordQuery', HelpMessage = 'The user name to use for authentication on the DHIS2 server.')]
            [string] $UserName = $Dhis2DefaultUserName,

            [Parameter(ParameterSetName = 'UsernamePasswordId', HelpMessage = 'The password to use for authentication on the DHIS2 server.')]
            [Parameter(ParameterSetName = 'UsernamePasswordQuery', HelpMessage = 'The password to use for authentication on the DHIS2 server.')]
            [securestring] $Password = $Dhis2DefaultPassword,

            [Parameter(Mandatory, ParameterSetName = 'PersonalAccessTokenId', HelpMessage = 'The personal access token to use for authentication on the DHIS2 server.')]
            [Parameter(Mandatory, ParameterSetName = 'PersonalAccessTokenQuery', HelpMessage = 'The personal access token to use for authentication on the DHIS2 server.')]
            [securestring] $PersonalAccessToken = $Dhis2DefaultToken,

            [Parameter(HelpMessage = 'The DHIS2 API base URL.')]
            [ArgumentCompletions('''http://localhost/api''', '''http://localhost:8080/api/39''', '''https://play.dhis2.org/2.39.1.1/api''')]
            [string] $Dhis2ApiBase = $Dhis2DefaultApiBase,

            [Parameter(HelpMessage = 'Expand the first property of the object returned from DHIS2.')]
            [switch] $ExpandFirstProperty)
      begin {
            if ($PersonalAccessToken) {
                  $client = New-Client $Dhis2ApiBase $PersonalAccessToken
            }
            else {
                  $client = New-Client $Dhis2ApiBase $UserName $Password
            }
            $queryStringBuilder = [QueryStringBuilder]::new()
            $contentBuffer = [System.IO.MemoryStream]::new()
      }
      process {
            try {
                  if ($Id) {
                        if ($RelativeApiEndpoint) {
                              $requestUri = "$RelativeApiEndpoint/$Id"
                              Write-Debug "Path: $requestUri"
                        }
                        else {
                              $requestUri = "identifiableObjects/$Id"
                              Write-Debug "Path: $requestUri"
                        }
                  }
                  else {
                        $queryStringBuilder.Append('fields', ($Fields | Join-String -Separator ','))
                        $queryStringBuilder.Append('filter', $Filter)
                        $queryStringBuilder.Append('order', $Order)
                        $queryStringBuilder.Append('paging', $Paging.ToString().ToLowerInvariant())
                        if ($Page) { $queryStringBuilder.Append('page', $Page.ToString()) }
                        if ($PageSize) { $queryStringBuilder.Append('pageSize', $PageSize.ToString()) }
                        $queryStringBuilder.Append('translate', $Translate.ToString().ToLowerInvariant())
                        $queryStringBuilder.Append('locale', $Locale)
                        $queryStringBuilder.Append('rootJunction', $RootJunction)
                        if ($IndexableOnly) {
                              if ($RelativeApiEndpoint -cnotmatch '^/?trackedEntityAttributtes') {
                                    throw "The -IndexableOnly switch can only be used for trackedEntityAttributtes."
                              }
                              $queryStringBuilder.Append('indexableOnly', $IndexableOnly.ToString().ToLowerInvariant())
                        }

                        $queryString = $queryStringBuilder.BuildAndReset()
                        Write-Debug "Path: $RelativeApiEndpoint"
                        Write-Debug "Query string: '$queryString'"
                        $requestUri = $RelativeApiEndpoint + $queryString
                  }
                  Write-Verbose "GET $($client.BaseAddress)$requestUri"
                  $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $requestUri)
                  $response = $client.Send($request)
                  $contentBuffer.SetLength(0)
                  $response.Content.CopyTo($contentBuffer, $null, [System.Threading.CancellationToken]::None) > $null
                  $contentString = [System.Text.Encoding]::UTF8.GetString($contentBuffer.GetBuffer(), 0, $contentBuffer.Length)
                  Write-Debug "Response content: $contentString"
                  if (-not $response.IsSuccessStatusCode) {
                        if ($contentString) {
                              try {
                                    $contentObject = $contentString | ConvertFrom-Json
                              }
                              catch {
                                    throw $contentString
                              }
                              throw $contentObject
                        }
                        elseif ($response.ReasonPhrase) {
                              throw "Status: $($response.StatusCode), Reason: $($response.ReasonPhrase)"
                        }
                        else {
                              throw "Status: $($response.StatusCode)"
                        }
                  }
                  else {
                        try {
                              $contentObject = $contentString | ConvertFrom-Json
                              if ($ExpandFirstProperty) {
                                    return $contentObject.PSObject.Properties | Select-Object -First 1 | ForEach-Object { $_.Value }
                              }
                              else {
                                    return $contentObject
                              }
                        }
                        catch {
                              throw $contentString
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

<#
.SYNOPSIS

Add an object to a DHIS2 a server.

.DESCRIPTION

Add a DHIS2 object to a server via the DHIS2 API.

.PARAMETER RelativeApiEndpoint
The relative endpoint in the DHIS2 API.

.PARAMETER PayloadString
The JSON payload as string.

.PARAMETER PayloadObject
The payload as object.

.PARAMETER PreheatCache
Turn cache-map preheating on/off.
This is on by default, turning this off will make initial load time
 for importer much shorter (but will make the import itself slower).
 This is mostly used for cases where you have a small XML/JSON file
 you want to import, and don't want to wait for cache-map preheating.

.PARAMETER ImportStrategy
Import strategy to use.

.PARAMETER MergeMode
Strategy for merging of objects when doing updates.
REPLACE will just overwrite the property with the new value provided,
MERGE will only set the property if it is not null (only if the
property was provided).

.PARAMETER ReturnId
Return the id of the created object instead of the whole response.

.PARAMETER UserName
The username to use for authentication on the DHIS2 server.

.PARAMETER Password
The password to use for authentication on the DHIS2 server.

.PARAMETER PersonalAccessToken
The personal access token to use for authentication on the DHIS2 server.

.PARAMETER Dhis2ApiBase
The DHIS2 API base URL.

.INPUTS

System.String or System.Object.

.OUTPUTS

System.Management.Automation.PSObject.

.LINK

https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-239/metadata.html#webapi_metadata_crud
#>
function Add-Dhis2Object {
      [CmdletBinding(DefaultParameterSetName = 'UsernamePasswordObject')]
      param (
            [Parameter(Position = 0, Mandatory, HelpMessage = 'The relative endpoint in the DHIS2 API')]
            [ArgumentCompletions('aggregateDataExchanges','analyticsTableHooks','apiToken','attributes','categories','categoryCombos',`
            'categoryOptionCombos','categoryOptionGroups','categoryOptionGroupSets','categoryOptions','constants','dashboardItems',`
            'dashboards','dataApprovalLevels','dataApprovalWorkflows','dataElementGroups','dataElementGroupSets','dataElementOperands',`
            'dataElements','dataEntryForms','dataSetNotificationTemplates','dataSets','dataStore','documents','eventCharts',`
            'eventFilters','eventReports','eventVisualizations','externalFileResources','externalMapLayers','fileResources','icons',`
            'indicatorGroups','indicatorGroupSets','indicators','indicatorTypes','interpretations','jobConfigurations','legendSets',`
            'maps','mapViews','messageConversations','metadata/proposals','metadata/version','minMaxDataElements','oAuth2Clients',`
            'optionGroups','optionGroupSets','options','optionSets','organisationUnitGroups','organisationUnitGroupSets',`
            'organisationUnitLevels','organisationUnits','predictorGroups','predictors','programDataElements','programIndicatorGroups',`
            'programIndicators','programNotificationTemplates','programRuleActions','programRules','programRuleVariables','programs',`
            'programSections','programStages','programStageSections','programTrackedEntityAttributeGroups','pushAnalysis','relationships',`
            'relationshipTypes','reports','sections','smsCommands','sqlViews','trackedEntityAttributes','trackedEntityInstanceFilters',`
            'trackedEntityInstances','trackedEntityTypes','userGroups','userRoles','users','validationNotificationTemplates',`
            'validationResults','validationRuleGroups','validationRules','visualizations')]
            [string] $RelativeApiEndpoint,

            [Parameter(Position = 1, Mandatory, ParameterSetName = 'PersonalAccessTokenString', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'The JSON payload as string.')]
            [Parameter(Position = 1, Mandatory, ParameterSetName = 'UsernamePasswordString', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'The JSON payload as string.')]
            [string] $PayloadString,

            [Parameter(Position = 1, Mandatory, ParameterSetName = 'PersonalAccessTokenObject', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'The payload as object.')]
            [Parameter(Position = 1, Mandatory, ParameterSetName = 'UsernamePasswordObject', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'The payload as object.')]
            [object] $PayloadObject,

            [Parameter(HelpMessage = 'Turn cache-map preheating on/off.')]
            [System.Nullable[bool]] $PreheatCache,

            [Parameter(HelpMessage = 'Return the id of the created object instead of the whole response.')]
            [switch] $ReturnId,

            [Parameter(HelpMessage = 'Import strategy to use.')]
            [ValidateSet('CREATE_AND_UPDATE','CREATE','UPDATE','DELETE')]
            [string] $ImportStrategy,

            [Parameter(HelpMessage = 'Import strategy to use.')]
            [ValidateSet('REPLACE','MERGE')]
            [string] $MergeMode,

            [Parameter(ParameterSetName = 'UsernamePasswordObject', HelpMessage = 'The username to use for authentication on the DHIS2 server.')]
            [Parameter(ParameterSetName = 'UsernamePasswordString', HelpMessage = 'The username to use for authentication on the DHIS2 server.')]
            [string] $UserName = $Dhis2DefaultUserName,

            [Parameter(ParameterSetName = 'UsernamePasswordObject', HelpMessage = 'The password to use for authentication on the DHIS2 server.')]
            [Parameter(ParameterSetName = 'UsernamePasswordString', HelpMessage = 'The password to use for authentication on the DHIS2 server.')]
            [securestring] $Password = $Dhis2DefaultPassword,

            [Parameter(Mandatory, ParameterSetName = 'PersonalAccessTokenObject', HelpMessage = 'The personal access token to use for authentication on the DHIS2 server.')]
            [Parameter(Mandatory, ParameterSetName = 'PersonalAccessTokenString', HelpMessage = 'The personal access token to use for authentication on the DHIS2 server.')]
            [securestring] $PersonalAccessToken = $Dhis2DefaultToken,

            [Parameter(HelpMessage = 'The DHIS2 API base URL')]
            [ArgumentCompletions('''http://localhost/api''', '''http://localhost:8080/api/39''', '''https://play.dhis2.org/2.39.1.1/api''')]
            [string] $Dhis2ApiBase = $Dhis2DefaultApiBase)
      begin {
            if ($PersonalAccessToken) {
                  $client = New-Client $Dhis2ApiBase $PersonalAccessToken
            }
            else {
                  $client = New-Client $Dhis2ApiBase $UserName $Password
            }
            $queryStringBuilder = [QueryStringBuilder]::new()
            $contentBuffer = [System.IO.MemoryStream]::new()
      }
      process {
            try {
                  if ($PayloadObject) {
                        $payload = ConvertTo-Json $PayloadObject -Compress -Depth 100
                  }
                  else {
                        $payload = $PayloadString
                  }
                  if ($PreheatCache.HasValue) { $queryStringBuilder.Append('page', $PreheatCache.Value.ToString().ToLowerInvariant()) }
                  $queryStringBuilder.Append('importStrategy', $ImportStrategy)
                  $queryStringBuilder.Append('mergeMode', $MergeMode)
                  $queryString = $queryStringBuilder.BuildAndReset()
                  Write-Debug "Path: $RelativeApiEndpoint"
                  Write-Debug "Query string: '$queryString'"
                  Write-Debug "Payload: $payload"
                  $requestUri = $RelativeApiEndpoint + $queryString
                  Write-Verbose "POST $($client.BaseAddress)$requestUri $(if ($payload.Length -gt 80) { $payload.Substring(76) + '...}' } else { $payload })"
                  $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, $RelativeApiEndpoint)
                  $request.Content = [System.Net.Http.StringContent]::new($payload, [System.Text.Encoding]::UTF8, 'application/json')
                  $response = $client.Send($request)
                  $contentBuffer.SetLength(0)
                  $response.Content.CopyTo($contentBuffer, $null, [System.Threading.CancellationToken]::None) > $null
                  $contentString = [System.Text.Encoding]::UTF8.GetString($contentBuffer.GetBuffer(), 0, $contentBuffer.Length)
                  Write-Debug "Response content: $contentString"
                  if (-not $response.IsSuccessStatusCode) {
                        if ($contentString) {
                              try {
                                    $contentObject = $contentString | ConvertFrom-Json
                              }
                              catch {
                                    throw $contentString
                              }
                              throw $contentObject
                        }
                        elseif ($response.ReasonPhrase) {
                              throw "Status: $($response.StatusCode), Reason: $($response.ReasonPhrase)"
                        }
                        else {
                              throw "Status: $($response.StatusCode)"
                        }
                  }
                  else {
                        try {
                              $contentObject = $contentString | ConvertFrom-Json
                              if ($ReturnId) {
                                    return $contentObject.response.uid
                              }
                              else {
                                    return $contentObject
                              }
                        }
                        catch {
                              throw $contentString
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


<#
.SYNOPSIS

Add or update an object to a DHIS2 a server.

.DESCRIPTION

Add or update a DHIS2 object to a server via the DHIS2 API.

.PARAMETER RelativeApiEndpoint
The relative endpoint in the DHIS2 API.

.PARAMETER PayloadString
The JSON payload as string.

.PARAMETER PayloadObject
The payload as object.

.PARAMETER PreheatCache
Turn cache-map preheating on/off.
This is on by default, turning this off will make initial load time
 for importer much shorter (but will make the import itself slower).
 This is mostly used for cases where you have a small XML/JSON file
 you want to import, and don't want to wait for cache-map preheating.

.PARAMETER ImportStrategy
Import strategy to use.

.PARAMETER MergeMode
Strategy for merging of objects when doing updates.
REPLACE will just overwrite the property with the new value provided,
MERGE will only set the property if it is not null (only if the
property was provided).

.PARAMETER ReturnId
Return the id of the created object instead of the whole response.

.PARAMETER UserName
The username to use for authentication on the DHIS2 server.

.PARAMETER Password
The password to use for authentication on the DHIS2 server.

.PARAMETER PersonalAccessToken
The personal access token to use for authentication on the DHIS2 server.

.PARAMETER Dhis2ApiBase
The DHIS2 API base URL.

.INPUTS

System.String or System.Object.

.OUTPUTS

System.Management.Automation.PSObject.

.LINK

https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-239/metadata.html#webapi_metadata_crud
#>
function Set-Dhis2Object {
      [CmdletBinding(DefaultParameterSetName = 'UsernamePasswordObject')]
      param (
            [Parameter(Position = 0, Mandatory, HelpMessage = 'The relative endpoint in the DHIS2 API')]
            [ArgumentCompletions('aggregateDataExchanges','analyticsTableHooks','apiToken','attributes','categories','categoryCombos',`
            'categoryOptionCombos','categoryOptionGroups','categoryOptionGroupSets','categoryOptions','constants','dashboardItems',`
            'dashboards','dataApprovalLevels','dataApprovalWorkflows','dataElementGroups','dataElementGroupSets','dataElementOperands',`
            'dataElements','dataEntryForms','dataSetNotificationTemplates','dataSets','dataStore','documents','eventCharts',`
            'eventFilters','eventReports','eventVisualizations','externalFileResources','externalMapLayers','fileResources','icons',`
            'indicatorGroups','indicatorGroupSets','indicators','indicatorTypes','interpretations','jobConfigurations','legendSets',`
            'maps','mapViews','messageConversations','metadata/proposals','metadata/version','minMaxDataElements','oAuth2Clients',`
            'optionGroups','optionGroupSets','options','optionSets','organisationUnitGroups','organisationUnitGroupSets',`
            'organisationUnitLevels','organisationUnits','predictorGroups','predictors','programDataElements','programIndicatorGroups',`
            'programIndicators','programNotificationTemplates','programRuleActions','programRules','programRuleVariables','programs',`
            'programSections','programStages','programStageSections','programTrackedEntityAttributeGroups','pushAnalysis','relationships',`
            'relationshipTypes','reports','sections','smsCommands','sqlViews','trackedEntityAttributes','trackedEntityInstanceFilters',`
            'trackedEntityInstances','trackedEntityTypes','userGroups','userRoles','users','validationNotificationTemplates',`
            'validationResults','validationRuleGroups','validationRules','visualizations')]
            [string] $RelativeApiEndpoint,

            [Parameter(Position = 1, Mandatory, ParameterSetName = 'PersonalAccessTokenString', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'The JSON payload as string.')]
            [Parameter(Position = 1, Mandatory, ParameterSetName = 'UsernamePasswordString', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'The JSON payload as string.')]
            [string] $PayloadString,

            [Parameter(Position = 1, Mandatory, ParameterSetName = 'PersonalAccessTokenObject', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'The payload as object.')]
            [Parameter(Position = 1, Mandatory, ParameterSetName = 'UsernamePasswordObject', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'The payload as object.')]
            [object] $PayloadObject,

            [Parameter(HelpMessage = 'Turn cache-map preheating on/off.')]
            [System.Nullable[bool]] $PreheatCache,

            [Parameter(HelpMessage = 'Return the id of the created object instead of the whole response.')]
            [switch] $ReturnId,

            [Parameter(HelpMessage = 'Import strategy to use.')]
            [ValidateSet('CREATE_AND_UPDATE','CREATE','UPDATE','DELETE')]
            [string] $ImportStrategy,

            [Parameter(HelpMessage = 'Import strategy to use.')]
            [ValidateSet('REPLACE','MERGE')]
            [string] $MergeMode,

            [Parameter(ParameterSetName = 'UsernamePasswordObject', HelpMessage = 'The username to use for authentication on the DHIS2 server.')]
            [Parameter(ParameterSetName = 'UsernamePasswordString', HelpMessage = 'The username to use for authentication on the DHIS2 server.')]
            [string] $UserName = $Dhis2DefaultUserName,

            [Parameter(ParameterSetName = 'UsernamePasswordObject', HelpMessage = 'The password to use for authentication on the DHIS2 server.')]
            [Parameter(ParameterSetName = 'UsernamePasswordString', HelpMessage = 'The password to use for authentication on the DHIS2 server.')]
            [securestring] $Password = $Dhis2DefaultPassword,

            [Parameter(Mandatory, ParameterSetName = 'PersonalAccessTokenObject', HelpMessage = 'The personal access token to use for authentication on the DHIS2 server.')]
            [Parameter(Mandatory, ParameterSetName = 'PersonalAccessTokenString', HelpMessage = 'The personal access token to use for authentication on the DHIS2 server.')]
            [securestring] $PersonalAccessToken = $Dhis2DefaultToken,

            [Parameter(HelpMessage = 'The DHIS2 API base URL')]
            [ArgumentCompletions('''http://localhost/api''', '''http://localhost:8080/api/39''', '''https://play.dhis2.org/2.39.1.1/api''')]
            [string] $Dhis2ApiBase = $Dhis2DefaultApiBase)
      begin {
            if ($PersonalAccessToken) {
                  $client = New-Client $Dhis2ApiBase $PersonalAccessToken
            }
            else {
                  $client = New-Client $Dhis2ApiBase $UserName $Password
            }
            $queryStringBuilder = [QueryStringBuilder]::new()
            $contentBuffer = [System.IO.MemoryStream]::new()
      }
      process {
            try {
                  if ($PayloadObject) {
                        $payload = ConvertTo-Json $PayloadObject -Compress -Depth 100
                  }
                  else {
                        $payload = $PayloadString
                  }
                  if ($PreheatCache.HasValue) { $queryStringBuilder.Append('page', $PreheatCache.Value.ToString().ToLowerInvariant()) }
                  $queryStringBuilder.Append('importStrategy', $ImportStrategy)
                  $queryStringBuilder.Append('mergeMode', $MergeMode)
                  $queryString = $queryStringBuilder.BuildAndReset()
                  Write-Debug "Path: $RelativeApiEndpoint"
                  Write-Debug "Query string: '$queryString'"
                  Write-Debug "Payload: $payload"
                  $requestUri = $RelativeApiEndpoint + $queryString
                  Write-Verbose "PUT $($client.BaseAddress)$requestUri $(if ($payload.Length -gt 80) { $payload.Substring(76) + '...}' } else { $payload })"
                  $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Put, $RelativeApiEndpoint)
                  $request.Content = [System.Net.Http.StringContent]::new($payload, [System.Text.Encoding]::UTF8, 'application/json')
                  $response = $client.Send($request)
                  $contentBuffer.SetLength(0)
                  $response.Content.CopyTo($contentBuffer, $null, [System.Threading.CancellationToken]::None) > $null
                  $contentString = [System.Text.Encoding]::UTF8.GetString($contentBuffer.GetBuffer(), 0, $contentBuffer.Length)
                  Write-Debug "Response content: $contentString"
                  if (-not $response.IsSuccessStatusCode) {
                        if ($contentString) {
                              try {
                                    $contentObject = $contentString | ConvertFrom-Json
                              }
                              catch {
                                    throw $contentString
                              }
                              throw $contentObject
                        }
                        elseif ($response.ReasonPhrase) {
                              throw "Status: $($response.StatusCode), Reason: $($response.ReasonPhrase)"
                        }
                        else {
                              throw "Status: $($response.StatusCode)"
                        }
                  }
                  else {
                        try {
                              $contentObject = $contentString | ConvertFrom-Json
                              if ($ReturnId) {
                                    return $contentObject.response.uid
                              }
                              else {
                                    return $contentObject
                              }
                        }
                        catch {
                              throw $contentString
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
      'Get-Dhis2Object'
      'Add-Dhis2Object'
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
