<#
.SYNOPSIS
	This script performs the reboot checks.
.DESCRIPTION
	
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.PARAMETER EnableScriptTest
	Speeds up the reboot policy to 1 minute intervals between messages. Default is: $false.
.PARAMETER RebootIntervalDays
	Compares the last reboot date timestamp to number specified; Default is: 7 days
.PARAMETER MaxReboots
    Doesn't allow script to reboot the system more than this number; Safety incase system need multple reboots; Default is: 2 times
.PARAMETER IgnoreRebootCheck
	Force the system to go through the reboot scenario. Use in conjunction with EnableScriptTest to allow quicker test of the full check. Default is: $false.
.PARAMETER ForcePendingReboot
	Force the system reboot if a pending reboot is detected on system no matter the day it rebooted in the past. Ignores the RebootIntervalDays check as well. Default is: $false.
.PARAMETER ScriptDisabled
	Disables the script from running. Also can be switched by seeting a registry key in HKLM\SOFTWARE\Policies\RebootPolicy with a key of DisableRebootPolicy of 1. Can be controlled by GPO. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Reboot-Policy.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Reboot-Policy.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
	Reboot-Policy.ps1 -AllowRebootPassThru -AllowDefer
.EXAMPLE
	Reboot-Policy.ps1 -ScriptDisabled
.EXAMPLE
	Reboot-Policy.ps1 -EnableScriptTest -IgnoreRebootCheck
.EXAMPLE
	Reboot-Policy.ps1 -EnableScriptTest -IgnoreRebootCheck -ForcePendingReboot
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK 
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
    [Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false,
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory=$false)]
    [switch]$EnableScriptTest = $false,
    [Parameter(Mandatory=$false)]
    [switch]$IgnoreRebootCheck = $false,
    [Parameter(Mandatory=$false)]
    [switch]$ForcePendingReboot = $false,
    [Parameter(Mandatory=$false)]
    [switch]$ScriptDisabled = $false,
    [ValidateSet(1,3,5,7,14)]
	[int32]$RebootIntervalDays = 7,
    [Parameter(Mandatory=$false)]
    [int32]$MaxReboots = 2 
    )

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}
	
	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'Your Company'
	[string]$appName = 'Reboot Policy'
	[string]$appVersion = '4.0'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '04/19/2018'
	[string]$appScriptAuthor = 'Richard Tracy'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''
	
	##* Do not modify section below
	#region DoNotModify
	
	## Variables: Exit Code
	[int32]$mainExitCode = 0
	
	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.6.8'
	[string]$deployAppScriptDate = '02/06/2016'
	[hashtable]$deployAppScriptParameters = $psBoundParameters
	
	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent
	
	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}
	
	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

    ##*===============================================
    ##*  START POLICY
    ##*===============================================

    #Set Global Variables for functions
    $Global:EnableScriptTest = $EnableScriptTest
    $Global:AllowRebootPassThru = $AllowRebootPassThru

    #Get system boot time
    $wmi = Get-WmiObject -Class Win32_OperatingSystem -Computer localhost
    $ConvertTime = $wmi.ConvertToDateTime($wmi.LastBootUpTime)
    $LastReboot = $ConvertTime

    #Get day of year (Julian)
    $LogDayOfYear = (Get-Date).DayOfYear

    # Get the current date and time
    $Date = Get-Date
    <# Variables needed according to policy 
    # If test is enabled change, speed up the time it takes for popups
    #>

    # If Weekly is 
    $PolicyRebootCheck = Get-RegistryKey -Key 'HKLM:SOFTWARE\Policies\RebootPolicy' -Value 'RebootCheck'
    if($PolicyRebootCheck){   
        $RebootIntervalDays = $PolicyRebootCheck
    }
        
    switch($RebootIntervalDays) {
        1       {
                $RebootCheck = 1
                $RequiredRebootDate = $Date.AddDays(-1).AddMinutes(-30)
                $RemoveLogsJulianDay = 30
                $RebootPolicyTitle = 'Daily'
                $MainBalloonMsg = 'Your system has been running more than a day'
                }

        3       {
                $RebootCheck = 3
                $RequiredRebootDate = $Date.AddDays(-2).AddMinutes(-30)
                $RemoveLogsJulianDay = 30
                $RebootPolicyTitle = '3 day'
                $MainBalloonMsg = 'Your system has been running longer than 3 days'
                }
            
        5       {
                $RebootCheck = 5
                $RequiredRebootDate = $Date.AddDays(-6).AddMinutes(-30)
                $RemoveLogsJulianDay = 30
                $RebootPolicyTitle = '5 day'
                $MainBalloonMsg = 'Your system has been running longer than 5 days'
                }

        7       {
                $RebootCheck = 7
                $RequiredRebootDate = $Date.AddDays(-6).AddMinutes(-30)
                $RemoveLogsJulianDay = 30
                $RebootPolicyTitle = 'Weekly'
                $MainBalloonMsg = 'Your system has been running longer than a week'
                }

        14      {
                $RebootCheck = 14
                $RequiredRebootDate = $Date.AddDays(-14).AddMinutes(-30)
                $RemoveLogsJulianDay = 90
                $RebootPolicyTitle = 'bi-Weekly'
                $MainBalloonMsg = 'Your system has been running longer than two weeks'
            
                }

        default {
                $RebootCheck = 7
                $RequiredRebootDate = $Date.AddDays(-6).AddMinutes(-30)
                $RemoveLogsJulianDay = 30
                $RebootPolicyTitle = 'Weekly'
                $MainBalloonMsg = 'Your system has been running longer than a week'
                }
    }

    if($EnableScriptTest){
        $RebootIntervalDays = 1
        $RebootPopupMinutes1 = 2
        $RebootPopupMinutes2 = 2
        $RebootPopupMinutes3 = 2
        $RebootPopupCountdown = 1
        $RandomMax = 10
        $LogDeleteAge = (Get-Date).DayOfYear - 1
        $SleepBetweenChecks = 10
        #Reboot in 30 days (actual 0 days and 30 minutes)
        $RequiredRebootDate = $Date.AddMinutes(-30)
        $AppendMsg = "SCRIPT TEST ENABLED`n"
    } 
    else {
        $RebootPopupMinutes1 = 60
        $RebootPopupMinutes2 = 45
        $RebootPopupMinutes3 = 15
        $RebootPopupCountdown = 5
        $RandomMax = 300
        $SleepBetweenChecks = 60
        $LogDayofYear = (Get-Date).DayOfYear
        If ($LogDayofYear -le $RemoveLogsJulianDay){
            $LogDeleteAge = 0 
        } 
        Else {
            $LogDeleteAge = (Get-Date).DayOfYear - $RemoveLogsJulianDay
        }
        $AppendMsg = ""
    }
    #remove spaces from application name for registry
    $RegAppname = $appName.Replace(" ","").Trim()

    #Convert timers
    $RebootPopupClock1 = $Date.AddMinutes($RebootPopupMinutes1)
    $RebootPopupClock2 = $Date.AddMinutes($RebootPopupMinutes2)
    $RebootPopupClock3 = $Date.AddMinutes($RebootPopupMinutes3)
    $Global:FirstRebootDelay = ([timespan]::FromMinutes($RebootPopupMinutes2)).TotalSeconds
    $Global:SecondRebootDelay = ([timespan]::FromMinutes($RebootPopupMinutes3)).TotalSeconds - ([timespan]::FromMinutes($RebootPopupCountdown)).TotalSeconds
    $Global:RebootCountdown = ([timespan]::FromMinutes($RebootPopupCountdown)).TotalSeconds

    #balloon Messages
    $CompliantBalloonMsg = "This system has met all requirements and does not need to be rebooted.`n`nHave a nice day!"
    $PendingRebootBalloonMsg = "Your system is pending a reboot; probably from updates."
    $ForcedRebootBalloonMsg = "Your system is forced to reboot."
    $RebootErrorBalloonMsg = "This system has issues with updates, please contact your Administrator."

    $Action1BalloonMsg = "You have chosen to wait to reboot. You will be prompted again in $RebootPopupMinutes2 minutes." 
    $Action2BalloonMsg = "You have chosen to wait to reboot. This system will reboot in $RebootPopupMinutes3 minutes. The countdown will start in $($RebootPopupMinutes3 - $RebootPopupCountdown) minutes."
    
    #Popup 1 Messages
    $MainPopup1Msg = "$($AppendMsg) Based on the system's uptime information, this system has not been rebooted since:`n$LastReboot`n`n
    Policy states this system must reboot $RebootPolicyTitle. This system is scheduled to reboot in $RebootPopupMinutes1 minutes at:`n$RebootPopupClock1`n`n
    If you HIDE this message you will be prompted again in $RebootPopupMinutes2 minutes. If you choose to REBOOT now, you will be given $RebootPopupCountdown minutes to close your applications.`n`n
    Thank you."

    $PendingRebootPopup1Msg = "$($AppendMsg) Since Pending Reboot Check is ENABLED by your administrator AND this system is pending a reboot from updates or another installation.
    This system is scheduled to reboot in $RebootPopupMinutes1 minutes at:`n$RebootPopupClock1`n`n
    If you HIDE this message you will be prompted again in $RebootPopupMinutes2 minutes.
    If you choose to REBOOT now, you will be given $RebootPopupCountdown minutes to close your applications.`n`n
    Thank you."
        
    $ForceRebootPopup1Msg = "$($AppendMsg) Since Ignore Reboot Check is ENABLED by your administrator, this system will be forced to reboot.
    This system is scheduled to reboot in $RebootPopupMinutes1 minutes at:`n$RebootPopupClock1`n`n
    If you HIDE this message you will be prompted again in $RebootPopupMinutes2 minutes.
    If you choose to REBOOT now, you will be given $RebootPopupCountdown minutes to close your applications.`n`n
    Thank you."

    #popup 2 message
    $MainPopup2Msg = "$($AppendMsg) THIS IS YOUR SECOND WARNING!`n`n  Policy states this system must reboot $RebootPolicyTitle.
    This system is scheduled to reboot in $RebootPopupMinutes3 minutes at:`n$RebootPopupClock3`n`n
    If you HIDE this message you will be presented with a reboot times $RebootPopupCountdown minutes before the deadline. 
    If you choose to REBOOT now, you will be given $RebootPopupCountdown minutes to close your applications.`n`n
    Thank you."

    $PendingRebootPopup2Msg = "$($AppendMsg) THIS IS YOUR SECOND WARNING!`n`nThis system is pending a reboot from another installation.
    This system is scheduled to reboot in $RebootPopupMinutes3 minutes at:`n$RebootPopupClock3`n`n
    If you HIDE this message you will be presented with a reboot times $RebootPopupCountdown minutes before the deadline.
    If you choose to REBOOT now, you will be given $RebootPopupCountdown minutes to close your applications.`n`n`
    Thank you."

    $ForceRebootPopup2Msg = "$($AppendMsg) THIS IS YOUR SECOND WARNING!`n`nThis system is forced to reboot.
    This system is scheduled to reboot in $RebootPopupMinutes3 minutes at:`n$RebootPopupClock3`n`n
    If you HIDE this message you will be presented with a reboot times $RebootPopupCountdown minutes before the deadline.
    If you choose to REBOOT now, you will be given $RebootPopupCountdown minutes to close your applications.`n`n`
    Thank you."

    $TestEndPopupMsg = "$($AppendMsg)`n This system would have rebooted."


    #Cleanup old Script logs and set new version
    $CleanupLogging = $true
    If ($CleanupLogging){
        <#
        Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname\Logging" -Name 'LastResult' -Value "Cleanup" -Type String
        Remove-RegistryKey -Key "HKLM:SOFTWARE\$appVendor\$RegAppname\Logging" -Name "PromptActionResponse1"
        Remove-RegistryKey -Key "HKLM:SOFTWARE\$appVendor\$RegAppname\Logging" -Name "PromptActionResponse2"
        #>
        #Remove-RegistryKey -Key 'HKLM:SOFTWARE\Policies\RebootPolicy' -Recurse
        Remove-RegistryKey -Key "HKLM:SOFTWARE\Policies\$RegAppname\Logging"
        Remove-RegistryKey -Key "HKLM:SOFTWARE\$appVendor\$RegAppname\Logging"
        $OldLogKeyPaths = Search-Registry -StartKey "HKLM:\Software\$appVendor\$RegAppname" -Pattern RunLog -MatchKey
        If ($OldLogKeyPaths){
            foreach ($OldLogKeyPath in $OldLogKeyPaths){
                $OldLogKey = $OldLogKeyPath.Key
                $OldLogDayofYear = $OldLogKey.split("-")
                if ($OldLogDayofYear[1] -lt $LogDeleteAge) {
                    #write-host "Will remove key"
                    Remove-RegistryKey -Key "$OldLogKey" -Recurse
                }
            }
        }
    }

    #Remove-RegistryKey -Key 'HKLM:SOFTWARE\$appVendor\$RegAppname\Logging'
    Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname" -Name 'ScriptVersion' -Value "$appScriptVersion" -Type String
    Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname" -Name 'ScriptLastRunTime' -Value "$Date" -Type String
    Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname" -Name 'ScriptLastLogDir' -Value "RunLog-$LogDayOfYear" -Type String

    #Reset Keys
    Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname\RunLog-$LogDayOfYear" -Name 'LastResult' -Value "Running" -Type String


    #Count how many times the script has ran
    $PolicyRunCountKey = Get-RegistryKey -Key "HKLM:SOFTWARE\$appVendor\$RegAppname" -Value "PolicyRunCount"
    $PolicyRunCountIncrement = $PolicyRunCountKey+1
    if ($PolicyRunCountKey){
        $PolicyRunCountIncrement = $PolicyRunCountKey+1
        Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname" -Name 'PolicyRunCount' -Value $PolicyRunCountIncrement -Type QWord
    } 
    else {
        Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname" -Name 'PolicyRunCount' -Value 1 -Type QWord
    }

    # Exit script if set to be disabled and exit with 0
    $CheckIfPolicyDisabled = Get-RegistryKey -Key 'HKLM:SOFTWARE\Policies\RebootPolicy' -Value 'DisableRebootPolicy'
    if($ScriptDisabled -or $CheckIfPolicyDisabled -eq 1){
        Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname\RunLog-$LogDayOfYear" -Name 'LastResult' -Value "Disabled" -Type String
        Exit-Script -ExitCode 0
    }

    #Check if the reboot counter has hit the max if so kill script
    $RebootAttemptKey = Get-RegistryKey -Key "HKLM:SOFTWARE\$appVendor\$RegAppname" -Value "RebootAttemptCounter"
    if($RebootAttemptKey -gt $maxreboots){
        Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname" -Name 'RebootAttemptCounter' -Value "0" -Type QWord
        Show-BalloonTip -BalloonTipText $RebootErrorBalloonMsg -BalloonTipTitle 'Reboot Policy'
        Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname" -Name 'ErrorDisabled' -Value 1 -Type QWord
        Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname\RunLog-$LogDayOfYear" -Name 'LastResult' -Value "ErrorDisabled" -Type String
        Exit-Script -ExitCode 0
    }

    # Check if Pending Reboot key exists
    #$PendingRebootKeyKey = Get-RegistryKey -Key 'HKLM:SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations'
    $PendingRebootKey = (Get-PendingReboot).IsSystemRebootPending
    if($PendingRebootKey){
        Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname\RunLog-$LogDayOfYear" -Name 'PendingRebootWhenRan' -Value 1 -Type QWord
    } 
    else{
        Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname\RunLog-$LogDayOfYear" -Name 'PendingRebootWhenRan' -Value 0 -Type QWord
    }

    [string]$installPhase = 'Installation'
    ## Show Welcome Message, close task manager if required, block it, verify there is enough disk space to complete the install, and persist the prompt
    if(!$EnableScriptTest){Show-InstallationWelcome -CloseApps 'Taskmgr' -Silent -BlockExecution}

    # Get random number for first use, always use this key (1 to 5 minutes)
    $random = Get-Random -minimum 1 -maximum $RandomMax
    Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname\RunLog-$LogDayOfYear" -Name 'SleepRandomKey' -Value $random -Type QWord

    #log Last reboot time
    Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname\RunLog-$LogDayOfYear" -Name 'LastRebootDate' -Value $LastReboot -Type String

    # Start script at a random time to offset amount of prompts per system
    Start-Sleep -s $random
        
    #Get date again but after random and thats the start time
    $StartTime = Get-Date
    Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname\RunLog-$LogDayOfYear" -Name 'PolicyStartTime' -Value $StartTime -Type String
        
    #since user logged in, prompt reboot
    If($usersLoggedOn){
        Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname\RunLog-$LogDayOfYear" -Name 'UserLoggedinWhenRan' -Value $usersLoggedOn -Type String
        # Is the reboot check is forced?
        if($IgnoreRebootCheck){
            Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname\RunLog-$LogDayOfYear" -Name 'LastResult' -Value "ForcedReboot-Prompt" -Type String
            Show-BalloonTip -BalloonTipText $ForcedRebootBalloonMsg -BalloonTipTitle 'Reboot Policy (Forced)' -BalloonTipIcon 'Warning'
            Start-Sleep -s $SleepBetweenChecks
            Execute-Policy -PopupMessage1 $ForceRebootPopup1Msg -PopupMessage2 $ForceRebootPopup2Msg -BalloonMessage1 $Action1BalloonMsg -BalloonMessage2 $Action2BalloonMsg
        }
        # Check if Last reboot status is greater than or equal to required reboot date
        elseif($ForcePendingReboot -and $PendingRebootKey){
            Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname\RunLog-$LogDayOfYear" -Name 'LastResult' -Value "PendingReboot-Prompt" -Type String
            Show-BalloonTip -BalloonTipText $PendingRebootBalloonMsg -BalloonTipTitle 'Reboot Policy (Pending)' -BalloonTipIcon 'Warning'
            Start-Sleep -s $SleepBetweenChecks
            Execute-Policy -PopupMessage1 $PendingRebootPopup1Msg -PopupMessage2 $PendingRebootPopup2Msg -BalloonMessage1 $Action1BalloonMsg -BalloonMessage2 $Action2BalloonMsg  
        }
        # Check if Last reboot status is greater than or equal to required reboot date
        elseif($LastReboot -le $RequiredRebootDate){
            Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname\RunLog-$LogDayOfYear" -Name 'LastResult' -Value "RequiredReboot-Prompt" -Type String
            Show-BalloonTip -BalloonTipText $MainBalloonMsg -BalloonTipTitle "Reboot Policy ($RebootPolicyTitle)" -BalloonTipIcon 'Warning'
            Start-Sleep -s $SleepBetweenChecks
            Execute-Policy -PopupMessage1 $MainPopup1Msg -PopupMessage2 $MainPopup2Msg -BalloonMessage1 $Action1BalloonMsg -BalloonMessage2 $Action2BalloonMsg
        }
        #system is complaint
        else{
            Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname\RunLog-$LogDayOfYear" -Name "LastResult" -Value "NoReboot-Needed" -Type String
            Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname\RunLog-$LogDayOfYear" -Name "PolicyEndTime" -Value $EndDate -Type String 
            Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname\RunLog-$LogDayOfYear" -Name "RebootAttemptCounter" -Value 0 -Type QWord
            Show-BalloonTip -BalloonTipText $CompliantBalloonMsg -BalloonTipTitle 'Reboot Policy' -BalloonTipIcon 'None'
            
            #Check to make sure system has unblocked the taskmgr
            Unblock-AppExecution
            #check again
            $TaskMgrBlock = Get-RegistryKey -Key 'HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\Taskmgr.exe' -Value 'Debugger'
            If ($TaskMgrBlock){
                Remove-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\Taskmgr.exe' -Name 'Debugger'
            }
            Start-Sleep -s $SleepBetweenChecks
        }
    } 
    #no user logged in, reboot system
    else {
        Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname\RunLog-$LogDayOfYear" -Name 'LastResult' -Value "Rebooted-NoUser" -Type String
        Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\$appVendor\$RegAppname\RunLog-$LogDayOfYear" -Name 'PolicyEndTime' -Value $EndDate -Type String 
        Set-RebootTimer -Seconds $RebootCountdown -Test $Test -PassThru $PassThru
    }
		
	
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================
	
	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}