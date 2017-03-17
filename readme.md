## XtremIO.Utils PowerShell module ReadMe

Contents:

- [Getting Started](#gettingStarted)
- [Changelog](#changelog)
- [Other Details](#otherDetails)

<a id="gettingStarted"></a>
### Getting Started


##### Importing the module

To import the module, use the `Import-Module` cmdlet, and use the top level folder of the module for the path.  No need to point explicitly at any .psd1 file, just use the parent folder of the module's files, like:

- `Import-Module \\path\to\XtremIO.Utils`

##### Getting commands in the module

- `Get-Command -Module XtremIO.Utils`

##### Dealing with non-legitimate / self-signed certificates
The cmdlets for connecting to an XMS machine and for opening the admin GUI (`Connect-XIOServer`, `Open-XIOMgmtConsole`) each have a `-TrustAllCert` switch parameter.  You can use this switch to ignore certificate errors when connecting or opening a management console, but you should only do so if you know the destination machine and trust that machine.


##### Connecting to an XMS device
- `Connect-XIOServer -ComputerName somexmsappl01.dom.com -Credential (Get-Credential dom\someUser)`

##### Credential handling

The module provides `Connect-` and `Disconnect-` cmdlets for handling connections to XMS servers, so that one may connect to an XMS server, and then take further action without needing to supply credentials again for each subsequent call.  These cmdlets also update the PowerShell window titlebar with information about the currently-connected XIO servers.  See the help for `Connect-XIOServer` and `Disconnect-XIOServer` for more information using these cmdlets.

The module can also store an encrypted credential for use with `Connect-XIOServer` calls.  This is a remnant from the days when the module required credentials for every call to get/create XIO objects.  For now, such a stored credential can still be used to a small extent:   

- Upon storing once (via `New-XIOStoredCred`), one can use the `Connect-XIOServer` function from this module without passing further credentials -- the stored credentials will be auto-detected if they are present
- One can remove this credential file at will via `Remove-XIOStoredCred`
- And, the encrypted credential is encrypted using the Windows Data Protection API, which allows only the user the encrypted the item to decrypt the item (and, can only do so from the same computer on which the item was encrypted)

##### Example run through of using the module
See this module's GitHub Pages page for exciting examples of using the cmdlets from this module, available at <https://mtboren.github.io/XtremIO.Utils/>.

##### For those rare occasions when you feel like you need a GUI:
Opening the Web-based administration GUI (yuck, but better than the Java-based UI):
- `Open-XIOXMSWebUI -ComputerName somexmsappl01.dom.com`

Opening the Java-based administration GUI (yuck)
- `Open-XIOMgmtConsole -ComputerName somexmsappl01.dom.com`


<a id="changelog"></a>
### Changelog for the module
In [changelog.md](changelog.md), there is an informative section for each version of the module, with listing of new features, improvements, bug fixes, and more.  Be sure to read it for all of the exciting news.


<a id="otherDetails"></a>
### Some details on the module, cmdlet behavior, etc.
`Remove-XIO*` cmdlets:

- `Remove-XIOConsistencyGroup`:  Removing a `ConsistencyGroup` does not affect the `Volume` objects that were in it -- they are _not_ deleted
- `Remove-XIOInitiatorGroup`:
	- If the target `InitiatorGroup` is part of a `LunMap`, the attempt to remove the `InitiatorGroup` will fail  -- user must first remove given `LunMap`
	- Removing an `InitiatorGroup` also removes the `Initiator` objects that were part of the target `IntiatorGroup`
- `Remove-XIOSnapshotScheduler`:  the API does not yet support removing the associated `SnapshotSet` objects, it seems, so removing the `SnapshotScheduler` does not affect the `SnapshotSet` objects that have been created as a result of the `SnapshotScheduler` having run
- `Remove-XIOSnapshotSet`:  this deletes the `Snapshot` objects that were in the `SnapshotSet`, too
- `Remove-XIOVolume`:
	- Can be used to remove both `Volume` and `Snapshot` objects
	- If the `Volume`/`Snapshot` is part of `LunMap`:  the attempt to remove the `Volume`/`Snapshot` will fail; more detail:  this action fails in the admin GUI, but the API allows it (it removes the `LunMap`, too); this cmdlet is written to emulate the behavior established by the GUI (the cmdlet does not delete the target `Volume`/`Snapshot` object if it is part of a `LunMap` -- user must first remove given `LunMap`)
	- If the `Volume`/`Snapshot` is the subject of a `SnapshotScheduler`:  the attempt to remove the `Volume`/`Snapshot` will fail -- user must first remove given `SnapshotScheduler`
	- If the `Snapshot` is part of a `SnapshotSet`:  removing the `Snapshot` leaves the `SnapshotSet` alone _unless_ this was the last `Snapshot` in the `SnapshotSet`
	- If it is the last `Snapshot` in the `SnapshotSet`:  the XMS deletes the then-empty `SnapshotSet`, too
	- If this `Volume`/`Snapshot` has any child `Snapshot`:  Those child `Snapshot` objects' `AncestorVolume` value is set to the value of this property of the `Volume`/`Snapshot` being deleted, if any (else, the property on the child `Snapshot` gets set to `$null`); and, then, if all of the ancestor `Volume` objects of the given `Snapshot` are deleted, the `Snapshot` object becomes _just_ a `Volume` object, no longer a `Snapshot` object (though, it remains a part of a `SnapshotSet` object!)
