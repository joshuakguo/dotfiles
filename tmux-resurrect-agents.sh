#!/usr/bin/env bash
# tmux-resurrect @resurrect-hook-post-save-layout hook (Linux + macOS, bash 3.2+).
#
# Rewrites Claude Code and Codex panes in the save file so restore relaunches each one
# into the conversation it was running (`claude --resume <id>`, `codex resume <id>`).
# Panes with no recoverable conversation are restored as bare `claude` / `codex`.
# Original launch args are dropped on purpose: they may include an initial prompt.
#
# Restore side needs: set -g @resurrect-processes 'claude codex'
# Codex lookup needs sqlite3 (preinstalled on macOS); without it Codex panes relaunch bare.
set -u

save_file="${1:-}"
[ -f "$save_file" ] || exit 0
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
codex_home="${CODEX_HOME:-$HOME/.codex}"
T=$'\t'

# Claude Code keeps <claude_dir>/sessions/<pid>.json (one-line JSON) for each live session,
# recording its tmux pane as "tmux":"<session>:@<window_id>.%<pane_id>".
claude_session() { # pane_id
	local f pid id
	for f in "$claude_dir"/sessions/*.json; do
		grep -q "\"tmux\":\"[^\"]*\\.$1\"" "$f" 2>/dev/null || continue
		pid=$(basename "$f" .json)
		kill -0 "$pid" 2>/dev/null || continue
		id=$(sed -n 's/.*"sessionId":"\([^"]*\)".*/\1/p' "$f")
		# A session with no messages yet has no transcript and can't be resumed.
		[ -n "$id" ] && ls "$claude_dir"/projects/*/"$id".jsonl >/dev/null 2>&1 && echo "$id"
		return
	done
}

descendants() { # pid -> that pid and every descendant
	ps -A -o pid= -o ppid= | awk -v root="$1" '
		{ parent[$1 + 0] = $2 + 0 }
		END {
			for (p in parent) {
				q = p + 0
				while (q > 1 && q != root + 0) q = (q in parent) ? parent[q] : 0
				if (q == root + 0) print p
			}
		}'
}

open_files() { # pid... (procfs on Linux, lsof on macOS)
	local p
	[ "$#" -gt 0 ] || return
	if [ -d /proc/self/fd ]; then
		for p in "$@"; do find "/proc/$p/fd" -mindepth 1 -maxdepth 1 -exec readlink {} + 2>/dev/null; done
	else
		lsof -n -P -Fn -p "$(IFS=,; echo "$*")" 2>/dev/null | sed -n 's/^n//p'
	fi
}

# Codex holds <codex_home>/thread-writer-locks/<thread_id>.lock open for every live thread:
# the conversation plus helper subagents, whose `source` in state_N.sqlite is a JSON object.
# Threads only get a row once they have a message, so empty sessions fall through.
codex_session() { # pane_pid
	command -v sqlite3 >/dev/null || return
	local db ids
	db=$(ls -t "$codex_home"/state_*.sqlite 2>/dev/null | head -n 1)
	[ -n "$db" ] || return
	ids=$(open_files $(descendants "$1") |
		sed -n 's#.*/thread-writer-locks/\([0-9a-f-]*\)\.lock$#\1#p' | sort -u | sed "s/.*/'&'/" | paste -s -d , -)
	[ -n "$ids" ] || return
	sqlite3 -readonly "$db" "select id from threads where id in ($ids) and source not like '{%' order by updated_at_ms desc limit 1;" 2>/dev/null
}

map=$(mktemp "${TMPDIR:-/tmp}/resurrect-agents.XXXXXX") || exit 0
trap 'rm -f "$map" "$save_file.agents"' EXIT
panes=$(tmux list-panes -a -F "#{session_name}${T}#{window_index}${T}#{pane_index}${T}#{pane_id}${T}#{pane_pid}")

# Save-file pane lines: pane, session, window, window_active, :flags, pane_index, title,
# :dir, pane_active, pane_command, :full_command (tab-separated). npm installs show up as
# `node /path/to/codex`, so look past a node/bun interpreter.
awk -F'\t' '$1 == "pane" {
	cmd = $11; sub(/^:/, "", cmd); n = split(cmd, word, " ")
	bin = word[1]; sub(/.*\//, "", bin)
	if ((bin == "node" || bin == "bun") && n > 1) { bin = word[2]; sub(/.*\//, "", bin) }
	sub(/\.js$/, "", bin)
	if (bin == "claude" || bin == "codex") print $2 "\t" $3 "\t" $6 "\t" bin
}' "$save_file" | while IFS="$T" read -r sess win pane agent; do
	read -r pane_id pane_pid < <(printf '%s\n' "$panes" |
		awk -F'\t' -v s="$sess" -v w="$win" -v p="$pane" '$1 == s && $2 == w && $3 == p { print $4, $5; exit }')
	[ -n "${pane_id:-}" ] || continue
	case $agent in
	claude) id=$(claude_session "$pane_id"); cmd="claude${id:+ --resume $id}" ;;
	codex) id=$(codex_session "$pane_pid"); cmd="codex${id:+ resume $id}" ;;
	esac
	printf '%s\t%s\t%s\t%s\n' "$sess" "$win" "$pane" "$cmd"
done >"$map"

[ -s "$map" ] || exit 0
awk -F'\t' -v OFS='\t' '
	NR == FNR { cmd[$1 FS $2 FS $3] = $4; next }
	$1 == "pane" && (($2 FS $3 FS $6) in cmd) { $11 = ":" cmd[$2 FS $3 FS $6] }
	{ print }' "$map" "$save_file" >"$save_file.agents" && mv "$save_file.agents" "$save_file"
