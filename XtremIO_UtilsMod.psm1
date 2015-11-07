## dot-source the config items file
. $PSScriptRoot\configItems.ps1

## dot-source the function-definition files, class-definition file
"GetXIOItem.ps1", "NewXIOItem.ps1", "OtherXIOMgmt.ps1", "XtremIO.Utils.init.ps1" | Foreach-Object {
	. $PSScriptRoot\$_
} ## end foreach-object

## export these items for use by consumer
Export-ModuleMember -Function Get-XIOItemInfo, Get-XIOAlert, Get-XIOAlertDefinition, Get-XIOBBU, Get-XIOBrick, Get-XIOConsistencyGroup, Get-XIOCluster, Get-XIODAE, Get-XIODAEController, Get-XIODAEPsu, Get-XIODataProtectionGroup, Get-XIOEmailNotifier, Get-XIOEvent, Get-XIOInitiator, Get-XIOInitiatorGroup, Get-XIOInitiatorGroupFolder, Get-XIOLdapConfig, Get-XIOLocalDisk, Get-XIOLunMap, Get-XIOSlot, Get-XIOSnapshot, Get-XIOSnapshotSet, Get-XIOSnapshotScheduler, Get-XIOSnmpNotifier, Get-XIOSsd, Get-XIOStorageController, Get-XIOStorageControllerPsu, Get-XIOTarget, Get-XIOTargetGroup, Get-XIOUserAccount, Get-XIOVolume, Get-XIOVolumeFolder, Get-XIOXenv, Open-XIOMgmtConsole, Get-XIOStoredCred, Get-XIOXMS, New-XIOStoredCred, Remove-XIOStoredCred, Update-TitleBarForXioConnection, Connect-XIOServer, Disconnect-XIOServer,
	## performance items
	Get-XIOClusterPerformance, Get-XIODataProtectionGroupPerformance, Get-XIOInitiatorGroupFolderPerformance, Get-XIOInitiatorGroupPerformance, Get-XIOInitiatorPerformance, Get-XIOSsdPerformance, Get-XIOTargetPerformance, Get-XIOVolumeFolderPerformance, Get-XIOVolumePerformance,
	## "New-" items
	New-XIOInitiator, New-XIOInitiatorGroup, New-XIOInitiatorGroupFolder, New-XIOLunMap, New-XIOVolume, New-XIOVolumeFolder
