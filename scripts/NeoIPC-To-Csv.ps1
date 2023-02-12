[CmdletBinding(DefaultParameterSetName = 'PersonalAccessToken')]
param (
    [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'A required parameter that specifies the location to save the CSV output files.')]
    [string] $Path,

    [Parameter(Position = 1, ValueFromPipelineByPropertyName, HelpMessage = 'DHIS2 API base URL')]
    [Alias('ApiBase')]
    [string] $Dhis2ApiBase,

    [Parameter(Position = 2, ParameterSetName = 'PersonalAccessToken', ValueFromPipelineByPropertyName, HelpMessage = 'Your personal access token for the DHIS2 API')]
    [securestring] $PersonalAccessToken,

    [Parameter(Position = 2, ParameterSetName = 'UsernamePassword', ValueFromPipelineByPropertyName, HelpMessage = 'Your username for the DHIS2 API')]
    [string] $UserName,

    [Parameter(Position = 3, ParameterSetName = 'UsernamePassword', ValueFromPipelineByPropertyName, HelpMessage = 'Your password for the DHIS2 API')]
    [securestring] $Password
)

Import-Module $PSScriptRoot/modules/Dhis2-Api -Force

if ($Dhis2ApiBase) { Set-Dhis2Defaults -ApiBase $Dhis2ApiBase }
if ($PersonalAccessToken) { Set-Dhis2Defaults -PersonalAccessToken $PersonalAccessToken }
elseif ($UserName -or $Password) { Set-Dhis2Defaults -UserName $UserName -Password $Password }

$timestamp = Get-Date -Format FileDateTimeUniversal

function SaveTranslations {
    param (
        [object[]]$InputObject,
        [string]$ObjectName,
        [switch]$UseName
        # ToDo Parametrize to add parent and grandparent
    )

    $locales = $InputObject.translations.locale | Select-Object -Unique
    $properties = $InputObject.translations.property | Select-Object -Unique
    foreach ($loc in @($locales)) {
        $list = [System.Collections.ArrayList]::new()
        foreach ($obj in @($inputObject)) {
            foreach ($prop in @($properties)) {
                $tran = $obj.translations | Where-Object { $_.locale -eq $loc -and $_.property -eq $prop }
                if ($tran -and $UseName) {
                    $list.Add(($tran | Select-Object `
                    @{Name='name';Expression={$obj.name}},`
                    property,`
                    @{Name='needs_translation';Expression={'t'}},`
                    @{Name='default';Expression={try {$obj | Select-Object -ExpandProperty ($_.property.ToLowerInvariant() -replace '_(\p{L})', { $_.Groups[1].Value.ToUpper() })} catch {''}}},`
                    @{Name="$loc";Expression={$_.value}})) > $null
                } elseif ($tran) {
                    $list.Add(($tran | Select-Object `
                    @{Name='code';Expression={$obj.code}},`
                    property,`
                    @{Name='needs_translation';Expression={'t'}},`
                    @{Name='default';Expression={try {$obj | Select-Object -ExpandProperty ($_.property.ToLowerInvariant() -replace '_(\p{L})', { $_.Groups[1].Value.ToUpper() })} catch {''}}},`
                    @{Name="$loc";Expression={$_.value}})) > $null
                } elseif ($UseName) {
                    $list.Add(($obj | Select-Object `
                    name,`
                    @{Name='property';Expression={$prop}},`
                    @{Name='needs_translation';Expression={''}},`
                    @{Name='default';Expression={$_.name}},`
                    @{Name="$loc";Expression={''}})) > $null
                } else {
                    $list.Add(($obj | Select-Object `
                    code,`
                    @{Name='property';Expression={$prop}},`
                    @{Name='needs_translation';Expression={''}},`
                    @{Name='default';Expression={$_.name}},`
                    @{Name="$loc";Expression={''}})) > $null
                }
            }
        }
        $list  | Export-Csv -Path (Join-Path $Path "$($timestamp)_$ObjectName.$loc.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append
    }
}

# Get objects from DHIS2
# Pick properties:
# Get-Dhis2Object schemas/programStageSection | select -ExpandProperty properties | where { -not $_.simple } | select name, fieldName, href
# Get-Dhis2Object schemas/programStageSection | select -ExpandProperty properties | where { $_.name -in 'id','code' -or $_.persisted -and $_.simple -and $_.readable -and $_.writable -and $_.name -notin 'created','favorites','href','lastUpdated','version'} | select -ExpandProperty name | sort | Join-String -Separator ','
$programs = Get-Dhis2Object programs @{
    paging='false'
    fields='accessLevel,code,completeEventsExpiryDays,description,displayFrontPageList,displayIncidentDate,enrollmentDateLabel,expiryDays,expiryPeriodType,featureType,'+
    'formName,id,ignoreOverdueEvents,incidentDateLabel,maxTeiCountToReturn,minAttributesRequiredToSearch,name,onlyEnrollOnce,openDaysAfterCoEndDate,programType,'+
    'selectEnrollmentDatesInFuture,selectIncidentDatesInFuture,shortName,skipOffline,useFirstStageDuringRegistration'+
    # manually added non-simple-type fields
    ',trackedEntityType,categoryCombo,'+
    'programTrackedEntityAttributes[allowFutureDate,code,displayInList,id,mandatory,renderOptionsAsRadio,renderType,searchable,sortOrder,trackedEntityAttribute],'+
    'programRuleVariables[id],'+
    'programStages[id],'+
    'translations[*]'
    filter='code:$like:NEOIPC_'
} -Unwrap

$programStages = Get-Dhis2Object programStages @{
    paging='false'
    fields='allowGenerateNextVisit,autoGenerateEvent,blockEntryForm,code,description,displayGenerateEventBox,dueDateLabel,enableUserAssignment,executionDateLabel,'+
    'featureType,formName,generatedByEnrollmentDate,hideDueDate,id,minDaysFromStart,name,openAfterEnrollment,periodType,preGenerateUID,remindCompleted,repeatable,'+
    'reportDateToUse,sortOrder,standardInterval,validationStrategy'+
    # manually added non-simple-type fields
    ',program,'+
    'programStageDataElements[allowFutureDate,allowProvidedElsewhere,code,compulsory,displayInReports,id,renderOptionsAsRadio,renderType,skipAnalytics,skipSynchronization,sortOrder,dataElement],'+
    'programStageSections[code,description,formName,id,name,renderType,sortOrder,dataElements,translations],'+
    'notificationTemplates[code,deliveryChannels,id,messageTemplate,name,notificationRecipient,notificationTrigger,notifyParentOrganisationUnitOnly,notifyUsersInHierarchyOnly,'+
        'relativeScheduledDays,sendRepeatable,subjectTemplate,recipientDataElement,recipientProgramAttribute,recipientUserGroup,translations],'+
    'translations[*]'
    filter="id:in:[$($programs.programStages.id | Select-Object -Unique | Join-String -Separator ',')]"
} -Unwrap

$trackedEntityAttributes = Get-Dhis2Object trackedEntityAttributes @{
    paging='false'
    fields='aggregationType,code,confidential,description,displayInListNoProgram,displayOnVisitSchedule,expression,fieldMask,formName,generated,id,inherit,name,orgunitScope,'+
    'pattern,shortName,skipSynchronization,sortOrderInListNoProgram,sortOrderInVisitSchedule,unique,valueType'+
    # manually added non-simple-type fields
    ',translations[*]'
    filter="id:in:[$($programs.programTrackedEntityAttributes.trackedEntityAttribute.id | Select-Object -Unique | Join-String -Separator ',')]"
} -Unwrap

$trackedEntityTypes = Get-Dhis2Object trackedEntityTypes @{
    paging='false'
    fields='allowAuditLog,code,description,featureType,formName,id,maxTeiCountToReturn,minAttributesRequiredToSearch,name'+
    # manually added non-simple-type fields
    ',style,trackedEntityTypeAttributes[code,displayInList,id,mandatory,searchable,trackedEntityAttribute],translations[*]'
    filter="id:in:[$($programs.trackedEntityType.id | Select-Object -Unique | Join-String -Separator ',')]"
} -Unwrap

# ToDo: Find a useful filter for them (this probably requires actually using them)
$userGroups = Get-Dhis2Object userGroups @{
    paging='false'
    fields='code,id,name,managedByGroups,managedGroups'
} -Unwrap

$dataElements = Get-Dhis2Object dataElements @{
    paging='false'
    fields='aggregationLevels,aggregationType,code,description,domainType,fieldMask,formName,id,name,shortName,url,valueType,valueTypeOptions,zeroIsSignificant'+
    # manually added non-simple-type fields
    ',optionSet,commentOptionSet,categoryCombo,translations[*]'
    filter="id:in:[$($programStages.programStageDataElements.dataElement.id | Select-Object -Unique | Join-String -Separator ',')]"
} -Unwrap

$categoryCombos = Get-Dhis2Object categoryCombos @{
    paging='false'
    fields='code,dataDimensionType,id,name,skipTotal'+
    # manually added non-simple-type fields
    ',categories,categoryOptionCombos,translations[*]'
    filter="id:in:[$(@($dataElements.categoryCombo.id) + @($programs.categoryCombo.id) | Select-Object -Unique | Join-String -Separator ',')]"
} -Unwrap

$optionSets = Get-Dhis2Object optionSets @{
    paging='false'
    fields='code,id,name,valueType'+
    # manually added non-simple-type fields
    ',options[code,description,formName,id,name,sortOrder,translations],translations[*]'
    filter="id:in:[$(@($trackedEntityAttributes.optionSet.id) + @($dataElements.optionSet.id) | Select-Object -Unique | Join-String -Separator ',')]"
} -Unwrap

$programRules = Get-Dhis2Object programRules @{
    paging='false'
    fields='code,condition,description,id,name,priority'+
    # manually added non-simple-type fields
    ',program,programStage,'+
    'programRuleActions[code,content,data,evaluationEnvironment,evaluationTime,id,location,programRuleActionType,templateUid,optionGroup,'+
        'programStageSection,programStage,dataElement,option,translations],translations[*]'
    filter="program.id:in:[$($programs.id | Select-Object -Unique | Join-String -Separator ',')]"
} -Unwrap

$programRuleVariables = Get-Dhis2Object programRuleVariables @{
    paging='false'
    fields='code,id,name,programRuleVariableSourceType,useCodeForOptionSet,valueType'+
    # manually added non-simple-type fields
    ',program,programStage,dataElement,translations[*]'
    filter="id:in:[$($programs.programRuleVariables.id | Select-Object -Unique | Join-String -Separator ',')]"
} -Unwrap

$optionSets = Get-Dhis2Object optionSets @{paging='false';fields='id,code,name,valueType,options[code,name,sortOrder,translations[*]]';filter="id:in:[$($dataElements.optionSet.id | Select-Object -Unique | Join-String -Separator ',')]"} -Unwrap

# Export objects as CSV

# programs
$programs | Select-Object code,accessLevel,completeEventsExpiryDays,description,displayFrontPageList,displayIncidentDate,enrollmentDateLabel,expiryDays,expiryPeriodType,`
    featureType,formName,ignoreOverdueEvents,incidentDateLabel,maxTeiCountToReturn,minAttributesRequiredToSearch,name,onlyEnrollOnce,openDaysAfterCoEndDate,programType,`
    selectEnrollmentDatesInFuture,selectIncidentDatesInFuture,shortName,skipOffline,useFirstStageDuringRegistration,`
    @{Name = 'trackedEntityType_name'; Expression = { $trackedEntityTypes | Where-Object id -EQ $_.trackedEntityType.id | Select-Object -ExpandProperty name }} |
    Export-Csv -Path (Join-Path $Path "$($timestamp)_programs.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

SaveTranslations -InputObject $programs -ObjectName programs

# programTrackedEntityAttributes
$programs | ForEach-Object {
    $program = $_
    $program.programTrackedEntityAttributes | Select-Object `
    @{Name = 'program_code'; Expression = { $program.code }},`
    @{Name = 'trackedEntityAttribute_code'; Expression = { $teaId = $_.trackedEntityAttribute.id; ($trackedEntityAttributes | Where-Object id -EQ $teaId).code }},`
    allowFutureDate,displayInList,mandatory,renderOptionsAsRadio,renderType,searchable,sortOrder
} | Sort-Object program_code,sortOrder |
Export-Csv -Path (Join-Path $Path "$($timestamp)_programTrackedEntityAttributes.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

# programStages
$programStages | Select-Object `
    @{Name = 'program_code'; Expression = { $programs | Where-Object id -EQ $_.program.id | Select-Object -ExpandProperty code }},`
    name,allowGenerateNextVisit,autoGenerateEvent,blockEntryForm,description,displayGenerateEventBox,dueDateLabel,enableUserAssignment,executionDateLabel,`
    featureType,formName,generatedByEnrollmentDate,hideDueDate,minDaysFromStart,openAfterEnrollment,periodType,preGenerateUID,remindCompleted,repeatable,reportDateToUse,sortOrder,`
    standardInterval,validationStrategy | Sort-Object program_code,sortOrder |
    Export-Csv -Path (Join-Path $Path "$($timestamp)_programStages.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

SaveTranslations -InputObject $programStages -ObjectName programStages -UseName

# programStageDataElements
$programStages | ForEach-Object {
    $programStage = $_
    $programCode = $programs | Where-Object id -EQ $programStage.program.id | Select-Object -ExpandProperty code
    $programStage.programStageDataElements | Select-Object `
    @{Name = 'program_code'; Expression = { $programCode }},`
    @{Name = 'programStage_name'; Expression = { $programStage.name }},`
    @{Name = 'dataElement_code'; Expression = { $dataElements | Where-Object id -EQ $_.dataElement.id | Select-Object -ExpandProperty code }},`
    allowFutureDate,allowProvidedElsewhere,compulsory,displayInReports,renderOptionsAsRadio,`
    renderType,skipAnalytics,skipSynchronization,sortOrder
} | Sort-Object program_code,programStage_name,sortOrder |
Export-Csv -Path (Join-Path $Path "$($timestamp)_programStageDataElements.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

# programStageSections
$programStages | ForEach-Object {
    $programStage = $_
    $programCode = $programs | Where-Object id -EQ $programStage.program.id | Select-Object -ExpandProperty code
    SaveTranslations -InputObject $programStage.programStageSections -ObjectName programStageSections -UseName
    $programStage.programStageSections | Select-Object `
    @{Name = 'program_code'; Expression = { $programCode }},`
    @{Name = 'programStage_name'; Expression = { $programStage.name }},`
    name,description,formName,renderType,sortOrder
} | Sort-Object program_code,programStage_name,sortOrder |
Export-Csv -Path (Join-Path $Path "$($timestamp)_programStageSections.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

# programNotificationTemplates
$programStages | ForEach-Object {
    $programStage = $_
    $programCode = $programs | Where-Object id -EQ $programStage.program.id | Select-Object -ExpandProperty code
    SaveTranslations -InputObject $programStage.notificationTemplates -ObjectName programNotificationTemplates -UseName
    $programStage.notificationTemplates | Select-Object `
    @{Name = 'program_code'; Expression = { $programCode }},`
    @{Name = 'programStage_name'; Expression = { $programStage.name }},`
    name,messageTemplate,notificationRecipient,notificationTrigger,notifyParentOrganisationUnitOnly,`
    notifyUsersInHierarchyOnly,relativeScheduledDays,sendRepeatable,subjectTemplate,`
    @{Name = 'recipientDataElement_code'; Expression = { $dataElements | Where-Object id -EQ $_.recipientDataElement.id | Select-Object -ExpandProperty code }},`
    @{Name = 'recipientProgramAttribute_code'; Expression = { $trackedEntityAttributes | Where-Object id -EQ $_.recipientProgramAttribute.id | Select-Object -ExpandProperty code }},`
    @{Name = 'recipientUserGroup_code'; Expression = { $userGroups | Where-Object id -EQ $_.recipientUserGroup.id | Select-Object -ExpandProperty code }}
} | Export-Csv -Path (Join-Path $Path "$($timestamp)_programNotificationTemplates.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

# programStageSections.dataElements
$programStages | ForEach-Object {
    $stageName = $_.name
    $_.programStageSections | ForEach-Object {
        $sectionName = $_.name
        $_.dataElements | Select-Object `
            @{Name = 'programStage_name'; Expression = { $stageName }},`
            @{Name = 'programStageSection_name'; Expression = { $sectionName }},`
            @{Name = 'dataElement_code'; Expression = { $deId = $_.id; ($dataElements | Where-Object id -EQ $deId).code }}
    }
} | Select-Object programStage_name,programStageSection_name,dataElement_code -Unique |
Export-Csv -Path (Join-Path $Path "$($timestamp)_programStageSections_dataElements.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

# trackedEntityAttributes
$trackedEntityAttributes | Select-Object code,aggregationType,confidential,description,displayInListNoProgram,displayOnVisitSchedule,expression,fieldMask,formName,`
    generated,inherit,name,orgunitScope,pattern,shortName,skipSynchronization,sortOrderInListNoProgram,sortOrderInVisitSchedule,unique,valueType,`
    @{Name = 'optionSet_code'; Expression = { $osId = $_.optionSet.id; ($optionSets | Where-Object id -EQ $osId).code }} |
    Export-Csv -Path (Join-Path $Path "$($timestamp)_trackedEntityAttributes.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

SaveTranslations -InputObject $trackedEntityAttributes -ObjectName trackedEntityAttributes

# trackedEntityTypes
$trackedEntityTypes | Select-Object name,allowAuditLog,description,featureType,formName,maxTeiCountToReturn,minAttributesRequiredToSearch,`
    @{Name = 'icon'; Expression = { $_.style.icon }} |
    Export-Csv -Path (Join-Path $Path "$($timestamp)_trackedEntityTypes.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

SaveTranslations -InputObject $trackedEntityTypes -ObjectName trackedEntityTypes -UseName

# trackedEntityTypeAttributes
$trackedEntityTypes | ForEach-Object {
    $trackedEntityType = $_
    $trackedEntityType.trackedEntityTypeAttributes | Select-Object `
        @{Name = 'trackedEntityType_name'; Expression = { $trackedEntityType.name }},`
        @{Name = 'trackedEntityAttribute_code'; Expression = { $teaId = $_.trackedEntityAttribute.id; ($trackedEntityAttributes | Where-Object id -EQ $teaId).code }},`
        displayInList,mandatory,searchable
} | Export-Csv -Path (Join-Path $Path "$($timestamp)_trackedEntityTypeAttributes.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

# userGroups
$userGroups | Select-Object code,name |
Export-Csv -Path (Join-Path $Path "$($timestamp)_userGroups.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

# dataElements
$dataElements | Select-Object code,name,aggregationType,description,domainType,fieldMask,formName,shortName,url,`
    valueType,valueTypeOptions,zeroIsSignificant,`
    @{Name = 'optionSet_code'; Expression = { $osId = $_.optionSet.id; ($optionSets | Where-Object id -EQ $osId).code }},`
    @{Name = 'commentOptionSet_code'; Expression = { $osId = $_.commentOptionSet.id; ($optionSets | Where-Object id -EQ $osId).code }},`
    @{Name = 'categoryCombo_code'; Expression = { $ccId = $_.categoryCombo.id; ($categoryCombos | Where-Object id -EQ $ccId).code }} |
Export-Csv -Path (Join-Path $Path "$($timestamp)_dataElements.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

SaveTranslations -InputObject $dataElements -ObjectName dataElements

# optionSets
$optionSets | Select-Object code,name,valueType |
Export-Csv -Path (Join-Path $Path "$($timestamp)_optionSets.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

SaveTranslations -InputObject $optionSets -ObjectName optionSets

# options
$optionSets | ForEach-Object {
    $optionSet = $_
    SaveTranslations -InputObject $optionSet.options -ObjectName options
    $optionSet.options | Select-Object `
        @{Name = 'optionSet_code'; Expression = { $optionSet.code }},`
        code,name,description,formName,sortOrder
} | Export-Csv -Path (Join-Path $Path "$($timestamp)_options.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

# programRules
$programRules | Select-Object `
    @{Name = 'program_code'; Expression = { $programs | Where-Object id -EQ $_.program.id | Select-Object -ExpandProperty code }},`
    @{Name = 'programStage_name'; Expression = { $programStages | Where-Object id -EQ $_.programStage.id | Select-Object -ExpandProperty name }},`
    name,condition,description,priority |
Export-Csv -Path (Join-Path $Path "$($timestamp)_programRules.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

SaveTranslations -InputObject $programRules -ObjectName programRules -UseName

# programRuleActions
$programRules | ForEach-Object {
    $programRule = $_
    SaveTranslations -InputObject $programRule.programRuleActions -ObjectName programRuleActions -UseName
    $programRule.programRuleActions | Select-Object `
        @{Name = 'program_code'; Expression = { $programs | Where-Object id -EQ $programRule.program.id | Select-Object -ExpandProperty code }},`
        @{Name = 'programRule_name'; Expression = { $programRule.name }},`
        content,'data',evaluationEnvironment,evaluationTime,location,programRuleActionType,`
        @{Name = 'template_name'; Expression = { $programStages.notificationTemplates | Where-Object id -EQ $_.templateUid | Select-Object -ExpandProperty name }},`
        @{Name = 'optionGroup_code'; Expression = { $optionGroups | Where-Object id -EQ $_.optionGroup.id | Select-Object -ExpandProperty code }},`
        @{Name = 'programStageSection_name'; Expression = { $programStages.programStageSections | Where-Object id -EQ $_.programStageSection.id | Select-Object -ExpandProperty name }},`
        @{Name = 'programStage_name'; Expression = { $programStages | Where-Object id -EQ $_.programStage.id | Select-Object -ExpandProperty name }},`
        @{Name = 'dataElement_code'; Expression = { $dataElements | Where-Object id -EQ $_.dataElement.id | Select-Object -ExpandProperty code }},`
        @{Name = 'option_code'; Expression = { $options | Where-Object id -EQ $_.option.id | Select-Object -ExpandProperty code }}
} | Export-Csv -Path (Join-Path $Path "$($timestamp)_programRuleActions.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

# programRuleVariables
$programRuleVariables | Select-Object `
    @{Name = 'program_code'; Expression = { $programs | Where-Object id -EQ $_.program.id | Select-Object -ExpandProperty code }},`
    @{Name = 'programStage_name'; Expression = { $programStages | Where-Object id -EQ $_.programStage.id | Select-Object -ExpandProperty name }},`
    name,programRuleVariableSourceType,useCodeForOptionSet,valueType,`
    @{Name = 'dataElement_code'; Expression = { $dataElements | Where-Object id -EQ $_.dataElement.id | Select-Object -ExpandProperty code }} |
Export-Csv -Path (Join-Path $Path "$($timestamp)_programRuleVariables.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

SaveTranslations -InputObject $programRuleVariables -ObjectName programRuleVariables -UseName
