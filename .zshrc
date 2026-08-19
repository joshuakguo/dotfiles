alias vim='nvim'

alias t='tmux -CC new-session -A -s'
alias tls='tmux list-sessions'
alias tlsw='tmux list-windows -a'
alias tks='tmux kill-session -t'

alias k='kubectl'

alias kgaa='kubectl get all -A'
alias kgp='kubectl get pods -n'
alias kgpa='kubectl get pods -A'
alias kgn='kubectl get nodes'
alias kgns='kubectl get namespaces'

alias kdp='kubectl describe pod -n'
alias kdn='kubectl describe node'
alias kdns='kubectl describe namespace'

alias kl='kubectl logs -n'