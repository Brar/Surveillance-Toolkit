[CmdletBinding()]
param(
    [ValidateSet('all', 'html', 'pdf', 'docx')]
    [string]$Format = 'all',
    [CultureInfo[]]$TargetCultures,
    [switch]$Release
    )

Import-Module -Name (Join-Path -Resolve -Path $PSScriptRoot -ChildPath 'modules' -AdditionalChildPath 'NeoIPC-Tools') -Force
function New-PathogenList {
    [OutputType([void])]
    param (
        [CultureInfo]$TargetCulture,
        [string]$InputDirectory,
        [string]$OutputDirectory
    )
    $listElements = [System.Collections.Generic.Dictionary[string, string]]::new()
    $neoipcConcepts = [System.Collections.Generic.Dictionary[uint, string]]::new()
    Import-Csv -LiteralPath (Join-Path -Path $InputDirectory -ChildPath 'NeoIPC-Owned-Pathogen-Concepts.csv') -Encoding utf8NoBOM | ForEach-Object {
        $neoipcConcepts.Add([uint]::Parse($_.id), ($_.pathogen_type + '_' + ($_.concept_type -creplace '\s', '_')))
    }
    $localizedlist = [System.Collections.ArrayList]::new()
    $c = $TargetCulture
    while ($c.Name.Length -gt 0) {
        $listElementsPath = Join-Path -Path $InputDirectory -ChildPath "ListElements.$($c.Name).csv"
        if ((Test-Path -LiteralPath $listElementsPath -PathType Leaf)) {
            $lineNo = 1
            Import-Csv -LiteralPath $listElementsPath -Encoding utf8NoBOM | ForEach-Object {
                $le = $_
                $lineNo++
                if ($le.property -cne 'VALUE') {
                    throw "Unknown property name '$($le.property)' in line $lineNo in file '$listElementsPath'."
                }
                $needs_translation = $le.needs_translation -ceq 't'
                if (-not $needs_translation) {
                    if ($le.needs_translation -ceq 'u') {
                        Write-Warning "Unverified translation value '$($le.translated)' in line $lineNo file '$listElementsPath'."
                        if ($le.translated.Length -gt 0) {
                            $needs_translation = $true
                        }
                    } elseif ($le.needs_translation -cne 'f') {
                        throw "Unexpected boolen value '$($le.needs_translation)' in line $lineNo file '$listElementsPath'."
                    }
                }

                if ($needs_translation -and (-not $listElements.ContainsKey($_.id))) {
                    $listElements.add($_.id, $_.translated)
                }
            }
        }
        $pcPath = Join-Path -Path $InputDirectory -ChildPath "NeoIPC-Pathogen-Concepts.$($c.Name).csv"
        $psPath = Join-Path -Path $InputDirectory -ChildPath "NeoIPC-Pathogen-Synonyms.$($c.Name).csv"

        if ((Test-Path -LiteralPath $pcPath -PathType Leaf)) {
            if (-not (Test-Path -LiteralPath $psPath -PathType Leaf)) {
                throw "Invalid state: If '$pcPath' exists, '$psPath' must exist too."
            }
            $pc = Import-Csv -LiteralPath $pcPath -Encoding utf8NoBOM
            $pcHash = [System.Collections.Generic.Dictionary[int, System.Collections.Hashtable]]::new()
            $lineNo = 1
            foreach ($p in $pc) {
                $lineNo++
                # Validate the input file
                if ($p.property -cne 'CONCEPT') {
                    throw "Unknown property name '$($p.property)' in line $lineNo in file '$pcPath'."
                }
                if ($p.default.Trim().Length -eq 0) {
                    throw "Missing default value in line $lineNo in file '$pcPath'."
                }
                if ($p.default.Trim() -cne $p.default) {
                    throw "Default value with superflous whitespace in line $lineNo in file '$pcPath'."
                }
                $needs_translation = $p.needs_translation -ceq 't'
                if (-not $needs_translation) {
                    if ($p.needs_translation -ceq 'u') {
                        Write-Warning "Unverified translation value '$($p.translated)' in line $lineNo file '$pcPath'."
                        if ($p.translated.Length -gt 0) {
                            $needs_translation = $true
                        }
                    } elseif ($p.needs_translation -cne 'f') {
                        throw "Unexpected boolen value '$($p.needs_translation)' in line $lineNo file '$pcPath'."
                    }
                }
                if ($needs_translation -and $p.translated.Trim().Length -eq 0) {
                    throw "Missing translation in line $lineNo file '$pcPath'."
                }
                if ($needs_translation -and $p.translated.Trim() -cne $p.translated) {
                    throw "Translation with superflous whitespace in line $lineNo in file '$pcPath'."
                }
                if ((-not $needs_translation) -and $p.translated.Length -ne 0) {
                    throw "Unexpected translation in line $lineNo file '$pcPath'."
                }
                $pcHash.Add($p.id, @{
                    needs_translation = $needs_translation
                    default = $p.default
                    translated = $p.translated
                })
            }

            $ps = Import-Csv -LiteralPath $psPath -Encoding utf8NoBOM
            $psHash = @{}
            $lineNo = 1
            foreach ($p in $ps) {
                $lineNo++
                # Validate the input file
                if ($p.property -cne 'SYNONYM') {
                    throw "Unknown property name '$($p.property)' in line $lineNo in file '$psPath'."
                }
                if ($p.default.Trim().Length -eq 0) {
                    throw "Missing default value in line $lineNo in file '$psPath'."
                }
                if ($p.default.Trim() -cne $p.default) {
                    throw "Default value with superflous whitespace in line $lineNo in file '$psPath'."
                }
                $needs_translation = $p.needs_translation -ceq 't'
                if (-not $needs_translation) {
                    if ($p.needs_translation -ceq 'u') {
                        Write-Warning "Unverified translation value '$($p.translated)' in line $lineNo file '$psPath'."
                        if ($p.translated.Length -gt 0) {
                            $needs_translation = $true
                        }
                    } elseif ($p.needs_translation -cne 'f') {
                        throw "Unexpected boolen value '$($p.needs_translation)' in line $lineNo file '$psPath'."
                    }
                }
                if ($needs_translation -and $p.translated.Trim().Length -eq 0) {
                    throw "Missing translation in line $lineNo file '$psPath'."
                }
                if ($needs_translation -and $p.translated.Trim() -cne $p.translated) {
                    throw "Translation with superflous whitespace in line $lineNo in file '$psPath'."
                }
                if ((-not $needs_translation) -and $p.translated.Length -ne 0) {
                    throw "Unexpected translation in line $lineNo file '$psPath'."
                }
                $psHash.Add($p.id, @{
                    needs_translation = $needs_translation
                    default = $p.default
                    translated = $p.translated
                })
            }
            $localizedlist.Add([System.ValueTuple]::Create($pcHash, $psHash)) > $null
        }
        elseif ((Test-Path -LiteralPath $psPath -PathType Leaf)) {
            throw "Invalid state: If '$psPath' exists, '$pcPath' must exist too."
        }
        $c = $TargetCulture.Parent
    }
    if ($TargetCulture.Name.Length -gt 0 -and $localizedlist.Count -eq 0) {
        Write-Warning "Could not find a pathogen translation file for '$($TargetCulture.Name)'. This will result in an untranslated pathogen list."
    }
    Import-Csv -LiteralPath (Join-Path -Path $InputDirectory -ChildPath 'ListElements.csv') -Encoding utf8NoBOM | ForEach-Object {
        if (-not $listElements.ContainsKey($_.id)) {
            $listElements.add($_.id, $_.value)
        }
    }

    $commonCommensal = ''
    if (-not $listElements.TryGetValue('common_commensal', [ref]$commonCommensal)) {
        throw "Lookup of string 'common_commensal' failed."
    }

    $recognisedPathogen = ''
    if (-not $listElements.TryGetValue('recognised_pathogen', [ref]$recognisedPathogen)) {
        throw "Lookup of string 'recognised_pathogen' failed."
    }

    $MRSA = ''
    if (-not $listElements.TryGetValue('mrsa', [ref]$MRSA)) {
        throw "Lookup of string 'mrsa' failed."
    }

    $VRE = ''
    if (-not $listElements.TryGetValue('vre', [ref]$VRE)) {
        throw "Lookup of string 'vre' failed."
    }

    $3GCR = ''
    if (-not $listElements.TryGetValue('3gcr', [ref]$3GCR)) {
        throw "Lookup of string '3gcr' failed."
    }

    $carbapenems = ''
    if (-not $listElements.TryGetValue('carbapenems', [ref]$carbapenems)) {
        throw "Lookup of string 'carbapenems' failed."
    }

    $colistin = ''
    if (-not $listElements.TryGetValue('colistin', [ref]$colistin)) {
        throw "Lookup of string 'colistin' failed."
    }


    $pcPath = Join-Path -Path $InputDirectory -ChildPath 'NeoIPC-Pathogen-Concepts.csv'
    $pc = Import-Csv -LiteralPath $pcPath -Encoding utf8NoBOM
    $pathogenList = [System.Collections.ArrayList]::new()
    $lineNo = 1
    foreach ($p in $pc) {
        $lineNo++
        # Validate the input file
        if ($p.concept.Trim().Length -eq 0) {
            throw "Missing concept value in line $lineNo in file '$pcPath'."
        }
        if ($p.concept.Trim() -cne $p.concept) {
            throw "Concept value with superflous whitespace in line $lineNo in file '$pcPath'."
        }
        if ($p.concept_type -cnotin 'clade','family','genus','group','serotype','species','species complex','subspecies','unknown','variety') {
            throw "Unknown concept type in line $lineNo in file '$pcPath'."
        }
        if ($p.concept_source -cnotin 'ICTV','LPSN','MycoBank','NeoIPC') {
            throw "Unknown concept source in line $lineNo in file '$pcPath'."
        }

        $type = ''
        switch -casesensitive ($p.concept_source) {
            'LPSN' {
                $typeString = 'bacterial_' + $p.concept_type -creplace '\s', '_'
                if (-not $listElements.TryGetValue($typeString, [ref]$type)) {
                    throw "Lookup of type string '$typeString' failed in line $lineNo in file '$pcPath'."
                }
                $type = "https://lpsn.dsmz.de/$($p.concept_id)[$type,window=_blank]"
            }
            'MycoBank' {
                $typeString = 'fungal_' + $p.concept_type -creplace '\s', '_'
                if (-not $listElements.TryGetValue($typeString, [ref]$type)) {
                    throw "Lookup of type string '$typeString' failed in line $lineNo in file '$pcPath'."
                }
                $type = "https://www.mycobank.org/page/Name%20details%20page/field/Mycobank%20%23/$($p.concept_id)[$type,window=_blank]"
            }
            'ICTV' {
                $typeString = 'viral_' + $p.concept_type -creplace '\s', '_'
                if (-not $listElements.TryGetValue($typeString, [ref]$type)) {
                    throw "Lookup of type string '$typeString' failed in line $lineNo in file '$pcPath'."
                }
                $type = "https://ictv.global/taxonomy/taxondetails?taxnode_id=$($p.concept_id)[$type,window=_blank]"
            }
            'NeoIPC' {
                $typeString = ''
                if ($p.concept_type -ceq 'unknown') {
                    if (-not $listElements.TryGetValue('unknown', [ref]$type)) {
                        throw "Lookup of type string 'unknown' failed in line $lineNo in file '$pcPath'."
                    }
                }
                else {
                    if (-not $neoipcConcepts.TryGetValue([uint]::Parse($p.concept_id), [ref]$typeString)) {
                        throw "Lookup of NeoIPC pathogen with concept_id $($p.concept_id) failed in line $lineNo in file '$pcPath'."
                    }
                    if (-not $listElements.TryGetValue($typeString, [ref]$type)) {
                        throw "Lookup of type string '$typeString' failed in line $lineNo in file '$pcPath'."
                    }
                }
            }
            default { throw "Lookup of type string failed in line $lineNo in file '$pcPath'." }
        }

        $pathogenName = $p.concept
        foreach ($l in $localizedlist) {
            $lpc = @{}
            if ($l.Item1.TryGetValue($p.id, [ref]$lpc)) {
                if ($p.concept -cne $lpc.default) {
                    throw "Default value '$($lpc.default)' in translation file differs from concept '$($p.concept)' for pathogen with id '$($p.id)'."
                }
                if ($lpc.needs_translation) {
                    $pathogenName = $lpc.translated
                }
                break
            }
        }

        if ($p.is_cc -ceq 't') {
            $pathogenicity = $commonCommensal
        } elseif ($p.is_cc -ceq 'f') {
            $pathogenicity = $recognisedPathogen
        }  else {
            throw "Unexpected boolen value '$($p.is_cc)' in line $lineNo file '$pcPath'."
        }

        $resistanceString = [System.Text.StringBuilder]::new()
        if ($p.show_mrsa -ceq 't') {
            $resistanceString.Append($MRSA).Append(', ') > $null
        } elseif (-not($p.show_mrsa -ceq 'f')) {
            throw "Unexpected boolen value '$($p.show_mrsa)' in line $lineNo file '$pcPath'."
        }
        if ($p.show_vre -ceq 't') {
            $resistanceString.Append($VRE).Append(', ') > $null
        } elseif (-not($p.show_vre -ceq 'f')) {
            throw "Unexpected boolen value '$($p.show_vre)' in line $lineNo file '$pcPath'."
        }
        if ($p.show_3gcr -ceq 't') {
            $resistanceString.Append($3GCR).Append(', ') > $null
        } elseif (-not($p.show_3gcr -ceq 'f')) {
            throw "Unexpected boolen value '$($p.show_3gcr)' in line $lineNo file '$pcPath'."
        }
        if ($p.show_carb_r -ceq 't') {
            $resistanceString.Append($carbapenems).Append(', ') > $null
        } elseif (-not($p.show_carb_r -ceq 'f')) {
            throw "Unexpected boolen value '$($p.show_carb_r)' in line $lineNo file '$pcPath'."
        }
        if ($p.show_coli_r -ceq 't') {
            $resistanceString.Append($colistin).Append(', ') > $null
        } elseif (-not($p.show_coli_r -ceq 'f')) {
            throw "Unexpected boolen value '$($p.show_coli_r)' in line $lineNo file '$pcPath'."
        }
        if ($resistanceString.Length -gt 0) {
            $resistanceString.Length -= 2
        }

        $pathogenList.Add(@(
            "[[pathogen-concept-$($p.id)]]$pathogenName"
            $type
            $pathogenicity
            $resistanceString.ToString()
        )) > $null
    }

    #$ps = Import-Csv -LiteralPath (Join-Path -Path $InputDirectory -ChildPath 'NeoIPC-Pathogen-Synonyms.csv') -Encoding utf8NoBOM

    if ($TargetCulture.Name.Length -gt 0) {
        $outfile = Join-Path -Path $OutputDirectory -ChildPath "NeoIPC-Pathogens.$TargetCulture.adoc"
    }
    else {
        $outfile = Join-Path -Path $OutputDirectory -ChildPath "NeoIPC-Pathogens.adoc"
    }
    $pathogenList |
    Sort-Object -Property {$_[0] -creplace '^\[\[pathogen-concept-\d+\]\](.+)$','$1'} -Culture $TargetCulture.Name |
    ForEach-Object { $_ | Join-String -OutputPrefix '|' -Separator ' |' } |
    Out-File -LiteralPath $outfile -Encoding utf8NoBOM

}

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
                    Write-Warning "Asciidoctor Mathematical is not supported on Windows. The STEM expressions will not be converted."
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
