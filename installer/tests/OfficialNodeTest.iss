; Compiles the real officialnode.iss choices without uninstalling Node.js.
; The PowerShell suite passes /OFFICIALNODELOG so Drop records msiexec instead of launching it.

#define Alias "nvm"

[Setup]
AppId={{7E4C1A2B-9D10-4F55-A111-0FF1C1A10002}
AppName=NVM Official Node Choice Test
AppVersion=1.0.0
DefaultDirName={localappdata}\nvm-officialnode-inno-test
PrivilegesRequired=lowest
OutputBaseFilename=officialnode-choice-test
DisableDirPage=yes
DisableProgramGroupPage=yes
Uninstallable=no
CreateAppDir=yes
Compression=none
SolidCompression=no
CloseApplications=no

[Code]
var
  OfficialNodePage: TInputOptionWizardPage;
  OfficialNodeDetected: Boolean;
  OfficialNodePath: String;
  OfficialNodeVersion: String;
  OfficialNodeProductCode: String;
  OfficialNodeUninstallString: String;
  OfficialNodeIsMsi: Boolean;
  OfficialNodeModuleCount: Integer;
  OfficialNodeModuleSize: Int64;
  OfficialNodeAction: String;
  OfficialNodeCopyFailed: Boolean;
  OfficialNodeDropFailed: Boolean;
  OfficialNodeDropError: String;
  InstallerHardFailed: Boolean;
  SuppressStepFailure: Boolean;
  StepBudgetArmed: Boolean;
  BudgetDeadline: Cardinal;
  BudgetCode: String;
  BudgetMessage: String;

function NormalizePath(const PathValue: String): String;
begin
  Result := Trim(PathValue);
  while (Length(Result) > 3) and (Result[Length(Result)] = '\') do
    Result := Copy(Result, 1, Length(Result) - 1);
end;

function GetRealProgramRoot(Param: String): String;
begin
  Result := ExpandConstant('{localappdata}\Author Software\nvm');
end;

function GetInstallRoot(Param: String): String;
begin
  Result := ExpandConstant('{param:INSTALLROOT}');
end;

procedure AppendInstallLog(const Message: String);
var
  LogPath: String;
begin
  LogPath := Trim(ExpandConstant('{param:INSTALLLOG}'));
  if LogPath <> '' then
    SaveStringToFile(LogPath, Message + #13#10, True);
end;

procedure AppendInstallLogWarn(const Message: String);
begin
  AppendInstallLog('WARN ' + Message);
end;

function CopyTreeWithProgress(
  const SourceDir, DestDir: String;
  ProgressPage: TOutputProgressWizardPage;
  var CopiedCount: Integer;
  const TotalCount: Integer;
  const VersionLabel: String
): Boolean;
var
  ResultCode: Integer;
begin
  Result := False;
  if not ForceDirectories(DestDir) then
    Exit;
  if not Exec(
    'robocopy.exe',
    '"' + SourceDir + '" "' + DestDir + '" /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  ) then
    Exit;
  Result := ResultCode < 8;
  if Result then
    CopiedCount := CopiedCount + 1;
end;

#include "..\officialnode.iss"

procedure InitializeWizard();
begin
  OfficialNodeDetected := ExpandConstant('{param:NODEFOUND}') = '1';
  OfficialNodePath := ExpandConstant('{param:NODESOURCE}');
  OfficialNodeVersion := '22.14.0';
  OfficialNodeUninstallString := '';
  OfficialNodeIsMsi := True;
  OfficialNodeModuleCount := 1;
  OfficialNodeModuleSize := 1024;
  OfficialNodeCopyFailed := False;
  OfficialNodeDropFailed := False;
  OfficialNodeDropError := '';
  OfficialNodeAction := OfficialNodeParam();
  if ExpandConstant('{param:SKIPPRODUCT}') = '1' then
    OfficialNodeProductCode := ''
  else
    OfficialNodeProductCode := '{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}';
  if OfficialNodeDetected then
    CreateOfficialNodePage();
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep <> ssPostInstall then
    Exit;
  ApplyOfficialNodeChoice();
end;

procedure DeinitializeSetup();
var
  Path: String;
  Body: String;
begin
  Path := Trim(ExpandConstant('{param:OFFICIALNODERESULT}'));
  if Path = '' then
    Exit;
  Body :=
    'action=' + OfficialNodeAction + #13#10 +
    'detected=' + IntToStr(Integer(OfficialNodeDetected)) + #13#10 +
    'copyfailed=' + IntToStr(Integer(OfficialNodeCopyFailed)) + #13#10 +
    'dropfailed=' + IntToStr(Integer(OfficialNodeDropFailed)) + #13#10 +
    'error=' + OfficialNodeDropError + #13#10;
  SaveStringToFile(Path, Body, False);
end;
