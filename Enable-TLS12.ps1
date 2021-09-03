#
# Configure WinHttp for TLS 1.2
#

Write-Output "`nConfiguring WinHttp for TLS 1.2.`n"

$WinHttpKeyPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp", "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp")

foreach ($WinHttpKeyPath in $WinHttpKeyPaths) {

    New-Item -Path $WinHttpKeyPath -Force | Out-Null
    Set-ItemProperty -Path $WinHttpKeyPath -Name "DefaultSecureProtocols" -Type DWord -Value 0x800 -Force

}


#
# Enable TLS 1.2
#

Write-Output "`nEnabling TLS 1.2.`n"

$Roles = @("Client", "Server")
foreach ($Role in $Roles) {

    $TLS12KeyPath = Join-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2" -ChildPath $Role
    
    New-Item -Path $TLS12KeyPath -Force | Out-Null
    Set-ItemProperty -Path $TLS12KeyPath -Name "DisabledByDefault" -Type DWord -Value 0 -Force
    Set-ItemProperty -Path $TLS12KeyPath -Name "Enabled" -Type DWord -Value 1 -Force

}


#
# Disable SSH 2.0, SSH 3.0, TLS 1.0, and TLS 1.1
#

Write-Output "`nDisabling SSH 2.0, SSH 3.0, TLS 1.0, and TLS 1.1.`n"

$LegacyProtocols = @("SSL 2.0", "SSL 3.0", "TLS 1.0", "TLS 1.1")
$Roles = @("Client", "Server")

foreach ($LegacyProtocol in $LegacyProtocols) {

    foreach ($Role in $Roles) {
        
        $AllProcotolsKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols"
        $LegacyProtocolKeyPath = Join-Path -Path (Join-Path -Path $AllProcotolsKeyPath -ChildPath $LegacyProtocol) -ChildPath $Role
        
        New-Item -Path $LegacyProtocolKeyPath -Force | Out-Null
        Set-ItemProperty -Path $LegacyProtocolKeyPath -Name "DisabledByDefault" -Type DWord -Value 1 -Force
        Set-ItemProperty -Path $LegacyProtocolKeyPath -Name "Enabled" -Type DWord -Value 0 -Force

    }
}


#
# Configure .Net Framework
#

Write-Output "`nConfiguring .Net Framework 2.0 and .Net Framework 4.0 for TLS 1.2.`n"

$dotNetFrameworkKeyPaths = @("HKLM:\SOFTWARE\Microsoft\.NETFramework", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework")
$dotNetFrameworkVersions = @("v2.0.50727", "v4.0.30319")

foreach ($dotNetFrameworkKeyPath in $dotNetFrameworkKeyPaths) {
       
    foreach ($dotNetFrameworkVersion in $dotNetFrameworkVersions) {
    
        $dotNetFrameworkVersionKeyPath = Join-Path -Path $dotNetFrameworkKeyPath -ChildPath $dotNetFrameworkVersion

        @("SystemDefaultTlsVersions", "SchUseStrongCrypto") | ForEach-Object {Set-ItemProperty -Path $dotNetFrameworkVersionKeyPath -Name $_  -Type DWord -Value 1 -Force}
        
    }
}
