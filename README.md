# countlines

A Free Pascal tool to count lines in Lazarus/Delphi projects (*.pas, *.pp, *.dpr, *.lfm). Outputs non-empty, code, comment, and empty line counts to console and CSV, designed for efficient code analysis.

## Features
- Counts lines in source files (*.pas, *.pp, *.dpr) and form files (*.lfm).
- Metrics for source files: Non-empty, Code (including code with trailing // comments), Comment (non-empty minus code), Empty.
- Metrics for form files: Total lines, Empty lines.
- Supports `{ ... }`, `(* ... *)`, and `//` comments.
- Warns on unclosed comment blocks.
- Ignores nested/malformed comments (bad practice).
- Outputs results to console and `line_counts.csv` in target directory.
- Safeguard for empty directories to prevent division-by-zero errors.

## Usage
```bash
fpc countlines.pas
./countlines [directory]
