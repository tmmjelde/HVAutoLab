#This just attempts to find the path this script is located in, so we can find the config.json file.
if ($myInvocation.mycommand.path){
  $mypath = Split-Path -parent $MyInvocation.MyCommand.Path
} else {
  $mypath = (get-location).path
}
#Loading in some extra functions.
#. "$mypath\functions.ps1"

#If you want, you can hardcode this path instead.
$Config = Get-Content -Path $mypath\Config.json | ConvertFrom-Json


$VHDPath = (Get-VMHost).VirtualHardDiskPath
$UnattendLocation = "$mypath\WS2012R2"
$VMName = "WS2012R2.$($Config.DomainName)"

function new-labvm ($vm){
  if (test-path "$UnattendLocation\AutoUnattend.iso"){remove-item "$UnattendLocation\AutoUnattend.iso"}
  get-childitem $UnattendLocation -Exclude *.iso | New-ISOFile -path "$UnattendLocation\AutoUnattend.iso"
  New-VM -Name $vm -MemoryStartupBytes 12GB -Generation 1
  Set-VM $vm -ProcessorCount 8
  Set-VM $vm -AutomaticCheckpointsEnabled 0

  New-VHD -Path $VHDPath\$vm.vhdx -SizeBytes 128GB -Dynamic
  Add-VMHardDiskDrive -VMName $vm -Path $VHDPath\$vm.vhdx

  Add-VMDvdDrive -VMName $vm
  Set-VMDvdDrive -VMName $vm -ControllerLocation 1 -Path "$UnattendLocation\AutoUnattend.iso"
  Set-VMDvdDrive -VMName $vm -ControllerLocation 0 -Path "D:\Source\Windows Server 2012 R2\9600.17050.WINBLUE_REFRESH.140317-1640_X64FRE_SERVER_EVAL_EN-US-IR3_SSS_X64FREE_EN-US_DV9.ISO"
  
  #First time startup IDE will be ignored because there's nothing there, so it will jump to CD. After install we will no longer boot from CD.
  Set-VMBios $VM -StartupOrder @("IDE","CD","LegacyNetworkAdapter","Floppy")
  #Connect to an existing network switch
  Connect-VMNetworkAdapter -VMName $VM -SwitchName $Config.SwitchName
  start-vm $vm
  #Opens console to the newly created VM
  & vmconnect.exe localhost $vm
}

#Found this online. Some genius wrote it. Really helps not having to download and install third party tools.
#Credits to SQLDBAWithABeard - https://github.com/SQLDBAWithABeard/Functions/blob/master/New-IsoFile.ps1
function New-IsoFile 
{  
  <# .Synopsis Creates a new .iso file .Description The New-IsoFile cmdlet creates a new .iso file containing content from chosen folders .Example New-IsoFile "c:\tools","c:Downloads\utils" This command creates a .iso file in $env:temp folder (default location) that contains c:\tools and c:\downloads\utils folders. The folders themselves are included at the root of the .iso image. .Example New-IsoFile -FromClipboard -Verbose Before running this command, select and copy (Ctrl-C) files/folders in Explorer first. .Example dir c:\WinPE | New-IsoFile -Path c:\temp\WinPE.iso -BootFile "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\efisys.bin" -Media DVDPLUSR -Title "WinPE" This command creates a bootable .iso file containing the content from c:\WinPE folder, but the folder itself isn't included. Boot file etfsboot.com can be found in Windows ADK. Refer to IMAPI_MEDIA_PHYSICAL_TYPE enumeration for possible media types: http://msdn.microsoft.com/en-us/library/windows/desktop/aa366217(v=vs.85).aspx .Notes NAME: New-IsoFile AUTHOR: Chris Wu LASTEDIT: 03/23/2016 14:46:50 #> 
   
  [CmdletBinding(DefaultParameterSetName='Source')]Param( 
    [parameter(Position=1,Mandatory=$true,ValueFromPipeline=$true, ParameterSetName='Source')]$Source,  
    [parameter(Position=2)][string]$Path = "$env:temp\$((Get-Date).ToString('yyyyMMdd-HHmmss.ffff')).iso",  
    [ValidateScript({Test-Path -LiteralPath $_ -PathType Leaf})][string]$BootFile = $null, 
    [ValidateSet('CDR','CDRW','DVDRAM','DVDPLUSR','DVDPLUSRW','DVDPLUSR_DUALLAYER','DVDDASHR','DVDDASHRW','DVDDASHR_DUALLAYER','DISK','DVDPLUSRW_DUALLAYER','BDR','BDRE')][string] $Media = 'DVDPLUSRW_DUALLAYER', 
    [string]$Title = (Get-Date).ToString("yyyyMMdd-HHmmss.ffff"),  
    [switch]$Force, 
    [parameter(ParameterSetName='Clipboard')][switch]$FromClipboard 
  ) 
  
  Begin {  
    ($cp = new-object System.CodeDom.Compiler.CompilerParameters).CompilerOptions = '/unsafe' 
    if (!('ISOFile' -as [type])) {  
      Add-Type -CompilerParameters $cp -TypeDefinition @'
public class ISOFile  
{ 
  public unsafe static void Create(string Path, object Stream, int BlockSize, int TotalBlocks)  
  {  
    int bytes = 0;  
    byte[] buf = new byte[BlockSize];  
    var ptr = (System.IntPtr)(&bytes);  
    var o = System.IO.File.OpenWrite(Path);  
    var i = Stream as System.Runtime.InteropServices.ComTypes.IStream;  
   
    if (o != null) { 
      while (TotalBlocks-- > 0) {  
        i.Read(buf, BlockSize, ptr); o.Write(buf, 0, bytes);  
      }  
      o.Flush(); o.Close();  
    } 
  } 
}  
'@  
    } 
   
    if ($BootFile) { 
      if('BDR','BDRE' -contains $Media) { Write-Warning "Bootable image doesn't seem to work with media type $Media" } 
      ($Stream = New-Object -ComObject ADODB.Stream -Property @{Type=1}).Open()  # adFileTypeBinary 
      $Stream.LoadFromFile((Get-Item -LiteralPath $BootFile).Fullname) 
      ($Boot = New-Object -ComObject IMAPI2FS.BootOptions).AssignBootImage($Stream) 
    } 
  
    $MediaType = @('UNKNOWN','CDROM','CDR','CDRW','DVDROM','DVDRAM','DVDPLUSR','DVDPLUSRW','DVDPLUSR_DUALLAYER','DVDDASHR','DVDDASHRW','DVDDASHR_DUALLAYER','DISK','DVDPLUSRW_DUALLAYER','HDDVDROM','HDDVDR','HDDVDRAM','BDROM','BDR','BDRE') 
  
    Write-Verbose -Message "Selected media type is $Media with value $($MediaType.IndexOf($Media))"
    ($Image = New-Object -com IMAPI2FS.MsftFileSystemImage -Property @{VolumeName=$Title}).ChooseImageDefaultsForMediaType($MediaType.IndexOf($Media)) 
   
    if (!($Target = New-Item -Path $Path -ItemType File -Force:$Force -ErrorAction SilentlyContinue)) { Write-Error -Message "Cannot create file $Path. Use -Force parameter to overwrite if the target file already exists."; break } 
  }  
  
  Process { 
    if($FromClipboard) { 
      if($PSVersionTable.PSVersion.Major -lt 5) { Write-Error -Message 'The -FromClipboard parameter is only supported on PowerShell v5 or higher'; break } 
      $Source = Get-Clipboard -Format FileDropList 
    } 
  
    foreach($item in $Source) { 
      if($item -isnot [System.IO.FileInfo] -and $item -isnot [System.IO.DirectoryInfo]) { 
        $item = Get-Item -LiteralPath $item
      } 
  
      if($item) { 
        Write-Verbose -Message "Adding item to the target image: $($item.FullName)"
        try { $Image.Root.AddTree($item.FullName, $true) } catch { Write-Error -Message ($_.Exception.Message.Trim() + ' Try a different media type.') } 
      } 
    } 
  } 
  
  End {  
    if ($Boot) { $Image.BootImageOptions=$Boot }  
    $Result = $Image.CreateResultImage()  
    [ISOFile]::Create($Target.FullName,$Result.ImageStream,$Result.BlockSize,$Result.TotalBlocks) 
    Write-Verbose -Message "Target image ($($Target.FullName)) has been created"
    $Target
  } 
} 

#If there's issues with the unattend.xml file, make changes and run this function to rebuild the iso and reboot the VM.
function retry ($vm) {
  stop-vm -vmname $vm -TurnOff
  if (test-path AutoUnattend_BIOS.iso){remove-item AutoUnattend_BIOS.iso}
  Get-ChildItem autounattend.xml | New-ISOFile -path .\AutoUnattend_BIOS.iso
  start-vm -vmname $vm
}

#This just clears up any remnants of the VM (Works most of the time)
function remove-labvm ($vm) {
  if (get-vm $vm){
    if ((get-vm $vm).state -ne 'off'){stop-vm $vm -TurnOff}
    $Disks = Get-VMHardDiskDrive -VMName $vm
    foreach ($disk in $disks){
      Remove-Item $disk.path
    }
    $Disks | Remove-VMHardDiskDrive
    remove-vm -vmname $vm -Force
  } else {return "no vm found"}
}

new-labvm $VMName