#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$CURRENT_DIR/scripts/claude-limit"

tmux_option() {
  local option="$1"
  local default="$2"
  local value
  value="$(tmux show-option -gqv "$option")"
  if [ -z "$value" ]; then
    printf '%s\n' "$default"
  else
    printf '%s\n' "$value"
  fi
}

set_default() {
  local option="$1"
  local value="$2"
  if [ -z "$(tmux show-option -gqv "$option")" ]; then
    tmux set-option -gq "$option" "$value"
  fi
}

set_default '@claude_limit_position' 'left-of-status-right'
set_default '@claude_limit_cache_ttl' '60'
set_default '@claude_limit_show_five_hour' 'on'
set_default '@claude_limit_show_seven_day' 'on'
set_default '@claude_limit_show_extra' 'on'
set_default '@claude_limit_show_reset' 'on'
set_default '@claude_limit_show_stale' 'on'
set_default '@claude_limit_label' 'Claude'
set_default '@claude_limit_separator' ' · '
set_default '@claude_limit_time_format' '%H:%M'
# Single style applied to the whole segment. tmux's `bg=default` inherits
# status-style bg, so on a themed status bar (e.g. 'bg=green,fg=black')
# 'fg=green' becomes invisible — override per-bar to suit your colors.
set_default '@claude_limit_style' 'fg=black'
set_default '@claude_limit_style_error' 'fg=red,bold'
# Default to lowercase 'u' so we don't shadow TPM's `prefix + U` (update).
set_default '@claude_limit_popup_key' 'u'
set_default '@claude_limit_bind_popup' 'on'
set_default '@claude_limit_popup_width' '72'
set_default '@claude_limit_popup_height' '22'
set_default '@claude_limit_min_status_right_length' '200'

tmux set-option -gq status-interval "$(tmux_option '@claude_limit_cache_ttl' '60')"

# tmux's default status-right-length is 40, which truncates our segment.
# Bump it (only if currently smaller than the requested minimum).
min_len="$(tmux_option '@claude_limit_min_status_right_length' '200')"
cur_len="$(tmux show-option -gqv status-right-length)"
if [ -z "$cur_len" ] || [ "$cur_len" -lt "$min_len" ]; then
  tmux set-option -gq status-right-length "$min_len"
fi

segment="#($SCRIPT status)"
position="$(tmux_option '@claude_limit_position' 'left-of-status-right')"

case "$position" in
  left-of-status-right)
    current="$(tmux show-option -gqv status-right)"
    case "$current" in
      *"$SCRIPT status"*) ;;
      *) tmux set-option -gq status-right "$segment ${current}" ;;
    esac
    ;;
  status-left)
    current="$(tmux show-option -gqv status-left)"
    case "$current" in
      *"$SCRIPT status"*) ;;
      *) tmux set-option -gq status-left "$current $segment" ;;
    esac
    ;;
  manual)
    ;;
esac

if [ "$(tmux_option '@claude_limit_bind_popup' 'on')" = "on" ]; then
  key="$(tmux_option '@claude_limit_popup_key' 'u')"
  popup_w="$(tmux_option '@claude_limit_popup_width' '72')"
  popup_h="$(tmux_option '@claude_limit_popup_height' '22')"
  # Pipe through `less` so the popup stays open until the user presses q.
  # Without this the popup closes instantly because the script exits fast.
  tmux bind-key "$key" display-popup -E -w "$popup_w" -h "$popup_h" "$SCRIPT panel | less -R"
fi

