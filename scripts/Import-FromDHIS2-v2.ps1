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

.PARAMETER IncludeAuditUsers
    Include users referenced only in audit trails (createdBy, lastUpdatedBy).
    By default, only exports users/groups/roles referenced in business logic
    (notifications, program rules, sharing settings).

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
    [string]$BaseUrl = $env:NEOIPC_DHIS2_BASEURL,
    
    [PSCredential]$Credential,
    
    [Parameter(Mandatory)]
    [string]$ProgramCode,
    
    [string]$OutputPath,
    
    [switch]$SkipOrganisationUnits,
    
    [switch]$IncludeAuditUsers,
    
    [switch]$DetectPatterns,
    
    [switch]$CreateGenerators,
    
    [switch]$Force
)

#Requires -Modules @{ ModuleName='powershell-yaml'; ModuleVersion='0.4.0' }

Import-Module (Join-Path $PSScriptRoot 'modules\NeoIPC-Tools\NeoIPC-Tools.psm1') -Force

# Validate parameters
if (-not $BaseUrl) {
    throw "BaseUrl is required. Specify via parameter or NEOIPC_DHIS2_BASEURL environment variable."
}

# Setup authentication
if (-not $Credential) {
    $Credential = Get-Credential -Message "Enter DHIS2 credentials"
}

$BaseUrl = $BaseUrl.TrimEnd('/')

Write-Host "`nDHIS2 Metadata Import (Dependency API)" -ForegroundColor Cyan
Write-Host "Server: $BaseUrl" -ForegroundColor Gray
Write-Host "Program Code: $ProgramCode" -ForegroundColor Gray
Write-Host ""

#region Helper Functions

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
        $response = Invoke-RestMethod -Uri $uri -Credential $Credential -Method $Method -ErrorAction Stop -Authentication Basic
        return $response
    }
    catch {
        Write-Error "DHIS2 API Error: $_"
        throw
    }
}

function Get-IdentifierForType {
    <#
    .SYNOPSIS
        Returns the identifier field value for a given metadata type.
    .DESCRIPTION
        Uses explicit type-based resolution to return the correct identifier field
        (username, name, or code) based on the metadata type.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$IntermediateObject
    )
    
    $typeName = $IntermediateObject['type']
    $readyToExport = $IntermediateObject['readyToExport']
    
    switch ($typeName) {
        'users' { 
            if (-not $readyToExport['username']) {
                throw "User object missing username identifier"
            }
            return $readyToExport['username']
        }
        
        { $_ -in 'programStages','programSections','programStageSections',
                  'programIndicators','programRules','programRuleVariables',
                  'programNotificationTemplates','trackedEntityTypes',
                  'organisationUnitLevels' } { 
            if (-not $readyToExport['name']) {
                throw "$typeName object missing name identifier"
            }
            return $readyToExport['name']
        }
        
        { $_ -in 'programs','dataElements','trackedEntityAttributes','options',
                  'optionSets','categories','categoryCombos','categoryOptions',
                  'categoryOptionCombos','organisationUnits','organisationUnitGroups',
                  'organisationUnitGroupSets','userGroups','userRoles' } { 
            if (-not $readyToExport['code']) {
                throw "$typeName object missing code identifier"
            }
            return $readyToExport['code']
        }
        
        default { throw "Unknown metadata type: $typeName" }
    }
}

function Convert-ToIntermediateObjects {
    <#
    .SYNOPSIS
        Pass 1: Extracts metadata objects to intermediate hashtable representation.
    .DESCRIPTION
        Iterates through metadata objects in leaf-to-trunk dependency order, creating
        intermediate hashtables with properties split into:
        - readyToExport: Fields that can be exported directly (identifiers, translatable fields)
        - idsToResolve: Hashtable of field names to IDs that need lookup/resolution
        - id: Original object ID
        - type: Metadata type name
    #>
    param(
        [Parameter(Mandatory)]
        [PSObject]$Metadata,
        [PSObject]$OrgUnitDeps,
        [PSObject]$UserDeps
    )
    
    Write-Host "`nPass 1: Extracting to intermediate objects..." -ForegroundColor Cyan
    
    # Field to metadata type mapping for reference resolution
    $fieldToMetadataType = @{
        'program' = 'programs'
        'programs' = 'programs'
        'programStage' = 'programStages'
        'programStages' = 'programStages'
        'trackedEntityType' = 'trackedEntityTypes'
        'trackedEntityTypes' = 'trackedEntityTypes'
        'trackedEntityAttribute' = 'trackedEntityAttributes'
        'trackedEntityAttributes' = 'trackedEntityAttributes'
        'dataElement' = 'dataElements'
        'dataElements' = 'dataElements'
        'optionSet' = 'optionSets'
        'optionSets' = 'optionSets'
        'option' = 'options'
        'options' = 'options'
        'categoryCombo' = 'categoryCombos'
        'categoryCombos' = 'categoryCombos'
        'category' = 'categories'
        'categories' = 'categories'
        'categoryOption' = 'categoryOptions'
        'categoryOptions' = 'categoryOptions'
        'categoryOptionCombo' = 'categoryOptionCombos'
        'categoryOptionCombos' = 'categoryOptionCombos'
        'organisationUnit' = 'organisationUnits'
        'organisationUnits' = 'organisationUnits'
        'parent' = 'organisationUnits'
        'organisationUnitGroup' = 'organisationUnitGroups'
        'organisationUnitGroups' = 'organisationUnitGroups'
        'organisationUnitLevel' = 'organisationUnitLevels'
        'organisationUnitLevels' = 'organisationUnitLevels'
        'user' = 'users'
        'users' = 'users'
        'userGroup' = 'userGroups'
        'userGroups' = 'userGroups'
        'recipientUserGroup' = 'userGroups'
        'managedGroups' = 'userGroups'
        'userRole' = 'userRoles'
        'userRoles' = 'userRoles'
        'programIndicator' = 'programIndicators'
        'programIndicators' = 'programIndicators'
        'programSection' = 'programSections'
        'programSections' = 'programSections'
        'programStageSection' = 'programStageSections'
        'programStageSections' = 'programStageSections'
        'programRuleVariable' = 'programRuleVariables'
        'programRuleVariables' = 'programRuleVariables'
        'recipientProgramAttribute' = 'trackedEntityAttributes'
    }
    
    # Define metadata types with their fields and dependency order
    $typeDefinitions = @(
        # Leaf types (no dependencies)
        @{ name = 'options'; translatable = @('name','description'); technical = @('code','sortOrder','optionSet') }
        @{ name = 'categoryOptions'; translatable = @('name','shortName','description','formName'); technical = @('organisationUnits','categories') }
        @{ name = 'organisationUnitLevels'; translatable = @('name'); technical = @('level') }
        @{ name = 'trackedEntityTypes'; translatable = @('name','description'); technical = @('featureType','minAttributesRequiredToSearch','maxTeiCountToReturn','allowAuditLog') }
        @{ name = 'userRoles'; translatable = @('name','description'); technical = @('authorities') }
        
        # Foundation types
        @{ name = 'optionSets'; translatable = @('name','description'); technical = @('valueType','options') }
        @{ name = 'categories'; translatable = @('name','shortName','description'); technical = @('dataDimensionType','categoryOptions') }
        @{ name = 'organisationUnits'; translatable = @('name','shortName','description'); technical = @('code','parent','level','openingDate','closedDate','geometry') }
        
        # Mid-level types
        @{ name = 'categoryCombos'; translatable = @('name','description'); technical = @('dataDimensionType','skipTotal','categories') }
        @{ name = 'categoryOptionCombos'; translatable = @('name'); technical = @('categoryCombo','categoryOptions') }
        @{ name = 'organisationUnitGroups'; translatable = @('name','shortName','description'); technical = @('organisationUnits') }
        @{ name = 'organisationUnitGroupSets'; translatable = @('name','shortName','description'); technical = @('compulsory','includeSubhierarchyInAnalytics','organisationUnitGroups') }
        @{ name = 'userGroups'; translatable = @('name'); technical = @('users','managedGroups') }
        @{ name = 'users'; translatable = @(); technical = @('userRoles','organisationUnits','dataViewOrganisationUnits','teiSearchOrganisationUnits','userGroups') }
        
        # Program-dependent types
        @{ name = 'programs'; translatable = @('name','shortName','description','enrollmentDateLabel','incidentDateLabel'); technical = @('programType','trackedEntityType','version','accessLevel','onlyEnrollOnce','registration','withoutRegistration','captureCoordinates','featureType') }
        @{ name = 'programStages'; translatable = @('name','description','formName','executionDateLabel'); technical = @('program','repeatable','minDaysFromStart','generatedByEnrollmentDate','autoGenerateEvent','blockEntryForm','featureType','sortOrder') }
        @{ name = 'dataElements'; translatable = @('name','shortName','description','formName'); technical = @('valueType','domainType','aggregationType','zeroIsSignificant','optionSet','categoryCombo') }
        @{ name = 'trackedEntityAttributes'; translatable = @('name','shortName','description','formName'); technical = @('valueType','aggregationType','unique','generated','pattern','inherit','optionSet','confidential') }
        @{ name = 'programSections'; translatable = @('name','description'); technical = @('program','sortOrder','trackedEntityAttributes') }
        @{ name = 'programStageSections'; translatable = @('name','description'); technical = @('programStage','sortOrder','dataElements') }
        @{ name = 'programIndicators'; translatable = @('name','shortName','description','formName'); technical = @('program','expression','filter','analyticsType','aggregationType','decimals') }
        @{ name = 'programRuleVariables'; translatable = @('name','description'); technical = @('program','programRuleVariableSourceType','dataElement','trackedEntityAttribute','useCodeForOptionSet','programStage','valueType') }
        @{ name = 'programNotificationTemplates'; translatable = @('name','subjectTemplate','messageTemplate'); technical = @('notificationTrigger','notificationRecipient','deliveryChannels','notifyUsersInHierarchyOnly','sendRepeatable','recipientUserGroup','recipientProgramAttribute') }
    )
    
    # Build intermediate object collection keyed by ID
    $intermediateObjects = @{}
    
    # Helper function to extract an object to intermediate format
    function Extract-ObjectToIntermediate {
        param(
            [PSObject]$Object,
            [string]$TypeName,
            [string[]]$TranslatableFields,
            [string[]]$TechnicalFields
        )
        
        $intermediate = @{
            id = $Object.id
            type = $TypeName
            readyToExport = @{}
            idsToResolve = @{}
        }
        
        # Determine and extract identifier field
        switch ($TypeName) {
            'users' { 
                if ($Object.username) { $intermediate.readyToExport['username'] = $Object.username }
            }
            { $_ -in 'programStages','programSections','programStageSections',
                      'programIndicators','programRules','programRuleVariables',
                      'programNotificationTemplates','trackedEntityTypes',
                      'organisationUnitLevels' } { 
                if ($Object.name) { $intermediate.readyToExport['name'] = $Object.name }
            }
            default { 
                if ($Object.code) { $intermediate.readyToExport['code'] = $Object.code }
            }
        }
        
        # Extract translatable fields (ready to export)
        foreach ($field in $TranslatableFields) {
            if ($Object.PSObject.Properties.Name -contains $field -and $Object.$field) {
                $intermediate.readyToExport[$field] = $Object.$field
            }
        }
        
        # Extract technical fields (may need resolution)
        foreach ($field in $TechnicalFields) {
            if ($Object.PSObject.Properties.Name -contains $field) {
                $value = $Object.$field
                if ($null -eq $value) { continue }
                
                # Handle GeoJSON Point geometry - ready to export
                if ($field -eq 'geometry' -and $value.type -eq 'Point' -and $value.coordinates) {
                    $intermediate.readyToExport[$field] = "$($value.coordinates[0]),$($value.coordinates[1])"
                }
                # Handle object references - need ID resolution
                elseif ($value -is [PSCustomObject] -or ($value.PSObject.Properties.Name -contains 'id')) {
                    if ($value.id) {
                        $intermediate.idsToResolve[$field] = $value.id
                    }
                }
                # Handle arrays
                elseif ($value -is [array]) {
                    if ($value.Count -gt 0) {
                        if ($value[0] -is [string]) {
                            # Array of strings - ready to export
                            $intermediate.readyToExport[$field] = $value -join ','
                        } else {
                            # Array of objects - need ID resolution
                            $ids = @($value | Where-Object { $_.id } | ForEach-Object { $_.id })
                            if ($ids.Count -gt 0) {
                                $intermediate.idsToResolve[$field] = $ids
                            }
                        }
                    }
                }
                # Handle booleans and simple values - ready to export
                elseif ($value -is [bool]) {
                    $intermediate.readyToExport[$field] = $value.ToString().ToLower()
                }
                elseif ($value -is [string] -or $value -is [int] -or $value -is [decimal]) {
                    $intermediate.readyToExport[$field] = $value
                }
            }
        }
        
        return $intermediate
    }
    
    # Extract metadata objects in dependency order
    foreach ($typeDef in $typeDefinitions) {
        $typeName = $typeDef.name
        $objects = $null
        
        # Get objects from appropriate source
        if ($Metadata.PSObject.Properties.Name -contains $typeName) {
            $objects = $Metadata.$typeName
        } elseif ($OrgUnitDeps -and $OrgUnitDeps.PSObject.Properties.Name -contains $typeName) {
            $objects = $OrgUnitDeps.$typeName
        } elseif ($UserDeps -and $UserDeps.PSObject.Properties.Name -contains $typeName) {
            $objects = $UserDeps.$typeName
        }
        
        if ($objects -and $objects.Count -gt 0) {
            Write-Host "  Extracting $($objects.Count) $typeName..." -ForegroundColor Gray
            
            foreach ($obj in $objects) {
                if (-not $obj.id) { continue }
                
                $intermediate = Extract-ObjectToIntermediate -Object $obj -TypeName $typeName `
                    -TranslatableFields $typeDef.translatable -TechnicalFields $typeDef.technical
                
                $intermediateObjects[$obj.id] = $intermediate
            }
        }
    }
    
    Write-Host "  ✓ Extracted $($intermediateObjects.Count) objects to intermediate format" -ForegroundColor Green
    
    return @{
        objects = $intermediateObjects
        fieldToTypeMapping = $fieldToMetadataType
    }
}

function Resolve-IntermediateReferences {
    <#
    .SYNOPSIS
        Pass 2: Resolves ID references to identifier strings using type knowledge.
    .DESCRIPTION
        Walks intermediate objects and replaces idsToResolve entries with actual
        identifier strings using Get-IdentifierForType. Uses type-specific knowledge
        to optimize lookups and minimize iterations.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$IntermediateObjects,
        [Parameter(Mandatory)]
        [hashtable]$FieldToTypeMapping
    )
    
    Write-Host "`nPass 2: Resolving references..." -ForegroundColor Cyan
    
    $resolvedCount = 0
    $unresolvedCount = 0
    
    foreach ($objId in $IntermediateObjects.Keys) {
        $intermediate = $IntermediateObjects[$objId]
        $idsToResolve = $intermediate['idsToResolve']
        
        if ($idsToResolve.Count -eq 0) { continue }
        
        foreach ($fieldName in @($idsToResolve.Keys)) {
            $value = $idsToResolve[$fieldName]
            
            # Determine target type from field name
            $targetType = $FieldToTypeMapping[$fieldName]
            if (-not $targetType) {
                Write-Warning "Unknown field type for: $fieldName in $($intermediate['type'])"
                $unresolvedCount++
                continue
            }
            
            # Resolve single ID or array of IDs
            if ($value -is [array]) {
                $identifiers = @()
                foreach ($id in $value) {
                    if ($IntermediateObjects.ContainsKey($id)) {
                        $targetObj = $IntermediateObjects[$id]
                        try {
                            $identifier = Get-IdentifierForType -IntermediateObject $targetObj
                            $identifiers += $identifier
                            $resolvedCount++
                        }
                        catch {
                            Write-Warning "Failed to resolve $fieldName ID $id in $($intermediate['type']): $_"
                            $unresolvedCount++
                        }
                    } else {
                        Write-Warning "Missing reference: $fieldName ID $id not found (referenced by $($intermediate['type']))"
                        $unresolvedCount++
                    }
                }
                
                if ($identifiers.Count -gt 0) {
                    $intermediate['readyToExport'][$fieldName] = $identifiers -join ','
                }
            } else {
                # Single ID
                if ($IntermediateObjects.ContainsKey($value)) {
                    $targetObj = $IntermediateObjects[$value]
                    try {
                        $identifier = Get-IdentifierForType -IntermediateObject $targetObj
                        $intermediate['readyToExport'][$fieldName] = $identifier
                        $resolvedCount++
                    }
                    catch {
                        Write-Warning "Failed to resolve $fieldName ID $value in $($intermediate['type']): $_"
                        $unresolvedCount++
                    }
                } else {
                    Write-Warning "Missing reference: $fieldName ID $value not found (referenced by $($intermediate['type']))"
                    $unresolvedCount++
                }
            }
            
            # Remove from idsToResolve
            $idsToResolve.Remove($fieldName)
        }
    }
    
    Write-Host "  ✓ Resolved $resolvedCount references" -ForegroundColor Green
    if ($unresolvedCount -gt 0) {
        Write-Warning "Failed to resolve $unresolvedCount references (see warnings above)"
    }
}

# Transformer Registry for Pass 3
$script:MetadataTransformers = @{}

function Register-MetadataTransformer {
    <#
    .SYNOPSIS
        Registers a type-specific transformer function.
    .DESCRIPTION
        Allows registration of custom transformation logic for specific metadata types.
        Transformers can handle pattern detection, generator creation, or custom export formats.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TypeName,
        
        [Parameter(Mandatory)]
        [scriptblock]$Transformer
    )
    
    $script:MetadataTransformers[$TypeName] = $Transformer
}

function Transform-IntermediateToOutput {
    <#
    .SYNOPSIS
        Pass 3: Transforms resolved intermediate objects to output format.
    .DESCRIPTION
        Converts resolved intermediate hashtables to CSV/YAML export format.
        Uses transformer registry for type-specific transformations, pattern detection, and generators.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$IntermediateObject
    )
    
    $typeName = $IntermediateObject['type']
    $readyToExport = $IntermediateObject['readyToExport']
    
    # Check for custom transformer
    if ($script:MetadataTransformers.ContainsKey($typeName)) {
        return & $script:MetadataTransformers[$typeName] $IntermediateObject
    }
    
    # Default transformation: split into YAML (translatable) and CSV (technical)
    $yaml = @{}
    $csv = @{}
    
    # Get identifier field for this type
    $identifierField = switch ($typeName) {
        'users' { 'username' }
        { $_ -in 'programStages','programSections','programStageSections',
                  'programIndicators','programRules','programRuleVariables',
                  'programNotificationTemplates','trackedEntityTypes',
                  'organisationUnitLevels' } { 'name' }
        default { 'code' }
    }
    
    # Add identifier to both yaml and csv
    if ($readyToExport.ContainsKey($identifierField)) {
        $yaml[$identifierField] = $readyToExport[$identifierField]
        $csv[$identifierField] = $readyToExport[$identifierField]
    }
    
    # Determine which fields are translatable (YAML) vs technical (CSV)
    # This is a simplified heuristic - can be enhanced with type-specific logic
    $translatableFieldNames = @('name','shortName','description','formName','enrollmentDateLabel',
                                 'incidentDateLabel','executionDateLabel','subjectTemplate','messageTemplate')
    
    foreach ($field in $readyToExport.Keys) {
        if ($field -eq $identifierField) { continue }
        
        $value = $readyToExport[$field]
        
        if ($field -in $translatableFieldNames) {
            $yaml[$field] = $value
        } else {
            $csv[$field] = $value
        }
    }
    
    return @{ yaml = $yaml; csv = $csv }
}

function Export-IntermediateCollection {
    <#
    .SYNOPSIS
        Pass 3: Exports a collection of intermediate objects to YAML/CSV files.
    .DESCRIPTION
        Uses the new three-pass transformation architecture with intermediate hashtables.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TypeName,
        
        [Parameter(Mandatory)]
        [hashtable]$IntermediateObjects,
        
        [Parameter(Mandatory)]
        [string]$OutputDirectory,
        
        [string]$Subdirectory
    )
    
    # Filter intermediate objects by type
    $objectsToExport = @($IntermediateObjects.Values | Where-Object { $_['type'] -eq $TypeName })
    
    if ($objectsToExport.Count -eq 0) {
        Write-Verbose "No $TypeName to export"
        return
    }
    
    Write-Host "  Exporting $($objectsToExport.Count) $TypeName..." -ForegroundColor Yellow
    
    # Determine output path
    $outputPath = $OutputDirectory
    if ($Subdirectory) {
        $outputPath = Join-Path $OutputDirectory $Subdirectory
    }
    
    if (-not (Test-Path $outputPath)) {
        New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
    }
    
    # Transform and collect objects
    $yamlObjects = @()
    $csvObjects = @()
    
    foreach ($intermediate in $objectsToExport) {
        $split = Transform-IntermediateToOutput -IntermediateObject $intermediate
        $yamlObjects += $split.yaml
        $csvObjects += $split.csv
    }
    
    # Write files
    $fileName = $TypeName.ToLower() -replace 'ies$','y' -replace 's$','' # Simple pluralization cleanup
    $yamlPath = Join-Path $outputPath "$fileName.yaml"
    $csvPath = Join-Path $outputPath "$fileName.csv"
    
    $yamlObjects | ConvertTo-Yaml | Set-Content -LiteralPath $yamlPath -Encoding UTF8NoBOM
    $csvObjects | ForEach-Object { [PSCustomObject]$_ } | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8NoBOM
    
    Write-Host "    ✓ Created $yamlPath" -ForegroundColor Green
    Write-Host "    ✓ Created $csvPath" -ForegroundColor Green
}

function Split-MetadataToYamlCsv {
    param(
        [Parameter(Mandatory)]
        [PSObject]$Object,
        
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$TranslatableFields,
        
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$TechnicalFields,
        
        [hashtable]$MetadataLookup = @{}
    )
    
    # Explicit mapping of field names to metadata type names
    $fieldToMetadataType = @{
        'program' = 'programs'
        'programs' = 'programs'
        'programStage' = 'programStages'
        'programStages' = 'programStages'
        'trackedEntityType' = 'trackedEntityTypes'
        'trackedEntityTypes' = 'trackedEntityTypes'
        'trackedEntityAttribute' = 'trackedEntityAttributes'
        'trackedEntityAttributes' = 'trackedEntityAttributes'
        'dataElement' = 'dataElements'
        'dataElements' = 'dataElements'
        'optionSet' = 'optionSets'
        'optionSets' = 'optionSets'
        'option' = 'options'
        'options' = 'options'
        'categoryCombo' = 'categoryCombos'
        'categoryCombos' = 'categoryCombos'
        'category' = 'categories'
        'categories' = 'categories'
        'categoryOption' = 'categoryOptions'
        'categoryOptions' = 'categoryOptions'
        'categoryOptionCombo' = 'categoryOptionCombos'
        'categoryOptionCombos' = 'categoryOptionCombos'
        'organisationUnit' = 'organisationUnits'
        'organisationUnits' = 'organisationUnits'
        'parent' = 'organisationUnits'
        'organisationUnitGroup' = 'organisationUnitGroups'
        'organisationUnitGroups' = 'organisationUnitGroups'
        'organisationUnitLevel' = 'organisationUnitLevels'
        'organisationUnitLevels' = 'organisationUnitLevels'
        'user' = 'users'
        'users' = 'users'
        'userGroup' = 'userGroups'
        'userGroups' = 'userGroups'
        'recipientUserGroup' = 'userGroups'
        'managedGroups' = 'userGroups'
        'userRole' = 'userRoles'
        'userRoles' = 'userRoles'
        'programIndicator' = 'programIndicators'
        'programIndicators' = 'programIndicators'
        'programSection' = 'programSections'
        'programSections' = 'programSections'
        'programStageSection' = 'programStageSections'
        'programStageSections' = 'programStageSections'
        'programRuleVariable' = 'programRuleVariables'
        'programRuleVariables' = 'programRuleVariables'
        'recipientProgramAttribute' = 'trackedEntityAttributes'
    }
    
    # Helper function to extract human-readable identifier from an object
    function Get-ObjectIdentifier {
        param(
            [Parameter(Mandatory)]
            [PSObject]$Object,
            [string]$FieldName
        )
        
        if ($Object.code) { return $Object.code }
        elseif ($Object.name) { return $Object.name }
        elseif ($Object.username) { return $Object.username }
        elseif ($Object.id -and $MetadataLookup.Count -gt 0 -and $FieldName) {
            # Try to resolve via metadata lookup (only for reference fields, not main object)
            $metadataTypeName = $fieldToMetadataType[$FieldName]
            if ($metadataTypeName -and $MetadataLookup.ContainsKey($metadataTypeName) -and $MetadataLookup[$metadataTypeName].ContainsKey($Object.id)) {
                $resolved = $MetadataLookup[$metadataTypeName][$Object.id]
                if ($resolved.code) { return $resolved.code }
                elseif ($resolved.name) { return $resolved.name }
                elseif ($resolved.username) { return $resolved.username }
                else { throw "Cannot export field '$FieldName': resolved object has no code, name, or username. IDs are not allowed." }
            }
            throw "Cannot export field '$FieldName': reference has only ID '$($Object.id)', lookup failed (metadata type: $metadataTypeName). IDs are not allowed in version control."
        }
        else {
            throw "Cannot export field '$FieldName': object has no code, name, or username. IDs are not allowed in version control."
        }
    }
    
    $yaml = @{ }
    $csv = @{ }
    
    # Determine identifier for the main object
    try {
        $identifier = Get-ObjectIdentifier -Object $Object
        $identifierField = if ($Object.code) { 'code' } elseif ($Object.name) { 'name' } else { 'username' }
        $yaml[$identifierField] = $identifier
        $csv[$identifierField] = $identifier
    }
    catch {
        throw "Failed to find identifier: $_"
    }
    
    # Split fields (skip identifier field if already added)
    foreach ($field in $TranslatableFields) {
        if ($field -eq $identifierField) { continue }
        if ($Object.PSObject.Properties.Name -contains $field -and $Object.$field) {
            $yaml[$field] = $Object.$field
        }
    }
    
    foreach ($field in $TechnicalFields) {
        if ($Object.PSObject.Properties.Name -contains $field) {
            $value = $Object.$field
            if ($null -eq $value) { continue }
            
            # Handle GeoJSON Point geometry - extract coordinates as "longitude,latitude"
            if ($field -eq 'geometry' -and $value.type -eq 'Point' -and $value.coordinates) {
                $csv[$field] = "$($value.coordinates[0]),$($value.coordinates[1])"
            }
            # Handle object references (metadata)
            elseif ($value -is [PSCustomObject] -or ($value.PSObject.Properties.Name -contains 'id')) {
                $csv[$field] = Get-ObjectIdentifier -Object $value -FieldName $field
            }
            # Handle arrays
            elseif ($value -is [array]) {
                if ($value.Count -gt 0) {
                    # Check if array contains strings (like authorities) or objects
                    if ($value[0] -is [string]) {
                        # Array of strings - join directly
                        $csv[$field] = $value -join ','
                    } else {
                        # Array of objects - extract identifiers
                        $identifiers = $value | ForEach-Object { Get-ObjectIdentifier -Object $_ -FieldName $field }
                        $csv[$field] = $identifiers -join ','
                    }
                }
            }
            # Handle booleans
            elseif ($value -is [bool]) {
                $csv[$field] = $value.ToString().ToLower()
            }
            # Handle simple values
            elseif ($value -is [string] -or $value -is [int] -or $value -is [decimal]) {
                $csv[$field] = $value
            }
        }
    }
    
    return @{ yaml = $yaml; csv = $csv }
}

function Export-MetadataCollection {
    <#
    .SYNOPSIS
        Exports a collection of metadata objects to YAML/CSV files.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TypeName,
        
        [Parameter(Mandatory)]
        [array]$Objects,
        
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$TranslatableFields,
        
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$TechnicalFields,
        
        [Parameter(Mandatory)]
        [string]$OutputDirectory,
        
        [string]$Subdirectory,
        
        [hashtable]$MetadataLookup = @{}
    )
    
    if ($Objects.Count -eq 0) {
        Write-Verbose "No $TypeName to export"
        return
    }
    
    Write-Host "  Exporting $($Objects.Count) $TypeName..." -ForegroundColor Yellow
    
    # Determine output path
    $outputPath = $OutputDirectory
    if ($Subdirectory) {
        $outputPath = Join-Path $OutputDirectory $Subdirectory
    }
    
    if (-not (Test-Path $outputPath)) {
        New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
    }
    
    # Process objects
    $yamlObjects = @()
    $csvObjects = @()
    
    foreach ($obj in $Objects) {
        # Skip objects without any identifier
        if (-not $obj.code -and -not $obj.name -and -not $obj.username) {
            Write-Warning "Skipping $TypeName object without identifier (no code, name, or username)"
            continue
        }
        
        $split = Split-MetadataToYamlCsv -Object $obj -TranslatableFields $TranslatableFields -TechnicalFields $TechnicalFields -MetadataLookup $MetadataLookup
        $yamlObjects += $split.yaml
        $csvObjects += $split.csv
    }
    
    # Write files
    $fileName = $TypeName.ToLower() -replace 'ies$','y' -replace 's$','' # Simple pluralization cleanup
    $yamlPath = Join-Path $outputPath "$fileName.yaml"
    $csvPath = Join-Path $outputPath "$fileName.csv"
    
    $yamlObjects | ConvertTo-Yaml | Set-Content -LiteralPath $yamlPath -Encoding UTF8NoBOM
    $csvObjects | ForEach-Object { [PSCustomObject]$_ } | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8NoBOM
    
    Write-Host "    ✓ Created $yamlPath" -ForegroundColor Green
    Write-Host "    ✓ Created $csvPath" -ForegroundColor Green
}

function Export-ProgramRules {
    <#
    .SYNOPSIS
        Exports program rules with nested structure: one folder per rule.
    #>
    param(
        [Parameter(Mandatory)]
        [array]$ProgramRules,
        
        [Parameter(Mandatory)]
        [array]$AllProgramRuleActions,
        
        [Parameter(Mandatory)]
        [string]$OutputDirectory
    )
    
    if ($ProgramRules.Count -eq 0) {
        Write-Verbose "No program rules to export"
        return
    }
    
    Write-Host "  Exporting $($ProgramRules.Count) program rules..." -ForegroundColor Yellow
    
    $rulesPath = Join-Path $OutputDirectory 'rules'
    
    # Create hashtable of all actions by ID for quick lookup
    $actionsById = @{}
    foreach ($action in $AllProgramRuleActions) {
        $actionsById[$action.id] = $action
    }
    
    foreach ($rule in $ProgramRules) {
        # Generate folder name from rule name (slug)
        $slug = $rule.name -replace '[^a-zA-Z0-9\s-]', '' -replace '\s+', '-' -replace '-+', '-'
        $slug = $slug.Trim('-').ToLower()
        
        if ([string]::IsNullOrWhiteSpace($slug)) {
            $slug = "rule-$($rule.id.Substring(0,8))"
        }
        
        # Ensure uniqueness by appending first 8 chars of ID if folder exists
        $ruleFolderName = $slug
        $ruleFolderPath = Join-Path $rulesPath $ruleFolderName
        
        if (Test-Path $ruleFolderPath) {
            $ruleFolderName = "$slug-$($rule.id.Substring(0,8))"
            $ruleFolderPath = Join-Path $rulesPath $ruleFolderName
        }
        
        # Create rule folder
        if (-not (Test-Path $ruleFolderPath)) {
            New-Item -Path $ruleFolderPath -ItemType Directory -Force | Out-Null
        }
        
        # Export metadata.yaml (name, description, technical fields)
        $metadata = @{
            name = $rule.name
        }
        
        if ($rule.description) {
            $metadata['description'] = $rule.description
        }
        
        if ($rule.program -and $rule.program.id) {
            $metadata['program'] = $rule.program.id
        }
        
        if ($rule.programStage -and $rule.programStage.id) {
            $metadata['programStage'] = $rule.programStage.id
        }
        
        if ($rule.priority) {
            $metadata['priority'] = $rule.priority
        }
        
        $metadata['id'] = $rule.id
        
        $metadataPath = Join-Path $ruleFolderPath 'metadata.yaml'
        $metadata | ConvertTo-Yaml | Set-Content -LiteralPath $metadataPath -Encoding UTF8NoBOM
        
        # Export condition.dhis2 (rule condition expression)
        if ($rule.condition) {
            $conditionPath = Join-Path $ruleFolderPath 'condition.dhis2'
            $rule.condition | Set-Content -LiteralPath $conditionPath -Encoding UTF8NoBOM -NoNewline
        }
        
        # Export actions
        if ($rule.programRuleActions -and $rule.programRuleActions.Count -gt 0) {
            $actionIndex = 1
            
            foreach ($actionRef in $rule.programRuleActions) {
                $action = $actionsById[$actionRef.id]
                
                if (-not $action) {
                    Write-Warning "Could not find programRuleAction with id: $($actionRef.id)"
                    continue
                }
                
                $actionType = $action.programRuleActionType
                $actionFileName = "action-$actionIndex-$actionType.yaml"
                $actionPath = Join-Path $ruleFolderPath $actionFileName
                
                # Determine if this action type needs a separate expression file
                $needsExpressionFile = $actionType -in @('ASSIGN', 'DISPLAYKEYVALUEPAIR')
                
                $actionData = @{
                    actionType = $actionType
                    id = $action.id
                }
                
                # Include relevant fields based on action type
                if ($action.content) {
                    $actionData['content'] = $action.content
                }
                
                # For ASSIGN and DISPLAYKEYVALUEPAIR, export 'data' to separate .dhis2 file
                if ($action.data) {
                    if ($needsExpressionFile) {
                        # Create separate expression file
                        $expressionFileName = "action-$actionIndex-$actionType-expression.dhis2"
                        $expressionPath = Join-Path $ruleFolderPath $expressionFileName
                        $action.data | Set-Content -LiteralPath $expressionPath -Encoding UTF8NoBOM -NoNewline
                    } else {
                        # Include data in YAML for other action types
                        $actionData['data'] = $action.data
                    }
                }
                
                if ($action.dataElement -and $action.dataElement.id) {
                    $actionData['dataElement'] = $action.dataElement.id
                }
                
                if ($action.trackedEntityAttribute -and $action.trackedEntityAttribute.id) {
                    $actionData['trackedEntityAttribute'] = $action.trackedEntityAttribute.id
                }
                
                if ($action.programIndicator -and $action.programIndicator.id) {
                    $actionData['programIndicator'] = $action.programIndicator.id
                }
                
                if ($action.programStage -and $action.programStage.id) {
                    $actionData['programStage'] = $action.programStage.id
                }
                
                if ($action.programStageSection -and $action.programStageSection.id) {
                    $actionData['programStageSection'] = $action.programStageSection.id
                }
                
                if ($action.option -and $action.option.id) {
                    $actionData['option'] = $action.option.id
                }
                
                if ($action.optionGroup -and $action.optionGroup.id) {
                    $actionData['optionGroup'] = $action.optionGroup.id
                }
                
                if ($action.location) {
                    $actionData['location'] = $action.location
                }
                
                if ($action.templateUid) {
                    $actionData['templateUid'] = $action.templateUid
                }
                
                $actionData | ConvertTo-Yaml | Set-Content -LiteralPath $actionPath -Encoding UTF8NoBOM
                $actionIndex++
            }
        }
        
        Write-Host "    ✓ Created rule: $ruleFolderName" -ForegroundColor Green
    }
}

function Get-OrganisationUnitDependencies {
    <#
    .SYNOPSIS
        Resolves organisation unit dependencies from program metadata.
    #>
    param(
        [PSObject]$Metadata,
        [string[]]$AdditionalOrgUnitIds = @()
    )
    
    # Field specifications:
    # EXPORT FIELDS (written to CSV/YAML):
    #   - Org Units: code, parent, level, openingDate, closedDate, geometry, name, shortName, description
    #   - Groups: organisationUnits (as codes), name, shortName, description
    #   - Group Sets: compulsory, includeSubhierarchyInAnalytics, organisationUnitGroups (as codes), name, shortName, description
    #   - Levels: level, name
    # PERFORMANCE FIELDS (for convergence loops and nested extraction, not exported):
    #   - path: extracts parent hierarchy IDs
    #   - organisationUnitGroups[id]: only IDs needed for convergence checks (details from metadata lookup)
    #   - groupSets[id]: only IDs needed for convergence checks (details from metadata lookup)
    
    Write-Host "`nResolving organisation unit dependencies..." -ForegroundColor Cyan
    
    $orgUnitIds = [System.Collections.Generic.HashSet[string]]::new()
    
    # Merge additional org unit IDs (from users, etc.)
    foreach ($additionalId in $AdditionalOrgUnitIds) {
        if ($additionalId) {
            $orgUnitIds.Add($additionalId) | Out-Null
        }
    }
    
    # Extract org unit references from various metadata types
    foreach ($prop in $Metadata.PSObject.Properties) {
        $objects = $prop.Value
        if ($objects -isnot [array]) { continue }
        
        foreach ($obj in $objects) {
            # Check for organisationUnits property
            if ($obj.PSObject.Properties.Name -contains 'organisationUnits') {
                $orgUnits = $obj.organisationUnits
                if ($orgUnits) {
                    foreach ($ou in $orgUnits) {
                        if ($ou.id) { $orgUnitIds.Add($ou.id) | Out-Null }
                    }
                }
            }
            
            # Check for recipientUserGroup with organisationUnits (notifications)
            if ($obj.PSObject.Properties.Name -contains 'recipientUserGroup') {
                $userGroup = $obj.recipientUserGroup
                if ($userGroup.id) {
                    # Will need to fetch user group details
                }
            }
        }
    }
    
    if ($orgUnitIds.Count -eq 0) {
        Write-Host "  No organisation unit references found" -ForegroundColor Gray
        return $null
    }
    
    Write-Host "  Found $($orgUnitIds.Count) organisation unit references" -ForegroundColor Gray
    Write-Host "  Fetching organisation unit details..." -ForegroundColor Yellow
    
    # Fetch org units
    $orgUnits = @()
    $orgUnitLevels = @()
    $orgUnitGroups = @()
    $orgUnitGroupSets = @()
    
    # Batch fetch all org units with nested dependencies
    if ($orgUnitIds.Count -gt 0) {
        try {
            $idFilter = $orgUnitIds -join ','
            
            # Fetch org units with:
            # - Export fields: code, name, shortName, description, level, openingDate, closedDate, geometry, parent
            # - Performance fields: path (for parent hierarchy extraction), organisationUnitGroups[id] (only IDs, full details from lookup)
            $response = Invoke-DHIS2Api -Endpoint "organisationUnits" -QueryParams @{ 
                filter = "id:in:[$idFilter]"
                fields = 'id,code,name,shortName,description,level,openingDate,closedDate,geometry,path,parent,organisationUnitGroups[id]'
                paging = 'false'
            }
            
            if ($response.organisationUnits) {
                $orgUnits = @($response.organisationUnits)
                
                # Extract parent IDs from path field (format: /id1/id2/id3)
                # This eliminates the need for recursive parent fetching
                $parentIds = [System.Collections.Generic.HashSet[string]]::new()
                foreach ($ou in $orgUnits) {
                    if ($ou.path) {
                        $pathIds = $ou.path.Split('/', [StringSplitOptions]::RemoveEmptyEntries)
                        foreach ($pathId in $pathIds) {
                            if ($pathId -and -not $orgUnitIds.Contains($pathId)) {
                                $parentIds.Add($pathId) | Out-Null
                                $orgUnitIds.Add($pathId) | Out-Null
                            }
                        }
                    }
                }
                
                # Fetch parent org units if any were found in paths
                if ($parentIds.Count -gt 0) {
                    $parentIdFilter = @($parentIds) -join ','
                    # Fetch parents with same fields as initial org units
                    $parentResponse = Invoke-DHIS2Api -Endpoint "organisationUnits" -QueryParams @{ 
                        filter = "id:in:[$parentIdFilter]"
                        fields = 'id,code,name,shortName,description,level,openingDate,closedDate,geometry,path,parent,organisationUnitGroups[id]'
                        paging = 'false'
                    }
                    
                    if ($parentResponse.organisationUnits) {
                        $orgUnits += $parentResponse.organisationUnits
                    }
                }
                
                # Extract groups and group sets from the nested response
                # Since we already fetched them with the org units, extract them now
                foreach ($ou in $orgUnits) {
                    if ($ou.organisationUnitGroups) {
                        foreach ($group in $ou.organisationUnitGroups) {
                            if ($group.id -and -not ($orgUnitGroups | Where-Object { $_.id -eq $group.id })) {
                                $orgUnitGroups += $group
                            }
                            # Extract group sets from groups
                            if ($group.groupSets) {
                                foreach ($groupSet in $group.groupSets) {
                                    if ($groupSet.id -and -not ($orgUnitGroupSets | Where-Object { $_.id -eq $groupSet.id })) {
                                        $orgUnitGroupSets += $groupSet
                                    }
                                }
                            }
                        }
                    }
                }
                
                # Now resolve any missing dependencies in an iterative loop
                # This handles cases where groups/group sets reference objects we don't have yet
                $groupIds = [System.Collections.Generic.HashSet[string]]::new()
                $groupSetIds = [System.Collections.Generic.HashSet[string]]::new()
                
                # Collect IDs we already have
                foreach ($group in $orgUnitGroups) {
                    if ($group.id) { $groupIds.Add($group.id) | Out-Null }
                }
                foreach ($groupSet in $orgUnitGroupSets) {
                    if ($groupSet.id) { $groupSetIds.Add($groupSet.id) | Out-Null }
                }
                
                # Iterate until convergence (no new dependencies found)
                $maxIterations = 10
                $iteration = 0
                
                while ($iteration -lt $maxIterations) {
                    $iteration++
                    $foundNewDependencies = $false
                    
                    # Check if any groups need full details (we might only have id/code/name from nested fetch)
                    # Also fetch any groups referenced by group sets that we don't have
                    $newGroupIds = [System.Collections.Generic.HashSet[string]]::new()
                    
                    # Collect group IDs from group sets
                    foreach ($ougs in $orgUnitGroupSets) {
                        if ($ougs.organisationUnitGroups) {
                            foreach ($groupRef in $ougs.organisationUnitGroups) {
                                if ($groupRef.id -and -not $groupIds.Contains($groupRef.id)) {
                                    $newGroupIds.Add($groupRef.id) | Out-Null
                                }
                            }
                        }
                    }
                    
                    if ($newGroupIds.Count -gt 0) {
                        $foundNewDependencies = $true
                        $groupIdFilter = @($newGroupIds) -join ','
                        # Fetch groups with export fields (code, name, shortName, description) + IDs only for nested objects (convergence)
                        $groupResponse = Invoke-DHIS2Api -Endpoint "organisationUnitGroups" -QueryParams @{ 
                            filter = "id:in:[$groupIdFilter]"
                            fields = 'id,code,name,shortName,description,organisationUnits[id],groupSets[id]'
                            paging = 'false'
                        }
                        if ($groupResponse.organisationUnitGroups) {
                            $orgUnitGroups += $groupResponse.organisationUnitGroups
                            
                            # Track the new group IDs and collect any new group set references
                            foreach ($oug in $groupResponse.organisationUnitGroups) {
                                $groupIds.Add($oug.id) | Out-Null
                                
                                if ($oug.groupSets) {
                                    foreach ($gs in $oug.groupSets) {
                                        if ($gs.id -and -not $groupSetIds.Contains($gs.id)) {
                                            $groupSetIds.Add($gs.id) | Out-Null
                                            if (-not ($orgUnitGroupSets | Where-Object { $_.id -eq $gs.id })) {
                                                $orgUnitGroupSets += $gs
                                            }
                                        }
                                    }
                                }
                                
                                # Collect org unit IDs (for potential additional fetching)
                                if ($oug.organisationUnits) {
                                    foreach ($ou in $oug.organisationUnits) {
                                        if ($ou.id -and -not $orgUnitIds.Contains($ou.id)) {
                                            $orgUnitIds.Add($ou.id) | Out-Null
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    # Fetch any group sets that need full details
                    $newGroupSetIds = [System.Collections.Generic.HashSet[string]]::new()
                    foreach ($ougs in $orgUnitGroupSets) {
                        # Check if this group set only has basic info (just id/code/name)
                        if ($ougs.id -and -not $ougs.PSObject.Properties.Name.Contains('organisationUnitGroups')) {
                            $newGroupSetIds.Add($ougs.id) | Out-Null
                        }
                    }
                    
                    if ($newGroupSetIds.Count -gt 0) {
                        $foundNewDependencies = $true
                        $groupSetIdFilter = @($newGroupSetIds) -join ','
                        # Fetch group sets with export fields (code, name, shortName, description, compulsory, includeSubhierarchyInAnalytics) + group IDs only
                        $groupSetResponse = Invoke-DHIS2Api -Endpoint "organisationUnitGroupSets" -QueryParams @{ 
                            filter = "id:in:[$groupSetIdFilter]"
                            fields = 'id,code,name,shortName,description,compulsory,includeSubhierarchyInAnalytics,organisationUnitGroups[id]'
                            paging = 'false'
                        }
                        if ($groupSetResponse.organisationUnitGroupSets) {
                            # Replace the partial objects with full ones
                            $orgUnitGroupSets = @($orgUnitGroupSets | Where-Object { -not $newGroupSetIds.Contains($_.id) })
                            $orgUnitGroupSets += $groupSetResponse.organisationUnitGroupSets
                            
                            # Collect group IDs from the full group sets
                            foreach ($ougs in $groupSetResponse.organisationUnitGroupSets) {
                                $groupSetIds.Add($ougs.id) | Out-Null
                                
                                if ($ougs.organisationUnitGroups) {
                                    foreach ($group in $ougs.organisationUnitGroups) {
                                        if ($group.id -and -not $groupIds.Contains($group.id)) {
                                            $groupIds.Add($group.id) | Out-Null
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    # Fetch any org units we don't have yet (from groups)
                    $newOrgUnitIds = @($orgUnitIds | Where-Object { -not ($orgUnits | Where-Object { $_.id -eq $_ }) })
                    if ($newOrgUnitIds.Count -gt 0) {
                        $foundNewDependencies = $true
                        $ouIdFilter = $newOrgUnitIds -join ','
                        # Fetch with same fields as initial org units (export + performance fields)
                        $ouResponse = Invoke-DHIS2Api -Endpoint "organisationUnits" -QueryParams @{ 
                            filter = "id:in:[$ouIdFilter]"
                            fields = 'id,code,name,shortName,description,level,openingDate,closedDate,geometry,path,parent,organisationUnitGroups[id]'
                            paging = 'false'
                        }
                        if ($ouResponse.organisationUnits) {
                            $orgUnits += $ouResponse.organisationUnits
                        }
                    }
                    
                    # If no new dependencies were found in this iteration, we're done
                    if (-not $foundNewDependencies) { break }
                }
            }
        }
        catch {
            Write-Warning "Failed to batch fetch organisation units: $_"
        }
    }
    
    # Fetch org unit levels (only need id, code, name, level)
    try {
        $levelsResponse = Invoke-DHIS2Api -Endpoint "organisationUnitLevels" -QueryParams @{ 
            fields = 'id,code,name,level'
            paging = 'false' 
        }
        if ($levelsResponse.organisationUnitLevels) {
            $orgUnitLevels = $levelsResponse.organisationUnitLevels
        }
    }
    catch {
        Write-Warning "Failed to fetch organisation unit levels: $_"
    }
    
    Write-Host "  ✓ Found $($orgUnits.Count) organisation units" -ForegroundColor Green
    Write-Host "  ✓ Found $($orgUnitLevels.Count) organisation unit levels" -ForegroundColor Green
    Write-Host "  ✓ Found $($orgUnitGroups.Count) organisation unit groups" -ForegroundColor Green
    Write-Host "  ✓ Found $($orgUnitGroupSets.Count) organisation unit group sets" -ForegroundColor Green
    
    return @{
        organisationUnits = $orgUnits | Group-Object -Property id | ForEach-Object { $_.Group[0] }
        organisationUnitLevels = $orgUnitLevels
        organisationUnitGroups = $orgUnitGroups | Group-Object -Property id | ForEach-Object { $_.Group[0] }
        organisationUnitGroupSets = $orgUnitGroupSets | Group-Object -Property id | ForEach-Object { $_.Group[0] }
    }
}

function Get-UserMetadataDependencies {
    <#
    .SYNOPSIS
        Resolves user and user group dependencies.
    .DESCRIPTION
        Distinguishes between:
        - Business logic references (notifications, rules, sharing) - always exported
        - Audit trail references (createdBy, lastUpdatedBy) - optional via IncludeAuditUsers
    #>
    param(
        [PSObject]$Metadata,
        [bool]$IncludeAuditUsers = $false
    )
    
    Write-Host "`nResolving user metadata dependencies..." -ForegroundColor Cyan
    
    $userGroupIds = [System.Collections.Generic.HashSet[string]]::new()
    $businessLogicUserIds = [System.Collections.Generic.HashSet[string]]::new()
    $auditTrailUserIds = [System.Collections.Generic.HashSet[string]]::new()
    
    # Extract business logic user group references from notifications
    if ($Metadata.PSObject.Properties.Name -contains 'programNotificationTemplates') {
        foreach ($notification in $Metadata.programNotificationTemplates) {
            if ($notification.recipientUserGroup -and $notification.recipientUserGroup.id) {
                $userGroupIds.Add($notification.recipientUserGroup.id) | Out-Null
            }
        }
    }
    
    # Extract audit trail users from lastUpdatedBy, createdBy fields
    if ($IncludeAuditUsers) {
        foreach ($prop in $Metadata.PSObject.Properties) {
            $objects = $prop.Value
            if ($objects -isnot [array]) { continue }
            
            foreach ($obj in $objects) {
                if ($obj.lastUpdatedBy -and $obj.lastUpdatedBy.id) {
                    $auditTrailUserIds.Add($obj.lastUpdatedBy.id) | Out-Null
                }
                if ($obj.createdBy -and $obj.createdBy.id) {
                    $auditTrailUserIds.Add($obj.createdBy.id) | Out-Null
                }
            }
        }
    }
    
    # ToDo: Extract users from sharing settings (publicAccess, userAccesses, userGroupAccesses)
    # These would be business logic users
    
    if ($userGroupIds.Count -eq 0 -and $businessLogicUserIds.Count -eq 0 -and $auditTrailUserIds.Count -eq 0) {
        Write-Host "  No user metadata references found" -ForegroundColor Gray
        return $null
    }
    
    Write-Host "  Found $($userGroupIds.Count) user group references (business logic)" -ForegroundColor Gray
    Write-Host "  Found $($businessLogicUserIds.Count) user references (business logic)" -ForegroundColor Gray
    if ($IncludeAuditUsers) {
        Write-Host "  Found $($auditTrailUserIds.Count) user references (audit trail)" -ForegroundColor Gray
    } else {
        Write-Host "  Skipping audit trail users (use -IncludeAuditUsers to include)" -ForegroundColor Gray
    }
    
    $userGroups = @()
    $users = @()
    $userRoles = @()
    
    # Batch fetch user groups
    if ($userGroupIds.Count -gt 0) {
        try {
            $ugIdFilter = @($userGroupIds) -join ','
            $ugResponse = Invoke-DHIS2Api -Endpoint "userGroups" -QueryParams @{ 
                filter = "id:in:[$ugIdFilter]"
                fields = ':all'
                paging = 'false'
            }
            
            if ($ugResponse.userGroups) {
                $userGroups = @($ugResponse.userGroups)
                
                # Collect users from groups (these are business logic users)
                foreach ($ug in $userGroups) {
                    if ($ug.users) {
                        foreach ($user in $ug.users) {
                            $businessLogicUserIds.Add($user.id) | Out-Null
                        }
                    }
                }
            }
        }
        catch {
            Write-Warning "Failed to batch fetch user groups: $_"
        }
    }
    
    # Combine business logic and audit trail users
    $allUserIds = [System.Collections.Generic.HashSet[string]]::new($businessLogicUserIds)
    if ($IncludeAuditUsers) {
        foreach ($id in $auditTrailUserIds) {
            $allUserIds.Add($id) | Out-Null
        }
    }
    
    # Batch fetch users (limited info for privacy)
    $referencedOrgUnitIds = [System.Collections.Generic.HashSet[string]]::new()
    
    if ($allUserIds.Count -gt 0) {
        try {
            $userIdFilter = @($allUserIds) -join ','
            $userResponse = Invoke-DHIS2Api -Endpoint "users" -QueryParams @{ 
                filter = "id:in:[$userIdFilter]"
                fields = 'id,code,username,userRoles[id,code,name],organisationUnits[id,code,name],dataViewOrganisationUnits[id,code,name],teiSearchOrganisationUnits[id,code,name],userGroups[id,code,name]'
                paging = 'false'
            }
            
            if ($userResponse.users) {
                $users = @($userResponse.users)
                
                # Collect org unit IDs from user assignments (these need to be resolved as dependencies)
                foreach ($user in $users) {
                    # Primary org units
                    if ($user.organisationUnits) {
                        foreach ($ou in $user.organisationUnits) {
                            if ($ou.id) { $referencedOrgUnitIds.Add($ou.id) | Out-Null }
                        }
                    }
                    # Data view org units
                    if ($user.dataViewOrganisationUnits) {
                        foreach ($ou in $user.dataViewOrganisationUnits) {
                            if ($ou.id) { $referencedOrgUnitIds.Add($ou.id) | Out-Null }
                        }
                    }
                    # TEI search org units
                    if ($user.teiSearchOrganisationUnits) {
                        foreach ($ou in $user.teiSearchOrganisationUnits) {
                            if ($ou.id) { $referencedOrgUnitIds.Add($ou.id) | Out-Null }
                        }
                    }
                }
                
                # Collect all user role IDs
                $roleIds = [System.Collections.Generic.HashSet[string]]::new()
                foreach ($user in $users) {
                    if ($user.userRoles) {
                        foreach ($role in $user.userRoles) {
                            if ($role.id) {
                                $roleIds.Add($role.id) | Out-Null
                            }
                        }
                    }
                }
                
                # Batch fetch all user roles
                if ($roleIds.Count -gt 0) {
                    $roleIdFilter = @($roleIds) -join ','
                    $roleResponse = Invoke-DHIS2Api -Endpoint "userRoles" -QueryParams @{ 
                        filter = "id:in:[$roleIdFilter]"
                        fields = ':all'
                        paging = 'false'
                    }
                    if ($roleResponse.userRoles) {
                        $userRoles = @($roleResponse.userRoles)
                    }
                }
            }
        }
        catch {
            Write-Warning "Failed to batch fetch users: $_"
        }
    }
    
    Write-Host "  ✓ Found $($userGroups.Count) user groups" -ForegroundColor Green
    Write-Host "  ✓ Found $($users.Count) users" -ForegroundColor Green
    Write-Host "  ✓ Found $($userRoles.Count) user roles" -ForegroundColor Green
    Write-Host "  ✓ Found $($referencedOrgUnitIds.Count) org unit references from users" -ForegroundColor Green
    
    return @{
        userGroups = $userGroups | Group-Object -Property id | ForEach-Object { $_.Group[0] }
        users = $users | Group-Object -Property id | ForEach-Object { $_.Group[0] }
        userRoles = $userRoles | Group-Object -Property id | ForEach-Object { $_.Group[0] }
        referencedOrgUnitIds = @($referencedOrgUnitIds)
    }
}

#endregion

#region Fetch Program Metadata with Dependencies

# First, look up the program UID from the code
Write-Host "Looking up program by code: $ProgramCode..." -ForegroundColor Yellow

try {
    $programSearch = Invoke-DHIS2Api -Endpoint "programs" -QueryParams @{
        filter = "code:eq:$ProgramCode"
        fields = 'id,code,name'
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

# Extract program details
if (-not $metadata.programs -or $metadata.programs.Count -eq 0) {
    throw "No program found in metadata response"
}

$program = $metadata.programs[0]

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

#region Resolve Additional Dependencies

# Resolve user metadata first to collect their org unit references
$userDeps = Get-UserMetadataDependencies -Metadata $metadata -IncludeAuditUsers:$IncludeAuditUsers

# Resolve organisation units (including those from users)
$orgUnitDeps = $null
if (-not $SkipOrganisationUnits) {
    $additionalOrgUnitIds = @()
    if ($userDeps -and $userDeps.referencedOrgUnitIds) {
        $additionalOrgUnitIds = $userDeps.referencedOrgUnitIds
    }
    $orgUnitDeps = Get-OrganisationUnitDependencies -Metadata $metadata -AdditionalOrgUnitIds $additionalOrgUnitIds
}

#endregion

#region Export to YAML/CSV

Write-Host "`nExporting to YAML/CSV format..." -ForegroundColor Cyan

# Three-Pass Transformation Architecture

# Pass 1: Extract to intermediate hashtables
$extractResult = Convert-ToIntermediateObjects -Metadata $metadata -OrgUnitDeps $orgUnitDeps -UserDeps $userDeps
$intermediateObjects = $extractResult.objects
$fieldToTypeMapping = $extractResult.fieldToTypeMapping

# Pass 2: Resolve ID references to identifier strings
Resolve-IntermediateReferences -IntermediateObjects $intermediateObjects -FieldToTypeMapping $fieldToTypeMapping

Write-Host "  ✓ Built intermediate objects with resolved references" -ForegroundColor Green

# Validate user org unit references
# Validate user org unit references
if ($userDeps -and $userDeps.referencedOrgUnitIds -and $userDeps.referencedOrgUnitIds.Count -gt 0) {
    Write-Host "`nValidating user org unit references..." -ForegroundColor Yellow
    $missingOrgUnitIds = @()
    
    foreach ($ouId in $userDeps.referencedOrgUnitIds) {
        if (-not $intermediateObjects.ContainsKey($ouId)) {
            $missingOrgUnitIds += $ouId
        }
    }
    
    if ($missingOrgUnitIds.Count -gt 0) {
        Write-Host "  ✗ Found $($missingOrgUnitIds.Count) missing org unit references" -ForegroundColor Red
        Write-Host "  Fetching object details for debugging..." -ForegroundColor Yellow
        
        $missingDetails = @()
        foreach ($missingId in $missingOrgUnitIds) {
            try {
                $objInfo = Invoke-DHIS2Api -Endpoint "identifiableObjects/$missingId"
                $missingDetails += "    - ID: $missingId, Type: $($objInfo.type), Code: $($objInfo.code), Name: $($objInfo.name)"
            }
            catch {
                $missingDetails += "    - ID: $missingId (failed to fetch details: $_)"
            }
        }
        
        $errorMessage = "Missing org unit references from users. This indicates a script bug in dependency resolution.`n"
        $errorMessage += "Missing org units ($($missingOrgUnitIds.Count)):`n"
        $errorMessage += $missingDetails -join "`n"
        
        throw $errorMessage
    }
    
    Write-Host "  ✓ All user org unit references validated" -ForegroundColor Green
}

# Create directory structure
$directories = @(
    $OutputPath,
    (Join-Path $OutputPath 'data-elements'),
    (Join-Path $OutputPath 'tracked-entity-attributes'),
    (Join-Path $OutputPath 'stages'),
    (Join-Path $OutputPath 'program-sections'),
    (Join-Path $OutputPath 'stage-sections'),
    (Join-Path $OutputPath 'program-indicators'),
    (Join-Path $OutputPath 'rules'),
    (Join-Path $OutputPath 'rules/variables'),
    (Join-Path $OutputPath 'notifications'),
    (Join-Path $OutputPath 'options'),
    (Join-Path $OutputPath 'categories'),
    (Join-Path $OutputPath 'organisation-units'),
    (Join-Path $OutputPath 'user-metadata'),
    (Join-Path $OutputPath 'generators')
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

# Pass 3: Export to YAML/CSV files using transformed intermediate objects
Write-Host "`nPass 3: Exporting to files..." -ForegroundColor Cyan

# Export each metadata type (in dependency order)
Export-IntermediateCollection -TypeName 'options' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'options'
Export-IntermediateCollection -TypeName 'categoryOptions' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'categories'
Export-IntermediateCollection -TypeName 'organisationUnitLevels' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'organisation-units'
Export-IntermediateCollection -TypeName 'trackedEntityTypes' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'tracked-entity-attributes'
Export-IntermediateCollection -TypeName 'userRoles' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'user-metadata'

Export-IntermediateCollection -TypeName 'optionSets' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'options'
Export-IntermediateCollection -TypeName 'categories' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'categories'
Export-IntermediateCollection -TypeName 'organisationUnits' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'organisation-units'

Export-IntermediateCollection -TypeName 'categoryCombos' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'categories'
Export-IntermediateCollection -TypeName 'categoryOptionCombos' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'categories'
Export-IntermediateCollection -TypeName 'organisationUnitGroups' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'organisation-units'
Export-IntermediateCollection -TypeName 'organisationUnitGroupSets' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'organisation-units'
Export-IntermediateCollection -TypeName 'userGroups' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'user-metadata'
Export-IntermediateCollection -TypeName 'users' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'user-metadata'

Export-IntermediateCollection -TypeName 'programs' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath
Export-IntermediateCollection -TypeName 'programStages' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'stages'
Export-IntermediateCollection -TypeName 'dataElements' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'data-elements'
Export-IntermediateCollection -TypeName 'trackedEntityAttributes' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'tracked-entity-attributes'
Export-IntermediateCollection -TypeName 'programSections' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'program-sections'
Export-IntermediateCollection -TypeName 'programStageSections' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'stage-sections'
Export-IntermediateCollection -TypeName 'programIndicators' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'program-indicators'
Export-IntermediateCollection -TypeName 'programRuleVariables' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'rules\variables'
Export-IntermediateCollection -TypeName 'programNotificationTemplates' -IntermediateObjects $intermediateObjects -OutputDirectory $OutputPath -Subdirectory 'notifications'

# Program rules still use special Export-ProgramRules function (TODO: migrate to intermediate objects)
if ($metadata.programRules -and $metadata.programRuleActions) {
    Export-ProgramRules -ProgramRules $metadata.programRules -AllProgramRuleActions $metadata.programRuleActions -OutputDirectory $OutputPath
} elseif ($metadata.programRules) {
    Export-ProgramRules -ProgramRules $metadata.programRules -AllProgramRuleActions @() -OutputDirectory $OutputPath
}

#endregion

#region Pattern Detection

if ($DetectPatterns) {
    Write-Host "`nAnalyzing metadata for repetitive patterns..." -ForegroundColor Cyan
    
    if ($metadata.dataElements) {
        $dePatterns = Find-GeneratorPattern -Objects $metadata.dataElements -PatternType IndexSequence
        
        if ($dePatterns.Count -gt 0) {
            Write-Host "`nDetected data element patterns:" -ForegroundColor Yellow
            foreach ($pattern in $dePatterns) {
                Write-Host "  • $($pattern.basePattern): $($pattern.count) items ($($pattern.startIndex)-$($pattern.endIndex))" -ForegroundColor White
                Write-Host "    Examples: $($pattern.examples -join ', ')" -ForegroundColor Gray
            }
        }
    }
    
    if ($metadata.programRules) {
        $rulePatterns = Find-GeneratorPattern -Objects $metadata.programRules -PatternType IndexSequence
        
        if ($rulePatterns.Count -gt 0) {
            Write-Host "`nDetected program rule patterns:" -ForegroundColor Yellow
            foreach ($pattern in $rulePatterns) {
                Write-Host "  • $($pattern.basePattern): $($pattern.count) items" -ForegroundColor White
            }
        }
    }
}

#endregion

#region Summary

Write-Host "`n" + "="*70 -ForegroundColor Cyan
Write-Host "Import Summary" -ForegroundColor Cyan
Write-Host "="*70 -ForegroundColor Cyan
Write-Host "Program:                   $($program.name)" -ForegroundColor White
Write-Host "Program Code:              $ProgramCode" -ForegroundColor White
Write-Host "Output Path:               $OutputPath" -ForegroundColor White
Write-Host ""

# Count exported items
$counts = @{
    'Programs' = if ($metadata.programs) { $metadata.programs.Count } else { 0 }
    'Program Stages' = if ($metadata.programStages) { $metadata.programStages.Count } else { 0 }
    'Data Elements' = if ($metadata.dataElements) { $metadata.dataElements.Count } else { 0 }
    'Tracked Entity Attributes' = if ($metadata.trackedEntityAttributes) { $metadata.trackedEntityAttributes.Count } else { 0 }
    'Program Indicators' = if ($metadata.programIndicators) { $metadata.programIndicators.Count } else { 0 }
    'Program Rules' = if ($metadata.programRules) { $metadata.programRules.Count } else { 0 }
    'Program Rule Variables' = if ($metadata.programRuleVariables) { $metadata.programRuleVariables.Count } else { 0 }
    'Program Rule Actions' = if ($metadata.programRuleActions) { $metadata.programRuleActions.Count } else { 0 }
    'Notifications' = if ($metadata.programNotificationTemplates) { $metadata.programNotificationTemplates.Count } else { 0 }
    'Options' = if ($metadata.options) { $metadata.options.Count } else { 0 }
    'Option Sets' = if ($metadata.optionSets) { $metadata.optionSets.Count } else { 0 }
    'Categories' = if ($metadata.categories) { $metadata.categories.Count } else { 0 }
}

if ($orgUnitDeps) {
    $counts['Organisation Units'] = if ($orgUnitDeps.organisationUnits) { $orgUnitDeps.organisationUnits.Count } else { 0 }
    $counts['Org Unit Levels'] = if ($orgUnitDeps.organisationUnitLevels) { $orgUnitDeps.organisationUnitLevels.Count } else { 0 }
    $counts['Org Unit Groups'] = if ($orgUnitDeps.organisationUnitGroups) { $orgUnitDeps.organisationUnitGroups.Count } else { 0 }
}

if ($userDeps) {
    $counts['User Groups'] = if ($userDeps.userGroups) { $userDeps.userGroups.Count } else { 0 }
    $counts['Users'] = if ($userDeps.users) { $userDeps.users.Count } else { 0 }
    $counts['User Roles'] = if ($userDeps.userRoles) { $userDeps.userRoles.Count } else { 0 }
}

foreach ($key in ($counts.Keys | Sort-Object)) {
    if ($counts[$key] -gt 0) {
        Write-Host ("{0,-30} {1,5}" -f "${key}:", $counts[$key]) -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review imported files in: $OutputPath" -ForegroundColor White
Write-Host "2. Run Update-MetadataTranslations.ps1 to extract translations" -ForegroundColor White
Write-Host "3. Run Validate-Metadata.ps1 to check for issues" -ForegroundColor White
Write-Host "4. Run Create-MetadataPackage.ps1 to build packages" -ForegroundColor White
Write-Host ""
Write-Host "✓ Import complete!" -ForegroundColor Green

#endregion
