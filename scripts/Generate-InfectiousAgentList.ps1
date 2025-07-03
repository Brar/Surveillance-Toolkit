[CmdletBinding()]
param(
    [string]$BaseDirectory = (Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'metadata','common','pathogens') -Relative),
    [string]$OutputDirectory = (Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'artifacts') -Relative),
    [string[]]$OutputLanguages = @('de', 'es', 'fr', 'gr', 'it'),
    [string[]]$OutputFormats = @('csv', 'adoc', 'md', 'pdf', 'docx')
)

$inf_agents = @{}

$uri = $null
if ([Uri]::TryCreate($BaseDirectory, [System.UriKind]::Absolute, [ref]$uri)) {
    $iaUri = [Uri]::new($uri, 'NeoIPC-Pathogen-Concepts.csv').AbsoluteUri
    $iaData = Invoke-WebRequest -Uri $iaUri | ConvertFrom-Csv
} else {
    $iaPath = Join-Path -Path $BaseDirectory -ChildPath 'NeoIPC-Pathogen-Concepts.csv'
    $iaData = Import-Csv -Path $iaPath
}