#Requires -Version 7.6
#requires -Module Pester
#requires -Module powershell-yaml

<#
.SYNOPSIS
    Pester gate for the reworked infection reads of both reports.

.DESCRIPTION
    The December edition replaces three pooled figures in the Reference and Partner Reports with
    figures the reader can act on: the infection section opens with counts instead of a mean of
    infections per patient, which has no time base; the infectious-agent texts quote the share per
    infection type instead of the pooled detection rate, which depends on each department's mix of
    infection types; and the sepsis and NEC kinds, the exposed patients and their mean days, and the
    departments' follow-up enter where the pooled figure alone stood. Each substitution is a read
    removed as much as a read added, and a left-behind pooled read renders a figure the methods text
    no longer explains. The gate holds both halves of that substitution:

    - The STRUCTURAL half reads the report sources and the three English string layers as text and
      YAML, and runs everywhere. It names the dataset row keys of the kinds (bsi_recognized,
      bsi_commensal, bsi_clinical, nec_surgical, nec_medical) and the column carrying the count the
      recognized-pathogen footnote shows, so the reports and the package cannot drift from one
      another silently; a recoded key that the dataset never carries drops its row from the table
      without a word, which is the failure this half exists to catch.
    - The BEHAVIOURAL half executes the shared helpers under R and is skipped where Rscript is
      absent, as the interpolation gate's half is; on CI its presence assertion makes an absent R
      a failure, not a silence.

.EXAMPLE
    Invoke-Pester -Path scripts/modules/NeoIPC-Tools/Tests/ReworkInfectionReads.Tests.ps1
#>

BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..')).Path
    $reportsDir = Join-Path $repoRoot 'reports'
    $helpers = Join-Path $reportsDir 'common' 'helpers.R'
    $rscript = (Get-Command Rscript -ErrorAction SilentlyContinue)?.Source

    # Runs an R snippet against a freshly sourced helpers.R and returns its stdout, so each
    # assertion is independent of the others' bindings, as in ReportInterpolationHygiene.Tests.ps1.
    # The existence guard is load-bearing: an ABSENT function also prints no PASS, and the guard
    # keeps that failure a refusal rather than an accident of the snippet.
    function Invoke-RSnippet {
        param([string]$Body, [string[]]$Guard)
        $guardLines = ($Guard | ForEach-Object {
            'stopifnot(exists("{0}"), is.function(get("{0}")))' -f $_
        }) -join "`n"
        $script = "source('$($helpers -replace '\\', '/')')`n$guardLines`n$Body"
        $file = New-TemporaryFile
        try {
            [System.IO.File]::WriteAllText($file.FullName, $script, [System.Text.UTF8Encoding]::new($false))
            (& $rscript --vanilla $file.FullName 2>&1) -join "`n"
        } finally {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    function Get-ReportSource {
        param([string]$RelativePath)
        (Get-Content -LiteralPath (Join-Path $reportsDir $RelativePath) -Raw)
    }

    # Every report source text (R, R Markdown, Quarto, YAML) outside the generated language layers,
    # as "file:text" pairs the pattern searches.
    function Get-AllReportSources {
        Get-ChildItem -LiteralPath $reportsDir -Recurse -File -Include '*.qmd', '*.Rmd', '*.R', '*.yaml' |
            Where-Object { $_.FullName -notmatch '\\content\.[a-z]' } |
            ForEach-Object {
                [pscustomobject]@{
                    Path = [IO.Path]::GetRelativePath($repoRoot, $_.FullName)
                    Text = Get-Content -LiteralPath $_.FullName -Raw
                }
            }
    }

    function Find-ReportSourceMatching {
        param([string]$Pattern)
        (Get-AllReportSources | Where-Object { $_.Text -match $Pattern }).Path
    }

    function Get-EnglishStringLayer {
        param([string]$RelativePath)
        ConvertFrom-Yaml (Get-Content -LiteralPath (Join-Path $reportsDir $RelativePath) -Raw)
    }

    # The {named} placeholders of a translatable string, as the string resources define them.
    function Get-StringPlaceholders {
        param([string]$Value)
        @([regex]::Matches($Value, '\{([a-z_][a-z0-9_]*)\}') | ForEach-Object { $_.Groups[1].Value })
    }
}

Describe 'The infection section opens with counts, not a mean' {

    Context 'the dataset resources carry the counts' -Skip:(-not $env:CI -and -not $rscript) {

        It 'Rscript is present on CI because the behavioural half needs it' {
            $rscript | Should -Not -BeNullOrEmpty -Because 'the behavioural half of this gate needs Rscript'
        }

        It 'formats the patients with at least one severe infection and drops the mean' {
            $out = Invoke-RSnippet -Guard @('format_dataset_resources') -Body @'
counts <- list(n_departments = 7L, n_patients = 100L, n_enrollments = 120L,
               n_patient_days = 400L, n_severe_infections = 30L,
               n_patients_with_severe_infection = 25L)
sR <- list(headerList = list(allBirthweights = "all", allGestationalAges = "all"),
           not_available = "n/a", unit_separator = " ", percent_symbol = "%",
           digit_group_separator = " ")
out <- format_dataset_resources(list(), counts, sR)
ok <- identical(out$numberOfPatientsWithSevereInfection, "25") &&
      is.null(out$averageSevereInfectionsPerPatient)
cat(if (ok) "PASS" else "FAIL", "\n")
'@
            $out | Should -MatchExactly '\bPASS\b' -Because 'the opening gives counts, and the mean of infections per patient has no time base'
        }
    }

    Context 'no read of the mean is left behind' {

        It 'no report source references averageSevereInfectionsPerPatient' {
            Find-ReportSourceMatching 'averageSevereInfectionsPerPatient' | Should -BeNullOrEmpty -Because 'the mean per patient leaves with the counts sentence that replaces it'
        }

        It 'both openings state the patients with at least one severe infection' {
            foreach ($file in 'Reference-Report/content/_nosocomial_infections.Rmd',
                              'Partner-Report/content/_nosocomial_infections.Rmd') {
                $text = Get-ReportSource $file
                $text | Should -Match 'had at least one' -Because "$file opens with the counts the template sets"
                $text | Should -Match 'numberOfPatientsWithSevereInfection' -Because "$file reads the patients-with-at-least-one figure"
            }
        }

        It 'the reference comparison names the patients with at least one' {
            $sR = Get-EnglishStringLayer 'Partner-Report/content/_sR.yaml'
            $sR.nosocomial_reference_comparison | Should -Match 'had at least one'
            (Get-StringPlaceholders $sR.nosocomial_reference_comparison) |
                Sort-Object | Should -Be @('infected_count', 'infection_count', 'patient_count') -Because 'the comparison gives the counts, not the mean'
        }
    }
}

Describe 'The sepsis and NEC kinds are rows of the incidence-density table' {

    Context 'the table files carry the kinds' {

        It 'both table files recode the five kinds and the unclassified count' {
            $countColumns = @{
                'Reference-Report/tables/_tbl-incidence-density-rates.qmd' = '"n_agent_unclassified"'
                'Partner-Report/tables/_tbl-incidence-density-rates.qmd' = '"n_agent_unclassified_own"'
            }
            foreach ($file in $countColumns.Keys | Sort-Object) {
                $text = Get-ReportSource $file
                foreach ($key in 'bsi_recognized', 'bsi_commensal', 'bsi_clinical',
                                 'nec_surgical', 'nec_medical') {
                    # The recode arm, not the bare string: a guard mentioning the key
                    # without mapping it to its label would drop the row silently.
                    $text | Should -Match ('"' + $key + '"\s*~') -Because "$file recodes the $key row to its label"
                }
                $text | Should -Match $countColumns[$file] -Because "$file reads the count column the dataset carries"
            }
        }
    }

    Context 'the strings carry the kinds' {

        It 'the labels and the kinds footnotes exist' {
            $common = Get-EnglishStringLayer 'common.yaml'
            $block = $common.'tbl-incidence-density-rates'
            foreach ($key in 'bsi_recognized', 'bsi_commensal', 'bsi_clinical',
                             'nec_surgical', 'nec_medical', 'bsi_kinds_footnote', 'nec_kinds_footnote') {
                $block.$key | Should -Not -BeNullOrEmpty -Because "common.yaml labels the $key row or footnotes the kinds"
            }
        }

        It 'the recognized-pathogen footnote carries the count of unclassified BSIs' {
            $common = Get-EnglishStringLayer 'common.yaml'
            $common.'tbl-incidence-density-rates'.bsi_kinds_footnote |
                Should -Match '\{count\}' -Because 'the footnote names how many BSIs carried an infectious agent the list cannot classify'
        }
    }
}

Describe 'The exposed patients and their days are a table of their own' {

    Context 'both reports carry it' {

        It 'the table files exist in both reports' {
            Join-Path $reportsDir 'Reference-Report/tables/_tbl-patients-exposed.qmd' |
                Should -Exist -Because 'the table of exposed patients and their mean days joins both reports'
            Join-Path $reportsDir 'Partner-Report/tables/_tbl-patients-exposed.qmd' |
                Should -Exist
        }

        It 'both content files include the table' {
            Get-ReportSource 'Reference-Report/_content.qmd' | Should -Match '_tbl-patients-exposed'
            Get-ReportSource 'Partner-Report/_content.qmd' | Should -Match '_tbl-patients-exposed'
        }
    }

    Context 'the strings carry it' {

        It 'the caption and the two measures are strings' {
            $common = Get-EnglishStringLayer 'common.yaml'
            $block = $common.'tbl-patients-exposed'
            $block.'tbl-cap' | Should -Be 'Patients Exposed to Risk and Protective Factors and Their Days of Exposure'
            $block.patients_exposed | Should -Not -BeNullOrEmpty
            $block.mean_days | Should -Not -BeNullOrEmpty
            $block.no_data | Should -Not -BeNullOrEmpty
            $block.abbreviations_footnote | Should -Not -BeNullOrEmpty
        }

        It 'both table files label all eight factors' {
            # The labels themselves are the shared glossary terms and derived
            # sentence-case variants, not a second copy in the table's block;
            # what the file must show is each dataset key bound to an sR lookup
            # on its recode arm.
            foreach ($file in 'Reference-Report/tables/_tbl-patients-exposed.qmd',
                              'Partner-Report/tables/_tbl-patients-exposed.qmd') {
                $text = Get-ReportSource $file
                foreach ($key in 'cvc', 'pvc', 'inv', 'niv', 'ab',
                                 'human_milk', 'probiotic', 'kangaroo_care') {
                    $text | Should -Match ('"' + $key + '"\s*~\s*sR\$') -Because "$file binds the $key factor to its label"
                }
            }
        }
    }
}

Describe 'The infectious-agent texts quote the types, not the pooled share' {

    Context 'the pooled read is gone' -Skip:(-not $env:CI -and -not $rscript) {

        It 'Rscript is present on CI because the behavioural half needs it' {
            $rscript | Should -Not -BeNullOrEmpty -Because 'the behavioural half of this gate needs Rscript'
        }

        It 'the pooled detection rate leaves the dataset resources' {
            $out = Invoke-RSnippet -Guard @('format_dataset_resources') -Body @'
counts <- list(n_departments = 7L, n_patients = 100L, n_enrollments = 120L,
               n_patient_days = 400L, n_severe_infections = 30L,
               n_infectious_agents = 40L, n_infections_with_agent = 20L,
               n_infections_overall = 60L)
sR <- list(headerList = list(allBirthweights = "all", allGestationalAges = "all"),
           not_available = "n/a", unit_separator = " ", percent_symbol = "%",
           digit_group_separator = " ")
out <- format_dataset_resources(list(), counts, sR)
cat(if (is.null(out$infectiousAgentDetectionRate)) "PASS" else "FAIL", "\n")
'@
            $out | Should -MatchExactly '\bPASS\b' -Because 'the pooled share depends on each department''s mix of infection types'
        }

        It 'the per-type counts and shares format from the type rows' {
            $out = Invoke-RSnippet -Guard @('format_agent_type_fields') -Body @'
sR <- list(digit_group_separator = " ", percent_symbol = "%", not_available = "n/a")
fields <- format_agent_type_fields(
  with_agent = list(bsi = 10L, hap = 8L, nec = 2L, ssi = 4L),
  totals = list(bsi = 50L, hap = 40L, nec = 20L, ssi = 0L), sR = sR)
dropped <- format_agent_type_fields(
  with_agent = list(bsi = 10L, hap = NULL),
  totals = list(bsi = 50L, hap = 40L), sR = sR)
ok <- identical(fields$bsi$count, "10") && identical(fields$bsi$total, "50") &&
      identical(fields$bsi$share, "20.0%") && identical(fields$nec$share, "10.0%") &&
      identical(fields$ssi$share, "n/a") && is.null(dropped$hap)
cat(if (ok) "PASS" else "FAIL", "\n")
'@
            $out | Should -MatchExactly '\bPASS\b' -Because 'the types replace the pooled share, and their shares format from the per-type rows'
        }
    }

    Context 'no pooled read is left behind' {

        It 'no report source reads the pooled rate field' {
            Find-ReportSourceMatching '\$(infectiousAgentDetectionRate|overallNumberOfInfections)\b' | Should -BeNullOrEmpty -Because 'the section quotes the types once the pooled rate is gone; the include parameter of the detection table keeps its name'
        }

        It 'neither setup reads the all row of the per-type table' {
            foreach ($file in 'Reference-Report/_setup.qmd', 'Partner-Report/_setup.qmd') {
                (Get-ReportSource $file) | Should -Not -Match '(?m)\binf\s*==\s*"all"|("inf",\s*"all")' -Because "$file must not read the row that the December datasets drop"
            }
        }

        It 'the outlier registry has no all metric for the per-type table' {
            $setup = Get-ReportSource 'Partner-Report/_setup.qmd'
            $setup | Should -Not -Match 'metrics\s*=\s*c\("all"'
            $setup | Should -Not -Match 'total_metric\s*=\s*"all"'
        }

        It 'the outlier strings dropped the all metric and do not name pathogens' {
            $sR = Get-EnglishStringLayer 'Partner-Report/content/_sR.yaml'
            $sR.outlier.agent_detection_per_inf_type_all_zero | Should -BeNullOrEmpty
            $sR.outlier.agent_detection_per_inf_type_interpretation_all_above | Should -BeNullOrEmpty
            $sR.outlier.agent_detection_per_inf_type_interpretation_all_below | Should -BeNullOrEmpty
            $sR.outlier.agent_detection_per_inf_type_interpretation_some_above | Should -Not -Match 'athogen'
            $sR.outlier.agent_detection_per_inf_type_interpretation_some_below | Should -Not -Match 'athogen'
        }

        It 'both infectious-agent texts quote the recorded share per type' {
            foreach ($file in 'Reference-Report/content/_infectious_agents.Rmd',
                              'Partner-Report/content/_infectious-agents.Rmd') {
                $text = Get-ReportSource $file
                $text | Should -Match 'had an infectious agent recorded' -Because "$file quotes the types"
                $text | Should -Not -Match '\$infectiousAgentDetectionRate\b'
            }
        }
    }
}

Describe 'The Partner Report shows the secondary-BSI and antibiotic tables by default' {

    It 'the two include parameters default to true in every language front end' {
        $files = Get-ChildItem -LiteralPath (Join-Path $reportsDir 'Partner-Report') -File -Filter 'Partner-Report*.qmd'
        $files.Count | Should -BeGreaterThan 0
        foreach ($file in $files) {
            $qmd = Get-Content -LiteralPath $file.FullName -Raw
            $qmd | Should -Match '(?m)^\s*includeSecondaryBsiRateTable:\s*true\s*$' -Because "$($file.Name) defaults the secondary-BSI table on"
            $qmd | Should -Match '(?m)^\s*includeAntibioticUtilisationTable:\s*true\s*$' -Because "$($file.Name) defaults the antibiotic table on"
        }
    }
}
