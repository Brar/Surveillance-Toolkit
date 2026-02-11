<#
.SYNOPSIS
    Imports DHIS2 program metadata and dependencies using the dependency export API.

.DESCRIPTION
    Extracts program metadata and ALL required dependencies from a DHIS2 instance using
    the built-in metadata dependency export API. This ensures you get exactly what's
    needed for the program, nothing more, nothing less.
    
    Uses: GET /api/programs/{programId}/metadata.json?skipSharing=false
    
    The script then resolves additional dependencies not included in the API response:
    - Organisation Units (referenced by program, stages, or data)
    - Organisation Unit Levels and Groups
    - User Roles and User Groups (from notifications, sharing)
    
    Finally converts all metadata to hybrid YAML+CSV format for source control.

.PARAMETER BaseUrl
    Base URL of the DHIS2 instance (e.g., 'https://dhis2.example.org').

.PARAMETER Credential
    PSCredential object for DHIS2 authentication.
    If not provided, you will be prompted to enter credentials.

.PARAMETER ProgramCode
    Code of the program to import (e.g., 'neoipc-core').
    The script will look up the program UID from the code via the DHIS2 API.

.PARAMETER OutputPath
    Root path for metadata output. Defaults to 'metadata/programs/{programCode}'.

.PARAMETER SkipOrganisationUnits
    Skip resolving organisation unit dependencies.

.PARAMETER DetectPatterns
    Analyzes metadata for repetitive patterns and suggests generators.

.PARAMETER CreateGenerators
    Automatically creates generator scripts for detected patterns.

.PARAMETER Force
    Overwrite existing output directory without prompting.

.EXAMPLE
    # Import program by code (will prompt for credentials)
    .\Import-FromDHIS2.ps1 `
        -BaseUrl "https://play.dhis2.org/40.2.2" `
        -ProgramCode "neoipc-core"

.EXAMPLE
    # Import with pattern detection
    .\Import-FromDHIS2.ps1 `
        -BaseUrl "https://dhis2.example.org" `
        -Credential (Get-Credential) `
        -ProgramCode "neoipc-core" `
        -DetectPatterns

.EXAMPLE
    # Use environment variable for base URL and provide credentials
    $env:NEOIPC_DHIS2_BASEURL = "https://dhis2.example.org"
    .\Import-FromDHIS2.ps1 -ProgramCode "neoipc-core"

.NOTES
    Requires powershell-yaml module and NeoIPC-Tools module.
    Uses DHIS2 metadata dependency export API for accurate dependency resolution.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ProgramCode,

    [Parameter(Mandatory)]
    [string]$BaseUrl,

    [PSCredential]$Credential,

    [string]$OutputPath,

    [switch]$SkipOrganisationUnits,

    [switch]$DetectPatterns,

    [switch]$CreateGenerators,

    [switch]$Force
)

# Validate parameters
if (-not $BaseUrl) {
    throw "BaseUrl is required. Specify via parameter or NEOIPC_DHIS2_BASEURL environment variable."
}

$BaseUrl = $BaseUrl.TrimEnd('/')

Write-Host "`nDHIS2 Metadata Import (Dependency API)" -ForegroundColor Cyan
Write-Host "Server: $BaseUrl" -ForegroundColor Gray
Write-Host "Program Code: $ProgramCode" -ForegroundColor Gray
Write-Host ""

#region Helper Functions

function Resolve-Token {
    $tokenCandidate = $env:NEOIPC_DHIS2_TOKEN

    if (-not [string]::IsNullOrWhiteSpace($tokenCandidate)) {
        # If it's a path to a file, read the first line
        if (Test-Path -LiteralPath $tokenCandidate -PathType Leaf) {
            try {
                $content = Get-Content -LiteralPath $tokenCandidate -Head 1 -Encoding UTF8 -ErrorAction Stop
                return $content
            }
            catch {
                throw "Token file '$tokenCandidate' could not be read: $($_.Exception.Message)"
            }
        }
        else {
            return $tokenCandidate
        }
    }
    return $null
}

function Invoke-DHIS2Api {
    param(
        [string]$Endpoint,
        [hashtable]$QueryParams = @{},
        [string]$Method = 'GET'
    )
    
    $uri = "$BaseUrl/api/$Endpoint"
    
    if ($QueryParams.Count -gt 0) {
        $queryString = ($QueryParams.GetEnumerator() | ForEach-Object { 
            "$($_.Key)=$([Uri]::EscapeDataString($_.Value))" 
        }) -join '&'
        $uri += "?$queryString"
    }
    
    Write-Verbose "API Request: $Method $uri"
    
    try {
        if ($resolvedToken) {
            $response = Invoke-RestMethod -Uri $uri -Method $Method -ErrorAction Stop -Headers @{'Authorization' = "ApiToken $resolvedToken" }
        } else {
            $response = Invoke-RestMethod -Uri $uri -Method $Method -ErrorAction Stop -Authentication Basic -Credential $Credential
        }
        return $response
    }
    catch {
        Write-Error "DHIS2 API Error: $_"
        throw
    }
}

function Add-MetadataDependencies {
    <#
    .SYNOPSIS
        Resolves business logic references that aren't included by the DHIS2 metadata dependency export
    #>
    param(
        [PSObject]$Metadata
    )

    Write-Host "`nResolving user metadata dependencies..." -ForegroundColor Cyan

    $userIds = [System.Collections.Generic.HashSet[string]]::new()
    $userRoleIds = [System.Collections.Generic.HashSet[string]]::new()
    $userGroupIds = [System.Collections.Generic.HashSet[string]]::new()

    # Extract business logic user group references from notifications
    if ($Metadata.PSObject.Properties.Name -contains 'programNotificationTemplates') {
        foreach ($notification in $Metadata.programNotificationTemplates) {
            if ($notification.recipientUserGroup -and $notification.recipientUserGroup.id) {
                $userGroupIds.Add($notification.recipientUserGroup.id) | Out-Null
            }
        }
    }

    # Extract users and userGroups from sharing settings
    foreach ($prop in $Metadata.PSObject.Properties) {
        $objects = $prop.Value
        if ($objects -isnot [array]) { continue }
        
        foreach ($obj in $objects) {
            # Modern sharing object
            if ($obj.sharing) {
                # Extract users from sharing.users (map of userId -> access)
                if ($obj.sharing.users) {
                    foreach ($userId in $obj.sharing.users.PSObject.Properties.Name) {
                        if ($userId) {
                            $userIds.Add($userId) | Out-Null
                        }
                    }
                }
                
                # Extract user groups from sharing.userGroups (map of userGroupId -> access)
                if ($obj.sharing.userGroups) {
                    foreach ($userGroupId in $obj.sharing.userGroups.PSObject.Properties.Name) {
                        if ($userGroupId) {
                            $userGroupIds.Add($userGroupId) | Out-Null
                        }
                    }
                }
            } else { # Legacy userAccesses and userGroupAccesses arrays
                if ($obj.userAccesses) {
                    foreach ($userAccess in $obj.userAccesses) {
                        if ($userAccess.id) {
                            $userIds.Add($userAccess.id) | Out-Null
                        }
                    }
                }
                if ($obj.userGroupAccesses) {
                    foreach ($userGroupAccess in $obj.userGroupAccesses) {
                        if ($userGroupAccess.id) {
                            $userGroupIds.Add($userGroupAccess.id) | Out-Null
                        }
                    }
                }
            }
        }
    }

    if ($userGroupIds.Count -lt 1 -and $userIds.Count -lt 1) {
        Write-Host "  No user metadata references found" -ForegroundColor Gray
        return $null
    }

    Write-Host "  Found $($userIds.Count) user references (business logic)" -ForegroundColor Gray
    Write-Host "  Found $($userGroupIds.Count) user group references (business logic)" -ForegroundColor Gray

    $users = @()
    $userRoles = @()
    $userGroups = @()

    # Batch fetch users
    if ($userIds.Count -gt 0) {
        try {
            $userIdFilter = @($userIds) -join ','
            $userResponse = Invoke-DHIS2Api -Endpoint "users" -QueryParams @{ 
                filter = "id:in:[$userIdFilter]"
                fields = 'id,code,username,userRoles[id],userGroups[id]'
                paging = 'false'
            }
            
            if ($userResponse.users) {
                $users = @($userResponse.users)

                # Collect all user role IDs
                foreach ($user in $users) {
                    if ($user.userRoles) {
                        foreach ($role in $user.userRoles) {
                            if ($role.id) {
                                $userRoleIds.Add($role.id) | Out-Null
                            }
                        }
                    }
                }

                # Collect all user group IDs
                foreach ($user in $users) {
                    if ($user.userGroups) {
                        foreach ($role in $user.userGroups) {
                            if ($role.id) {
                                $userGroupIds.Add($role.id) | Out-Null
                            }
                        }
                    }
                }
            }
        }
        catch {
            Write-Warning "Failed to batch fetch users: $_"
        }
    }

    # Batch fetch all user roles
    if ($userRoleIds.Count -gt 0) {
        try {
            $roleIdFilter = @($userRoleIds) -join ','
            $roleResponse = Invoke-DHIS2Api -Endpoint "userRoles" -QueryParams @{ 
                filter = "id:in:[$roleIdFilter]"
                fields = '*'
                paging = 'false'
            }
            if ($roleResponse.userRoles) {
                $userRoles = @($roleResponse.userRoles)
            }
        }
        catch {
            Write-Warning "Failed to batch fetch user roles: $_"
        }
    }

    # Batch fetch user groups
    if ($userGroupIds.Count -gt 0) {
        try {
            $ugIdFilter = @($userGroupIds) -join ','
            $ugResponse = Invoke-DHIS2Api -Endpoint "userGroups" -QueryParams @{ 
                filter = "id:in:[$ugIdFilter]"
                fields = '*'
                paging = 'false'
            }
            
            if ($ugResponse.userGroups) {
                $userGroups = @($ugResponse.userGroups)
            }
        }
        catch {
            Write-Warning "Failed to batch fetch user groups: $_"
        }
    }

    Write-Host "  ✓ Found $($userGroups.Count) user groups" -ForegroundColor Green
    Write-Host "  ✓ Found $($users.Count) users" -ForegroundColor Green
    Write-Host "  ✓ Found $($userRoles.Count) user roles" -ForegroundColor Green

    return $Metadata |
        Add-Member -MemberType NoteProperty -Name 'users' -Value $users -PassThru |
        Add-Member -MemberType NoteProperty -Name 'userGroups' -Value $userGroups -PassThru |
        Add-Member -MemberType NoteProperty -Name 'userRoles' -Value $userRoles -PassThru
}

function Resolve-MissingMetadata {
    <#
    .SYNOPSIS
        Recursively resolves missing metadata objects by fetching from DHIS2 API
    #>
    param(
        [PSObject]$Metadata,
        [string]$ObjectType,
        [string]$Identifier,
        [System.Collections.Generic.HashSet[string]]$ResolvedUids,
        [switch]$ByName,
        [switch]$ByCode
    )

    # Map object types to API endpoints and collection property names
    $typeMap = @{
        'dataElement' = @{ endpoint = 'dataElements'; property = 'dataElements' }
        'trackedEntityAttribute' = @{ endpoint = 'trackedEntityAttributes'; property = 'trackedEntityAttributes' }
        'programRuleVariable' = @{ endpoint = 'programRuleVariables'; property = 'programRuleVariables' }
        'organisationUnitGroup' = @{ endpoint = 'organisationUnitGroups'; property = 'organisationUnitGroups' }
        'userGroup' = @{ endpoint = 'userGroups'; property = 'userGroups' }
        'userRole' = @{ endpoint = 'userRoles'; property = 'userRoles' }
    }

    if (-not $typeMap.ContainsKey($ObjectType)) {
        Write-Verbose "Unknown object type: $ObjectType"
        return
    }

    $mapping = $typeMap[$ObjectType]
    $collectionName = $mapping.property

    # Check if already exists in metadata
    if ($Metadata.PSObject.Properties.Name -contains $collectionName) {
        $existing = $Metadata.$collectionName | Where-Object {
            if ($ByName) { $_.name -eq $Identifier }
            elseif ($ByCode) { $_.code -eq $Identifier }
            else { $_.id -eq $Identifier }
        }
        if ($existing) {
            if ($existing.id -and -not $ResolvedUids.Contains($existing.id)) {
                $ResolvedUids.Add($existing.id) | Out-Null
            }
            return
        }
    }

    # Check if already resolved to prevent loops
    if (-not $ByName -and -not $ByCode -and $ResolvedUids.Contains($Identifier)) {
        return
    }

    # Fetch from DHIS2 API
    try {
        $filter = if ($ByName) { "name:eq:$Identifier" } 
                  elseif ($ByCode) { "code:eq:$Identifier" }
                  else { "id:eq:$Identifier" }
        $response = Invoke-DHIS2Api -Endpoint $mapping.endpoint -QueryParams @{
            filter = $filter
            fields = '*'
            paging = 'false'
        }

        if ($response.$collectionName -and $response.$collectionName.Count -gt 0) {
            $obj = $response.$collectionName[0]
            
            # Mark as resolved
            if ($obj.id) {
                $ResolvedUids.Add($obj.id) | Out-Null
            }

            # Add to metadata collection
            if ($Metadata.PSObject.Properties.Name -contains $collectionName) {
                $Metadata.$collectionName += $obj
            } else {
                $Metadata | Add-Member -MemberType NoteProperty -Name $collectionName -Value @($obj) -Force
            }

            Write-Verbose "  Resolved ${$ObjectType}: $Identifier"

            # Recursively resolve references in the fetched object
            if ($ObjectType -eq 'programRuleVariable') {
                # Program rule variables reference dataElement or trackedEntityAttribute
                if ($obj.dataElement -and $obj.dataElement.id) {
                    Resolve-MissingMetadata -Metadata $Metadata -ObjectType 'dataElement' -Identifier $obj.dataElement.id -ResolvedUids $ResolvedUids
                }
                if ($obj.trackedEntityAttribute -and $obj.trackedEntityAttribute.id) {
                    Resolve-MissingMetadata -Metadata $Metadata -ObjectType 'trackedEntityAttribute' -Identifier $obj.trackedEntityAttribute.id -ResolvedUids $ResolvedUids
                }
            }
        }
    }
    catch {
        Write-Verbose "Failed to resolve $ObjectType '$Identifier': $_"
    }
}

function Add-ProgramRuleExpressionDependencies {
    <#
    .SYNOPSIS
        Resolves metadata referenced in program rule expressions
    .DESCRIPTION
        Parses program rule conditions and actions to extract references to:
        - Tracked entity attributes: A{name}
        - Data elements: #{name} or #{stage.name}
        - Program rule variables: V{variableName}
        - d2: functions with metadata parameters
        
        DHIS2 Implementation References:
        - Documentation: https://docs.dhis2.org/en/use/user-guides/dhis-core-version-master/configuring-the-system/programs.html#program_rules_operators_functions
        - d2 Functions Implementation: https://github.com/dhis2/capture-app/blob/master/packages/rules-engine/src/d2Functions/getD2Functions.ts
    #>
    param(
        [PSObject]$Metadata
    )

    Write-Host "`nResolving program rule expression dependencies..." -ForegroundColor Cyan

    if (-not ($Metadata.PSObject.Properties.Name -contains 'programRules')) {
        Write-Host "  No program rules found" -ForegroundColor Gray
        return $Metadata
    }

    $resolvedUids = [System.Collections.Generic.HashSet[string]]::new()
    $attributeNames = [System.Collections.Generic.HashSet[string]]::new()
    $dataElementNames = [System.Collections.Generic.HashSet[string]]::new()
    $variableNames = [System.Collections.Generic.HashSet[string]]::new()
    $orgUnitGroupIdentifiers = [System.Collections.Generic.HashSet[string]]::new()
    $userGroupUids = [System.Collections.Generic.HashSet[string]]::new()
    $userRoleUids = [System.Collections.Generic.HashSet[string]]::new()
    $syntaxErrorCount = 0

    # Collect all expressions to parse
    Write-Verbose "Collecting expressions from program rules and actions..."
    $expressions = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($rule in $Metadata.programRules) {
        if ($rule.condition) { $expressions.Add($rule.condition) | Out-Null }
    }
    if ($Metadata.PSObject.Properties.Name -contains 'programRuleActions') {
        foreach ($action in $Metadata.programRuleActions) {
            if ($action.data) { $expressions.Add($action.data) | Out-Null }
            if ($action.content) { $expressions.Add($action.content) | Out-Null }
        }
    }
    Write-Verbose "Collected $($expressions.Count) different expressions to parse"

    # Parse expressions for references
    Write-Verbose "Parsing expressions for metadata references..."
    foreach ($expr in $expressions) {
        if (-not $expr) { continue }

        # A{attributeName} - tracked entity attributes by name
        # DHIS2 Documentation: https://docs.dhis2.org/en/use/user-guides/dhis-core-version-master/configuring-the-system/programs.html#program_rules_operators_functions
        # Standard program rule expression syntax - references tracked entity attribute by name
        [regex]::Matches($expr, 'A\{([^}]+)\}') | ForEach-Object {
            $attributeName = $_.Groups[1].Value
            Write-Debug "Found tracked entity attribute expression with name '$attributeName'"
            $attributeNames.Add($attributeName) | Out-Null
        }

        # #{dataElementName} or #{stage.dataElementName} - data elements by name
        # DHIS2 Documentation: https://docs.dhis2.org/en/use/user-guides/dhis-core-version-master/configuring-the-system/programs.html#program_rules_operators_functions
        # Standard program rule expression syntax - references data element by name (with optional stage prefix)
        [regex]::Matches($expr, '#\{([^}]+)\}') | ForEach-Object {
            $name = $_.Groups[1].Value
            # Handle stage.dataElement format - take last segment
            if ($name -match '\.') {
                $name = ($name -split '\.')[-1]
            }
            Write-Debug "Found data element expression with name '$name'"
            $dataElementNames.Add($name) | Out-Null
        }

        # V{variableName} - program rule variables by name
        # DHIS2 Documentation: https://docs.dhis2.org/en/use/user-guides/dhis-core-version-master/configuring-the-system/programs.html#program_rules_operators_functions
        # Standard program rule expression syntax - references program rule variable by name
        # Variables provide indirection - they reference either dataElement or trackedEntityAttribute
        [regex]::Matches($expr, 'V\{([^}]+)\}') | ForEach-Object {
            $variableName = $_.Groups[1].Value
            Write-Debug "Found program rule variable expression with name '$variableName'"
            $variableNames.Add($variableName) | Out-Null
        }

        # d2:count('name'), d2:hasValue('name'), etc. - data elements by name in string literals
        # DHIS2 Documentation: https://docs.dhis2.org/en/use/user-guides/dhis-core-version-master/configuring-the-system/programs.html#program_rules_operators_functions
        # Implementation:
        # * d2:count: https://github.com/dhis2/capture-app/blob/991e547d67949f0195ebe566a12cef894855a1df/packages/rules-engine/src/d2Functions/getD2Functions.ts#L79
        # * d2:countIfValue: https://github.com/dhis2/capture-app/blob/991e547d67949f0195ebe566a12cef894855a1df/packages/rules-engine/src/d2Functions/getD2Functions.ts#L92
        # * d2:countIfZeroPos: https://github.com/dhis2/capture-app/blob/991e547d67949f0195ebe566a12cef894855a1df/packages/rules-engine/src/d2Functions/getD2Functions.ts#L111
        # * d2:hasValue: https://github.com/dhis2/capture-app/blob/991e547d67949f0195ebe566a12cef894855a1df/packages/rules-engine/src/d2Functions/getD2Functions.ts#L118
        # * d2:maxValue: https://github.com/dhis2/capture-app/blob/991e547d67949f0195ebe566a12cef894855a1df/packages/rules-engine/src/d2Functions/getD2Functions.ts#L118
        # * d2:minValue: https://github.com/dhis2/capture-app/blob/991e547d67949f0195ebe566a12cef894855a1df/packages/rules-engine/src/d2Functions/getD2Functions.ts#L118
        [regex]::Matches($expr, 'd2:(count|countIfValue|countIfZeroPos|hasValue|maxValue|minValue)\s*\(\s*[''"]([^''"]+)[''"]') | ForEach-Object {
            $functionName = $_.Groups[1].Value
            $dataElementName = $_.Groups[2].Value
            Write-Debug "Found d2:$functionName() function expression with data element name '$dataElementName'"
            $dataElementNames.Add($dataElementName) | Out-Null
        }

        # d2:inOrgUnitGroup('identifier') - organisation unit groups by UID or code
        # DHIS2 Documentation: https://docs.dhis2.org/en/use/user-guides/dhis-core-version-master/configuring-the-system/programs.html#program_rules_operators_functions
        # Implementation: https://github.com/dhis2/capture-app/blob/991e547d67949f0195ebe566a12cef894855a1df/packages/rules-engine/src/d2Functions/getD2Functions.ts#L190
        # Accepts both UID (11 alphanumeric chars starting with letter) and code
        [regex]::Matches($expr, 'd2:inOrgUnitGroup\s*\(\s*[''"]([^''"]+)[''"]') | ForEach-Object {
            $identifier = $_.Groups[1].Value
            Write-Debug "Found d2:inOrgUnitGroup() function expression with identifier '$identifier'"
            $orgUnitGroupIdentifiers.Add($identifier) | Out-Null
        }

        # d2:inUserGroup('uid') - user groups by UID  
        # DHIS2 Documentation: https://docs.dhis2.org/en/use/user-guides/dhis-core-version-master/configuring-the-system/programs.html#program_rules_operators_functions
        # Note: This function is documented but not found in the capture-app rules-engine implementation
        [regex]::Matches($expr, 'd2:inUserGroup\s*\(\s*[''"]([^''"]+)[''"]') | ForEach-Object {
            $uid = $_.Groups[1].Value
            Write-Debug "Found d2:inUserGroup() function expression with user group id '$uid'"
            $userGroupUids.Add($uid) | Out-Null
        }

        # d2:hasUserRole('uid') - user roles by UID
        # DHIS2 Documentation: https://docs.dhis2.org/en/use/user-guides/dhis-core-version-master/configuring-the-system/programs.html#program_rules_operators_functions
        # Implementation: https://github.com/dhis2/capture-app/blob/991e547d67949f0195ebe566a12cef894855a1df/packages/rules-engine/src/d2Functions/getD2Functions.ts#L198
        [regex]::Matches($expr, 'd2:hasUserRole\s*\(\s*[''"]([^''"]+)[''"]') | ForEach-Object {
            $uid = $_.Groups[1].Value
            Write-Debug "Found d2:hasUserRole() function expression with user role id '$uid'"
            $userRoleUids.Add($uid) | Out-Null
        }

        # SYNTAX ERROR PATTERNS - Functions with unquoted A{}, #{}, or V{} references
        # These should use quoted names, but we'll extract them anyway and warn

        # d2:count/hasValue etc with A{attributeName} - SYNTAX ERROR
        [regex]::Matches($expr, 'd2:(?:count|countIfValue|countIfZeroPos|hasValue|maxValue|minValue)\s*\(\s*A\{([^}]+)\}') | ForEach-Object {
            $name = $_.Groups[1].Value
            Write-Debug "SYNTAX ERROR: d2 function called with A{$name} instead of quoted attribute name. Expression: $($expr.Substring(0, [Math]::Min(80, $expr.Length)))"
            $attributeNames.Add($name) | Out-Null
            $syntaxErrorCount++
        }

        # d2:count/hasValue etc with #{dataElementName} - SYNTAX ERROR
        [regex]::Matches($expr, 'd2:(?:count|countIfValue|countIfZeroPos|hasValue|maxValue|minValue)\s*\(\s*#\{([^}]+)\}') | ForEach-Object {
            $name = $_.Groups[1].Value
            # Handle stage.dataElement format
            if ($name -match '\.') {
                $name = ($name -split '\.')[-1]
            }
            Write-Debug "SYNTAX ERROR: d2 function called with #{$name} instead of quoted data element name. Expression: $($expr.Substring(0, [Math]::Min(80, $expr.Length)))"
            $dataElementNames.Add($name) | Out-Null
            $syntaxErrorCount++
        }

        # d2:count/hasValue etc with V{variableName} - SYNTAX ERROR
        [regex]::Matches($expr, 'd2:(?:count|countIfValue|countIfZeroPos|hasValue|maxValue|minValue)\s*\(\s*V\{([^}]+)\}') | ForEach-Object {
            $name = $_.Groups[1].Value
            Write-Debug "SYNTAX ERROR: d2 function called with V{$name} instead of quoted variable name. Expression: $($expr.Substring(0, [Math]::Min(80, $expr.Length)))"
            $variableNames.Add($name) | Out-Null
            $syntaxErrorCount++
        }

        # d2:inOrgUnitGroup with A{}, #{}, or V{} - SYNTAX ERROR
        [regex]::Matches($expr, 'd2:inOrgUnitGroup\s*\(\s*A\{([^}]+)\}') | ForEach-Object {
            $name = $_.Groups[1].Value
            Write-Debug "SYNTAX ERROR: d2:inOrgUnitGroup called with A{$name} instead of quoted identifier. Expression: $($expr.Substring(0, [Math]::Min(80, $expr.Length)))"
            $attributeNames.Add($name) | Out-Null
            $syntaxErrorCount++
        }

        [regex]::Matches($expr, 'd2:inOrgUnitGroup\s*\(\s*#\{([^}]+)\}') | ForEach-Object {
            $name = $_.Groups[1].Value
            if ($name -match '\.') {
                $name = ($name -split '\.')[-1]
            }
            Write-Debug "SYNTAX ERROR: d2:inOrgUnitGroup called with #{$name} instead of quoted identifier. Expression: $($expr.Substring(0, [Math]::Min(80, $expr.Length)))"
            $dataElementNames.Add($name) | Out-Null
            $syntaxErrorCount++
        }

        [regex]::Matches($expr, 'd2:inOrgUnitGroup\s*\(\s*V\{([^}]+)\}') | ForEach-Object {
            $name = $_.Groups[1].Value
            Write-Debug "SYNTAX ERROR: d2:inOrgUnitGroup called with V{$name} instead of quoted identifier. Expression: $($expr.Substring(0, [Math]::Min(80, $expr.Length)))"
            $variableNames.Add($name) | Out-Null
            $syntaxErrorCount++
        }
    }

    # Report syntax errors
    if ($syntaxErrorCount -gt 0) {
        Write-Warning "Found $syntaxErrorCount program rule expression syntax errors (unquoted A{}/#{}/V{} passed to d2 functions). Metadata references extracted anyway. Run with -Debug for details."
    }

    # Report findings
    Write-Verbose "Parsing complete. Found references across all expression types"
    Write-Host "  Found $($attributeNames.Count) tracked entity attribute references" -ForegroundColor Gray
    Write-Host "  Found $($dataElementNames.Count) data element references" -ForegroundColor Gray
    Write-Host "  Found $($variableNames.Count) program rule variable references" -ForegroundColor Gray
    Write-Host "  Found $($orgUnitGroupIdentifiers.Count) organisation unit group references" -ForegroundColor Gray
    Write-Host "  Found $($userGroupUids.Count) user group references" -ForegroundColor Gray
    Write-Host "  Found $($userRoleUids.Count) user role references" -ForegroundColor Gray

    # Resolve missing metadata
    Write-Verbose "Resolving $($attributeNames.Count) tracked entity attributes..."
    foreach ($name in $attributeNames) {
        Resolve-MissingMetadata -Metadata $Metadata -ObjectType 'trackedEntityAttribute' -Identifier $name -ResolvedUids $resolvedUids -ByName
    }

    Write-Verbose "Resolving $($dataElementNames.Count) data elements..."
    foreach ($name in $dataElementNames) {
        Resolve-MissingMetadata -Metadata $Metadata -ObjectType 'dataElement' -Identifier $name -ResolvedUids $resolvedUids -ByName
    }

    Write-Verbose "Resolving $($variableNames.Count) program rule variables..."
    foreach ($name in $variableNames) {
        Resolve-MissingMetadata -Metadata $Metadata -ObjectType 'programRuleVariable' -Identifier $name -ResolvedUids $resolvedUids -ByName
    }

    Write-Verbose "Resolving $($orgUnitGroupIdentifiers.Count) organisation unit groups..."
    foreach ($identifier in $orgUnitGroupIdentifiers) {
        # Check if identifier is a UID (11 alphanumeric chars starting with letter) or a code
        $isUid = $identifier -match '^[A-Za-z][A-Za-z0-9]{10}$'
        if ($isUid) {
            Resolve-MissingMetadata -Metadata $Metadata -ObjectType 'organisationUnitGroup' -Identifier $identifier -ResolvedUids $resolvedUids
        } else {
            Resolve-MissingMetadata -Metadata $Metadata -ObjectType 'organisationUnitGroup' -Identifier $identifier -ResolvedUids $resolvedUids -ByCode
        }
    }

    Write-Verbose "Resolving $($userGroupUids.Count) user groups..."
    foreach ($uid in $userGroupUids) {
        Resolve-MissingMetadata -Metadata $Metadata -ObjectType 'userGroup' -Identifier $uid -ResolvedUids $resolvedUids
    }

    Write-Verbose "Resolving $($userRoleUids.Count) user roles..."
    foreach ($uid in $userRoleUids) {
        Resolve-MissingMetadata -Metadata $Metadata -ObjectType 'userRole' -Identifier $uid -ResolvedUids $resolvedUids
    }

    Write-Verbose "Resolution complete. Total resolved: $($resolvedUids.Count) metadata objects"
    Write-Host "  ✓ Resolved $($resolvedUids.Count) metadata objects" -ForegroundColor Green

    return $Metadata
}

#endregion

#region Fetch Program Metadata with Dependencies

# Setup authentication
if (-not $Credential) {
    $resolvedToken = Resolve-Token
    if (-not $resolvedToken) {
        $Credential = Get-Credential -Message "Enter DHIS2 credentials"
    }
}

# First, look up the program UID from the code
Write-Host "Looking up program by code: $ProgramCode..." -ForegroundColor Yellow

try {
    $programSearch = Invoke-DHIS2Api -Endpoint "programs" -QueryParams @{
        filter = "code:eq:$ProgramCode"
        fields = 'id,name'
        paging = 'false'
    }
    
    if (-not $programSearch.programs -or $programSearch.programs.Count -eq 0) {
        throw "No program found with code: $ProgramCode"
    }
    
    if ($programSearch.programs.Count -gt 1) {
        Write-Warning "Multiple programs found with code: $ProgramCode. Using first match."
    }
    
    $programInfo = $programSearch.programs[0]
    $ProgramId = $programInfo.id
    
    Write-Host "✓ Found program: $($programInfo.name) (ID: $ProgramId)" -ForegroundColor Green
}
catch {
    Write-Error "Failed to look up program by code: $_"
    throw
}

Write-Host "`nFetching program metadata and dependencies..." -ForegroundColor Yellow
Write-Host "Using metadata dependency export API..." -ForegroundColor Gray

try {
    $metadata = Invoke-DHIS2Api -Endpoint "programs/$ProgramId/metadata.json" -QueryParams @{
        skipSharing = 'false'
    }
}
catch {
    Write-Error "Failed to fetch program metadata. Verify program exists and you have access."
    throw
}

# Resolve program rule expression dependencies
$metadata = Add-ProgramRuleExpressionDependencies $metadata

# Add additional dependencies
$metadata = Add-MetadataDependencies $metadata

# Extract program details
if (-not $metadata.programs -or $metadata.programs.Count -eq 0) {
    throw "No program found in metadata response"
}

# Determine output path
if (-not $OutputPath) {
    $OutputPath = Join-Path $PSScriptRoot "..\metadata\programs\$($ProgramCode.ToLower())"
}

if ((Test-Path $OutputPath) -and -not $Force) {
    $response = Read-Host "Output directory '$OutputPath' exists. Overwrite? (y/N)"
    if ($response -notmatch '^y(es)?$') {
        Write-Host "Import cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "`nOutput directory: $OutputPath" -ForegroundColor Cyan

# Show what was included in the dependency export
Write-Host "`nMetadata included in dependency export:" -ForegroundColor Cyan
$metadata.PSObject.Properties | Where-Object { $_.Name -ne 'system' -and $_.Value -is [array] } | ForEach-Object {
    $count = $_.Value.Count
    if ($count -gt 0) {
        Write-Host "  $($_.Name): $count" -ForegroundColor Gray
    }
}

#endregion

$OutputPath
