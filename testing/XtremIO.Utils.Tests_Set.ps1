<#	.Description
	Pester tests for Set-XIO* cmdlets for XtremIO.Utils PowerShell module.  Expects that:
	0) XtremIO.Utils module is already loaded (but, will try to load it if not)
	1) a connection to at least one XMS is in place (but, will prompt for XMS to which to connect if not)
#>

## initialize things, preparing for tests; provides $oXioConnectionToUse, $strXmsComputerName, and $strClusterNameToUse
. $PSScriptRoot\XtremIO.Utils.TestingInit.ps1

## string to append (including a GUID) to all objects renamed, to avoid any naming conflicts
$strNameToAppend = "_{0}" -f [System.Guid]::NewGuid().Guid.Replace("-","")
## string to prefix to existing names during object rename tests
$strNamePrefixForRename = "ren_"
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
## common parameters to use for New-XIO* cmdlet calls
$hshCommonParamsForNewObj = @{ComputerName = $strXmsComputerName}
## add -Cluster param if the XtremIO API version is at least v2.0
if ($oXioConnectionToUse.RestApiVersion -ge [System.Version]"2.0") {
	$hshCommonParamsForNewObj["Cluster"] = $strClusterNameToUse
} ## end if
else {Write-Verbose -Verbose "XtremIO API is older than v2.0 -- not using -Cluster parameter for commands"}
## common parameters to use for Set-XIO* cmdlet calls
$hshCommonParamsForSetObj = @{Confirm = $false}

Write-Verbose -Verbose "Getting current counts of each object type of interest, for comparison to counts after testing"
## the types of objects that will get created as target objects on which to then test Set-XIO* cmdlets
$arrTypesToCount = Write-Output ConsistencyGroup Initiator InitiatorGroup InitiatorGroupFolder Snapshot SnapshotScheduler Tag UserAccount Volume VolumeFolder
## all of the Set-XIO* cmdlets' target objects, and objects involved w/ Set operations:
# AlertDefinition ConsistencyGroup EmailNotifier Initiator InitiatorGroup InitiatorGroupFolder LdapConfig SnapshotScheduler SnapshotSet SnmpNotifier SyslogNotifier Tag Target UserAccount Volume VolumeFolder
$arrTypesToCount | Foreach-Object -Begin {$hshTypeCounts_before = @{}} -Process {$hshTypeCounts_before[$_] = Invoke-Command -ScriptBlock {(& "Get-XIO$_" | Measure-Object).Count}}

##### make the test objects
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
$oNewInitiator1 = New-XIOInitiator -Name "mysvr0-hba3$strNameToAppend" -InitiatorGroup $oTestIG0.name -PortAddress "${strInitiatorAddrPrefix}:${strInitiatorRandomEightHexChar_ColonJoined}:54" @hshCommonParamsForNewObj
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


## crate these objects if the XtremIO API version is at least v2.0
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
	$oNewSnapshotScheduler = New-XIOSnapshotScheduler -Enabled:$false -RelatedObject $oTestVolume0 -Interval (New-TimeSpan -Days 2 -Hours 6 -Minutes 9) -SnapshotRetentionCount $intSnapshotRetentionCount @hshCommonParamsForNewObj
	$hshXioObjsToRemove["SnapshotScheduler"] += @($oNewSnapshotScheduler)


	## New Tag
	## create a new tag to be used for Volume entities
	## This example highlights the behavior that, if no explicit "path" specified to the tag, the new tag is put at the root of its parent tag, based on the entity type
	$strEntityType = "Volume"
	$oNewTag0 = New-XIOTag -Name "v$strNameToAppend" -EntityType $strEntityType -ComputerName $strXmsComputerName
	$strEntityType = "InitiatorGroup"
	$oNewTag1 = New-XIOTag -Name "ig$strNameToAppend" -EntityType $strEntityType -ComputerName $strXmsComputerName
	$hshXioObjsToRemove["Tag"] += @($oNewTag0, $oNewTag1)


	## New UserAccount
	## create a new UserAccount with the read_only role, and with the given username/password. Uses default inactivity timeout configured on the XMS
	$strRole = "read_only"
	## create a new UserAccount with Credentials for auth; obviously a weak/fake password, and this is not the way that one should use the cmdlet in general practice:  static here for the testing aspect
	$oNewUserAccount = New-XIOUserAccount -Credential (New-Object System.Management.Automation.PSCredential("test_RoUser$strNameToAppend", ("someGre@tPasswordHere" | ConvertTo-SecureString -AsPlainText -Force))) -Role $strRole -ComputerName $strXmsComputerName
	$hshXioObjsToRemove["UserAccount"] += @($oNewUserAccount)
} ## end if
else {Write-Verbose -Verbose "XtremIO API is older than v2.0 -- not running tests for creating these object types:  ConsistencyGroup, Snapshot (since this module does not yet support them on pre-v2.0 APIs), SnapshotScheduler, Tag, and UserAccount"}






####### do the Set-XIO* tests
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
#>


Describe -Tags "Set" -Name "Set-XIOInitiator" {
	It "Renames an Initiator, changes the PortAddress, taking object from pipeline" {
		## grab an Initiator from the hashtable that is in the parent scope, as the scopes between tests are unique
		$oTestInitiator0 = $hshXioObjsToRemove["Initiator"] | Select-Object -First 1
		$strNewNameForObject = "$strNamePrefixForRename$($oTestInitiator0.Name)"
		$strNewHBAPortAddress = "${strInitiatorAddrPrefix}:${strInitiatorRandomEightHexChar_ColonJoined}:84"
		$oUpdatedInitiator = $oTestInitiator0 | Set-XIOInitiator -Name $strNewNameForObject -PortAddress $strNewHBAPortAddress @hshCommonParamsForSetObj

		$oUpdatedInitiator.Name | Should Be $strNewNameForObject
		$oUpdatedInitiator.PortAddress | Should Be $strNewHBAPortAddress
	}
}

Describe -Tags "Set" -Name "Set-XIOInitiatorGroup" {
	It "Renames an InitiatorGroup" {
		## grab an InitiatorGroup from the hashtable that is in the parent scope, as the scopes between tests are unique
		$oTestInitiatorGroup0 = $hshXioObjsToRemove["InitiatorGroup"] | Select-Object -First 1
		$strNewNameForObject = "$strNamePrefixForRename$($oTestInitiatorGroup0.Name)"
		$oUpdatedInitiatorGroup = Set-XIOInitiatorGroup -InitiatorGroup $oTestInitiatorGroup0 -Name $strNewNameForObject @hshCommonParamsForSetObj

		$oUpdatedInitiatorGroup.Name | Should Be $strNewNameForObject
	}

	It "Renames an InitiatorGroup, taking object from pipeline" {
		## grab an InitiatorGroup from the hashtable that is in the parent scope, as the scopes between tests are unique
		$oTestInitiatorGroup1 = $hshXioObjsToRemove["InitiatorGroup"] | Select-Object -First 1 -Skip 1
		$strNewNameForObject = "$strNamePrefixForRename$($oTestInitiatorGroup1.Name)"
		$oUpdatedInitiatorGroup = $oTestInitiatorGroup1 | Set-XIOInitiatorGroup -Name $strNewNameForObject @hshCommonParamsForSetObj

		$oUpdatedInitiatorGroup.Name | Should Be $strNewNameForObject
	}
}

Describe -Tags "Set" -Name "Set-XIOVolume" {
	It "Renames a Volume" {
		## grab a Volume from the hashtable that is in the parent scope, as the scopes between tests are unique
		$oTestVolume0 = $hshXioObjsToRemove["Volume"] | Select-Object -First 1
		$strNewNameForObject = "$strNamePrefixForRename$($oTestVolume0.Name)"
		$oUpdatedVolume = Set-XIOVolume -Volume $oTestVolume0 -Name $strNewNameForObject @hshCommonParamsForSetObj

		$oUpdatedVolume.Name | Should Be $strNewNameForObject
	}

	It "Renames a Volume, increases its size, and disables one kind of alert, taking object from pipeline" {
		## grab a Volume from the hashtable that is in the parent scope, as the scopes between tests are unique
		$oTestVolume1 = $hshXioObjsToRemove["Volume"] | Select-Object -First 1 -Skip 1
		$strNewNameForObject = "$strNamePrefixForRename$($oTestVolume1.Name)"
		$intNewSizeForObject = $oTestVolume1.VolSizeGB + 1
		## should the test enable VaaiTPAlertsCfg, or disable? (basically, toggle from current value on Volume)
		$bNewVaaiTPAlertsCfg_EnabledState = $oTestVolume1.VaaiTPAlertsCfg -eq "disabled"
		$oUpdatedVolume = $oTestVolume1 | Set-XIOVolume -Name $strNewNameForObject -SizeGB $intNewSizeForObject -VaaiTPAlertEnabled:$bNewVaaiTPAlertsCfg_EnabledState @hshCommonParamsForSetObj

		$oUpdatedVolume.Name | Should Be $strNewNameForObject
		$oUpdatedVolume.VolSizeGB | Should Be $intNewSizeForObject
		$bVaaiTPAlertsCfgAreNowEnabled = $oUpdatedVolume.VaaiTPAlertsCfg -eq "enabled"
		$bVaaiTPAlertsCfgAreNowEnabled | Should Be $bNewVaaiTPAlertsCfg_EnabledState
	}
}


## run these tests if the XtremIO API version is at least v2.0
if ($oXioConnectionToUse.RestApiVersion -ge [System.Version]"2.0") {
	Describe -Tags "Set" -Name "Set-XIOInitiator" {
		It "Renames an Initiator, changes the OperatingSystem, taking object from pipeline" {
			## grab an Initiator from the hashtable that is in the parent scope, as the scopes between tests are unique
			$oTestInitiator0 = $hshXioObjsToRemove["Initiator"] | Select-Object -First 1 -Skip 1
			$strNewNameForObject = "$strNamePrefixForRename$($oTestInitiator0.Name)"
			$strNewInitiatorOS = if ($oTestInitiator0.OperatingSystem -eq "ESX") {"Other"} else {"ESX"}
			$oUpdatedInitiator = $oTestInitiator0 | Set-XIOInitiator -Name $strNewNameForObject -OperatingSystem $strNewInitiatorOS @hshCommonParamsForSetObj

			$oUpdatedInitiator.Name | Should Be $strNewNameForObject
			$oUpdatedInitiator.OperatingSystem | Should Be $strNewInitiatorOS
		}
	}

	Describe -Tags "Set" -Name "Set-XIOVolume" {
		It "Renames a Volume, changes the AccessRightLevel, taking object from pipeline" {
			## grab a Volume from the hashtable that is in the parent scope, as the scopes between tests are unique
			$oTestVolume0 = $hshXioObjsToRemove["Volume"] | Select-Object -Last 1
			$strNewNameForObject = "$strNamePrefixForRename$($oTestVolume0.Name)"
			$strNewAccessLevelForObject = if ($oTestVolume0.AccessType -eq "write_access") {"Read_Access"} else {"Write_Access"}
			$oUpdatedVolume = $oTestVolume0 | Set-XIOVolume -Name $strNewNameForObject -AccessRightLevel $strNewAccessLevelForObject @hshCommonParamsForSetObj

			$oUpdatedVolume.Name | Should Be $strNewNameForObject
			$oUpdatedVolume.AccessType | Should Be $strNewAccessLevelForObject
		}
	}

	Describe -Tags "Set" -Name "Set-XIOSnapshotScheduler" {
		It "Sets the Suffix and RetentionCount on a SnapshotScheduler" {
			## grab a SnapshotScheduler from the hashtable that is in the parent scope, as the scopes between tests are unique
			$oTestSnapshotScheduler0 = $hshXioObjsToRemove["SnapshotScheduler"] | Select-Object -First 1
			$strNewSnapshotSchedulerSuffix = "newSnapSchedSuff_$($oTestSnapshotScheduler0.Suffix)"
			$intNewNumSnapToKeep = if ($oTestSnapshotScheduler0.NumSnapToKeep -eq 20) {21} else {20}
			$oUpdatedSnapshotScheduler = Set-XIOSnapshotScheduler -SnapshotScheduler $oTestSnapshotScheduler0 -Suffix $strNewSnapshotSchedulerSuffix -SnapshotRetentionCount $intNewNumSnapToKeep @hshCommonParamsForSetObj

			$oUpdatedSnapshotScheduler.Suffix | Should Be $strNewSnapshotSchedulerSuffix
			$oUpdatedSnapshotScheduler.NumSnapToKeep | Should Be $intNewNumSnapToKeep
		}

		## params for "It" call; Skip the test if REST API version is less than v2.1
		$hshParamsForIt = @{Skip = ($oXioConnectionToUse.RestApiVersion -lt [System.Version]"2.1")}
		if ($hshParamsForIt["Skip"]) {Write-Verbose -Verbose "REST API version is less than v2.1; skipping testing of setting SnapshotScheduler name (for which support began in REST API v2.1)"}
		It "Sets a new name for a SnapshotScheduler, taking object from pipeline" {
			## grab a SnapshotScheduler from the hashtable that is in the parent scope, as the scopes between tests are unique
			$oTestSnapshotScheduler0 = $hshXioObjsToRemove["SnapshotScheduler"] | Select-Object -First 1
			$strNewSnapshotSchedulerName = "${strNamePrefixForRename}testSnapSched$strNameToAppend"
			$oUpdatedSnapshotScheduler = $oTestSnapshotScheduler0 | Set-XIOSnapshotScheduler -Name $strNewSnapshotSchedulerName @hshCommonParamsForSetObj

			$oUpdatedSnapshotScheduler.Name | Should Be $strNewSnapshotSchedulerName
		}

		It "Sets the SnapshotType and SnapshotRetentionDuration on a SnapshotScheduler, taking object from pipeline" {
			## grab a SnapshotScheduler from the hashtable that is in the parent scope, as the scopes between tests are unique
			$oTestSnapshotScheduler0 = $hshXioObjsToRemove["SnapshotScheduler"] | Select-Object -First 1
			$tspNewSnapRetentionTimespan = if ($oTestSnapshotScheduler0.Retain -eq (New-TimeSpan -Days 3)) {New-TimeSpan -Days 4} else {New-TimeSpan -Days 3}
			$strNewTypeOfSnapshot = if ($oTestSnapshotScheduler0.SnapType -eq "regular") {"ReadOnly"} else {"Regular"}
			$oUpdatedSnapshotScheduler = $oTestSnapshotScheduler0 | Set-XIOSnapshotScheduler -SnapshotRetentionDuration $tspNewSnapRetentionTimespan -SnapshotType $strNewTypeOfSnapshot @hshCommonParamsForSetObj

			$oUpdatedSnapshotScheduler.Retain | Should Be $tspNewSnapRetentionTimespan
			$oUpdatedSnapshotScheduler.SnapType | Should Be $strNewTypeOfSnapshot
		}

		It "Sets the SnapshotScheduler to type Interval (vs. Explicit), specifying the new interval for snapshots, taking object from pipeline" {
			## grab a SnapshotScheduler from the hashtable that is in the parent scope, as the scopes between tests are unique
			$oTestSnapshotScheduler0 = $hshXioObjsToRemove["SnapshotScheduler"] | Select-Object -First 1
			$tspNewSnapInterval = (New-TimeSpan -Hours (Get-Random -Minimum 1 -Maximum 71) -Minutes (Get-Random -Minimum 0 -Maximum 59))
			$strExpectedScheduleString = "Every {0} hours {1} mins" -f [System.Math]::Floor($tspNewSnapInterval.TotalHours), $tspNewSnapInterval.Minutes
			$strExpectedSchedulerType = "Interval"
			$oUpdatedSnapshotScheduler = $oTestSnapshotScheduler0 | Set-XIOSnapshotScheduler -Interval $tspNewSnapInterval @hshCommonParamsForSetObj
			$bSchedulerScheduleIsProperlyUpdated = $oUpdatedSnapshotScheduler.Schedule -eq $strExpectedScheduleString
			$bSchedulerIsOfProperType = $oUpdatedSnapshotScheduler.Type -eq $strExpectedSchedulerType

			$bSchedulerScheduleIsProperlyUpdated | Should Be $true
			$bSchedulerIsOfProperType | Should Be $true
		}

		It "Sets the SnapshotScheduler to type Explicit (vs. Interval), specifying the new schedule for snapshots, changing the snapped object, taking object from pipeline" {
			## grab a SnapshotScheduler from the hashtable that is in the parent scope, as the scopes between tests are unique
			$oTestSnapshotScheduler0 = $hshXioObjsToRemove["SnapshotScheduler"] | Select-Object -First 1
			## get an object that is of a different type than is already the SnappedObject type for this SnapshotScheduler, to specify as the new SnappedObject
			$oNewSnappedObject = $hshXioObjsToRemove[$(if ($oTestSnapshotScheduler0.SnappedObject.Type -eq "ConsistencyGroup") {"Volume"} else {"ConsistencyGroup"})] | Select-Object -Last 1
			$dteNewTimeOfDay = (Get-Date -Hour (Get-Random -Minimum 0 -Maximum 23) -Minute (Get-Random -Minimum 0 -Maximum 59))
			$strExplicitDay = "Everyday"
			$strExpectedScheduleString = "Every day at {0}" -f $dteNewTimeOfDay.ToString("HH:mm")
			$strExpectedSchedulerType = "Explicit"
			$oUpdatedSnapshotScheduler = $oTestSnapshotScheduler0 | Set-XIOSnapshotScheduler -ExplicitDay $strExplicitDay -ExplicitTimeOfDay $dteNewTimeOfDay -RelatedObject $oNewSnappedObject @hshCommonParamsForSetObj
			$bSchedulerScheduleIsProperlyUpdated = $oUpdatedSnapshotScheduler.Schedule -eq $strExpectedScheduleString
			$bSchedulerIsOfProperType = $oUpdatedSnapshotScheduler.Type -eq $strExpectedSchedulerType
			$bSnappedObjectIsProperlyUpdated = ($oUpdatedSnapshotScheduler.SnappedObject.Type -eq $oNewSnappedObject.GetType().Name) -and ($oUpdatedSnapshotScheduler.SnappedObject.Name -eq $oNewSnappedObject.Name)

			$bSchedulerScheduleIsProperlyUpdated | Should Be $true
			$bSchedulerIsOfProperType | Should Be $true
			$bSnappedObjectIsProperlyUpdated | Should Be $true
		}
	}

	Describe -Tags "Set" -Name "Set-XIOTag" {
		It "Sets the new name for a Tag" {
			## grab a Tag from the hashtable that is in the parent scope, as the scopes between tests are unique
			$oTag0 = $hshXioObjsToRemove["Tag"] | Select-Object -First 1
			$strNewTagName = "${strNamePrefixForRename}$($oTag0.Caption)"
			$oUpdatedTag = Set-XIOTag -Tag $oTag0 -Caption $strNewTagName @hshCommonParamsForSetObj
			$bTagNameIsProperlyUpdated = $oUpdatedTag.Caption -eq $strNewTagName

			$bTagNameIsProperlyUpdated | Should Be $true
		}

		# Get-XIOTag -Name /InitiatorGroup/myTag | Set-XIOTag -Caption myTag_renamed -Color 00FF00
		It "Sets the new name and color for a Tag, taking object from pipeline" {
			## grab a Tag from the hashtable that is in the parent scope, as the scopes between tests are unique
			$oTag0 = $hshXioObjsToRemove["Tag"] | Select-Object -First 1 -Skip 1
			$strNewTagName = "${strNamePrefixForRename}$($oTag0.Caption)"
			$intColorDecFromHexToAvoid = if ([String]::IsNullOrEmpty($oTag0.ColorHex)) {0} else {[System.Convert]::ToInt32($oTag0.ColorHex.Trim("#"), 16)}
			## get a number that is (16^6 - 1) max value (0xFFFFFF) and is not the current color of the Tag; trying a few times, just to be sure that we get a value different than the current ColorHex on the Tag
			$strNewHexColor = "{0:x6}" -f (0..7 | Foreach-Object {Get-Random -Maximum ([Int]([System.Math]::Pow(16,6) - 1))} | Where-Object {$_ -ne $intColorDecFromHexToAvoid} | Select-Object -First 1)
			$oUpdatedTag = $oTag0 | Set-XIOTag -Caption $strNewTagName -Color $strNewHexColor @hshCommonParamsForSetObj
			$bTagNameIsProperlyUpdated = $oUpdatedTag.Caption -eq $strNewTagName
			$bTagColorIsProperlyUpdated = $oUpdatedTag.ColorHex -eq "#$strNewHexColor"

			$bTagNameIsProperlyUpdated | Should Be $true
			$bTagColorIsProperlyUpdated | Should Be $true
		}
	}

	Describe -Tags "Set" -Name "Set-XIOUserAccount" {
		It "Sets the InactivityTimeoutMin and Role for a UserAccount" {
			## grab a UserAccount from the hashtable that is in the parent scope, as the scopes between tests are unique
			$oUserAccount0 = $hshXioObjsToRemove["UserAccount"] | Select-Object -First 1
			$intNewInactivityTimeout = if ($oUserAccount0 -eq 0) {1} else {0}
			$strNewRole = if ($oUserAccount0.Role -eq "read_only") {"configuration"} else {"read_only"}
			$oUpdatedUserAccount = Set-XIOUserAccount -UserAccount $oUserAccount0 -InactivityTimeout $intNewInactivityTimeout -Role $strNewRole @hshCommonParamsForSetObj
			$bUserAccountTimeoutIsProperlyUpdated = $oUpdatedUserAccount.InactivityTimeoutMin -eq $intNewInactivityTimeout
			$bUserAccountRoleIsProperlyUpdated = $oUpdatedUserAccount.Role -eq $strNewRole

			$bUserAccountTimeoutIsProperlyUpdated | Should Be $true
			$bUserAccountRoleIsProperlyUpdated | Should Be $true
		}

		# Get-XIOUserAccount -Name someUser0 | Set-XIOUserAccount -UserName someUser0_renamed -SecureStringPassword (Read-Host -AsSecureString)
		It "Sets a new name and password for a UserAccount, taking object from pipeline" {
			## grab a UserAccount from the hashtable that is in the parent scope, as the scopes between tests are unique
			$oUserAccount0 = Get-XIOItemInfo -URI ($hshXioObjsToRemove["UserAccount"] | Select-Object -First 1).Uri
			$strNewUserAccountName = "${strNamePrefixForRename}$($oUserAccount0.Name)"
			$sstrNewPasswd = ConvertTo-SecureString -AsPlainText -String ([System.Guid]::NewGuid().Guid) -Force
			$oUpdatedUserAccount = $oUserAccount0 | Set-XIOUserAccount -UserName $strNewUserAccountName -SecureStringPassword $sstrNewPasswd @hshCommonParamsForSetObj
			$bUserAccountNameIsProperlyUpdated = $oUpdatedUserAccount.Name -eq $strNewUserAccountName

			$bUserAccountNameIsProperlyUpdated | Should Be $true
		}
	}

	## Tests for cmdlets that rename-only
	"ConsistencyGroup", "SnapshotSet" | Foreach-Object {
		$strThisObjectTypeToTest = $_
		Describe -Tags "Set" -Name "Set-XIO$strThisObjectTypeToTest" {
			It "Sets a new name for a $strThisObjectTypeToTest, taking object from pipeline" {
				## grab a targeted object from the hashtable that is in the parent scope, as the scopes between tests are unique
				$oObjToTestUpon0 = Get-XIOItemInfo -URI ($hshXioObjsToRemove[$strThisObjectTypeToTest] | Select-Object -First 1).Uri
				$strNewNameForObj = "${strNamePrefixForRename}$($oObjToTestUpon0.Name)"
				$oUpdatedItem = $oObjToTestUpon0 | & "Set-XIO$strThisObjectTypeToTest" -Name $strNewNameForObj @hshCommonParamsForSetObj
				$bItemIsPropertyUpdated = $oUpdatedItem.Name -eq $strNewNameForObj

				$bItemIsPropertyUpdated | Should Be $true
			}
		}
	} ## end foreach-object
} ## end if
else {Write-Verbose -Verbose "XtremIO API is older than v2.0 -- not running tests for creating these object types:  ConsistencyGroup, Snapshot (since this module does not yet support them on pre-v2.0 APIs), SnapshotScheduler, Tag, and UserAccount"}

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
				Try {Invoke-Command -ScriptBlock {& "Remove-XIO$strCmdletNounPortion" (Get-XIOItemInfo -URI $oThisObjToRemove.URI)}}
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
