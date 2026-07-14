# review-loop.ps1
# Run from the project root. No screenshots, no prompts, no stopping.
# Usage:  .\review-loop.ps1

$maxIterations = 8
$iteration = 0
$sessionId = $null

$basePrompt = "Work through REPORT.md and any remaining unfinished items in TASKS.md. Use ONLY static code reading and reasoning - do not ask me for screenshots, logs, or device output, and do not wait for my input under any circumstance. If an item truly cannot be resolved without a live device, make your best reasoned fix based on the code logic anyway (e.g. add defensive null checks, fix suspicious state/navigation logic you find), note it clearly as 'best-effort, not device-verified' in REPORT.md, and move on immediately to the next item. Never stop and ask a question. When you've gone through everything, commit your changes with git and stop."

Write-Host "Starting unattended review loop (max $maxIterations iterations)..."

while ($iteration -lt $maxIterations) {
    $iteration++
    Write-Host ""
    Write-Host "=== Iteration $iteration ==="

    if ($sessionId) {
        $rawResult = claude -p $basePrompt `
            --resume $sessionId `
            --allowedTools "Read,Edit,Bash(git:*),Bash(flutter analyze:*)" `
            --permission-mode acceptEdits `
            --output-format json
    } else {
        $rawResult = claude -p $basePrompt `
            --allowedTools "Read,Edit,Bash(git:*),Bash(flutter analyze:*)" `
            --permission-mode acceptEdits `
            --output-format json
    }

    try {
        $result = $rawResult | ConvertFrom-Json
        $sessionId = $result.session_id
        Write-Host $result.result
    } catch {
        Write-Host "Iteration $iteration produced no parseable output. Continuing."
    }
}

Write-Host ""
Write-Host "Loop finished after $iteration iteration(s). Check REPORT.md and git log for what changed."
