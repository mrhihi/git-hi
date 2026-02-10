# git-hi

本專案提供兩個平台的 Git 擴充腳本：

- [`git-hi.sh`](git-hi.sh:1) (macOS / Linux，zsh 腳本)
- [`git-hi.cmd`](git-hi.cmd:1) (Windows，Batch 檔)

用途：在多個專案資料夾上執行常用的 Git 維護動作（pull、checkout、prune、gc、reset、列出衝突、產出 tag 間變更等）。

## 安裝

### macOS / Linux

1. 將 [`git-hi.sh`](git-hi.sh:1) 複製並放到系統 PATH 中，並移除副檔名或命名為 `git-hi`：

   sudo cp git-hi.sh /usr/local/bin/git-hi
   sudo chmod +x /usr/local/bin/git-hi

2. 確認 /usr/local/bin 在你的 PATH（或選擇其他已在 PATH 的目錄）。
3. `git` 會自動把 `git-hi` 當作子指令，透過 `git hi ...` 呼叫。

注意：腳本採用 `#!/bin/zsh`，若系統沒有 zsh，請安裝或修改為你系統的 shell。

### Windows

1. 將 [`git-hi.cmd`](git-hi.cmd:1) 放到系統 PATH 中的資料夾（例如 `C:\Users\你\bin`，並將該資料夾加入 PATH）。
2. 如果已經加入 PATH ，且重新開啟 Terminal 後仍沒作用，執行以下命令來設定 git alias：

```bash
git config --global alias.hi "!git-hi.cmd"
```

3. 在 cmd 或 PowerShell 中可直接使用 `git hi ...` 呼叫（Git 會找到 `git-hi.cmd` 來執行）。

## 使用方法（概覽）

基本語法：  

```bash
  git hi [--force] --prune {project|all}
  git hi [--force] --show-current {project|all}
  git hi [--force] --pull {project|all} [remote]
  git hi [--force] --checkout {project|all} {branch}
  git hi [--force] --gc {project|all}
  git hi [--force] --ls-conflicted {project|all}
  git hi [--force] --reset {project|all}
  git hi --log {project|all} {tag1} {tag2}
```

參數說明：

- `--force`：在執行 pull/checkout/reset 前會先執行 `git reset --hard HEAD` 與 `git clean -fxd`（請小心使用，會清除未追蹤與未提交的變更）。
- `project`：指定資料夾名稱（相對或絕對路徑），該目錄內含 `.git` 即會被視為 Git 專案。
- `all`：代表當前目錄下的所有資料夾（包含子資料夾）都會被視為專案。

## 範例

- 清理遠端已刪除的本地分支（所有專案）：

  git hi --prune all

- 顯示某專案目前分支：

  git hi --show-current my-project

- 在所有專案執行 pull（指定遠端）：

  git hi --pull all origin

- 使用 force 清理後再 pull（注意 --force 必須放在最前）：

  git hi --force --pull all origin

- 在所有專案切換分支：

  git hi --checkout all develop

- 強制重置至主分支（會自動偵測 `main` 或 `master`）：

  git hi --reset my-project

- 產出兩個 Tag 間的變更報告：

  git hi --log my-project v1.0.0 v1.1.0

## 注意事項

- 使用 `--force` 會丟棄未提交與未追蹤的檔案，請務必在確認無重要變更後再使用。
- 腳本透過檢查目錄下是否存在 `.git` 來識別專案；請在欲操作的上層目錄執行 `git hi`（或指定特定專案資料夾）。

---

開發者：請參閱檔案 [`git-hi.sh`](git-hi.sh:1) 與 [`git-hi.cmd`](git-hi.cmd:1) 以了解完整實作與細節。  
