## XtremIO.Utils PowerShell module ##

### Changelog ###
### v0.11.0
20 Mar 2016

This release brings four (4) new cmdlets for creating XtremIO configuration items.  Additionally, there is now support for the `OperatingSystem` property of `Initiator` objects.  The list:

- \[new] New cmdlets: `New-XIOConsistencyGroup`, `New-XIOSnapshotScheduler`, `New-XIOTag`, and `New-XIOUserAccount`
- \[improvement] the `New-XIOInitiator` cmdlet now provides the `-OperatingSystem` parameter for specifying the OS type of the host whose HBA is involved with the new `Initiator` object, and `Initiator` objects now have the `OperatingSystem` property
- \[improvement] Better reporting for when a web exception does happen, for easier issue identification/troubleshooting (mostly useful/applicable during development and API exploration)

### v0.10.0
08 Mar 2016

This release took on the task of adding support for multi-cluster XMS situations to `Get-XIO*` and `New-XIO*` cmdlets.  Another great add was the formalization and integration of the [Pester](https://github.com/pester/Pester "Pester GitHub repo") unit testing.  While there were some tests before, the actual test code was external to this project -- no longer.

The behavior for multi-cluster scenarios is:

- For `Get-XIO*` cmdlets:
	- if `-Cluster` parameter/value specified, the `Get-XIO*` cmdlet will only consider the given cluster(s) when querying for XIO objects
	- if no `-Cluster` parameter/value specified, the `Get-XIO*` cmdlet will return any matching XIO object from all clusters managed by the XMS devices to which current session is connected
- For `New-XIO*` cmdlets:  you must specify one or more values for `-Cluster` for `New-XIO*` cmdlets for objects that are cluster-specific; otherwise, the cmdlets return an error (though, as the `-Cluster` parameter is not necessary for single-cluster scenarios, the parameter itself is not made proper "Mandatory" from a PowerShell standpoint) 

And, `-Cluster` is now valid for all of the cmdlets that deal with XtremIO objects that are cluster-specific (like, `Volumes`, `LunMaps`, etc. -- not XMS-specific things like `Alerts` and `SnmpNotifiers`).  This consists of 22 object-specific `Get-XIO*` cmdlets, six (6) object-specific performance cmdlets, the general `Get-XIOPerformanceCounter` cmdlet, and five (5) `New-XIO*` cmdlets.  You can see which cmdlets support the `-Cluster` parameter like:

	Get-Command -Module XtremIO.Utils -ParameterName Cluster

Some further details about this release:


- \[improvement] added `Cluster` property to `XioConnection` objects; this new property holds the `XIOCluster` objects for the clusters that the given XMS appliance manages
- \[improvement] added oodles of Pester tests for verifying functioning module/cmdlets
- \[improvement] restructured/cleaned-up project directory:  segregated module-specific files into new subdirectory
- \[bugfixes] fixed issues with using the module in PowerShell v5 (WMF 5 RTM re-release from 24 Feb 2016)


### v0.9.5
03 Jan 2016

This version is a collection of improvements, bug fixes, feature additions, and standardization.  Fixed are several bugs relating to using the module in PowerShell v5, and changes in behavior due to changes in the XMS (particularly, the launching of the Java management console).

A couple of improvements around speed/efficiency take advantage of capabilities provided by v2.0 of the XtremIO REST API (which came to be in XIOS v4).  Firstly, we can now retrieve all objects of a given type in one web call, instead of one web call per object.  Also, we can specify just the properties to return, instead of always receiving all properties of the given objects.  While this can help greatly with the speed and efficiency of the cmdlets, it introduces a new potential for issue:  the size of the JSON response might be larger than 2MB, the maximum size currently supported by the PowerShell cmdlet from Microsoft used in this module for JSON handling (`ConvertFrom-Json`).  The use of the `-Property` parameter can help keep the response size under the current 2MB max.  If Microsoft does not make change this cmdlet in the near future, we will need to explore other means for JSON handling. 

See below for the full list of changes.

- \[new] added `New-XIOSnapshot` cmdlet for creating snapshots from the types `Volume`, `Tag`, `ConsistencyGroup`, and `SnapshotSet`, including from-pipeline support. Note:  this cmdlet currently supports new snapshots via the v2 API (in XIOS v4). Further support for snapshots in v1 of the API may be coming, depending on need
- \[improvement] added support for leveraging v2 API feature that allows for getting "full" view of objects upon initial request, instead of getting just the list of HREFs the the "default" view gives. Allows for far more efficient queries.  Supported by `Get-XIOItemInfo`, implemented in `Get-XIOLunMap` for now.  `Get-XIOLunMap` showed an up to 15x speed improvement in the testing environment
- \[improvement] added `about_XtremIO.Utils.help.txt` with the general "here's the module, here are some ways to use it".  You can now get this help via `Get-Help about_XtremIO.Utils`
- \[improvement] more standardized:  updated type definitions for "original" object types (types that have been available since API v1), bringing them in line with the properties of objects from API v2.  While the goal was to avoid any breaking changes, there are several deprecated properties now, and just a few changes to property values, as described here:
	- deprecated (in `DeprecatedPropertyName` -> `NewPropertyName` format below), and deprecated properties are to be removed in some future release:
		- On `Brick`:
			- `NumNode` -> `NumStorageController`
			- `NodeList` -> `StorageController`, a collection of objects with ID, Name, Index properties, instead of just lists of the properties
		- On `Cluster`:
			- `BrickList` -> `Brick`, a collection of objects with ID, Name, Index properties, instead of just lists of the properties
			- `InfiniBandSwitchList` -> `InfiniBandSwitch`, a collection of objects with ID, Name, Index properties, instead of just lists of the properties
		- On `DataProtectionGroup`:
			- `BrickIndex`, `BrickName` -> `Brick`, a collection of objects with ID, Name, Index properties, instead of just the properties
			- `ClusterIndex`, `ClusterName` -> `Cluster`, objects with ID, Name, Index properties, instead of just the properties
			- `RGrpId` -> `DataProtectionGrpId`, the ID of the `DataProtectionGroup` (instead of an array of id/name/index)
		- On `LunMap`:
			- `MappingId` -> `LunMapId`, the ID of the `LunMap` (instead of an array of id/name/index)
			- `MappingIndex` -> `Index`, to have the standard property name used across other objects
		- On `SSD`:
			- `EnabledState` -> (new property) `Enabled`, to have the standard property name and type used across other objects
			- `ModelName` -> `Model`, to have the standard property name used across other objects
			- `ObjSeverity` -> `Severity`, to have the standard property name used across other objects
			- `RGrpId` -> `DataProtectionGroup`, objects with ID, Name, Index properties, instead of just the properties
		- On `StorageController`:
			- `EnabledState` -> (new property) `Enabled`, to have the standard property name and type used across other objects
			- `BiosFWVersion` -> `FWVersion`, to have the standard property name used across other objects
		- On `Target`:
			- `BrickId` -> `Brick`, an object with ID, Name, Index properties, instead of just the properties
			- `TargetGrpId` -> `TargetGroup`, an object with ID, Name, Index properties, instead of just the properties
		- On `Volume`, `Snapshot`:
			- `LunMappingList` -> `LunMapList`, which contains objects with `InitiatorGroup`, `TargetGroup`, and `LunId` info, instead of just lists of properties
			- `NumLunMapping` -> `NumLunMap`, for naming consistency
		- On `Xenv`:
			- `BrickId` -> `Brick`, an object with ID, Name, Index properties, instead of just the properties
			- `NumMdl` -> `NumModule`, for more clear naming of property
	- changes/additions:
		- On `Brick`:
			- added `NumStorageController`, `StorageController` properties
		- On `Cluster`:
			- added `Brick`, `InfiniBandSwitch` properties
		- On `DataProtectionGroup`:
			- added `Brick`, `Cluster`, `DataProtectionGrpId`, `Guid`  properties
		- On `IgFolder`:
			- **CHANGED** `FolderId`: it is now the unique identifier of the folder, instead of the array of <id>,<name>,<index>; this is to align with the *Id properties of the rest of the objects in the module -- they are just the Id string value, not the array of all three properties. And, this <objType>Id property is essentially the `Guid` property of the object, but, older XIOS did not present the `Guid` property directly; so, <objType>Id and `Guid` values should be the same on objects from XIOS v4 and newer; on objects from XIOS older than v3, the `Guid` property will be empty string
			- `SubfolderList` now contains objects with subfolders' Id, Name, and Index info, instead of just lists of properties
			- added `Caption`, `ColorHex`, `CreationTime`, `Guid`, `ObjectType` properties
		- On `Initiator`:
			- **CHANGED** `InitiatorId`: it is now the unique identifier of the intiator, instead of the array of <id>,<name>,<index>; this is like the change to the FolderId property of IgFolder objects above
			- added `Guid`, `InitiatorGroup` properties
		- On `LunMap`:
			- added `LunMapId`, that is the unique identifier of the folder; will eventually be the favored identifying property, over the deprecated MappingId property
		- On `SSD`:
			- **CHANGED** `SsdId`: it is now the unique identifier of the SSD, instead of the array of <id>,<name>,<index>; this is like the change to the FolderId property of IgFolder objects above
			- added `DataProtectionGroup`, `Enabled`, `Model`, `Severity` properties
		- On `StorageController`:
			- added `DataProtectionGroup`, `Enabled`, `FWVersion`, `IdLED`, `LifecycleState`, `PartNumber`, `StorageControllerId` properties
		- On `Target`:
			- added `Brick`, `ErrorReason`, `PortMacAddress`, `StorageController`, `TargetGroup`, `TargetId` properties
		- On `TargetGroup`:
			- **CHANGED** `TargetGrpId`: it is now the unique identifier of the `TargetGroup`, instead of the array of <id>,<name>,<index>; this is like the change to the `FolderId` property of `IgFolder` objects above
		- On `Snapshot`, `Volume`:
			- added `Folder`, `LunMapList`, `NumLunMap`, `SnapshotType`, `TagList` properties
		- On `VolumeFolder`:
			- added `Caption`, `ColorHex`, `CreationTime`, `ObjectType`, `SubfolderList` properties
		- On `Xenv`:
			- **CHANGED** `XenvId`: it is now the unique identifier of the `Xenv`, instead of the array of <id>,<name>,<index>; this is like the change to the `FolderId` property of `IgFolder` objects above
			- added `NumModule`, `StorageController` properties
- \[improvement] Added ability to specify particular properties for retrieval/return, so as to allow for quicker, more focused queries.  Implemented on `Get-XIOItemInfo` and `Get-XIOLunMap` cmdlets first.  Can specify the "nice" property names as defined for objects created by the PowerShell module, or the "raw" property names as defined in the XIO REST API.
- \[improvement] for when web call returns an error, added additional verbose error info from WebException in InnnerException of returned error (if any) for when issue getting items from API.  This is helpful for troubleshooting, especially when you are crafting own URIs
- \[bugfix] `Open-XIOMgmtConsole` now works as it should on XMS of XIOS version 4 and newer -- the path to the .jnlp file is now dependent upon the XMS version. Also uses HTTPS to get launch file. This now expects the current PowerShell session has an `XioConnection` to the target XMS server (via which the XMS version info is retrieved)
- \[bugfix] Module now works in PowerShell v5. Importing the module in PowerShell v5 previously resulted in multiple errors of:  `Multiple ambiguous overloads found for ".ctor" and the argument count: "1"`. This was due to the `OutputType` statement for cmdlet definitions specifying a type that was not yet defined in the session, which was due to the adding of types occurring _after_ the dot-source of the given function-defining .ps1 file
- \[bugfix] Several cmdlets are now fixed for use in PowerShell v5:
	- `TagList` property type was not a nullable type before, so would throw error if returned object had no value. Fixed for:
		- `Get-XIOBBU`
		- `Get-XIODAE`
		- `Get-XIOInfinibandSwitch`
		- `Get-XIOLocalDisk`
		- `Get-XIOSnapshotSet`
	- Similar issue for various properties of objects returned by other cmdlets. Fixed for:
		- `Get-XIOInitiatorGroupFolder`
		- `Get-XIOInitiatorGroupFolderPerformance`
		- `Get-XIOSnapshot`
		- `Get-XIOTag`
		- `Get-XIOVolume`
		- `Get-XIOVolumeFolder`
		- `Get-XIOVolumeFolderPerformance`
		- `Get-XIOVolumePerformance`
	- difference in PowerShell v5 in `Where-Object` result in function internals for creating the URL. Fixed for:
		- `Get-XIOPerformanceCounter`
- \[bugfix] Fixed issue where `BuildNumber` property of XMS object did not handle all possible values.  Usually the value received from the API call is an Int32, but can be string. **CHANGED:**  This property was renamed to `Build` and is now a `String` instead of an `Int32`




### v0.9.0
14 Nov 2015

The focus for this version was on updating the module to support new things available in XIOS version 4.0.  Twenty new types, and the ability to get the newly available performance counters for eleven entity types (`Cluster`, `DataProtectionGroup`, `Initiator`, `InitiatorGroup`, `SnapshotGroup`, `SSD`, `Target`, `TargetGroup`, `Volume`, `XEnv`, and `Xms`).

- \[new] added `Get-` cmdlet coverage for new types available in XIOS v4 and newer:

		Get-XIOAlert
		Get-XIOAlertDefinition
		Get-XIOBBU
		Get-XIOConsistencyGroup
		Get-XIODAE
		Get-XIODAEController
		Get-XIODAEPsu
		Get-XIOEmailNotifier
		Get-XIOInfinibandSwitch
		Get-XIOLdapConfig
		Get-XIOLocalDisk
		Get-XIOSlot
		Get-XIOSnapshotScheduler
		Get-XIOSnapshotSet
		Get-XIOSnmpNotifier
		Get-XIOStorageControllerPsu
		Get-XIOSyslogNotifier
		Get-XIOTag
		Get-XIOUserAccount
		Get-XIOXMS

- \[new] added `Get-XIOPerformanceCounter` cmdlet for getting performance counter values for given entity types, and exposing the ability to set granularity of the counter values and timeframe from which to get the data. Note:  not yet supporting getting performance counters based on Tag entity type, as there may be some further research needed, possibly involving discussions with the vendor
- \[new] added feature that allows for graceful determination of valid types for given XioConnection; so, executing `Get-XIOTag` when connected to an XIOS v3 or older XMS will not throw error due to non-existent object types, but rather will return verbose message that given type is not available on XMS at older XIOS (API) version 
- \[improvement] added XIOS REST API version and full XMS version to `XioItemInfo.XioConnection` object (if available via XMS type, which it _is_ for XIOS v4+).  The new properties on the XioConnection type are `RestApiVersion`, `XmsDBVersion`, `XmsSWVersion` (string representation, like "4.0.1-41"), and `XmsVersion`
- \[bugfix] fixed issue in return-object-creation where *in-progress properties from XIOS v4 DataProtectionGroup API objects might have values other than "true" and "false". Module was expecting just these two strings and converting them to boolean; this could have failed in XIOS v4 environments. Affected cmdlets were `Get-XIODataProtectionGroup` and `Get-XIODataProtectionGroupPerformance`

Other notes:

- not yet adding support for `consistency-group-volumes` API objects, as their returned properties seem to just be consistency groups, not consistency group volumes -- may also require discussion with vendor
- not yet adding support for SYR Notifiers. While the XIOS v4 release notes talk about API support for these objects, the API on the few systems on which I tested did not surface this object type
- the new cmdlets are at the base level -- on the to-do list are things like extending/improving them to bring in the additional power of supporting pipelining

### v0.8.3
Sep 2015

- \[improvement] updated supporting function `New-XioApiURI` such that communications testing can be controlled (say, only at, `Connect-XIOServer` time) -- previously, communications were tested with every cmdlet call.  Once verified with the `Connection-XIOServer` call, the assumption is that the port does not change on the destination XMS appliance in the session (or, probably ever), so, for the sake of performance, the test is not performed at every call, now
- \[update] added handling of `DataReduction` property calculation on `Cluster` objects that accounts for the now-missing property `data-reduction-ratio` from the XMS appliance on at least the 4.0.0-54 beta and 4.0.1-7 XIOS versions. Without this, `DataReduction` value for connections to XMS appliance of these XIOS versions would return just the `DedupeRatio` value for  `DataReduction` property

### v0.8.2
24 Jun 2015

- \[bugfix] fixed issue where some `VolSizeTB` and `UsedLogicalTB` properties were defined as `Int32` types in the type definition, which lead to lack of precision due to subsequent rounding in the casting process. Corrected, defining them as `Double` items

### v0.8.1
08 Jun 2015

- \[improvement] updated `Connect-XIOServer` to return "legit" object type, instead of PSObject with inserted typename of `XioItemInfo.XioConnection` (so that things like `$oConnection -is [XioItemInfo.XioConnection]` return `$true`)
- [correction] fixed incorrect examples in changelog

### v0.8.0
22 May 2015

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

		Get-XIOInitiatorGroup myIgroup0 | Get-XIOVolume
		Get-XIOInitiatorGroup myIgroup0 | Get-XIOSnapshot
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
