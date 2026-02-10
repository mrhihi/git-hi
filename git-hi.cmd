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
    echo  (7) --reset all
    echo.
    echo  (q) 離開
    echo.
    choice /C 1234567q /M "請選擇:"
    
    if errorlevel 8 goto :eof
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