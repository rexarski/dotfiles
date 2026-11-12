# Environment Variables
# --------------------

type -q zoxide; and zoxide init fish | source

# Aliases
# -------
# Python related
alias pip=pip3
alias python=python3

# File listing (eza)
if type -q eza
    alias ll "eza -l -g --icons"
    alias lla "ll -a"
end

# uv
fish_add_path $HOME/.local/bin

# bun
if test -d $HOME/.bun
    set --export BUN_INSTALL "$HOME/.bun"
    set --export PATH $BUN_INSTALL/bin $PATH
end

# Obsidian CLI
test -d /Applications/Obsidian.app; and fish_add_path /Applications/Obsidian.app/Contents/MacOS

# Emacs aliases
function em
    emacs -nw $argv
end

function emacsgui
    emacs $argv
end

# yazi

function y
	set tmp (mktemp -t "yazi-cwd.XXXXXX")
	command yazi $argv --cwd-file="$tmp"
	if read -z cwd < "$tmp"; and [ "$cwd" != "$PWD" ]; and test -d "$cwd"
		builtin cd -- "$cwd"
	end
	rm -f -- "$tmp"
end

# Added by LM Studio CLI (lms)
test -d $HOME/.lmstudio/bin; and set -gx PATH $PATH $HOME/.lmstudio/bin
# End of LM Studio CLI section

