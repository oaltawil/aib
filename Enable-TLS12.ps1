#
# Configure WinHttp for TLS 1.2
#

$WinHttpRegistryKeyPaths = @(
        "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp", 
        "HKLM:SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp"
    )

foreach ($WinHttpRegistryKeyPath in $WinHttpRegistryKeyPaths) {

    New-Item -Path $WinHttpRegistryKeyPath -Force | Out-Null
    Set-ItemProperty -Path $WinHttpRegistryKeyPath -Name "DefaultSecureProtocols" -Type DWord -Value 0x800 -Force

}


#
# Enable TLS 1.2
#

$Roles = @("Client", "Server")
foreach ($Role in $Roles) {

    $TLS12RegistryKeyPath = "HKLM:SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\$Role"
    New-Item -Path $TLS12RegistryKeyPath -Force | Out-Null
    Set-ItemProperty -Path $TLS12RegistryKeyPath -Name "DisabledByDefault" -Type DWord -Value 0 -Force
    Set-ItemProperty -Path $TLS12RegistryKeyPath -Name "Enabled" -Type DWord -Value 1 -Force

}


#
# Disable SSH 2.0, SSH 3.0, TLS 1.0, and TLS 1.1
#

$Protocols = @("SSL 2.0", "SSL 3.0", "TLS 1.0", "TLS 1.1")
$Roles = @("Client", "Server")

foreach ($Protocol in $Protocols) {

    foreach ($Role in $Roles) {
        
        $LegacyProtocolRegistryKeyPath = "HKLM:SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$Protocol\$Role"
        New-Item -Path $LegacyProtocolRegistryKeyPath -Force | Out-Null
        Set-ItemProperty -Path $LegacyProtocolRegistryKeyPath -Name "DisabledByDefault" -Type DWord -Value 1 -Force
        Set-ItemProperty -Path $LegacyProtocolRegistryKeyPath -Name "Enabled" -Type DWord -Value 0 -Force

    }
}


#
# Configure .Net Framework
#

$NETFrameworkVersions = @("v2.0.50727", "v4.0.30319")
$NETFrameworkRegistryValueNames = @("SystemDefaultTlsVersions", "SchUseStrongCrypto")

foreach ($NETFrameworkVersion in $NETFrameworkVersions) {

    foreach ($NETFrameworkRegistryValueName in $NETFrameworkRegistryValueNames) {
        
        Set-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\.NETFramework\$NETFrameworkVersion" -Name $NETFrameworkRegistryValueName -Type DWord -Value 1 -Force
        Set-ItemProperty -Path "HKLM:SOFTWARE\WOW6432Node\Microsoft\.NETFramework\$NETFrameworkVersion" -Name $NETFrameworkRegistryValueName -Type DWord -Value 1 -Force

    }
}

