@echo off
setlocal enabledelayedexpansion

:Initialize
    set _FORCE=N
    if "%1" EQU "--force" (
        set _FORCE=Y
        shift
    )
    set _COMMAND=%1
    set _ARG1=%2
    set _ARG2=%3
    set _ARG3=%4

    if "%_COMMAND%" EQU "" goto :Menu
    if "%_COMMAND%" EQU "--prune" ( call :prune %_ARG1% & goto :eof )
    if "%_COMMAND%" EQU "--show-current" ( call :show-current %_ARG1% & goto :eof )
    if "%_COMMAND%" EQU "--pull" ( call :pull %_ARG1% %_ARG2% & goto :eof )
    if "%_COMMAND%" EQU "--checkout" ( call :checkout %_ARG1% %_ARG2% %_ARG3% & goto :eof )
    if "%_COMMAND%" EQU "--gc" ( call :gc %_ARG1% & goto :eof )
    if "%_COMMAND%" EQU "--ls-conflicted" ( call :ls-conflicted %_ARG1% & goto :eof )
    if "%_COMMAND%" EQU "--reset" ( call :reset %_ARG1% & goto :eof )
    if "%_COMMAND%" EQU "--show-auth" ( call :show-auth %_ARG1% & goto :eof )
    if "%_COMMAND%" EQU "--set-token" ( call :set-token %_ARG1% %_ARG2% & goto :eof )
    if "%_COMMAND%" EQU "--log" (
        if "%_ARG3%" EQU "" goto :BadParam
        call :log %_ARG1% %_ARG2% %_ARG3%
        goto :eof
    )
    
    goto :BadParam

:Menu
    cls
    echo.
    echo [ Git-Hi 擴充指令選單 ]
    echo.
    echo  (1) --prune all            (2) --show-current all
    echo  (3) --pull all             (4) --checkout all master
    echo  (5) --gc all               (6) --ls-conflicted all
    echo  (7) --reset all            (8) --show-auth all
    echo  (9) --set-token all {token}
    echo.
    echo  (q) 離開
    echo.
    choice /C 123456789q /M "請選擇:"
    
    if errorlevel 10 goto :eof
    if errorlevel 9 (
        set /p _TOK=請輸入新 Token:
        call :set-token all !_TOK!
        pause
        goto :Menu
    )
    if errorlevel 8 ( call :show-auth all & pause & goto :Menu )
    if errorlevel 7 ( call :reset all & pause & goto :Menu )
    if errorlevel 6 ( call :ls-conflicted all & pause & goto :Menu )
    if errorlevel 5 ( call :gc all & pause & goto :Menu )
    if errorlevel 4 ( call :checkout all master & pause & goto :Menu )
    if errorlevel 3 ( call :pull all & pause & goto :Menu )
    if errorlevel 2 ( call :show-current all & pause & goto :Menu )
    if errorlevel 1 ( call :prune all & pause & goto :Menu )
    goto :eof

:BadParam
    echo 使用方式：
    echo   git hi [--force] --prune {project^|all}
    echo   git hi [--force] --show-current {project^|all}
    echo   git hi [--force] --pull {project^|all} [stream]
    echo   git hi [--force] --checkout {project^|all} {branch}
    echo   git hi [--force] --gc {project^|all}
    echo   git hi [--force] --ls-conflicted {project^|all}
    echo   git hi [--force] --reset {project^|all}
    echo   git hi --log {project^|all} {tag1} {tag2}
    echo   git hi --show-auth {project^|all}
    echo   git hi --set-token {project^|all} {token^|user:token}
    goto :eof

:choiceProject
    set "R_choiceProject=%~1"
    if "%R_choiceProject%" EQU "" exit /b 1
    if "%R_choiceProject%" EQU "all" (
        set "Projects=*"
    ) else (
        set "Projects=%R_choiceProject%"
    )
    exit /b 0

:getMainBranch
    :: 預設為 master
    set "DETECTED_MAIN=master"
    :: 嘗試從遠端抓取 HEAD 資訊
    for /f "tokens=3" %%i in ('git remote show origin ^| findstr "HEAD branch"') do (
        set "DETECTED_MAIN=%%i"
    )
    :: 如果抓不到遠端，檢查本地是否有 main 分支
    if "%DETECTED_MAIN%" EQU "master" (
        git rev-parse --verify main >nul 2>&1
        if !errorlevel! EQU 0 set "DETECTED_MAIN=main"
    )
    exit /b 0

:prune
    call :choiceProject %1 || goto :BadParam
    for /d %%d in (%Projects%) do (
        if exist "%%d\.git" (
            echo [%%d] 清理中...
            pushd %%d
            git fetch -v --progress --prune "origin"
            :: 刪除已不存在於遠端的本地分支
            for /f "tokens=1" %%a in ('git branch -vv ^| findstr ": gone]"') do (
                set "br=%%a"
                if "!br:~0,1!" NEQ "*" git branch -D !br!
            )
            popd
        )
    )
    exit /b 0

:show-current
    call :choiceProject %1 || goto :BadParam
    for /d %%d in (%Projects%) do (
        if exist "%%d\.git" (
            pushd %%d
            for /f "tokens=*" %%b in ('git branch --show-current') do set "cur=%%b"
            echo [%%d] -^> !cur!
            popd
        )
    )
    exit /b 0

:pull
    call :choiceProject %1 || goto :BadParam
    set "stream=%~2"
    if "%stream%" EQU "" set "stream=origin"
    for /d %%d in (%Projects%) do (
        if exist "%%d\.git" (
            echo [%%d] Pulling...
            pushd %%d
            if "%_FORCE%" EQU "Y" ( git reset --hard HEAD & git clean -fxd )
            git pull -v --progress %stream%
            popd
        )
    )
    exit /b 0

:checkout
    call :choiceProject %1 || goto :BadParam
    set "branch=%~2"
    if "%branch%" EQU "" goto :BadParam
    for /d %%d in (%Projects%) do (
        if exist "%%d\.git" (
            echo [%%d] Checkout %branch%...
            pushd %%d
            if "%_FORCE%" EQU "Y" ( git reset --hard HEAD & git clean -fxd )
            git checkout %branch%
            popd
        )
    )
    exit /b 0

:ls-conflicted
    call :choiceProject %1 || goto :BadParam
    for /d %%d in (%Projects%) do (
        if exist "%%d\.git" (
            echo [%%d] 衝突檔案：
            pushd %%d
            git diff --name-only --diff-filter=U
            popd
        )
    )
    exit /b 0

:reset
    call :choiceProject %1 || goto :BadParam
    for /d %%d in (%Projects%) do (
        if exist "%%d\.git" (
            pushd %%d
            call :getMainBranch
            echo [%%d] 強制重置至 !DETECTED_MAIN!...
            if "%_FORCE%" EQU "Y" git clean -fxd
            git checkout -f !DETECTED_MAIN!
            git reset --hard origin/!DETECTED_MAIN!
            popd
        )
    )
    exit /b 0

:log
    call :choiceProject %1 || goto :BadParam
    set "t1=%~2"
    set "t2=%~3"
    for /d %%d in (%Projects%) do (
        if exist "%%d\.git" (
            echo [%%d] 產出 Log...
            pushd %%d
            git rev-parse %t1% >nul 2>&1 && git rev-parse %t2% >nul 2>&1
            if !errorlevel! EQU 0 (
                git --no-pager log %t1%..%t2% > ..\%%d_log.txt
                echo   -^> 已存至 %%d_log.txt
            ) else (
                echo   -^> 錯誤：找不到 Tag
            )
            popd
        )
    )
    exit /b 0

:gc
    call :choiceProject %1 || goto :BadParam
    for /d %%d in (%Projects%) do (
        if exist "%%d\.git" (
            echo [%%d] 優化中...
            pushd %%d & git gc --aggressive & popd
        )
    )
    exit /b 0

:show-auth
    call :choiceProject %1 || goto :BadParam
    for /d %%d in (%Projects%) do (
        if exist "%%d\.git" (
            echo [%%d]
            pushd %%d
            set "remote_url="
            for /f "tokens=*" %%u in ('git config --get remote.origin.url') do set "remote_url=%%u"

            if "!remote_url!" EQU "" (
                echo   無 remote origin
            ) else (
                echo   Remote URL: !remote_url!

                set "prefix=!remote_url:~0,8!"
                if /I not "!prefix!"=="https://" (
                    echo   驗證模式: ssh/other
                    echo   非 HTTPS remote，無法從 config URL 解析 token
                ) else (
                    set "rest=!remote_url:~8!"
                    for /f "tokens=1* delims=/" %%a in ("!rest!") do (
                        set "authority=%%a"
                        set "path_part=%%b"
                    )

                    set "userinfo="
                    set "host=!authority!"
                    for /f "tokens=1,2 delims=@" %%a in ("!authority!") do (
                        if not "%%b"=="" (
                            set "userinfo=%%a"
                            set "host=%%b"
                        )
                    )

                    if "!userinfo!"=="" (
                        echo   驗證模式: https ^(no token in remote.origin.url^)
                        echo   Token: 未設定在 config URL
                    ) else (
                        set "username="
                        set "token="
                        for /f "tokens=1,2 delims=:" %%a in ("!userinfo!") do (
                            set "username=%%a"
                            set "token=%%b"
                        )
                        if "!token!"=="" (
                            set "token=!userinfo!"
                            set "username="
                        )
                        echo   驗證模式: token ^(from remote.origin.url^)
                        if "!username!"=="" (
                            echo   使用者名稱: 未指定
                        ) else (
                            echo   使用者名稱: !username!
                        )
                        echo   Token: !token!
                    )
                )
            )
            popd
        )
    )
    exit /b 0

:set-token
    call :choiceProject %1 || goto :BadParam
    set "input_raw=%~2"
    if "%input_raw%" EQU "" goto :BadParam

    set "has_user_token_pair=N"
    set "forced_username="
    set "new_token=%input_raw%"
    for /f "tokens=1* delims=:" %%a in ("%input_raw%") do (
        if not "%%b"=="" (
            set "has_user_token_pair=Y"
            set "forced_username=%%a"
            set "new_token=%%b"
        )
    )
    if "%new_token%" EQU "" goto :BadParam

    for /d %%d in (%Projects%) do (
        if exist "%%d\.git" (
            pushd %%d
            set "remote_url="
            for /f "tokens=*" %%u in ('git config --get remote.origin.url') do set "remote_url=%%u"

            if "!remote_url!" EQU "" (
                echo [%%d] 無 remote origin，略過
            ) else (
                set "prefix=!remote_url:~0,8!"
                if /I not "!prefix!"=="https://" (
                    echo [%%d] 非 HTTPS remote，略過
                ) else (
                    set "rest=!remote_url:~8!"
                    for /f "tokens=1* delims=/" %%a in ("!rest!") do (
                        set "authority=%%a"
                        set "path_part=%%b"
                    )

                    set "userinfo="
                    set "host=!authority!"
                    for /f "tokens=1,2 delims=@" %%a in ("!authority!") do (
                        if not "%%b"=="" (
                            set "userinfo=%%a"
                            set "host=%%b"
                        )
                    )

                    set "username="
                    set "old_token="
                    if not "!userinfo!"=="" (
                        for /f "tokens=1,2 delims=:" %%a in ("!userinfo!") do (
                            set "username=%%a"
                            set "old_token=%%b"
                        )
                        if "!old_token!"=="" set "username="
                    )

                    if "!has_user_token_pair!"=="Y" set "username=!forced_username!"

                    if "!username!"=="" (
                        set "new_url=https://!new_token!@!host!/!path_part!"
                    ) else (
                        set "new_url=https://!username!:!new_token!@!host!/!path_part!"
                    )

                    git config remote.origin.url "!new_url!"
                    echo [%%d] Token 已更新（直接寫入 remote.origin.url）
                )
            )
            popd
        )
    )
    exit /b 0