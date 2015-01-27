## XtremIO.Utils PowerShell module ReadMe##

### Getting Started ###

##### Importing the module #####

To import the module, use the `Import-Module` cmdlet, and use the top level folder of the module for the path.  No need to point explicitly at any .psd1 file, just use the parent folder of the module's files, like:

- `Import-Module \\path\to\XtremIO.Utils`

##### Getting commands in the module #####

- `Get-Command -Module XtremIO.Utils`

##### Opening the Java-based administration GUI (yuck) #####

- `Open-XIOMgmtConsole -ComputerName somexmsappl01.dom.com`

##### Credential handling #####

The module provides `Connect-` and `Disconnect-` cmdlets for handling connections to XMS servers, so that one may connect to an XMS server, and then take further action without needing to supply credentials again for each subsequent call.  These cmdlets also update the PowerShell window titlebar with information about the currently-connected XIO servers.  See the help for `Connect-XIOServer` and `Disconnect-XIOServer` for more information using these cmdlets.

The module can also store an encrypted credential for use with `Connect-XIOServer` calls.  This is a remnant from the days when the module required credentials for every call to get/create XIO objects.  For now, such a stored credential can still be used to a small extent:   

- Upon storing once (via `New-XIOStoredCred`), one can use the `Connect-XIOServer` function from this module without passing further credentials -- the stored credentials will be auto-detected if they are present
- One can remove this credential file at will via `Remove-XIOStoredCred`
- And, the encrypted credential is encrypted using the Windows Data Protection API, which allows only the user the encrypted the item to decrypt the item (and, can only do so from the same computer on which the item was encrypted)
