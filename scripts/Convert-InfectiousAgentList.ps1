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
        [System.Collections.Generic.List[PSCustomObject]]$Output
    )

    if (-not $Output) {
        $Output = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    foreach ($item in $Children) {
        if ($item.Id) {
            $newItem = [ordered]@{
                Id = $item.Id
                Name = $item.Name
                Type = $item.ConceptType
                Code = $item.ConceptCode
                CommonCommensal = if($item.CommonCommensal){$ContentStrings.Yes}
                Resistances = [System.Collections.Generic.List[string]]::new()
                Url = ""
            }
            if ($item.MRSA) {
                $newItem.Resistances.Add($ContentStrings.MRSA)
            }
            if ($item.VRE) {
                $newItem.Resistances.Add($ContentStrings.VRE)
            }
            if ($item['3GCR']) {
                $newItem.Resistances.Add($ContentStrings['3GCR'])
            }
            if ($item.Carbapenems) {
                $newItem.Resistances.Add($ContentStrings.Carbapenems)
            }
            if ($item.Colistin) {
                $newItem.Resistances.Add($ContentStrings.Colistin)
            }
            $Output.Add([PSCustomObject]$newItem)
        }
        if ($item.Children) {
            if ($Output) {
                $Output = AppendChildrenRecursive $item.Children $Output
            } else {
                $Output = AppendChildrenRecursive $item.Children
            }
        }
        if ($item.Synonyms) {
            AppendSynonyms $Output $item.Synonyms $item
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
        [System.Collections.IList]$ynonyms,
        [Parameter(Mandatory, Position = 3)]
        [object]$parent
    )
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
'@
}

$config_file = Resolve-Path "$InputDirectory/po4a.cfg" -Relative
$po4aCmd = "po4a -q "
if ($Force) {
    $po4aCmd += '-k 0 '
} else {
    $po4aCmd += '-k 75 '
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
    $data = Get-Content -LiteralPath $iaList.FilePath | ConvertFrom-Yaml
    $output = AppendChildrenRecursive $data.Hierarchies | Sort-Object Name -Culture ([cultureinfo]::GetCultureInfo($iaList.Language))
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
