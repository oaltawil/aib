<#PSScriptInfo

.VERSION 0.0.1

.GUID a99a7416-19d1-4c7e-a4aa-cc21fd55638d

.AUTHOR oaltawil@microsoft.com

.TAGS WVD

.LICENSEURI https://www.gnu.org/licenses/gpl-3.0.html

.RELEASENOTES
v0.0.1 Initial version released on July 19, 2021
#>

<#
.SYNOPSIS
The Add-Win7SessionHost.ps1 script can be used to join a Windows 7 Session Host Virtual Machine to an Azure Virtual Desktop Host Pool.

.DESCRIPTION
The Add-Win7SessionHost.ps1 script is typically executed using the Custom Script Virtual Machine Extension in an Azure Resource Manager Template. 

The script downloads and installs the following:
- Azure Virtual Desktop Agent for Windows 7: Microsoft.RDInfra.WVDAgent.Installer-x64-version
- Azure Virtual Desktop Agent Manager for Windows 7: Microsoft.RDInfra.WVDAgentManager.Installer-x64-version

The script returns errors, but continues execution, if any of the following requirements for Azure Virtual Desktop Agent is not met:
- Microsoft .Net Framework 4.7.2 (or later) is installed
- "KB2592687 - Security Update for Windows 7 x64" (for Remote Desktop Protocol 8.0) is installed
- "Enable Remote Desktop Protocol 8.0" group policy setting is enabled

.PARAMETER HostPoolRegistrationToken
Registration Key of the Azure Virtual Desktop Host Pool that the Session Host VM is joining. 

.EXAMPLE
The following example installs the Azure Virtual Desktop Agent and Azure Virtual Desktop Agent Manager. Please note that the Azure Virtual Desktop Service automatically updates the agent whenever an agent update is available.

Add-Win7SessionHost.ps1 -HostPoolRegistrationToken "ey...BjHbQ"

#>

param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [String]
    $HostPoolRegistrationToken
)

#
# Define the download URL's for Azure Virtual Desktop Agent for Windows 7 and Azure Virtual Desktop Agent Manager for Windows 7
#

# "13. Download the Azure Virtual Desktop Agent for Windows 7" Link in "https://docs.microsoft.com/en-us/azure/virtual-desktop/deploy-windows-7-virtual-machine#configure-a-windows-7-virtual-machine"
$WVDAgentInstallerDownloadUri = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RE3JZCm"

# "14. Download the Azure Virtual Desktop Agent Manager for Windows 7" Link in "https://docs.microsoft.com/en-us/azure/virtual-desktop/deploy-windows-7-virtual-machine#configure-a-windows-7-virtual-machine"
$WVDAgentManagerInstallerDownloadUri = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RE3K2e3"


#
# A helper function that outputs an error message and stops script execution.
#
function Write-TerminatingError {

    param (
        [Parameter(Mandatory)]
        [String]
        $Message
    )

    Write-Host $Message

    Stop-Transcript

    Exit

}


#
# Setup Script Logging 
#

$MsiExecSuccessExitCodes = @(
    
    0,      # Success (no reboot)
    1707,   # Success (no reboot)
    3010,   # Soft Reboot
    1641,   # Hard Reboot
    1618    # Fast Retry 
    
)

# Retrieve the script's parent folder
$ScriptWorkingDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

# If the script's working directory could not be determined, use the currently logged on user's Temporary folder instead
if (-not $ScriptWorkingDirectory) {

    $ScriptWorkingDirectory = $ENV:TEMP

}

# Generate the name of the Script log file: Add-Win7SessionHost.log
$LogFileName = ($MyInvocation.MyCommand.Name).Replace(".ps1", ".log")

# If the script's file name could not be determined, use the static string "Add-Win7SessionHost.log"
if (-not $LogFileName) {

    $LogFileName = "Add-Win7SessionHost.log"
    
}

# Start a transcript logging all script activity to the Script log file
Start-Transcript -Path (Join-Path -Path $ScriptWorkingDirectory -ChildPath $LogFileName) -Append


#
# Verify Administrative Privileges
#

$whoamiGroups = whoami.exe /groups

$AdministratorsGroup = $whoamiGroups | Where-Object {$_ -match "BUILTIN\\Administrators" -or $_ -match "BUILTIN\\Administrateurs"}

if (($AdministratorsGroup -notmatch "Enabled") -and ($AdministratorsGroup -notmatch "Activ")) {

    Write-TerminatingError "Administrative privileges are required. Please run the script from an elevated context, i.e. Run As Administrator.`n"

}


#
# Verify .Net Framework Version
#

<#

Reference: https://docs.microsoft.com/en-us/dotnet/framework/migration-guide/how-to-determine-which-versions-are-installed#detect-net-framework-45-and-later-versions

Release numbers (or versions) for .Net Framework 4.7.2:

Release     Operating System
=======     ================
461808      Windows 10 v1803 and Windows Server v1803
461814      All other operating systems

#>

$NDPv4FullRegKey = "HKLM:\SOFTWARE\Microsoft\Net Framework Setup\NDP\v4\Full"

$NDPv4ErrorMessage = "Microsoft .Net Framework 4.7.2 (or later) is required by Azure Virtual Desktop Agent.`n"

# Retrieve the Release (version number) of the Microsoft .Net Framework
$ReleaseRegValue = Get-ItemProperty -Path $NDPv4FullRegKey -Name "Release" -ErrorAction SilentlyContinue

# If the Release registry value does not exist, output an error message
if (-not $ReleaseRegValue) {

    Write-Host $NDPv4ErrorMessage

}
# Release 461808 covers all versions of .Net Framework 4.7.2. If the Release is greater than 461808, output a success message
elseif ($ReleaseRegValue.Release -ge 461808) {

     Write-Host "Successfully verified that .Net Framework 4.7.2 (or later) is installed.`n"

}
else {

    Write-Host $NDPv4ErrorMessage

}


#
# Verify KB2592687: Security Update for Windows 7 x64  - Remote Desktop Protocol 8.0
#

if (Get-WMIObject -Class Win32_QuickFixEngineering -Filter "HotfixID = 'KB2592687'") {

    Write-Host "Successfully verified that Remote Desktop Protocol 8.0 is installed through 'KB2592687: Security Update for Windows 7 x64'.`n"

}
else {

    Write-Host "Remote Desktop Protocol 8.0 must be installed using 'KB2592687: Security Update for Windows 7 x64'. Please refer to https://www.microsoft.com/download/details.aspx?id=35387 for more details.`n"

}


#
# Verify Group Policy Setting: Enable Remote Desktop Protocol 8.0
#

$TerminalServicesPoliciesRegKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"

$TerminalServicesPolicyErrorMessage = "Remote Desktop Protocol 8.0 must be enabled using Group Policy setting: 'Computer Configuration / Administrative Templates / Windows Components / Remote Desktop Services / Remote Desktop Session Host / Remote Session Environment / Enable Remote Desktop Protocol 8.0'.`n"

# Retrieve the "fServerEnableRDP8" Terminal Services registry value
$fServerEnableRDP8RegValue = Get-ItemProperty -Path $TerminalServicesPoliciesRegKey -Name "fServerEnableRDP8" -ErrorAction SilentlyContinue

# If the "fServerEnableRDP8" registry value does not exist, output an error message
if (-not $fServerEnableRDP8RegValue) {

    Write-Host $TerminalServicesPolicyErrorMessage

} 
# If the "fServerEnableRDP8" registry vaue exists but its data is different than "1", output an error message.
elseif ($fServerEnableRDP8RegValue.fServerEnableRDP8 -ne 1) {

    Write-Host $TerminalServicesPolicyErrorMessage

} else {

    Write-Host "Successfully verified that Remote Desktop Protocol 8.0 is enabled through Group Policy.'`n"
}


#
# Download the Azure Virtual Desktop Agent for Windows 7
#

# Generate the full path to the WVD Agent Installer file
$WVDAgentInstallerFilePath = Join-Path -Path $ScriptWorkingDirectory -ChildPath "Microsoft.RDInfra.WVDAgent.Installer-x64.msi"

Write-Host "Downloading the Azure Virtual Desktop Agent for Windows 7 ...`n"

# Download the Azure Virtual Desktop Agent for Windows 7.
$WVDAgentInstallerDownloadWebResponse = Invoke-WebRequest -UseBasicParsing -Uri $WVDAgentInstallerDownloadUri -OutFile $WVDAgentInstallerFilePath -PassThru -ErrorAction Stop

if ($WVDAgentInstallerDownloadWebResponse.StatusCode -eq 200) {

    Write-Host "Successfully downloaded the Azure Virtual Desktop Agent for Windows 7: $WVDAgentInstallerFilePath.`n"

}
else {

    Write-TerminatingError "Failed to download the Azure Virtual Desktop Agent from $WVDAgentInstallerDownloadUri with status code $($WVDAgentInstallerDownloadWebResponse.StatusCode) and description $($WVDAgentInstallerDownloadWebResponse.StatusDescription).`n"

}


#
# Download the Azure Virtual Desktop Agent Manager for Windows 7
#

# Generate the full path to the WVD Agent Manager Installer file
$WVDAgentManagerInstallerFilePath = Join-Path -Path $ScriptWorkingDirectory -ChildPath "Microsoft.RDInfra.WVDAgentManager.Installer-x64.msi"

Write-Host "Downloading the Azure Virtual Desktop Agent Manager for Windows 7 ...`n"

$WVDAgentManagerInstallerDownloadWebResponse = Invoke-WebRequest -UseBasicParsing -Uri $WVDAgentManagerInstallerDownloadUri -OutFile $WVDAgentManagerInstallerFilePath -PassThru -ErrorAction Stop

if ($WVDAgentManagerInstallerDownloadWebResponse.StatusCode -eq 200) {

    Write-Host "Successfully downloaded the Azure Virtual Desktop Agent Manager for Windows 7: $WVDAgentManagerInstallerFilePath.`n"

}
else {

    Write-TerminatingError "Failed to download the Azure Virtual Desktop Agent Manager from $WVDAgentManagerInstallerDownloadUri with status code $(WVDAgentManagerInstallerDownloadWebResponse.StatusCode) and description $(WVDAgentManagerInstallerDownloadWebResponse.StatusDescription).`n"

}


#
# Install WVD Agent: "Microsoft.RDInfra.WVDAgent.Installer-x64-version.msi"
#

# Generate the full path to the WVD Agent Installer log file
$WVDAgentInstallerLogFilePath = Join-Path -Path $ScriptWorkingDirectory -ChildPath "WVDAgentInstaller.log"

# Define the MSIExec.exe parameters
$WVDAgentInstallerArgumentList = @(
    "/i $WVDAgentInstallerFilePath",
    "/quiet",
    "/passive",
    "/qn",
    "/norestart",
    "/l*v $WVDAgentInstallerLogFilePath",
    "REGISTRATIONTOKEN=$HostPoolRegistrationToken"
)

Write-Host "Installing Azure Virtual Desktop Agent for Windows 7 using $WVDAgentInstallerFilePath ...`n"

# Install the WVD Agent using msiexec.exe and wait for the installer to finish
$WVDAgentInstallerProcessResult = Start-Process -FilePath "msiexec.exe" -ArgumentList $WVDAgentInstallerArgumentList -PassThru -NoNewWindow -Wait

if ($WVDAgentInstallerProcessResult.ExitCode -in $MsiExecSuccessExitCodes) {

    Write-Host "Successfully installed Azure Virtual Desktop Agent for Windows 7.`n"

}
else {

    Write-TerminatingError "Failed to install Azure Virtual Desktop Agent for Windows 7 with error code $($WVDAgentInstallerProcessResult.ExitCode). Please refer to the Windows Installer (MSI) log file for more details: $WVDAgentInstallerLogFilePath.`n"

}


#
# Install WVD Agent Manager: "Microsoft.RDInfra.WVDAgentManager.Installer-x64-version.msi"
#

# Generate the full path to the WVD Agent Manager Installer log file
$WVDAgentManagerInstallerLogFilePath = Join-Path -Path $ScriptWorkingDirectory -ChildPath "WVDAgentManagerInstaller.log"

# Define the MSIExec.exe arguments
$WVDAgentManagerInstallerArgumentList = @(
    "/i $WVDAgentManagerInstallerFilePath",
    "/quiet",
    "/passive",
    "/qn",
    "/norestart",
    "/l*v $WVDAgentManagerInstallerLogFilePath"
)

Write-Host "Installing Azure Virtual Desktop Agent Manager for Windows 7 using $WVDAgentManagerInstallerFilePath ...`n"

# Install the WVD Agent Manager using msiexec.exe
$WVDAgentManagerInstallerProcessResult = Start-Process -FilePath "msiexec.exe" -ArgumentList $WVDAgentManagerInstallerArgumentList -PassThru -NoNewWindow -Wait

if ($WVDAgentManagerInstallerProcessResult.ExitCode -in $MsiExecSuccessExitCodes ) {

    Write-Host "Successfully installed Azure Virtual Desktop Agent Manager for Windows 7.`n"

}
else {

    Write-TerminatingError "Failed to install Azure Virtual Desktop Agent Manager for Windows 7 with error code $($WVDAgentManagerInstallerProcessResult.ExitCode). Please refer to the Windows Installer (MSI) log file for more details: $WVDAgentManagerInstallerLogFilePath.`n"

}


#
# Verify successful registration with the host pool
#

Write-Host "Waiting 15 seconds for the session host registration to complete ...`n"

# Wait 15 seconds for the registration with the host pool to complete
Start-Sleep -Seconds 15

# Registry Key containing Azure Virtual Desktop Agent Settings 
$RDInfraAgentRegKey = "HKLM:\SOFTWARE\Microsoft\RDInfraAgent"

if (Test-Path -Path $RDInfraAgentRegKey) {

    # Expected value: empty string (when the session host is registered)
    $RegistrationToken = Get-ItemProperty -Path $RDInfraAgentRegKey -Name "RegistrationToken" -ErrorAction SilentlyContinue
    
    # Expected value: 1
    $IsRegistered = Get-ItemProperty -Path $RDInfraAgentRegKey -Name "IsRegistered" -ErrorAction SilentlyContinue
    
}

if ([String]::IsNullOrEmpty($RegistrationToken.RegistrationToken) -and ($IsRegistered.IsRegistered -eq 1)) {

    Write-Host "Successfully registered the Session Host $($ENV:COMPUTERNAME) with Azure Virtual Desktop Host Pool. Please note that the health status of the Azure Virtual Desktop Agent and Side-by-Side Stack have not been verified.`n"

}
else {

    Write-TerminatingError "Failed to register the Session Host $($ENV:COMPUTERNAME) with Azure Virtual Desktop Host Pool.`n"

}

Stop-Transcript