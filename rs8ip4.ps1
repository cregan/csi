# Powershell iSCSI MPIO Connections

# Refresh iSCSI Portals
Function Refresh-Targets {
  $(Get-WmiObject -Namespace root/wmi MSiSCSIInitiator_MethodClass).RefreshTargetList() | Out-Null
}

# Get Available Target IQNs and portal IPs
Function Get-AvailableTargets {
  $TargetClass = Get-WmiObject -Namespace root\wmi MSiSCSIInitiator_TargetClass
  foreach ($Target in $TargetClass) {
    foreach ($Portal in $Target.PortalGroups.Get(0).Portals) {
      New-Object PSObject -Property  @{
        Target = $Target.TargetName
		TargetNice = $Target.TargetName -replace "^[^:]+:(.+)-\w+\.\w+\.\w+", "`$1"
		Address = $Portal.Address
	    Port = $Portal.Port
	  }
    }
  }
}

# Get list of established sessions and their respective IPs and ports
Function Get-EstablishedSessions {
  $SessionClass = Get-WmiObject -Namespace root\wmi MSiSCSIInitiator_SessionClass
  foreach ($Session in $SessionClass) {
    if ($Session -eq $null) {
      continue;
    }
    $SessionConnectionInformation = $Session.GetPropertyValue("ConnectionInformation").Get(0)
    New-Object PSObject -Property @{
	  Target = $Session.TargetName
	  TargetNice = $Session.TargetName -replace "^[^:]+:(.+)-\w+\.\w+\.\w+", "`$1"
      Address = $SessionConnectionInformation.TargetAddress
      Port = $SessionConnectionInformation.TargetPort
	  InitiatorAddress = $SessionConnectionInformation.InitiatorAddress
	  Devices = $Session.Devices
    }
  }
}

# Get list of Persistent Logins
Function Get-PersistentLogins {
  $PersistentLoginClass = Get-WmiObject -Namespace root\wmi MSiSCSIInitiator_PersistentLoginClass
  foreach ($PersistentLogin in $PersistentLoginClass) {
    if ($PersistentLogin -eq $null) {
      continue;
    }
	New-Object PSObject -Property @{
	  Target = $PersistentLogin.TargetName
	  TargetNice = $PersistentLogin.TargetName -replace "^[^:]+:(.+)-\w+\.\w+\.\w+", "`$1"	  
      Initiator = $PersistentLogin.InitiatorInstance
      InitiatorPort = $PersistentLogin.InitiatorPortNumber
      TargetIP = $PersistentLogin.TargetPortal.Address
	  TargetPort = $PersistentLogin.TargetPortal.Port
	}
  }
}

# Compare two IPs with a subnet mask and return true if they are in the same subnet
Function Compare-Subnet ([string]$ip1, [string]$ip2, [string]$subnet) {
  $octets1 = $ip1 -split '\.'
  $octets2 = $ip2 -split '\.'
  $mask = $subnet -split '\.'
  
  for ($i = 0; $i -lt 4; $i++) {
    $bandip1 += $octets1[$i] -band $mask[$i]
    $bandip2 += $octets2[$i] -band $mask[$i]
  }
  $bandip1 -eq $bandip2
}

# Return all the IPs on the server
Function Get-HostIPs {
  $IPconfigset = Get-WmiObject Win32_NetworkAdapterConfiguration -Namespace "root\CIMv2" | ? {$_.IPEnabled}
  foreach ($ip in $IPconfigset) {
    New-Object PSObject -Property @{
      IPAddress = $ip.IPAddress[0]
	  Subnet = $ip.IPSubnet[0]
    }
  }
}

# Return the iSCSI port and IP mappings
Function Get-iSCSIPorts {
  $InitiatorInfo = Get-WmiObject -namespace root\wmi MSiSCSI_PortalInfoClass
  foreach ($Initiator in $InitiatorInfo) {  
    foreach ($Port in $Initiator.PortalInformation) {
	  New-Object -TypeName PSObject -Property @{
	    "InitiatorName" = $Initiator.InstanceName;
		"Port" = $Port.Port;
		"IPAddress" = ([Net.IPAddress]$Port.IpAddr.IPV4Address).IPAddressToString
      }
    }
  }
}

# Add proper MPIO connection by IQN
Function Connect-toIQN ([string]$iqn) {
  $PersistentLogins = 0
  $NewConnections = 0
  foreach ($Login in Get-PersistentLogins | ? {$_.Target -match $iqn}) {
	if ($Login.Target -eq $null) {
      continue
    }
    iscsicli removepersistenttarget $Login.Initiator $Login.Target $Login.InitiatorPort $Login.TargetIP $Login.TargetPort | Out-Null
  }
  foreach ($Target in Get-AvailableTargets | ? {$_.Target -match $iqn}) {
    foreach ($ip in Get-HostIPs) {
      if (Compare-Subnet $Target.Address $ip.IPaddress $ip.Subnet) {
        $iSCSIPort = Get-iSCSIPorts | ? {$_.IPAddress -eq $ip.IPAddress}
	    if (Get-EstablishedSessions | ? {$_.Target -eq $Target.Target -and $_.Address -eq $Target.Address -and $_.InitiatorAddress -eq $ip.IPAddress}) {
		  $PersistentLogins++
	      iscsicli persistentlogintarget $Target.Target T $Target.Address $Target.Port $iSCSIPort.InitiatorName $iSCSIPort.port * 0x2 * * * * * * * * * 0 | Out-Null
        }
        else {
    	  iscsicli logintarget $Target.Target T $Target.Address $Target.Port $iSCSIPort.InitiatorName $iSCSIPort.port * 0x2 * * * * * * * * * 0 | Out-Null
		  $NewConnections++
	      iscsicli persistentlogintarget $Target.Target T $Target.Address $Target.Port $iSCSIPort.InitiatorName $iSCSIPort.port * 0x2 * * * * * * * * * 0 | Out-Null
		  $PersistentLogins++
        }
	  }
    }
  }
  New-Object PSObject -Property @{
    NewConnections = $NewConnections
	PersistentLogins = $PersistentLogins
  }
}

# Remove all Nimble persistant logins
foreach ($Login in Get-PersistentLogins | ? {$_.Target -match "com.rs8ip4"}) {
  if ($Login.Target -eq $null) {
    continue
  }
  iscsicli removepersistenttarget $Login.Initiator $Login.Target $Login.InitiatorPort $Login.TargetIP $Login.TargetPort | Out-Null
}

# Find available Nimble targets
Refresh-Targets
$NimbleTargets = Get-AvailableTargets | ? {$_.Target -notmatch "com.nimblestorage:control-"} | ? {$_.Target -match "com.rs8ip4"} | Sort -Unique Target

Write-Host "Connecting to : " 
$NimbleTargets | Format-Table -HideTableHeaders TargetNice

# Loop through each Nimble target and host IP and validate connections. If any are missing, execute iscsicli to connect and make persistent 
foreach ($Target in $NimbleTargets) {
  $Result = Connect-toIQN $Target.Target
  Write-Host $Target.TargetNice "has" $Result.PersistentLogins "connections -" $Result.NewConnections "new connections"
}
