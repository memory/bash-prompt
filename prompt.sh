#!/bin/bash
# Filename:      prompt.sh
# Maintainer:    Nathan Mehl

# based on Dave Vehrs' "custom_prompt.sh" from https://debian-administration.org/article/205/Fancy_Bash_Prompts

# Current Format: USER@HOST [dynamic section] { CURRENT DIRECTORY }$
# USER:      (also sets the base color for the prompt)
#   Red       == Root(UID 0) Login shell (i.e. sudo bash)
#   Light Red == Root(UID 0) Login shell (i.e. su -l or direct login)
#   Yellow    == Root(UID 0) priviledges in non-login shell (i.e. su)
#   Brown     == SU to user other than root(UID 0)
#   Green     == Normal user
# @:
#   Light Red == http_proxy environmental variable undefined.
#   Green     == http_proxy environmental variable configured.
# HOST:
#   Red       == Insecure remote connection (unknown type)
#   Yellow    == Insecure remote connection (Telnet)
#   Brown     == Insecure remote connection (RSH)
#   Cyan      == Secure remote connection (i.e. SSH)
#   Green     == Local session
# DYNAMIC SECTION:
#     (If count is zero for any of the following, it will not appear)
#   [scr:#] ==== Number of detached screen sessions
#     Yellow    == 1-2
#     Red       == 3+
#   [bg:#]  ==== Number of backgrounded but still running jobs
#     Yellow    == 1-10
#     Red       == 11+
#   [stp:#] ==== Number of stopped (backgrounded) jobs
#     Yellow    == 1-2
#     Red       == 3+
# CURRENT DIRECTORY:     (truncated to 1/4 screen width)
#   Red       == Current user does not have write priviledges
#   Green     == Current user does have write priviledges
# NOTE:
#   1.  Displays message on day change at midnight on the line above the
#       prompt (Day changed to...).
#   2.  Command is added to the history file each time you hit enter so its
#       available to all shells.

# Configure Colors:
COLOR_WHITE='\033[1;37m'
COLOR_LIGHTGRAY='033[0;37m'
COLOR_GRAY='\033[1;30m'
COLOR_BLACK='\033[0;30m'
COLOR_RED='\033[0;31m'
COLOR_LIGHTRED='\033[1;31m'
COLOR_GREEN='\033[0;32m'
COLOR_LIGHTGREEN='\033[1;32m'
COLOR_BROWN='\033[0;33m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_LIGHTBLUE='\033[1;34m'
COLOR_PURPLE='\033[0;35m'
COLOR_PINK='\033[1;35m'
COLOR_CYAN='\033[0;36m'
COLOR_LIGHTCYAN='\033[1;36m'
COLOR_DEFAULT='\033[0m'
UNDERLINE='\033[4m'
NO_UNDERLINE='\033[24m'

# Function to set prompt_command to.
function promptcmd () {
    # log the exitval of the last expr
    local EXIT="$?"
    history -a
    local SSH_FLAG=0
    local TTY=$(tty | awk -F/dev/ '{print $2}')
    if [[ ${TTY} ]]; then
        local SESS_SRC=$(who | grep "$TTY "  | awk '{print $6 }')
    fi

    # detect SCM repos
    if (which hg 2>&1 >/dev/null); then
      MERCURIAL=$(basename $(hg root 2>/dev/null) 2>/dev/null)
    elif (which git 2>&1 >/dev/null); then
      GIT=$(basename $(git rev-parse --show-toplevel 2>/dev/null) 2>/dev/null)
    fi

    # Titlebar
    case ${TERM} in
        screen*|rxvt*|xterm*  )
            if [ "${MERCURIAL}" ]; then
              local TITLEBAR='\[\033]0;\u@\h: (${MERCURIAL}) { \w }  \007\]'
	    elif [ "${GIT}" ]; then
              local TITLEBAR='\[\033]0;\u@\h: (${GIT}) { \w }  \007\]'
            else
                local TITLEBAR='\[\033]0;\u@\h: { \w }  \007\]'
            fi
            ;;
        *       )
            local TITLEBAR=''
            ;;
    esac
    NOW=$(date)
    RULE_LENGTH=$(expr ${COLUMNS} - $(echo $NOW | wc -c))
    if [ $EXIT -eq 0 ]; then
      HORIZONTAL_LINE="${UNDERLINE}$(eval printf '%.s\ ' {1..${RULE_LENGTH}})${NOW}${NO_UNDERLINE}"
    else
      ERR="[E:${EXIT}] "
      RULE_LENGTH=$(expr ${RULE_LENGTH} - $(echo ${ERR} | wc -c))
      HORIZONTAL_LINE="${COLOR_RED}${UNDERLINE}${ERR}$(eval printf '%.s\ ' {1..${RULE_LENGTH}})${NOW}${NO_UNDERLINE}${COLOR_DEFAULT}"
    fi
    PS1="${HORIZONTAL_LINE}\n${TITLEBAR}"

    # Test for day change.
    if [ -z $DAY ] ; then
        export DAY=$(/bin/date +%A)
    else
        local today=$(/bin/date +%A)
        if [ "${DAY}" != "${today}" ]; then
            PS1="${PS1}\n\[${COLOR_GREEN}\]Day changed to $(/bin/date '+%A, %d %B %Y').\n"
            export DAY=$today
       fi
    fi

    # User
    if [ ${UID} -eq 0 ] ; then
        if [ "${USER}" == "${LOGNAME}" ]; then
            if [[ ${SUDO_USER} ]]; then
                PS1="${PS1}\[${COLOR_RED}\]\u"
            else
                PS1="${PS1}\[${COLOR_LIGHTRED}\]\u"
            fi
        else
            PS1="${PS1}\[${COLOR_YELLOW}\]\u"
        fi
    else
        if [ ${USER} == ${LOGNAME} ]; then
            PS1="${PS1}\[${COLOR_GREEN}\]\u"
        else
            PS1="${PS1}\[${COLOR_BROWN}\]\u"
        fi
    fi

    # HTTP Proxy var configured or not
    if [ -n "$http_proxy" ] ; then
        PS1="${PS1}\[${COLOR_GREEN}\]@"
    else
        PS1="${PS1}\[${COLOR_LIGHTRED}\]@"
    fi

    # Host

    if [[ ${SSH_CLIENT} ]] || [[ ${SSH2_CLIENT} ]]; then
        SSH_FLAG=1
    fi
    if [ ${SSH_FLAG} -eq 1 ]; then
       PS1="${PS1}\[${COLOR_CYAN}\]\h "
    elif [[ -n ${SESS_SRC} ]]; then
        if [ "${SESS_SRC}" == "(:0.0)" ]; then
        PS1="${PS1}\[${COLOR_GREEN}\]\h "
        else
            local parent_process=`/bin/ps -p ${PPID} -o command=`
            if [[ "$parent_process" == "in.rlogind*" ]]; then
                PS1="${PS1}\[${COLOR_BROWN}\]\h "
            elif [[ "$parent_process" == "in.telnetd*" ]]; then
                PS1="${PS1}\[${COLOR_YELLOW}\]\h "
            else
                PS1="${PS1}\[${COLOR_LIGHTRED}\]\h "
            fi
        fi
    elif [[ "${SESS_SRC}" == "" ]]; then
        PS1="${PS1}\[${COLOR_GREEN}\]\h "
    else
        PS1="${PS1}\[${COLOR_RED}\]\h "
    fi

    # Detached Screen Sessions
    local DTCHSCRN=$(screen -ls | grep -c Detach )
    if [ ${DTCHSCRN} -gt 2 ]; then
        PS1="${PS1}\[${COLOR_RED}\][scr:${DTCHSCRN}] "
    elif [ ${DTCHSCRN} -gt 0 ]; then
        PS1="${PS1}\[${COLOR_YELLOW}\][scr:${DTCHSCRN}] "
    fi

    # Backgrounded running jobs
    local BKGJBS=$(jobs -r | wc -l )
    if [ ${BKGJBS} -gt 2 ]; then
        PS1="${PS1}\[${COLOR_RED}\][bg:${BKGJBS}]"
    elif [ ${BKGJBS} -gt 0 ]; then
        PS1="${PS1}\[${COLOR_YELLOW}\][bg:${BKGJBS}] "
    fi

    # Stopped Jobs
    local STPJBS=$(jobs -s | wc -l )
    if [ ${STPJBS} -gt 2 ]; then
        PS1="${PS1}\[${COLOR_RED}\][stp:${STPJBS}]"
    elif [ ${STPJBS} -gt 0 ]; then
        PS1="${PS1}\[${COLOR_YELLOW}\][stp:${STPJBS}] "
    fi

    # Mercurial repo support
    if [ "${MERCURIAL}" ]; then
      PS1="${PS1}\[${COLOR_LIGHTBLUE}\][☿:${MERCURIAL}] "
      if BRANCH=$(hg branch 2>/dev/null); then
        PS1="${PS1}\[${COLOR_CYAN}\][🌲:${BRANCH}] "
      fi
      if DIRTY=$(hg status 2>/dev/null | wc -l 2>/dev/null); then
        if [ $DIRTY -gt 0 ]; then
          PS1="${PS1}\[${COLOR_RED}\][💩:${DIRTY}] "
        fi
      fi
    fi

    # Git repo support
    if [ "${GIT}" ]; then
      PS1="${PS1}\[${COLOR_LIGHTBLUE}\][G:${GIT}] "
      if BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null); then
        if [ "${BRANCH}" == "HEAD" ]; then
	  BRANCH="(detached head state)"
	fi
        PS1="${PS1}\[${COLOR_CYAN}\][🌲:${BRANCH}] "
      fi
      if DIRTY=$(git status --porcelain 2>/dev/null | wc -l 2>/dev/null | xargs); then
        if [ $DIRTY -gt 0 ]; then
          PS1="${PS1}\[${COLOR_RED}\][💩:${DIRTY}] "
        fi
      fi
    fi

    # Python Virtualenv support
    if [ "${VIRTUAL_ENV}" ]; then
      VENV=$(basename $VIRTUAL_ENV)
      PS1="${PS1}\[${COLOR_YELLOW}\][🐍:${VENV}] "
    fi

    # Bracket {
    if [ ${UID} -eq 0 ]; then
        if [ "${USER}" == "${LOGNAME}" ]; then
            if [[ ${SUDO_USER} ]]; then
                PS1="${PS1}\[${COLOR_RED}\]"
            else
                PS1="${PS1}\[${COLOR_LIGHTRED}\]"
            fi
        else
            PS1="${PS1}\[${COLOR_YELLOW}\]"
        fi
    else
        if [ "${USER}" == "${LOGNAME}" ]; then
            PS1="${PS1}\[${COLOR_GREEN}\]"
        else
            PS1="${PS1}\[${COLOR_BROWN}\]"
        fi
    fi
    PS1="${PS1}{ "

    # Working directory
    if [ -w "${PWD}" ]; then
        PS1="${PS1}\[${COLOR_GREEN}\]$(prompt_workingdir)"
    else
        PS1="${PS1}\[${COLOR_RED}\]$(prompt_workingdir)"
    fi

    # Closing bracket } and $\#
    if [ ${UID} -eq 0 ]; then
        if [ "${USER}" == "${LOGNAME}" ]; then
            if [[ ${SUDO_USER} ]]; then
                PS1="${PS1}\[${COLOR_RED}\]"
            else
                PS1="${PS1}\[${COLOR_LIGHTRED}\]"
            fi
        else
            PS1="${PS1}\[${COLOR_YELLOW}\]"
        fi
    else
        if [ "${USER}" == "${LOGNAME}" ]; then
            PS1="${PS1}\[${COLOR_GREEN}\]"
        else
            PS1="${PS1}\[${COLOR_BROWN}\]"
        fi
    fi
    PS1="${PS1} }\$\[${COLOR_DEFAULT}\] "
}

# Trim working dir to 1/4 the screen width
function prompt_workingdir () {
  local pwdmaxlen=$(($COLUMNS/4))
  local trunc_symbol="..."
  if [[ $PWD == $HOME* ]]; then
    newPWD="~${PWD#$HOME}"
  else
    newPWD=${PWD}
  fi
  if [ ${#newPWD} -gt $pwdmaxlen ]; then
    local pwdoffset=$(( ${#newPWD} - $pwdmaxlen + 3 ))
    newPWD="${trunc_symbol}${newPWD:$pwdoffset:$pwdmaxlen}"
  fi
  echo $newPWD
}

# Determine what prompt to display:
# 1.  Display simple custom prompt for shell sessions started
#     by script.
# 2.  Display "bland" prompt for shell sessions within emacs or
#     xemacs.
# 3   Display promptcmd for all other cases.

function load_prompt () {
    # Get PIDs
    local parent_process=$(/bin/ps -p ${PPID} -o command= | cut -d \. -f 1)
    local my_process=$(/bin/ps -p $$ -o command= | cut -d \. -f 1)

    if  [[ $parent_process == script* ]]; then
        PROMPT_COMMAND=""
        PS1="\t - \# - \u@\H { \w }\$ "
    elif [[ $parent_process == emacs* || $parent_process == xemacs* ]]; then
        PROMPT_COMMAND=""
        PS1="\u@\h { \w }\$ "
    else
        export DAY=$(/bin/date +%A)
        PROMPT_COMMAND=promptcmd
     fi
    export PS1 PROMPT_COMMAND
}

load_prompt
