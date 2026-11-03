# most aliases are defined in the zsh git plugin; these are only custom or overridden aliases.
alias gt='git status -sb'
alias gr="git remote -vv"
alias gb="git branch -a -vv"
alias gbk="git branch -a -vv | grep kcc"
alias gdn="git diff --name-only"
alias glg='git log --pretty=format:"%h %Cblue %d %Cred %ad %Cgreen %ae %Creset %<(100,trunc) %s" --date=short --graph --all'

function git-set-user () {
    if [[ $# -ne 2 ]]; then
        echo "Usage: git-set-user <name> <email>"
        return 1
    fi
    git config --file ~/.gitconfig.local user.name "$1"
    git config --file ~/.gitconfig.local user.email "$2"
    echo "Set user.name='$1' and user.email='$2' in ~/.gitconfig.local"
}
