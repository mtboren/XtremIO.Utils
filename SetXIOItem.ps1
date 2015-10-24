<#	.Description
	Function to set XtremIO item info using REST API with XtremIO XMS appliance
	.Outputs
	PSCustomObject
#>
function Set-XIOItemInfo {
	[CmdletBinding(DefaultParameterSetName="ByComputerName", SupportsShouldProcess=$true, ConfirmImpact=[System.Management.Automation.Confirmimpact]::High)]
	param(
		## XMS appliance address to which to connect
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item type for which to set info
		[parameter(Mandatory=$true,ParameterSetName="ByComputerName")]
		[ValidateSet("ig-folder", "initiator-group", "initiator", "volume", "volume-folder")]
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


<# general process:
-get item
	-Switch (ParamSet)
		ByComputerName
			-get the item by name
				-if not valid, error
		SpecifyFullUri
			-get item by URI
				-if not valid, error
		ByXioItemInfoObj
			-continue on
-try to PUT request
	-takes the URI and the JSON

#>
<#	.Description
	Set properties of an XtremIO item, like a volume, initiator group, etc.  Used as helper function to the Set-XIO* functions that are each for modifying items of a specific type
	.Outputs
	XioItemInfo object for the newly updated object if successful
#>
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
				$strShouldProcessOutput = "Set {0} propert{1} for '{2}' object named '{3}'" -f $intNumPropertyToSet, $(if ($intNumPropertyToSet -eq 1) {"y"} else {"ies"}), $oExistingXioItem.GetType().Name, $oExistingXioItem.Name
				if ($PsCmdlet.ShouldProcess($oThisXioConnection.ComputerName, $strShouldProcessOutput)) {
					## make params hashtable for new WebRequest
					$hshParamsToSetXIOItem = @{
						## make URI
						Uri = $oExistingXioItem.Uri
						## JSON contents for body, for the params for creating the new XIO object
						Body = $SpecForSetItem
						## set method
						Method = "Put"
						## do something w/ creds to make Headers
						Headers = @{Authorization = (Get-BasicAuthStringFromCredential -Credential $oThisXioConnection.Credential)}
					} ## end hashtable

					## try request
					try {
						Write-Debug "$strLogEntry_ToAdd hshParamsToSetXIOItem: `n$(dWrite-ObjectToTableString -ObjectToStringify $hshParamsToSetXIOItem)"
						$oWebReturn = Invoke-WebRequest @hshParamsToSetXIOItem
					} ## end try
					## catch, write-error, break
					catch {Write-Error $_; break}
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
	Modify an XtremIO volume-folder. Not yet functional for XIOS v4 and newer
	.Example
	.Outputs
	XioItemInfo.VolumeFolder object for the modified object if successful
#>
function Set-XIOVolumeFolder {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.VolumeFolder])]
	param(
		## XMS appliance to use
		[parameter(Position=0)][string[]]$ComputerName,
		## New name to set for volume
		[parameter(Mandatory=$true)][string]$Name,
		## Volume Folder to modify; either a VolumeFolder object or the name of the Volume folder to modify
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][ValidateScript({
			_Test-TypeOrString -Object $_ -Type ([XioItemInfo.VolumeFolder])
		})]
		[PSObject]$VolumeFolder
	) ## end param

	Begin {
		## this item type (singular)
		$strThisItemType = "volume-folder"
	} ## end begin

	Process {
		## the API-specific pieces for modifying the XIO object's properties
		## set argument name based on XIOS version (not functional yet -- not yet testing XIOS version, so always defaults to older-than-v4 right now)
## INCOMPLETE:  still need to do the determination for $intXiosMajorVersion; on hold while working on addint XIOSv4 object support
		$strNewCaptionArgName = if ($intXiosMajorVersion -lt 4) {"new-caption"} else {"caption"}
		$hshSetItemSpec = @{
			$strNewCaptionArgName = $Name
		} ## end hashtable

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForSetItem = @{
			SpecForSetItem = $hshSetItemSpec | ConvertTo-Json
		} ## end hashtable

		if ($VolumeFolder -is [XioItemInfo.VolumeFolder]) {$hshParamsForSetItem["XIOItemInfoObj"] = $VolumeFolder}
		else {$hshParamsForSetItem["ItemName"] = $VolumeFolder}
		$hshParamsForSetItem["ComputerName"] = $ComputerName
		$hshParamsForSetItem["ItemType"] = $strThisItemType

		## call the function to actually modify this item
		Set-XIOItemInfo @hshParamsForSetItem
	} ## end process
} ## end function
