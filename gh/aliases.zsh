alias gh-view='gh repo view --web'
alias ghv='gh repo view --web'

alias gh-view-pr='gh pr view --web'
alias ghvp='gh pr view --web'

# open local repos on github
function kc () {
    gh repo view --web keithchev/"$1"
}
