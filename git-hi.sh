#!/bin/zsh

# --- 全域變數初始化 ---
FORCE=false
PROJECT_LIST=()

# --- 內部輔助函式 ---

# 顯示使用說明
show_help() {
    echo "\033[1;34mGit 自定義擴充工具 (git-hi)\033[0m"
    echo "使用方式:"
    echo "  git hi --prune {project|all}          清理遠端已刪除的本地分支"
    echo "  git hi --show-current {project|all}   顯示目前分支名稱"
    echo "  git hi [--force] --pull {project|all} [remote]"
    echo "  git hi [--force] --checkout {project|all} {branch}"
    echo "  git hi --gc {project|all}             執行垃圾回收優化"
    echo "  git hi --ls-conflicted {project|all}  列出衝突檔案"
    echo "  git hi [--force] --reset {project|all} 自動偵測主分支並強制重置"
    echo "  git hi --log {project|all} {t1} {t2}  產出兩個 Tag 間的變更報告"
    echo ""
    echo "參數說明:"
    echo "  --force    執行 pull/checkout/reset 前先進行 git clean 與 hard reset"
    echo "  project     指定專案資料夾名稱 (必填)，可以用相對路徑或絕對路徑，只要該目錄裡有 .git 就會被視為 Git 專案"
    echo "  all         代表當前目錄下的所有資料夾 (包含子資料夾) 都會被視為 Git 專案來執行對應的 Git 操作"
}

# 選擇專案目錄 (過濾出含有 .git 的資料夾)
choice_projects() {
    local target=$1
    if [[ -z "$target" ]]; then
        show_help
        exit 1
    fi

    if [[ "$target" == "all" ]]; then
        PROJECT_LIST=( *(ND/) )
    else
        if [[ -d "$target" ]]; then
            PROJECT_LIST=("$target")
        else
            echo "\033[1;31m錯誤：目錄 '$target' 不存在。\033[0m"
            exit 1
        fi
    fi
}

# 自動偵測主分支名稱 (main or master)
get_main_branch() {
    # 優先從遠端 HEAD 取得，若失敗則檢查本地
    local branch=$(git remote show origin 2>/dev/null | sed -n '/HEAD branch/s/.*: //p')
    if [[ -z "$branch" ]]; then
        if git show-ref --verify --quiet refs/heads/main; then
            branch="main"
        else
            branch="master"
        fi
    fi
    echo "$branch"
}

# --- 指令功能實作 ---

do_prune() {
    choice_projects $1
    for d in $PROJECT_LIST; do
        if [[ -d "$d/.git" ]]; then
            echo "\033[1;32m[$d]\033[0m 正在清理分支..."
            (cd "$d" && git fetch -v --progress --prune "origin")
            (cd "$d" && git branch -vv | grep ": gone]" | awk '{print $1}' | tr -d '*' | xargs -r git branch -D)
        fi
    done
}

do_show_current() {
    choice_projects $1
    for d in $PROJECT_LIST; do
        if [[ -d "$d/.git" ]]; then
            local branch=$(cd "$d" && git branch --show-current)
            echo "[$d] -> \033[1;33m$branch\033[0m"
        fi
    done
}

do_ls_conflicted() {
    choice_projects $1
    for d in $PROJECT_LIST; do
        if [[ -d "$d/.git" ]]; then
            echo "\033[1;31m[$d] 衝突檔案列表：\033[0m"
            local conflicts=$(cd "$d" && git diff --name-only --diff-filter=U)
            if [[ -n "$conflicts" ]]; then
                echo "$conflicts"
            else
                echo "  (目前無衝突)"
            fi
        fi
    done
}

do_reset() {
    choice_projects $1
    for d in $PROJECT_LIST; do
        if [[ -d "$d/.git" ]]; then
            cd "$d"
            local main_branch=$(get_main_branch)
            echo "[$d] 正在重置至 \033[1;36m$main_branch\033[0m..."
            
            [[ "$FORCE" == true ]] && git reset --hard HEAD && git clean -fxd
            
            git checkout -f "$main_branch"
            git reset --hard "origin/$main_branch"
            cd ..
        fi
    done
}

do_log() {
    choice_projects $1
    local t1=$2
    local t2=$3
    [[ -z "$t1" || -z "$t2" ]] && echo "請提供 tag1 與 tag2" && return

    for d in $PROJECT_LIST; do
        if [[ -d "$d/.git" ]]; then
            echo "[$d] 產出 Log 中..."
            (cd "$d" && git --no-pager log "$t1..$t2" > "../${d}_log.txt" 2>/dev/null) && \
            echo "  -> 已儲存至 ${d}_log.txt" || echo "  -> \033[1;31m失敗：找不到 Tag\033[0m"
        fi
    done
}

# --- 主程式進入點 ---

# 檢查 --force
if [[ "$1" == "--force" ]]; then
    FORCE=true
    shift
fi

# 指令分流
case "$1" in
    --prune)          do_prune $2 ;;
    --show-current)   do_show_current $2 ;;
    --ls-conflicted)  do_ls_conflicted $2 ;;
    --reset)          do_reset $2 ;;
    --log)            do_log $2 $3 $4 ;;
    --pull)
        choice_projects $2; stream=${3:-"origin"}
        for d in $PROJECT_LIST; do
            if [[ -d "$d/.git" ]]; then
                echo "[$d] Pulling..."; cd "$d"
                [[ "$FORCE" == true ]] && git reset --hard HEAD && git clean -fxd
                git pull -v --progress "$stream"; cd ..
            fi
        done ;;
    --checkout)
        choice_projects $2; branch=$3
        for d in $PROJECT_LIST; do
            if [[ -d "$d/.git" ]]; then
                echo "[$d] Checkout..."; cd "$d"
                [[ "$FORCE" == true ]] && git reset --hard HEAD && git clean -fxd
                git checkout "$branch"; cd ..
            fi
        done ;;
    --gc)
        choice_projects $2
        for d in $PROJECT_LIST; do (cd "$d" && echo "[$d] GC..." && git gc --aggressive); done ;;
    *)
        show_help ;;
esac