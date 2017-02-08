<#	.Description
	Pester tests for Set-XIO* cmdlets for XtremIO.Utils PowerShell module.  Expects that:
	0) XtremIO.Utils module is already loaded (but, will try to load it if not)
	1) a connection to at least one XMS is in place (but, will prompt for XMS to which to connect if not)
#>

## initialize things, preparing for tests
. $PSScriptRoot\XtremIO.Utils.TestingInit.ps1

## string to append (including a GUID) to all objects renamed, to avoid any naming conflicts
$strNameToAppend = "_itemNewName_{0}" -f [System.Guid]::NewGuid().Guid.Replace("-","")
Write-Verbose -Verbose "Testing of Set-XIO* cmdlets involves creating new XIO objects whose properties to set. After the Set-XIO* testing, these newly created, temporary XIO objects will be removed. But, to ensure that only the temporary objects are being removed, the Remove-XIO* calls all prompt for confirmation. This breaks fully automated testing, but is kept in place for now to keep the consumer's comfort level on high."
Write-Verbose -Verbose "Suffix used for new objects for this test:  $strNameToAppend"
## bogus OUI for making sure that the addresses of the intiators created here do not conflict with any real-world addresses
$strInitiatorAddrPrefix = "EE:EE:EE"
## random hex value to use for four hex-pairs in the port addresses, to avoid address conflicts if testing multiple times without removing newly created test objects (with particular port addresses)
$strInitiatorRandomEightHexChar = "{0:x}" -f (Get-Random -Maximum ([Int64]([System.Math]::pow(16,8) - 1)))
$strInitiatorRandomEightHexChar_ColonJoined = ($strInitiatorRandomEightHexChar -split "(\w{2})" | Where-Object {$_ -ne ""}) -join ":"
## hashtable to keep the variables that hold the newly created objects, so that these objects can be removed from the XMS later; making it a global variable, so that consumer has it for <anything they desire> after testing
$global:hshXioObjsToRemove = [ordered]@{}
$hshCommonParamsForNewObj = @{ComputerName =  $strXmsComputerName}

Write-Verbose -Verbose "Getting current counts of each object type of interest, for comparison to counts after testing"
## the types of objects that will get created as target objects on which to then test Set-XIO* cmdlets
$arrTypesToCount = Write-Output ConsistencyGroup Initiator InitiatorGroup InitiatorGroupFolder SnapshotScheduler Tag UserAccount Volume VolumeFolder
## all of the Set-XIO* cmdlets' target objects:
# AlertDefinition ConsistencyGroup EmailNotifier Initiator InitiatorGroup InitiatorGroupFolder LdapConfig SnapshotScheduler SnapshotSet SnmpNotifier SyslogNotifier Tag Target UserAccount Volume VolumeFolder
$arrTypesToCount | Foreach-Object -Begin {$hshTypeCounts_before = @{}} -Process {$hshTypeCounts_before[$_] = Invoke-Command -ScriptBlock {(& "Get-XIO$_" | Measure-Object).Count}}

## still need to generalize these, and to capture the original state of objects, so as to be able to set them back to original state
<#
# Set-XIOItemInfo -Name /testFolder -ItemType volume-folder -SpecForSetItem ($hshTmpSpecForNewVolFolderName | ConvertTo-Json) -Cluster $strClusterNameToUse
# Set-XIOItemInfo -SpecForSetItem ($hshTmpSpecForNewVolFolderName | ConvertTo-Json) -URI https://$strXmsComputerName/api/json/types/volume-folders/10
# Set-XIOItemInfo -SpecForSetItem ($hshTmpSpecForNewVolFolderName | ConvertTo-Json) -XIOItemInfoObj (Get-XIOVolumeFolder /testFolder)
Get-XIOVolumeFolder /testFolder | Set-XIOItemInfo -SpecForSetItem ($hshTmpSpecForNewVolFolderName | ConvertTo-Json)
Get-XIOAlertDefinition alert_def_module_inactive | Set-XIOAlertDefinition -Enable
Get-XIOAlertDefinition alert_def_module_inactive | Set-XIOAlertDefinition -Severity Major -ClearanceMode Ack_Required -SendToCallHome:$false
Set-XIOConsistencyGroup -ConsistencyGroup (Get-XIOConsistencyGroup myConsistencyGroup0) -Name newConsistencyGroupName0
Get-XIOConsistencyGroup -Name myConsistencyGroup0 -Cluster $strClusterNameToUse -ComputerName $strXmsComputerName | Set-XIOConsistencyGroup -Name newConsistencyGroupName0
Get-XIOEmailNotifier | Set-XIOEmailNotifier -Sender myxms.dom.com -Recipient me@dom.com,someoneelse@dom.com
Get-XIOEmailNotifier | Set-XIOEmailNotifier -CompanyName MyCompany -MailRelayServer mysmtp.dom.com
Get-XIOEmailNotifier | Set-XIOEmailNotifier -ProxyServer myproxy.dom.com -ProxyServerPort 10101 -ProxyCredential (Get-Credential dom\myProxyUser) -Enable:$false
Set-XIOInitiator -Initiator (Get-XIOInitiator myInitiator0) -Name newInitiatorName0 -OperatingSystem ESX
Get-XIOInitiator -Name myInitiator0 -Cluster $strClusterNameToUse -ComputerName $strXmsComputerName | Set-XIOInitiator -Name newInitiatorName0 -PortAddress 10:00:00:00:00:00:00:54
Set-XIOInitiatorGroup -InitiatorGroup (Get-XIOInitiatorGroup myInitiatorGroup0) -Name newInitiatorGroupName0
Get-XIOInitiatorGroup -Name myInitiatorGroup0 -Cluster $strClusterNameToUse -ComputerName $strXmsComputerName | Set-XIOInitiatorGroup -Name newInitiatorGroupName0
Set-XIOInitiatorGroupFolder -InitiatorGroupFolder (Get-XIOInitiatorGroupFolder /myIgFolder) -Caption myIgFolder_renamed
Get-XIOInitiatorGroupFolder /myIgFolder | Set-XIOInitiatorGroupFolder -Caption myIgFolder_renamed
Get-XIOLdapConfig | Where-Object {$_.SearchBaseDN -eq "DC=DOM,DC=COM"} | Set-XIOLdapConfig -RoleMapping "read_only:cn=grp0,dc=dom,dc=com","configuration:CN=user0,DC=dom.com"
Get-XIOLdapConfig | Where-Object {$_.SearchBaseDN -eq "DC=DOM,DC=COM"} | Set-XIOLdapConfig -BindDN "cn=mybinder,dc=dom,dc=com" -BindSecureStringPassword (Read-Host -AsSecureString -Prompt "Enter some password") -SearchBaseDN "OU=tiptop,DC=DOM,DC=COM" -SearchFilter "sAMAccountName={username}" -LdapServerURL ldaps://prim.dom.com,ldaps://sec.dom.com -UserToDnRule "dom\{username}" -CacheExpire 8 -Timeout 30 -RoleMapping "admin:cn=grp0,dc=dom,dc=com","admin:cn=grp2,dc=dom,dc=com"
Set-XIOSnapshotScheduler -SnapshotScheduler (Get-XIOSnapshotScheduler mySnapshotScheduler0) -Suffix someSuffix0 -SnapshotRetentionCount 20
Get-XIOSnapshotScheduler -Name mySnapshotScheduler0 | Set-XIOSnapshotScheduler -SnapshotRetentionDuration (New-TimeSpan -Days (365*3)) -SnapshotType Regular
Get-XIOSnapshotScheduler -Name mySnapshotScheduler0 | Set-XIOSnapshotScheduler -Interval (New-TimeSpan -Hours 54 -Minutes 21)
Get-XIOSnapshotScheduler -Name mySnapshotScheduler0 | Set-XIOSnapshotScheduler -ExplicitDay Everyday -ExplicitTimeOfDay (Get-Date 2am) -RelatedObject (Get-XIOConsistencyGroup -Name myConsistencyGrp0)
Get-XIOSnapshotScheduler -Name mySnapshotScheduler0 -Cluster $strClusterNameToUse -ComputerName $strXmsComputerName | Set-XIOSnapshotScheduler -Enable:$false
Set-XIOSnapshotSet -SnapshotSet (Get-XIOSnapshotSet mySnapshotSet0) -Name newSnapsetName0
Get-XIOSnapshotSet -Name mySnapshotSet0 -Cluster $strClusterNameToUse -ComputerName $strXmsComputerName | Set-XIOSnapshotSet -Name newSnapsetName0
Get-XIOSnmpNotifier | Set-XIOSnmpNotifier -Enable:$false
Get-XIOSnmpNotifier | Set-XIOSnmpNotifier -PrivacyKey (Read-Host -AsSecureString "priv key") -SnmpVersion v3 -AuthenticationKey (Read-Host -AsSecureString "auth key") -PrivacyProtocol DES -AuthenticationProtocol MD5 -UserName admin2 -Recipient testdest0.dom.com,testdest1.dom.comw
Set-XIOSyslogNotifier -SyslogNotifier (Get-XIOSyslogNotifier) -Enable:$false
Get-XIOSyslogNotifier | Set-XIOSyslogNotifier -Enable -Target syslog0.dom.com,syslog1.dom.com:515
Set-XIOTag -Tag (Get-XIOTag /InitiatorGroup/myTag) -Caption myTag_renamed
Get-XIOTag -Name /InitiatorGroup/myTag | Set-XIOTag -Caption myTag_renamed
Set-XIOTarget -Target (Get-XIOTarget X1-SC2-iscsi1) -MTU 9000
Get-XIOTarget -Name X1-SC2-iscsi1 -Cluster $strClusterNameToUse -ComputerName $strXmsComputerName | Set-XIOTarget -MTU 1500
Get-XIOUserAccount -Name someUser0 | Set-XIOUserAccount -UserName someUser0_renamed -SecureStringPassword (Read-Host -AsSecureString)
Set-XIOUserAccount -UserAccount (Get-XIOUserAccount someUser0) -InactivityTimeout 0 -Role read_only
Set-XIOVolume -Volume (Get-XIOVolume myVolume) -Name myVolume_renamed
Get-XIOSnapshot myVolume.snapshot0 | Set-XIOVolume -Name myVolume.snapshot0_old
Get-XIOVolume myVolume0 | Set-XIOVolume -SizeTB 10 -AccessRightLevel Read_Access -SmallIOAlertEnabled:$false -VaaiTPAlertEnabled
Set-XIOVolumeFolder -VolumeFolder (Get-XIOVolumeFolder /testFolder) -Caption testFolder_renamed
Get-XIOVolumeFolder /testFolder | Set-XIOVolumeFolder -Caption testFolder_renamed
#>


Write-Verbose -Verbose "Getting final counts of each object type of interest, for comparison to counts from before testing"
$arrTypesToCount | Foreach-Object -Begin {$hshTypeCounts_after = @{}} -Process {$hshTypeCounts_after[$_] = Invoke-Command -ScriptBlock {(& "Get-XIO$_" | Measure-Object).Count}}
$arrObjTypeCountInfo = $arrTypesToCount | Foreach-Object {New-Object -Type PSObject -Property ([ordered]@{Type = $_; CountBefore = $hshTypeCounts_before.$_; CountAfter = $hshTypeCounts_after.$_; CountIsSame = ($hshTypeCounts_before.$_ -eq $hshTypeCounts_after.$_)})}

Describe -Tags "Verification" -Name "VerificationAfterTesting" {
	It "Checks that there are the same number of objects of the subject types after the testing as there were before testing began" {
		$arrObjTypeCountInfo | Foreach-Object {
			$thisObjTypeInfo = $_
			$thisObjTypeInfo.CountIsSame | Should Be $true
		}
	}
}

Write-Verbose -Verbose "Counts of each subject type before and after testing:"
$arrObjTypeCountInfo

Write-Verbose -Verbose "Global variable named `$hshXioObjsToRemove contains info about all of the objects created during this testing"
