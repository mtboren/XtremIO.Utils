<#	.Description
	Create a new XtremIO item, like a volume, initiator group, etc.  Used as helper function to the New-XIO* functions that are each for a new item of a specific type

	.Outputs
	XioItemInfo object for the newly created object if successful
#>
function New-XIOItem {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		## Address to which to connect
		[parameter(Position=0)][string[]]$ComputerName,

		## Item type to create; currently supported types:
		##   for all API versions:  "ig-folder", "initiator, "initiator-group", "lun-map", "volume", "volume-folder"
		##   starting in API v2:  "consistency-group", "scheduler", "user-account", "tag"
		[ValidateSet("consistency-group","ig-folder","initiator","initiator-group","lun-map","scheduler","snapshot","tag","user-account","volume","volume-folder")][parameter(Mandatory=$true)][string]$ItemType,

		## JSON for the body of the POST WebRequest, for specifying the properties for the new XIO object
		[parameter(Mandatory=$true)][ValidateScript({ try {ConvertFrom-Json -InputObject $_ -ErrorAction:SilentlyContinue | Out-Null; $true} catch {$false} })][string]$SpecForNewItem,

		## Item name being made (for checking if such item already exists)
		[parameter(Mandatory=$true)][string]$Name,

		## XtremIO REST API version to use
		[System.Version]$XiosRestApiVersion,

		## Cluster for which to create new item
		[string[]]$Cluster
	) ## end param

	Begin {
		## from the param value, make the plural form (the item types in the API are all plural; adding "s" here to the singular form used for valid param values, the singular form being the standard for PowerShell-y things)
		$strItemType_plural = "${ItemType}s"
		## the base portion of the REST command to issue
		$strRestCmd_base = "/types/$strItemType_plural"
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## get the XIO connections to use
		$arrXioConnectionsToUse = Get-XioConnectionsToUse -ComputerName $ComputerName
	} ## end begin

	Process {
		## make hashtable of params for the Get call (that verifies if any such object by given name exists); remove any extra params that were copied in that are not used for the Get call, or where the param name is not quite the same in the subsequent function being called
		$hshParamsForGetItem = @{}
		$PSBoundParameters.Keys | Where-Object {"SpecForNewItem","XiosRestApiVersion","WhatIf" -notcontains $_} | Foreach-Object {$hshParamsForGetItem[$_] = $PSBoundParameters[$_]}
		## if the item type is of "lun-map", do not need to get XIO Item Info again, as that is already done in the New-XIOLunMap call, and was $null at that point, else it would not have progressed to _this_ point
		$oExistingXioItem = if ($ItemType -eq "lun-map") {$null} else {Get-XIOItemInfo @hshParamsForGetItem}
		## if such an item already exists, write a warning and stop
		if ($null -ne $oExistingXioItem) {Write-Warning "Item of name '$Name' and type '$ItemType' already exists on '$($oExistingXioItem.ComputerName -join ", ")'. Taking no action"; break;} ## end if
		## else, actually try to make such an object
		else {
			$arrXioConnectionsToUse | Foreach-Object {
				$oThisXioConnection = $_
				## is this a type that is supported in this XioConnection's XIOS version?
				if (-not (_Test-XIOObjectIsInThisXIOSVersion -XiosVersion $oThisXioConnection.XmsVersion -ApiItemType $strItemType_plural)) {
					Write-Verbose $("As should have been already warned, the type '$strItemType_plural' does not exist in $($oThisXioConnection.ComputerName)'s XIOS version{0}. This is possibly an object type that was introduced in a later XIOS version" -f $(if (-not [String]::IsNullOrEmpty($_.XmsSWVersion)) {" ($($_.XmsSWVersion))"}))
				} ## end if
				## else, the Item type _does_ exist in this XIOS version -- try to create a new item of this type
				else {
					## for each value for $Cluster, if cluster is specified, else, just one time (as indicated by the empty string -- that is there just to have the Foreach-Object process scriptblock run at least once)
					$(if ($PSBoundParameters.ContainsKey("Cluster")) {$Cluster} else {""}) | Foreach-Object {
						## the cluster name (if any -- might be empty string, but, in that case, will not be used, as code checks PSBoundParameters for Cluster param before using this variable)
						$strThisXioClusterName = $_
						## if the -CLuster param is given, add to the WhatIf msg, and add the "cluster-id" param piece to the JSON body specification
						if ($PSBoundParameters.ContainsKey("Cluster")) {
							$strClusterTidbitForWhatIfMsg = " in cluster '$strThisXioClusterName'"
							$strJsonSpecForNewItem = $SpecForNewItem | ConvertFrom-Json | Select-Object *, @{n="cluster-id"; e={$strThisXioClusterName}} | ConvertTo-Json
						} ## end if
						else {
							$strClusterTidbitForWhatIfMsg = $null
							$strJsonSpecForNewItem = $SpecForNewItem
						} ## end else
						$strMsgForWhatIf = "Create new '$ItemType' object named '$Name'{0}" -f $strClusterTidbitForWhatIfMsg
						if ($PsCmdlet.ShouldProcess($oThisXioConnection.ComputerName, $strMsgForWhatIf)) {
							## make params hashtable for new WebRequest
							$hshParamsToCreateNewXIOItem = @{
								## make URI
								Uri = $(
									$hshParamsForNewXioApiURI = @{ComputerName = $oThisXioConnection.ComputerName; RestCommand = $strRestCmd_base; Port = $oThisXioConnection.Port}
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
				} ## end else (item type _does_ exist in this XIOS API version)
			} ## end foreach-object
		} ## end else
	} ## end process
} ## end function


<#	.Description
	Create a new XtremIO ConsistencyGroup

	.Example
	New-XIOConsistencyGroup -Name myConsGrp0
	Create a new, empty ConsistencyGroup

	.Example
	New-XIOConsistencyGroup -Name myConsGrp1 -Volume coolVol0,coolVol1
	Create a new, ConsistencyGroup that contains the volumes specified

	.Example
	New-XIOConsistencyGroup -Name myConsGrp2 -Volume (Get-XIOVolume coolVol*2016,coolVol[01])
	Create a new, ConsistencyGroup that contains the volumes specified

	.Example
	New-XIOConsistencyGroup -Name myConsGrp3 -Tag (Get-XIOTag /Volume/someImportantVolsTag,/Volume/someImportantVolsTag2) -Cluster myCluster0
	Create a new, ConsistencyGroup that contains the volumes on XIO cluster "myCluster0" that are tagged with either "someImportantVolsTag" or "someImportantVolsTag2"

	.Outputs
	XioItemInfo.ConsistencyGroup object for the newly created object if successful
#>
function New-XIOConsistencyGroup {
	[CmdletBinding(SupportsShouldProcess=$true,DefaultParameterSetName="DefaultUnnamedPSet")]
	[OutputType([XioItemInfo.ConsistencyGroup])]
	param(
		## XMS address to use
		[string[]]$ComputerName,

		## The name of the XIO Cluster on which to make new consistency group. This parameter may be omitted if there is only one cluster defined in the XtremIO Storage System.
		[string[]]$Cluster,

		## Name of the new consistency group
		[parameter(Mandatory=$true, Position=0)]$Name,

		## XtremIO Volume(s) or Snapshot(s) from which to create new consistency group. Accepts either Volume/Snapshot names or objects
		[parameter(ParameterSetName="ByVolume")][ValidateScript({_Test-TypeOrString $_ -Type ([XioItemInfo.Volume])})][PSObject[]]$Volume,

		## XtremIO Tag whose volumes/snapshots from which to create new consistency group. Accepts either Tag names or objects. These should be Tags for Volume object types, of course. And, when specifying tag names, use "full" tag name, like "/Volume/myVolsTag0"
		[parameter(ParameterSetName="ByTag")][ValidateScript({_Test-TypeOrString $_ -Type ([XioItemInfo.Tag])})][PSObject[]]$Tag
	) ## end param

	Begin {
		## this item type (singular)
		$strThisItemType = "consistency-group"
	} ## end begin

	Process {
		## the API-specific pieces that define the new XIO object's properties
		$hshNewItemSpec = @{
			"consistency-group-name" = $Name
		} ## end hashtable

		Switch($PsCmdlet.ParameterSetName) {
			## for ByVolume, populate "vol-list"
			"ByVolume" {
				## get the array of names to use from the param; if param values are of given type, access the .Name property of each param object; else, param should be System.String types
				$arrSrcVolumeNames = @(if ("XioItemInfo.Volume", "XioItemInfo.Snapshot" -contains ($Volume | Get-Member | Select-Object -Unique TypeName).TypeName) {$Volume.Name} else {$Volume})
				$hshNewItemSpec["vol-list"] = $arrSrcVolumeNames
				break
			} ## end case
			## for ByTag, populate "tag-list"
			"ByTag" {
				## value needs to be an array, so that the JSON will be correct for the API call, which expects an array of values
				$arrSrcTagNames = if (($Tag | Get-Member | Select-Object -Unique TypeName).TypeName -eq "XioItemInfo.Tag") {$Tag.Name} else {$arrSrcTagNames = $Tag} ## end else
				$hshNewItemSpec["tag-list"] = @($arrSrcTagNames)
			} ## end case
		} ## end switch

		## the params to use in calling the helper function to actually create the new object
		$hshParamsForNewItem = @{
			ComputerName = $ComputerName
			ItemType = $strThisItemType
			Name = $Name
			SpecForNewItem = $hshNewItemSpec | ConvertTo-Json
		} ## end hashtable

		## if the user specified a cluster to use, include that param
		if ($PSBoundParameters.ContainsKey("Cluster")) {$hshParamsForNewItem["Cluster"] = $Cluster}
		## set the XIOS REST API param to 2.0; the Tag object type is only available in XIOS v4 and up (and, so, API v2 and newer)
		$hshParamsForNewItem["XiosRestApiVersion"] = "2.0"

		## call the function to actually make this new item
		New-XIOItem @hshParamsForNewItem
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
	New-XIOInitiatorGroup -Name testIG1 -InitiatorList @{myserver_hba2 = "10:00:00:00:00:00:00:F0"; myserver_hba3 = "10:00:00:00:00:00:00:F1"} | New-XIOTagAssignment -Tag (Get-XIOTag /InitiatorGroup/testIGs)
	Create an initiator-group named testIG1 with two initiators defined therein, and then assign the Tag "/InitiatorGroup/testIGs" to the new initiator group

	.Example
	New-XIOInitiatorGroup -Name testIG2 -ParentFolder /testIGs -InitiatorList @{'"myserver_hba2"' = '"10:00:00:00:00:00:00:F4"'; '"myserver_hba3"' = '"10:00:00:00:00:00:00:F5"'}
	Deprecated:  Create an initiator-group named testIG2 with two initiators defined therein (specifying parent folder no longer supported in XIOS REST API v2.0, which came in XIOS v4.0). And, notice the keys/values in the InitatorList hashtable:  they are made to include quotes in them by wrapping the double-quoted value in single quotes. This is a "feature" of XIOS REST API v1.0 -- these values need to reach the REST API with quotes around them

	.Example
	New-XIOInitiatorGroup -Name testIG3 -Cluster myCluster0 -InitiatorList @{myserver2_hba2 = "10:00:00:00:00:00:00:F6"; myserver2_hba3 = "10:00:00:00:00:00:00:F7"}
	Create an initiator-group named testIG3 with two initiators defined therein, and for XIO Cluster "myCluster0" (-Cluster being handy/necessary for connection to XMS that manages multiple XIO Clusters).  Notice, no additional quoting needed for InitiatorList hashtable keys/values -- the XIOS REST API v2 does not have the "feature" described in the previous example

	.Outputs
	XioItemInfo.InitiatorGroup object for the newly created object if successful
#>
function New-XIOInitiatorGroup {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.InitiatorGroup])]
	param(
		## XMS address to use
		[parameter(Position=0)][string[]]$ComputerName,

		## Name for new initiator-group being made
		[parameter(Mandatory=$true)][string]$Name,

		## The name of the XIO Cluster on which to make new initiator group. This parameter may be omitted if there is only one cluster defined in the XtremIO Storage System.
		[string[]]$Cluster,

		## The initiator-name and port-address for each initiator you want to add to the group, if any (why not, though?). Each key/value pair shall use initiator-name as the key, and the corresponding port-address for the value.
		#For the port addresses, valid values are colon-separated hex numbers, non-separated hex numbers, or non-separated hex numbers prefixed with "0x".  That is, the following formats are acceptable for port-address values:  XX:XX:XX:XX:XX:XX:XX:XX, XXXXXXXXXXXXXXXX, or 0xXXXXXXXXXXXXXXXX
		#Example hashtable for two initiators named "myserver_hba2" and "myserver_hba3":
		#    @{"myserver_hba2" = "10:00:00:00:00:00:00:F4"; "myserver_hba3" = "10:00:00:00:00:00:00:F5"}
		[System.Collections.Hashtable]$InitiatorList_hsh,

		## Deprecated:  The initiator group's parent folder. The folder's Folder Type must be IG. If omitted, the volume will be added to the root IG folder. Example value: "/IGsForMyCluster0"
		[ValidateScript({$_.StartsWith("/")})][string]$ParentFolder
	) ## end param

	Begin {
		## this item type (singular)
		$strThisItemType = "initiator-group"
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		if ($PSBoundParameters.ContainsKey("ParentFolder")) {Write-Warning "Parameter ParentFolder is obsolete in XIOS API v2.0.  Parameter will be removed from this cmdlet in a future release."}
	} ## end begin

	Process {
		## the API-specific pieces that define the new XIO object's properties
		$hshNewItemSpec = @{
			"ig-name" = $Name
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
		if ($PSBoundParameters.ContainsKey("ParentFolder")) {$hshNewItemSpec["parent-folder-id"] = $ParentFolder}
		## the params to use in calling the helper function to actually create the new object
		$hshParamsForNewItem = @{
			ComputerName = $ComputerName
			ItemType = $strThisItemType
			Name = $Name
			SpecForNewItem = ($hshNewItemSpec | ConvertTo-Json)
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
	New-XIOInitiator -Name myserver0_hba2 -InitiatorGroup myserver0 -PortAddress 0x100000000000ab56
	Create a new initiator in the initiator group "myserver0"

	.Example
	New-XIOInitiator -Name myserver0_hba3 -InitiatorGroup myserver0 -PortAddress 10:00:00:00:00:00:00:54 -OperatingSystem ESX
	Create a new initiator in the initiator group "myserver0" on all XIO Clusters in the connected XMS, and specifies "ESX" for the Operating System type

	.Example
	New-XIOInitiator -Name myserver0_hba4 -Cluster myCluster0 -InitiatorGroup myserver0 -PortAddress 10:00:00:00:00:00:00:55
	Create a new initiator in the initiator group "myserver0", on specified XIO Cluster only

	.Outputs
	XioItemInfo.Initiator object for the newly created object if successful
#>
function New-XIOInitiator {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.Initiator])]
	param(
		## XMS address to use
		[parameter(Position=0)][string[]]$ComputerName,

		## Name for new initiator being made
		[parameter(Mandatory=$true)][string]$Name,

		## The name of the XIO Cluster on which to make new initiator. This parameter may be omitted if there is only one cluster defined in the XtremIO Storage System.
		[string[]]$Cluster,

		## The existing initiator group name to which associate the initiator
		[parameter(Mandatory=$true)][string]$InitiatorGroup,

		## The initiator's port address.  The following rules apply:
		#-For FC initiators, any of the following formats are allowed ("X" is a hexadecimal digit � uppercase and lower case are allowed):
		#	XX:XX:XX:XX:XX:XX:XX:XX
		#	XXXXXXXXXXXXXXXX
		#	0xXXXXXXXXXXXXXXXX
		#-For iSCSI initiators, IQN and EUI formats are allowed
		#-Two initiators cannot share the same port address
		#-You cannot specify an FC address for an iSCSI target and vice-versa
		[parameter(Mandatory=$true)][ValidateScript({$_ -match "^((0x)?[0-9a-f]{16}|(([0-9a-f]{2}:){7}[0-9a-f]{2}))$"})][string]$PortAddress,

		## The operating system of the host whose HBA this Initiator involves. One of Linux, Windows, ESX, Solaris, AIX, HPUX, or Other
		[XioItemInfo.Enums.General.OSType]$OperatingSystem
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
			"initiator-name" = $Name
			"ig-id" = $InitiatorGroup
			"port-address" = $PortAddress
		} ## end hashtable
		## add these if bound
		if ($PSBoundParameters.ContainsKey("OperatingSystem")) {$hshNewItemSpec["operating-system"] = $OperatingSystem.ToString().ToLower()}

		## the params to use in calling the helper function to actually create the new object
		$hshParamsForNewItem = @{
			ComputerName = $ComputerName
			ItemType = $strThisItemType
			Name = $Name
			## need to replace triple backslash with single backslash where there is a backslash in the literal value of some field (as req'd by new initiator group call); triple-backslashes come about due to ConvertTo-Json escaping backslashes with backslashes, but causes issue w/ the format expected by XIO API
			SpecForNewItem = $hshNewItemSpec | ConvertTo-Json
		} ## end hashtable

		## if the user specified a cluster to use, include that param, and set the XIOS REST API param to 2.0; this excludes XIOS REST API v1 with multicluster from being a target for new XIO initiator with this cmdlet
		if ($PSBoundParameters.ContainsKey("Cluster")) {$hshParamsForNewItem["Cluster"] = $Cluster; $hshParamsForNewItem["XiosRestApiVersion"] = "2.0"}

		## call the function to actually make this new item
		New-XIOItem @hshParamsForNewItem
	} ## end process
} ## end function


<#	.Description
	Create a new XtremIO initiator-group-folder

	.Synopsis
	Deprecated cmdlet for creating legacy "folder" objects

	.Notes
	Folders have been replaced with Tags in newer XIOS releases.  Support for *Folder cmdlets is deprecated, and the cmdlets will be removed at some point.  Use Tags instead of folders.

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
		[parameter(Position=0)][string[]]$ComputerName,

		## Name for new volume being made
		[parameter(Mandatory=$true)][string]$Name,

		## Parent folder in which to make this folder; defaults to "/"
		[ValidateScript({$_.StartsWith("/")})][string]$ParentFolder = "/"
	) ## end param

	Begin {
		## this item type (singular)
		$strThisItemType = "ig-folder"
	} ## end begin

	Process {
		## the API-specific pieces that define the new XIO object's properties
		$hshNewItemSpec = @{
			"caption" = $Name
			"parent-folder-id" = $ParentFolder
		} ## end hashtable

		## the params to use in calling the helper function to actually create the new object
		$hshParamsForNewItem = @{
			ComputerName = $ComputerName
			ItemType = $strThisItemType
			Name = $Name
			SpecForNewItem = $hshNewItemSpec | ConvertTo-Json
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
		[parameter(Position=0)][string[]]$ComputerName,

		## The name of the XIO Cluster on which to make new lun mapping. This parameter may be omitted if there is only one cluster defined in the XtremIO Storage System.
		[string[]]$Cluster,

		## The name of the volume to map to initiator group(s)
		[parameter(Mandatory=$true)][string]$Volume,

		## The name(s) of one or more initiator groups to which to map the given volume
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
		$hshParamForGetXioLunMap = @{Volume = $Volume; InitiatorGroup = $InitiatorGroup; ComputerName = $ComputerName}
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
					ComputerName = $ComputerName
					ItemType = $strThisItemType
					Name = "${Volume}_${InitiatorGroup}_${HostLunId}"
					SpecForNewItem = $hshNewItemSpec | ConvertTo-Json
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
	Create a new XtremIO Tag. Note:  As of XIOS v4.0.2, this cmdlet can make Tags for the fifteen entity types supported by the API.  However, the XMS management interface only displays Tags for six of these entity types (ConsistencyGroup, Initiator, InitatorGroup, SnapshotScheduler, SnapshotSet, and Volume).  The Get-XIOTag cmdlet _will_ show all tags, not just for these six entity types.

	.Example
	New-XIOTag -Name MyVols -EntityType Volume -Color ffcc99
	Create a new tag "MyVols", nested in the "/Volume" parent tag, to be used for Volume entities, and with the given hex RGB color (-Color supported by XtremIO REST API starting in v2.1).  This example highlights the behavior that, if no explicit "path" specified to the tag, the new tag is put at the root of its parent tag, based on the entity type

	.Example
	New-XIOTag -Name /Volume/MyVols2/someOtherTag/superImportantVols -EntityType Volume
	Create a new tag "superImportantVols", nested in the "/Volume/MyVols/someOtherTag" parent tag, to be used for Volume entities.  Notice that none of the "parent" tags needed to exist before issuing this command -- the are created appropriately as required for creating the "leaf" tag.  And, the maximum tag depth seems to be four (three "parent" tag levels, and then the fourth level being the "leaf" tag "superImportantVols" in this example)

	.Example
	New-XIOTag -Name /X-Brick/MyTestXBrickTag -EntityType Brick
	Create a new tag "/X-Brick/MyTestXBrickTag", to be used for XtremIO Brick entities

	.Outputs
	XioItemInfo.Tag object for the newly created object if successful
#>
function New-XIOTag {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.Tag])]
	param(
		## XMS address to use
		[parameter(Position=0)][string[]]$ComputerName,

		## Name for new tag being made.  Can specify "deep" tags (nested tags), up to four total levels.
		[parameter(Mandatory=$true)][string]$Name,

		## Type of entity to which this tag can be applied.  Entity types supported for Tag objects:  get the values of the XioItemInfo.Enums.Tag.EntityType enumeration, via:  [System.Enum]::GetNames([XioItemInfo.Enums.Tag.EntityType])
		[parameter(Mandatory=$true)][XioItemInfo.Enums.Tag.EntityType]$EntityType,

		## Color to assign this tag (as seen in an XMS UI), in the form of six hexadecimal characters (a 'hex triplet'), representing the red, green, and blue components of the color.  Supported by XtremIO REST API starting in v2.1.  Examples:  FFFFFF for white, or FF0000 for red.  Read more about such color things at https://en.wikipedia.org/wiki/Web_colors
		[ValidateScript({$_ -match "^[0-9a-f]{6}$"})][string]$Color
	) ## end param

	Begin {
		## this item type (singular)
		$strThisItemType = "tag"
	} ## end begin

	Process {
		## the API-specific pieces that define the new XIO object's properties
		$hshNewItemSpec = @{
			"tag-name" = $Name
			## get the URI entity type value to use for this PSModule entity typename (need to do .ToString() to get the typename string, as it is a XioItemInfo.Enums.Tag.EntityType enum value)
			"entity" = $hshCfg.TagEntityTypeMapping[$EntityType.ToString()]
		} ## end hashtable

		## if the Color was specified, add it (prefixing a '#' to the hex triplet, as that is how the color values are seemingly stored in the XMS, though it also seems that it is not mandatory, as the API will accept other values)
		if ($PSBoundParameters.ContainsKey("Color")) {$hshNewItemSpec['color'] = "#{0}" -f $Color.ToUpper()}

		## the params to use in calling the helper function to actually create the new object
		$hshParamsForNewItem = @{
			ComputerName = $ComputerName
			ItemType = $strThisItemType
			Name = $Name
			SpecForNewItem = $hshNewItemSpec | ConvertTo-Json
		} ## end hashtable

		## set the XIOS REST API param to 2.0; the Tag object type is only available in XIOS v4 and up (and, so, API v2 and newer)
		$hshParamsForNewItem["XiosRestApiVersion"] = "2.0"

		## call the function to actually make this new item
		New-XIOItem @hshParamsForNewItem
	} ## end process
} ## end function


<#	.Description
	Create a new, "internal" XtremIO user account

	.Example
	New-XIOUserAccount -Credential (Get-Credential test_RoUser) -Role read_only
	Create a new UserAccount with the read_only role, and with the given username/password. Uses default inactivity timeout configured on the XMS

	.Example
	New-XIOUserAccount -UserName test_CfgUser -Role configuration -UserPublicKey $strThisPubKey -InactivityTimeout 45
	Create a new UserAccount with the configuration role, and with the given username and PublicKey. Sets inactivity timeout of 45 minutes for this new user

	.Outputs
	XioItemInfo.UserAccount object for the newly created object if successful
#>
function New-XIOUserAccount {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.UserAccount])]
	param(
		## XMS address to use
		[string[]]$ComputerName,

		## Credentials from which to make new user account (from the credential's username and password)
		[parameter(Position=0)][parameter(Mandatory=$true,ParameterSetName="SpecifyCredential")][System.Management.Automation.PSCredential]$Credential,

		## If specifying a public key for a user, instead of a credential, this is the username for the new user; use either -Credential or (-UserName and -UserPublicKey)
		[parameter(Mandatory=$true,ParameterSetName="SpecifyPublicKey")][string]$UserName,

		## If specifying a public key for a user, instead of a credential, this is the public key for the new user; use either -Credential or (-UserName and -UserPublicKey)
		[parameter(Mandatory=$true,ParameterSetName="SpecifyPublicKey")][string]$UserPublicKey,

		## User role.  One of 'read_only', 'configuration', 'admin', or 'technician'. To succeed in adding a user with "technician" role, seems that you may need to authenticated to the XMS _as_ a technician first (as administrator does not succeed)
		[parameter(Mandatory=$true)][ValidateSet('read_only', 'configuration', 'admin', 'technician')]$Role,

		## Inactivity timeout in minutes. Provide value of zero ("0") to specify "no timeout" for this user
		[int]$InactivityTimeout
	) ## end param

	Begin {
		## this item type (singular)
		$strThisItemType = "user-account"
	} ## end begin

	Process {
		## the API-specific pieces that define the new XIO object's properties
		$hshNewItemSpec = @{
			role = $Role
		} ## end hashtable

		Switch($PsCmdlet.ParameterSetName) {
			## for SpecifyCredential, populate "usr-name" and "password"
			"SpecifyCredential" {$hshNewItemSpec["usr-name"] = $Credential.UserName; $hshNewItemSpec["password"] = $Credential.GetNetworkCredential().Password; break}
			## for SpecifyPublicKey, populate "usr-name" and "public-key"
			"SpecifyPublicKey" {$hshNewItemSpec["usr-name"] = $UserName; $hshNewItemSpec["public-key"] = $UserPublicKey}
		} ## end switch

		if ($PSBoundParameters.ContainsKey("InactivityTimeout")) {$hshNewItemSpec["inactivity-timeout"] = $InactivityTimeout}

		## the params to use in calling the helper function to actually create the new object
		$hshParamsForNewItem = @{
			ComputerName = $ComputerName
			ItemType = $strThisItemType
			Name = $hshNewItemSpec["usr-name"]
			SpecForNewItem = $hshNewItemSpec | ConvertTo-Json
		} ## end hashtable

		## set the XIOS REST API param to 2.0; the Tag object type is only available in XIOS v4 and up (and, so, API v2 and newer)
		$hshParamsForNewItem["XiosRestApiVersion"] = "2.0"

		## call the function to actually make this new item
		New-XIOItem @hshParamsForNewItem
	} ## end process
} ## end function


<#	.Description
	Create a new XtremIO volume

	.Example
	New-XIOVolume -Name testvol03 -SizeGB 2KB
	Create a 2TB (which is 2048GB, as represented by the "2KB" value for the -SizeGB param) volume named testvol0

	.Example
	New-XIOVolume -ComputerName somexms01.dom.com -Name testvol04 -SizeGB 5120 | New-XIOTagAssignment -Tag (Get-XIOTag /Volumes/testVols)
	Create a 5TB volume named testvol04 and assign the given Tag to the new volume

	.Example
	New-XIOVolume -Name testvol05 -SizeGB 5KB -EnableSmallIOAlert -EnableUnalignedIOAlert -EnableVAAITPAlert
	Create a 5TB volume named testvol05 with all three alert types enabled

	.Example
	New-XIOVolume -Name testvol10 -Cluster myxio05,myxio06 -SizeGB 1024
	Create two 1TB volumes named "testvol10", one on each of the two given XIO clusters (expects that the XMS is using at least v2.0 of the REST API, which is available as of XIOS v4.0)

	.Example
	New-XIOVolume -ComputerName somexms01.dom.com -Name testvol11 -SizeGB 5120 -ParentFolder "/testVols"
	Deprecated:  Create a 5TB volume named testvol04 in the given parent folder (specifying parent folder no longer supported in XIOS REST API v2.0, which came in XIOS v4.0)

	.Outputs
	XioItemInfo.Volume object for the newly created object if successful
#>
function New-XIOVolume {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.Volume])]
	param(
		## XMS address to use
		[parameter(Position=0)][string[]]$ComputerName,

		## Name for new volume being made
		[parameter(Mandatory=$true)][string]$Name,

		## The alignment offset for volumes of 512 Logical Block size, between 0 and 7. If this property is omitted, the offset value is 0. Volumes of lb-size 4096 must not be defined with an offset.
		[ValidateRange(0,7)][int]$AlignmentOffset,

		## The volume's Logical Block size, either 512 (default) or 4096.  Once defined, the size cannot be modified.  If defined as 4096, AlignmentOffset will be ignored
		[ValidateSet(512,4096)][int]$LogicalBlockSize = 512,

		## The name of the XIO Cluster on which to make new volume. This parameter may be omitted if there is only one cluster defined in the XtremIO Storage System.
		[string[]]$Cluster,

		## The disk space size of the volume in GB. This parameter reflects the size of the volume available to the initiators. It does not indicate the actual SSD space this volume may consume
		#   Must be an integer greater than 0 and a multiple of 1 MB.
		[parameter(Mandatory=$true)][ValidateScript({$_ -gt 0})][int]$SizeGB,

		## Deprecated:  Identifies the volume folder to which this volume will initially belong. The folder's Folder Type must be Volume. If omitted, the volume will be added to the root volume folder. Example value: "/myBigVolumesFolder"
		##   Note:  parameter is obsolete, no longer supported in XIOS API v2.0
		[ValidateScript({$_.StartsWith("/")})][string]$ParentFolder,

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
		if ($PSBoundParameters.ContainsKey("ParentFolder")) {Write-Warning "Parameter ParentFolder is obsolete in XIOS API v2.0.  Parameter will be removed from this cmdlet in a future release."}
	} ## end begin

	Process {
		## the API-specific pieces that define the new XIO object's properties
		$hshNewItemSpec = @{
			"vol-name" = $Name
			## The disk space size of the volume in KB(k)/MB(m)/GB(g)/or TB(t). This parameter reflects the size of the volume available to the initiators. It does not indicate the actual SSD space this volume may consume.
			#   Must be an integer greater than 0 and a multiple of 1 MB.
			"vol-size" = "{0}g" -f $SizeGB
		} ## end hashtable
		## add these if bound
		if ($PSBoundParameters.ContainsKey("LogicalBlockSize")) {$hshNewItemSpec["lb-size"] = $LogicalBlockSize}
		if ($PSBoundParameters.ContainsKey("ParentFolder")) {$hshNewItemSpec["parent-folder-id"] = $ParentFolder}
		## only add this if lb-size is (not bound) or (bound and -ne 4096); "Volumes of lb-size 4096 must not be defined with an offset"
		if ($PSBoundParameters.ContainsKey("AlignmentOffset")) {
			if ((-not $PSBoundParameters.ContainsKey("LogicalBlockSize")) -or ($LogicalBlockSize -ne 4096)) {$hshNewItemSpec["alignment-offset"] = $AlignmentOffset}
			else {Write-Warning "Volumes of lb-size 4096 must not be defined with an offset. Not using specified AlignmentOffset"}
		} ## end if

		## set Alerts to enabled for any of the config items specified
		if ($EnableSmallIOAlert) {$hshNewItemSpec["small-io-alerts"] = $strEnableAlertValue}
		if ($EnableUnalignedIOAlert) {$hshNewItemSpec["unaligned-io-alerts"] = $strEnableAlertValue}
		if ($EnableVAAITPAlert) {$hshNewItemSpec["vaai-tp-alerts"] = $strEnableAlertValue}

		## the params to use in calling the helper function to actually create the new object
		$hshParamsForNewItem = @{
			ComputerName = $ComputerName
			ItemType = $strThisItemType
			Name = $Name
			SpecForNewItem = $hshNewItemSpec | ConvertTo-Json
		} ## end hashtable

		## if the user specified a cluster to use, include that param, and set the XIOS REST API param to 2.0; this excludes XIOS REST API v1 with multicluster from being a target for new XIO volumes with this cmdlet
		if ($PSBoundParameters.ContainsKey("Cluster")) {$hshParamsForNewItem["Cluster"] = $Cluster; $hshParamsForNewItem["XiosRestApiVersion"] = "2.0"}

		## call the function to actually make this new item
		New-XIOItem @hshParamsForNewItem
	} ## end process
} ## end function


<#	.Description
	Create a new XtremIO volume-folder

	.Synopsis
	Deprecated cmdlet for creating legacy "folder" objects

	.Notes
	Folders have been replaced with Tags in newer XIOS releases.  Support for *Folder cmdlets is deprecated, and the cmdlets will be removed at some point.  Use Tags instead of folders.

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
		[parameter(Position=0)][string[]]$ComputerName,

		## Name for new volume being made
		[parameter(Mandatory=$true)][string]$Name,

		## Parent folder in which to make this folder; defaults to "/"
		[ValidateScript({$_.StartsWith("/")})][string]$ParentFolder = "/"
	) ## end param

	Begin {
		## this item type (singular)
		$strThisItemType = "volume-folder"
	} ## end begin

	Process {
		## the API-specific pieces that define the new XIO object's properties
		$hshNewItemSpec = @{
			"caption" = $Name
			"parent-folder-id" = $ParentFolder
		} ## end hashtable

		## the params to use in calling the helper function to actually create the new object
		$hshParamsForNewItem = @{
			ComputerName = $ComputerName
			ItemType = $strThisItemType
			Name = $Name
			SpecForNewItem = $hshNewItemSpec | ConvertTo-Json
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

		## Name of the XIO Cluster on which to make new snapshot. This parameter may be omitted if there is only one cluster defined in the XtremIO Storage System.
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
				$strNameForCheckingForExistingItem = ($arrSrcVolumeNames | Select-Object -First 1),$SnapshotSuffix -join "."
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
				$strNameForCheckingForExistingItem = if (($arrSrcVolumeNames | Measure-Object).Count -gt 0) {($arrSrcVolumeNames | Select-Object -First 1),$SnapshotSuffix -join "."} else {$strSrcCGName,$SnapshotSuffix -join "."}
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
				$strNameForCheckingForExistingItem = if (($arrSrcVolumeNames | Measure-Object).Count -gt 0) {($arrSrcVolumeNames | Select-Object -First 1), $SnapshotSuffix -join "."} else {$strSrcSnapsetName,$SnapshotSuffix -join "."}
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
				## needs to be an array, so that the JSON will be correct for the API call, which expects an array of values
				$hshNewItemSpec["tag-list"] = $arrSrcTagNames
				## set the name for checking; may need updated for when receiving Tag value by name (won't have volume list, and won't be able to check for an existing volume of the given name)
				$strNameForCheckingForExistingItem = if (($arrSrcVolumeNames | Measure-Object).Count -gt 0) {($arrSrcVolumeNames | Select-Object -First 1),$SnapshotSuffix -join "."} else {($arrSrcTagNames | Select-Object -First 1),$SnapshotSuffix -join "."}
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


<#	.Description
	Create a new XtremIO SnapshotScheduler. Can schedule on given time interval, or on explicit day of the week (or everyday), and can specify the number of snapshots to keep or the duration for which to keep snapshots.  The maximums are 511 snapshots or an age of 5 years, whichever is lower. That is, if specifying a "Friday" schedule and "500" for the number of snapshots to keep, the system will keep the last 260 snapshots, since 5 years is the max, 5years * 52snaps/year = 260 snaps.

	.Notes
	XIO API does not require a name for the new SnapshotScheduler (a.k.a., "Scheduler" or "Protection Scheduler".  If you specify no value for -Name parameter, the name property of the new SnapshotScheduler will be an empty string (not $null).  The XMS Java-based GUI will show the SnapshotScheduler's name as "[Scheduler5]", and the XMS WebUI will show the SnapshotScheduler's name as "[Protection Scheduler5]", where 5 is the given SnapshotScheduler's index.

	API version support for specifying name:  the XtremIO REST API v2.0 does not seem to support specifying the name for a new SnapshotScheduler, but the REST API v2.1 (and newer, presumably) does support specifying the name.

	.Example
	New-XIOSnapshotScheduler -RelatedObject (Get-XIOVolume someVolume0) -Interval (New-Timespan -Days 2 -Hours 6 -Minutes 9) -SnapshotRetentionCount 20
	Create new SnapshotScheduler from a Volume, using an interval between snapshots, and specifying a particular number of Snapshots to retain

	.Example
	New-XIOSnapshotScheduler -Name mySnapScheduler0 -RelatedObject (Get-XIOConsistencyGroup testCG0) -ExplicitDay Sunday -ExplicitTimeOfDay 10:16pm -SnapshotRetentionDuration (New-Timespan -Days 10 -Hours 12) -Cluster myCluster0 -Enabled:$false
	Create new SnapshotScheduler from a ConsistencyGroup, with an explict schedule, specifying duration for which to keep Snapshots, on the given XIO cluster, and set the scheduler as user-disabled

	.Example
	Get-XIOSnapshotSet -Name testSnapshotSet0.1455845074 | New-XIOSnapshotScheduler -ExplicitDay EveryDay -ExplicitTimeOfDay 3am -SnapshotRetentionCount 500 -Suffix myScheduler0
	Create new SnapshotScheduler from a SnapshotSet, from pipeline, scheduled for every day of the week at 3am, keeping the last 500 snapshots, and with the given "suffix" that is inserted in each new snapshot's name

	.Outputs
	XioItemInfo.SnapshotScheduler object for the newly created object if successful
#>
function New-XIOSnapshotScheduler {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.SnapshotScheduler])]
	param(
		## XMS address to use
		[string[]]$ComputerName,

		## The name for the new SnapshotScheduler. Supported starting with XtremIO REST API v2.1.
		[parameter(Position=0)][string]$Name,

		## The name of the XIO Cluster on which to make new snapshot scheduler. This parameter may be omitted if there is only one cluster defined in the XtremIO Storage System.
		[string[]]$Cluster,

		## Source object of which to create snapshots with this snapshot scheduler. Can be an XIO object of type Volume, SnapshotSet, or ConsistencyGroup
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][ValidateScript({($_ -is [XioItemInfo.Volume]) -or ($_ -is [XioItemInfo.ConsistencyGroup]) -or ($_ -is [XioItemInfo.SnapshotSet])})]
		[PSObject]$RelatedObject,

		## The timespan to wait between each run of the scheduled snapshot action (maximum is 72 hours). Specify either the -Interval parameter or both of -ExplicitDay and -ExplicitTimeOfDay
		[parameter(Mandatory=$true,ParameterSetName="ByTimespanInterval_SpecifySnapNum")]
		[parameter(Mandatory=$true,ParameterSetName="ByTimespanInterval_SpecifySnapAge")][ValidateScript({$_ -le (New-TimeSpan -Hours 72)})][System.TimeSpan]$Interval,

		## The day of the week on which to take the scheduled snapshot (or, every day).  Expects the name of the day of the week, or "Everyday". Specify either the -Interval parameter or both of -ExplicitDay and -ExplicitTimeOfDay
		[parameter(Mandatory=$true,ParameterSetName="ByExplicitSchedule_SpecifySnapNum")]
		[parameter(Mandatory=$true,ParameterSetName="ByExplicitSchedule_SpecifySnapAge")]
		[ValidateSet('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Everyday')][string]$ExplicitDay,

		## The hour and minute to use for the explicit schedule, along with the explicit day of the week. Specify either the -Interval parameter or both of -ExplicitDay and -ExplicitTimeOfDay
		[parameter(Mandatory=$true,ParameterSetName="ByExplicitSchedule_SpecifySnapNum")]
		[parameter(Mandatory=$true,ParameterSetName="ByExplicitSchedule_SpecifySnapAge")][System.DateTime]$ExplicitTimeOfDay,

		## Number of Snapshots to be saved. Use either this parameter or -SnapshotRetentionDuration. With either retention Count or Duration, the oldest snapshot age to be kept is 5 years. And, the maximum count is 511 snapshots
		[parameter(Mandatory=$true,ParameterSetName="ByTimespanInterval_SpecifySnapNum")]
		[parameter(Mandatory=$true,ParameterSetName="ByExplicitSchedule_SpecifySnapNum")][ValidateRange(1,511)][int]$SnapshotRetentionCount,

		## The timespan for which a Snapshot should be saved. When the defined timespan has elapsed, the XtremIO cluster automatically removes the Snapshot.  Use either this parameter or -SnapshotRetentionCount
		##   The minimum value is 1 minute, and the maximum value is 5 years
		[parameter(Mandatory=$true,ParameterSetName="ByTimespanInterval_SpecifySnapAge")]
		[parameter(Mandatory=$true,ParameterSetName="ByExplicitSchedule_SpecifySnapAge")]
		[ValidateScript({($_ -ge (New-TimeSpan -Minutes 1)) -and ($_ -le (New-TimeSpan -Days (5*365)))})][System.TimeSpan]$SnapshotRetentionDuration,

		## Switch:  Snapshot Scheduler enabled-state. Defaults to $true (scheduler enabled)
		[Switch]$Enabled = $true,

		## Type of snapshot to create:  "Regular" (readable/writable) or "ReadOnly". Defaults to "Regular"
		[ValidateSet("Regular","ReadOnly")][string]$SnapshotType = "Regular",

		## String to injected into the resulting snapshot's name. For example, a value of "mySuffix" will result in a snapshot named something like "<baseVolumeName>.mySuffix.<someTimestamp>"
		[string]$Suffix
	) ## end param

	Begin {
		## this item type (singular)
		$strThisItemType = "scheduler"
	} ## end begin

	Process {
		## type of snapsource:  Volume, SnapshotSet, ConsistencyGroup
		$strSnapshotSourceObjectTypeAPIValue = Switch ($RelatedObject.GetType().FullName) {
			"XioItemInfo.Volume" {"Volume"; break}
			## API requires "SnapSet" string for this
			"XioItemInfo.SnapshotSet" {"SnapSet"; break}
			## not yet supported by API per API error (even though API reference says "Tag List", too)
			# "XioItemInfo.Tag" {"Tag"; break}
			"XioItemInfo.ConsistencyGroup" {"ConsistencyGroup"}
		} ## end switch

		## the API-specific pieces that define the new XIO object's properties
		$hshNewItemSpec = @{
			"snapshot-type" = $SnapshotType.ToLower()
			## name of snaphot source; need to be single item array if taglist?; could use index, too, it seems, but why would we?
			"snapshot-object-id" = $RelatedObject.Name
			"snapshot-object-type" = $strSnapshotSourceObjectTypeAPIValue
			"enabled-state" = $(if ($Enabled) {'enabled'} else {'user_disabled'})
		} ## end hashtable

		## set the snapshots-to-keep values based on ParameterSetName (either Number to keep or Duration for which to keep)
		Switch($PsCmdlet.ParameterSetName) {
			{"ByTimespanInterval_SpecifySnapNum", "ByExplicitSchedule_SpecifySnapNum" -contains $_} {$hshNewItemSpec["snapshots-to-keep-number"] = $SnapshotRetentionCount; break}
			{"ByTimespanInterval_SpecifySnapAge", "ByExplicitSchedule_SpecifySnapAge" -contains $_} {$hshNewItemSpec["snapshots-to-keep-time"] = [System.Math]::Floor($SnapshotRetentionDuration.TotalMinutes)}
		} ## end switch

		## set the scheduler type and schedule (time) string, based on the ParameterSetName
		#    time is either (Hours:Minutes:Seconds) for interval or (NumberOfDayOfTheWeek:Hour:Minute) for explicit
		Switch($PsCmdlet.ParameterSetName) {
			{"ByTimespanInterval_SpecifySnapNum", "ByTimespanInterval_SpecifySnapAge" -contains $_} {
					$hshNewItemSpec["scheduler-type"] = "interval"
					## (Hours:Minutes:Seconds)
					$hshNewItemSpec["time"] = $("{0}:{1}:{2}" -f [System.Math]::Floor($Interval.TotalHours), $Interval.Minutes, $Interval.Seconds)
					break
				} ## end case
			{"ByExplicitSchedule_SpecifySnapNum", "ByExplicitSchedule_SpecifySnapAge" -contains $_} {
					$hshNewItemSpec["scheduler-type"] = "explicit"
					## (NumberOfDayOfTheWeek:Hour:Minute), with 0-7 for NumberOfDayOfTheWeek, and 0 meaning "everyday"
					$intNumberOfDayOfTheWeek = if ($ExplicitDay -eq "Everyday") {0}
						## else, get the value__ for this name in the DayOfWeek enum, and add one (DayOfWeek is zero-based index, this XIO construct is 1-based for day names, with "0" being used as "everyday")
						else {([System.Enum]::GetValues([System.DayOfWeek]) | Where-Object {$_.ToString() -eq $ExplicitDay}).value__ + 1}
					$hshNewItemSpec["time"] = $("{0}:{1}:{2}" -f $intNumberOfDayOfTheWeek, $ExplicitTimeOfDay.Hour, $ExplicitTimeOfDay.Minute)
				} ## end case
		} ## end switch
		## if Name was specified, add it to the config spec
		if ($PSBoundParameters.ContainsKey("Name")) {$hshNewItemSpec["scheduler-name"] = $Name}
		## if Suffix was specified, add it to the config spec
		if ($PSBoundParameters.ContainsKey("Suffix")) {$hshNewItemSpec["suffix"] = $Suffix}
		## if Cluster not specified explicitly, add (else, subsequent New-XIOItem call adds it already)
		if (-not $PSBoundParameters.ContainsKey("Cluster")) {$hshNewItemSpec["cluster-id"] = $RelatedObject.Cluster.Name}

		## the params to use in calling the helper function to actually create the new object
		$hshParamsForNewItem = @{
			ComputerName = $ComputerName
			ItemType = $strThisItemType
			Name = $(if ($PSBoundParameters.ContainsKey("Name")) {$Name} else {"<new no-name scheduler>"})
			SpecForNewItem = $hshNewItemSpec | ConvertTo-Json
		} ## end hashtable

		## if the user specified a cluster to use, include that param
		if ($PSBoundParameters.ContainsKey("Cluster")) {$hshParamsForNewItem["Cluster"] = $Cluster}
		## set the XIOS REST API param to 2.0; the scheduler object type is only available in XIOS v4 and up (and, so, API v2 and newer)
		$hshParamsForNewItem["XiosRestApiVersion"] = "2.0"

		## call the function to actually make this new item
		New-XIOItem @hshParamsForNewItem
	} ## end process
} ## end function


<#	.Description
	Create a new XtremIO Tag assignment (assign a Tag to an XIO entity)

	.Example
	New-XIOTagAssignment -Tag (Get-XIOTag /Initiator/myInitiatorTag0) -Entity (Get-XIOInitiator myServer0-Init*)
	Tag the Initiators myServer0-Init* with the initiator Tag "/Initiator/myInitiatorTag0"

	.Example
	Get-XIOVolume myVol[01] | New-XIOTagAssignment -Tag (Get-XIOTag /Volume/favoriteVolumes)
	Tag the Volumes myVol0, myVol1 with the volume Tag "/Volume/favoriteVolumes"

	.Outputs
	XioItemInfo.TagAssignment object with information about the newly created assignment if successful
#>
function New-XIOTagAssignment {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.TagAssignment])]
	param(
		## XtremIO entity to which to apply/assign the given Tag. Can be an XIO object of type BBU, Brick, Cluster, ConsistencyGroup, DAE, DataProtectionGroup, InfinibandSwitch, Initiator, InitiatorGroup, SnapshotScheduler, SnapshotSet, SSD, StorageController, Target, or Volume
		[parameter(ValueFromPipeline=$true, Mandatory=$true)][PSObject[]]$Entity,

		## The Tag object to apply/assign to the given Entity object(s)
		[parameter(Mandatory=$true)][XioItemInfo.Tag]$Tag
	) ## end param

	Begin {
		## this item type (singular)
		# $strThisItemType = "tag"
		## TypeNames of supported Entity objects
		$arrTypeNamesOfSupportedEntityObj = Write-Output BBU, Brick, Cluster, ConsistencyGroup, DAE, DataProtectionGroup, InfinibandSwitch, Initiator, InitiatorGroup, SnapshotScheduler, SnapshotSet, SSD, StorageController, Target, Volume | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		$Entity | Foreach-Object {
			$oThisEntity = $_
			if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedEntityObj) {
				## the Tag object that will get updated
				$oThisTag = $Tag

				## the API-specific pieces that define the new properties to add to the given XIO Tag object
				$hshSetItemSpec = ([ordered]@{
					"tag-id" = @($oThisTag.Guid, $oThisTag.Name, $oThisTag.Index)
					## get the URI entity type value to use for this Entity type shortname
					"entity" = $hshCfg.TagEntityTypeMapping[$oThisEntity.GetType().Name]
					"entity-details" = @($oThisEntity.Guid, $oThisEntity.Name, $oThisEntity.Index)
				}) ## end hashtable

				## add cluster-id if suitable
				if ($oThisEntity -is [XioItemInfo.Cluster]) {$hshSetItemSpec["cluster-id"] = @($oThisEntity.Guid, $oThisEntity.Name, $oThisEntity.Index)}
				## SnapshotScheduler object in REST API v2.0 has $null Cluster property value
				else {if ($null -ne $oThisEntity.Cluster) {$hshSetItemSpec["cluster-id"] = $oThisEntity.Cluster.Name}}

				## the params to use in calling the helper function to actually update the Tag object
				$hshParamsForSetItem = @{
					SpecForSetItem = $hshSetItemSpec | ConvertTo-Json
					## the Set-XIOItemInfo cmdlet derives the ComputerName to use from the .ComputerName property of this tag object being acted upon; so, not taking -ComputerName as param to New-XIOTagAssignment
					XIOItemInfoObj = $oThisTag
					Confirm = $false
				} ## end hashtable

				## call the function to make this new item, which is actually setting properties on a Tag object
				try {
					$oUpdatedTag = Set-XIOItemInfo @hshParamsForSetItem
					if ($null -ne $oUpdatedTag) {New-Object -Type XioItemInfo.TagAssignment -Property ([ordered]@{Tag = $oUpdatedTag; Entity = Get-XIOItemInfo -Uri $oThisEntity.Uri})}
				} ## end try
				## currently just throwing caught error
				catch {Throw $_}
			} ## end if
			else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedEntityObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedEntityObj -join ", "))}
		} ## end foreach-object
	} ## end process
} ## end function
