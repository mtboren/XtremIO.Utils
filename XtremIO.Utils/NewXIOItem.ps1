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
		[ValidateSet("ig-folder","initiator","initiator-group","lun-map","snapshot","volume","volume-folder")][parameter(Mandatory=$true)][string]$ItemType_str,
		## JSON for the body of the POST WebRequest, for specifying the properties for the new XIO object
		[parameter(Mandatory=$true)][ValidateScript({ try {ConvertFrom-Json -InputObject $_ -ErrorAction:SilentlyContinue | Out-Null; $true} catch {$false} })][string]$SpecForNewItem_str,
		## Item name being made (for checking if such item already exists)
		[parameter(Mandatory=$true)][string]$Name,
		## XtremIO REST API version to use
		[System.Version]$XiosRestApiVersion,
		## Cluster for which to create new item
		[string[]]$Cluster
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
		$hshParamsForGetItem = @{}
		$PSBoundParameters.Keys | Where-Object {"SpecForNewItem_str","XiosRestApiVersion","WhatIf" -notcontains $_} | Foreach-Object {$hshParamsForGetItem[$_] = $PSBoundParameters[$_]}
		## if the item type is of "lun-map", do not need to get XIO Item Info again, as that is already done in the New-XIOLunMap call, and was $null at that point, else it would not have progressed to _this_ point
		$oExistingXioItem = if ($ItemType_str -eq "lun-map") {$null} else {Get-XIOItemInfo @hshParamsForGetItem}
		## if such an item already exists, write a warning and stop
		if ($null -ne $oExistingXioItem) {Write-Warning "Item of name '$Name' and type '$ItemType_str' already exists on '$($oExistingXioItem.ComputerName -join ", ")'. Taking no action"; break;} ## end if
		## else, actually try to make such an object
		else {
			$arrXioConnectionsToUse | Foreach-Object {
				$oThisXioConnection = $_
				## for each value for $Cluster, if cluster is specified, else, just one time (as indicated by the empty string -- that is there just to have the Foreach-Object process scriptblock run at least once)
				$(if ($PSBoundParameters.ContainsKey("Cluster")) {$Cluster} else {""}) | Foreach-Object {
					## the cluster name (if any -- might be empty string, but, in that case, will not be used, as code checks PSBoundParameters for Cluster param before using this variable)
					$strThisXioClusterName = $_
					## if the -CLuster param is given, add to the WhatIf msg, and add the "cluster-id" param piece to the JSON body specification
					if ($PSBoundParameters.ContainsKey("Cluster")) {
						$strClusterTidbitForWhatIfMsg = " in cluster '$strThisXioClusterName'"
						$strJsonSpecForNewItem = $SpecForNewItem_str | ConvertFrom-Json | Select-Object *, @{n="cluster-id"; e={$strThisXioClusterName}} | ConvertTo-Json
					} ## end if
					else {
						$strClusterTidbitForWhatIfMsg = $null
						$strJsonSpecForNewItem = $SpecForNewItem_str
					} ## end else
					$strMsgForWhatIf = "Create new '$ItemType_str' object named '$Name'{0}" -f $strClusterTidbitForWhatIfMsg
					if ($PsCmdlet.ShouldProcess($oThisXioConnection.ComputerName, $strMsgForWhatIf)) {
						## make params hashtable for new WebRequest
						$hshParamsToCreateNewXIOItem = @{
							## make URI
							Uri = $(
								$hshParamsForNewXioApiURI = @{ComputerName_str = $oThisXioConnection.ComputerName; RestCommand_str = $strRestCmd_base; Port_int = $oThisXioConnection.Port}
								if ($PSBoundParameters.ContainsKey("XiosRestApiVersion")) {$hshParamsForNewXioApiURI["RestApiVersion"] = $XiosRestApiVersion}
								New-XioApiURI @hshParamsForNewXioApiURI)
							## JSON contents for body, for the params for creating the new XIO object
							Body = $strJsonSpecForNewItem
							## set method to Post
							Method = "Post"
							## do something w/ creds to make Headers
							Headers = @{Authorization = (Get-BasicAuthStringFromCredential -Credential $oThisXioConnection.Credential)}
						} ## end hashtable

						## try request
						try {
							$oWebReturn = Invoke-WebRequest @hshParamsToCreateNewXIOItem -ErrorAction:Stop
						} ## end try
						## catch, write info, throw
						catch {_Invoke-WebExceptionErrorCatchHandling -URI $hshParamsToCreateNewXIOItem['Uri'] -ErrorRecord $_}
						## if good, write-verbose the status and, if status is "Created", Get-XIOInfo on given HREF
						if (($oWebReturn.StatusCode -eq $hshCfg["StdResponse"]["Post"]["StatusCode"] ) -and ($oWebReturn.StatusDescription -eq $hshCfg["StdResponse"]["Post"]["StatusDescription"])) {
							Write-Verbose "$strLogEntry_ToAdd Item created successfully. StatusDescription: '$($oWebReturn.StatusDescription)'"
							## use the return's links' hrefs to return the XIO item(s)
							($oWebReturn.Content | ConvertFrom-Json).links | Foreach-Object {
								## add "?cluster-name=blahh" here to HREF, if using -Cluster param
								$strHrefForNewObjToRetrieve = if ($PSBoundParameters.ContainsKey("Cluster")) {
										"{0}?cluster-name={1}" -f $_.href, $strThisXioClusterName
									} ## end if
									else {$_.href}
								Get-XIOItemInfo -URI $strHrefForNewObjToRetrieve
							} ## end foreach-object
						} ## end if
					} ## end if ShouldProcess
				} ## end foreach-object
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
	New-XIOInitiatorGroup -Name testIG0
	Create an initiator-group named testIG0 with no initiators defined therein
	.Example
	New-XIOInitiatorGroup -Name testIG1 -ParentFolder "/testIGs" -InitiatorList @{'"myserver-hba2"' = '"10:00:00:00:00:00:00:F4"'; '"myserver-hba3"' = '"10:00:00:00:00:00:00:F5"'}
	Create an initiator-group named testIG1 with two initiators defined therein (specifying parent folder no longer supported in XIOS REST API v2.0, which came in XIOS v4.0). And, notice the keys/values in the InitatorList hashtable:  they are made to include quotes in them by wrapping the double-quoted value in single quotes. This is a "feature" of XIOS REST API v1.0 -- these values need to reach the REST API with quotes around them
	.Example
	New-XIOInitiatorGroup -Name testIG2 -Cluster myCluster0 -InitiatorList @{"myserver2-hba2" = "10:00:00:00:00:00:00:F6"; "myserver2-hba3" = "10:00:00:00:00:00:00:F7"}
	Create an initiator-group named testIG3 with two initiators defined therein, and for XIO Cluster "myCluster0" (-Cluster being handy/necessary for connection to XMS that manages multiple XIO Clusters).  Notice, no additional quoting needed for InitiatorList hashtable keys/values -- the XIOS REST API v2 does not have the "feature" described in the previous example
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
		## The name of the XIO Cluster on which to make new initiator group. This value may be omitted if there is only one cluster defined in the XtremIO Storage System.
		[string[]]$Cluster,
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
		if ($PSBoundParameters.ContainsKey("ParentFolder_str")) {Write-Warning "Parameter ParentFolder is obsolete in XIOS API v2.0.  Parameter will be removed from this cmdlet in a future release."}
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
			$arrInitiatorsInfo = @($InitiatorList_hsh.Keys | Foreach-Object {
				$strKey = $_
				## add a hash to the array of initiator definitions
				@{"initiator-name" = $strKey; "port-address" = $InitiatorList_hsh[$strKey]}
			} ## end foreach-object
			)
			$hshNewItemSpec["initiator-list"] = $arrInitiatorsInfo
		} ## end if
		if ($PSBoundParameters.ContainsKey("ParentFolder_str")) {$hshNewItemSpec["parent-folder-id"] = $ParentFolder_str}
		## the params to use in calling the helper function to actually create the new object
		$hshParamsForNewItem = @{
			ComputerName = $ComputerName_arr
			ItemType_str = $strThisItemType
			Name = $Name_str
			SpecForNewItem_str = ($hshNewItemSpec | ConvertTo-Json)
		} ## end hashtable

		## if the user specified a cluster to use, include that param, and set the XIOS REST API param to 2.0; this excludes XIOS REST API v1 with multicluster from being a target for new XIO initiator groups with this cmdlet
		if ($PSBoundParameters.ContainsKey("Cluster")) {$hshParamsForNewItem["Cluster"] = $Cluster; $hshParamsForNewItem["XiosRestApiVersion"] = "2.0"}

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
	New-XIOInitiator -Name myserver0-hba3 -InitiatorGroup myserver0 -PortAddress 10:00:00:00:00:00:00:54
	Create a new initiator in the initiator group "myserver0" on all XIO Clusters in the connected XMS
	.Example
	New-XIOInitiator -Name myserver0-hba4 -Cluster myCluster0 -InitiatorGroup myserver0 -PortAddress 10:00:00:00:00:00:00:55
	Create a new initiator in the initiator group "myserver0", on specified XIO Cluster only
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
		## The name of the XIO Cluster on which to make new initiator. This value may be omitted if there is only one cluster defined in the XtremIO Storage System.
		[string[]]$Cluster,
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

		## if the user specified a cluster to use, include that param, and set the XIOS REST API param to 2.0; this excludes XIOS REST API v1 with multicluster from being a target for new XIO initiator with this cmdlet
		if ($PSBoundParameters.ContainsKey("Cluster")) {$hshParamsForNewItem["Cluster"] = $Cluster; $hshParamsForNewItem["XiosRestApiVersion"] = "2.0"}

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
	.Example
	New-XIOLunMap -Volume someVolume03 -Cluster myCluster0 -InitiatorGroup myIG0,myIG1 -HostLunId 22
	Create a new LUN mapping specific to myCluster0, for this cluster's volume "someVolume03" to the two given initiator groups in this cluster, using host LUN ID of 22
	.Outputs
	XioItemInfo.LunMap object for the newly created object if successful
#>
function New-XIOLunMap {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.LunMap])]
	param(
		## XMS address to use
		[parameter(Position=0)][string[]]$ComputerName_arr,
		## The name of the XIO Cluster on which to make new lun mapping. This value may be omitted if there is only one cluster defined in the XtremIO Storage System.
		[string[]]$Cluster,
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
		$hshParamForGetXioLunMap = @{Volume = $Volume; InitiatorGroup = $InitiatorGroup; ComputerName = $ComputerName_arr}
		if ($PSBoundParameters.ContainsKey("Cluster")) {$hshParamForGetXioLunMap["Cluster"] = $Cluster}
		## if a mapping with these properties already exists, do not proceed; retrieve just the given properties, so as to keep the response JSON as small as possible (for speed, plus to stay under the current 2MB hard max length for ConvertFrom-JSON cmdlet)
		$arrExistingLUNMaps = Get-XIOLunMap -Property lun,vol-name,ig-name @hshParamForGetXioLunMap
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

				## if the user specified a cluster to use, include that param, and set the XIOS REST API param to 2.0; this excludes XIOS REST API v1 with multicluster from being a target for new XIO lun mappings with this cmdlet
				if ($PSBoundParameters.ContainsKey("Cluster")) {$hshParamsForNewItem["Cluster"] = $Cluster; $hshParamsForNewItem["XiosRestApiVersion"] = "2.0"}

				## call the function to actually make this new item
				New-XIOItem @hshParamsForNewItem
			} ## end foreach-object
		} ## end else
	} ## end process
} ## end function


<#	.Description
	Create a new XtremIO volume
	.Example
	New-XIOVolume -Name testvol03 -SizeGB 2KB
	Create a 2TB (which is 2048GB, as represented by the "2KB" value for the -SizeGB param) volume named testvol0
	.Example
	New-XIOVolume -ComputerName somexms01.dom.com -Name testvol04 -SizeGB 5120 -ParentFolder "/testVols"
	Create a 5TB volume named testvol04 in the given parent folder (specifying parent folder no longer supported in XIOS REST API v2.0, which came in XIOS v4.0)
	.Example
	New-XIOVolume -Name testvol05 -SizeGB 5KB -EnableSmallIOAlert -EnableUnalignedIOAlert -EnableVAAITPAlert
	Create a 5TB volume named testvol05 with all three alert types enabled
	.Example
	New-XIOVolume -Name testvol10 -Cluster myxio05,myxio06 -SizeGB 1024
	Create two 1TB volumes named "testvol10", one on each of the two given XIO clusters (expects that the XMS is using at least v2.0 of the REST API, which is available as of XIOS v4.0)
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
		## The name of the XIO Cluster on which to make new volume. This value may be omitted if there is only one cluster defined in the XtremIO Storage System.
		[string[]]$Cluster,
		## The disk space size of the volume in GB. This parameter reflects the size of the volume available to the initiators. It does not indicate the actual SSD space this volume may consume
		#   Must be an integer greater than 0 and a multiple of 1 MB.
		[parameter(Mandatory=$true)][ValidateScript({$_ -gt 0})][int]$SizeGB_int,
		## Identifies the volume folder to which this volume will initially belong. The folder's Folder Type must be Volume. If omitted, the volume will be added to the root volume folder. Example value: "/myBigVolumesFolder"
		##   Note:  parameter is obsolete, no longer supported in XIOS API v2.0
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
		## the string value to pass for enabling Alert config on new volume if doing so
		$strEnableAlertValue = "enabled"
		if ($PSBoundParameters.ContainsKey("ParentFolder_str")) {Write-Warning "Parameter ParentFolder is obsolete in XIOS API v2.0.  Parameter will be removed from this cmdlet in a future release."}
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

		## if the user specified a cluster to use, include that param, and set the XIOS REST API param to 2.0; this excludes XIOS REST API v1 with multicluster from being a target for new XIO volumes with this cmdlet
		if ($PSBoundParameters.ContainsKey("Cluster")) {$hshParamsForNewItem["Cluster"] = $Cluster; $hshParamsForNewItem["XiosRestApiVersion"] = "2.0"}

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


<#	.Description
	Create a new XtremIO snapshot
	.Example
	New-XIOSnapshot -Volume myVol0,myVol1 -SnapshotSuffix snap.20151225-0800-5
	Create new writable snapshots of the two volumes of these names, placing them in a single, new SnapshotSet, and the snapshots will have the specified suffix
	.Example
	New-XIOSnapshot -Volume myVol0_clu3,myVol1_clu3 -Cluster myCluster03
	Create new writable snapshots of the two volumes of these names that are defined in XIO cluster "myCluster03"
	.Example
	Get-XIOVolume -Name myVol[01] | New-XIOSnapshot -Type ReadOnly
	Create new ReadOnly snapshots of the two volumes of these names, placing them each in their own new SnapshotSet, and the snapshots will have the default suffix in their name
	.Example
	Get-XIOConsistencyGroup someGrp[01] | New-XIOSnapshot -Type ReadOnly
	Get these two consistency groups and create snapshots of each group's volumes. Note:  this makes separate SnapshotSets for each consistency group's volumes' new snapshots (that is, this does not create a single SnapshotSet with the snapshots of all of the volumes from both consistency groups)
	.Example
	New-XIOSnapshot -SnapshotSet SnapshotSet.1449941173 -SnapshotSuffix addlSnap.now -Type Regular
	Create new writable snapshots for the volumes (snapshots) in the given SnapshotSet, and makes names new snapshots with given suffix
	.Example
	Get-XIOSnapshotSet | Where-Object {$_.CreationTime -gt (Get-Date).AddHours(-1)} | New-XIOSnapshot ReadOnly
	Create new ReadOnly snapshots for the volumes (snapshots) in the SnapshotSets that were made in the last hour. For every source Snapshot, this makes a new SnapshotSet object for the source volumes' new snapshots.
	.Example
	New-XIOSnapshot -Tag /Volume/myCoolVolTag0
	Create snapshots of the volumes tagged with the given Tag
	.Example
	Get-XIOTag /Volume/myCoolVolTag* | New-XIOSnapshot -Type ReadOnly
	Get the matching Tags and create new snapshots for each tag's volumes/snapshots. Note:  this makes separate SnapshotSets for each Tag's volumes' new snapshots (that is, this does not create a single SnapshotSet with the snapshots of all of the volumes from all Tags)
	.Outputs
	XioItemInfo.Snapshot object for the newly created object if successful
#>
function New-XIOSnapshot {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.Snapshot])]
	param(
		## XMS address to use
		[string[]]$ComputerName,
		## The name of the XIO Cluster on which to make new snapshot. This value may be omitted if there is only one cluster defined in the XtremIO Storage System.
		[string[]]$Cluster,
		## XtremIO Volume or Snapshot from which to create new snapshot. Accepts either Volume/Snapshot names or objects
		[parameter(Mandatory=$true,ParameterSetName="ByVolume")][ValidateScript({_Test-TypeOrString $_ -Type ([XioItemInfo.Volume])})][PSObject[]]$Volume,
		## XtremIO Consistency Group whose volumes from which to create new snapshot. Accepts either ConsistencyGroup name or object
		[parameter(Mandatory=$true, ParameterSetName="ByConsistencyGroup")][ValidateScript({_Test-TypeOrString $_ -Type ([XioItemInfo.ConsistencyGroup])})][PSObject]$ConsistencyGroup,
		## XtremIO SnapshotSet whose snapshots from which to create new snapshot. Accepts either SnapshotSet name or object
		[parameter(Mandatory=$true, ParameterSetName="BySnapshotSet")][ValidateScript({_Test-TypeOrString $_ -Type ([XioItemInfo.SnapshotSet])})][PSObject]$SnapshotSet,
		## XtremIO Tag whose volumes/snapshots from which to create new snapshot. Accepts either Tag names or objects. These should be Tags for Volume object types, of course.
		[parameter(Mandatory=$true, ParameterSetName="ByTag")][ValidateScript({_Test-TypeOrString $_ -Type ([XioItemInfo.Tag])})][PSObject[]]$Tag,
		## Suffix to append to name of source volume/snapshot, making the resultant name to use for the new snapshot. Defaults to "<numberOfSecondsSinceUnixEpoch>"
		[string]$SnapshotSuffix,
		## Name to use for new SnapshotSet that will hold the new snapshot. Defaults to "SnapshotSet.<numberOfSecondsSinceUnixEpoch>"
		[string]$NewSnapshotSetName,
		## Related object whose volumes from which to make new snapshots -- one of the types Volume, ConsistencyGroup, SnapshotSet, or Tag
		[parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")]
		[ValidateScript({($_ -is [XioItemInfo.Volume]) -or ($_ -is [XioItemInfo.ConsistencyGroup]) -or ($_ -is [XioItemInfo.SnapshotSet]) -or ($_ -is [XioItemInfo.Tag])})]
		[PSObject]$RelatedObject,
		## Type of snapshot to create:  "Regular" (readable/writable) or "ReadOnly". Defaults to "Regular"
		[ValidateSet("Regular","ReadOnly")][string]$Type = "Regular"
	) ## end param

	Begin {
		## this item type (singular)
		$strThisItemType = "snapshot"
		## incrementer to use in case there are multiple iterations through the process scriptblock (needed for making SnapshotSet and SnapshotSuffix values unique within the same second)
		$intI = 0
		$int64NumSecSinceUnixEpoch_atStart = _Get-NumSecondSinceUnixEpoch
	} ## end begin

	Process {
		## if these were not specified, get one time the number of seconds since Unix Epoch, so that the same value is used in both suffix and snapset names if _neither_ was specified (to avoid the unlikely event where the values might be different if retrieving that count multiple times)
		#   doing this every time through the Process scriptblock, as there is a new SnapshotSet for every "new snapshot" action in XtremIO -- cannot use the same SnapshotSet name for multiple "new snapshot" calls, as the action create the new snapshot set each time
		if ((-not $PSBoundParameters.ContainsKey("SnapshotSuffix")) -or (-not $PSBoundParameters.ContainsKey("NewSnapshotSetName"))) {
			## if this is the first time through the process scriptblock, just use the initial num sec; else, get the num sec again
			$int64NumSecSinceUnixEpoch = if ($intI -eq 0) {$int64NumSecSinceUnixEpoch_atStart} else {_Get-NumSecondSinceUnixEpoch}
			## make a string to append to SnapshotSuffix and and NewSnapshotName if this is not the first time through the process scriptblock _and_ it's the same number of seconds since the Unix Epoch as when this function was in the begin scriptblock
			$strIncrementerSuffix = if (($intI -gt 0) -and ($int64NumSecSinceUnixEpoch -eq $int64NumSecSinceUnixEpoch_atStart)) {"_$intI"}
			if (-not $PSBoundParameters.ContainsKey("SnapshotSuffix")) {$SnapshotSuffix = "snapshot.${int64NumSecSinceUnixEpoch}$strIncrementerSuffix"}
			if (-not $PSBoundParameters.ContainsKey("NewSnapshotSetName")) {$NewSnapshotSetName = "SnapshotSet.${int64NumSecSinceUnixEpoch}$strIncrementerSuffix"}
		} ## end if

		## the API-specific pieces that define the new XIO object's properties
		$hshNewItemSpec = @{
			"snap-suffix" = $SnapshotSuffix
			"snapshot-set-name" = $NewSnapshotSetName
			"snapshot-type" = $Type.ToLower()
		} ## end hashtable

		Switch ($PsCmdlet.ParameterSetName) {
			## if this is ByVolume, or ByRelatedObject where the object is a Volume
			{($_ -eq "ByVolume") -or (($_ -eq "ByRelatedObject") -and ($RelatedObject -is [XioItemInfo.Volume]))} {
				$oParamOfInterest = if ($PsCmdlet.ParameterSetName -eq "ByVolume") {$Volume} else {$RelatedObject}
				## get the array of names to use from the param; if param values are of given type, access the .Name property of each param object; else, param should be System.String types
				$arrSrcVolumeNames = @(if (($oParamOfInterest | Get-Member | Select-Object -Unique TypeName).TypeName -eq "XioItemInfo.Volume") {$oParamOfInterest.Name} else {$oParamOfInterest})
				$hshNewItemSpec["volume-list"] = $arrSrcVolumeNames
				$strNameForCheckingForExistingItem = "$($arrSrcVolumeNames | Select-Object -First 1)$SnapshotSuffix"
				break
			} ## end case
			## if this is ByConsistencyGroup, or ByRelatedObject where the object is a ConsistencyGroup
			{($_ -eq "ByConsistencyGroup") -or (($_ -eq "ByRelatedObject") -and ($RelatedObject -is [XioItemInfo.ConsistencyGroup]))} {
				$oParamOfInterest = if ($PsCmdlet.ParameterSetName -eq "ByConsistencyGroup") {$ConsistencyGroup} else {$RelatedObject}
				if ($oParamOfInterest -is [XioItemInfo.ConsistencyGroup]) {
					$strSrcCGName = $oParamOfInterest.Name
					$arrSrcVolumeNames = @($oParamOfInterest.VolList.Name)
				} else {
					$strSrcCGName = $oParamOfInterest
				} ## end else
				$hshNewItemSpec["consistency-group-id"] = $strSrcCGName
				## set the name for checking; may need updated for when receiving ConsistencyGroup value by name (won't have volume list, and won't be able to check for an existing volume of the given name)
				$strNameForCheckingForExistingItem = if (($arrSrcVolumeNames | Measure-Object).Count -gt 0) {"$($arrSrcVolumeNames | Select-Object -First 1)$SnapshotSuffix"} else {"$strSrcCGName$SnapshotSuffix"}
				break
			} ## end case
			## if this is BySnapshotSet, or ByRelatedObject where the object is a SnapshotSet
			{($_ -eq "BySnapshotSet") -or (($_ -eq "ByRelatedObject") -and ($RelatedObject -is [XioItemInfo.SnapshotSet]))} {
				$oParamOfInterest = if ($PsCmdlet.ParameterSetName -eq "BySnapshotSet") {$SnapshotSet} else {$RelatedObject}
				if ($oParamOfInterest -is [XioItemInfo.SnapshotSet]) {
					$strSrcSnapsetName = $oParamOfInterest.Name
					$arrSrcVolumeNames = @($oParamOfInterest.VolList.Name)
				} else {
					$strSrcSnapsetName = $oParamOfInterest
				} ## end else
				$hshNewItemSpec["snapshot-set-id"] = $strSrcSnapsetName
				## set the name for checking; may need updated for when receiving SnapshotSet value by name (won't have volume list, and won't be able to check for an existing volume of the given name)
				$strNameForCheckingForExistingItem = if (($arrSrcVolumeNames | Measure-Object).Count -gt 0) {"$($arrSrcVolumeNames | Select-Object -First 1)$SnapshotSuffix"} else {"$strSrcSnapsetName$SnapshotSuffix"}
				break
			} ## end case
			## if this is ByTag, or ByRelatedObject where the object is a Tag
			{($_ -eq "ByTag") -or (($_ -eq "ByRelatedObject") -and ($RelatedObject -is [XioItemInfo.Tag]))} {
				$oParamOfInterest = if ($PsCmdlet.ParameterSetName -eq "ByTag") {$Tag} else {$RelatedObject}
				if (($oParamOfInterest | Get-Member | Select-Object -Unique TypeName).TypeName -eq "XioItemInfo.Tag") {
					$arrSrcTagNames = @($oParamOfInterest.Name)
					$arrSrcVolumeNames = @($oParamOfInterest.ObjectList.Name)
				} else {
					$arrSrcTagNames = @($oParamOfInterest)
				} ## end else
				## needs to be an array, so that the JSON will be correct for the API call, which expects an array values
				$hshNewItemSpec["tag-list"] = $arrSrcTagNames
				## set the name for checking; may need updated for when receiving Tag value by name (won't have volume list, and won't be able to check for an existing volume of the given name)
				$strNameForCheckingForExistingItem = if (($arrSrcVolumeNames | Measure-Object).Count -gt 0) {"$($arrSrcVolumeNames | Select-Object -First 1)$SnapshotSuffix"} else {"$($arrSrcTagNames | Select-Object -First 1)$SnapshotSuffix"}
				break
			} ## end case
		} ## end switch

		## the params to use in calling the helper function to actually create the new object
		$hshParamsForNewItem = @{
			ComputerName = $ComputerName
			ItemType = $strThisItemType
			Name = $strNameForCheckingForExistingItem
			SpecForNewItem = $hshNewItemSpec | ConvertTo-Json
			XiosRestApiVersion = "2.0"
		} ## end hashtable

		## if the user specified a cluster to use, include that param (the XIOS REST API param is already set to 2.0; this excludes XIOS REST API v1 with multicluster from being a target for new XIO snapshots with this cmdlet)
		if ($PSBoundParameters.ContainsKey("Cluster")) {$hshParamsForNewItem["Cluster"] = $Cluster}

		## call the function to actually make this new item
		New-XIOItem @hshParamsForNewItem

		$intI++
	} ## end process
} ## end function
