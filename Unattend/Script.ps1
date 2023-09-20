set-location C:\Users\t\OneDrive\!LabNew\Unattend
$Unattend = [xml](gc .\Autounattend.xml)
$windowsPE = $Unattend.unattend.settings | where {$_.pass -eq 'windowsPE'}

$windowsPE.component | where {$_.name -eq 'Microsoft-Windows-Setup'}
$WindowsSetup= $windowsPE.component | where {$_.name -eq 'Microsoft-Windows-Setup'}
$WindowsSetup.ImageInstall.OSImage.InstallFrom.MetaData.Value
$WindowsSetup.ImageInstall.OSImage.InstallFrom.MetaData.Value = "Windows Server 2012 R2 SERVERDATACENTER"