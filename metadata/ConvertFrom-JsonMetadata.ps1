[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$LiteralPath = (Join-Path $PSScriptRoot -ChildPath 'metadata.json')
)

function SerializeObject {
    param (
        [Parameter(Mandatory)]
        [System.Management.Automation.OrderedHashtable]$object,
        [Parameter(Mandatory)]
        [hashtable]$map,
        [Parameter(Mandatory)]
        [string]$outDir
    )

    if ($object -isnot [System.Management.Automation.OrderedHashtable]) {
        throw "Unexpected object type '$($object.GetType())'"
    }

    for ($i = 0; $i -lt $object.Count; $i++) {
        $objectName = $object.Keys[$i]
        $objectValue = $object.Values[$i]
        $dir = Join-Path $outDir -ChildPath $objectName
        New-Item -Path $dir -ItemType Directory
        $file = Join-Path $dir -ChildPath 'data.csv'
        if ($objectValue -is [System.Management.Automation.OrderedHashtable]) {
            $scalarValuesObject = [ordered]@{}
            for ($j = 0; $j -lt $objectValue.Count; $j++) {
                if ($objectValue.Values[$j].GetType().ImplementedInterfaces.Contains([type]'System.Collections.ICollection')) {
                    # ToDo
                    continue
                }
                $scalarValuesObject[$objectValue.Keys[$j]] = $objectValue.Values[$j]
            }
            $scalarValuesObject | Export-Csv -LiteralPath $file -Encoding utf8NoBOM -UseQuotes AsNeeded -UseCulture
        } elseif ($objectValue -is [System.Array]) {
            $scalarValueNames = [System.Collections.ArrayList]::new()
            foreach ($element in $objectValue) {
                if ($element -isnot [System.Management.Automation.OrderedHashtable]) {
                    throw "Unexpected object type '$($object.GetType())'"
                }
                for ($j = 0; $j -lt $element.Count; $j++) {
                    if ($element.Values[$j].GetType().ImplementedInterfaces.Contains([type]'System.Collections.ICollection')) {
                        $itemName = $element.Keys[$j]
                        $itemCollection = $element.Values[$j]
                        if ($itemCollection -is [System.Management.Automation.OrderedHashtable]) {
                            if ($itemCollection.Count -eq 1 -and $itemCollection.Keys[0] -ceq 'id') {
                                if (-not $map['__ElementNameMap'].ContainsKey($itemName)) {
                                    Write-Warning "The element name map does not contain '$itemName'"
                                    continue
                                }
                                $mapElementName = $map['__ElementNameMap'][$itemName]
                                if (-not $map['__MappingTypes'].ContainsKey($mapElementName)) {
                                    Write-Warning "The type map does not contain '$mapElementName'"
                                    continue
                                }
                                if (-not $map.ContainsKey($mapElementName)) {
                                    Write-Warning "The map does not contain $mapElementName"
                                    continue
                                }
                                $idName = $itemName + '__' + $map['__MappingTypes'][$mapElementName]
                                $scalarValueNames.Add($idName) > $null
                                $element[$idName] = $map[$mapElementName][$itemCollection.Values[0]]
                                continue
                            }
                            if ($itemName -ceq 'renderType') {
                                foreach ($renderDevice in $itemCollection.Keys) {
                                    $idName = $itemName + '_' + $renderDevice
                                    $scalarValueNames.Add($idName) > $null
                                    if (-not $itemCollection[$renderDevice].ContainsKey('type')) {
                                        throw 'Unexpected renderType content'
                                    }
                                    $element[$idName] = $itemCollection[$renderDevice].type
                                }
                                continue
                            }
                            if ($itemName -ceq 'lastUpdatedBy') {
                                continue
                            }
                            else {
                                continue
                            }
                            <# Action to perform if the condition is true #>
                        }
                        $subDir = Join-Path $dir -ChildPath $itemName
                        if (-not (Test-Path -LiteralPath $subDir -PathType Container)) {
                            New-Item -Path $subDir -ItemType Directory
                        }
                
                        # ToDo
                        continue
                    }
                    $scalarValueNames.Add($element.Keys[$j]) > $null
                }
            }
            $data = [System.Collections.ArrayList]::new()
            foreach ($element in $objectValue) {
                $item = [ordered]@{}
                $data.Add($item) > $null
                foreach ($name in $scalarValueNames) {
                    if ($element.ContainsKey($name)) {
                        $item[$name] = $element[$name]
                    } else {
                        $item[$name] = ''
                    }
                }
            }

            $data | Export-Csv -LiteralPath $file -Encoding utf8NoBOM -UseQuotes AsNeeded -UseCulture
        }
    }
}

$metadata = Get-Content -Raw -Path $LiteralPath | ConvertFrom-Json -AsHashtable

$objectName = 'optionSets'
if (-not $metadata.ContainsKey($objectName)) {
    throw "The metadata do not contain the required '$objectName' object"
}
$objectValue = $metadata[$objectName]
$dir = Join-Path $PSScriptRoot -ChildPath 'tmp' -AdditionalChildPath $objectName
New-Item -Path $dir -ItemType Directory
$file = Join-Path $dir -ChildPath 'data.csv'
$objectValue |
    Sort-Object -Property code,name,valueType |
    Select-Object -Property code,name,valueType |
    Export-Csv -LiteralPath $file -Encoding utf8NoBOM -UseQuotes AsNeeded -UseCulture

# $codes = @{
#     '__MappingTypes' = @{}
#     '__ElementNameMap' = @{
#         'category' = 'categories'
#         'categoryCombo' = 'categoryCombos'
#         'categoryOptionCombo' = 'categoryOptionCombos'
#         'categoryOption' = 'categoryOptions'
#         'commentOptionSet' = 'optionSets'
#         'dataElement' = 'dataElements'
#         'option' = 'options'
#         'optionSet' = 'optionSets'
#         'programIndicator' = 'programIndicators'
#         'programNotificationTemplate' = 'programNotificationTemplates'
#         'programRuleAction' = 'programRuleActions'
#         'programRule' = 'programRules'
#         'programRuleVariable' = 'programRuleVariables'
#         'program' = 'programs'
#         'programSection' = 'programSections'
#         'programStageDataElement' = 'programStageDataElements'
#         'programStage' = 'programStages'
#         'programStageSection' = 'programStageSections'
#         'programTrackedEntityAttribute' = 'programTrackedEntityAttributes'
#         'trackedEntityAttribute' = 'trackedEntityAttributes'
#         'trackedEntityType' = 'trackedEntityTypes'
#     }
# }

# for ($i = $metadata.Count - 1; $i -ge 0 ; $i--) {
#     $objectName = $metadata.Keys[$i]
#     $objectValue = $metadata.Values[$i]
#     $dir = Join-Path $PSScriptRoot -ChildPath 'tmp' -AdditionalChildPath $objectName
#     New-Item -Path $dir -ItemType Directory
#     switch ($x) {
#         'categories' {  }
#         'categoryCombos' {  }
#         'categoryOptionCombos' {  }
#         'categoryOptions' {  }
#         'dataElements' {  }
#         'options' {  }
#         'optionSets' {  }
#         'programIndicators' {  }
#         'programNotificationTemplates' {  }
#         'programRuleActions' {  }
#         'programRules' {  }
#         'programRuleVariables' {  }
#         'programs' {  }
#         'programSections' {  }
#         'programStageDataElements' {  }
#         'programStages' {  }
#         'programStageSections' {  }
#         'programTrackedEntityAttributes' {  }
#         'system' {  }
#         'trackedEntityAttributes' {  }
#         'trackedEntityTypes' {  }
#     }

#     if ($objectValue -is [System.Array]) {
#         $codes[$objectName] = @{}
#     }
#     switch ($objectName) {
#         { $_ -cin 'categories', 'categoryCombos', 'categoryOptionCombos', 'categoryOptions', 'dataElements', 'options', 'optionSets', 'programIndicators', 'programs', 'trackedEntityAttributes'} {
#             $codes['__MappingTypes'][$objectName] = 'code'
#             foreach ($item in $objectValue) {
#                 $codes[$objectName][$item['id']] = $item['code']
#             }
#         }
#         { $_ -cin 'programNotificationTemplates', 'programRules', 'programRuleVariables', 'programSections', 'programStages', 'programStageSections', 'trackedEntityTypes'} {
#             $codes['__MappingTypes'][$objectName] = 'name'
#             foreach ($item in $objectValue) {
#                 $codes[$objectName][$item['id']] = $item['name']
#             }
#         }
#         { $_ -cin 'programRuleActions', 'programStageDataElements', 'programTrackedEntityAttributes' } {
#             # ToDo
#             $codes['__MappingTypes'][$objectName] = 'UNSUPPORTED'
#         }
#     }
# }

# # $d = Join-Path $PSScriptRoot -ChildPath tmp

# # SerializeObject $metadata $codes $d
