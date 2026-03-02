# CLAUDE.md

## Project Overview

This is the **NeoIPC Surveillance Toolkit** — a comprehensive toolkit for healthcare-associated infection (HAI) surveillance in neonatology, focused on Very Low Birth Weight (VLBW) and Very Preterm (VPT) infants. It is maintained by The NeoIPC Project Consortium under the MIT license.

The repository produces multi-language clinical protocol documentation (HTML, PDF, DOCX) from AsciiDoc sources, backed by structured metadata for antibiotics, pathogens, and organisation units.

## Repository Structure

```
├── doc/                           # Documentation source files
│   ├── protocol/                  # Core protocol AsciiDoc files
│   │   ├── NeoIPC-Core-Protocol.adoc       # Main protocol document (~1000 lines)
│   │   ├── NeoIPC-Core-Protocol-Header.adoc
│   │   ├── definitions/           # Clinical definition includes (8 .adoc files)
│   │   ├── img/                   # SVG images and diagrams
│   │   ├── po4a/                  # Translation PO/POT files
│   │   ├── resx/                  # .NET resource files (translated strings for SVGs)
│   │   └── xslt/                  # XSLT transforms (title page, decision flow, etc.)
│   ├── locale/                    # Locale attribute files (attributes-{lang}.adoc)
│   ├── NeoIPC.theme.yml           # Asciidoctor PDF theme
│   ├── reference.docx             # Word template for DOCX output
│   └── .linthtmlrc.yaml           # HTML linter config
├── metadata/                      # Surveillance metadata (CSV format)
│   ├── common/
│   │   ├── antibiotics/           # Antibiotic data with ATC codes and AWaRe class
│   │   ├── pathogens/             # Pathogen concepts and synonyms (186K+ records)
│   │   ├── organisation_units/    # Country and NUTS region data
│   │   ├── optionSets.csv         # Option sets configuration
│   │   └── options.csv            # Options data
│   └── play/                      # Play/test instance metadata
├── reports/                       # Quarto-based reports (R)
│   ├── Validation Report/         # Data validation reports
│   ├── Reference Report/          # Reference reports
│   └── filters/                   # Pandoc Lua filters
├── scripts/                       # Build and utility scripts (PowerShell)
│   ├── Make-NeoIPC-Core-Protocol.ps1    # Main build script
│   ├── Create-MetadataPackage.ps1       # Metadata JSON packaging
│   ├── ConvertFrom-JsonMetadata.ps1     # JSON→CSV conversion
│   ├── Update-Translation.ps1           # Translation management
│   └── modules/
│       └── NeoIPC-Tools/
│           └── NeoIPC-Tools.psm1        # PowerShell utility module (~900 lines)
├── .github/workflows/build.yml    # GitHub Actions CI/CD
├── po4a.cfg                       # Translation config (po4a)
└── artifacts/                     # Build output directory (gitignored)
```

## Build System

### Primary Build Tool: PowerShell Core

The main build script is `scripts/Make-NeoIPC-Core-Protocol.ps1`. It generates documentation in multiple formats from AsciiDoc sources.

### Build Command

```powershell
# Build all formats for all locales (default)
./scripts/Make-NeoIPC-Core-Protocol.ps1

# Build specific formats
./scripts/Make-NeoIPC-Core-Protocol.ps1 -Html
./scripts/Make-NeoIPC-Core-Protocol.ps1 -Pdf
./scripts/Make-NeoIPC-Core-Protocol.ps1 -Docx

# Build for specific cultures
./scripts/Make-NeoIPC-Core-Protocol.ps1 -TargetCultures de,es

# Release build (no preview watermarks)
./scripts/Make-NeoIPC-Core-Protocol.ps1 -Release

# Clean build artifacts
./scripts/Make-NeoIPC-Core-Protocol.ps1 -Clean
```

### Build Pipeline

1. Generate antibiotic and pathogen AsciiDoc lists from CSV metadata
2. Generate SVG images (title page, decision flow, data collection sheets) via XSLT from .resx files
3. Generate HTML5 output via Asciidoctor, then lint with LintHTML
4. Generate DocBook XML intermediate format
5. Generate PDF via Asciidoctor PDF (with asciidoctor-mathematical on Linux)
6. Generate DOCX via Pandoc from DocBook

Build outputs go to `artifacts/`. The build system tracks dependencies and only rebuilds targets when inputs change.

### CI/CD

GitHub Actions workflow (`.github/workflows/build.yml`) triggers on:
- Push to `main`
- All pull requests
- Tags
- Manual dispatch

CI steps: install dependencies → run po4a translations → run PowerShell build → upload artifacts.

The CI build uses `-WarningAction:Stop` to treat warnings as errors.

## Required Dependencies

- **PowerShell 7+** — build orchestration
- **Ruby gems:** asciidoctor-pdf, asciidoctor-bibtex, asciidoctor-diagram, asciidoctor-mathematical, asciimath, mathematical:1.6.18
- **Node.js:** @linthtml/linthtml (HTML validation)
- **Pandoc** — DocBook to DOCX conversion
- **librsvg2** (rsvg-convert) — SVG rendering
- **po4a** — translation management
- **Noto Sans font** — document rendering

See `doc/README.md` for full installation instructions (Windows and Ubuntu).

## Internationalization (i18n)

### Supported Languages

- **en** (English) — source language
- **de** (German)
- **es** (Spanish)
- **it** (Italian)
- **tr** (Turkish)

### Translation Workflow

- **Tool:** po4a (configured in `po4a.cfg`)
- **Flow:** AsciiDoc → POT template → PO files per language → localized AsciiDoc
- **Locale attributes:** `doc/locale/attributes-{lang}.adoc`
- **Resource strings:** `.resx` files in `doc/protocol/resx/` (translated via po4a to generate localized SVGs)
- **Metadata translations:** `metadata/common/{category}/NeoIPC-*.{lang}.csv`

Localized files follow the naming convention: `FileName.{lang}.ext` (e.g., `NeoIPC-Core-Protocol.de.adoc`).

## Code Conventions

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

### Metadata (CSV)

- UTF-8 encoding (BOM optional for Excel compatibility)
- RFC 4180 compliant CSV format
- Standardized columns: `id`, `code`, `name`, plus translation columns
- Pipe-delimited (`|`) for structured sub-lists within fields

### HTML Linting Rules (`doc/.linthtmlrc.yaml`)

- `id-no-dup`: error — no duplicate IDs
- `id-style`: error, dash — IDs must use dash-case
- `class-style`: error, bem — CSS classes must follow BEM naming
- Footnote IDs matching `^_footnote.+$` are ignored

## Generated Files (Do Not Edit)

The following files are generated by the build and listed in `.gitignore`:

- `artifacts/` — all build output
- `doc/protocol/NeoIPC-Antibiotics*.adoc` — generated antibiotic lists
- `doc/protocol/NeoIPC-Infectious-Agents*.adoc` — generated pathogen lists
- `doc/protocol/NeoIPC-Core-Protocol*.xml` — DocBook intermediates
- `doc/protocol/img/NeoIPC-Core-Decision-Flow*.svg` — generated SVGs
- `doc/protocol/img/NeoIPC-Core-Master-Data-Collection-Sheet*.svg`
- `doc/protocol/img/NeoIPC-Core-Title-Page*.svg`
- `doc/protocol/img/Preview-Watermark*.svg`

## Key Utility Functions (NeoIPC-Tools Module)

The PowerShell module at `scripts/modules/NeoIPC-Tools/NeoIPC-Tools.psm1` provides:

- `Build-Target` — dependency-aware build target (skips if output is newer than inputs)
- `Get-LocalisedPath` — resolves culture-specific file paths
- `Export-AsciiDocReferences` — extracts file references from AsciiDoc (respects ifdef/ifndef)
- `Export-AsciiDocIds` — extracts anchor IDs from AsciiDoc files
- `New-AntibioticsList` — generates antibiotic list AsciiDoc from CSV metadata
- `New-PathogenList` — generates pathogen list AsciiDoc from CSV metadata

## Working With This Repository

### Adding a New Clinical Definition

1. Create the definition file in `doc/protocol/definitions/` following the naming pattern `NeoIPC-Core-{Name}-Definition.adoc`
2. Add an `include::` directive in the main `NeoIPC-Core-Protocol.adoc`
3. Register the file in `po4a.cfg` for translation
4. Create corresponding translation PO entries

### Updating Metadata

1. Edit CSV files in `metadata/common/{category}/`
2. Run the build script to regenerate AsciiDoc lists
3. Translation CSVs follow `FileName.{lang}.csv` naming

### Adding a New Language

1. Add the language code to `po4a.cfg` `[po4a_langs]` line
2. Create `doc/locale/attributes-{lang}.adoc` with translated attributes
3. Create `.resx` files for SVG string translations
4. Create translated metadata CSVs where needed
5. Run `po4a` to generate initial translation PO files

### VSCode Integration

The `.vscode/` directory contains:
- `tasks.json` — build tasks (default build runs `Make-NeoIPC-Core-Protocol.ps1`)
- `launch.json` — PowerShell debug configurations
