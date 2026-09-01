## ==========================================================================
## Helper-Script for ↑genPlanes_Starter.cmd (documented there)
## --------------------------------------------------------------------------
## DevNote: I/O limits, PS7-MTA isn´t lucrative.
## DevNote: `-ErrorAction Stop` is required to make `catch` catch stderr.
## --------------------------------------------------------------------------
##  v0.9 en-de 2026 🅭🅯 Björn G. Kulms assisted by Copilot ¡ No Warranties !
## ==========================================================================
param(
    [string]$relGlyphTestPath = ".\glyphtest\GlyphTest.exe",
    [int]$min = 32,
    [int]$max = 0x10FFFF,
    [string]$baseDir = ".",
    [bool]$makeFiles = $false,
    [bool]$makeSubdirs = $false
)

## Unicode-Kategorien (sg. κατηγορία, pl. κατηγορίες)
## ↑[https://learn.microsoft.com/en-us/
##  /dotnet/api/system.text.unicodeencoding.getbytes]
$kategoriaMap = @{
	## Enum                  =  kk
    "UppercaseLetter"        = "Lu"
    "LowercaseLetter"        = "Ll"
    "TitlecaseLetter"        = "Lt"
    "ModifierLetter"         = "Lm"
    "OtherLetter"            = "Lo"
    "NonSpacingMark"         = "Mn"
    "SpacingCombiningMark"   = "Mc"
    "EnclosingMark"          = "Me"
    "DecimalDigitNumber"     = "Nd"
    "LetterNumber"           = "Nl"
    "OtherNumber"            = "No"
    "SpaceSeparator"         = "Zs"
    "LineSeparator"          = "Zl"
    "ParagraphSeparator"     = "Zp"
    "Control"                = "Cc"
    "Format"                 = "Cf"
    "Surrogate"              = "Cs"
    "PrivateUse"             = "Co"
    "ConnectorPunctuation"   = "Pc"
    "DashPunctuation"        = "Pd"
    "OpenPunctuation"        = "Ps"
    "ClosePunctuation"       = "Pe"
    "InitialQuotePunctuation"= "Pi"
    "FinalQuotePunctuation"  = "Pf"
    "OtherPunctuation"       = "Po"
    "MathSymbol"             = "Sm"
    "CurrencySymbol"         = "Sc"
    "ModifierSymbol"         = "Sk"
    "OtherSymbol"            = "So"
    "NotAssigned"            = "Cn"
} ## DevNote: Love Copilot for extracting whole this list in no time!
## ↻[System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($char)

## ==========================================================================

function Convert-CpToCtime {
    <#
        .SYNOPSIS
            Converts Unicode codepoint U+ppxxxx into a 
			synthetic NTFS-CreationTime (ctime).

        .DESCRIPTION
			This ctime is to be used as an additional sorting criterion.

			Formatted in YYyy-MM-DD hh:mm:ss the "calendar fields" mean ⇆
			YYyy = 2080 + pp = 2080…2096: synthetic-mark, Unicode code page; 
			MM-DD hh:mm = xxxx minutes since YYyy-01-01 00:00, xmm+1 ≙ xxxx+1;
			ss = 00: meaningless (and not shown in File-Explorer-Listings).

			!!! 2080 is hardcoded, but might not work for future versions of
			!!! Windows File Explorer that shows 1980 ≤ YYyy ≤ 2107, only
			!!! (blank, otherwise), corresponding to FAT-Epoch and FAT-Limit,
			!!! that aren´t really applicable. 

        .PARAMETER cp
            The Unicode codepoint as integer (0x000000–0x10FFFF).

        .OUTPUTS
            [datetime] — NTFS‑compatible synthetic CreationTime (UTC).
    #>

    param(
        [int]$cp
    )

    # Extract Unicode Plane (pp) and codepoint index (xxxx)
    $pp    = $cp -shr 16
    $xxxx  = $cp -band 0xFFFF

    # Base year: 2080 + pp (pp = 0x00–0x10 → 2080–2096)
    $year  = 2080 + $pp

    # 29 seconds offset avoid an easy-switching "00:00:00".
    $base = [datetime]::SpecifyKind(
        (Get-Date -Year $year -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 29),
        [System.DateTimeKind]::Utc
    )
    # Add codepoint index as minutes
    $dt = $base.AddMinutes($xxxx)

	# arbitrary signature: this ctime is synthetic
    $ticks = $dt.ToFileTimeUtc()
    $ticks = ($ticks -band 0xFFFFFFFFFF000000) -bor 0x000000000042474B

    # Return final synthetic timestamp
    return [datetime]::FromFileTimeUtc($ticks)
}

## ==========================================================================

#####{{{ Logging-Stuff: irrelvant to the main function of this script. #######

$ESC = [char]0x1B
$myName=$MyInvocation.MyCommand.Name
## return prompt-like a signature and the current time (current on call)
function sMe { 
	$time = (Get-Date).ToString("HH:mm:ss,fff")
	return "$ESC[32m$( $myName )[$time]>$ESC[0m"
}

## Get-WindowTitle − to distguish 
## windowed "start powershell" (Window-Title is set by ↑genPlanes_Starter.cmd)
## from inline "start /B powershell" (MainWindowTitle not set).
$winTitle = (Get-Process -Id $PID).MainWindowTitle
if ($winTitle -eq "") {
    $effTitle = "–inline–"
} else {
    $effTitle = $winTitle
}

## Tell «I'm alive» by logging some more or less useful information
[Console]::Error.WriteLine($( `
		"$(sMe) PS-Version {1}, $ESC[35mmyPID {0}$ESC[0m, myTitle: {2}" `
	-f `
		$PID, `
		$PSVersionTable.PSVersion, `
		$effTitle `
) )
#[Console]::Error.WriteLine( $("$(sMe){0}" -f [Environment]::CommandLine))
[Console]::Error.WriteLine( "$(sMe) ... be patient and watch $basedir ..." )

######}}} Logging-Stuff ######################################################

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$glyphTest = Join-Path $scriptDir $relGlyphTestPath

for ($i = $min; $i -le $max; $i++) {

	## Unicode Planes 0xPP0000...0xPPFFFF
    $nPlane = $i -shr 16 #= [math]::Floor($i / 0x10000)

	if (($i -band 0xFF) -eq 0) { ## log multiples of 256
		[Console]::Error.WriteLine($( `
			"$(sMe) 0x{1:X4}../0x{0:X6}" -f $max, ($i -shr 8) `
		))
	}

	## Reduce effective loop iterations to 7/17:
	## ⇄ Plane currently not defined ⇒ continue
	switch ($nPlane) {
		{0x00 -le $_ -and $_ -le 0x03} {} ## ⇅2nd switch($nPlane)
		{0x04 -le $_ -and $_ -le 0x0D} { continue }
		{0x0E -le $_ -and $_ -le 0x10} {} ## ⇅2nd switch($nPlane)
		default	{ 
			Write-Error -Category InvalidArgument "min/max out of range!" 
			$host.SetShouldExit(1)
			return
		}
	}
	## Get-Glyph (or not → further reduction of iterations)
	## DevNote: This test is relatively expensive
    $char = & $glyphTest $i
    if ( $LASTEXITCODE -ne 0 ) { continue }
	if ([string]::IsNullOrEmpty($char)) { 
		Write-Error -Category InvalidResult $( `
			"Unexpected Result of «{0} 0x{1:X6}»!" `
			-f $glyphTest, $i `
		)
		$host.SetShouldExit(2)
		continue 
	}
	## Got Glyph 
    ## Set Plane-FolderName
	switch ($nPlane) {
		0x00 { $planeName = "Plane00=BMP" }
		0x01 { $planeName = "Plane01=SMP" }
		0x02 { $planeName = "Plane02=SIP" }
		0x03 { $planeName = "Plane03=TIP" }
		##...: currently undefined, ⇅1st switch($nPlane)
		0x0E { $planeName = "Plane0E=SSP" }
		0x0F { $planeName = "Plane0F=SPA" }
		0x10 { $planeName = "Plane10=SPB" }
		## default already caught in 1st switch($nPlane)?
	}

	## make Plane-Folder
	$folder = Join-Path $baseDir $planeName
    try {
		# New-Item -ItemType Directory `
		New-Item -ItemType Directory -ErrorAction Stop `
			-Force -Path $folder | Out-Null
	} catch {
		Write-Error $_.Exception.Message  
		continue
	}
	
	## Get Char-Kategorie
	$kategoria = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($char, 0)
	$kk = $kategoriaMap[$kategoria.ToString()]
	## Dummy-FileSystemObjects 

	$FSOName = "____{0}____________U+{2:X6}.__{1}__" -f $char, $kk, $i 
	$synCtime = Convert-CpToCtime( $i )

    if( $makeFiles ){
	  try {
		$FSOPath = (Join-Path $folder ($FSOName + "(nul)"))
		New-Item -ItemType File `
				-ErrorAction Stop -Path $FSOPath | Out-Null
		(Get-Item $FSOPath).CreationTimeUtc = $synCtime
	  #} catch { Write-Error $_.Exception.Message ; continue }
	  } catch { continue }
	}

	if(	$makeSubdirs ){
	  try {
		$FSOPath = (Join-Path $folder ($FSOName + "(empty)"))
		New-Item -ItemType Directory `
				-ErrorAction Stop -Path $FSOPath | Out-Null
		(Get-Item $FSOPath).CreationTimeUtc = $synCtime
	  #} catch { Write-Error $_.Exception.Message ; continue }
	  } catch { continue }
	}

}

## simplified "exit" for use with PS-arg "-noExit" 
if ( $effTitle -eq $winTitle ) { 
	## Running in a window → Don´t close it before we could read messages!
	[Console]::Error.WriteLine($( `
		"$(sMe) {0}" -f "$ESC[7mHit [⏎] to close!$ESC[0m"
	) )
	$null = Read-Host "<<<enter>"
}
$host.SetShouldExit(0)
return
# :vi: set ts=4:
