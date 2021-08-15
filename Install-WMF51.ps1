<#
This script installs KB3191566: Windows Management Framework 5.1 for Windows 7 SP1 x64
This script is fully compatible with PowerShell 2.0 on Windows 7 SP1
#>

param (
    [String]
    $ScriptWorkingDirectory
)
#
# A helper function that outputs an error message and stops script execution.
#

function Write-TerminatingError {

    param (
        [String]
        $Message
    )

    Write-Host $Message

    Exit

}


#
# Setup Script Logging 
#

$WusaSuccessExitCodes = @(

    0x00000000 # WU_S_SUCCESS_COMPLETED
    0x00240005 # WU_S_REBOOT_REQUIRED
    0x00240006 # WU_S_ALREADY_INSTALLED

)

if (-not $ScriptWorkingDirectory) {

    # Retrieve the script's parent folder
    $ScriptWorkingDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

    # If the script's working directory could not be determined, use the currently logged on user's Temporary folder instead
    if (-not $ScriptWorkingDirectory) {

        $ScriptWorkingDirectory = $ENV:TEMP

    }
}
elseif (-not (Test-Path -Path $ScriptWorkingDirectory)) {

    # Retrieve the script's parent folder
    $ScriptWorkingDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

    # If the script's working directory could not be determined, use the currently logged on user's Temporary folder instead
    if (-not $ScriptWorkingDirectory) {

        $ScriptWorkingDirectory = $ENV:TEMP

    }
}

#
# Verify Administrative Privileges
#

$whoamiGroups = whoami.exe /groups

$AdministratorsGroup = $whoamiGroups | Where-Object {$_ -match "BUILTIN\\Administrators" -or $_ -match "BUILTIN\\Administrateurs"}

if (($AdministratorsGroup -notmatch "Enabled") -and ($AdministratorsGroup -notmatch "Activ")) {

    Write-TerminatingError "`nAdministrative privileges are required. Please run the script from an elevated context, i.e. Run As Administrator.`n`n"

}


#
# Download Win7AndW2K8R2-KB3191566-x64.zip
#

# The download URL for WMF 5.1
$WMFDownloadUri = "https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win7AndW2K8R2-KB3191566-x64.zip"

# Generate the full download  path for Win7AndW2K8R2-KB3191566-x64.zip
$WMFZipFilePath = Join-Path -Path $ScriptWorkingDirectory -ChildPath "Win7AndW2K8R2-KB3191566-x64.zip"

Write-Host "`nDownloading `"$WMFDownloadUri`" to `"$WMFZipFilePath`"  ...`n"

# Instantiate a WebClient .Net object to use for downloading azcopy.zip
$WebRequest = New-Object -Typename System.Net.WebClient

try {
    # Download FSLogix_App.zip using the WebClient.DownloadFile method
    # Reference: https://docs.microsoft.com/en-us/dotnet/api/system.net.webclient.downloadfile?view=net-5.0
    $WebRequest.DownloadFile($WMFDownloadUri, $WMFZipFilePath)

}
catch [System.Net.WebException] {

    Write-TerminatingError "`nFailed to download WMF 5.1 from `"$WMFDownloadUri`" to `"$WMFZipFilePath`".`n`n"
    

}
catch {
    
    Write-TerminatingError "`nAn unhandled exception occurred while downloading WMF 5.1 from `"$WMFDownloadUri`" to `"$WMFZipFilePath`".`n`n"
    
}


#
# Extract Win7AndW2K8R2-KB3191566-x64.zip
#

# Generate the full path for the extracted FSLogixApps folder
$WMFFolderPath = Join-Path -Path $ScriptWorkingDirectory -ChildPath "Win7AndW2K8R2-KB3191566-x64"

Write-Host "`nExtracting Win7AndW2K8R2-KB3191566-x64.zip to `"$WMFFolderPath`" ...`n"

if (-not (Test-Path -Path $WMFFolderPath)) {

    New-Item -Path $WMFFolderPath -ItemType Directory -Force | Out-Null
}

try {
    # Create a Shell (Windows Explorer) COM Object
    $ShellObject = New-Object -ComObject Shell.Application

    # Retrieve the contents of the azcopy.zip archive
    $WMFZipFileContents = $ShellObject.NameSpace($WMFZipFilePath).Items()
    
    # Create a Shell Folder Object for the FSLogixApps directory
    $WMFFolderObject = $ShellObject.NameSpace($WMFFolderPath)
    
    # Use the Folder.CopyHere() method to extract the contents of the azcopy.zip archive to the "tools" folder overwriting any existing files
    # Reference: https://docs.microsoft.com/en-us/windows/win32/shell/folder-copyhere
    $WMFFolderObject.CopyHere($WMFZipFileContents, 16)

}
catch {

    Write-TerminatingError "`nAn unhandled exception occurred while extracting `"$WMFZipFilePath`" to `"$WMFFolderPath`".`n`n"
    
}


#
# Install Win7AndW2K8R2-KB3191566-x64.msu
#

$WMFScriptFilePath = Get-ChildItem -Path $WMFFolderPath -Filter "Install-WMF5.1.ps1" -Recurse

# Return an error if the Win7AndW2K8R2-KB3191566-x64.msu file could not be found
if (-not (Test-Path -Path $WMFScriptFilePath.FullName)) {

    Write-TerminatingError "`nFailed to find the file Install-WMF5.1.ps1 in the following directory: `"$WMFFolderPath`".`n`n"

}


# Return the full path of the Win7AndW2K8R2-KB3191566-x64.msu file
$MSUFilePath = Get-ChildItem -Path $WMFFolderPath -Filter "Win7AndW2K8R2-KB3191566-x64.msu" -Recurse

# Return an error if the Win7AndW2K8R2-KB3191566-x64.msu file could not be found
if (-not (Test-Path -Path $MSUFilePath.FullName)) {

    Write-TerminatingError "`nFailed to find the file Win7AndW2K8R2-KB3191566-x64.msu in the following directory: `"$WMFFolderPath`".`n`n"

}

# Define the command-line parameters for Win7AndW2K8R2-KB3191566-x64.msu
$WusaArguments = @(
    "`"$($MSUFilePath.FullName)`"",
    "/quiet",
    "/norestart"
)

Write-Host "`nInstalling Windows Management Framework 5.1 using the Windows Update Standalone Installer: Wusa.exe `"$($MSUFilePath.FullName)`" /quiet /norestart ...`n"

# Install the WVD Agent using msiexec.exe and wait for the installer to finish
$WusaExitCode = Start-Process -FilePath wusa.exe -ArgumentList $WusaArguments -PassThru -NoNewWindow -Wait

if ($WusaSuccessExitCodes -contains $WusaExitCode.ExitCode) {

    Write-Host "`nSuccessfully installed WMF 5.1.`n"

}
else {

    Write-TerminatingError "`nFailed to install WMF 5.1 with error code $($WusaExitCode.ExitCode).`n"

}
