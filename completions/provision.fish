function __fish_provision_needs_command
    set -l cmd (commandline -opc)
    if test (count $cmd) -eq 1
        return 0
    end
    return 1
end

function __fish_provision_using_command -a current_command
    set -l cmd (commandline -opc)
    if test (count $cmd) -gt 1
        if test $current_command = $cmd[2]
            return 0
        end
    end
    return 1
end

complete -f -c provision -n '__fish_provision_needs_command' -a help -d "provision help for command"
complete -x -c provision -d "script" -a "(provision commands)"
