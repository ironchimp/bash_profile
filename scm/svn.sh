# SVN configurations for 
export __SVN_BASE_URL__="http://subversion.ny.jpmorgan.com/svn/repos"

svn_update() {
    svn update $__PROJECT_DIR__
}

svn_changes() {
    svn diff $__PROJECT_DIR__
}

svn_commit() {
    svn commit $__PROJECT_DIR__
}

svn_checkout() {
    meta=$1
    project=$2
    url="${__SVN_BASE_URL__}/${meta}/${project}/trunk"
    svn co ${url} ${__SCM_DIR__}/${meta}/${project}
}