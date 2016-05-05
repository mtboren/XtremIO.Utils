<#	.Description
	Pester tests for XtremIO.Utils PowerShell module.  Expects that:
	0) XtremIO.Utils module is already loaded (but, will try to load it if not)
	1) a connection to at least one XMS is in place (but, will prompt for XMS to which to connect if not)
#>

## initialize things, preparing for tests
. $PSScriptRoot\XtremIO.Utils.TestingInit.ps1


## for each of the object types whose typenames match the object name in the cmdlet noun, test getting such an object
$arrXioObjectTypesToGet = Write-Output Alert, BBU, Brick, Cluster, ClusterPerformance, ConsistencyGroup, DAE, DAEController, DAEPsu, DataProtectionGroup, DataProtectionGroupPerformance, EmailNotifier, Event, InfinibandSwitch, Initiator, InitiatorGroup, InitiatorGroupPerformance, InitiatorPerformance, LdapConfig, LocalDisk, LunMap, PerformanceCounter, Slot, Snapshot, SnapshotScheduler, SnapshotSet, SnmpNotifier, Ssd, SsdPerformance, StorageController, StorageControllerPsu, SyslogNotifier, Tag, Target, TargetGroup, TargetPerformance, UserAccount, Volume, VolumeFolder, VolumeFolderPerformance, VolumePerformance, Xenv, XMS
$arrXioObjectTypesToGet | Foreach-Object {
	Describe -Tags "Get" -Name "Get-XIO$_" {
	    It "Gets an XIO $_ object" {
	 		$arrReturnTypes = if ($arrTmpObj = Invoke-Command -ScriptBlock {& "Get-XIO$_"}) {$arrTmpObj | Get-Member -ErrorAction:Stop | Select-Object -Unique -ExpandProperty TypeName} else {$null}
	    	New-Variable -Name "bGetsOnly${_}Type" -Value ($arrReturnTypes -eq "XioItemInfo.$_")
	    	(Get-Variable -ValueOnly -Name "bGetsOnly${_}Type") | Should Be $true
	    }
	}
}

## for each of the object types whose typenames match the object name in the cmdlet noun, and it is far quicker to get at least one such item by a standard name, test getting such an object
@{AlertDefinition = "alert_def_dae_inaccessible"}.GetEnumerator() | Foreach-Object {
	$strObjNounName = $_.Name
	$strObjValue = $_.Value
	Describe -Tags "Get" -Name "Get-XIO$strObjNounName -Name " {
	    It "Gets an XIO $strObjNounName object" {
	 		$arrReturnTypes = if ($arrTmpObj = Invoke-Command -ScriptBlock {& "Get-XIO$strObjNounName" -Name $strObjValue}) {$arrTmpObj | Get-Member | Select-Object -Unique -ExpandProperty TypeName} else {$null}
	    	New-Variable -Name "bGetsOnly${strObjNounName}Type" -Value ($arrReturnTypes -eq "XioItemInfo.$strObjNounName")
	    	(Get-Variable -ValueOnly -Name "bGetsOnly${strObjNounName}Type") | Should Be $true
	    }
	}
}

## for each of the object types whose typenames do not match the object name in the cmdle noun, test getting such an object
@{InitiatorGroupFolder = "XioItemInfo.IgFolder";
  InitiatorGroupFolderPerformance = "XioItemInfo.IgFolderPerformance";
  StoredCred = "System.Management.Automation.PSCredential"}.GetEnumerator() | Foreach-Object {
	$strObjNounName = $_.Name
	Describe -Tags "Get" -Name "Get-XIO$strObjNounName" {
	    It "Gets object of type $($_.Value)" {
	 		$arrReturnTypes = Invoke-Command -ScriptBlock {& "Get-XIO$strObjNounName"} | Get-Member | Select-Object -Unique -ExpandProperty TypeName
	    	New-Variable -Name "bGetsOnly${strObjNounName}Type" -Value ($arrReturnTypes -eq $_.Value)
	    	(Get-Variable -ValueOnly -Name "bGetsOnly${strObjNounName}Type") | Should Be $true
	    }
	}
}

Describe -Tags "Get" -Name "Get-XIOItemInfo" {
	It "Gets XIO initiator objects as directed, and from specified computername" {
		$arrReturnTypes = Get-XIOItemInfo -ComputerName $strXmsComputerName -ItemType initiator | Get-Member | Select-Object -Unique -ExpandProperty TypeName
		$bGetsOnlyInitiatorType = $arrReturnTypes -eq "XioItemInfo.Initiator"
		$bGetsOnlyInitiatorType | Should Be $true
	}

	It "Gets XIO volume objects as directed" {
		$arrReturnTypes = Get-XIOItemInfo -ItemType volume | Get-Member | Select-Object -Unique -ExpandProperty TypeName
		$bGetsOnlyVolumeType = $arrReturnTypes -eq "XioItemInfo.Volume"
    	$bGetsOnlyVolumeType | Should Be $true
	}

	It "Gets XIO cluster objects by default, and returns full response when so directed" {
		$oFullResponse = Get-XIOItemInfo -ReturnFullResponse
		$bLinkHrefIsAClusterType = $oFullResponse.links[0].href -like "https://${strXmsComputerName}/api/json/types/clusters/*"
		$bLinkHrefHasContentAndLinksProperties = ($oFullResponse | Get-Member -Name content,links | Measure-Object).Count -eq 2
		$bLinkHrefIsAClusterType | Should Be $true
		$bLinkHrefHasContentAndLinksProperties | Should Be $true
	}

	It "Gets XIO type items from URI, and returns children types of given names" {
		$arrChildrenInfo = Get-XIOItemInfo -Uri "https://${strXmsComputerName}/api/json/types" -ReturnFullResponse | Select-Object -ExpandProperty children
		## the names should include these object type names; all of the -contains comparisons should be $true, so the Select-Object -Unique should return a single $true for the value
		$bChildTypenamesAreExpected = Write-Output bricks, initiators, snapshots, volumes, xenvs | Foreach-Object {$arrChildrenInfo.name -contains $_} | Select-Object -Unique
		## there should only be one type for this value -- a Boolean (not an array of Booleans, which would be $true and $false)
		$bChildTypenamesAreExpected | Should BeOfType [System.Boolean]
		## and, it should be $true
		$bChildTypenamesAreExpected | Should Be $true
	}
}

Describe -Tags "Get" -Name "Get-XIOLunMap (choice properties)" {
	It "Gets XIO LUN Map objects as directed, retrieving just the given properties" {
		$arrReturnTypes = Get-XIOLunMap -ComputerName $strXmsComputerName -Property VolumeName,LunId | Get-Member | Select-Object -Unique -ExpandProperty TypeName
		$bGetsOnlyLunMapType = $arrReturnTypes -eq "XioItemInfo.LunMap"
		$bGetsOnlyLunMapType | Should Be $true
	}
	It "Gets XIO LUN Map objects as directed, retrieving just the given properties (another version of the test)" {
		$arrReturnTypes = Get-XIOLunMap -ComputerName $strXmsComputerName -Property guid,vol-name,ig-name,tg-name | Get-Member | Select-Object -Unique -ExpandProperty TypeName
		$bGetsOnlyLunMapType = $arrReturnTypes -eq "XioItemInfo.LunMap"
		$bGetsOnlyLunMapType | Should Be $true
	}
}

## for each cmdlet that supports -Cluster param, test getting such an object, specifying -Cluster for each test (the object types' typenames happen to match the object name in the cmdlet noun)
$arrXioCmdletsSupportingClusterParam = Write-Output BBU, Brick, ConsistencyGroup, DAE, DAEController, DAEPsu, DataProtectionGroup, Initiator, InitiatorGroup, LocalDisk, LunMap, Slot, Snapshot, SnapshotSet, Ssd, StorageController, StorageControllerPsu, Target, TargetGroup, Volume, Xenv, DataProtectionGroupPerformance, InitiatorGroupPerformance, InitiatorPerformance, SsdPerformance, TargetPerformance, VolumePerformance, PerformanceCounter
$arrXioCmdletsSupportingClusterParam | Foreach-Object {
	Describe -Tags "Get","ClusterSpecific" -Name "Get-XIO$_ (Cluster-specific for targeted XMS)" {
	    It "Gets an XIO $_ object, uses -Cluster param" {
	 		$arrReturnTypes = if ($arrTmpObj = Invoke-Command -ScriptBlock {& "Get-XIO$_" -ComputerName $strXmsComputerName -Cluster $strClusterNameToUse}) {$arrTmpObj | Get-Member -ErrorAction:Stop | Select-Object -Unique -ExpandProperty TypeName} else {$null}
	    	New-Variable -Name "bGetsOnly${_}Type" -Value ($arrReturnTypes -eq "XioItemInfo.$_")
	    	(Get-Variable -ValueOnly -Name "bGetsOnly${_}Type") | Should Be $true
	    }
	}
}
