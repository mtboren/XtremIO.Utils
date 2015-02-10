## dot-source the config items file
. $PSScriptRoot\configItems.ps1

## dot-source the function-definition files, class-definition file
"GetXIOItem.ps1", "NewXIOItem.ps1", "OtherXIOMgmt.ps1", "SetXIOItem.ps1", "XtremIO.Utils.init.ps1" | Foreach-Object {
	. $PSScriptRoot\$_
} ## end foreach-object

## export these items for use by consumer
Export-ModuleMember -Function Get-XIOItemInfo, Get-XIOBrick, Get-XIOCluster, Get-XIODataProtectionGroup, Get-XIOEvent, Get-XIOInitiator, Get-XIOInitiatorGroup, Get-XIOInitiatorGroupFolder, Get-XIOLunMap, Get-XIOSnapshot, Get-XIOSsd, Get-XIOStorageController, Get-XIOTarget, Get-XIOTargetGroup, Get-XIOVolume, Get-XIOVolumeFolder, Get-XIOXenv, Open-XIOMgmtConsole, Get-XIOStoredCred, New-XIOStoredCred, Remove-XIOStoredCred, Update-TitleBarForXioConnection, Connect-XIOServer, Disconnect-XIOServer,
	## "Get-XIOPerformanceInfo" -- not exported when dev is done for given release
	#Get-XIOPerformanceInfo,
	## performance items
	Get-XIOClusterPerformance, Get-XIODataProtectionGroupPerformance, Get-XIOInitiatorGroupFolderPerformance, Get-XIOInitiatorGroupPerformance, Get-XIOInitiatorPerformance, Get-XIOSsdPerformance, Get-XIOTargetPerformance, Get-XIOVolumeFolderPerformance, Get-XIOVolumePerformance,
	## "New-" items
	New-XIOInitiator, New-XIOInitiatorGroup, New-XIOInitiatorGroupFolder, New-XIOLunMap, New-XIOVolume, New-XIOVolumeFolder,
	## "Set-" items
	Set-XIOVolumeFolder,
	## exported for now -- remove at release time
	Set-XIOItemInfo
