# PSRebootPolicy
Reboot Policy using PowerShell and a modified verison of AppdeployToolkit

![Alt_text](https://github.com/PowerShellCrack/PSRebootPolicy/blob/master/screenshots/rebootpolicy_firstprompt.png?raw=true)

# Goal
I needed a way I can reboot a system but give the user 3 prompts before doing so at different time intevals. Also to report those responses to management. 

# Solution
PSAppDeployToolkit (https://psappdeploytoolkit.com/) provided a interesting way of presenting a UI to the user when deployed via SCCM. I modified the UI slightly to achieve a look that was like a notification for the user.


## Additional switches

| Parameters          | Values     | Comments                 |
|-------------------  |--------    |--------------------------|
| AllowRebootPassThru  | True/False | Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered. |
|EnableScriptTest     | True/False | Speeds up the reboot policy to 2 minute intervals between messages. Default is: $false. |
| IgnoreRebootCheck    | True/False  | Force the system to go through the reboot scenario no matter what. Use in conjunction with EnableScriptTest to allow quicker test of the full check. Default is: $false. |
| ForcePendingReboot   | True/False  | Force the system reboot if a pending reboot is detected on system no matter the day it rebooted in the past. Ignores the RebootIntervalDays check as well. Default is: $false. |
| ScriptDisabled       | True/False  | Disables the script from running. Also can be switched by seeting a registry key in HKLM\SOFTWARE\Policies\RebootPolicy with a key of DisableRebootPolicy of 1. Can be controlled by GPO. Default is: $false. |
| RebootIntervalDays      | 1,3,5,7,14 | Compares the last reboot date timestamp to number specified; Default is: 7 days |
| MaxReboots           | integer      | Doesn't allow script to reboot the system more than this number; Safety incase system need multple reboots; Default is: 2 times |

## Main Logging
Script logs entries into the registry under `HKLM:SOFTWARE\Policies\<Company name>\Logging`

| Entry                | Values                | Comments                 |
|-------------------   |--------               |--------------------------|
| ScriptVersion        |  Version              |                          |
| ScriptLastRunTime    | Date                  |
| ScriptLastLogDir     | <See RunLog section>
| PolicyRunCount       | Counter               | Count how many times the script has ran|
| DisableRebootPolicy  | 0 or 1                | Exit script if set to be disabled and exit with 0
| RebootAttemptCounter | Counter | Check if the reboot counter has hit the max if so kill script
| ErrorDisabled        | 0 or 1                | Triggered set if max reboot is reached
| RebootCountTotal     | Counter               | Record total times script has rebooted system

## Run Logging
There is a sub keys to record every instance and acton when ran using julian time format. It is located here: `HKLM:SOFTWARE\Policies\<Company name>\Logging\RunLog-<julianDate>`

| Entry               | Values     | Comments                 |
|-------------------  |--------    |--------------------------|
| LastResult          | <Status>   | Status are: Running,Disabled,ErrorDisabled,ForcedReboot-Prompt,PendingReboot-Prompt,RequiredReboot-Prompt,NoReboot-Needed,Rebooted-NoUser |
| PendingRebootWhenRan | 0 or 1                | Logs if Pending Reboot key exists |
| SleepRandomKey      | Random 0-300 | logs random number for first use, always use this key for this instance (1 to 5 minutes) |
| LastRebootDate      | Date           | Logs last time the system rebooted |
| PolicyStartTime     | Date           | Logs when script started |
| UserLoggedinWhenRan | username       | Logs if a user is logged in (actively or inactively) |
| PolicyEndTime       | Date           | Logs when script ends |
|PromptActionResponse1 | Hide/Reboot   | Logs reponse for first prompt |
|PromptActionResponse2 | Hide/Reboot   | Logs reponse for second prompt |

## GPO Policy
Script can also be controlled by a GPO policy. Key will be located here: `HKLM:SOFTWARE\Policies\RebootPolicy`

| Entry               | Values     | Comments                 |
|-------------------  |--------    |--------------------------|
| DisableRebootPolicy  | 0/1 | Disabled the script entirely if set to 1, no matter what runs it


## Status 
Here are meanings of the status messages 
| Value                  | Meaning               |
|-------------------     |--------------------------|
| Running                | Script is running |
| Disabled               | Script is disabled either by GPO or ScriptDisabled parameter |
| ErrorDisabled          | Script Errored because it rebooted system mor than MaxReboots |
| ForcedReboot-Prompt    | Script parameter $IgnoreRebootCheck is triggered and prompted user |
| PendingReboot-Prompt   | Script detected a pending reboot is required and prompted user |
| RequiredReboot-Prompt  | Script detected a reboot is required based last reboot is greater than RebootIntervalDays and prompted user |
| NoReboot-Needed        | Script detected no reboot required and notified user |
| Rebooted-NoUser        | Script detected no user is logged in and it will reboot the system with no prompt |


