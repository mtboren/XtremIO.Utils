<#	.Description
	Function to set XtremIO item info using REST API with XtremIO XMS appliance
	.Outputs
	PSCustomObject
#>
function Set-XIOItemInfo {
	[CmdletBinding(DefaultParameterSetName="ByComputerName", SupportsShouldProcess=$true)]
	param(
		## XMS appliance address to which to connect
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName_arr,
		## Item type for which to set info
		[parameter(Mandatory=$true,ParameterSetName="ByComputerName")]
		[ValidateSet("ig-folder", "initiator-group", "initiator", "volume", "volume-folder")]
		[string]$ItemType_str,
		## Item name for which to set info
		[parameter(Position=0,ParameterSetName="ByComputerName")][string]$Name,
		## JSON for the body of the POST WebRequest, for specifying the properties for modifying the XIO object
		[parameter(Mandatory=$true)][ValidateScript({ try {ConvertFrom-Json -InputObject $_ -ErrorAction:SilentlyContinue | Out-Null; $true} catch {$false} })][string]$SpecForSetItem_str,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str
	) ## end param


<# general process:
-get item
	-Switch (ParamSet)
		ByComputerName
			-get the item by name
				-if not valid, error
		SpecifyFullUri
			-get item by URI
				-if not valid, error
-try to Put request
	-takes the URI and the JSON

#>
<#	.Description
	Create a new XtremIO item, like a volume, initiator group, etc.  Used as helper function to the New-XIO* functions that are each for a new item of a specific type
	.Outputs
	XioItemInfo object for the newly created object if successful
#>
	Begin {
		## from the param value, make the plural form (the item types in the API are all plural; adding "s" here to the singular form used for valid param values, the singular form being the standard for PowerShell-y things)
		$strItemType_plural = "${ItemType_str}s"
		## the base portion of the REST command to issue
		$strRestCmd_base = "/types/$strItemType_plural"
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## get the XIO connections to use
		$arrXioConnectionsToUse = Get-XioConnectionsToUse -ComputerName $ComputerName_arr
	} ## end begin

	Process {
		## make hashtable of params for the Get call (that verifies if any such object by given name exists); remove any extra params that were copied in that are not used for the Get call, or where the param name is not quite the same in the subsequent function being called
		$hshParamsForGetItem = $PSBoundParameters; "SpecForNewItem_str","WhatIf" | %{$hshParamsForGetItem.Remove($_) | Out-Null}
		## if the item type is of "lun-map", do not need to get XIO Item Info again, as that is already done in the New-XIOLunMap call, and was $null at that point, else it would not have progressed to _this_ point
		$oExistingXioItem = if ($ItemType_str -eq "lun-map") {$null} else {Get-XIOItemInfo @hshParamsForGetItem}
		## if such an item already exists, write a warning and stop
		if ($null -ne $oExistingXioItem) {Write-Warning "Item of name '$Name' and type '$ItemType_str' already exists on '$($oExistingXioItem.ComputerName -join ", ")'. Taking no action"; break;} ## end if
		## else, actually try to make such an object
		else {
			$arrXioConnectionsToUse | Foreach-Object {
				$oThisXioConnection = $_
				if ($PsCmdlet.ShouldProcess($oThisXioConnection.ComputerName, "Create new '$ItemType_str' object named '$Name'")) {
					## make params hashtable for new WebRequest
					$hshParamsToCreateNewXIOItem = @{
						## make URI
						Uri = $(
							$hshParamsForNewXioApiURI = @{ComputerName_str = $oThisXioConnection.ComputerName; RestCommand_str = $strRestCmd_base; Port_int = $oThisXioConnection.Port}
							New-XioApiURI @hshParamsForNewXioApiURI)
						## JSON contents for body, for the params for creating the new XIO object
						Body = $SpecForNewItem_str
						## set method to Post
						Method = "Post"
						## do something w/ creds to make Headers
						Headers = @{Authorization = (Get-BasicAuthStringFromCredential -Credential $oThisXioConnection.Credential)}
					} ## end hashtable

					## try request
					try {
						Write-Debug "$strLogEntry_ToAdd hshParamsToCreateNewXIOItem: `n$($hshParamsToCreateNewXIOItem | Format-Table | Out-String)"
						$oWebReturn = Invoke-WebRequest @hshParamsToCreateNewXIOItem
					} ## end try
					## catch, write-error, break
					catch {Write-Error $_; break}
					## if good, write-verbose the status and, if status is "Created", Get-XIOInfo on given HREF
					if (($oWebReturn.StatusCode -eq $hshCfg["StdResponse"]["Post"]["StatusCode"] ) -and ($oWebReturn.StatusDescription -eq $hshCfg["StdResponse"]["Post"]["StatusDescription"])) {
						Write-Verbose "$strLogEntry_ToAdd Item created successfully. StatusDescription: '$($oWebReturn.StatusDescription)'"
						## use the return's links' hrefs to return the XIO item(s)
						($oWebReturn.Content | ConvertFrom-Json).links | Foreach-Object {Get-XIOItemInfo -URI $_.href}
					} ## end if
				} ## end if ShouldProcess
			} ## end foreach-object
		} ## end else
	} ## end process
} ## end function



<#	.Description
	Modify an XtremIO volume-folder
	.Example
	.Outputs
	XioItemInfo.VolumeFolder object for the modified object if successful
#>
function Set-XIOVolumeFolder {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.VolumeFolder])]
	param(
		## XMS appliance to use
		[parameter(Position=0)][string[]]$ComputerName_arr,
		## New name to set for volume
		[parameter(Mandatory=$true)][string]$Name,
		## Volume Folder to modify; either a VolumeFolder object or the name of the Volume folder to modify
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][ValidateScript({
			_Test-TypeOrString -Object $_ -Type ([XioItemInfo.VolumeFolder])
		})]
		[PSObject]$VolumeFolder,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str
	) ## end param

	Begin {
		## this item type (singular)
		$strThisItemType = "volume-folder"
	} ## end begin

	Process {
		## the API-specific pieces for modifying the XIO object's properties
		$hshSetItemSpec = @{
			"new-caption" = $Name
		} ## end hashtable

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForSetItem = @{
			ComputerName = $ComputerName_arr
			ItemType_str = $strThisItemType
			SpecForSetItem_str = $hshSetItemSpec | ConvertTo-Json
		} ## end hashtable

		Switch ($PsCmdlet.ParameterSetName) {
			"SpecifyFullUri" {$hshParamsForSetItem["URI_str"] = $URI_str; break}
			default {
				if ($VolumeFolder -is [XioItemInfo.VolumeFolder]) {$hshParamsForSetItem["URI_str"] = $VolumeFolder.Uri}
				else {$hshParamsForSetItem["ItemName"] = $VolumeFolder}
			} ## end case
		} ## end switch
		Write-Debug "done in Set-XIOVolumeFolder, now to call Set"
		## call the function to actually modify this item
		#Set-XIOItem @hshParamsForSetItem
	} ## end process
} ## end function
