Set WSHShell = CreateObject("WScript.Shell")
userpath = WSHShell.RegRead("HKCU\Environment\Path")
userpath = Replace(userpath, "%NVM_HOME%", "")
userpath = Replace(userpath, "%NVM_SYMLINK%", "")
userpath = Replace(userpath, ";;", ";")
WSHShell.RegWrite "HKCU\Environment\Path", userpath