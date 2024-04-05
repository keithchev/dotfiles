# most aliases are defined in the zsh git plugin; these are only custom or overridden aliases.
alias gt='git status -sb'
alias gr="git remote -vv"
alias gb="git branch -a -vv"
alias gbk="git branch -a -vv | grep kcc"
alias gdn="git diff --name-only"
alias glg='git log --pretty=format:"%h %Cblue %d %Cred %ad %Cgreen %ae %Creset %<(100,trunc) %s" --date=short --graph --all'
