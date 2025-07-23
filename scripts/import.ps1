[CmdletBinding()]
param(
    #[string]$BaseDirectory = 'https://raw.githubusercontent.com/Brar/Surveillance-Toolkit/refs/heads/ReferenceReport/metadata/common/pathogens/',
    [string]$BaseDirectory = (Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'metadata','common','pathogens') -Relative),
    [string]$OutputDirectory = (Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'artifacts') -Relative),
    [string[]]$OutputLanguages = @('de', 'es', 'fr', 'gr', 'it'),
    [string[]]$OutputFormats = @('csv', 'adoc', 'md', 'pdf', 'docx')
)

Import-Module powershell-yaml

$uri = $null
if ([Uri]::TryCreate($BaseDirectory, [System.UriKind]::Absolute, [ref]$uri)) {
    $infectiousAgentData = Invoke-WebRequest -Uri ([Uri]::new($uri, 'NeoIPC-Pathogen-Concepts.csv').AbsoluteUri) | ConvertFrom-Csv
    $synonymData = Invoke-WebRequest -Uri ([Uri]::new($uri, 'NeoIPC-Pathogen-Synonyms.csv').AbsoluteUri) | ConvertFrom-Csv
} else {
    $infectiousAgentData = Import-Csv -Path (Join-Path -Path $BaseDirectory -ChildPath 'NeoIPC-Pathogen-Concepts.csv')
    $synonymData = Import-Csv -Path (Join-Path -Path $BaseDirectory -ChildPath 'NeoIPC-Pathogen-Synonyms.csv')
}

$mycobankToken = Invoke-RestMethod `
    -Uri https://webservices.bio-aware.com/cbsdatabase_new/connect/token `
    -Method Post `
    -Headers @{
        'Referer' = 'https://webservices.bio-aware.com/cbsdatabase_new/mycobank'
        'Content-Type' = 'application/x-www-form-urlencoded'
        'Authorization' = 'Basic Q0JTOg=='
        'Origin' = 'https://webservices.bio-aware.com'
    } `
    -Body "client_id=CBS&scope=mycobank&grant_type=password&username=$([System.Web.HttpUtility]::UrlEncode((Read-Host 'Enter Mycobank username')))&password=$([System.Web.HttpUtility]::UrlEncode((Read-Host 'Enter Mycobank password' -MaskInput)))" |
    Select-Object -ExpandProperty access_token

$lpsnRaw = Get-Content -LiteralPath ./metadata/common/pathogens/LPSN_data.json -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable -Depth 100

$ById = [System.Collections.Generic.Dictionary[int,[System.Collections.Generic.OrderedDictionary[string,string]]]]::new()
$ByName = [System.Collections.Generic.Dictionary[string,[System.Collections.Generic.OrderedDictionary[string,string]]]]::new()
$ByLpsnConceptId = [System.Collections.Generic.Dictionary[string,[System.Collections.Generic.OrderedDictionary[string,string]]]]::new()
$lpsnDataByConceptId = [System.Collections.Generic.Dictionary[string,System.Management.Automation.OrderedHashtable]]::new()
$lpsnDataByRecordNumber = [System.Collections.Generic.Dictionary[Int64,System.Management.Automation.OrderedHashtable]]::new()
foreach ($row in $lpsnRaw.Values) {
    $concept_id = $row.lpsn_address.Substring(21)
    $lpsnDataByConceptId[$concept_id] = $row
    $lpsn_record_number = $row.id
    $lpsnDataByRecordNumber[$lpsn_record_number] = $row
}
Remove-Variable -Name lpsnRaw

#$ictvRaw = Import-Csv ./metadata/common/pathogens/ICTV_Master_Species_List_2024_MSL40.v1.csv -UseCulture
$ByIctvConceptId = [System.Collections.Generic.Dictionary[string,[System.Collections.Generic.OrderedDictionary[string,string]]]]::new()
$ictvDataByName = [System.Collections.Generic.Dictionary[string,PSCustomObject]]::new()
$ictvDataByTaxNodeId = [System.Collections.Generic.Dictionary[int,PSCustomObject]]::new()
$ictvDataByIctvId = [System.Collections.Generic.Dictionary[int,PSCustomObject]]::new()
Import-Csv C:/Users/Brar/dev/NeoIPC/ICTVdatabase/data/taxonomy_node_export.utf8.txt -Delimiter "`t" -Encoding utf8 | ForEach-Object {
    $inputRow = $_
    $row = [ordered]@{}
    foreach ($old in @($inputRow.psobject.properties)) {
        switch -Exact -CaseSensitive ($old.Name) {
            taxnode_id {
                $row[$old.Name] = [int]$old.Value
                break
            }
            parent_id {
                $row[$old.Name] = [int]$old.Value
                break
            }
            tree_id {
                $row[$old.Name] = [int]$old.Value
                break
            }
            msl_release_num {
                $row[$old.Name] = [int]$old.Value
                break
            }
            level_id {
                $row[$old.Name] = [int]$old.Value
                break
            }
            name {
                $row[$old.Name] = $old.Value
                break
            }
            ictv_id {
                $row[$old.Name] = [int]$old.Value
                break
            }
            molecule_id {
                if ($old.Value -eq 'NULL') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = [int]$old.Value
                }
                break
            }
            abbrev_csv {
                if ($old.Value -eq 'NULL' -or $old.Value -eq '') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = $old.Value
                }
                break
            }
            genbank_accession_csv {
                if ($old.Value -eq 'NULL' -or $old.Value -eq '') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = $old.Value
                }
                break
            }
            genbank_refseq_accession_csv {
                if ($old.Value -eq 'NULL' -or $old.Value -eq '') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = $old.Value
                }
                break
            }
            refseq_accession_csv {
                if ($old.Value -eq 'NULL' -or $old.Value -eq '') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = $old.Value
                }
                break
            }
            isolate_csv {
                if ($old.Value -eq 'NULL' -or $old.Value -eq '') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = $old.Value
                }
                break
            }
            notes {
                if ($old.Value -eq 'NULL' -or $old.Value -eq '') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = $old.Value
                }
                break
            }
            is_ref {
                if ($old.Value -eq '0') {
                    $row[$old.Name] = $false
                } elseif ($old.Value -eq '1') {
                    $row[$old.Name] = $true
                } else {
                    Write-Error "Invalid bool value '$($old.Value)' in column $_."
                }
                break
            }
            is_official {
                if ($old.Value -eq '0') {
                    $row[$old.Name] = $false
                } elseif ($old.Value -eq '1') {
                    $row[$old.Name] = $true
                } else {
                    Write-Error "Invalid bool value '$($old.Value)' in column $_."
                }
                break
            }
            is_hidden {
                if ($old.Value -eq '0') {
                    $row[$old.Name] = $false
                } elseif ($old.Value -eq '1') {
                    $row[$old.Name] = $true
                } else {
                    Write-Error "Invalid bool value '$($old.Value)' in column $_."
                }
                break
            }
            is_deleted {
                if ($old.Value -eq '0') {
                    $row[$old.Name] = $false
                } elseif ($old.Value -eq '1') {
                    $row[$old.Name] = $true
                } else {
                    Write-Error "Invalid bool value '$($old.Value)' in column $_."
                }
                break
            }
            is_deleted_next_year {
                if ($old.Value -eq '0') {
                    $row[$old.Name] = $false
                } elseif ($old.Value -eq '1') {
                    $row[$old.Name] = $true
                } else {
                    Write-Error "Invalid bool value '$($old.Value)' in column $_."
                }
                break
            }
            is_typo {
                if ($old.Value -eq '0') {
                    $row[$old.Name] = $false
                } elseif ($old.Value -eq '1') {
                    $row[$old.Name] = $true
                } else {
                    Write-Error "Invalid bool value '$($old.Value)' in column $_."
                }
                break
            }
            is_renamed_next_year {
                if ($old.Value -eq '0') {
                    $row[$old.Name] = $false
                } elseif ($old.Value -eq '1') {
                    $row[$old.Name] = $true
                } else {
                    Write-Error "Invalid bool value '$($old.Value)' in column $_."
                }
                break
            }
            is_obsolete {
                if ($old.Value -eq '0') {
                    $row[$old.Name] = $false
                } elseif ($old.Value -eq '1') {
                    $row[$old.Name] = $true
                } else {
                    Write-Error "Invalid bool value '$($old.Value)' in column $_."
                }
                break
            }
            in_change {
                if ($old.Value -eq 'NULL' -or $old.Value -eq '') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = $old.Value
                }
                break
            }
            in_target {
                if ($old.Value -eq 'NULL' -or $old.Value -eq '') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = $old.Value
                }
                break
            }
            in_filename {
                if ($old.Value -eq 'NULL' -or $old.Value -eq '') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = $old.Value
                }
                break
            }
            in_notes {
                if ($old.Value -eq 'NULL' -or $old.Value -eq '') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = $old.Value
                }
                break
            }
            out_change {
                if ($old.Value -eq 'NULL' -or $old.Value -eq '') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = $old.Value
                }
                break
            }
            out_target {
                if ($old.Value -eq 'NULL' -or $old.Value -eq '') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = $old.Value
                }
                break
            }
            out_filename {
                if ($old.Value -eq 'NULL' -or $old.Value -eq '') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = $old.Value
                }
                break
            }
            out_notes {
                if ($old.Value -eq 'NULL' -or $old.Value -eq '') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = $old.Value
                }
                break
            }
            lineage {
                if ($old.Value -eq 'NULL' -or $old.Value -eq '') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = $old.Value
                }
                break
            }
            cleaned_name {
                if ($old.Value -eq 'NULL' -or $old.Value -eq '') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = $old.Value
                }
                break
            }
            rank {
                if ($old.Value -eq 'NULL' -or $old.Value -eq '') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = $old.Value
                }
                break
            }
            molecule {
                if ($old.Value -eq 'NULL' -or $old.Value -eq '') {
                    $row[$old.Name] = $null
                } else {
                    $row[$old.Name] = $old.Value
                }
                break
            }
            Default {
                Write-Error "Unexpected column name $_."
                break
            }
        }
    }

    $ictvDataByTaxNodeId[$row.taxnode_id] = $row
    # The names contain duplicates but the list is ordered from old taxons to new ones
    # so we'll automatically keep the newest entry for a name
    $ictvDataByName[$row.name] = $row
    # The ictv_ids contain duplicates but the list is ordered from old taxons to new ones
    # so we'll automatically keep the newest entry for a ictv_id
    $ictvDataByIctvId[$row.ictv_id] = $row
}

$ictvLevels = [System.Collections.Generic.Dictionary[int,PSCustomObject]]::new()
Import-Csv C:/Users/Brar/dev/NeoIPC/ICTVdatabase/data/taxonomy_level.utf8.txt -Delimiter "`t" -Encoding utf8 | ForEach-Object {
    $row = $_
    $id = [int]$_.id
    $ictvLevels[$id] = $row
}

$mycoBankDataById = Get-Content -LiteralPath ./metadata/common/pathogens/MycoBank_data.json -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable -Depth 100
$mycoBankDataByMycoBankNumber = [System.Collections.Generic.Dictionary[Int64,PSCustomObject]]::new()
foreach ($row in $mycoBankDataById.Values) {
    $concept_id = $row.mycobankNr
    $mycoBankDataByMycoBankNumber[$concept_id] = [PSCustomObject]$row
}

Class ConceptComparer:System.Collections.Generic.IComparer[System.Collections.Specialized.OrderedDictionary] {
    [int]Compare([System.Collections.Specialized.OrderedDictionary]$x, [System.Collections.Specialized.OrderedDictionary]$y) {
        if (
            $x.Name -in @('Alphaproteobacteria','Betaproteobacteria','Gammaproteobacteria','Deltaproteobacteria','Epsilonproteobacteria') `
            -and `
            $y.Name -in @('Alphaproteobacteria','Betaproteobacteria','Gammaproteobacteria','Deltaproteobacteria','Epsilonproteobacteria'))
        {
            [int]$x1 = switch -Exact -CaseSensitive ($x.Name[0]) {A{0;break}B{1;break}G{2;break}D{3;break}E{4;break}}
            [int]$y1 = switch -Exact -CaseSensitive ($y.Name[0]) {A{0;break}B{1;break}G{2;break}D{3;break}E{4;break}}
            return [System.Collections.Generic.Comparer[int]]::Default.Compare($x1, $y1)
        } elseif (
            $x.Name -in @('Alphainfluenzavirus','Betainfluenzavirus','Gammainfluenzavirus','Deltainfluenzavirus') `
            -and `
            $y.Name -in @('Alphainfluenzavirus','Betainfluenzavirus','Gammainfluenzavirus','Deltainfluenzavirus'))
        {
            [int]$x1 = switch -Exact -CaseSensitive ($x.Name[0]) {A{0;break}B{1;break}G{2;break}D{3;break}}
            [int]$y1 = switch -Exact -CaseSensitive ($y.Name[0]) {A{0;break}B{1;break}G{2;break}D{3;break}}
            return [System.Collections.Generic.Comparer[int]]::Default.Compare($x1, $y1)
        } elseif ($x.Name.EndsWith('streptococci') -or $y.Name.EndsWith('streptococci')) {
            $x1 = $x.Name.EndsWith('streptococci')
            $y1 = $y.Name.EndsWith('streptococci')
            $x2 = $x.Name.StartsWith('Viridans')
            $y2 = $y.Name.StartsWith('Viridans')
            if ($x1 -and $y1) {
                if ($x2) {
                     return 1
                } elseif ($y2) {
                    return -1
                } else {
                    return [System.Collections.Generic.Comparer[string]]::Default.Compare($x.Name, $y.Name)
                }
            } elseif ($x1) {
                return -1
            } else {
                return 1
            }
        } elseif ($x.Name.EndsWith('group') -or $x.Name.EndsWith('complex') -or $y.Name.EndsWith('group') -or $y.Name.EndsWith('complex')) {
            $x1 = $x.Name.EndsWith('group') -or $x.Name.EndsWith('complex')
            $y1 = $y.Name.EndsWith('group') -or $y.Name.EndsWith('complex')
            if ($x1 -and $y1) {
                return [System.Collections.Generic.Comparer[string]]::Default.Compare($x.Name, $y.Name)
            } elseif ($x1) {
                return -1
            } else {
                return 1
            }
        } elseif (($x.Contains('ConceptType') -and $x.ConceptType -eq 'Group') -or ($y.Contains('ConceptType') -and $y.ConceptType -eq 'Group')) {
            $x1 = $x.Contains('ConceptType') -and $x.ConceptType -eq 'Group'
            $y1 = $y.Contains('ConceptType') -and $y.ConceptType -eq 'Group'
            if ($x1 -and $y1) {
                return [System.Collections.Generic.Comparer[string]]::Default.Compare($x.Name, $y.Name)
            } elseif ($x1) {
                return -1
            } else {
                return 1
            }
        }
        return [System.Collections.Generic.Comparer[string]]::Default.Compare($x.Name, $y.Name)
    }
}
[ConceptComparer]$myConceptComparer=[ConceptComparer]::new()

$cacheById = [System.Collections.Generic.Dictionary[int,ordered]]::new()
$downgraded = [System.Collections.Generic.Dictionary[int,int]]::new()
$childrenToAdd = [System.Collections.Generic.Dictionary[ordered,int]]::new()

$bacteria = [ordered]@{
    Name = 'Bacteria'
    ConceptType = 'Domain'
    ConceptId = 'domain/bacteria'
    ConceptSource = 'LPSN'
    LpsnRecordNumber = 43123
    Children = [System.Collections.Generic.SortedSet[ordered]]::new($myConceptComparer)
}

$viruses = [ordered]@{
    Name = 'Viruses'
    Children = [System.Collections.Generic.SortedSet[ordered]]::new($myConceptComparer)
}
$fungi = [ordered]@{
    Name = 'Fungi'
    ConceptType = 'Kingdom'
    Children = [System.Collections.Generic.SortedSet[ordered]]::new($myConceptComparer)
}

$data = [ordered]@{
    UrlTemplates = [ordered]@{
        ICTV = 'https://ictv.global/taxonomy/taxondetails?taxnode_id={0}'
        LPSN = 'https://lpsn.dsmz.de/{0}'
        MycoBank = 'http://www.mycobank.org/page/Name%20details%20page/field/Mycobank%20%23/{0}'
        NeoIPC = 'TODO: Create URIs for NeoIPC-owned pathogen concepts'
    }
    Hierarchies = @(
        [ordered]@{
            Name = 'Not listed'
            ConceptType = 'Unknown'
            ConceptId = 1
            ConceptSource = 'NeoIPC'
            Id = 0
            MRSA = $true
            VRE = $true
            '3GCR' = $true
            Carbapenems = $true
            Colistin = $true
        }
        $bacteria
        $fungi
        $viruses
    )
}
        if ($inputData.is_cc -eq 't') {
            $output.CommonCommensal = $true
        }
        if ($inputData.show_mrsa -eq 't') {
            $output.MRSA = $true
        }
        if ($inputData.show_vre -eq 't') {
            $output.VRE = $true
        }
        if ($inputData.show_3gcr -eq 't') {
            $output['3GCR'] = $true
        }
        if ($inputData.show_carb_r -eq 't') {
            $output.Carbapenems = $true
        }
        if ($inputData.show_coli_r -eq 't') {
            $output.Colistin = $true
        }

$coNS = [ordered]@{
    Name = 'Coagulase-negative staphylococci'
    ConceptType = 'Group'
    ConceptId = 63
    ConceptSource = 'NeoIPC'
    Id = 2776
}
$coPS = [ordered]@{
    Name = 'Coagulase-positive staphylococci'
    ConceptType = 'Group'
    ConceptId = 64
    ConceptSource = 'NeoIPC'
    Id = 2777
}

# "`n$(((Import-Csv -LiteralPath .\metadata\common\pathogens\NeoIPC-Pathogen-Concepts.csv | select id) + (Import-Csv -LiteralPath .\metadata\common\pathogens\NeoIPC-Pathogen-Synonyms.csv | select id) | %{[int]$_.id} | sort | select -Last 1) + 1)"
# "`n$(((Import-Csv -LiteralPath .\metadata\common\pathogens\NeoIPC-Pathogen-Concepts.csv | Where-Object concept_source -EQ 'NeoIPC' | Select-Object concept_id) + (Import-Csv -LiteralPath .\metadata\common\pathogens\NeoIPC-Pathogen-Synonyms.csv | Where-Object concept_source -EQ 'NeoIPC' | Select-Object concept_id) | %{[int]$_.concept_id} | sort | select -Last 1) + 1)"

$coVS = [ordered]@{
    Name = 'Coagulase-variable staphylococci'
    ConceptType = 'Group'
    ConceptId = 86
    ConceptSource = 'NeoIPC'
}
$aBCC = [ordered]@{
    Name = 'Acinetobacter calcoaceticus-Acinetobacter baumannii complex'
    ConceptType = 'Group'
    ConceptId = 31
    ConceptSource = 'NeoIPC'
    Id = 2704
    Carbapenems = $true
    Colistin = $true
}
$vScc = [ordered]@{
    Name = 'Viridans streptococci'
    ConceptType = 'Group'
    ConceptId = 68
    ConceptSource = 'NeoIPC'
    Id = 2798
    Children = [System.Collections.Generic.SortedSet[ordered]]::new($myConceptComparer)
}
$sAg = [ordered]@{
    Name = 'Streptococcus anginosus group'
    ConceptType = 'Group'
    ConceptId = 69
    ConceptSource = 'NeoIPC'
    Id = 2799
}
$sBg = [ordered]@{
    Name = 'Streptococcus bovis group'
    ConceptType = 'Group'
    ConceptId = 71
    ConceptSource = 'NeoIPC'
    Id = 2801
}
$sMig = [ordered]@{
    Name = 'Streptococcus mitis group'
    ConceptType = 'Group'
    ConceptId = 72
    ConceptSource = 'NeoIPC'
    Id = 2802
}
$sMug = [ordered]@{
    Name = 'Streptococcus mutans group'
    ConceptType = 'Group'
    ConceptId = 73
    ConceptSource = 'NeoIPC'
    Id = 2803
}
$sSalg = [ordered]@{
    Name = 'Streptococcus salivarius group'
    ConceptType = 'Group'
    ConceptId = 74
    ConceptSource = 'NeoIPC'
    Id = 2804
}
$sSangg = [ordered]@{
    Name = 'Streptococcus sanguinis group'
    ConceptType = 'Group'
    ConceptId = 75
    ConceptSource = 'NeoIPC'
    Id = 2805
}

$vScc.Children.Add($sAg) | Out-Null
$vScc.Children.Add($sBg) | Out-Null
$vScc.Children.Add($sMig) | Out-Null
$vScc.Children.Add($sMug) | Out-Null
$vScc.Children.Add($sSalg) | Out-Null
$vScc.Children.Add($sSangg) | Out-Null
$cacheById.Add(2799, $sAg) | Out-Null
$cacheById.Add(2801, $sBg) | Out-Null
$cacheById.Add(2802, $sMig) | Out-Null
$cacheById.Add(2803, $sMug) | Out-Null
$cacheById.Add(2804, $sSalg) | Out-Null
$cacheById.Add(2805, $sSangg) | Out-Null

$bCg = [ordered]@{
    Name = 'Bacillus cereus group'
    ConceptType = 'Group'
    ConceptId = 76
    ConceptSource = 'NeoIPC'
    Id = 2935
}

$bSg = [ordered]@{
    Name = 'Bacillus subtilis group'
    ConceptType = 'Group'
    ConceptId = 77
    ConceptSource = 'NeoIPC'
    Id = 2938
}

$bFg = [ordered]@{
    Name = 'Bacteroides fragilis group'
    ConceptType = 'Group'
    ConceptId = 78
    ConceptSource = 'NeoIPC'
    Id = 2939
}

$bCc = [ordered]@{
    Name = 'Burkholderia cepacia complex'
    ConceptType = 'Group'
    ConceptId = 79
    ConceptSource = 'NeoIPC'
    Id = 2940
}

$eCc = [ordered]@{
    Name = 'Enterobacter cloacae complex'
    ConceptType = 'Group'
    ConceptId = 32
    ConceptSource = 'NeoIPC'
    Id = 2711
}

$mAc = [ordered]@{
    Name = 'Mycobacterium avium complex'
    ConceptType = 'Group'
    ConceptId = 2
    ConceptSource = 'NeoIPC'
    Id = 2599
}

$mFc = [ordered]@{
    Name = 'Mycobacterium fortuitum complex'
    ConceptType = 'Group'
    ConceptId = 80
    ConceptSource = 'NeoIPC'
    Id = 2951
}

$mTec = [ordered]@{
    Name = 'Mycobacterium terrae complex'
    ConceptType = 'Group'
    ConceptId = 81
    ConceptSource = 'NeoIPC'
    Id = 2952
}

$mTuc = [ordered]@{
    Name = 'Mycobacterium tuberculosis complex'
    ConceptType = 'Group'
    ConceptId = 82
    ConceptSource = 'NeoIPC'
    Id = 2953
}

$nAc = [ordered]@{
    Name = 'Nocardia asteroides complex'
    ConceptType = 'Group'
    ConceptId = 83
    ConceptSource = 'NeoIPC'
    Id = 2954
}

$pOg = [ordered]@{
    Name = 'Prevotella oralis group'
    ConceptType = 'Group'
    ConceptId = 84
    ConceptSource = 'NeoIPC'
    Id = 2956
}

$pV = [ordered]@{
    Name = 'Poliovirus'
    ConceptType = 'Serotype'
    ConceptId = 87
    ConceptSource = 'NeoIPC'
    Id = 2635
}

$pV1 = [ordered]@{
    Name = 'Poliovirus 1'
    ConceptType = 'Serotype'
    ConceptId = 88
    ConceptSource = 'NeoIPC'
    Id = 2637
}


$pV2 = [ordered]@{
    Name = 'Poliovirus 2'
    ConceptType = 'Serotype'
    ConceptId = 89
    ConceptSource = 'NeoIPC'
    Id = 2638
}

$pV3 = [ordered]@{
    Name = 'Poliovirus 3'
    ConceptType = 'Serotype'
    ConceptId = 90
    ConceptSource = 'NeoIPC'
    Id = 2639
}

$eV = [ordered]@{
    Name = 'Echovirus'
    ConceptType = 'Group'
    ConceptId = 27
    ConceptSource = 'NeoIPC'
    Id = 2681
}

$hCov = [ordered]@{
    Name = 'Human coronavirus'
    ConceptId = 7
    ConceptSource = 'NeoIPC'
    Id = 2609
}

$hAv = [ordered]@{
    Name = 'Human adenovirus'
    ConceptType = 'Group'
    ConceptId = 28
    ConceptSource = 'NeoIPC'
    Id = 2692
}

$hBv = [ordered]@{
    Name = 'Human bocavirus'
    ConceptType = 'Group'
    ConceptId = 16
    ConceptSource = 'NeoIPC'
    Id = 2626
}

$hCoxV = [ordered]@{
    Name = 'Human coxsackievirus'
    ConceptType = 'Group'
    ConceptId = 13
    ConceptSource = 'NeoIPC'
    Id = 2623
}

$hCoxVA = [ordered]@{
    Name = 'Human coxsackievirus A'
    ConceptType = 'Group'
    ConceptId = 14
    ConceptSource = 'NeoIPC'
    Id = 2624
}

$hCoxVB = [ordered]@{
    Name = 'Human coxsackievirus B'
    ConceptType = 'Group'
    ConceptId = 15
    ConceptSource = 'NeoIPC'
    Id = 2625
}

$hHsV = [ordered]@{
    Name = 'Human herpes simplex virus'
    ConceptType = 'Group'
    ConceptId = 12
    ConceptSource = 'NeoIPC'
    Id = 2621
}

$hHV6 = [ordered]@{
    Name = 'Human herpesvirus 6'
    ConceptType = 'Group'
    ConceptId = 24
    ConceptSource = 'NeoIPC'
    Id = 2674
}

$hIV = [ordered]@{
    Name = 'Human immunodeficiency virus'
    ConceptType = 'Group'
    ConceptId = 19
    ConceptSource = 'NeoIPC'
    Id = 2634
}

$hInflV = [ordered]@{
    Name = 'Influenza virus'
    ConceptType = 'Group'
    ConceptId = 22
    ConceptSource = 'NeoIPC'
    Id = 2659
}

# Severe acute respiratory syndrome coronavirus 2
# SARS-CoV-2

# Acremonium alabamensis
# Candida parapsilosis complex

$lpsnCacheByRecordNumber = [System.Collections.Generic.Dictionary[Int64,ordered]]::new()
$lpsnCacheByRecordNumber[[Int64]43123] = $bacteria
$ictvCacheByTaxNodeId = [System.Collections.Generic.Dictionary[int,ordered]]::new()
$ictvCacheByTaxNodeId[[int]19710000] = $viruses
$ictvCacheByTaxNodeId[[int]19740000] = $viruses
$ictvCacheByTaxNodeId[[int]19750000] = $viruses
$ictvCacheByTaxNodeId[[int]19760000] = $viruses
$ictvCacheByTaxNodeId[[int]19780000] = $viruses
$ictvCacheByTaxNodeId[[int]19790000] = $viruses
$ictvCacheByTaxNodeId[[int]19810000] = $viruses
$ictvCacheByTaxNodeId[[int]19820000] = $viruses
$ictvCacheByTaxNodeId[[int]19840000] = $viruses
$ictvCacheByTaxNodeId[[int]19870000] = $viruses
$ictvCacheByTaxNodeId[[int]19900000] = $viruses
$ictvCacheByTaxNodeId[[int]19910000] = $viruses
$ictvCacheByTaxNodeId[[int]19930000] = $viruses
$ictvCacheByTaxNodeId[[int]19950000] = $viruses
$ictvCacheByTaxNodeId[[int]19960000] = $viruses
$ictvCacheByTaxNodeId[[int]19970000] = $viruses
$ictvCacheByTaxNodeId[[int]19980000] = $viruses
$ictvCacheByTaxNodeId[[int]19990000] = $viruses
$ictvCacheByTaxNodeId[[int]19995000] = $viruses
$ictvCacheByTaxNodeId[[int]20020000] = $viruses
$ictvCacheByTaxNodeId[[int]20025000] = $viruses
$ictvCacheByTaxNodeId[[int]20040000] = $viruses
$ictvCacheByTaxNodeId[[int]20070000] = $viruses
$ictvCacheByTaxNodeId[[int]20080000] = $viruses
$ictvCacheByTaxNodeId[[int]20090000] = $viruses
$ictvCacheByTaxNodeId[[int]20110000] = $viruses
$ictvCacheByTaxNodeId[[int]20120000] = $viruses
$ictvCacheByTaxNodeId[[int]20130000] = $viruses
$ictvCacheByTaxNodeId[[int]20140000] = $viruses
$ictvCacheByTaxNodeId[[int]20150000] = $viruses
$ictvCacheByTaxNodeId[[int]20160000] = $viruses
$ictvCacheByTaxNodeId[[int]20170000] = $viruses
$ictvCacheByTaxNodeId[[int]20180000] = $viruses
$ictvCacheByTaxNodeId[[int]201850000] = $viruses
$ictvCacheByTaxNodeId[[int]201900000] = $viruses
$ictvCacheByTaxNodeId[[int]202000000] = $viruses
$ictvCacheByTaxNodeId[[int]202100000] = $viruses
$ictvCacheByTaxNodeId[[int]202200000] = $viruses
$ictvCacheByTaxNodeId[[int]202300000] = $viruses
$ictvCacheByTaxNodeId[[int]202400000] = $viruses

function EnsureChildren {
    param ([System.Collections.Specialized.OrderedDictionary]$Object, [switch]$Synonyms)
    if ($Synonyms) {
        $objName = 'Synonyms'
    } else {
        $objName = 'Children'
    }
    if (-not $Object.Contains($objName)) {
        $Object[$objName] = [System.Collections.Generic.SortedSet[ordered]]::new($myConceptComparer)
    }
}

function Update-LpsnParent {
    param ($Parent, $LpsnRow, $InputData)

    # Insert Coagulase groups
    if ($LpsnRow.lpsn_parent_id -eq 516664) {
        if ($InputData.coagulase -eq 'p') { $Parent = $coPS }
        elseif ($InputData.coagulase -eq 'n') { $Parent = $coNS }
        elseif ($InputData.coagulase -eq 'v') { $Parent = $coVS }
        elseif ($InputData.concept -eq 'Staphylococcus fleurettii') { $Parent = $coNS }
        elseif ($InputData.concept -eq 'Staphylococcus lentus') { $Parent = $coNS }
        elseif ($InputData.concept -eq 'Staphylococcus sciuri') { $Parent = $coNS }
        elseif ($InputData.concept -eq 'Staphylococcus vitulinus') { $Parent = $coNS }
        else {
            Write-Error "Found a species that's a mamber of Staphylococcus which is neither coagulase positive nor coagulase negative."
        }
    }
    # Insert Acinetobacter calcoaceticus-Acinetobacter baumannii complex
    elseif ($LpsnRow.lpsn_parent_id -eq 515021 -and $LpsnRow.id -in @(772610,772613,789232,789231)) {
        $Parent = $aBCC
    }
    # Insert Viridans streptococci
    elseif ($LpsnRow.lpsn_parent_id -eq 517118) {
        # Streptococcus anginosus group
        if ($LpsnRow.id -in @(781299,784976,781351)) {
            $Parent = $sAg
        }
        # Streptococcus bovis group
        elseif ($LpsnRow.id -in @(781302,781328,781337,784982)) {
            $Parent = $sBg
        }
        # Streptococcus mitis group
        elseif ($LpsnRow.id -in @(781361,781364,781313,781372,781349,784991)) {
            $Parent = $sMig
        }
        # Streptococcus mutans group
        elseif ($LpsnRow.id -in @(781363,781387,781381,781348)) {
            $Parent = $sMug
        }
        # Streptococcus salivarius group
        elseif ($LpsnRow.id -in @(781383,781394,784982,781390)) {
            $Parent = $sSalg
        }
        # Streptococcus sanguinis group
        elseif ($LpsnRow.id -in @(781385,781368,781342)) {
            $Parent = $sSangg
        }
    }
    # Insert Bacillus groups
    elseif ($LpsnRow.lpsn_parent_id -eq 515217) {
        # Bacillus cereus
        if ($LpsnRow.id -in @(773670,773635,773869,773780,773813,790412,773911)) {
            $Parent = $bCg
        }
        # Bacillus subtilis group
        elseif ($LpsnRow.id -in @(773846,773632,773644,773903,773820,773776,783435)) {
            $Parent = $bSg
        }
    }
    # Insert Burkholderia cepacia complex
    elseif ($LpsnRow.lpsn_parent_id -eq 515281 -and $LpsnRow.id -in @(774277,774288,774276,774304,774312,774279,774269,774271,774298)) {
        $Parent = $bCc
    }
    # Insert Enterobacter cloacae complex
    elseif ($LpsnRow.lpsn_parent_id -eq 515587 -and $LpsnRow.id -in @(775931,775932,775933,775946,775948,783768,789537,793840)) {
        $Parent = $eCc
    }
    # Insert Mycobacterium complexes
    elseif ($LpsnRow.lpsn_parent_id -eq 516137) {
        # Mycobacterium avium complex
        if ($LpsnRow.id -in @(784303,778469,785698,778422,785392,788076,788198,788196,788197,784309)) {
            $Parent = $mAc
        }
        # Mycobacterium fortuitum complex
        elseif ($LpsnRow.id -in @(778444,778480,785474,778525,778504,778508,778524)) {
            $Parent = $mFc
        }
        # Mycobacterium terrae complex
        elseif ($LpsnRow.id -in @(778533,778495,786029,787251,790475,790509,778395,778461,789392,790508,794315,801065)) {
            $Parent = $mTec
        }
        # Mycobacterium tuberculosis complex
        elseif ($LpsnRow.id -in @(778540,784301,14335,784305,778485,7980,784307,784312,12053,801230)) {
            $Parent = $mTuc
        }
    }
    # Insert Nocardia asteroides complex
    elseif ($LpsnRow.lpsn_parent_id -eq 516182 -and $LpsnRow.id -in @(778689,778714,778677,778753,778720,778757)) {
        $Parent = $nAc
    }

    return $Parent
}

function Add-LpsnManualChildren {
    param ($Output, $LpsnRow, $InputData)

    # Insert Coagulase groups
    if ($Output.LpsnRecordNumber -eq 516664) {
        EnsureChildren $Output
        $Output.Children.Add($coPS) | Out-Null
        $Output.Children.Add($coVS) | Out-Null
        $Output.Children.Add($coNS) | Out-Null
    }
    # Insert Acinetobacter calcoaceticus-Acinetobacter baumannii complex
    elseif ($Output.LpsnRecordNumber -eq 515021) {
        EnsureChildren $Output
        $Output.Children.Add($aBCC) | Out-Null
    }
    # Insert Viridans streptococci
    elseif ($Output.LpsnRecordNumber -eq 517118) {
        EnsureChildren $Output
        $Output.Children.Add($vScc) | Out-Null
    }
    # Insert Bacillus groups
    elseif ($Output.LpsnRecordNumber -eq 515217) {
        EnsureChildren $Output
        $Output.Children.Add($bCg) | Out-Null
        $Output.Children.Add($bSg) | Out-Null
    }
    # Insert Bacteroides fragilis group
    # We need to put it under the Bacteroidales order since it contains members
    # from two genera of the Bacteroidaceae family (Bacteroides and Phocaeicola)
    # and members from one genus from the Tannerellaceae family (Parabacteroides)
    # see: https://doi.org/10.1128/jcm.02361-20
    elseif ($Output.LpsnRecordNumber -eq 517409) {
        EnsureChildren $Output
        $Output.Children.Add($bFg) | Out-Null
    }
    # Insert Burkholderia cepacia complex
    elseif ($Output.LpsnRecordNumber -eq 515281) {
        EnsureChildren $Output
        $Output.Children.Add($bCc) | Out-Null
    }
    # Insert Enterobacter cloacae complex
    elseif ($Output.LpsnRecordNumber -eq 515587) {
        EnsureChildren $Output
        $Output.Children.Add($eCc) | Out-Null
    }
    # Insert Mycobacterium complexes
    elseif ($Output.LpsnRecordNumber -eq 516137) {
        EnsureChildren $Output
        # Mycobacterium avium complex
        $Output.Children.Add($mAc) | Out-Null
        # Mycobacterium fortuitum complex
        $Output.Children.Add($mFc) | Out-Null
        # Mycobacterium terrae complex
        $Output.Children.Add($mTec) | Out-Null
        # Mycobacterium tuberculosis complex
        $Output.Children.Add($mTuc) | Out-Null
    }
    # Insert Nocardia asteroides complex
    elseif ($Output.LpsnRecordNumber -eq 516182) {
        EnsureChildren $Output
        $Output.Children.Add($nAc) | Out-Null
    }
    # Insert Prevotella oralis group
    elseif ($Output.LpsnRecordNumber -eq 516385) {
        EnsureChildren $Output
        $Output.Children.Add($pOg) | Out-Null
    }
}

function New-LpsnOutput
{
    param ($LpsnRow, $Parent, $InputData)
    $output = [ordered]@{}
    $output.Name = $LpsnRow.full_name
    $output.ConceptType = $LpsnRow.category.Substring(0,1).ToUpperInvariant() + $LpsnRow.category.Substring(1)
    $output.ConceptId = $concept_id
    $output.ConceptSource = 'LPSN'
    if ($InputData -and $InputData.id -and $inputData.concept_type -in @('serotype','subspecies','species','genus')) {
        $output.Id = [int]$inputData.id
    } elseif ($LpsnRow.ContainsKey('NewId')) {
        $output.Id = $LpsnRow.NewId
    }
    $output.LpsnRecordNumber = $LpsnRow.id
    if ($InputData) {
        if ($inputData.is_cc -eq 't') {
            $output.CommonCommensal = $true
        }
        if ($inputData.show_mrsa -eq 't') {
            $output.MRSA = $true
        }
        if ($inputData.show_vre -eq 't') {
            $output.VRE = $true
        }
        if ($inputData.show_3gcr -eq 't') {
            $output['3GCR'] = $true
        }
        if ($inputData.show_carb_r -eq 't') {
            $output.Carbapenems = $true
        }
        if ($inputData.show_coli_r -eq 't') {
            $output.Colistin = $true
        }
    }

    $Parent = Update-LpsnParent $Parent $LpsnRow $InputData
    if(-not $Parent.Contains('Children')) {
        EnsureChildren $Parent
        $Parent.Children.Add($output) | Out-Null
        $lpsnCacheByRecordNumber[$output.LpsnRecordNumber] = $output
        if ($output.Contains("Id")) {
            $cacheById[$output.Id] = $output
        }
    } elseif (-not $lpsnCacheByRecordNumber.ContainsKey($output.LpsnRecordNumber)) {
        $Parent.Children.Add($output) | Out-Null
        $lpsnCacheByRecordNumber[$output.LpsnRecordNumber] = $output
        if ($output.Contains("Id")) {
            $cacheById[$output.Id] = $output
        }
    }
    Write-Debug "Adding $($output.Name)"

    Add-LpsnManualChildren $output $LpsnRow $InputData | Out-Null
    return $output
}

function AddLpsnAgentRecursive {
    param ($LpsnRow)
    New-Variable -Name output
    if ($LpsnRow.ContainsKey('lpsn_parent_id') -and -not $lpsnCacheByRecordNumber.ContainsKey($LpsnRow.lpsn_parent_id)) {
        $p = AddLpsnAgentRecursive $lpsnDataByRecordNumber[$LpsnRow.lpsn_parent_id]
    } elseif ($lpsnCacheByRecordNumber.TryGetValue($LpsnRow.id, [ref]$output)) {
        if ($LpsnRow.ContainsKey('NewId') -and -not $output.Contains('Id')) {
            $output.Id = $LpsnRow.NewId
            $cacheById[$output.Id] = $output
        }
        return $output
    } else {
        $p = $lpsnCacheByRecordNumber[$LpsnRow.lpsn_parent_id]
    }
    $concept_id = $LpsnRow.lpsn_address.Substring(21)
    New-Variable -Name inputData
    if ($ByLpsnConceptId.TryGetValue($concept_id, [ref]$inputData)) {
        New-LpsnOutput $LpsnRow $p $inputData
    }
    else {
        New-LpsnOutput $LpsnRow $p $null
    }   
}

function AddLpsnAgentToHierarchy {
    param ($Agent)
    $concept_id = $Agent.concept_id
    New-Variable -Name lpsnRow
    if (-not $lpsnDataByConceptId.TryGetValue($concept_id, [ref]$lpsnRow)) {
        Write-Warning "LPSN data is missing information for concept id $concept_id"
    }
    if ($lpsnRow.full_name -ne $Agent.concept -and [string]::Join(' ', ($lpsnRow.full_name.Split(' ') | Where-Object {$_ -ne 'subsp.'})) -cne $Agent.concept) {
        Write-Warning "The input concept name '$($Agent.concept)' does not match the detected LPSN full name '$($lpsnRow.full_name)'."
    }
    # Check if we're actually using the correct name
    if ($lpsnRow.ContainsKey('lpsn_correct_name_id') -and $lpsnRow.lpsn_correct_name_id -ne $lpsnRow.id) {
        $lpsnRow = $lpsnDataByRecordNumber[$lpsnRow.lpsn_correct_name_id]

        # Do we have the correct name in our original data?
        $concept_id = $lpsnRow.lpsn_address.Substring(21)
        New-Variable -Name correctAgent
        if ($ByLpsnConceptId.TryGetValue($concept_id, [ref]$correctAgent)) {
            $lpsnRow.NewId = $correctAgent.id
            # If we have the correct name as synonym we need to upgrade and add it
            if ($correctAgent.ContainsKey('synonym')) {
                #Write-Host "Upgrading $($correctAgent.synonym) from synonym to infectious agent"
                $template = $ById[$correctAgent.synonym_for]
                $correctAgent.concept = $correctAgent.synonym
                $correctAgent.Remove('synonym') | Out-Null
                $correctAgent.Remove('synonym_for') | Out-Null
                foreach ($key in $template.Keys) {
                    if ($key -notin @('id','concept','concept_source','concept_id')) {
                        $correctAgent[$key] = $template[$key]
                    }
                }
                AddLpsnAgentRecursive $lpsnRow | Out-Null
            }
        } else {
            # We have a correct name that isn't in our original data yet
            #Write-Host "Adding new infectious agent $($lpsnRow.full_name)"
            $lpsnRow.NewId = ++$Script:maxId
            AddLpsnAgentRecursive $lpsnRow | Out-Null
        }
        # Downgrade the incorrect name to synonym
        #Write-Host "Downgrading $($Agent.concept) from infectious agent to synonym"
        $Agent.synonym = $Agent.concept
        $Agent.synonym_for = $lpsnRow.NewId
        $Agent.Remove('concept') | Out-Null
        foreach ($key in @($Agent.Keys)) {
            if ($key -notin @('id','synonym','concept_source','concept_id','synonym_for')) {
                $Agent.Remove($key) | Out-Null
            }
        }
        $downgraded[[int]$Agent.id] = $lpsnRow.NewId
    }
    else {
        AddLpsnAgentRecursive $lpsnRow | Out-Null
    }
}

function AddLpsnSynonym {
    param ($Synonym)
    $concept_id = $Synonym.concept_id
    New-Variable -Name lpsnRow
    if (-not $lpsnDataByConceptId.TryGetValue($concept_id, [ref]$lpsnRow)) {
        Write-Warning "LPSN data is missing information for concept id $concept_id"
    }

    New-Variable -Name parentId
    if (-not $downgraded.TryGetValue([int]$Synonym.synonym_for, [ref]$parentId)) {
        $parentId = [int]$Synonym.synonym_for
    }
    New-Variable -Name parent
    if ($cacheById.TryGetValue($parentId, [ref]$parent)) {
        EnsureChildren $parent -Synonyms
        $parent.Synonyms.Add([ordered]@{
            Name = $lpsnRow.full_name
            ConceptId = $concept_id
            ConceptSource = 'LPSN'
            Id = [int]$Synonym.id
            LpsnRecordNumber = $lpsnRow.id
        }) | Out-Null
    } else {
        Write-Warning "Missing parent infectious agent with id $parentId for LPSN synonym '$($Synonym.synonym)' with id $($Synonym.id)"
    }
}

function AddNeoIpcAgentToHierarchy {
    param ($Agent)
    switch ($Agent.concept) {
        # Skip manually added agents
         {$_ -in @(
            'Acinetobacter calcoaceticus-Acinetobacter baumannii complex'
            'Coagulase-negative staphylococcus'
            'Coagulase-positive staphylococcus'
            'Bacillus cereus group'
            'Bacillus subtilis group'
            'Bacteroides fragilis group'
            'Burkholderia cepacia complex'
            'Echovirus'
            'Enterobacter cloacae complex'
            'Eukaryota'
            'Human adenovirus'
            'Human bocavirus'
            'Human coronavirus'
            'Human coxsackievirus'
            'Human coxsackievirus A'
            'Human coxsackievirus B'
            'Human herpes simplex virus'
            'Human herpesvirus 6'
            'Human immunodeficiency virus'
            'Mycobacterium avium complex'
            'Mycobacterium fortuitum complex'
            'Mycobacterium terrae complex'
            'Mycobacterium tuberculosis complex'
            'Nocardia asteroides complex'
            'Not listed'
            'Poliovirus'
            'Poliovirus 1'
            'Poliovirus 2'
            'Poliovirus 3'
            'Prevotella oralis group'
            'Streptococcus anginosus group'
            'Streptococcus bovis group'
            'Streptococcus mitis group'
            'Streptococcus mutans group'
            'Streptococcus salivarius group'
            'Streptococcus sanguinis group'
            'Viridans streptococci'
            )} {
            break
        }
        {$_ -in @(
            'Salmonella enterica subsp. enterica Choleraesuis'
            'Salmonella enterica subsp. enterica Enteritidis'
            'Salmonella enterica subsp. enterica Infantis'
            'Salmonella enterica subsp. enterica Bareilly'
            'Salmonella enterica subsp. enterica Isangi'
            'Salmonella enterica subsp. enterica Kottbus'
            'Salmonella enterica subsp. enterica Livingstone'
            'Salmonella enterica subsp. enterica Montevideo'
            'Salmonella enterica subsp. enterica Newport'
            'Salmonella enterica subsp. enterica Ohio'
            'Salmonella enterica subsp. enterica Senftenberg'
            'Salmonella enterica subsp. enterica Tennessee'
            'Salmonella enterica subsp. enterica Urbana'
            'Salmonella enterica subsp. enterica Virchow'
            'Salmonella enterica subsp. enterica Worthington'
            'Salmonella enterica subsp. enterica Typhi'
            'Salmonella enterica subsp. enterica Typhimurium'
            )} {
            $id = [int]$Agent.id
            if (-not $cacheById.ContainsKey($id)) {
                $output = [ordered]@{}
                $output.Name = $Agent.concept
                $output.ConceptType = 'Serotype'
                $output.ConceptId = $_
                $output.ConceptSource = 'NeoIPC'
                $output.Id = $id
                New-Variable -Name parent
                if ($cacheById.TryGetValue(2733, [ref]$parent)) {
                    EnsureChildren $parent
                    $parent.Children.Add($output) | Out-Null
                }
                else {
                    $childrenToAdd[$output] = 2733
                }
                $cacheById[$id] = $output
            }
            break
        }
        {$_ -in @(
            'Alpha-hemolytic streptococci'
            'Beta-hemolytic streptococci'
            'Gamma-hemolytic streptococci'
            )} {
            $id = [int]$Agent.id
            if (-not $cacheById.ContainsKey($id)) {
                $output = [ordered]@{}
                $output.Name = $Agent.concept
                $output.ConceptType = 'Group'
                $output.ConceptId = $_
                $output.ConceptSource = 'NeoIPC'
                $output.Id = $id
                New-Variable -Name parent
                if ($cacheById.TryGetValue(1642, [ref]$parent)) {
                    EnsureChildren $parent
                    $parent.Children.Add($output) | Out-Null
                }
                else {
                    $childrenToAdd[$output] = 1642
                }
                $cacheById[$id] = $output
            }
            break
        }
        {$_ -eq 'Human papillomavirus'} {
            $id = [int]$Agent.id
            if (-not $cacheById.ContainsKey($id)) {
                $output = [ordered]@{}
                $output.Name = $Agent.concept
                $output.ConceptType = 'Group'
                $output.ConceptId = $_
                $output.ConceptSource = 'NeoIPC'
                $output.Id = $id
                $parent = AddIctvAgentRecursive $ictvDataByTaxNodeId[202405883]
                EnsureChildren $parent
                $parent.Children.Add($output) | Out-Null
                $cacheById[$id] = $output
            }
            break
        }
        {$_ -eq 'Human parainfluenza virus'} {
            $id = [int]$Agent.id
            if (-not $cacheById.ContainsKey($id)) {
                $output = [ordered]@{}
                $output.Name = $Agent.concept
                $output.ConceptType = 'Group'
                $output.ConceptId = $_
                $output.ConceptSource = 'NeoIPC'
                $output.Id = $id
                $parent = AddIctvAgentRecursive $ictvDataByTaxNodeId[202401586]
                EnsureChildren $parent
                $parent.Children.Add($output) | Out-Null
                $cacheById[$id] = $output
            }
            break
        }
        {$_ -eq 'Human pegivirus'} {
            $id = [int]$Agent.id
            if (-not $cacheById.ContainsKey($id)) {
                $output = [ordered]@{}
                $output.Name = $Agent.concept
                $output.ConceptType = 'Group'
                $output.ConceptId = $_
                $output.ConceptSource = 'NeoIPC'
                $output.Id = $id
                $parent = AddIctvAgentRecursive $ictvDataByTaxNodeId[202403139]
                EnsureChildren $parent
                $parent.Children.Add($output) | Out-Null
                $cacheById[$id] = $output
            }
            break
        }
        {$_ -eq 'Human rhinovirus'} {
            $id = [int]$Agent.id
            if (-not $cacheById.ContainsKey($id)) {
                $output = [ordered]@{}
                $output.Name = $Agent.concept
                $output.ConceptType = 'Group'
                $output.ConceptId = $_
                $output.ConceptSource = 'NeoIPC'
                $output.Id = $id
                $parent = AddIctvAgentRecursive $ictvDataByTaxNodeId[202401982]
                EnsureChildren $parent
                $parent.Children.Add($output) | Out-Null
                $cacheById[$id] = $output
            }
            break
        }
        {$_ -eq 'Influenza virus'} {
            $id = [int]$Agent.id
            if (-not $cacheById.ContainsKey($id)) {
                $output = $hInflV
                $parent = AddIctvAgentRecursive $ictvDataByTaxNodeId[202403953]
                EnsureChildren $parent
                $parent.Children.Add($output) | Out-Null
                $cacheById[$id] = $output
            }
            break
        }
        {$_ -eq 'Severe acute respiratory syndrome coronavirus 2'} {
            $id = [int]$Agent.id
            if (-not $cacheById.ContainsKey($id)) {
                $output = [ordered]@{}
                $output.Name = $Agent.concept
                $output.ConceptType = 'Serotype'
                $output.ConceptId = $_
                $output.ConceptSource = 'NeoIPC'
                $output.Id = $id
                $parent = AddIctvAgentRecursive $ictvDataByTaxNodeId[202401868]
                EnsureChildren $parent
                $parent.Children.Add($output) | Out-Null
                $cacheById[$id] = $output
            }
            break
        }
        Default {
            Write-Warning "Unhandled NeoIPC concept '$($Agent.concept)'"
        }
    }
}

function AddNeoIpcSynonym {
    param ($Synonym)
    New-Variable -Name parentId
    if (-not $downgraded.TryGetValue([int]$Synonym.synonym_for, [ref]$parentId)) {
        $parentId = [int]$Synonym.synonym_for
    }
    New-Variable -Name parent
    if ($cacheById.TryGetValue($parentId, [ref]$parent)) {
        EnsureChildren $parent -Synonyms
        $parent.Synonyms.Add([ordered]@{
            Name = $Synonym.synonym
            ConceptId = $Synonym.concept_id
            ConceptSource = 'NeoIPC'
            Id = [int]$Synonym.id
        }) | Out-Null
    } else {
        Write-Warning "Missing parent infectious agent with id $parentId for NeoIPC synonym '$($Synonym.synonym)' with id $($Synonym.id)"
    }
}

function Update-IctvParent {
    param ($Parent, $IctvRow, $InputData)
    if ($IctvRow.name -in @(
        'Mastadenovirus adami' # Human adenovirus A
        'Mastadenovirus blackbeardi' # Human adenovirus B
        'Mastadenovirus caesari' # Human adenovirus C
        'Mastadenovirus dominans' # Human adenovirus D
        'Mastadenovirus exoticum' # Human adenovirus E
        'Mastadenovirus faecale' # Human adenovirus F
        'Mastadenovirus russelli' # Human adenovirus G
    )) {
        $Parent = $hAv
    } elseif ($IctvRow.name -in @(
        'Bocaparvovirus primate 1'
        'Bocaparvovirus primate 2'
        'Bocaparvovirus primate 3'
    )) {
        $Parent = $hBv
    } elseif ($IctvRow.name -in @(
        'Simplexvirus humanalpha1'
        'Simplexvirus humanalpha2'
    )) {
        $Parent = $hHsV
    } elseif ($IctvRow.name -in @(
        'Roseolovirus humanbeta6b'
        'Roseolovirus humanbeta6a'
    )) {
        $Parent = $hHV6
    } elseif ($IctvRow.name -in @(
        'Lentivirus humimdef1'
        'Lentivirus humimdef2'
    )) {
        $Parent = $hIV
    } elseif ($IctvRow.name -in @(
        'Alphainfluenzavirus'
        'Betainfluenzavirus'
        'Gammainfluenzavirus'
        'Deltainfluenzavirus'
    )) {
        $Parent = $hInflV
    }
    return $Parent
}

function Add-IctvManualChildren {
    param ($Output, $LpsnRow, $InputData)

    # Insert Polio viruses as children of Enterovirus coxsackiepol
    if ($Output.ConceptId -eq 202401985) {
        EnsureChildren $Output
        $Output.Children.Add($pV) | Out-Null
        $Output.Children.Add($pV1) | Out-Null
        $Output.Children.Add($pV2) | Out-Null
        $Output.Children.Add($pV3) | Out-Null
    }
    # Echovirus
    elseif ($Output.ConceptId -eq 202401953) {
        EnsureChildren $Output
        $Output.Children.Add($eV) | Out-Null
    }
    # Human coronavirus
    elseif ($Output.ConceptId -eq 202401847) {
        EnsureChildren $Output -Synonyms
        $Output.Synonyms.Add($hCov) | Out-Null
    }
    # Human adenovirus
    elseif ($Output.ConceptId -eq 202402412) {
        EnsureChildren $Output
        $Output.Children.Add($hAv) | Out-Null
    }
    # Human bocavirus
    elseif ($Output.ConceptId -eq 202404241) {
        EnsureChildren $Output
        $Output.Children.Add($hBv) | Out-Null
    }
    # Human coxsackievirus
    elseif ($Output.ConceptId -eq 202401982) {
        EnsureChildren $Output
        $Output.Children.Add($hCoxV) | Out-Null
        $Output.Children.Add($hCoxVA) | Out-Null
        $Output.Children.Add($hCoxVB) | Out-Null
    }
    # Human herpes simplex virus
    elseif ($Output.ConceptId -eq 202401424) {
        EnsureChildren $Output
        $Output.Children.Add($hHsV) | Out-Null
    }
    # Human herpesvirus 6
    elseif ($Output.ConceptId -eq 202401473) {
        EnsureChildren $Output
        $Output.Children.Add($hHV6) | Out-Null
    }
    # Human immunodeficiency virus
    elseif ($Output.ConceptId -eq 202405025) {
        EnsureChildren $Output
        $Output.Children.Add($hIV) | Out-Null
    }
}

function New-IctvOutput
{
    param ($IctvRow, $Parent, $InputData)

    $levelName = $ictvLevels[$IctvRow.level_id].name
    $output = [ordered]@{}
    $output.Name = $IctvRow.name
    $output.ConceptType = $levelName.Substring(0,1).ToUpperInvariant() + $levelName.Substring(1)
    $output.ConceptId = $IctvRow.taxnode_id
    $output.ConceptSource = 'ICTV'
    if ($InputData -and $InputData.id) {
        $output.Id = [int]$inputData.id
    } elseif ($IctvRow.Contains('NewId')) {
        $output.Id = $IctvRow.NewId
    }
    $output.IctvId = $IctvRow.ictv_id

    $Parent = Update-IctvParent $Parent $IctvRow $InputData
    if(-not $Parent.Contains('Children')) {
        EnsureChildren $Parent
        $Parent.Children.Add($output) | Out-Null
        $ictvCacheByTaxNodeId[$IctvRow.taxnode_id] = $output
        if ($output.Contains("id")) {
            $cacheById[$output.id] = $output
        }
    } elseif (-not $ictvCacheByTaxNodeId.ContainsKey($IctvRow.taxnode_id)) {
        $Parent.Children.Add($output) | Out-Null
        $ictvCacheByTaxNodeId[$IctvRow.taxnode_id] = $output
        if ($output.Contains("id")) {
            $cacheById[$output.id] = $output
        }
    }
    Write-Debug "Adding $($output.Name)"

    Add-IctvManualChildren $output $IctvRow $InputData | Out-Null
    return $output
}

function AddIctvAgentRecursive {
    param ($IctvRow)
    New-Variable -Name p
    $parent_id = $IctvRow.parent_id
    if ($ictvCacheByTaxNodeId.TryGetValue($IctvRow.taxnode_id, [ref]$p)) {
        if ($IctvRow.Contains('NewId') -and -not $p.Contains('Id')) {
            $p.Id = $IctvRow.NewId
            $cacheById[$p.Id] = $p
        }
        return $p
    } elseif (-not $ictvCacheByTaxNodeId.TryGetValue($parent_id, [ref]$p)) {
        $p = AddIctvAgentRecursive $ictvDataByTaxNodeId[$parent_id]
    }
    New-Variable -Name inputData
    if ($ByIctvConceptId.TryGetValue($IctvRow.taxnode_id, [ref]$inputData) -or $ByName.TryGetValue($IctvRow.name, [ref]$inputData)) {
        New-IctvOutput $IctvRow $p $inputData
    } else {
        New-IctvOutput $IctvRow $p
    }   
}

function AddIctvAgentToHierarchy {
    param ($Agent)
    New-Variable -Name ictvRow
    if (-not $ictvDataByName.TryGetValue($Agent.concept, [ref]$ictvRow)) {
        if ($Agent.concept -notin @('Poliovirus 1','Poliovirus 2','Poliovirus 3')) {
            Write-Warning "ICTV data is missing information for concept '$($Agent.concept)'"
        }
        return
    }
    if ($ictvRow.name -ne $Agent.concept) {
        Write-Warning "The input concept name '$($Agent.concept)' does not match the detected LPSN full name '$($ictvRow.name)'."
    }
    # Check if we're actually using the correct name
    New-Variable -Name newestIctvRow
    if ($ictvDataByIctvId.TryGetValue($ictvRow.ictv_id, [ref]$newestIctvRow) -and $newestIctvRow.taxnode_id -ne $ictvRow.taxnode_id) {
        Write-Information "Upgrading the old ICTV name '$($ictvRow.name)' to the new one ('$($newestIctvRow.name)')"
        $ictvRow = $newestIctvRow

        # Do we have the correct name in our original data?
        New-Variable -Name correctAgent
        if ($ByIctvConceptId.TryGetValue($ictvRow.taxnode_id, [ref]$correctAgent) -or $ByName.TryGetValue($ictvRow.name, [ref]$correctAgent)) {
            $ictvRow.NewId = [int]$correctAgent.id
            # If we have the correct name as synonym we need to upgrade and add it
            if ($correctAgent.ContainsKey('synonym')) {
                Write-Debug "Upgrading $($correctAgent.synonym) from synonym to infectious agent"
                $template = $ById[$correctAgent.synonym_for]
                $correctAgent.concept = $correctAgent.synonym
                $correctAgent.Remove('synonym') | Out-Null
                $correctAgent.Remove('synonym_for') | Out-Null
                foreach ($key in $template.Keys) {
                    if ($key -notin @('id','concept','concept_source','concept_id')) {
                        $correctAgent[$key] = $template[$key]
                    }
                }
                AddIctvAgentRecursive $ictvRow | Out-Null
            }
        } else {
            # We have a correct name that isn't in our original data yet
            Write-Debug "Adding new infectious agent $($ictvRow.name)"
            $ictvRow.NewId = ++$Script:maxId
            AddIctvAgentRecursive $ictvRow | Out-Null
        }
        # Downgrade the incorrect name to synonym
        Write-Debug "Downgrading $($Agent.concept) from infectious agent to synonym"
        $Agent.synonym = $Agent.concept
        $Agent.synonym_for = $ictvRow.NewId
        $Agent.Remove('concept') | Out-Null
        foreach ($key in @($Agent.Keys)) {
            if ($key -notin @('id','synonym','concept_source','concept_id','synonym_for')) {
                $Agent.Remove($key) | Out-Null
            }
        }
        $downgraded[[int]$Agent.id] = $ictvRow.NewId
    } else {
        AddIctvAgentRecursive $ictvRow | Out-Null
    }
}

function AddIctvSynonym {
    param ($Synonym)
    $concept_id = [int]$Synonym.concept_id
    New-Variable -Name ictvRow1
    if (-not $ictvDataByTaxNodeId.TryGetValue($concept_id, [ref]$ictvRow1)) {
        Write-Warning "ICTV data is missing information for concept id $concept_id"
    }
    New-Variable -Name ictvRow2
    if (-not $ictvDataByIctvId.TryGetValue($ictvRow1.ictv_id, [ref]$ictvRow2)) {
        Write-Warning "ICTV data is missing information for ICTV id $($ictvRow1.ictv_id)"
    }

    New-Variable -Name parentId
    if (-not $downgraded.TryGetValue([int]$Synonym.synonym_for, [ref]$parentId)) {
        $parentId = [int]$Synonym.synonym_for
    }
    New-Variable -Name parent
    if ($cacheById.TryGetValue($parentId, [ref]$parent)) {
        if (-not $parent.Contains('Synonyms')) {
            $parent.Synonyms = [System.Collections.Generic.SortedSet[ordered]]::new($myConceptComparer)
        }
        if ($ictvRow1.name -cne $Synonym.synonym) {
            Write-Warning "Renaming ICTV synonym '$($Synonym.synonym)' to '$($ictvRow1.name)' (ictv_id: $($ictvRow1.ictv_id), taxnode_id: $($ictvRow1.taxnode_id))"
            $parent.Synonyms.Add([ordered]@{
                Name = $ictvRow1.name
                ConceptId = $concept_id
                ConceptSource = 'ICTV'
                Id = [int]$Synonym.id
                IctvId = [int]$ictvRow1.ictv_id
            }) | Out-Null
        }
        elseif ($ictvRow1.name -eq $ictvRow2.name) {
            Write-Warning "The ICTV synonym '$($Synonym.synonym)' is not pointing to a synonym but to a current name ($($ictvRow1.name))."
        }
        else {
            $parent.Synonyms.Add([ordered]@{
                Name = $ictvRow1.name
                ConceptId = $concept_id
                ConceptSource = 'ICTV'
                Id = [int]$Synonym.id
                IctvId = [int]$ictvRow1.ictv_id
            }) | Out-Null
        }
    } else {
        Write-Warning "Missing parent infectious agent with id $parentId for ICTV synonym '$($Synonym.synonym)' with id $($Synonym.id)"
    }
}

function FetchMycoBankData {
    param ($ConceptId, $ConceptName)
    New-Variable -Name mycoBankRow
    if ($mycoBankDataByMycoBankNumber.TryGetValue([Int64]$ConceptId, [ref]$mycoBankRow)) {
        return $mycoBankRow
    }

    $filter = [System.Web.HttpUtility]::UrlEncode("name startWith '$ConceptName'")
    $mycobankData = Invoke-RestMethod -Uri "https://webservices.bio-aware.com/cbsdatabase_new/mycobank/taxonnames?page=1&pageSize=1&filter=$filter" -Headers @{'Authorization' = "Bearer $mycobankToken"} |
        Select-Object -ExpandProperty items

    $mycoBankDataById["$($mycobankData.id)"] = $mycobankData
    $mycoBankDataByMycoBankNumber[$mycobankData.mycobankNr] = $mycobankData

    $mycoBankDataById | ConvertTo-Json -Depth 100 | Set-Content -Encoding utf8NoBOM -LiteralPath ./metadata/common/pathogens/MycoBank_data.json

    return $mycobankData
}

function AddMycoBankAgentToHierarchy {
    param ($Agent)
    $mycoBankRow = FetchMycoBankData $Agent.concept_id $Agent.concept
    $currentNameId = $mycoBankRow.synonymy.currentNameId
    if ($mycoBankRow.id -ne $currentNameId) {
        if (-not $mycoBankDataById.ContainsKey($currentNameId)) {
            $currentMycobankData = Invoke-RestMethod -Uri "https://webservices.bio-aware.com/cbsdatabase_new/mycobank/taxonnames/$currentNameId" -Headers @{'Authorization' = "Bearer $mycobankToken"}
        }
    }

}

function AdMycoBankSynonym {
    param ($Synonym)
}

function AddAgentToHierarchy {
    param ($Agent)
    switch ($Agent.concept_source) {
        NeoIPC {
            AddNeoIpcAgentToHierarchy $Agent
            break
        }
        LPSN {
            AddLpsnAgentToHierarchy $Agent
            break
        }
        ICTV {
            AddIctvAgentToHierarchy $Agent
            break
        }
        MycoBank {
            AddMycoBankAgentToHierarchy $Agent
            break
        }
        Default { break }
    }
}

function AddSynonym {
    param ($Synonym)
    switch ($Synonym.concept_source) {
        NeoIPC {
            AddNeoIpcSynonym $Synonym
            break
        }
        LPSN {
            AddLpsnSynonym $Synonym
            break
        }
        ICTV {
            AddIctvSynonym $Synonym
            break
        }
        MycoBank {
            AddMycoBankSynonym $Synonym
            break
        }
        Default { break }
    }
}

$lineNo = 2
foreach ($iaRow in $infectiousAgentData) {
    $id = [int]::Parse($iaRow.id)
    # Convert the input object to a hashtable so that we can easily add properties
    $newRow = [System.Collections.Generic.OrderedDictionary[string,string]]::new()
    $iaRow.psobject.properties | ForEach-Object { $newRow[$_.Name] = $_.Value }
    try {
        $ById.Add($id, $newRow)
    }
    catch {
        Write-Error "Duplicate id $id in file 'NeoIPC-Pathogen-Concepts.csv' line $lineNo."
    }
    try {
        if ($iaRow.concept_source -eq 'LPSN') {
            $ByLpsnConceptId.Add($iaRow.concept_id, $newRow)
        }
    }
    catch {
        Write-Error "Duplicate LPSN concept id '$($iaRow.concept_id)' in file 'NeoIPC-Pathogen-Concepts.csv' line $lineNo."
    }
    try {
        if ($iaRow.concept_source -eq 'ICTV') {
            if ($iaRow.concept_id -in @('202101985','202101868') -and $iaRow.concept_type -ne 'species') {
                # do nothing
            } else {
                $ByIctvConceptId.Add($iaRow.concept_id, $newRow)
            }
        }
    }
    catch {
        Write-Error "Duplicate ICTV concept id '$($iaRow.concept_id)' in file 'NeoIPC-Pathogen-Concepts.csv' line $lineNo."
    }
    try {
        $ByName.Add($iaRow.concept, $newRow)
    }
    catch {
        Write-Error "Duplicate name '$($iaRow.concept)' in file 'NeoIPC-Pathogen-Concepts.csv' line $lineNo."
    }
    $lineNo++
}

$lineNo = 2
foreach ($sRow in $synonymData) {
    $id = [int]::Parse($sRow.id)
    # Convert the input object to a hashtable so that we can easily add properties
    $newRow = [System.Collections.Generic.OrderedDictionary[string,string]]::new()
    $sRow.psobject.properties | ForEach-Object { $newRow[$_.Name] = $_.Value }
    try {
        $ById.Add($id, $newRow)
    }
    catch {
        Write-Error "Duplicate id $id in file 'NeoIPC-Pathogen-Synonyms.csv' line $lineNo."
    }
    try {
        if ($sRow.concept_source -eq 'LPSN') {
            $ByLpsnConceptId.Add($sRow.concept_id, $newRow)
        }
    }
    catch {
        Write-Error "Duplicate LPSN concept id '$($sRow.concept_id)' in file 'NeoIPC-Pathogen-Concepts.csv' line $lineNo."
    }
    try {
        $ByName.Add($sRow.synonym, $newRow)
    }
    catch {
        Write-Error "Duplicate name '$($sRow.synonym)' in file 'NeoIPC-Pathogen-Synonyms.csv' line $lineNo."
    }
    $lineNo++
}
$Script:maxId = [int]($ById.Keys | Sort-Object | Select-Object -Last 1)

foreach ($row in $ById.Values) {
    if ($row.ContainsKey('concept')) {
        AddAgentToHierarchy $row
    }
}
foreach ($row in $ById.Values) {
    if ($row.ContainsKey('synonym')) {
        AddSynonym $row
    }
}
$more = $true
while ($more) {
    $more = $false
    foreach ($pair in $childrenToAdd.GetEnumerator()) {
        $parent = $null
        if ($cacheById.TryGetValue($pair.Value, [ref]$parent)) {
            $add = $true
            if ($parent.Contains('Children')) {
                foreach ($child in $parent.Children) {
                    if ($child.Name -eq $pair.Key.Name) {
                        $add = $false
                    }
                }
            }
            if ($add) {
                EnsureChildren $parent
                $parent.Children.Add($pair.Key) | Out-Null
                if ($pair.Key.Id) {
                    $cacheById[$pair.Key.Id] = $pair.Key
                }
            }
        } else {
            $more = $true
        }
    }
}

$data | ConvertTo-Yaml | Out-File -Encoding utf8NoBOM -LiteralPath ./metadata/common/pathogens/NeoIPC-Infectious-Agents.yml
