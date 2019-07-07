Set WSHShell = CreateObject("WScript.Shell")
userpath = WSHShell.RegRead("HKCU\Environment\Path")
If InStr(userpath, "%NVM_HOME%") = False Then
    userpath = userpath & ";%NVM_HOME%;"
End If
If InStr(userpath, "%NVM_SYMLINK%") = False Then
    userpath = userpath & ";%NVM_SYMLINK%;"
End If

userpath = Replace(userpath, ";;", ";")
WSHShell.RegWrite "HKCU\Environment\Path", userpath