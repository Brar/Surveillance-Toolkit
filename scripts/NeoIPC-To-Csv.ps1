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
Get-Dhis2Object programs @{paging='false';fields='*,programTrackedEntityAttributes[trackedEntityAttribute,displayInList,mandatory,searchable,sortOrder],programRuleVariables[*]';filter='code:eq:P_NEOIPC_CORE'} -Unwrap | ForEach-Object {
    $program = $_

    $trackedEntityType = Get-Dhis2Object "trackedEntityTypes/$($program.trackedEntityType.id)"
    $trackedEntityAttributes = Get-Dhis2Object trackedEntityAttributes `
        @{paging='false';fields='*';filter="id:in:[$($program.programTrackedEntityAttributes.trackedEntityAttribute.id | Select-Object -Unique | Join-String -Separator ',')]"} -Unwrap

    $programStages = Get-Dhis2Object programStages @{
        paging='false'
        fields='id,name,description,minDaysFromStart,repeatable,displayGenerateEventBox,autoGenerateEvent,openAfterEnrollment,reportDateToUse,enableUserAssignment,'+`
            'blockEntryForm,remindCompleted,allowGenerateNextVisit,generatedByEnrollmentDate,hideDueDate,preGenerateUID,sortOrder,programStageDataElements[*],programStageSections[*],notificationTemplates[*],translations[*]'
        filter="id:in:[$($program.programStages.id | Select-Object -Unique | Join-String -Separator ',')]"
        order='sortOrder'
    } -Unwrap

    $programStage_notificationTemplates_recipientUserGroups = Get-Dhis2Object userGroups @{paging='false';fields='code';filter="id:in:[$($programStages.notificationTemplates.recipientUserGroup.id | Select-Object -Unique | Join-String -Separator ',')]"} -Unwrap

    $dataElements = Get-Dhis2Object dataElements @{paging='false';fields='*';filter="id:in:[$($programStages.programStageDataElements.dataElement.id | Select-Object -Unique | Join-String -Separator ',')]"} -Unwrap

    $optionSets = Get-Dhis2Object optionSets @{paging='false';fields='id,code,name,valueType,options[code,name,sortOrder,translations[*]]';filter="id:in:[$($dataElements.optionSet.id | Select-Object -Unique | Join-String -Separator ',')]"} -Unwrap

    $program | Select-Object `
        code,`
        programType,`
        name,`
        shortName,`
        description,`
        @{Name = 'trackedEntityType_name'; Expression = { $trackedEntityType.name }},`
        displayFrontPageList,`
        useFirstStageDuringRegistration,`
        accessLevel,`
        openDaysAfterCoEndDate,`
        expiryDays,`
        minAttributesRequiredToSearch,`
        maxTeiCountToReturn,`
        selectEnrollmentDatesInFuture,`
        selectIncidentDatesInFuture,`
        onlyEnrollOnce,`
        displayIncidentDate,`
        enrollmentDateLabel,`
        ignoreOverdueEvents | Export-Csv -Path (Join-Path $Path "$($timestamp)_programs.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

    $program.programTrackedEntityAttributes | Select-Object `
        @{Name = 'program_code'; Expression = { $program.code }},`
        @{Name = 'trackedEntityAttribute_code'; Expression = { $teaId = $_.trackedEntityAttribute.id; ($trackedEntityAttributes | Where-Object id -EQ $teaId).code }},`
        displayInList,`
        mandatory,`
        searchable | Export-Csv -Path (Join-Path $Path "$($timestamp)_programTrackedEntityAttributes.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

    $trackedEntityType | Select-Object `
        name,`
        @{Name = 'icon'; Expression = { $_.style.icon }},`
        description,`
        allowAuditLog,`
        minAttributesRequiredToSearch,`
        maxTeiCountToReturn,`
        featureType | Export-Csv -Path (Join-Path $Path "$($timestamp)_trackedEntityTypes.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

    $trackedEntityType.trackedEntityTypeAttributes | Select-Object `
        @{Name = 'program_code'; Expression = { $program.code }},`
        @{Name = 'trackedEntityAttribute_code'; Expression = { $teaId = $_.trackedEntityAttribute.id; ($trackedEntityAttributes | Where-Object id -EQ $teaId).code }},`
        displayInList,`
        mandatory,`
        searchable | Export-Csv -Path (Join-Path $Path "$($timestamp)_trackedEntityTypeAttributes.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

    $trackedEntityAttributes | Select-Object `
        code,`
        name,`
        shortName,`
        formName,`
        description,`
        fieldMask,`
        @{Name = 'optionSet_code'; Expression = { $osId = $_.optionSet.id; ($optionSets | Where-Object id -EQ $osId).code }},`
        valueType,`
        aggregationType,`
        unique,`
        inherit,`
        confidential,`
        displayInListNoProgram,`
        skipSynchronization | Export-Csv -Path (Join-Path $Path "$($timestamp)_trackedEntityAttributes.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

    $programStages | Select-Object `
        name,`
        description,`
        minDaysFromStart,`
        repeatable,`
        displayGenerateEventBox,`
        autoGenerateEvent,`
        openAfterEnrollment,`
        reportDateToUse,`
        enableUserAssignment,`
        blockEntryForm,`
        remindCompleted,`
        allowGenerateNextVisit,`
        generatedByEnrollmentDate,`
        hideDueDate,`
        preGenerateUID,`
        sortOrder | Export-Csv -Path (Join-Path $Path "$($timestamp)_programStages.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

    $programStages | ForEach-Object {
        $stageName = $_.name
        $_.programStageDataElements | Select-Object `
            @{Name = 'programStage_name'; Expression = { $stageName }},`
            @{Name = 'dataElement_code'; Expression = { $deId = $_.dataElement.id; ($dataElements | Where-Object id -EQ $deId).code }},`
            compulsory,`
            allowProvidedElsewhere,`
            displayInReports,`
            allowFutureDate,`
            skipSynchronization,`
            @{Name = 'renderType_MOBILE_type'; Expression = { $renderType.MOBILE.type }},`
            @{Name = 'renderType_DESKTOP_type'; Expression = { $renderType.DESKTOP.type }}
    } | Export-Csv -Path (Join-Path $Path "$($timestamp)_programStageDataElements.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

    $programStages | ForEach-Object {
        $stageName = $_.name
        $_.programStageSections | Select-Object `
            @{Name = 'programStage_name'; Expression = { $stageName }},`
            name,`
            description,`
            @{Name = 'renderType_MOBILE_type'; Expression = { $renderType.MOBILE.type }},`
            @{Name = 'renderType_DESKTOP_type'; Expression = { $renderType.DESKTOP.type }},`
            sortOrder
    } | Export-Csv -Path (Join-Path $Path "$($timestamp)_programStageSections.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

    $programStages | ForEach-Object {
        $stageName = $_.name
        $_.programStageSections | ForEach-Object {
            $sectionName = $_.name
            $_.dataElements | Select-Object `
                @{Name = 'programStage_name'; Expression = { $stageName }},`
                @{Name = 'programStageSection_name'; Expression = { $sectionName }},`
                @{Name = 'dataElement_code'; Expression = { $deId = $_.id; ($dataElements | Where-Object id -EQ $deId).code }}
        }
    } | Select-Object -Unique | Export-Csv -Path (Join-Path $Path "$($timestamp)_programStageSections_dataElements.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

    $programStages | ForEach-Object {
        $stageName = $_.name
        $_.notificationTemplates | Select-Object `
            @{Name = 'programStage_name'; Expression = { $stageName }},`
            name,`
            notificationTrigger,`
            subjectTemplate,`
            messageTemplate,`
            sendRepeatable,`
            notificationRecipient,`
            notifyUsersInHierarchyOnly,`
            notifyParentOrganisationUnitOnly,`
            @{Name = 'recipientUserGroup_code'; Expression = { $grpId = $_.recipientUserGroup; $programStage_notificationTemplates_recipientUserGroups | Where-Object id -EQ $grpId | Select-Object -ExpandProperty code }}
    } | Select-Object -Unique | Export-Csv -Path (Join-Path $Path "$($timestamp)_programStage_notificationTemplates.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

    $translations = @{ }
    $defaults = [System.Collections.ArrayList]::new()
    $dataElements  | ForEach-Object {
        $dataElement = $_
        $dataElement.translations | ForEach-Object {
            $translation = $_
            if (-not $translations[$translation.locale]) {
                $translations[$translation.locale] = [System.Collections.ArrayList]::new()
            }
            $default = switch ($translation.property) {
                NAME { $dataElement.name }
                SHORT_NAME { $dataElement.shortName }
                FORM_NAME { $dataElement.formName }
                DESCRIPTION { $dataElement.description }
            }
            $translations[$translation.locale].Add(@{
                code = $dataElement.code
                property = $translation.property
                default = $default
                needs_translation = 't'
                $translation.locale = $translation.value
            }) > $null
        }

        # Omit the value type it it can be derived from an option set
        $valueType = if ($dataElement.optionSet) {''} else { $dataElement.valueType }
        $categoryCombo_code = if ($dataElement.categoryCombo.id -eq 'bjDvmb4bfuf'){ 'default' } else {'ToDo'}
        $defaults.Add(@{
            code = $dataElement.code
            name = $dataElement.name
            shortName = $dataElement.shortName
            description = $dataElement.description
            fieldMask = $dataElement.fieldMask
            formName = $dataElement.formName
            domainType = $dataElement.domainType
            valueType = $valueType
            aggregationType = $dataElement.aggregationType
            zeroIsSignificant = $dataElement.zeroIsSignificant
            url = $dataElement.url
            categoryCombo_code = $categoryCombo_code
            optionSet_code= ($optionSets | Where-Object id -EQ $dataElement.optionSet.id).code
            commentOptionSet_code = ($optionSets | Where-Object id -EQ $dataElement.commentOptionSet.id).code
        }) > $null
    }

    $defaults | Sort-Object code | Select-Object `
        code,`
        name,`
        shortName,`
        description,`
        fieldMask,`
        formName,`
        domainType,`
        valueType,`
        aggregationType,`
        zeroIsSignificant,`
        url,`
        categoryCombo_code,`
        optionSet_code,`
        commentOptionSet_code | Export-Csv -Path (Join-Path $Path "$($timestamp)_dataElements.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append

        $translations.keys | ForEach-Object {
            $locale = $_
            $translation = $translations[$_]
            $defaults | ForEach-Object {
                $i = $_;
                'name','shortName','formName','description' | ForEach-Object {
                    $prop = $_
                    switch ($prop) {
                        name {
                            if (-not  $i.name) { continue}
                            $t =  $translation | Where-Object { $_.code -eq $i.code -and $_.property -eq 'NAME' -and $_.default -eq $i.name }
                            if ($t) { $t } else {
                                @{
                                    code = $i.code
                                    property = 'NAME'
                                    default = $i.name
                                    needs_translation = ''
                                    $locale = ''
                                }
                            }        
                        }
                        shortName {
                            if (-not  $i.shortName) { continue}
                            $t =  $translation | Where-Object { $_.code -eq $i.code -and $_.property -eq 'SHORT_NAME' -and $_.default -eq $i.shortName }
                            if ($t) { $t } else {
                                @{
                                    code = $i.code
                                    property = 'SHORT_NAME'
                                    default = $i.shortName
                                    needs_translation = ''
                                    $locale = ''
                                }
                            }        
                        }
                        formName {
                            if (-not  $i.formName) { continue}
                            $t =  $translation | Where-Object { $_.code -eq $i.code -and $_.property -eq 'FORM_NAME' -and $_.default -eq $i.formName }
                            if ($t) { $t } else {
                                @{
                                    code = $i.code
                                    property = 'FORM_NAME'
                                    default = $i.formName
                                    needs_translation = ''
                                    $locale = ''
                                }
                            }        
                        }
                        description {
                            if (-not  $i.description) { continue}
                            $t =  $translation | Where-Object { $_.code -eq $i.code -and $_.property -eq 'DESCRIPTION' -and $_.default -eq $i.description }
                            if ($t) { $t } else {
                                @{
                                    code = $i.code
                                    property = 'DESCRIPTION'
                                    default = $i.description
                                    needs_translation = ''
                                    $locale = ''
                                }
                            }        
                        }
                    }
                }
            } | Select-Object code,property,'default',needs_translation,$locale | Sort-Object code,property | Export-Csv -Path (Join-Path $Path "$($timestamp)_dataElements.$_.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append
        }

    $optionSets | Select-Object code,name,valueType | Export-Csv -Path (Join-Path $Path "$($timestamp)_optionSets.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append
    $translations = @{ }
    $defaults = [System.Collections.ArrayList]::new()
    $optionSets | ForEach-Object {
        $optionSet = $_

        $optionSet.options | ForEach-Object {
            $option = $_

            $option.translations | ForEach-Object {
                $translation = $_
                if (-not $translations[$translation.locale]) { $translations[$translation.locale] = [System.Collections.ArrayList]::new() }
                $translations[$translation.locale].Add(@{ optionSet_code = $optionSet.code; option_code = $option.code; name = $option.name; needs_translation = 't'; "name_$($translation.locale)" = $translation.value }) > $null
            }
            $defaults.Add(@{ optionSet_code = $optionSet.code; option_code = $option.code; name = $option.name; sortOrder = $option.sortOrder }) > $null
        }
    }

    $defaults | Sort-Object optionSet_code,option_code,sortOrder,name | Select-Object optionSet_code,option_code,name,sortOrder | Export-Csv -Path (Join-Path $Path "$($timestamp)_options.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append
    $translations.keys | ForEach-Object {
        $locale = $_
        $translation = $translations[$_]
        $defaults | ForEach-Object {
            $i = $_;
            $t = ($translation | Where-Object { $_.optionSet_code -eq $i.optionSet_code -and $_.option_code -eq $i.option_code -and $_.name -eq $i.name})
            if ($t) {
                $t
            } else {
                $i
            }
        } | Select-Object optionSet_code,option_code,name,needs_translation,"name_$locale" | Export-Csv -Path (Join-Path $Path "$($timestamp)_options.$_.csv") -Encoding utf8NoBOM -UseQuotes AsNeeded -Append
    }
}
