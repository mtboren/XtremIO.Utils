<#	.Description
	Pester tests for New-XIO* cmdlets for XtremIO.Utils PowerShell module.  Expects that:
	0) XtremIO.Utils module is already loaded (but, will try to load it if not)
	1) a connection to at least one XMS is in place (but, will prompt for XMS to which to connect if not)
#>

## initialize things, preparing for tests
. $PSScriptRoot\XtremIO.Utils.TestingInit.ps1

## string to append (including a GUID) to all new objects created, to avoid any naming conflicts
$strNameToAppend = "_testItemToDelete_{0}" -f [System.Guid]::NewGuid().Guid.Replace("-","")

Write-Warning "no automatic tests yet defined for New-XIO* cmdlets"


<#
## test making new things; will need to capture the new items, and return them as items for tester to remove (or, auto-remove them?)
## should test against XIOS v3 (XIO API v1) and XIOS v4+ (XIO API v2), at least
$oNewIG0 = New-XIOInitiatorGroup -Name "testIG0$strNameToAppend"  ## without "-Cluster" in multicluster instance, fails
## IG for XIOS older than v3 (testing the extra double-quotes needed in the older XIOS)
$oNewIG1 = New-XIOInitiatorGroup -Name "testIG1$strNameToAppend" -ParentFolder / -InitiatorList @{'"myserver-hba2$strNameToAppend"' = '"10:00:00:00:00:00:00:F4"'; '"myserver-hba3$strNameToAppend"' = '"10:00:00:00:00:00:00:F5"'}
## IG for XIOS v3 and newer
$oNewIG2 = New-XIOInitiatorGroup -Name "testIG2$strNameToAppend" -Cluster $strClusterNameToUse -InitiatorList @{"myserver2-hba2$strNameToAppend" = "10:00:00:00:00:00:00:F6"; "myserver2-hba3$strNameToAppend" = "10:00:00:00:00:00:00:F7"}
New-XIOInitiator -Name "mysvr0-hba2$strNameToAppend" -InitiatorGroup $oNewIG2.name -PortAddress 0x100000000000ab56
New-XIOInitiator -Name "mysvr0-hba3$strNameToAppend" -InitiatorGroup $oNewIG2.name -PortAddress 10:00:00:00:00:00:00:54
New-XIOInitiator -Name "mysvr0-hba4$strNameToAppend" -Cluster $strClusterNameToUse -InitiatorGroup $oNewIG2.name -PortAddress 10:00:00:00:00:00:00:55
New-XIOInitiator -Name "mysvr0-hba5$strNameToAppend" -Cluster $strClusterNameToUse -InitiatorGroup $oNewIG2.name -PortAddress 10:00:00:00:00:00:00:56 -OperatingSystem ESX
New-XIOInitiatorGroupFolder -Name "myIGFolder$strNameToAppend" -ParentFolder /
$oNewVolFolder0 = New-XIOVolumeFolder -Name "myVolFolder$strNameToAppend" -ParentFolder /
## for single-cluster XMS connections
$oNewVol0 = New-XIOVolume -Name "testvol03$strNameToAppend" -SizeGB 10
$oNewVol1 = New-XIOVolume -ComputerName $strXmsComputerName -Name "testvol04$strNameToAppend" -SizeGB 5120 -ParentFolder $oNewVolFolder0.Name
$oNewVol2 = New-XIOVolume -Name "testvol05$strNameToAppend" -SizeGB 5KB -EnableSmallIOAlert -EnableUnalignedIOAlert -EnableVAAITPAlert
#New-XIOLunMap -Volume $oNewVol0.Name -InitiatorGroup $oNewIG0.name,$oNewIG2.name -HostLunId 21
#New-XIOLunMap -Volume $oNewVol1.Name -Cluster $strClusterNameToUse -InitiatorGroup $oNewIG0.name,$oNewIG2.name -HostLunId 22
## for multi-cluster XMS connections
$oNewVol3 = New-XIOVolume -Name "testvol06$strNameToAppend" -SizeGB 10 -Cluster $strClusterNameToUse
$oNewVol5 = New-XIOVolume -Name "testvol08$strNameToAppend" -SizeGB 5KB -EnableSmallIOAlert -EnableUnalignedIOAlert -EnableVAAITPAlert -Cluster $strClusterNameToUse
$arrNewVol_other = New-XIOVolume -Name "testvol10$strNameToAppend" -Cluster myxio05,myxio06 -SizeGB 1024
New-XIOLunMap -Volume $oNewVol3.Name -InitiatorGroup $oNewIG1.name,$oNewIG2.name -HostLunId 121 -Cluster $strClusterNameToUse
New-XIOLunMap -Volume $oNewVol5.Name -InitiatorGroup $oNewIG1.name,$oNewIG2.name -HostLunId 122 -Cluster $strClusterNameToUse
New-XIOSnapshot -Volume $oNewVol3.Name,$oNewVol5.Name -SnapshotSuffix "snap$strNameToAppend"
New-XIOSnapshot -Volume $oNewVol3.Name,$oNewVol5.Name -Cluster $strClusterNameToUse
Get-XIOVolume -Name $oNewVol3.Name,$oNewVol5.Name | New-XIOSnapshot -Type ReadOnly
#Get-XIOConsistencyGroup someGrp[01] | New-XIOSnapshot -Type ReadOnly
#New-XIOSnapshot -SnapshotSet SnapshotSet.1449941173 -SnapshotSuffix addlSnap.now -Type Regular
#New-XIOSnapshot -Tag /Volume/myCoolVolTag0
#Get-XIOTag /Volume/myCoolVolTag* | New-XIOSnapshot -Type ReadOnly
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
#>
