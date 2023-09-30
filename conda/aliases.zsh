alias ca="conda activate"
alias cls="conda env list"

# delete a virtualenv
function conda-rm () {
    conda remove -y -n $1 --all
}

# create a virtualenv with a specific python version
function mc () {
    local name=$1
    local python=$2
    local packages="${@:3}"
    mamba create -y -n $name python=$python $packages
}
