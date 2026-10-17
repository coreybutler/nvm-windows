{ Official Node.js adopt / drop. Included from setup.iss [Code]. }

#include "installtimeout.iss"

{ Set by setup.iss when a 2.0.0+ install is already present. The official Node.js product stays; setup notifies instead of uninstalling it. }
var
  DeferOfficialNodeOnV2Upgrade: Boolean;

function OfficialNodeParam(): String;
var
  Raw: String;
begin
  Raw := LowerCase(Trim(ExpandConstant('{param:OFFICIALNODE}')));
  if (Raw = 'adopt') or (Raw = 'drop') then
    Result := Raw
  else
    Result := 'adopt';
end;

function IsNvmManagedPath(const PathValue: String): Boolean;
var
  N: String;
  AppRoot: String;
  Home: String;
  InstallRoot: String;
begin
  Result := False;
  N := LowerCase(NormalizePath(PathValue));
  if N = '' then
    Exit;

  // app constant is not initialized in InitializeWizard. Program root is the real LOCALAPPDATA path.
  AppRoot := LowerCase(NormalizePath(GetRealProgramRoot('')));
  Home := LowerCase(NormalizePath(GetEnv('NVM_HOME')));
  InstallRoot := LowerCase(NormalizePath(GetInstallRoot('')));

  if (AppRoot <> '') and ((N = AppRoot) or (Pos(AppRoot + '\', N) = 1)) then
  begin
    Result := True;
    Exit;
  end;
  if (Home <> '') and (Pos('author software\nvm', Home) > 0) and
     ((N = Home) or (Pos(Home + '\', N) = 1)) then
  begin
    Result := True;
    Exit;
  end;
  if (InstallRoot <> '') and ((N = InstallRoot) or (Pos(InstallRoot + '\', N) = 1)) then
    Result := True;
end;

function PathIsReparsePoint(const DirPath: String): Boolean;
var
  FindRec: TFindRec;
begin
  Result := False;
  if FindFirst(DirPath, FindRec) then
  begin
    Result := (FindRec.Attributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0;
    FindClose(FindRec);
  end;
end;

function OfficialNodeLooksLikeInstall(const DirPath: String): Boolean;
begin
  { A v1 NVM_SYMLINK directory symlink is not the nodejs.org product. The v1 cleanup removes the link. }
  Result :=
    (not IsNvmManagedPath(DirPath)) and
    (not PathIsReparsePoint(DirPath)) and
    FileExists(AddBackslash(DirPath) + 'node.exe');
end;

function StripNodeFileVersion(const FileVersion: String): String;
begin
  Result := Trim(FileVersion);
  if Result = '' then
    Exit;
  StringChangeEx(Result, ',', '.', True);
  { 22.20.0.0 -> 22.20.0 }
  if (Length(Result) > 2) and (Copy(Result, Length(Result) - 1, 2) = '.0') and
     (Pos('.', Copy(Result, 1, Length(Result) - 2)) > 0) then
    Result := Copy(Result, 1, Length(Result) - 2);
  while (Length(Result) > 0) and ((Result[1] = 'v') or (Result[1] = 'V')) do
    Result := Copy(Result, 2, MaxInt);
end;

function OfficialNodeVersionDirName(): String;
var
  V: String;
begin
  V := Trim(OfficialNodeVersion);
  if V = '' then
    V := 'unknown';
  if (Length(V) > 0) and ((V[1] = 'v') or (V[1] = 'V')) then
    Result := V
  else
    Result := 'v' + V;
end;

procedure MeasureTreeBytes(const RootDir: String; var Bytes: Int64);
var
  FindRec: TFindRec;
  CurrentPath: String;
  Chunk: Int64;
begin
  if not FindFirst(AddBackslash(RootDir) + '*', FindRec) then
    Exit;
  try
    repeat
      if (FindRec.Name <> '.') and (FindRec.Name <> '..') then
      begin
        CurrentPath := AddBackslash(RootDir) + FindRec.Name;
        if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
        begin
          if (FindRec.Attributes and FILE_ATTRIBUTE_REPARSE_POINT) = 0 then
            MeasureTreeBytes(CurrentPath, Bytes);
        end
        else
        begin
          Chunk := FindRec.SizeHigh;
          Chunk := (Chunk shl 32) + FindRec.SizeLow;
          Bytes := Bytes + Chunk;
        end;
      end;
    until not FindNext(FindRec);
  finally
    FindClose(FindRec);
  end;
end;

procedure MeasureGlobalNpmModules(var ModuleCount: Integer; var Bytes: Int64);
var
  RootDir: String;
  FindRec: TFindRec;
  NameLower: String;
begin
  ModuleCount := 0;
  Bytes := 0;
  RootDir := ExpandConstant('{userappdata}\npm\node_modules');
  if not DirExists(RootDir) then
    Exit;

  MeasureTreeBytes(RootDir, Bytes);

  if not FindFirst(AddBackslash(RootDir) + '*', FindRec) then
    Exit;
  try
    repeat
      if (FindRec.Name <> '.') and (FindRec.Name <> '..') and
         ((FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) then
      begin
        NameLower := LowerCase(FindRec.Name);
        if (NameLower <> '.bin') and (NameLower <> '.package-lock.json') and
           ((FindRec.Attributes and FILE_ATTRIBUTE_HIDDEN) = 0) then
          ModuleCount := ModuleCount + 1;
      end;
    until not FindNext(FindRec);
  finally
    FindClose(FindRec);
  end;
end;

function FormatOfficialNodeSize(const Bytes: Int64): String;
var
  Kb: Extended;
  Mb: Extended;
begin
  if Bytes <= 0 then
  begin
    Result := '0 MB';
    Exit;
  end;
  Kb := Bytes / 1024.0;
  if Kb < 1024.0 then
  begin
    Result := IntToStr(Round(Kb)) + ' KB';
    Exit;
  end;
  Mb := Kb / 1024.0;
  if Mb < 10.0 then
    Result := Format('%.1f MB', [Mb])
  else
    Result := IntToStr(Round(Mb)) + ' MB';
end;

function OfficialNodeSummary(): String;
begin
  Result :=
    'Node.js ' + OfficialNodeVersion + ' detected with ' +
    IntToStr(OfficialNodeModuleCount) + ' global modules (' +
    FormatOfficialNodeSize(OfficialNodeModuleSize) + ')';
end;

function TrySetOfficialNodeFromDir(const DirPath, VersionHint, UninstallString, ProductCode: String; IsMsi: Boolean): Boolean;
var
  Dir: String;
  Ver: String;
  FileVer: String;
begin
  Result := False;
  Dir := NormalizePath(DirPath);
  if not OfficialNodeLooksLikeInstall(Dir) then
    Exit;

  Ver := Trim(VersionHint);
  FileVer := '';
  if FileExists(AddBackslash(Dir) + 'node.exe') then
  begin
    if GetVersionNumbersString(AddBackslash(Dir) + 'node.exe', FileVer) then
      FileVer := StripNodeFileVersion(FileVer)
    else
      FileVer := '';
  end;
  if Ver = '' then
    Ver := FileVer;
  Ver := StripNodeFileVersion(Ver);
  if Ver = '' then
    Ver := 'unknown';

  OfficialNodeDetected := True;
  OfficialNodePath := Dir;
  OfficialNodeVersion := Ver;
  OfficialNodeUninstallString := Trim(UninstallString);
  OfficialNodeProductCode := Trim(ProductCode);
  OfficialNodeIsMsi := IsMsi;
  MeasureGlobalNpmModules(OfficialNodeModuleCount, OfficialNodeModuleSize);
  Result := True;
end;

function ProductCodeFromKeyName(const KeyName: String): String;
var
  K: String;
begin
  Result := '';
  K := Trim(KeyName);
  if (Length(K) = 38) and (K[1] = '{') and (K[38] = '}') then
    Result := K;
end;

function UninstallLooksLikeMsi(const UninstallString: String; const WindowsInstaller: Cardinal; const KeyName: String): Boolean;
var
  LowerUninstall: String;
begin
  Result := False;
  if WindowsInstaller = 1 then
  begin
    Result := True;
    Exit;
  end;
  if ProductCodeFromKeyName(KeyName) <> '' then
  begin
    Result := True;
    Exit;
  end;
  LowerUninstall := LowerCase(UninstallString);
  if (Pos('msiexec', LowerUninstall) > 0) then
    Result := True;
end;

function TryOfficialNodeFromUninstallRoot(const Root: Integer; const UninstallRoot: String): Boolean;
var
  SubKeys: TArrayOfString;
  I: Integer;
  KeyName: String;
  FullSubKey: String;
  DisplayName: String;
  InstallLocation: String;
  DisplayVersion: String;
  UninstallString: String;
  WindowsInstaller: Cardinal;
  IsMsi: Boolean;
begin
  Result := False;
  if not RegGetSubkeyNames(Root, UninstallRoot, SubKeys) then
    Exit;

  for I := 0 to GetArrayLength(SubKeys) - 1 do
  begin
    KeyName := SubKeys[I];
    FullSubKey := UninstallRoot + '\' + KeyName;
    DisplayName := '';
    if not RegQueryStringValue(Root, FullSubKey, 'DisplayName', DisplayName) then
      Continue;
    if CompareText(Trim(DisplayName), 'Node.js') <> 0 then
      Continue;

    InstallLocation := '';
    DisplayVersion := '';
    UninstallString := '';
    WindowsInstaller := 0;
    RegQueryStringValue(Root, FullSubKey, 'InstallLocation', InstallLocation);
    RegQueryStringValue(Root, FullSubKey, 'DisplayVersion', DisplayVersion);
    RegQueryStringValue(Root, FullSubKey, 'UninstallString', UninstallString);
    RegQueryDWordValue(Root, FullSubKey, 'WindowsInstaller', WindowsInstaller);
    IsMsi := UninstallLooksLikeMsi(UninstallString, WindowsInstaller, KeyName);

    if Trim(InstallLocation) = '' then
      Continue;
    if TrySetOfficialNodeFromDir(InstallLocation, DisplayVersion, UninstallString, ProductCodeFromKeyName(KeyName), IsMsi) then
    begin
      if OfficialNodeProductCode = '' then
        OfficialNodeProductCode := ProductCodeFromKeyName(KeyName);
      Result := True;
      Exit;
    end;
  end;
end;

procedure DetectOfficialNode();
var
  InstallPath: String;
  DisplayVersion: String;
begin
  OfficialNodeDetected := False;
  OfficialNodePath := '';
  OfficialNodeVersion := '';
  OfficialNodeProductCode := '';
  OfficialNodeUninstallString := '';
  OfficialNodeIsMsi := False;
  OfficialNodeModuleCount := 0;
  OfficialNodeModuleSize := 0;
  OfficialNodeCopyFailed := False;
  OfficialNodeDropFailed := False;
  OfficialNodeDropError := '';
  OfficialNodeAction := OfficialNodeParam();

  if TryOfficialNodeFromUninstallRoot(HKLM64, 'Software\Microsoft\Windows\CurrentVersion\Uninstall') then
    Exit;
  if TryOfficialNodeFromUninstallRoot(HKLM32, 'Software\Microsoft\Windows\CurrentVersion\Uninstall') then
    Exit;
  if TryOfficialNodeFromUninstallRoot(HKLM, 'Software\Microsoft\Windows\CurrentVersion\Uninstall') then
    Exit;
  if TryOfficialNodeFromUninstallRoot(HKLM, 'Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall') then
    Exit;

  InstallPath := '';
  DisplayVersion := '';
  if RegQueryStringValue(HKLM64, 'SOFTWARE\Node.js', 'InstallPath', InstallPath) or
     RegQueryStringValue(HKLM, 'SOFTWARE\Node.js', 'InstallPath', InstallPath) then
  begin
    RegQueryStringValue(HKLM64, 'SOFTWARE\Node.js', 'Version', DisplayVersion);
    if DisplayVersion = '' then
      RegQueryStringValue(HKLM, 'SOFTWARE\Node.js', 'Version', DisplayVersion);
    if TrySetOfficialNodeFromDir(InstallPath, DisplayVersion, '', '', True) then
      Exit;
  end;

  if TrySetOfficialNodeFromDir(ExpandConstant('{pf}\nodejs'), '', '', '', False) then
    Exit;
  if TrySetOfficialNodeFromDir(GetEnv('ProgramW6432') + '\nodejs', '', '', '', False) then
    Exit;
  if TrySetOfficialNodeFromDir(ExpandConstant('{pf32}\nodejs'), '', '', '', False) then
    Exit;
end;

function SelectedOfficialNodeAction(): String;
begin
  Result := OfficialNodeAction;
  if OfficialNodePage = nil then
    Exit;
  if OfficialNodePage.Values[1] then
    Result := 'drop'
  else
    Result := 'adopt';
end;

procedure CreateOfficialNodePage();
var
  Description: String;
begin
  OfficialNodePage := nil;
  if not OfficialNodeDetected then
    Exit;
  if DeferOfficialNodeOnV2Upgrade then
    Exit;

  Description :=
    OfficialNodeSummary() + #13#10 +
    'Location: ' + OfficialNodePath + #13#10#13#10 +
    'The existing Node.js installation overrides NVM for Windows and must be removed. Removing it may require elevated privileges.';

  OfficialNodePage := CreateInputOptionPage(
    wpLicense,
    'Existing Node.js',
    OfficialNodeSummary(),
    Description,
    True,
    False
  );
  OfficialNodePage.Add('Adopt — copy into NVM and uninstall the existing installation');
  OfficialNodePage.Add('Drop — uninstall the existing installation (do not copy)');

  if OfficialNodeAction = 'drop' then
    OfficialNodePage.Values[1] := True
  else
    OfficialNodePage.Values[0] := True;
end;

function AdoptOfficialNodeVersion(): Boolean;
var
  DestDir: String;
  SourceDir: String;
  UserModules: String;
  DestModules: String;
  CopiedCount: Integer;
  ProgressPage: TOutputProgressWizardPage;
  ResultCode: Integer;
  UseVer: String;
begin
  Result := False;
  SourceDir := OfficialNodePath;
  DestDir := AddBackslash(GetInstallRoot('')) + OfficialNodeVersionDirName();
  BeginStepBudget('NVM4106', 'Adopting official Node.js exceeded 15 minutes.', 900);
  AppendInstallLog('AdoptOfficialNode: source=' + SourceDir + ' dest=' + DestDir);

  if FileExists(AddBackslash(DestDir) + 'node.exe') then
  begin
    AppendInstallLog('AdoptOfficialNode: destination already has node.exe');
    Result := True;
  end
  else
  begin
    CopiedCount := 0;
    ProgressPage := CreateOutputProgressPage(
      'Adopting official Node.js',
      OfficialNodeSummary()
    );
    ProgressPage.SetProgress(0, 1);
    ProgressPage.Show;
    try
      if not CopyTreeWithProgress(SourceDir, DestDir, ProgressPage, CopiedCount, 1, 'Node.js ' + OfficialNodeVersion) then
      begin
        OfficialNodeCopyFailed := True;
        AppendInstallLogWarn('AdoptOfficialNode: copy failed');
        Exit;
      end;
    finally
      ProgressPage.Hide;
    end;
    Result := FileExists(AddBackslash(DestDir) + 'node.exe');
    if not Result then
    begin
      OfficialNodeCopyFailed := True;
      AppendInstallLogWarn('AdoptOfficialNode: node.exe missing after copy');
      Exit;
    end;
  end;

  UserModules := Trim(ExpandConstant('{param:OFFICIALNODEMODULES}'));
  if UserModules = '' then
    UserModules := ExpandConstant('{userappdata}\npm\node_modules');
  DestModules := AddBackslash(DestDir) + 'node_modules';
  if DirExists(UserModules) then
  begin
    CopiedCount := 0;
    if not CopyTreeWithProgress(UserModules, DestModules, nil, CopiedCount, 1, '') then
      AppendInstallLogWarn('AdoptOfficialNode: global module overlay failed (version copy kept)');
  end;

  UseVer := OfficialNodeVersion;
  if not ExecStep(
    ExpandConstant('{app}\{#Alias}.exe'),
    'use ' + UseVer,
    'NVM4106',
    'Adopting official Node.js exceeded 15 minutes.',
    RemainingBudgetSec,
    True,
    False,
    ResultCode
  ) then
    AppendInstallLogWarn('AdoptOfficialNode: nvm use failed to start')
  else if ResultCode <> 0 then
    AppendInstallLogWarn('AdoptOfficialNode: nvm use exit=' + IntToStr(ResultCode))
  else
    AppendInstallLog('AdoptOfficialNode: nvm use ' + UseVer);
end;

function UninstallResultOk(const Started: Boolean; const ResultCode: Integer): Boolean;
begin
  Result := Started and ((ResultCode = 0) or (ResultCode = 3010) or (ResultCode = 1641));
end;

procedure NoteUninstallFailure(const Started: Boolean; const ResultCode: Integer; const FailureText: String);
begin
  OfficialNodeDropFailed := True;
  if (not Started) and (ResultCode = 1223) then
    OfficialNodeDropError := 'The admin prompt was canceled.'
  else if not Started then
    OfficialNodeDropError := 'Could not start the uninstaller (system error ' + IntToStr(ResultCode) + ').'
  else
    OfficialNodeDropError := FailureText + ' (exit ' + IntToStr(ResultCode) + ').';
  AppendInstallLogWarn('DropOfficialNode: ' + OfficialNodeDropError);
end;

function OfficialNodeUninstallWasRecorded(const FileName, Args: String): Boolean;
var
  LogPath: String;
begin
  LogPath := Trim(ExpandConstant('{param:OFFICIALNODELOG}'));
  Result := LogPath <> '';
  if Result then
    SaveStringToFile(LogPath, FileName + ' ' + Args + #13#10, False);
end;

function DropOfficialNodeInstall(): Boolean;
var
  ResultCode: Integer;
  Args: String;
  Ok: Boolean;
begin
  Result := False;
  AppendInstallLog('DropOfficialNode: msi=' + IntToStr(Integer(OfficialNodeIsMsi)) + ' product=' + OfficialNodeProductCode);

  if OfficialNodeIsMsi and (OfficialNodeProductCode <> '') then
  begin
    Args := '/x ' + OfficialNodeProductCode + ' /qn /norestart';
    if OfficialNodeUninstallWasRecorded(ExpandConstant('{sys}\msiexec.exe'), Args) then
    begin
      Result := True;
      Exit;
    end;
    Ok := ExecStep(
      ExpandConstant('{sys}\msiexec.exe'),
      Args,
      'NVM4115',
      'Uninstalling official Node.js exceeded 10 minutes.',
      600,
      False,
      True,
      ResultCode
    );
    if not UninstallResultOk(Ok, ResultCode) then
    begin
      NoteUninstallFailure(Ok, ResultCode, 'Silent MSI uninstall failed');
      Exit;
    end;
    Result := True;
    Exit;
  end;

  if OfficialNodeIsMsi and (OfficialNodeUninstallString <> '') and
     (Pos('msiexec', LowerCase(OfficialNodeUninstallString)) > 0) then
  begin
    Args := OfficialNodeUninstallString;
    StringChangeEx(Args, '/I', '/X', True);
    StringChangeEx(Args, '/i', '/x', True);
    if Pos('/qn', LowerCase(Args)) = 0 then
      Args := Args + ' /qn /norestart';
    if OfficialNodeUninstallWasRecorded(ExpandConstant('{cmd}'), '/C ' + Args) then
    begin
      Result := True;
      Exit;
    end;
    Ok := ExecStep(ExpandConstant('{cmd}'), '/C ' + Args, 'NVM4115', 'Uninstalling official Node.js exceeded 10 minutes.', 600, False, True, ResultCode);
    if not UninstallResultOk(Ok, ResultCode) then
    begin
      NoteUninstallFailure(Ok, ResultCode, 'MSI uninstall string failed');
      Exit;
    end;
    Result := True;
    Exit;
  end;

  if Trim(OfficialNodeUninstallString) <> '' then
  begin
    if OfficialNodeUninstallWasRecorded(ExpandConstant('{cmd}'), '/C ' + OfficialNodeUninstallString) then
    begin
      Result := True;
      Exit;
    end;
    Ok := ExecStep(ExpandConstant('{cmd}'), '/C ' + OfficialNodeUninstallString, 'NVM4115', 'Uninstalling official Node.js exceeded 10 minutes.', 600, False, True, ResultCode);
    if not UninstallResultOk(Ok, ResultCode) then
    begin
      NoteUninstallFailure(Ok, ResultCode, 'Official uninstall failed');
      Exit;
    end;
    Result := True;
    Exit;
  end;

  OfficialNodeDropFailed := True;
  OfficialNodeDropError := 'No uninstall command was found for official Node.js.';
  AppendInstallLogWarn('DropOfficialNode: ' + OfficialNodeDropError);
end;

procedure ExitProcess(uExitCode: Cardinal);
  external 'ExitProcess@kernel32.dll stdcall';

procedure AbortInstallBecauseOfficialNodeRemains();
var
  MessageText: String;
begin
  if InstallerHardFailed then
    Exit;
  MessageText :=
    'The existing Node.js installation could not be removed.' + #13#10#13#10 +
    OfficialNodeDropError + #13#10#13#10 +
    'Exit the NVM for Windows installer, remove the existing Node.js version, then run the installer again.' + #13#10#13#10 +
    'Node.js is still at:' + #13#10 +
    OfficialNodePath + #13#10#13#10 +
    'Removing it may require elevated privileges.';
  AppendInstallLogWarn('ApplyOfficialNodeChoice: ' + OfficialNodeDropError);
  if not WizardSilent then
  begin
    MsgBox(MessageText, mbError, MB_OK);
    Abort;
  end;
  { ssPostInstall is too late for Abort to change the process exit code. }
  ExitProcess(1);
end;

procedure ApplyOfficialNodeChoice();
begin
  if not OfficialNodeDetected then
    Exit;

  if DeferOfficialNodeOnV2Upgrade then
  begin
    AppendInstallLog('ApplyOfficialNodeChoice: left in place for a 2.x upgrade at ' + OfficialNodePath);
    Exit;
  end;

  OfficialNodeAction := SelectedOfficialNodeAction();
  AppendInstallLog('ApplyOfficialNodeChoice: action=' + OfficialNodeAction + ' path=' + OfficialNodePath);

  if OfficialNodeAction = 'drop' then
    DropOfficialNodeInstall()
  else
  begin
    if not AdoptOfficialNodeVersion() then
      OfficialNodeCopyFailed := True;
    if InstallerHardFailed then
      Exit;
    DropOfficialNodeInstall();
  end;

  if OfficialNodeDropFailed then
    AbortInstallBecauseOfficialNodeRemains();
end;

procedure WarnIfOfficialNodeIncomplete();
var
  MessageText: String;
begin
  if WizardSilent then
    Exit;

  if OfficialNodeCopyFailed then
  begin
    MessageText :=
      OfficialNodeSummary() + #13#10#13#10 +
      'NVM could not copy this version. The existing Node.js installation was removed.' + #13#10#13#10 +
      'Install that version later with nvm install.';
    MsgBox(MessageText, mbInformation, MB_OK);
  end;
end;
