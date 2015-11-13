<#	.Description
	Create a new XtremIO item, like a volume, initiator group, etc.  Used as helper function to the New-XIO* functions that are each for a new item of a specific type
	.Outputs
	XioItemInfo object for the newly created object if successful
#>
function New-XIOItem {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		##  address to which to connect
		[parameter(Position=0)][string[]]$ComputerName_arr,
		## Item type to create; currently supported types:
		##   for all API versions:  "ig-folder", "initiator, "initiator-group", "lun-map", "volume", "volume-folder"
		[ValidateSet("ig-folder","initiator","initiator-group","lun-map","volume","volume-folder")][parameter(Mandatory=$true)][string]$ItemType_str,
		## JSON for the body of the POST WebRequest, for specifying the properties for the new XIO object
		[parameter(Mandatory=$true)][ValidateScript({ try {ConvertFrom-Json -InputObject $_ -ErrorAction:SilentlyContinue | Out-Null; $true} catch {$false} })][string]$SpecForNewItem_str,
		## Item name being made (for checking if such item already exists)
		[parameter(Mandatory=$true)][string]$Name
	) ## end param

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
						Write-Debug "$strLogEntry_ToAdd hshParamsToCreateNewXIOItem: `n$(dWrite-ObjectToTableString -ObjectToStringify $hshParamsToCreateNewXIOItem)"
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
	Create a new XtremIO initiator-group, optionally with initiators defined at creation time
	.Notes
	One cannot create a new initiator group with a port address that is already used in another initiator on the XMS -- this will fail.
	Similarly, attempting to create an initiator group that contains an initiator name already defined on the XMS will fail.
	.Example
	New-XIOInitiatorGroup -Name testIG0 -ParentFolder "/testIGs" -InitiatorList @{"myserver-hba2" = "10:00:00:00:00:00:00:F4"; "myserver-hba3" = "10:00:00:00:00:00:00:F5"}
	Create an initiator-group named testIG0 with two initiators defined therein
	.Outputs
	XioItemInfo.InitiatorGroup object for the newly created object if successful
#>
function New-XIOInitiatorGroup {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.InitiatorGroup])]
	param(
		## XMS address to use
		[parameter(Position=0)][string[]]$ComputerName_arr,
		## Name for new initiator-group being made
		[parameter(Mandatory=$true)][string]$Name_str,
		## The initiator-name and port-address for each initiator you want to add to the group, if any (why not, though?). Each key/value pair shall use initiator-name as the key, and the corresponding port-address for the value.
		#For the port addresses, valid values are colon-separated hex numbers, non-separated hex numbers, or non-separated hex numbers prefixed with "0x".  That is, the following formats are acceptable for port-address values:  XX:XX:XX:XX:XX:XX:XX:XX, XXXXXXXXXXXXXXXX, or 0xXXXXXXXXXXXXXXXX
		#Example hashtable for two initiators named "myserver-hba2" and "myserver-hba3":
		#    @{"myserver-hba2" = "10:00:00:00:00:00:00:F4"; "myserver-hba3" = "10:00:00:00:00:00:00:F5"}
		[System.Collections.Hashtable]$InitiatorList_hsh,
		## The initiator group's parent folder. The folder's Folder Type must be IG. If omitted, the volume will be added to the root IG folder. Example value: "/IGsForMyCluster0"
		[ValidateScript({$_.StartsWith("/")})][string]$ParentFolder_str
	) ## end param

	Begin {
		## this item type (singular)
		$strThisItemType = "initiator-group"
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
	} ## end begin

	Process {
		## the API-specific pieces that define the new XIO object's properties
		$hshNewItemSpec = @{
			"ig-name" = $Name_str
		} ## end hashtable
		## add these if bound
		## make array of new hashtables, add to NewItemSpec hashtable; these new hashtables have backslash-escaped double-quoted values (using key/value pairs from parameter value)
		if ($PSBoundParameters.ContainsKey("InitiatorList_hsh")) {
			## for each key in the hashtable, make a new hashtable for the array that holds the initiators info (this is an array of hashtables); Values will have escaped double-quotes added by the function, as this is the current format expected by the XtremIO API
			$InitiatorList_hsh.Keys | Foreach-Object -begin {$arrInitiatorsInfo = @()} -process {
				$strKey = $_
				## add a hash to the array of initiator definitions
				$arrInitiatorsInfo += @{"initiator-name" = ('\"{0}\"' -f $strKey); "port-address" = ('\"{0}\"' -f $InitiatorList_hsh[$strKey])}
			} ## end foreach-object
			$hshNewItemSpec["initiator-list"] = $arrInitiatorsInfo
		} ## end if
		if ($PSBoundParameters.ContainsKey("ParentFolder_str")) {$hshNewItemSpec["parent-folder-id"] = $ParentFolder_str}
		## the params to use in calling the helper function to actually create the new object
		$hshParamsForNewItem = @{
			ComputerName = $ComputerName_arr
			ItemType_str = $strThisItemType
			Name = $Name_str
			## need to replace triple backslash with single backslash where there is a backslash in the literal value of some field (as req'd by new initiator group call); triple-backslashes come about due to ConvertTo-Json escaping backslashes with backslashes, but causes issue w/ the format expected by XIO API
			SpecForNewItem_str = ($hshNewItemSpec | ConvertTo-Json).Replace("\\\","\")
		} ## end hashtable

		Write-Debug "$strLogEntry_ToAdd SpecForNewItem_str:`n$($hshParamsForNewItem["SpecForNewItem_str"])"

		## call the function to actually make this new item
		New-XIOItem @hshParamsForNewItem
	} ## end process
} ## end function


<#	.Description
	Create a new XtremIO initiator in an existing initator group
	.Notes
	Does not yet support creating iSCSI initiators
	.Example
	New-XIOInitiator -Name myserver0-hba2 -InitiatorGroup myserver0 -PortAddress 0x100000000000ab56
	Create a new initiator in the initiator group "myserver0"
	.Example
	New-XIOInitiator -Name myserver0-hba2 -InitiatorGroup myserver0 -PortAddress 10:00:00:00:00:00:00:54
	Create a new initiator in the initiator group "myserver0"
	.Outputs
	XioItemInfo.Initiator object for the newly created object if successful
#>
function New-XIOInitiator {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.Initiator])]
	param(
		## XMS address to use
		[parameter(Position=0)][string[]]$ComputerName_arr,
		## Name for new initiator being made
		[parameter(Mandatory=$true)][string]$Name_str,
		## The existing initiator group name to which associate the initiator
		[parameter(Mandatory=$true)][string]$InitiatorGroup,
		## The initiator's port address.  The following rules apply:
		#-For FC initiators, any of the following formats are allowed ("X" is a hexadecimal digit – uppercase and lower case are allowed):
		#	XX:XX:XX:XX:XX:XX:XX:XX
		#	XXXXXXXXXXXXXXXX
		#	0xXXXXXXXXXXXXXXXX
		#-For iSCSI initiators, IQN and EUI formats are allowed
		#-Two initiators cannot share the same port address
		#-You cannot specify an FC address for an iSCSI target and vice-versa
		[parameter(Mandatory=$true)][ValidateScript({$_ -match "^((0x)?[0-9a-f]{16}|(([0-9a-f]{2}:){7}[0-9a-f]{2}))$"})][string]$PortAddress
	) ## end param

	Begin {
		## this item type (singular)
		$strThisItemType = "initiator"
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
	} ## end begin

	Process {
		## the API-specific pieces that define the new XIO object's properties
		$hshNewItemSpec = @{
			"initiator-name" = $Name_str
			"ig-id" = $InitiatorGroup
			"port-address" = $PortAddress
		} ## end hashtable
		## add these if bound
		## the params to use in calling the helper function to actually create the new object
		$hshParamsForNewItem = @{
			ComputerName = $ComputerName_arr
			ItemType_str = $strThisItemType
			Name = $Name_str
			## need to replace triple backslash with single backslash where there is a backslash in the literal value of some field (as req'd by new initiator group call); triple-backslashes come about due to ConvertTo-Json escaping backslashes with backslashes, but causes issue w/ the format expected by XIO API
			SpecForNewItem_str = $hshNewItemSpec | ConvertTo-Json
		} ## end hashtable

		Write-Debug "$strLogEntry_ToAdd SpecForNewItem_str:`n$($hshParamsForNewItem["SpecForNewItem_str"])"

		## call the function to actually make this new item
		New-XIOItem @hshParamsForNewItem
	} ## end process
} ## end function


<#	.Description
	Create a new XtremIO initiator-group-folder
	.Example
	New-XIOInitiatorGroupFolder -Name someDeeperFolder -ParentFolder /myMainIGroups
	Create a subfolder "someDeeperFolder" in parent folder "/myMainIGroups"
	.Outputs
	XioItemInfo.IgFolder object for the newly created object if successful
#>
function New-XIOInitiatorGroupFolder {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.IgFolder])]
	param(
		## XMS address to use
		[parameter(Position=0)][string[]]$ComputerName_arr,
		## Name for new volume being made
		[parameter(Mandatory=$true)][string]$Name_str,
		## parent folder in which to make this folder; defaults to "/"
		[ValidateScript({$_.StartsWith("/")})][string]$ParentFolder = "/"
	) ## end param

	Begin {
		## this item type (singular)
		$strThisItemType = "ig-folder"
	} ## end begin

	Process {
		## the API-specific pieces that define the new XIO object's properties
		$hshNewItemSpec = @{
			"caption" = $Name_str
			"parent-folder-id" = $ParentFolder
		} ## end hashtable

		## the params to use in calling the helper function to actually create the new object
		$hshParamsForNewItem = @{
			ComputerName = $ComputerName_arr
			ItemType_str = $strThisItemType
			Name = $Name_str
			SpecForNewItem_str = $hshNewItemSpec | ConvertTo-Json
		} ## end hashtable

		## call the function to actually make this new item
		New-XIOItem @hshParamsForNewItem
	} ## end process
} ## end function


<#	.Description
	Create a new XtremIO LUN mapping between a volume and an initiator-group
	.Example
	New-XIOLunMap -Volume someVolume02 -InitiatorGroup myIG0,myIG1 -HostLunId 21
	Create a new LUN mapping for volume "someVolume02" to the two given initiator groups, using host LUN ID of 21
	.Outputs
	XioItemInfo.LunMap object for the newly created object if successful
#>
function New-XIOLunMap {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.LunMap])]
	param(
		## XMS address to use
		[parameter(Position=0)][string[]]$ComputerName_arr,
		## The name of the volume to map
		[parameter(Mandatory=$true)][string]$Volume,
		## The names of one or more initiator groups to which to map volume
		[parameter(Mandatory=$true)][string[]]$InitiatorGroup,
		## Unique Host LUN ID (decimal), exposing the volume to the host (16K LUN mappings are currently supported)
		[parameter(Mandatory=$true)][int]$HostLunId,
		## Name of target group. May be omitted only if the cluster involved contains exactly one target group. In that case, the volume is mapped to that target group. Default value is "Default"
		[string]$TargetGroup = "Default"
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## this item type (singular)
		$strThisItemType = "lun-map"
	} ## end begin

	Process {
		## if a mapping with these properties already exists, do not proceed
		$arrExistingLUNMaps = Get-XIOLunMap -Volume $Volume -InitiatorGroup $InitiatorGroup -ComputerName $ComputerName_arr
		if ($null -ne $arrExistingLUNMaps) {Write-Warning "LUN mapping already exists for this volume/LUNID/initiator group combination:`n$(dWrite-ObjectToTableString -ObjectToStringify ($arrExistingLUNMaps | Select-Object VolumeName, LunId, InitiatorGroup, tg-name, ComputerName))`nNot continuing."}
		## else, go ahead an try to make the new LUN mappings
		else {
			$InitiatorGroup | Foreach-Object {
				## the API-specific pieces that define the new XIO object's properties
				$hshNewItemSpec = @{
					"vol-id" = $Volume
					"ig-id" = $_
					"lun" = $HostLunId
					"tg-id" = $TargetGroup
				} ## end hashtable

				## the params to use in calling the helper function to actually create the new object
				$hshParamsForNewItem = @{
					ComputerName = $ComputerName_arr
					ItemType_str = $strThisItemType
					Name = "${Volume}_${InitiatorGroup}_${HostLunId}"
					SpecForNewItem_str = $hshNewItemSpec | ConvertTo-Json
				} ## end hashtable

				## call the function to actually make this new item
				New-XIOItem @hshParamsForNewItem
			} ## end foreach-object
		} ## end else
	} ## end process
} ## end function


<#	.Description
	Create a new XtremIO volume
	.Example
	New-XIOVolume -Name testvol03 -SizeGB 2KB -ParentFolder "/testVols"
	Create a 2TB volume named testvol03
	.Example
	New-XIOVolume -ComputerName somexms01.dom.com -Name testvol04 -SizeGB 5120 -ParentFolder "/testVols"
	Create a 5TB volume named testvol04
	.Example
	New-XIOVolume -Name testvol05 -SizeGB 5KB -ParentFolder "/testVols" -EnableSmallIOAlert -EnableUnalignedIOAlert -EnableVAAITPAlert
	Create a 5TB volume named testvol05 with all three alert types enabled
	.Outputs
	XioItemInfo.Volume object for the newly created object if successful
#>
function New-XIOVolume {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.Volume])]
	param(
		## XMS address to use
		[parameter(Position=0)][string[]]$ComputerName_arr,
		## Name for new volume being made
		[parameter(Mandatory=$true)][string]$Name_str,
		## The alignment offset for volumes of 512 Logical Block size, between 0 and 7. If this property is omitted, the offset value is 0. Volumes of lb-size 4096 must not be defined with an offset.
		[ValidateRange(0,7)][int]$AlignmentOffset_int,
		## The volume's Logical Block size, either 512 (default) or 4096.  Once defined, the size cannot be modified.  If defined as 4096, AlignmentOffset will be ignored
		[ValidateSet(512,4096)][int]$LogicalBlockSize_int = 512,
		## The cluster's name or index number. This value may be omitted if there is only one cluster defined in the XtremIO Storage System.
		[string]$ClusterSysId_str,
		## The disk space size of the volume in GB. This parameter reflects the size of the volume available to the initiators. It does not indicate the actual SSD space this volume may consume
		#   Must be an integer greater than 0 and a multiple of 1 MB.
		[parameter(Mandatory=$true)][ValidateScript({$_ -gt 0})][int]$SizeGB_int,
		## Identifies the volume folder to which this volume will initially belong. The folder's Folder Type must be Volume. If omitted, the volume will be added to the root volume folder. Example value: "/myBigVolumesFolder"
		[ValidateScript({$_.StartsWith("/")})][string]$ParentFolder_str,
		## Switch:  Enable small IO alerts for this volume?  They are disabled by default
		[Switch]$EnableSmallIOAlert,
		## Switch:  Enable unaligned IO alerts for this volume?  They are disabled by default
		[Switch]$EnableUnalignedIOAlert,
		## Switch:  Enable VAAI thin-provisioning alerts for this volume?  They are disabled by default
		[Switch]$EnableVAAITPAlert
	) ## end param

	Begin {
		## this item type (singular)
		$strThisItemType = "volume"
		## the string value to pass for enabling Alert config on new volume
		$strEnableAlertValue = "enabled"
	} ## end begin

	Process {
		## the API-specific pieces that define the new XIO object's properties
		$hshNewItemSpec = @{
			"vol-name" = $Name_str
			## The disk space size of the volume in KB(k)/MB(m)/GB(g)/or TB(t). This parameter reflects the size of the volume available to the initiators. It does not indicate the actual SSD space this volume may consume.
			#   Must be an integer greater than 0 and a multiple of 1 MB.
			"vol-size" = "{0}g" -f $SizeGB_int
		} ## end hashtable
		## add these if bound
		if ($PSBoundParameters.ContainsKey("LogicalBlockSize_int")) {$hshNewItemSpec["lb-size"] = $LogicalBlockSize_int}
		if ($PSBoundParameters.ContainsKey("ParentFolder_str")) {$hshNewItemSpec["parent-folder-id"] = $ParentFolder_str}
		if ($PSBoundParameters.ContainsKey("ClusterSysId_str")) {$hshNewItemSpec["sys-id"] = $ClusterSysId_str}
		## only add this if lb-size is (not bound) or (bound and -ne 4096); "Volumes of lb-size 4096 must not be defined with an offset"
		if ($PSBoundParameters.ContainsKey("AlignmentOffset_int")) {
			if ((-not $PSBoundParameters.ContainsKey("LogicalBlockSize_int")) -or ($LogicalBlockSize_int -ne 4096)) {$hshNewItemSpec["alignment-offset"] = $AlignmentOffset_int}
			else {Write-Warning "Volumes of lb-size 4096 must not be defined with an offset. Not using specified AlignmentOffset"}
		} ## end if

		## set Alerts to enabled for any of the config items specified
		if ($EnableSmallIOAlert) {$hshNewItemSpec["small-io-alerts"] = $strEnableAlertValue}
		if ($EnableUnalignedIOAlert) {$hshNewItemSpec["unaligned-io-alerts"] = $strEnableAlertValue}
		if ($EnableVAAITPAlert) {$hshNewItemSpec["vaai-tp-alerts"] = $strEnableAlertValue}

		## the params to use in calling the helper function to actually create the new object
		$hshParamsForNewItem = @{
			ComputerName = $ComputerName_arr
			ItemType_str = $strThisItemType
			Name = $Name_str
			SpecForNewItem_str = $hshNewItemSpec | ConvertTo-Json
		} ## end hashtable

		## call the function to actually make this new item
		New-XIOItem @hshParamsForNewItem
	} ## end process
} ## end function


<#	.Description
	Create a new XtremIO volume-folder
	.Example
	New-XIOVolumeFolder -Name someDeeperFolder -ParentFolder /myMainVols
	Create a subfolder "someDeeperFolder" in parent folder "/myMainVols"
	.Outputs
	XioItemInfo.VolumeFolder object for the newly created object if successful
#>
function New-XIOVolumeFolder {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.VolumeFolder])]
	param(
		## XMS address to use
		[parameter(Position=0)][string[]]$ComputerName_arr,
		## Name for new volume being made
		[parameter(Mandatory=$true)][string]$Name_str,
		## parent folder in which to make this folder; defaults to "/"
		[ValidateScript({$_.StartsWith("/")})][string]$ParentFolder = "/"
	) ## end param

	Begin {
		## this item type (singular)
		$strThisItemType = "volume-folder"
	} ## end begin

	Process {
		## the API-specific pieces that define the new XIO object's properties
		$hshNewItemSpec = @{
			"caption" = $Name_str
			"parent-folder-id" = $ParentFolder
		} ## end hashtable

		## the params to use in calling the helper function to actually create the new object
		$hshParamsForNewItem = @{
			ComputerName = $ComputerName_arr
			ItemType_str = $strThisItemType
			Name = $Name_str
			SpecForNewItem_str = $hshNewItemSpec | ConvertTo-Json
		} ## end hashtable

		## call the function to actually make this new item
		New-XIOItem @hshParamsForNewItem
	} ## end process
} ## end function
