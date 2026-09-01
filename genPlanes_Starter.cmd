@set pPROMPT=%PROMPT%&&>nul chcp 65001&setlocal&prompt $E[1A$E[32m%~n0[$T]$G$E[0m
@if NOT "%1" == "" echo ::80×24:: & echo  ^
::============================================================================= ^
:: Runs genPlanes.ps1 that uses GlyphTest or GlyphFallbackTest to generate      ^
:: Dummy-FileSystemObjects (DFSOs), that have Unicode chars in their filenames. ^
::                                                                              ^
:: → Check the look and the sorting order of Unicode-chars in filenames.        ^
::                                                                              ^
:: ← GlyphTest translates Unicode-Codepoints into Unicode-Characters and checks ^
::   whether the respective Character would be rendered into a Missing-Glyph as ^
::   a visually non-distinguable placeholder.                                   ^
:: ← GlyphFallbackTest additionaly runs through a font-sweep emulating the      ^
::   Fallback-Mechanism of DWriteCore that is actually used by the modern       ^
::   File-Explorer of Windows 11 to utilize further fonts for missing glyphs.   ^
:: ↔ Edit GlyphTest.cpp for font-names or the display of effective font-names!  ^
::                                                                              ^
:: Input ← Edit Settings in this file!                                          ^
:: Output: Watch directories Plane.. in baseDir↑Settings!                       ^
::_____________________________________________________________________________ ^
:: v0.7 en-de 2026 🅭🅯 Björn G. Kulms assisted by Copilot ¡ No Warranties !      ^
::============================================================================= ^
:: Usage:                                                 ¡break run by Ctrl+C! ^
:: [cmd] [notepad] "%~f0" [/?]&& if NOT "%1" == "" goto :END
@set genPlanes=.\genPlanes.ps1
:SETTINGS
REM SETTINGS{{{
:: ¡Trailing &-characters avoid trailing blank-characters where critical!
:: The about 300k defined Unicode-Chars are not numbered consecutively.
:: Plane04…13 ≙ [04.0000…0E.0000[ aren´t officialy used, yet (↑genPlanes.ps1).
REM ↱ Enumerate 0 ≤ min ≤ Char# ≤ max ≤ 0x10FFFD 
@set min=0x0E0000
@set min=0
@set max=0x10FFFD
@set max=0x03FFFF
@set max=0x100
REM ↳ -min %min% -max %max%
REM ↱ Generate the DFSOs in Subdirs "Plane*.*" of
@set baseDir=.\generatedPlanes&
REM ↳ -baseDir %baseDir%
REM ↱ DFSOs: ¿generate plain Files? → sortable listings of the glyphs
@set genFiles=^$True
@set genFiles=^$False 
REM ↳ -makeFiles:%genFiles%
REM ↱ DFSOs: ¿generate Directories? ← Glyphs look different in Tabs
@set genDirs=^$False
@set genDirs=^$True
REM ↳ -makeDirs:%genDirs%
REM ↻ (^$False ∧ ^$False) ⇔  generate empty dirs "Plane..", only.
REM ↻ ¡One File requires ≈1 kB MFT, one Directory ≈5 kB MFT!
REM ↱ rel. Path from %genPlanes% to the glyph translator 
@set relGlyphTestDir=.\glyphtest&
REM ↱ Translator: Glyph{Fallback}Test.exe 
@set glyphTest=GlyphTest.exe
@set glyphTest=GlyphFallbackTest.exe
REM ↳ -relGlyphTestPath: %relGlyphTestDir%\%GlyphTest%
@REM ↱ PowerShell-Instance to use:
@set PS="%ProgramFiles%\PowerShell\7\pwsh.exe"
@set PS="%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -version 5.1
REM }}}SETTINGS
@echo.

@set relGlyphTestPath=%relGlyphTestDir%\%GlyphTest%
@set makeGlyphTestCmd=buildAndTest-GlyphTest.cmd
@if not exist %relGlyphTestPath% (
	pushd "%relGlyphTestDir%"
	if exist "%makeGlyphTestCmd%" call "%makeGlyphTestCmd%"
	popd
)
@if not exist %relGlyphTestPath% goto :ErrGlyphTestMissing

@set runScript='%genPlanes%' ^
	-relGlyphTestPath '%relGlyphTestPath%' ^
	-baseDir '%baseDir%' ^
	-makeFiles:%genFiles% -makeSubdirs:%genDirs% ^
	-min %min% -max %max%

set RunCmd=%PS% -noExit -ExecutionPolicy Bypass ^
		-Command "& %runScript%"

::REM ¡Break run by Ctrl+Break!
REM ¡Break run by Ctrl+C followed by input "exit" and "y"![1A 
@choice /C YN /N /M "[7m  Launch RunCmd?  {No|Yes}<<[0m"
@if ERRORLEVEL 2 goto :EXIT &REM 2: <'n', 255: Error
@echo.

::¡Title "%genPlanes%" is used by ↑genPlanes.ps1!
::@start "%genPlanes%" /WAIT %RunCmd%
@%RunCmd%
@if ERRORLEVEL 1 set genPlanesErr=%ERRORLEVEL% & goto :GenPlanesErr

@goto :EXIT
:ErrGlyphTestMissing
REM 👺 Fatal: Cannot find or build  %relGlyphTestPath%
@goto :END
:GenPlanesErr
REM 👺 %genPlanes%: Error %genPlanesErr%

:EXIT
@echo 
REM Use `dir /T:C` for CLI-Listings!
REM ¡Rendered «_?_» ⇄ Wildcards (`_?_` ⊻ `_??_`  ⊻ `_???_` ⊻ …) match!
REM ¡    ⇖BMP[+HiSurrogate[+LowSurrogate]][+Varia][+Combining-Marks]…!
REM See %genPlanes% for an explanation of kk in «__*__kk-U+*»!
REM Use `rmdir /s/q %baseDir%` to get rid of all results!
:END
@endlocal & echo.&echo. & prompt %pPROMPT%&
@echo.
:: vi: set ts=8:
