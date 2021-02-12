// Inno Setup Preprocessor
//
// Inno Setup (C) 1997-2020 Jordan Russell. All Rights Reserved.
// Portions Copyright (C) 2000-2020 Martijn Laan. All Rights Reserved.
// Portions Copyright (C) 2001-2004 Alex Yackimoff. All Rights Reserved.
//
// See the ISPP help file for more documentation of the functions defined by this file
//
#if defined(ISPP_INVOKED) && !defined(_BUILTINS_ISS_)
//
#if PREPROCVER < 0x01000000
# error Inno Setup Preprocessor version is outdated
#endif
//
#define _BUILTINS_ISS_
//
#ifdef __OPT_E__
# define private EnableOptE
# pragma option -e-
#endif

#ifndef __POPT_P__
# define private DisablePOptP
#else
# pragma parseroption -p-
#endif

#define NewLine            "\n"
#define Tab                "\t"

#pragma parseroption -p+

#pragma spansymbol "\"

#define True               1
#define False              0
#define Yes                True
#define No								 False

#define MaxInt             0x7FFFFFFFFFFFFFFFL
#define MinInt             0x8000000000000000L

#define NULL
#define void

// TypeOf constants

#define TYPE_ERROR         0
#define TYPE_NULL          1
#define TYPE_INTEGER       2
#define TYPE_STRING        3
#define TYPE_MACRO         4
#define TYPE_FUNC          5
#define TYPE_ARRAY         6

// Helper macro to find out the type of an array element or expression. TypeOf
// standard function only allows identifier as its parameter. Use this macro
// to convert an expression to identifier.

#define TypeOf2(any Expr) TypeOf(Expr)

// ReadReg constants

#define HKEY_CLASSES_ROOT  0x80000000UL
#define HKEY_CURRENT_USER  0x80000001UL
#define HKEY_LOCAL_MACHINE 0x80000002UL
#define HKEY_USERS         0x80000003UL
#define HKEY_CURRENT_CONFIG     0x80000005UL
#define HKEY_CLASSES_ROOT_64    0x82000000UL
#define HKEY_CURRENT_USER_64    0x82000001UL
#define HKEY_LOCAL_MACHINE_64   0x82000002UL
#define HKEY_USERS_64           0x82000003UL
#define HKEY_CURRENT_CONFIG_64  0x82000005UL

#define HKCR               HKEY_CLASSES_ROOT
#define HKCU               HKEY_CURRENT_USER
#define HKLM               HKEY_LOCAL_MACHINE
#define HKU                HKEY_USERS
#define HKCC               HKEY_CURRENT_CONFIG
#define HKCR64             HKEY_CLASSES_ROOT_64
#define HKCU64             HKEY_CURRENT_USER_64
#define HKLM64             HKEY_LOCAL_MACHINE_64
#define HKU64              HKEY_USERS_64
#define HKCC64             HKEY_CURRENT_CONFIG_64

// Exec constants

#define SW_HIDE            0
#define SW_SHOWNORMAL      1
#define SW_NORMAL          1
#define SW_SHOWMINIMIZED   2
#define SW_SHOWMAXIMIZED   3
#define SW_MAXIMIZE        3
#define SW_SHOWNOACTIVATE  4
#define SW_SHOW            5
#define SW_MINIMIZE        6
#define SW_SHOWMINNOACTIVE 7
#define SW_SHOWNA          8
#define SW_RESTORE         9
#define SW_SHOWDEFAULT     10
#define SW_MAX             10

// Find constants

#define FIND_MATCH         0x00
#define FIND_BEGINS        0x01
#define FIND_ENDS          0x02
#define FIND_CONTAINS      0x03
#define FIND_CASESENSITIVE 0x04 
#define FIND_SENSITIVE     FIND_CASESENSITIVE
#define FIND_AND           0x00
#define FIND_OR            0x08
#define FIND_NOT           0x10
#define FIND_TRIM          0x20

// FindFirst constants

#define faReadOnly         0x00000001
#define faHidden           0x00000002
#define faSysFile          0x00000004
#define faVolumeID         0x00000008
#define faDirectory        0x00000010
#define faArchive          0x00000020
#define faSymLink          0x00000040
#define faAnyFile          0x0000003F

// GetStringFileInfo standard names

#define COMPANY_NAME       "CompanyName"
#define FILE_DESCRIPTION   "FileDescription"
#define FILE_VERSION       "FileVersion"
#define INTERNAL_NAME      "InternalName"
#define LEGAL_COPYRIGHT    "LegalCopyright"
#define ORIGINAL_FILENAME  "OriginalFilename"
#define PRODUCT_NAME       "ProductName"
#define PRODUCT_VERSION    "ProductVersion"

// GetStringFileInfo helpers

#define GetFileCompany(str FileName) GetStringFileInfo(FileName, COMPANY_NAME)
#define GetFileDescription(str FileName) GetStringFileInfo(FileName, FILE_DESCRIPTION)
#define GetFileVersionString(str FileName) GetStringFileInfo(FileName, FILE_VERSION)
#define GetFileCopyright(str FileName) GetStringFileInfo(FileName, LEGAL_COPYRIGHT)
#define GetFileOriginalFilename(str FileName) GetStringFileInfo(FileName, ORIGINAL_FILENAME)
#define GetFileProductVersion(str FileName) GetStringFileInfo(FileName, PRODUCT_VERSION)

#define DeleteToFirstPeriod(str *S) \
  Local[1] = Copy(S, 1, (Local[0] = Pos(".", S)) - 1), \
  S = Copy(S, Local[0] + 1), \
  Local[1]

#define GetVersionComponents(str FileName, *Major, *Minor, *Rev, *Build) \
  Local[1]  = Local[0] = GetVersionNumbersString(FileName), \
  Local[1] == "" ? "" : ( \
    Major   = Int(DeleteToFirstPeriod(Local[1])), \
    Minor   = Int(DeleteToFirstPeriod(Local[1])), \
    Rev     = Int(DeleteToFirstPeriod(Local[1])), \
    Build   = Int(Local[1]), \
  Local[0])

#define GetPackedVersion(str FileName, *Version) \
  Local[0] = GetVersionComponents(FileName, Local[1], Local[2], Local[3], Local[4]), \
  Version = PackVersionComponents(Local[1], Local[2], Local[3], Local[4]), \
  Local[0]

#define GetVersionNumbers(str FileName, *MS, *LS) \
  Local[0] = GetPackedVersion(FileName, Local[1]), \
  UnpackVersionNumbers(Local[1], MS, LS), \
  Local[0]

#define PackVersionNumbers(int VersionMS, int VersionLS) \
  VersionMS << 32 | (VersionLS & 0xFFFFFFFF)

#define PackVersionComponents(int Major, int Minor, int Rev, int Build) \
  Major << 48 | (Minor & 0xFFFF) << 32 | (Rev & 0xFFFF) << 16 | (Build & 0xFFFF)

#define UnpackVersionNumbers(int Version, *VersionMS, *VersionLS) \
  VersionMS = Version >> 32, \
  VersionLS = Version & 0xFFFFFFFF, \
  void

#define UnpackVersionComponents(int Version, *Major, *Minor, *Rev, *Build) \
  Major = Version >> 48, \
  Minor = (Version >> 32) & 0xFFFF, \
  Rev   = (Version >> 16) & 0xFFFF, \
  Build = Version & 0xFFFF, \
  void

#define VersionToStr(int Version) \
  Str(Version >> 48 & 0xFFFF) + "." + Str(Version >> 32 & 0xFFFF) + "." + \
  Str(Version >> 16 & 0xFFFF) + "." + Str(Version & 0xFFFF)

#define EncodeVer(int Major, int Minor, int Revision = 0, int Build = -1) \
  (Major & 0xFF) << 24 | (Minor & 0xFF) << 16 | (Revision & 0xFF) << 8 | (Build >= 0 ? Build & 0xFF : 0)

#define DecodeVer(int Version, int Digits = 3) \
  Str(Version >> 24 & 0xFF) + (Digits > 1 ? "." : "") + \
  (Digits > 1 ? \
    Str(Version >> 16 & 0xFF) + (Digits > 2 ? "." : "") : "") + \
  (Digits > 2 ? \
    Str(Version >> 8 & 0xFF) + (Digits > 3 && (Local = Version & 0xFF) ? "." : "") : "") + \
  (Digits > 3 && Local ? \
    Str(Version & 0xFF) : "")

#define FindSection(str Section = "Files") \
  Find(0, "[" + Section + "]", FIND_MATCH | FIND_TRIM) + 1

#if VER >= 0x03000000
# define FindNextSection(int Line) \
    Find(Line, "[", FIND_BEGINS | FIND_TRIM, "]", FIND_ENDS | FIND_AND)
# define FindSectionEnd(str Section = "Files") \
    FindNextSection(FindSection(Section))
#else
# define FindSectionEnd(str Section = "Files") \
    FindSection(Section) + EntryCount(Section)
#endif

#define FindCode() \
    Local[1] = FindSection("Code"), \
    Local[0] = Find(Local[1] - 1, "program", FIND_BEGINS, ";", FIND_ENDS | FIND_AND), \
    (Local[0] < 0 ? Local[1] : Local[0] + 1)

#define ExtractFilePath(str PathName) \
  (Local[0] = \
    !(Local[1] = RPos("\", PathName)) ? \
      "" : \
      Copy(PathName, 1, Local[1] - 1)), \
  Local[0] + \
    ((Local[2] = Len(Local[0])) == 2 && Copy(Local[0], Local[2]) == ":" ? \
      "\" : \
      "")

#define ExtractFileDir(str PathName) \
  RemoveBackslash(ExtractFilePath(PathName))

#define ExtractFileExt(str PathName) \
  Local[0] = RPos(".", PathName), \
  Copy(PathName, Local[0] + 1)

#define ExtractFileName(str PathName) \
  !(Local[0] = RPos("\", PathName)) ? \
    PathName : \
    Copy(PathName, Local[0] + 1)

#define ChangeFileExt(str FileName, str NewExt) \
  !(Local[0] = RPos(".", FileName)) ? \
    FileName + "." + NewExt : \
    Copy(FileName, 1, Local[0]) + NewExt

#define RemoveFileExt(str FileName) \
  !(Local[0] = RPos(".", FileName)) ? \
  FileName : \
  Copy(FileName, 1, Local[0] - 1)

#define AddBackslash(str S) \
  Copy(S, Len(S)) == "\" ? S : S + "\"

#define RemoveBackslash(str S) \
  Local[0] = Len(S), \
  Local[0] > 0 ? \
    Copy(S, Local[0]) == "\" ? \
      (Local[0] == 3 && Copy(S, 2, 1) == ":" ? \
        S : \
        Copy(S, 1, Local[0] - 1)) : \
      S : \
    ""

#define Delete(str *S, int Index, int Count = MaxInt) \
  S = Copy(S, 1, Index - 1) + Copy(S, Index + Count)

#define Insert(str *S, int Index, str Substr) \
  Index > Len(S) + 1 ? \
    S : \
    S = Copy(S, 1, Index - 1) + SubStr + Copy(S, Index)

#define YesNo(str S) \
  (S = LowerCase(S)) == "yes" || S == "true" || S == "1"

#define IsDirSet(str SetupDirective) \
  YesNo(SetupSetting(SetupDirective))

#define Power(int X, int P = 2) \
  !P ? 1 : X * Power(X, P - 1)

#define Min(int A, int B, int C = MaxInt)  \
  A < B ? A < C ? Int(A) : Int(C) : Int(B)

#define Max(int A, int B, int C = MinInt)  \
  A > B ? A > C ? Int(A) : Int(C) : Int(B)

#define SameText(str S1, str S2) \
  LowerCase(S1) == LowerCase(S2)

#define SameStr(str S1, str S2) \
  S1 == S2

#define WarnRenamedVersion(str OldName, str NewName) \
  Warning("Function """ + OldName + """ has been renamed. Use """ + NewName + """ instead.")

#define ParseVersion(str FileName, *Major, *Minor, *Rev, *Build) \
  WarnRenamedVersion("ParseVersion", "GetVersionComponents"), \
  GetVersionComponents(FileName, Major, Minor, Rev, Build)

#define GetFileVersion(str FileName) \
  WarnRenamedVersion("GetFileVersion", "GetVersionNumbersString"), \
  GetVersionNumbersString(FileName)

#ifdef DisablePOptP
# pragma parseroption -p-
#endif

#ifdef EnableOptE
# pragma option -e+
#endif
#endif