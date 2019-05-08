@ECHO OFF
powershell -ExecutionPolicy Bypass -NoProfile -NoLogo -WindowStyle Hidden -File "%~dp0\Reboot-Policy.ps1" -IgnoreRebootCheck -AllowRebootPassThru