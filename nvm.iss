#define MyAppName "NVM for Windows"
#define MyAppShortName "nvm"
#define MyAppLCShortName "nvm"
#define MyAppVersion "1.0.1"
#define MyAppPublisher "Ecor Ventures, LLC"
#define MyAppURL "http://github.com/coreybutler/nvm"
#define MyAppExeName "nvm.exe"
#define MyIcon "nodejs.ico"
#define ProjectRoot "C:\Users\Corey\Documents\workspace\Experiments\nvm"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
PrivilegesRequired=admin
AppId=40078385-F676-4C61-9A9C-F9028599D6D3
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={userappdata}\{#MyAppShortName}
DisableDirPage=no
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile={#ProjectRoot}\LICENSE
OutputDir={#ProjectRoot}\dist\{#MyAppVersion}
OutputBaseFilename={#MyAppLCShortName}-setup
SetupIconFile={#ProjectRoot}\{#MyIcon}
Compression=lzma
SolidCompression=yes
ChangesEnvironment=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 0,6.1

[Files]
Source: "{#ProjectRoot}\bin\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppShortName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{#MyIcon}"
Name: "{group}\Uninstall {#MyAppShortName}"; Filename: "{uninstallexe}"

[Code]
var
  SymlinkPage: TInputDirWizardPage;
procedure InitializeWizard;
begin
  SymlinkPage := CreateInputDirPage(wpSelectDir,
    'Set Node.js Symlink', 'The active version of Node.js will always be available here.',
    'Select the folder in which Setup should create the symlink, then click Next.',
    False, '');
  SymlinkPage.Add('This directory will automatically be added to your system path.');
  SymlinkPage.Values[0] := ExpandConstant('{pf32}\nodejs');
end;

function InitializeUninstall(): Boolean;
var
  path: string;
  nvm_symlink: string;
begin
  // Remove the symlink
  RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'NVM_SYMLINK', nvm_symlink);
  RemoveDir(nvm_symlink);
      
  // Clean the registry    
  RegDeleteValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'NVM_HOME')
  RegDeleteValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'NVM_SYMLINK')
  RegDeleteValue(HKEY_CURRENT_USER,
    'Environment',
    'NVM_HOME')
  RegDeleteValue(HKEY_CURRENT_USER,
    'Environment',
    'NVM_SYMLINK')

  RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', path);

  StringChangeEx(path,'%NVM_HOME%','',True);
  StringChangeEx(path,'%NVM_SYMLINK%','',True);
  StringChangeEx(path,';;',';',True);
  
  RegWriteExpandStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', path);
  
  RegQueryStringValue(HKEY_CURRENT_USER,
    'Environment',
    'Path', path);

  StringChangeEx(path,'%NVM_HOME%','',True);
  StringChangeEx(path,'%NVM_SYMLINK%','',True);
  StringChangeEx(path,';;',';',True);
  
  RegWriteExpandStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', path);
  
  Result := True;
end;

// Generate the settings file based on user input & update registry
procedure CurStepChanged(CurStep: TSetupStep);
var
  path: string;
begin
  if CurStep = ssPostInstall then 
  begin
    SaveStringToFile(ExpandConstant('{app}\settings.txt'), 'root: ' + ExpandConstant('{app}') + #13#10 + 'path: ' + SymlinkPage.Values[0] + #13#10, False);

    // Add Registry settings
    RegWriteExpandStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'NVM_HOME', ExpandConstant('{app}'));
    RegWriteExpandStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'NVM_SYMLINK', SymlinkPage.Values[0]);
    RegWriteExpandStringValue(HKEY_CURRENT_USER, 'Environment', 'NVM_HOME', ExpandConstant('{app}'));
    RegWriteExpandStringValue(HKEY_CURRENT_USER, 'Environment', 'NVM_SYMLINK', SymlinkPage.Values[0]);

    // Update system and user PATH if needed
    RegQueryStringValue(HKEY_LOCAL_MACHINE,
      'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
      'Path', path);
    if Pos('%NVM_HOME%',path) = 0 then begin
      path := path+';%NVM_HOME%';
      StringChangeEx(path,';;',';',True);
      RegWriteExpandStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', path);
    end;
    if Pos('%NVM_SYMLINK%',path) = 0 then begin
      path := path+';%NVM_SYMLINK%';
      StringChangeEx(path,';;',';',True);
      RegWriteExpandStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', path);
    end;
    RegQueryStringValue(HKEY_CURRENT_USER,
      'Environment',
      'Path', path);
    if Pos('%NVM_HOME%',path) = 0 then begin
      path := path+';%NVM_HOME%';
      StringChangeEx(path,';;',';',True);
      RegWriteExpandStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', path);
    end;
    if Pos('%NVM_SYMLINK%',path) = 0 then begin
      path := path+';%NVM_SYMLINK%';
      StringChangeEx(path,';;',';',True);
      RegWriteExpandStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', path);
    end;
  end;
end;

function getSymLink(o: string): string;
begin
  Result := SymlinkPage.Values[0];
end;

[Run]
Filename: "{sys}\cmd.exe"; Parameters: "/C {code:getSymLink}"; Flags: runhidden;
//Filename: "{sys}\cmd.exe"; Parameters: "/K nvm"; Flags: runasoriginaluser postinstall;

[UninstallDelete]
Type: files; Name: "{app}\nvm.exe";
Type: files; Name: "{app}\elevate.cmd";
Type: files; Name: "{app}\elevate.vbs";
Type: files; Name: "{app}\nodejs.ico";
Type: files; Name: "{app}\settings.txt";
Type: filesandordirs; Name: "{app}";