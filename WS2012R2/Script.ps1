#Get-ItemPropertyValue doesn't work on WS2012R2
    #Disable floppy drive
    REG ADD HKLM\SYSTEM\CurrentControlSet\Services\flpydisk /f /v Start /t REG_DWORD /d 4

#Checking feedback notification setting

    REG ADD HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection /f /v DoNotShowFeedbackNotifications /t REG_DWORD /d 0  

        #Do not show notifications about telemetry changes
        REG ADD HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection /f /v DisableTelemetryOptInChangeNotification /t REG_DWORD /d 1

        #Do not allow telemetry data
        REG ADD HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection /f /v AllowTelemetry /t REG_DWORD /d 0
        #Do not show first run dialog for Edge
        REG ADD HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge /f /v PreventFirstRunPage /t REG_DWORD /d 1
    #Disable network discovery prompt for all users
    reg ADD HKLM\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff /f
}
#Copy the installer for .net framework 3.5
if (!(test-path c:\temp\sxs)){
    new-item -path c:\temp\sxs -ItemType Directory
    Copy-Item -Path E:\sources\sxs\*.* -Destination c:\temp\sxs -recurse -force
}

#Unmount the drives
$Drives = get-wmiobject win32_volume -filter "drivetype=5"
foreach ($drive in $drives){
    if ($drive.label){
        (New-Object -ComObject Shell.Application).Namespace(17).ParseName($drive.Name).InvokeVerb("Eject")
    }
}
#WS2012R2 cannot read this json file for some reason.
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

#
##Joining the domain requires a reboot and some time to apply computer settings.
#if ((systeminfo | findstr /B /C:"Domain") -Like "*WORKGROUP"){
#    if ((systeminfo | findstr /B /C:"Domain") -Like "*WORKGROUP"){
#        $joinCred = New-Object pscredential -ArgumentList ([pscustomobject]@{
#            UserName = "Administrator"
#            Password = (ConvertTo-SecureString -String $Config.SafeModeAdministratorPassword -AsPlainText -Force)[0]
#        })
#        Add-Computer -DomainName $config.DomainNetbiosName -Credential $joinCred -Restart -Force
#    }
#    Write-Host "Join Domain"
#    #Restart-Computer
#}
New-NetFirewallRule -DisplayName "Allow All" -Profile Any -Direction Inbound -Action Allow -Protocol Any -LocalPort Any


Pause
