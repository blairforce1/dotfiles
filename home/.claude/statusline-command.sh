#!/usr/bin/env bash
# Status line: current model, context window usage, Claude.ai plan (rate
# limit) usage. Managed via this repo -- see home.nix's home.file entry and
# CLAUDE.md's "Adding a new managed CLI tool" recipe.

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name')

used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
context="Context: --"
[ -n "$used" ] && context=$(printf "Context: %.0f%%" "$used")

five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
plan=""
[ -n "$five" ] && plan="5h: $(printf '%.0f' "$five")%"
if [ -n "$week" ]; then
  week_fmt="7d: $(printf '%.0f' "$week")%"
  if [ -n "$plan" ]; then plan="$plan  $week_fmt"; else plan="$week_fmt"; fi
fi
[ -z "$plan" ] && plan="Plan: --"

printf '%s  |  %s  |  %s\n' "$model" "$context" "$plan"
