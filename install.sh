#!/bin/sh

set -eu

DOTFILES_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ZSHRC="$HOME/.zshrc"
TMUXCONF="$HOME/.tmux.conf"
ITERM_PREFS="$DOTFILES_DIR/com.googlecode.iterm2.plist"
START_MARKER="# >>> dotfiles >>>"
END_MARKER="# <<< dotfiles <<<"

install_zsh() {
    touch "$ZSHRC"

    if grep -Fq "$START_MARKER" "$ZSHRC"; then
        return
    fi

    {
        printf '\n%s\n' "$START_MARKER"
        printf 'source %s\n' "$(printf '%s' "$DOTFILES_DIR/.zshrc" | sed "s/'/'\\\\''/g; s/^/'/; s/$/'/")"
        printf '%s\n' "$END_MARKER"
    } >> "$ZSHRC"
}

install_tmux() {
    touch "$TMUXCONF"

    if grep -Fq "$START_MARKER" "$TMUXCONF"; then
        return
    fi

    {
        printf '\n%s\n' "$START_MARKER"
        printf 'source-file %s\n' "$(printf '%s' "$DOTFILES_DIR/.tmux.conf" | sed "s/'/'\\\\''/g; s/^/'/; s/$/'/")"
        printf '%s\n' "$END_MARKER"
    } >> "$TMUXCONF"
}

install_git() {
    git config --global core.excludesfile "$DOTFILES_DIR/.gitignore.global"
}

install_iterm2() {
    if [ ! -f "$ITERM_PREFS" ]; then
        printf '%s\n' "Missing iTerm2 preferences at $ITERM_PREFS" >&2
        exit 1
    fi

    defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$DOTFILES_DIR"
    defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
}

install_zsh
install_tmux
install_git
if [ "$(uname -s)" = Darwin ]; then
    install_iterm2
fi
