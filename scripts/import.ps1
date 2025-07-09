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

$lpsnRaw = Get-Content -LiteralPath ./metadata/common/pathogens/LPSN_data.json -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable -Depth 100
$ictvData = Import-Csv ./metadata/common/pathogens/ICTV_Master_Species_List_2024_MSL40.v1.csv -UseCulture

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
$maxId = $null
Class ConceptComparer:System.Collections.Generic.IComparer[System.Collections.Specialized.OrderedDictionary] {
    [int]Compare([System.Collections.Specialized.OrderedDictionary]$x, [System.Collections.Specialized.OrderedDictionary]$y) {
        return [System.Collections.Generic.Comparer[string]]::Default.Compare($x.Name, $y.Name)
    }
}
[ConceptComparer]$myConceptComparer=[ConceptComparer]::new()

$bacteria = [ordered]@{
    Name = 'Bacteria'
    ConceptType = 'Domain'
    LpsnRecordNumber = 43123
    ConceptId = 'domain/bacteria'
    Children = [System.Collections.Generic.SortedSet[ordered]]::new($myConceptComparer)
}

$viruses = [ordered]@{
    ConceptType = 'Domain'
    Name = 'Virus'
    Children = [System.Collections.Generic.SortedSet[ordered]]::new($myConceptComparer)
}
$fungi = [ordered]@{
    ConceptType = 'Kingdom'
    Name = 'Fungi'
    Children = [System.Collections.Generic.SortedSet[ordered]]::new($myConceptComparer)
}

$data = [ordered]@{
    UrlTemplates = [ordered]@{
        ICTV = 'https://ictv.global/taxonomy/taxondetails?taxnode_id={0}'
        LPSN = 'https://lpsn.dsmz.de/{0}'
        MycoBank = 'TODO'
        NeoIPC = 'TODO'
    }
    Hierarchies = @(
        $bacteria
        $fungi
        $viruses
    )
}
$coNS = [ordered]@{
    Id = 2776
    Name = 'Coagulase-negative staphylococci'
    ConceptType = 'Diagnostic group'
    ConceptId = 63
    ConceptSource = 'NeoIPC'
}
$coPS = [ordered]@{
    Id = 2777
    Name = 'Coagulase-positive staphylococci'
    ConceptType = 'Diagnostic group'
    ConceptId = 64
    ConceptSource = 'NeoIPC'
}
$coVS = [ordered]@{
    Name = 'Coagulase-variable staphylococci'
    ConceptType = 'Diagnostic group'
    ConceptId = 'ToDo assign NeoIPC concept id for CoVS'
    ConceptSource = 'NeoIPC'
}
$aBCC = [ordered]@{
    Id = 2704
    Name = 'Acinetobacter calcoaceticus-Acinetobacter baumannii complex'
    ConceptType = 'Diagnostic group'
    ConceptId = 31
    ConceptSource = 'NeoIPC'
    Carbapenems = $true
    Colistin = $true
}
# Alpha-hemolytic streptococci
# Beta-hemolytic streptococci
# Gamma-hemolytic streptococci
# Bacillus cereus group
# Bacillus subtilis group   
# Bacteroides fragilis group
# Burkholderia cepacia complex
# Enterobacter cloacae complex
# Mycobacterium avium complex
# Mycobacterium fortuitum complex
# Mycobacterium terrae complex
# Mycobacterium tuberculosis complex
# Nocardia asteroides complex
# Prevotella oralis group
# Streptococcus anginosus group
# Streptococcus bovis group
# Streptococcus mitis group
# Streptococcus mutans group
# Streptococcus salivarius group
# Streptococcus sanguinis group
# Viridans streptococci

# Salmonella enterica subsp. enterica Bareilly
# Salmonella enterica subsp. enterica Choleraesuis
# Salmonella enterica subsp. enterica Enteritidis
# Salmonella enterica subsp. enterica Infantis
# Salmonella enterica subsp. enterica Isangi
# Salmonella enterica subsp. enterica Kottbus
# Salmonella enterica subsp. enterica Livingstone
# Salmonella enterica subsp. enterica Montevideo
# Salmonella enterica subsp. enterica Newport
# Salmonella enterica subsp. enterica Ohio
# Salmonella enterica subsp. enterica Senftenberg
# Salmonella enterica subsp. enterica Tennessee
# Salmonella enterica subsp. enterica Typhi
# Salmonella enterica subsp. enterica Typhimurium
# Salmonella enterica subsp. enterica Urbana
# Salmonella enterica subsp. enterica Virchow
# Salmonella enterica subsp. enterica Worthington

# Candida parapsilosis complex

# Echovirus
# Hepatitis D virus
# Human adenovirus
# Human bocavirus
# Human coronavirus   
# Human coxsackievirus
# Human coxsackievirus A
# Human coxsackievirus B
# Human herpes simplex virus
# Human herpesvirus 6
# Human immunodeficiency virus
# Human papillomavirus
# Human parainfluenza virus
# Human rhinovirus
# Influenza virus
# Poliovirus



$lpsnCacheByRecordNumber = [System.Collections.Generic.Dictionary[Int64,ordered]]::new()
$lpsnCacheByRecordNumber[[Int64]43123] = $bacteria
$cacheById = [System.Collections.Generic.Dictionary[int,ordered]]::new()
$downgraded = [System.Collections.Generic.Dictionary[int,int]]::new()

function EnsureChildren {
    param ([System.Collections.Specialized.OrderedDictionary]$Object)
    if (-not $Object.Contains('Children')) {
        $Object.Children = [System.Collections.Generic.SortedSet[ordered]]::new($myConceptComparer)
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
}

function New-LpsnOutput
{
    param ($LpsnRow, $Parent, $InputData)
    $output = [ordered]@{}
    if ($InputData -and $InputData.id -and $inputData.concept_type -in @('subspecies','species','genus')) {
        $output.Id = [int]$inputData.id
    } elseif ($LpsnRow.ContainsKey('NewId')) {
        $output.Id = $LpsnRow.NewId
    }
    $output.Name = $LpsnRow.full_name
    $output.ConceptSource = 'LPSN'
    $output.ConceptType = $LpsnRow.category.Substring(0,1).ToUpperInvariant() + $LpsnRow.category.Substring(1)
    $output.ConceptId = $concept_id
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
        if ($output.Contains("id")) {
            $cacheById[$output.id] = $output
        }
    } elseif (-not $lpsnCacheByRecordNumber.ContainsKey($output.LpsnRecordNumber)) {
        $Parent.Children.Add($output) | Out-Null
        $lpsnCacheByRecordNumber[$output.LpsnRecordNumber] = $output
        if ($output.Contains("id")) {
            $cacheById[$output.id] = $output
        }
    }

    Add-LpsnManualChildren $output $LpsnRow $InputData | Out-Null
    return $output
}

function AddLpsnAgentRecursive {
    param ($LpsnRow)
    New-Variable -Name output
    if ($LpsnRow.ContainsKey('lpsn_parent_id') -and -not $lpsnCacheByRecordNumber.ContainsKey($LpsnRow.lpsn_parent_id)) {
        $p = AddLpsnAgentRecursive $lpsnDataByRecordNumber[$LpsnRow.lpsn_parent_id]
    } elseif ($lpsnCacheByRecordNumber.TryGetValue($LpsnRow.id, [ref]$output)) {
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
            $lpsnRow.NewId = ++$maxId
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

function AddNeoIpcAgentToHierarchy {
    param ($Agent)
    $Agent.concept
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
        ICTV { break }
        MycoBank { break }
        Default { break }
    }
}

function AddSynonym {
    param ($Synonym)
    switch ($Synonym.concept_source) {
        NeoIPC { break }
        LPSN {
            AddLpsnSynonym $Synonym
            break
        }
        ICTV { break }
        MycoBank { break }
        Default { break }
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
        if (-not $parent.Contains('Synonyms')) {
            $parent.Synonyms = [System.Collections.Generic.SortedSet[ordered]]::new($myConceptComparer)
        }
        $parent.Synonyms.Add([ordered]@{
            Id = [int]$Synonym.id
            Name = $lpsnRow.full_name
            ConceptId = $concept_id
            ConceptSource = 'LPSN'
            LpsnRecordNumber = $lpsnRow.id
        }) | Out-Null
    } else {
        Write-Warning "Missing infectious agent with id $($Synonym.synonym_for)"
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
$maxId = $ById.Keys | Sort-Object | Select-Object -Last 1

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

$data | ConvertTo-Yaml | Out-File -Encoding utf8NoBOM -LiteralPath ./metadata/common/pathogens/NeoIPC-Infectious-Agents.yml
