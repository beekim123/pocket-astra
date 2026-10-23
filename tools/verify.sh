#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ -n "${GODOT_BIN:-}" ]; then
    engine="$GODOT_BIN"
elif [ -x ./Godot.app/Contents/MacOS/Godot ]; then
    engine=./Godot.app/Contents/MacOS/Godot
elif command -v godot >/dev/null 2>&1; then
    engine=godot
else
    echo 'Set GODOT_BIN to your Godot 4.7.2 executable.' >&2
    exit 1
fi
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1
log_dir="${TMPDIR:-/tmp}/lanternwake-verification-$$"
mkdir -p "$log_dir"
run_check() {
    label="$1"
    shift
    log="$log_dir/$label.log"
    if ! nice -n 10 "$engine" --headless --single-threaded-scene --path . --log-file "$log" "$@" >"$log.stdout" 2>&1; then
        cat "$log.stdout"
        exit 1
    fi
    cat "$log.stdout"
    if grep -E 'SCRIPT ERROR:|ERROR:|FAIL:|WARNING:' "$log.stdout" >/dev/null 2>&1; then
        echo "Validation failed: $label (see $log.stdout)" >&2
        exit 1
    fi
}
run_check import --editor --import --quit
run_check rules --script tests/test_rules.gd
run_check journey --script tests/test_journey.gd
run_check art --script tests/test_art.gd
run_check music --script tests/test_music.gd
run_check startup --quit-after 30
echo "All sequential checks passed. Logs: $log_dir"
