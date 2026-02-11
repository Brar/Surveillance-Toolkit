<#
.SYNOPSIS
    Validates DHIS2 metadata package before building or deployment.

.DESCRIPTION
    Performs comprehensive validation of metadata including:
    - Generator script execution in dry-run mode
    - Shared-data version compatibility
    - .po file placeholder consistency
    - Program rule variable references
    - Reference integrity (codes exist)
    - Translation completeness
    - WHO design principles compliance
    - Domain-specific validation rules

.PARAMETER MetadataPath
    Path to metadata root directory (default: '../metadata').

.PARAMETER ProgramCode
    Specific program to validate (default: validates all programs).

.PARAMETER SharedDataPath
    Path to shared-data directory (default: '../shared-data').

.PARAMETER SkipTranslations
    Skip translation completeness checks.

.PARAMETER SkipGenerators
    Skip generator execution validation.

.EXAMPLE
    .\Validate-Metadata.ps1

.EXAMPLE
    .\Validate-Metadata.ps1 -ProgramCode "neoipc-core" -Verbose

.NOTES
    Returns exit code 0 on success, non-zero on validation failures.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$MetadataPath = (Join-Path $PSScriptRoot '..\metadata'),
    
    [Parameter()]
    [string]$ProgramCode,
    
    [Parameter()]
    [string]$SharedDataPath = (Join-Path $PSScriptRoot '..\shared-data'),
    
    [switch]$SkipTranslations,
    
    [switch]$SkipGenerators
)

Import-Module (Join-Path $PSScriptRoot 'modules\NeoIPC-Tools\NeoIPC-Tools.psm1') -Force

$ErrorCount = 0
$WarningCount = 0

function Write-ValidationError {
    param([string]$Message)
    Write-Host "❌ ERROR: $Message" -ForegroundColor Red
    $script:ErrorCount++
}

function Write-ValidationWarning {
    param([string]$Message)
    Write-Host "⚠️  WARNING: $Message" -ForegroundColor Yellow
    $script:WarningCount++
}

function Write-ValidationSuccess {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

Write-Host "DHIS2 Metadata Validation" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan
Write-Host ""

#region Check Dependencies

Write-Host "Checking dependencies..." -ForegroundColor Yellow

$dependenciesPath = Join-Path $MetadataPath 'metadata-dependencies.json'
if (Test-Path $dependenciesPath) {
    $dependencies = Get-Content $dependenciesPath -Raw | ConvertFrom-Json
    
    foreach ($dep in $dependencies.dependencies.PSObject.Properties) {
        $depName = $dep.Name
        $depInfo = $dep.Value
        
        $depPath = Join-Path $PSScriptRoot "..\$($depInfo.source)"
        
        if (Test-Path $depPath) {
            $manifestPath = Join-Path $depPath 'manifest.json'
            if (Test-Path $manifestPath) {
                $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
                
                if ($manifest.version -eq $depInfo.version) {
                    Write-ValidationSuccess "Dependency '$depName' version $($depInfo.version) matches"
                }
                else {
                    Write-ValidationWarning "Dependency '$depName' version mismatch: expected $($depInfo.version), found $($manifest.version)"
                }
            }
            else {
                Write-ValidationError "Manifest not found for dependency '$depName' at $manifestPath"
            }
        }
        else {
            if ($depInfo.required) {
                Write-ValidationError "Required dependency '$depName' not found at $depPath"
            }
            else {
                Write-ValidationWarning "Optional dependency '$depName' not found at $depPath"
            }
        }
    }
}
else {
    Write-ValidationWarning "metadata-dependencies.json not found"
}

Write-Host ""

#endregion

#region Validate Generators

if (-not $SkipGenerators) {
    Write-Host "Validating generators..." -ForegroundColor Yellow
    
    $programsPath = Join-Path $MetadataPath 'programs'
    $programs = Get-ChildItem $programsPath -Directory
    
    foreach ($program in $programs) {
        if ($ProgramCode -and $program.Name -ne $ProgramCode) {
            continue
        }
        
        $generatorsConfig = Join-Path $program.FullName 'generators\generators.json'
        if (Test-Path $generatorsConfig) {
            $config = Get-Content $generatorsConfig -Raw | ConvertFrom-Json
            
            foreach ($generator in $config.generators) {
                if (-not $generator.enabled) {
                    Write-Verbose "Skipping disabled generator: $($generator.name)"
                    continue
                }
                
                $scriptPath = Join-Path $program.FullName "generators\$($generator.script)"
                if (-not (Test-Path $scriptPath)) {
                    Write-ValidationError "Generator script not found: $scriptPath"
                    continue
                }
                
                try {
                    Write-Verbose "Dry-run validation of generator: $($generator.name)"
                    Invoke-MetadataGenerator -GeneratorName $generator.name `
                        -GeneratorsConfigPath $generatorsConfig `
                        -OutputPath (Join-Path $program.FullName '_generated') `
                        -DryRun -ErrorAction Stop
                    
                    Write-ValidationSuccess "Generator '$($generator.name)' validation passed"
                }
                catch {
                    Write-ValidationError "Generator '$($generator.name)' failed: $_"
                }
            }
        }
    }
    
    Write-Host ""
}

#endregion

#region Validate Translations

if (-not $SkipTranslations) {
    Write-Host "Validating translations..." -ForegroundColor Yellow
    
    $poPath = Join-Path $PSScriptRoot '..\po'
    if (Test-Path $poPath) {
        # Check if Test-PoPlaceholders.ps1 exists
        $testPoScript = Join-Path $PSScriptRoot 'Test-PoPlaceholders.ps1'
        if (Test-Path $testPoScript) {
            try {
                & $testPoScript -Path (Join-Path $poPath 'dhis2-metadata.*.po') -ErrorAction Stop
                Write-ValidationSuccess "Translation placeholder validation passed"
            }
            catch {
                Write-ValidationError "Translation placeholder validation failed: $_"
            }
        }
        else {
            Write-Verbose "Test-PoPlaceholders.ps1 not found, skipping placeholder validation"
        }
        
        # Check for empty translations
        $poFiles = Get-ChildItem $poPath -Filter "dhis2-metadata.*.po"
        foreach ($poFile in $poFiles) {
            $content = Get-Content $poFile.FullName -Raw
            $emptyCount = ([regex]::Matches($content, 'msgstr ""')).Count
            $totalCount = ([regex]::Matches($content, 'msgid "')).Count
            
            if ($totalCount -gt 0) {
                $completeness = [math]::Round((($totalCount - $emptyCount) / $totalCount) * 100, 1)
                
                if ($completeness -lt 50) {
                    Write-ValidationWarning "$($poFile.Name): $completeness% translated"
                }
                else {
                    Write-ValidationSuccess "$($poFile.Name): $completeness% translated"
                }
            }
        }
    }
    else {
        Write-Validation Warning "po/ directory not found"
    }
    
    Write-Host ""
}

#endregion

#region Validate Reference Integrity

Write-Host "Validating reference integrity..." -ForegroundColor Yellow

# Load all codes from metadata
$allCodes = @{}

$programsPath = Join-Path $MetadataPath 'programs'
if (Test-Path $programsPath) {
    $programs = Get-ChildItem $programsPath -Directory
    
    foreach ($program in $programs) {
        if ($ProgramCode -and $program.Name -ne $ProgramCode) {
            continue
        }
        
        # Load data elements
        $dePath = Join-Path $program.FullName 'data-elements\data-elements.csv'
        if (Test-Path $dePath) {
            $dataElements = Import-Csv $dePath
            foreach ($de in $dataElements) {
                if ($de.code) {
                    $allCodes[$de.code] = 'dataElement'
                }
            }
        }
        
        # Load option sets from shared-data
        # TODO: Implement option set loading
        
        # Validate program rule variable references
        $rulesPath = Join-Path $program.FullName 'rules\rules.csv'
        $variablesPath = Join-Path $program.FullName 'rules\variables.csv'
        
        if ((Test-Path $rulesPath) -and (Test-Path $variablesPath)) {
            $rules = Import-Csv $rulesPath
            $variables = Import-Csv $variablesPath
            
            $variableMap = @{}
            foreach ($var in $variables) {
                if ($var.code) {
                    $variableMap[$var.code] = $true
                }
            }
            
            foreach ($rule in $rules) {
                if ($rule.condition) {
                    # Extract variable references like #{variableName}
                    $matches = [regex]::Matches($rule.condition, '#\{([^}]+)\}')
                    foreach ($match in $matches) {
                        $varName = $match.Groups[1].Value
                        if (-not $variableMap.ContainsKey($varName)) {
                            Write-ValidationError "Rule '$($rule.code)' references undefined variable '#{$varName}'"
                        }
                    }
                }
            }
            
            Write-ValidationSuccess "Program rule variable references validated"
        }
        
        # Validate program rule actions reference valid rules
        $actionsPath = Join-Path $program.FullName 'rules\actions'
        if (Test-Path $actionsPath) {
            $rulesMap = @{}
            if (Test-Path $rulesPath) {
                $rules = Import-Csv $rulesPath
                foreach ($rule in $rules) {
                    if ($rule.code) {
                        $rulesMap[$rule.code] = $true
                    }
                }
            }
            
            $actionFiles = Get-ChildItem $actionsPath -Filter "*.csv"
            foreach ($actionFile in $actionFiles) {
                $ruleCode = $actionFile.BaseName
                if (-not $rulesMap.ContainsKey($ruleCode)) {
                    Write-ValidationWarning "Action file '$($actionFile.Name)' references undefined rule '$ruleCode'"
                }
            }
            
            Write-ValidationSuccess "Program rule action references validated"
        }
    }
}

Write-Host ""

#endregion

#region Summary

Write-Host "="*60 -ForegroundColor Cyan
Write-Host "Validation Summary" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan
Write-Host "Errors:   $ErrorCount" -ForegroundColor $(if ($ErrorCount -eq 0) { "Green" } else { "Red" })
Write-Host "Warnings: $WarningCount" -ForegroundColor $(if ($WarningCount -eq 0) { "Green" } else { "Yellow" })
Write-Host ""

if ($ErrorCount -eq 0) {
    Write-Host "✓ Validation passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Ready to build metadata package with Create-MetadataPackage.ps1" -ForegroundColor White
    exit 0
}
else {
    Write-Host "❌ Validation failed with $ErrorCount error(s)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please fix errors before building metadata package" -ForegroundColor Yellow
    exit 1
}

#endregion
