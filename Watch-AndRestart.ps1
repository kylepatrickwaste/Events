# Watch-AndRestart.ps1
# Polls GitHub for new commits every 60 seconds.
# On a new commit: git pull, then restart the API via `dotnet run`.
#
# Usage: .\Watch-AndRestart.ps1
# Optional overrides:
#   .\Watch-AndRestart.ps1 -PollSeconds 30 -Branch main

param(
    [string]$RepoRoot   = $PSScriptRoot,
    [string]$ApiProject = "artifacts\dotnet-api\src\Events.Api\Events.Api.csproj",
    [string]$Branch     = "main",
    [int]   $PollSeconds = 30
)

$ErrorActionPreference = "Stop"
$apiProcess = $null

function Write-Status([string]$msg, [string]$color = "Cyan") {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $msg" -ForegroundColor $color
}

function Get-RemoteCommit {
    # Ask GitHub directly — no auth needed for public repos, no local fetch required.
    $remote = git -C $RepoRoot ls-remote origin "refs/heads/$Branch" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "ls-remote failed: $remote" }
    return ($remote -split "\s+")[0]
}

function Get-LocalCommit {
    return (git -C $RepoRoot rev-parse HEAD 2>&1).Trim()
}

function Start-Api {
    Write-Status "Starting API  (dotnet run)..." "Green"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = "dotnet"
    $psi.Arguments = "run --project `"$ApiProject`""
    $psi.WorkingDirectory = $RepoRoot
    $psi.UseShellExecute = $false
    # Inherit the parent console so you see API output in this window
    $psi.RedirectStandardOutput = $false
    $psi.RedirectStandardError  = $false
    $proc = [System.Diagnostics.Process]::Start($psi)
    Write-Status "API started  (PID $($proc.Id))" "Green"
    return $proc
}

function Stop-Api([System.Diagnostics.Process]$proc) {
    if ($proc -and -not $proc.HasExited) {
        Write-Status "Stopping API (PID $($proc.Id))..." "Yellow"
        # Kill the process tree so child processes don't linger
        taskkill /PID $proc.Id /T /F 2>&1 | Out-Null
        $proc.WaitForExit(5000) | Out-Null
        Write-Status "API stopped." "Yellow"
    }
}

function Pull-Latest {
    Write-Status "Pulling latest from origin/$Branch ..." "Magenta"
    $out = git -C $RepoRoot pull origin $Branch 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git pull failed:`n$out" }
    Write-Status $out "Gray"
}

# ── main loop ────────────────────────────────────────────────────────────────

Write-Status "Watcher starting. Repo: $RepoRoot  Branch: $Branch  Poll: ${PollSeconds}s" "White"

# Start the API immediately on launch
$apiProcess = Start-Api

# Give the API a moment to bind its port before we start polling
Start-Sleep -Seconds 3

$lastKnownCommit = Get-LocalCommit
Write-Status "Local HEAD: $lastKnownCommit" "Gray"

try {
    while ($true) {
        Start-Sleep -Seconds $PollSeconds

        try {
            $remoteCommit = Get-RemoteCommit

            if ($remoteCommit -ne $lastKnownCommit) {
                Write-Status "New commit detected: $remoteCommit" "Yellow"
                Stop-Api $apiProcess
                Pull-Latest
                $lastKnownCommit = Get-LocalCommit
                Write-Status "Now at: $lastKnownCommit" "Gray"
                $apiProcess = Start-Api
            }
            else {
                Write-Status "No changes. (HEAD: $($lastKnownCommit.Substring(0,7)))" "DarkGray"
            }
        }
        catch {
            Write-Status "Poll error (will retry): $_" "Red"
        }
    }
}
finally {
    # Ctrl+C or any exit — clean up the API process
    Stop-Api $apiProcess
    Write-Status "Watcher stopped." "White"
}
