alias ca="conda activate"

alias cls="conda env list"

# delete a virtualenv
function conda-rm () {
    conda remove -y -n $1 --all
}

function mc() {
    name=$1
    shift
    packages=$@
    mamba create -y -n $name $packages
}

function mc-310 () {
    mamba create -y -n $1 python=3.10
}

function mc-39 () {
    mamba create -y -n $1 python=3.9
}
