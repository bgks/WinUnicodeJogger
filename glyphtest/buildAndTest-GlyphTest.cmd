@set pPROMPT=%PROMPT%&&setlocal&chcp 65001&set PROMPT=$E[1A$E[32m%~n0[$T]$G$E[0m
@if "%1" == "tests" goto :TESTS
:: ===========================================================================
REM ¡ We´re building a Win32-App that simulates 
REM ¡ WinUI-behavior, not a WinUI-App!
@set ArT=x64
REM Architecture: %ArT%
REM Requirements ⇄ Visual Studio Installer→Components
REM 1.) Compiler, Buildtools and Runtimes
REM	← MSVC Build Tools core features
REM	← MSVC v14x C++ (%ArT%) Build Tools
REM 2.) Windows 10 SDK
REM	→ Direct2D → DirectWrite
REM 3.) Windows SDK – Desktop C++ (%ArT%)
:: ===========================================================================
::  v0.3 en-de 2026 🅭🅯 Björn G. Kulms assisted by Copilot ¡ No Warranties !
:: ===========================================================================
@set GlyphFallbackExe_Name=GlyphFallbackTest
REM Individual local Install {{{⚠️ You must edit these!
REM ⇅ Check VS-environment's paths for an explanation.
::set localVCROOT=C:\Program Files\Microsoft Visual Studio\2022\‹Edition›
set localVCROOT=M:\m_MSDEV\VS_22C
::set localVCROOT_Ver=‹MSVC-Version›
set localVCROOT_Ver=14.44.35207
::set localWINSDK=C:\Program Files (x86)\Windows Kits\10\
set localWINSDK=M:\m_MSDEV\_Prg_WindowsKits\10
set localWINSDK_Ver=10.0.26100.0
REM }}} Individual local Install
:: ↳ Shortcuts
@set VCROOT=%localVCROOT%\VC\Tools\MSVC\%localVCROOT_Ver%
@set WINSDK=%localWINSDK%
@set WdkIncl=%WINSDK%\Include\%localWINSDK_Ver%
@set WdkLibs=%WINSDK%\Lib\%localWINSDK_Ver%
REM ⇘ VS-environment {{{ -------------------------
set localPATH=%VCROOT%\bin\Host%ArT%\%ArT%;%WINSDK%\bin\%localWINSDK_Ver%\%ArT%
set INCLUDE=%VCROOT%\include;%WdkIncl%\um;%WdkIncl%\shared;%WdkIncl%\ucrt
set LIB=%VCROOT%\lib\%ArT%;%WdkLibs%\um\%ArT%;%WdkLibs%\ucrt\%ArT%
set LIBPATH=%VCROOT%\lib\%ArT%
@set PATH=%localPATH%;%PATH%
REM }}} VS-environment   -------------------------
:: ===========================================================================
:DISTCLEAN
@set builtfiles= GlyphTest.obj, GlyphTest.exe, %GlyphFallbackExe_Name%.exe
@for %%f in (%builtFiles%) do @if exist %%f del %%f
@if "%1" == "distclean" goto :EXIT

:BUILD
REM Directives:
REM ↱FALLBACK_DEBUG: GlyphFallbackTest Codepoint Uc
REM   Uc → "(<effective Font after Fallback>)<UcGlyph>"
set debug=/DGLYPH_FALLBACK_DEBUG
REM   Uc → "<UcGlyph>"
set debug=
REM ↳FALLBACK_DEBUG set to "%debug%"
@set compPd=/DFALLBACKEXE_NAME=L\"%GlyphFallbackExe_Name%\" %debug%
@set compPs=/EHsc /DUNICODE /D_UNICODE 
@set linkPs=/link dwrite.lib
@set RunCmd=cl.exe %compPs% %compPd% GlyphTest.cpp %linkPs%
%RunCmd%

:INSTALL
@if not exist Glyphtest.exe goto EXIT
mklink /H %GlyphFallbackExe_Name%.exe GlyphTest.exe

:TESTS
@echo.
REM ----- GlyphTest Basic Functionality -----
@call :testcase      -1 2 2  Min- 	«Range»
@call :testcase 0x110000 2 2 Max+ 	«Range»
@call :testcase     0xD 2 2  ‹CR› «special-case»
@call :testcase    0x41	0 0 A	BaseFont-
@call :testcase  0x0378	1 1
@call :testcase  0x033F 0 0  ̿ 	a& REM Combining Letter
@call :testcase  0xFFFD 0 0 ‹ReplacementChar›
@call :testcase	 0xFFFF 1 1 ‹Non-Character›
::@call :testcase	0x1F5FA 0 0 🗺️ &REM non-funct
REM ----- Fallbacks in Win11-Priority -------
@call :testcase 0x1F600 1 0 😀	-Emoji:
@call :testcase 0x1D4B7 1 0 𝒷	Cambria:
@call :testcase  0x0995 1 0 ক	Nirmala_UI:
@call :testcase	 0xB2E4 1 0 다	Malgun_Gothic:
@call :testcase	0x1B001 1 0 𛀁	Yu_Gothic_UI:
@call :testcase	 0x31A0 1 0 ㆠ	MS_JhengHei:
@call :testcase	0x2F9B2 1 0 䕫	MS_YaHei:
@call :testcase	 0x2D30 1 0 ⴰ	Ebrima:
@call :testcase	 0x0E01 1 0 ส	Leelawadee_UI:
::@call :testcase	0x10F1 1 0 ჱ 	Sylfaen &REM obsolet
@call :testcase	 0xF61E 1 0 	-Fluent_Icons:
::@call :testcase	 0x	-MDL2_Assets: &REM non-funct.
@call :testcase	0x1F16D 1 0 🅭	-Symbol:
@call :testcase 0x1F16F 1 0 🅯	-Symbol:
::@call :testcase 0x1D4BA 1 0 𝒷	Cambria-Math &REM non-funct.
REM ===== Tests done  =======================
@goto EXIT

:testcase
REM %4 ← Codepoint %1?
@if "%1" == "" goto :EOF
REM %4 Expected GlyphTest-Exit %2, c/w %5 
@if NOT "%5" == "" <nul set /p=%5&REM ≙ echo -n %5
@GlyphTest %1
@if "%ERRORLEVEL%" == "%2" echo ✅
@if NOT "%ERRORLEVEL%" == "%2" echo ⚠️GlyphTest-Test %1→%4 failed!
REM %4 Expected  Fallback-Exit %3, c/w %5 
@if NOT "%5" == "" <nul set /p=%5&REM ≙ echo -n %5
@GlyphFallbackTest %1
@if "%ERRORLEVEL%" == "%3" echo ✅
@if NOT "%ERRORLEVEL%" == "%3" echo ⚠️Fallback-Test %1→%4 failed!
@GOTO :EOF

:EXIT
REM Consider `del GlyphTest.obj`!
@endlocal & set %PROMPT%=%pPROMPT%&& echo.
:: vi: set ts=8:
