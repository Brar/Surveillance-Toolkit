###############################################
# NeoIPC bootstrap script for a play instance #
###############################################
#
# This PowerShell script can initialize a new dummy NeoIPC installation in DHIS2
# that you can use to play with.

Import-Module $PSScriptRoot/modules/Dhis2-Api -Force

#####################
# organisationUnits #
#####################
$organisationUnits = Import-Csv $PSScriptRoot/../metadata/play/organisationUnits.csv -Encoding utf8NoBOM

# First get the root organisation unit and add it
$rootOrgUnit = $organisationUnits | Where-Object { $_.parent_code -eq '' }
$orgUnitMap = @{}
$rootOrgUnit | Select-Object -ExcludeProperty parent_code | Add-Dhis2Object organisationUnits -CodeMap $orgUnitMap > $null

# Now add the lower level organisation units recursively
$tmpMap = $orgUnitMap.Clone()
while ($tmpMap.Keys.Count -gt 0) {
    $codes = @($tmpMap.Keys)
    foreach ($code in $codes) {
        $organisationUnits | 
             Where-Object { $_.parent_code -eq $code } |
             Select-Object *,@{Name = 'parent'; Expression = {@{id=$tmpMap[$code]}}} -ExcludeProperty parent_code |
             Add-Dhis2Object organisationUnits -CodeMap $tmpMap > $null
        $tmpMap.Remove($code)
    }
}
Remove-Variable organisationUnits

################################
# filledOrganisationUnitLevels #
################################
Add-Dhis2Object filledOrganisationUnitLevels @{
    organisationUnitLevels = @(
        @{
            level = '1'
            name = 'NeoIPC'
            offlineLevels = '1'
        }
        @{
            level = '2'
            name = 'Country'
            offlineLevels = '2'
        }
        @{
            level = '3'
            name = 'Region'
            offlineLevels = '3'
        }
        @{
            level = '4'
            name = 'Hospital'
            offlineLevels = '4'
        }
        @{
            level = '5'
            name = 'Department/Unit'
            offlineLevels = '5'
        }
    )
} > $null

########################################################
# Add access rights for the the root organisation unit #
########################################################
$userId = Get-Dhis2Object me @{paging='false';fields='id'} -Unwrap
$rootOrgUnitId = $orgUnitMap[$rootOrgUnit.code]
Update-Dhis2Object "users/$userId" @(
    @{
        op = 'add'
        path = '/organisationUnits'
        value = @( @{ id = $rootOrgUnitId } )
    }
    @{
        op = 'add'
        path = '/dataViewOrganisationUnits'
        value = @( @{ id = $rootOrgUnitId } )
    }
    @{
        op = 'add'
        path = '/teiSearchOrganisationUnits'
        value = @( @{ id = $rootOrgUnitId } )
    }
) > $null

# ##############
# # optionSets #
# ##############
$optionSets = Import-Csv $PSScriptRoot/../metadata/common/optionSets.csv -Encoding utf8NoBOM
$optionSetMap = @{}
$optionSets | Add-Dhis2Object optionSets -CodeMap $optionSetMap > $null
Remove-Variable optionSets

###########
# options #
###########
$options = Import-Csv $PSScriptRoot/../metadata/common/options.csv -Encoding utf8NoBOM |
    Select-Object code,sortOrder,name,@{Name = 'optionSet'; Expression = {@{id=$optionSetMap[$_.optionSetCode]}}}
$options | Add-Dhis2Object options > $null
Remove-Variable options

# The pathogens, their attributes, and their synonyms are maintained as sparate lists that are used to
# populate options and generate program rules
$PathogenConcepts = Import-Csv $PSScriptRoot/../metadata/common/pathogens/NeoIPC-Pathogen-Concepts.csv -Encoding utf8NoBOM
$PathogenSynonyms = Import-Csv $PSScriptRoot/../metadata/common/pathogens/NeoIPC-Pathogen-Synonyms.csv -Encoding utf8NoBOM

$sortOrder = 1
$pathogenOptionSetId = $optionSetMap.NEOIPC_PATHOGENS
# The "Not listed" option (id = 0) is first
$PathogenOptions = @($PathogenConcepts |
    Where-Object id -EQ 0 |
    Select-Object @{Name = 'code'; Expression = {$_.id}},@{Name = 'name'; Expression = {$_.concept}},@{Name = 'sortOrder'; Expression = {$script:sortOrder}},@{Name = 'optionSet'; Expression = {@{id=$pathogenOptionSetId}}})
# The concepts and synonyms are concatenated and sorted by name
$PathogenOptions += 
    @($PathogenConcepts | Where-Object id -NE 0  | Select-Object @{Name = 'code'; Expression = {$_.id}},@{Name = 'name'; Expression = {"$($_.concept) [$($_.concept_type)]"}}) +
    @($PathogenSynonyms | Select-Object @{Name = 'code'; Expression = {$_.id}},@{Name = 'name'; Expression = {"$($_.synonym) [synonym]"}}) |
    Sort-Object -Property name | Select-Object *,@{Name = 'sortOrder'; Expression = {$script:sortOrder++;$script:sortOrder}},@{Name = 'optionSet'; Expression = {@{id=$pathogenOptionSetId}}}

$PathogenOptions | Add-Dhis2Object options > $null
Remove-Variable PathogenConcepts,PathogenSynonyms,PathogenOptions

################
# dataElements #
################

$dataElements = [System.Collections.ArrayList]::new((Import-Csv $PSScriptRoot/../metadata/common/dataElements.csv -Encoding utf8NoBOM |
    Select-Object -ExcludeProperty optionSetCode,zeroIsSignificant `
        *,`
        @{Name = 'optionSet'; Expression = {if($_.optionSetCode){@{id=$optionSetMap[$_.optionSetCode]}}}},`
        @{Name = 'zeroIsSignificant'; Expression = {[bool]$_.zeroIsSignificant}} | New-Dhis2DataElement))

# Pathogen-related data elements
# The outermost loop iterates the different infection entities we capture
$pathogenRecoveredFromOptionSetId = $optionSetMap.NEOIPC_BSI_PATHOGEN_RECOVERED_FROM
$yesNoNotTestedOptionSetId = $optionSetMap.NEOIPC_YES_NO_NOTTESTED
'NeoIPC BSI','NeoIPC HAP','NeoIPC NEC','NeoIPC SSI' | ForEach-Object {
    # Adjust for secondary BSI.
    # Primary BSI cannot have a secondary BSI and for NEC the
    # secondary BSI is the only source for pathogens we capture
    $pathogenSources = switch ($_) {
        'NeoIPC BSI' { @("$_ Pathogen") }
        'NeoIPC NEC' { @("$_ Secondary BSI pathogen") }
        Default { @("$_ Pathogen", "$_ Secondary BSI pathogen") }
    }
    $pathogenSources | ForEach-Object {
        # The next loop itrates the pathogen indeces (currently 1-3)
        $pathogenSource=$_; 1,2,3 | ForEach-Object{
            $pathogenIndex=$_;
            $indexName = switch ($pathogenIndex) {
                1 {'first'}
                2 {'second'}
                3 {'third'}
                default {"$($pathogenIndex)th"}
            }

            # Data element to select the pathogen
            $pathogenDataElementName = "$pathogenSource $pathogenIndex"
            $pathogenDataElementShortName = $pathogenDataElementName.Replace('Secondary BSI', 'Sec. BSI')
            $pathogenDataElementCode = $pathogenDataElementName.Replace(' ', '_').ToUpperInvariant().Replace('SECONDARY_BSI', 'SEC_BSI')
            $pathogenDataElementFormName = "Pathogen $pathogenIndex"
            $dataElements.Add((New-Dhis2DataElement -DomainType TRACKER -ValueType INTEGER_ZERO_OR_POSITIVE -ZeroIsSignificant `
                -OptionSetId $pathogenOptionSetId `
                -Name $pathogenDataElementName `
                -ShortName $pathogenDataElementShortName `
                -Code $pathogenDataElementCode `
                -FormName $pathogenDataElementFormName `
                -Description "The $indexName detected pathogen.")) > $null

            # Data element to add the pathogen name if it does not exist in the pathogen list
            $dataElements.Add((New-Dhis2DataElement -DomainType TRACKER -ValueType TEXT `
                -Name "$pathogenDataElementName name" `
                -ShortName "$pathogenDataElementShortName name" `
                -Code "$($pathogenDataElementCode)_NAME" `
                -FormName " - name" `
                -Description "The name of the $indexName detected pathogen as it is specified in the laboratory report. Only use this option if no option from the dropdown-list applies.")) > $null

            # The BSI has two extra data elements
            if ($pathogenSource -eq 'NeoIPC BSI Pathogen') {
                # Data element record the fact that a pathogen was recovered multiple times
                $dataElements.Add((New-Dhis2DataElement -DomainType TRACKER -ValueType TRUE_ONLY `
                    -Name "$pathogenDataElementName recovered multiple times" `
                    -ShortName "$pathogenDataElementShortName multiple" `
                    -Code "$($pathogenDataElementCode)_MULTIPLE" `
                    -FormName " - recovered multiple times" `
                    -Description "Check this box if the pathogen selected in ""$pathogenDataElementFormName"" was recovered from at least two blood culture and/or CSF culture specimens collected on separate occasions.")) > $null

                # Data element to select the source of a pathogen
                $dataElements.Add((New-Dhis2DataElement -DomainType TRACKER -ValueType INTEGER_POSITIVE `
                    -OptionSetId $pathogenRecoveredFromOptionSetId `
                    -Name "$pathogenDataElementName source" `
                    -ShortName "$pathogenDataElementShortName source" `
                    -Code "$($pathogenDataElementCode)_SOURCE" `
                    -FormName " - recovered from" `
                    -Description "Select the body site (lab sample material) the $indexName pathogen was recovered from.")) > $null
            }

            '3GCR','carbapenem-resistant','colistin-resistant','MRSA','VRE' | ForEach-Object {
                $pathogenAttributeDataElementCodeAbbrev = $_
                $pathogenAttributeDataElementAbbrev = $_
                switch ($_) {
                    '3GCR' {
                        $pathogenAttributeDataElementDescription = "$pathogenDataElementFormName is a third-generation cephalosporin resistant (3GCR) gram-negative pathogen (sometimes also called ESBL/AmpC). Select ""Yes"" if the isolate recorded as ""$pathogenDataElementFormName"" is not an intrinsically resistant species, was tested for third-generation cephalosporin resistance and the result was positive. Select ""No"" if it was tested and the result was negative. Select ""Not tested"" if no test for third-generation cephalosporin resistance was performed."
                    }
                    'carbapenem-resistant' {
                        $pathogenAttributeDataElementCodeAbbrev = 'CAR'
                        $pathogenAttributeDataElementAbbrev = 'carb-r'
                        $pathogenAttributeDataElementDescription = "$pathogenDataElementFormName is a carbapenem-resistant gram-negative pathogen. Select ""Yes"" if the isolate recorded as ""$pathogenDataElementFormName"" is not an intrinsically resistant species, was tested for carbapenem-resistance and the result was positive. Select ""No"" if it was tested and the result was negative. Select ""Not tested"" if no test for carbapenem-resistance was performed."
                    }
                    'colistin-resistant' {
                        $pathogenAttributeDataElementCodeAbbrev = 'COR'
                        $pathogenAttributeDataElementAbbrev = 'coli-r'
                        $pathogenAttributeDataElementDescription = "$pathogenDataElementFormName is a colistin-resistant gram-negative pathogen. Select ""Yes"" if the isolate recorded as ""$pathogenDataElementFormName"" is not an intrinsically resistant species, was tested for colistin-resistance and the result was positive. Select ""No"" if it was tested and the result was negative. Select ""Not tested"" if no test for colistin-resistance was performed."
                    }
                    'MRSA' {
                        $pathogenAttributeDataElementDescription = "$pathogenDataElementFormName is a methicillin-resistant Staphylococcus aureus (MRSA). Select ""Yes"" if the Staphylococcus aureus isolate recorded as ""$pathogenDataElementFormName"" was tested for MRSA and the result was positive. Select ""No"" if it was tested and the result was negative. Select ""Not tested"" if no test for MRSA was performed."
                    }
                    'VRE' {
                        $pathogenAttributeDataElementDescription = "$pathogenDataElementFormName is a vancomycin-resistant Enterococcus (VRE). Select ""Yes"" if the Enterococcus isolate recorded as ""$pathogenDataElementFormName"" is not an intrinsically resistant species, was tested for vancomycin resistance and the result was positive. Select ""No"" if it was tested and the result was negative. Select ""Not tested"" if no test for vancomycin resistance was performed."
                    }
                }
                # Data element for the pathogen attribute
                $pathogenAttributeDataElementCode = "$($pathogenDataElementCode)_$pathogenAttributeDataElementCodeAbbrev"
                $dataElements.Add((New-Dhis2DataElement -DomainType TRACKER -ValueType INTEGER -ZeroIsSignificant `
                    -OptionSetId $yesNoNotTestedOptionSetId `
                    -Name "$pathogenDataElementName  $_" `
                    -ShortName "$pathogenDataElementShortName  $pathogenAttributeDataElementAbbrev" `
                    -Code $pathogenAttributeDataElementCode -FormName " - $_" `
                    -Description $pathogenAttributeDataElementDescription
                )) > $null
            }
        }
    }
}

$dataElementMap = @{}
$dataElements | Add-Dhis2Object dataElements -CodeMap $dataElementMap > $null

###########################
# trackedEntityAttributes #
###########################
$trackedEntityAttributes = Import-Csv $PSScriptRoot/../metadata/common/trackedEntityAttributes.csv -Encoding utf8NoBOM |
    Select-Object *,@{Name = 'optionSet'; Expression = {if($_.optionSetCode){@{id=$optionSetMap[$_.optionSetCode]}}}} -ExcludeProperty optionSetCode
$trackedEntityAttributeMap = @{}
$trackedEntityAttributes | Add-Dhis2Object trackedEntityAttributes -CodeMap $trackedEntityAttributeMap > $null

######################
# trackedEntityTypes #
######################
# Here we emulate the payload that the web-GUI generates which is weird and also hard to generate.
# This is pretty ugly and probably has room for improvement
$trackedEntityTypesRaw = Import-Csv $PSScriptRoot/../metadata/common/trackedEntityTypes.csv -Encoding utf8NoBOM
$trackedEntityTypeAttributes = Import-Csv $PSScriptRoot/../metadata/common/trackedEntityTypeAttributes.csv -Encoding utf8NoBOM

$trackedEntityTypes = $trackedEntityTypesRaw | ForEach-Object {
    $result = @{}
    $_.PSObject.Properties | ForEach-Object {
        $name = $_.Name
        $value = $_.Value
        switch ($name) {
            'icon' { $result.style = @{ icon = $value } }
            Default {
                if (-not [string]::IsNullOrEmpty($value)) {$result.$name = $value}
            }
        }
    }
    $trackedEntityTypeName = $_.name
    $result.trackedEntityTypeAttributes = @(
        $trackedEntityTypeAttributes | Where-Object trackedEntityTypeName -EQ $trackedEntityTypeName | ForEach-Object {
            $trackedEntityAttribute = ($trackedEntityAttributes | Where-Object code -EQ $_.trackedEntityAttributeCode);
            $r = @{
                displayName = $trackedEntityAttribute.name
                text = $trackedEntityAttribute.name
                value = $trackedEntityAttributeMap[$_.trackedEntityAttributeCode]
                valueType = $trackedEntityAttribute.valueType
            }
            $_.PSObject.Properties | ForEach-Object {
                $n = $_.Name
                $v = $_.Value
                switch ($n) {
                    'searchable' {
                         if ([bool]$trackedEntityAttribute.unique) {$r.unique = $trackedEntityAttribute.unique}
                         $r.$n = $trackedEntityAttribute.unique
                        }
                    'trackedEntityTypeName' { }
                    'trackedEntityAttributeCode' { $r.trackedEntityAttribute = @{ id = $trackedEntityAttributeMap[$v] } }
                    Default {
                        if (-not [string]::IsNullOrEmpty($v)) {$r.$n = $v}
                    }
                }
            }
            $r
        })
    $result
}

$trackedEntityTypes | Add-Dhis2Object trackedEntityTypes -CodeMap $map > $null
