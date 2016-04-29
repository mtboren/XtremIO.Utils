<#	.Description
	Pester tests for New-XIO* cmdlets for XtremIO.Utils PowerShell module.  Expects that:
	0) XtremIO.Utils module is already loaded (but, will try to load it if not)
	1) a connection to at least one XMS is in place (but, will prompt for XMS to which to connect if not)
#>

## initialize things, preparing for tests; provides $oXioConnectionToUse, $strXmsComputerName, and $strClusterNameToUse
. $PSScriptRoot\XtremIO.Utils.TestingInit.ps1

## string to append (including a GUID) to all new objects created, to avoid any naming conflicts
$strNameToAppend = "_testItemToDelete_{0}" -f [System.Guid]::NewGuid().Guid.Replace("-","")
## bogus OUI for making sure that the addresses of the intiators created here do not conflict with any real-world addresses
$strInitiatorAddrPrefix = "EE:EE:EE"
## hashtable to keep the variables that hold the newly created objects, so that these objects can be removed from the XMS later
$hshXioObjsToRemove = [ordered]@{NewObjSuffixForThisTest = $strNameToAppend}
$hshCommonParamsForNewObj = @{ComputerName =  $strXmsComputerName; Cluster = $strClusterNameToUse}

Write-Warning "no fully-automatic tests yet defined for New-XIO* and Remove-XIO* cmdlets"


## test making new things; will capture the new items, and then remove them
## should test against XIOS v3 (XIO API v1) and XIOS v4+ (XIO API v2), at least
<#
Describe -Tags "New" -Name "New-XIOInitiatorGroup" {
	It "Creates new, empty InitiatorGroup" {
		## without "-Cluster" in multicluster instance, fails
		$oNewIG0 = New-XIOInitiatorGroup -Name "testIG0$strNameToAppend" @hshCommonParamsForNewObj
		$hshXioObjsToRemove["InitiatorGroup"] += @($oNewIG0)
		$oNewIG0 | Should BeOfType [XioItemInfo.InitiatorGroup]
	}

	It "Creates a new InitiatorGroup with two new Initiators in it" {
		## InitiatorList:  XIOS older than v3 needs double-quotes around the keys and values, XIOS v3 and newer does not
		$hshNewIGParam = if ($oXioConnectionToUse.XmsVersion -lt [System.Version]"3.0.0") {
			@{
				InitiatorList = @{'"myserver-hba2$strNameToAppend"' = '"${strInitiatorAddrPrefix}:00:00:00:00:F4"'; '"myserver-hba3$strNameToAppend"' = '"${strInitiatorAddrPrefix}:00:00:00:00:F5"'}
				ParentFolder = "/"
			}
		} else {
			@{InitiatorList = @{"myserver-hba2$strNameToAppend" = "${strInitiatorAddrPrefix}:00:00:00:00:F4"; "myserver-hba3$strNameToAppend" = "${strInitiatorAddrPrefix}:00:00:00:00:F5"}}
		}
		## new InitiatorGroup
		$oNewIG1 = New-XIOInitiatorGroup -Name "testIG1$strNameToAppend" @hshNewIGParam @hshCommonParamsForNewObj
		$hshXioObjsToRemove["InitiatorGroup"] += @($oNewIG1)

		$oNewIG1 | Should BeOfType [XioItemInfo.InitiatorGroup]
		$oNewIG1 | Get-XIOInitiator | Foreach-Object {$_ | Should BeOfType [XioItemInfo.Initiator]}
		$oNewIG1.NumInitiator | Should Be 2
	}
}

Describe -Tags "New" -Name "New-XIOInitiator" {
	It "Creates a new Initiator using Hex port address notation, placing it in an existing InitiatorGroup" {
		## grab this IG from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one InitiatorGroup has been made in the course of this testing
		$oTestIG0 = $hshXioObjsToRemove["InitiatorGroup"] | Select-Object -First 1
		$oDestIG_before = Get-XIOInitiatorGroup -URI $oTestIG0.URI
		$oNewInitiator0 = New-XIOInitiator -Name "mysvr0-hba2$strNameToAppend" -InitiatorGroup $oTestIG0.name -PortAddress ("0x{0}000000abcd" -f $strInitiatorAddrPrefix.Replace(":", "")) @hshCommonParamsForNewObj
		$hshXioObjsToRemove["Initiator"] += @($oNewInitiator0)
		$oDestIG_after = Get-XIOInitiatorGroup -URI $oTestIG0.URI

		$intNumNewInitiatorsInIG = $oDestIG_after.NumInitiator - $oDestIG_before.NumInitiator
		## the target InitiatorGroup should have one more Initiator in it, now
		$intNumNewInitiatorsInIG | Should Be 1
		$oNewInitiator0 | Should BeOfType [XioItemInfo.Initiator]
	}

	It "Creates a new Initiator using colon-delimited port address notation, placing it in an existing InitiatorGroup" {
		## grab this IG from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one InitiatorGroup has been made in the course of this testing
		$oTestIG0 = $hshXioObjsToRemove["InitiatorGroup"] | Select-Object -First 1
		$oDestIG_before = Get-XIOInitiatorGroup -URI $oTestIG0.URI
		$oNewInitiator1 = New-XIOInitiator -Name "mysvr0-hba3$strNameToAppend" -InitiatorGroup $oTestIG0.name -PortAddress ${strInitiatorAddrPrefix}:00:00:00:00:54 @hshCommonParamsForNewObj
		$hshXioObjsToRemove["Initiator"] += @($oNewInitiator1)
		$oDestIG_after = Get-XIOInitiatorGroup -URI $oTestIG0.URI

		$intNumNewInitiatorsInIG = $oDestIG_after.NumInitiator - $oDestIG_before.NumInitiator
		## the target InitiatorGroup should have one more Initiator in it, now
		$intNumNewInitiatorsInIG | Should Be 1
		$oNewInitiator1 | Should BeOfType [XioItemInfo.Initiator]
	}

	## run this test if the XtremIO API version is at least v2.0
	if ($oXioConnectionToUse.RestApiVersion -ge [System.Version]"2.0") {
		It "Creates a new Initiator using colon-delimited port address notation, placing it in an existing InitiatorGroup, and specifying an OperatingSystem" {
			## grab this IG from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one InitiatorGroup has been made in the course of this testing
			$oTestIG0 = $hshXioObjsToRemove["InitiatorGroup"] | Select-Object -First 1
			$oDestIG_before = Get-XIOInitiatorGroup -URI $oTestIG0.URI
			$oNewInitiator2 = New-XIOInitiator -Name "mysvr0-hba5$strNameToAppend" -InitiatorGroup $oTestIG0.name -PortAddress ${strInitiatorAddrPrefix}:00:00:00:00:56 -OperatingSystem ESX @hshCommonParamsForNewObj
			$oDestIG_after = Get-XIOInitiatorGroup -URI $oTestIG0.URI
			$hshXioObjsToRemove["Initiator"] += @($oNewInitiator2)

			$intNumNewInitiatorsInIG = $oDestIG_after.NumInitiator - $oDestIG_before.NumInitiator
			## the target InitiatorGroup should have one more Initiator in it, now
			$intNumNewInitiatorsInIG | Should Be 1
			$oNewInitiator2 | Should BeOfType [XioItemInfo.Initiator]
			$oNewInitiator2.OperatingSystem | Should Be "ESX"
		}
	} ## end if
	else {Write-Verbose -Verbose "XtremIO API is older than v2.0 -- not testing setting OperatingSystem at new Initiator creation time"}
}

Describe -Tags "New" -Name "New-XIOInitiatorGroupFolder" {
	It "Creates a new IGFolder" {
		$oNewIGFolder = New-XIOInitiatorGroupFolder -Name "myIGFolder$strNameToAppend" -ParentFolder / -ComputerName $strXmsComputerName
		$hshXioObjsToRemove["IGFolder"] += @($oNewIGFolder)
		$oNewIGFolder | Should BeOfType [XioItemInfo.IgFolder]
	}
}

Describe -Tags "New" -Name "New-XIOVolumeGroupFolder" {
	It "Creates a new VolumeFolder" {
		$oNewVolFolder = New-XIOVolumeFolder -Name "myVolFolder$strNameToAppend" -ParentFolder / -ComputerName $strXmsComputerName
		$hshXioObjsToRemove["VolumeFolder"] += @($oNewVolFolder)
		$oNewVolFolder | Should BeOfType [XioItemInfo.VolumeFolder]
	}
}

Describe -Tags "New" -Name "New-XIOVolume" {
	It "Creates a new Volume for a single-cluster XMS connection" {
		$oNewVol = New-XIOVolume -Name "testvol0$strNameToAppend" -SizeGB 10 -ComputerName $strXmsComputerName
		$hshXioObjsToRemove["Volume"] += @($oNewVol)
		$oNewVol | Should BeOfType [XioItemInfo.Volume]
	}

	It "Creates a new Volume for a single-cluster XMS connection, specifying the VolumeFolder in which to create the Volume" {
		## grab a VolumeFolder from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one VolumeFolder has been made in the course of this testing
		$oTestVolFolder0 = $hshXioObjsToRemove["VolumeFolder"] | Select-Object -First 1
		$oNewVol =  New-XIOVolume -ComputerName $strXmsComputerName -Name "testvol1$strNameToAppend" -SizeGB 10 -ParentFolder $oTestVolFolder0.Name
		$hshXioObjsToRemove["Volume"] += @($oNewVol)
		$oNewVol | Should BeOfType [XioItemInfo.Volume]
		$oNewVol.Folder.Name | Should Be $oTestVolFolder0.FullName
	}

	It "Creates a new Volume for a specified cluster and XMS connection, enabling the three Alerts available on a Volume object" {
		$oNewVol =  New-XIOVolume -Name "testvol2$strNameToAppend" -SizeGB 10 -EnableSmallIOAlert -EnableUnalignedIOAlert -EnableVAAITPAlert @hshCommonParamsForNewObj
		$hshXioObjsToRemove["Volume"] += @($oNewVol)
		$oNewVol | Should BeOfType [XioItemInfo.Volume]
		"SmallIOAlertsCfg", "UnalignedIOAlertsCfg", "VaaiTPAlertsCfg" | Foreach-Object {$oNewVol.$_ | Should Be "enabled"}
	}
}

Describe -Tags "New" -Name "New-XIOLunMap" {
	It "Creates a new LunMap" {
		$intLunIdForNewLunMap = 173
		## grab some IGs and a Volume from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least two InitiatorGroups and one Volume have been made in the course of this testing
		$oTestIG0, $oTestIG1 = $hshXioObjsToRemove["InitiatorGroup"] | Select-Object -First 2
		$oTestVolume = $hshXioObjsToRemove["Volume"] | Select-Object -First 1
		$arrNewLunMap = New-XIOLunMap -Volume $oTestVolume.Name -InitiatorGroup $oTestIG0.name,$oTestIG1.name -HostLunId $intLunIdForNewLunMap @hshCommonParamsForNewObj
		$hshXioObjsToRemove["LunMap"] += $arrNewLunMap
		$arrNewLunMap | Foreach-Object {
			$oThisNewLunMap = $_
			$oThisNewLunMap | Should BeOfType [XioItemInfo.LunMap]
			$oThisNewLunMap.VolumeName | Should Be $oTestVolume.Name
			$oThisNewLunMap.LunId | Should Be $intLunIdForNewLunMap
		} ## end foreach-object
	}
}

Describe -Tags "New" -Name "New-XIOSnapshot" {
	It "Creates a new regular Snapshot for each of two (2) Volumes by name, specifying the SnapshotSuffix and a name for the new SnapshotSet that will contain both" {
		## grab some Volumes from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least two Volumes have been made in the course of this testing
		$oTestVolume0, $oTestVolume1 = $hshXioObjsToRemove["Volume"] | Select-Object -First 2
		$strNameForNewSnapshotSet = "SnapSet0$strNameToAppend"; $strValueForSnapshotSuffix = "SnapTest"
		$arrNewSnapshot = New-XIOSnapshot -Volume $oTestVolume0.Name,$oTestVolume1.Name -SnapshotSuffix $strValueForSnapshotSuffix -NewSnapshotSetName $strNameForNewSnapshotSet @hshCommonParamsForNewObj
		$hshXioObjsToRemove["Snapshot"] += $arrNewSnapshot
		$hshXioObjsToRemove["SnapshotSet"] += $arrNewSnapshot | Foreach-Object {Get-XIOSnapshotSet -Name $_.SnapshotSet.Name @hshCommonParamsForNewObj} | Select-Object -Unique

		$arrNewSnapshot | Foreach-Object {
			$oThisNewSnapshot = $_
			$oThisNewSnapshot | Should BeOfType [XioItemInfo.Snapshot]
			$oThisNewSnapshot.Type | Should Be "Regular"
			$oThisNewSnapshot.SnapshotSet.Name | Should Be $strNameForNewSnapshotSet
			$oThisNewSnapshot.Name | Should BeLike "*$strValueForSnapshotSuffix"
		} ## end foreach-object
	}

	It "Creates a new ReadOnly Snapshot for one Volume by pipeline, specifying a name for the new SnapshotSet that will contain the Snapshot" {
		## grab some Volumes from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one Volume has been made in the course of this testing
		$oTestVolume0 = $hshXioObjsToRemove["Volume"] | Select-Object -First 1
		$strNameForNewSnapshotSet = "SnapSet1$strNameToAppend"
		$oNewSnapshot = Get-XIOVolume -Name $oTestVolume0.Name @hshCommonParamsForNewObj | New-XIOSnapshot -Type ReadOnly -NewSnapshotSetName $strNameForNewSnapshotSet
		$hshXioObjsToRemove["Snapshot"] += @($oNewSnapshot)
		$hshXioObjsToRemove["SnapshotSet"] += @($oNewSnapshot | Foreach-Object {Get-XIOSnapshotSet -Name $_.SnapshotSet.Name @hshCommonParamsForNewObj} | Select-Object -Unique)

		$oNewSnapshot | Foreach-Object {
			$oThisNewSnapshot = $_
			$oThisNewSnapshot | Should BeOfType [XioItemInfo.Snapshot]
			$oThisNewSnapshot.Type | Should Be "ReadOnly"
			$oThisNewSnapshot.SnapshotSet.Name | Should Be $strNameForNewSnapshotSet
			$oThisNewSnapshot.Name | Should BeLike "*$strValueForSnapshotSuffix"
		} ## end foreach-object
	}

	It "Creates a new regular Snapshot for the Volumes in a SnapshotSet, specifying the SnapshotSuffix a name for the new SnapshotSet that will contain the Snapshots" {
		## grab some Volumes from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one SnapshotSet has been made in the course of this testing
		$oTestSnapshotSet = $hshXioObjsToRemove["SnapshotSet"] | Select-Object -First 1
		$strNameForNewSnapshotSet = "SnapSet2$strNameToAppend"; $strValueForSnapshotSuffix = "addlSnap.now"
		$arrNewSnapshot = New-XIOSnapshot -SnapshotSet $oTestSnapshotSet.Name -SnapshotSuffix $strValueForSnapshotSuffix -NewSnapshotSetName $strNameForNewSnapshotSet
		$hshXioObjsToRemove["Snapshot"] += $arrNewSnapshot
		$hshXioObjsToRemove["SnapshotSet"] += @($arrNewSnapshot | Foreach-Object {Get-XIOSnapshotSet -Name $_.SnapshotSet.Name @hshCommonParamsForNewObj} | Select-Object -Unique)

		$arrNewSnapshot | Foreach-Object {
			$oThisNewSnapshot = $_
			$oThisNewSnapshot | Should BeOfType [XioItemInfo.Snapshot]
			$oThisNewSnapshot.Type | Should Be "Regular"
			$oThisNewSnapshot.SnapshotSet.Name | Should Be $strNameForNewSnapshotSet
			$oThisNewSnapshot.Name | Should BeLike "*$strValueForSnapshotSuffix"
		} ## end foreach-object
	}
}

$hshXioObjsToRemove


## for remove:
# should remove in particular order of:  LunMap (so can then remove InitiatorGroups), then Snapshot (so that all Snapshots are still Snapshots, instead of having been transformed into Volumes by action of having all ancestor volumes removed), then <all the rest>

<#
## Create a new tag "MyVols", nested in the "/Volume" parent tag, to be used for Volume entities. This example highlights the behavior that, if no explicit "path" specified to the tag, the new tag is put at the root of its parent tag, based on the entity type
New-XIOTag -Name MyVols$strNameToAppend -EntityType Volume
## Create a new tag "superImportantVols", nested in the "/Volume/MyVols/someOtherTag" parent tag, to be used for Volume entities.  Notice that none of the "parent" tags needed to exist before issuing this command -- the are created appropriately as required for creating the "leaf" tag.
New-XIOTag -Name /Volume/MyVols2/someOtherTag/superImportantVols$strNameToAppend -EntityType Volume
New-XIOTag -Name /X-Brick/MyTestXBrickTag$strNameToAppend -EntityType Brick

## create new users
## Create a new UserAccount with the read_only role, and with the given username/password. Uses default inactivity timeout configured on the XMS
New-XIOUserAccount -Credential (Get-Credential test_RoUser) -Role read_only
## Create a new UserAccount with the read_only role, and with the given username/password. Sets "no timeout"
New-XIOUserAccount -UserName test_CfgUser -Role configuration -UserPublicKey $strThisPubKey -InactivityTimeout 0

## 	Create a new, empty ConsistencyGroup
New-XIOConsistencyGroup -Name myConsGrp0
## Create a new ConsistencyGroup that contains the volumes specified
New-XIOConsistencyGroup -Name myConsGrp1 -Volume coolVol0,coolVol1
## Create a new ConsistencyGroup that contains the volumes specified
New-XIOConsistencyGroup -Name myConsGrp2 -Volume (Get-XIOVolume coolVol*2016,coolVol[01])
## Create a new ConsistencyGroup that contains the volumes on XIO cluster "myCluster0" that are tagged with either "someImportantVolsTag" or "someImportantVolsTag2"
New-XIOConsistencyGroup -Name myConsGrp3 -Tag (Get-XIOTag /Volume/someImportantVolsTag,/Volume/someImportantVolsTag2) -Cluster myCluster0
Get-XIOConsistencyGroup someGrp0 | New-XIOSnapshot -Type ReadOnly -NewSnapshotSetName "SnapSet2$strNameToAppend"

## new XIO Snapshot Schedulers (cannot yet specify new scheduler name via the API -- no way to do so, or, no documented way, at least)
## from Volume, using interval between snapshots, specifying particular number of Snapshots to retain
New-XIOSnapshotScheduler -Enabled:$false -RelatedObject (Get-XIOVolume someVolume0) -Interval (New-Timespan -Days 2 -Hours 6 -Minutes 9) -SnapshotRetentionCount 20
## from a ConsistencyGroup, with an explict schedule, specifying duration for which to keep Snapshots
New-XIOSnapshotScheduler -Enabled:$false -RelatedObject (Get-XIOConsistencyGroup testCG0) -ExplicitDay Sunday -ExplicitTimeOfDay 10:16pm -SnapshotRetentionDuration (New-Timespan -Days 10 -Hours 12)
## from a SnapshotSet
Get-XIOSnapshotSet -Name testSnapshotSet0.1455845074 | New-XIOSnapshotScheduler -Enabled:$false -ExplicitDay EveryDay -ExplicitTimeOfDay 3am -SnapshotRetentionCount 500 -Suffix myScheduler0
## from a Tag (several types) -- NOT YET SUPPORTED by API; API reference says that Tag List is a source object, but the API returns error that only Volume, ConsistencyGroup, SnapshotSet are valid (XIOS 4.0.2-80)
#  from a Volume tag, using interval between snapshots
#New-XIOSnapshotScheduler -Enabled:$false -RelatedObject (Get-XIOTag /Volume/testVolTag) -Interval (New-Timespan -Days 1) -SnapshotRetentionCount 100
#  from a SnapshotSet tag, scheduled everyday at midnight
#New-XIOSnapshotScheduler -Enabled:$false -RelatedObject (Get-XIOTag /SnapshotSet/testSnapshotSetTag) -ExplicitDay Everyday -ExplicitTimeOfDay 12am -SnapshotRetentionDuration (New-Timespan -Days 31 -Hours 5)
#  from a ConsistencyGroup tag, on given day, with suffix
#New-XIOSnapshotScheduler -Enabled:$false -RelatedObject (Get-XIOTag /ConsistencyGroup/testCGTag) -ExplicitDay Thursday -ExplicitTimeOfDay 19:30 -SnapshotRetentionCount 5 -Suffix myImportantSnap

## for multiple clusters in this XMS connection
$arrNewVol_other = New-XIOVolume -Name "testvol10$strNameToAppend" -Cluster myxio05,myxio06 -SizeGB 1024
## to do after ability to create new Tag assignments, so that there will be test volumes with test tags applied
#New-XIOSnapshot -Tag /Volume/myCoolVolTag0 -NewSnapshotSetName "SnapSet5$strNameToAppend"
#Get-XIOTag /Volume/myCoolVolTag* | New-XIOSnapshot -Type ReadOnly -NewSnapshotSetName "SnapSet6$strNameToAppend"

## for removes:
## removing an InitiatorGroup or Volume that is part of a LunMap should Throw!
#>
