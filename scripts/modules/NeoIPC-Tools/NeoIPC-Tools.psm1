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
        [string]$TargetFilePath,
        [string[]]$InputFiles,
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

function New-AntibioticsList {
    param (
        [Parameter(Mandatory=$true)]
        [CultureInfo]$TargetCulture,
        [Parameter(Mandatory=$true)]
        [string]$MetadataPath,
        [switch]$AsciiDoc
    )
    $culture = $TargetCulture
    $antibioticsFolderPath = Join-Path -Resolve -Path $MetadataPath -ChildPath 'common' -AdditionalChildPath 'antibiotics'
    $translations = [System.Collections.Generic.List[PSCustomObject]]::new()
    # Import translations for the target culture and all of its parent cultures up to (excluding) the invarinat culture into a list of dictionaries.
    while ($culture.Name) {
        $translationFile = Join-Path -Resolve -ErrorAction SilentlyContinue -ErrorVariable resolveErrors -Path $antibioticsFolderPath -ChildPath "NeoIPC-Antibiotics.$($culture.Name).csv"
        if (-not $translationFile) {
            foreach ($e in $resolveErrors) {
                Write-Debug $e
             }
             $culture = $culture.Parent
             continue
        }
        $translationInfo =[System.Collections.Generic.Dictionary[string,PSCustomObject]]::new()
        Import-Csv -LiteralPath $translationFile -Encoding utf8NoBOM |
        Foreach-Object {
            if ($_.property -cne 'NAME') {
                Write-Error "Unexpected property value '$($_.property)' in file '$translationFile'"
                return
            }
            if ($_.needs_translation -ceq 'f') {
                $translationInfo.Add($_.id,[PSCustomObject]@{NeedsTranslation = $false; DefaultValue = $_.default; TranslatedValue = [string]$null})
            } elseif ($_.needs_translation -ceq 't') {
                $translationInfo.Add($_.id,[PSCustomObject]@{NeedsTranslation = $true; DefaultValue = $_.default; TranslatedValue = $_.translated})
            } elseif ($_.needs_translation -ceq 'u') {
                Write-Warning "Unverified translation value '$($_.translated)' in file '$translationFile'"
                if ($_.translated.Length -gt 0) {
                    $translationInfo.Add($_.id,[PSCustomObject]@{NeedsTranslation = $true; DefaultValue = $_.default; TranslatedValue = $_.translated})
                } else {
                    $translationInfo.Add($_.id,[PSCustomObject]@{NeedsTranslation = $false; DefaultValue = $_.default; TranslatedValue = [string]$null})
                }
            } else {
                Write-Error "Unexpected needs_translation value '$($_.needs_translation)' in file '$translationFile'"
            }
        }
        $translations.Add([PSCustomObject]@{ CultureInfo = $culture; TranslationFile = $translationFile; Translations = $translationInfo })
        $culture = $culture.Parent
    }

    if ($TargetCulture.Name -and $translations.Count -eq 0) {
        Write-Warning "Could not find a translation file for locale '$($TargetCulture.Name)' or any of its parent locales in directory '$antibioticsFolderPath'. All antibiotics in the list will have their untranslated default names."
    }

    # Iterate the list of antibiotics and try to find and return the translated row in the requested format.
    $antibioticsFile = Join-Path -Resolve -Path $antibioticsFolderPath -ChildPath 'NeoIPC-Antibiotics.csv'
    Import-Csv -LiteralPath $antibioticsFile -Encoding utf8NoBOM |
    Foreach-Object {
        $name = $_.name
        $url = $AtcUrlTemplate -f $_.atc_code
        foreach ($translation in $translations) {
            $translationInfo = $null
            if ($translation.Translations.TryGetValue($_.atc_code, [ref]$translationInfo)) {
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
            Write-Warning "Could not find a translation for ATC-Code '$($_.atc_code)' in any of the translation files for locale '$($TargetCulture.Name)' or any of its parent locales in directory '$antibioticsFolderPath'. The antibiotic will have its untranslated default name '$($_.name)'."
        }
        return [PSCustomObject][ordered]@{ 'ATC-Code' = $_.atc_code; Name = $name; Url = $url }
    } |
    Sort-Object -Culture $TargetCulture -Property 'Name' |
    ForEach-Object {
        if ($AsciiDoc) { "|$($_.Name) |$($_.Url)[$($_.'ATC-Code'),window=_blank]" } else { $_ } }
}
