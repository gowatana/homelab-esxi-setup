$hv_name = $args[0]

$hv = Get-VMHost -Name $hv_name

if ($hv.ConnectionState -ne "Maintenance") {
    "Not in Maintenance Mode."
    exit 1 
}

"Get ESXi Short Name"
$hv_short_name = $hv.Name -replace "\..*",""
$hv_short_name

"Get ESXi IP 4th Octet Number"
$hv_ip_4th_octet = [int]($hv_short_name.Split("-")[2]) + 200
$hv_ip_4th_octet

"Set Domain"
$hv | Get-VMHostNetwork | Set-VMHostNetwork -DomainName "go-lab.jp"

"Disable Core Dump Warning"
$hv | Get-AdvancedSetting -Name UserVars.SuppressCoredumpWarning | Set-AdvancedSetting -Value 1 -Confirm:$false

"Disable Shell Warning"
$hv | Get-AdvancedSetting -Name UserVars.SuppressShellWarning | Set-AdvancedSetting -Value 1 -Confirm:$false

"Disable KB55636 Warning"
$hv | Get-AdvancedSetting -Name UserVars.SuppressHyperthreadWarning | Set-AdvancedSetting -Value 1 -Confirm:$false

"Set NTP Servers"
$hv | Add-VMHostNtpServer -NtpServer 192.168.1.101,192.168.1.102
$hv | Get-VMHostService | where {$_.key -eq "ntpd"} | Set-VMHostService -Policy On
$hv | Get-VMHostService | where {$_.key -eq "ntpd"} | Start-VMHostService

"Start SSH"
$hv | Get-VMHostService | where {$_.key -eq "TSM-SSH"} | Set-VMHostService -Policy on
$hv | Get-VMHostService | where {$_.key -eq "TSM-SSH"} | Start-VMHostService

"Start ESxi Shell"
$hv | Get-VMHostService | where {$_.key -eq "TSM"} | Set-VMHostService -Policy on
$hv | Get-VMHostService | where {$_.key -eq "TSM"} | Start-VMHostService

$pnic = $hv | Get-VMHostNetworkAdapter -Physical -Name vmnic0
$vmk_port = $hv | Get-VMHostNetworkAdapter -VMKernel -Name vmk0
$vds = Get-VDSwitch -Name "infra-vds-01"
$dvpg = Get-VDPortgroup -VDSwitch $vds -Name "dvpg-0000-mgmt"

Add-VDSwitchVMHost -VDSwitch $vds -VMHost $hv
Add-VDSwitchPhysicalNetworkAdapter -DistributedSwitch $vds -VMHostPhysicalNic $pnic -VMHostVirtualNic $vmk_port -VirtualNicPortgroup $dvpg -Confirm:$false

$dvpg_nfs = Get-VDPortgroup -VDSwitch $vds -Name "dvpg-0051-nfs"
$dvpg_vsan = Get-VDPortgroup -VDSwitch $vds -Name "dvpg-0052-vsan"

"Add vmk1 - NFS"
$vmk1_ip = "192.168.51." + $hv_ip_4th_octet
$vmk1_ip
$hv | New-VMHostNetworkAdapter -VirtualSwitch $vds -PortGroup $dvpg_nfs `
-IP $vmk1_ip   -SubnetMask "255.255.255.0"

"Add vmk2 - vSAN"
$vmk2_ip = "192.168.52." + $hv_ip_4th_octet
$vmk2_ip 
$hv | New-VMHostNetworkAdapter -VirtualSwitch $vds -PortGroup $dvpg_vsan `
-IP $vmk2_ip -SubnetMask "255.255.255.0" -VsanTrafficEnabled:$true

"Enable vMotion"
$hv | Get-VMHostNetworkAdapter -Name vmk0 | Set-VMHostNetworkAdapter -VMotionEnabled:$true -Confirm:$false

"Mount NFS Datastore"
$hv | New-Datastore -Name "ds-nfs-repo-01" -Nfs -NfsHost "192.168.51.105" -Path "/nfs/fs01"

"Set Local Syslog Directory"
$hv_logdir = "[ds-nfs-repo-01] logs/$hv_short_name"
$hv_logdir
$hv | Get-AdvancedSetting -Name Syslog.global.logDir | Set-AdvancedSetting -Value $hv_logdir -Confirm:$false
