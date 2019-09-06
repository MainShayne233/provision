
#compdef provision

# This completion file should be linked to a directory in ZSH fpath
# and named `_sub`.

SUBNAME="provision"

_provision(){
  case $CURRENT in
    2)
      local cmds
      local -a commands
      cmds=$($SUBNAME commands)
      commands=(${(ps:\n:)cmds})
      _wanted command expl "$SUBNAME command" compadd -a commands
      ;;
    *)
      local cmd subcmds
      local -a commands
      cmd=${words[2]}
      subcmds=$($SUBNAME completions ${words[2,$(($CURRENT - 1))]})
      commands=(${(ps:\n:)subcmds})
      _wanted subcommand expl "$SUBNAME $cmd subcommand" compadd -a commands
      ;;
  esac
}
