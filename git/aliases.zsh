alias gc='git commit'
alias gca='git commit -a'
alias gco='git checkout'

alias gt='git status'
alias gs='git status -sb'
alias gr="git remote -vv"
alias gb="git branch -a -vv"
alias gbk="git branch -a -vv | grep kcc"

alias glg='git log --pretty=format:"%h %Cblue %d %Cred %ad %Cgreen %ae %Creset %<(100,trunc) %s" --date=short --graph --all'

# Remove `+` and `-` from start of diff lines; just rely upon color.
alias gd='git diff --color | sed "s/^\([^-+ ]*\)[-+ ]/\\1/" | less -r'
