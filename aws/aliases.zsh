
function s3-ls () {
    local dir=$1
    # append a trailing slash.
    [[ "${dir}" != */ ]] && dir="${dir}/"
    aws s3 ls --human-readable "${dir}"
}


function s3-size-gb () {
    local dir=$1
    # append a trailing slash.
    [[ "${dir}" != */ ]] && dir="${dir}/"
    aws s3 ls --recursive "${dir}" | \
        awk '{size += $3} END {print "Total size: " size/1024/1024/1024 " GB"}'
}

function s3-up () {
    aws s3 cp $1 s3://$2
}

function s3-down () {
    aws s3 cp s3://$1 $2
}

function s3-rm () {
    aws s3 rm --dryrun s3://$1
}

function s3-rm-im-sure () {
    aws s3 rm s3://$1
}

function s3-fetch () {
    uv run $DOTFILES/aws/s3_fetch.py "$@"
}

# list ec2 instances across the regions configured in ~/.aws-instances.yaml
# rows of (region, id, state, name, alias). Pass --region to override.
function ec2-ls () {
    uv run $DOTFILES/aws/manage_instances.py ls "$@"
}

function ec2-start () {
    uv run $DOTFILES/aws/manage_instances.py start "$@"
}

function ec2-stop () {
    uv run $DOTFILES/aws/manage_instances.py stop "$@"
}

function ec2-status () {
    uv run $DOTFILES/aws/manage_instances.py status "$@"
}

alias ec2-ls-aliases='uv run $DOTFILES/aws/manage_instances.py list'

function ec2-add-alias () {
    uv run $DOTFILES/aws/manage_instances.py add-alias "$@"
}
