function GetCurrentProcessId: DWORD;
  external 'GetCurrentProcessId@kernel32.dll stdcall';
function OpenProcess(dwDesiredAccess: DWORD; bInheritHandle: BOOL; dwProcessId: DWORD): THandle;
  external 'OpenProcess@kernel32.dll stdcall';
function CloseHandle(hObject: THandle): BOOL;
  external 'CloseHandle@kernel32.dll stdcall';
function CreateToolhelp32Snapshot(dwFlags, th32ProcessID: DWORD): THandle;
  external 'CreateToolhelp32Snapshot@kernel32.dll stdcall';
function Process32FirstW(hSnapshot: THandle; var lppe: TProcessEntry32W): BOOL;
  external 'Process32FirstW@kernel32.dll stdcall';
function Process32NextW(hSnapshot: THandle; var lppe: TProcessEntry32W): BOOL;
  external 'Process32NextW@kernel32.dll stdcall';
function QueryFullProcessImageNameW(hProcess: THandle; dwFlags: DWORD; lpExeName: String; var lpdwSize: DWORD): BOOL;
  external 'QueryFullProcessImageNameW@kernel32.dll stdcall';
function AttachConsole(dwProcessId: DWORD): BOOL;
  external 'AttachConsole@kernel32.dll stdcall';
function FreeConsole: BOOL;
  external 'FreeConsole@kernel32.dll stdcall';
function GetConsoleWindow: HWND;
  external 'GetConsoleWindow@kernel32.dll stdcall';
function IsWindowVisible(hWnd: HWND): BOOL;
  external 'IsWindowVisible@user32.dll stdcall';

function NVM4116UserMessage(): String;
begin
  Result :=
    'NVM4116: Machine-triggered community installation detected. {#Name} {#Version} setup aborted. ' +
    'For IT-managed, MSI, or Intune deployment, use Certified Builds: https://nvm-windows.com/certified. ' +
    'For self-managed installation, see the available community installers at https://docs.nvm-windows.com.';
end;

procedure AbortFleetSetup(const Trigger: String);
var
  Message: String;
begin
  Message := NVM4116UserMessage();
  Log(Message + ' trigger=' + Trigger);
  WriteApplicationEventError(NVM4116EventId, Message + ' trigger=' + Trigger);
  MsgBox(Message, mbCriticalError, MB_OK);
end;

function IsCurrentUserSystem(): Boolean;
var
  ResultCode: Integer;
begin
  Result := False;
  if Exec(
    ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    '-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "if ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -eq ''S-1-5-18'') { exit 18 } else { exit 0 }"',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  ) then
    Result := (ResultCode = 18);
end;

function GetParentProcessId(const ProcessId: DWORD): DWORD;
var
  Snap: THandle;
  Pe: TProcessEntry32W;
begin
  Result := 0;
  Snap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (Snap = 0) or (Snap = INVALID_HANDLE_VALUE) then
    Exit;
  Pe.dwSize := SizeOf(Pe);
  if Process32FirstW(Snap, Pe) then
  begin
    repeat
      if Pe.th32ProcessID = ProcessId then
      begin
        Result := Pe.th32ParentProcessID;
        Break;
      end;
    until not Process32NextW(Snap, Pe);
  end;
  CloseHandle(Snap);
end;

function GetProcessImagePath(const ProcessId: DWORD): String;
var
  Proc: THandle;
  Size: DWORD;
  Buf: String;
begin
  Result := '';
  Proc := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, ProcessId);
  if Proc = 0 then
    Exit;
  Size := 1024;
  SetLength(Buf, Size);
  if QueryFullProcessImageNameW(Proc, 0, Buf, Size) then
  begin
    if Size > 0 then
      Result := Copy(Buf, 1, Size);
  end;
  CloseHandle(Proc);
end;

function ProcessFileName(const ImagePath: String): String;
begin
  Result := ExtractFileName(ImagePath);
end;

function ProcessEntryFileName(const Pe: TProcessEntry32W): String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to 259 do
  begin
    if Pe.szExeFile[I] = #0 then
      Break;
    Result := Result + Pe.szExeFile[I];
  end;
end;

function IsFleetHostFileName(const FileName: String): Boolean;
begin
  Result :=
    (CompareText(FileName, 'IntuneManagementExtension.exe') = 0) or
    (CompareText(FileName, 'AgentExecutor.exe') = 0) or
    (CompareText(FileName, 'taskhostw.exe') = 0) or
    (CompareText(FileName, 'taskeng.exe') = 0) or
    (CompareText(FileName, 'gpscript.exe') = 0) or
    (CompareText(FileName, 'CcmExec.exe') = 0);
end;

function PathLooksLikeWindowsApps(const ImagePath: String): Boolean;
var
  LowerPath: String;
begin
  LowerPath := LowerCase(ImagePath);
  Result :=
    (Pos('\windowsapps\', LowerPath) > 0) or
    (Pos('\systemapps\', LowerPath) > 0);
end;

function PathLooksLikeIntuneAgent(const ImagePath: String): Boolean;
begin
  Result := Pos('\microsoft intune management extension\', LowerCase(ImagePath)) > 0;
end;

function IntuneAgentExecutorRunning(): Boolean;
var
  Snap: THandle;
  Pe: TProcessEntry32W;
  FileName: String;
  ImagePath: String;
begin
  Result := False;
  Snap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (Snap = 0) or (Snap = INVALID_HANDLE_VALUE) then
    Exit;
  Pe.dwSize := SizeOf(Pe);
  if Process32FirstW(Snap, Pe) then
  begin
    repeat
      FileName := ProcessEntryFileName(Pe);
      if CompareText(FileName, 'AgentExecutor.exe') = 0 then
      begin
        ImagePath := GetProcessImagePath(Pe.th32ProcessID);
        if (ImagePath = '') or PathLooksLikeIntuneAgent(ImagePath) then
        begin
          Result := True;
          Break;
        end;
      end;
    until not Process32NextW(Snap, Pe);
  end;
  CloseHandle(Snap);
end;

function IsStoreUiAncestor(const FileName, ImagePath: String): Boolean;
begin
  Result := False;
  if CompareText(FileName, 'WinStore.App.exe') <> 0 then
    Exit;
  Result := PathLooksLikeWindowsApps(ImagePath);
end;

function IsClickHostAncestor(const FileName, ImagePath: String): Boolean;
begin
  Result := False;
  if FileName = '' then
    Exit;
  if (CompareText(FileName, 'UniGetUI.exe') = 0) or
     (CompareText(FileName, 'WingetUI.exe') = 0) or
     (CompareText(FileName, 'uniget.exe') = 0) then
  begin
    Result := True;
    Exit;
  end;
  Result := IsStoreUiAncestor(FileName, ImagePath);
end;

function IsUserControlledAncestor(const FileName, ImagePath: String): Boolean;
begin
  Result := False;
  if FileName = '' then
    Exit;
  if (CompareText(FileName, 'UniGetUI.exe') = 0) or
     (CompareText(FileName, 'WingetUI.exe') = 0) or
     (CompareText(FileName, 'uniget.exe') = 0) then
  begin
    Result := True;
    Exit;
  end;
  if not PathLooksLikeWindowsApps(ImagePath) then
    Exit;
  Result :=
    (CompareText(FileName, 'WinStore.App.exe') = 0) or
    (CompareText(FileName, 'WindowsPackageManagerServer.exe') = 0) or
    (CompareText(FileName, 'AppInstaller.exe') = 0);
end;

function AncestorHasRealConsole(const ProcessId: DWORD): Boolean;
var
  ConsoleWnd: HWND;
begin
  Result := False;
  FreeConsole();
  if not AttachConsole(ProcessId) then
    Exit;
  ConsoleWnd := GetConsoleWindow();
  if ConsoleWnd = 0 then
    Result := True
  else if IsWindowVisible(ConsoleWnd) then
    Result := True;
  FreeConsole();
end;

function PassesFleetInstallGate(): Boolean;
var
  Depth: Integer;
  CurrentPid: DWORD;
  ParentPid: DWORD;
  ImagePath: String;
  FileName: String;
  UserControlled: Boolean;
  ClickHost: Boolean;
  ConsoleOk: Boolean;
  Seen: String;
begin
  Result := True;
  if IsCurrentUserSystem() then
  begin
    AbortFleetSetup('SYSTEM');
    Result := False;
    Exit;
  end;

  UserControlled := False;
  ClickHost := False;
  ConsoleOk := False;
  Seen := ',';
  CurrentPid := GetCurrentProcessId();
  Seen := Seen + IntToStr(CurrentPid) + ',';

  for Depth := 1 to FleetWalkMaxDepth do
  begin
    ParentPid := GetParentProcessId(CurrentPid);
    if (ParentPid = 0) or (ParentPid = 4) or (ParentPid = CurrentPid) then
      Break;
    if Pos(',' + IntToStr(ParentPid) + ',', Seen) > 0 then
      Break;
    Seen := Seen + IntToStr(ParentPid) + ',';

    ImagePath := GetProcessImagePath(ParentPid);
    FileName := ProcessFileName(ImagePath);
    if FileName <> '' then
    begin
      if IsFleetHostFileName(FileName) then
      begin
        AbortFleetSetup(FileName);
        Result := False;
        Exit;
      end;
      if IsClickHostAncestor(FileName, ImagePath) then
        ClickHost := True;
      if IsUserControlledAncestor(FileName, ImagePath) then
        UserControlled := True;
    end;

    if AncestorHasRealConsole(ParentPid) then
      ConsoleOk := True;

    CurrentPid := ParentPid;
  end;

  if WizardSilent and IntuneAgentExecutorRunning() and (not ClickHost) and (not ConsoleOk) then
  begin
    AbortFleetSetup('AgentExecutor-peer');
    Result := False;
    Exit;
  end;

  if not WizardSilent then
    Exit;

  if UserControlled or ConsoleOk then
    Exit;

  AbortFleetSetup('silent-no-console');
  Result := False;
end;
