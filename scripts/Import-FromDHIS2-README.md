# Import-FromDHIS2.ps1 - Comprehensive Metadata Import

## Supported DHIS2 Metadata Types

The `Import-FromDHIS2.ps1` script now supports **all major DHIS2 metadata object types**. This document lists all supported types and their usage.

## Complete List of Supported Metadata Types

### Core Data Elements
- `dataElements` - Data elements with aggregation and value types
- `dataElementGroups` - Groups of data elements
- `dataElementGroupSets` - Sets of data element groups

### Categories  
- `categoryOptions` - Individual category options
- `categories` - Categories for disaggregation
- `categoryCombos` - Category combinations
- `categoryOptionCombos` - Category option combinations
- `categoryOptionGroups` - Groups of category options
- `categoryOptionGroupSets` - Sets of category option groups

### Indicators
- `indicatorTypes` - Types of indicators (e.g., per 1000, percentage)
- `indicators` - Calculated indicators with numerator/denominator
- `indicatorGroups` - Groups of indicators
- `indicatorGroupSets` - Sets of indicator groups

### Options
- `options` - Individual option values
- `optionSets` - Sets of options for dropdowns
- `optionGroups` - Groups of options
- `optionGroupSets` - Sets of option groups

### Organisation Units
- `organisationUnits` - Healthcare facilities and administrative units
- `organisationUnitLevels` - Hierarchy levels (national, regional, facility, etc.)
- `organisationUnitGroups` - Groups of organisation units
- `organisationUnitGroupSets` - Sets of organisation unit groups

### Programs (Tracker)
- `programs` - Tracker or event programs
- `programStages` - Stages within a program
- `programStageSections` - Sections within a stage
- `programSections` - Sections for tracked entity attributes
- `programIndicators` - Indicators calculated from program data
- `programIndicatorGroups` - Groups of program indicators
- `programRules` - Business logic rules
- `programRuleVariables` - Variables used in program rules
- `programRuleActions` - Actions triggered by program rules

### Tracked Entities
- `trackedEntityAttributes` - Attributes for tracked entities (patients, etc.)
- `trackedEntityTypes` - Types of tracked entities

### Data Sets (Aggregate)
- `dataSets` - Data collection forms for aggregate data

### Validation
- `validationRules` - Data quality validation rules
- `validationRuleGroups` - Groups of validation rules

### Predictors
- `predictors` - Automated data prediction rules
- `predictorGroups` - Groups of predictors

### Visualizations
- `visualizations` - Charts, pivot tables, etc.
- `eventVisualizations` - Visualizations for event/tracker data
- `dashboards` - Dashboard compositions
- `maps` - GIS map visualizations

### Other
- `attributes` - Custom attributes for metadata objects
- `legendSets` - Color legends for maps and visualizations
- `relationshipTypes` - Types of relationships between tracked entities
- `userRoles` - User permission roles
- `userGroups` - Groups of users

## Usage Examples

### Import a Complete Program

```powershell
# Import all metadata for a specific program
.\Import-FromDHIS2.ps1 `
    -BaseUrl "https://play.dhis2.org/40.2.2" `
    -Credential (Get-Credential) `
    -ProgramCode "NEOIPC_CORE" `
    -DetectPatterns
```

This imports:
- Program definition
- Program stages and sections
- Data elements and tracked entity attributes
- Program rules, variables, and actions
- Program indicators
- Option sets and options
- Tracked entity types

### Import Specific Metadata Types

```powershell
# Import only option sets and options
.\Import-FromDHIS2.ps1 `
    -BaseUrl "https://dhis2.org" `
    -Username "admin" `
    -Password "district" `
    -MetadataTypes @('optionSets', 'options') `
    -OutputPath "..\shared-data\infectious-agents"
```

```powershell
# Import data elements with filter
.\Import-FromDHIS2.ps1 `
    -BaseUrl "https://dhis2.org" `
    -Credential (Get-Credential) `
    -MetadataTypes @('dataElements') `
    -Filter "name:like:NEOIPC"
```

```powershell
# Import organisation units
.\Import-FromDHIS2.ps1 `
    -BaseUrl "https://dhis2.org" `
    -Credential (Get-Credential) `
    -MetadataTypes @('organisationUnits', 'organisationUnitLevels') `
    -OutputPath "..\metadata\organisation-units"
```

```powershell
# Import indicators and their dependencies
.\Import-FromDHIS2.ps1 `
    -BaseUrl "https://dhis2.org" `
    -Credential (Get-Credential) `
    -MetadataTypes @('indicatorTypes', 'indicators', 'indicatorGroups') `
    -Filter "name:like:Mortality"
```

```powershell
# Import dashboards and visualizations
.\Import-FromDHIS2.ps1 `
    -BaseUrl "https://dhis2.org" `
    -Credential (Get-Credential) `
    -MetadataTypes @('dashboards', 'visualizations', 'maps')
```

### Advanced Usage

```powershell
# Import with pattern detection and generator creation
.\Import-FromDHIS2.ps1 `
    -BaseUrl "https://dhis2.org" `
    -Credential (Get-Credential) `
    -ProgramCode "NEOIPC_CORE" `
    -DetectPatterns `
    -CreateGenerators
```

```powershell
# Force overwrite existing files
.\Import-FromDHIS2.ps1 `
    -BaseUrl "https://dhis2.org" `
    -Credential (Get-Credential) `
    -MetadataTypes @('options', 'optionSets') `
    -OutputPath "..\shared-data\antibiotics" `
    -Force
```

```powershell
# Use environment variables for credentials
$env:NEOIPC_DHIS2_BASEURL = "https://dhis2.org"
$env:NEOIPC_DHIS2_USERNAME = "admin"
$env:NEOIPC_DHIS2_PASSWORD = "district"

.\Import-FromDHIS2.ps1 `
    -ProgramCode "NEOIPC_CORE"
```

## Output Structure

### Program Mode

When importing a program, metadata is organized by type:

```
metadata/programs/neoipc_core/
├── data-elements/
│   ├── dataElements.yaml
│   └── dataElements.csv
├── tracked-entity-attributes/
│   ├── trackedEntityAttributes.yaml
│   └── trackedEntityAttributes.csv
├── stages/
│   ├── programStages.yaml
│   └── programStages.csv
├── stage-sections/
│   ├── programStageSections.yaml
│   └── programStageSections.csv
├── program-sections/
│   ├── programSections.yaml
│   └── programSections.csv
├── program-indicators/
│   ├── programIndicators.yaml
│   └── programIndicators.csv
├── rules/
│   ├── programRules.yaml
│   ├── programRules.csv
│   ├── variables/
│   │   ├── programRuleVariables.yaml
│   │   └── programRuleVariables.csv
│   └── actions/
│       ├── programRuleActions.yaml
│       └── programRuleActions.csv
└── option-sets/
    ├── optionSets.yaml
    ├── optionSets.csv
    ├── options.yaml
    └── options.csv
```

### Metadata Types Mode

When importing specific types, each type gets its own subdirectory:

```
shared-data/infectious-agents/
├── option-sets/
│   ├── optionSets.yaml
│   └── optionSets.csv
└── options/
    ├── options.yaml
    └── options.csv
```

## Field Mapping

### Translatable Fields (YAML)

These fields contain user-facing text that needs translation:

- `name` - Display name
- `shortName` - Abbreviated name
- `description` - Full description
- `formName` - Label shown on forms
- `content` - Content for program rules
- `title`, `subtitle` - Visualization titles
- `instruction` - Instructions for validation rules

### Technical Fields (CSV)

These fields contain technical configuration:

- `code` - Unique identifier
- `valueType` - Data type (TEXT, INTEGER, DATE, etc.)
- `domainType` - AGGREGATE or TRACKER
- `aggregationType` - SUM, AVERAGE, COUNT, etc.
- `optionSet` - Reference to option set (by code)
- `program`, `programStage` - References to program objects
- `condition` - Program rule conditions
- `expression`, `filter` - Indicator formulas
- Configuration booleans: `mandatory`, `unique`, `repeatable`, etc.

## Filtering

The `-Filter` parameter accepts DHIS2 API filter syntax:

```
name:like:text         # Name contains "text"
code:eq:VALUE          # Code equals "VALUE"
name:ilike:text        # Case-insensitive name contains
shortName:!like:text   # Short name does not contain
created:gt:2024-01-01  # Created after date
```

Multiple filters can be combined with `&`:

```powershell
-Filter "name:like:NEOIPC&domainType:eq:TRACKER"
```

## Common Workflows

### 1. Bootstrap Shared Data from Existing DHIS2

```powershell
# Export infectious agent option sets
.\Import-FromDHIS2.ps1 `
    -BaseUrl "https://production.dhis2.org" `
    -Credential $cred `
    -MetadataTypes @('optionSets', 'options') `
    -Filter "name:like:Pathogen" `
    -OutputPath "..\shared-data\infectious-agents"

# Export antibiotic option sets  
.\Import-FromDHIS2.ps1 `
    -BaseUrl "https://production.dhis2.org" `
    -Credential $cred `
    -MetadataTypes @('optionSets', 'options') `
    -Filter "name:like:Antibiotic" `
    -OutputPath "..\shared-data\antibiotics"
```

### 2. Bootstrap Program Metadata

```powershell
# Import complete program
.\Import-FromDHIS2.ps1 `
    -BaseUrl "https://production.dhis2.org" `
    -Credential $cred `
    -ProgramCode "NEOIPC_CORE" `
    -DetectPatterns

# Review imported files
explorer metadata\programs\neoipc_core

# Extract translations
.\Update-MetadataTranslations.ps1 -Extract

# Build package
.\Create-MetadataPackage.ps1 -ProgramCode "neoipc_core"
```

### 3. Sync Organization Units

```powershell
# Import organisation unit hierarchy
.\Import-FromDHIS2.ps1 `
    -BaseUrl "https://production.dhis2.org" `
    -Credential $cred `
    -MetadataTypes @('organisationUnits', 'organisationUnitLevels', 'organisationUnitGroups') `
    -OutputPath "..\metadata\organisation-units"
```

### 4. Import Dashboards and Analytics

```powershell
# Import analytics objects
.\Import-FromDHIS2.ps1 `
    -BaseUrl "https://production.dhis2.org" `
    -Credential $cred `
    -MetadataTypes @('dashboards', 'visualizations', 'indicators', 'indicatorGroups') `
    -Filter "name:like:NeoIPC" `
    -OutputPath "..\metadata\analytics"
```

## Troubleshooting

### Authentication Errors

```
ERROR: DHIS2 API Error: 401 Unauthorized
```

**Solution**: Verify credentials and server URL.

```powershell
# Test connection
$cred = Get-Credential
Invoke-RestMethod -Uri "https://dhis2.org/api/me" -Credential $cred
```

### No Objects Found

```
No objects found
```

**Solution**: Check filter syntax or remove filter to see all objects.

```powershell
# List all option sets
.\Import-FromDHIS2.ps1 `
    -BaseUrl "https://dhis2.org" `
    -Credential $cred `
    -MetadataTypes @('optionSets')
```

### Unsupported Metadata Type

```
WARNING: Unsupported metadata type: customType
```

**Solution**: Use one of the supported types listed above. Check spelling and case sensitivity.

## Tips

1. **Start with program import**: Use `-ProgramCode` first to get all related metadata automatically

2. **Use filters strategically**: Narrow down large result sets with `-Filter` to avoid importing unnecessary objects

3. **Check output before committing**: Review imported YAML/CSV files before committing to ensure accuracy

4. **Backup first**: When using `-Force`, ensure you have backups of any existing metadata

5. **Combine with pattern detection**: Use `-DetectPatterns` to identify opportunities for generators

6. **Export in stages**: For large imports, export metadata type by type to avoid timeout issues

## See Also

- [Create-MetadataPackage.ps1](./Create-MetadataPackage.ps1) - Build packages from imported metadata
- [Update-MetadataTranslations.ps1](./Update-MetadataTranslations.ps1) - Manage translations
- [Deploy-MetadataPackage.ps1](./Deploy-MetadataPackage.ps1) - Deploy to DHIS2
- [metadata/README.md](../metadata/README.md) - Complete metadata management guide
