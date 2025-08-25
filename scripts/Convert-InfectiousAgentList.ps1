[CmdletBinding(PositionalBinding, SupportsShouldProcess)]
param(
    [string]$InputDirectory = "$PSScriptRoot/../metadata/common/infectious-agents",
    [string]$OutputDirectory = "$PSScriptRoot/../artifacts",
    [string[]]$TranslationLanguages,
    [ValidateSet('AsciiDoc','CSV','PDF')]
    [string[]]$OutputFormats,
    [switch]$Force
)

Import-Module powershell-yaml

function AppendChildrenRecursive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 1)]
        [System.Collections.IList]$Children,
        [Parameter(Position = 2)]
        [System.Collections.Generic.List[PSCustomObject]]$Output,
        [Parameter(Position = 3)]
        [string]$Type
    )

    if (-not $Output) {
        $Output = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    $resetType = $false
    foreach ($item in $Children) {
        if ($resetType -or -not $Type) {
            if ($item.ConceptSource -eq 'NeoIPC' -and $item.ConceptId -eq 1) {
                $Type = $item.ConceptType
                $resetType = $true
            } elseif ($item.ConceptSource -eq 'NeoIPC' -and $item.ConceptId -eq 100) {
                $Type = $ContentStrings.Virus
                $resetType = $true
            } elseif ($item.ConceptSource -eq 'LPSN' -and $item.ConceptId -eq 'domain/bacteria') {
                $Type = $ContentStrings.Bacterium
                $resetType = $true
            } elseif ($item.ConceptSource -eq 'MycoBank' -and $item.ConceptId -eq 455206) {
                $Type = $ContentStrings.Fungus
                $resetType = $true
            } elseif ($item.ConceptSource -eq 'MycoBank' -and $item.ConceptId -eq 92339) {
                $Type = $ContentStrings.Protozoon
                $resetType = $true
            } else {
                $Type = $null
            }
        }
        if ($item.Id) {
            $newItem = [ordered]@{}
            $newItem[$ContentStrings.Id] = $item.Id
            $newItem[$ContentStrings.Name] = $item.Name
            $newItem[$ContentStrings.Type] = $Type
            $newItem[$ContentStrings.CommonCommensal] = if($item.CommonCommensal){$ContentStrings.Yes}
            $newItem[$ContentStrings.ParentId] = ''

            $r = [System.Collections.Generic.List[string]]::new()
            if ($item.MRSA) {
                $r.Add($ContentStrings.MRSA)
            }
            if ($item.VRE) {
                $r.Add($ContentStrings.VRE)
            }
            if ($item['3GCR']) {
                $r.Add($ContentStrings['3GCR'])
            }
            if ($item.Carbapenems) {
                $r.Add($ContentStrings.Carbapenems)
            }
            if ($item.Colistin) {
                $r.Add($ContentStrings.Colistin)
            }
            $newItem[$ContentStrings.RecordedResistances] = $r |
                Join-String -Separator ', '

            switch ($item.ConceptSource) {
                LPSN {
                    $newItem[$ContentStrings.URL] = $data.UrlTemplates.LPSN -f $item.ConceptId
                    break
                }
                MycoBank {
                    $newItem[$ContentStrings.URL] = $data.UrlTemplates.MycoBank -f $item.ConceptId
                    break
                }
                ICTV {
                    $newItem[$ContentStrings.URL] = $data.UrlTemplates.ICTV -f $item.ConceptId
                    break
                }
            }
            $Output.Add([PSCustomObject]$newItem)
        }
        if ($item.Children) {
            if ($Output) {
                $Output = AppendChildrenRecursive $item.Children $Output $Type
            } else {
                $Output = AppendChildrenRecursive -Children $item.Children -Type $Type
            }
        }
        if ($item.Synonyms) {
            AppendSynonyms $Output $item.Synonyms $item $Type
        }
    }

    return $Output
}

function AppendSynonyms {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 1)]
        [System.Collections.Generic.List[PSCustomObject]]$Output,
        [Parameter(Mandatory, Position = 2)]
        [System.Collections.IList]$Synonyms,
        [Parameter(Mandatory, Position = 3)]
        [object]$Parent,
        [Parameter(Position = 4)]
        [string]$Type
    )

    foreach ($item in $Synonyms) {
        if ($Parent.Id) {
            $newItem = [ordered]@{}
            $newItem[$ContentStrings.Id] = $item.Id
            $newItem[$ContentStrings.Name] = $item.Name
            $newItem[$ContentStrings.Type] = $Type
            $newItem[$ContentStrings.CommonCommensal] = if($Parent.CommonCommensal){$ContentStrings.Yes}
            $newItem[$ContentStrings.ParentId] = $Parent.Id

            $r = [System.Collections.Generic.List[string]]::new()
            if ($Parent.MRSA) {
                $r.Add($ContentStrings.MRSA)
            }
            if ($Parent.VRE) {
                $r.Add($ContentStrings.VRE)
            }
            if ($Parent['3GCR']) {
                $r.Add($ContentStrings['3GCR'])
            }
            if ($Parent.Carbapenems) {
                $r.Add($ContentStrings.Carbapenems)
            }
            if ($Parent.Colistin) {
                $r.Add($ContentStrings.Colistin)
            }
            $newItem[$ContentStrings.RecordedResistances] = $r |
                Join-String -Separator ', '

            switch ($item.ConceptSource) {
                LPSN {
                    $newItem[$ContentStrings.URL] = $data.UrlTemplates.LPSN -f $item.ConceptId
                    break
                }
                MycoBank {
                    $newItem[$ContentStrings.URL] = $data.UrlTemplates.MycoBank -f $item.ConceptId
                    break
                }
                ICTV {
                    $newItem[$ContentStrings.URL] = $data.UrlTemplates.ICTV -f $item.ConceptId
                    break
                }
            }
            $Output.Add([PSCustomObject]$newItem)
        }
    }
}

data MessageStrings -SupportedCommand ConvertFrom-Yaml {
    ConvertFrom-Yaml @'
CreatingInfoMsg: "Creating infectious agent list for language ‘{0}’"
Po4aErrorMsg: "The execution of the command '{0}' was terminated with the following error message:"
Po4aWarningMsg: "The execution of the command '{0}' resulted in the following warning message:"
'@
}
Import-LocalizedData -BindingVariable 'MessageStrings' -SupportedCommand ConvertFrom-Yaml -FileName 'Convert-InfectiousAgentList-MessageStrings' -ErrorAction Ignore

data ContentStrings -SupportedCommand ConvertFrom-Yaml {
    ConvertFrom-Yaml @'
Yes: Yes
MRSA: MRSA
VRE: VRE
3GCR: 3GCR
Carbapenems: Carbapenems
Colistin: Colistin
Bacterium: Bacterium
Fungus: Fungus
Virus: Virus
Protozoon: Protozoon
Id: Id
Name: Name
Type: Type
CommonCommensal: Common Commensal
ParentId: Parent Id
RecordedResistances: Recorded Resistances
URL: URL
'@
}

$config_file = Resolve-Path "$InputDirectory/po4a.cfg" -Relative
$po4aCmd = "po4a -q "
if ($Force) {
    $po4aCmd += '-k 0 '
}
$po4aCmd += $config_file

$po4aErrors = $( $po4aWarnings = Invoke-Expression -Command $po4aCmd ) 2>&1
if ($po4aErrors) {
    $msg = ($MessageStrings.Po4aErrorMsg -f $po4aCmd) + [System.Environment]::NewLine
    for ($i = 0; $i -lt $po4aErrors.Count; $i++) {
        $line = $po4aErrors[$i]
        if ($line.Exception.Message -and $line.Exception.Message -notmatch '^\s*$') {
            $msg = $msg + $line + [System.Environment]::NewLine
        }
    }
    Write-Error -Message $msg -ErrorAction Stop
}
if ($po4aWarnings) {
    $msg = ($MessageStrings.Po4aWarningMsg -f $po4aCmd) + [System.Environment]::NewLine
    for ($i = 0; $i -lt $po4aWarnings.Count; $i++) {
        $line = $po4aWarnings[$i]
        if ($line -and $line -notmatch '^\s*$') {
            $msg = $msg + $line + [System.Environment]::NewLine
        }
    }
    Write-Warning -Message $msg
}

$translationPaths = Resolve-Path -Path "$InputDirectory/NeoIPC-Infectious-Agents.*.yaml" -Relative |
    ForEach-Object {
        $_ -match '^.*NeoIPC-Infectious-Agents\.(.*)\.yaml$' | Out-Null
        [PSCustomObject]@{
            Language = $Matches[1]
            FilePath = $Matches[0]
        }
    }

if ($TranslationLanguages) {
    $translationPaths = $translationPaths |
        Where-Object Language -In $TranslationLanguages
}

$translationPaths = @(
    [PSCustomObject]@{
        Language = 'en'
        FilePath = Resolve-Path -LiteralPath "$InputDirectory/NeoIPC-Infectious-Agents.yaml" -Relative
    }) + @($translationPaths)

if (-not $OutputFormats) {
    $OutputFormats = @('AsciiDoc','CSV','PDF')
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

foreach ($iaList in $translationPaths) {
    $culture = [cultureinfo]::GetCultureInfo($iaList.Language)
    Write-Information -MessageData ($MessageStrings.CreatingInfoMsg -f $culture.DisplayName)
    $contentStringFile = Join-Path -Path $PSScriptRoot -ChildPath $culture.Name -AdditionalChildPath 'Convert-InfectiousAgentList-ContentStrings.psd1'
    if (Test-Path -LiteralPath $contentStringFile) {
        Import-LocalizedData -UICulture $culture -BindingVariable 'ContentStrings' -SupportedCommand ConvertFrom-Yaml -FileName 'Convert-InfectiousAgentList-ContentStrings' -ErrorAction Stop
    }
    $data = Get-Content -LiteralPath $iaList.FilePath |
        ConvertFrom-Yaml
    $output = AppendChildrenRecursive $data.Hierarchies |
        Sort-Object Name -Culture ([cultureinfo]::GetCultureInfo($iaList.Language))
    $outputBasePath = Join-Path -Path $OutputDirectory -ChildPath "NeoIPC-Infectious-Agents.$($culture.Name)."
    switch ($OutputFormats) {
        'AsciiDoc' {
            $outputPath = $outputBasePath + 'adoc'
            continue
        }
        'CSV' {
            $outputPath = $outputBasePath + 'csv'
            $output |
                Export-Csv -LiteralPath $outputPath -Encoding utf8NoBOM -UseQuotes AsNeeded
            continue
        }
        'PDF' {
            $outputPath = $outputBasePath + 'pdf'
            continue
        }
        Default {
            throw "Unsupported output format: '$outputFormat'"
        }
    }
}
