alias dls="docker container ls"
alias dlsa="docker container ls -a"
alias dils="docker image ls"
alias dilsa="docker image ls -a"

# list mounted volumes in a container 
function dlsv () {
	docker inspect -f '{{ json .Mounts }}' "$1" | python -m json.tool
}

function deb () {
    docker exec -it "$1" /bin/bash;
}

alias d-c='docker-compose $*'
