#!/bin/sh

set -eu

DOTFILES_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
START_MARKER="# >>> dotfiles >>>"
END_MARKER="# <<< dotfiles <<<"

remove_managed_block() {
    file=$1

    if [ ! -f "$file" ] || ! grep -Fq "$START_MARKER" "$file"; then
        return
    fi

    if ! grep -Fq "$END_MARKER" "$file"; then
        printf '%s\n' "Refusing to modify $file: incomplete dotfiles block" >&2
        exit 1
    fi

    sed -i '' "/^$START_MARKER$/,/^$END_MARKER$/d" "$file"
}

uninstall_git() {
    excludes_file=$(git config --global --get core.excludesfile || true)

    if [ "$excludes_file" = "$DOTFILES_DIR/.gitignore.global" ]; then
        git config --global --unset core.excludesfile
    fi
}

uninstall_iterm2() {
    prefs_folder=$(defaults read com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null || true)

    if [ "$prefs_folder" = "$DOTFILES_DIR" ]; then
        defaults delete com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null || true
        defaults delete com.googlecode.iterm2 LoadPrefsFromCustomFolder 2>/dev/null || true
    fi
}

remove_managed_block "$HOME/.zshrc"
remove_managed_block "$HOME/.tmux.conf"
uninstall_git
uninstall_iterm2
