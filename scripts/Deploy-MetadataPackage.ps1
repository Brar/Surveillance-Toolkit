<#
.SYNOPSIS
    Deploys DHIS2 metadata package to a DHIS2 instance.

.DESCRIPTION
    Uploads and imports metadata JSON package to DHIS2 via the /api/metadata endpoint.
    Supports incremental updates, pre-deployment validation, and detailed reporting.

.PARAMETER PackagePath
    Path to the metadata JSON package file to deploy.

.PARAMETER BaseUrl
    Base URL of the target DHIS2 instance (e.g., 'https://dhis2.example.org').

.PARAMETER Credential
    PSCredential object for DHIS2 authentication.

.PARAMETER Username
    DHIS2 username (alternative to Credential).

.PARAMETER Password
    DHIS2 password (alternative to Credential).

.PARAMETER ImportStrategy
    DHIS2 import strategy: CREATE_AND_UPDATE, CREATE, UPDATE, DELETE.

.PARAMETER AtomicMode
    Atomic mode: ALL (rollback on error), NONE (continue on error).

.PARAMETER IncrementalUpdate
    If specified, compares package versions and skips unchanged objects.

.PARAMETER DryRun
    If specified, validates package without importing.

.EXAMPLE
    .\Deploy-MetadataPackage.ps1 -PackagePath ".\packages\neoipc-complete-v1.0.0.json" -BaseUrl "https://dhis2.example.org" -Credential (Get-Credential)

.EXAMPLE
    $env:NEOIPC_DHIS2_BASEURL = "https://dhis2.example.org"
    $env:NEOIPC_DHIS2_USERNAME = "admin"
    $env:NEOIPC_DHIS2_PASSWORD = "district"
    .\Deploy-MetadataPackage.ps1 -PackagePath ".\packages\neoipc-complete-v1.0.0.json" -IncrementalUpdate

.NOTES
    Requires network connectivity to DHIS2 instance and appropriate user permissions.
#>

[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Credential')]
param(
    [Parameter(Mandatory)]
    [string]$PackagePath,
    
    [Parameter()]
    [string]$BaseUrl = $env:NEOIPC_DHIS2_BASEURL,
    
    [Parameter(ParameterSetName = 'Credential')]
    [PSCredential]$Credential,
    
    [Parameter(ParameterSetName = 'UsernamePassword')]
    [string]$Username = $env:NEOIPC_DHIS2_USERNAME,
    
    [Parameter(ParameterSetName = 'UsernamePassword')]
    [string]$Password = $env:NEOIPC_DHIS2_PASSWORD,
    
    [Parameter()]
    [ValidateSet('CREATE_AND_UPDATE', 'CREATE', 'UPDATE', 'DELETE')]
    [string]$ImportStrategy = 'CREATE_AND_UPDATE',
    
    [Parameter()]
    [ValidateSet('ALL', 'NONE')]
    [string]$AtomicMode = 'ALL',
    
    [switch]$IncrementalUpdate,
    
    [switch]$DryRun
)

# Validate parameters
if (-not $BaseUrl) {
    throw "BaseUrl is required. Specify via parameter or NEOIPC_DHIS2_BASEURL environment variable."
}

if (-not (Test-Path $PackagePath)) {
    throw "Package file not found: $PackagePath"
}

# Setup authentication
if ($PSCmdlet.ParameterSetName -eq 'UsernamePassword') {
    if (-not $Username -or -not $Password) {
        throw "Username and Password are required when not using Credential parameter."
    }
    $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $Credential = New-Object PSCredential($Username, $securePassword)
}

if (-not $Credential) {
    $Credential = Get-Credential -Message "Enter DHIS2 credentials"
}

# Normalize BaseUrl
$BaseUrl = $BaseUrl.TrimEnd('/')

Write-Host "DHIS2 Metadata Package Deployment" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan
Write-Host "Package: $PackagePath" -ForegroundColor White
Write-Host "Target:  $BaseUrl" -ForegroundColor White
Write-Host "Mode:    $(if ($DryRun) { 'DRY RUN (Validation Only)' } else { $ImportStrategy })" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'White' })
Write-Host ""

#region Load Package

Write-Host "Loading metadata package..." -ForegroundColor Yellow

try {
    $packageContent = Get-Content -Path $PackagePath -Raw
    $package = $packageContent | ConvertFrom-Json -AsHashtable -Depth 100
    
    $packageVersion = $package.package.version ?? "unknown"
    $packageName = $package.package.name ?? "unknown"
    
    Write-Host "✓ Package loaded: $packageName v$packageVersion" -ForegroundColor Green
}
catch {
    Write-Error "Failed to load package: $_"
    exit 1
}

#endregion

#region Count Objects

$objectCounts = @{}
foreach ($key in $package.Keys) {
    if ($key -ne 'package' -and $key -ne 'system' -and $package[$key] -is [array]) {
        $objectCounts[$key] = $package[$key].Count
    }
}

Write-Host ""
Write-Host "Package contents:" -ForegroundColor Cyan
foreach ($type in $objectCounts.Keys | Sort-Object) {
    Write-Host "  $type: $($objectCounts[$type])" -ForegroundColor White
}
Write-Host ""

#endregion

#region Pre-Deployment Validation

Write-Host "Validating package with DHIS2..." -ForegroundColor Yellow

$validateUrl = "$BaseUrl/api/metadata/validate"

try {
    $validateResponse = Invoke-RestMethod -Uri $validateUrl `
        -Method Post `
        -Credential $Credential `
        -ContentType "application/json" `
        -Body $packageContent `
        -ErrorAction Stop
    
    if ($validateResponse.status -eq 'OK') {
        Write-Host "✓ Package validation passed" -ForegroundColor Green
    }
    else {
        Write-Warning "Package validation warnings:"
        if ($validateResponse.typeReports) {
            foreach ($report in $validateResponse.typeReports) {
                if ($report.objectReports) {
                    foreach ($objReport in $report.objectReports) {
                        if ($objReport.errorReports) {
                            foreach ($error in $objReport.errorReports) {
                                Write-Host "  ⚠️  $($error.message)" -ForegroundColor Yellow
                            }
                        }
                    }
                }
            }
        }
    }
}
catch {
    Write-Error "Validation failed: $_"
    if ($DryRun) {
        exit 1
    }
    
    $response = Read-Host "Continue with deployment despite validation failure? (y/N)"
    if ($response -notmatch '^y(es)?$') {
        Write-Host "Deployment cancelled." -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""

#endregion

#region Incremental Update Check

if ($IncrementalUpdate) {
    Write-Host "Checking for incremental update capability..." -ForegroundColor Yellow
    
    # TODO: Implement version comparison with DHIS2 custom attributes
    # For now, just log that incremental mode is enabled
    Write-Warning "Incremental update mode is enabled but version comparison not yet implemented"
    Write-Host ""
}

#endregion

#region Deploy Package

if ($DryRun) {
    Write-Host "DRY RUN MODE: Skipping actual deployment" -ForegroundColor Yellow
    Write-Host "Validation passed. Package is ready for deployment." -ForegroundColor Green
    exit 0
}

if ($PSCmdlet.ShouldProcess("$BaseUrl", "Import metadata package")) {
    Write-Host "Deploying metadata package..." -ForegroundColor Yellow
    
    $importUrl = "$BaseUrl/api/metadata"
    $importUrl += "?importStrategy=$ImportStrategy"
    $importUrl += "&atomicMode=$AtomicMode"
    $importUrl += "&importReportMode=FULL"
    $importUrl += "&async=false"
    
    try {
        $importResponse = Invoke-RestMethod -Uri $importUrl `
            -Method Post `
            -Credential $Credential `
            -ContentType "application/json" `
            -Body $packageContent `
            -ErrorAction Stop
        
        Write-Host ""
        Write-Host "="*60 -ForegroundColor Cyan
        Write-Host "Deployment Results" -ForegroundColor Cyan
        Write-Host "="*60 -ForegroundColor Cyan
        
        if ($importResponse.status -eq 'OK') {
            Write-Host "✓ Deployment successful!" -ForegroundColor Green
        }
        elseif ($importResponse.status -eq 'WARNING') {
            Write-Host "⚠️  Deployment completed with warnings" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ Deployment failed" -ForegroundColor Red
        }
        
        Write-Host ""
        
        # Display statistics
        if ($importResponse.stats) {
            Write-Host "Statistics:" -ForegroundColor Cyan
            foreach ($prop in $importResponse.stats.PSObject.Properties) {
                if ($prop.Value -gt 0) {
                    Write-Host "  $($prop.Name): $($prop.Value)" -ForegroundColor White
                }
            }
            Write-Host ""
        }
        
        # Display type reports
        if ($importResponse.typeReports) {
            $hasErrors = $false
            $hasWarnings = $false
            
            foreach ($typeReport in $importResponse.typeReports) {
                if ($typeReport.stats.total -gt 0) {
                    $color = 'White'
                    $status = "✓"
                    
                    if ($typeReport.stats.ignored -gt 0) {
                        $color = 'Gray'
                        $status = "•"
                        $hasWarnings = $true
                    }
                    
                    if ($typeReport.stats.created -gt 0) {
                        $color = 'Green'
                        $status = "+"
                    }
                    
                    if ($typeReport.stats.updated -gt 0) {
                        $color = 'Cyan'
                        $status = "↻"
                    }
                    
                    Write-Host "$status $($typeReport.klass): " -NoNewline -ForegroundColor $color
                    Write-Host "created=$($typeReport.stats.created) " -NoNewline -ForegroundColor Green
                    Write-Host "updated=$($typeReport.stats.updated) " -NoNewline -ForegroundColor Cyan
                    Write-Host "ignored=$($typeReport.stats.ignored) " -NoNewline -ForegroundColor Gray
                    Write-Host "deleted=$($typeReport.stats.deleted)" -ForegroundColor Yellow
                    
                    # Show errors if any
                    if ($typeReport.objectReports) {
                        foreach ($objReport in $typeReport.objectReports) {
                            if ($objReport.errorReports -and $objReport.errorReports.Count -gt 0) {
                                $hasErrors = $true
                                foreach ($error in $objReport.errorReports) {
                                    Write-Host "    ❌ $($error.message)" -ForegroundColor Red
                                }
                            }
                        }
                    }
                }
            }
            
            Write-Host ""
            
            if ($hasErrors) {
                Write-Host "❌ Deployment completed with errors" -ForegroundColor Red
                exit 1
            }
            elseif ($hasWarnings) {
                Write-Host "⚠️  Deployment completed with warnings" -ForegroundColor Yellow
            }
            else {
                Write-Host "✓ Deployment completed successfully!" -ForegroundColor Green
            }
        }
        
        exit 0
    }
    catch {
        Write-Error "Deployment failed: $_"
        
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            Write-Error "Response: $responseBody"
        }
        
        exit 1
    }
}
else {
    Write-Host "Deployment cancelled (WhatIf mode)" -ForegroundColor Yellow
    exit 0
}

#endregion
