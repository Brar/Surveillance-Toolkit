[CmdletBinding()]
param(
    #[string]$BaseDirectory = 'https://raw.githubusercontent.com/Brar/Surveillance-Toolkit/refs/heads/ReferenceReport/metadata/common/pathogens/',
    [string]$BaseDirectory = (Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'metadata','common','pathogens') -Relative),
    [string]$OutputDirectory = (Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'artifacts') -Relative),
    [string[]]$OutputLanguages = @('de', 'es', 'fr', 'gr', 'it'),
    [string[]]$OutputFormats = @('csv', 'adoc', 'md', 'pdf', 'docx')
)

$ById = @{}
$ByName = @{}

$uri = $null
if ([Uri]::TryCreate($BaseDirectory, [System.UriKind]::Absolute, [ref]$uri)) {
    $infectiousAgentData = Invoke-WebRequest -Uri ([Uri]::new($uri, 'NeoIPC-Pathogen-Concepts.csv').AbsoluteUri) | ConvertFrom-Csv
    $synonymData = Invoke-WebRequest -Uri ([Uri]::new($uri, 'NeoIPC-Pathogen-Synonyms.csv').AbsoluteUri) | ConvertFrom-Csv
} else {
    $infectiousAgentData = Import-Csv -Path (Join-Path -Path $BaseDirectory -ChildPath 'NeoIPC-Pathogen-Concepts.csv')
    $synonymData = Import-Csv -Path (Join-Path -Path $BaseDirectory -ChildPath 'NeoIPC-Pathogen-Synonyms.csv')
}

$lineNo = 2
foreach ($iaRow in $infectiousAgentData) {
    $id = [int]::Parse($iaRow.id)
    try {
        $ById.Add($id, $iaRow)
    }
    catch {
        Write-Error "Duplicate id $id in file 'NeoIPC-Pathogen-Concepts.csv' line $lineNo."
    }
    try {
        $ByName.Add($iaRow.concept, $iaRow)
    }
    catch {
        Write-Error "Duplicate name '$($iaRow.concept)' in file 'NeoIPC-Pathogen-Concepts.csv' line $lineNo."
    }
    $lineNo++
}

$lineNo = 2
foreach ($sRow in $synonymData) {
    $id = [int]::Parse($sRow.id)
    try {
        $ById.Add($id, $sRow)
    }
    catch {
        Write-Error "Duplicate id $id in file 'NeoIPC-Pathogen-Synonyms.csv' line $lineNo."
    }
    try {
        $ByName.Add($sRow.synonym, $sRow)
    }
    catch {
        Write-Error "Duplicate name '$($sRow.synonym)' in file 'NeoIPC-Pathogen-Synonyms.csv' line $lineNo."
    }
    $lineNo++
}

$ByName