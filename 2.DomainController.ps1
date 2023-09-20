#This is the folder I have all these files in. Helps if I run a shortcut to the script or launch it from a different folder.
#Change to whatever folder you have.
set-location "C:\Users\thomjel\OneDrive\!LabNew"
#This just attempts to find the path this script is located in, so we can find the config.json file.
if ($myInvocation.mycommand.path){
  $mypath = Split-Path -parent $MyInvocation.MyCommand.Path
} else {
  $mypath = (get-location).path
}
#Loading in some extra functions.
. "$mypath\functions.ps1"

#If you want, you can hardcode this path instead.
$Config = Get-Content -Path $mypath\Config.json | ConvertFrom-Json
#Go here to change your guest configuration
$UnattendFolder = "$mypath\2.DCUnattend"

$ClientConfig =  Get-Content -Path $UnattendFolder\Config.json | ConvertFrom-Json


#Download your ISO files into $config.isofolder and rename to your liking
$config.isofolder
$ISOs = @{}
$ISOFiles = get-childitem $config.isofolder -filter *.iso
foreach ($iso in $isofiles){
  $ISOs.add($iso.name, $iso.fullname)
}
$ISO = $isos."Windows Server 2022.iso"

$VMName = "$($ClientConfig.ComputerName).$($Config.DomainName)"

new-labvm -Name $VMName -UnattendFolder $UnattendFolder -IsoFile $ISO

#Set static IP
#Create DHCP Scope
