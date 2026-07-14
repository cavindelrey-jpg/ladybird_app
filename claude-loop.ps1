# claude-loop.ps1
# Run from the root of the academia-cameroon repo (same folder as pubspec.yaml)
# Usage:  .\claude-loop.ps1

$maxIterations = 15
$iteration = 0
$sessionId = $null

Write-Host "Starting Claude Code build/fix loop (max $maxIterations iterations)..."

while ($iteration -lt $maxIterations) {
    $iteration++
    Write-Host ""
    Write-Host "=== Iteration $iteration ==="

    $analyzeOutput = flutter analyze 2>&1 | Out-String

    if ($analyzeOutput -match "No issues found!") {
        Write-Host "flutter analyze is clean. Attempting a debug build..."
        flutter build apk --debug 2>&1 | Tee-Object -Variable buildRaw | Out-Null
        $buildOutput = $buildRaw | Out-String

        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "Build succeeded. Loop complete after $iteration iteration(s)."
            break
        }

        Write-Host "Build failed. Sending errors to Claude Code..."
        $prompt = "The Flutter build failed. Read CLAUDE.md for project conventions, then fix the errors below. Do not run flutter build yourself; just fix the code so the next analyze/build pass is clean.`n`n$buildOutput"
    } else {
        Write-Host "flutter analyze found issues. Sending errors to Claude Code..."
        $prompt = "flutter analyze reported the issues below. Read CLAUDE.md for project conventions, then fix them. Do not run flutter build yourself; just fix the code.`n`n$analyzeOutput"
    }

    if ($sessionId) {
        $rawResult = claude -p $prompt `
            --resume $sessionId `
            --allowedTools "Read,Edit,Bash(flutter analyze:*),Bash(flutter build:*)" `
            --permission-mode acceptEdits `
            --output-format json
    } else {
        $rawResult = claude -p $prompt `
            --allowedTools "Read,Edit,Bash(flutter analyze:*),Bash(flutter build:*)" `
            --permission-mode acceptEdits `
            --output-format json
    }

    try {
        $result = $rawResult | ConvertFrom-Json
        $sessionId = $result.session_id
    } catch {
        Write-Host "Warning: couldn't parse Claude Code output as JSON. Continuing loop without session resume."
        $sessionId = $null
    }
}

if ($iteration -ge $maxIterations) {
    Write-Host ""
    Write-Host "Hit the $maxIterations-iteration cap without a clean build."
    Write-Host "Stopping here so you can review manually rather than looping forever."
}
