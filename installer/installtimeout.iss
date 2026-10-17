function GetTickCount: Cardinal;
  external 'GetTickCount@kernel32.dll stdcall';

function InstallerReportScript: String;
begin
  Result := ExpandConstant('{tmp}\InstallerReport.ps1');
  if not FileExists(Result) then
    Result := ExpandConstant('{app}\utils\InstallerReport.ps1');
end;

procedure BeginStepBudget(const Code, Message: String; TimeoutSec: Integer);
begin
  BudgetCode := Code;
  BudgetMessage := Message;
  StepBudgetArmed := TimeoutSec > 0;
  if StepBudgetArmed then
    BudgetDeadline := GetTickCount + Cardinal(TimeoutSec) * 1000
  else
    BudgetDeadline := 0;
end;

function WalkTimeoutSec(const VersionCount: Integer): Integer;
begin
  if VersionCount < 1 then
    Result := 600
  else
    Result := VersionCount * 120;
  if Result < 600 then
    Result := 600;
  if Result > 1800 then
    Result := 1800;
end;

function RemainingBudgetSec: Integer;
var
  LeftMs: Integer;
begin
  if not StepBudgetArmed then
  begin
    Result := 180;
    Exit;
  end;
  LeftMs := Integer(BudgetDeadline - GetTickCount);
  if LeftMs < 1000 then
    Result := 0
  else
    Result := LeftMs div 1000;
end;

procedure ShowInstallerFailureDialog();
var
  ScriptPath: String;
  ResultCode: Integer;
begin
  ScriptPath := InstallerReportScript;
  if not FileExists(ScriptPath) then
    Exit;
  Exec(
    ExpandConstant('{cmd}'),
    '/C powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + ScriptPath + '" -Action dialog',
    '',
    SW_SHOWNORMAL,
    ewWaitUntilTerminated,
    ResultCode
  );
end;

function ExecStep(
  const FileName, Params, Code, Message: String;
  TimeoutSec: Integer;
  SoftFail, RunAs: Boolean;
  var ResultCode: Integer
): Boolean;
var
  ScriptPath, ArgPath, CommandLine, Flags: String;
  LaunchCode: Integer;
begin
  Result := False;
  ResultCode := 0;
  if InstallerHardFailed then
  begin
    ResultCode := 1460;
    Exit;
  end;
  if SuppressStepFailure then
  begin
    Result := Exec(FileName, Params, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exit;
  end;
  if TimeoutSec <= 0 then
  begin
    ResultCode := 1460;
    InstallerHardFailed := True;
    Exit;
  end;

  ScriptPath := InstallerReportScript;
  if not FileExists(ScriptPath) then
  begin
    Result := Exec(FileName, Params, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exit;
  end;

  ArgPath := ExpandConstant('{tmp}\nvm-step-args.txt');
  SaveStringToFile(ArgPath, Params, False);
  Flags := '';
  if SoftFail then
    Flags := Flags + ' -SoftFail';
  if RunAs then
    Flags := Flags + ' -RunAs';
  CommandLine :=
    '/C powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + ScriptPath + '"' +
    ' -Action run -Exe "' + FileName + '" -ArgumentsFile "' + ArgPath + '"' +
    ' -TimeoutSec ' + IntToStr(TimeoutSec) +
    ' -Code ' + Code +
    ' -Message "' + Message + '"' +
    Flags;
  if not Exec(ExpandConstant('{cmd}'), CommandLine, '', SW_HIDE, ewWaitUntilTerminated, LaunchCode) then
  begin
    ResultCode := LaunchCode;
    Exit;
  end;

  ResultCode := LaunchCode;
  if LaunchCode = 1460 then
  begin
    InstallerHardFailed := True;
    Exit;
  end;
  Result := True;
end;

procedure ScheduleInstallerRollback();
var
  Uninstaller, CommandLine: String;
  ResultCode: Integer;
begin
  Uninstaller := ExpandConstant('{app}\unins000.exe');
  if not FileExists(Uninstaller) then
    Exit;
  CommandLine :=
    '/C ping -n 8 127.0.0.1 >nul & "' + Uninstaller + '" /SILENT';
  Exec(ExpandConstant('{cmd}'), CommandLine, '', SW_HIDE, ewNoWait, ResultCode);
end;
