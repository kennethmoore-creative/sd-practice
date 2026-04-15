# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

An R project for building statistical/structural dynamics (sd) models from scratch. Uses RStudio (`.Rproj` configured with 2-space indentation, UTF-8 encoding).

## Common Commands

Run R scripts from the terminal:
```bash
Rscript path/to/script.R
```

Launch an interactive R session:
```bash
R
```

Run a specific function or expression inline:
```bash
Rscript -e "source('path/to/script.R')"
```

## Project Conventions

- 2 spaces for indentation (per `.Rproj` settings)
- UTF-8 encoding throughout
- `.RData`, `.Rhistory`, and `.Renviron` are gitignored — do not commit session state or environment variables
