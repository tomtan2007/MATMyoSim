$runDir = 'C:\users\tomtan\matmyosim\Code\Fitting\mava_codex\output\runs\mava_seq_20260908_windows'
$manifestFile = Join-Path $runDir 'manifest.json'
$logFile = Join-Path $runDir 'postprocess.log'
$matlab = 'C:\Program Files\MATLAB\R2026a\bin\matlab.exe'

while ($true) {
    $manifest = Get-Content -Raw -Path $manifestFile | ConvertFrom-Json
    if ($manifest.status -eq 'complete') { break }
    Start-Sleep -Seconds 60
}

& $matlab -batch "cd('C:\users\tomtan\matmyosim'); addpath('Code\Fitting\mava_codex'); run_mava_sequential_analysis('mava_seq_20260908_windows','summarize'); exit" *>&1 | Set-Content -Path $logFile
