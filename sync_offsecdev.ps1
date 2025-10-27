<#
    OffsecDEV-Obsidian Sync

    Safe sync between local offline root and OneDrive Obsidian vault.

    Defaults to a non-destructive DryRun. Use -RunMode Execute to apply.

    Two-way sync copies newer files in both directions without deletions.
    One-way sync supports deletions with -PropagateDeletes.
#>

[CmdletBinding()] param(
    [Parameter(Mandatory=$false)]
    [string]$RootPath = 'C:\OffsecDEV\OffsecDEV_Root',

    [Parameter(Mandatory=$false)]
    [string]$CloudPath = 'C:\Users\joshp\OneDrive\Documents\Obsidian Vaults\OffsecDEV',

    [Parameter(Mandatory=$false)]
    [ValidateSet('RootToCloud','CloudToRoot','Bidirectional')]
    [string]$Direction = 'Bidirectional',

    [Parameter(Mandatory=$false)]
    [ValidateSet('DryRun','Execute')]
    [string]$RunMode = 'DryRun',

    [Parameter(Mandatory=$false)]
    [int]$ThreadCount = 8,

    [Parameter(Mandatory=$false)]
    [string[]]$ExcludeDirs = @('.git','node_modules','.sync','.trash','.recycle'),

    [Parameter(Mandatory=$false)]
    [string[]]$ExcludeFiles = @('desktop.ini','Thumbs.db','.DS_Store'),

    [Parameter(Mandatory=$false, HelpMessage='For one-way modes only: also remove files deleted on source (uses Robocopy /MIR).')]
    [switch]$PropagateDeletes,

    [Parameter(Mandatory=$false)]
    [string]$LogDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Determine script root for logging defaults even when PSScriptRoot is empty
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
if (-not $LogDirectory -or [string]::IsNullOrWhiteSpace($LogDirectory)) {
    $LogDirectory = Join-Path $scriptRoot 'logs'
}

function Write-Section {
    param([string]$Text)
    Write-Host "`n=== $Text ===" -ForegroundColor Cyan
}

function Assert-PathExists {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "${Label} path not found: $Path"
    }
}

function New-LogFile {
    if (-not (Test-Path -LiteralPath $LogDirectory)) {
        New-Item -ItemType Directory -Path $LogDirectory | Out-Null
    }
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    return Join-Path $LogDirectory "sync_${ts}.log"
}

function Invoke-RoboCopySafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination,
        [Parameter()][switch]$Mirror
    )

    $args = @()
    # Pass paths as raw strings; PowerShell handles quoting for spaces when invoking external commands
    $args += @($Source, $Destination)

    # Copy options
    if ($Mirror) {
        $args += '/MIR' # mirror tree incl. deletions
    } else {
        $args += '/E'   # copy subdirs, including Empty
    }

    # Preserve timestamps; copy Data, Attributes, Timestamps
    $args += @('/COPY:DAT','/DCOPY:T')
    # Robustness/perf
    $args += @('/R:1','/W:2',"/MT:$ThreadCount",'/NFL','/NDL','/NP','/TEE')

    # Newer-wins behavior; always avoid overwriting newer destination files
    $args += '/XO'

    # Exclusions
    if ($ExcludeDirs -and $ExcludeDirs.Count -gt 0) { $args += '/XD'; $args += $ExcludeDirs }
    if ($ExcludeFiles -and $ExcludeFiles.Count -gt 0) { $args += '/XF'; $args += $ExcludeFiles }

    # Dry run?
    $isDry = ($RunMode -eq 'DryRun')
    if ($isDry) { $args += '/L' }

    $logFile = New-LogFile
    $args += "/LOG:$logFile"

    # Display-friendly command string
    $dispArgs = $args | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
    Write-Host "robocopy $($dispArgs -join ' ')" -ForegroundColor DarkGray

    & robocopy @args | Write-Host
    $rc = $LASTEXITCODE

    # Robocopy exit codes: 0..7 are OK-ish; >=8 serious errors
    if ($rc -ge 8) {
        throw "Robocopy failed with exit code $rc. See log: $logFile"
    } else {
        Write-Host "Robocopy exit code: $rc (success or minor issues). Log: $logFile" -ForegroundColor Green
    }

    return $rc
}

# Validate environment and inputs
Write-Section 'Validating paths'
Assert-PathExists -Path $RootPath -Label 'Root'
Assert-PathExists -Path $CloudPath -Label 'Cloud'

if ($Direction -eq 'Bidirectional' -and $PropagateDeletes.IsPresent) {
    Write-Warning "-PropagateDeletes is ignored in Bidirectional mode to prevent accidental data loss."
}

Write-Host "Root:  $RootPath"
Write-Host "Cloud: $CloudPath"
Write-Host "Mode:  $Direction | $RunMode"
Write-Host "Deletes propagated: $($PropagateDeletes.IsPresent -and $Direction -ne 'Bidirectional')"

Write-Section 'Sync plan'
switch ($Direction) {
    'RootToCloud' {
        $mirror = $PropagateDeletes.IsPresent
        Write-Host "1) Root -> Cloud $(if($mirror){'(mirror with deletions)'}else{'(no deletions)'})"
        $null = Invoke-RoboCopySafe -Source $RootPath -Destination $CloudPath -Mirror:$mirror
    }
    'CloudToRoot' {
        $mirror = $PropagateDeletes.IsPresent
        Write-Host "1) Cloud -> Root $(if($mirror){'(mirror with deletions)'}else{'(no deletions)'})"
        $null = Invoke-RoboCopySafe -Source $CloudPath -Destination $RootPath -Mirror:$mirror
    }
    'Bidirectional' {
        Write-Host '1) Root -> Cloud (no deletions, newer-wins)'
        $null = Invoke-RoboCopySafe -Source $RootPath -Destination $CloudPath -Mirror:$false
        Write-Host '2) Cloud -> Root (no deletions, newer-wins)'
        $null = Invoke-RoboCopySafe -Source $CloudPath -Destination $RootPath -Mirror:$false
    }
}

Write-Section 'Done'
if ($RunMode -eq 'DryRun') {
    Write-Host 'Dry run only. Re-run with -RunMode Execute to apply changes.' -ForegroundColor Yellow
}
