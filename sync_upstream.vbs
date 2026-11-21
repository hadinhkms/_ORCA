Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
batPath = scriptDir & "\sync_upstream.bat"
logPath = scriptDir & "\sync_upstream.log"
cmd = "cmd.exe /c """"" & batPath & """ --silent >> """ & logPath & """ 2>&1"""
WshShell.Run cmd, 0, True
