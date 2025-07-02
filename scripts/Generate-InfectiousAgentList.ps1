[CmdletBinding()]
param(
    [string]$BaseDirectory = (Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'metadata','common','pathogens') -Relative),
    [string]$OutputDirectory = (Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'artifacts') -Relative),
    [string[]]$OutputLanguages = @('de', 'es', 'fr', 'gr', 'it'),
    [string[]]$OutputFormats = @('csv', 'adoc', 'md', 'pdf', 'docx')
)

$inf_agents = @{}
