[string]$Dhis2DefaultApiBase
[string]$Dhis2DefaultUserName
[securestring]$Dhis2DefaultPassword
[securestring]$Dhis2DefaultToken

Add-Type -Language CSharp -TypeDefinition @"
namespace Dhis2Api
{
    public class IdGenerator
    {
        const string Values = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        const int FirstLength = 52;
        const int RestLength = 62;
        readonly System.Collections.Generic.HashSet<string> _existing = new();

        public string[] GenerateIds(int count)
        {
            var ids = new string[count];
            for (var i = 0; i < count; i++)
                ids[i] = GenerateId();
            return ids;
        }

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

function Reset-Dhis2Defaults {
      param (
            [Parameter(HelpMessage = 'The DHIS2 API base URL to use as default.')]
            [switch] $ApiBase,

            [Parameter(HelpMessage = 'The DHIS2 personal access token to use as default.')]
            [switch] $PersonalAccessToken,

            [Parameter(HelpMessage = 'Enter the payload as string')]
            [switch] $UserName,

            [Parameter(HelpMessage = 'The DHIS2 personal access token to use as default.')]
            [switch] $Password
      )
      if (($ApiBase -and $PersonalAccessToken -and $UserName -and $Password) -eq $false) {
            $script:Dhis2DefaultApiBase = 'http://localhost:8080/api/39'
            $script:Dhis2DefaultToken = $null
            $script:Dhis2DefaultUserName = 'admin'
            $script:Dhis2DefaultPassword = ConvertTo-SecureString 'district' -AsPlainText
      }
      elseif ($ApiBase) {
            $script:Dhis2DefaultApiBase = 'http://localhost:8080/api/39'
      }
      elseif ($PersonalAccessToken) {
            $script:Dhis2DefaultToken = $null
      }
      elseif ($UserName) {
            $script:Dhis2DefaultUserName = 'admin'
      }
      elseif ($Password) {
            $script:Dhis2DefaultPassword = ConvertTo-SecureString 'district' -AsPlainText
      }
}

Reset-Dhis2Defaults

function Test-ApiBase {
      param (
            [Parameter(Mandatory, Position = 0)]
            [string] $Dhis2ApiBase
      )
      if (-not [uri]::IsWellFormedUriString($Dhis2ApiBase, [System.UriKind]::Absolute)) {
            Write-Error "'$Dhis2ApiBase' is not a well-formed URI string."
            return $false
      }
      New-Variable -Name uri
      if (-not [uri]::TryCreate($Dhis2ApiBase, [System.UriKind]::Absolute, [ref]$uri)) {
            Write-Error "Failed to parse the URI '$Dhis2ApiBase'"
            return $false
      }
      if (-not [string]::IsNullOrEmpty($uri.Query)) {
            Write-Error "The DHIS2 API base must not contain a query string."
            return $false
      }
      if (-not [System.Text.RegularExpressions.Regex]::IsMatch($uri.AbsolutePath, '^/api(/\d\d)?/?')) {
            Write-Error "The path '$($uri.AbsolutePath)' is not a valid DHIS2 API path."
            return $false
      }
      return $true
}
function Set-Dhis2Defaults {
      param (
            [Parameter(HelpMessage = 'The DHIS2 API base URL to use as default.')]
            [string] $ApiBase,

            [Parameter(HelpMessage = 'The DHIS2 personal access token to use as default.')]
            [securestring] $PersonalAccessToken,

            [Parameter(HelpMessage = 'Enter the payload as string')]
            [string] $UserName,

            [Parameter(HelpMessage = 'The DHIS2 personal access token to use as default.')]
            [securestring] $Password
      )

      if (-not $Apibase -and -not $PersonalAccessToken -and -not $UserName -and -not $Password) {
            $newApiBase = Read-Host -Prompt "Enter the DHIS2 API base URL [$Dhis2DefaultApiBase]"
            if ([string]::IsNullOrWhiteSpace($newApiBase) -or -not (Test-ApiBase $newApiBase)) {
                  return
            }
            $script:Dhis2DefaultApiBase = $newApiBase

            if ($Dhis2DefaultToken) { $mask = '*****' }
            else { $mask = 'NONE' }
            $token = Read-Host -Prompt "Enter your personal access token [$mask]" -AsSecureString
            if ($token.Length -gt 0) {
                  $script:Dhis2DefaultToken = $token
            }
            else {
                  $newUserName = Read-Host -Prompt "Enter your user name [$Dhis2DefaultUserName]"
                  if (-not [string]::IsNullOrWhiteSpace($newUserName)) {
                        $script:Dhis2DefaultUserName = $newUserName
                  }
                  $newPassword = Read-Host -Prompt "Enter your password [*****]" -AsSecureString
                  if ($newPassword) {
                        $script:Dhis2DefaultPassword = $newPassword
                  }
            }
      }
      else {
            if ($Apibase) {
                  if ([string]::IsNullOrWhiteSpace($Apibase) -or -not (Test-ApiBase $Apibase)) {
                        return
                  }
                  $script:Dhis2DefaultApiBase = $Apibase
            }
            if ($PersonalAccessToken) {
                  if ($PersonalAccessToken.Length -eq 0) {
                        Reset-Dhis2Defaults -PersonalAccessToken
                  }
                  else {
                        $script:Dhis2DefaultToken = $PersonalAccessToken
                  }
            }
            if ($UserName) {
                  $script:Dhis2DefaultUserName = $UserName
            }
            if ($Password) {
                  $script:Dhis2DefaultPassword = $Password
            }
      }
}

function Get-Dhis2Defaults {
      return [PSCustomObject]@{
            ApiBase = $Dhis2DefaultApiBase
            PersonalAccessToken = $Dhis2DefaultToken
            UserName = $Dhis2DefaultUserName
            Password = $Dhis2DefaultPassword
      }
}

function New-Client {
      param (
            [Parameter(Mandatory, Position = 0)]
            [string] $Dhis2ApiBase,

            [Parameter(Mandatory, Position = 1, ParameterSetName = 'UsernamePassword')]
            [AllowNull()]
            [string] $UserName,

            [Parameter(Mandatory, Position = 2, ParameterSetName = 'UsernamePassword')]
            [AllowNull()]
            [securestring] $Password,

            [Parameter(Mandatory, Position = 1, ParameterSetName = 'PersonalAccessToken')]
            [AllowNull()]
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

function Get-Dhis2Object {
      [CmdletBinding(DefaultParameterSetName = 'UsernamePasswordHash')]
      param (
            [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the DHIS2 API object to read')]
            [ArgumentCompletions('dataElements/', 'dataValueSets', 'me', 'me/authorities', 'me/authorities/ALL', 'metadata/version', 'options', 'optionSets/', 'organisationUnits/',
            'programs/', 'programStages/', 'programStageSections/', 'system/id', 'system/info')]
            [string] $ApiObject,

            [Parameter(Position = 1, ParameterSetName = 'PersonalAccessTokenArray', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the query parameters as array of ValueTuple[string,string]')]
            [Parameter(Position = 1, ParameterSetName = 'UsernamePasswordArray', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the query parameters as array of ValueTuple[string,string]')]
            [System.ValueTuple[string,string][]] $QueryParametersArray,

            [Parameter(Position = 1, ParameterSetName = 'PersonalAccessTokenHash', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the query parameters as HashTable')]
            [Parameter(Position = 1, ParameterSetName = 'UsernamePasswordHash', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the query parameters as HashTable')]
            [ArgumentCompletions('@{paging=''false'';fields=''*''}', '@{paging=''false'';fields=''*''}', '@{paging=''false'';filter=''code:eq:TODO''}', '@{paging=''false'';filter=''name:$ilike:TODO''}')]
            [hashtable] $QueryParameterHash,

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
                  $requestUri = $ApiObject
                  if ($QueryParametersArray -and $QueryParametersArray.Count -gt 0) {
                        $sb = [System.Text.StringBuilder]::new('?')
                        foreach ($tuple in $QueryParametersArray) {
                              $sb.Append([System.Web.HttpUtility]::UrlEncode($tuple.Item1)).Append('=').Append([System.Web.HttpUtility]::UrlEncode($tuple.Item2)).Append('&') > $null
                        }
                        $sb.Length = $sb.Length - 1
                        $requestUri += $sb.ToString()
                  }
                  elseif ($QueryParameterHash -and $QueryParameterHash.Count -gt 0) {
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
                              Write-Error $contentString
                        }
                        else {
                              Write-Error "Error: Status code: $($response.StatusCode), Reason: $($response.ReasonPhrase)"
                        }
                  }
                  $contentObject = $contentString | ConvertFrom-Json
                  if ($Unwrap) {
                        return $contentObject.PSObject.Properties | Select-Object -First 1 | ForEach-Object { $_.Value }
                  }
                  else {
                        return $contentObject
                  }
            }
            finally {
                  if ($request) { $request.Dispose() }
                  if ($response) { $response.Dispose() }
            }
      }
      clean { if ($client) { $client.Dispose() } }
}

function Add-Dhis2Object {
      [CmdletBinding(DefaultParameterSetName = 'UsernamePasswordObject')]
      param (
            [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the DHIS2 API object to write to')]
            [ArgumentCompletions('dataElements', 'dataValueSets', 'metadata', 'options', 'optionSets', 'programRuleVariables')]
            [string] $ApiObject,

            [Parameter(Position = 1, Mandatory, ParameterSetName = 'PersonalAccessTokenString', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the payload as string')]
            [Parameter(Position = 1, Mandatory, ParameterSetName = 'UsernamePasswordString', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the payload as string')]
            [string] $PayloadString,

            [Parameter(Position = 1, Mandatory, ParameterSetName = 'PersonalAccessTokenObject', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the payload as object')]
            [Parameter(Position = 1, Mandatory, ParameterSetName = 'UsernamePasswordObject', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the payload as object')]
            [System.Object] $PayloadObject,

            [Parameter(ParameterSetName = 'UsernamePasswordObject', HelpMessage = 'Enter your username')]
            [Parameter(ParameterSetName = 'UsernamePasswordString', HelpMessage = 'Enter your username')]
            [string] $UserName = $Dhis2DefaultUserName,

            [Parameter(ParameterSetName = 'UsernamePasswordObject', HelpMessage = 'Enter your password')]
            [Parameter(ParameterSetName = 'UsernamePasswordString', HelpMessage = 'Enter your password')]
            [securestring] $Password = $Dhis2DefaultPassword,

            [Parameter(Mandatory, ParameterSetName = 'PersonalAccessTokenObject', HelpMessage = 'Enter your personal access token for the DHIS2 API')]
            [Parameter(Mandatory, ParameterSetName = 'PersonalAccessTokenString', HelpMessage = 'Enter your personal access token for the DHIS2 API')]
            [securestring] $PersonalAccessToken = $Dhis2DefaultToken,

            [Parameter(HelpMessage = 'Enter the DHIS2 API base URL')]
            [string] $Dhis2ApiBase = $Dhis2DefaultApiBase,

            [Parameter(HelpMessage = 'Set this flag to return the uid of the created object instead of the whole response')]
            [switch] $Uid,

            [Parameter(ParameterSetName = 'PersonalAccessTokenObject', HelpMessage = 'Pass a hashtable to get a mapping from the code to the uid.')]
            [Parameter(ParameterSetName = 'UsernamePasswordObject', HelpMessage = 'Pass a hashtable to get a mapping from the code to the uid.')]
            [hashtable] $CodeMap)
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
                  if ($PayloadObject) {
                        $payload = ConvertTo-Json $PayloadObject -Compress -Depth 100
                  }
                  else {
                        $payload = $PayloadString
                  }
                  Write-Debug "API object: $ApiObject"
                  Write-Debug "Payload: $payload"
                  $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, $ApiObject)
                  $request.Content = [System.Net.Http.StringContent]::new($payload, [System.Text.Encoding]::UTF8, 'application/json')
                  $response = $client.Send($request)
                  $ms = [System.IO.MemoryStream]::new()
                  $response.Content.CopyTo($ms, $null, [System.Threading.CancellationToken]::None) > $null
                  $contentString = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
                  if (-not $response.IsSuccessStatusCode) {
                        if ($contentString) {
                              Write-Error $contentString
                        }
                        else {
                              Write-Error "Error: Status code: $($response.StatusCode), Reason: $($response.ReasonPhrase)"
                        }
                  }
                  $contentObject = $contentString | ConvertFrom-Json
                  if ($CodeMap -and $PayloadObject.code) {
                        $CodeMap[$PayloadObject.code] = $contentObject.response.uid
                  }
                  if ($Uid) {
                        return $contentObject.response.uid
                  }
                  else {
                        return $contentObject
                  }
            }
            finally {
                  if ($request) { $request.Dispose() }
                  if ($response) { $response.Dispose() }
            }
      }
      clean { if ($client) { $client.Dispose() } }
}

function Set-Dhis2Object {
      [CmdletBinding(DefaultParameterSetName = 'UsernamePasswordObject')]
      param (
            [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the DHIS2 API object to write to')]
            [ArgumentCompletions('dataElements', 'dataValueSets', 'metadata', 'options', 'optionSets', 'programRuleVariables')]
            [string] $ApiObject,

            [Parameter(Position = 1, Mandatory, ParameterSetName = 'PersonalAccessTokenString', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the payload as string')]
            [Parameter(Position = 1, Mandatory, ParameterSetName = 'UsernamePasswordString', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the payload as string')]
            [string] $PayloadString,

            [Parameter(Position = 1, Mandatory, ParameterSetName = 'PersonalAccessTokenObject', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the payload as object')]
            [Parameter(Position = 1, Mandatory, ParameterSetName = 'UsernamePasswordObject', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the payload as object')]
            [System.Object] $PayloadObject,

            [Parameter(ParameterSetName = 'UsernamePasswordObject', HelpMessage = 'Enter your username')]
            [Parameter(ParameterSetName = 'UsernamePasswordString', HelpMessage = 'Enter your username')]
            [string] $UserName = $Dhis2DefaultUserName,

            [Parameter(ParameterSetName = 'UsernamePasswordObject', HelpMessage = 'Enter your password')]
            [Parameter(ParameterSetName = 'UsernamePasswordString', HelpMessage = 'Enter your password')]
            [securestring] $Password = $Dhis2DefaultPassword,

            [Parameter(Mandatory, ParameterSetName = 'PersonalAccessTokenObject', HelpMessage = 'Enter your personal access token for the DHIS2 API')]
            [Parameter(Mandatory, ParameterSetName = 'PersonalAccessTokenString', HelpMessage = 'Enter your personal access token for the DHIS2 API')]
            [securestring] $PersonalAccessToken = $Dhis2DefaultToken,

            [Parameter(HelpMessage = 'Enter the DHIS2 API base URL')]
            [string] $Dhis2ApiBase = $Dhis2DefaultApiBase,

            [Parameter(HelpMessage = 'Set this flag to return the uid of the created object instead of the whole response')]
            [switch] $Uid,

            [Parameter(ParameterSetName = 'PersonalAccessTokenObject', HelpMessage = 'Pass a hashtable to get a mapping from the code to the uid.')]
            [Parameter(ParameterSetName = 'UsernamePasswordObject', HelpMessage = 'Pass a hashtable to get a mapping from the code to the uid.')]
            [hashtable] $CodeMap)
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
                  if ($PayloadObject) {
                        $payload = ConvertTo-Json $PayloadObject -Compress -Depth 100
                  }
                  else {
                        $payload = $PayloadString
                  }
                  Write-Debug "API object: $ApiObject"
                  Write-Debug "Payload: $payload"
                  $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Put, $ApiObject)
                  $request.Content = [System.Net.Http.StringContent]::new($payload, [System.Text.Encoding]::UTF8, 'application/json')
                  $response = $client.Send($request)
                  $ms = [System.IO.MemoryStream]::new()
                  $response.Content.CopyTo($ms, $null, [System.Threading.CancellationToken]::None) > $null
                  $contentString = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
                  if (-not $response.IsSuccessStatusCode) {
                        if ($contentString) {
                              Write-Error $contentString
                        }
                        else {
                              Write-Error "Error: Status code: $($response.StatusCode), Reason: $($response.ReasonPhrase)"
                        }
                  }
                  $contentObject = $contentString | ConvertFrom-Json
                  if ($CodeMap -and $PayloadObject.code) {
                        $CodeMap[$PayloadObject.code] = $contentObject.response.uid
                  }
                  if ($Uid) {
                        return $contentObject.response.uid
                  }
                  else {
                        return $contentObject
                  }
            }
            finally {
                  if ($request) { $request.Dispose() }
                  if ($response) { $response.Dispose() }
            }
      }
      clean { if ($client) { $client.Dispose() } }
}

function Update-Dhis2Object {
      [CmdletBinding(DefaultParameterSetName = 'UsernamePasswordObject')]
      param (
            [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the DHIS2 API object to write to')]
            [ArgumentCompletions('dataElements', 'dataValueSets', 'metadata', 'options', 'optionSets', 'programRuleVariables')]
            [string] $ApiObject,

            [Parameter(Position = 1, Mandatory, ParameterSetName = 'PersonalAccessTokenString', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the payload as string')]
            [Parameter(Position = 1, Mandatory, ParameterSetName = 'UsernamePasswordString', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the payload as string')]
            [string] $PayloadString,

            [Parameter(Position = 1, Mandatory, ParameterSetName = 'PersonalAccessTokenObject', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the payload as object')]
            [Parameter(Position = 1, Mandatory, ParameterSetName = 'UsernamePasswordObject', ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the payload as object')]
            [System.Object] $PayloadObject,

            [Parameter(ParameterSetName = 'UsernamePasswordObject', HelpMessage = 'Enter your username')]
            [Parameter(ParameterSetName = 'UsernamePasswordString', HelpMessage = 'Enter your username')]
            [string] $UserName = $Dhis2DefaultUserName,

            [Parameter(ParameterSetName = 'UsernamePasswordObject', HelpMessage = 'Enter your password')]
            [Parameter(ParameterSetName = 'UsernamePasswordString', HelpMessage = 'Enter your password')]
            [securestring] $Password = $Dhis2DefaultPassword,

            [Parameter(Mandatory, ParameterSetName = 'PersonalAccessTokenObject', HelpMessage = 'Enter your personal access token for the DHIS2 API')]
            [Parameter(Mandatory, ParameterSetName = 'PersonalAccessTokenString', HelpMessage = 'Enter your personal access token for the DHIS2 API')]
            [securestring] $PersonalAccessToken = $Dhis2DefaultToken,

            [Parameter(HelpMessage = 'Enter the DHIS2 API base URL')]
            [string] $Dhis2ApiBase = $Dhis2DefaultApiBase,

            [Parameter(HelpMessage = 'Set this flag to return the uid of the created object instead of the whole response')]
            [switch] $Uid,

            [Parameter(ParameterSetName = 'PersonalAccessTokenObject', HelpMessage = 'Pass a hashtable to get a mapping from the code to the uid.')]
            [Parameter(ParameterSetName = 'UsernamePasswordObject', HelpMessage = 'Pass a hashtable to get a mapping from the code to the uid.')]
            [hashtable] $CodeMap)
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
                  if ($PayloadObject) {
                        $payload = ConvertTo-Json $PayloadObject -Compress -Depth 100
                  }
                  else {
                        $payload = $PayloadString
                  }
                  Write-Debug "API object: $ApiObject"
                  Write-Debug "Payload: $payload"
                  $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Patch, $ApiObject)
                  $request.Content = [System.Net.Http.StringContent]::new($payload, [System.Text.Encoding]::UTF8, 'application/json-patch+json')
                  $response = $client.Send($request)
                  $ms = [System.IO.MemoryStream]::new()
                  $response.Content.CopyTo($ms, $null, [System.Threading.CancellationToken]::None) > $null
                  $contentString = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
                  if (-not $response.IsSuccessStatusCode) {
                        if ($contentString) {
                              Write-Error $contentString
                        }
                        else {
                              Write-Error "Error: Status code: $($response.StatusCode), Reason: $($response.ReasonPhrase)"
                        }
                  }
                  $contentObject = $contentString | ConvertFrom-Json
                  if ($CodeMap -and $PayloadObject.code) {
                        $CodeMap[$PayloadObject.code] = $contentObject.response.uid
                  }
                  if ($Uid) {
                        return $contentObject.response.uid
                  }
                  else {
                        return $contentObject
                  }
            }
            finally {
                  if ($request) { $request.Dispose() }
                  if ($response) { $response.Dispose() }
            }
      }
      clean { if ($client) { $client.Dispose() } }
}

function Remove-Dhis2Object {
      [CmdletBinding(DefaultParameterSetName = 'UsernamePassword')]
      param (
            [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the DHIS2 API object to remove')]
            [ArgumentCompletions('dataElements', 'dataValueSets', 'options', 'optionSets')]
            [string] $ApiObject,

            [Parameter(Position = 1, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Enter the object id as string')]
            [ValidateScript({ if ([string]::IsNullOrEmpty($_)) { $true } else { [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') } },
            ErrorMessage = "The value '{0}' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string] $Id,

            [Parameter(ParameterSetName = 'UsernamePassword', HelpMessage = 'Enter your username')]
            [string] $UserName = $Dhis2DefaultUserName,

            [Parameter(ParameterSetName = 'UsernamePassword', HelpMessage = 'Enter your password')]
            [securestring] $Password = $Dhis2DefaultPassword,

            [Parameter(Mandatory, ParameterSetName = 'PersonalAccessToken', HelpMessage = 'Enter your personal access token for the DHIS2 API')]
            [securestring] $PersonalAccessToken = $Dhis2DefaultToken,

            [Parameter(HelpMessage = 'Enter the DHIS2 API base URL')]
            [string] $Dhis2ApiBase = $Dhis2DefaultApiBase)
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
                  Write-Debug "API object: $ApiObject"
                  Write-Debug "Id: $Id"
                  $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Delete, "$ApiObject/$Id")
                  $response = $client.Send($request)
                  $ms = [System.IO.MemoryStream]::new()
                  $response.Content.CopyTo($ms, $null, [System.Threading.CancellationToken]::None) > $null
                  $contentString = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())

                  if (-not $response.IsSuccessStatusCode) {
                        if ($contentString) {
                              Write-Error $contentString
                        }
                        else {
                              Write-Error "Error: Status code: $($response.StatusCode), Reason: $($response.ReasonPhrase)"
                        }
                  }
                  return $contentString | ConvertFrom-Json
            }
            finally {
                  if ($request) { $request.Dispose() }
                  if ($response) { $response.Dispose() }
            }
      }
      clean { if ($client) { $client.Dispose() } }
}

function New-Dhis2DataElement {
      [CmdletBinding()]
      param (
            [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'The DHIS2 domain type to use this data element in.')]
            [ValidateSet('AGGREGATE', 'TRACKER')]
            [string]$DomainType,

            [Parameter(Position = 1, Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'The DHIS2 value type of this data element.')]
            # https://github.com/dhis2/dhis2-core/blob/master/dhis-2/dhis-api/src/main/java/org/hisp/dhis/common/ValueType.java
            [ValidateSet('TEXT', 'LONG_TEXT', 'MULTI_TEXT', 'LETTER', 'PHONE_NUMBER', 'EMAIL', 'BOOLEAN', 'TRUE_ONLY', 'DATE', 'DATETIME', 'TIME', 'NUMBER', 'UNIT_INTERVAL', 'PERCENTAGE', 'INTEGER', 'INTEGER_POSITIVE', 'INTEGER_NEGATIVE', 'INTEGER_ZERO_OR_POSITIVE', 'TRACKER_ASSOCIATE', 'USERNAME', 'COORDINATE', 'ORGANISATION_UNIT', 'REFERENCE', 'AGE', 'URL', 'FILE_RESOURCE', 'IMAGE', 'GEOJSON')]
            [string]$ValueType,

            [Parameter(Position = 2, Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'The name of the data element.')]
            [ValidateLength(1,230)]
            [string]$Name,

            [Parameter(Position = 3, Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'The short name of the data element.')]
            [ValidateLength(1,50)]
            [string]$ShortName,

            [Parameter(ValueFromPipelineByPropertyName, HelpMessage = 'The code of the data element.')]
            [ValidateLength(0,50)]
            [string]$Code,

            [Parameter(ValueFromPipelineByPropertyName, HelpMessage = 'The form name of the data element.')]
            [ValidateLength(0,230)]
            [string]$FormName,

            [Parameter(ValueFromPipelineByPropertyName, HelpMessage = 'The description of the data element.')]
            [string]$Description,

            [Parameter(ValueFromPipelineByPropertyName, HelpMessage = 'The id of the option set that should be assigned to the data element.')]
            [ValidateScript({ if ([string]::IsNullOrEmpty($_)) { $true } else { [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') } },
            ErrorMessage = "The value '{0}' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$OptionSetId,

            [Parameter(ValueFromPipelineByPropertyName, HelpMessage = 'The id of the option set for comments that should be assigned to the data element.')]
            [ValidateScript({ if ([string]::IsNullOrEmpty($_)) { $true } else { [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') } },
            ErrorMessage = "The value '{0}' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$CommentOptionSetId,

            [Parameter(ValueFromPipelineByPropertyName, HelpMessage = 'The field mask of the data element.')]
            [ValidateScript({ if ([string]::IsNullOrEmpty($_)) { $true } else { [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') } },
            ErrorMessage = "The value '{0}' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$Id,

            [Parameter(ValueFromPipelineByPropertyName, HelpMessage = 'The field mask of the data element.')]
            [ValidateLength(0,255)]
            [string]$FieldMask,

            [Parameter(ValueFromPipelineByPropertyName, HelpMessage = 'The DHIS2 aggregationType type of this data element.')]
            # https://github.com/dhis2/dhis2-core/blob/master/dhis-2/dhis-api/src/main/java/org/hisp/dhis/common/ValueType.java
            [ValidateSet('SUM', 'AVERAGE', 'AVERAGE_SUM_ORG_UNIT', 'LAST', 'LAST_AVERAGE_ORG_UNIT', 'LAST_LAST_ORG_UNIT', 'LAST_IN_PERIOD', 'LAST_IN_PERIOD_AVERAGE_ORG_UNIT', 'FIRST', 'FIRST_AVERAGE_ORG_UNIT', 'FIRST_FIRST_ORG_UNIT', 'COUNT', 'STDDEV', 'VARIANCE', 'MIN', 'MAX', 'MIN_SUM_ORG_UNIT', 'MAX_SUM_ORG_UNIT', 'NONE', 'CUSTOM', 'DEFAULT')]
            [string]$AggregationType='DEFAULT',

            [Parameter(ValueFromPipelineByPropertyName, HelpMessage = 'The help URL for the data element.')]
            [ValidateScript({ if ([string]::IsNullOrEmpty($_)) { $true } else { [uri]::IsWellFormedUriString($_, [System.UriKind]::Absolute) } },
            ErrorMessage = "The value '{0}' is not a well-formed URI.")]
            [string]$Url,

            
            [Parameter(ValueFromPipelineByPropertyName, HelpMessage = 'Indicates whether zero values will be stored for this data element.')]
            [switch]$ZeroIsSignificant,


            [Parameter(ValueFromPipelineByPropertyName, HelpMessage = 'The id of the DHIS2 category combination to use for this data element.')]
            [ValidateScript({ [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') },
            ErrorMessage = "The value '{0}' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$CategoryComboId='bjDvmb4bfuf'
      )

      process {
            if (-not  $DomainType) { return }
            if (-not  $ValueType) { return }
            if (-not  $Name) { return }
            if (-not  $ShortName) { return }
            if (-not  $AggregationType) { return }
            if (-not  $CategoryComboId) { return }
            $obj = @{
                  domainType = $DomainType
                  valueType = $ValueType
                  name = $Name
                  shortName = $ShortName
                  aggregationType = $AggregationType
                  categoryCombo = @{ id = $CategoryComboId }
            }
            if ($Code) { $obj.code = $Code }
            if ($FormName) { $obj.formName = $FormName }
            if ($Description) { $obj.description = $Description }
            if ($OptionSetId) { $obj.optionSet = @{ id = $OptionSetId } }
            if ($CommentOptionSetId) { $obj.commentOptionSet = @{ id = $CommentOptionSetId } }
            if ($Id) { $obj.id = $Id }
            if ($FieldMask) { $obj.fieldMask = $FieldMask }
            if ($ZeroIsSignificant) { $obj.zeroIsSignificant = $ZeroIsSignificant.ToString() }
            if ($Url) { $obj.url = $Url }
            return $obj
      }
}

function ConvertTo-Dhis2DataElement {
      [CmdletBinding()]
      param (
            [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
            [object]$InputObject,

            [Parameter()]
            [System.Collections.Hashtable]$OptionSetCodeMap,

            [Parameter()]
            [System.Collections.Hashtable]$CategoryComboCodeMap
      )
      process {
            if ($InputObject.optionSet_id) {
                  $optionSetId = $InputObject.optionSet_id
            } elseif ($InputObject.optionSetId) {
                  $optionSetId = $InputObject.optionSetId
            } elseif ($OptionSetCodeMap -and $InputObject.optionSet_code) {
                  $optionSetId = $OptionSetCodeMap[$InputObject.optionSet_code]
                  if (-not $optionSetId){Write-Error "Failed to find the id for optionSet '$($InputObject.optionSet_code)'."}
            } elseif ($OptionSetCodeMap -and $InputObject.optionSetCode) {
                  $optionSetId = $OptionSetCodeMap[$InputObject.optionSetCode]
                  if (-not $optionSetId){Write-Error "Failed to find the id for optionSet '$($InputObject.optionSetCode)'."}
            } else {
                  $optionSetId = $null
            }
            if ($InputObject.commentOptionSet_id) {
                  $commentOptionSetId = $InputObject.commentOptionSet_id
            } elseif ($InputObject.commentOptionSetId) {
                  $commentOptionSetId = $InputObject.commentOptionSetId
            } elseif ($OptionSetCodeMap -and $InputObject.commentOptionSet_code) {
                  $commentOptionSetId = $OptionSetCodeMap[$InputObject.commentOptionSet_code]
                  if (-not $commentOptionSetId){Write-Error "Failed to find the id for commentOptionSet '$($InputObject.commentOptionSet_code)'."}
            } elseif ($OptionSetCodeMap -and $InputObject.commentOptionSetCode) {
                  $commentOptionSetId = $OptionSetCodeMap[$InputObject.commentOptionSetCode]
                  if (-not $commentOptionSetId){Write-Error "Failed to find the id for commentOptionSet '$($InputObject.commentOptionSetCode)'."}
            } else {
                  $commentOptionSetId = $null
            }
            if ($InputObject.categoryCombo_id) {
                  $categoryComboId = $InputObject.categoryCombo_id
            } elseif ($InputObject.categoryComboId) {
                  $categoryComboId = $InputObject.categoryComboId
            } elseif ($categorCategoryComboCodeMapyComboCodeMap -and $InputObject.categoryCombo_code) {
                  $categoryComboId = $CategoryComboCodeMap[$InputObject.categoryCombo_code]
                  if (-not $categoryComboId -and $InputObject.categoryCombo_code -eq 'default'){$categoryComboId = 'bjDvmb4bfuf'}
                  elseif (-not $categoryComboId){Write-Error "Failed to find the id for category combination '$($InputObject.categoryCombo_code)'."}
            } elseif ($CategoryComboCodeMap -and $InputObject.categoryComboCode) {
                  $categoryComboId = $CategoryComboCodeMap[$InputObject.categoryComboCode]
                  if (-not $categoryComboId -and $InputObject.categoryComboCode -eq 'default'){$categoryComboId = 'bjDvmb4bfuf'}
                  elseif (-not $categoryComboId){Write-Error "Failed to find the id for category combination '$($InputObject.categoryComboCode)'."}
            } else {
                  $categoryComboId = 'bjDvmb4bfuf'
            }
            $argHash = @{
                  OptionSetId = $optionSetId
                  CommentOptionSetId = $commentOptionSetId
                  CategoryComboId = $categoryComboId
                  Code = $InputObject.code
                  Name = $InputObject.name
                  AggregationType = $InputObject.aggregationType
                  Description = $InputObject.description
                  DomainType = $InputObject.domainType
                  FieldMask = $InputObject.fieldMask
                  FormName = $InputObject.formName
                  ShortName = $InputObject.shortName
                  Url = $InputObject.url
                  ValueType = $InputObject.valueType
                  ZeroIsSignificant = [System.Convert]::ToBoolean($InputObject.zeroIsSignificant)
              }
              New-Dhis2DataElement @argHash
      }
}

<#
.SYNOPSIS
Creates a new DHIS2 programRuleVariable object.

.DESCRIPTION
Creates a new DHIS2 programRuleVariable object that cann be passed to
Add-Dhis2Object. The different parameter sets and validations help to
ensure that the created object is valid.

.PARAMETER ProgramId
The id of the program the program rule variable should be created in.

.PARAMETER Name
The name for the programRuleVariable - this name is used in expressions.

.PARAMETER TrackedEntityAttributeId
Used for linking the programRuleVariable to a trackedEntityAttribute.
Implicitly sets SourceType to TEI_ATTRIBUTE.
Gets the value of a given tracked entity attribute.

.PARAMETER ProgramStageId
Used for specifying a specific program stage to retreive the programRuleVariable value from.
Implicitly sets SourceType to DATAELEMENT_NEWEST_EVENT_PROGRAM_STAGE.
In tracker capture, this gets the newest value that exists for a data element, within the events
of a given program stage in the current enrollment.
In event capture, gets the newest value among the 10 newest events on the organisation unit.

.PARAMETER DataElementId
Used for linking the programRuleVariable to a dataElement.

.PARAMETER SourceType
Defines how this variable is populated with data from the enrollment and events.
 - DATAELEMENT_NEWEST_EVENT_PROGRAM - In tracker capture, get the newest value that exists for a data element across
   the whole enrollment. In event capture, gets the newest value among the 10 newest events on the organisation unit.
 - DATAELEMENT_CURRENT_EVENT - Gets the value of the given data element in the current event only.
 - DATAELEMENT_PREVIOUS_EVENT - In tracker capture, gets the newest value that exists among events in the program that
   precedes the current event. In event capture, gets the newvest value among the 10 preceeding events registered on the
   organisation unit.

.PARAMETER ValueType
The valueType parameter defines the type of the value that this ProgramRuleVariable can contain.
Implicitly sets SourceType to CALCULATED_VALUE.
Used to reserve a variable name that will be assigned by an ASSIGN program rule action.

.PARAMETER UseCodeForOptionSet
If set, the variable will be populated with the code - not the name - from any linked option set.
Default is unset, meaning that the name of the option is populated.

.PARAMETER Code
The code of the program rule variable..

.OUTPUTS
System.Collections.Hashtable. New-Dhis2ProgramRuleVariable returns a Hashtable containing the
newly created program rule variable object.

.EXAMPLE
PS>  New-Dhis2ProgramRuleVariable XUu9DGNdQJo Test -ValueType BOOLEAN

Name                           Value
----                           -----
programRuleVariableSourceType  CALCULATED_VALUE
name                           Test
valueType                      BOOLEAN
program                        {[id, XUu9DGNdQJo]}

.LINK
Add-Dhis2Object
#>
function New-Dhis2ProgramRuleVariable {
      [CmdletBinding(DefaultParameterSetName = 'SourceType')]
      param (
            [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName)]
            [ValidateScript({ [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  "See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$ProgramId,

            [Parameter(Position = 1, Mandatory, ValueFromPipelineByPropertyName)]
            [ValidateLength(1,230)]
            [string]$Name,

            [Parameter(Position = 2, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'TrackedEntityAttribute')]
            [ValidateScript({ if ([string]::IsNullOrEmpty($_)) { $true } else { [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') } },
            ErrorMessage = "The value '{0}' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$TrackedEntityAttributeId,

            [Parameter(Position = 2, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ProgramStageId')]
            [ValidateScript({ if ([string]::IsNullOrEmpty($_)) { $true } else { [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') } },
            ErrorMessage = "The value '{0}' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$ProgramStageId,

            [Parameter(Position = 2, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'SourceType')]
            [Parameter(Position = 3, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ProgramStageId')]
            [ValidateScript({ if ([string]::IsNullOrEmpty($_)) { $true } else { [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') } },
            ErrorMessage = "The value '{0}' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$DataElementId,

            [Parameter(Position = 3, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'SourceType')]
            [ValidateSet('DATAELEMENT_NEWEST_EVENT_PROGRAM', 'DATAELEMENT_CURRENT_EVENT', 'DATAELEMENT_PREVIOUS_EVENT')]
            [string]$SourceType,

            [Parameter(Position = 2, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'CalculatedValue')]
            [ValidateSet('TEXT','LONG_TEXT','MULTI_TEXT','LETTER','PHONE_NUMBER','EMAIL','BOOLEAN',
            'TRUE_ONLY','DATE','DATETIME','TIME','NUMBER','UNIT_INTERVAL','PERCENTAGE','INTEGER','INTEGER_POSITIVE',
            'INTEGER_NEGATIVE','INTEGER_ZERO_OR_POSITIVE','TRACKER_ASSOCIATE','USERNAME','COORDINATE','ORGANISATION_UNIT',
            'REFERENCE','AGE','URL','FILE_RESOURCE','IMAGE','GEOJSON')]
            [string]$ValueType,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$UseCodeForOptionSet,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateLength(0,50)]
            [string]$Code
      )

      process {
            if (-not  $ProgramId) { return }
            if (-not  $Name) { return }
            $obj = @{
                  program = @{ id = $ProgramId }
                  name = $Name
            }
            if ($TrackedEntityAttributeId) {
                  $obj.trackedEntityAttribute = @{ id = $TrackedEntityAttributeId }
                  $obj.programRuleVariableSourceType = 'TEI_ATTRIBUTE'
            }
            elseif ($ProgramStageId) {
                  if (-not $DataElementId) {
                        Write-Error "The DataElementId parameter must be set if the ProgramStageId parameter is set."
                        return
                  }
                  $obj.programStage = @{ id = $ProgramStageId }
                  $obj.dataElement = @{ id = $DataElementId }
                  $obj.programRuleVariableSourceType = 'DATAELEMENT_NEWEST_EVENT_PROGRAM_STAGE'
            }
            elseif ($DataElementId) {
                  if (-not $SourceType) {
                        Write-Error "The SourceType parameter must be set if the DataElementId parameter is set."
                        return
                  }
                  $obj.dataElement = @{ id = $DataElementId }
                  $obj.programRuleVariableSourceType = $SourceType
            }
            elseif ($ValueType) {
                  $obj.valueType = $ValueType
                  $obj.programRuleVariableSourceType = 'CALCULATED_VALUE'
            }
            else {
                  return
            }
            if ($UseCodeForOptionSet) { $obj.useCodeForOptionSet = $UseCodeForOptionSet.ToString() }
            if ($Code) { $obj.code = $Code }
            return $obj
      }
}

function New-Dhis2ProgramRule {
      [CmdletBinding()]
      param (
            [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName)]
            [ValidateScript({ [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  "See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$ProgramId,

            [Parameter(Position = 1, Mandatory, ValueFromPipelineByPropertyName)]
            [ValidateLength(1,230)]
            [string]$Name,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateScript({ if ([string]::IsNullOrEmpty($_)) { $true } else { [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') } },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  "See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$Id,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateScript({ if ([string]::IsNullOrEmpty($_)) { $true } else { [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') } },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  "See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$ProgramStageId,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateLength(0,255)]
            [string]$Description,

            [Parameter(ValueFromPipelineByPropertyName)]
            [System.Nullable[int]]$Priority,

            [Parameter(ValueFromPipelineByPropertyName)]
            [string]$Condition,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateLength(0,50)]
            [string]$Code,

            [Parameter(ValueFromPipelineByPropertyName)]
            [System.Collections.Hashtable[]]$ProgramRuleActions
      )

      process {
            if (-not  $ProgramId) { return }
            if (-not  $Name) { return }
            $obj = @{
                  program = @{ id = $ProgramId }
                  name = $Name
            }
            if ($Id) { $obj.id = $Id }
            if ($ProgramStageId) {
                  $obj.programStage = @{ id = $ProgramStageId }
            }
            if ($Description) { $obj.description = $Description }
            if ($null -ne $Priority) { $obj.priority = $Priority.ToString([System.Globalization.NumberFormatInfo]::InvariantInfo) }
            if ($Condition) { $obj.condition = $Condition }
            if ($Code) { $obj.code = $Code }
            if ($ProgramRuleActions) { $obj.programRuleActions = $ProgramRuleActions }else{$obj.programRuleActions=[System.Collections.Hashtable[]]@()}
            return $obj
      }
}

function New-Dhis2ProgramRuleAction {
      [CmdletBinding(DefaultParameterSetName = 'AssignProgramRuleVariable')]
      param (
            [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName)]
            [ValidateScript({ [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  "See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$Id,

            [Parameter(Position = 1, Mandatory, ValueFromPipelineByPropertyName)]
            [ValidateScript({ [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  "See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$ProgramRuleId,

            [Parameter(Position = 2, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'AssignProgramRuleVariable')]
            [string]$Content,

            [Parameter(Position = 3, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'AssignProgramRuleVariable')]
            [string]$Data,

            [Parameter(Position = 2, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'HideProgramStageSection')]
            [ValidateScript({ [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  "See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$ProgramStageSectionId,

            [Parameter(Position = 2, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'DataElement')]
            [ValidateScript({ [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  "See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$DataElementId,

            [Parameter(Position = 3, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'DataElement')]
            [ValidateSet('HIDEFIELD', 'SETMANDATORYFIELD')]
            [string]$Type,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateScript({ if ([string]::IsNullOrEmpty($_)) { $true } else { [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') } },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  "See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$ProgramStageId,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateLength(0,50)]
            [string]$Code
      )

      process {
            if (-not  $Id) { return }
            if (-not  $ProgramRuleId) { return }
            $obj = @{
                  id = $Id
                  programRule = @{ id = $ProgramRuleId }
            }
            if ($ProgramStageId) {
                  $obj.programStage = @{ id = $ProgramStageId }
            }
            if ($Content) {
                  if (-not $Data) {
                        Write-Error "The Data parameter must be set if the Content parameter is set."
                        return
                  }
                  $obj.content = $Content
                  $obj.data = $Data
                  $obj.programRuleActionType = 'ASSIGN'
            }
            if ($ProgramStageSectionId) {
                  $obj.programStageSection = @{ id = $ProgramStageSectionId }
                  $obj.programRuleActionType = 'HIDESECTION'
            }
            if ($DataElementId) {
                  if (-not $Type) {
                        Write-Error "The Type parameter must be set if the DataElementId parameter is set."
                        return
                  }
                  $obj.dataElement = @{ id = $DataElementId }
                  $obj.programRuleActionType = $Type
            }
            if ($Code) { $obj.code = $Code }
            return $obj
      }
}

function New-Dhis2Program {
      [CmdletBinding()]
      param (

            [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName)]
            [ValidateSet('WITH_REGISTRATION','WITHOUT_REGISTRATION')]
            [string]$ProgramType,

            [Parameter(Position = 1, Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'The proram name.')]
            [ValidateLength(1,230)]
            [string]$Name,

            [Parameter(Position = 2, Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'The short name of the program.')]
            [ValidateLength(1,50)]
            [string]$ShortName,

            [Parameter(Position = 3, Mandatory, ValueFromPipelineByPropertyName)]
            [ValidateScript({ [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  "See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$TrackedEntityTypeId,

            [Parameter(Position = 4, Mandatory, ValueFromPipelineByPropertyName)]
            [ValidateSet('OPEN','AUDITED','PROTECTED','CLOSED')]
            [string]$AccessLevel,

            [Parameter(ValueFromPipelineByPropertyName, HelpMessage = 'The code of the program.')]
            [ValidateLength(0,50)]
            [string]$Code,

            [Parameter(ValueFromPipelineByPropertyName, HelpMessage = 'The description of the program.')]
            [string]$Description,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$DisplayFrontPageList,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$UseFirstStageDuringRegistration,

            [Parameter(ValueFromPipelineByPropertyName)]
            [System.Nullable[uint]]$CompleteEventsExpiryDays,

            [Parameter(ValueFromPipelineByPropertyName)]
            [System.Nullable[uint]]$ExpiryDays,

            [Parameter(ValueFromPipelineByPropertyName)]
            [System.Nullable[uint]]$MinAttributesRequiredToSearch,

            [Parameter(ValueFromPipelineByPropertyName)]
            [System.Nullable[uint]]$MaxTeiCountToReturn,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$OnlyEnrollOnce,

            # We might want to have a separate generator function for this
            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateScript({if($null -eq $_){$true} else {foreach($att in @($_)){if(-not [System.Text.RegularExpressions.Regex]::IsMatch($att.trackedEntityAttribute.id, '^[A-Za-z][A-Za-z0-9]{10}$')){throw}}}$true},
            ErrorMessage = 'The value ''{0}'' is not valid as DHIS2 programTrackedEntityAttributes.')]
            [object[]]$ProgramTrackedEntityAttributes,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateScript({if($null -eq $_){$true}else{foreach($att in $_){if(-not [System.Text.RegularExpressions.Regex]::IsMatch($att, '^[A-Za-z][A-Za-z0-9]{10}$')){throw}}}$true},
            ErrorMessage = 'The value ''{0}'' contains an invalid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  'See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers')]
            [string[]]$ProgramStageIds,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateScript({if($null -eq $_){$true}else{foreach($att in $_){if(-not [System.Text.RegularExpressions.Regex]::IsMatch($att, '^[A-Za-z][A-Za-z0-9]{10}$')){throw}}}$true},
            ErrorMessage = 'The value ''{0}'' contains an invalid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  'See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers')]
            [string[]]$OrganisationUnitIds,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateSet($null,'BI_MONTHLY','BI_WEEKLY','DAILY','FINANCIAL_APRIL',`
                  'FINANCIAL_JULY','FINANCIAL_NOV','FINANCIAL_OCT','MONTHLY',`
                  'QUARTERLY','SIX_MONTHLY_APRIL','SIX_MONTHLY_NOV','SIX_MONTHLY',`
                  'TWO_YEARLY','WEEKLY','WEEKLY_SATURDAY','WEEKLY_SUNDAY','WEEKLY_THURSDAY',`
                  'WEEKLY_WEDNESDAY','YEARLY')]
            [string]$ExpiryPeriodType,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$DisplayIncidentDate,

            [Parameter(ValueFromPipelineByPropertyName)]
            [string]$EnrollmentDateLabel,

            [Parameter(ValueFromPipelineByPropertyName)]
            [string]$FormName,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateSet('','NONE','MULTI_POLYGON','POLYGON','POINT','SYMBOL')]
            [string]$FeatureType,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$IgnoreOverdueEvents,

            [Parameter(ValueFromPipelineByPropertyName)]
            [string]$IncidentDateLabel,

            [Parameter(ValueFromPipelineByPropertyName)]
            [System.Nullable[int]]$OpenDaysAfterCoEndDate,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$SelectEnrollmentDatesInFuture,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$SelectIncidentDatesInFuture,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$SkipOffline,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateScript({ if ([string]::IsNullOrEmpty($_)) { $true } else { [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') } },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  'See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers')]
            [string]$Id
      )

      process {
            if (-not  $ProgramType) { return }
            if (-not  $Name) { return }
            if (-not  $ShortName) { return }
            if (-not  $TrackedEntityTypeId) { return }
            if (-not  $AccessLevel) { return }
            $obj = @{
                  programType = $ProgramType
                  name = $Name
                  shortName = $ShortName
                  trackedEntityType = @{ id = $TrackedEntityTypeId }
                  accessLevel = $AccessLevel
                  # Hard-code a few properties we don't use for now
                  categoryCombo = @{ id = 'bjDvmb4bfuf' }
                  notificationTemplates = @()
                  programSections = @()
                  # Always pass this since the default is true.
                  displayIncidentDate = $DisplayIncidentDate.ToString()
            }
            if ($Code) { $obj.code = $Code }
            if ($Description) { $obj.description = $Description }
            if ($DisplayFrontPageList) { $obj.displayFrontPageList = $DisplayFrontPageList.ToString() }
            if ($UseFirstStageDuringRegistration) { $obj.useFirstStageDuringRegistration = $UseFirstStageDuringRegistration.ToString() }
            if ($null -ne $CompleteEventsExpiryDays) { $obj.completeEventsExpiryDays = $CompleteEventsExpiryDays.ToString([System.Globalization.NumberFormatInfo]::InvariantInfo) }
            if ($null -ne $ExpiryDays) { $obj.expiryDays = $ExpiryDays.ToString([System.Globalization.NumberFormatInfo]::InvariantInfo) }
            if ($null -ne $MinAttributesRequiredToSearch) { $obj.minAttributesRequiredToSearch = $MinAttributesRequiredToSearch.ToString([System.Globalization.NumberFormatInfo]::InvariantInfo) }
            if ($null -ne $MaxTeiCountToReturn) { $obj.maxTeiCountToReturn = $MaxTeiCountToReturn.ToString([System.Globalization.NumberFormatInfo]::InvariantInfo) }
            if ($OnlyEnrollOnce) { $obj.onlyEnrollOnce = $OnlyEnrollOnce.ToString() }
            if ($ProgramTrackedEntityAttributes) { $obj.programTrackedEntityAttributes = $ProgramTrackedEntityAttributes }
            if ($ProgramStageIds) { $obj.programStages = @( $ProgramStageIds | ForEach-Object{ @{ id = $_ } } ) }
            if ($OrganisationUnitIds) { $obj.organisationUnits = @( $OrganisationUnitIds | ForEach-Object{ @{ id = $_ } } ) }
            if ($ExpiryPeriodType) { $obj.expiryPeriodType = $ExpiryPeriodType }
            if ($EnrollmentDateLabel) { $obj.enrollmentDateLabel = $EnrollmentDateLabel }
            if ($FormName) { $obj.formName = $FormName }
            if ($FeatureType) { $obj.featureType = $FeatureType }
            if ($IgnoreOverdueEvents) { $obj.ignoreOverdueEvents = $IgnoreOverdueEvents.ToString() }
            if ($IncidentDateLabel) { $obj.incidentDateLabel = $IncidentDateLabel }
            if ($null -ne $OpenDaysAfterCoEndDate) { $obj.openDaysAfterCoEndDate = $OpenDaysAfterCoEndDate.ToString([System.Globalization.NumberFormatInfo]::InvariantInfo) }
            if ($SelectEnrollmentDatesInFuture) { $obj.selectEnrollmentDatesInFuture = $SelectEnrollmentDatesInFuture.ToString() }
            if ($SelectIncidentDatesInFuture) { $obj.selectIncidentDatesInFuture = $SelectIncidentDatesInFuture.ToString() }
            if ($SkipOffline) { $obj.skipOffline = $SkipOffline.ToString() }
            if ($Id) { $obj.id = $Id }
            return $obj
      }
}

function ConvertTo-Dhis2Program {
      [CmdletBinding()]
      param (
            [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
            [object]$InputObject,

            [Parameter()]
            [System.Collections.Hashtable]$TrackedEntityTypeCodeMap,

            [Parameter()]
            [System.Collections.Hashtable]$TrackedEntityTypeNameMap
      )
      process {
            if ($InputObject.trackedEntityType_id) {
                  $trackedEntityTypeId = $InputObject.trackedEntityType_id
            } elseif ($InputObject.trackedEntityTypeId) {
                  $trackedEntityTypeId = $InputObject.trackedEntityTypeId
            } elseif ($TrackedEntityTypeCodeMap -and $InputObject.trackedEntityType_code) {
                  $trackedEntityTypeId = $TrackedEntityTypeCodeMap[$InputObject.trackedEntityType_code]
            } elseif ($TrackedEntityTypeCodeMap -and $InputObject.trackedEntityTypeCode) {
                  $trackedEntityTypeId = $TrackedEntityTypeCodeMap[$InputObject.trackedEntityTypeCode]
            } elseif ($TrackedEntityTypeNameMap -and $InputObject.trackedEntityType_name) {
                  $trackedEntityTypeId = $TrackedEntityTypeNameMap[$InputObject.trackedEntityType_name]
            } elseif ($TrackedEntityTypeNameMap -and $InputObject.trackedEntityTypeName) {
                  $trackedEntityTypeId = $TrackedEntityTypeNameMap[$InputObject.trackedEntityTypeName]
            } else {
                  $trackedEntityTypeId = $null
            }
            $argHash = @{
                  Id = $InputObject.id
                  Code = $InputObject.code
                  AccessLevel = $InputObject.accessLevel
                  CompleteEventsExpiryDays = $InputObject.completeEventsExpiryDays
                  Description = $InputObject.description
                  DisplayFrontPageList = [System.Convert]::ToBoolean($InputObject.displayFrontPageList)
                  DisplayIncidentDate = [System.Convert]::ToBoolean($InputObject.displayIncidentDate)
                  EnrollmentDateLabel = $InputObject.enrollmentDateLabel
                  ExpiryDays = $InputObject.expiryDays
                  ExpiryPeriodType = if($InputObject.expiryPeriodType){$InputObject.expiryPeriodType}
                  FeatureType = $InputObject.featureType
                  FormName = $InputObject.formName
                  IgnoreOverdueEvents = [System.Convert]::ToBoolean($InputObject.ignoreOverdueEvents)
                  IncidentDateLabel = $InputObject.incidentDateLabel
                  MaxTeiCountToReturn = $InputObject.maxTeiCountToReturn
                  MinAttributesRequiredToSearch = $InputObject.minAttributesRequiredToSearch
                  Name = $InputObject.name
                  OnlyEnrollOnce = [System.Convert]::ToBoolean($InputObject.onlyEnrollOnce)
                  OpenDaysAfterCoEndDate = $InputObject.openDaysAfterCoEndDate
                  ProgramType = $InputObject.programType
                  SelectEnrollmentDatesInFuture = [System.Convert]::ToBoolean($InputObject.selectEnrollmentDatesInFuture)
                  SelectIncidentDatesInFuture = [System.Convert]::ToBoolean($InputObject.selectIncidentDatesInFuture)
                  ShortName = $InputObject.shortName
                  SkipOffline = [System.Convert]::ToBoolean($InputObject.skipOffline)
                  UseFirstStageDuringRegistration = [System.Convert]::ToBoolean($InputObject.useFirstStageDuringRegistration)
                  TrackedEntityTypeId = $trackedEntityTypeId
              }
              New-Dhis2Program @argHash
      }
}

function New-Dhis2ProgramTrackedEntityAttribute {
      [CmdletBinding()]
      param (
            [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
            [ValidateScript({ [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  "See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$TrackedEntityAttributeId,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$DisplayInList,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$Mandatory,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$Searchable,

            [Parameter(ValueFromPipelineByPropertyName)]
            [System.Nullable[int]]$SortOrder,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateScript({ if ([string]::IsNullOrEmpty($_)) { $true } else { [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') } },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  'See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers')]
            [string]$ProgramId,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateScript({ if ([string]::IsNullOrEmpty($_)) { $true } else { [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') } },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  'See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers')]
            [string]$Id
      )

      process {
            if (-not  $TrackedEntityAttributeId) { return }
            $obj = @{
                  trackedEntityAttribute = @{ id = $TrackedEntityAttributeId }
            }
            if ($DisplayInList) { $obj.displayInList = $DisplayInList.ToString() }
            if ($Mandatory) { $obj.mandatory = $Mandatory.ToString() }
            if ($Searchable) { $obj.searchable = $Searchable.ToString() }
            if ($null -ne $SortOrder) { $obj.sortOrder = $SortOrder.ToString([System.Globalization.NumberFormatInfo]::InvariantInfo) }
            if ($ProgramId) { $obj.program = @{ id = $ProgramId } }
            if ($Id) { $obj.id = $Id }
            return $obj
      }
}

function New-Dhis2ProgramStage {
      [CmdletBinding()]
      param (
            [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'The proram stage name.')]
            [ValidateLength(1,230)]
            [string]$Name,

            [Parameter(Position = 1, Mandatory, ValueFromPipelineByPropertyName)]
            [ValidateScript({ [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  'See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers')]
            [string]$ProgramId,

            [Parameter(ValueFromPipelineByPropertyName, HelpMessage = 'The description of the program stage.')]
            [string]$Description,

            [Parameter(ValueFromPipelineByPropertyName)]
            [System.Nullable[uint]]$MinDaysFromStart,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateSet($null,'BI_MONTHLY','BI_WEEKLY','DAILY','FINANCIAL_APRIL',`
                  'FINANCIAL_JULY','FINANCIAL_NOV','FINANCIAL_OCT','MONTHLY',`
                  'QUARTERLY','SIX_MONTHLY_APRIL','SIX_MONTHLY_NOV','SIX_MONTHLY',`
                  'TWO_YEARLY','WEEKLY','WEEKLY_SATURDAY','WEEKLY_SUNDAY','WEEKLY_THURSDAY',`
                  'WEEKLY_WEDNESDAY','YEARLY')]
            [string]$PeriodType,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$Repeatable,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$DisplayGenerateEventBox,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$AutoGenerateEvent,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$OpenAfterEnrollment,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$EnableUserAssignment,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$BlockEntryForm,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$RemindCompleted,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$AllowGenerateNextVisit,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$GeneratedByEnrollmentDate,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$HideDueDate,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$PreGenerateUID,

            [Parameter(ValueFromPipelineByPropertyName)]
            [System.Nullable[int]]$SortOrder,

            [Parameter(ValueFromPipelineByPropertyName)]
            [string]$DueDateLabel,

            [Parameter(ValueFromPipelineByPropertyName)]
            [string]$ExecutionDateLabel,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateSet('NONE','MULTI_POLYGON','POLYGON','POINT','SYMBOL')]
            [string]$FeatureType,

            [Parameter(ValueFromPipelineByPropertyName)]
            [string]$FormName,

            [Parameter(ValueFromPipelineByPropertyName)]
            [string]$ReportDateToUse,

            [Parameter(ValueFromPipelineByPropertyName)]
            [System.Nullable[int]]$StandardInterval,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateSet('ON_COMPLETE','ON_UPDATE_AND_INSERT')]
            [string]$ValidationStrategy,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateScript({if($null -eq $_){$true} else {foreach($att in @($_)){if(-not [System.Text.RegularExpressions.Regex]::IsMatch($att.dataElement.id, '^[A-Za-z][A-Za-z0-9]{10}$')){throw}}}$true},
            ErrorMessage = 'The value ''{0}'' is not valid as DHIS2 programTrackedEntityAttributes.')]
            [object[]]$ProgramStageDataElements,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateScript({if($null -eq $_){$true}else{foreach($att in $_){if(-not [System.Text.RegularExpressions.Regex]::IsMatch($att, '^[A-Za-z][A-Za-z0-9]{10}$')){throw}}}$true},
            ErrorMessage = 'The value ''{0}'' contains an invalid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  'See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers')]
            [string[]]$ProgramStageSectionIds,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateScript({ if ([string]::IsNullOrEmpty($_)) { $true } else { [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') } },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  'See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers')]
            [string]$Id
      )

      process {
            if (-not  $Name) { return }
            if (-not  $ProgramId) { return }
            $obj = @{
                  name = $Name
                  program = @{ id = $ProgramId }
                  # Always pass the following flags since the DHIS2 default is true
                  displayGenerateEventBox = $DisplayGenerateEventBox.ToString()
                  autoGenerateEvent = $AutoGenerateEvent.ToString()
            }
            if ($Description) { $obj.description = $Description }
            if ($null -ne $MinDaysFromStart) { $obj.minDaysFromStart = $MinDaysFromStart.ToString([System.Globalization.NumberFormatInfo]::InvariantInfo) }
            if ($PeriodType) { $obj.periodType = $PeriodType }
            if ($Repeatable) { $obj.repeatable = $Repeatable.ToString() }
            if ($OpenAfterEnrollment) { $obj.openAfterEnrollment = $OpenAfterEnrollment.ToString() }
            if ($EnableUserAssignment) { $obj.enableUserAssignment = $EnableUserAssignment.ToString() }
            if ($BlockEntryForm) { $obj.blockEntryForm = $BlockEntryForm.ToString() }
            if ($RemindCompleted) { $obj.remindCompleted = $RemindCompleted.ToString() }
            if ($AllowGenerateNextVisit) { $obj.allowGenerateNextVisit = $AllowGenerateNextVisit.ToString() }
            if ($GeneratedByEnrollmentDate) { $obj.generatedByEnrollmentDate = $GeneratedByEnrollmentDate.ToString() }
            if ($HideDueDate) { $obj.hideDueDate = $HideDueDate.ToString() }
            if ($PreGenerateUID) { $obj.preGenerateUID = $PreGenerateUID.ToString() }
            if ($null -ne $SortOrder) { $obj.sortOrder = $SortOrder.ToString([System.Globalization.NumberFormatInfo]::InvariantInfo) }
            if ($ProgramStageDataElements) { $obj.programStageDataElements = $ProgramStageDataElements }
            if ($ProgramStageSectionIds) { $obj.programStageSections = @( $ProgramStageSectionIds | ForEach-Object{ @{ id = $_ } } ) }
            if ($DueDateLabel) { $obj.dueDateLabel = $DueDateLabel }
            if ($ExecutionDateLabel) { $obj.executionDateLabel = $ExecutionDateLabel }
            if ($FeatureType) { $obj.featureType = $FeatureType }
            if ($FormName) { $obj.formName = $FormName }
            if ($ReportDateToUse) { $obj.reportDateToUse = $ReportDateToUse }
            if ($null -ne $StandardInterval) { $obj.standardInterval = $StandardInterval.ToString([System.Globalization.NumberFormatInfo]::InvariantInfo) }
            if ($ValidationStrategy) { $obj.validationStrategy = $ValidationStrategy }
            if ($Id) { $obj.id = $Id }
            return $obj
      }
}

function ConvertTo-Dhis2ProgramStage {
      [CmdletBinding()]
      param (
            [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
            [object]$InputObject,

            [Parameter()]
            [System.Collections.Hashtable]$ProgramCodeMap
      )
      process {
            if ($InputObject.program_id) {
                  $programId = $InputObject.program_id
            } elseif ($InputObject.programId) {
                  $programId = $InputObject.programId
            } elseif ($ProgramCodeMap -and $InputObject.program_code) {
                  $programId = $ProgramCodeMap[$InputObject.program_code]
            } elseif ($ProgramCodeMap -and $InputObject.programCode) {
                  $programId = $ProgramCodeMap[$InputObject.programCode]
            } else {
                  $programId = $null
            }
            $argHash = @{
                  ProgramId = $programId
                  Name = $InputObject.name
                  AllowGenerateNextVisit = [System.Convert]::ToBoolean($InputObject.allowGenerateNextVisit)
                  AutoGenerateEvent = [System.Convert]::ToBoolean($InputObject.autoGenerateEvent)
                  BlockEntryForm = [System.Convert]::ToBoolean($InputObject.blockEntryForm)
                  Description = $InputObject.description
                  DisplayGenerateEventBox = [System.Convert]::ToBoolean($InputObject.displayGenerateEventBox)
                  DueDateLabel = $InputObject.dueDateLabel
                  EnableUserAssignment = [System.Convert]::ToBoolean($InputObject.enableUserAssignment)
                  ExecutionDateLabel = $InputObject.executionDateLabel
                  FeatureType = if($InputObject.periodType){$InputObject.featureType}else{'NONE'}
                  FormName = $InputObject.formName
                  GeneratedByEnrollmentDate = [System.Convert]::ToBoolean($InputObject.generatedByEnrollmentDate)
                  HideDueDate = [System.Convert]::ToBoolean($InputObject.hideDueDate)
                  MinDaysFromStart = $InputObject.minDaysFromStart
                  OpenAfterEnrollment = [System.Convert]::ToBoolean($InputObject.openAfterEnrollment)
                  PeriodType = if($InputObject.periodType){$InputObject.periodType}
                  PreGenerateUID = [System.Convert]::ToBoolean($InputObject.preGenerateUID)
                  RemindCompleted = [System.Convert]::ToBoolean($InputObject.remindCompleted)
                  Repeatable = [System.Convert]::ToBoolean($InputObject.repeatable)
                  ReportDateToUse = $InputObject.reportDateToUse
                  SortOrder = $InputObject.sortOrder
                  StandardInterval = $InputObject.standardInterval
                  ValidationStrategy = $InputObject.validationStrategy
              }
              New-Dhis2ProgramStage @argHash
      }
}

function New-Dhis2ProgramStageDataElement {
      [CmdletBinding(DefaultParameterSetName = 'Searchable')]
      param (
            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateScript({ [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  'See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers')]
            [string]$ProgramId,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateScript({ [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  'See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers')]
            [string]$ProgramStageId,

            [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
            [ValidateScript({ [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  "See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$DataElementId,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$AllowFutureDate,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$AllowProvidedElsewhere,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$Compulsory,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$DisplayInReports,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateSet('DEFAULT','DROPDOWN','VERTICAL_RADIOBUTTONS','HORIZONTAL_RADIOBUTTONS',`
                  'VERTICAL_CHECKBOXES','HORIZONTAL_CHECKBOXES','SHARED_HEADER_RADIOBUTTONS',`
                  'ICONS_AS_BUTTONS','SPINNER','ICON','TOGGLE','VALUE','SLIDER','LINEAR_SCALE',`
                  'AUTOCOMPLETE','QR_CODE','BAR_CODE','GS1_DATAMATRIX')]
            [string]$DesktopRenderType = 'DEFAULT',

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateSet('DEFAULT','DROPDOWN','VERTICAL_RADIOBUTTONS','HORIZONTAL_RADIOBUTTONS',`
                  'VERTICAL_CHECKBOXES','HORIZONTAL_CHECKBOXES','SHARED_HEADER_RADIOBUTTONS',`
                  'ICONS_AS_BUTTONS','SPINNER','ICON','TOGGLE','VALUE','SLIDER','LINEAR_SCALE',`
                  'AUTOCOMPLETE','QR_CODE','BAR_CODE','GS1_DATAMATRIX')]
            [string]$MobileRenderType = 'DEFAULT',

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$RenderOptionsAsRadio,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$SkipAnalytics,

            [Parameter(ValueFromPipelineByPropertyName)]
            [switch]$SkipSynchronization,

            [Parameter(ValueFromPipelineByPropertyName)]
            [string]$ExecutionDateLabel,

            [Parameter(ValueFromPipelineByPropertyName)]
            [System.Nullable[int]]$SortOrder,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateScript({ if ([string]::IsNullOrEmpty($_)) { $true } else { [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') } },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  'See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers')]
            [string]$Id
      )

      process {
            if (-not  $ProgramId) { return }
            if (-not  $ProgramStageId) { return }
            if (-not  $DataElementId) { return }
            $obj = @{
                  program = @{ id = $ProgramId }
                  programStage = @{ id = $ProgramStageId }
                  dataElement = @{ id = $DataElementId }
            }
            if ($AllowFutureDate) { $obj.allowFutureDate = $AllowFutureDate.ToString() }
            if ($AllowProvidedElsewhere) { $obj.allowProvidedElsewhere = $AllowProvidedElsewhere.ToString() }
            if ($Compulsory) { $obj.compulsory = $Compulsory.ToString() }
            if ($DisplayInReports) { $obj.displayInReports = $DisplayInReports.ToString() }
            if ($DesktopRenderType -and $MobileRenderType) { $obj.renderType = @{ DESKTOP = @{ type = $DesktopRenderType }; MOBILE = @{ type = $MobileRenderType } } }
            elseif ($DesktopRenderType) { $obj.renderType = @{ DESKTOP = @{ type = $DesktopRenderType } } }
            elseif ($MobileRenderType) { $obj.renderType = @{ MOBILE = @{ type = $MobileRenderType } } }
            if ($RenderOptionsAsRadio) { $obj.renderOptionsAsRadio = $RenderOptionsAsRadio.ToString() }
            if ($SkipAnalytics) { $obj.skipAnalytics = $SkipAnalytics.ToString() }
            if ($SkipSynchronization) { $obj.skipSynchronization = $SkipSynchronization.ToString() }
            if ($ExecutionDateLabel) { $obj.executionDateLabel = $ExecutionDateLabel }
            if ($null -ne $SortOrder) { $obj.sortOrder = $SortOrder.ToString([System.Globalization.NumberFormatInfo]::InvariantInfo) }
            if ($Id) { $obj.id = $Id }
            return $obj
      }
}

function ConvertTo-Dhis2ProgramStageDataElement {
      [CmdletBinding()]
      param (
            [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
            [object]$InputObject,

            [Parameter()]
            [System.Collections.Hashtable]$ProgramCodeMap,

            [Parameter()]
            [System.Collections.Hashtable]$ProgramStageNameMap,

            [Parameter()]
            [System.Collections.Hashtable]$DataElementCodeMap
      )
      process {
            if ($InputObject.program_id) {
                  $programId = $InputObject.program_id
            } elseif ($InputObject.programId) {
                  $programId = $InputObject.programId
            } elseif ($ProgramCodeMap -and $InputObject.program_code) {
                  $programId = $ProgramCodeMap[$InputObject.program_code]
                  if (-not $programId){Write-Error "Failed to find the id for program '$($InputObject.program_code)'."}
            } elseif ($ProgramCodeMap -and $InputObject.programCode) {
                  $programId = $ProgramCodeMap[$InputObject.programCode]
                  if (-not $programId){Write-Error "Failed to find the id for program '$($InputObject.programCode)'."}
            } else {
                  $programId = $null
            }
            if ($InputObject.programStage_id) {
                  $programStageId = $InputObject.programStage_id
            } elseif ($InputObject.programStageId) {
                  $programStageId = $InputObject.programStageId
            } elseif ($ProgramStageNameMap -and $InputObject.programStage_name) {
                  $programStageId = $ProgramStageNameMap[$InputObject.programStage_name]
                  if (-not $programStageId){Write-Error "Failed to find the id for program stage '$($InputObject.programStage_name)'."}
            } elseif ($ProgramStageNameMap -and $InputObject.programStageName) {
                  $programStageId = $ProgramStageNameMap[$InputObject.programStageName]
                  if (-not $programStageId){Write-Error "Failed to find the id for program stage '$($InputObject.programStageName)'."}
            } else {
                  $programStageId = $null
            }
            if ($InputObject.dataElement_id) {
                  $dataElementId = $InputObject.dataElement_id
            } elseif ($InputObject.dataElementId) {
                  $dataElementId = $InputObject.dataElementId
            } elseif ($DataElementCodeMap -and $InputObject.dataElement_code) {
                  $dataElementId = $DataElementCodeMap[$InputObject.dataElement_code]
                  if (-not $dataElementId){Write-Error "Failed to find the id for data element '$($InputObject.dataElement_code)'."}
            } elseif ($DataElementCodeMap -and $InputObject.dataElementCode) {
                  $dataElementId = $DataElementCodeMap[$InputObject.dataElementCode]
                  if (-not $dataElementId){Write-Error "Failed to find the id for data element '$($InputObject.dataElementCode)'."}
            } else {
                  $dataElementId = $null
            }
            if ($InputObject.DesktopRenderType) {
                  $DesktopRenderType = $InputObject.DesktopRenderType
            } elseif ($InputObject.RenderType_Desktop) {
                  $DesktopRenderType = $InputObject.RenderType_Desktop
            } else {
                  $DesktopRenderType = 'DEFAULT'
            }
            if ($InputObject.MobileRenderType) {
                  $MobileRenderType = $InputObject.MobileRenderType
            } elseif ($InputObject.RenderType_Mobile) {
                  $MobileRenderType = $InputObject.RenderType_Mobile
            } else {
                  $MobileRenderType = 'DEFAULT'
            }
            $argHash = @{
                  ProgramId = $programId
                  ProgramStageId = $programStageId
                  DataElementId = $dataElementId
                  AllowFutureDate = [System.Convert]::ToBoolean($InputObject.allowFutureDate)
                  AllowProvidedElsewhere = [System.Convert]::ToBoolean($InputObject.allowProvidedElsewhere)
                  Compulsory = [System.Convert]::ToBoolean($InputObject.compulsory)
                  DisplayInReports = [System.Convert]::ToBoolean($InputObject.displayInReports)
                  RenderOptionsAsRadio = [System.Convert]::ToBoolean($InputObject.renderOptionsAsRadio)
                  DesktopRenderType = $DesktopRenderType
                  MobileRenderType = $MobileRenderType
                  SkipAnalytics = [System.Convert]::ToBoolean($InputObject.skipAnalytics)
                  SkipSynchronization = [System.Convert]::ToBoolean($InputObject.skipSynchronization)
                  ExecutionDateLabel = $InputObject.executionDateLabel
                  SortOrder = $InputObject.sortOrder
              }
              New-Dhis2ProgramStageDataElement @argHash
      }
}

function New-Dhis2ProgramStageSection {
      [CmdletBinding()]
      param (
            [Parameter(Position = 1, Mandatory, ValueFromPipelineByPropertyName)]
            [ValidateScript({ [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  "See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers")]
            [string]$ProgramStageId,

            [Parameter(Position = 2, Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'The proram stage section name.')]
            [ValidateLength(1,230)]
            [string]$Name,

            [Parameter(ValueFromPipelineByPropertyName, HelpMessage = 'The description of the program stage section.')]
            [string]$Description,

            [Parameter(ValueFromPipelineByPropertyName, HelpMessage = 'The form name of the program stage section.')]
            [string]$FormName,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateScript({if($null -eq $_){$true}else{foreach($att in $_){if(-not [System.Text.RegularExpressions.Regex]::IsMatch($att, '^[A-Za-z][A-Za-z0-9]{10}$')){throw}}}$true},
            ErrorMessage = 'The value ''{0}'' contains an invalid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  'See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers')]
            [string[]]$DataElementIds,

            [Parameter(ValueFromPipelineByPropertyName)]
            [System.Nullable[int]]$SortOrder,

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateSet('LISTING','SEQUENTIAL','MATRIX')]
            [string]$DesktopRenderType = 'LISTING',

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateSet('LISTING','SEQUENTIAL','MATRIX')]
            [string]$MobileRenderType = 'LISTING',

            [Parameter(ValueFromPipelineByPropertyName)]
            [ValidateScript({ if ([string]::IsNullOrEmpty($_)) { $true } else { [System.Text.RegularExpressions.Regex]::IsMatch($_, '^[A-Za-z][A-Za-z0-9]{10}$') } },
            ErrorMessage = 'The value ''{0}'' is not a valid DHIS2 id. DHIS2 ids must be 11 characters long, ' +
                  'consist of alphanumeric characters (A-Za-z0-9) only, and start with an alphabetic character (A-Za-z). ' +
                  'See: https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-master/maintenance.html#webapi_system_resource_generate_identifiers')]
            [string]$Id
      )

      process {
            if (-not  $ProgramStageId) { return }
            if (-not  $Name) { return }
            $obj = @{
                  program = @{ id = $ProgramId }
                  programStage = @{ id = $ProgramStageId }
                  name = $Name
                  # Hard-coded default for now
                  programIndicators = @()
            }
            #program_code,formName
            if ($Description) { $obj.description = $Description }
            if ($FormName) { $obj.formName = $FormName }
            if ($DataElementIds) { $obj.dataElements = @( $DataElementIds | ForEach-Object{ @{ id = $_ } } ) }
            if ($null -ne $SortOrder) { $obj.sortOrder = $SortOrder.ToString([System.Globalization.NumberFormatInfo]::InvariantInfo) }
            if ($DesktopRenderType -and $MobileRenderType) { $obj.renderType = @{ DESKTOP = @{ type = $DesktopRenderType }; MOBILE = @{ type = $MobileRenderType } } }
            elseif ($DesktopRenderType) { $obj.renderType = @{ DESKTOP = @{ type = $DesktopRenderType } } }
            elseif ($MobileRenderType) { $obj.renderType = @{ MOBILE = @{ type = $MobileRenderType } } }
            if ($Id) { $obj.id = $Id }
            return $obj
      }
}

function ConvertTo-Dhis2ProgramStageSection {
      [CmdletBinding()]
      param (
            [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
            [object]$InputObject,

            [Parameter()]
            [System.Collections.Hashtable]$ProgramCodeMap,

            [Parameter()]
            [System.Collections.Hashtable]$ProgramStageNameMap
      )
      process {
            if ($InputObject.programStage_id) {
                  $programStageId = $InputObject.programStage_id
            } elseif ($InputObject.programStageId) {
                  $programStageId = $InputObject.programStageId
            } elseif ($ProgramStageNameMap -and $InputObject.programStage_name) {
                  $programStageId = $ProgramStageNameMap[$InputObject.programStage_name]
                  if (-not $programStageId){Write-Error "Failed to find the id for program stage '$($InputObject.programStage_name)'."}
            } elseif ($ProgramStageNameMap -and $InputObject.programStageName) {
                  $programStageId = $ProgramStageNameMap[$InputObject.programStageName]
                  if (-not $programStageId){Write-Error "Failed to find the id for program stage '$($InputObject.programStageName)'."}
            } else {
                  $programStageId = $null
            }
            if ($InputObject.DesktopRenderType) {
                  $DesktopRenderType = $InputObject.DesktopRenderType
            } elseif ($InputObject.RenderType_Desktop) {
                  $DesktopRenderType = $InputObject.RenderType_Desktop
            } else {
                  $DesktopRenderType = 'LISTING'
            }
            if ($InputObject.MobileRenderType) {
                  $MobileRenderType = $InputObject.MobileRenderType
            } elseif ($InputObject.RenderType_Mobile) {
                  $MobileRenderType = $InputObject.RenderType_Mobile
            } else {
                  $MobileRenderType = 'LISTING'
            }
            $argHash = @{
                  ProgramStageId = $programStageId
                  Name = $InputObject.name
                  Description = $InputObject.description
                  FormName = $InputObject.formName
                  DesktopRenderType = $DesktopRenderType
                  MobileRenderType = $MobileRenderType
                  SortOrder = $InputObject.sortOrder
              }
              New-Dhis2ProgramStageSection @argHash
      }
}

Export-ModuleMember -Function @(
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
      'New-Dhis2Program'
      'New-Dhis2ProgramStage'
      'New-Dhis2ProgramStageDataElement'
      'New-Dhis2ProgramStageSection'
      'New-Dhis2ProgramTrackedEntityAttribute'
      'New-Dhis2ProgramRule'
      'New-Dhis2ProgramRuleAction'
      'New-Dhis2ProgramRuleVariable'
      'New-Dhis2Option'
      'New-Dhis2OptionSet'
  )
