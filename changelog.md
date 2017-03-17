## XtremIO.Utils PowerShell module Changelog

Contents:

- [v1.4.0](#v1.4.0), 16 Mar 2017
- [Known Issues](#currentKnownIssues)
- [v1.3.0](#v1.3.0), 14 Dec 2016
- [v1.2.0](#v1.2.0), 17 Nov 2016
- [v1.1.0](#v1.1.0), 30 Jun 2016
- [v1.0.0](#v1.0.0), 05 May 2016
- [v0.14.0](#v0.14.0), 22 Apr 2016
- [v0.12.0](#v0.12.0), 08 Apr 2016
- [Older versions](#olderVersions)

------

<a id="v1.4.0"></a>
### v1.4.0
16 Mar 2017

This release brings some nice new functionality, providing for increased ease-of-use and more natural use. It also increased the testing-coverage, and fixed a few bugs.  The details:

- \[new] added `Tag` type as accepted type by `-RelatedObject` parameter to main `Get-XIO*` cmdlets, providing much needed capability of getting given objects by `Tag`. Cmdlets updated:
	`Get-XIOBBU`, `Get-XIOConsistencyGroup`, `Get-XIOInitiator`, `Get-XIOInitiatorGroup`, `Get-XIOSnapshot`, `Get-XIOSnapshotSet`, `Get-XIOSsd`, `Get-XIOVolume`
- \[new] added `-Name` parameter to `Set-XIOSnapshotScheduler`, `Set-XIOTarget`, for specifying new name respectively for `SnapshotScheduler`, `Target` (not documented in API reference, but supported operation)
- \[new] added Pester tests for `Set-XIO*` cmdlets
- \[fixed] fixed bug in `Set-XIOInitiator` where setting failed for all initiators
	- appears that sending _full_ "initiator-id" property as defined on "FullResponse" objects (which is @(<guid>, <name>, <index>)), call now succeeds on at least API v2.1:
	- updated `Remove-XIO*`, which were working w/ name-only for the ID portion, but including GUID and index in request body should now be better
	- updated `Set-XIO*`:
		- fixed: `Set-XIOInitiator`, `Set-XIOSnapshotScheduler` (worked, but try also w/ legit "scheduler-id" array of values instead of just index), `Set-XIOTarget`, `Set-XIOVolume`
- \[fixed] fixed typo "multple" in help for `Set-XIOLdapConfig`


<a id="currentKnownIssues"></a>
**Known Issues as of v1.4.0:**

From module release v1.4.0

- Setting of `AccessType` on `Snapshot` objects not seemingly supported. While the API reference documentation mentions this item as a valid parameter in one spot, the documentation omits it in another, making it unclear if there is official support for setting this property on a `Snapshot` object. Updated `Set-XIOVolume` help (`Set-XIOVolume` is used for the other set-operations for `Snapshot` objects)
- in XtremIO REST API v2.1:
	- UPDATE on item: some filters (via the `-Filter` parameter to `Get-XIOItemInfo`) give unexpected results when comparison operator is "eq" and value is an integer:  filtering for same object by different attribute (generally, whose value is a string instead of an integer) seems to be unaffected. Update:  vendor confirmed this as a bug, and that said bug should be fixed in upcoming release currently slated for end of Q1 2017
	- Getting objects from related Tag object could return more than just the tagged objects in a multi-cluster XMS environment with objects of the same name across multiple clusters. This is due to the current compatibility mode of the module which does not rely on XMS REST API v2+ feature of filtering. A future module release will handle this by filtering on unique properties, but the current solution uses object names from the Tag (clearly not the best key to try to use), and Tag objects are XMS-wide (not cluster specific).
	- removing SnapshotSet objects seems to consistently fail, as though the name of one of the API request body parameters changed -- the documented property name of `snapshot-set-id`, as well as the observed (by Audit events) property name of `snapset-id` both fail in removal requests


From module release v1.3.0

- in XtremIO REST API v2.1:
	- some filters (via the `-Filter` parameter to `Get-XIOItemInfo`) give unexpected results when comparison operator is "eq" and value is an integer:  filtering for same object by different attribute (generally, whose value is a string instead of an integer) seems to be unaffected. Investigating with vendor

From module release v1.2.0

- User must assign proper Tag type to proper Entity type (cmdlet does not currently prevent user from trying to assign an Initiator tag to a Volume entity, for example)
- XIO REST API version support for specifying `-Name` for new SnapshotScheduler:  the XIO REST API v2.0 does not seem to support specifying the name for a new scheduler, but the REST API v2.1 (and newer, presumably) does support specifying the name.
- cannot get deprecated XIO VolumeFolder from Snapshot object in modern XIOS (with modern REST API), as API does not provide "folder" type of property any more. Support for Snapshot type as related object to `Get-XIOVolumeFolder` will be removed in future release (though, may survive until the altogether removal of `Get-XIOVolumeFolder`)
- `New-XIOTag`, `Set-XIOTag`: Specifying `-Color` parameter is only supported by the XIO REST API starting in v2.1 of said REST API

From module release v1.1.0

- In XtremIO REST API v2.0, getting objects from pipeline with `SnapshotScheduler` as the `-RelatedObject` in a multi-cluster XMS scenario may return more that just one of given object type:  the XIOS API does not have cluster-specificity for `SnapshotScheduler` objects, so objects related to `SnapshotScheduler` are retrieved only by name and XMS computer name for now (until better filtering based on GUID is in place); if objects of same name exist across mutliple clusters in this XMS, all of those objects will be returned.  This is not the case starting in XtremIO REST API v2.1.
- When connected to a multi-cluster XMS, getting the following objects in the given ways may fail with, "cluster\_id\_is\_required" message:
	- `Get-XIOVolume` when using a `VolumeFolder` as the `-RelatedObject` parameter value
	- `Get-XIOInitiatorGroup` when using an `IgFolder` as the `-RelatedObject` parameter value
	- This is due to `VolumeFolder` and `IgFolder` objects not having a `Cluster` property
	- this may not get resolved, as support for `VolumeFolder`/`IgFolder` objects is going away (they have been replaced with `Tag` objects)
- `Remove-XIOInitiatorGroupFolder`, `Remove-VolumeFolder` via XIO API v2.1 (on at least XMS version 4.2.0-33) -- fails with message "Invalid property", which is "ig-folder-name" for `IgFolder` objects, "folder-type" for `VolumeFolder` objects; potentially due changed API in which folder support is now different/gone
	- folder support will be removed from this PowerShell module eventually, so these may not get addressed
	- Workaround:  these items show up as `Tag` objects, too, so one can use `Get-XIOTag` to get them, and `Remove-XIOTag` to remove them
- Specifying `-ParentFolder` parameter to `New-XIOVolume` via XIO API v2.1 (on at least XMS version 4.2.0-33) -- fails with message "Command Syntax Error: Invalid property ig-folder-name"; again, potentially due changed API in which folder support is now different/gone
	- Workaround:  do not specify `-ParentFolder` parameter, which creates volume without volume tag

------

<a id="v1.3.0"></a>
### v1.3.0
14 Dec 2016

This release brought the first implementation of filtering support for the module, along with a fix and an improvement here and there.  This filtering support provides the basis for great speed improvements in future updates, as some queries will benifit in a big way from leveraging such filtering.  The list for this release:

- \[new] added initial Filtering support, which is supported the XtremIO REST API v2.0 and up
	- first added to `Get-XIOItemInfo` cmdlet as a parameter (`-Filter`)
	- can facilitate surgical selection of objects to return, providing for vastly improved retrieval of objects (like is characteristic of server-side filtering)
	- utilized in improved `Get-XIOLunMap` cmdlet (mentioned below)
	- see `Get-XIOItemInfo` for brief help and examples, and see the "Filter" section towards the start of the XtremIO "RESTful API Guide" for complete syntax
- \[fixed] fixed bug in `Remove-XIOUserAccount` that was caused by change of input parameter name in XtremIO REST API v2.1 and inaccurate API docs; this fix maintained compatibility with XtremIO REST API v2.0
- \[improvement] improved `Get-XIOLunMap`:
	- added `-RelatedItem` parameter, which supports `InitiatorGroup`, `Volume`, and `Snapshot` items (and, from pipeline, too); this uses new Filtering capabilities, which bring great speed improvements
	- added `-Name` param, for the off chance that someone wants to get LunMap by `1_3_1` kind of name


<a id="v1.2.0"></a>
### v1.2.0
17 Nov 2016

This release brought new cmdlets for managing Tag assignments on objects, a small new cmdlet to quickly open the WebUI on XMS appliances, some lifecycle management of object types and properties, and various bugfixes/updates.  See below for the exciting list:

- \[new] added ability to assign/remove Tag for an object; done via new cmdlets `New-XIOTagAssignment` and `Remove-XIOTagAssignment`
- \[new] added `Open-XIOXMSWebUI` cmdlet for opening the WebUI web management interface of the given XMS appliance(s)
- \[updated] `New-XIOTag`, `Set-XIOTag` cmdlets now support specifying Tag color via new `-Color` parameter
- \[updated] added `-Name` parameter to `New-XIOSnapshotScheduler` (available via XIO REST API starting in v2.1)
- \[updated] added/removed/deprecated following properties for given object types:
	- for `Alert`:  added `Cluster` property, deprecated `ClusterId` and `ClusterName` properties
	- for `LunMap`:  added `Certainty`
	- for `SnapshotScheduler`: added `Cluster` property (available via XIO REST API starting in v2.1; will be `$null` in `SnapshotScheduler` objects returned from XIO REST API v2.0)
	- for `SSD`:  removed obsolete property `SSDPositionState` (values were returned from API as "obsolete")
	- for `StorageController`:  removed obsolete properties `EncryptionMode`, `EncryptionSwitchStatus` (values were returned from API as "obsolete")
	- for `Volume`, `Snapshot`:  added `VolSizeGB` property for ease of reading for when the volume size is less than 1TB, updated output format to include these in default table view
- \[fixed] fixed order of items in `[XioItemInfo.Enums.Tag.EntityType]` enumeration
- \[fixed] added DefaultParameterSetName to `Set-XIOUserAccount`, as some parameter combinations resulted in "Parameter set cannot be resolved using the specified named parameters" error
- \[updated] various minor updates/fixes to cmdlets and their parameters, for improving the overall experience


<a id="v1.1.0"></a>
### v1.1.0
30 Jun 2016

This release is all about having expanded the pipelining capabilities of the `Get-XIO*` cmdlets.  This was accomplished by adding a `-RelatedObject` parameter to many of these cmdlets.  For example, one can now get a `ConsistencyGroup` object based on a related `Snapshot` object, or a `LunMap` object based on a related `Volume` object, or a `StorageController` object based on a related `Brick` object.  One can pass a value directly to `-RelatedObject`, or (much more conveniently) via pipeline.  Details for this release:

- \[improvement] Added `-RelatedObject` parameter to nineteen (19) cmdlets, accepting related objects by value and by pipeline as such.  The cmdlets then use the properties of the related object to determine the Cluster, ComputerName, etc., in order to get the desired object type based on the related object:
	- **`Get-XIOBBU`**:  from `Brick`, `StorageController`
	- **`Get-XIOBrick`**:  from `BBU`, `Cluster`, `DAE`, `DAEController`, `DAEPsu`, `DataProtectionGroup`, `LocalDisk`, `Slot`, `Ssd`, `StorageController`, `StorageControllerPsu`, `Target`, `Xenv`
	- **`Get-XIOCluster`**:  from `BBU`, `Brick`, `ConsistencyGroup`, `DAE`, `DAEController`, `DAEPsu`, `DataProtectionGroup`, `InfinibandSwitch`, `Initiator`, `InitiatorGroup`, `LocalDisk`, `LunMap`, `Slot`, `Snapshot`, `SnapshotSet`, `Ssd`, `StorageController`, `StorageControllerPsu`, `Target`, `TargetGroup`, `Volume`, `Xenv`
	- **`Get-XIOConsistencyGroup`**:  from `Snapshot`, `SnapshotScheduler`, `SnapshotSet`, `Volume`
	- **`Get-XIODAE`**:  from `Brick`, `DAEController`, `DAEPsu`
	- **`Get-XIODataProtectionGroup`**:  from `Brick`, `Ssd`, `StorageController`
	- **`Get-XIOInfinibandSwitch`**:  from `Cluster`
	- **`Get-XIOInitiatorGroup`**:  from `Initiator`, `IgFolder`, `LunMap`, `Snapshot`, `Volume`
		- `-RelatedObject` parameter replaces `-InitiatorGrpId`
	- **`Get-XIOInitiatorGroupFolder`**:  from `IgFolder`, `InitiatorGroup`
		- `-RelatedObject` parameter replaces `-InitiatorGrpId`
	- **`Get-XIOLocalDisk`**:  from `StorageController`
	- **`Get-XIOSnapshot`**:  from `Snapshot`, `SnapshotSet`, `Volume`, `VolumeFolder`
		- `-RelatedObject` parameter replaces `-VolumeId` and `-InitiatorGrpId` parameters, which are now gone
	- **`Get-XIOSnapshotSet`**:  from `Snapshot`, `SnapshotScheduler`, `Volume`
	- **`Get-XIOSsd`**:  from `Brick`, `Slot`
	- **`Get-XIOStorageController`**:  from `BBU`, `Brick`, `LocalDisk`, `StorageControllerPsu`, `Target`, `Xenv`
	- **`Get-XIOStorageControllerPsu`**:  from Get-XIOStorageController
	- **`Get-XIOTag`**:  from `BBU`, `Brick`, `Cluster`, `ConsistencyGroup`, `DAE`, `InfinibandSwitch`, `Initiator`, `InitiatorGroup`, `LocalDisk`, `Snapshot`, `SnapshotSet`, `Ssd`, `Target`, `TargetGroup`, `Volume`, `Xenv`
	- **`Get-XIOTargetGroup`**:  from `Target`
	- **`Get-XIOVolume`**:  from `ConsistencyGroup`, `InitiatorGroup`, `LunMap`, `Snapshot`, `SnapshotScheduler`, `SnapshotSet`, `Volume`, `VolumeFolder`
		- `-RelatedObject` parameter replaces `-VolumeId` and `-InitiatorGrpId` parameters, which are now gone
	- **`Get-XIOVolumeFolder`**:  from `Snapshot`, `Volume`, `VolumeFolder`
		- `-RelatedObject` parameter replaces VolumeId parameter, which is now gone

Known Issues as of v1.1.0:

- Getting objects from pipeline with `SnapshotScheduler` as the `-RelatedObject` in a multi-cluster XMS scenario may return more that just one of given object type:  the XIOS API does not have cluster-specificity for `SnapshotScheduler` objects, so objects related to `SnapshotScheduler` are retrieved only by name and XMS computer name for now (until better filtering based on GUID is in place); if objects of same name exist across mutliple clusters in this XMS, all of those objects will be returned
- When connected to a multi-cluster XMS, getting the following objects in the given ways may fail with, "cluster\_id\_is\_required" message:
	- `Get-XIOVolume` when using a `VolumeFolder` as the `-RelatedObject` parameter value
	- `Get-XIOInitiatorGroup` when using an `IgFolder` as the `-RelatedObject` parameter value
	- This is due to `VolumeFolder` and `IgFolder` objects not having a `Cluster` property
	- this may not get resolved, as support for `VolumeFolder`/`IgFolder` objects is going away (they have been replaced with `Tag` objects)
- `Remove-XIOUserAccount` via the XIO API v2.1 (on at least XMS version 4.2.0-33) -- fails with message "Invalid property user-id" due to potentially changed API parameter (not confirmed, but events on XMS show param name as "usr_id", API ref until this point says "user-id", with the dash/underscore being insignificant, as they seem interchangable, but with the "usr" vs. user" difference possibly being the issue)
- `Remove-XIOInitiatorGroupFolder`, `Remove-VolumeFolder` via XIO API v2.1 (on at least XMS version 4.2.0-33) -- fails with message "Invalid property", which is "ig-folder-name" for `IgFolder` objects, "folder-type" for `VolumeFolder` objects; potentially due changed API in which folder support is now different/gone
	- folder support will be removed from this PowerShell module eventually, so these may not get addressed
	- Workaround:  these items show up as `Tag` objects, too, so one can use `Get-XIOTag` to get them, and `Remove-XIOTag` to remove them
- Specifying `-ParentFolder` parameter to `New-XIOVolume` via XIO API v2.1 (on at least XMS version 4.2.0-33) -- fails with message "Command Syntax Error: Invalid property ig-folder-name"; again, potentially due changed API in which folder support is now different/gone
	- Workaround:  do not specify `-ParentFolder` parameter (of course), which creates volume without volume tag

------

<a id="v1.0.0"></a>
### v1.0.0
05 May 2016

Oh, my -- v1.0.0! Added the other set of cmdlets still needed, the Remove-XIO* cmdlets.  And, while there is still a long list of things to add/update/enhance, this update brings the module to version 1.0 status.  Details for this release:

- \[new] Remove-XIO* cmdlets:  `Remove-XIOConsistencyGroup`, `Remove-XIOInitiator`, `Remove-XIOInitiatorGroup`, `Remove-XIOInitiatorGroupFolder`, `Remove-XIOLunMap`, `Remove-XIOSnapshotScheduler`, `Remove-XIOSnapshotSet`, `Remove-XIOTag`, `Remove-XIOUserAccount`, `Remove-XIOVolume`, `Remove-XIOVolumeFolder`
- \[new] Added [Pester](https://github.com/pester/Pester "Pester GitHub repo") tests for New-XIO* and Remove-XIO* cmdlets, with an additional test that verifies that the same number of XtremIO inventory objects exist after testing as did before testing -- to get a feel for whether any testing crumbs were left behind
- \[bugfix] Fixed issue where `New-XIOSnapshotScheduler` for multi-cluster XMS requires `cluster-id` property in the JSON body, but the cmdlet was not passing it if not explicitly specified by user; the cmdlet now takes it from the `-RelatedObject`'s `Cluster` property if `-Cluster` parameter not specified

------

<a id="v0.14.0"></a>
### v0.14.0
22 Apr 2016

Now, with Set-XIO* cmdlets!  This release brings a bevy of new Set-XIO* cmdlets:  sixteen (16) of them, to be exact.  This provides coverage for setting properties of objects with settable properties -- woo-hoo!  The details for this release:

- \[new] Set-XIO* cmdlets:  `Set-XIOAlertDefinition`, `Set-XIOConsistencyGroup`, `Set-XIOEmailNotifier`, `Set-XIOInitiator`, `Set-XIOInitiatorGroup`, `Set-XIOInitiatorGroupFolder`, `Set-XIOLdapConfig`, `Set-XIOSnapshotScheduler`, `Set-XIOSnapshotSet`, `Set-XIOSnmpNotifier`, `Set-XIOSyslogNotifier`, `Set-XIOTag`, `Set-XIOTarget`, `Set-XIOUserAccount`, `Set-XIOVolume`, `Set-XIOVolumeFolder`.  These all accept from pipeline the object upon which to operate for maximum ease of use.
- \[new] A couple of new properties for `Cluster` objects:  `DebugCreationTimeoutLevel`, `ObfuscateDebugInformation`

------

<a id="v0.12.0"></a>
### v0.12.0
08 Apr 2016

New properties!  This release was all about fleshing out the properties of returned objects, partly for increasing the richness of the objects, and partly in preparation for making vast pipelining improvements between cmdlets.  The further standardization of objects' properties lead to three property deprecations, and those properties will be removed in a future release (see list below).  Some details:

- \[new] added or updated `Cluster` property to twenty-one (21) object types, and in the form of an `XioItemInfo.Cluster` object
- \[change] updated `Cluster` property to be an `XioItemInfo.Cluster` object instead of just a `String`  on object types `DataProtectionGroup` and `StorageController`
- \[deprecated] deprecated properties `ClusterId`, `ClusterName`, and `SysId`, with the new `Cluster` property being the direction forward, for fourteen object types that had one or more of said properties.  Affected object types: `BBU`, `Brick`, `ConsistencyGroup`, `DAE`, `DAEController`, `DAEPsu`, `LocalDisk`, `Slot`, `Snapshot`, `SnapshotSet`, `Ssd`, `StorageControllerPsu`, `TargetGroup`, `Volume`
- \[new] added various new properties to twenty-seven object types

------

<a id="olderVersions"></a>
### v0.11.0
20 Mar 2016

This release brings four (4) new cmdlets for creating XtremIO configuration items.  Additionally, there is now support for the `OperatingSystem` property of `Initiator` objects.  The list:

- \[new] New cmdlets: `New-XIOConsistencyGroup`, `New-XIOSnapshotScheduler`, `New-XIOTag`, and `New-XIOUserAccount`
- \[improvement] the `New-XIOInitiator` cmdlet now provides the `-OperatingSystem` parameter for specifying the OS type of the host whose HBA is involved with the new `Initiator` object, and `Initiator` objects now have the `OperatingSystem` property
- \[improvement] Better reporting for when a web exception does happen, for easier issue identification/troubleshooting (mostly useful/applicable during development and API exploration)

------

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

------

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


------

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

------

### v0.8.3
Sep 2015

- \[improvement] updated supporting function `New-XioApiURI` such that communications testing can be controlled (say, only at, `Connect-XIOServer` time) -- previously, communications were tested with every cmdlet call.  Once verified with the `Connection-XIOServer` call, the assumption is that the port does not change on the destination XMS appliance in the session (or, probably ever), so, for the sake of performance, the test is not performed at every call, now
- \[update] added handling of `DataReduction` property calculation on `Cluster` objects that accounts for the now-missing property `data-reduction-ratio` from the XMS appliance on at least the 4.0.0-54 beta and 4.0.1-7 XIOS versions. Without this, `DataReduction` value for connections to XMS appliance of these XIOS versions would return just the `DedupeRatio` value for  `DataReduction` property

------

### v0.8.2
24 Jun 2015

- \[bugfix] fixed issue where some `VolSizeTB` and `UsedLogicalTB` properties were defined as `Int32` types in the type definition, which lead to lack of precision due to subsequent rounding in the casting process. Corrected, defining them as `Double` items

------

### v0.8.1
08 Jun 2015

- \[improvement] updated `Connect-XIOServer` to return "legit" object type, instead of PSObject with inserted typename of `XioItemInfo.XioConnection` (so that things like `$oConnection -is [XioItemInfo.XioConnection]` return `$true`)
- [correction] fixed incorrect examples in changelog

------

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

------

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

------

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

------

### v0.5.6 ###
10 Jun 2014

Great new feature:  store encrypted credential for use with subsequent `Get-XIOItemInfo` and `New-XIO*` calls.  Can now store once, and use other functions from this module without passing further credentials -- the credentials will be auto-detected if present.  One can remove this credential file at will, and return to passing credentials explicitly to each call, as before.  And, the encrypted credential is encrypted using the Windows Data Protection API, which allows only the user the encrypted the item to decrypt the item (and, can only do so from the same computer on which the item was encrypted).

The list:

- added `New-XIOStoredCred` function for encrypting and storing credential for use in subsequent calls
- added `Get-XIOStoredCred` function for retrieving previously stored (and encrypted) credential
- added `Remove-XIOStoredCred` function for removing stored credential
- updated `Get-XIOItemInfo`, `New-XIOVolume`, and `New-XIOInitiatorGroup` to check for stored credential and use it, if no credential value was provided
- updated `Get-XIOItemInfo` to return precise values, and handle the output formatting with ps1xml (was previously returning less precise values)

------

### v0.5.5 ###
28 May 2014

- added `New-XIOInitiatorGroup` function for creating new initiator-group
- added `New-XIOVolume` function for creating new volume
- added `Open-XIOMgmtConsole` function for opening XtremIO management console
- updated `Get-XIOItemInfo` to accept URI (increasing reusability by other functions)
- changed module name to "XtremIO.Utils", as module now does more than just "get" operations
- updated IOPS property types to be [int64] instead of the default [string] that they were

------

### v0.5.1 ###

25 Apr 2014

- added new ItemType types of `targets` and `controllers`
- updated format.ps1xml to include formatting for two new types

------

### v0.5.0 ###

Initial release, 24 Apr 2014.
