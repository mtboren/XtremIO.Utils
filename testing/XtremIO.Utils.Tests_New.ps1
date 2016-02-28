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
$oNewIG2 = New-XIOInitiatorGroup -Name "testIG2$strNameToAppend" -Cluster myCluster0 -InitiatorList @{"myserver2-hba2$strNameToAppend" = "10:00:00:00:00:00:00:F6"; "myserver2-hba3$strNameToAppend" = "10:00:00:00:00:00:00:F7"}
New-XIOInitiator -Name "mysvr0-hba2$strNameToAppend" -InitiatorGroup $oNewIG2.name -PortAddress 0x100000000000ab56
New-XIOInitiator -Name "mysvr0-hba3$strNameToAppend" -InitiatorGroup $oNewIG2.name -PortAddress 10:00:00:00:00:00:00:54
New-XIOInitiator -Name "mysvr0-hba4$strNameToAppend" -Cluster myCluster0 -InitiatorGroup $oNewIG2.name -PortAddress 10:00:00:00:00:00:00:55
New-XIOInitiatorGroupFolder -Name "myIGFolder$strNameToAppend" -ParentFolder /
#New-XIOLunMap -Volume someVolume02 -InitiatorGroup myIG0,myIG1 -HostLunId 21
#New-XIOLunMap -Volume someVolume03 -Cluster myCluster0 -InitiatorGroup myIG0,myIG1 -HostLunId 22
$oNewVolFolder0 = New-XIOVolumeFolder -Name "myVolFolder$strNameToAppend" -ParentFolder /
$oNewVol0 = New-XIOVolume -Name "testvol03$strNameToAppend" -SizeGB 10
$oNewVol1 = New-XIOVolume -ComputerName $strXmsComputerName -Name "testvol04$strNameToAppend" -SizeGB 5120 -ParentFolder $oNewVolFolder0.Name
$oNewVol2 = New-XIOVolume -Name "testvol05$strNameToAppend" -SizeGB 5KB -EnableSmallIOAlert -EnableUnalignedIOAlert -EnableVAAITPAlert
$arrNewVol_other = New-XIOVolume -Name "testvol10$strNameToAppend" -Cluster myxio05,myxio06 -SizeGB 1024
New-XIOSnapshot -Volume $oNewVol0.Name,$oNewVol1.Name -SnapshotSuffix "snap$strNameToAppend"
New-XIOSnapshot -Volume $oNewVol0.Name,$oNewVol1.Name -Cluster myCluster03
Get-XIOVolume -Name $oNewVol0.Name,$oNewVol1.Name | New-XIOSnapshot -Type ReadOnly
#Get-XIOConsistencyGroup someGrp[01] | New-XIOSnapshot -Type ReadOnly
#New-XIOSnapshot -SnapshotSet SnapshotSet.1449941173 -SnapshotSuffix addlSnap.now -Type Regular
#New-XIOSnapshot -Tag /Volume/myCoolVolTag0
#Get-XIOTag /Volume/myCoolVolTag* | New-XIOSnapshot -Type ReadOnly
#>