export __GIT_BASE_URL__="ssh://git@stash-prod2.us.jpmchase.net:7999"

git_update() {
    old_dir=`pwd`
    cd $__PROJECT_DIR__
    git rebase
    status=$?
    cd $old_dir
    return $status
}

git_changes() {
    old_dir=`pwd`
    cd $__PROJECT_DIR__
    git diff
    status=$?
    cd $old_dir
    return $status
}

git_commit() {
    old_dir=`pwd`
    cd $__PROJECT_DIR__
    git commit -a
    status=$?
    cd $old_dir
    return $status
}

git_checkout() {
    meta=`echo $1 | tr '[:upper:]' '[:lower:]'`
    project=`echo $2 | tr '[:upper:]' '[:lower:]'`
    meta_dir=$meta
    if [[ "${meta}" == "$USER" ]]; then
        meta="~$USER"
    fi
    url="${__GIT_BASE_URL__}/${meta}/${project}.git"
    echo $url
    git clone ${url} ${__SCM_DIR__}/${meta_dir}/${project}
}
