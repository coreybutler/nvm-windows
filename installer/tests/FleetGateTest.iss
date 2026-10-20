#define Name "NVM for Windows"
#define Version "0.0.0-test"

[Setup]
AppId={{7E4C1A2B-9D10-4F55-A111-0FF1C1A10016}
AppName={#Name}
AppVersion={#Version}
DefaultDirName={localappdata}\nvm-fleetgate-inno-test
PrivilegesRequired=lowest
OutputBaseFilename=fleetgate-compile-test
DisableDirPage=yes
DisableProgramGroupPage=yes
Uninstallable=no
CreateAppDir=yes
Compression=none
SolidCompression=no
CloseApplications=no

[Code]
const
  TH32CS_SNAPPROCESS = $00000002;
  PROCESS_QUERY_LIMITED_INFORMATION = $1000;
  INVALID_HANDLE_VALUE = $FFFFFFFF;
  FleetWalkMaxDepth = 16;
  NVM4116EventId = 4116;

type
  TProcessEntry32W = record
    dwSize: DWORD;
    cntUsage: DWORD;
    th32ProcessID: DWORD;
    th32DefaultHeapID: DWORD;
    th32ModuleID: DWORD;
    cntThreads: DWORD;
    th32ParentProcessID: DWORD;
    pcPriClassBase: LongInt;
    dwFlags: DWORD;
    szExeFile: array[0..259] of Char;
  end;

procedure WriteApplicationEventError(EventId: Integer; const Message: String);
begin
  Log('event ' + IntToStr(EventId) + ' ' + Message);
end;

#include "..\fleetgate.iss"

function InitializeSetup(): Boolean;
begin
  Result := PassesFleetInstallGate();
end;
