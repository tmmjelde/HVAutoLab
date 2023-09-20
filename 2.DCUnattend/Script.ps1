if ((Get-ItemPropertyValue -Path HKLM:\SYSTEM\CurrentControlSet\Services\flpydisk -Name "Start") -ne 4){
    #Disable floppy drive
    REG ADD HKLM\SYSTEM\CurrentControlSet\Services\flpydisk /f /v Start /t REG_DWORD /d 4
}
#Checking feedback notification setting
if (!(Get-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name "DoNotShowFeedbackNotifications" -ErrorAction SilentlyContinue)){
        REG ADD HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection /f /v DoNotShowFeedbackNotifications /t REG_DWORD /d 0  
}

#Checking telemetry optin
if (!(Get-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name "DisableTelemetryOptInChangeNotification" -ErrorAction SilentlyContinue)){
        #Do not show notifications about telemetry changes
        REG ADD HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection /f /v DisableTelemetryOptInChangeNotification /t REG_DWORD /d 1
}
#Checking telemetry disallowed
if (!(Get-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name "AllowTelemetry" -ErrorAction SilentlyContinue)){
        #Do not allow telemetry data
        REG ADD HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection /f /v AllowTelemetry /t REG_DWORD /d 0
}
#Checking edge first run
if (!(Get-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge -Name "PreventFirstRunPage" -ErrorAction SilentlyContinue)){
        #Do not show first run dialog for Edge
        REG ADD HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge /f /v PreventFirstRunPage /t REG_DWORD /d 1
}
if (!(test-path HKLM:\\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff)){
    #Disable network discovery prompt for all users
    reg ADD HKLM\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff /f
}
#Copy the installer for .net framework 3.5
if (!(test-path c:\temp\sxs)){
    new-item -path c:\temp\sxs -ItemType Directory
    Copy-Item -Path E:\sources\sxs\*.* -Destination c:\temp\sxs
}

#Unmount the drives
$Drives = get-wmiobject win32_volume -filter "drivetype=5"
foreach ($drive in $drives){
    if ($drive.label){
        (New-Object -ComObject Shell.Application).Namespace(17).ParseName($drive.Name).InvokeVerb("Eject")
    }
}

#Reading config
$Config = Get-Content c:\temp\config.json | convertfrom-json

#Rename computer
if ($env:computername -ne $config.computername){
    Rename-Computer -NewName $Config.ComputerName
    #We expect a reboot to be required after changing the computer name. So to continue, we add a simple auto login and reboot.
    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty $RegPath "AutoAdminLogon" -Value "1" -type String 
    Set-ItemProperty $RegPath "DefaultUsername" -Value "Administrator" -type String 
    Set-ItemProperty $RegPath "DefaultPassword" -Value $Config.SafeModeAdministratorPassword -type String
    $RegROPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    Set-ItemProperty $RegROPath "(Default)" -Value "C:\Temp\Script.cmd" -type String
    Restart-Computer
}

#Add WindowsFeatures
foreach ($Feature in Get-WindowsFeature $config.features.split(",") | Where-Object {$_.InstallState -ne 'Installed'}){
    Add-WindowsFeature $Feature 
}


#Creating the domain requires a reboot and some time to apply computer settings.
if (!(Test-Path "c:\Windows\NTDS")){
    #Reboot will be required after setting up a domain. We want to rerun the script after this.
    $RegROPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    Set-ItemProperty $RegROPath "(Default)" -Value "C:\Temp\Script.cmd" -type String
    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty $RegPath "AutoAdminLogon" -Value "1" -type String 
    Set-ItemProperty $RegPath "DefaultUsername" -Value "Administrator" -type String 
    Set-ItemProperty $RegPath "DefaultDomainName" -Value $Config.DomainNetbiosName -type String 
    Set-ItemProperty $RegPath "DefaultPassword" -Value $Config.SafeModeAdministratorPassword -type String


    $Secure_String_Pwd = ConvertTo-SecureString $Config.SafeModeAdministratorPassword -AsPlainText -Force
    Install-ADDSForest `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "WinThreshold" `
    -DomainName $Config.DomainName `
    -DomainNetbiosName $Config.DomainNetbiosName `
    -ForestMode "WinThreshold" `
    -InstallDns:$true `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion:$false `
    -SysvolPath "C:\Windows\SYSVOL" `
    -Force:$true -SafeModeAdministratorPassword $Secure_String_Pwd
    Restart-Computer
}

#Wait for DHCP Service to start
if ((get-service dhcpserver).Status -ne 'Running'){
    start-service DHCPServer
}
#If the DHCP server isn't configured yet, do so.
if ((Get-ItemPropertyValue -Path HKLM:\Software\Microsoft\ServerManager\Roles\12 -Name ConfigurationState) -eq '1'){
    Add-DHCPServerSecurityGroup
    Add-DhcpServerInDC
    restart-service dhcpserver
}
#Tell server manager that DHCP is now configured.
if ((get-adgroup "DHCP Administrators") -and (get-dhcpserverindc)){
    Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2
}
#Set static IP
$IPConfig = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias Ethernet
if ($ipconfig.IPAddress -ne $Config.IPAddress){
    New-NetIPAddress -InterfaceIndex $IPConfig.InterfaceIndex -IPAddress $Config.IPAddress -AddressFamily IPv4 -PrefixLength $config.PrefixLength -DefaultGateway $Config.DefaultGateway
    Set-NetIPAddress -InterfaceIndex $IPConfig.InterfaceIndex -IPAddress $Config.IPAddress -PrefixLength $Config.PrefixLength 
}
#Set DNS Server
if (!((Get-DnsClientServerAddress -InterfaceIndex $IPConfig.InterfaceIndex -AddressFamily IPv4).ServerAddresses)){
    Set-DnsClientServerAddress -InterfaceIndex $IPConfig.InterfaceIndex -ServerAddresses "127.0.0.1"
}
#Configure IP Forwarders
if ((Get-DnsServerForwarder).IPAddress.IPAddressToString -eq '1.1.1.1'){
    Set-DnsServerForwarder -IPAddress 1.1.1.1
}
#Create DHCP Scope
if (!(Get-DhcpServerv4Scope)){
    Add-DhcpServerv4Scope -Name "Lab Network" -StartRange $config.defaultgateway.replace(".254",".1") -EndRange $config.defaultgateway -SubnetMask 255.255.255.0
    Set-DhcpServerv4OptionValue -ScopeId $config.defaultgateway.replace(".254",".0") -DnsServer $Config.IPAddress -DnsDomain $config.DomainName -Router $Config.DefaultGateway
}
#Enable DHCP Scope
#Configure DNS Forwarder

#Create AD Users, Groups, etc?
#Create Group Policy Objects?


#Remove autologon settings
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty $RegPath "AutoAdminLogon" -Value "" -type String 
Set-ItemProperty $RegPath "DefaultPassword" -Value "" -type String
#Clean up local files

#This script should contain all tests to verify the DC has been created successfully.
& C:\temp\verify.ps1
