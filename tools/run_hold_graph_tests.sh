#!/usr/bin/env bash
# HoldGraph Validator regression suite.
#
# Cases:
#   1. shipping scene (src/level/greybox_wall.tscn)  -> must PASS
#   2. known_distances fixture (edges 2.00, rest path 4.00) -> must PASS
#   3. unreachable_hold fixture (24.0 edge > 22.8 breath max, isolated rest)
#      -> must FAIL (exit 1) — proves soft-locks are no longer concealed
#
# Usage: bash tools/run_hold_graph_tests.sh
# Env:   GODOT  binary name/path (default: godot; use godot4 locally)
set -u

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_DIR="${RESULTS_DIR:-$ROOT/.godot/test-results}"
mkdir -p "$RESULTS_DIR"

passed=0
failed=0

run_case() {
  local name="$1" scene="$2" want="$3"
  local log="$RESULTS_DIR/${name}.log"
  local expect_pass=0
  [ "$want" = "pass" ] && expect_pass=1

  local out exit_code
  if [ -n "$scene" ]; then
    out="$("$GODOT" --headless --path "$ROOT" --script res://tools/validate_hold_graph.gd -- "$scene" 2>&1)"
  else
    out="$("$GODOT" --headless --path "$ROOT" --script res://tools/validate_hold_graph.gd 2>&1)"
  fi
  exit_code=$?
  printf '%s\n' "$out" > "$log"

  if [ "$exit_code" -eq 0 ] && [ "$expect_pass" -eq 1 ]; then
    echo "PASS  $name (exit 0, log: $log)"
    passed=$((passed + 1))
  elif [ "$exit_code" -ne 0 ] && [ "$expect_pass" -eq 0 ]; then
    echo "PASS  $name (exit $exit_code as expected, log: $log)"
    passed=$((passed + 1))
  else
    echo "FAIL  $name (wanted $want, got exit $exit_code, log: $log)"
    failed=$((failed + 1))
  fi
}

echo "== HoldGraph Validator regression suite =="
run_case "shipping_scene"   ""                                  "pass"
run_case "known_distances"  "res://tools/test_fixtures/known_distances.tscn"   "pass"
run_case "unreachable_hold" "res://tools/test_fixtures/unreachable_hold.tscn"  "fail"

echo "-----------------------------------"
echo "SUITE: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
