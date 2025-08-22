[CmdletBinding(PositionalBinding, SupportsShouldProcess)]
param(
    [string]$InputDirectory = "$PSScriptRoot/../metadata/common/infectious-agents",
    [string]$OutputDirectory = "$PSScriptRoot/../build",
    [string[]]$TranslationLanguages,
    [string[]]$OutputFormats
)

Import-Module powershell-yaml

$config_file = Resolve-Path "$InputDirectory/po4a.cfg" -Relative
Invoke-Expression -Command "po4a -q $config_file" -ErrorAction Stop
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

function AppendChildrenRecursive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 1)]
        [System.Collections.IList]$Children,
        [Parameter(Position = 2)]
        [System.Collections.Generic.List[ordered]]$Output
    )

    if (-not $Output) {
        $Output = [System.Collections.Generic.List[ordered]]::new()
    }

    foreach ($item in $Children) {
        if ($item.Id) {
            $newItem = [ordered]@{
                Id = $item.Id
                Name = $item.Name
                Type = $item.ConceptType
                Code = $item.ConceptCode
                CommonCommensal = if($item.CommonCommensal){'Yes'}
                Resistances = [System.Collections.Generic.List[string]]::new()
                Url = ""
            }
            if ($item.MRSA) {
                $newItem.Resistances.Add('MRSA')
            }
            if ($item.VRE) {
                $newItem.Resistances.Add('VRE')
            }
            if ($item.'3GCR') {
                $newItem.Resistances.Add('3GCR')
            }
            if ($item.Carbapenems) {
                $newItem.Resistances.Add('Carbapenems')
            }
            if ($item.Colistin) {
                $newItem.Resistances.Add('Colistin')
            }
            $Output.Add($newItem)
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
        [System.Collections.Generic.List[ordered]]$Output,
        [Parameter(Mandatory, Position = 2)]
        [System.Collections.IList]$ynonyms,
        [Parameter(Mandatory, Position = 3)]
        [object]$parent
    )
}

foreach ($iaList in $translationPaths) {
    $lang = $iaList.Language
    Write-Information "Creating infectious agent list for language '$lang'"
    $data = Get-Content -LiteralPath $iaList.FilePath | ConvertFrom-Yaml
    $output = AppendChildrenRecursive $data.Hierarchies

    return $output
}

