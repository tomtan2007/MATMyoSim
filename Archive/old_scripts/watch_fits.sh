#!/usr/bin/env bash
# Live status table for the 3 HCM fits.
# Run in a separate terminal:  bash watch_fits.sh
# Ctrl-C to quit.

OUT_DIR="/private/tmp/claude-503/-Users-tomtan-Research-MATMyoSim/8c24e4ba-c7ae-482a-ad28-e8d442b29af2/tasks"

declare -A FITS=(
    [3-state]="btifel303.output:50"
    [4-state]="bf8eh43ok.output:50"
    [6-state]="b8ejhpti7.output:100"
)

while true; do
    clear
    printf '%-10s %-8s %-8s %-12s %-10s\n' "Model" "Evals" "Iter~" "Best e" "Latest e"
    printf '%s\n' "-------------------------------------------------------"
    for name in 3-state 4-state 6-state; do
        IFS=':' read -r file swarm <<< "${FITS[$name]}"
        f="$OUT_DIR/$file"
        if [[ ! -f $f ]]; then
            printf '%-10s %-8s %-8s %-12s %-10s\n' "$name" "?" "?" "(no file)" "?"
            continue
        fi
        evals=$(grep -c "eval:" "$f" 2>/dev/null || echo 0)
        iters=$(( evals / swarm ))
        best=$(grep "eval:" "$f" | awk '{print $2}' | sed 's/e=//' | grep -v NaN | sort -g | head -1)
        latest=$(grep "eval:" "$f" | tail -1 | awk '{print $2}' | sed 's/e=//')
        printf '%-10s %-8s %-8s %-12s %-10s\n' "$name" "$evals" "$iters" "${best:-—}" "${latest:-—}"
    done
    echo ""
    echo "Updated $(date '+%H:%M:%S')  —  refreshing every 5s  —  Ctrl-C to quit"
    sleep 5
done
