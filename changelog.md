## XtremIO.Utils PowerShell module ##

### Changelog ###
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
