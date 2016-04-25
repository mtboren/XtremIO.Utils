<#	.Description
	Function to remove XtremIO item using REST API with XtremIO XMS appliance.  Generally used as supporting function to the rest of the Remove-XIO* cmdlets, but can be used directly, too, if needed
	.Outputs
	No output
#>
function Remove-XIOItemInfo {
	[CmdletBinding(DefaultParameterSetName="ByComputerName", SupportsShouldProcess=$true, ConfirmImpact=[System.Management.Automation.Confirmimpact]::High)]
	param(
		## XMS appliance address to which to connect
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Name(s) of cluster in which resides the object to remove
		[parameter(Mandatory=$true,ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Type of item to remove
		[parameter(Mandatory=$true,ParameterSetName="ByComputerName")]
		[ValidateSet("ig-folder", "initiator-group", "initiator", "syslog-notifier", "tag", "user-account", "volume", "volume-folder")]
		[string]$ItemType,
		## Name of item to remove
		[parameter(Position=0,ParameterSetName="ByComputerName")][Alias("ItemName")][string]$Name,
		## JSON for the body of the POST WebRequest, for specifying the properties of the XIO object to remove
		[parameter(Mandatory=$true)][ValidateScript({ try {ConvertFrom-Json -InputObject $_ -ErrorAction:SilentlyContinue | Out-Null; $true} catch {$false} })][string]$SpecForRemoveItem,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI,
		## XioItemInfo object to remove from the XMS
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
					$PSBoundParameters.Keys | Where-Object {"SpecForRemoveItem","WhatIf" -notcontains $_} | Foreach-Object -begin {$hshParamsForGetItem = @{}} -process {$hshParamsForGetItem[$_] = $PSBoundParameters[$_]}
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
				## the Remove items' specification, from JSON; PSCustomObject with properties/values to be set
				$oRemoveSpecItem = ConvertFrom-Json -InputObject $SpecForRemoveItem
				$intNumPropertyToSet = ($oRemoveSpecItem | Get-Member -Type NoteProperty | Measure-Object).Count
				## make a string to display the properties being used for the removal in the -WhatIf and -Confirm types of messages
				$strPropertiesOfObjToRemove = ($SpecForRemoveItem.Trim("{}").Split("`n") | Where-Object {-not [System.String]::IsNullOrEmpty($_.Trim())}) -join "`n"
				$strShouldProcessOutput = "Remove XIO '{2}' object named '{3}' with the following {0} propert{1}:`n{4}`n" -f $intNumPropertyToSet, $(if ($intNumPropertyToSet -eq 1) {"y"} else {"ies"}), $oExistingXioItem.GetType().Name, $oExistingXioItem.Name, $strPropertiesOfObjToRemove
				if ($PsCmdlet.ShouldProcess($oThisXioConnection.ComputerName, $strShouldProcessOutput)) {
					## make params hashtable for new WebRequest
					$hshParamsToSetXIOItem = @{
						Uri = $oExistingXioItem.Uri
						## JSON contents for body, for the params for creating the new XIO object
						Body = $SpecForRemoveItem
						Method = "Delete"
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
					if (($oWebReturn.StatusCode -eq $hshCfg["StdResponse"]["Delete"]["StatusCode"] ) -and ($oWebReturn.StatusDescription -eq $hshCfg["StdResponse"]["Delete"]["StatusDescription"])) {
						Write-Verbose "$strLogEntry_ToAdd Item removed successfully. StatusDescription: '$($oWebReturn.StatusDescription)'"
					} ## end if
				} ## end if ShouldProcess
			} ## end foreach-object
		} ## end else
	} ## end process
} ## end function



<#	.Description
	Remove an XtremIO IGFolder (InitiatorGroup folder). In modern XIOS versions, InitiatorGroups(s) that might reside in the IGFolder are not disturbed by the removal, they just have a new parent folder (the root IGFolder).  However, in some older XIOS versions, the folder must be empty before removal (verified to be the case in XIOS v2.4).
	.Example
	Get-XIOInitiatorGroupFolder /someFolder/someDeeperFolderToRemove | Remove-XIOInitiatorGroupFolder
	Removes the given InitiatorGroupFolder, "someDeeperFolderToRemove".
	.Outputs
	No output upon successful removal
#>
function Remove-XIOInitiatorGroupFolder {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		## InitiatorGroupFolder object to remove
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.IGFolder]$InitiatorGroupFolder
	) ## end param

	Process {
		## the API-specific pieces for specifying the XIO object to remove
		$hshRemoveItemSpec = @{
			## IGFolder's ig-folder-name (name or index, but, using name, of course, because by-index is no fun); though, it appears that the API might be gleaning the folder-id from the URI, and not using the folder name
			"ig-folder-name" = $InitiatorGroupFolder.Name
			## FYI:  API may replace this with "ig", at least in older XIOS
			"folder-type" = "InitiatorGroup"
		} ## end hashtable

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForRemoveItem = @{
			SpecForRemoveItem = $hshRemoveItemSpec | ConvertTo-Json
			XIOItemInfoObj = $InitiatorGroupFolder
		} ## end hashtable

		## call the function to actually remove this item
		Remove-XIOItemInfo @hshParamsForRemoveItem
	} ## end process
} ## end function


<#	.Description
	Remove an XtremIO SnapshotScheduler.  API does not yet support deleting the associated SnapshotSets.
	.Example
	Get-XIOSnapshotScheduler myScheduler0 | Remove-XIOSnapshotScheduler
	Removes the given SnapshotScheduler, but leaves intact any SnapshotSets that it created and that are still present
	.Outputs
	No output upon successful removal
#>
function Remove-XIOSnapshotScheduler {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		## SnapshotScheduler object to remove
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.SnapshotScheduler]$SnapshotScheduler
	) ## end param

	Process {
		## the API-specific pieces for specifying the XIO object to remove
		$hshRemoveItemSpec = @{
			## API doc says that cluster-id is valid, but the SnapshotScheduler does not have a Cluster property (no sys-id property returned via API)
			# "cluster-id" = <something>
			## Events show this param, but API does not accept it (ignores it, it seems)
			# "remove-snapshot-sets" = ($true -eq $DeleteRelatedSnapshotSet)
			## SnapshotScheduler's scheduler-id (name or index, but, using name, of course, because by-index is no fun)
			"scheduler-id" = $SnapshotScheduler.Name
		} ## end hashtable

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForRemoveItem = @{
			SpecForRemoveItem = $hshRemoveItemSpec | ConvertTo-Json
			# XIOItemInfoObj = $SnapshotScheduler
			## for this particular obj type, API v2 in at least XIOS v4.0.2-80 does not deal well with URI that has "?cluster-name=myclus01" in it -- API tries to use the "name=myclus01" part when determining the ID of this object; so, removing that bit from this object's URI (if there)
			Uri = _Remove-ClusterNameQStringFromURI -URI $SnapshotScheduler.Uri
		} ## end hashtable

		## call the function to actually remove this item
		Remove-XIOItemInfo @hshParamsForRemoveItem
	} ## end process
} ## end function


<#	.Description
	Remove an XtremIO Tag.  Does not disturb objects that are tagged with the Tag being removed, except that they no longer have that Tag associated with them.
	.Example
	Get-XIOTag /Volume/myVolTag0 | Remove-XIOTag
	Removes the given Tag.
	.Outputs
	No output upon successful removal
#>
function Remove-XIOTag {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		## Tag object to remove
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.Tag]$Tag
	) ## end param

	Process {
		## the API-specific pieces for specifying the XIO object to remove
		$hshRemoveItemSpec = @{
			## Tag's tag-id (name or index, but, using name, of course, because by-index is no fun)
			"tag-id" = $Tag.Name
		} ## end hashtable

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForRemoveItem = @{
			SpecForRemoveItem = $hshRemoveItemSpec | ConvertTo-Json
			XIOItemInfoObj = $Tag
		} ## end hashtable

		## call the function to actually remove this item
		Remove-XIOItemInfo @hshParamsForRemoveItem
	} ## end process
} ## end function


<#	.Description
	Remove an XtremIO UserAccount
	.Example
	Get-XIOUserAccount someUser0 | Remove-XIOUserAccount
	Removes the given UserAccount.
	.Outputs
	No output upon successful removal
#>
function Remove-XIOUserAccount {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		## UserAccount object to remove
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.UserAccount]$UserAccount
	) ## end param

	Process {
		## the API-specific pieces for specifying the XIO object to remove
		$hshRemoveItemSpec = @{
			## UserAccount's user-id (name or index, but, using name, of course, because by-index is no fun)
			"user-id" = $UserAccount.Name
		} ## end hashtable

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForRemoveItem = @{
			SpecForRemoveItem = $hshRemoveItemSpec | ConvertTo-Json
			XIOItemInfoObj = $UserAccount
		} ## end hashtable

		## call the function to actually remove this item
		Remove-XIOItemInfo @hshParamsForRemoveItem
	} ## end process
} ## end function


<#	.Description
	Remove an XtremIO VolumeFolder. Volume(s) that might reside in the VolumeFolder are not disturbed by the removal, they just have a new parent folder (the root VolumeFolder)
	.Example
	Get-XIOVolumeFolder /someFolder/someDeeperFolderToRemove | Remove-XIOVolumeFolder
	Removes the given VolumeFolder, "someDeeperFolderToRemove".
	.Outputs
	No output upon successful removal
#>
function Remove-XIOVolumeFolder {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		## VolumeFolder object to remove
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.VolumeFolder]$VolumeFolder
	) ## end param

	Process {
		## the API-specific pieces for specifying the XIO object to remove
		$hshRemoveItemSpec = @{
			## VolumeFolder's folder-name (name or index, but, using name, of course, because by-index is no fun); though, it appears that the API might be gleaning the folder-id from the URI, and not using the folder name
			"folder-name" = $VolumeFolder.Name
			## FYI:  API may replace this with "vol", at least in older XIOS
			"folder-type" = "Volume"
		} ## end hashtable

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForRemoveItem = @{
			SpecForRemoveItem = $hshRemoveItemSpec | ConvertTo-Json
			XIOItemInfoObj = $VolumeFolder
		} ## end hashtable

		## call the function to actually remove this item
		Remove-XIOItemInfo @hshParamsForRemoveItem
	} ## end process
} ## end function
