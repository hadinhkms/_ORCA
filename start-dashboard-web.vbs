Option Explicit
Dim WshShell, fso, scriptDir, batPath, cmd, shouldOpen, i, http, ready

Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
batPath = scriptDir & "\start-dashboard-web.bat"

shouldOpen = False
For i = 0 To WScript.Arguments.Count - 1
    If LCase(WScript.Arguments(i)) = "--open" Then
        shouldOpen = True
    End If
Next

Function IsHostReady()
    Dim req
    IsHostReady = False
    On Error Resume Next
    Set req = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    req.setTimeouts 500, 500, 500, 500
    req.Open "GET", "http://127.0.0.1:6769/web-index.html", False
    req.Send
    If Err.Number = 0 And req.Status = 200 Then
        IsHostReady = True
    End If
    Err.Clear
    On Error GoTo 0
End Function

If Not IsHostReady() Then
    cmd = "cmd.exe /c """"" & batPath & """ --run"""
    WshShell.Run cmd, 0, False
    If shouldOpen Then
        WScript.Sleep 1500
        ' First run after a pull rebuilds Electron (often >1 min); wait up to ~5 min.
        For i = 1 To 600
            If IsHostReady() Then
                Exit For
            End If
            WScript.Sleep 500
        Next
    End If
End If

If shouldOpen Then
    WshShell.Run "http://127.0.0.1:6769/web-index.html", 1, False
End If
