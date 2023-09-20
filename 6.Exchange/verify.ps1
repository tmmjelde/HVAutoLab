#We only want True responses to quickly verify the setup has completed.

#Checking floppy setting
(Get-ItemPropertyValue -Path HKLM:\SYSTEM\CurrentControlSet\Services\flpydisk -Name "Start") -eq 4
#Checking feedback notification setting
(Get-ItemPropertyValue -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name "DoNotShowFeedbackNotifications") -eq 0
#Checking telemetry optin
(Get-ItemPropertyValue -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name "DisableTelemetryOptInChangeNotification") -eq 1
#Checking telemetry disallowed
(Get-ItemPropertyValue -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name "AllowTelemetry") -eq 0
#Checking edge first run
(Get-ItemPropertyValue -Path HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge -Name "PreventFirstRunPage") -eq 1
#Checking for network window not popping up
test-path HKLM:\\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff

$Config = Get-Content c:\temp\config.json | convertfrom-json
#Is unattend.xml deleted
!(test-path "c:\Windows\Panther\Unattend.xml")


#Check all features are installed
Get-WindowsFeature $config.Features.Split(",") | select-object Name, Installed

#Check computername is correct
$env:computername

Pause