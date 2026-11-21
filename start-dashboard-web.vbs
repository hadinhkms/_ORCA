Option Explicit
Dim WshShell, fso, scriptDir, batPath, logPath, cmd, shouldOpen, i, http, ready

Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
batPath = scriptDir & "\start-dashboard-web.bat"
logPath = scriptDir & "\start-dashboard-web.log"

shouldOpen = False
For i = 0 To WScript.Arguments.Count - 1
    If LCase(WScript.Arguments(i)) = "--open" Then
        shouldOpen = True
    End If
Next

cmd = "cmd.exe /c """"" & batPath & """ --run > """ & logPath & """ 2>&1"""
WshShell.Run cmd, 0, False

If shouldOpen Then
    ready = False
    WScript.Sleep 1200
    For i = 1 To 30
        On Error Resume Next
        Set http = CreateObject("MSXML2.ServerXMLHTTP.6.0")
        http.setTimeouts 500, 500, 500, 500
        http.Open "GET", "http://127.0.0.1:5173/web-index.html", False
        http.Send
        If Err.Number = 0 And http.Status = 200 Then
            ready = True
            On Error GoTo 0
            Exit For
        End If
        Err.Clear
        On Error GoTo 0
        WScript.Sleep 500
    Next
    WshShell.Run "http://127.0.0.1:5173/web-index.html", 1, False
End If
