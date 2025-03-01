# About this fork
This is a diverged fork of holman/dotfiles that is heavily modified for my own purposes. In practical terms, this is a hard fork; there is no intention to merge any changes here to the upstream.

## Summary of major divergent changes
I deleted commands, configs, subdirectories, etc that I don't need or that conflicted with other things that I do need. This turned out to be quite a lot of things. In addition, I dropped everything homebrew-related and also all of the install scripts, since it seemed preferable to handle that stuff manually. 

I incorporated oh-my-zsh by merging the `.zshrc` created by oh-my-zsh with `zsh/zshrc.symlink`. This may turn out to cause problems when starting with a fresh install of oh-my-zsh. 

## Usage
Clone the repo to `~/projects/dotfiles`, call `script/bootstrap`, call `update-dotfiles`. 

Unlike holman, I decided to clone the repo in my normal directory of local clones (`~/projects`) rather than to the special location `~/.dotfiles`. 

## Original README

The original README content from the upstream [dotfiles](https://github.com/holman/dotfiles) repo from the point at which this fork diverged from it is found in [ORIGINAL_README.md](ORIGINAL_README.md).
