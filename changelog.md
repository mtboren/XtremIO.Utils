## XtremIO.Utils PowerShell module ##

### Changelog ###
### v0.8.0

Several great improvements in this release, most of which were centered around adding pipelining support for objects returns from cmdlets (hurray for all of us, especially Greg D.).  These required updates that ranged from defining legitimate Types to adding more parameters on cmdlets to adding/renaming properties to/on objects.  Some of these property- and object name changes could affect existing scripts that leverage the module, but were necessary for adherence to things like .NET standards. The list of changes/updates:

- \[improvement] added parameters to `New-XIOVolume` cmdlet: can now set `SmallIoAlerts`, `UnalignedIoAlerts`, and `VaaiTpAlerts` volume properties to `enabled` or `disabled`; implemented as switch params
- \[update] published the function `Update-TitleBarForXioConnection` so that user can invoke said function at will (it is what sets the PowerShell window title bar with XIO connection info, and is invoked internally by the `Connect-XIOServer` / `Disconnect-XIOServer` cmdlets)
- \[improvement] defined output types made by module, used `Add-Type` to add them to session at module load time. This required renaming types and properties (boo for that) that had a dash in their name to not have a dash (.NET properties should not have a dash)
	- types renamed:

			"Data-Protection-Group" -> DataProtectionGroup
			"Data-Protection-GroupPerformance" -> DataProtectionGroupPerformance
			"Ig-Folder" -> IgFolder
			"Ig-FolderPerformance" -> IgFolderPerformance
			"Initiator-Group" -> InitiatorGroup
			"Initiator-GroupPerformance" -> InitiatorGroupPerformance
			"Lun-Map" -> LunMap
			"Storage-Controller" -> StorageController
			"Target-Group" -> TargetGroup
			"Volume-Folder" -> VolumeFolder
			"Volume-FolderPerformance" -> VolumeFolderPerformance
	- properties renamed across all object types that had them:

			"brick-id" -> BrickId
			"rg-id" -> RGrpId
			"ssd-slot-array" -> SsdSlotInfo
			"xms-id" -> XmsId
			"ig-id" -> InitiatorGrpId
			"initiator-id" -> InitiatorId
			"lu-name" -> LuName
			"small-io-ratio" -> SmallIORatio
			"small-io-ratio-level" -> SmallIORatioLevel
			"snapgrp-id" -> SnapGrpId
			"unaligned-io-ratio" -> UnalignedIORatio
			"unaligned-io-ratio-level" -> UnalignedIORatioLevel
			"sys-id" -> SysId
			"ssd-id" -> SsdId
			"ssd-rg-state" -> SsdRGrpState
			"ssd-uid" -> SsdUid
			"xenv-id" -> XEnvId
			"xenv-state" -> XEnvState
			"ig-index" -> InitiatorGrpIndex
			"tg-name" -> TargetGrpName
			"tg-index" -> TargetGrpIndex
			"tg-id" -> TargetGrpId
			"vol-index" -> VolumeIndex
			"os-version" -> OSVersion
			"IMPIState" -> IPMIState
- \[improvement] updated piece that makes the objects to return to now return "fully" legit objects, by using proper TypeName for `New-Object`, instead of inserting PSTypeName into PSObject properties after the fact (useful for many things, including detection of object type -- was not necessarily expected type when using PSTypeName insertion method of adding type)
- \[improvement] added OutputType to cmdlets once types were defined, which, along with having proper types, allows for leveraging other handy/convenient PowerShell features like tab-completion of property names on the command line while constructing the pipeline
- \[update] changed property values to be more usable (partially in support of adding pipelining support)
	- on `Initiator` and `InitiatorGroup` objects:
		- `InitiatorGrpId` property now is a string that is just the ID, instead of the array of three strings which was `<initiator group ID string>, <initiator group name>, <initiator group object index number>`
	- on `Volume` and `Snapshot` objects:
		- `VolId` property now is a string that is just the ID, instead of the array of three strings which was `<volume ID string>, <volume name>, <volume object index number>`
- \[update] added property `InitiatorGrpIdList` to `IgFolder` objects that is the list of IDs of the initiator groups that reside directly in the given `IgFolder`
- \[improvement] added support for getting Initiator by PortAddress
- \[improvement] added support for getting Initiator by InitiatorGrpId, including by pipeline:

		Get-XIOInitiatorGroup someIG | Get-XIOInitiator
- \[improvement] added support for getting InitiatorGroup by InitatorGrpId, including by pipeline:

		Get-XIOInitator someInitiatorName | Get-XIOInitiatorGroup
		Get-XIOInitiatorGroupFolder /someIGFolder/someDeeperFolder | Get-XIOInitiatorGroup
		Get-XIOVolume myVol0 | Get-XIOInitiatorGroup
		Get-XIOSnapshot mySnap0 | Get-XIOInitiatorGroup
- \[improvement] added support for getting InitiatorGroupFolder by InitatorGrpId, including by pipeline:

		Get-XIOInitiatorGroup someIG | Get-XIOInitiatorGroupFolder
- \[improvement] added support for getting Volume and Snapshot by VolId, including by pipeline:

		Get-XIOVolumeFolder /someVolumeFolder | Get-XIOVolume
		Get-XIOVolumeFolder /someVolumeFolder | Get-XIOSnapshot
- \[improvement] added support for getting Volume and Snapshot by InitiatorGrpId, including by pipeline

		Get-XIOVolumeFolder /someVolumeFolder | Get-XIOVolume
		Get-XIOVolumeFolder /someVolumeFolder | Get-XIOSnapshot
- \[improvement] added support for getting VolumeFolder by VolId, including by pipeline:

		Get-XIOVolume myVol0 | Get-XIOVolumeFolder
- \[bugfix] fixed ParameterSet bug where specifying URI to most `Get-XIO*` cmdlets (excluding the `Get-XIO*Performance` cmdlets) was also passing the `-ItemType` to internal function, which caused problems/errors
- \[bugfix] corrected minor typo in changelog (thanks AC)


### v0.7.0 ###
30 Nov 2014

Hottest new feature:  Added `Connect-XIOServer` and `Disconnect-XIOServer` cmdlets to be able to use other XIO cmdlets without needing to pass credentials with every call.  Simply connect to one or more XIO server (XMS appliance) with the `Connect-XIOServer` cmdlet, and then use the module's other cmdlets without hassling with further credential passing!  Other great updates:

- added the rest of the `New-XIO<specificItem>` functions:
	- `New-XIOInitiator`, `New-XIOInitiatorGroupFolder`, `New-XIOLunMap`, `New-XIOVolumeFolder`
- added performance-specific cmdlets for retrieving performance data for given types:
	- `Get-XIOClusterPerformance`, `Get-XIODataProtectionGroupPerformance`, `Get-XIOInitiatorGroupFolderPerformance`, `Get-XIOInitiatorGroupPerformance`, `Get-XIOInitiatorPerformance`, `Get-XIOSsdPerformance`, `Get-XIOTargetPerformance`, `Get-XIOVolumeFolderPerformance`, `Get-XIOVolumePerformance`
	- included the ability to do "refresh interval" kind of performance data returns (similar to the "frequency" and "duration" types of options in the xmcli) -- see the help on these new cmdlets for examples
	- the performance data is still available via structured properties in these object types' "normal" `Get-*` cmdlets, as introduced in v0.6.0, but the performance-specific cmdlets aim to get the pertinent info on one screen 
- added `Get-XIODataProtectionGroup` for getting XIO data-protection-groups (available in XIOS API v2.4 and up)
- added `Get-XIOEvent` for getting XIO events (available in XIOS API v2.4 and up)
- updated `Get-XIOLunMap` with new parameters for filtering return:  `-Volume`, `-InitiatorGroup`, `-HostLunId`
- removed default of checking original API port of 42503 (which was in use in XIOS versions 2.2.2 and older); now uses either explicitly specified port or default of 443 (the default port in XIOS versions 2.2.3 and newer)
- other & under the covers:
	- added DataReduction property to `XioItemInfo.Cluster` objects; this is the ratio of data reduction provided by deduplication and by compression.  In arrays without compression (arrays with XIOS older that v3.0), DataReduction -eq DedupeRatio
	- added URL encoding helper function
	- added URI property to `Get-XIOItemInfo` output objects
	- renamed "ig-name" property to "InitiatorGroup" for `XioItemInfo.Lun-Map` objects (as returned by `Get-XIOLunMap`)

### v0.6.0 ###
24 Sep 2014

Added discreet `Get-*` cmdlets for the types supported by this module, added `PerformanceInfo` property to many types, added support for XIOS v3.0beta, and more! The list:

- included new properties available in XIOS v2.4.0:
	- updated `Cluster` info objects with new properties `EncryptionMode` and `EncryptionSupported` for encryption-related info, `SizeAndCapacity` for "numBrick X brickSize" info, latency statistics
	- updated `SSD` info object with new property `EncryptionStatus`
- included new properties available in XIOS v3.0:
	- updated `Cluster` info objects with new properties `CompressionFactor`, `CompressionMode`, `DataReduction`, `SharedMemEfficiencyLevel`, `SharedMemInUseRatioLevel`
- updated behavior of a supporting, internal `Get-` function:  throws error now rather than writing to error stream and calling `break`; old behavior would render try/catch statements useless, as it would break all the way out, even of the try/catch statement's parent loop statement, if any
- added ReadMe file with helpful tidbits on how to use the module
- added `Get-*` functions for all object types supported by this module (versus using `Get-XIOItemInfo` for each/every type, added this is the more PowerShell-y; under consideration for long time, available in this release due partially to request by R.C. Monster)
- added support for getting `snapshots` info
- added pile of performance-related properties in `PerformanceInfo` property to pertinent objects (`clusters`, `initiators`, `initiator-groups`, `ig-folders`, `targets`, `volumes`, `volume-folders`)
- added FCIssue property and additional configuration properties to `targets` info
- updated `PowerShellVersion` of module to 4.0

### v0.5.6 ###
10 Jun 2014

Great new feature:  store encrypted credential for use with subsequent `Get-XIOItemInfo` and `New-XIO*` calls.  Can now store once, and use other functions from this module without passing further credentials -- the credentials will be auto-detected if present.  One can remove this credential file at will, and return to passing credentials explicitly to each call, as before.  And, the encrypted credential is encrypted using the Windows Data Protection API, which allows only the user the encrypted the item to decrypt the item (and, can only do so from the same computer on which the item was encrypted).

The list:

- added `New-XIOStoredCred` function for encrypting and storing credential for use in subsequent calls
- added `Get-XIOStoredCred` function for retrieving previously stored (and encrypted) credential
- added `Remove-XIOStoredCred` function for removing stored credential
- updated `Get-XIOItemInfo`, `New-XIOVolume`, and `New-XIOInitiatorGroup` to check for stored credential and use it, if no credential value was provided
- updated `Get-XIOItemInfo` to return precise values, and handle the output formatting with ps1xml (was previously returning less precise values)

### v0.5.5 ###
28 May 2014

- added `New-XIOInitiatorGroup` function for creating new initiator-group
- added `New-XIOVolume` function for creating new volume
- added `Open-XIOMgmtConsole` function for opening XtremIO management console
- updated `Get-XIOItemInfo` to accept URI (increasing reusability by other functions)
- changed module name to "XtremIO.Utils", as module now does more than just "get" operations
- updated IOPS property types to be [int64] instead of the default [string] that they were

### v0.5.1 ###

25 Apr 2014

- added new ItemType types of `targets` and `controllers`
- updated format.ps1xml to include formatting for two new types

### v0.5.0 ###

Initial release, 24 Apr 2014.
