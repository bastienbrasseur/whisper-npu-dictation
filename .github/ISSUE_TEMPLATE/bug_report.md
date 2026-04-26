---
name: Bug report
about: Something doesn't work — help us reproduce it
labels: bug
---

## System

| Field | Your value |
|-------|-----------|
| CPU / NPU | e.g. Ryzen AI 9 HX 370 (Strix Point) |
| NPU driver version | e.g. 32.0.203.329 — check in Device Manager |
| XRT version | run `C:\Windows\System32\AMD\xrt-smi.exe examine` |
| Windows build | e.g. 26200 |
| Lemonade Server version | run `lemonade --version` |
| Python version | run `python --version` |

## What happened

<!-- Describe what you did and what went wrong -->

## Expected behavior

<!-- What should have happened -->

## Error output

<!-- Paste any error messages here. For AHK errors: right-click tray icon → open script, look for error dialogs.
     For Lemonade errors: run `lemonade logs` -->

```
paste here
```

## Steps to reproduce

1. 
2. 
3. 

## NPU detected?

Run this and paste the output:
```powershell
C:\Windows\System32\AMD\xrt-smi.exe examine
```

## Lemonade status

```powershell
$lem = "$env:LOCALAPPDATA\lemonade_server\bin\lemonade.exe"
& $lem status
(Invoke-RestMethod http://localhost:13305/api/v1/system-info).devices.amd_npu
```
