<#
.SYNOPSIS
    Updates metadata translations using po4a.

.DESCRIPTION
    Runs po4a to extract translatable strings from YAML metadata files to .po files,
    or applies translations from .po files back to YAML. This script is the bridge
    between the YAML metadata format and the translator-friendly .po format.

.PARAMETER Mode
    'Extract' to create/update .pot and .po files from YAML sources.
    'Apply' to apply translations from .po files to YAML.

.PARAMETER ConfigPath
    Path to metadata.po4a.cfg file (default: 'metadata/metadata.po4a.cfg').

.PARAMETER KeepTranslations
    Percentage threshold for po4a (0-100). Default is 0 (keep all translations even if outdated).

.EXAMPLE
    .\Update-MetadataTranslations.ps1 -Mode Extract

.EXAMPLE
    .\Update-MetadataTranslations.ps1 -Mode Apply -Verbose

.NOTES
    Requires po4a to be installed and available in PATH.
    Install on Windows: winget install gettext, then install Perl and po4a
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Extract', 'Apply', 'Both')]
    [string]$Mode = 'Both',
    
    [Parameter()]
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\metadata\metadata.po4a.cfg'),
    
    [Parameter()]
    [ValidateRange(0, 100)]
    [int]$KeepTranslations = 0
)

# Check for po4a
$po4aCmd = Get-Command 'po4a' -ErrorAction SilentlyContinue
if (-not $po4aCmd) {
    Write-Error @"
po4a not found in PATH. Please install po4a:

Windows (with Chocolatey):
  choco install strawberryperl
  cpan Po4a

Linux/macOS:
  apt-get install po4a    # Debian/Ubuntu
  brew install po4a       # macOS

See: https://po4a.org/
"@
    exit 1
}

if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    exit 1
}

$configFile = Resolve-Path $ConfigPath

Write-Host "Metadata Translation Update" -ForegroundColor Cyan
Write-Host "Config: $configFile" -ForegroundColor Gray
Write-Host "Mode: $Mode" -ForegroundColor Gray
Write-Host ""

if ($Mode -in 'Extract', 'Both') {
    Write-Host "Extracting translatable strings from YAML to .po files..." -ForegroundColor Yellow
    
    # Run po4a in extract mode
    $po4aArgs = @(
        "-k", $KeepTranslations
        "-v"
        $configFile
    )
    
    Write-Verbose "Running: po4a $($po4aArgs -join ' ')"
    
    & po4a @po4aArgs
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "po4a extraction failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
    
    Write-Host "✓ Translation files updated in po/ directory" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Translators: Open .po files in po/ directory with Poedit or similar" -ForegroundColor White
    Write-Host "2. After translation: Run this script with -Mode Apply" -ForegroundColor White
}

if ($Mode -in 'Apply', 'Both') {
    Write-Host "Applying translations from .po files to YAML..." -ForegroundColor Yellow
    
    # po4a automatically applies translations when run
    # The same command both extracts and applies
    if ($Mode -eq 'Apply') {
        $po4aArgs = @(
            "-k", $KeepTranslations
            "-v"
            $configFile
        )
        
        Write-Verbose "Running: po4a $($po4aArgs -join ' ')"
        
        & po4a @po4aArgs
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "po4a application failed with exit code $LASTEXITCODE"
            exit $LASTEXITCODE
        }
    }
    
    Write-Host "✓ Translations applied to YAML files" -ForegroundColor Green
    Write-Host ""
    Write-Host "Translated YAML files created with language suffix (e.g., .de.yaml)" -ForegroundColor White
    Write-Host "These will be merged during package build." -ForegroundColor White
}

Write-Host ""
Write-Host "Translation update complete!" -ForegroundColor Green
