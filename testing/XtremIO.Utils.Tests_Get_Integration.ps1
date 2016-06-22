<#	.Description
	Pester integration tests for XtremIO.Utils PowerShell module, for testing the interplay between cmdlets.  Expects that:
	0) XtremIO.Utils module is already loaded (but, will try to load it if not)
	1) a connection to at least one XMS is in place (but, will prompt for XMS to which to connect if not)
#>

## initialize things, preparing for tests
. $PSScriptRoot\XtremIO.Utils.TestingInit.ps1


# ## for each of the object types whose typenames match the object name in the cmdlet noun, test getting such an object
# $arrXioObjectTypesToGet = Write-Output Alert, BBU, Brick, Cluster, ClusterPerformance, ConsistencyGroup, DAE, DAEController, DAEPsu, DataProtectionGroup, DataProtectionGroupPerformance, EmailNotifier, Event, InfinibandSwitch, Initiator, InitiatorGroup, InitiatorGroupPerformance, InitiatorPerformance, LdapConfig, LocalDisk, LunMap, PerformanceCounter, Slot, Snapshot, SnapshotScheduler, SnapshotSet, SnmpNotifier, Ssd, SsdPerformance, StorageController, StorageControllerPsu, SyslogNotifier, Tag, Target, TargetGroup, TargetPerformance, UserAccount, Volume, VolumeFolder, VolumeFolderPerformance, VolumePerformance, Xenv, XMS
# $arrXioObjectTypesToGet | Foreach-Object {
# 	Describe -Tags "Get" -Name "Get-XIO$_" {
# 	    It "Gets an XIO $_ object" {
# 	 		$arrReturnTypes = if ($arrTmpObj = Invoke-Command -ScriptBlock {& "Get-XIO$_"}) {$arrTmpObj | Get-Member -ErrorAction:Stop | Select-Object -Unique -ExpandProperty TypeName} else {$null}
# 	    	New-Variable -Name "bGetsOnly${_}Type" -Value ($arrReturnTypes -eq "XioItemInfo.$_")
# 	    	(Get-Variable -ValueOnly -Name "bGetsOnly${_}Type") | Should Be $true
# 	    }
# 	}
# }

## all types:
# $arrXioRelatedObjectTypesToAccept = Write-Output BBU, Brick, Cluster, ClusterPerformance, ConsistencyGroup, DAE, DAEController, DAEPsu, DataProtectionGroup, DataProtectionGroupPerformance, EmailNotifier, Event, InfinibandSwitch, Initiator, InitiatorGroup, InitiatorGroupPerformance, InitiatorPerformance, LdapConfig, LocalDisk, LunMap, PerformanceCounter, Slot, Snapshot, SnapshotScheduler, SnapshotSet, SnmpNotifier, Ssd, SsdPerformance, StorageController, StorageControllerPsu, SyslogNotifier, Tag, Target, TargetGroup, TargetPerformance, UserAccount, Volume, VolumeFolder, VolumeFolderPerformance, VolumePerformance, Xenv, XMS

## hashtable of Types to test and the corresponding "RelatedObject" Types that each should accept
$hshTypesToGetFromRelatedObjInfo = [ordered]@{
	BBU = Write-Output Brick, StorageController
	Brick = Write-Output BBU, Cluster, DAE, DAEController, DAEPsu, DataProtectionGroup, LocalDisk, Slot, Ssd, StorageController, StorageControllerPsu, Target, Xenv
	Cluster = Write-Output BBU, Brick, ConsistencyGroup, DAE, DAEController, DAEPsu, DataProtectionGroup, InfinibandSwitch, Initiator, InitiatorGroup, LocalDisk, LunMap, Slot, Snapshot, SnapshotSet, Ssd, StorageController, StorageControllerPsu, Target, TargetGroup, Volume, Xenv
	ConsistencyGroup = Write-Output Snapshot, SnapshotScheduler, SnapshotSet, Volume
	DAE = Write-Output Brick, DAEController, DAEPsu
	DataProtectionGroup = Write-Output Brick, Ssd, StorageController
	InfinibandSwitch = Write-Output Cluster
	InitiatorGroup = Write-Output Initiator, InitiatorGroupFolder, LunMap, Snapshot, Volume
	InitiatorGroupFolder = Write-Output InitiatorGroup, InitiatorGroupFolder
	LocalDisk = Write-Output StorageController
	Snapshot = Write-Output InitiatorGroup, Snapshot, SnapshotSet, Volume, VolumeFolder
	SnapshotSet = Write-Output Snapshot, SnapshotScheduler, Volume
} ## end hash

$hshTypesToGetFromRelatedObjInfo.GetEnumerator() | Foreach-Object {
	$strXIOObjectTypeToGet = $_.Key
	$strXIOObjReturnTypeShortname = if ($strXIOObjectTypeToGet -ne "InitiatorGroupFolder") {$strXIOObjectTypeToGet} else {"IgFolder"}
	$arrXioRelatedObjectTypesToAccept = $_.Value
	Describe -Tags "Get" -Name "Get-XIO$strXIOObjectTypeToGet" {
		$arrXioRelatedObjectTypesToAccept | Foreach-Object {
			$strThisRelatedObjectType = $_
			## Get related objects.  These will be used to test the targeted cmdlet
			$arrRelatedObjects = Switch ($strXIOObjectTypeToGet) {
				## specific tests for Get-XIOSnapshotSet with RelatedObject of Snapshot or Volume, get such items that have SnapshotSet property populated
				{($_ -eq "SnapshotSet") -and ("Snapshot","Volume" -contains $strThisRelatedObjectType)} {& "Get-XIO$strThisRelatedObjectType" | Where-Object {($_.SnapshotSet | Measure-Object).Count -gt 0} | Select-Object -First 5; break}
				## Get up to five of the related objects
				default {& "Get-XIO$strThisRelatedObjectType" | Select-Object -First 5}
			} ## end switch
			It "Gets XIO $strXIOObjReturnTypeShortname object, based on related $strThisRelatedObjectType object" {
		 		$arrReturnTypes = if ($arrTmpObj = Invoke-Command -ScriptBlock {& "Get-XIO$strXIOObjectTypeToGet" -RelatedObject $arrRelatedObjects}) {$arrTmpObj | Get-Member -ErrorAction:Stop | Select-Object -Unique -ExpandProperty TypeName} else {$null}
		    	New-Variable -Name "bGetsOnly${strXIOObjReturnTypeShortname}Type" -Value ($arrReturnTypes -eq "XioItemInfo.$strXIOObjReturnTypeShortname")
		    	(Get-Variable -ValueOnly -Name "bGetsOnly${strXIOObjReturnTypeShortname}Type") | Should Be $true
			}
			It "Gets XIO $strXIOObjReturnTypeShortname object, based on related $strThisRelatedObjectType object from pipeline" {
		 		$arrReturnTypes = if ($arrTmpObj = Invoke-Command -ScriptBlock {$arrRelatedObjects | & "Get-XIO$strXIOObjectTypeToGet"}) {$arrTmpObj | Get-Member -ErrorAction:Stop | Select-Object -Unique -ExpandProperty TypeName} else {$null}
		    	New-Variable -Name "bGetsOnly${strXIOObjReturnTypeShortname}Type" -Value ($arrReturnTypes -eq "XioItemInfo.$strXIOObjReturnTypeShortname")
		    	(Get-Variable -ValueOnly -Name "bGetsOnly${strXIOObjReturnTypeShortname}Type") | Should Be $true
			}
		} ## end foreach-object
	} ## end describe
} ## end foreach-object


## tests for cmdlets that do not support all of the standard features given above
Describe -Tags "Get" -Name "Get-XIOInitiator" {
	$strXIOObjectTypeToGet = "Initiator"
	"InitiatorGroup" | Foreach-Object {
		$strThisRelatedObjectType = $_
		## Get up to two of the related objects.  These will be used to test the targeted cmdlet
		$arrRelatedObjects = & "Get-XIO$strThisRelatedObjectType" | Select-Object -First 2
		It "Gets XIO $strXIOObjectTypeToGet object, based on $strThisRelatedObjectType object ID" {
	 		$arrReturnTypes = if ($arrTmpObj = Invoke-Command -ScriptBlock {& "Get-XIO$strXIOObjectTypeToGet" -InitiatorGrpId $arrRelatedObjects.InitiatorGrpId}) {$arrTmpObj | Get-Member -ErrorAction:Stop | Select-Object -Unique -ExpandProperty TypeName} else {$null}
	    	New-Variable -Name "bGetsOnly${strXIOObjectTypeToGet}Type" -Value ($arrReturnTypes -eq "XioItemInfo.$strXIOObjectTypeToGet")
	    	(Get-Variable -ValueOnly -Name "bGetsOnly${strXIOObjectTypeToGet}Type") | Should Be $true
		}
		It "Gets XIO $strXIOObjectTypeToGet object, based on related $strThisRelatedObjectType object from pipeline" {
	 		$arrReturnTypes = if ($arrTmpObj = Invoke-Command -ScriptBlock {$arrRelatedObjects | & "Get-XIO$strXIOObjectTypeToGet"}) {$arrTmpObj | Get-Member -ErrorAction:Stop | Select-Object -Unique -ExpandProperty TypeName} else {$null}
	    	New-Variable -Name "bGetsOnly${strXIOObjectTypeToGet}Type" -Value ($arrReturnTypes -eq "XioItemInfo.$strXIOObjectTypeToGet")
	    	(Get-Variable -ValueOnly -Name "bGetsOnly${strXIOObjectTypeToGet}Type") | Should Be $true
		}
	} ## end foreach-object
} ## end describe
