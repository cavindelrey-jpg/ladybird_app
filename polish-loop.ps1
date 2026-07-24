# polish-loop.ps1
# PowerShell port of polish/loop.sh (bash), for a native Windows setup
# with no WSL/Git Bash required.
#
# Run from the project root (same folder as pubspec.yaml and CLAUDE.md):
#   .\polish-loop.ps1                                    # uses polish/TASKS.md
#   .\polish-loop.ps1 -TasksFile polish/TASKS_PERF.md     # a different task file
#   .\polish-loop.ps1 -MaxRuns 5                          # cap how many tasks this run
#
# Requires: claude CLI on PATH, flutter/dart on PATH, a git repo with a
# CLEAN working tree (uncommitted changes are refused — commit or stash
# first, same as the bash original).

param([int]$MaxRuns = 999, [string]$TasksFile = "polish/TASKS.md")

$LogDir = "polish/logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

if (-not (Test-Path $TasksFile)) {
    Write-Host "Missing $TasksFile -- run this from the repo root." -ForegroundColor Red
    exit 1
}

$gitStatus = git status --porcelain
if ($gitStatus) {
    Write-Host "Working tree isn't clean. Commit or stash before running the loop." -ForegroundColor Red
    Write-Host $gitStatus
    exit 1
}

function Get-NextTask {
    $lines = Get-Content $TasksFile
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^\- \[ \] (.+)$') {
            return @{ LineNumber = $i; Text = $Matches[1] }
        }
    }
    return $null
}

$runCount = 0

Write-Host "Starting the polish loop (max $MaxRuns tasks)."
Write-Host "This will not ask you anything mid-task. Check polish/logs/ and git log if you want to watch progress."

while ($runCount -lt $MaxRuns) {
    $task = Get-NextTask
    if ($null -eq $task) {
        Write-Host ""
        Write-Host "No unchecked tasks left in $TasksFile. Done."
        break
    }

    $runCount++
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $logFile = Join-Path $LogDir "$ts.json"

    Write-Host ""
    Write-Host "=== Task $runCount : $($task.Text) ==="

    $prompt = "Read CLAUDE.md in the project root for conventions and known gotchas. Your task, exactly this and only this: $($task.Text)`n`nWhen done: run flutter analyze and fix anything it flags as a result of this change. If analyze is clean, git add the changed files and commit with a clear one-line message describing the change. Then, in polish/TASKS.md, change the line for this task from '- [ ] $($task.Text)' to '- [x] $($task.Text)' and commit that as part of the same commit. If this task turns out to be too large for one reviewable commit, instead split it into sub-checkboxes under the same TASKS.md section (mark the original unchecked, add 2-4 smaller '- [ ]' items describing the pieces) and commit just that TASKS.md split -- do not attempt the whole thing in one diff. Never change public widget or API signatures used across files without grepping for every call site first and updating them in the same commit. Never make a behavior change and call it polish. If flutter/dart don't resolve on PATH, find the full executable path first (see CLAUDE.md known gotchas) before giving up."

    $job = Start-Job -ScriptBlock {
        param($p, $workDir)
        Set-Location $workDir
        & claude -p $p --dangerously-skip-permissions --output-format json
    } -ArgumentList $prompt, $PWD.Path

    $taskStart = Get-Date
    while ($job.State -eq 'Running') {
        Start-Sleep -Seconds 15
        $elapsed = [int]((Get-Date) - $taskStart).TotalMinutes
        Write-Host "  ...still working on task $runCount (${elapsed}m elapsed)"
    }

    $rawResult = Receive-Job -Job $job
    Remove-Job -Job $job

    $rawResult | Out-File -FilePath $logFile -Encoding utf8

    try {
        $result = $rawResult | ConvertFrom-Json
        Write-Host $result.result
    } catch {
        Write-Host "Task $runCount produced no parseable output -- check $logFile"
    }

    # Safety net: if the model claimed success but never actually
    # committed (e.g. it hit a wall and just talked about the problem),
    # don't silently loop forever re-attempting the same broken task --
    # stop and let the human look, same spirit as the bash original's
    # clean-tree requirement.
    $stillDirty = git status --porcelain
    if ($stillDirty) {
        Write-Host ""
        Write-Host "Task $runCount left uncommitted changes -- stopping so you can review before continuing." -ForegroundColor Yellow
        Write-Host $stillDirty
        break
    }
}

Write-Host ""
Write-Host "Polish loop stopped after $runCount task(s)."
Write-Host "Check 'git log --oneline' and polish/TASKS.md for what actually happened."
