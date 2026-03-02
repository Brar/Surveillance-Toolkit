# CLAUDE.md

## Project Overview

This is the **NeoIPC Surveillance Toolkit** — a comprehensive toolkit for healthcare-associated infection (HAI) surveillance in neonatology, focused on Very Low Birth Weight (VLBW) and Very Preterm (VPT) infants. It is maintained by The NeoIPC Project Consortium. Code is MIT-licensed. Documentation and certain metadata files may be subject to different licensing terms — see individual files for details.

The toolkit includes:

- **Validation Report** (active focus) — Quarto/R-based per-site data quality reports generated from the NeoIPC DHIS2 instance
- **Partner Report** — Quarto/R-based per-site performance reports with analytics and outlier detection
- **Partner Certificate** — participation certificates for partner hospitals
- **Reference Report** — epidemiological benchmark reporting across participating sites
- **Core Protocol** (on hold) — multi-language clinical protocol documentation (HTML, PDF, DOCX) from AsciiDoc sources
- **Surveillance metadata** — structured data for antibiotics, infectious agents, and organisation units (CSV/YAML)

### Current Participants

NeoIPC has participants from: Estonia, Germany, Greece, Italy, Nepal, South Africa, Spain, Switzerland, and the United Kingdom.

### Current Priorities

1. **Validation Report** — most important deliverable; first to receive full localization support
2. **Reference Report** — follows after Validation Report
3. **Partner Certificate** — follows after Reference Report
4. **Core Protocol & build scripts** — low priority; will resume in a separate branch
5. **DHIS2 metadata scripts** — legacy/experimental; will be reworked in a separate branch
6. **NeoIPC-Tools module** — needs rethinking and reworking alongside future build/CI updates

## Repository Structure

```
├── reports/                       # Quarto-based reports (R) — ACTIVE FOCUS
│   ├── Validation-Report/         # Data validation reports (en, de)
│   │   ├── Validation-Report.qmd  # Main Quarto document (orchestrator)
│   │   ├── build-reports.ps1      # PowerShell build script
│   │   ├── _quarto.yml            # Shared Quarto config
│   │   ├── _quarto-{lang}.yml     # Language-specific Quarto profiles
│   │   ├── _setup.qmd             # R setup (packages, DHIS2 data import)
│   │   ├── _mapping.qmd           # Problem↔detail↔solution mappings
│   │   ├── _problems.qmd          # Problem aggregation and rendering
│   │   ├── _formatters.qmd        # 42 problem formatter functions
│   │   ├── rules/                 # 42 validation rule files (_rule_0001–0042.qmd)
│   │   ├── en/                    # English strings, problem details, solutions
│   │   ├── de/                    # German strings, problem details, solutions
│   │   └── img/                   # Screenshots and diagrams
│   ├── Partner-Report/            # Per-site performance reports
│   │   ├── Partner-Report.qmd     # Main Quarto document (English source)
│   │   ├── Partner-Report.de.qmd  # German (po4a-generated)
│   │   ├── build-partner-reports.ps1
│   │   ├── _quarto.yml, _quarto-en.yml, _quarto-full.yml, _quarto-minimal.yml
│   │   ├── _setup.qmd, _header.qmd, _content.qmd, _brand.yml
│   │   ├── content/, figures/, tables/   # Report content sections
│   │   └── translations.tex       # LaTeX translation strings
│   ├── Partner-Certificate/       # Participation certificates
│   │   ├── Partner-Certificate.qmd       # English source
│   │   ├── Partner-Certificate.{de,it}.qmd  # Localized (po4a-generated)
│   │   ├── _quarto.yml, _quarto-en.yml
│   │   └── _setup.qmd, _content.qmd, title.tex, before-body.tex
│   ├── Reference-Report/          # Epidemiological benchmark reports
│   │   ├── Reference-Report.qmd   # English source
│   │   ├── Reference-Report.{de,es,et,gr,it}.qmd  # Localized (po4a-generated)
│   │   ├── _quarto.yml, _quarto-en.yml, _quarto-minimal.yml
│   │   ├── _setup.qmd, _header.qmd, _content.qmd, _brand.yml
│   │   ├── content/, figures/, tables/
│   │   ├── Generate-ReferenceData.R, getReferenceData.R
│   │   └── translations.tex
│   ├── common/                    # Shared report infrastructure
│   │   ├── _language.yml          # Multilingual UI strings
│   │   ├── helpers.R              # Shared R utilities
│   │   ├── getDataset.R           # Data access patterns
│   │   └── reference.docx, reference.pptx  # Output templates
│   ├── common.yaml                # Master configuration for all reports
│   ├── logos/                     # Shared branding assets
│   ├── filters/                   # Pandoc Lua filters
│   │   └── pandoc-quotes.lua      # Typographic quotation marks (language-aware)
│   ├── .gitignore
│   └── .lintr                     # R linting config
├── po/                            # Centralized translation (po4a)
│   ├── documentation.po4a.cfg     # Protocol AsciiDoc translations
│   ├── glossary.po4a.cfg          # Glossary translations
│   ├── infectious_agents.po4a.cfg # Infectious agent YAML/AsciiDoc translations
│   ├── reports.po4a.cfg           # All report translations (YAML, markdown, LaTeX)
│   ├── *.pot                      # POT templates (generated)
│   └── *.{lang}.po                # PO files per language
├── metadata/                      # Surveillance metadata
│   ├── common/
│   │   ├── antibiotics/           # Antibiotic data with ATC codes and AWaRe class
│   │   ├── infectious-agents/     # Infectious agent taxonomy (YAML is primary; CSV files are mostly legacy)
│   │   ├── organisation_units/    # Country and NUTS region data
│   │   ├── optionSets.csv         # DHIS2 option sets (legacy)
│   │   └── options.csv            # DHIS2 options (legacy)
│   └── play/                      # Play/test instance metadata
├── doc/                           # Protocol documentation (ON HOLD)
│   ├── protocol/                  # Core protocol AsciiDoc files
│   │   ├── NeoIPC-Core-Protocol.adoc
│   │   ├── definitions/           # Clinical definition includes
│   │   ├── img/                   # SVG images and diagrams
│   │   ├── resx/                  # .NET resource files (TO BE REMOVED — see i18n)
│   │   └── xslt/                  # XSLT transforms
│   ├── locale/                    # Locale attribute files (attributes-{lang}.adoc)
│   └── NeoIPC.theme.yml           # Asciidoctor PDF theme
├── scripts/                       # Build and utility scripts (PowerShell)
│   ├── Build-PartnerReports.ps1   # Batch partner report generation
│   ├── Build-ReferenceReport.ps1  # Reference report generation
│   ├── Convert-InfectiousAgentList.ps1  # YAML→AsciiDoc/CSV/PDF conversion
│   ├── New-PartnerCertificate.ps1 # Single certificate generation
│   ├── Test-PoPlaceholders.ps1    # Translation placeholder validation
│   ├── Update-Po4aYamlKeys.ps1    # Translation config management
│   ├── Update-Translation.ps1     # Translation management
│   ├── Make-NeoIPC-Core-Protocol.ps1    # Protocol build script (on hold)
│   ├── Create-MetadataPackage.ps1       # DHIS2 metadata packaging (legacy)
│   ├── ConvertFrom-JsonMetadata.ps1     # DHIS2 JSON→CSV (legacy)
│   └── modules/
│       └── NeoIPC-Tools/                # PowerShell utility module (needs rework)
├── docs/                          # Design documentation
│   ├── Infctious_agent_ontology_design.md
│   └── unit-test-infectious-agent-detection-rates.md
├── common/logos/                   # Brand assets (CC/BY license logos)
├── tools/po4a                     # po4a as git submodule
├── glossary.yaml                  # Centralized multilingual glossary
├── .github/workflows/build.yml    # GitHub Actions CI/CD
├── .gitmodules                    # Git submodule config (po4a)
└── artifacts/                     # Build output directory (gitignored)
```

## Reports

### Validation Report

The Validation Report validates surveillance data quality per participating site. It connects to the NeoIPC DHIS2 instance, runs 42 validation rules, and produces a PDF report with problems, explanations, and solutions — all localized.

**Architecture:** 42 validation problems → 20 problem details → 15 solutions (many-to-many mapping defined in `_mapping.qmd`).

```powershell
# From reports/Validation-Report/
./build-reports.ps1                          # All departments, English
./build-reports.ps1 -Language de             # German
./build-reports.ps1 -SiteCodeFilter 'DE_.*'  # Filter by site code regex
```

### Partner Report

Per-site performance reports with analytics, outlier detection, and comparative metrics. Supports multiple output profiles (default, full, minimal).

```powershell
# From repo root
./scripts/Build-PartnerReports.ps1
```

### Partner Certificate

Participation certificates for partner hospitals. Can pull data from DHIS2 or accept manual parameters. Currently supports en, de, it.

```powershell
./scripts/New-PartnerCertificate.ps1
```

### Reference Report

Epidemiological benchmark reporting across participating sites. Country-level filtering with selective element inclusion.

```powershell
./scripts/Build-ReferenceReport.ps1
```

### Shared Infrastructure

- `reports/common.yaml` — master configuration for all reports
- `reports/common/_language.yml` — multilingual UI strings shared across reports
- `reports/common/helpers.R` — shared R utilities
- `reports/common/getDataset.R` — data access patterns
- `reports/filters/pandoc-quotes.lua` — language-aware typographic quotation marks

### Report Dependencies

- **R 4.x+** with packages: tidyverse, pak
- **neoipcr** — custom R package from GitHub (`Brar/neoipcr`). The Validation Report currently uses the legacy `initial_tests` branch, but the plan is to port it to the newer integrated validation in more recent neoipcr branches (WIP).
- **Quarto** (with bundled Pandoc)
- **PowerShell 7+** for build scripts
- **DHIS2 authentication** — configured via neoipcr (supports multiple authentication methods)

## Internationalization (i18n)

### Languages

**Participant languages** (top priority — casual languages of current NeoIPC participants):
- **en** (English) — source language (UK, South Africa, Nepal, Switzerland)
- **de** (German) — Germany, Switzerland
- **es** (Spanish) — Spain
- **it** (Italian) — Italy, Switzerland
- **el** (Greek) — Greece
- **et** (Estonian) — Estonia
- **ne** (Nepali) — Nepal
- **fr** (French) — Switzerland

**Additional languages with native speaker access:**
- **tr** (Turkish)
- **he** (Hebrew) — first RTL language (important for identifying RTL-specific issues)

### Translation Toolchain

- **Weblate** (free account) — web-based translation management with good PO file support
- **po4a** (bundled as git submodule in `tools/po4a`) — converts between source formats and PO/POT files
- **Flow:** Source files → po4a → POT template → Weblate → PO files per language → po4a → localized output

### Modular po4a Configuration

Translation configs are in the `po/` directory, organized by component:

| Config file | Scope | Formats |
|-------------|-------|---------|
| `po/reports.po4a.cfg` | All reports (Partner, Reference, Certificate, Validation) | YAML, markdown (text), LaTeX |
| `po/documentation.po4a.cfg` | Protocol AsciiDoc files | AsciiDoc |
| `po/infectious_agents.po4a.cfg` | Infectious agent taxonomy | YAML, AsciiDoc |
| `po/glossary.po4a.cfg` | Centralized glossary | YAML |

### Supported Localization Formats

All localizable content must use formats with good po4a support:

| Format | po4a module | Used for |
|--------|-------------|----------|
| AsciiDoc | `asciidoc` | Protocol documents, clinical definitions |
| Text (markdown flavour) | `text -o markdown` | Quarto report prose (.qmd content sections) |
| LaTeX | `latex` | Small amount of LaTeX content (translations.tex) |
| YAML | `yaml` | Report config, glossary, localizable metadata |

### Formats Being Removed

- **`.resx` files** — .NET resource XML files in `doc/protocol/resx/` are being eliminated. Localizable strings will move to po4a-compatible formats.
- **Translated CSV columns** — localizable parts of metadata CSVs will move to YAML files. CSV remains for non-localizable structured data. YAML→XLSX conversion scripts will be created if Excel interchange is needed.

### Current Translation State

| Language | Reports PO | Protocol PO | Infectious agents PO | Glossary PO |
|----------|-----------|-------------|---------------------|-------------|
| **en** | source | source | source | source |
| **de** | yes | yes | yes | yes |
| **es** | yes | yes | yes | — |
| **it** | yes | — | — | — |
| **et** | yes | — | — | — |
| **gr** | yes | — | — | — |

## Code Conventions

### R / Quarto

- Tidyverse style throughout (dplyr verbs, tibbles, pipe operators)
- Validation rules as individual `.qmd` files (`_rule_NNNN.qmd`)
- Language strings in structured R lists within `_strings.qmd`
- `sprintf()` for parameterized problem descriptions
- `echo: false` in Quarto config (hide code in output)
- KOMA document class (`scrartcl`) for PDF output
- Pandoc Lua filters for typographic quotes

### PowerShell

- Use `CmdletBinding` with explicit parameter declarations
- PascalCase for function and parameter names (Verb-Noun pattern)
- Comment-based help for public functions
- Support `-Verbose`, `-Debug`, `-WhatIf`, `-Confirm` where appropriate
- UTF-8 encoding without BOM (`utf8NoBOM`) for output files
- Culture-aware operations using `[CultureInfo]` objects
- Error handling with `Write-Error` and `$?` checking

### AsciiDoc

- Standard Asciidoctor syntax with extensions
- Attribute-driven conditional includes (`ifdef::`, `ifndef::`)
- Cross-references via `[[id]]` or `[#id]` anchors
- STEM expressions for mathematical notation (AsciiMath syntax)
- Image paths relative to document location
- UTF-8 encoding required

### Metadata (CSV / YAML)

- UTF-8 encoding (BOM optional for Excel compatibility in CSV)
- RFC 4180 compliant CSV format for structured data
- YAML for localizable content and hierarchical data (po4a-compatible)
- Standardized columns: `id`, `code`, `name`
- Pipe-delimited (`|`) for structured sub-lists within CSV fields

## Protocol Build System (On Hold)

The protocol build is low priority and will resume in a separate branch. For reference:

- **Build script:** `scripts/Make-NeoIPC-Core-Protocol.ps1`
- **Formats:** HTML (Asciidoctor + LintHTML), PDF (Asciidoctor PDF), DOCX (Pandoc from DocBook)
- **Dependencies:** PowerShell 7+, Ruby gems (asciidoctor-pdf, etc.), Node.js (linthtml), Pandoc, librsvg2, po4a, Noto Sans font
- **CI/CD:** `.github/workflows/build.yml` — triggers on push to main, PRs, tags, manual dispatch

See `doc/README.md` for full installation instructions.

## Generated Files (Do Not Edit)

The following files are generated by builds and listed in `.gitignore`:

- `artifacts/` — all protocol build output
- `reports/*/_output/` — generated report PDFs/HTML
- `reports/*/Reference-Report.{lang}.qmd` etc. — po4a-generated localized .qmd files
- `doc/protocol/NeoIPC-Antibiotics*.adoc` — generated antibiotic lists
- `doc/protocol/NeoIPC-Infectious-Agents*.adoc` — generated infectious agent lists
- `doc/protocol/NeoIPC-Core-Protocol*.xml` — DocBook intermediates
- `doc/protocol/img/NeoIPC-Core-Decision-Flow*.svg` — generated SVGs
- `doc/protocol/img/NeoIPC-Core-Master-Data-Collection-Sheet*.svg`
- `doc/protocol/img/NeoIPC-Core-Title-Page*.svg`
- `doc/protocol/img/Preview-Watermark*.svg`

## Known Issues

- **NeoIPC-Tools module manifest** (`scripts/modules/NeoIPC-Tools/NeoIPC-Tools.psd1`): comment says "AsciiDocTools" instead of "NeoIPC-Tools"; exports `Get-Properties` but the function is actually `Get-ObjectProperties`
- **Protocol build `-Clean`** doesn't remove generated SVGs (TODO in script)
- **German .resx** for data collection sheet only has 2 of 14 entries translated
- **`transform-svg.xslt`** appears unused by the build pipeline
- **`docs/` typo**: `Infctious_agent_ontology_design.md` (missing 'e' in Infectious)
