#ifndef GLYPH_FALLBACK_DEBUG
// Set Debug-Mode by ↑buildAndTest-GlyphTest.cmd ← /DGLYPH_FALLBACK_DEBUG!
#endif
#ifndef FALLBACKEXE_NAME
//#define FALLBACKEXE_NAME L"GlyphFallbackTest"
#endif
/* ***************************************************************************
* A) GlyphTest.exe: Font-Coverage-Analysis
* B) FALLBACKEXE_NAME: What would DWrite actually render?
* ----------------------------------------------------------------------------
* 
* Input:	arg[1] = int Unicode‑Codepoint cp 
* 
* Output:	a) Char renderbar ⇒ stdout:
* 	   		A) "<Unicode-Char>" in UTF‑8-Encoding 
*  			B) + "(effective Font)" #ifdef GLYPH_FALLBACK_DEBUG 
* 			⇒ ExitCode 0
* 		b) Char nicht renderbar (Missing-Glyph) ⇒ stdout: \0  
* 			⇒ ExitCode 1
* 		c) ExitCode 2 ⇔ invalid input: cp out of range, special case <CR>, … 
* 		d) ExitCode 3 ⇔ DirectWrite fails / COM-Errors
* 
* Font/Font-Family: s. TEST_FONT_FAMILY below
* 
* ✅ Unicode-Surrogate‑Pairs: fully supported
* ✅ Unicode-Combining‑Marks: fully supported
* ✅ No .NET-Interop: native DirectWrite1 
* ✅ Minimal dependencies: dwrite.lib.
* ____________________________________________________________________________
* ¡ Der Fallback-Test kann den orignalen WinUI3-Mechanismus 
* ¡ (Windows App SDK, DWriteCore) nicht nutzen, den etwa der Win11-
* ¡ File-Explorer nutzt, sondern baut dessen Font-Fallback-Chain 
* ¡ mit Win32-Mitteln (Windows SDK, DirectWrite1) nach.
* ⛔The real WinUI3-Font-Fallback-Chain might be subject of change⛔
* ****************************************************************************
* v0.6 en-de 2026 🅭🅯 Björn G. Kulms assisted by Copilot ¡ No Warranties !
* ****************************************************************************
*/ 
#include <windows.h>
#include <dwrite.h>
#include <iostream>
#include <string>


static const wchar_t* TEST_FONT_FAMILY = L"Segoe UI";
//static const wchar_t* TEST_FONT_FAMILY = L"Segoe UI Emoji";
//static const wchar_t* TEST_FONT_FAMILY = L"Cambria";
//static const wchar_t* TEST_FONT_FAMILY = L"MS Gothic";
//static const wchar_t* TEST_FONT_FAMILY = L"Nirmala UI";
//static const wchar_t* TEST_FONT_FAMILY = L"Malgun Gothic";
//static const wchar_t* TEST_FONT_FAMILY = L"Yu Gothic UI";
//static const wchar_t* TEST_FONT_FAMILY = L"Microsoft JhengHei";
//static const wchar_t* TEST_FONT_FAMILY = L"Microsoft YaHei";
//static const wchar_t* TEST_FONT_FAMILY = L"Ebrima";
//static const wchar_t* TEST_FONT_FAMILY = L"Leelawadee UI";
//static const wchar_t* TEST_FONT_FAMILY = L"Segoe MDL2 Assets";
//static const wchar_t* TEST_FONT_FAMILY = L"Segoe UI Symbol";
//static const wchar_t* TEST_FONT_FAMILY = L"Cambria Math";
// ===============================================================
#define SAFE_RELEASE(x) if (x) { (x)->Release(); (x) = nullptr; }

std::string ToUTF8(const std::wstring& ws)
{
    int size = WideCharToMultiByte(CP_UTF8, 0, ws.c_str(), (int)ws.size(), NULL, 0, NULL, NULL);
    std::string utf8(size, 0);
    WideCharToMultiByte(CP_UTF8, 0, ws.c_str(), (int)ws.size(), &utf8[0], size, NULL, NULL);
    return utf8;
}


int wmain(int argc, wchar_t** argv)
{
	// Check args
    if (argc < 2) 		return 2;
	if (argv[1] < 0)	return 2;
	 
	errno = 0;
    unsigned long cp = wcstoul(argv[1], NULL, 0); // CodePoint
	if (errno != 0)		return 2;
    if (cp > 0x10FFFF) 	return 2;
	switch (cp)	{ // catch valid "" {0xA:0x200B:0x2060:0x00AD:0x2028:0x2029}
		case      0xD: 	/* <Carriage Return (CR)>  */
		case   0xFEFF:  /* <Byte Order Mark (BOM)> */
						return 2;
	}

	// different filename, different function
    std::wstring exePath = argv[0];
    bool useFallback = (exePath.find(FALLBACKEXE_NAME) != std::wstring::npos);

	// text ← cp ¡Windows: wchar_t is dword (max. 0xFFFF)
    std::wstring text;
    if (cp <= 0xFFFF) 					// cp in 1st Unicode-Page (BMP)
        text.push_back((wchar_t)cp);
    else {								// convert into a UTF-16 Surrogate-Pair
        UINT32 tmp = cp - 0x10000;
        text.push_back((wchar_t)((tmp >> 10) + 0xD800));	// High Surrogate
        text.push_back((wchar_t)((tmp & 0x3FF) + 0xDC00));	// Low Surrogate
    }

	// create a shared DirectWrite-Factory (COM-object, template code)
    IDWriteFactory* factory = nullptr;
    HRESULT hr = DWriteCreateFactory(
        DWRITE_FACTORY_TYPE_SHARED,
        __uuidof(IDWriteFactory),
        reinterpret_cast<IUnknown**>(&factory)
    );
    if (FAILED(hr) || !factory)
        return 3;

	// get the System-Font Collection (COM-Object, template code)
    IDWriteFontCollection* fonts = nullptr;
    hr = factory->GetSystemFontCollection(&fonts, FALSE);
    if (FAILED(hr) || !fonts)
    {
        SAFE_RELEASE(factory);
        return 3;
    }

    // direct GlyphTest in TEST_FONT_FAMILY ⇒ okDirect (template code)

    UINT32 index = 0;
    BOOL exists = FALSE;
    hr = fonts->FindFamilyName(TEST_FONT_FAMILY, &index, &exists);

    bool okDirect = false;
    std::wstring usedFamilyName = TEST_FONT_FAMILY;

    if (SUCCEEDED(hr) && exists)
    {
        IDWriteFontFamily* family = nullptr;
        fonts->GetFontFamily(index, &family);

        IDWriteFont* font = nullptr;
        family->GetFirstMatchingFont(
            DWRITE_FONT_WEIGHT_NORMAL,
            DWRITE_FONT_STRETCH_NORMAL,
            DWRITE_FONT_STYLE_NORMAL,
            &font
        );

        IDWriteFontFace* face = nullptr;
        font->CreateFontFace(&face);

        UINT32 cp32[1] = { cp };
        UINT16 glyphs[1];
        hr = face->GetGlyphIndices(cp32, 1, glyphs);

        okDirect = (SUCCEEDED(hr) && glyphs[0] != 0);

        SAFE_RELEASE(face);
        SAFE_RELEASE(font);
        SAFE_RELEASE(family);
    }

    // A) No Fallback: done

    if (!useFallback)
    {
        SAFE_RELEASE(fonts);
        SAFE_RELEASE(factory);

        if (!okDirect) return 1;

		std::cout << ToUTF8(text);
        return 0;
    }

    // B) Fallback: simulate DWriteCore-Fallback by Font-Sweep ⇒ okFallback

    bool okFallback = false;

    if (!okDirect)
    {
        UINT32 familyCount = fonts->GetFontFamilyCount();

        for (UINT32 i = 0; i < familyCount; i++)
        {
            IDWriteFontFamily* family = nullptr;
            fonts->GetFontFamily(i, &family);

            IDWriteLocalizedStrings* names = nullptr;
            family->GetFamilyNames(&names);

            UINT32 length = 0;
            names->GetStringLength(0, &length);

            std::wstring famName(length + 1, L'\0');
            names->GetString(0, &famName[0], length + 1);

            IDWriteFont* font = nullptr;
            family->GetFirstMatchingFont(
                DWRITE_FONT_WEIGHT_NORMAL,
                DWRITE_FONT_STRETCH_NORMAL,
                DWRITE_FONT_STYLE_NORMAL,
                &font
            );

            IDWriteFontFace* face = nullptr;
            font->CreateFontFace(&face);

            UINT32 cp32[1] = { cp };
            UINT16 glyphs[1];
            hr = face->GetGlyphIndices(cp32, 1, glyphs);

            if (SUCCEEDED(hr) && glyphs[0] != 0)
            {
                okFallback = true;
                usedFamilyName = famName;

            }

            SAFE_RELEASE(face);
            SAFE_RELEASE(font);
            SAFE_RELEASE(names);
            SAFE_RELEASE(family);
	
            if ( okFallback ) break;
        }
    }

    SAFE_RELEASE(fonts);
    SAFE_RELEASE(factory);

    if (!okDirect && !okFallback) return 1;

#ifdef GLYPH_FALLBACK_DEBUG
    std::cout << "(" << ToUTF8(usedFamilyName) << ") ";
#endif
    std::cout << ToUTF8(text);
    return 0;
}
// vi: set ts=4:
