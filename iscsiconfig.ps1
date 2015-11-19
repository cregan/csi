function Set-iSCSIConfig { 
$colItems1 = get-wmiobject -class "Win32_NetworkAdapter" -namespace "root\CIMV2" -computername localhost 
$colItems = get-wmiobject -class "Win32_NetworkAdapterconfiguration" -namespace "root\CIMV2" -computername localhost 
foreach ($objitem in $colItems) 
 
{ 
 
# Match the current $objItem with the correct $ColItems1 element. 
 
 
 
 
$objItem1 = $colItems1| where-object{$_.Caption -eq $objItem.Caption} 
if ($objItem.ipenabled -eq "true" -and ($objitem1.netconnectionid -match "iscsi")) { 
 
 
 
 
 
<#Uncheck Register This Connection in DNS#> 
 
 
 
$objitem.SetDynamicDNSRegistration($false) 
<#Disable NETBIOS over TCPIP for iSCSI1#> 
$adapter=(gwmi -query "select * from win32_networkadapter where netconnectionid= 'iscsi1'").deviceid 
([wmi]"\\.\root\cimv2:Win32_NetworkAdapterConfiguration.Index=$adapter").SetTcpipNetbios(2) 
 
 
 
 
 
<#Disable NETBIOS over TCPIP for iSCSI2#> 
 
 
 
$adapter=(gwmi -query "select * from win32_networkadapter where netconnectionid= 'iscsi2'").deviceid 
([wmi]"\\.\root\cimv2:Win32_NetworkAdapterConfiguration.Index=$adapter").SetTcpipNetbios(2) 
<#Here Below we use nvspbind to disable all properties for iSCSI NIC except ipV4#> 
Set-Location "C:\install\nvsp" 
$nic = $objitem1.netconnectionid 
.\nvspbind.exe /d "$nic"ms_tcpip6 
.\nvspbind.exe /d "$nic"ms_server 
.\nvspbind.exe /d "$nic"ms_lltdio 
.\nvspbind.exe /d "$nic"ms_rspndr 
.\nvspbind.exe /d "$nic"ms_msclient 
.\nvspbind.exe /d "$nic"ms_pacer 
 
} 
} 
 
<#Below we set the advanced property #> 
 
 
 
 
$GuidSet = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\services\Tcpip\Parameters\Interfaces\*" | ?{$_.ipaddress -match "192"} | select pschildname,ipaddress 
$path1 = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}\*" |?{$_.NetCfgInstanceId -match $guidset[0].pschildname} | select -ExpandProperty pspath 
$finalpath=$path1.replace("Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\","HKLM:\") 
Set-itemproperty $finalpath -name "*JumboPacket" -value 9014 
Set-itemproperty $finalpath -name "*LsoV2IPv4" -value 0 
Set-itemproperty $finalpath -name "*LsoV2IPv6" -value 0 
Set-itemproperty $finalpath -name "*TCPChecksumOffloadIPv4" -value 0 
Set-itemproperty $finalpath -name "*TCPChecksumOffloadIPv6" -value 0 
Set-itemproperty $finalpath -name "*UDPChecksumOffloadIPv4" -value 0 
Set-itemproperty $finalpath -name "*UDPChecksumOffloadIPv6" -value 0 
Set-itemproperty $finalpath -name "*IPChecksumOffloadIPv4" -value 0 
$path2 = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}\*" |?{$_.NetCfgInstanceId -match $guidset[1].pschildname} | select -ExpandProperty pspath 
$finalpath=$path2.replace("Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\","HKLM:\") 
Set-itemproperty $finalpath -name "*JumboPacket" -value 9014 
Set-itemproperty $finalpath -name "*LsoV2IPv4" -value 0 
Set-itemproperty $finalpath -name "*LsoV2IPv6" -value 0 
Set-itemproperty $finalpath -name "*TCPChecksumOffloadIPv4" -value 0 
Set-itemproperty $finalpath -name "*TCPChecksumOffloadIPv6" -value 0 
Set-itemproperty $finalpath -name "*UDPChecksumOffloadIPv4" -value 0 
Set-itemproperty $finalpath -name "*UDPChecksumOffloadIPv6" -value 0 
Set-itemproperty $finalpath -name "*IPChecksumOffloadIPv4" -value 0 
Netsh int tcp set global RSS=Disabled 
Netsh int tcp set global chimney=Disabled 
Netsh int tcp set global autotuninglevel=Disabled 
Netsh int tcp set global congestionprovider=None 
Netsh int tcp set global ecncapability=Disabled 
Netsh int ip set global taskoffload=disabled 
Netsh int tcp set global timestamps=Disabled 
Netsh int tcp set global netdma=disabled 
 
} 
 
Set-iSCSIConfig 
