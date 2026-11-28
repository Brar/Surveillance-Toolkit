#Requires -Version 7.6
#requires -Module Pester

<#
.SYNOPSIS
    Pester tests for the report edition helpers: the preset reader, the reference dataset's
    department count, and the preset data the birth-weight-class and gestational-age-range
    editions render from.

.DESCRIPTION
    Covers Get-NeoIPCReportPreset and Get-NeoIPCReferenceDatasetDepartmentCount of
    Public/ReportEdition.ps1, and the class-range-edition entry of
    reports/Reference-Report/presets.json. The floor of 5 contributing departments a
    Reference Report edition may publish under is decided by the edition's design; this
    file pins what the helpers read, the builder decides whether to stop on it.

.EXAMPLE
    Invoke-Pester -Path scripts/modules/NeoIPC-Tools/Tests/ReportEdition.Tests.ps1
#>

BeforeAll {
    Import-Module -Name (Join-Path $PSScriptRoot '..') -Force
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..')).Path
    $script:ReferencePresetsPath = Join-Path $RepoRoot 'reports/Reference-Report/presets.json'
}

Describe 'Get-NeoIPCReportPreset' {
    BeforeAll {
        $script:PresetsFile = Join-Path $TestDrive 'presets.json'
        @'
{
  "presets": {
    "default": {},
    "minimal": { "includeMethodsTexts": false },
    "with-comment": {
      "_comment": "not a parameter",
      "includeIntroductionTexts": false
    }
  }
}
'@ | Set-Content -LiteralPath $PresetsFile -Encoding utf8NoBOM
    }

    It 'reads the parameters of a named preset' {
        $preset = Get-NeoIPCReportPreset -PresetsFilePath $PresetsFile -Name 'minimal'
        $preset | Should -BeOfType [hashtable]
        $preset['includeMethodsTexts'] | Should -BeFalse
    }

    It 'returns a fresh hashtable every call, so a caller may edit it' {
        $first = Get-NeoIPCReportPreset -PresetsFilePath $PresetsFile -Name 'minimal'
        $first['added'] = 1
        $second = Get-NeoIPCReportPreset -PresetsFilePath $PresetsFile -Name 'minimal'
        $second.ContainsKey('added') | Should -BeFalse
    }

    It 'leaves out a comment key and keeps every parameter of the preset' {
        $preset = Get-NeoIPCReportPreset -PresetsFilePath $PresetsFile -Name 'with-comment'
        $preset.ContainsKey('_comment') | Should -BeFalse -Because 'the _comment key documents the file, it is no render parameter'
        $preset['includeIntroductionTexts'] | Should -BeFalse
    }

    It 'returns an empty hashtable for a preset that overrides nothing' {
        $preset = Get-NeoIPCReportPreset -PresetsFilePath $PresetsFile -Name 'default'
        @($preset.Keys).Count | Should -Be 0
    }

    It 'names the available presets when it is given a name the file lacks' {
        $errorRecords = @()
        { Get-NeoIPCReportPreset -PresetsFilePath $PresetsFile -Name 'no-such' -ErrorAction SilentlyContinue -ErrorVariable errorRecords } |
            Should -Throw
        ($errorRecords | Out-String) + $Error[0].ToString() | Should -Match 'default'
    }

    It 'refuses a presets file without a presets object' {
        $broken = Join-Path $TestDrive 'broken.json'
        '{"unexpected": {}}' | Set-Content -LiteralPath $broken -Encoding utf8NoBOM
        { Get-NeoIPCReportPreset -PresetsFilePath $broken -Name 'minimal' } | Should -Throw
    }
}

Describe 'Get-NeoIPCReferenceDatasetDepartmentCount' {
    # R decodes the serialized dataset, so these cases run only where Rscript is present.
    # Decided during discovery, so that it can gate -Skip.
    $script:RscriptAvailable = [bool](Get-Command -Name Rscript -ErrorAction SilentlyContinue)

    BeforeAll {
        # The fixtures come from serializeJSON's own writer, run in R now. The serialized
        # shape belongs to the installed jsonlite and has shifted across package versions,
        # so a hand-written fixture can pin a shape no writer writes.
        $gen = Join-Path $TestDrive 'make-datasets.R'
        @'
args <- commandArgs(trailingOnly = TRUE)
ds <- structure(list(n_departments = 26L, metadata = list(period = "2024-2025")),
                class = c("neoipcr_ref_ds", "neoipcr_rep_ds", "list"))
writeLines(jsonlite::serializeJSON(ds), args[[1]])
nodata <- structure(list(metadata = list(period = "2024-2025")),
                    class = c("neoipcr_ref_ds", "neoipcr_rep_ds", "list"))
writeLines(jsonlite::serializeJSON(nodata), args[[2]])
wrong <- structure(list(n_departments = "5"),
                   class = c("neoipcr_ref_ds", "neoipcr_rep_ds", "list"))
writeLines(jsonlite::serializeJSON(wrong), args[[3]])
huge <- structure(list(n_departments = 9999999999),
                  class = c("neoipcr_ref_ds", "neoipcr_rep_ds", "list"))
writeLines(jsonlite::serializeJSON(huge), args[[4]])
'@ | Set-Content -LiteralPath $gen -Encoding utf8NoBOM
        $script:WithCount = Join-Path $TestDrive 'with-count.json'
        $script:WithoutCount = Join-Path $TestDrive 'without-count.json'
        $script:WrongType = Join-Path $TestDrive 'wrong-type.json'
        $script:HugeCount = Join-Path $TestDrive 'huge-count.json'
        $script:PlainJson = Join-Path $TestDrive 'plain.json'
        '{"n_departments": 26}' | Set-Content -LiteralPath $PlainJson -Encoding utf8NoBOM
        if (Get-Command -Name Rscript -ErrorAction SilentlyContinue) {
            & Rscript --vanilla $gen $WithCount $WithoutCount $WrongType $HugeCount
            if ($LASTEXITCODE -ne 0) {
                throw "The R fixture writer failed with exit code $LASTEXITCODE."
            }
        }
    }

    It 'reads the department count out of a dataset as its own writer serializes it' -Skip:(-not $script:RscriptAvailable) {
        Get-NeoIPCReferenceDatasetDepartmentCount -DatasetFilePath $WithCount | Should -Be 26
    }

    It 'stops with an error that names the file on a serialized dataset that carries no count' -Skip:(-not $script:RscriptAvailable) {
        $message = ''
        try { Get-NeoIPCReferenceDatasetDepartmentCount -DatasetFilePath $WithoutCount } catch { $message = $_.Exception.Message }
        $message | Should -Not -BeNullOrEmpty
        $message | Should -Match ([regex]::Escape([System.IO.Path]::GetFileName($WithoutCount))) -Because 'the operator must see which file lacks the count'
    }

    It 'refuses a plain JSON document that is no serialized dataset' -Skip:(-not $script:RscriptAvailable) {
        $message = ''
        try { Get-NeoIPCReferenceDatasetDepartmentCount -DatasetFilePath $PlainJson } catch { $message = $_.Exception.Message }
        $message | Should -Match ([regex]::Escape([System.IO.Path]::GetFileName($PlainJson))) -Because 'a gate may not count a document R cannot unserialize'
    }

    It 'refuses a dataset whose count is no number' -Skip:(-not $script:RscriptAvailable) {
        $message = ''
        try { Get-NeoIPCReferenceDatasetDepartmentCount -DatasetFilePath $WrongType } catch { $message = $_.Exception.Message }
        $message | Should -Match ([regex]::Escape([System.IO.Path]::GetFileName($WrongType))) -Because 'a string that looks like a number is not a count'
    }

    It 'refuses a count no whole department count can be' -Skip:(-not $script:RscriptAvailable) {
        $message = ''
        try { Get-NeoIPCReferenceDatasetDepartmentCount -DatasetFilePath $HugeCount } catch { $message = $_.Exception.Message }
        $message | Should -Match ([regex]::Escape([System.IO.Path]::GetFileName($HugeCount))) -Because 'a value beyond the range of department counts must refuse by naming the file, not by a cast error'
    }
}

Describe 'The Reference Report edition preset' {
    It 'carries a class-range-edition preset' {
        $presets = ((Get-Content -LiteralPath $ReferencePresetsPath -Raw) | ConvertFrom-Json).presets
        $presets.PSObject.Properties.Name | Should -Contain 'class-range-edition'
    }

    It 'withholds every part the edition of a class or range does not print' {
        $edition = ((Get-Content -LiteralPath $ReferencePresetsPath -Raw) | ConvertFrom-Json).presets.'class-range-edition'
        # The editions print the overview, the case-mix figures, the incidence densities,
        # the device-associated rates, and the risk densities, and leave out the validation
        # summary, the agent-per-infection and infectious-agent-detection rates, and the
        # surgery table. The antibiotic utilisation, resistance, and secondary-BSI tables
        # are off in the document defaults, so the preset sets only the four parts it
        # withholds.
        $edition.includeValidationSummaryTable | Should -BeFalse
        $edition.includeAgentPerInfectionRateTable | Should -BeFalse
        $edition.includeInfectiousAgentDetectionRateTable | Should -BeFalse
        $edition.includeSurgicalProcedureRateTable | Should -BeFalse
    }

    It 'lists no parameter that the Reference Report document does not declare' -Skip:(-not (Get-Module -ListAvailable powershell-yaml)) {
        # The document's parameter block is YAML, so it is read with the YAML parser the
        # module tests use elsewhere, not with a regex over its text.
        Import-Module powershell-yaml
        $lines = Get-Content -LiteralPath (Join-Path $RepoRoot 'reports/Reference-Report/Reference-Report.qmd')
        $open = [Array]::FindIndex([string[]]$lines, [Predicate[string]] { param($l) $l -match '^---\s*$' })
        if ($open -lt 0) { throw 'the Reference Report document carries no YAML frontmatter to read its parameters from' }
        $close = -1
        for ($i = $open + 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^---\s*$') { $close = $i; break }
        }
        if ($close -lt 0) { throw 'the Reference Report document has no closing YAML frontmatter marker' }
        $document = ConvertFrom-Yaml (($lines[($open + 1)..($close - 1)] -join [Environment]::NewLine))
        $declared = @($document.params.Keys)
        $edition = ((Get-Content -LiteralPath $ReferencePresetsPath -Raw) | ConvertFrom-Json).presets.'class-range-edition'
        foreach ($key in @($edition.PSObject.Properties.Name)) {
            $declared | Should -Contain $key -Because 'the preset may only set a parameter the document declares'
        }
    }

    It 'keeps the preset a pure diff of the document defaults' {
        $edition = ((Get-Content -LiteralPath $ReferencePresetsPath -Raw) | ConvertFrom-Json).presets.'class-range-edition'
        @($edition.PSObject.Properties.Name) | Should -Not -Contain 'includeSecondaryBsiRateTable' -Because 'the document default already keeps it off'
        @($edition.PSObject.Properties.Name) | Should -Not -Contain 'includeAntibioticUtilisationTable' -Because 'the edition stays off where the document default is off; only the overall report enables it, by parameter'
    }
}
