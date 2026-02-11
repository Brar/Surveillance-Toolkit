[AppContext]::SetSwitch("Switch.System.Xml.AllowDefaultResolver", $true);

$AtcUrlTemplate = 'https://www.whocc.no/atc_ddd_index/?code={0}&showdescription=yes'
$AWaReUrlTemplate = 'https://aware.essentialmeds.org/list?query=%22{0}%22'
$LspnUrlTemplate = 'https://lpsn.dsmz.de/{0}'
$MycoBankUrlTemplate = 'https://www.mycobank.org/page/Name%20details%20page/field/Mycobank%20%23/{0}'
$IctvUrlTemplate = 'https://ictv.global/taxonomy/taxondetails?taxnode_id={0}'

function Export-AsciiDocIds {
    param(
        [Parameter(Mandatory)]
        [string]$LiteralPath,
        [switch]$LineNumbers,
        [switch]$FileNames
    )

    $file = Get-Item -LiteralPath $LiteralPath
    $lineNumber = 0
    if ($FileNames) { "File: $($file.FullName)" }
    Get-Content -LiteralPath $file.FullName |
    ForEach-Object {
        $line = $_
        $lineNumber++
        switch -regex ($Line) {
            '^include::(\S+)\[\]' {
                $childFile = Join-Path -Path $file.DirectoryName -ChildPath $matches[1] -Resolve -ErrorAction SilentlyContinue -ErrorVariable includeFileError
                if ($childFile) {
                    Export-AsciiDocIds -LiteralPath $childFile -LineNumbers:$LineNumbers.IsPresent -FileNames:$FileNames.IsPresent
                    if ($FileNames) { "File: $($file.FullName)" }
                }
                else {
                    foreach ($w in $includeFileError) {
                        Write-Warning $w
                    }
                }
            }
            '\[\[(\S+)\]\]' {
                if ($LineNumbers) { "$($lineNumber):$($matches[1])" }
                else { $matches[1] }
            }
            '\[#(\S+)\]' {
                if ($LineNumbers) { "$($lineNumber):$($matches[1])" }
                else { $matches[1] }
            }
        }
    }
}

function Export-AsciiDocReferences {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$LiteralPath,
        [Parameter(Position = 2)]
        [hashtable]$Attributes
    )

    $file = Get-Item -LiteralPath $LiteralPath
    $skip = $false;
    Get-Content -LiteralPath $file.FullName |
    ForEach-Object {
        $line = $_
        switch -regex ($Line) {
            # Singleline ifdef
            '^ifdef::([A-Za-z0-9_\-]+)\[.+\]' {
                if ($skip) { return }
                if (-not ($Attributes -and $Attributes.ContainsKey($matches[1]))) {
                    Write-Debug "Skipping '$_' because the attribute '$($matches[1])' is not defined."
                    return
                }
            }
            # Singleline ifndef
            '^ifndef::([A-Za-z0-9_\-]+)\[.+\]' {
                if ($skip) { return }
                if ($Attributes -and $Attributes.ContainsKey($matches[1])) {
                    Write-Debug "Skipping '$_' because the attribute '$($matches[1])' is defined."
                    return
                }
            }
            # Multiline ifdef
            '^ifdef::([A-Za-z0-9_\-]+)\[\]' {
                if (-not ($Attributes -and $Attributes.ContainsKey($matches[1]))) {
                    Write-Debug "Starting to skip lines within '$_' because the attribute '$($matches[1])' is not defined."
                    $skip = $true
                    return
                }
            }
            # Multiline ifndef
            '^ifndef::([A-Za-z0-9_\-]+)\[\]' {
                if ($Attributes -and $Attributes.ContainsKey($matches[1])) {
                    Write-Debug "Starting to skip lines within '$_' because the attribute '$($matches[1])' is not defined."
                    $skip = $true
                    return
                }
            }
            # endif
            '^endif::[A-Za-z0-9_\-]*\[\]' {
                Write-Debug "Stopping to skip lines."
                $skip = $false
            }
            '^//' {
                # Skip commented lines
                return
            }
            'include::([^[]+)\[.*\]' {
                if ($skip) { return }
                $expanded = $matches[1]
                $expanded = $expanded -replace '\{([A-Za-z0-9_\-]+)\}',{
                    $attribute = $_.Groups[1].Value
                    if ($Attributes -and $Attributes.ContainsKey($attribute)) {
                        $Attributes[$attribute]
                    } else {
                        Write-Error "Cannot resolve attribute reference '{$attribute}' in include '$expanded'."
                        break
                    }
                }
                $childFile = Join-Path -Path $file.DirectoryName -ChildPath $expanded -Resolve -ErrorAction SilentlyContinue -ErrorVariable includeFileError
                if ($childFile) {
                    $childFile
                    Export-AsciiDocReferences -LiteralPath $childFile -Attributes $Attributes
                }
                else {
                    foreach ($w in $includeFileError) {
                        Write-Warning $w
                    }
                }
                return
            }
            'image::?([^[ ]+)\[.*\]' {
                if ($skip) { return }
                $expanded = $matches[1]
                $expanded = $expanded -replace '\{([A-Za-z0-9_\-]+)\}',{
                    $attribute = $_.Groups[1].Value
                    if ($Attributes -and $Attributes.ContainsKey($attribute)) {
                        $Attributes[$attribute]
                    } else {
                        Write-Error "Cannot resolve attribute reference '{$attribute}' in image '$expanded'."
                        break
                    }
                }
                $imageFile = Join-Path -Path $file.DirectoryName -ChildPath 'img' -AdditionalChildPath $expanded -Resolve -ErrorAction SilentlyContinue -ErrorVariable includeFileError
                if ($imageFile) {
                    $imageFile
                }
                else {
                    foreach ($w in $includeFileError) {
                        Write-Warning $w
                    }
                }
                return
            }
        }
    }
}

function Build-Target {
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$TargetFilePath,
        [Parameter(Mandatory, Position = 1)]
        [string[]]$InputFiles,
        [Parameter(Mandatory, Position = 2)]
        [scriptblock]$Command
    )

    # Check if the output file exists
    if (-not (Test-Path $TargetFilePath)) {
        Write-Debug "Output file not found. Running command..."
        & $Command
        return
    }

    # Get the timestamp of the output file
    $outputTimestamp = (Get-Item $TargetFilePath).LastWriteTime

    # Iterate through input files
    foreach ($inputFile in (Resolve-Path -Path $InputFiles)) {
        # Check if the input file exists
        if (-not (Test-Path $inputFile)) {
            Write-Debug "Input file '$inputFile' not found. Skipping..."
            continue
        }

        # Get the timestamp of the input file
        $inputTimestamp = (Get-Item $inputFile).LastWriteTime

        # Compare timestamps
        if ($inputTimestamp -gt $outputTimestamp) {
            Write-Debug "Input file '$inputFile' is newer than output file. Running command..."
            & $Command
            return
        }
    }

    Write-Debug "All input files are older or equal to the output file. No need to run the command."
}

function Get-LocalisedPath {
    [CmdletBinding(DefaultParameterSetName = 'DirectoryFile')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'LiteralPath', Position = 0)]
        [string]$LiteralPath,
        [Parameter(Mandatory, ParameterSetName = 'DirectoryFile', Position = 0)]
        [string]$Directory,
        [Parameter(Mandatory, ParameterSetName = 'DirectoryFile', Position = 1)]
        [string]$File,
        [Parameter(Mandatory, ParameterSetName = 'LiteralPath', Position = 1)]
        [Parameter(Mandatory, ParameterSetName = 'DirectoryFile', Position = 2)]
        [CultureInfo]$TargetCulture,
        [switch]$Resolve,
        [switch]$All,
        [switch]$Existing
    )

    do {
        if (-not $LiteralPath) { $LiteralPath = Join-Path -Path $Directory -ChildPath $File }
        $path = [System.IO.Path]::ChangeExtension($LiteralPath, $TargetCulture.Name + [System.IO.Path]::GetExtension($LiteralPath))
        $TargetCulture = $TargetCulture.Parent
        if ($Resolve) {
            if ($Existing) {
                $path = Resolve-Path -LiteralPath $path -ErrorAction SilentlyContinue
            } else {
                $path = Resolve-Path -LiteralPath $path
            }
        } elseif ($Existing -and -not (Test-Path -LiteralPath $path)) {
            if ($All) {
                continue
            } else {
                return
            }
        }
        if ($All) { $path } else { return $path }
    } while ($TargetCulture.Name)
}

function Import-Translations {
    param (
        [Parameter(Mandatory)]
        [string]$LiteralPath,
        [Parameter(Mandatory)]
        [CultureInfo]$TargetCulture,
        [Parameter(Mandatory)]
        [string[]]$ExpectedProperties
    )

    $translations = [System.Collections.Generic.List[PSCustomObject]]::new()
    # Import translations for the target culture and all of its parent cultures up to (excluding) the invarinat culture into a list of dictionaries.
    $culture = $TargetCulture
    $cultureNames = [System.Collections.Generic.List[string]]::new()
    while ($culture.Name) {
        $cultureNames.Add($culture.Name)
        $translationFile = Get-LocalisedPath -LiteralPath $LiteralPath -TargetCulture $culture -Resolve -ErrorAction SilentlyContinue -ErrorVariable resolveErrors
        # Write a debug message if the translation file for the culture does not exist
        # Due to the implicit locale fallback this neither warrants a warning nor an error
        if (-not $translationFile) {
            foreach ($e in $resolveErrors) {
                Write-Debug $e
             }
             $culture = $culture.Parent
             continue
        }

        # Initialize the dictionary with the expexted properties
        $translationInfos = [System.Collections.Generic.Dictionary[string,System.Collections.Generic.Dictionary[string,PSCustomObject]]]::new()
        foreach ($property in $ExpectedProperties) {
            $translationInfos.Add($property, [System.Collections.Generic.Dictionary[string,PSCustomObject]]::new())
        }

        # Iterate the tanslation file and populate the dictonary
        $translationFileContent = Import-Csv -LiteralPath $translationFile -Encoding utf8NoBOM
        foreach ($item in $translationFileContent) {
            $translationInfo = $null
            if (-not $translationInfos.TryGetValue($item.property, [ref]$translationInfo)) {
                Write-Error "Unexpected property value '$($item.property)' in file '$translationFile'"
                continue
            }
            if ($item.needs_translation -ceq 'f') {
                $translationInfo.Add($item.id,[PSCustomObject]@{NeedsTranslation = $false; DefaultValue = $item.default; TranslatedValue = [string]$null})
            } elseif ($item.needs_translation -ceq 't') {
                $translationInfo.Add($item.id,[PSCustomObject]@{NeedsTranslation = $true; DefaultValue = $item.default; TranslatedValue = $item.translated})
            } elseif ($item.needs_translation -ceq 'u') {
                Write-Warning "Unverified translation value '$($item.translated)' in file '$translationFile'"
                if ($item.translated.Length -gt 0) {
                    $translationInfo.Add($item.id,[PSCustomObject]@{NeedsTranslation = $true; DefaultValue = $item.default; TranslatedValue = $item.translated})
                } else {
                    $translationInfo.Add($item.id,[PSCustomObject]@{NeedsTranslation = $false; DefaultValue = $item.default; TranslatedValue = [string]$null})
                }
            } else {
                Write-Error "Unexpected needs_translation value '$($item.needs_translation)' in file '$translationFile'"
                continue
            }
        }
        $translation = @{ CultureInfo = $culture; TranslationFile = $translationFile }
        $pair = $translationInfos.GetEnumerator()
        while ($pair.MoveNext()) {
            $translation[$pair.Key] = $pair.Value
        }
        $translations.Add([PSCustomObject]$translation)
        $culture = $culture.Parent
    }

    if (-not $TargetCulture.Name) {
        Write-Warning 'Calling Import-Translations with -TargetCulture set to the invariant culture will always return an empty translation list.'
        return [PSCustomObject[]]@()
    } elseif ($translations.Count -eq 0) {
        $sb = [System.Text.StringBuilder]::new()
        foreach ($cultureName in $cultureNames) {
            $sb.Append("'").Append($cultureName).Append("', ") > $null
        }
        $sb.Length -= 2
        Write-Warning "Cannot find a translation file for '$LiteralPath' for any of the following locales $($sb.ToString())."
        return [PSCustomObject[]]@()
    }
    return $translations.ToArray()
}

function New-AntibioticsList {
    param (
        [Parameter(Mandatory)]
        [CultureInfo]$TargetCulture,
        [Parameter(Mandatory)]
        [string]$MetadataPath,
        [switch]$AsciiDoc
    )
    $antibioticsFolderPath = Join-Path -Resolve -Path $MetadataPath -ChildPath 'common' -AdditionalChildPath 'antibiotics'
    $antibioticsFile = Join-Path -Resolve -Path $antibioticsFolderPath -ChildPath 'NeoIPC-Antibiotics.csv'
    $awareFile = Join-Path -Resolve -Path $antibioticsFolderPath -ChildPath 'WHO-AWaRe-Classification-2021.csv'
    $listElementsFile = Join-Path -Resolve -Path $antibioticsFolderPath -ChildPath 'ListElements.csv'

    $awareClasses = [System.Collections.Generic.Dictionary[string, PSCustomObject]]::new()
    $lineNo = 1
    Import-Csv -LiteralPath $awareFile -Encoding utf8NoBOM | ForEach-Object {
        $lineNo++
        $category = $_.category
        switch ($category) {
            'Access' { $c = 'A' }
            'Watch' { $c = 'W' }
            'Reserve' { $c = 'R' }
            Default {
                Write-Warning "Unexpected AWaRe category '$($category)' in '$awareFile' line $lineNo."
                return
            }
        }
        if ($_.atc_code -eq 'to be assigned') { return }
        $awareClasses.Add($_.id,[PSCustomObject]@{
            Category = $c
            Url = $AWaReUrlTemplate -f [System.Web.HttpUtility]::UrlEncode($_.antibiotic)
        })
    }

    if ($TargetCulture.Name) {
        $listElementsTranslations = Import-Translations -LiteralPath $listElementsFile -TargetCulture $TargetCulture -ExpectedProperties 'VALUE'
        $translations = Import-Translations -LiteralPath $antibioticsFile -TargetCulture $TargetCulture -ExpectedProperties 'NAME'
    } else {
        $listElementsTranslations = @()
        $translations = @()
    }

    $listElements = [System.Collections.Generic.Dictionary[string, string]]::new()
    Import-Csv -LiteralPath $listElementsFile -Encoding utf8NoBOM | ForEach-Object {
        foreach ($translation in $listElementsTranslations) {
            $translationInfo = $null
            if ($translation.VALUE.TryGetValue($_.id, [ref]$translationInfo)) {
                if ($_.value -cne $translationInfo.DefaultValue) {
                    Write-Warning "The default value '$($translationInfo.DefaultValue)' for id '$($_.id)' in translation file '$($translation.TranslationFile)' does not match the value '$($_.value)' in '$listElementsFile'."
                }
                if ($translationInfo.NeedsTranslation) {
                    $listElements.add($_.id, $translationInfo.TranslatedValue)
                }
                break
            }
        }
        if (-not $listElements.ContainsKey($_.id)) {
            $listElements.add($_.id, $_.value)
        }
    }

    $atcCodeString = $listElements['atc_code']
    $awareCategoryString = $listElements['aware_category']
    $substanceString = $listElements['substance']

    # Iterate the list of antibiotics and try to find and return the translated row in the requested format.
    Import-Csv -LiteralPath $antibioticsFile -Encoding utf8NoBOM |
    Foreach-Object {
        $substance = $_.name
        $atcUrl = $AtcUrlTemplate -f $_.atc_code
        $awareInfo = $null
        if ($awareClasses.TryGetValue($_.id, [ref]$awareInfo)) {
            $awareCategory = $awareInfo.Category
            $awareUrl = $awareInfo.Url
        } else {
            $awareCategory = $null
            $awareUrl = $null
        }
        foreach ($translation in $translations) {
            $translationInfo = $null
            if ($translation.NAME.TryGetValue($_.id, [ref]$translationInfo)) {
                if ($_.name -cne $translationInfo.DefaultValue) {
                    Write-Warning "The default value '$($translationInfo.DefaultValue)' for id '$($_.id)' in translation file '$($translation.TranslationFile)' does not match the value '$($_.name)' in '$antibioticsFile'."
                }
                if ($translationInfo.NeedsTranslation) {
                    $substance = $translationInfo.TranslatedValue
                }
                return [PSCustomObject][ordered]@{ Id = $_.id; Substance = $substance; AtcCode = $_.atc_code; AtcUrl = $atcUrl; AWaReCategory = $awareCategory; AWaReUrl = $awareUrl }
            }
        }
        if ($TargetCulture.Name -and $translations.Count -gt 0) {
            Write-Warning "Cannot find a translation for id '$($_.id)' in any of the translation files for locale '$($TargetCulture.Name)' or any of its parent locales in directory '$antibioticsFolderPath'. The antibiotic will have its untranslated default name '$($_.name)'."
        }
        return [PSCustomObject][ordered]@{ Id = $_.id; Substance = $substance; AtcCode = $_.atc_code; AtcUrl = $atcUrl; AWaReCategory = $awareCategory; AWaReUrl = $awareUrl }
    } |
    Sort-Object -Culture $TargetCulture -Property 'Substance' |
    ForEach-Object -Begin {
        if ($AsciiDoc) {
            Write-Output '[cols="4,3,^2"]'
            Write-Output '|==='
            Write-Output "|$substanceString |$atcCodeString |$awareCategoryString"
            Write-Output ''
        }
    } -Process {
        if ($AsciiDoc) {
            $a = if ($_.AWaReCategory) { "$($_.AWaReUrl)[image:AWaRe-$($_.AWaReCategory).svg[$($_.AWaReCategory),20],window=_blank]" } else { '' }
            Write-Output "|$($_.Substance) |$($_.AtcUrl)[$($_.AtcCode),window=_blank] |$a"
        } else {
            $_
        }
    } -End {
        if ($AsciiDoc) {
            Write-Output '|==='
        }
    }
}

function New-PathogenList {
    [OutputType([void])]
    param (
        [Parameter(Mandatory)]
        [CultureInfo]$TargetCulture,
        [Parameter(Mandatory)]
        [string]$MetadataPath,
        [switch]$AsciiDoc
    )

    $infectiousAgentsFolderPath = Join-Path -Resolve -Path $MetadataPath -ChildPath 'common' -AdditionalChildPath 'infectious-agents'
    $listElementsFile = Join-Path -Resolve -Path $infectiousAgentsFolderPath -ChildPath 'ListElements.csv'
    $ownedPathogenConceptsFile = Join-Path -Resolve -Path $infectiousAgentsFolderPath -ChildPath 'NeoIPC-Owned-Pathogen-Concepts.csv'
    $infectiousAgentConceptsFile = Join-Path -Resolve -Path $infectiousAgentsFolderPath -ChildPath 'NeoIPC-Pathogen-Concepts.csv'
    $infectiousAgentSynonymsFile = Join-Path -Resolve -Path $infectiousAgentsFolderPath -ChildPath 'NeoIPC-Pathogen-Synonyms.csv'
    if ($TargetCulture.Name) {
        $listElementsTranslations = Import-Translations -LiteralPath $listElementsFile -TargetCulture $TargetCulture -ExpectedProperties 'VALUE'
        $infectiousAgentConceptsTranslations = Import-Translations -LiteralPath $infectiousAgentConceptsFile -TargetCulture $TargetCulture -ExpectedProperties 'CONCEPT'
        $infectiousAgentSynonymsTranslations = Import-Translations -LiteralPath $infectiousAgentSynonymsFile -TargetCulture $TargetCulture -ExpectedProperties 'SYNONYM'
    } else {
        $listElementsTranslations = @()
        $infectiousAgentConceptsTranslations = @()
        $infectiousAgentSynonymsTranslations = @()
    }

    $ownedPathogenConcepts = [System.Collections.Generic.Dictionary[uint, string]]::new()
    $listElements = [System.Collections.Generic.Dictionary[string, string]]::new()
    Import-Csv -LiteralPath $ownedPathogenConceptsFile -Encoding utf8NoBOM | ForEach-Object {
        $ownedPathogenConcepts.Add([uint]::Parse($_.id), ($_.pathogen_type + '_' + ($_.concept_type -replace '\s', '_')))
    }
    Import-Csv -LiteralPath $listElementsFile -Encoding utf8NoBOM | ForEach-Object {
        foreach ($translation in $listElementsTranslations) {
            $translationInfo = $null
            if ($translation.VALUE.TryGetValue($_.id, [ref]$translationInfo)) {
                if ($_.value -cne $translationInfo.DefaultValue) {
                    Write-Warning "The default value '$($translationInfo.DefaultValue)' for id '$($_.id)' in translation file '$($translation.TranslationFile)' does not match the value '$($_.value)' in '$listElementsFile'."
                }
                if ($translationInfo.NeedsTranslation) {
                    $listElements.add($_.id, $translationInfo.TranslatedValue)
                }
                break
            }
        }
        if (-not $listElements.ContainsKey($_.id)) {
            $listElements.add($_.id, $_.value)
        }
    }

    $commonCommensalString = $listElements['common_commensal']
    $recognisedPathogenString = $listElements['recognised_pathogen']
    $MRSAString = $listElements['mrsa']
    $VREString = $listElements['vre']
    $3GCRString = $listElements['3gcr']
    $carbapenemsString = $listElements['carbapenems']
    $colistinString = $listElements['colistin']
    $synonymForString = $listElements['synonym_for']
    $assumedPathogenicityString = $listElements['assumed_pathogenicity']
    $nameString = $listElements['name']
    $recordedResistancesString = $listElements['recorded_resistances']
    $typeString = $listElements['type']

    $infectiousAgentConcepts = Import-Csv -LiteralPath $infectiousAgentConceptsFile -Encoding utf8NoBOM
    $infectiousAgentList = [System.Collections.Generic.List[PSCustomObject]]::new()
    $infectiousAgentConceptDictionary = [System.Collections.Generic.Dictionary[uint,PSCustomObject]]::new()
    $lineNo = 1
    foreach ($infectiousAgentConcept in $infectiousAgentConcepts) {
        $lineNo++
        # Validate the input file
        if ($infectiousAgentConcept.concept.Trim().Length -eq 0) {
            throw "Missing concept value in line $lineNo in file '$infectiousAgentConceptsFile'."
        }
        if ($infectiousAgentConcept.concept.Trim() -cne $infectiousAgentConcept.concept) {
            throw "Concept value with superflous whitespace in line $lineNo in file '$infectiousAgentConceptsFile'."
        }
        if ($infectiousAgentConcept.concept_type -cnotin 'clade','family','genus','group','serotype','species','species complex','subspecies','unknown','variety') {
            throw "Unknown concept type in line $lineNo in file '$infectiousAgentConceptsFile'."
        }
        switch -casesensitive ($infectiousAgentConcept.concept_source) {
            'LPSN' {
                $urlTemplate = $LspnUrlTemplate
                $listElementKey = 'bacterial_' + $infectiousAgentConcept.concept_type -creplace '\s', '_'
                break
            }
            'MycoBank' {
                $urlTemplate = $MycoBankUrlTemplate
                $listElementKey = 'fungal_' + $infectiousAgentConcept.concept_type -creplace '\s', '_'
                break
            }
            'ICTV' {
                $urlTemplate = $IctvUrlTemplate
                $listElementKey = 'viral_' + $infectiousAgentConcept.concept_type -creplace '\s', '_'
                break
            }
            'NeoIPC' {
                $urlTemplate = $null
                $listElementKey = if ($infectiousAgentConcept.concept_type -ceq 'unknown') { 'unknown' } else { $ownedPathogenConcepts[[uint]::Parse($infectiousAgentConcept.concept_id)] }
                break
            }
            default {
                throw "Unknown concept source '$($infectiousAgentConcept.concept_source)' in line $lineNo in file '$infectiousAgentConceptsFile'."
            }
        }

        $url = if ($urlTemplate) { $urlTemplate -f $infectiousAgentConcept.concept_id } else { $null }
        $infectiousAgentConceptType = $listElements[$listElementKey]

        $infectiousAgentName = $infectiousAgentConcept.concept
        foreach ($translation in $infectiousAgentConceptsTranslations) {
            $translationInfo = $null
            if ($translation.CONCEPT.TryGetValue($infectiousAgentConcept.id, [ref]$translationInfo)) {
                if ($infectiousAgentConcept.concept -cne $translationInfo.DefaultValue) {
                    Write-Warning "The default value '$($translationInfo.DefaultValue)' for id '$($infectiousAgentConcept.id)' in translation file '$($translation.TranslationFile)' does not match the value '$($infectiousAgentConcept.concept)' in '$infectiousAgentConceptsFile'."
                }
                if ($translationInfo.NeedsTranslation) {
                    $infectiousAgentName = $translationInfo.TranslatedValue
                }
                break
            }
        }

        if ($infectiousAgentConcept.is_cc -ceq 't') {
            $pathogenicity = $commonCommensalString
        } elseif ($infectiousAgentConcept.is_cc -ceq 'f') {
            $pathogenicity = $recognisedPathogenString
        }  else {
            throw "Unexpected boolen value '$($infectiousAgentConcept.is_cc)' in line $lineNo file '$infectiousAgentConceptsFile'."
        }

        $recordedResistances = [System.Collections.Generic.List[string]]::new()
        if ($infectiousAgentConcept.show_mrsa -ceq 't') {
            $recordedResistances.Add($MRSAString)
        } elseif (-not($infectiousAgentConcept.show_mrsa -ceq 'f')) {
            throw "Unexpected boolen value '$($infectiousAgentConcept.show_mrsa)' in line $lineNo file '$infectiousAgentConceptsFile'."
        }
        if ($infectiousAgentConcept.show_vre -ceq 't') {
            $recordedResistances.Add($VREString)
        } elseif (-not($infectiousAgentConcept.show_vre -ceq 'f')) {
            throw "Unexpected boolen value '$($infectiousAgentConcept.show_vre)' in line $lineNo file '$infectiousAgentConceptsFile'."
        }
        if ($infectiousAgentConcept.show_3gcr -ceq 't') {
            $recordedResistances.Add($3GCRString)
        } elseif (-not($infectiousAgentConcept.show_3gcr -ceq 'f')) {
            throw "Unexpected boolen value '$($infectiousAgentConcept.show_3gcr)' in line $lineNo file '$infectiousAgentConceptsFile'."
        }
        if ($infectiousAgentConcept.show_carb_r -ceq 't') {
            $recordedResistances.Add($carbapenemsString)
        } elseif (-not($infectiousAgentConcept.show_carb_r -ceq 'f')) {
            throw "Unexpected boolen value '$($infectiousAgentConcept.show_carb_r)' in line $lineNo file '$infectiousAgentConceptsFile'."
        }
        if ($infectiousAgentConcept.show_coli_r -ceq 't') {
            $recordedResistances.Add($colistinString)
        } elseif (-not($infectiousAgentConcept.show_coli_r -ceq 'f')) {
            throw "Unexpected boolen value '$($infectiousAgentConcept.show_coli_r)' in line $lineNo file '$infectiousAgentConceptsFile'."
        }

        $infectiousAgentConceptId = [uint]::Parse($infectiousAgentConcept.id)
        $infectiousAgentConceptObject = [PSCustomObject]@{
            Id = $infectiousAgentConceptId
            Name = $infectiousAgentName
            Type = $infectiousAgentConceptType
            AssumedPathogenicity = $pathogenicity
            RecordedResistances = $recordedResistances.ToArray()
            Url = $url
            SynonymFor = $null
        }
        $infectiousAgentConceptDictionary.Add($infectiousAgentConceptId, $infectiousAgentConceptObject)
        $infectiousAgentList.Add($infectiousAgentConceptObject)
    }

    $infectiousAgentSynonyms = Import-Csv -LiteralPath $infectiousAgentSynonymsFile -Encoding utf8NoBOM
    $lineNo = 1
    foreach ($infectiousAgentSynonym in $infectiousAgentSynonyms) {
        $lineNo++
        # Validate the input file
        if ($infectiousAgentSynonym.synonym.Trim().Length -eq 0) {
            throw "Missing concept value in line $lineNo in file '$infectiousAgentSynonymsFile'."
        }
        if ($infectiousAgentSynonym.synonym.Trim() -cne $infectiousAgentSynonym.synonym) {
            throw "Concept value with superflous whitespace in line $lineNo in file '$infectiousAgentSynonymsFile'."
        }
        switch -casesensitive ($infectiousAgentSynonym.concept_source) {
            'LPSN' {
                $urlTemplate = $LspnUrlTemplate
                break
            }
            'MycoBank' {
                $urlTemplate = $MycoBankUrlTemplate
                break
            }
            'ICTV' {
                $urlTemplate = $IctvUrlTemplate
                break
            }
            'NeoIPC' {
                $urlTemplate = $null
                break
            }
            default {
                throw "Unknown concept source '$($infectiousAgentSynonym.concept_source)' in line $lineNo in file '$infectiousAgentSynonymsFile'."
            }
        }

        $url = if ($urlTemplate) { $urlTemplate -f $infectiousAgentSynonym.concept_id } else { $null }
        $infectiousAgentSynonymName = $infectiousAgentSynonym.synonym
        foreach ($translation in $infectiousAgentSynonymsTranslations) {
            $translationInfo = $null
            if ($translation.SYNONYM.TryGetValue($infectiousAgentSynonym.id, [ref]$translationInfo)) {
                if ($infectiousAgentSynonym.synonym -cne $translationInfo.DefaultValue) {
                    Write-Warning "The default value '$($translationInfo.DefaultValue)' for id '$($infectiousAgentSynonym.id)' in translation file '$($translation.TranslationFile)' does not match the value '$($infectiousAgentSynonym.synonym)' in '$infectiousAgentSynonymsFile'."
                }
                if ($translationInfo.NeedsTranslation) {
                    $infectiousAgentSynonymName = $translationInfo.TranslatedValue
                }
                break
            }
        }
        $parentConcept = $infectiousAgentConceptDictionary[[uint]::Parse($infectiousAgentSynonym.synonym_for)]
        $infectiousAgentList.Add([PSCustomObject]@{
            Id = [uint]::Parse($infectiousAgentSynonym.id)
            Name = $infectiousAgentSynonymName
            Type = $parentConcept.Type
            AssumedPathogenicity = $parentConcept.AssumedPathogenicity
            RecordedResistances = $parentConcept.RecordedResistances
            Url = $url
            SynonymFor = $parentConcept
        })
    }

    $infectiousAgentList |
    Sort-Object -Property Name -Culture $TargetCulture.Name |
    ForEach-Object -Begin {
        if ($AsciiDoc) {
            Write-Output '[.small,cols="5,3,3,3"]'
            Write-Output '|==='
            Write-Output "|$nameString |$typeString |$assumedPathogenicityString |$recordedResistancesString"
            Write-Output ''
        }
    } -Process {
        if ($AsciiDoc) {
            $type = if ($_.Url) { "$($_.Url)[$($_.Type),window=_blank]" } else { $_.Type }
            if ($_.SynonymFor) {
                $type += " ($synonymForString xref:infectious-agent-concept-$($_.SynonymFor.Id)[$($_.SynonymFor.Name)])"
            }
            Write-Output "|[[infectious-agent-concept-$($_.Id)]]$($_.Name) |$type |$($_.AssumedPathogenicity) |$($_.RecordedResistances -join ', ')"
        } else {
            $_
        }
    } -End {
        if ($AsciiDoc) {
            Write-Output '|==='
        }
    }
}

function Test-ChildObject {
    param (
        [Parameter(Position=0, Mandatory)]
        [System.Management.Automation.OrderedHashtable]$Metadata,
        [Parameter(Position=1, Mandatory, ValueFromPipeline)]
        [string[]]$ChildObjectNames,
        [switch]$Throw
    )
    foreach ($childObjectName in $ChildObjectNames) {
        if (-not $Metadata.ContainsKey($childObjectName)) {
            if ($Throw) {
                throw "The metadata do not contain the required child object '$childObjectName'"
            }
            return $false
        }
    }
    return $true
}

function Get-ChildObject {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory, ValueFromPipeline)]
        [System.Management.Automation.OrderedHashtable]$Metadata,
        [Parameter(Position=1, ParameterSetName='Extract single object')]
        [string[]]$ChildObjectNames,
        [Parameter(ParameterSetName='Extract single object')]
        [switch]$ThrowIfMissing,
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    )
    if ($ChildObjectNames) {
        foreach ($n in $ChildObjectNames) {
            if (-not (Test-ChildObject -Metadata $Metadata -ChildObjectName $n -Throw:$ThrowIfMissing.IsPresent)) {
                return
            }
            Write-Output [PSCustomObject]@{ Name = $n; Value = $Metadata[$n]}
        }
    }
    else {
        foreach ($key in ($Metadata.Keys | Sort-Object)) {
            Write-Output ([PSCustomObject]@{ Name = $key; Value = $Metadata[$key]})
        }
    }
}

function Get-ObjectProperties {
    param (
        [Parameter(Position=0, Mandatory)]
        [string]$ObjectName,
        [switch]$AddIdProperty,
        [switch]$AddSharingProperties
    )
    $props = [System.Collections.ArrayList]::new()
    if ($AddIdProperty ) {
        $props.Add(@{name='id';expression={$_['id']}}) > $null
    }
    switch -exact -casesensitive ($ObjectName) {
        'attributes' {
            $properties = @(
                'code'
                'name'
                'shortName'
                'description'
                'categoryAttribute'
                'categoryOptionAttribute'
                'categoryOptionComboAttribute'
                'categoryOptionGroupAttribute'
                'categoryOptionGroupSetAttribute'
                'constantAttribute'
                'dataElementAttribute'
                'dataElementGroupAttribute'
                'dataElementGroupSetAttribute'
                'dataSetAttribute'
                'documentAttribute'
                'eventChartAttribute'
                'eventReportAttribute'
                'indicatorAttribute'
                'indicatorGroupAttribute'
                'legendSetAttribute'
                'mandatory'
                'mapAttribute'
                'optionAttribute'
                'optionSetAttribute'
                'organisationUnitAttribute'
                'organisationUnitGroupAttribute'
                'organisationUnitGroupSetAttribute'
                'programAttribute'
                'programIndicatorAttribute'
                'programStageAttribute'
                'relationshipTypeAttribute'
                'sectionAttribute'
                'sqlViewAttribute'
                'trackedEntityAttributeAttribute'
                'trackedEntityTypeAttribute'
                'unique'
                'userAttribute'
                'userGroupAttribute'
                'validationRuleAttribute'
                'validationRuleGroupAttribute'
                'valueType'
                'visualizationAttribute')
        }
        'dataElements' {
            $properties = @(
                'code'
                'name'
                'shortName'
                'description'
                'aggregationType'
                @{name='categoryCombo_code';expression={
                    if ($categoryComboMap -and $categoryComboMap.Contains($_.categoryCombo.id)) {
                        Write-Debug "Mapping category combo id '$($_.categoryCombo.id)' to code '$($categoryComboMap[$_.categoryCombo.id])'"
                        $categoryComboMap[$_.categoryCombo.id]
                    } else {
                        Write-Warning "Failed to map a code for the category combo with the id '$($_.categoryCombo.id)'."
                        $_.categoryCombo.id
                    }
                }}
                'domainType'
                'valueType'
                'zeroIsSignificant')
        }
        'optionSets' {
            $properties = @(
                'code'
                'name'
                'valueType')
        }
        Default { $properties = @()}
    }
    foreach ($prop in $properties) {
        if ($prop -is [string]) {
            $props.Add(@{name=$prop;expression=$prop}) > $null
        } else {
            $props.Add($prop) > $null
        }
    }
    if ($AddSharingProperties ) {
        $props.Add(@{name='sharing_external';expression={$_.sharing.external}}) > $null
        $props.Add(@{name='sharing_public';expression={$_.sharing.public}}) > $null
        $props.Add(@{name='sharing_owner';expression={
            if ($userMap -and $userMap.Contains($_.sharing.owner)) {
                Write-Debug "Mapping user id '$($_.sharing.owner)' to code '$($userMap[$_.sharing.owner])'"
                $userMap[$_.sharing.owner]
            } else {
                Write-Warning "Failed to map a code for the user with the id '$($_.sharing.owner)'."
                $_.sharing.owner
            }
        }}) > $null
    }
    return $props.ToArray()
}

function Initialize-ObjectDirectory {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Position=0, Mandatory)]
        [string]$BasePath,
        [Parameter(Position=1, Mandatory)]
        [string[]]$ObjectNames,
        $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference'),
        $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference'),
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    )
    foreach ($objectName in $ObjectNames) {
        $dir = Join-Path $BasePath -ChildPath $objectName

        if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
            Write-Verbose "Creating directory $dir"
            New-Item -Path $dir -ItemType Directory > $null
        }
        return $dir
    }
}

function Get-CodeMap {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory, ValueFromPipeline)]
        [Hashtable]$InputObject,
        [switch]$Reverse,
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    )
    begin {
        $map = @{}
    }
    process {
        if (-not $InputObject.Contains('id')) {
            Write-Debug "The input object does not contain an id key. Skipping."
            return
        }
        $id = $InputObject['id']
        if (-not $id) {
            Write-Debug "The input object does not contain a valid id. Skipping."
            return
        }
        if (-not $InputObject.Contains('code')) {
            Write-Debug "The input object does not contain a code key. Skipping."
            return
        }
        $code = $InputObject['code']
        if (-not $code) {
            Write-Debug "The input object does not contain a valid code. Skipping."
            return
        }
        if ($Reverse) {
            $map[$code] = $id
        } else {
            $map[$id] = $code
        }
    }
    end {
        return $map
    }
}

#region Metadata Generation Framework

<#
.SYNOPSIS
    Invokes a metadata generator script with parameters from generators.json.

.DESCRIPTION
    Executes generator scripts that create repetitive DHIS2 metadata patterns.
    Tracks generated objects in generation-map.json for roundtrip support.

.PARAMETER GeneratorName
    Name of the generator to execute (matches name in generators.json).

.PARAMETER GeneratorsConfigPath
    Path to generators.json configuration file.

.PARAMETER OutputPath
    Directory where generated files should be written.

.PARAMETER DryRun
    If specified, shows what would be generated without writing files.

.EXAMPLE
    Invoke-MetadataGenerator -GeneratorName "pathogen-data-elements" -OutputPath ".\_generated"
#>
function Invoke-MetadataGenerator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GeneratorName,
        
        [Parameter(Mandatory)]
        [string]$GeneratorsConfigPath,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [switch]$DryRun
    )
    
    Write-Verbose "Loading generator configuration from $GeneratorsConfigPath"
    $config = Get-Content -LiteralPath $GeneratorsConfigPath -Raw | ConvertFrom-Json
    
    $generator = $config.generators | Where-Object { $_.name -eq $GeneratorName }
    if (-not $generator) {
        throw "Generator '$GeneratorName' not found in configuration"
    }
    
    if (-not $generator.enabled) {
        Write-Warning "Generator '$GeneratorName' is disabled in configuration"
        return
    }
    
    $scriptPath = Join-Path (Split-Path $GeneratorsConfigPath) $generator.script
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "Generator script not found: $scriptPath"
    }
    
    Write-Verbose "Executing generator: $($generator.description)"
    
    if ($DryRun) {
        Write-Host "DRY RUN: Would execute $scriptPath with parameters:" -ForegroundColor Cyan
        $generator.parameters | ConvertTo-Json -Depth 10 | Write-Host
        return
    }
    
    # Create output directory if it doesn't exist
    if (-not (Test-Path -LiteralPath $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    
    # Execute the generator script
    $result = & $scriptPath -Parameters $generator.parameters -OutputPath $OutputPath -Verbose:$VerbosePreference
    
    # Register generated objects
    if ($result -and $result.GeneratedObjects) {
        Register-GeneratedObject -GeneratorName $GeneratorName -Objects $result.GeneratedObjects -OutputPath $OutputPath
    }
    
    return $result
}

<#
.SYNOPSIS
    Registers generated metadata objects in generation-map.json for roundtrip tracking.

.PARAMETER GeneratorName
    Name of the generator that created the objects.

.PARAMETER Objects
    Array of generated object codes.

.PARAMETER OutputPath
    Directory containing generation-map.json.
#>
function Register-GeneratedObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GeneratorName,
        
        [Parameter(Mandatory)]
        [array]$Objects,
        
        [Parameter(Mandatory)]
        [string]$OutputPath
    )
    
    $mapPath = Join-Path $OutputPath "generation-map.json"
    
    $map = @{
        generatedBy = @{}
        metadata = @{
            lastUpdated = (Get-Date -Format "o")
            generator = $GeneratorName
        }
    }
    
    if (Test-Path -LiteralPath $mapPath) {
        $existing = Get-Content -LiteralPath $mapPath -Raw | ConvertFrom-Json -AsHashtable -Depth 10
        $map = $existing
    }
    
    foreach ($obj in $Objects) {
        $map.generatedBy[$obj.code] = @{
            generator = $GeneratorName
            parameters = $obj.parameters
            timestamp = (Get-Date -Format "o")
        }
    }
    
    $map.metadata.lastUpdated = (Get-Date -Format "o")
    
    $map | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $mapPath -Encoding UTF8NoBOM
    Write-Verbose "Registered $($Objects.Count) objects from generator '$GeneratorName' in $mapPath"
}

<#
.SYNOPSIS
    Detects repetitive patterns in DHIS2 metadata objects for generator creation.

.PARAMETER Objects
    Array of DHIS2 metadata objects to analyze.

.PARAMETER PatternType
    Type of pattern to detect: 'IndexSequence', 'CrossProduct', 'Naming'.

.EXAMPLE
    Find-GeneratorPattern -Objects $dataElements -PatternType IndexSequence
#>
function Find-GeneratorPattern {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [array]$Objects,
        
        [Parameter()]
        [ValidateSet('IndexSequence', 'CrossProduct', 'Naming')]
        [string]$PatternType = 'IndexSequence'
    )
    
    begin {
        $allObjects = @()
    }
    
    process {
        $allObjects += $Objects
    }
    
    end {
        Write-Verbose "Analyzing $($allObjects.Count) objects for $PatternType patterns"
        
        switch ($PatternType) {
            'IndexSequence' {
                # Detect patterns like "pathogen1", "pathogen2", "pathogen3"
                $patterns = @{}
                foreach ($obj in $allObjects) {
                    if ($obj.code -match '^(.+?)(\d+)$') {
                        $base = $matches[1]
                        $index = [int]$matches[2]
                        
                        if (-not $patterns.ContainsKey($base)) {
                            $patterns[$base] = @()
                        }
                        $patterns[$base] += @{ index = $index; object = $obj }
                    }
                }
                
                # Filter to patterns with at least 2 sequential items
                $detectedPatterns = @()
                foreach ($base in $patterns.Keys) {
                    $items = $patterns[$base] | Sort-Object { $_.index }
                    if ($items.Count -ge 2) {
                        $indices = $items | ForEach-Object { $_.index }
                        $sequential = $true
                        for ($i = 0; $i -lt $indices.Count - 1; $i++) {
                            if ($indices[$i + 1] -ne $indices[$i] + 1) {
                                $sequential = $false
                                break
                            }
                        }
                        
                        if ($sequential) {
                            $detectedPatterns += @{
                                basePattern = $base
                                count = $items.Count
                                startIndex = $indices[0]
                                endIndex = $indices[-1]
                                examples = $items[0..([Math]::Min(2, $items.Count - 1))] | ForEach-Object { $_.object.code }
                            }
                        }
                    }
                }
                
                return $detectedPatterns
            }
            
            'CrossProduct' {
                # Detect patterns like "BSI_pathogen1_MRSA", "BSI_pathogen2_MRSA", etc.
                # This is more complex and requires detecting multiple dimensions
                Write-Warning "CrossProduct pattern detection not yet implemented"
                return @()
            }
            
            'Naming' {
                # Detect common naming conventions and inconsistencies
                Write-Warning "Naming pattern detection not yet implemented"
                return @()
            }
        }
    }
}

<#
.SYNOPSIS
    Merges manual override CSV/YAML files with generated metadata.

.PARAMETER GeneratedPath
    Path to generated metadata files.

.PARAMETER OverridePath
    Path to manual override files.

.PARAMETER ObjectType
    Type of metadata object (e.g., 'dataElements', 'programRules').

.EXAMPLE
    Merge-ManualOverrides -GeneratedPath ".\_generated\data-elements" -OverridePath ".\data-elements" -ObjectType "dataElements"
#>
function Merge-ManualOverrides {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GeneratedPath,
        
        [Parameter(Mandatory)]
        [string]$OverridePath,
        
        [Parameter(Mandatory)]
        [string]$ObjectType
    )
    
    if (-not (Test-Path -LiteralPath $GeneratedPath)) {
        Write-Warning "Generated path does not exist: $GeneratedPath"
        return @()
    }
    
    # Load generated objects
    $generatedObjects = @()
    Get-ChildItem -LiteralPath $GeneratedPath -Filter "*.yaml" | ForEach-Object {
        $yamlContent = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Yaml
        $generatedObjects += $yamlContent
    }
    
    # Load override objects if they exist
    $overrideObjects = @{}
    if (Test-Path -LiteralPath $OverridePath) {
        Get-ChildItem -LiteralPath $OverridePath -Filter "*.yaml" | ForEach-Object {
            $yamlContent = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Yaml
            if ($yamlContent.code) {
                $overrideObjects[$yamlContent.code] = $yamlContent
            }
        }
    }
    
    # Merge: override takes precedence
    $merged = @()
    foreach ($generated in $generatedObjects) {
        if ($overrideObjects.ContainsKey($generated.code)) {
            Write-Warning "Manual override detected for $ObjectType '$($generated.code)' - using override instead of generated"
            $merged += $overrideObjects[$generated.code]
            $overrideObjects.Remove($generated.code)
        } else {
            $merged += $generated
        }
    }
    
    # Add any override objects that weren't in generated set
    $merged += $overrideObjects.Values
    
    return $merged
}

<#
.SYNOPSIS
    Converts DHIS2 translation objects to .po file format for po4a.

.PARAMETER Translations
    Array of DHIS2 translation objects with locale, property, value.

.PARAMETER OutputPath
    Directory where .po files should be written.

.PARAMETER Domain
    Translation domain (e.g., 'dhis2-metadata').
#>
function ConvertTo-PoTranslations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Translations,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [Parameter()]
        [string]$Domain = 'dhis2-metadata'
    )
    
    # Group translations by locale
    $byLocale = $Translations | Group-Object -Property locale
    
    foreach ($group in $byLocale) {
        $locale = $group.Name
        $poPath = Join-Path $OutputPath "$Domain.$locale.po"
        
        # Create .po file header
        $poContent = @"
# DHIS2 Metadata Translations ($locale)
# Copyright (C) 2026 Charité – Universitätsmedizin Berlin
# This file is distributed under the same license as the NeoIPC package.
#
msgid ""
msgstr ""
"Project-Id-Version: NeoIPC Surveillance DHIS2 Metadata\n"
"Report-Msgid-Bugs-To: NeoIPC-Support@charite.de\n"
"POT-Creation-Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:sszzz")\n"
"PO-Revision-Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:sszzz")\n"
"Last-Translator: \n"
"Language-Team: $locale\n"
"Language: $locale\n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"

"@
        
        # Add each translation entry
        foreach ($trans in $group.Group) {
            $msgid = $trans.defaultValue ?? ""
            $msgstr = $trans.value ?? ""
            
            # Escape special characters
            $msgid = $msgid -replace '"', '\"' -replace "`n", '\n'
            $msgstr = $msgstr -replace '"', '\"' -replace "`n", '\n'
            
            $poContent += @"

#: $($trans.objectType):$($trans.objectCode):$($trans.property)
msgid "$msgid"
msgstr "$msgstr"
"@
        }
        
        $poContent | Set-Content -LiteralPath $poPath -Encoding UTF8NoBOM
        Write-Verbose "Created .po file: $poPath with $($group.Group.Count) translations"
    }
}

<#
.SYNOPSIS
    Merges base YAML with po4a-generated translated YAML files.

.PARAMETER BaseYamlPath
    Path to base (English) YAML file.

.PARAMETER TranslatedYamlPattern
    Pattern to find translated YAML files (e.g., 'data-elements.*.yaml').

.PARAMETER OutputFormat
    Output format: 'DHIS2' (with translations array) or 'Separate' (separate language files).

.EXAMPLE
    Merge-YamlTranslations -BaseYamlPath ".\data-elements.yaml" -TranslatedYamlPattern ".\data-elements.*.yaml"
#>
function Merge-YamlTranslations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseYamlPath,
        
        [Parameter(Mandatory)]
        [string]$TranslatedYamlPattern,
        
        [Parameter()]
        [ValidateSet('DHIS2', 'Separate')]
        [string]$OutputFormat = 'DHIS2'
    )
    
    if (-not (Test-Path -LiteralPath $BaseYamlPath)) {
        throw "Base YAML file not found: $BaseYamlPath"
    }
    
    $baseContent = Get-Content -LiteralPath $BaseYamlPath -Raw | ConvertFrom-Yaml
    
    if ($OutputFormat -eq 'DHIS2') {
        # Add translations array to base content
        $baseContent.translations = @()
        
        $translatedFiles = Get-Item -Path $TranslatedYamlPattern -ErrorAction SilentlyContinue
        foreach ($file in $translatedFiles) {
            if ($file.Name -match '\.([^.]+)\.yaml$') {
                $locale = $matches[1]
                $translatedContent = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Yaml
                
                # Compare and extract differences
                foreach ($prop in @('name', 'description', 'formName', 'content')) {
                    if ($translatedContent.ContainsKey($prop) -and $translatedContent[$prop] -ne $baseContent[$prop]) {
                        $baseContent.translations += @{
                            locale = $locale
                            property = $prop.ToUpper()
                            value = $translatedContent[$prop]
                        }
                    }
                }
            }
        }
        
        return $baseContent
    }
    
    # For 'Separate' format, return dictionary of locale -> content
    return @{ en = $baseContent }
}

<#
.SYNOPSIS
    Helper function to create a new generated data element with both YAML and CSV components.

.PARAMETER Code
    Unique code for the data element.

.PARAMETER Name
    Display name (translatable).

.PARAMETER Description
    Description text (translatable).

.PARAMETER ValueType
    DHIS2 value type (INTEGER, TEXT, etc.).

.PARAMETER DomainType
    Domain type (TRACKER, AGGREGATE).

.PARAMETER OptionSetCode
    Code of associated option set, if any.

.EXAMPLE
    New-GeneratedDataElement -Code "NEOIPC_BSI_PATHOGEN_1" -Name "Pathogen 1" -ValueType "INTEGER" -DomainType "TRACKER"
#>
function New-GeneratedDataElement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Code,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter()]
        [string]$Description = "",
        
        [Parameter()]
        [string]$FormName = "",
        
        [Parameter(Mandatory)]
        [string]$ValueType,
        
        [Parameter(Mandatory)]
        [string]$DomainType,
        
        [Parameter()]
        [string]$OptionSetCode,
        
        [Parameter()]
        [string]$AggregationType = "DEFAULT",
        
        [Parameter()]
        [bool]$ZeroIsSignificant = $false
    )
    
    return @{
        yaml = @{
            code = $Code
            name = $Name
            description = $Description
            formName = if ($FormName) { $FormName } else { $Name }
        }
        csv = @{
            code = $Code
            valueType = $ValueType
            domainType = $DomainType
            optionSet = $OptionSetCode
            aggregationType = $AggregationType
            zeroIsSignificant = $ZeroIsSignificant
        }
    }
}

<#
.SYNOPSIS
    Helper function to create a new generated program rule with YAML and CSV components.

.PARAMETER Code
    Unique code for the rule.

.PARAMETER Name
    Display name (translatable).

.PARAMETER Description
    Description (translatable).

.PARAMETER ProgramStageCode
    Code of the program stage this rule applies to.

.PARAMETER Condition
    Rule condition expression (using #{variable} syntax).

.PARAMETER Priority
    Execution priority.

.EXAMPLE
    New-GeneratedProgramRule -Code "NEOIPC_BSI_PATHOGEN_1_MRSA" -Name "Show MRSA field" -Condition "d2:hasValue(#{pathogen1})" -ProgramStageCode "NEOIPC_STAGE_BSI"
#>
function New-GeneratedProgramRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Code,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter()]
        [string]$Description = "",
        
        [Parameter(Mandatory)]
        [string]$ProgramStageCode,
        
        [Parameter(Mandatory)]
        [string]$Condition,
        
        [Parameter()]
        [int]$Priority = 0
    )
    
    return @{
        yaml = @{
            code = $Code
            name = $Name
            description = $Description
        }
        csv = @{
            code = $Code
            programStage = $ProgramStageCode
            condition = $Condition
            priority = $Priority
        }
    }
}

<#
.SYNOPSIS
    Helper function to create a new generated program rule variable.

.PARAMETER Code
    Unique code for the variable.

.PARAMETER Name
    Display name (translatable).

.PARAMETER SourceType
    Source type (DATAELEMENT_CURRENT_EVENT, CALCULATED_VALUE, etc.).

.PARAMETER DataElementCode
    Code of source data element, if applicable.

.PARAMETER ValueType
    Value type (INTEGER, BOOLEAN, TEXT, etc.).

.EXAMPLE
    New-GeneratedProgramRuleVariable -Code "pathogen1_value" -Name "Pathogen 1 value" -SourceType "DATAELEMENT_CURRENT_EVENT" -DataElementCode "NEOIPC_BSI_PATHOGEN_1"
#>
function New-GeneratedProgramRuleVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Code,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [ValidateSet('DATAELEMENT_CURRENT_EVENT', 'DATAELEMENT_NEWEST_EVENT_PROGRAM', 
                     'DATAELEMENT_PREVIOUS_EVENT', 'CALCULATED_VALUE', 'TEI_ATTRIBUTE')]
        [string]$SourceType,
        
        [Parameter()]
        [string]$DataElementCode,
        
        [Parameter()]
        [string]$TrackedEntityAttributeCode,
        
        [Parameter(Mandatory)]
        [string]$ValueType,
        
        [Parameter()]
        [bool]$UseCodeForOptionSet = $false
    )
    
    return @{
        yaml = @{
            code = $Code
            name = $Name
        }
        csv = @{
            code = $Code
            sourceType = $SourceType
            dataElement = $DataElementCode
            trackedEntityAttribute = $TrackedEntityAttributeCode
            valueType = $ValueType
            useCodeForOptionSet = $UseCodeForOptionSet
        }
    }
}

#endregion
