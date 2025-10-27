OffsecDEV Obsidian Sync

Safe PowerShell sync between your offline root notes and your OneDrive Obsidian vault. Defaults to a non-destructive dry run and avoids deletions unless explicitly requested.

Paths
- Root: `C:\OffsecDEV\OffsecDEV_Root`
- Cloud: `C:\Users\joshp\OneDrive\Documents\Obsidian Vaults\OffsecDEV`

Features
- Dry run by default; add `-RunMode Execute` to apply changes
- Bidirectional safe sync (no deletions) using newer-wins logic
- One-way mirror modes with optional deletion propagation
- Excludes common noise files and directories
- Logs each run to `logs/`

Usage
- Dry run (default) bidirectional sync:
  `powershell -ExecutionPolicy Bypass -File sync_offsecdev.ps1`

- Execute bidirectional sync (no deletions, newer-wins both ways):
  `powershell -ExecutionPolicy Bypass -File sync_offsecdev.ps1 -RunMode Execute -Direction Bidirectional`

- One-way root → cloud, mirror with deletions:
  `powershell -ExecutionPolicy Bypass -File sync_offsecdev.ps1 -RunMode Execute -Direction RootToCloud -PropagateDeletes`

- One-way cloud → root, no deletions:
  `powershell -ExecutionPolicy Bypass -File sync_offsecdev.ps1 -RunMode Execute -Direction CloudToRoot`

- Custom paths and exclusions:
  `powershell -ExecutionPolicy Bypass -File sync_offsecdev.ps1 -RunMode Execute -Direction Bidirectional -RootPath "D:\Notes" -CloudPath "C:\Users\me\OneDrive\OffsecDEV" -ExcludeDirs ".git","node_modules" -ExcludeFiles "Thumbs.db",".DS_Store"`

Safety Notes
- Bidirectional mode never deletes; it only copies newer files both ways.
- Deletion propagation is available only in one-way modes via `-PropagateDeletes`.
- Review logs in `logs/` after each run; robocopy exit codes ≥ 8 indicate errors.

Robocopy Details
- Copies with `/E /COPY:DAT /DCOPY:T /R:1 /W:2 /MT:n /XO`
- Dry run adds `/L`; logging uses `/LOG:<file> /TEE`
- Exit codes 0–7 are considered success or minor issues; ≥ 8 is failure

Development
- Script: `sync_offsecdev.ps1`
- Requires Windows with `robocopy` available (built-in)

