#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ -n "${GODOT_BIN:-}" ]; then
    engine="$GODOT_BIN"
elif [ -x ./Godot.app/Contents/MacOS/Godot ]; then
    engine="$PWD/Godot.app/Contents/MacOS/Godot"
elif command -v godot >/dev/null 2>&1; then
    engine=godot
else
    echo 'Set GODOT_BIN to your Godot 4.7.2 executable.' >&2
    exit 1
fi
# Never execute fixtures in the player's user-data namespace.
case "$engine" in
    /*) ;;
    */*) engine="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "$engine")" ;;
    *) engine="$(command -v "$engine")" ;;
esac
validation_root="$(python3 tools/prepare_validation.py)"
cd "$validation_root"
echo "Isolated validation project: $validation_root"
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
run_check journey_english --script tests/test_journey.gd -- en
run_check art --script tests/test_art.gd
run_check music --script tests/test_music.gd
run_check localization --script tests/test_localization.gd
run_check chinese_font --script tests/test_chinese_font.gd
run_check preferences --script tests/test_preferences.gd
run_check tide_rules --script tests/test_tide_rules.gd
run_check tide_journey --script tests/test_tide_journey.gd
run_check tide_journey_english --script tests/test_tide_journey.gd -- en
run_check tide_localization --script tests/test_tide_localization.gd
run_check rain_rules --script tests/test_rain_rules.gd
run_check rain_journey --script tests/test_rain_journey.gd
run_check rain_journey_english --script tests/test_rain_journey.gd -- en
run_check rain_localization --script tests/test_rain_localization.gd
run_check rain_species --script tests/test_rain_species.gd
run_check species_localization --script tests/test_species_localization.gd
run_check journal --script tests/test_journal.gd
run_check challenges --script tests/test_challenges.gd
run_check second_light_journey --script tests/test_second_light_journey.gd
run_check second_light_journey_english --script tests/test_second_light_journey.gd -- en
run_check second_light_localization --script tests/test_second_light_localization.gd
run_check capture_isolation --script tests/test_capture_isolation.gd
run_check startup --quit-after 30
echo "All sequential checks passed. Logs: $log_dir"
