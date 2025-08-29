alias gh-view='gh repo view --web'
alias pr-view='gh pr view --web'

function kc-view () {
    gh repo view --web keithchev/"$1"
}

function ac-view () {
    gh repo view --web arcadia-science/"$1"
}

function kc-clone () {
    gh repo clone keithchev/"$1"
}

function ac-clone () {
    gh repo clone arcadia-science/"$1"
}

function kc-search () {
    local query=$1
    shift
    gh search repos --owner keithchev "$@" "$query"
}

function ac-search () {
    local query=$1
    shift
    gh search repos --owner arcadia-science "$@" "$query"
}
