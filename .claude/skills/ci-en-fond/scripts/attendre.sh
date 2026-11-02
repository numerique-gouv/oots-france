#!/bin/sh
# Waits, in the foreground and under a bound, for the CI of one pull request.
#
#   attendre.sh <pr> [bound in seconds, 150 by default]
#
#   0   → every check passed
#   1   → a check failed: the summary that follows says which
#   124 → still running, or the head just changed: run it again
#
# The bound stays under 180 s because the Bash tool moves any command still
# running at 180 s to the background: the caller then gets its turn back with
# no verdict, and a watch nobody reads keeps the agent alive after it reported.
#
# `gh pr checks --watch` prints "no checks reported" and exits 1 both before the
# workflows of a push are registered and when a push replaces the head mid-watch:
# that exit is a "run it again", never a red check.

pr=${1:?usage: attendre.sh <pr> [bound]}
bound=${2:-150}
deadline=$(( $(date +%s) + bound ))
output=$(mktemp)
trap 'rm -f "$output"' EXIT

remaining() { echo $(( deadline - $(date +%s) )); }

until ! gh pr checks "$pr" 2>&1 | grep -q 'no checks reported'; do
  if [ "$(remaining)" -le 5 ]; then
    echo 'en cours : aucun check enregistré encore'
    exit 124
  fi
  sleep 5
done

left=$(remaining)
[ "$left" -lt 10 ] && left=10
timeout "$left" gh pr checks "$pr" --watch --interval 20 >"$output" 2>&1
status=$?

if grep -q 'no checks reported' "$output"; then
  echo 'en cours : la tête de la PR a changé pendant la surveillance'
  exit 124
fi

case $status in
  0) echo 'verte' ;;
  124) echo 'en cours'; exit 124 ;;
  *) gh pr checks "$pr" 2>&1 | grep -v -E '\bpass\b|\bskipping\b'; exit 1 ;;
esac
