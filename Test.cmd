@ECHO OFF
powershell -ExecutionPolicy bypass -file "%~dp0\Reboot-Policy.ps1" -EnableScriptTest -IgnoreRebootCheck -ForcePendingReboot