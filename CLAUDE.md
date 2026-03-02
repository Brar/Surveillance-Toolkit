# CLAUDE.md

## Project Overview

This is the **NeoIPC Surveillance Toolkit** — a comprehensive toolkit for healthcare-associated infection (HAI) surveillance in neonatology, focused on Very Low Birth Weight (VLBW) and Very Preterm (VPT) infants. It is maintained by The NeoIPC Project Consortium under the MIT license.

The toolkit includes:

- **Validation Report** (active focus) — Quarto/R-based per-site data quality reports generated from the NeoIPC DHIS2 instance
- **Reference Report** (planned) — epidemiological benchmark reporting across participating sites
- **Partner Certificate** (planned, not yet in repo) — recognition documents for participating sites
- **Core Protocol** (on hold) — multi-language clinical protocol documentation (HTML, PDF, DOCX) from AsciiDoc sources
- **Surveillance metadata** — structured data for antibiotics, pathogens, and organisation units (CSV/YAML)

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
│   ├── Validation Report/         # Data validation reports (en, de)
│   │   ├── Validation Report.qmd  # Main Quarto document (orchestrator)
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
│   ├── Reference Report/          # Reference reports (stub — translations only)
│   │   └── translations/          # en.json, de.json (329 keys each)
│   └── filters/                   # Pandoc Lua filters
│       └── pandoc-quotes.lua      # Typographic quotation marks (language-aware)
├── metadata/                      # Surveillance metadata
│   ├── common/
│   │   ├── antibiotics/           # Antibiotic data with ATC codes and AWaRe class
│   │   ├── pathogens/             # Pathogen concepts and synonyms (186K+ records)
│   │   ├── organisation_units/    # Country and NUTS region data
│   │   ├── optionSets.csv         # DHIS2 option sets (legacy)
│   │   └── options.csv            # DHIS2 options (legacy)
│   └── play/                      # Play/test instance metadata
├── doc/                           # Protocol documentation (ON HOLD)
│   ├── protocol/                  # Core protocol AsciiDoc files
│   │   ├── NeoIPC-Core-Protocol.adoc
│   │   ├── definitions/           # Clinical definition includes
│   │   ├── img/                   # SVG images and diagrams
│   │   ├── po4a/                  # Translation PO/POT files
│   │   ├── resx/                  # .NET resource files (TO BE REMOVED — see i18n)
│   │   └── xslt/                  # XSLT transforms
│   ├── locale/                    # Locale attribute files (attributes-{lang}.adoc)
│   └── NeoIPC.theme.yml           # Asciidoctor PDF theme
├── scripts/                       # Build and utility scripts (PowerShell)
│   ├── Make-NeoIPC-Core-Protocol.ps1    # Protocol build script (on hold)
│   ├── Create-MetadataPackage.ps1       # DHIS2 metadata packaging (legacy)
│   ├── ConvertFrom-JsonMetadata.ps1     # DHIS2 JSON→CSV (legacy)
│   ├── Update-Translation.ps1           # Translation management
│   └── modules/
│       └── NeoIPC-Tools/                # PowerShell utility module (needs rework)
├── .github/workflows/build.yml    # GitHub Actions CI/CD
├── po4a.cfg                       # Translation config (po4a)
└── artifacts/                     # Build output directory (gitignored)
```

## Validation Report

### Overview

The Validation Report is a Quarto/R-based report that validates surveillance data quality per participating site. It connects to the NeoIPC DHIS2 instance, runs 42 validation rules, and produces a PDF report with problems, explanations, and solutions — all localized.

**Architecture:** 42 validation problems → 20 problem details → 15 solutions (many-to-many mapping defined in `_mapping.qmd`).

### Building

```powershell
# From the "reports/Validation Report/" directory
./build-reports.ps1                          # All departments, English
./build-reports.ps1 -Language de             # German
./build-reports.ps1 -SiteCodeFilter 'DE_.*'  # Filter by site code regex
```

The script reads a DHIS2 API token from `../../../token.txt`, fetches the department list, and renders one PDF per department.

**Output:** `_output/YYYY-MM-DD_HHmmss_NeoIPC-Surveillance-Validation-Report_[SITE].[LANG].pdf`

### Dependencies

- **R 4.x+** with packages: tidyverse, pak
- **neoipcr** — custom package from GitHub (`Brar/neoipcr@initial_tests`), installed automatically
- **Quarto** (with bundled Pandoc)
- **PowerShell 7+** for the build script
- **DHIS2 API token** in `token.txt`

### Current Localization (en, de)

Language-specific content lives in `en/` and `de/` subdirectories:
- `_strings.qmd` — all 42 problem descriptions + UI strings
- `_problem_detail_NNNN.qmd` — 21 problem detail pages
- `_solution_NNNN.qmd` — 16 solution pages
- `_problems_intro.qmd`, `_problem_details_intro.qmd`, `_solutions_intro.qmd`

Quarto profiles (`_quarto-en.yml`, `_quarto-de.yml`) configure language, title, author, and metadata per language.

### Localization Plan

The Validation Report will be the first deliverable to receive full localization via the new i18n infrastructure (see below). The approach is hybrid: po4a for prose content, Quarto's built-in features for format-level strings (dates, figure labels, section numbering).

## Internationalization (i18n)

### Language Tiers

**Tier 1 — Active participant languages** (top priority):
- **en** (English) — source language (UK, South Africa, Nepal, Switzerland)
- **de** (German) — Germany, Switzerland
- **es** (Spanish) — Spain
- **it** (Italian) — Italy, Switzerland
- **el** (Greek) — Greece
- **et** (Estonian) — Estonia

**Tier 2 — Participant languages requiring assessment:**
- **ne** (Nepali) — Nepal
- **fr** (French) — Switzerland

**Tier 3 — Native speaker access available:**
- **tr** (Turkish) — team member is a native speaker
- **he** (Hebrew) — friend is a native speaker; first RTL language (important for identifying RTL-specific issues)

### Translation Toolchain

- **Weblate** (free account) — web-based translation management with good PO file support
- **po4a** — converts between source formats and PO/POT files (configured in `po4a.cfg`)
- **Flow:** Source files → po4a → POT template → Weblate → PO files per language → po4a → localized output

### Supported Localization Formats

All localizable content must use formats with good po4a support:

| Format | po4a module | Used for |
|--------|-------------|----------|
| AsciiDoc | `asciidoc` | Protocol documents, clinical definitions |
| Text (markdown flavour) | `text -o markdown` | Quarto report prose (.qmd content sections) |
| LaTeX | `latex` | Small amount of LaTeX content |
| YAML | `yaml` | Localizable metadata (replacing CSV translations) |

### Formats Being Removed

- **`.resx` files** — .NET resource XML files in `doc/protocol/resx/` are being eliminated. Localizable strings will move to po4a-compatible formats.
- **Translated CSV columns** — localizable parts of metadata CSVs will move to YAML files. CSV remains for non-localizable structured data. YAML→XLSX conversion scripts will be created if Excel interchange is needed.

### Current Translation State

| Language | Protocol PO | Protocol locale | Report content | Metadata |
|----------|-------------|-----------------|----------------|----------|
| **en** | source | complete | complete | source |
| **de** | ~57% | complete | complete | complete |
| **es** | ~59% | complete | — | complete |
| **it** | — | complete | — | — |
| **tr** | — | incomplete | — | — |
| **el–he** | — | — | — | — |

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
- YAML for localizable content (po4a-compatible)
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
- `reports/Validation Report/_output/` — generated report PDFs/HTML
- `doc/protocol/NeoIPC-Antibiotics*.adoc` — generated antibiotic lists
- `doc/protocol/NeoIPC-Infectious-Agents*.adoc` — generated pathogen lists
- `doc/protocol/NeoIPC-Core-Protocol*.xml` — DocBook intermediates
- `doc/protocol/img/NeoIPC-Core-Decision-Flow*.svg` — generated SVGs
- `doc/protocol/img/NeoIPC-Core-Master-Data-Collection-Sheet*.svg`
- `doc/protocol/img/NeoIPC-Core-Title-Page*.svg`
- `doc/protocol/img/Preview-Watermark*.svg`

## Known Issues

- **NeoIPC-Tools module manifest** (`scripts/modules/NeoIPC-Tools/NeoIPC-Tools.psd1`): comment says "AsciiDocTools" instead of "NeoIPC-Tools"; exports `Get-Properties` but the function is actually `Get-ObjectProperties`
- **Protocol build `-Clean`** doesn't remove generated SVGs (TODO in script)
- **German .resx** for data collection sheet only has 2 of 14 entries translated
- **Italian and Turkish** have locale attribute files but no actual translations yet
- **`transform-svg.xslt`** appears unused by the build pipeline
