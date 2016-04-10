<#	.Description
	Function to set XtremIO item info using REST API with XtremIO XMS appliance.  Generally used as supporting function to the rest of the Set-XIO* cmdlets, but can be used directly, too, if needed
	.Example
	Set-XIOItemInfo -Name /mattTestFolder -ItemType volume-folder -SpecForSetItem ($hshTmpSpecForNewVolFolderName | ConvertTo-Json) -Cluster myCluster0
	Set a new name for the given VolumeFolder, using the hashtable that has a "caption" key/value pair for the new name
	An example of the hastable is:  $hshTmpSpecForNewVolFolderName = @{"caption" = "mattTestFolder_renamed"}
	.Example
	Set-XIOItemInfo -SpecForSetItem ($hshTmpSpecForNewVolFolderName | ConvertTo-Json) -URI https://somexms.dom.com/api/json/types/volume-folders/10
	Set a new name for the given VolumeFolder by specifying the object's URI, using the hashtable that has a "caption" key/value pair for the new name
	.Example
	Set-XIOItemInfo -SpecForSetItem ($hshTmpSpecForNewVolFolderName | ConvertTo-Json) -XIOItemInfoObj (Get-XIOVolumeFolder /mattTestFolder)
	Set a new name for the given VolumeFolder from the existing object itself, using the hashtable that has a "caption" key/value pair for the new name
	.Example
	Get-XIOVolumeFolder /mattTestFolder | Set-XIOItemInfo -SpecForSetItem ($hshTmpSpecForNewVolFolderName | ConvertTo-Json)
	Set a new name for the given VolumeFolder from the existing object itself (via pipeline), using the hashtable that has a "caption" key/value pair for the new name
	.Outputs
	XioItemInfo object for the newly updated object if successful
#>
function Set-XIOItemInfo {
	[CmdletBinding(DefaultParameterSetName="ByComputerName", SupportsShouldProcess=$true, ConfirmImpact=[System.Management.Automation.Confirmimpact]::High)]
	param(
		## XMS appliance address to which to connect
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Name(s) of cluster in which resides the object whose properties to set
		[parameter(Mandatory=$true,ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Item type for which to set info
		[parameter(Mandatory=$true,ParameterSetName="ByComputerName")]
		[ValidateSet("ig-folder", "initiator-group", "initiator", "syslog-notifier", "tag", "user-account", "volume", "volume-folder")]
		[string]$ItemType,
		## Item name for which to set info
		[parameter(Position=0,ParameterSetName="ByComputerName")][Alias("ItemName")][string]$Name,
		## JSON for the body of the POST WebRequest, for specifying the properties for modifying the XIO object
		[parameter(Mandatory=$true)][ValidateScript({ try {ConvertFrom-Json -InputObject $_ -ErrorAction:SilentlyContinue | Out-Null; $true} catch {$false} })][string]$SpecForSetItem,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI,
		## XioItemInfo object whose property to set
		[parameter(Position=0,ParameterSetName="ByXioItemInfoObj",ValueFromPipeline)][ValidateNotNullOrEmpty()][PSObject]$XIOItemInfoObj
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## get the XIO connections to use, either from ComputerName param, or from the URI
		$arrXioConnectionsToUse = Get-XioConnectionsToUse -ComputerName $(
			Switch ($PSCmdlet.ParameterSetName) {
				"ByComputerName" {$ComputerName; break}
				"SpecifyFullUri" {([System.Uri]($URI)).DnsSafeHost; break}
				"ByXioItemInfoObj" {$XIOItemInfoObj.ComputerName}
			})
	} ## end begin

	Process {
		## make sure that object exists; attempt to get it, first
		$oExistingXioItem = Switch ($PSCmdlet.ParameterSetName) {
				{"ByComputerName","SpecifyFullUri" -contains $_} {
					## make hashtable of params for the Get call (that verifies that such an object exists); remove any extra params that were copied in that are not used for the Get call, or where the param name is not quite the same in the subsequent function being called
					$PSBoundParameters.Keys | Where-Object {"SpecForSetItem","WhatIf" -notcontains $_} | Foreach-Object -begin {$hshParamsForGetItem = @{}} -process {$hshParamsForGetItem[$_] = $PSBoundParameters[$_]}
					Get-XIOItemInfo @hshParamsForGetItem; break
				} ## end case
				"ByXioItemInfoObj" {$XIOItemInfoObj; break}
			} ## end switch
		## if such an item does not exist, throw error and stop
		if ($null -eq $oExistingXioItem) {Throw "Item of name '$Name' and type '$ItemType' does not exist on '$($arrXioConnectionsToUse.ComputerName -join ", ")'. Taking no action"} ## end if
		## if more than one such an item exists, throw error and stop
		if (($oExistingXioItem | Measure-Object).Count -ne 1) {Throw "More than one item like name '$Name' and of type '$ItemType' found on '$($arrXioConnectionsToUse.ComputerName -join ", ")'"} ## end if
		## else, actually try to set properties on the object
		else {
			$arrXioConnectionsToUse | Foreach-Object {
				$oThisXioConnection = $_
				## the Set items' specification, from JSON; PSCustomObject with properties/values to be set
				$oSetSpecItem = ConvertFrom-Json -InputObject $SpecForSetItem
				$intNumPropertyToSet = ($oSetSpecItem | Get-Member -Type NoteProperty | Measure-Object).Count
				## make a string to display the properties being set in the -WhatIf and -Confirm types of messages; replace any "password" values with asterisks
				$strPropertiesBeingSet = ($SpecForSetItem.Trim("{}").Split("`n") | Where-Object {-not [System.String]::IsNullOrEmpty($_.Trim())} | Foreach-Object {if ($_ -match '^\s+"password": ') {$_ -replace '^(\s+"password":\s+)".+"', ('$1'+("*"*10))} else {$_}}) -join "`n"
				$strShouldProcessOutput = "Set following {0} propert{1} for '{2}' object named '{3}':`n$strPropertiesBeingSet`n" -f $intNumPropertyToSet, $(if ($intNumPropertyToSet -eq 1) {"y"} else {"ies"}), $oExistingXioItem.GetType().Name, $oExistingXioItem.Name
				if ($PsCmdlet.ShouldProcess($oThisXioConnection.ComputerName, $strShouldProcessOutput)) {
					## make params hashtable for new WebRequest
					$hshParamsToSetXIOItem = @{
						Uri = $oExistingXioItem.Uri
						## JSON contents for body, for the params for creating the new XIO object
						Body = $SpecForSetItem
						Method = "Put"
						## do something w/ creds to make Headers
						Headers = @{Authorization = (Get-BasicAuthStringFromCredential -Credential $oThisXioConnection.Credential)}
					} ## end hashtable

					## try request
					try {
						## when Method is Put or when there is a body to the request, seems to ignore cert errors by default, so no need to change cert-handling behavior here based on -TrustAllCert value
						$oWebReturn = Invoke-WebRequest @hshParamsToSetXIOItem
					} ## end try
					catch {
						_Invoke-WebExceptionErrorCatchHandling -URI $hshParamsToSetXIOItem['Uri'] -ErrorRecord $_
					} ## end catch
					## if good, write-verbose the status and, if status is "Created", Get-XIOInfo on given HREF
					if (($oWebReturn.StatusCode -eq $hshCfg["StdResponse"]["Put"]["StatusCode"] ) -and ($oWebReturn.StatusDescription -eq $hshCfg["StdResponse"]["Put"]["StatusDescription"])) {
						Write-Verbose "$strLogEntry_ToAdd Item updated successfully. StatusDescription: '$($oWebReturn.StatusDescription)'"
						## use the return's links' hrefs to return the XIO item(s)
						Get-XIOItemInfo -URI $oExistingXioItem.Uri
					} ## end if
				} ## end if ShouldProcess
			} ## end foreach-object
		} ## end else
	} ## end process
} ## end function



<#	.Description
	Modify an XtremIO IgFolder. Not yet functional for XIOS v3.x and older
	.Example
	Set-XIOInitiatorGroupFolder -InitiatorGroupFolder (Get-XIOInitiatorGroupFolder /myIgFolder) -Caption myIgFolder_renamed
	Set a new caption for the given IgFolder from the existing object itself
	.Example
	Get-XIOInitiatorGroupFolder /myIgFolder | Set-XIOInitiatorGroupFolder -Caption myIgFolder_renamed
	Set a new caption for the given IgFolder from the existing object itself (via pipeline)
	.Outputs
	XioItemInfo.IgFolder object for the modified object if successful
#>
function Set-XIOInitiatorGroupFolder {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.IgFolder])]
	param(
		## IgFolder object to modify
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.IgFolder]$InitiatorGroupFolder,
		## New caption to set for initiator group folder
		[parameter(Mandatory=$true)][string]$Caption
	) ## end param

	Process {
		## the API-specific pieces for modifying the XIO object's properties
		$hshSetItemSpec = @{
			caption = $Caption
		} ## end hashtable

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForSetItem = @{
			SpecForSetItem = $hshSetItemSpec | ConvertTo-Json
			XIOItemInfoObj = $InitiatorGroupFolder
		} ## end hashtable

		## call the function to actually modify this item
		Set-XIOItemInfo @hshParamsForSetItem
	} ## end process
} ## end function


<#	.Description
	Modify an XtremIO SyslogNotifier
	.Example
	Set-XIOSyslogNotifier -SyslogNotifier (Get-XIOSyslogNotifier) -Enable:$false
	Disable the given SyslogNotifier
	.Example
	Get-XIOSyslogNotifier | Set-XIOSyslogNotifier -Enable -Target syslog0.dom.com,syslog1.dom.com:515
	Enable the SyslogNotifier and set two targets, one that will use the default port of 514 (as none was specified), and one that will use custom port 515
	.Outputs
	XioItemInfo.SyslogNotifier object for the modified object if successful
#>
function Set-XIOSyslogNotifier {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.SyslogNotifier])]
	param(
		## SyslogNotifier object to modify
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.SyslogNotifier]$SyslogNotifier,
		## Switch:  Enable/disable SyslogNotifier (enable via -Enable, disable via -Enable:$false)
		[Switch]$Enable,
		## For when enabling the SyslogNotifier, the syslog target(s) to use.  If none specified, the existing Targets for the SyslogNotifier will be retained/used, if any (if none already in use, will throw error with informative message).
		[String[]]$Target
	) ## end param

	Process {
		## the API-specific pieces for modifying the XIO object's properties
		$hshSetItemSpec = if ($Enable) {
			@{
				enable = $true
				## if someone specified the target(s), use them; else, pass the .Target value from the existing SyslogNotifier object
				targets = $(if ($PSBoundParameters.ContainsKey("Target")) {$Target} else {if (($SyslogNotifier.Target | Measure-Object).Count -gt 0) {$SyslogNotifier.Target} else {Throw "No Target specified and this SyslogNotifier had none to start with.  SyslogNotifier must have one or more targets when enabled. Please specify a Target"}})
			}
		} else {@{disable = $true}}

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForSetItem = @{
			SpecForSetItem = $hshSetItemSpec | ConvertTo-Json
			XIOItemInfoObj = $SyslogNotifier
		} ## end hashtable

		## call the function to actually modify this item
		Set-XIOItemInfo @hshParamsForSetItem
	} ## end process
} ## end function


<#	.Description
	Modify an XtremIO Tag
	.Example
	Set-XIOTag -Tag (Get-XIOTag /InitiatorGroup/myTag) -Caption myTag_renamed
	Set a new caption for the given Tag from the existing object itself
	.Example
	Get-XIOTag -Name /InitiatorGroup/myTag | Set-XIOTag -Caption myTag_renamed
	Set a new caption for the given Tag from the existing object itself (via pipeline)
	.Outputs
	XioItemInfo.Tag object for the modified object if successful
#>
function Set-XIOTag {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.Tag])]
	param(
		## Tag object to modify
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.Tag]$Tag,
		## New caption to set for Tag
		[parameter(Mandatory=$true)][string]$Caption
	) ## end param

	Process {
		## the API-specific pieces for modifying the XIO object's properties
		$hshSetItemSpec = @{
			caption = $Caption
		} ## end hashtable

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForSetItem = @{
			SpecForSetItem = $hshSetItemSpec | ConvertTo-Json
			XIOItemInfoObj = $Tag
		} ## end hashtable

		## call the function to actually modify this item
		Set-XIOItemInfo @hshParamsForSetItem
	} ## end process
} ## end function


<#	.Description
	Modify an XtremIO UserAccount
	.Example
	Get-XIOUserAccount -Name someUser0 | Set-XIOUserAccount -UserName someUser0_renamed -SecureStringPassword (Read-Host -AsSecureString)
	Change the username for this UserAccount, and set the password to the new value (without showing the password in clear-text)
	.Example
	Set-XIOUserAccount -UserAccount (Get-XIOUserAccount someUser0) -InactivityTimeout 0 -Role read_only
	Disable the inactivity timeout value for this UserAccount, and set the user's role to read_only
	.Outputs
	XioItemInfo.UserAccount object for the modified object if successful
#>
function Set-XIOUserAccount {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.UserAccount])]
	param(
		## UserAccount object to modify
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.UserAccount]$UserAccount,
		## The new username to set for this UserAccount
		[string]$UserName,
		## Password in SecureString format.  Easily made by something like the following, which will prompt for entering password, does not display it in clear text, and results in a SecureString to be used:  -SecureStringPassword (Read-Host -AsSecureString -Prompt "Enter some password")
		[parameter(ParameterSetName="SpecifySecureStringPassword")][System.Security.SecureString]$SecureStringPassword,
		## Public key for UserAccount; use either -SecureStringPassword or -UserPublicKey
		[parameter(ParameterSetName="SpecifyPublicKey")][ValidateLength(16,2048)][string]$UserPublicKey,
		## User role.  One of 'read_only', 'configuration', 'admin', or 'technician'. To succeed in adding a user with "technician" role, seems that you may need to authenticated to the XMS _as_ a technician first (as administrator does not succeed)
		[ValidateSet('read_only', 'configuration', 'admin', 'technician')]$Role,
		## Inactivity timeout in minutes. Provide value of zero ("0") to specify "no timeout" for this UserAccount
		[int]$InactivityTimeout
	) ## end param

	Process {
		## the API-specific pieces for modifying the XIO object's properties
		$hshSetItemSpec = @{}

		if ($PSBoundParameters.ContainsKey("UserName")) {$hshSetItemSpec["usr-name"] = $UserName}
		if ($PSBoundParameters.ContainsKey("Role")) {$hshSetItemSpec["role"] = $Role}
		if ($PSBoundParameters.ContainsKey("SecureStringPassword")) {$hshSetItemSpec["password"] = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureStringPassword))}
		if ($PSBoundParameters.ContainsKey("UserPublicKey")) {$hshSetItemSpec["public-key"] = $UserPublicKey}
		if ($PSBoundParameters.ContainsKey("InactivityTimeout")) {$hshSetItemSpec["inactivity-timeout"] = $InactivityTimeout}

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForSetItem = @{
			SpecForSetItem = $hshSetItemSpec | ConvertTo-Json
			XIOItemInfoObj = $UserAccount
		} ## end hashtable

		## call the function to actually modify this item
		Set-XIOItemInfo @hshParamsForSetItem
	} ## end process
} ## end function


<#	.Description
	Modify an XtremIO VolumeFolder. Not yet functional for XIOS v3.x and older
	.Example
	Set-XIOVolumeFolder -VolumeFolder (Get-XIOVolumeFolder /mattTestFolder) -Caption mattTestFolder_renamed
	Set a new caption for the given VolumeFolder from the existing object itself
	.Example
	Get-XIOVolumeFolder /mattTestFolder | Set-XIOVolumeFolder -Caption mattTestFolder_renamed
	Set a new caption for the given VolumeFolder from the existing object itself (via pipeline)
	.Outputs
	XioItemInfo.VolumeFolder object for the modified object if successful
#>
function Set-XIOVolumeFolder {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.VolumeFolder])]
	param(
		## Volume Folder object to modify
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.VolumeFolder]$VolumeFolder,
		## New caption to set for volume folder
		[parameter(Mandatory=$true)][string]$Caption
	) ## end param

	Begin {
		## this item type (singular)
		# $strThisItemType = "volume-folder"
	} ## end begin

	Process {
		## the API-specific pieces for modifying the XIO object's properties
		## set argument name based on XIOS version (not functional yet -- not yet testing XIOS version, so always defaults to older-than-v4 right now)
## INCOMPLETE for older-than-v4 XIOS:  still need to do the determination for $intXiosMajorVersion; on hold while working on addint XIOSv4 object support
		# $strNewCaptionArgName = if ($intXiosMajorVersion -lt 4) {"new-caption"} else {"caption"}
		$strNewCaptionArgName = "caption"
		$hshSetItemSpec = @{
			$strNewCaptionArgName = $Caption
		} ## end hashtable

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForSetItem = @{
			SpecForSetItem = $hshSetItemSpec | ConvertTo-Json
			## not needed while not supporting object-by-name for Set command
			# ItemType = $strThisItemType
			# ComputerName = $ComputerName
		} ## end hashtable

		## check if specifying object by name or by object (object-by-name not currently implemented)
		# if ($VolumeFolder -is [XioItemInfo.VolumeFolder]) {$hshParamsForSetItem["XIOItemInfoObj"] = $VolumeFolder}
		# else {$hshParamsForSetItem["ItemName"] = $VolumeFolder}
		$hshParamsForSetItem["XIOItemInfoObj"] = $VolumeFolder

		## call the function to actually modify this item
		Set-XIOItemInfo @hshParamsForSetItem
	} ## end process
} ## end function
