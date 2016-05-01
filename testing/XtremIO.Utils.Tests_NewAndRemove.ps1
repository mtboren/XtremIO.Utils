<#	.Description
	Pester tests for New-XIO* cmdlets for XtremIO.Utils PowerShell module.  Expects that:
	0) XtremIO.Utils module is already loaded (but, will try to load it if not)
	1) a connection to at least one XMS is in place (but, will prompt for XMS to which to connect if not)
#>

## initialize things, preparing for tests; provides $oXioConnectionToUse, $strXmsComputerName, and $strClusterNameToUse
. $PSScriptRoot\XtremIO.Utils.TestingInit.ps1

## string to append (including a GUID) to all new objects created, to avoid any naming conflicts
$strNameToAppend = "_testItemToDelete_{0}" -f [System.Guid]::NewGuid().Guid.Replace("-","")
Write-Verbose -Verbose "Suffix used for new objects for this test:  $strNameToAppend"
## bogus OUI for making sure that the addresses of the intiators created here do not conflict with any real-world addresses
$strInitiatorAddrPrefix = "EE:EE:EE"
## random hex value to use for four hex-pairs in the port addresses, to avoid address conflicts if testing multiple times without removing newly created test objects (with particular port addresses)
$strInitiatorRandomEightHexChar = "{0:x}" -f (Get-Random -Maximum ([Int64]([System.Math]::pow(16,8) - 1)))
$strInitiatorRandomEightHexChar_ColonJoined = ($strInitiatorRandomEightHexChar -split "(\w{2})" | Where-Object {$_ -ne ""}) -join ":"
## hashtable to keep the variables that hold the newly created objects, so that these objects can be removed from the XMS later; making it a global variable, so that consumer has it for <anything they desire> after testing
$global:hshXioObjsToRemove = [ordered]@{}
$hshCommonParamsForNewObj = @{ComputerName =  $strXmsComputerName; Cluster = $strClusterNameToUse}

Write-Warning "no fully-automatic tests yet defined for Remove-XIO* cmdlets -- they still require confirmation (for safety's sake)"

Write-Verbose -Verbose "Getting current counts of each object type of interest, for comparison to counts after testing"
## the types of interest
$arrTypesToCount = Write-Output InitiatorGroup Initiator InitiatorGroupFolder VolumeFolder Volume ConsistencyGroup Snapshot SnapshotScheduler LunMap Tag UserAccount
$arrTypesToCount | Foreach-Object -Begin {$hshTypeCounts_before = @{}} -Process {$hshTypeCounts_before[$_] = Invoke-Command -ScriptBlock {(& "Get-XIO$_" | Measure-Object).Count}}


## test making new things; saves the new items in a hashtable, which is then used for the Remove-XIO* testing (which then removes them)
## should test against XIOS v3 (XIO API v1) and XIOS v4+ (XIO API v2), at least

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
				InitiatorList = @{"`"myserver-hba2$strNameToAppend`"" = "`"${strInitiatorAddrPrefix}:${strInitiatorRandomEightHexChar_ColonJoined}:F4`""; "`"myserver-hba3$strNameToAppend`"" = "`"${strInitiatorAddrPrefix}:${strInitiatorRandomEightHexChar_ColonJoined}:F5`""}
				ParentFolder = "/"
			}
		} else {
			@{InitiatorList = @{"myserver-hba2$strNameToAppend" = "${strInitiatorAddrPrefix}:${strInitiatorRandomEightHexChar_ColonJoined}:F4"; "myserver-hba3$strNameToAppend" = "${strInitiatorAddrPrefix}:${strInitiatorRandomEightHexChar_ColonJoined}:F5"}}
		}
		## new InitiatorGroup
		$oNewIG1 = New-XIOInitiatorGroup -Name "testIG1$strNameToAppend" @hshNewIGParam @hshCommonParamsForNewObj
		$hshXioObjsToRemove["InitiatorGroup"] += @($oNewIG1)
		$arrNewInitiators_thisIG = $oNewIG1 | Get-XIOInitiator
		$hshXioObjsToRemove["Initiator"] += @($arrNewInitiators_thisIG)

		$oNewIG1 | Should BeOfType [XioItemInfo.InitiatorGroup]
		$arrNewInitiators_thisIG | Foreach-Object {$_ | Should BeOfType [XioItemInfo.Initiator]}
		$oNewIG1.NumInitiator | Should Be 2
	}
}


Describe -Tags "New" -Name "New-XIOInitiator" {
	It "Creates a new Initiator using Hex port address notation, placing it in an existing InitiatorGroup" {
		## grab this IG from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one InitiatorGroup has been made in the course of this testing
		$oTestIG0 = $hshXioObjsToRemove["InitiatorGroup"] | Select-Object -First 1
		$oDestIG_before = Get-XIOInitiatorGroup -URI $oTestIG0.URI
		$oNewInitiator0 = New-XIOInitiator -Name "mysvr0-hba2$strNameToAppend" -InitiatorGroup $oTestIG0.name -PortAddress ("0x{0}{1}cd" -f $strInitiatorAddrPrefix.Replace(":", ""), $strInitiatorRandomEightHexChar) @hshCommonParamsForNewObj
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
		$oNewInitiator1 = New-XIOInitiator -Name "mysvr0-hba3$strNameToAppend" -InitiatorGroup $oTestIG0.name -PortAddress ${strInitiatorAddrPrefix}:${strInitiatorRandomEightHexChar_ColonJoined}:54 @hshCommonParamsForNewObj
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
			$oNewInitiator2 = New-XIOInitiator -Name "mysvr0-hba5$strNameToAppend" -InitiatorGroup $oTestIG0.name -PortAddress ${strInitiatorAddrPrefix}:${strInitiatorRandomEightHexChar_ColonJoined}:56 -OperatingSystem ESX @hshCommonParamsForNewObj
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
		$hshXioObjsToRemove["InitiatorGroupFolder"] += @($oNewIGFolder)
		$oNewIGFolder | Should BeOfType [XioItemInfo.IgFolder]
	}
}


Describe -Tags "New" -Name "New-XIOVolumeFolder" {
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


Describe -Tags "New" -Name "New-XIOConsistencyGroup" {
	It "Creates a new ConsistencyGroup that contains the volumes specified" {
		$intNumVolForConsistencyGroup = 2
		## grab some Volumes from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least two Volumes have been made in the course of this testing
		$arrTestVolume = $hshXioObjsToRemove["Volume"] | Select-Object -First $intNumVolForConsistencyGroup
		$oNewConsistencyGroup = New-XIOConsistencyGroup -Name myConsGrp0$strNameToAppend -Volume $arrTestVolume @hshCommonParamsForNewObj
		$hshXioObjsToRemove["ConsistencyGroup"] += @($oNewConsistencyGroup)

		$oNewConsistencyGroup | Should BeOfType [XioItemInfo.ConsistencyGroup]
		$oNewConsistencyGroup.NumVol | Should Be $intNumVolForConsistencyGroup
	}
}


Describe -Tags "New" -Name "New-XIOSnapshot" {
	It "Creates a new regular Snapshot for each of two (2) Volumes by name, specifying the SnapshotSuffix and a name for the new SnapshotSet that will contain both" {
		## grab some Volumes from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least two Volumes have been made in the course of this testing
		$oTestVolume0, $oTestVolume1 = $hshXioObjsToRemove["Volume"] | Select-Object -First 2
		$strNameForNewSnapshotSet = "SnapSet0$strNameToAppend"; $strValueForSnapshotSuffix = "SnapTest"
		$arrNewSnapshot = New-XIOSnapshot -Volume $oTestVolume0.Name,$oTestVolume1.Name -SnapshotSuffix $strValueForSnapshotSuffix -NewSnapshotSetName $strNameForNewSnapshotSet @hshCommonParamsForNewObj
		$hshXioObjsToRemove["Snapshot"] += $arrNewSnapshot
		$hshXioObjsToRemove["SnapshotSet"] += @(Get-XIOSnapshotSet -Name $arrNewSnapshot.SnapshotSet.Name @hshCommonParamsForNewObj | Select-Object -Unique)

		$arrNewSnapshot | Foreach-Object {
			$oThisNewSnapshot = $_
			$oThisNewSnapshot | Should BeOfType [XioItemInfo.Snapshot]
			$oThisNewSnapshot.Type | Should Be "Regular"
			$oThisNewSnapshot.SnapshotSet.Name | Should Be $strNameForNewSnapshotSet
			$oThisNewSnapshot.Name | Should BeLike "*$strValueForSnapshotSuffix"
		} ## end foreach-object
	}

	It "Creates a new ReadOnly Snapshot for one Volume by pipeline, specifying a name for the new SnapshotSet that will contain the Snapshot" {
		## grab a Volume from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one Volume has been made in the course of this testing
		$oTestVolume0 = $hshXioObjsToRemove["Volume"] | Select-Object -First 1
		$strNameForNewSnapshotSet = "SnapSet1$strNameToAppend"
		## should already have ComputerName and Cluster from the Volume, so not specifying here for New-XIOSnapshot
		$oNewSnapshot = Get-XIOVolume -Name $oTestVolume0.Name @hshCommonParamsForNewObj | New-XIOSnapshot -Type ReadOnly -NewSnapshotSetName $strNameForNewSnapshotSet
		$hshXioObjsToRemove["Snapshot"] += @($oNewSnapshot)
		$hshXioObjsToRemove["SnapshotSet"] += @(Get-XIOSnapshotSet -Name $oNewSnapshot.SnapshotSet.Name @hshCommonParamsForNewObj | Select-Object -Unique)

		$oNewSnapshot | Foreach-Object {
			$oThisNewSnapshot = $_
			$oThisNewSnapshot | Should BeOfType [XioItemInfo.Snapshot]
			$oThisNewSnapshot.Type | Should Be "ReadOnly"
			$oThisNewSnapshot.SnapshotSet.Name | Should Be $strNameForNewSnapshotSet
		} ## end foreach-object
	}

	It "Creates a new regular Snapshot for the Volumes in a SnapshotSet, specifying the SnapshotSuffix and a name for the new SnapshotSet that will contain the Snapshots" {
		## grab a SnapshotSet from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one SnapshotSet has been made in the course of this testing
		$oTestSnapshotSet = $hshXioObjsToRemove["SnapshotSet"] | Select-Object -First 1
		$strNameForNewSnapshotSet = "SnapSet2$strNameToAppend"; $strValueForSnapshotSuffix = "addlSnap.now"
		$arrNewSnapshot = New-XIOSnapshot -SnapshotSet $oTestSnapshotSet.Name -SnapshotSuffix $strValueForSnapshotSuffix -NewSnapshotSetName $strNameForNewSnapshotSet @hshCommonParamsForNewObj
		$hshXioObjsToRemove["Snapshot"] += $arrNewSnapshot
		$hshXioObjsToRemove["SnapshotSet"] += @(Get-XIOSnapshotSet -Name $arrNewSnapshot.SnapshotSet.Name @hshCommonParamsForNewObj | Select-Object -Unique)

		$arrNewSnapshot | Foreach-Object {
			$oThisNewSnapshot = $_
			$oThisNewSnapshot | Should BeOfType [XioItemInfo.Snapshot]
			$oThisNewSnapshot.Type | Should Be "Regular"
			$oThisNewSnapshot.SnapshotSet.Name | Should Be $strNameForNewSnapshotSet
			$oThisNewSnapshot.Name | Should BeLike "*$strValueForSnapshotSuffix"
		} ## end foreach-object
	}

	It "Creates a new ReadOnly Snapshot for the Volumes in a ConsistencyGroup, specifying a name for the new SnapshotSet that will contain the Snapshots" {
		## grab a ConsistencyGroup from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one ConsistencyGroup has been made in the course of this testing
		$oTestConsistencyGroup = $hshXioObjsToRemove["ConsistencyGroup"] | Select-Object -First 1
		$strNameForNewSnapshotSet = "SnapSet3$strNameToAppend"
		## should already have ComputerName and Cluster from the ConsistencyGroup, so not specifying here
		$arrNewSnapshot = $oTestConsistencyGroup | New-XIOSnapshot -Type ReadOnly -NewSnapshotSetName $strNameForNewSnapshotSet
		$hshXioObjsToRemove["Snapshot"] += $arrNewSnapshot
		$hshXioObjsToRemove["SnapshotSet"] += @(Get-XIOSnapshotSet -Name $arrNewSnapshot.SnapshotSet.Name @hshCommonParamsForNewObj | Select-Object -Unique)

		$arrNewSnapshot | Foreach-Object {
			$oThisNewSnapshot = $_
			$oThisNewSnapshot | Should BeOfType [XioItemInfo.Snapshot]
			$oThisNewSnapshot.Type | Should Be "ReadOnly"
			$oThisNewSnapshot.SnapshotSet.Name | Should Be $strNameForNewSnapshotSet
		} ## end foreach-object
	}
} ## end describing New-XIOSnapshot


## test creating new XIO SnapshotSchedulers (cannot yet specify new scheduler name via the API -- no way to do so, or, no documented way, at least)
Describe -Tags "New" -Name "New-XIOSnapshotScheduler" {
	It "Creates a new (disabled) SnapshotScheduler from a Volume, using interval between snapshots, specifying particular number of regular Snapshots to retain" {
		$intSnapshotRetentionCount = 20
		## grab a Volume from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one Volume has been made in the course of this testing
		$oTestVolume0 = $hshXioObjsToRemove["Volume"] | Select-Object -First 1
		$oNewSnapshotScheduler = New-XIOSnapshotScheduler -Enabled:$false -RelatedObject $oTestVolume0 -Interval (New-Timespan -Days 2 -Hours 6 -Minutes 9) -SnapshotRetentionCount $intSnapshotRetentionCount -ComputerName $strXmsComputerName
		$hshXioObjsToRemove["SnapshotScheduler"] += @($oNewSnapshotScheduler)

		$oNewSnapshotScheduler | Should BeOfType [XioItemInfo.SnapshotScheduler]
		$oNewSnapshotScheduler.Enabled | Should Be $false
		$oNewSnapshotScheduler.NumSnapToKeep | Should Be $intSnapshotRetentionCount
		$oNewSnapshotScheduler.SnapType | Should Be "Regular"
		$oNewSnapshotScheduler.Type | Should Be "interval"
	}

	It "Creates a new (disabled) SnapshotScheduler from a ConsistencyGroup, with an explicit schedule (vs. an interval), specifying a duration for which to keep the ReadOnly Snapshots" {
		$tspSnapshotRetentionDuration = New-Timespan -Days 10 -Hours 12
		## grab a ConsistencyGroup from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one ConsistencyGroup has been made in the course of this testing
		$oTestConsistencyGroup = $hshXioObjsToRemove["ConsistencyGroup"] | Select-Object -First 1
		$oNewSnapshotScheduler = New-XIOSnapshotScheduler -Enabled:$false -RelatedObject $oTestConsistencyGroup -ExplicitDay Sunday -ExplicitTimeOfDay 10:16pm -SnapshotRetentionDuration $tspSnapshotRetentionDuration -SnapshotType ReadOnly -ComputerName $strXmsComputerName
		$hshXioObjsToRemove["SnapshotScheduler"] += @($oNewSnapshotScheduler)

		$oNewSnapshotScheduler | Should BeOfType [XioItemInfo.SnapshotScheduler]
		$oNewSnapshotScheduler.Enabled | Should Be $false
		$oNewSnapshotScheduler.SnapType | Should Be "ReadOnly"
		$oNewSnapshotScheduler.Retain | Should Be $tspSnapshotRetentionDuration
		$oNewSnapshotScheduler.Type | Should Be "explicit"
	}

	It "Creates a new (disabled) SnapshotScheduler from a SnapshotSet, by pipeline, using an explicit schedule of everyday, and specifying the number of regular Snapshots to retain" {
		$intSnapshotRetentionCount = 500; $strSuffix = "myTestScheduler0"
		## grab a SnapshotSet from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one SnapshotSet has been made in the course of this testing
		$oTestSnapshotSet = $hshXioObjsToRemove["SnapshotSet"] | Select-Object -First 1
		$oNewSnapshotScheduler = $oTestSnapshotSet | New-XIOSnapshotScheduler -Enabled:$false -ExplicitDay EveryDay -ExplicitTimeOfDay 3am -SnapshotRetentionCount $intSnapshotRetentionCount -Suffix $strSuffix  -ComputerName $strXmsComputerName
		$hshXioObjsToRemove["SnapshotScheduler"] += @($oNewSnapshotScheduler)

		$oNewSnapshotScheduler | Should BeOfType [XioItemInfo.SnapshotScheduler]
		$oNewSnapshotScheduler.Enabled | Should Be $false
		$oNewSnapshotScheduler.NumSnapToKeep | Should Be $intSnapshotRetentionCount
		$oNewSnapshotScheduler.SnapType | Should Be "Regular"
		$oNewSnapshotScheduler.Suffix | Should Be $strSuffix
		$oNewSnapshotScheduler.Type | Should Be "explicit"
	}
} ## end describing New-XIOSnapshotScheduler


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


Describe -Tags "New" -Name "New-XIOTag" {
	It "Creates a new tag to be used for Volume entities" {
		## This example highlights the behavior that, if no explicit "path" specified to the tag, the new tag is put at the root of its parent tag, based on the entity type
		$strEntityType = "Volume"
		$oNewTag = New-XIOTag -Name v$strNameToAppend -EntityType $strEntityType -ComputerName $strXmsComputerName
		$hshXioObjsToRemove["Tag"] += @($oNewTag)

		$oNewTag | Should BeOfType [XioItemInfo.Tag]
		$oNewTag.ObjectType | Should Be $strEntityType
	}

	It "Creates a new tag nested in the another Volume parent tag, to be used for Volume entities" {
		$strEntityType = "Volume"
		## grab some Volume Tag from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one volume Tag has been made in the course of this testing
		$oTestVolTag = $hshXioObjsToRemove["Tag"] | Where-Object {$_.ObjectType -eq $strEntityType} | Select-Object -First 1
		$oNewTag = New-XIOTag -Name "$($oTestVolTag.Name)/subF" -EntityType $strEntityType -ComputerName $strXmsComputerName
		$hshXioObjsToRemove["Tag"] += @($oNewTag)

		$oNewTag | Should BeOfType [XioItemInfo.Tag]
		$oNewTag.ObjectType | Should Be $strEntityType
		$oNewTag.ParentTag.Name | Should Be $oTestVolTag.Name
	}
}


Describe -Tags "New" -Name "New-XIOUserAccount" {
	It "Creates a new UserAccount with the read_only role, and with the given username/password. Uses default inactivity timeout configured on the XMS" {
		$strRole = "read_only"
		## create a new UserAccount with Credentials for auth; obviously a weak/fake password, and this is not the way that one should use the cmdlet in general practice:  static here for the testing aspect
		$oNewUserAccount = New-XIOUserAccount -Credential (New-Object System.Management.Automation.PSCredential("test_RoUser$strNameToAppend", ("someGre@tPasswordHere" | ConvertTo-SecureString -AsPlainText -Force))) -Role $strRole -ComputerName $strXmsComputerName
		$hshXioObjsToRemove["UserAccount"] += @($oNewUserAccount)

		$oNewUserAccount | Should BeOfType [XioItemInfo.UserAccount]
		$oNewUserAccount.Role | Should Be $strRole
		$oNewUserAccount.IsExternal | Should Be $false
	}
}


Describe -Tags "Remove" -Name "Remove-XIOInitiatorGroup_shouldThrow" {
	Context "InitiatorGroup is part of a LunMap" {
		It "Tries to remove an InitiatorGroup that is part of a LunMap, which should fail" {
			## grab an IG from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one InitiatorGroup has been made in the course of this testing
			$oTestIG = $hshXioObjsToRemove["InitiatorGroup"] | Select-Object -First 1
			## update the InitiatorGroup object, to make sure that it has the current property values of the server-side object
			$oUpdatedTestIGObj = Get-XIOInitiatorGroup -URI $oTestIG.Uri
			{$oUpdatedTestIGObj | Remove-XIOInitiatorGroup} | Should Throw
		}
	}
}


## not in use for now
# Describe -Tags "Remove" -Name "Remove-XIOVolume_shouldThrow" {
# 	Context "Volume is part of a LunMap" {
# 		It "Tries to remove an Volume that is part of a LunMap, which should fail" {
# 			## grab a Volume from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one Volume has been made in the course of this testing, and that this Volume is part of a LunMap
# 			$oTestVolume = $hshXioObjsToRemove["Volume"] | Select-Object -First 1
# 			## update the Volume object, to make sure that it has the current property values of the server-side object
# 			$oUpdatedTestVolObj = Get-XIOVolume -URI $oTestVolume.Uri
# 			$oUpdatedTestVolObj.LunMapList.Count | Should BeGreaterThan 0
# 			{$oUpdatedTestVolObj | Remove-XIOVolume} | Should Throw
# 		}
# 	}

# 	Context "Volume is part of a ConsistencyGroup" {
# 		It "Tries to remove an Volume that is part of a ConsistencyGroup, which should fail" {
# 			## grab a Volume from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one Volume has been made in the course of this testing, and that this Volume is part of a ConsistencyGroup
# 			$oTestVolume = $hshXioObjsToRemove["Volume"] | Select-Object -First 1
# 			## update the Volume object, to make sure that it has the current property values of the server-side object
# 			$oUpdatedTestVolObj = Get-XIOVolume -URI $oTestVolume.Uri
# 			$oUpdatedTestVolObj.ConsistencyGroup.Count | Should BeGreaterThan 0
# 			{$oUpdatedTestVolObj | Remove-XIOVolume} | Should Throw
# 		}
# 	}

# 	Context "Volume is part of a SnapshotScheduler" {
# 		It "Tries to remove an Volume that is part of a SnapshotScheduler, which should fail" {
# 			## grab a Volume from the hashtable that is in the parent scope, as the scopes between tests are unique; expects that at least one Volume has been made in the course of this testing, and that this Volume is part of a SnapshotScheduler
# 			$oTestVolume = $hshXioObjsToRemove["Volume"] | Select-Object -First 1
# 			{$oTestVolume | Remove-XIOVolume} | Should Throw
# 		}
# 	}
# }

## For the removal of all objects that were created while testing the New-XIO* cmdlets above:
## the order in which types should be removed, so as to avoid removal issues (say, due to a Volume being part of a LunMap, and the likes)
# should then remove in particular order of:
#	SnapshotScheduler (so then can remove ConsistencyGroups, SnapshotSets, and Volumes),
#	ConsistencyGroup (so can then remove Volumes),
#	LunMap (so can then remove InitiatorGroups),
#	Snapshot (so that all Snapshots are still Snapshots, instead of having been transformed into Volumes by action of having all ancestor volumes removed),
#	Initiator (so that they still exist, vs. having been indirectly removed by having removed InitiatorGroups)
#	then <all the rest>
$arrTypeSpecificRemovalOrder = Write-Output SnapshotScheduler ConsistencyGroup LunMap Snapshot Initiator
## then, the order-specific types, plus the rest of the types that were created during the New-XIO* testing, so as to be sure to removal all of the new test objects created:
$arrOverallTypeToRemove_InOrder = $arrTypeSpecificRemovalOrder + @($hshXioObjsToRemove.Keys | Where-Object {$arrTypeSpecificRemovalOrder -notcontains $_})

## for each of the types to remove, and in order, if there were objects of this type created, remove them
$arrOverallTypeToRemove_InOrder | Foreach-Object {
	$strThisTypeToRemove = $_
	Describe -Tags "Remove" -Name "Remove-XIO$strThisTypeToRemove" {
		It "Removes a $strThisTypeToRemove (all that were created in New-XIO* testing)" {
			## grab the objects from the hashtable that is in the parent scope, as the scopes between tests are unique
			$arrTestObjToRemove = $hshXioObjsToRemove[$strThisTypeToRemove]
			$intNumObjToRemove = ($arrTestObjToRemove | Measure-Object).Count
			Write-Verbose -Verbose ("will attempt to remove {0} '{1}' object{2}" -f $intNumObjToRemove, $strThisTypeToRemove, $(if ($intNumObjToRemove -ne 1) {"s"}))
			## should remove without issue; need to use "Remove-XIOVolume" for removing Snapshots, since that cmdlet is for removing both Volumes and Snapshots
			$strCmdletNounPortion = if ($strThisTypeToRemove -eq "Snapshot") {"Volume"} else {$strThisTypeToRemove}
			## if these are the Tag objects, sort descending by the Tag CreationTime, so that the remove tests will try to remove the newest first (which should be any "nested" Tags first), so as to try to avoid getting in a test scenario where a child Tag is already deleted by the action of having deleted its parent Tag, so the test of deleting the child Tag would fail (Tag not found)
			if ($strThisTypeToRemove -eq "Tag") {$arrTestObjToRemove = $arrTestObjToRemove | Sort-Object -Property CreationTime -Descending}
			$arrTestObjToRemove | Foreach-Object {
				$oThisObjToRemove = $_
				{Invoke-Command -ScriptBlock {& "Remove-XIO$strCmdletNounPortion" $oThisObjToRemove}} | Should Not Throw
			} ## end foreach-object
			## trying to get the objects with the given URIs should now fail, as those objects should have been removed
			$arrTestObjToRemove | Foreach-Object {
				$oThisObjToRemove = $_
				## try to get the object at the given URI -- should throw, along with write some verbose output, which is being redirect to Out-Null here (the Verbose stream is stream #4)
				{Invoke-Command -ScriptBlock {& "Get-XIO$strThisTypeToRemove" -URI $oThisObjToRemove.URI 4>Out-Null}} | Should Throw
			} ## end foreach-object
		} ## end it
	} ## end describe
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

<#
## for removes:
## removing a ConsistencyGroup that is part of a SnapshotScheduler should Throw!
## for removing Tags, should either remove leaf Tags first, or, if removing parent tags first that had child Tags, do not later try to remove child Tag (they'll already be gone)
#>


<#
##### Other New-XIO* tests to do, eventually
## New-XIOSnapshotScheduler from a Tag (several types) -- NOT YET SUPPORTED by API; API reference says that Tag List is a source object, but the API returns error that only Volume, ConsistencyGroup, SnapshotSet are valid (XIOS 4.0.2-80)
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
## Create a new ConsistencyGroup that contains the volumes on XIO cluster "myCluster0" that are tagged with either "someImportantVolsTag" or "someImportantVolsTag2"
#New-XIOConsistencyGroup -Name myConsGrp3 -Tag (Get-XIOTag /Volume/someImportantVolsTag,/Volume/someImportantVolsTag2) -Cluster myCluster0
#>
