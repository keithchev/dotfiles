alias cls="conda env list"

# delete a virtualenv
function conda-rm () {
    conda remove -y -n $1 --all
}

function conda-create() {
    name=$1
    shift
    packages=$@
    conda create -y -n $name $packages
}

function conda-create-310 () {
    conda create -y -n $1 python=3.10
}

function conda-create-39 () {
    conda create -y -n $1 python=3.9
}
