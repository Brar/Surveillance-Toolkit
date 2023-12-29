[AppContext]::SetSwitch("Switch.System.Xml.AllowDefaultResolver", $true);

$AtcUrlTemplate = 'https://www.whocc.no/atc_ddd_index/?code={0}&showdescription=yes'

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
    if ($AsciiDoc) { $formatString = ' in AsciiDoc format' } else { $formatString = ''}
    if ($TargetCulture.Name) {
        Write-Debug "Generating antibiotics list$formatString for culture '$($TargetCulture.Name)'."
        $translations = Import-Translations -LiteralPath $antibioticsFile -TargetCulture $TargetCulture -ExpectedProperties 'NAME'
    } else {
        Write-Debug "Generating antibiotics list$formatString for the invariant culture."
        $translations = @()
    }

    # Iterate the list of antibiotics and try to find and return the translated row in the requested format.
    Import-Csv -LiteralPath $antibioticsFile -Encoding utf8NoBOM |
    Foreach-Object {
        $name = $_.name
        $url = $AtcUrlTemplate -f $_.atc_code
        foreach ($translation in $translations) {
            $translationInfo = $null
            if ($translation.NAME.TryGetValue($_.atc_code, [ref]$translationInfo)) {
                if ($_.name -cne $translationInfo.DefaultValue) {
                    Write-Warning "The default value '$($translationInfo.DefaultValue)' for code '$($_.atc_code)' in translation file '$($translation.TranslationFile)' does not match the value '$($_.name)' in '$antibioticsFile'."
                }
                if ($translationInfo.NeedsTranslation) {
                    $name = $translationInfo.TranslatedValue
                }
                return [PSCustomObject][ordered]@{ Name = $name; 'ATC-Code' = $_.atc_code; Url = $url }
            }
        }
        if ($TargetCulture.Name -and $translations.Count -gt 0) {
            Write-Warning "Cannot find a translation for ATC-Code '$($_.atc_code)' in any of the translation files for locale '$($TargetCulture.Name)' or any of its parent locales in directory '$antibioticsFolderPath'. The antibiotic will have its untranslated default name '$($_.name)'."
        }
        return [PSCustomObject][ordered]@{ Name = $name; 'ATC-Code' = $_.atc_code; Url = $url }
    } |
    Sort-Object -Culture $TargetCulture -Property 'Name' |
    ForEach-Object -Begin {
        if ($AsciiDoc) {
            Write-Output '|==='
            Write-Output '|Name |ATC-Code'
            Write-Output ''
        }
    } -Process {
        if ($AsciiDoc) {
            Write-Output "|$($_.Name) |$($_.Url)[$($_.'ATC-Code'),window=_blank]"
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
        [CultureInfo]$TargetCulture,
        [string]$InputDirectory,
        [string]$OutputDirectory
    )
    $listElements = [System.Collections.Generic.Dictionary[string, string]]::new()
    $neoipcConcepts = [System.Collections.Generic.Dictionary[uint, string]]::new()
    Import-Csv -LiteralPath (Join-Path -Path $InputDirectory -ChildPath 'NeoIPC-Owned-Pathogen-Concepts.csv') -Encoding utf8NoBOM | ForEach-Object {
        $neoipcConcepts.Add([uint]::Parse($_.id), ($_.pathogen_type + '_' + ($_.concept_type -creplace '\s', '_')))
    }
    $localizedlist = [System.Collections.ArrayList]::new()
    $c = $TargetCulture
    while ($c.Name.Length -gt 0) {
        $listElementsPath = Join-Path -Path $InputDirectory -ChildPath "ListElements.$($c.Name).csv"
        if ((Test-Path -LiteralPath $listElementsPath -PathType Leaf)) {
            $lineNo = 1
            Import-Csv -LiteralPath $listElementsPath -Encoding utf8NoBOM | ForEach-Object {
                $le = $_
                $lineNo++
                if ($le.property -cne 'VALUE') {
                    throw "Unknown property name '$($le.property)' in line $lineNo in file '$listElementsPath'."
                }
                $needs_translation = $le.needs_translation -ceq 't'
                if (-not $needs_translation) {
                    if ($le.needs_translation -ceq 'u') {
                        Write-Warning "Unverified translation value '$($le.translated)' in line $lineNo file '$listElementsPath'."
                        if ($le.translated.Length -gt 0) {
                            $needs_translation = $true
                        }
                    } elseif ($le.needs_translation -cne 'f') {
                        throw "Unexpected boolen value '$($le.needs_translation)' in line $lineNo file '$listElementsPath'."
                    }
                }

                if ($needs_translation -and (-not $listElements.ContainsKey($_.id))) {
                    $listElements.add($_.id, $_.translated)
                }
            }
        }
        $pcPath = Join-Path -Path $InputDirectory -ChildPath "NeoIPC-Pathogen-Concepts.$($c.Name).csv"
        $psPath = Join-Path -Path $InputDirectory -ChildPath "NeoIPC-Pathogen-Synonyms.$($c.Name).csv"

        if ((Test-Path -LiteralPath $pcPath -PathType Leaf)) {
            if (-not (Test-Path -LiteralPath $psPath -PathType Leaf)) {
                throw "Invalid state: If '$pcPath' exists, '$psPath' must exist too."
            }
            $pc = Import-Csv -LiteralPath $pcPath -Encoding utf8NoBOM
            $pcHash = [System.Collections.Generic.Dictionary[int, System.Collections.Hashtable]]::new()
            $lineNo = 1
            foreach ($p in $pc) {
                $lineNo++
                # Validate the input file
                if ($p.property -cne 'CONCEPT') {
                    throw "Unknown property name '$($p.property)' in line $lineNo in file '$pcPath'."
                }
                if ($p.default.Trim().Length -eq 0) {
                    throw "Missing default value in line $lineNo in file '$pcPath'."
                }
                if ($p.default.Trim() -cne $p.default) {
                    throw "Default value with superflous whitespace in line $lineNo in file '$pcPath'."
                }
                $needs_translation = $p.needs_translation -ceq 't'
                if (-not $needs_translation) {
                    if ($p.needs_translation -ceq 'u') {
                        Write-Warning "Unverified translation value '$($p.translated)' in line $lineNo file '$pcPath'."
                        if ($p.translated.Length -gt 0) {
                            $needs_translation = $true
                        }
                    } elseif ($p.needs_translation -cne 'f') {
                        throw "Unexpected boolen value '$($p.needs_translation)' in line $lineNo file '$pcPath'."
                    }
                }
                if ($needs_translation -and $p.translated.Trim().Length -eq 0) {
                    throw "Missing translation in line $lineNo file '$pcPath'."
                }
                if ($needs_translation -and $p.translated.Trim() -cne $p.translated) {
                    throw "Translation with superflous whitespace in line $lineNo in file '$pcPath'."
                }
                if ((-not $needs_translation) -and $p.translated.Length -ne 0) {
                    throw "Unexpected translation in line $lineNo file '$pcPath'."
                }
                $pcHash.Add($p.id, @{
                    needs_translation = $needs_translation
                    default = $p.default
                    translated = $p.translated
                })
            }

            $ps = Import-Csv -LiteralPath $psPath -Encoding utf8NoBOM
            $psHash = @{}
            $lineNo = 1
            foreach ($p in $ps) {
                $lineNo++
                # Validate the input file
                if ($p.property -cne 'SYNONYM') {
                    throw "Unknown property name '$($p.property)' in line $lineNo in file '$psPath'."
                }
                if ($p.default.Trim().Length -eq 0) {
                    throw "Missing default value in line $lineNo in file '$psPath'."
                }
                if ($p.default.Trim() -cne $p.default) {
                    throw "Default value with superflous whitespace in line $lineNo in file '$psPath'."
                }
                $needs_translation = $p.needs_translation -ceq 't'
                if (-not $needs_translation) {
                    if ($p.needs_translation -ceq 'u') {
                        Write-Warning "Unverified translation value '$($p.translated)' in line $lineNo file '$psPath'."
                        if ($p.translated.Length -gt 0) {
                            $needs_translation = $true
                        }
                    } elseif ($p.needs_translation -cne 'f') {
                        throw "Unexpected boolen value '$($p.needs_translation)' in line $lineNo file '$psPath'."
                    }
                }
                if ($needs_translation -and $p.translated.Trim().Length -eq 0) {
                    throw "Missing translation in line $lineNo file '$psPath'."
                }
                if ($needs_translation -and $p.translated.Trim() -cne $p.translated) {
                    throw "Translation with superflous whitespace in line $lineNo in file '$psPath'."
                }
                if ((-not $needs_translation) -and $p.translated.Length -ne 0) {
                    throw "Unexpected translation in line $lineNo file '$psPath'."
                }
                $psHash.Add($p.id, @{
                    needs_translation = $needs_translation
                    default = $p.default
                    translated = $p.translated
                })
            }
            $localizedlist.Add([System.ValueTuple]::Create($pcHash, $psHash)) > $null
        }
        elseif ((Test-Path -LiteralPath $psPath -PathType Leaf)) {
            throw "Invalid state: If '$psPath' exists, '$pcPath' must exist too."
        }
        $c = $TargetCulture.Parent
    }
    if ($TargetCulture.Name.Length -gt 0 -and $localizedlist.Count -eq 0) {
        Write-Warning "Could not find a pathogen translation file for '$($TargetCulture.Name)'. This will result in an untranslated pathogen list."
    }
    Import-Csv -LiteralPath (Join-Path -Path $InputDirectory -ChildPath 'ListElements.csv') -Encoding utf8NoBOM | ForEach-Object {
        if (-not $listElements.ContainsKey($_.id)) {
            $listElements.add($_.id, $_.value)
        }
    }

    $commonCommensal = ''
    if (-not $listElements.TryGetValue('common_commensal', [ref]$commonCommensal)) {
        throw "Lookup of string 'common_commensal' failed."
    }

    $recognisedPathogen = ''
    if (-not $listElements.TryGetValue('recognised_pathogen', [ref]$recognisedPathogen)) {
        throw "Lookup of string 'recognised_pathogen' failed."
    }

    $MRSA = ''
    if (-not $listElements.TryGetValue('mrsa', [ref]$MRSA)) {
        throw "Lookup of string 'mrsa' failed."
    }

    $VRE = ''
    if (-not $listElements.TryGetValue('vre', [ref]$VRE)) {
        throw "Lookup of string 'vre' failed."
    }

    $3GCR = ''
    if (-not $listElements.TryGetValue('3gcr', [ref]$3GCR)) {
        throw "Lookup of string '3gcr' failed."
    }

    $carbapenems = ''
    if (-not $listElements.TryGetValue('carbapenems', [ref]$carbapenems)) {
        throw "Lookup of string 'carbapenems' failed."
    }

    $colistin = ''
    if (-not $listElements.TryGetValue('colistin', [ref]$colistin)) {
        throw "Lookup of string 'colistin' failed."
    }


    $pcPath = Join-Path -Path $InputDirectory -ChildPath 'NeoIPC-Pathogen-Concepts.csv'
    $pc = Import-Csv -LiteralPath $pcPath -Encoding utf8NoBOM
    $pathogenList = [System.Collections.ArrayList]::new()
    $lineNo = 1
    foreach ($p in $pc) {
        $lineNo++
        # Validate the input file
        if ($p.concept.Trim().Length -eq 0) {
            throw "Missing concept value in line $lineNo in file '$pcPath'."
        }
        if ($p.concept.Trim() -cne $p.concept) {
            throw "Concept value with superflous whitespace in line $lineNo in file '$pcPath'."
        }
        if ($p.concept_type -cnotin 'clade','family','genus','group','serotype','species','species complex','subspecies','unknown','variety') {
            throw "Unknown concept type in line $lineNo in file '$pcPath'."
        }
        if ($p.concept_source -cnotin 'ICTV','LPSN','MycoBank','NeoIPC') {
            throw "Unknown concept source in line $lineNo in file '$pcPath'."
        }

        $type = ''
        switch -casesensitive ($p.concept_source) {
            'LPSN' {
                $typeString = 'bacterial_' + $p.concept_type -creplace '\s', '_'
                if (-not $listElements.TryGetValue($typeString, [ref]$type)) {
                    throw "Lookup of type string '$typeString' failed in line $lineNo in file '$pcPath'."
                }
                $type = "https://lpsn.dsmz.de/$($p.concept_id)[$type,window=_blank]"
            }
            'MycoBank' {
                $typeString = 'fungal_' + $p.concept_type -creplace '\s', '_'
                if (-not $listElements.TryGetValue($typeString, [ref]$type)) {
                    throw "Lookup of type string '$typeString' failed in line $lineNo in file '$pcPath'."
                }
                $type = "https://www.mycobank.org/page/Name%20details%20page/field/Mycobank%20%23/$($p.concept_id)[$type,window=_blank]"
            }
            'ICTV' {
                $typeString = 'viral_' + $p.concept_type -creplace '\s', '_'
                if (-not $listElements.TryGetValue($typeString, [ref]$type)) {
                    throw "Lookup of type string '$typeString' failed in line $lineNo in file '$pcPath'."
                }
                $type = "https://ictv.global/taxonomy/taxondetails?taxnode_id=$($p.concept_id)[$type,window=_blank]"
            }
            'NeoIPC' {
                $typeString = ''
                if ($p.concept_type -ceq 'unknown') {
                    if (-not $listElements.TryGetValue('unknown', [ref]$type)) {
                        throw "Lookup of type string 'unknown' failed in line $lineNo in file '$pcPath'."
                    }
                }
                else {
                    if (-not $neoipcConcepts.TryGetValue([uint]::Parse($p.concept_id), [ref]$typeString)) {
                        throw "Lookup of NeoIPC pathogen with concept_id $($p.concept_id) failed in line $lineNo in file '$pcPath'."
                    }
                    if (-not $listElements.TryGetValue($typeString, [ref]$type)) {
                        throw "Lookup of type string '$typeString' failed in line $lineNo in file '$pcPath'."
                    }
                }
            }
            default { throw "Lookup of type string failed in line $lineNo in file '$pcPath'." }
        }

        $pathogenName = $p.concept
        foreach ($l in $localizedlist) {
            $lpc = @{}
            if ($l.Item1.TryGetValue($p.id, [ref]$lpc)) {
                if ($p.concept -cne $lpc.default) {
                    throw "Default value '$($lpc.default)' in translation file differs from concept '$($p.concept)' for pathogen with id '$($p.id)'."
                }
                if ($lpc.needs_translation) {
                    $pathogenName = $lpc.translated
                }
                break
            }
        }

        if ($p.is_cc -ceq 't') {
            $pathogenicity = $commonCommensal
        } elseif ($p.is_cc -ceq 'f') {
            $pathogenicity = $recognisedPathogen
        }  else {
            throw "Unexpected boolen value '$($p.is_cc)' in line $lineNo file '$pcPath'."
        }

        $resistanceString = [System.Text.StringBuilder]::new()
        if ($p.show_mrsa -ceq 't') {
            $resistanceString.Append($MRSA).Append(', ') > $null
        } elseif (-not($p.show_mrsa -ceq 'f')) {
            throw "Unexpected boolen value '$($p.show_mrsa)' in line $lineNo file '$pcPath'."
        }
        if ($p.show_vre -ceq 't') {
            $resistanceString.Append($VRE).Append(', ') > $null
        } elseif (-not($p.show_vre -ceq 'f')) {
            throw "Unexpected boolen value '$($p.show_vre)' in line $lineNo file '$pcPath'."
        }
        if ($p.show_3gcr -ceq 't') {
            $resistanceString.Append($3GCR).Append(', ') > $null
        } elseif (-not($p.show_3gcr -ceq 'f')) {
            throw "Unexpected boolen value '$($p.show_3gcr)' in line $lineNo file '$pcPath'."
        }
        if ($p.show_carb_r -ceq 't') {
            $resistanceString.Append($carbapenems).Append(', ') > $null
        } elseif (-not($p.show_carb_r -ceq 'f')) {
            throw "Unexpected boolen value '$($p.show_carb_r)' in line $lineNo file '$pcPath'."
        }
        if ($p.show_coli_r -ceq 't') {
            $resistanceString.Append($colistin).Append(', ') > $null
        } elseif (-not($p.show_coli_r -ceq 'f')) {
            throw "Unexpected boolen value '$($p.show_coli_r)' in line $lineNo file '$pcPath'."
        }
        if ($resistanceString.Length -gt 0) {
            $resistanceString.Length -= 2
        }

        $pathogenList.Add(@(
            "[[pathogen-concept-$($p.id)]]$pathogenName"
            $type
            $pathogenicity
            $resistanceString.ToString()
        )) > $null
    }

    #$ps = Import-Csv -LiteralPath (Join-Path -Path $InputDirectory -ChildPath 'NeoIPC-Pathogen-Synonyms.csv') -Encoding utf8NoBOM

    if ($TargetCulture.Name.Length -gt 0) {
        $outfile = Join-Path -Path $OutputDirectory -ChildPath "NeoIPC-Pathogens.$TargetCulture.adoc"
    }
    else {
        $outfile = Join-Path -Path $OutputDirectory -ChildPath "NeoIPC-Pathogens.adoc"
    }
    $pathogenList |
    Sort-Object -Property {$_[0] -creplace '^\[\[pathogen-concept-\d+\]\](.+)$','$1'} -Culture $TargetCulture.Name |
    ForEach-Object { $_ | Join-String -OutputPrefix '|' -Separator ' |' } |
    Out-File -LiteralPath $outfile -Encoding utf8NoBOM
}
