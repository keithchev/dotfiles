alias mls="mamba list"
alias mels="mamba env list"

# delete a virtualenv
function mamba-rm () {
    mamba remove -y -n $1 --all
}

# create a virtualenv with a specific python version
function mamba-create () {
    local name=$1
    local python=$2
    local packages="${@:3}"
    mamba create -y -n $name python=$python $packages
}

alias mc="mamba-create"
