### ToDo for XtremIO.Utils PowerShell module

ToDo:
- add support for new objects that came to be in REST API v2.1:
	- Discover Initiators:  `GET /api/json/v2/types/discover-initiators`
	- Initiators Connectivity:  `GET /api/json/v2/types/initiators-connectivity`
- enable adding/removing volume to/from `ConsistencyGroup` (via `Set-XIOConsistencyGroup`, or via `Add-XIOVolumeToConsistencyGroup`, `Remove-XIOVolumeFromConsistencyGroup`?)
- eventually support filtering in `-URI` param _and_ returning `XioItemInfo.*` objects (filtering in URI and using `-ReturnFullResponse` works as expected), need to have new code that either:
	- with `&full=1` in URI:  needs to do something to handle return-obj creation from `&full=1` object; near the `_New-ObjectFromApiObject` call in `Get-XIOItemInfo`
	- without `&full=1` in URI:  needs to do additional call to `Get-XIOItemInfo` of just the URL (for each URL) from the <item-type> property of object returned from filtered call, and does not do the rest of the Get-XIOItemInfo call that was in the works when the original call w/ the URI with filter was passed; needs to consider (and preserve / pass-on) the `prop=...`` bits from original URI, if any
- after Filter support is in place:
	- add `-Filter` param to the `Get-XIO*` cmdlets for which it makes sense; ex:  `Get-XIOInitiator` should filter when taking `IntiatorGroup` from pipeline (filter on `Initiators` that have given `InitiatorGrpId` value)
	- for `Get-XIOSnapshot`:  add Param option for `ancestor-vol-id`, implement via Filter -- available via xmcli
	- for `Get-XIOVolume`:  add Param option for `sg-id` (snapshot group ID), implement via Filter -- available via xmcli
	- potentially once API allows for things like `?folder-id=b38b38123b38123asdfb38b38123` in the query string, can use IDs in URI?  Until then, these IDs would only be used to filter items _after_ they've been retrieved from the XMS appliance
	- once assuming that min XIO REST API version is 2.0 (after dropping support for XMS older than v4) improve `Get-XIOLunMap`:
		- change the `-Volume`, `-HostLunId`, and `-InitiatorGroup` params to use `-Filter` on `Get-XIOItemInfo` (do away with `-Volume` and `-InitiatorGroup`, since those are handled via `-RelatedObject`?)
- investigate bug where `Tag` objects' `DirectObjectList` objects may have properties that do not correspond to the actual type of object the given Direct`Objects are; like, an IG `Tag` with a "nested" `Tag` object:  that nested tag object in the parent `Tag`'s `DirectObjectList` may have properties like `InitiatorGrpId`, instead of something that denotes that the value is actually the `Tag` ID; these child `Tags` seem to show up properly in the parent `Tag`'s `ChildTagList` property, but incorrectly in the `DirectObjectList` property
- improve `Set-XIOLdapConfig`:
	- add ability to append a role mapping (instead of user having to specify full RoleMapping value for every Set operation)
- investigate improving `Set-XIOSnapshotScheduler` to support renaming of SnapshotScheduler (in XtremIO REST API v2.1 or newer); rename in web UI seems to use "rename" command with "new_name" parameter, like:  {obj_class="Scheduler", obj_id=["", "None", "1"], new_name="some new name", new_caption=None, sys_id=["", "", "2"]}
- expand availability of `-Property` parameter on other `Get-*` cmdlets as it makes sense (already done on `Get-XIOLunMap`)
	- include "translation" config item to go from "nice" property names (as returned on `XIOItemInfo.*` objects) to API Objects' property names, so that consumer does not need to know the API property names
	- will need to update type definitions and the hsh table definitions for the eventual `New-Object` call to expect/handle/allow $null values, so as to be able to populate only some property values for the return object, as done for Volume/Snapshot, LunMap objects
- once `.Cluster` type of property is added to cluster-specific objects:
	- for `Volume`: update `New-XIOSnapshot` to take cluster value from `Volume` object when `Volume` object taken from pipeline (and if that particular `Volume` has a `Cluster` property value)
	- this is also in prep for better pipelining, which will need to get `Cluster` info from pipeline object coming through (along with `.ComputerName`, right?)
	- once added to `Volume` and `Tag`, update `New-XIOConsistencyGroup` to take it from `Volume`/`Tag` objects if those were passed as values to `-Volume` or `-Tag`?  Else, user has to specify the vol/tag _and_ the cluster, when that should be gleanable from the vol/tag objects themselves (right?)
- change the `.Guid` property on API v1 objects to have value that, if `.guid` property of API obj does not exist, then use <objType>-id[0] (the Id part of the <id>,<name>,<index> array)
	- then, can more universally use that `Guid` in pipelining and whatnot
- fix bug in `New-XIOVolume`:  when specifying both `-ParentFolder` and `-Cluster`, throws error:  "message": "Command Syntax Error: Invalid property parent-folder-id"
	- either send `ParentFolder` property as part of tag_list value (need to test), or do not include `-ParentFolder` in same paramset as `-Cluster`?
- fix bug in `Get-XIOSnapshotScheduler` when using by URI:  must have "?cluster-name=<blahh>" in the URI, or request returns error:  "message": "cluster_id_is_required"
	- encountered when connected to multi-cluster XMS and creating new `SnapshotScheduler`
- fix bug in `New-XIOTagAssignment` when the entity is a Snapshot:  the "entity" property does not get populated on body of submission, and the call then fails
- once pipelining supports getting `SnapshotScheduler` by `Volume`/`Snapshot`, add bit to `Remove-XIOVolume` that checks first if `Volume`/`Snapshot` is part of a `SnapshotScheduler`, throwing an error if so (instead of the current behavior that does not check and that results in an error from the API call, "cannot_remove_volume_that_has_a_scheduler")
- investigate adding `New-XIOLdapConfig` (the POST how-to is not specified in the API reference -- present but not documented? -- if not, add cmdlet once (if ever) this method is supported for this object type)
	- same for adding `Remove-XIOLdapConfig` (the DELETE how-to is not specified in the API reference)
- replace "manual" enumeration of valid types for param values in `Get-XIOEvent` with legit Enums
	- do same for `Get-XIOItemInfo`?
- improve `New-XIOLunMap`:
	- take `initiatorgroup` from pipeline (by property of `InitGrpId`); currently expects IG _name_, and doesn't accept by pipeline (weak)
	- update `-Volume` to accept vol objects or vol name (just does name right now), and take `Volume` obj from pipeline
- update Parent* properties of older objects to be obj like: <parentType>Id, Name, Index as returned by helper function
- include support for `Get-XIOSnapshotScheduler` to get by Volume/snapshot/snapset (and, accept from pipeline, too) as related object
- update `Get-XIOTag` to have `-ObjectType` parameter; will filter on ObjectType enumeration (after dropping support for REST API v1)
- for when removing InitiatorGrpIdList from IgFolder object (deprecated after v0.11), remove the three spots that take it from pipeline via:  `ValueFromPipelineByPropertyName=$true)][Alias("InitiatorGrpIdList")]`
- add pipelining abilities for things like (add their tests at the same time!)
``` PowerShell
	Get-XIOInitiatorGroup | Get-XIOLunMap (just by IG name until adding support for "by IGrpID" when working on XIOSv4 things)
	## currently behaves unexpectedly when using something like:
	Get-XIOInitiatorGroupFolder | Get-XIOInitiatorGroupFolderPerformance
	#  Get-XIOInitiatorGroupFolder -computer *01* | Get-XIOInitiatorGroupFolderPerformance -DurationSeconds 15
	#   outputs like:
<#	Name         WriteBW_MBps   WriteIOPS     ReadBW_MBps   ReadIOPS      BW_MBps      IOPS       TotWriteIOs  TotReadIOs
	----         ------------   ---------     -----------   --------      -------      ----       -----------  ----------
	/            21.153         851           17.813        825           38.966       1676       29298600763  77718380223
	VERBOSE: Starting sleep for '5' sec; ending run at/about 2014.Nov.13 18:24:52 (duration of '15' sec)
	/            29.306         769           27.256        759           56.562       1528       29298604621  77718384024
	VERBOSE: Starting sleep for '5' sec; ending run at/about 2014.Nov.13 18:24:52 (duration of '15' sec)
	/            7.345          550           6.692         630           14.037       1180       29298607403  77718387183
	/fol04       7.345          550           6.692         630           14.037       1180       29298607403  77718387183
	VERBOSE: Starting sleep for '5' sec; ending run at/about 2014.Nov.13 18:25:03 (duration of '15' sec)
	/fol04       5.918          609           12.021        739           17.938       1348       29298610477  77718390880
	VERBOSE: Starting sleep for '5' sec; ending run at/about 2014.Nov.13 18:25:03 (duration of '15' sec)
	/fol04       5.918          609           12.021        739           17.938       1348       29298610477  77718390880

	instead of the expected
	Name         WriteBW_MBps   WriteIOPS     ReadBW_MBps   ReadIOPS      BW_MBps      IOPS       TotWriteIOs  TotReadIOs
	----         ------------   ---------     -----------   --------      -------      ----       -----------  ----------
	/            21.153         851           17.813        825           38.966       1676       29298600763  77718380223
	/fol04       7.345          550           6.692         630           14.037       1180       29298607403  77718387183
	VERBOSE: Starting sleep for '5' sec; ending run at/about 2014.Nov.13 18:24:52 (duration of '15' sec)
	/            29.306         769           27.256        759           56.562       1528       29298604621  77718384024
	/fol04       7.345          550           6.692         630           14.037       1180       29298607403  77718387183
	VERBOSE: Starting sleep for '5' sec; ending run at/about 2014.Nov.13 18:24:52 (duration of '15' sec)
	/            7.345          550           6.692         630           14.037       1180       29298607403  77718387183
	/fol04       7.345          550           6.692         630           14.037       1180       29298607403  77718387183
	VERBOSE: Starting sleep for '5' sec; ending run at/about 2014.Nov.13 18:25:03 (duration of '15' sec)
	/            7.345          550           6.692         630           14.037       1180       29298607403  77718387183
	/fol04       5.918          609           12.021        739           17.938       1348       29298610477  77718390880
	VERBOSE: Starting sleep for '5' sec; ending run at/about 2014.Nov.13 18:25:03 (duration of '15' sec)
	/            7.345          550           6.692         630           14.037       1180       29298607403  77718387183
	/fol04       5.918          609           12.021        739           17.938       1348       29298610477  77718390880
#>
```
- add Catch for explicit DownloadString exception:
``` PowerShell
	VERBOSE: Uh-oh -- something went awry trying to get data from that URI
	('https://somexms.dom.com/api/json/types'). A pair of guesses:  no such XMS appliance, or that item type is not
	valid in the API version on the XMS appliance that you are contacting, maybe?  Should handle this in future module
	release.  Throwing error for now.
	Connect-XIOServer : Failed to connect to XMS 'somexms.dom.com'.  See error below for details
	At line:1 char:1
	+ Connect-XIOServer -ComputerName somexms.dom.com -TrustAllCert -Credential  ...
	+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		+ CategoryInfo          : NotSpecified: (:) [Write-Error], WriteErrorException
		+ FullyQualifiedErrorId : Microsoft.PowerShell.Commands.WriteErrorException,Connect-XIOServer

	Exception calling "DownloadString" with "1" argument(s): "The operation has timed out"
	At \\path\to\XtremIO.Utils\XIO_SupportingFunctions.ps1:58 char:4
	+             $oWebClient.DownloadString($hshParamsForRequest["Uri"]) | ConvertFrom-Json
	+             ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		+ CategoryInfo          : NotSpecified: (:) [], MethodInvocationException
		+ FullyQualifiedErrorId : WebException
```
- check into / remove use of deprecated properties, if any, from list: (per v3.0.1 REST API guide, p12)
	- In version 3.0, the following object parameters are not in use and have been deprecated:
		- Cluster object:
			- max-snapshots-per-volume
			- meta-data-utilization-level
			- meta-data-utilization
			- vamd-memory
			- vamd-memory-in-use
			- max-cgs-per-volume
			- max-cgs
			- num-of-r-mdls
			- max-snapsets-per-cg
			- max-vol-per-cg
			- num-of-d-mdls
			- min-num-of-ssds-per-healthy-rg
			- num-of-c-mdls
		- Storage Controller object:
			- eth-link-health-level
	- In version 3.0.1, the following object parameters are not in use and have been deprecated:
		- Storage Controller object:
			- hw-revision
	- also, others listed on p198 of v3.0.1 REST API guide
- change wording around Disable-CertValidation to refer to the output as ServerCertificateValidationCallback, not CertificatePolicy
- address performance properties that are no longer "real" from the API, but still presented as properties/values on objects; for example:  IgFolder objects have an IOPS property that may actually have no value, but that gets cast to an Int in the SupportingFunctions, and becomes "0" for the returned object
	- need to make these nullable? (can we?)
- try `Invoke-WebRequest` in place of the WebClient .NET class (this guy reports success vs. `Invoke-RestMethod` when same symptoms, but uses an IDontCare CertPolicy:  https://communities.vmware.com/thread/466166)
- add `Update-Snapshot` to correspond to "refresh" operation in mgmt GUI
	- Create a Snapshot and reassign on a Volume, Consistency Group or Snapshot Set (see Table 4, on page 192).
		Note: Refer to example use cases for taking Snapshots and reassigning on a Volume, Consistency Group or Snapshot Set, on page 14.
- XIOS v4 properties/types to add/update/handle:
	- on XMS object, provide DateTime property from the ISO8601 date/time string that has timezone abbreviation in it
	not doing yet:
		- consistency-group-volumes, as their properties returned seem to just be consistency groups, not consistency group volumes (properties match identically, and there are none of the Performance types of properties in the object as there are in the advertised object per the API guide)
			- and, from initial query of "https://xms.dom.com/api/json/types/consistency-group-volumes", the sub-property is "consistency-groups" (instead of the expected "consistency-group-volumes")
			- possible mix-up in the API?
		- getting performance counter for Tag EntityType needs more work (API call needs obj-list defined, apparently, and is throwing errors even when having done so)
- future release:  remove deprecated properties that are noted by `System.ObsoleteAttribute` statements (deprecated in v0.9.5 or so)
	- before then, compile the type definition, so that these properties actually write warning in PowerShell session to make it more clear to users that properties are deprecated? Else, relying on them to have thoroughly read the changelog
- for supporting targeted cluster queries on XMS appliances that manage multiple clusters, still need to:
	- add piece that checks that the given Cluster values are managed by this XMS and if not, doesn't even try to get the given object, just does write-verbose of "no such cluster managed by this XMS", instead of non-graceful throw of, ""message": "sys_not_found""
	- ?add piece that, if `.Cluster` count on given XIOConnection is 1, does not try to use cluster-name input param in URI
- for `Get-XIO*Performance` returns, include the GUID or URI or so of the given XIO object, for clarification (return of `Get-XIODataProtectionGroupPerformance` for multi-cluster does not give distinguishable objects -- can't tell the cluster of each DPG)
- deprecate `VolumeFolder`, `InitiatorGroupFolder` cmdlets, and the use of these object types for `RelatedObject` param values in other cmdlets
- for when dropping support for legacy XIOS/API (XIOS 2 & 3, API v1)
	- remove `PerformanceInfo` property from `IGFolder`, `VolumeFolder` (and remove `Get-XIOInitiatorGroupFolderPerformance`, `Get-XIOVolumeFolderPerformance` cmdlets)
	- remove the Nullable aspect of `.Cluster` properties in the type def (v2 API objects should always have the .sys-id property on objects for which code tries to make .Cluster value from said property)
- item types for which to add support in module:
	- iscsi-portals
	- iscsi-routes
- add ability to create ISCSI initiators via `New-XIOInitiator`
- add `Set-XIOAlert` once getting the proper JSON body info from either updated docs or from EMC ("command" is not valid, but is the only property specified in the API reference)
- update (refactor) to use either `hshParamsForGetXioInfo` or `hshParamsForGetXioItemInfo` variable name in `GetXIOItem.ps1`
- for `New-XIO*`, make -Name param only positional param (none right now?), so that one need not specify -Name for something like `New-XIOVolume myTestVol -SizeGB 5KB`
- revisit `-RelatedObject` items from pipeline:  currently using Name property for getting desired objects, but other properties are available (like GUID and whatnot) -- use more unique item like GUID instead of Name for when switching to using API v2 that supports filtering -- can use GUID instead of name
- eventually add `Tag` type as accepted type by `-RelatedObject` parameter to rest of `Get-XIO*` cmdlets (did not add immediately, as these objects are less likely to get tagged in standard practice):  `Get-XIOBrick`, `Get-XIOCluster`, `Get-XIODAE`, `Get-XIODataProtectionGroup`, `Get-XIOInfinibandSwitch`, `Get-XIOSnapshotScheduler`, `Get-XIOStorageController`, `Get-XIOTarget`
- ?gracefully handle Entity-type / Tag-type mismatch in `New-XIOTagAssignment`?  Right now, user must assign proper Tag type to proper Entity type (cmdlet does not currently prevent user from trying to assign an Initiator tag to a Volume entity, for example)
- add paramsets to `Set-XIOTarget`, so that at least one of MTU, Name is mandatory (Two param set names?)
- ?if adding this project to that EMC {code} site, add things to ReadMe related to "EMC {code}" (see requirements/suggestions on EMC {code} site)
- ?add something that handles return of objects such that only one instance of each unique object is returned?  For example:  should `Get-XIOInitiatorGroup | select -First 5 | Get-XIOSnapshot -Name mysnap044.*`` only return one object for "mysnap044.lastweeksnap", even if that snapshot is mapped to all of the five InitiatorGroups passed as RelateObjects to `Get-XIOSnapshot`?  The, "return only unique objects" behavior is how some other modules do it, like PowerCLI, for example
- after adding Tag as supported `RelatedObject` type on `Get-XIO*` cmdlets:  Tags do not have Cluster properties, so may give unexpected behavior if only getting targeted object by name (won't have associated Cluster by which to pinpoint the targeted object); or, need to use Guid instead and filter?  A: still hit the "need cluster name" issue for when in multi-cluster situation; need to solve this someway
- for future (once supporitng iSCSI in this PSModule), add ability to set following properties via `Set-XIOInitiator`:  'initiator-authentication-user-name', 'initiator-authentication-password', 'initiator-discovery-user-name', 'initiator-discovery-password', 'cluster-authentication-user-name', 'cluster-authentication-password', 'cluster-discovery-user-name', 'cluster-discovery-password', 'remove-initiator-authentication-credentials', 'remove-initiator-discovery-credentials', 'remove-cluster-authentication-credentials', 'remove-cluster-discovery-credentials'
- ?add ability for `Get-XIOItemInfo` to detect, for when `-URI` paramset is used, that `full=1` is in use, and to handle return object creation accordingly
- ?add ability to specify `-Tag` for when creating new objects that support "tag-list" property via API (like `New-XIOInitiatorGroup`, for example); or, just stick w/ adding new Tag assignments via dedicated cmdlet?  Answer:  the latter; user can add tag assignment via `New-XIOTagAssignment` along the New-XIO* object creation pipeline
- ?for `Set-XIO*` cmdlets other than `Set-XIOItemInfo`, add ability to specify object by name and cluster?  Currently just supports by-object
- ?add backwards compatibility for XIOSv3 (APIv1):
	- for `New-Snapshot`, add backwards support for snapshots; currently only supports new snapshots on XIOSv4 (APIv2)
		- for XIOS v3.0, support creation:
			- from one volume
			- from volumes
			- from one volumefolder
	- need to exclude -OperatingSystem parameter option in New-XIOInitiator if API of XMS is v1 -- breaks things to send along in a request to API V1 XMS; lower priority
- ?for `PerfomanceCounter` objects, need better way to present the `.Counters` property? (for easier export by user once retrieved)
- ?eventually for `Open-XIOMgmtConsole`:  only act on existing XMS connections (as the cmdlet will need the XMS software version in order to create the correct URL to the JNLP file); or, will this cmdlet change to open the web management console instead of the Java management console, once the Web UI takes over?
- ?provide ability for module user to set preferences for the module?  Like, a different default value for `-OperatingSystem` for `New-XIOInitiator`, for example?
	- if so:
	- add a `Get-XIOUtilsConfiguration` function to report things like the filespec of the `StoredXioCred`
	- add a `Set-XIOUtilsConfiguration` function to set things like the default port to use, and `$true`/`$false` for TrustAllCert
- ?add `if ($PsCmdlet.ShouldProcess())` portion to `New-XIOVolume`, around the `New-XioItem` call, so as to have better `WhatIf` output?
- ?add "small" and "unaligned" performance items, too? (available in xmcli)
- ?replace usage of singular item type string (essentially used for output type name creation; make config hsh table of plural item type string -> XIOItemInfo output object type)
	- use the config API item types as the ValidateSet value for ItemType in `Get-XIOItem` function, so as not to need to upkeep such info in multiple places!
	- have config hsh of API type (like /types/ig-folders) -> XioItemInfo type (like IgFolder)
		- to remove the "strip an 's', title case the string, and remove the dash" antics that are in place now
		- need to update all places that specify API types as singular to use real API type name
- ?add object definitions of sub-property objects?  Could slow things down (like `Get-VM` does vs. `Get-View` in PowerCLI)
- ?for when rev'ing minimum API support level to API v2.0, remove the conditional `Cluster` property population code (as needed `.sys-id` property should be present on everything at that point); affected object types:  `Initiator`, `InitiatorGroup`, `LunMap`, `Target`
- ?add `Get-XIOAssignment` cmdlet, and update `Remove-XIOTagAssignment` to take that from pipeline?  Could be an easier pipeline for the user for when removing `Tag` assignments


### Known Issues / Considerations
#### From module release v1.4.0

- Setting of `AccessType` on `Snapshot` objects not seemingly supported. While the API reference documentation mentions this item as a valid parameter in one spot, the documentation omits it in another, making it unclear if there is official support for setting this property on a `Snapshot` object. Updated `Set-XIOVolume` help (`Set-XIOVolume` is used for the other set-operations for `Snapshot` objects)
- in XtremIO REST API v2.1:
	- UPDATE on item: some filters (via the `-Filter` parameter to `Get-XIOItemInfo`) give unexpected results when comparison operator is "eq" and value is an integer:  filtering for same object by different attribute (generally, whose value is a string instead of an integer) seems to be unaffected. Update:  vendor confirmed this as a bug, and that said bug should be fixed in upcoming release currently slated for end of Q1 2017
	- Getting objects from related Tag object could return more than just the tagged objects in a multi-cluster XMS environment with objects of the same name across multiple clusters. This is due to the current compatibility mode of the module which does not rely on XMS REST API v2+ feature of filtering. A future module release will handle this by filtering on unique properties, but the current solution uses object names from the Tag (clearly not the best key to try to use), and Tag objects are XMS-wide (not cluster specific).
	- removing SnapshotSet objects seems to consistently fail, as though the name of one of the API request body parameters changed -- the documented property name of `snapshot-set-id`, as well as the observed (by Audit events) property name of `snapset-id` both fail in removal requests


#### From module release v1.3.0

- in XtremIO REST API v2.1:
	- some filters (via the `-Filter` parameter to `Get-XIOItemInfo`) give unexpected results when comparison operator is "eq" and value is an integer:  filtering for same object by different attribute (generally, whose value is a string instead of an integer) seems to be unaffected. Investigating with vendor


#### From module release v1.2.0

- User must assign proper Tag type to proper Entity type (cmdlet does not currently prevent user from trying to assign an Initiator tag to a Volume entity, for example)
- XIO REST API version support for specifying `-Name` for new SnapshotScheduler:  the XIO REST API v2.0 does not seem to support specifying the name for a new scheduler, but the REST API v2.1 (and newer, presumably) does support specifying the name.
- cannot get deprecated XIO VolumeFolder from Snapshot object in modern XIOS (with modern REST API), as API does not provide "folder" type of property any more. Support for Snapshot type as related object to `Get-XIOVolumeFolder` will be removed in future release (though, may survive until the altogether removal of `Get-XIOVolumeFolder`)
- `New-XIOTag`, `Set-XIOTag`: Specifying `-Color` parameter is only supported by the XIO REST API starting in v2.1 of said REST API

#### From module release v1.1.0

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






### Actual Doing-Action info:
#### Should do next:
- update ReadMe w/ some of the info on the module's GeneralInfo page at vN -- the PSGet stuff, the getting started stuff, etc.; add update about opening WebUI
- update GH Pages examples
- update parameter names to be consistent across cmdlets (remove "_str" and "_arr" types of trailing parameter bits)
- update to Filter as much as possible in place of relying on by-name things (in -RelatedObject types of scenarios, for example) -- this is the break from supporting API v1 (XMS v3 and older)


#### Doing:

#### Done:

#### Things already added to changelog/readme:


#### Done for previous versions:
_moved to [done.txt](done.txt)_
