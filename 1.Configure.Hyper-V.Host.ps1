#This just attempts to find the path this script is located in, so we can find the config.json file.
if ($myInvocation.mycommand.path){
    $mypath = Split-Path -parent $MyInvocation.MyCommand.Path
} else {
    $mypath = (get-location).path
}
#If you want, you can hardcode this path instead.
$Config = Get-Content -Path $mypath\Config.json | ConvertFrom-Json


#Make sure Hyper-V is installed.
if ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V).State -ne 'Enabled'){
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
}
#Hyper-V is NOT compatible with other virtualization software like VMware Workstation etc. So uninstall those and reboot.
#Not going to check CPU virtualization is enabled. Do this in UEFI/BIOS.
#Not going to check if you have Windows Pro/Enterprise. Hyper-V does not work in Windows Home edition OS.
$VMHost = Get-VMHost
if ($VMHost.VirtualHardDiskPath -ne 'D:\VMs'){
    Set-VMHost -VirtualHardDiskPath 'D:\VMs'
}
if ($VMHost.VirtualMachinePath -ne 'D:\VMs'){
    Set-VMHost -VirtualMachinePath 'D:\VMs'
}

<#
    The default internal switch would work for our purposes, but it includes a builtin DHCP Server assigning IP addresses to clients.
    Since we want our Domain Controller to serve as DHCP Server, we need to create a new interface.
#>



$SwitchType = "Internal"

if (!(Get-VMSwitch -Name $Config.SwitchName -SwitchType $SwitchType)){
    New-VMSwitch -Name $Config.SwitchName -SwitchType $SwitchType
}

$EthernetAdapter = get-netadapter -Name "vEthernet ($($Config.SwitchName))"

#This is going to be the network adressing.
if (!(Get-NetIPAddress -IPAddress $Config.DFGW -PrefixLength $Config.PrefixLength -InterfaceIndex $EthernetAdapter.ifIndex)){
    New-NetIPAddress -IPAddress $Config.DFGW -PrefixLength $Config.PrefixLength -InterfaceIndex $EthernetAdapter.ifIndex  
}

#This is what allows the VM's on the internal network to communicate with the outside world (through NAT, because it's a LAB I don't want full routing.)
if (!(Get-NetNat -Name $Config.SwitchName | where {$_.InternalIPInterfaceAddressPrefix -eq "$($Config.Network)/$($Config.PrefixLength)"})){
    New-NetNat -Name $Config.SwitchName -InternalIPInterfaceAddressPrefix "$($Config.Network)/$($Config.PrefixLength)"
}

#If traffic doesn't work from VM's internal network to your dfgw/network/internet then ensure a firewall rule on the host is in place that allows traffic from the lab network.
if (!(Get-NetFirewallRule -DisplayName AllowTrafficFromLabOut)){
    New-NetFirewallRule -DisplayName AllowTrafficFromLabOut -Enabled True -Direction Inbound -Action Allow -RemoteAddress 10.69.42.0/24
}
