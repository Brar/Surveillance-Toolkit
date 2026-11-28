#Requires -Version 7.6

<#
.SYNOPSIS
Read the parameters of one report preset from a presets.json file.

.DESCRIPTION
Reads the named preset's parameter set from a report's presets.json, the file the reporting
service also serves for its preset listing. The _comment key documents the file and is no
render parameter, so it is left out. Each call returns a fresh hashtable the caller may edit.
An unknown name ends the call with an error listing the names the file carries, and a file
without a presets object is refused rather than read as an empty one.

.PARAMETER PresetsFilePath
The presets.json to read, path of an existing file.

.PARAMETER Name
The preset to read, a key of the file's presets object.

.OUTPUTS
[hashtable] The preset's render parameters, camelCase keys as the document declares them.

.EXAMPLE
$preset = Get-NeoIPCReportPreset -PresetsFilePath reports/Reference-Report/presets.json -Name class-range-edition

Reads what a report of a class or range switches off, to seed the render parameters with.
#>
function Get-NeoIPCReportPreset {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$PresetsFilePath,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if (-not (Test-Path -LiteralPath $PresetsFilePath)) {
        throw "The presets file '$PresetsFilePath' does not exist."
    }
    $document = (Get-Content -LiteralPath $PresetsFilePath -Raw) | ConvertFrom-Json
    $presets = $document.PSObject.Properties['presets']
    if ($null -eq $presets -or $null -eq $presets.Value) {
        throw "The presets file '$PresetsFilePath' carries no presets object."
    }

    $entry = $presets.Value.PSObject.Properties[$Name]
    if ($null -eq $entry) {
        $available = @($presets.Value.PSObject.Properties.Name) | Sort-Object
        throw "No preset named '$Name'. The file carries: $($available -join ', ')."
    }

    $parameters = @{}
    foreach ($property in $entry.Value.PSObject.Properties) {
        if ($property.Name -eq '_comment') {
            continue
        }
        $parameters[$property.Name] = $property.Value
    }
    return $parameters
}

<#
.SYNOPSIS
Read the number of departments a serialized reference dataset was built from.

.DESCRIPTION
Reads the n_departments field a serialized NeoIPC reference dataset carries: the number of
distinct departments its enrolments sit in, which is the count of departments whose patient
records ended their surveillance within the dataset's period. The dataset files the report
generators write come from jsonlite::serializeJSON, which wraps the R object in a
data/attributes/class envelope and every scalar in one of its own, so the field is read as
data.n_departments and an integer value is unwrapped once more. A file that is no serialized
dataset, or carries no n_departments within its data, is refused with an error naming the
file, since a build gate cannot decide on a count it cannot read.

.PARAMETER DatasetFilePath
The dataset's JSON file, path of an existing file.

.OUTPUTS
[System.Int32]

.EXAMPLE
$departments = Get-NeoIPCReferenceDatasetDepartmentCount -DatasetFilePath reference.json

Reads how many departments the dataset gives its figures to.
#>
function Get-NeoIPCReferenceDatasetDepartmentCount {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [string]$DatasetFilePath
    )

    if (-not (Test-Path -LiteralPath $DatasetFilePath)) {
        throw "The dataset file '$DatasetFilePath' does not exist."
    }
    $document = (Get-Content -LiteralPath $DatasetFilePath -Raw) | ConvertFrom-Json
    # serializeJSON's envelope puts the object's fields under data and names its class;
    # a document without that envelope is no serialized dataset and carries no count this
    # gate may trust.
    if (-not $document.PSObject.Properties['data'] -or -not $document.PSObject.Properties['class']) {
        throw "The dataset file '$(Split-Path -Leaf $DatasetFilePath)' is not a serialized reference dataset."
    }
    $fields = $document.data
    $count = $fields.PSObject.Properties['n_departments']
    if ($null -eq $count -or $null -eq $count.Value) {
        throw "The dataset file '$(Split-Path -Leaf $DatasetFilePath)' carries no n_departments field."
    }
    $value = $count.Value
    if ($value -is [pscustomobject] -and $value.PSObject.Properties['data']) {
        $value = $value.data
    }
    return [int]$value
}
