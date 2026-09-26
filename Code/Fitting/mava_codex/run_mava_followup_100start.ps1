$repo = 'C:\users\tomtan\matmyosim'
$primary = Join-Path $repo 'Code\Fitting\mava_codex\output\runs\mava_seq_20260908_windows'
$authority = Join-Path $repo 'Code\Fitting\mava_codex\output\AUTHORITATIVE_RUN.txt'
$followup = Join-Path $repo 'Code\Fitting\mava_codex\output\runs\mava_seq_20260908_windows_followup100'
$log = Join-Path (Split-Path $followup -Parent) 'mava_seq_20260908_windows_followup100.log'
$matlab = 'C:\Program Files\MATLAB\R2026a\bin\matlab.exe'

while (-not (Test-Path $authority)) { Start-Sleep -Seconds 60 }
if ((Get-Content -Raw $authority).Trim() -ne 'mava_seq_20260908_windows') { exit 1 }
if (Test-Path $followup) { exit 2 }

& $matlab -batch "cd('C:\users\tomtan\matmyosim'); addpath('Code\Fitting\mava_codex'); run_mava_followup_multistart('$primary','$followup','execute'); exit" *>&1 | Tee-Object -FilePath $log
