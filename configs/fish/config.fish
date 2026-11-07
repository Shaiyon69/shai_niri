# Load CachyOS's fish defaults when they're available.
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

# Monochrome syntax colours, so the command line matches the terminal palette.
set -g fish_color_command brwhite
set -g fish_color_keyword brwhite --bold
set -g fish_color_param white
set -g fish_color_option cyan
set -g fish_color_quote green
set -g fish_color_redirection brblack
set -g fish_color_end brblack
set -g fish_color_operator cyan
set -g fish_color_escape magenta
set -g fish_color_error red
set -g fish_color_comment brblack --italics
set -g fish_color_autosuggestion brblack
set -g fish_color_valid_path --underline

# Git details and the short prompt left in scrollback are used by fish_prompt.
set -g __fish_git_prompt_showdirtystate 1
set -g __fish_git_prompt_showuntrackedfiles 1
set -g __fish_git_prompt_showupstream informative
set -g __fish_git_prompt_color_branch brblack
set -g fish_transient_prompt 1
