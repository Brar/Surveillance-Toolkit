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
    BeforeAll {
        # The fixtures carry the shape the report generators really write: Generate-ReferenceData.R
        # hands the object to jsonlite::serializeJSON, so the file is a data/attributes/class
        # envelope and every scalar inside it is wrapped in one of its own.
        $script:WithCount = Join-Path $TestDrive 'with-count.json'
        '{"data": {"metadata": {"data": {"period": "2024"}, "attributes": null, "class": ["list"]},' +
            ' "n_departments": {"data": 26, "attributes": null, "class": ["integer"]}},' +
            ' "attributes": {"names": ["metadata", "n_departments"]},' +
            ' "class": ["neoipcr_ref_ds", "neoipcr_rep_ds", "list"]}' |
            Set-Content -LiteralPath $WithCount -Encoding utf8NoBOM
        $script:WithoutCount = Join-Path $TestDrive 'without-count.json'
        '{"data": {"metadata": {"data": {}, "attributes": null, "class": ["list"]}},' +
            ' "attributes": {"names": ["metadata"]},' +
            ' "class": ["neoipcr_ref_ds", "neoipcr_rep_ds", "list"]}' |
            Set-Content -LiteralPath $WithoutCount -Encoding utf8NoBOM
        $script:PlainJson = Join-Path $TestDrive 'plain.json'
        '{"n_departments": 26}' | Set-Content -LiteralPath $PlainJson -Encoding utf8NoBOM
    }

    It 'reads the department count out of the serializeJSON envelope' {
        Get-NeoIPCReferenceDatasetDepartmentCount -DatasetFilePath $WithCount | Should -Be 26
    }

    It 'stops with an error that names the file on a dataset that carries no count' {
        $message = ''
        try { Get-NeoIPCReferenceDatasetDepartmentCount -DatasetFilePath $WithoutCount } catch { $message = $_.Exception.Message }
        $message | Should -Not -BeNullOrEmpty
        $message | Should -Match ([regex]::Escape([System.IO.Path]::GetFileName($WithoutCount))) -Because 'the operator must see which file lacks the count'
    }

    It 'refuses a plain JSON document that is no serialized dataset' {
        $message = ''
        try { Get-NeoIPCReferenceDatasetDepartmentCount -DatasetFilePath $PlainJson } catch { $message = $_.Exception.Message }
        $message | Should -Match ([regex]::Escape([System.IO.Path]::GetFileName($PlainJson))) -Because 'a gate may not count a shape no report generator writes'
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

    It 'lists no parameter that the Reference Report document does not declare' {
        $qmd = Get-Content -LiteralPath (Join-Path $RepoRoot 'reports/Reference-Report/Reference-Report.qmd') -Raw
        $edition = ((Get-Content -LiteralPath $ReferencePresetsPath -Raw) | ConvertFrom-Json).presets.'class-range-edition'
        foreach ($key in @($edition.PSObject.Properties.Name)) {
            $qmd | Should -Match ("(?m)^  {0}:" -f [regex]::Escape($key)) -Because "the preset may only set a parameter the document declares: $key"
        }
    }

    It 'keeps the preset a pure diff of the document defaults' {
        $edition = ((Get-Content -LiteralPath $ReferencePresetsPath -Raw) | ConvertFrom-Json).presets.'class-range-edition'
        @($edition.PSObject.Properties.Name) | Should -Not -Contain 'includeSecondaryBsiRateTable' -Because 'the document default already keeps it off'
        @($edition.PSObject.Properties.Name) | Should -Not -Contain 'includeAntibioticUtilisationTable' -Because 'the edition stays off where the document default is off; only the overall report enables it, by parameter'
    }
}
