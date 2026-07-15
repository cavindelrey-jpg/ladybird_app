# loop4.ps1
# Fully unattended. Run from the project root (same folder as pubspec.yaml).
# You do not need to watch this or respond to anything — it will not ask.
# Usage:  .\loop4.ps1

$maxIterations = 25
$iteration = 0
$sessionId = $null

$basePrompt = "Read CLAUDE.md and TASKS_LOOP4.md in the project root. Work through the 4 sections in TASKS_LOOP4.md in order. Follow the 'Rules' section exactly: never stop and wait for input under any circumstance -- if something needs a live device, a design decision, or credentials, skip it, log one line to REPORT.md, and move on immediately. After each section, run flutter analyze and fix what it flags before moving on. Commit after each section completes clean. When you have gone through all 4 sections (or exhausted what's possible without a live device), run flutter build apk --debug as a final check, write a full summary to REPORT.md, and stop."

Write-Host "Starting the zero-intervention loop (max $maxIterations iterations)."
Write-Host "This will not ask you anything. Walk away if you want -- check back on REPORT.md and git log."

while ($iteration -lt $maxIterations) {
    $iteration++
    Write-Host ""
    Write-Host "=== Iteration $iteration ==="
    $iterStart = Get-Date

    $args = @($basePrompt,
        "--allowedTools", "Read,Edit,Bash(flutter analyze:*),Bash(flutter build:*),Bash(flutter pub get:*),Bash(git:*)",
        "--permission-mode", "acceptEdits",
        "--output-format", "json")
    if ($sessionId) { $args = @($basePrompt, "--resume", $sessionId) + $args[1..($args.Length-1)] }

    # Run claude in the background so we can print a heartbeat while it
    # works, instead of the terminal going silent for however long a
    # single response takes -- that silence is what looked like a freeze
    # before.
    $job = Start-Job -ScriptBlock {
        param($cliArgs, $workDir)
        Set-Location $workDir
        & claude -p @cliArgs
    } -ArgumentList (,$args), $PWD.Path

    while ($job.State -eq 'Running') {
        Start-Sleep -Seconds 15
        $elapsed = [int]((Get-Date) - $iterStart).TotalMinutes
        Write-Host "  ...still working on iteration $iteration (${elapsed}m elapsed)"
    }

    $rawResult = Receive-Job -Job $job
    Remove-Job -Job $job

    try {
        $result = $rawResult | ConvertFrom-Json
        $sessionId = $result.session_id
        $text = $result.result
        Write-Host $text

        # Stop early if the model itself signals it's actually finished,
        # rather than always burning all 25 iterations.
        if ($text -match "(?i)all 4 sections.*(done|complete)|nothing (left|more) to do|REPORT\.md.*final summary written") {
            Write-Host ""
            Write-Host "Loop appears to have finished its own scope after $iteration iteration(s)."
            break
        }
    } catch {
        Write-Host "Iteration $iteration produced no parseable output. Continuing."
    }
}

Write-Host ""
Write-Host "Loop stopped after $iteration iteration(s)."
Write-Host "Check REPORT.md and 'git log --oneline -10' for what actually happened."
