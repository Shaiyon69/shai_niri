function fish_prompt
    # Read these first: every command below overwrites them.
    set -l last_status $status
    set -l duration $CMD_DURATION

    set -l arrow_color brwhite
    test $last_status -ne 0; and set arrow_color red

    # Older prompts collapse to the arrow, which keeps scrollback readable.
    if contains -- --final-rendering $argv
        set_color brblack
        printf ' '
        set_color normal
        return
    end

    # A blank line separates each command's output from the next prompt.
    echo

    set -l pill 26272c
    set_color $pill
    printf ''
    set_color --background $pill brwhite
    printf '  %s ' (prompt_pwd --dir-length 1 --full-length-dirs 2)
    set_color normal
    set_color $pill
    printf ''
    set_color normal

    fish_git_prompt '  %s'

    if test $duration -ge 2000
        set_color brblack
        printf '  %ss' (math --scale 1 $duration / 1000)
    end
    if test $last_status -ne 0
        set_color red
        printf '   %s' $last_status
    end
    set_color normal
    echo

    set_color $arrow_color
    printf ' '
    set_color normal
end
