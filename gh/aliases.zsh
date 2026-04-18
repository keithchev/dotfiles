alias gh-view='gh repo view --web'
alias pr-view='gh pr view --web'

function kc-view () {
    gh repo view --web keithchev/"$1"
}

function kc-clone () {
    gh repo clone keithchev/"$1"
}

function kc-search () {
    local query=$1
    shift
    gh search repos --owner keithchev "$@" "$query"
}

function is-view () {
    gh repo view --web insitro/"$1"
}

function is-clone () {
    gh repo clone insitro/"$1"
}

function is-search () {
    local query=$1
    shift
    gh search repos --owner insitro "$@" "$query"
}
