<#	.Description
	Pester tests for XtremIO.Utils PowerShell module.  Expects that:
	0) XtremIO.Utils module is already loaded (but, will try to load it if not)
	1) a connection to at least one XMS is in place (but, will prompt for XMS to which to connect if not)
#>

$strXioModuleName = "XtremIO.Utils"
## if module not already loaded, try to load it (assumes that module is in PSModulePath)
if (-not ($oModuleInfo = Get-Module $strXioModuleName)) {
	$oModuleInfo = Import-Module $strXioModuleName -PassThru
	if (-not ($oModuleInfo -is [System.Management.Automation.PSModuleInfo])) {Throw "Could not load module '$strXioModuleName' -- is it available in the PSModulePath? You can manually load the module and start tests again"}
} ## end if
Write-Verbose -Verbose ("Starting testing of module '{0}' (version '{1}' from '{2}')" -f $oModuleInfo.Name, $oModuleInfo.Version, $oModuleInfo.Path)

## get the XIO connection to use
$oXioConnectionToUse = if (-not (($DefaultXmsServers | Measure-Object).Count -gt 0)) {
	$hshParamForConnectXioServer = @{ComputerName = $(Read-Host -Prompt "XMS computer name to which to connect for testing"); TrustAllCert = $true}
	Connect-XIOServer @hshParamForConnectXioServer
} ## end if
else {$DefaultXmsServers[0]}
$strXmsComputerName = $oXioConnectionToUse.ComputerName
Write-Verbose -Verbose "Testing using all XMS connections, generally, but single-XMS tests are using computer name of '$strXmsComputerName'"

## get the XIO cluster name to use for -Cluster param testing -- use the first cluster available in the oXioConnectionToUse
$strClusterNameToUse = (Get-XIOCluster -ComputerName $strXmsComputerName | Select-Object -First 1).Name
Write-Verbose -Verbose "Testing using all XIO clusters, generally, but single-cluster tests are using cluster name of '$strClusterNameToUse'"


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
		$bChildTypenamesAreExpected | Should Be $true
	}
}

## for each cmdlet that supports -Cluster param, test getting such an object, specifying -Cluster for each test (the object types' typenames happen to match the object name in the cmdlet noun)
$arrXioCmdletsSupportingClusterParam = Write-Output BBU, Brick, ConsistencyGroup, DAE, DAEController, DAEPsu, DataProtectionGroup, Initiator, InitiatorGroup, LocalDisk, LunMap, Slot, Snapshot, SnapshotSet, Ssd, StorageController, StorageControllerPsu, Target, TargetGroup, Volume, Xenv
$arrXioCmdletsSupportingClusterParam | Foreach-Object {
	Describe -Tags "Get","ClusterSpecific" -Name "Get-XIO$_ (Cluster-specific)" {
	    It "Gets an XIO $_ object, uses -Cluster param" {
	 		$arrReturnTypes = if ($arrTmpObj = Invoke-Command -ScriptBlock {& "Get-XIO$_" -Cluster $strClusterNameToUse}) {$arrTmpObj | Get-Member -ErrorAction:Stop | Select-Object -Unique -ExpandProperty TypeName} else {$null}
	    	New-Variable -Name "bGetsOnly${_}Type" -Value ($arrReturnTypes -eq "XioItemInfo.$_")
	    	(Get-Variable -ValueOnly -Name "bGetsOnly${_}Type") | Should Be $true
	    }
	}
}
