[CmdletBinding()]
param(
    [ValidateSet('all', 'html', 'pdf', 'docx')]
    [string]$Format = 'all',
    [CultureInfo[]]$TargetCultures,
    [switch]$Release
    )

Import-Module -Name (Join-Path -Resolve -Path $PSScriptRoot -ChildPath 'modules' -AdditionalChildPath 'NeoIPC-Tools') -Force

$workspaceFolder = Join-Path -Resolve -Path $PSScriptRoot -ChildPath '..'
$metadataFolder =  Join-Path -Resolve -Path $workspaceFolder -ChildPath 'metadata'
$artifactsFolder = Join-Path -Resolve -Path $workspaceFolder -ChildPath 'artifacts' -ErrorAction SilentlyContinue
if (-not $artifactsFolder) {
    Write-Debug -Message "Creating build artifacts directory"
    $artifactsFolder = (New-Item -Path $workspaceFolder -Name 'artifacts' -ItemType Directory).FullName
}
$antibioticsDir = Join-Path -Resolve -Path $metadataFolder -ChildPath 'common' -AdditionalChildPath 'antibiotics'
$pathogensDir = Join-Path -Resolve -Path $metadataFolder -ChildPath 'common' -AdditionalChildPath 'pathogens'
$docDir = Join-Path -Resolve -Path $workspaceFolder -ChildPath 'doc'
$protocolDir = Join-Path -Resolve -Path $docDir -ChildPath 'protocol'
$imgDir = Join-Path -Resolve -Path $protocolDir -ChildPath 'img'
$resDir = Join-Path -Resolve -Path $protocolDir -ChildPath 'resx'
$transDir = Join-Path -Resolve -Path $protocolDir -ChildPath 'xslt'

if ($null -eq $TargetCultures) {
    $TargetCultures = Get-Item .\doc\protocol\NeoIPC-Core-Protocol.*adoc |
    ForEach-Object { [CultureInfo]($_.Name -replace 'NeoIPC-Core-Protocol\.?([^.]*)\.adoc','$1') }
}

if ($Release) { $revRemark = 'revremark!' }
else { $revRemark = 'revremark=Preview' }

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

$attributes = @{}
if (-not $Release) { $attributes.revremark = $revRemark }

foreach ($targetCulture in $targetCultures)
{
    if ($targetCulture.Name) { $attributes.lang = $targetCulture.TwoLetterISOLanguageName } else { $attributes.Remove('lang') }

    if ("iv" -eq $targetCulture.TwoLetterISOLanguageName)
    {
        $revDate = "revdate=$([datetime]::UtcNow.ToString('yyyy-MM-dd'))"
        $localeSuffix = ""
        Write-Information "Generating NeoIPC documentation (english)"
    }
    else
    {
        $revDate = "revdate=$([datetime]::UtcNow.ToString('d', $targetCulture))"
        $localeSuffix = ".$($targetCulture.Name)"
        Write-Information "Generating NeoIPC documentation for language '$($targetCulture.DisplayName)'"
    }
    Build-Target (Get-LocalisedPath $protocolDir 'NeoIPC-Antibiotics.adoc' $targetCulture) (Get-LocalisedPath $antibioticsDir NeoIPC-Antibiotics.csv $targetCulture -All -Existing) {
        Write-Verbose "Generating list of antibiotics"
        New-AntibioticsList -TargetCulture $targetCulture -MetadataPath $metadataFolder -AsciiDoc > "$protocolDir/NeoIPC-Antibiotics$localeSuffix.adoc"
    }
    Build-Target (Get-LocalisedPath $protocolDir 'NeoIPC-Pathogens.adoc' $targetCulture) (Get-LocalisedPath $pathogensDir 'NeoIPC-Pathogen-Concepts.csv' $targetCulture -All -Existing),(Get-LocalisedPath $pathogensDir 'NeoIPC-Pathogen-Synonyms.csv' $targetCulture -All -Existing) {
        Write-Verbose "Generating list of infectious agents"
        New-PathogenList -TargetCulture $targetCulture -InputDirectory $pathogensDir -OutputDirectory $protocolDir
    }
    Build-Target (Get-LocalisedPath $imgDir 'NeoIPC-Core-Title-Page.svg' $targetCulture) (Get-LocalisedPath $resDir 'NeoIPC-Core-Title-Page.resx' $targetCulture -All -Existing),(Join-Path $transDir 'NeoIPC-Core-Title-Page.xslt') {
        Write-Verbose "Generating title page background SVG"
        $titlePage.Transform("$resDir/NeoIPC-Core-Title-Page$localeSuffix.resx", "$imgDir/NeoIPC-Core-Title-Page$localeSuffix.svg")
    }
    if (-not $Release) {
        Build-Target (Get-LocalisedPath $imgDir 'Preview-Watermark.svg' $targetCulture) (Get-LocalisedPath $resDir 'Preview-Watermark.resx' $targetCulture -All -Existing),(Join-Path $transDir 'Preview-Watermark.xslt') {
            Write-Verbose "Generating preview watermark SVG"
            $previewWatermark.Transform("$resDir/Preview-Watermark$localeSuffix.resx", "$imgDir/Preview-Watermark$localeSuffix.svg")
        }
    }
    Build-Target (Get-LocalisedPath $imgDir 'NeoIPC-Core-Decision-Flow.svg' $targetCulture) (Get-LocalisedPath $resDir 'NeoIPC-Core-Decision-Flow.resx' $targetCulture -All -Existing),(Join-Path $transDir 'NeoIPC-Core-Decision-Flow.xslt') {
        Write-Verbose "Generating decision flow SVG"
        $decisionFlow.Transform("$resDir/NeoIPC-Core-Decision-Flow$localeSuffix.resx", "$imgDir/NeoIPC-Core-Decision-Flow$localeSuffix.svg")
    }
    Build-Target (Get-LocalisedPath $imgDir 'NeoIPC-Core-Master-Data-Collection-Sheet.svg' $targetCulture) (Get-LocalisedPath $resDir 'NeoIPC-Core-Master-Data-Collection-Sheet.resx' $targetCulture -All -Existing),(Join-Path $transDir 'NeoIPC-Core-Master-Data-Collection-Sheet.xslt') {
        Write-Verbose "Generating master data collection sheet SVG"
        $masterDataSheet.Transform("$resDir/NeoIPC-Core-Master-Data-Collection-Sheet$localeSuffix.resx", "$imgDir/NeoIPC-Core-Master-Data-Collection-Sheet$localeSuffix.svg")
    }
    Build-Target (Get-LocalisedPath $imgDir 'NeoIPC-Core-Master-Data-Collection-Sheet-Image.svg' $targetCulture) (Get-LocalisedPath $resDir 'NeoIPC-Core-Master-Data-Collection-Sheet.resx' $targetCulture -All -Existing),(Join-Path $transDir 'NeoIPC-Core-Master-Data-Collection-Sheet-Image.xslt') {
        Write-Verbose "Generating master data collection sheet image SVG"
        $masterDataSheetImage.Transform("$resDir/NeoIPC-Core-Master-Data-Collection-Sheet$localeSuffix.resx", "$imgDir/NeoIPC-Core-Master-Data-Collection-Sheet-Image$localeSuffix.svg")
    }
    $protocolFile = Get-LocalisedPath $protocolDir 'NeoIPC-Core-Protocol.adoc' $targetCulture -Resolve
    if ($Format -eq 'all' -or $Format -eq 'html') {
        $att = $attributes.Clone()
        $att['backend-html5'] = $true
        $outputFile = Get-LocalisedPath $artifactsFolder 'index.html' $targetCulture
        Build-Target $outputFile (@($protocolFile)+@(Export-AsciiDocReferences $protocolFile $att)) {
            Write-Information "Generating HTML"
            asciidoctor -a $revRemark -a $revDate -b html5 -w --failure-level=WARN -D $(Resolve-Path $artifactsFolder -Relative) -o $([System.IO.Path]::GetFileName($outputFile)) $(Resolve-Path $protocolFile -Relative)
            if (-not $?) { exit 1 }
            Write-Verbose "Linting HTML"
            $allOutput = & linthtml --config (((Resolve-Path -Relative "$docDir/.linthtmlrc.yaml") -replace "\\","/") -replace "\./","") (((Resolve-Path -Relative $outputFile) -replace "\\","/") -replace "\./","") 2>&1
            $success = $?
            $stderr = $allOutput | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
            $stdout = $allOutput | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
            # For some reason linthtml writes standard output to STDERR and error messages to STDOUT
            foreach ($msg in $stderr) {
                if ($msg.Exception.Message.Trim().Length -gt 0) {
                    Write-Verbose $msg.Exception.Message
                }
            }
            if (-not $success) {
                foreach ($msg in $stdout) {
                    if ($msg.Trim().Length -gt 0) {
                        Write-Error $msg
                    }
                }
                exit 1
            }
        }
    }
    if ($Format -eq 'all' -or $Format -eq 'docx' -or ($Format -eq 'pdf' -and $targetCulture.TextInfo.IsRightToLeft)) {
        $att = $attributes.Clone()
        $att['backend-docbook5'] = $true
        $docbookFile = Get-LocalisedPath $protocolDir 'NeoIPC-Core-Protocol.xml' $targetCulture
        Build-Target $docbookFile (@($protocolFile)+@(Export-AsciiDocReferences $protocolFile $att)) {
            Write-Verbose "Generating DocBook xml"
            asciidoctor -a $revRemark -a $revDate -b docbook -w --failure-level=WARN -D $(Resolve-Path $protocolDir -Relative) -o $([System.IO.Path]::GetFileName($docbookFile)) $(Resolve-Path $protocolFile -Relative)
            if (-not $?) { exit 1 }
        }
    }
    if ($Format -eq 'all' -or $Format -eq 'pdf') {
        if ($targetCulture.TextInfo.IsRightToLeft) {
            # ToDo: Build pdf via the DocBook toolchain
        } else {
            $att = $attributes.Clone()
            $att['backend-pdf'] = $true
            $outputFile = Get-LocalisedPath $artifactsFolder 'NeoIPC-Core-Protocol.pdf' $targetCulture
            Build-Target $outputFile (@($protocolFile)+@(Export-AsciiDocReferences $protocolFile $att)) {
                Write-Information "Generating PDF"
                if ($IsWindows) {
                    Write-Warning "Asciidoctor Mathematical is not supported on Windows. The STEM expressions will not be converted in your pdf output."
                    asciidoctor-pdf -a $revRemark -a $revDate -w --failure-level=WARN -D $(Resolve-Path $artifactsFolder -Relative) -o $([System.IO.Path]::GetFileName($outputFile)) $(Resolve-Path $protocolFile -Relative)
                } else {
                    asciidoctor-pdf -a $revRemark -a $revDate -a mathematical-format=svg -r asciidoctor-mathematical -w --failure-level=WARN -D $(Resolve-Path $artifactsFolder -Relative) -o $([System.IO.Path]::GetFileName($outputFile)) $(Resolve-Path $protocolFile -Relative)
                }
                if (-not $?) { exit 1 }
            }
        }
    }
    if ($Format -eq 'all' -or $Format -eq 'docx') {
        $outputFile = Get-LocalisedPath $artifactsFolder 'NeoIPC-Core-Protocol.docx' $targetCulture
        Build-Target $outputFile $docbookFile {
            Write-Information "Generating Open XML for Microsoft Word (docx)"
            pandoc --from=docbook --to=docx --toc --number-sections --reference-doc=$(Resolve-Path "$docDir/reference.docx" -Relative) --resource-path=$(Resolve-Path $protocolDir -Relative) --fail-if-warnings --output=$outputFile $(Resolve-Path $docbookFile -Relative)
            if (-not $?) { exit 1 }
        }
    }
}
