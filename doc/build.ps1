[CmdletBinding()]
param(
    [ValidateSet('all', 'html', 'pdf', 'docx')]
    [string]$Format = 'all',
    [CultureInfo[]]$TargetCultures,
    [switch]$Release
    )

function Test-RebuildRequired {
    [OutputType([bool])]
    param (
        [parameter(Mandatory,Position=0)]
        [string]
        $OutputPath,
        [parameter(Mandatory,Position=1)]
        [string]
        $FirstInputPath,
        [parameter(Position=2)]
        [string[]]
        $AdditionalInputPaths
    )

    if (-not (Test-Path $OutputPath -PathType Leaf)) {
        Write-Debug ("'$OutputPath' does not exist." -replace "/", [IO.Path]::DirectorySeparatorChar)
        return $true
    }

    $outputStamp = (Get-ChildItem $OutputPath).LastWriteTimeUtc
    $inputStamp = (Get-ChildItem $FirstInputPath).LastWriteTimeUtc

    if ($outputStamp -lt $inputStamp) {
        Write-Debug ("'$OutputPath' is older than '$FirstInputPath'." -replace "/", [IO.Path]::DirectorySeparatorChar)
        return $true
    }

    foreach ($inputPath in $AdditionalInputPaths) {
        $inputStamp = (Get-ChildItem $inputPath).LastWriteTimeUtc
        if ($outputStamp -lt $inputStamp) {
            Write-Debug ("'$OutputPath' is older than '$inputPath'." -replace "/", [IO.Path]::DirectorySeparatorChar)
            return $true
        }
        Write-Debug ("'$OutputPath' is newer than or equal to '$inputPath'." -replace "/", [IO.Path]::DirectorySeparatorChar)
    }

    return $false
}

if ($null -eq $targetCultures)
{
    $targetCultures = @(
        (new-object CultureInfo("")),
        (new-object CultureInfo("de")),
        (new-object CultureInfo("es"))
         )
}
if ($Release)
{
    $revRemark = 'revremark!'
}
else {
    $revRemark = 'revremark=Preview'
}

$metadataDir = (Resolve-Path -Path "$PSScriptRoot/../metadata").Path
$antibioticsDir = "$metadataDir/common/antibiotics"
$pathogensDir = "$metadataDir/common/pathogens"
$buildDir = "$PSScriptRoot/build"
$outDir = "$PSScriptRoot/out"
$protocolDir = "$PSScriptRoot/protocol"
$imgDir = "$protocolDir/img"
$buildImgDir = "$buildDir/img"
$resDir = "$protocolDir/resx"
$transDir = "$protocolDir/xslt"

if (-not (Test-Path -LiteralPath $buildDir -PathType Container)) {
    Write-Debug -Message "Build directory does not exist."
    $p = (New-Item -Path $PSScriptRoot -Name build -ItemType Directory).FullName
    Write-Verbose -Message "Created build directory at '$p'."
}

if (-not (Test-Path -LiteralPath $buildImgDir -PathType Container)) {
    Write-Debug -Message "Build image directory does not exist."
    $p = (New-Item -Path $buildDir -Name img -ItemType Directory).FullName
    Write-Verbose -Message "Created build image directory at '$p'."
}

if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    Write-Debug -Message "Output directory does not exist."
    $p = (New-Item -Path $PSScriptRoot -Name out -ItemType Directory).FullName
    Write-Verbose -Message "Created output directory at '$p'."
}

Copy-Item $imgDir/* $buildImgDir/ -Force
Copy-Item $imgDir $buildImgDir/ -Force -Recurse
Copy-Item $imgDir $outDir -Force -Recurse

[AppContext]::SetSwitch("Switch.System.Xml.AllowDefaultResolver", $true);
$resolver = New-Object System.Xml.XmlUrlResolver

$titlePage = New-Object System.Xml.Xsl.XslCompiledTransform
$titlePage.Load((Get-ChildItem $transDir/NeoIPC-Core-Title-Page.xslt).FullName, [System.Xml.Xsl.XsltSettings]::TrustedXslt, $resolver)

$previewWatermark = New-Object System.Xml.Xsl.XslCompiledTransform
$previewWatermark.Load((Get-ChildItem $transDir/Preview-Watermark.xslt).FullName, [System.Xml.Xsl.XsltSettings]::TrustedXslt, $resolver)

$decisionFlow = New-Object System.Xml.Xsl.XslCompiledTransform
$decisionFlow.Load((Get-ChildItem $transDir/NeoIPC-Core-Decision-Flow.xslt).FullName, [System.Xml.Xsl.XsltSettings]::TrustedXslt, $resolver)

$masterDataSheet = New-Object System.Xml.Xsl.XslCompiledTransform
$masterDataSheet.Load((Get-ChildItem $transDir/NeoIPC-Core-Master-Data-Collection-Sheet.xslt).FullName, [System.Xml.Xsl.XsltSettings]::TrustedXslt, $resolver)

$masterDataSheetImage = New-Object System.Xml.Xsl.XslCompiledTransform
$masterDataSheetImage.Load((Get-ChildItem $transDir/NeoIPC-Core-Master-Data-Collection-Sheet-Image.xslt).FullName, [System.Xml.Xsl.XsltSettings]::TrustedXslt, $resolver)

if (Test-RebuildRequired $buildDir/NeoIPC-Core-Protocol.header.adoc $protocolDir/NeoIPC-Core-Protocol.header.adoc) {
    Write-Debug "Copying Asciidoc header file to build dir"
    Copy-Item $protocolDir/NeoIPC-Core-Protocol.header.adoc $buildDir/NeoIPC-Core-Protocol.header.adoc -Force
}

foreach ($targetCulture in $targetCultures)
{
    if ("iv" -eq $targetCulture.TwoLetterISOLanguageName)
    {
        $revDate = "revdate=$([datetime]::UtcNow.ToString('yyyy-MM-dd'))"
        $lang = ""
        $langSuffix = ""
        Write-Information "Creating NeoIPC documentation (english)"

        if (Test-RebuildRequired $buildDir/NeoIPC-Antibiotics.adoc $antibioticsDir/NeoIPC-Antibiotics.csv) {
            Write-Verbose "Creating appendix table for antibiotics"

            Import-Csv -LiteralPath $antibioticsDir/NeoIPC-Antibiotics.csv -Encoding utf8 |
                Sort-Object name |
                ForEach-Object { "|$($_.name) |$($_.atc_code)" } |
                Out-File -LiteralPath $buildDir/NeoIPC-Antibiotics.adoc -Encoding utf8NoBOM -Append
        }
    }
    else
    {
        $revDate = "revdate=$([datetime]::UtcNow.ToString('d', $targetCulture))"
        $lang = $targetCulture.TwoLetterISOLanguageName
        $langSuffix = ".$lang"
        Write-Information "Creating NeoIPC documentation for language '$($targetCulture.DisplayName)'"

        if (Test-RebuildRequired $buildDir/NeoIPC-Antibiotics$langSuffix.adoc $antibioticsDir/NeoIPC-Antibiotics.csv $antibioticsDir/NeoIPC-Antibiotics$langSuffix.csv) {
            Write-Verbose "Creating appendix table for antibiotics"

            $hash = @{}
            Import-Csv -LiteralPath $antibioticsDir/NeoIPC-Antibiotics$langSuffix.csv -Encoding utf8 |
                ForEach-Object {
                    if ($_.property -cne 'NAME') {
                        throw "Unexpected property value '$($_.property)' in file '$antibioticsDir/NeoIPC-Antibiotics$langSuffix.csv'"
                    }
                    $loc = @{}
                    $loc['default'] = $_.default

                    if ($_.needs_translation -ceq 'f') {
                        $loc['translated'] = $null
                    } elseif ($_.needs_translation -ceq 't') {
                        $loc['translated'] = $_.translated
                    } else {
                        throw "Unexpected needs_translation value '$($_.needs_translation)' in file '$antibioticsDir/NeoIPC-Antibiotics$langSuffix.csv'"
                    }
                    $hash[$_.code] = $loc
                }

            Import-Csv -LiteralPath $antibioticsDir/NeoIPC-Antibiotics.csv -Encoding utf8 |
                Sort-Object name |
                ForEach-Object {
                    $loc = $hash[$_.atc_code]
                    if ($loc['default'] -cne $_.name) {
                        throw "Values for name ($($_.name)) and default ($($loc['default']) for ATC code '$($_.atc_code)' don't match between '$antibioticsDir/NeoIPC-Antibiotics.csv' and '$antibioticsDir/NeoIPC-Antibiotics$langSuffix.csv'"
                    }
                    if ($loc['translated']) {
                        $name = $loc['translated']
                    }
                    else {
                        $name = $_.name
                    }

                    "|$name |$($_.atc_code)"
                } |
                Out-File -LiteralPath $buildDir/NeoIPC-Antibiotics$langSuffix.adoc -Encoding utf8NoBOM -Append
        }
    }
    if (Test-RebuildRequired $buildImgDir/NeoIPC-Core-Title-Page$langSuffix.svg $resDir/NeoIPC-Core-Title-Page$langSuffix.resx $transDir/NeoIPC-Core-Title-Page.xslt) {
        Write-Verbose "Creating title page background SVG"
        $titlePage.Transform("$resDir/NeoIPC-Core-Title-Page$langSuffix.resx", "$buildImgDir/NeoIPC-Core-Title-Page$langSuffix.svg")
    }
    if (($revRemark -ne 'revremark!') -and (Test-RebuildRequired $buildImgDir/Preview-Watermark$langSuffix.svg $resDir/Preview-Watermark$langSuffix.resx $transDir/Preview-Watermark.xslt)) {
        Write-Verbose "Creating preview watermark SVG"
        $previewWatermark.Transform("$resDir/Preview-Watermark$langSuffix.resx", "$buildImgDir/Preview-Watermark$langSuffix.svg")
    }
    if (Test-RebuildRequired $buildImgDir/NeoIPC-Core-Decision-Flow$langSuffix.svg $resDir/NeoIPC-Core-Decision-Flow$langSuffix.resx $transDir/NeoIPC-Core-Decision-Flow.xslt) {
        Write-Verbose "Creating decision flow SVG"
        $decisionFlow.Transform("$resDir/NeoIPC-Core-Decision-Flow$langSuffix.resx", "$buildImgDir/NeoIPC-Core-Decision-Flow$langSuffix.svg")
    }
    if (Test-RebuildRequired $buildImgDir/NeoIPC-Core-Master-Data-Collection-Sheet$langSuffix.svg $resDir/NeoIPC-Core-Master-Data-Collection-Sheet$langSuffix.resx $transDir/NeoIPC-Core-Master-Data-Collection-Sheet.xslt) {
        Write-Verbose "Creating master data collection sheet SVG"
        $masterDataSheet.Transform("$resDir/NeoIPC-Core-Master-Data-Collection-Sheet$langSuffix.resx", "$buildImgDir/NeoIPC-Core-Master-Data-Collection-Sheet$langSuffix.svg")
    }
    if (Test-RebuildRequired $buildImgDir/NeoIPC-Core-Master-Data-Collection-Sheet-Image$langSuffix.svg $resDir/NeoIPC-Core-Master-Data-Collection-Sheet$langSuffix.resx $transDir/NeoIPC-Core-Master-Data-Collection-Sheet-Image.xslt) {
        Write-Verbose "Creating master data collection sheet image SVG"
        $masterDataSheetImage.Transform("$resDir/NeoIPC-Core-Master-Data-Collection-Sheet$langSuffix.resx", "$buildImgDir/NeoIPC-Core-Master-Data-Collection-Sheet-Image$langSuffix.svg")
    }
    if (Test-RebuildRequired $buildDir/NeoIPC-Core-Protocol$langSuffix.adoc $protocolDir/NeoIPC-Core-Protocol$langSuffix.adoc) {
        Write-Debug "Copying Asciidoc files to build dir"
        Copy-Item $protocolDir/*$langSuffix.adoc $buildDir/ -Force
    }
    if (($Format -eq 'all' -or $Format -eq 'html') -and (Test-RebuildRequired $outDir/index$langSuffix.html $buildDir/NeoIPC-Core-Protocol$langSuffix.adoc @(
        "$buildDir/NeoIPC-Core-Protocol.header.adoc",
        "$buildImgDir/NeoIPC-Core-Decision-Flow$langSuffix.svg",
        "$buildImgDir/NeoIPC-Core-Master-Data-Collection-Sheet-Image$langSuffix.svg"
        ))) {
        Write-Information "Creating HTML"
        asciidoctor -a $revRemark -a $revDate --backend html5 --warnings --trace --failure-level WARN --destination-dir $outDir --out-file index$langSuffix.html $buildDir/NeoIPC-Core-Protocol$langSuffix.adoc
    }
    if (($Format -eq 'all' -or $Format -eq 'pdf') -and (Test-RebuildRequired $outDir/NeoIPC-Core-Protocol$langSuffix.pdf $buildDir/NeoIPC-Core-Protocol$langSuffix.adoc @(
        "$buildDir/NeoIPC-Core-Protocol.header.adoc",
        "$PSScriptRoot/NeoIPC.theme.yml",
        "$buildImgDir/NeoIPC-Core-Title-Page$langSuffix.svg",
        "$buildImgDir/NeoIPC-Core-Decision-Flow$langSuffix.svg",
        "$buildImgDir/NeoIPC-Core-Master-Data-Collection-Sheet-Image$langSuffix.svg"
        ))) {
        Write-Information "Creating PDF"
        if ($IsWindows) {
            Write-Warning "Asciidoctor Mathematical is not supported on Windows. The STEM expressions will not be converted."
            asciidoctor-pdf -a $revRemark -a $revDate --warnings --trace --failure-level WARN --destination-dir $outDir --out-file NeoIPC-Core-Protocol$langSuffix.pdf $buildDir/NeoIPC-Core-Protocol$langSuffix.adoc
        } else {
            asciidoctor-pdf -a $revRemark -a $revDate -a mathematical-format=svg -r asciidoctor-mathematical --warnings --trace --failure-level WARN --destination-dir $outDir --out-file NeoIPC-Core-Protocol$langSuffix.pdf $buildDir/NeoIPC-Core-Protocol$langSuffix.adoc
        }
    }
    if (($Format -eq 'all' -or $Format -eq 'docx') -and (Test-RebuildRequired $outDir/NeoIPC-Core-Protocol$langSuffix.docx $buildDir/NeoIPC-Core-Protocol$langSuffix.adoc @(
        "$buildDir/NeoIPC-Core-Protocol.header.adoc",
        "$buildDir/NeoIPC-Core-Protocol$langSuffix.xml",
        "$buildImgDir/NeoIPC-Core-Decision-Flow$langSuffix.svg",
        "$buildImgDir/NeoIPC-Core-Master-Data-Collection-Sheet-Image$langSuffix.svg"
        ))) {
        Write-Information "Creating Open XML (docx)"
        if (Test-RebuildRequired $buildDir/NeoIPC-Core-Protocol$langSuffix.xml $buildDir/NeoIPC-Core-Protocol$langSuffix.adoc) {
            Write-Verbose "Creating DocBook xml"
            if ($IsWindows) {
                Write-Warning "Asciidoctor Mathematical is not supported on Windows. The STEM expressions will not be converted."
                asciidoctor -a $revRemark -a $revDate --backend docbook --warnings --trace --failure-level WARN --destination-dir $buildDir --out-file NeoIPC-Core-Protocol$langSuffix.xml $buildDir/NeoIPC-Core-Protocol$langSuffix.adoc
            } else {
                asciidoctor -a $revRemark -a $revDate -a mathematical-format=svg -r asciidoctor-mathematical --backend docbook --warnings --trace --failure-level WARN --destination-dir $buildDir --out-file NeoIPC-Core-Protocol$langSuffix.xml $buildDir/NeoIPC-Core-Protocol$langSuffix.adoc
            }
        }
        if (Test-RebuildRequired $outDir/img/NeoIPC-Core-Decision-Flow$langSuffix.docx $buildDir/NeoIPC-Core-Decision-Flow$langSuffix.xml @(
            "$buildImgDir/NeoIPC-Core-Decision-Flow$langSuffix.svg",
            "$buildImgDir/NeoIPC-Core-Master-Data-Collection-Sheet-Image$langSuffix.svg"
            )) {
            Write-Verbose "Creating DOCX"
            $locationBackup = Get-Location
            Set-Location $buildDir
            pandoc --from=docbook --to=docx --toc --output=$outDir/NeoIPC-Core-Protocol$langSuffix.docx NeoIPC-Core-Protocol$langSuffix.xml
            Set-Location $locationBackup
        }
    }
}
