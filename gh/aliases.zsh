alias gh-view='gh repo view --web'
alias pr-view='gh pr view --web'

# open local repos on github
function kc-view () {
    gh repo view --web keithchev/"$1"
}

function ac-view () {
    gh repo view --web arcadia-science/"$1"
}

function ac-clone () {
    gh repo clone arcadia-science/"$1"
}
