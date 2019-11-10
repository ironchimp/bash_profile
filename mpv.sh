# MVP Management environment configuration
__SCRIPT_DIR__=~/.config/bash

# Specify the location of the development root directory here
__DEV_SPACE__=$HOME/development
if [[ ! -d ${__DEV_SPACE__} ]]; then
    echo "IMPORTANT: Please create a directory / symlink for development at the following location: ${__DEV_SPACE__}"
fi

#Contains the current M/P/V data
__CURRENT_SCM__=
__CURRENT_META__=
__CURRENT_PROJECT__=
__CURRENT_APP__=

__SCM_DIR__=
__CONFIG_DIR__=
__META_DIR__=
__PROJECT_DIR__=
__APP_DIR__=
__HOSTNAME__=`hostname`

# =============================================================================
# Utility Functions

find_subdirs()
{
    if [[ -z $1 ]]; then
        echo "No parent directory specified"
        return 1
    fi
    
    if [[ -d $1 ]]; then
        find $1 -maxdepth 1 -mindepth 1 -type d -not -iname ".*" -exec basename {} \;
    fi
}

choose_item() 
{
    if [[ -z $1 ]]; then
        echo "No array specified"
        return 1
    fi

    if [[ -z $2 ]]; then
        echo "No target variable presented"
        return 2
    fi
    declare -a items=("${!1}")
    num_items=${#items[@]}
    num_items=$(( $num_items - 1 ))
    echo "Available choices are:"
    for idx in "${!items[@]}"; do
        echo "   ${idx}) ${items[idx]}"
    done
    read -p "Enter selection (0-${num_items}): " selected_item
    if [[ -z "${selected_item##+([0-9])}" && "${selected_item}" -ge "0" && "${selected_item}" -le "${num_items}" ]]; then
        eval "$2=${items[selected_item]}"
        return 0
    else
        echo "Selection Cancelled"
    fi
    return 3
}

in_array() {
    declare -a array_to_search=("${!1}")
    local item_to_find=${2}
    for i in ${array_to_search[@]}; do
        if [[ "${i}" == "${item_to_find}" ]]; then
            return 0
        fi
    done
    return 1
}

verify_selection()
{
    available_items_array=$1
    new_value=$2
    target_variable=$3

    in_array $available_items_array $new_value
    if [[ $? -eq 0 ]]; then
        eval "$target_variable=\"$new_value\""
        return 0
    fi

    if [[ -z "$new_value" ]]; then
        choose_item $available_items_array $target_variable
        if [[ $? -ne 0 ]]; then
            echo "failed to chose the item"
            return 1
        fi
    fi
}

truncate_path()
{
    tmp="$1"
    var="$2"
    c=${tmp: -1}
    if [[ "$c" != "/" ]]; then
        pth="${tmp}/"
    else
        pth="${tmp}"
    fi
    
    if [[ ! -z ${__APP_DIR__} ]]; then
        v="$__APP_DIR__/"
        pth="${pth//$v/app/}"
    fi
    
    if [[ ! -z ${__PROJECT_DIR__} ]]; then
        v="$__PROJECT_DIR__/"
        pth="${pth//$v/root/}"
    fi

    if [[ ! -z ${__META_DIR__} ]]; then
        v="$__META_DIR__/"
        pth="${pth//$v/meta/}"
    fi

    if [[ ! -z ${__SCM_DIR__} ]]; then
        v="$__SCM_DIR__/"
        pth="${pth//$v/scmroot/}"
    fi

    if [[ ! -z ${__DEV_SPACE__} ]]; then
        v="$__DEV_SPACE__/"
        pth="${pth//$v/devspace/}"
    fi
  
    #finaly....    
    v="${HOME}"
    pth="${pth//$v/\\\~}"
    
    eval $var=$pth
}

settitle() { 
    echo -ne "\e]2;$@\a\e]1;$@\a"
}

setprompt()
{
    last_status=$?
    bgray='\[\e[1;34m\]'
    byellow='\[\e[1;33m\]'
    dblue='\[\e[36m\]'
    bblue='\[\e[1;36m\]'
    bgreen='\[\e[1;32m\]'
    dgreen='\[\e[32m\]'
    bwhite='\[\e[1;37m\]'
    bred='\[\e[1;31m\]'
    happyface='\[\e[1;33m\]'
    sadface='\[\e[1;31m\]'
    plain='\[\e[m\]'
    
    if [[ $last_status -ne 0 ]]; then
        face='( =_=)'
        facecol=$sadface
    else
        face='( ^_^)'
        facecol=$happyface
    fi
    scm_upper=`echo ${__CURRENT_SCM__} | tr '[:lower:]' '[:upper:]'`
    truncate_path $PWD "tpath"
    settitle "${__HOSTNAME__}"
    export PS1="${bgray}SCM:${dblue}${scm_upper}${bgray} MVPA:${dblue}${__CURRENT_META__:-_}${bwhite}/${dblue}${__CURRENT_PROJECT__:-_}${bwhite}/${dblue}${__CURRENT_APP__:-_} ${bgray}PWD:${dblue}${tpath}\n${bgray}[${dblue}${__HOSTNAME__}${bgray}]${facecol}${face} ${bgray}> ${plain}"
    export PS2="${facecol}...... ${bgray}>${plain} "
}

# =============================================================================
# SCM Management Functions
available_scm()
{
    find ${__SCRIPT_DIR__}/scm -type f -exec basename {} \; | sed "s/\.sh//g"
}

write_last_scm()
{
    echo ${__CURRENT_SCM__} > ${__DEV_SPACE__}/.scm
}

load_scm_state() {
    __CURRENT_META__=
    __CURRENT_PROJECT__=
    __CURRENT_APP__=
    __SCM_DIR__=${__DEV_SPACE__}/${__CURRENT_SCM__}
    __CONFIG_DIR__=${__SCM_DIR__}/.mpv
    mkdir -p ${__CONFIG_DIR__}
    source ${__SCRIPT_DIR__}/scm/${__CURRENT_SCM__}.sh
    lastmeta=`cat $__CONFIG_DIR__/lastmeta`
    if [[ ! -z $lastmeta ]]; then
        change_meta $lastmeta
        return $?
    fi
    return 0
}

change_scm()
{
    new_scm=
    readarray -t scm_list <<< `available_scm | sort`
    verify_selection scm_list[@] "$1" new_scm
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    __CURRENT_SCM__=$new_scm
    write_last_scm
    load_scm_state
    return $?
}

load_last_scm()
{
    last_scm=`cat ${__DEV_SPACE__}/.scm`
    if [[ ! -z $last_scm ]]; then
        change_scm $last_scm
    fi
}

# =============================================================================
# Meta Management Functions

available_meta()
{
    find_subdirs $__SCM_DIR__
}

write_last_meta()
{
    echo $__CURRENT_META__ > $__CONFIG_DIR__/lastmeta
}

load_meta_state()
{
    __CURRENT_APP__=
    __CURRENT_PROJECT__=
    __META_DIR__=$__SCM_DIR__/$__CURRENT_META__
    mfile="$__CONFIG_DIR__/$__CURRENT_META__.lastproject"
    if [[ -f $mfile ]]; then
        __CURRENT_PROJECT__=`cat $mfile`
        load_project_state
        return $?
    fi
    return 0
}

change_meta()
{
    new_meta=
    readarray -t meta_list <<< `available_meta | sort -z`
    verify_selection meta_list[@] "$1" new_meta
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    __CURRENT_META__=$new_meta
    write_last_meta
    load_meta_state
    return $?
}

# =============================================================================
# Project Management Functions

available_projects()
{
    find_subdirs $__META_DIR__
}

write_last_project()
{
    echo $__CURRENT_PROJECT__ > $__CONFIG_DIR__/$__CURRENT_META__.lastproject
}

load_project_state()
{
    __CURRENT_APP__=
    __PROJECT_DIR__=$__META_DIR__/$__CURRENT_PROJECT__
    vfile="$__CONFIG_DIR__/$__CURRENT_META__.$__CURRENT_PROJECT__.lastapp"
    if [[ -f $vfile ]]; then
        __CURRENT_APP__=`cat $vfile`
        load_app_state
        return $?
    fi
    return 0
}

change_project()
{
    new_project=
    readarray -t project_list <<< `available_projects | sort -z`
    verify_selection project_list[@] "$1" new_project
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    __CURRENT_PROJECT__=$new_project
    write_last_project
    load_project_state
    return $?
}

# =============================================================================
# App Management Functions
available_apps()
{
    find_subdirs $__PROJECT_DIR__
}

write_last_app()
{
    echo $__CURRENT_APP__ > $__CONFIG_DIR__/$__CURRENT_META__.$__CURRENT_PROJECT__.lastapp
}

load_app_state()
{
    __APP_DIR__=$__PROJECT_DIR__/$__CURRENT_APP__
    return 0
}

change_app()
{
    new_app=
    readarray -t app_list <<< `available_apps | sort -z`
    verify_selection app_list[@] "$1" new_app
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    __CURRENT_APP__=$new_app
    write_last_app
    load_app_state
    return $?
}

# =============================================================================
# Navigation Functions

_nav()
{
    eval to_dir=\$$1
    shift
    cd $to_dir/$*
}

alias root='_nav __PROJECT_DIR__'
alias src='_nav __APP_DIR__/src'
alias scmroot='_nav __SCM_DIR__'
alias devspace='_nav __DEV_SPACE__'

scm()
{
    if [[ $# -ge 1 ]]; then
        if [[ "$1" == -* ]]; then
            case "$1" in
                "-?" )
                    available_scm
                    return 0
                    ;;
                "-c" )
                    shift
                    change_scm "$1"
                    root
                    ;;
                * )
                    echo "Unknown switch: $1"
                    return 1
                    ;;
            esac
            shift
        fi
    else
        cd "$__SCM_DIR__/$*"
    fi
}

meta()
{
    if [[ $# -ge 1 ]]; then
        if [[ "$1" == -* ]]; then
            case "$1" in
                "-?" )
                    available_meta
                    return 0
                    ;;
                "-c" )
                    shift
                    change_meta "$1"
                    root
                    ;;
                * )
                    echo "Unknown switch: $1"
                    return 1
                    ;;
            esac
            shift
        fi
    else
        cd "$__META_DIR__/$*"
    fi
}

project()
{
    if [[ $# -ge 1 ]]; then
        if [[ "$1" == -* ]]; then
            case "$1" in
                "-?" )
                    available_projects
                    return 0
                    ;;
                "-c" )
                    shift
                    change_project "$1"
                    root
                    ;;
                * )
                    echo "Unknown switch: $1"
                    return 1
                    ;;
            esac
            shift
        fi
    else    
        cd "$__PROJECT_DIR__/$*"
    fi
}

app()
{
    if [[ $# -ge 1 ]]; then
        if [[ "$1" == -* ]]; then
            case "$1" in
                "-?" )
                    available_apps
                    return 0
                    ;;
                "-c" )
                    shift
                    change_app "$1"
                    app
                    ;;
                * )
                    echo "Unknown switch: $1"
                    return 1
                    ;;
            esac
            shift
        fi
    else    
        cd "$__APP_DIR__/$*"
    fi
}

mvpa()
{
    if [[ $# -ge 1 ]]; then
        change_meta $1
    fi
    if [[ $# -ge 2 ]]; then
        change_project $2
    fi
    if [[ $# -ge 3 ]]; then
        change_app $3
    fi
}

# =============================================================================
# Utilities

find_src()
{
    key="$*"
    grep -rHni "$key" $__PROJECT_DIR__/*/src/* | grep -v ".svn/"
}

is_root_dir_valid()
{
    if [[ ! -d $__PROJECT_DIR__ ]]; then
        echo "Location of $__CURRENT_META__/$__CURRENT_PROJECT__ does not seem to be valid"
        return 1
    fi 
    return 0
}   

update()
{
    is_root_dir_valid
    if [[ $? -eq 0 ]]; then
        ${__CURRENT_SCM__}_update
    fi
}

changes()
{
    is_root_dir_valid
    if [[ $? -eq 0 ]]; then
        ${__CURRENT_SCM__}_changes
    fi
}

commit()
{
    is_root_dir_valid
    if [[ $? -eq 0 ]]; then
         ${__CURRENT_SCM__}_commit
    fi
}

__nav_or_create_dir() 
{
    if [[ $# -ne 1 ]]; then
        echo "Usage: $0 <dirname>"
        return 1
    fi
    if [[ ! -d $1 ]]; then
        mkdir $1
    fi
    cd $1
}

checkout()
{
    if [[ $# -lt 2 || $# -gt 3 ]]; then
        echo "Usage $0 <meta> <project> [tag]"
        return 1
    fi

    meta=$1
    project=$2
    
    if [[ -d ${__SCM_DIR__}/${meta}/${project} ]]; then
        echo "Project location already exists: Not checking out - please repair if required"
        return 1
    fi

    clean_project=0
    clean_meta=0
    if [[ ! -d ${__SCM_DIR__}/${meta}/${project}/ ]]; then
        clean_project=1
    fi
    if [[ ! -d ${__SCM_DIR__}/${meta}/ ]]; then
        clean_meta=1
    fi

    ${__CURRENT_SCM__}_checkout $meta $project
    success=$?

    if [[ ${success} -ne 0 ]]; then
        rm -rf ${__SCM_DIR__}/${meta}/${project}

        if [[ ${clean_project} == 1 ]]; then
            rm -rf ${__SCM_DIR__}/${meta}/${project}
        fi
        if [[ ${clean_meta} == 1 ]]; then
            rm -rf ${__SCM_DIR__}/${meta}
        fi
    else
        mvpa ${meta} ${project}
        root
    fi
}

export PROMPT_COMMAND='setprompt'
load_last_scm
