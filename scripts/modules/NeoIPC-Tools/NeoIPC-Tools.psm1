[AppContext]::SetSwitch("Switch.System.Xml.AllowDefaultResolver", $true);

$AtcUrlTemplate = 'https://www.whocc.no/atc_ddd_index/?code={0}&showdescription=yes'

function Export-AsciiDocIds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
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
        [Parameter(Mandatory=$true)]
        [string]$LiteralPath,
        [Parameter(Mandatory=$true)]
        [CultureInfo]$TargetCulture,
        [Parameter(Mandatory=$true)]
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
        [Parameter(Mandatory=$true)]
        [CultureInfo]$TargetCulture,
        [Parameter(Mandatory=$true)]
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
                return [PSCustomObject][ordered]@{ 'ATC-Code' = $_.atc_code; Name = $name; Url = $url }
            }
        }
        if ($TargetCulture.Name -and $translations.Count -gt 0) {
            Write-Warning "Cannot find a translation for ATC-Code '$($_.atc_code)' in any of the translation files for locale '$($TargetCulture.Name)' or any of its parent locales in directory '$antibioticsFolderPath'. The antibiotic will have its untranslated default name '$($_.name)'."
        }
        return [PSCustomObject][ordered]@{ 'ATC-Code' = $_.atc_code; Name = $name; Url = $url }
    } |
    Sort-Object -Culture $TargetCulture -Property 'Name' |
    ForEach-Object {
        if ($AsciiDoc) { "|$($_.Name) |$($_.Url)[$($_.'ATC-Code'),window=_blank]" } else { $_ } }
}
