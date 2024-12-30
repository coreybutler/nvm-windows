#define MyAppName "NVM for Windows"
#define MyAppShortName "nvm"
#define MyAppLCShortName "nvm"
#define MyAppVersion "{{VERSION}}"
#define MyAppPublisher "Author Software Inc."
#define MyAppURL "https://github.com/coreybutler/nvm-windows"
#define MyAppExeName "nvm.exe"
#define MyIcon "bin\nvm.ico"
#define MyAppId "40078385-F676-4C61-9A9C-F9028599D6D3"
#define ProjectRoot "."

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
PrivilegesRequired=admin
; SignTool=MsSign $f
; SignedUninstaller=yes
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppCopyright=Copyright (C) 2018-{code:GetCurrentYear} Author Software Inc., Ecor Ventures LLC, Corey Butler, and contributors.
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={localappdata}\{#MyAppShortName}
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
DisableProgramGroupPage=yes
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\{#MyIcon}

; Version information
VersionInfoVersion={{VERSION}}.0
VersionInfoCopyright=Copyright © {code:GetCurrentYear} Author Software Inc., Ecor Ventures LLC, Corey Butler, and contributors.
VersionInfoCompany=Author Software Inc.
VersionInfoDescription=Node.js version manager for Windows
VersionInfoProductName={#MyAppShortName}
VersionInfoProductTextVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 0,6.1

[Files]
Source: "{#ProjectRoot}\bin\*"; DestDir: "{app}"; BeforeInstall: PreInstall; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "{#ProjectRoot}\bin\install.cmd"

[Icons]
Name: "{group}\{#MyAppShortName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{#MyIcon}"
Name: "{group}\Uninstall {#MyAppShortName}"; Filename: "{uninstallexe}"

[Registry]
; Register the URL protocol 'nvm'
Root: HKCR; Subkey: "{#MyAppShortName}"; ValueType: string; ValueName: ""; ValueData: "URL:nvm"; Flags: uninsdeletekey
Root: HKCR; Subkey: "{#MyAppShortName}"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Flags: uninsdeletekey
Root: HKCR; Subkey: "{#MyAppShortName}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Flags: uninsdeletekey
Root: HKCR; Subkey: "{#MyAppShortName}\shell\launch\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Flags: uninsdeletekey

[Code]
var
  SymlinkPage: TInputDirWizardPage;
  NotificationOptionPage: TInputOptionWizardPage;
  EmailPage: TWizardPage;
  EmailEdit: TEdit;
  EmailLabel: TLabel;
  PreText: TLabel;

function GetCurrentYear(Param: String): String;
begin
  result := GetDateTimeString('yyyy', '-', ':');
end;

function IsDirEmpty(dir: string): Boolean;
var
  FindRec: TFindRec;
  ct: Integer;
begin
  ct := 0;
  if FindFirst(ExpandConstant(dir + '\*'), FindRec) then
  try
    repeat
      if FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY = 0 then
        ct := ct+1;
    until
      not FindNext(FindRec);
  finally
    FindClose(FindRec);
    Result := ct = 0;
  end;
end;

//function getInstalledVersions(dir: string):
var
  nodeInUse: string;

procedure TakeControl(np: string; nv: string);
var
  path: string;
begin
  // Move the existing node.js installation directory to the nvm root & update the path
  RenameFile(np,ExpandConstant('{app}')+'\'+nv);

  RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', path);

  StringChangeEx(path,np+'\','',True);
  StringChangeEx(path,np,'',True);
  StringChangeEx(path,np+';;',';',True);

  RegWriteExpandStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', path);

  RegQueryStringValue(HKEY_CURRENT_USER,
    'Environment',
    'Path', path);

  StringChangeEx(path,np+'\','',True);
  StringChangeEx(path,np,'',True);
  StringChangeEx(path,np+';;',';',True);

  RegWriteExpandStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', path);

  nodeInUse := ExpandConstant('{app}')+'\'+nv;

end;

function Ansi2String(AString:AnsiString):String;
var
 i : Integer;
 iChar : Integer;
 outString : String;
begin
 outString :='';
 for i := 1 to Length(AString) do
 begin
  iChar := Ord(AString[i]); //get int value
  outString := outString + Chr(iChar);
 end;

 Result := outString;
end;

procedure PreInstall();
var
  TmpResultFile, TmpJS, NodeVersion, NodePath: string;
  stdout: Ansistring;
  ResultCode: integer;
  msg1, msg2, msg3, dir1: Boolean;
begin
  // Create a file to check for Node.JS
  TmpJS := ExpandConstant('{tmp}') + '\nvm_check.js';
  SaveStringToFile(TmpJS, 'console.log(require("path").dirname(process.execPath));', False);

  // Execute the node file and save the output temporarily
  TmpResultFile := ExpandConstant('{tmp}') + '\nvm_node_check.txt';
  Exec(ExpandConstant('{cmd}'), '/C node "'+TmpJS+'" > "' + TmpResultFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  DeleteFile(TmpJS)

  // Process the results
  LoadStringFromFile(TmpResultFile,stdout);
  NodePath := Trim(Ansi2String(stdout));
  if DirExists(NodePath) then begin
    Exec(ExpandConstant('{cmd}'), '/C node -v > "' + TmpResultFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    LoadStringFromFile(TmpResultFile, stdout);
    NodeVersion := Trim(Ansi2String(stdout));
    msg1 := SuppressibleMsgBox('Node '+NodeVersion+' is already installed. Do you want NVM to control this version?', mbConfirmation, MB_YESNO, IDYES) = IDNO;
    if msg1 then begin
      msg2 := SuppressibleMsgBox('NVM cannot run in parallel with an existing Node.js installation. Node.js must be uninstalled before NVM can be installed, or you must allow NVM to control the existing installation. Do you want NVM to control node '+NodeVersion+'?', mbConfirmation, MB_YESNO, IDYES) = IDYES;
      if msg2 then begin
        TakeControl(NodePath, NodeVersion);
      end;
      if not msg2 then begin
        DeleteFile(TmpResultFile);
        WizardForm.Close;
      end;
    end;
    if not msg1 then
    begin
      TakeControl(NodePath, NodeVersion);
    end;
  end;

  // Make sure the symlink directory doesn't exist
  if DirExists(SymlinkPage.Values[0]) then begin
    // If the directory is empty, just delete it since it will be recreated anyway.
    dir1 := IsDirEmpty(SymlinkPage.Values[0]);
    if dir1 then begin
      RemoveDir(SymlinkPage.Values[0]);
    end;
    if not dir1 then begin
      msg3 := SuppressibleMsgBox(SymlinkPage.Values[0]+' will be overwritten and all contents will be lost. Do you want to proceed?', mbConfirmation, MB_OKCANCEL, IDOK) = IDOK;
      if msg3 then begin
        RemoveDir(SymlinkPage.Values[0]);
      end;
      if not msg3 then begin
        //RaiseException('The symlink cannot be created due to a conflict with the existing directory at '+SymlinkPage.Values[0]);
        WizardForm.Close;
      end;
    end;
  end;
end;

function IsSymbolicLink(const Path: string): Boolean;
var
  FindRec: TFindRec;
begin
  Result := False;
  if FindFirst(Path, FindRec) then
  begin
    Result := (FindRec.Attributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0;
    FindClose(FindRec);
  end;
end;

procedure SymlinkPageChange(Sender: TObject);
var
  NewPath: string;
begin
  // Append '\nodejs' to the path if it is not already appended
  NewPath := AddBackslash(SymlinkPage.Values[0]) + 'nodejs';
  if Copy(SymlinkPage.Values[0], Length(SymlinkPage.Values[0]) - Length('\nodejs') + 1, Length('\nodejs')) <> '\nodejs' then
    SymlinkPage.Values[0] := NewPath;

  // Check if the new path exists and is not a symbolic link
  if DirExists(NewPath) and not IsSymbolicLink(NewPath) then
  begin
    MsgBox('The directory "' + NewPath + '" already exists as a physical directory. Please choose a different location.', mbError, MB_OK);
    SymlinkPage.Values[0] := '';
  end;
end;

procedure InitializeWizard;
begin
  SymlinkPage := CreateInputDirPage(wpSelectDir,
    'Active Version Location',
    'The active version of Node.js will always be available at this location.',
    'Select the folder in which Setup should create the symlink, then click Next.',
    False, '');
  SymlinkPage.Add('This directory will automatically be added to your system path.');
  SymlinkPage.Values[0] := ExpandConstant('C:\nvm4w\nodejs');

  // Assign the OnChange event handler
  SymlinkPage.Edits[0].OnChange := @SymlinkPageChange;

  // Notification option page (after the Symlink page)
  NotificationOptionPage := CreateInputOptionPage(
    SymlinkPage.ID, // Ensures the Notification page appears right after the Symlink page
    'Desktop Notifications (PREVIEW)',
    'NVM for Windows supports the basic (free) edition of Author Notifications.',
    'Select the events you wish to be notified of. Your choices can be modified at any time in the future.',
    FALSE,
    FALSE);

  // Pre-checked checkbox
  NotificationOptionPage.AddEx('Node.js LTS releases (Long-Term Support/Stable)', 0, FALSE);
  NotificationOptionPage.AddEx('Node.js Current releases (Latest/Testing)', 0, FALSE);
  NotificationOptionPage.AddEx('NVM For Windows releases', 0, FALSE);
  NotificationOptionPage.AddEx('Author updates and releases (upcoming NVM for Windows successor)', 0, FALSE);
  NotificationOptionPage.Values[0] := TRUE;
  NotificationOptionPage.Values[1] := TRUE;
  NotificationOptionPage.Values[2] := TRUE;
  NotificationOptionPage.Values[3] := TRUE;

  // Email Input Page
  EmailPage := CreateCustomPage(
    NotificationOptionPage.ID,
    'Author Progress Email Signup',
    'Get details about Author development milestones in your inbox.');

  // Add introductory text above the input field
  PreText := TLabel.Create(WizardForm);
  PreText.Parent := EmailPage.Surface;
  PreText.Caption := 'Author is the upcoming successor to NVM for Windows. Provide your email address to be informed of development milestones, release timelines, and enterprise capabilities. ' +
                     'Leave it blank if you do not wish to receive notifications.';
  PreText.Left := 10;
  PreText.Top := 10;
  PreText.Width := 600; // Adjust width to fit the text
  PreText.WordWrap := True; // Ensures the text wraps if it exceeds the width

  // Add a label for the email input field
  EmailLabel := TLabel.Create(WizardForm);
  EmailLabel.Parent := EmailPage.Surface;
  EmailLabel.Caption := 'Email Address: (Optional)';
  EmailLabel.Font.Style := [fsBold];
  EmailLabel.Left := 10;  // Position from the left
  EmailLabel.Top := 80;   // Position from the top

  // Add an email input field on the EmailPage
  EmailEdit := TEdit.Create(WizardForm);
  EmailEdit.Parent := EmailPage.Surface;
  EmailEdit.Left := 10;   // Align with the label
  EmailEdit.Top := 110;    // Position just below the label
  EmailEdit.Width := 610;
  EmailEdit.Text := ''; // Default value
end;

function LastPos(const SubStr, S: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := Length(S) downto 1 do
  begin
    if Copy(S, I, Length(SubStr)) = SubStr then
    begin
      Result := I;
      Exit;
    end;
  end;
end;

function IsValidEmail(const Email: string): Boolean;
var
  AtPos, DotPos: Integer;
begin
  AtPos := Pos('@', Email);
  DotPos := LastPos('.', Email);
  Result := (AtPos > 1) and (DotPos > AtPos + 1) and (DotPos < Length(Email));
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Email: string;
begin
  Result := True; // Allow navigation by default

  if CurPageID = SymlinkPage.ID then
  begin
    // Check if the directory is empty
    if DirExists(SymlinkPage.Values[0]) then
    begin
      if IsDirEmpty(SymlinkPage.Values[0]) then
      begin
        // If the directory is empty, just delete it since it will be recreated anyway.
        RemoveDir(SymlinkPage.Values[0]);
      end
      else
      begin
        // Show a warning if the directory is not empty
        MsgBox('The selected directory is not empty. Please choose a different path.', mbError, MB_OK);
        Result := False; // Prevent navigation to the next page
      end;
    end;
  end;

  if CurPageID = EmailPage.ID then
  begin
    Email := Trim(EmailEdit.Text); // Remove leading/trailing spaces
    if (Email <> '') and not IsValidEmail(Email) then
    begin
      MsgBox('Please enter a valid email address or leave the field blank.', mbError, MB_OK);
      Result := False; // Prevent navigation to the next page
    end
    else
    begin
      WizardForm.NextButton.Enabled := True; // Allow navigation to the next page
    end;
  end;

  // Handle the Notification page logic
  if CurPageID = NotificationOptionPage.ID then
  begin
    if NotificationOptionPage.Values[0] then
    begin
      Log('User opted to enable Node.js release notifications.');
      // Add your logic for enabling notifications here
    end
    else
    begin
      Log('User opted out of Node.js release notifications.');
    end;
  end;
end;

function InitializeUninstall(): Boolean;
var
  path: string;
  nvm_symlink: string;
begin
  SuppressibleMsgBox('Removing NVM for Windows will remove the nvm command and all versions of node.js, including global npm modules.', mbInformation, MB_OK, IDOK);

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
  rootDir: string;
begin
  if CurStep = ssInstall then
  begin
    // Ensure the root directory exists
    rootDir := ExtractFileDir(SymlinkPage.Values[0]);
    if not DirExists(rootDir) then
    begin
      if not CreateDir(rootDir) then
      begin
        MsgBox('Failed to create root directory: ' + rootDir, mbError, MB_OK);
        WizardForm.Close;
      end;
    end;
  end;

  if CurStep = ssPostInstall then
  begin
    SaveStringToFile(ExpandConstant('{app}\settings.txt'), 'root: ' + ExpandConstant('{app}') + #13#10 + 'path: ' + SymlinkPage.Values[0] + #13#10, False);

    // Add Registry settings
    RegWriteExpandStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'NVM_HOME', ExpandConstant('{app}'));
    RegWriteExpandStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'NVM_SYMLINK', SymlinkPage.Values[0]);
    RegWriteExpandStringValue(HKEY_CURRENT_USER, 'Environment', 'NVM_HOME', ExpandConstant('{app}'));
    RegWriteExpandStringValue(HKEY_CURRENT_USER, 'Environment', 'NVM_SYMLINK', SymlinkPage.Values[0]);

    RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppId}_is1', 'DisplayVersion', '{#MyAppVersion}');

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

function GetNotificationString(Param: String): String;
begin
  Result := ' subscribe';
  if NotificationOptionPage.Values[0] then
  begin
    Result := Result + ' --lts';
  end;
  if NotificationOptionPage.Values[1] then
  begin
    Result := Result + ' --current';
  end;
  if NotificationOptionPage.Values[2] then
  begin
    Result := Result + ' --nvm4w';
  end;
  if NotificationOptionPage.Values[3] then
  begin
    Result := Result + ' --author';
  end;
  Result := Trim(Result);
end;

function getSymLink(o: string): string;
begin
  Result := SymlinkPage.Values[0];
end;

function getCurrentVersion(o: string): string;
begin
  Result := nodeInUse;
end;

function isNodeAlreadyInUse(): boolean;
begin
  Result := Length(nodeInUse) > 0;
end;

function isEmailSupplied(): boolean;
begin
  Result := Trim(EmailEdit.Text) <> '';
end;

function GetEmailRegistrationString(Param: String): string;
begin
  Result := ' author newsletter --notify ' + Trim(EmailEdit.Text);
end;

[Run]
Filename: "{app}\nvm.exe"; Parameters: "{code:GetNotificationString}"; Flags: waituntilidle runhidden;
Filename: "{app}\nvm.exe"; Parameters: "{code:GetEmailRegistrationString}"; Check: isEmailSupplied; Flags: waituntilidle runhidden;
Filename: "{cmd}"; Parameters: "/C ""mklink /D ""{code:getSymLink}"" ""{code:getCurrentVersion}"""" "; Check: isNodeAlreadyInUse; Flags: waituntilidle runhidden;
Filename: "powershell.exe"; Parameters: "-NoExit -Command refreshenv; cls; Write-Host 'Welcome to NVM for Windows v{{VERSION}}'"; Description: "Open with Powershell"; Flags: postinstall skipifsilent;

[UninstallRun]
Filename: "{app}\nvm.exe"; Parameters: "unsubscribe --lts --current --nvm4w --author"; Flags: runhidden; RunOnceId: "UnregisterNVMForWindows";
Filename: "{app}\nvm.exe"; Parameters: "off"; Flags: runhidden; RunOnceId: "RemoveNVMForWindowsSymlink";
Filename: "{cmd}"; Parameters: "/C rmdir /S /Q ""{code:getSymLink}"""; Flags: runhidden; RunOnceId: "RemoveSymlink";

[UninstallDelete]
Type: filesandordirs; Name: "{app}";
Type: filesandordirs; Name: "{localappdata}\.nvm";
