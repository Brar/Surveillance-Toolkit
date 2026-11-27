#!/usr/bin/env pwsh
#Requires -Version 7.6

<#
.SYNOPSIS
    Assert that rendered report PDFs carry the tagging structure their declarations claim.

.DESCRIPTION
    The reports declare PDF/UA-2 except the Partner Certificate, and a declaration the file does
    not honour is worse than no declaration: consumers trust it. This script opens the rendered
    PDFs and checks what the declaration obliges, in the file itself:

    1. a UA-2 report has /StructTreeRoot and /MarkInfo /Marked true, so it is a tagged PDF at the
       document level, and at least one /S /Sect structure element, so headings — not just the
       document shell — carry structure; a UA-2 file without these is a defect;
    2. the Partner-Certificate file, which declares archival a-4 alone because its textpos layout
       is incompatible with tagging, must have no /StructTreeRoot: a silently tagged file under an
       untagged declaration is the mirror-image defect;
    3. the XMP metadata declares pdfaid:part 4 in every report, and pdfuaid:part 2 in exactly the
       UA-2 ones, since that identifier is where a consumer reads the claim;
    4. the number of /Alt entries is at least the number of /S /Figure structure elements, so no
       figure stands wholly without accessible text. This one is a count, not a mapping: pairing
       each figure with its text is a conforming validator's job, and the count only proves no
       figure is missing one outright. Where an alt repeats its image's file path — the tagging
       engine's fallback when LaTeX hands it none — the script reports it as a warning, which
       --FailOnPathAlt turns into a failure; a figure's /Alt is that path fallback today.

    The PDF objects live in compressed object streams, so there is nothing to read raw: the
    script decompresses each file with qpdf (`qpdf --decrypt --qdf --object-streams=disable`,
    which also rewrites cross-stream objects as ordinary ones) and matches the decoded text.
    There is no PDF parser in PowerShell; the qpdf QDF dump is the documented means of reading
    these files as text, and the patterns are line-anchored against it. qpdf is required.

    PDFs are matched to reports by file name: the rendered document of the Reference Report,
    whatever the build names it inside the report's output directory, must be handed in under a
    name containing the directory's (so Reference-Report.pdf or Reference-Report.de.pdf is
    accepted for the Reference Report). Every missing file fails the run: a green result always
    means all five were inspected.

.EXAMPLE
    pwsh scripts/Test-ReportPdfTagging.ps1 -RenderedDir tmp/renders

.PARAMETER RenderedDir
    Directory holding the rendered PDFs, named as above. Required.

.PARAMETER FailOnPathAlt
    Fail instead of warn where a figure's /Alt text repeats its file path.

.OUTPUTS
    Exit code 0 when every check passes, 1 otherwise. Nothing is modified.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $RenderedDir,

    [switch] $FailOnPathAlt
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command qpdf -ErrorAction Ignore)) {
    Write-Error 'qpdf is required to decompress the PDF object streams this script reads.' -ErrorAction Continue
    exit 1
}

# One row per report: whether it declares PDF/UA-2 next to a-4. The Certificate's textpos layout
# is incompatible with LaTeX tagging, so it stays archival-only; the gate
# scripts/modules/NeoIPC-Tools/Tests/ReportPdfStandards.Tests.ps1 holds the configuration side.
$reports = @(
    @{ Name = 'Partner-Certificate'; Ua2 = $false }
    @{ Name = 'Partner-Report'; Ua2 = $true }
    @{ Name = 'Patient-Data-Report'; Ua2 = $true }
    @{ Name = 'Reference-Report'; Ua2 = $true }
    @{ Name = 'Validation-Report'; Ua2 = $true }
)

$resolved = (Resolve-Path -LiteralPath $RenderedDir).Path
$pdfs = Get-ChildItem -LiteralPath $resolved -File -Filter '*.pdf'
$failures = [System.Collections.Generic.List[string]]::new()

foreach ($report in $reports) {
    $pdf = $pdfs | Where-Object Name -Like "*$($report.Name)*.pdf" | Select-Object -First 1
    if (-not $pdf) {
        $failures.Add("$($report.Name): no rendered PDF found in $resolved")
        continue
    }

    $dump = (& qpdf --decrypt --qdf --object-streams=disable $pdf.FullName -) -join "`n"

    $hasStruct = $dump -match '(?m)^  /StructTreeRoot '
    if ($report.Ua2) {
        if (-not $hasStruct) {
            $failures.Add("$($pdf.Name): declares ua-2 but has no /StructTreeRoot")
        }
        # /MarkInfo may be inline or a reference; require /Marked true in whichever
        # dictionary it names, not merely anywhere in the file.
        $markInfoInline = [regex]::Match($dump, '(?ms)^  /MarkInfo <<.{0,80}?/Marked true')
        $markInfoRef = [regex]::Match($dump, '(?m)^  /MarkInfo (\d+) 0 R')
        if (-not $markInfoInline.Success) {
            if (-not $markInfoRef.Success) {
                $failures.Add("$($pdf.Name): declares ua-2 but has no /MarkInfo")
            }
            elseif ($dump -notmatch "(?ms)^\r?\n?$($markInfoRef.Groups[1].Value) 0 obj\b.{0,120}?/Marked true") {
                $failures.Add("$($pdf.Name): declares ua-2 but its /MarkInfo does not say /Marked true")
            }
        }
        if ($dump -notmatch '/S /Sect') {
            $failures.Add("$($pdf.Name): declares ua-2 but carries no /S /Sect heading structure")
        }
    }
    elseif ($hasStruct) {
        $failures.Add("$($pdf.Name): declares a-4 alone but is a tagged PDF")
    }

    if ($dump -notmatch 'pdfaid:part>4') {
        $failures.Add("$($pdf.Name): XMP does not declare pdfaid:part 4")
    }
    $hasUaId = $dump -match 'pdfuaid:part>2'
    if ($report.Ua2 -and -not $hasUaId) {
        $failures.Add("$($pdf.Name): XMP does not declare pdfuaid:part 2")
    }
    if (-not $report.Ua2 -and $hasUaId) {
        $failures.Add("$($pdf.Name): XMP declares pdfuaid:part 2, which it does not conform to")
    }

    $figures = ([regex]::Matches($dump, '(?m)^  /S /Figure$')).Count
    $alts = ([regex]::Matches($dump, '(?m)^  /Alt ')).Count
    if ($figures -gt $alts) {
        $failures.Add("$($pdf.Name): $figures Figure elements but only $alts /Alt entries")
    }
    # The tagging engine defaults a figure's /Alt to its file path when LaTeX hands it no alt
    # text. The decoded defaults come out of qpdf as UTF-16 hex strings whose readable part is
    # the path; a real description does not contain a file separator.
    $pathAlts = [regex]::Matches($dump, '(?mi)^  /Alt <feff([0-9a-f]{4})+>$') |
        ForEach-Object {
            $bytes = [byte[]]::new($_.Groups[1].Captures.Count * 2)
            for ($i = 0; $i -lt $_.Groups[1].Captures.Count; $i++) {
                $hi = [Convert]::ToByte($_.Groups[1].Captures[$i].Value.Substring(0, 2), 16)
                $lo = [Convert]::ToByte($_.Groups[1].Captures[$i].Value.Substring(2, 2), 16)
                $bytes[2 * $i] = $hi
                $bytes[2 * $i + 1] = $lo
            }
            [System.Text.Encoding]::BigEndianUnicode.GetString($bytes)
        } |
        Where-Object { $_ -match '[/\\]' -and $_ -match '\.(?:png|jpg|jpeg|pdf)$' }
    if ($pathAlts) {
        $message = "$($pdf.Name): figure /Alt repeats a file path ($($pathAlts -join ', '))"
        if ($FailOnPathAlt) {
            $failures.Add($message)
        } else {
            Write-Warning $message
        }
    }

    Write-Host ("OK   {0}" -f $pdf.Name) -NoNewline
    Write-Host (" struct={0} figures={1} alts={2}" -f $hasStruct, $figures, $alts)
}

if ($failures.Count) {
    foreach ($failure in $failures) {
        Write-Host "FAIL $failure"
    }
    exit 1
}
exit 0
