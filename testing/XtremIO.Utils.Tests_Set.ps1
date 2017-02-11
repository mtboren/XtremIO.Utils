<#	.Description
	Pester tests for Set-XIO* cmdlets for XtremIO.Utils PowerShell module.  Expects that:
	0) XtremIO.Utils module is already loaded (but, will try to load it if not)
	1) a connection to at least one XMS is in place (but, will prompt for XMS to which to connect if not)
#>

## initialize things, preparing for tests; provides $oXioConnectionToUse, $strXmsComputerName, and $strClusterNameToUse
. $PSScriptRoot\XtremIO.Utils.TestingInit.ps1

## string to append (including a GUID) to all objects renamed, to avoid any naming conflicts
$strNameToAppend = "_{0}" -f [System.Guid]::NewGuid().Guid.Replace("-","")
Write-Verbose -Verbose "Testing of Set-XIO* cmdlets involves creating new XIO objects whose properties to set. After the Set-XIO* testing, these newly created, temporary XIO objects will be removed. But, to ensure that only the temporary objects are being removed, the Remove-XIO* calls all prompt for confirmation. This breaks fully automated testing, but is kept in place for now to keep the consumer's comfort level on high."
Write-Verbose -Verbose "No tests currently written for Set-XIO* cmdlets against some built-in, sytem-wide objects:  AlertDefinition, EmailNotifier, LdapConfig, SnmpNotifier, SyslogNotifier, Target"
Write-Verbose -Verbose "Suffix used for new objects for this test:  $strNameToAppend"
## bogus OUI for making sure that the addresses of the intiators created here do not conflict with any real-world addresses
$strInitiatorAddrPrefix = "EE:EE:EE"
## random hex value to use for four hex-pairs in the port addresses, to avoid address conflicts if testing multiple times without removing newly created test objects (with particular port addresses)
$strInitiatorRandomEightHexChar = "{0:x8}" -f (Get-Random -Maximum ([Int64]([System.Math]::pow(16,8) - 1)))
$strInitiatorRandomEightHexChar_ColonJoined = ($strInitiatorRandomEightHexChar -split "(\w{2})" | Where-Object {$_ -ne ""}) -join ":"
## hashtable to keep the variables that hold the newly created objects, so that these objects can be removed from the XMS later; making it a global variable, so that consumer has it for <anything they desire> after testing
$global:hshXioObjsToRemove = [ordered]@{}
$hshCommonParamsForNewObj = @{ComputerName =  $strXmsComputerName}
## add -Cluster param if the XtremIO API version is at least v2.0
if ($oXioConnectionToUse.RestApiVersion -ge [System.Version]"2.0") {
	$hshCommonParamsForNewObj["Cluster"] = $strClusterNameToUse
} ## end if
else {Write-Verbose -Verbose "XtremIO API is older than v2.0 -- not using -Cluster parameter for commands"}

Write-Verbose -Verbose "Getting current counts of each object type of interest, for comparison to counts after testing"
## the types of objects that will get created as target objects on which to then test Set-XIO* cmdlets
$arrTypesToCount = Write-Output ConsistencyGroup Initiator InitiatorGroup InitiatorGroupFolder Snapshot SnapshotScheduler Tag UserAccount Volume VolumeFolder
## all of the Set-XIO* cmdlets' target objects, and objects involved w/ Set operations:
# AlertDefinition ConsistencyGroup EmailNotifier Initiator InitiatorGroup InitiatorGroupFolder LdapConfig SnapshotScheduler SnapshotSet SnmpNotifier SyslogNotifier Tag Target UserAccount Volume VolumeFolder
$arrTypesToCount | Foreach-Object -Begin {$hshTypeCounts_before = @{}} -Process {$hshTypeCounts_before[$_] = Invoke-Command -ScriptBlock {(& "Get-XIO$_" | Measure-Object).Count}}

<#
## on single, built-in, system-wide objects (do not do automated tests for these?)
Get-XIOAlertDefinition alert_def_module_inactive | Set-XIOAlertDefinition -Enable
Get-XIOAlertDefinition alert_def_module_inactive | Set-XIOAlertDefinition -Severity Major -ClearanceMode Ack_Required -SendToCallHome:$false
Get-XIOEmailNotifier | Set-XIOEmailNotifier -Sender myxms.dom.com -Recipient me@dom.com,someoneelse@dom.com
Get-XIOEmailNotifier | Set-XIOEmailNotifier -CompanyName MyCompany -MailRelayServer mysmtp.dom.com
Get-XIOEmailNotifier | Set-XIOEmailNotifier -ProxyServer myproxy.dom.com -ProxyServerPort 10101 -ProxyCredential (Get-Credential dom\myProxyUser) -Enable:$false
Get-XIOLdapConfig | Where-Object {$_.SearchBaseDN -eq "dc=dom,dc=com"} | Set-XIOLdapConfig -RoleMapping "read_only:cn=grp0,dc=dom,dc=com","configuration:cn=user0,dc=dom,dc=com"
Get-XIOLdapConfig | Where-Object {$_.SearchBaseDN -eq "dc=dom,dc=com"} | Set-XIOLdapConfig -BindDN "cn=mybinder,dc=dom,dc=com" -BindSecureStringPassword (Read-Host -AsSecureString -Prompt "Enter some password") -SearchBaseDN "OU=tiptop,dc=dom,dc=com" -SearchFilter "sAMAccountName={username}" -LdapServerURL ldaps://prim.dom.com,ldaps://sec.dom.com -UserToDnRule "dom\{username}" -CacheExpire 8 -Timeout 30 -RoleMapping "admin:cn=grp0,dc=dom,dc=com","admin:cn=grp2,dc=dom,dc=com"
Get-XIOSnmpNotifier | Set-XIOSnmpNotifier -Enable:$false
Get-XIOSnmpNotifier | Set-XIOSnmpNotifier -PrivacyKey (Read-Host -AsSecureString "priv key") -SnmpVersion v3 -AuthenticationKey (Read-Host -AsSecureString "auth key") -PrivacyProtocol DES -AuthenticationProtocol MD5 -UserName admin2 -Recipient testdest0.dom.com,testdest1.dom.com
Set-XIOSyslogNotifier -SyslogNotifier (Get-XIOSyslogNotifier) -Enable:$false
Get-XIOSyslogNotifier | Set-XIOSyslogNotifier -Enable -Target syslog0.dom.com,syslog1.dom.com:515
Set-XIOTarget -Target (Get-XIOTarget X1-SC2-iscsi1) -MTU 9000
Get-XIOTarget -Name X1-SC2-iscsi1 -Cluster myCluster0 -ComputerName somexms.dom.com | Set-XIOTarget -MTU 1500
## end built-in, system-wide objects

## tests for deprecated objects (do not run these?)
Set-XIOInitiatorGroupFolder -InitiatorGroupFolder (Get-XIOInitiatorGroupFolder /myIgFolder) -Caption myIgFolder_renamed
Get-XIOInitiatorGroupFolder /myIgFolder | Set-XIOInitiatorGroupFolder -Caption myIgFolder_renamed
Set-XIOVolumeFolder -VolumeFolder (Get-XIOVolumeFolder /testFolder) -Caption testFolder_renamed
Get-XIOVolumeFolder /testFolder | Set-XIOVolumeFolder -Caption testFolder_renamed
## end tests for deprecated objects


Set-XIOInitiator -Initiator (Get-XIOInitiator myInitiator0) -Name newInitiatorName0 -OperatingSystem ESX
Get-XIOInitiator -Name myInitiator0 -Cluster myCluster0 -ComputerName somexms.dom.com | Set-XIOInitiator -Name newInitiatorName0 -PortAddress 10:00:00:00:00:00:00:54
Set-XIOInitiatorGroup -InitiatorGroup (Get-XIOInitiatorGroup myInitiatorGroup0) -Name newInitiatorGroupName0
Get-XIOInitiatorGroup -Name myInitiatorGroup0 -Cluster myCluster0 -ComputerName somexms.dom.com | Set-XIOInitiatorGroup -Name newInitiatorGroupName0
Set-XIOSnapshotScheduler -SnapshotScheduler (Get-XIOSnapshotScheduler mySnapshotScheduler0) -Suffix someSuffix0 -SnapshotRetentionCount 20
Get-XIOSnapshotScheduler -Name mySnapshotScheduler0 | Set-XIOSnapshotScheduler -Name mySnapshotScheduler0_newName
Get-XIOSnapshotScheduler -Name mySnapshotScheduler0 | Set-XIOSnapshotScheduler -SnapshotRetentionDuration (New-TimeSpan -Days (365*3)) -SnapshotType Regular
Get-XIOSnapshotScheduler -Name mySnapshotScheduler0 | Set-XIOSnapshotScheduler -Interval (New-TimeSpan -Hours 54 -Minutes 21)
Get-XIOSnapshotScheduler -Name mySnapshotScheduler0 | Set-XIOSnapshotScheduler -ExplicitDay Everyday -ExplicitTimeOfDay (Get-Date 2am) -RelatedObject (Get-XIOConsistencyGroup -Name myConsistencyGrp0)
Get-XIOSnapshotScheduler -Name mySnapshotScheduler0 -Cluster myCluster0 -ComputerName somexms.dom.com | Set-XIOSnapshotScheduler -Enable:$false
Set-XIOTag -Tag (Get-XIOTag /InitiatorGroup/myTag) -Caption myTag_renamed
Get-XIOTag -Name /InitiatorGroup/myTag | Set-XIOTag -Caption myTag_renamed -Color 00FF00
Get-XIOUserAccount -Name someUser0 | Set-XIOUserAccount -UserName someUser0_renamed -SecureStringPassword (Read-Host -AsSecureString)
Set-XIOUserAccount -UserAccount (Get-XIOUserAccount someUser0) -InactivityTimeout 0 -Role read_only
Set-XIOVolume -Volume (Get-XIOVolume myVolume) -Name myVolume_renamed
Get-XIOSnapshot myVolume.snapshot0 | Set-XIOVolume -Name myVolume.snapshot0_old
Get-XIOVolume myVolume0 | Set-XIOVolume -SizeTB 10 -AccessRightLevel Read_Access -SmallIOAlertEnabled:$false -VaaiTPAlertEnabled

## Tests for cmdlets that rename-only
Set-XIOConsistencyGroup -ConsistencyGroup (Get-XIOConsistencyGroup myConsistencyGroup0) -Name newConsistencyGroupName0
Get-XIOConsistencyGroup -Name myConsistencyGroup0 -Cluster myCluster0 -ComputerName somexms.dom.com | Set-XIOConsistencyGroup -Name newConsistencyGroupName0
Set-XIOSnapshotSet -SnapshotSet (Get-XIOSnapshotSet mySnapshotSet0) -Name newSnapsetName0
Get-XIOSnapshotSet -Name mySnapshotSet0 -Cluster myCluster0 -ComputerName somexms.dom.com | Set-XIOSnapshotSet -Name newSnapsetName0
#>

## make the test objects
Write-Verbose -Verbose "Starting creation of temporary objects for this testing"
## New InitiatorGroups
## create new, empty InitiatorGroup
$oNewIG0 = New-XIOInitiatorGroup -Name "testIG0$strNameToAppend" @hshCommonParamsForNewObj
$hshXioObjsToRemove["InitiatorGroup"] += @($oNewIG0)

## create a new InitiatorGroup with two new Initiators in it
$hshNewIGParam = @{InitiatorList = @{"myserver-hba2$strNameToAppend" = "${strInitiatorAddrPrefix}:${strInitiatorRandomEightHexChar_ColonJoined}:F4"; "myserver-hba3$strNameToAppend" = "${strInitiatorAddrPrefix}:${strInitiatorRandomEightHexChar_ColonJoined}:F5"}}
$oNewIG1 = New-XIOInitiatorGroup -Name "testIG1$strNameToAppend" @hshNewIGParam @hshCommonParamsForNewObj
$hshXioObjsToRemove["InitiatorGroup"] += @($oNewIG1)
$arrNewInitiators_thisIG = $oNewIG1 | Get-XIOInitiator
$hshXioObjsToRemove["Initiator"] += @($arrNewInitiators_thisIG)


## New Initiators
## create a new Initiator using Hex port address notation, placing it in an existing InitiatorGroup
## grab this IG from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one InitiatorGroup has been made in the course of this testing
$oTestIG0 = $hshXioObjsToRemove["InitiatorGroup"] | Select-Object -First 1
$oNewInitiator0 = New-XIOInitiator -Name "mysvr0-hba2$strNameToAppend" -InitiatorGroup $oTestIG0.name -PortAddress ("0x{0}{1}cd" -f $strInitiatorAddrPrefix.Replace(":", ""), $strInitiatorRandomEightHexChar) @hshCommonParamsForNewObj
$hshXioObjsToRemove["Initiator"] += @($oNewInitiator0)

## create a new Initiator using colon-delimited port address notation, placing it in an existing InitiatorGroup
## grab this IG from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one InitiatorGroup has been made in the course of this testing
$oTestIG0 = $hshXioObjsToRemove["InitiatorGroup"] | Select-Object -First 1
$oNewInitiator1 = New-XIOInitiator -Name "mysvr0-hba3$strNameToAppend" -InitiatorGroup $oTestIG0.name -PortAddress ${strInitiatorAddrPrefix}:${strInitiatorRandomEightHexChar_ColonJoined}:54 @hshCommonParamsForNewObj
$hshXioObjsToRemove["Initiator"] += @($oNewInitiator1)


# ## New InitiatorGroupFolder
# ## create a new IGFolder
# $oNewIGFolder = New-XIOInitiatorGroupFolder -Name "myIGFolder$strNameToAppend" -ParentFolder / -ComputerName $strXmsComputerName
# $hshXioObjsToRemove["InitiatorGroupFolder"] += @($oNewIGFolder)


# ## New VolumeFolder
# ## create a new VolumeFolder
# $oNewVolFolder = New-XIOVolumeFolder -Name "myVolFolder$strNameToAppend" -ParentFolder / -ComputerName $strXmsComputerName
# $hshXioObjsToRemove["VolumeFolder"] += @($oNewVolFolder)


## New Volume
## create new Volumes in a specified cluster and XMS connection, enabling the three Alerts available on a Volume object
$hshXioObjsToRemove["Volume"] += 0..2 | Foreach-Object {New-XIOVolume -Name "testvol${_}$strNameToAppend" -SizeGB 10 -EnableSmallIOAlert -EnableUnalignedIOAlert -EnableVAAITPAlert @hshCommonParamsForNewObj}


## run these tests if the XtremIO API version is at least v2.0
if ($oXioConnectionToUse.RestApiVersion -ge [System.Version]"2.0") {
	## New ConsistencyGroup
	## create a new ConsistencyGroup that contains the volumes specified
	$intNumVolForConsistencyGroup = 2
	## grab some Volumes from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least two Volumes have been made in the course of this testing
	$arrTestVolume = $hshXioObjsToRemove["Volume"] | Select-Object -First $intNumVolForConsistencyGroup
	$oNewConsistencyGroup = New-XIOConsistencyGroup -Name myConsGrp0$strNameToAppend -Volume $arrTestVolume @hshCommonParamsForNewObj
	$hshXioObjsToRemove["ConsistencyGroup"] += @($oNewConsistencyGroup)


	## New Snapshot
	## create a new regular Snapshot for each of two (2) Volumes by name, specifying the SnapshotSuffix and a name for the new SnapshotSet that will contain both
	## grab some Volumes from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least two Volumes have been made in the course of this testing
	$oTestVolume0, $oTestVolume1 = $hshXioObjsToRemove["Volume"] | Select-Object -First 2
	$strNameForNewSnapshotSet = "SnapSet0$strNameToAppend"; $strValueForSnapshotSuffix = "SnapTest"
	$arrNewSnapshot = New-XIOSnapshot -Volume $oTestVolume0.Name,$oTestVolume1.Name -SnapshotSuffix $strValueForSnapshotSuffix -NewSnapshotSetName $strNameForNewSnapshotSet @hshCommonParamsForNewObj
	$hshXioObjsToRemove["Snapshot"] += $arrNewSnapshot
	$hshXioObjsToRemove["SnapshotSet"] += @(Get-XIOSnapshotSet -Name $arrNewSnapshot.SnapshotSet.Name @hshCommonParamsForNewObj | Select-Object -Unique)


	## New SnapshotScheduler
	## create a new (disabled) SnapshotScheduler from a Volume, using interval between snapshots, specifying particular number of regular Snapshots to retain
	$intSnapshotRetentionCount = 20
	## grab a Volume from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one Volume has been made in the course of this testing
	$oTestVolume0 = $hshXioObjsToRemove["Volume"] | Select-Object -First 1
	$oNewSnapshotScheduler = New-XIOSnapshotScheduler -Enabled:$false -RelatedObject $oTestVolume0 -Interval (New-Timespan -Days 2 -Hours 6 -Minutes 9) -SnapshotRetentionCount $intSnapshotRetentionCount @hshCommonParamsForNewObj
	$hshXioObjsToRemove["SnapshotScheduler"] += @($oNewSnapshotScheduler)


	## New Tag
	## create a new tag to be used for Volume entities
	## This example highlights the behavior that, if no explicit "path" specified to the tag, the new tag is put at the root of its parent tag, based on the entity type
	$strEntityType = "Volume"
	$oNewTag = New-XIOTag -Name v$strNameToAppend -EntityType $strEntityType -ComputerName $strXmsComputerName
	$hshXioObjsToRemove["Tag"] += @($oNewTag)


	## New UserAccount
	## create a new UserAccount with the read_only role, and with the given username/password. Uses default inactivity timeout configured on the XMS
	$strRole = "read_only"
	## create a new UserAccount with Credentials for auth; obviously a weak/fake password, and this is not the way that one should use the cmdlet in general practice:  static here for the testing aspect
	$oNewUserAccount = New-XIOUserAccount -Credential (New-Object System.Management.Automation.PSCredential("test_RoUser$strNameToAppend", ("someGre@tPasswordHere" | ConvertTo-SecureString -AsPlainText -Force))) -Role $strRole -ComputerName $strXmsComputerName
	$hshXioObjsToRemove["UserAccount"] += @($oNewUserAccount)
} ## end if
else {Write-Verbose -Verbose "XtremIO API is older than v2.0 -- not running tests for creating these object types:  ConsistencyGroup, Snapshot (since this module does not yet support them on pre-v2.0 APIs), SnapshotScheduler, Tag, and UserAccount"}






####### do the Set-XIO* tests here




Write-Verbose -Verbose "Starting removal of temporary objects created for this testing"
## For the removal of all objects that were created while testing the New-XIO* cmdlets above:
## the order in which types should be removed, so as to avoid removal issues (say, due to a Volume being part of a LunMap, and the likes)
# should then remove in particular order of:
#	SnapshotScheduler (so then can remove ConsistencyGroups, SnapshotSets, and Volumes),
#	ConsistencyGroup (so can then remove Volumes),
#	LunMap (so can then remove InitiatorGroups),
#	Snapshot (so that all Snapshots are still Snapshots, instead of having been transformed into Volumes by action of having all ancestor volumes removed),
#	Initiator (so that they still exist, vs. having been indirectly removed by having removed InitiatorGroups)
#   Volume (so that subsequent Remove-XIOVolumeFolder will not fail on API v1 due to non-empty folder -- that throws error in API v1)
#	then <all the rest>
$arrTypeSpecificRemovalOrder = Write-Output SnapshotScheduler ConsistencyGroup LunMap Snapshot Initiator Volume Tag
## list of types that are removed by other means (separate tests), and, so, will not be added to list of types to "auto" remove
$arrTypesRemovedInOtherTests = Write-Output TagAssignment
## then, the order-specific types, plus the rest of the types that were created during the New-XIO* testing, so as to be sure to removal all of the new test objects created:
$arrOverallTypeToRemove_InOrder = $arrTypeSpecificRemovalOrder + @($hshXioObjsToRemove.Keys | Where-Object {$arrTypeSpecificRemovalOrder -notcontains $_ -and ($arrTypesRemovedInOtherTests -notcontains $_)})

## for each of the types to remove, and in order, if there were objects of this type created, remove them
$arrOverallTypeToRemove_InOrder | Foreach-Object {
	$strThisTypeToRemove = $_
	## if this XIO connection is of API v2, do all tests; if not of v2, do all tests except the ones called out in the "-or" bit
	if (($oXioConnectionToUse.RestApiVersion -ge [System.Version]"2.0") -or ("SnapshotScheduler", "ConsistencyGroup", "Snapshot" -notcontains $strThisTypeToRemove)) {
		## remove a $strThisTypeToRemove (all that were created in New-XIO* testing)
		## grab the objects from the hashtable that is in the parent scope, as the scopes between tests are unique
		$arrTestObjToRemove = $hshXioObjsToRemove[$strThisTypeToRemove]
		$intNumObjToRemove = ($arrTestObjToRemove | Measure-Object).Count
		if ($intNumObjToRemove -gt 0) {
			Write-Verbose -Verbose ("will attempt to remove {0} '{1}' object{2}" -f $intNumObjToRemove, $strThisTypeToRemove, $(if ($intNumObjToRemove -ne 1) {"s"}))
			## should remove without issue; need to use "Remove-XIOVolume" for removing Snapshots, since that cmdlet is for removing both Volumes and Snapshots
			$strCmdletNounPortion = if ($strThisTypeToRemove -eq "Snapshot") {"Volume"} else {$strThisTypeToRemove}
			## if these are the Tag objects, sort descending by the Tag CreationTime, so that the remove tests will try to remove the newest first (which should be any "nested" Tags first), so as to try to avoid getting in a test scenario where a child Tag is already deleted by the action of having deleted its parent Tag, so the test of deleting the child Tag would fail (Tag not found)
			if ($strThisTypeToRemove -eq "Tag") {$arrTestObjToRemove = $arrTestObjToRemove | Sort-Object -Property CreationTime -Descending}
			$arrTestObjToRemove | Foreach-Object {
				$oThisObjToRemove = $_
				## there is a verification later to report whether all things were removed, which will report any errant removes
				Try {Invoke-Command -ScriptBlock {& "Remove-XIO$strCmdletNounPortion" $oThisObjToRemove}}
				Catch {Write-Warning "Did not remove following object.  Already removed, or remove failed? Obj name: $($oThisObjToRemove.Name)"}
			} ## end foreach-object
		} ## end if
		else {Write-Verbose -Verbose "No '$strThisTypeToRemove' objects were created in this testing; will not attempt to remove any"}
	} ## end if
	else {Write-Verbose -Verbose "XtremIO API is older than v2.0 -- not running specific tests for removing object type:  $strThisTypeToRemove"}
} ## end foreach-object


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
