alias vim='nvim'

alias k='kubectl'
alias kl='kubectl logs -n'

alias kgp='kubectl get pods -n'
alias kgn='kubectl get nodes'
alias kgns='kubectl get namespaces'

alias t='tmux -CC new-session -A -s'
alias tls='tmux list-sessions'
alias tlsw='tmux list-windows -a'
alias tks='tmux kill-session -t'
alias tss='tmux run-shell "$(tmux show -gv @resurrect-save-script-path)"'
alias trs='tmux run-shell "$(tmux show -gv @resurrect-restore-script-path)"'