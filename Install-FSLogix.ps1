<#
C:\Windows\SysWOW64\ext-ms-win-kernel32-package-current-l1-1-0.DLL
C:\Windows\SysWOW64\api-ms-win-appmodel-runtime-l1-1-1.DLL

#>


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
$ScriptWorkingDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent -ErrorAction SilentlyContinue

# If the script's working directory could not be determined, use the currently logged on user's Temporary folder instead
if (-not $ScriptWorkingDirectory) {

    $ScriptWorkingDirectory = $ENV:TEMP

}

# Generate the name of the Script log file: Install-FSLogix.log
$LogFileName = ($MyInvocation.MyCommand.Name).Replace(".ps1", ".log")

# If the script's file name could not be determined, use the static string "Install-FSLogix.log"
if (-not $LogFileName) {

    $LogFileName = "Install-FSLogix.log"
    
}

# Start a transcript logging all script activity to the Script log file
Start-Transcript -Path (Join-Path -Path $ScriptWorkingDirectory -ChildPath $LogFileName) -Append

#
# Verify Administrative Privileges
#

$whoamiGroups = whoami.exe /groups

$AdministratorsGroup = $whoamiGroups | Where-Object {$_ -match "BUILTIN\\Administrators" -or $_ -match "BUILTIN\\Administrateurs"}

if (($AdministratorsGroup -notmatch "Enabled") -and ($AdministratorsGroup -notmatch "Activ")) {

    Write-TerminatingError "`nAdministrative privileges are required. Please run the script from an elevated context, i.e. Run As Administrator.`n`n"

}


#
# Download FSLogixApps.zip
#

# The download URL for FSLogix Apps
$FSLogixAppsDownloadUri = "https://aka.ms/fslogix/download"

# Generate the full download  path for FSLogixApps.zip
$FSLogixAppsZipFilePath = Join-Path -Path $ScriptWorkingDirectory -ChildPath "FSLogixApps.zip"

Write-Host "`nDownloading FSLogixApps.zip from `"$FSLogixAppsDownloadUri`" to `"$FSLogixAppsZipFilePath`"  ...`n"

# Configure .Net Framework to use TLS 1.2 for this session
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Instantiate a WebClient .Net object to use for downloading azcopy.zip
$WebRequest = New-Object -Typename System.Net.WebClient

try {
    # Download FSLogix_App.zip using the WebClient.DownloadFile method
    # Reference: https://docs.microsoft.com/en-us/dotnet/api/system.net.webclient.downloadfile?view=net-5.0
    $WebRequest.DownloadFile($FSLogixAppsDownloadUri, $FSLogixAppsZipFilePath)

}
catch [System.Net.WebException] {

    Write-TerminatingError "`nFailed to download FSLogix Apps from `"$FSLogixAppsDownloadUri`" to `"$FSLogixAppsZipFilePath`".`n`n"
    

}
catch {
    
    Write-TerminatingError "`nAn unhandled exception occurred while downloading FSLogix Apps from `"$FSLogixAppsDownloadUri`" to `"$FSLogixAppsZipFilePath`".`n`n"
    
}


#
# Extract FSLogixApps.zip
#

# Generate the full path for the extracted FSLogixApps folder
$FSLogixAppsFolderPath = Join-Path -Path $ScriptWorkingDirectory -ChildPath "FSLogixApps"

Write-Host "`nExtracting FSLogixApps.zip to `"$FSLogixAppsFolderPath`" ...`n"

if (-not (Test-Path -Path $FSLogixAppsFolderPath)) {

    New-Item -Path $FSLogixAppsFolderPath -ItemType Directory -Force | Out-Null
}

try {
    # Create a Shell (Windows Explorer) COM Object
    $ShellObject = New-Object -ComObject Shell.Application

    # Retrieve the contents of the azcopy.zip archive
    $FSLogixAppsZipContents = $ShellObject.NameSpace($FSLogixAppsZipFilePath).Items()
    
    # Create a Shell Folder Object for the FSLogixApps directory
    $FSLogixAppsFolderObject = $ShellObject.NameSpace($FSLogixAppsFolderPath)
    
    # Use the Folder.CopyHere() method to extract the contents of the azcopy.zip archive to the "tools" folder overwriting any existing files
    # Reference: https://docs.microsoft.com/en-us/windows/win32/shell/folder-copyhere
    $FSLogixAppsFolderObject.CopyHere($FSLogixAppsZipContents, 16)

}
catch {

    Write-TerminatingError "`nAn unhandled exception occurred while extracting `"$FSLogixAppsZipFilePath`" to `"$FSLogixAppsFolderPath`".`n`n"
    
}


#
# Install FSLogixApps.exe
#

switch ((Get-WmiObject -Class Win32_OperatingSystem).OSArchitecture) {

    "64-bit" {$OSArchitecture = "x64"}

    "32-bit" {$OSArchitecture = "Win32"}

}
# Return the full path of the FSLogixAppsSetup.exe installer file
$FSLogixAppsSetupFilePath = Join-Path -Path (Join-Path -Path (Join-Path -Path $FSLogixAppsFolderPath -ChildPath $OSArchitecture) -ChildPath "Release") -ChildPath "FSLogixAppsSetup.exe"

# Return an error if the FSLogixAppsSetup.exe file could not be found
if (-not(Test-Path -Path $FSLogixAppsSetupFilePath)) {

    Write-TerminatingError "`nFailed to find the file FSLogixAppsSetup.exe in the following directory: `"$FSLogixAppsFolderPath`".`n`n"

}

# Define the command-line parameters for FSLogixAppsSetup.exe
$FSLogixAppsSetupArguments = @(
    "/install",
    "/quiet",
    "/norestart"
)

Write-Host "`nInstalling FSLogix Apps using `"$FSLogixAppsSetupFilePath`" ...`n"

# Install the WVD Agent using msiexec.exe and wait for the installer to finish
$FSLogixAppsSetupExitCode = Start-Process -FilePath $FSLogixAppsSetupFilePath -ArgumentList $FSLogixAppsSetupArguments -PassThru -NoNewWindow -Wait

if ($FSLogixAppsSetupExitCode.ExitCode -in $MsiExecSuccessExitCodes) {

    Write-Host "`nSuccessfully installed FSLogix Apps.`n"

}
else {

    Write-TerminatingError "`nFailed to install FSLogix Apps with error code $($FSLogixAppsSetupExitCode.ExitCode).`n"

}

Stop-Transcript