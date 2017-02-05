<#	.Description
	Function to get XtremIO item info using REST API with XtremIO Management Server (XMS); Apr 2014, Matt Boren.  Tries to do some auto-detection of the API version (and, so, the URIs to use) by determining on which port the XMS is listening for API requests.  There was a change from v2.2.2 to v2.2.3 of the XMS in which they stopped listening on the non-SSL port 42503, and began listening on 443.

	.Example
	Get-XIOItemInfo
	Request info from XMS and return an object with the "cluster" info for the logical storage entity defined on the array

	.Example
	Get-XIOItemInfo -ComputerName somexmsappl01.dom.com -ItemType initiator
	Return some objects with info about the defined intiators on the given XMS

	.Example
	Get-XIOItemInfo -ItemType volume
	Return objects with info about each LUN mapping on the XMS

	.Example
	Get-XIOItemInfo -ItemType cluster -ReturnFullResponse
	Return PSCustomObjects that contain the full data from the REST API response (helpful for looking at what all properties are returned/available)

	.Example
	Get-XIOItemInfo -ItemType lun-map -Property VolumeName,LunID
	Get LunMap objects, but just retrieve the two specified properties instead of the default of retrieving all properties

	.Example
	Get-XIOItemInfo -ItemType lun-map -Property VolumeName,LunID -Filter "filter=ig-name:eq:myIG0"
	Get LunMap objects for which the ig-name property is "myIG0" (effectively, get the LunMaps for the initiator group "myIG0"), retrieving just the two specified properties instead of the default of retrieving all properties

	.Example
	Get-XIOItemInfo -Uri https://xms.dom.com/api/json/types -ReturnFullResponse | Select-Object -ExpandProperty children
	Return PSCustomObject that contains the full data from the REST API response (this particular example returns the HREFs for all of the base types supported by the given XMS's API -- helpful for spelunking for when new API versions come out and this XtremIO PowerShell module is not yet updated to cover new types that may have come to be)

	.Outputs
	PSCustomObject
#>
function Get-XIOItemInfo {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	param(
		## XMS address to which to connect
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName_arr,

		## Item type for which to get info; currently supported types:
		##   for all XIOS versions:                "cluster", "initiator-group", "initiator", "lun-map", target-group", "target", "volume"
		##   and, for XIOS versions 2.2.3 and up:  "brick", "snapshot", "ssd", "storage-controller", "xenv"
		##   and, for XIOS versions 2.4 and up:    "data-protection-group", "event", "ig-folder", "volume-folder"
		##   and, for XIOS version 4.0 and up:     "alert-definition", "alert", "bbu", "consistency-group", "dae", "dae-controller", "dae-psu", "email-notifier", "infiniband-switch", "ldap-config", "local-disk", "performance", "scheduler", "slot", "snapshot-set", "snmp-notifier", "storage-controller-psu", "tag", "user-account", "xms"
		[parameter(ParameterSetName="ByComputerName")]
		[ValidateSet("alert-definition", "alert", "bbu", "cluster", "consistency-group", "dae", "dae-controller", "dae-psu", "data-protection-group", "email-notifier", "event", "ig-folder", "infiniband-switch", "initiator-group", "initiator", "ldap-config", "local-disk", "lun-map", "performance", "scheduler", "slot", "snmp-notifier", "target-group", "target", "user-account", "volume", "volume-folder", "brick", "snapshot", "snapshot-set", "ssd", "storage-controller", "storage-controller-psu", "syslog-notifier", "tag", "xenv", "xms")]
		[string]$ItemType_str = "cluster",

		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name_arr,

		## Switch: Use the API v2 feature of "full=1", which returns full object details, instead of just name and HREF for the given XIO object?
		[parameter(ParameterSetName="ByComputerName")][Switch]$UseApiFullFeature,

		## XtremIO REST API filter string for refining the get operation. Filtering is supported starting in version 2.0 of the XIOS REST API. See the "Filtering Logics" section of the XtremIO Storage Array RESTful API guide. Filter syntax is: "filter=<propertyName>:<comparisonOperator>:<value>". Very brief example of syntax:  "filter=vol-size:eq:10240&filter=name:eq:production"
		[parameter(ParameterSetName="ByComputerName")][ValidatePattern("^(filter=.+:.+:.+)+")][string]$Filter,

		## Select properties to retrieve/return for given object type, instead of retrieving all (default). This capability is available as of the XIOS REST API v2
		[parameter(ParameterSetName="ByComputerName")][string[]]$Property,

		## Name of XtremIO Cluster whose child objects to get
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,

		## Additional parameters to use in the REST call (like those used to return a subset of events instead of all)
		[parameter(ParameterSetName="ByComputerName")][string]$AdditionalURIParam,

		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")][ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str,

		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse_sw
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## get the XIO connections to use, either from ComputerName param, or from the URI
		$arrXioConnectionsToUse = Get-XioConnectionsToUse -ComputerName $(
			Switch ($PSCmdlet.ParameterSetName) {
				"ByComputerName" {$ComputerName_arr; break}
				"SpecifyFullUri" {([System.Uri]($URI_str)).DnsSafeHost; break}
			})
	} ## end begin

	Process {
		## iterate through the list of $arrXioConnectionsToUse
		$arrXioConnectionsToUse | Foreach-Object {
			$oThisXioConnection = $_
			## the XtremIO Cluster name(s) to use for the query; if cluster(s) are specified, use them, else use all Cluster names known for this XioConnection
			$arrXioClusterNamesToPotentiallyUse = if ($PSBoundParameters.ContainsKey("Cluster")) {$Cluster} else {$oThisXioConnection.Cluster}
			## data hashtables for getting XIO info (not gotten via the "full view" API feature)
			$arrDataHashtablesForGettingXioInfo = @()

			## if full URI specified, use it to populate hashtables for getting XIO info
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {
				## get the plural item type from the URI (the part of the URI after "/types/")
				$strItemType_plural = Get-ItemTypeFromURI -URI $URI_str
				$arrDataHashtablesForGettingXioInfo += @{
					## the computer name, to be used for a value in the return object
					ComputerName = ([System.Uri]($URI_str)).DnsSafeHost
					arrHrefsToGetItemsInfo = $URI_str
				} ## end hashtable
			} ## end if

			## else, not SpecifyFullUri, so use ItemType
			else {
				## from the param value, make the plural form (the item types in the API are all plural; adding "s" here to the singular form used for valid param values, the singular form being the standard for PowerShell-y things)
				$strItemType_plural = Switch ($ItemType_str) {
					"infiniband-switch" {"infiniband-switches"; break}
					## items that are not "plural" in the API URIs
					{@("email-notifier", "performance", "snmp-notifier", "syslog-notifier", "xms") -notcontains $_} {"${ItemType_str}s"; break}
					default {$ItemType_str}
				} ## end switch


				## is this a type that is supported in this XioConnection's XIOS version? (and, was this not a "by URI" request? excluding those so that user can explore other objects, like /json/api/types)
				if (-not (_Test-XIOObjectIsInThisXIOSVersion -XiosVersion $oThisXioConnection.XmsVersion -ApiItemType $strItemType_plural)) {
					Write-Warning $("Type '$strItemType_plural' does not exist in $($oThisXioConnection.ComputerName)'s XIOS version{0}. This is possibly an object type that was introduced in a later XIOS version" -f $(if (-not [String]::IsNullOrEmpty($_.XmsSWVersion)) {" ($($_.XmsSWVersion))"}))
				} ## end if
				## else, the Item type _does_ exist in this XIOS version -- get its info
				else {
					## the base portion of the REST command to issue (not including any "?cluster-name=<blahh>" portion, yet)
					$strRestCmd_base = "/types/${strItemType_plural}"
					## this XMS name
					$strThisXmsName = $oThisXioConnection.ComputerName

					## if the item type is "event" or "performance", add a bit more to the URI
					if ("event","performance" -contains $ItemType_str) {
						## make REST commands (with any add'l params) to use for making new XioApiURIs for eventual object getting
						$arrRestCommandWithAnyAddlParams = @(
							## if either $AdditionalURIParam or $Cluster, append appropriate things to URI
							if ($PSBoundParameters.ContainsKey("AdditionalURIParam") -or $PSBoundParameters.ContainsKey("Cluster")) {
								## if $Cluster is specified, cycle through each value
								if ($PSBoundParameters.ContainsKey("Cluster")) {
									$Cluster | Foreach-Object {
										## make a tidbit to append that is either just "cluster-name=<blah>", or is "<addlParam>&cluster-name=<blah>"
										$strUriTidbitToAppend = ($AdditionalURIParam, "cluster-name=$_" | Where-Object {-not [string]::IsNullOrEmpty($_)}) -join "&"
										## emit this updated REST cmd (with params) as one of the elements in the array of REST commands to use
										"${strRestCmd_base}/?${strUriTidbitToAppend}"
									} ## end foreach-object
								} ## end if
								## else, it's AdditionalURIParam only, append just AdditionalURIParam to URI
								else {"${strRestCmd_base}/?${AdditionalURIParam}"}
							} ## end if
							## else, just use $strRestCmd_base
							else {$strRestCmd_base}
						) ## end array

						## grab the entity type from the AdditionalURIParam if this is a "performance" item
						$strPerformanceCounterEntityType = if ("performance" -eq $ItemType_str) {($AdditionalURIParam.Split("&") | Where-Object {$_ -like "entity=*"}).Split("=")[1]}
						## populate the array of hashtables for getting XIO info with just one computername/HREF hashtable
						$arrRestCommandWithAnyAddlParams | Foreach-Object {
							$strRestCommandWithAnyAddlParams = $_
							$arrDataHashtablesForGettingXioInfo += @{
								ComputerName = $strThisXmsName
								arrHrefsToGetItemsInfo = New-XioApiURI -ComputerName $strThisXmsName -RestCommand $strRestCommandWithAnyAddlParams
							} ## end hashtable
						} ## end foreach-object
					} ## end if

					## do all the necessary things to populate $arrDataHashtablesForGettingXioInfo with individual XIO item's HREFs
					else { ## making arrDataHashtablesForGettingXioInfo from "default" view via API, or array of objects with "full" properties, as is supported in XIOS API v2

						## if type supports cluster-name param, iterate through the specified (or default) clusters; else, do not include "cluster-name" in the URIs (passing empty string to Foreach-Object that will not get used, as the designated boolean is $false)
						$(if ($hshCfg["ItemTypesSupportingClusterNameInput"] -contains $strItemType_plural) {$bUseClusterNameInUri = $true; $arrXioClusterNamesToPotentiallyUse} else {$bUseClusterNameInUri = $false; ""}) | Foreach-Object {
							## the current XIO Cluster whose objects to get
							$strThisXIOClusterName = $_
							## for this XMS name, get ready to get API objects (either ones of default view with just HREFs, or ones with partial/full properties to consume directly with no further calls to API needed)
							$hshParamsForGetXioInfo_allItemsOfThisType = @{
								Credential = $oThisXioConnection.Credential
								ComputerName_str = $strThisXmsName
				 				## the REST command will include the "?cluster-name=<blahh>" portion if this XIO object type supports it
								RestCommand_str = "${strRestCmd_base}{0}" -f $(if ($bUseClusterNameInUri) {"?cluster-name=$strThisXIOClusterName"})
								Port_int = $oThisXioConnection.Port
								TrustAllCert_sw = $oThisXioConnection.TrustAllCert
							} ## end hsh
							## the base info for all items of this type known by this XMS (href & name pairs)
							## the general pattern:  the property returned is named the same as the item type
							#   however, not the case with:
							#     volume-folders and ig-folders:  the property is "folders"; so, need to use "folders" if either of those two types are used here
							#     xms:  the property is "xmss"
							$strPropertyNameToAccess = Switch ($strItemType_plural) {
								{"volume-folders","ig-folders" -contains $_} {"folders"; break}
								"xms" {"xmss"; break}
								default {$strItemType_plural}
							} ## end switch

							## if there was a Filter specified, add it to the query string
							if ($PSBoundParameters.ContainsKey("Filter")) {
								if ($oThisXioConnection.RestApiVersion -ge $hshCfg["MinimumRESTAPIVerForFiltering"]) {
									## add the "?filter=..." or "&filter=..." bit to the REST command (the command may already have a ?<someparam>=<blahh> piece)
									$hshParamsForGetXioInfo_allItemsOfThisType["RestCommand_str"] += "{0}{1}" -f $(if ($hshParamsForGetXioInfo_allItemsOfThisType["RestCommand_str"] -match "\?") {"&"} else {"?"}), $Filter
								} ## end if
								else {Write-Warning "Version of REST API ('$($oThisXioConnection.RestApiVersion)') on XMS '$($oThisXioConnection.ComputerName)' does not support filtering (min API version for filtering support is '$($hshCfg["MinimumRESTAPIVerForFiltering"])'). Ignoring the -Filter parameter in this call"}
							} ## end if

							## if v2 or higher API is available and "full" object views can be gotten directly (without subesquent calls for every object), and the -UseApiFullFeature switch was specified
							if (($UseApiFullFeature -or $PSBoundParameters.ContainsKey("Property")) -and ($oThisXioConnection.RestApiVersion -ge [System.Version]"2.0")) {
								## add the "?full=1" or "&full=1" bit to the REST command (the command may already have a ?<someparam>=<blahh> piece)
								$hshParamsForGetXioInfo_allItemsOfThisType["RestCommand_str"] += "{0}full=1" -f $(if ($hshParamsForGetXioInfo_allItemsOfThisType["RestCommand_str"] -match "\?") {"&"} else {"?"})
								## if -Property was specified, add &prop=<propName0>&prop=<propName1>... to the REST command
								if ($PSBoundParameters.ContainsKey("Property")) {
									$arrNamesOfPropertiesToGet = `
										## if there is a "mapping" config hashtable that holds PSObjectPropertyName -> APIObjectPropertyName info, get the API property names; include sys-id by default, so that Cluster property (of objects that have it) can always be property populated
										if ($hshCfg["TypePropMapping"].ContainsKey($strItemType_plural)) {
											## if "friendly" property names were passed, get the corresponding XIO API property names to use in the request
											@($Property) + "sys-id" | Where-Object {$null -ne $_} | Foreach-Object {if ($hshCfg["TypePropMapping"][$strItemType_plural].ContainsKey($_)) {$hshCfg["TypePropMapping"][$strItemType_plural][$_]} else {$_}}
										} ## end if
										## else, just use the property names as passed in
										else {@($Property) + "sys-id" | Where-Object {$null -ne $_}}
									$hshParamsForGetXioInfo_allItemsOfThisType["RestCommand_str"] += ("&{0}" -f (($arrNamesOfPropertiesToGet | Foreach-Object {"prop=$_"}) -join "&"))
								} ## end if
								## get an object from the API that holds the full view of the given object types, and that has properties <objectsType> and "Links"
								#    the array of full object views from the API response is had by:  $oApiResponseToGettingFullObjViews.$strPropertyNameToAccess; like "$oApiResponseToGettingFullObjViews.'lun-maps'"
								$oApiResponseToGettingFullObjViews = Get-XIOInfo @hshParamsForGetXioInfo_allItemsOfThisType
								## get the base HREF for the object views, from the API response; should be something like "https://xms.dom.com/api/json/types/lun-maps" after the TrimEnd(); for use in creating new objects from FullApiObjects
								$strBaseHref_TheseFullApiObjects = ($oApiResponseToGettingFullObjViews.links | Where-Object {$_.rel -eq "self"}).href.TrimEnd("/")

								## return XIO objects for these API response objects (if any)
								if (($oApiResponseToGettingFullObjViews | Measure-Object).Count -gt 0) {
									## boolean to let later code know that objects were returned
									$bReturnedObjects = $true
									## if returning full API response, do so
									if ($ReturnFullResponse_sw) {$oApiResponseToGettingFullObjViews}
									else {
										## for each of the FullApiObjects, create and return a new XIO object
										$oApiResponseToGettingFullObjViews.$strPropertyNameToAccess | Foreach-Object {
											## recreate the Uri for this item from the base HREF for these items and the index of this particular item
											$strUriThisItem = "${strBaseHref_TheseFullApiObjects}/{0}{1}" -f $_.index,$(if ($bUseClusterNameInUri) {"?cluster-name=$strThisXIOClusterName"})
											_New-ObjectFromApiObject -ApiObject $_ -ItemType $strItemType_plural -ComputerName $oThisXioConnection.ComputerName -ItemURI $strUriThisItem -UsingFullApiObjectView
										} ## end foreach-object
									} ## end else
								} ## end if
							} ## end if using ApiFullFeature or using -Property param

							## else, make arrDataHashtablesForGettingXioInfo from "default" view via API, for later return object creation
							else {
								## get the HREF->Name objects for this type of item
								$arrKnownItemsOfThisTypeHrefInfo = (Get-XIOInfo @hshParamsForGetXioInfo_allItemsOfThisType).$strPropertyNameToAccess

								## get the known items of this type, based on Name matching (if any)
								$arrItemsOfThisTypeToReturn_HrefInfo =
									## if particular initiator names specified, get just the hrefs for those
									if ($PSBoundParameters.ContainsKey("Name_arr")) {
										$Name_arr | Select-Object -Unique | Foreach-Object {
											$strThisItemNameToGet = $_
											## if any of the names are like the specified name, add those HREFs to the array of HREFs to get
											$arrTmp_ItemsOfThisTypeAndNameHrefInfo = $arrKnownItemsOfThisTypeHrefInfo | Where-Object {$_.Name -like $strThisItemNameToGet}
											if (($arrTmp_ItemsOfThisTypeAndNameHrefInfo | Measure-Object).Count -gt 0) {$arrTmp_ItemsOfThisTypeAndNameHrefInfo.href } ## end if
											else {Write-Verbose "$strLogEntry_ToAdd No '$ItemType_str' item of name '$_' found on '$strThisXmsName'. Valid item name/type pair?"}
										} ## end foreach-object
									} ## end if
									## else, getting all objects of this type known; get all the hrefs
									else {$arrKnownItemsOfThisTypeHrefInfo | Foreach-Object {$_.href}} ## end else

								## get the API Hrefs for getting the detailed info for the desired items (specified items, or all items of this type)
								#   and, add the "?cluster-name=<blahh>" bit here if using ClusterName in Uri
								$arrHrefsToGetItemsInfo_thisXmsAppl = if ($bUseClusterNameInUri) {
										$arrItemsOfThisTypeToReturn_HrefInfo | Foreach-Object {"{0}?cluster-name={1}" -f $_, $strThisXIOClusterName}
									} ## end if
									else {$arrItemsOfThisTypeToReturn_HrefInfo}

								## if there are HREFs from which to get info, add new hashtable to the overall array
								if (($arrHrefsToGetItemsInfo_thisXmsAppl | Measure-Object).Count -gt 0) {
									$arrDataHashtablesForGettingXioInfo += @{
										ComputerName = $strThisXmsName
										## HREFs to get are the unique HREFs (depending on the -Name value provided, user might have made overlapping matches)
										arrHrefsToGetItemsInfo = $arrHrefsToGetItemsInfo_thisXmsAppl | Select-Object -Unique
									} ## end hashtable
								} ## end if
							} ## end else
						} ## end of foreach-object on XIO Cluster names

					} ## end else "making arrDataHashtablesForGettingXioInfo"; end if "not full URI"
				} ## end else (item type _does_ exist in this XIOS version)
			} ## end else (was not SpecifyFullUri, so used ItemType)


			## get and return the actual info items, if any
			## if there are hrefs from which to get item info, do so for each
			if (($arrDataHashtablesForGettingXioInfo | Measure-Object).Count -gt 0) {
				$arrDataHashtablesForGettingXioInfo | Foreach-Object {
					## $_ is a hsh of DataForGettingInfoFromThisXmsAppl, with key arrHrefsToGetItemsInfo that has HREFs for getting items' info
					$_.arrHrefsToGetItemsInfo | Foreach-Object {
						$strUriThisItem = $_
						## make the params hash for this item
						$hshParamsForGetXioInfo_thisItem = @{
							Credential = $oThisXioConnection.Credential
							URI_str = $strUriThisItem
						} ## end hsh
						$hshParamsForGetXioInfo_thisItem["TrustAllCert_sw"] = $oThisXioConnection.TrustAllCert
						## call main Get-Info function with given params, getting a web response object back
						$oResponseCustObj = Get-XIOInfo @hshParamsForGetXioInfo_thisItem
## for returnfullresponse, need to include the cluster-name to make proper, full URI?
						if ($ReturnFullResponse_sw) {$oResponseCustObj}
						else {_New-ObjectFromApiObject -ApiObject $oResponseCustObj -ItemType $strItemType_plural -ComputerName $oThisXioConnection.ComputerName -ItemURI $strUriThisItem}
					} ## end foreach-object
				} ## end foreach-object
			} ## end "if there are hrefs from which to get item info, do so for each"
			elseif (-not $bReturnedObjects) {Write-Verbose "no matching objects found"}
		} ## end foreach-object
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO BBU info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOBBU
	Get the "BBU" items

	.Example
	Get-XIOBBU -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "BBU" items from the given XMS appliance, and only for the given XIO Clusters

	.Example
	Get-XIOStorageController -Name X1-SC2 -Cluster myCluster0 -ComputerName somexmsappl01.dom.com | Get-XIOBBU
	Get the BBU that is associated with the StorageController "X1-SC2" from the given XMS appliance and XIO Cluster

	.Example
	Get-XIOBrick -Name X1 -Cluster myCluster0 -ComputerName somexmsappl01.dom.com | Get-XIOBBU -Name X2-BBU
	Get the BBU of the given name, and that is associated with the Brick "X1" from the given XMS appliance and XIO Cluster

	.Example
	Get-XIOTag /BatteryBackupUnit/myBBUTag0 | Get-XIOBBU
	Get the BBU(s) to which the given Tag is assigned

	.Outputs
	XioItemInfo.BBU
#>
function Get-XIOBBU {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.BBU])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,

		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][parameter(Position=0,ParameterSetName="ByRelatedObject")][string[]]$Name,

		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,

		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI,

		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,

		## Related object from which to determine the BBU to get. Can be an XIO object of type Brick, StorageController, or Tag
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "bbu"
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output Brick, StorageController, Tag | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					$oThisRelatedObj = $_
					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName; Cluster = $_.Cluster}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = if ($PSBoundParameters.ContainsKey("Name")) {$Name} else {
						Switch ($oThisRelatedObj.GetType().FullName) {
							## if it is a Tag object, and the tagged ObjectType is UPS (otherwise, Tag object is not "used", as the -Name param will be $null, and the subsequent calls to get XIOItemInfos will return nothing)
							{("XioItemInfo.Tag" -eq $_) -and ($oThisRelatedObj.ObjectType -eq "UPS")} {$oThisRelatedObj.ObjectList.Name; break} ## end case
							default {$oThisRelatedObj."BBU".Name}
						} ## end switch
					} ## end else
					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					$hshParamsForGetXioInfo
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO brick info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOBrick
	Request info from current XMS connection and return an object with the "brick" info for the logical storage entity defined on the array

	.Example
	Get-XIOBrick X3
	Get the "brick" named X3

	.Example
	Get-XIOBrick -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "Brick" items from the given XMS appliance, and only for the given XIO Clusters

	.Example
	Get-XIOBBU -Name X3-BBU | Get-XIOBrick
	Get the "Brick" item associated with the given BBU

	.Example
	Get-XIOTarget X4-SC2-fc2 | Get-XIOBrick
	Get the "Brick" item associated with the given fiber channel target

	.Example
	Get-XIOBrick -ReturnFullResponse
	Return PSCustomObjects that contain the full data from the REST API response (helpful for looking at what all properties are returned/available)

	.Outputs
	XioItemInfo.Brick
#>
function Get-XIOBrick {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.Brick])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][parameter(Position=0,ParameterSetName="ByRelatedObject")][string[]]$Name_arr,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse_sw,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Related object from which to determine the Brick to get. Can be an XIO object of type BBU, Cluster, DAE, DAEController, DAEPsu, DataProtectionGroup, LocalDisk, Slot, Ssd, StorageController, StorageControllerPsu, Target, or Xenv
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "brick"
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output BBU, Cluster, DAE, DAEController, DAEPsu, DataProtectionGroup, LocalDisk, Slot, Ssd, StorageController, StorageControllerPsu, Target, Xenv | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					## the name of the property on the RelatedObject from which to get the Cluster name (Cluster objects do not have a .Cluster property)
					$strPropertyFromWhichToGetClusterName = if ($_ -is [XioItemInfo.Cluster]) {"Name"} else {"Cluster"}
					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName; Cluster = $_.$strPropertyFromWhichToGetClusterName}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = if ($PSBoundParameters.ContainsKey("Name_arr")) {$Name_arr} else {$_."Brick".Name}
					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					$hshParamsForGetXioInfo
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO cluster info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOCluster
	Request info from current XMS connection and return an object with the "Cluster" info for the logical storage entity defined on the array

	.Example
	Get-XIOCluster myCluster
	Get the "Cluster" named myCluster

	.Example
	Get-XIOInitiatorGroup myIG0 | Get-XIOCluster
	Get the "Cluster" in which this IntiatorGroup is defined

	.Example
	Get-XIOSsd -Name wwn-0x5000000000000001 | Get-XIOCluster
	Get the "Cluster" for which this SSD provides storage

	.Example
	Get-XIOVolume myVol0 | Get-XIOCluster
	Get the "Cluster" in which this Volume is defined

	.Example
	Get-XIOCluster -ReturnFullResponse
	Return PSCustomObjects that contain the full data from the REST API response (helpful for looking at what all properties are returned/available)

	.Outputs
	XioItemInfo.Cluster
#>
function Get-XIOCluster {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.Cluster])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name_arr,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse_sw,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str,
		## Related object from which to determine the Cluster to get. Can be an XIO object of type BBU, Brick, ConsistencyGroup, DAE, DAEController, DAEPsu, DataProtectionGroup, InfinibandSwitch, Initiator, InitiatorGroup, LocalDisk, LunMap, Slot, Snapshot, SnapshotSet, Ssd, StorageController, StorageControllerPsu, Target, TargetGroup, Volume, or Xenv
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "cluster"
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output BBU, Brick, ConsistencyGroup, DAE, DAEController, DAEPsu, DataProtectionGroup, InfinibandSwitch, Initiator, InitiatorGroup, LocalDisk, LunMap, Slot, Snapshot, SnapshotSet, Ssd, StorageController, StorageControllerPsu, Target, TargetGroup, Volume, Xenv | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName; Cluster = $_.Cluster}
					## for Get-XIOCluster (only), not supporting -Name in RelatedObject parameter set (doesn't make sense, as the related object would be the source for the cluster name, and if someone just wants to specify -Name for the cluster, no RelatedObject is necessary)
					$hshParamsForGetXioInfo["Name"] = $_."Cluster".Name
					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					$hshParamsForGetXioInfo
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO ConsistencyGroup info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOConsistencyGroup
	Get the "ConsistencyGroup" items

	.Example
	Get-XIOConsistencyGroup -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "ConsistencyGroup" items from the given XMS appliance, and only for the given XIO Clusters

	.Example
	Get-XIOVolume myVol0 | Get-XIOConsistencyGroup
	Get the "ConsistencyGroup" items related to this Volume

	.Example
	Get-XIOSnapshotScheduler mySnapSched0 | Get-XIOConsistencyGroup
	Get the "ConsistencyGroup" items related to this SnapshotScheduler.  Only returns anything for a SnapshotScheduler whose snapshotted object is a ConsistencyGroup

	.Outputs
	XioItemInfo.ConsistencyGroup
#>
function Get-XIOConsistencyGroup {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.ConsistencyGroup])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][parameter(Position=0,ParameterSetName="ByRelatedObject")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Related object from which to determine the ConsistencyGroup to get. Can be an XIO object of type Snapshot, SnapshotScheduler, SnapshotSet, or Volume
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "consistency-group"
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output Snapshot, SnapshotScheduler, SnapshotSet, Volume | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					$oThisRelatedObj = $_

					## In REST API v2.0, Cluster will be $null if RelatedObject is SnapshotScheduler; this goes away in API v2.1
					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName; Cluster = $_.Cluster}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = $(if ($PSBoundParameters.ContainsKey("Name")) {$Name} else {
						Switch ($oThisRelatedObj.GetType().FullName) {
							## if the related object is a SnapshotScheduler, get the ConsistencyGroup name from some subsequent object's properties
							"XioItemInfo.SnapshotScheduler" {
								if ($oThisRelatedObj.SnappedObject.Type -eq "ConsistencyGroup") {$oThisRelatedObj."SnappedObject".Name}
									## else, the SnappedObject type is a Volume or a SnapshotSet, so will get no ConsistencyGroup here
								else {$null} ## end else
								break
							} ## end case
							## default is that this related object has a ConsistencyGroup property
							default {$oThisRelatedObj."ConsistencyGroup".Name}
						} ## end switch
					}) ## end else
					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					## only return this as a hash of params of Name is not null or empty,  since Name is one of the keys by which to get the targeted object type (this RelatedObject may not have a value for the property with this targeted object the cmdlet is trying to get)
					if (-not [String]::IsNullOrEmpty($hshParamsForGetXioInfo["Name"])) {$hshParamsForGetXioInfo}
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO DAE (Disk Array Enclosure) info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIODAE
	Get the "DAE" items

	.Example
	Get-XIODAE -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "DAE" items from the given XMS appliance, and only for the given XIO Clusters

	.Example
	Get-XIOBrick -Cluster myCluster0 -ComputerName somexmsappl01.dom.com | Get-XIODAE
	Get the "DAE" items for just the related Brick object

	.Example
	Get-XIODAEController X1-DAE-LCC-B -Cluster myCluster0 -ComputerName somexmsappl01.dom.com | Get-XIODAE
	Get the "DAE" items for just the related DAEController object

	.Outputs
	XioItemInfo.DAE
#>
function Get-XIODAE {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.DAE])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][parameter(Position=0,ParameterSetName="ByRelatedObject")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Related object from which to determine the DAE to get. Can be an XIO object of type Brick, DAEController, or DAEPsu
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "dae"
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output Brick, DAEController, DAEPsu | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName; Cluster = $_.Cluster}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = if ($PSBoundParameters.ContainsKey("Name")) {$Name} else {$_."DAE".Name}
					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					$hshParamsForGetXioInfo
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO DataProtectionGroup info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIODataProtectionGroup
	Request info from current XMS connection and return an object with the "DataProtectionGroup " info for the logical storage entity defined on the array

	.Example
	Get-XIODataProtectionGroup X[34]-DPG
	Get the DataProtectionGroup objects named X3-DPG and X4-DPG

	.Example
	Get-XIODataProtectionGroup -ReturnFullResponse
	Return PSCustomObjects that contain the full data from the REST API response (helpful for looking at what all properties are returned/available)

	.Example
	Get-XIODataProtectionGroup -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "DataProtectionGroup" items from the given XMS appliance, and only for the given XIO Clusters

	.Example
	Get-XIOSsd wwn-0x5000000000000001 | Get-XIODataProtectionGroup
	Get the "DataProtectionGroup" that this SSD services

	.Example
	Get-XIOStorageController -Cluster myCluster0 -ComputerName somexmsappl01.dom.com -Name X3-SC2 | Get-XIODataProtectionGroup
	Get the "DataProtectionGroup" that this StorageController services

	.Outputs
	XioItemInfo.DataProtectionGroup
#>
function Get-XIODataProtectionGroup {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.DataProtectionGroup])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][parameter(Position=0,ParameterSetName="ByRelatedObject")][string[]]$Name_arr,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse_sw,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Related object from which to determine the DataProtectionGroup to get. Can be an XIO object of type Brick, Ssd, or StorageController
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "data-protection-group"
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output Brick, Ssd, StorageController | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName; Cluster = $_.Cluster}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = if ($PSBoundParameters.ContainsKey("Name_arr")) {$Name_arr} else {$_."DataProtectionGroup".Name}
					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					$hshParamsForGetXioInfo
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO InfiniBand Switch info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOInfinibandSwitch
	Get the "InfinibandSwitch" items

	.Example
	Get-XIOCluster myCluster0 | Get-XIOInfinibandSwitch
	Get the "InfinibandSwitch" items associated with the given cluster; potentially more useful as the XtremIO physical infrastructure grows to support more InfinibandSwitches per unit

	.Outputs
	XioItemInfo.InfinibandSwitch
#>
function Get-XIOInfinibandSwitch {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.InfinibandSwitch])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][parameter(Position=0,ParameterSetName="ByRelatedObject")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI,
		## Related object from which to determine the InfinibandSwitch to get. Can be an XIO object of type Cluster
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "infiniband-switch"
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output Cluster | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					## the name of the property on the RelatedObject from which to get the Cluster name (Cluster objects do not have a .Cluster property)
					$strPropertyFromWhichToGetClusterName = if ($_ -is [XioItemInfo.Cluster]) {"Name"} else {"Cluster"}
					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName; Cluster = $_.$strPropertyFromWhichToGetClusterName}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = if ($PSBoundParameters.ContainsKey("Name")) {$Name} else {$_."InfinibandSwitch".Name}
					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					## only return this as a hash of params of Name is not null or empty,  since Name is one of the keys by which to get the targeted object type (this RelatedObject may not have a value for the property with this targeted object the cmdlet is trying to get)
					if (-not [String]::IsNullOrEmpty($hshParamsForGetXioInfo["Name"])) {$hshParamsForGetXioInfo}
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO initiator info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOInitiator
	Request info from current XMS connection and return an object with the "initiator" info for the logical storage entity defined on the array

	.Example
	Get-XIOInitiator mysvr-hba*
	Get the "initiator" objects whose name are like mysvr-hba*

	.Example
	Get-XIOInitiator -PortAddress 10:00:00:00:00:00:00:01
	Get the "initiator" object with given port address

	.Example
	Get-XIOInitiatorGroup someIG | Get-XIOInitiator
	Get the "initiator" object in the given initiator group

	.Example
	Get-XIOTag /Initiator/myInitTag0 | Get-XIOInitiator
	Get the "initiator" objects to which the given Tag is assigned

	.Example
	Get-XIOInitiator -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "initiator" items from the given XMS appliance, and only for the given XIO Clusters

	.Example
	Get-XIOInitiator -ReturnFullResponse
	Return PSCustomObjects that contain the full data from the REST API response (helpful for looking at what all properties are returned/available)

	.Outputs
	XioItemInfo.Initiator
#>
function Get-XIOInitiator {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.Initiator])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,

		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name_arr,

		## Specific initiator Port Address for which to get initiator info; if not specified, return all
		[parameter(ParameterSetName="ByComputerName")][ValidatePattern("([0-9a-f]{2}:){7}([0-9a-f]{2})")][string[]]$PortAddress,

		## Specific initiator group ID for which to get initiator info; if not specified, return all
		[parameter(ParameterSetName="ByComputerName",ValueFromPipelineByPropertyName=$true)][string[]]$InitiatorGrpId,

		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse_sw,

		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str,

		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,

		## Related object from which to determine the Initiator to get. Can be an XIO object of type Tag
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "initiator"
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output Tag | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					$oThisRelatedObj = $_
					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName; Cluster = $_.Cluster}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = if ($PSBoundParameters.ContainsKey("Name_arr")) {$Name_arr} else {
						Switch ($oThisRelatedObj.GetType().FullName) {
							## if it is a Tag object, and the tagged ObjectType is InitiatorGroup (otherwise, Tag object is not "used", as the -Name param will be $null, and the subsequent calls to get XIOItemInfos will return nothing)
							{("XioItemInfo.Tag" -eq $_) -and ($oThisRelatedObj.ObjectType -eq "Initiator")} {$oThisRelatedObj.ObjectList.Name; break} ## end case
							## default is that this related object has a InitiatorGroup property with a subproperty Name (like Initiator and InitiatorGroupFolder objects)
							default {$null}
						} ## end switch
					} ## end else

					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					## only return this as a hash of params of Name is not null or empty,  since Name is one of the keys by which to get the targeted object type (this RelatedObject may not have a value for the property with this targeted object the cmdlet is trying to get)
					if (-not [String]::IsNullOrEmpty($hshParamsForGetXioInfo["Name"])) {$hshParamsForGetXioInfo}
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters}
			else {
				## initialize new hashtable to hold params for Get-XIOItemInfo call
				$hshParamsForGetXioItemInfo = @{}
				## get the params for Get-XIOItemInfo (exclude some choice params)
				$PSBoundParameters.Keys | Where-Object {@("PortAddress","InitiatorGrpId") -notcontains $_} | Foreach-Object {$hshParamsForGetXioItemInfo[$_] = $PSBoundParameters[$_]}
				@{ItemType = $ItemType_str} + $hshParamsForGetXioItemInfo
			} ## end else
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		$arrItemsToReturn = $arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}

		## if the PortAddress was specified, return just initiator involving that PortAddress
		if ($PSBoundParameters.ContainsKey("PortAddress")) {$arrItemsToReturn = $arrItemsToReturn | Where-Object {$oThisItem = $_; ($PortAddress | Where-Object {$oThisItem.PortAddress -eq $_}).Count -gt 0}}
		## if the InitiatorGrpId was specified, return just initiators involving that InitiatorGroup
		if ($PSBoundParameters.ContainsKey("InitiatorGrpId")) {$arrItemsToReturn = $arrItemsToReturn | Where-Object {$oThisItem = $_; ($InitiatorGrpId | Where-Object {$oThisItem.InitiatorGrpId -eq $_}).Count -gt 0}}
		return $arrItemsToReturn
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO InitiatorGroup info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOInitiatorGroup
	Request info from current XMS connection and return an object with the "InitiatorGroup" info for the logical storage entity defined on the array

	.Example
	Get-XIOInitiatorGroup myIG0
	Get the "InitiatorGroup" named myIG0

	.Example
	Get-XIOInitiator mysvr-hba* | Get-XIOInitiatorGroup
	Get the "InitiatorGroup" of which the given initiator is a part

	.Example
	Get-XIOInitiatorGroupFolder /someIGFolder/someDeeperFolder | Get-XIOInitiatorGroup
	Get the "InitiatorGroup(s)" that are directly in the given InitiatorGroupFolder

	.Example
	Get-XIOTag /InitiatorGroup/someIGTag | Get-XIOInitiatorGroup
	Get the "InitiatorGroup(s)" to which the given InitiatorGroup Tag is assigned

	.Example
	Get-XIOVolume myVol0 | Get-XIOInitiatorGroup
	Get the "InitiatorGroup(s)" that are mapped to the given volume

	.Example
	Get-XIOSnapshot mySnap0 | Get-XIOInitiatorGroup
	Get the "InitiatorGroup(s)" that are mapped to the given snapshot

	.Example
	Get-XIOInitiatorGroup -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "InitiatorGroup" items from the given XMS appliance, and only for the given XIO Clusters

	.Example
	Get-XIOInitiatorGroup -ReturnFullResponse
	Return PSCustomObjects that contain the full data from the REST API response (helpful for looking at what all properties are returned/available)

	.Outputs
	XioItemInfo.InitiatorGroup
#>
function Get-XIOInitiatorGroup {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.InitiatorGroup])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,

		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][parameter(Position=0,ParameterSetName="ByRelatedObject")][string[]]$Name_arr,

		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse_sw,

		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str,

		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,

		## Related object from which to determine the InitiatorGroup to get. Can be an XIO object of type Initiator, InitiatorGroupFolder, LunMap, Snapshot, Tag, or Volume
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "initiator-group"
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output Initiator, IgFolder, LunMap, Snapshot, Tag, Volume | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					$oThisRelatedObj = $_
					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName; Cluster = $_.Cluster}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = if ($PSBoundParameters.ContainsKey("Name_arr")) {$Name_arr} else {
						Switch ($oThisRelatedObj.GetType().FullName) {
							"XioItemInfo.LunMap" {$oThisRelatedObj."InitiatorGroup"; break} ## end case
							{"XioItemInfo.Snapshot","XioItemInfo.Volume" -contains $_} {$oThisRelatedObj.LunMapList.InitiatorGroup.Name; break} ## end case
							## if it is a Tag object, and the tagged ObjectType is InitiatorGroup (otherwise, Tag object is not "used", as the -Name param will be $null, and the subsequent calls to get XIOItemInfos will return nothing)
							{("XioItemInfo.Tag" -eq $_) -and ($oThisRelatedObj.ObjectType -eq "InitiatorGroup")} {$oThisRelatedObj.ObjectList.Name; break} ## end case
							## default is that this related object has a InitiatorGroup property with a subproperty Name (like Initiator and InitiatorGroupFolder objects)
							default {$oThisRelatedObj."InitiatorGroup".Name}
						} ## end switch
					} ## end else

					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					## only return this as a hash of params of Name is not null or empty,  since Name is one of the keys by which to get the targeted object type (this RelatedObject may not have a value for the property with this targeted object the cmdlet is trying to get)
					if (-not [String]::IsNullOrEmpty($hshParamsForGetXioInfo["Name"])) {$hshParamsForGetXioInfo}
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO initiator group folder info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOInitiatorGroupFolder
	Request info from current XMS connection and return an object with the "initiator group folder" info for the logical storage entity defined on the array

	.Example
	Get-XIOInitiatorGroupFolder /someVC/someCluster
	Get the "initiator group folder" named /someVC/someCluster

	.Example
	Get-XIOInitiatorGroup myIG0 | Get-XIOInitiatorGroupFolder
	Get the "initiator group folder" that contains the initiator group myIG0

	.Example
	Get-XIOInitiatorGroupFolder /someVC/someCluster | Get-XIOInitiatorGroup
	Get the InitiatorGroup objects in the given "initiator group folder"

	.Example
	Get-XIOInitiatorGroupFolder /someVC | Get-XIOInitiatorGroupFolder
	Get the "initiator group folder" objects that are direct subfolders of the given "initiator group folder"

	.Example
	Get-XIOInitiatorGroupFolder -ReturnFullResponse
	Return PSCustomObjects that contain the full data from the REST API response (helpful for looking at what all properties are returned/available)

	.Outputs
	XioItemInfo.IgFolder
#>
function Get-XIOInitiatorGroupFolder {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.IgFolder])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][parameter(Position=0,ParameterSetName="ByRelatedObject")][string[]]$Name_arr,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse_sw,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str,
		## Related object from which to determine the InitiatorGroupFolder to get. Can be an XIO object of type IgFolder or InitiatorGroup
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "ig-folder"
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output IgFolder, InitiatorGroup | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					$oThisRelatedObj = $_
					## no "Cluster" param here, as IgFolder objects are not cluster-specific
					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = if ($PSBoundParameters.ContainsKey("Name_arr")) {$Name_arr} else {
						Switch ($oThisRelatedObj.GetType().FullName) {
							"XioItemInfo.IgFolder" {$oThisRelatedObj."SubfolderList".Name -replace "^/InitiatorGroup",""; break} ## end case
							"XioItemInfo.InitiatorGroup" {$oThisRelatedObj."Folder".Name -replace "^/InitiatorGroup",""; break} ## end case
							## default:  doing nothing, as all cases should be covered above
							default {}
						} ## end switch
					} ## end else

					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					## only return this as a hash of params of Name is not null or empty,  since Name is one of the keys by which to get the targeted object type (this RelatedObject may not have a value for the property with this targeted object the cmdlet is trying to get)
					if (-not [String]::IsNullOrEmpty($hshParamsForGetXioInfo["Name"])) {$hshParamsForGetXioInfo}
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO LocalDisk info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOLocalDisk
	Get the "LocalDisk" items

	.Example
	Get-XIOLocalDisk -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "LocalDisk" items from the given XMS appliance, and only for the given XIO Clusters

	.Example
	Get-XIOStorageController X4-SC1 -ComputerName somexmsappl01.dom.com | Get-XIOLocalDisk
	Get the "LocalDisk" items from the given XMS appliance, and only for the given XIO StorageController

	.Outputs
	XioItemInfo.LocalDisk
#>
function Get-XIOLocalDisk {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.LocalDisk])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][parameter(Position=0,ParameterSetName="ByRelatedObject")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Related object from which to determine the LocalDisk to get. Can be an XIO object of type StorageController
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "local-disk"
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output StorageController | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName; Cluster = $_.Cluster}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = if ($PSBoundParameters.ContainsKey("Name")) {$Name} else {$_."LocalDisk".Name}
					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					$hshParamsForGetXioInfo
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO LUN map info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOLunMap
	Request info from current XMS connection and return an object with the "LUN map" info for the logical storage entity defined on the array

	.Example
	Get-XIOVolume myVolume0 | Get-XIOLunMap
	Get the LunMap objects that involve volume "myVolume0". Leverages the filtering capability available in version 2.0 and higher of the XtremIO REST API

	.Example
	Get-XIOSnapshot mySnap0 | Get-XIOLunMap -Property VolumeName,LunId
	Get the LunMap objects that involve snapshot "mySnap0", and retrieves/returns LunMap values only for the specified properties. Leverages the filtering capability available in version 2.0 and higher of the XtremIO REST API

	.Example
	Get-XIOInitiatorGroup myIG0,myIG1 | Get-XIOLunMap
	Get the LunMap objects that involve InitiatorGroups "myIG0", "myIG1". Leverages the filtering capability available in version 2.0 and higher of the XtremIO REST API

	.Example
	Get-XIOLunMap -Volume myVolume0
	Get the "LUN map" objects for volume myVolume0

	.Example
	Get-XIOLunMap -InitiatorGroup someig* -Volume *2[23]
	Get the "LUN map" objects for initator groups with names like someig* and whose volume names end with 22 or 23

	.Example
	Get-XIOLunMap -HostLunId 21,22
	Get the "LUN map" objects defined with LUN IDs 21 or 22

	.Example
	Get-XIOLunMap -Property VolumeName,LunId
	Get the "LUN map" objects, but retrieve only their VolumeName and LunId properties, so as to optimize the data retrieval (retrieve just the data desired). Note:  this is only effective when dealing with an XMS of at least v2.0 of the REST API -- the older API does not support this functionality.  The -Property parameter value is ignored if the REST API is not of at least v2.0

	.Example
	Get-XIOLunMap -HostLunId 101 -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "LUN map" items from the given XMS appliance, and only for the given XIO Clusters

	.Example
	Get-XIOLunMap -ReturnFullResponse
	Return PSCustomObjects that contain the full data from the REST API response (helpful for looking at what all properties are returned/available)

	.Outputs
	XioItemInfo.LunMap
#>
function Get-XIOLunMap {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.LunMap])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Name of LunMap object to get, in the unlikely event that this is deemed a "handy" property by which to get a LunMap. Value like "1_3_1"
		[parameter(ParameterSetName="ByComputerName",Position=0)][string[]]$Name,
		## Volume name(s) for which to get LUN mapping info (or, all volumes' mappings if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Volume,
		## Specific initiator group for which to get LUN mapping info; if not specified, return all
		[parameter(ParameterSetName="ByComputerName")][string[]]$InitiatorGroup,
		## LUN ID on which to filter returned LUN mapping info; if not specified, return all
		[parameter(ParameterSetName="ByComputerName")][int[]]$HostLunId,
		## Select properties to retrieve/return for given object type, instead of retrieving all (retriving all is default). This capability is available as of the XIOS REST API v2
		[parameter(ParameterSetName="ByComputerName")][parameter(ParameterSetName="ByRelatedObject")][string[]]$Property,
		## Related object from which to determine the LunMap to get. Can be an XIO object of type InitiatorGroup, Snapshot, or Volume. Uses Filtering feature of XtremIO REST API (requires at least v2.0 of this REST API)
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse_sw,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "lun-map"
		## initialize new hashtable to hold params for Get-XIOItemInfo call
		$hshParamsForGetXioItemInfo = @{}
		## if  not getting LunMap by URI of item, add the ItemType key/value to the Params hashtable
		if ($PSCmdlet.ParameterSetName -ne "SpecifyFullUri") {$hshParamsForGetXioItemInfo["ItemType_str"] = $ItemType_str}
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output InitiatorGroup, Snapshot, Volume | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			## add -Property param if used here
			if ($PSBoundParameters.ContainsKey("Property")) {$hshParamsForGetXIOItemInfo["Property"] = $Property}
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					$oThisRelatedObj = $_
					## make a filter for LunMaps involving this RelatedObject
					$hshParamsForGetXIOItemInfo["Filter"] = Switch ($oThisRelatedObj.GetType().FullName) {
						## if the related object is a Snapshot or a Volume
						{"XioItemInfo.Snapshot","XioItemInfo.Volume" -contains $_} {"filter=vol-name:eq:{0}" -f $oThisRelatedObj.Name; break}
						"XioItemInfo.InitiatorGroup" {"filter=ig-name:eq:{0}&filter=ig-index:eq:{1}" -f $oThisRelatedObj.Name, $oThisRelatedObj.Index; break}
					} ## end switch
					$hshParamsForGetXIOItemInfo["ComputerName"] = $oThisRelatedObj.ComputerName
					## if Cluster property is populated (which it should be almost without exception)
					if (-not [System.String]::IsNullOrEmpty($oThisRelatedObj.Cluster)) {$hshParamsForGetXIOItemInfo["Cluster"] = $oThisRelatedObj.Cluster}

					## get the actual item using this particular Filter
					Get-XIOItemInfo @hshParamsForGetXioItemInfo
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		## else, use the 'old' way of trying to filter, but that is after-the-fact of having retrieve all LunMap objects already
		else {
			## get the params for Get-XIOItemInfo (exclude some choice params)
			$PSBoundParameters.Keys | Where-Object {"Volume","InitiatorGroup","HostLunId" -notcontains $_} | Foreach-Object {$hshParamsForGetXIOItemInfo[$_] = $PSBoundParameters[$_]}
			## call the base function to get the given item
			$arrItemsToReturn = Get-XIOItemInfo @hshParamsForGetXioItemInfo
			## if the Volume was specified, return just LUN mappings involving that volume
			if ($PSBoundParameters.ContainsKey("Volume")) {$arrItemsToReturn = $arrItemsToReturn | Where-Object {$oThisItem = $_; ($Volume | Where-Object {$oThisItem.VolumeName -like $_}).Count -gt 0}}
			## if InitiatorGroup was specified, return just LUN mappings involving that InitiatorGroup
			if ($PSBoundParameters.ContainsKey("InitiatorGroup")) {$arrItemsToReturn = $arrItemsToReturn | Where-Object {$oThisItem = $_; ($InitiatorGroup | Where-Object {$oThisItem.InitiatorGroup -like $_}).Count -gt 0}}
			## if HostLunId was specified, return just LUN mappings involving that HostLunId
			if ($PSBoundParameters.ContainsKey("HostLunId")) {$arrItemsToReturn = $arrItemsToReturn | Where-Object {$HostLunId -contains $_.LunId}}
			return $arrItemsToReturn
		} ## end else
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO Slot info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOSlot
	Get the "Slot" items

	.Example
	Get-XIOSlot -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "Slot" items from the given XMS appliance, and only for the given XIO Clusters

	.Outputs
	XioItemInfo.Slot
#>
function Get-XIOSlot {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.Slot])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "slot"
		## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
		$hshParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType_str = $ItemType_str} + $PSBoundParameters}
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOItemInfo @hshParamsForGetXioInfo
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO snapshot info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOSnapshot
	Request info from current XMS connection and return an object with the "Snapshot" info for the logical storage entity defined on the array

	.Example
	Get-XIOVolumeFolder /myVolumeFolder | Get-XIOSnapshot
	Get the "Snapshot" objects that are directly in the given volume folder

	.Example
	Get-XIOInitiatorGroup myIgroup | Get-XIOSnapshot
	Get the "Snapshot" objects that are mapped to the given initiator group

	.Example
	Get-XIOSnapshot someSnap0 | Get-XIOSnapshot
	Get the "Snapshot" object that was made from source volume (a snapshot itself) "someSnap0"

	.Example
	Get-XIOSnapshotSet mySnapSet0 | Get-XIOSnapshot
	Get the "Snapshot" objects that are a part of the SnapshotSet "mySnapSet0"

	.Example
	Get-XIOVolume myVolume0 | Get-XIOSnapshot
	Get the "Snapshot" object that was made from source volume "myVolume0"

	.Example
	Get-XIOSnapshot -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "Snapshot" items from the given XMS appliance, and only for the given XIO Clusters

	.Example
	Get-XIOSnapshot -ReturnFullResponse
	Return PSCustomObjects that contain the full data from the REST API response (helpful for looking at what all properties are returned/available)

	.Outputs
	XioItemInfo.Snapshot
#>
function Get-XIOSnapshot {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.Snapshot])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][parameter(Position=0,ParameterSetName="ByRelatedObject")][string[]]$Name_arr,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse_sw,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Related object from which to determine the Snapshot to get. Can be an XIO object of type InitiatorGroup, Snapshot, SnapshotSet, Volume, or VolumeFolder
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "snapshot"
		## initialize new hashtable to hold params for Get-XIOItemInfo call
		$hshParamsForGetXioItemInfo = @{}
		## if  not getting LunMap by URI of item, add the ItemType key/value to the Params hashtable
		if ($PSCmdlet.ParameterSetName -ne "SpecifyFullUri") {$hshParamsForGetXioItemInfo["ItemType_str"] = $ItemType_str}
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output InitiatorGroup, Snapshot, SnapshotSet, Volume, VolumeFolder | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					$oThisRelatedObj = $_
					## unique to Get-XIOSnapshot, Get-XIOVolume:  if the RelatedObject is an InitiatorGroup, will do the filtering in a bit different way
					if ($oThisRelatedObj -is [XioItemInfo.InitiatorGroup]) {$bFilterByInitiatorGroupId = $true}
					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName; Cluster = $_.Cluster}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = if ($PSBoundParameters.ContainsKey("Name_arr")) {$Name_arr} else {
						Switch ($oThisRelatedObj.GetType().FullName) {
							## if the related object is a Snapshot or a Volume, get the Snapshot name from some subsequent object's properties
							{"XioItemInfo.Snapshot","XioItemInfo.Volume" -contains $_} {$oThisRelatedObj.DestinationSnapshot.Name; break} ## end case
							"XioItemInfo.SnapshotSet" {$oThisRelatedObj.VolList.Name; break} ## end case
							## this gets both volume and snapshot names, but, as the Get-XIOItemInfo call gets only Snapshots here, the names of Volumes will not "hit", so just Snapshots will come back
							"XioItemInfo.VolumeFolder" {$oThisRelatedObj.Volume.Name; break} ## end case
							"XioItemInfo.InitiatorGroup" {"*"; break}
						} ## end switch
					} ## end else

					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					## only return this as a hash of params of Name is not null or empty,  since Name is one of the keys by which to get the targeted object type (this RelatedObject may not have a value for the property with this targeted object the cmdlet is trying to get)
					if (-not [String]::IsNullOrEmpty($hshParamsForGetXioInfo["Name"])) {$hshParamsForGetXioInfo}
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		## if filtering by InitiatorGroup
		if ($bFilterByInitiatorGroupId) {
			$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_} | Where-Object {$oThisItem = $_; ($RelatedObject.InitiatorGrpId | Where-Object {$oThisItem.LunMapList.InitiatorGroup.InitiatorGrpId -contains $_}).Count -gt 0}
		} ## end if
		else {$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO SnapshotSet info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOSnapshotSet
	Get the "SnapshotSet" items

	.Example
	Get-XIOSnapshotSet -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "SnapshotSet" items from the given XMS appliance, and only for the given XIO Clusters

	.Example
	Get-XIOVolume myVolumeWithASnapshot | Get-XIOSnapshotSet
	Get the "SnapshotSet" item related to this Volume

	.Example
	Get-XIOSnapshot myImportantSnap | Get-XIOSnapshotSet
	Get the "SnapshotSet" item related to this Snapshot

	.Example
	Get-XIOSnapshotScheduler myScheduler_OfSnapset | Get-XIOSnapshotSet
	Get the "SnapshotSet" item related that this SnapshotScheduler targets as its "snapped object". If the SnapshotScheduler targets a Volume or ConsistencyGroup, this returns $null

	.Outputs
	XioItemInfo.SnapshotSet
#>
function Get-XIOSnapshotSet {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.SnapshotSet])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Related object from which to determine the SnapshotSet to get. Can be an XIO object of type Snapshot, SnapshotScheduler, or Volume
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "snapshot-set"
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output Snapshot, SnapshotScheduler, Volume | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					$oThisRelatedObj = $_

					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName; Cluster = $_.Cluster}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = if ($PSBoundParameters.ContainsKey("Name")) {$Name} else {
						Switch ($oThisRelatedObj.GetType().FullName) {
							## if the related object is a SnapshotScheduler, get the SnapshotSet name from some subsequent object's properties
							"XioItemInfo.SnapshotScheduler" {
								if ($oThisRelatedObj.SnappedObject.Type -eq "SnapSet") {$oThisRelatedObj."SnappedObject".Name}
									## else, the SnappedObject type is a Volume or a ConsistencyGroup, so will get no SnapshotSet here
								else {$null} ## end else
								break
							} ## end case
							## default is that this related object has a SnapshotSet property
							default {$oThisRelatedObj."SnapshotSet".Name}
						} ## end switch
					} ## end else

					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					$hshParamsForGetXioInfo
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO SSD info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOSsd
	Request info from current XMS connection and return an object with the "SSD" info for the logical storage entity defined on the array

	.Example
	Get-XIOSsd wwn-0x500000000abcdef0
	Get the "SSD" named wwn-0x500000000abcdef0

	.Example
	Get-XIOSsd -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "SSD" items from the given XMS appliance, and only for the given XIO Clusters

	.Example
	Get-XIOBrick -Name X3 | Get-XIOSsd
	Get the "SSD" items for the SSDs in the given Brick

	.Example
	Get-XIOSlot 3_23 | Get-XIOSsd
	Get the "SSD" info for the SSD in the given Slot

	.Example
	Get-XIOSsd -ReturnFullResponse
	Return PSCustomObjects that contain the full data from the REST API response (helpful for looking at what all properties are returned/available)

	.Outputs
	XioItemInfo.Ssd
#>
function Get-XIOSsd {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.Ssd])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name_arr,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse_sw,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Related object from which to determine the Ssd to get. Can be an XIO object of type Brick or Slot
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "ssd"
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output Brick, Slot | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					$oThisRelatedObj = $_

					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName; Cluster = $_.Cluster}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = if ($PSBoundParameters.ContainsKey("Name")) {$Name} else {
						Switch ($oThisRelatedObj.GetType().FullName) {
							## if the related object is a Slot, get the SSD name from some subsequent object's properties
							"XioItemInfo.Slot" {$oThisRelatedObj.SsdUid; break} ## end case
							## default is that this related object has an SSD property
							default {$oThisRelatedObj."SSD".Name}
						} ## end switch
					} ## end else

					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					$hshParamsForGetXioInfo
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO storage controller info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOStorageController
	Request info from current XMS connection and return an object with the "storage controller" info for the logical storage entity defined on the array

	.Example
	Get-XIOStorageController X3-SC1
	Get the "StorageController" named X3-SC1

	.Example
	Get-XIOStorageController -Name X1-SC2 -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the given "StorageController" items from the given XMS appliance, and only for the given XIO Clusters

	.Example
	Get-XIOLocalDisk X4-SC2-LocalDisk6 | Get-XIOStorageController
	Get the "StorageController" in which the given LocalDisk resides

	.Example
	Get-XIOLocalDisk | Where-Object {$_.LifecycleState -ne "healthy"} | Get-XIOStorageController
	Get the "StorageControllers" that have one or more LocalDisks that are in a LifeCycleState that is other than "healthy"

	.Example
	Get-XIOXenv | Sort-Object CPUUsage -Descending | Select-Object -First 1 | Get-XIOStorageController
	Get the "StorageController" of the XEnv that has the highest CPUUsage

	.Example
	Get-XIOTarget | Where-Object {($_.PortType -eq "fc") -and ($_.PortState -eq "down")} | Get-XIOStorageController
	Get the "StorageControllers" of the fibre channel Targets that are down

	.Example
	Get-XIOStorageController -ReturnFullResponse
	Return PSCustomObjects that contain the full data from the REST API response (helpful for looking at what all properties are returned/available)

	.Outputs
	XioItemInfo.StorageController
#>
function Get-XIOStorageController {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.StorageController])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name_arr,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse_sw,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Related object from which to determine the StorageController to get. Can be an XIO object of type BBU, Brick, LocalDisk, StorageControllerPsu, Target, or Xenv
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "storage-controller"
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output BBU, Brick, LocalDisk, StorageControllerPsu, Target, Xenv | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName; Cluster = $_.Cluster}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = if ($PSBoundParameters.ContainsKey("Name")) {$Name} else {$_."StorageController".Name}
					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					$hshParamsForGetXioInfo
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO Storage Controller PSU info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOStorageControllerPsu
	Get the "StorageControllerPsu" items

	.Example
	Get-XIOStorageController X1-SC2 | Get-XIOStorageControllerPsu
	Get the "StorageControllerPsu" items for the given StorageController

	.Example
	Get-XIOStorageControllerPsu -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "StorageControllerPsu" items from the given XMS appliance, and only for the given XIO Clusters

	.Outputs
	XioItemInfo.StorageControllerPsu
#>
function Get-XIOStorageControllerPsu {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.StorageControllerPsu])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Related object from which to determine the StorageControllerPsu to get. Can be an XIO object of type StorageController
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "storage-controller-psu"
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output StorageController | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName; Cluster = $_.Cluster}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = if ($PSBoundParameters.ContainsKey("Name")) {$Name} else {$_."StorageControllerPsu".Name}
					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					$hshParamsForGetXioInfo
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO Tag info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOTag
	Get the "Tag" items

	.Outputs
	XioItemInfo.Tag
#>
function Get-XIOTag {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.Tag])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI,
		## Related object from which to determine the Tag to get. Can be an XIO object of type BBU, Brick, Cluster, ConsistencyGroup, DAE, InfinibandSwitch, Initiator, InitiatorGroup, LocalDisk, Snapshot, SnapshotSet, Ssd, Target, TargetGroup, Volume, or Xenv
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "tag"
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output BBU, Brick, Cluster, ConsistencyGroup, DAE, InfinibandSwitch, Initiator, InitiatorGroup, LocalDisk, Snapshot, SnapshotSet, Ssd, Target, TargetGroup, Volume, Xenv | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					## no "Cluster" param for getting Tag objects
					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = $_."TagList".Name
					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					$hshParamsForGetXioInfo
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO target info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOTarget
	Request info from current XMS connection and return an object with the "Target" info for the logical storage entity defined on the array

	.Example
	Get-XIOTarget *fc[12]
	Get the "Target" objects with names ending in "fc1" or "fc2"

	.Example
	Get-XIOTarget -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "Target" items from the given XMS appliance, and only for the given XIO Clusters

	.Example
	Get-XIOTarget -ReturnFullResponse
	Return PSCustomObjects that contain the full data from the REST API response (helpful for looking at what all properties are returned/available)

	.Outputs
	XioItemInfo.Target
#>
function Get-XIOTarget {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.Target])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name_arr,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse_sw,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "target"
		## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
		$hshParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType_str = $ItemType_str} + $PSBoundParameters}
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOItemInfo @hshParamsForGetXioInfo
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO target group info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOTargetGroup
	Request info from current XMS connection and return an object with the "TargetGroup" info for the logical storage entity defined on the array

	.Example
	Get-XIOTargetGroup Default
	Get the "TargetGroup" named Default

	.Example
	Get-XIOTarget X1-SC1-fc1 | Get-XIOTargetGroup
	Get the "TargetGroup" related to the given Target

	.Example
	Get-XIOTargetGroup -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "TargetGroup" items from the given XMS appliance, and only for the given XIO Clusters

	.Example
	Get-XIOTargetGroup -ReturnFullResponse
	Return PSCustomObjects that contain the full data from the REST API response (helpful for looking at what all properties are returned/available)

	.Outputs
	XioItemInfo.TargetGroup
#>
function Get-XIOTargetGroup {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.TargetGroup])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name_arr,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse_sw,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Related object from which to determine the TargetGroup to get. Can be an XIO object of type Target
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "target-group"
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output BBU, Brick, Cluster, ConsistencyGroup, DAE, InfinibandSwitch, Initiator, InitiatorGroup, LocalDisk, Snapshot, SnapshotSet, Ssd, Target, TargetGroup, Volume, Xenv | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					## no "Cluster" param for getting Tag objects
					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = $_."TargetGroup".Name
					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					$hshParamsForGetXioInfo
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO Volume info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOVolume
	Request info from current XMS connection and return an object with the "Volume" info for the logical storage entity defined on the array

	.Example
	Get-XIOVolume someTest02
	Get the "Volume" named someTest02

	.Example
	Get-XIOVolumeFolder /myVolumeFolder | Get-XIOVolume
	Get the "Volume" objects that are directly in the given volume folder

	.Example
	Get-XIOInitiatorGroup myIgroup | Get-XIOVolume
	Get the "Volume" objects that are mapped to the given initiator group

	.Example
	Get-XIOVolume -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "Volume" items from the given XMS appliance, and only for the given XIO Clusters

	.Example
	Get-XIOConsistencyGroup myCG0 | Get-XIOVolume
	Get the "Volume" items from the related ConsistencyGroup object

	.Example
	Get-XIOLunMap -InitiatorGroup myIG0 | Get-XIOVolume
	Get the "Volume" items from the related InitiatorGroup object

	.Example
	Get-XIOSnapshot mySnapshot0 | Get-XIOVolume
	Get the "Volume" object from which the given Snapshot was taken (the snapshot's ancestor volume)

	.Example
	Get-XIOSnapshotScheduler mySnapshotScheduler0 | Get-XIOVolume
	Get the "Volume" object that is the subject of the given SnapshotScheduler (the "snapped object" of the scheduler)

	.Example
	Get-XIOSnapshotSet someSnapshotSet | Get-XIOVolume
	Get the "Volume" items that comprise the given SnapshotSet

	.Example
	Get-XIOTag /Volume/myTestVols | Get-XIOVolume
	Get the "Volume" items to which the given Tag is assigned

	.Example
	Get-XIOVolume mySourceVolume0 | Get-XIOVolume
	Get the "Volume" item resulted from having taken a snapshot of the given volume, if any (the "offspring" Volume of this ancestor Volume)

	.Example
	Get-XIOVolume -ReturnFullResponse
	Return PSCustomObjects that contain the full data from the REST API response (helpful for looking at what all properties are returned/available)

	.Outputs
	XioItemInfo.Volume
#>
function Get-XIOVolume {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.Volume])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name_arr,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse_sw,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Related object from which to determine the Volume to get. Can be an XIO object of type ConsistencyGroup, InitiatorGroup, LunMap, Snapshot, SnapshotScheduler, SnapshotSet, Tag, Volume, or VolumeFolder
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "volume"
		## initialize new hashtable to hold params for Get-XIOItemInfo call
		$hshParamsForGetXioItemInfo = @{}
		## if  not getting LunMap by URI of item, add the ItemType key/value to the Params hashtable
		if ($PSCmdlet.ParameterSetName -ne "SpecifyFullUri") {$hshParamsForGetXioItemInfo["ItemType_str"] = $ItemType_str}
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output ConsistencyGroup, InitiatorGroup, LunMap, Snapshot, SnapshotScheduler, SnapshotSet, Tag, Volume, VolumeFolder | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					$oThisRelatedObj = $_
					## unique to Get-XIOSnapshot, Get-XIOVolume:  if the RelatedObject is an InitiatorGroup, will do the filtering in a bit different way
					if ($oThisRelatedObj -is [XioItemInfo.InitiatorGroup]) {$bFilterByInitiatorGroupId = $true}
					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName; Cluster = $_.Cluster}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = if ($PSBoundParameters.ContainsKey("Name_arr")) {$Name_arr} else {
						Switch ($oThisRelatedObj.GetType().FullName) {
							"XioItemInfo.ConsistencyGroup" {$oThisRelatedObj.VolList.Name; break} ## end case
							"XioItemInfo.LunMap" {$oThisRelatedObj.VolumeName; break} ## end case
							## if the related object is a Snapshot, get the Snapshot name from some subsequent object's properties
							"XioItemInfo.Snapshot" {$oThisRelatedObj.AncestorVolume.Name; break} ## end case
							"XioItemInfo.SnapshotScheduler" {
								if ($oThisRelatedObj.SnappedObject.Type -eq "Volume") {$oThisRelatedObj."SnappedObject".Name}
									## else, the SnappedObject type is a Consistency or a SnapshotSet, so will get no Volume here
								else {$null} ## end else
								break
							} ## end case
							"XioItemInfo.SnapshotSet" {$oThisRelatedObj.VolList.Name; break} ## end case
							## if it is a Tag object, and the tagged ObjectType is Volume (otherwise, Tag object is not "used", as the -Name param will be $null, and the subsequent calls to get XIOItemInfos will return nothing)
							{("XioItemInfo.Tag" -eq $_) -and ($oThisRelatedObj.ObjectType -eq "Volume")} {$oThisRelatedObj.ObjectList.Name; break} ## end case
							"XioItemInfo.Volume" {$oThisRelatedObj.DestinationSnapshot.Name; break} ## end case
							## this gets both volume and snapshot, since snapshots are treated as Volumes, too
							"XioItemInfo.VolumeFolder" {$oThisRelatedObj.Volume.Name; break} ## end case
							## gets all volumes, then filters later in the cmdlet
							"XioItemInfo.InitiatorGroup" {"*"; break}
						} ## end switch
					} ## end else

					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					## only return this as a hash of params of Name is not null or empty,  since Name is one of the keys by which to get the targeted object type (this RelatedObject may not have a value for the property with this targeted object the cmdlet is trying to get)
					if (-not [String]::IsNullOrEmpty($hshParamsForGetXioInfo["Name"])) {$hshParamsForGetXioInfo}
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		## if filtering by InitiatorGroup
		if ($bFilterByInitiatorGroupId) {
			$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_} | Where-Object {$oThisItem = $_; ($RelatedObject.InitiatorGrpId | Where-Object {$oThisItem.LunMapList.InitiatorGroup.InitiatorGrpId -contains $_}).Count -gt 0}
		} ## end if
		else {$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO volume folder info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOVolumeFolder
	Request info from current XMS connection and return an object with the "volume folder" info for the logical storage entity defined on the array

	.Example
	Get-XIOVolumeFolder /myBigVols
	Get the "volume folder" named /myBigVols

	.Example
	Get-XIOVolume myBigVol0 | Get-XIOVolumeFolder
	Get the "volume folder" for the volume

	.Example
	Get-XIOVolumeFolder /myBigVols | Get-XIOVolumeFolder
	Get only the "volume folder" objects that are direct subfolders of /myBigVols

	.Example
	Get-XIOVolumeFolder -ReturnFullResponse
	Return PSCustomObjects that contain the full data from the REST API response (helpful for looking at what all properties are returned/available)

	.Outputs
	XioItemInfo.VolumeFolder
#>
function Get-XIOVolumeFolder {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.VolumeFolder])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name_arr,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse_sw,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str,
		## Related object from which to determine the Volume to get. Can be an XIO object of type Snapshot, Volume, or VolumeFolder
		[parameter(ValueFromPipeline=$true, ParameterSetName="ByRelatedObject")][PSObject[]]$RelatedObject
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "volume-folder"
		## TypeNames of supported RelatedObjects
		$arrTypeNamesOfSupportedRelObj = Write-Output Snapshot, Volume, VolumeFolder | Foreach-Object {"XioItemInfo.$_"}
	} ## end begin

	Process {
		## make an array of one or more hashtables that have params for a Get-XIOItemInfo call
		$arrHshsOfParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "ByRelatedObject") {
			$RelatedObject | Foreach-Object {
				if (_Test-IsOneOfGivenType -Object $_ -Type $arrTypeNamesOfSupportedRelObj) {
					$oThisRelatedObj = $_
					## no "Cluster" param here, as VolumeFolder objects are not cluster-specific
					$hshParamsForGetXioInfo = @{ItemType = $ItemType_str; ComputerName = $_.ComputerName}
					## if -Name was specified, use it; else, use the Name property of the property of the RelatedObject that relates to the actual object type to now get
					$hshParamsForGetXioInfo["Name"] = if ($PSBoundParameters.ContainsKey("Name_arr")) {$Name_arr} else {
						Switch ($oThisRelatedObj.GetType().FullName) {
							{"XioItemInfo.Snapshot","XioItemInfo.Volume" -contains $_} {$oThisRelatedObj."Folder".Name -replace "^/Volume",""; break} ## end case
							"XioItemInfo.VolumeFolder" {$oThisRelatedObj."SubfolderList".Name -replace "^/Volume",""; break} ## end case
							## default:  doing nothing, as all cases should be covered above
							default {}
						} ## end switch
					} ## end else

					if ($ReturnFullResponse) {$hshParamsForGetXioInfo["ReturnFullResponse"] = $true}
					## only return this as a hash of params of Name is not null or empty,  since Name is one of the keys by which to get the targeted object type (this RelatedObject may not have a value for the property with this targeted object the cmdlet is trying to get)
					if (-not [String]::IsNullOrEmpty($hshParamsForGetXioInfo["Name"])) {$hshParamsForGetXioInfo}
				} ## end if
				else {Write-Warning ($hshCfg["MessageStrings"]["NonsupportedRelatedObjectType"] -f $_.GetType().FullName, ($arrTypeNamesOfSupportedRelObj -join ", "))}
			} ## end foreach-object
		} ## end if
		else {
			## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
			if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType = $ItemType_str} + $PSBoundParameters}
		} ## end else

		## call the base function to get the given item for each of the hashtables of params
		$arrHshsOfParamsForGetXioInfo | Foreach-Object {Get-XIOItemInfo @_}
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO XEnv info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOXenv
	Request info from current XMS connection and return an object with the "XEnv" info for the logical storage entity defined on the array

	.Example
	Get-XIOXenv X3-SC1-E1,X3-SC1-E2
	Get the "XEnv" items namedX3-SC1-E1 and X3-SC1-E2

	.Example
	Get-XIOXenv -Cluster myCluster0,myCluster3 -Name X1-SC2-E1, X1-SC2-E2 -ComputerName somexmsappl01.dom.com
	Get the given "XEnv" items from the given XMS appliance, and only for the given XIO Clusters

	.Example
	Get-XIOXenv -ReturnFullResponse
	Return PSCustomObjects that contain the full data from the REST API response (helpful for looking at what all properties are returned/available)

	.Outputs
	XioItemInfo.XEnv
#>
function Get-XIOXenv {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.XEnv])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name_arr,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse_sw,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "xenv"
		## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
		$hshParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType_str = $ItemType_str} + $PSBoundParameters}
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOItemInfo @hshParamsForGetXioInfo
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO event info using REST API from XtremIO Management Server (XMS).
	Note about -Start and -End parameters:  via the XIO API, the search is performed starting with the most recent event ang working back through time.  So, to get events from a month ago, one may need to specify and -End value that is (a month ago plus a few days), depending on how many events have occurred. For instance, if -Start is a date of one month ago, and -Limit is 10, this will return the 10 most recent events from _now_ (starting from now, working backwards), not the first 10 events that happened _after_ the -Start value of one month ago.  This is a bit quirky, but one can adjust -Start, -End, -Limit, etc. params to eventually get the events for the desired range.

	.Example
	Get-XIOEvent
	Request info from current XMS connection and return event info

	.Example
	Get-XIOEvent -ComputerName somexmsappl01.dom.com -Limit 100
	Request info from XMS connection "somexmsappl01" only and return objects with the event info, up to the given number specified by -Limit

	.Example
	Get-XIOEvent -Start (Get-Date).AddMonths(-1) -End (Get-Date).AddMonths(-1).AddDays(1)
	Request info from current XMS connection and return event info from one month ago for one day's amount of time (up to the default limit returned)

	.Example
	Get-XIOEvent -Severity major
	Request info from current XMS connection and return event info for all events of severity "major"

	.Example
	Get-XIOEvent -EntityType StorageController
	Request info from current XMS connection and return event info for all events involving entity of type StorageController

	.Example
	Get-XIOEvent -EntityType StorageController -SearchText level_3_warning
	Request info from current XMS connection and return event info for all events involving entity of type StorageController with string "level_3_warning" in the event

	.Outputs
	XioItemInfo.Event
#>
function Get-XIOEvent {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.Event])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Maximum number of events to retrieve per XMS connection. Default is 50
		[int]$Limit = 50,
		## Datetime of earliest event to return. Can be an actual System.DateTime object, or a string that can be cast to a DateTime, like "27 Dec 1943 11am"
		[System.DateTime]$Start,
		## Datetime of most recent event to return. Can be an actual System.DateTime object, or a string that can be cast to a DateTime, like "Jun 02 1992, 5:30:00"
		[System.DateTime]$End,
		## Severity of event to retrieve; one of 'information', 'major', 'critical', 'minor'
		[ValidateSet('information', 'major', 'critical', 'minor')]
		[ValidateScript({'information', 'major', 'critical', 'minor' -ccontains $_})][string]$Severity,
		## Category of event to retrieve; one of 'audit', 'state_change', 'hardware', 'activity', 'security', 'lifecycle', 'software'
		[ValidateSet('audit', 'state_change', 'hardware', 'activity', 'security', 'lifecycle', 'software')]
		[ValidateScript({'audit', 'state_change', 'hardware', 'activity', 'security', 'lifecycle', 'software' -ccontains $_})][string]$Category,
		## Text for which to search in events. Short little string
		[ValidateLength(0,32)][string]$SearchText,
		## Entity type for which to get events; one of 'BatteryBackupUnit', 'Cluster', 'DAE', 'DAEController', 'DAEPSU', 'IGFolder', 'InfinibandSwitch', 'InfinibandSwitchPSU', 'Initiator', 'InitiatorGroup', 'LocalDisk', 'SSD', 'StorageController', 'StorageControllerPSU', 'Target', 'Volume', 'VolumeFolder', 'X-Brick'
		[ValidateScript({'BatteryBackupUnit','Cluster','DAE','DAEController','DAEPSU','IGFolder','InfinibandSwitch','InfinibandSwitchPSU','Initiator','InitiatorGroup','LocalDisk','SSD','StorageController','StorageControllerPSU','Target','Volume','VolumeFolder','X-Brick' -ccontains $_})]
		[ValidateSet('BatteryBackupUnit','Cluster','DAE','DAEController','DAEPSU','IGFolder','InfinibandSwitch','InfinibandSwitchPSU','Initiator','InitiatorGroup','LocalDisk','SSD','StorageController','StorageControllerPSU','Target','Volume','VolumeFolder','X-Brick')]
		[string]$EntityType,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse_sw
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "event"
		## params for URI filtering:  entity, limit, severity, from-date-time, to-date-time, category, free-text
		## hashtable to "translate" between PowerShell cmdlet parameter name and the API filter parameter name
		$hshCmdletParamNameToXIOAPIParamNameMapping = @{EntityType = "entity"; Limit = "limit"; Severity = "severity"; Start = "from-date-time"; End = "to-date-time"; Category = "category"; SearchText = "free-text"}
		## array of Parameter names for this cmdlet that can be added to a URI param string as name=value pairs (don't need special formatting like dates or something)
		$arrCmdletParamNamesForNameValuePairs = "Category","EntityType","SearchText","Severity"
		## array of URI parameter "pieces" (like 'name=value') to use for filtering
		$arrUriParamPiecesToAdd = @("limit=$Limit")
		$PSBoundParameters.GetEnumerator() | Where-Object {$arrCmdletParamNamesForNameValuePairs -contains $_.Key} | Foreach-Object {
			$arrUriParamPiecesToAdd += ("{0}={1}" -f $hshCmdletParamNameToXIOAPIParamNameMapping[$_.Key], (Convert-UrlEncoding $_.Value).ConvertedString)
		} ## end foreach-object
		## add start/end date filters, if any
		"Start", "End" | Foreach-Object {
			$strThisCmdletParamName = $_
			if ($PSBoundParameters.ContainsKey($strThisCmdletParamName)) {
				$arrUriParamPiecesToAdd += "{0}={1}" -f $hshCmdletParamNameToXIOAPIParamNameMapping[$strThisCmdletParamName], (Convert-UrlEncoding $PSBoundParameters.Item($strThisCmdletParamName).ToString($hshCfg["GetEventDatetimeFormat"])).ConvertedString
			} ## end if
		} ## end foreach-object
		## URI filter portion (may end up $null if no add'l params passed to this function)
		$strURIFilter = $arrUriParamPiecesToAdd -join "&"
	} ## end begin

	Process {
		## start of params for Get-XIOItemInfo call
		$hshParamsForGetXioItemInfo = @{ItemType_str = $ItemType_str} ## end hash
		## if any of these params were passed, add them to the hashtable of params to pass along
		"ComputerName","ReturnFullResponse_sw" | Foreach-Object {if ($PSBoundParameters.ContainsKey($_)) {$hshParamsForGetXIOItemInfo[$_] = $PSBoundParameters[$_]}}
		## if any of the filtering params were passed (and, so, $strURIFilter is non-null), add param to hashtable
		if (-not [System.String]::IsNullOrEmpty($strURIFilter)) {$hshParamsForGetXioItemInfo["AdditionalURIParam"] = "${strURIFilter}"}
		#Write-Debug ("${strLogEntry_ToAdd}: string for URI filter: '$strURIFilter'")
		## call the base function to get the given events
		Get-XIOItemInfo @hshParamsForGetXioItemInfo
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO Alert info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOAlert
	Get the "Alert" items

	.Outputs
	XioItemInfo.Alert
#>
function Get-XIOAlert {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.Alert])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "alert"
		## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
		$hshParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType_str = $ItemType_str} + $PSBoundParameters}
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOItemInfo @hshParamsForGetXioInfo
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO AlertDefinition info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOAlertDefinition
	Get the "AlertDefinition" items

	.Outputs
	XioItemInfo.AlertDefinition
#>
function Get-XIOAlertDefinition {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.AlertDefinition])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "alert-definition"
		## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
		$hshParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType_str = $ItemType_str} + $PSBoundParameters}
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOItemInfo @hshParamsForGetXioInfo
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO DAE Controller info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIODAEController
	Get the "DAEController" items

	.Example
	Get-XIODAEController -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "DAEController" items from the given XMS appliance, and only for the given XIO Clusters

	.Outputs
	XioItemInfo.DAEController
#>
function Get-XIODAEController {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.DAEController])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "dae-controller"
		## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
		$hshParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType_str = $ItemType_str} + $PSBoundParameters}
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOItemInfo @hshParamsForGetXioInfo
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO DAE (Disk Array Enclosure) PSU info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIODAEPsu
	Get the "DAEPsu" items

	.Example
	Get-XIODAEPsu -Cluster myCluster0,myCluster3 -ComputerName somexmsappl01.dom.com
	Get the "DAEPsu" items from the given XMS appliance, and only for the given XIO Clusters

	.Outputs
	XioItemInfo.DAEPsu
#>
function Get-XIODAEPsu {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.DAEPsu])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "dae-psu"
		## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
		$hshParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType_str = $ItemType_str} + $PSBoundParameters}
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOItemInfo @hshParamsForGetXioInfo
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO Email Notifier info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOEmailNotifier
	Get the "EmailNotifier" items

	.Outputs
	XioItemInfo.EmailNotifier
#>
function Get-XIOEmailNotifier {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.EmailNotifier])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "email-notifier"
		## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
		$hshParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType_str = $ItemType_str} + $PSBoundParameters}
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOItemInfo @hshParamsForGetXioInfo
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO LDAP Config info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOLdapConfig
	Get the "LdapConfig" items

	.Outputs
	XioItemInfo.LdapConfig
#>
function Get-XIOLdapConfig {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.LdapConfig])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "ldap-config"
		## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
		$hshParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType_str = $ItemType_str} + $PSBoundParameters}
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOItemInfo @hshParamsForGetXioInfo
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO object performance counters using REST API from XtremIO Management Server (XMS).  Typical use of these counters would be for exporting to <some other destination> for further manipulation/massaging.

	.Example
	Get-XIOPerformanceCounter
	Request info from current XMS connection and return PerformanceCounter info

	.Example
	Get-XIOPerformanceCounter -ComputerName somexmsappl01.dom.com -Limit ([System.Int32]::MaxValue)
	Request info from XMS connection "somexmsappl01" only and return PerformanceCounter info, up to the given number specified by -Limit

	.Example
	Get-XIOPerformanceCounter -EntityType DataProtectionGroup -Start (Get-Date).AddMonths(-1) -End (Get-Date).AddMonths(-1).AddDays(1)
	Request info from current XMS connection and return PerformanceCounter info from one month ago for one day's amount of time (up to the default limit returned)

	.Example
	Get-XIOPerformanceCounter -EntityType Volume -TimeFrame real_time
	Request info from current XMS connection and return realtime (most recent sample in the last five seconds) PerformanceCounter info for entities of type Volume

	.Example
	Get-XIOPerformanceCounter -EntityType Volume -TimeFrame real_time -Cluster myCluster0
	Request info from current XMS connection and return realtime (most recent sample in the last five seconds) PerformanceCounter info for entities of type Volume, and only for the given XIO Cluster

	.Example
	Get-XIOPerformanceCounter -EntityType InitiatorGroup -TimeFrame last_hour -EntityName myInitGroup0 | ConvertTo-Json
	Get the realtime (most recent sample in the last five seconds) PerformanceCounter info for the InitiatorGroup entity myInitGroup0, and then convert it to JSON for later consumption by <some awesome data visualization app>

	.Outputs
	XioItemInfo.PerformanceCounter
#>
function Get-XIOPerformanceCounter {
	[CmdletBinding(DefaultParameterSetName="ByTimeFrameEnum")]
	[OutputType([XioItemInfo.PerformanceCounter])]
	param(
		## XMS address to use; if none, use default connections
		[string[]]$ComputerName,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[string[]]$Cluster,
		## Maximum number of performance facts to retrieve per XMS connection. Default is 50
		[int]$Limit = 50,
		## Datetime of earliest performance sample to return. Can be an actual System.DateTime object, or a string that can be cast to a DateTime, like "27 Dec 1943 11am".   Can either use -Start and -End parameters, or use -TimeFrame parameter.
		[parameter(ParameterSetName="ByStartEndDate")][System.DateTime]$Start,
		## Datetime of most recent performance sample to return. Can be an actual System.DateTime object, or a string that can be cast to a DateTime, like "Jun 02 1992, 5:30:00"
		[parameter(ParameterSetName="ByStartEndDate")][System.DateTime]$End,
		## Time frame for which to get performance counter information. Can be one of real_time, last_hour, last_day, last_week, last_year.  Can use either -TimeFrame, or use -Start and -End parameters.  If using real_time for -TimeFrame, will ignore the Granularity parameter, as real_time reports in "raw" Granularity
		[parameter(ParameterSetName="ByTimeFrameEnum")][XioItemInfo.Enums.PerfCounter.TimeFrame]$TimeFrame,
		## Entity type for which to get performance information; one of Cluster, DataProtectionGroup, Initiator, InitiatorGroup, SnapshotGroup, SSD, Target, TargetGroup, Volume, XEnv, Xms. EntityType "Tag" is not yet supported here.
		[XioItemInfo.Enums.PerfCounter.EntityType]$EntityType = "Cluster",
		## Name of the entity for which to get performance counter information; wildcarding not yet supported, so must be full object name, like "myvol.44"
		[Alias("Name")][string[]]$EntityName,
		## Type of value aggregation to use; one or more of avg, max, min
		[XioItemInfo.Enums.PerfCounter.AggregationType[]]$AggregationType,
		## Type of value granularity to use; one of auto, one_minute, ten_minutes, one_hour, one_day, raw.  If using real_time for -TimeFrame, will ignore the -Granularity parameter, as real_time determines the Granularity to use
		[XioItemInfo.Enums.PerfCounter.Granularity]$Granularity,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "performance"
		## params for URI filtering:  aggregation-type, entity, from-time, granularity, limit, obj-list, to-time, time-frame
		## hashtable to "translate" between PowerShell cmdlet parameter name and the API filter parameter name
		$hshCmdletParamNameToXIOAPIParamNameMapping = @{AggregationType = "aggregation-type"; EntityName = "obj-list"; EntityType = "entity"; Granularity = "granularity"; Limit = "limit"; Start = "from-time"; End = "to-time"; TimeFrame = "time-frame"}

		## if TimeFrame is "real_time", remove the Granularity paremeter from the bound params, as the only Granularity is auto-determined for real_time TimeFrame
		if (($TimeFrame -eq "real_time") -and ($PSBoundParameters.ContainsKey("Granularity"))) {$PSBoundParameters.Remove("Granularity")}

		## array of Parameter names for this cmdlet that can be added to a URI param string as name=value pairs (don't need special formatting like dates or something)
		$arrCmdletParamNamesForNameValuePairs = "EntityType", "Granularity", "TimeFrame"
		## array of URI parameter "pieces" (like 'name=value') to use for filtering
		$arrUriParamPiecesToAdd = @("limit=$Limit")
		## for the params that have values (either because they were passed/bound, or have a default value in the param() section)
		$arrCmdletParamNamesForNameValuePairs | Where-Object {$null -ne (Get-Variable -ValueOnly -ErrorAction:SilentlyContinue -Name $_)} | Foreach-Object {
			$strThisParamName = $_
			$arrUriParamPiecesToAdd += ("{0}={1}" -f $hshCmdletParamNameToXIOAPIParamNameMapping[$strThisParamName], (Convert-UrlEncoding (Get-Variable -Name $strThisParamName -ValueOnly)).ConvertedString)
		} ## end foreach-object
		## add start/end date filters, if any
		"Start", "End" | Foreach-Object {
			$strThisCmdletParamName = $_
			if ($PSBoundParameters.ContainsKey($strThisCmdletParamName)) {
				$arrUriParamPiecesToAdd += "{0}={1}" -f $hshCmdletParamNameToXIOAPIParamNameMapping[$strThisCmdletParamName], (Convert-UrlEncoding $PSBoundParameters.Item($strThisCmdletParamName).ToString($hshCfg["GetEventDatetimeFormat"])).ConvertedString
			} ## end if
		} ## end foreach-object
		## add AggregationType and EntityName (obj-list) items, if any
		"AggregationType", "EntityName" | Foreach-Object {
			if ($PSBoundParameters.ContainsKey($_)) {
				$strThisParamName = $_
				$PSBoundParameters.Item($strThisParamName) | Foreach-Object {$arrUriParamPiecesToAdd += ("{0}={1}" -f $hshCmdletParamNameToXIOAPIParamNameMapping[$strThisParamName], (Convert-UrlEncoding $_).ConvertedString)}
			} ## end if
		} ## end foreach-object
		## URI filter portion (may end up $null if no add'l params passed to this function)
		$strURIFilter = $arrUriParamPiecesToAdd -join "&"
	} ## end begin

	Process {
		## start of params for Get-XIOItemInfo call
		$hshParamsForGetXioItemInfo = @{ItemType_str = $ItemType_str} ## end hash
		## if any of these params were passed, add them to the hashtable of params to pass along
		"ComputerName","ReturnFullResponse","Cluster" | Foreach-Object {if ($PSBoundParameters.ContainsKey($_)) {$hshParamsForGetXioItemInfo[$_] = $PSBoundParameters[$_]}}
		## if any of the filtering params were passed (and, so, $strURIFilter is non-null), add param to hashtable
		if (-not [System.String]::IsNullOrEmpty($strURIFilter)) {$hshParamsForGetXioItemInfo["AdditionalURIParam"] = "${strURIFilter}"}
		#Write-Debug ("${strLogEntry_ToAdd}: string for URI filter: '$strURIFilter'")
		## call the base function to get the given performance counters
		Get-XIOItemInfo @hshParamsForGetXioItemInfo
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO SNMP Notifier info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOSnmpNotifier
	Get the "SnmpNotifier" items

	.Outputs
	XioItemInfo.SnmpNotifier
#>
function Get-XIOSnmpNotifier {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.SnmpNotifier])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "snmp-notifier"
		## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
		$hshParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType_str = $ItemType_str} + $PSBoundParameters}
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOItemInfo @hshParamsForGetXioInfo
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO Syslog Notifier info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOSyslogNotifier
	Get the "SyslogNotifier" items

	.Outputs
	XioItemInfo.SyslogNotifier
#>
function Get-XIOSyslogNotifier {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.SyslogNotifier])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "syslog-notifier"
		## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
		$hshParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType_str = $ItemType_str} + $PSBoundParameters}
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOItemInfo @hshParamsForGetXioInfo
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO User Account info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOUserAccount
	Get the "UserAccount" items

	.Outputs
	XioItemInfo.UserAccount
#>
function Get-XIOUserAccount {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.UserAccount])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "user-account"
		## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
		$hshParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType_str = $ItemType_str} + $PSBoundParameters}
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOItemInfo @hshParamsForGetXioInfo
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO Snapshot Scheduler info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOSnapshotScheduler
	Get the "SnapshotScheduler" items

	.Outputs
	XioItemInfo.SnapshotScheduler
#>
function Get-XIOSnapshotScheduler {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.SnapshotScheduler])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "scheduler"
		## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
		$hshParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType_str = $ItemType_str} + $PSBoundParameters}
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOItemInfo @hshParamsForGetXioInfo
	} ## end process
} ## end function


<#	.Description
	Function to get XtremIO XMS info using REST API from XtremIO Management Server (XMS)

	.Example
	Get-XIOXMS
	Request info from current XMS connection and return an object with the "XMS" info for the XMS

	.Outputs
	XioItemInfo.XMS
#>
function Get-XIOXMS {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.XMS])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name,
		## switch:  Return full response object from API call?  (instead of PSCustomObject with choice properties)
		[switch]$ReturnFullResponse,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri")]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOItemInfo
		$ItemType_str = "xms"
		## just use PSBoundParameters if by URI, else add the ItemType key/value to the Params to use with Get-XIOItemInfo, if ByComputerName
		$hshParamsForGetXioInfo = if ($PSCmdlet.ParameterSetName -eq "SpecifyFullUri") {$PSBoundParameters} else {@{ItemType_str = $ItemType_str} + $PSBoundParameters}
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOItemInfo @hshParamsForGetXioInfo
	} ## end process
} ## end function



#region  performance section #####################################################################################
<#	.Description
	Function to get XIO item performance information

	.Example
	Get-XIOPerformanceInfo -ItemType cluster
	Request info from all current XMS connections and return an object with the cluster performance info

	.Example
	Get-XIOPerformanceInfo -ComputerName somexmsappl01.dom.com  -ItemType cluster
	Request info from specified XMS connection and return an object with the cluster peformance info

	.Example
	Get-XIOPerformanceInfo -ComputerName somexmsappl01.dom.com  -ItemType initiator-group -Cluster myCluster0
	Request info from specified XMS connection and return an object with the cluster peformance info, and only for the specified XIO Cluster's objects

	.Example
	Get-XIOCluster somecluster | Get-XIOPerformanceInfo -FrequencySeconds 5 -DurationSeconds 30
	Get info for specified item and return cluster peformance info every 5 seconds for 30 seconds

	.Outputs
	PSCustomObject
#>
function Get-XIOPerformanceInfo {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	param(
		## XMS address to which to connect
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName_arr,
		## Item type for which to get info; currently supported types:
		##   for all API versions:                "cluster", "initiator-group", "initiator", "target", "volume"
		##   and, for API versions 2.2.3 and up:  "ssd"
		##   and, for API versions 2.4 and up:    "ig-folder", "volume-folder"
		## "target-group" performance not available via API, yet
		[parameter(Mandatory=$true,ParameterSetName="ByComputerName")]
		[ValidateSet("cluster","data-protection-group","ig-folder","initiator","initiator-group","ssd","target","volume-folder","volume")][string]$ItemType_str,
		## Name of XtremIO Cluster whose child objects to get
		[string[]]$Cluster,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][string[]]$Name_arr,
		## Duration for which to refresh performance info, in seconds
		[int]$DurationSeconds = 15,
		## Frequency, in seconds, to refresh performance info
		[int]$FrequencySeconds = 5,
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri",ValueFromPipelineByPropertyName)]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][Alias("Uri")][string]$URI_str
	) ## end param

	begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
	} ## end begin
	process {
		## params to pass to Get-XIOItemInfo (since there are potentially some PSBoundParameters params specific to only this function)
		$hshParamsForGetXIOItemInfo = @{}
		if ($PSBoundParameters.ContainsKey("Cluster")) {$hshParamsForGetXIOItemInfo["Cluster"] = $Cluster}
		Switch ($PSCmdlet.ParameterSetName) {
			"ByComputerName" {
				"ComputerName_arr","ItemType_str","Name_arr" | Foreach-Object {if ($PSBoundParameters.ContainsKey($_)) {$hshParamsForGetXIOItemInfo[$_] = $PSBoundParameters[$_]}}
				## type to create from _New-Object_fromItemTypeAndContent; something like "Data-Protection-GroupPerformance"
				$strItemTypeToCreate = "$((Get-Culture).TextInfo.ToTitleCase($ItemType_str.ToLower()))Performance"
				break} ## end case
			"SpecifyFullUri" {
				$hshParamsForGetXIOItemInfo["URI_str"] = $URI_str
				## the type being retrieved, for use in making the typename for the return
				$strItemType_plural = Get-ItemTypeFromURI -URI $URI_str
				## type to return; something like "TargetPerformance", grabbed from URL
				$strItemTypeToCreate = "$((Get-Culture).TextInfo.ToTitleCase($strItemType_plural.TrimEnd('s').ToLower()))Performance"
				break} ## end case
		} ## end switch
		## scriptblock to execute to get performance info
		$sbGetPerformanceInfo = {
			$arrXioItemInfo = Get-XIOItemInfo @hshParamsForGetXIOItemInfo
			$arrXioItemInfo | Foreach-Object {
				$oThisXioItemInfo = $_
				## the TypeName to use for the new object
				$strPSTypeNameForNewObj = "XioItemInfo.$($strItemTypeToCreate.Replace('-',''))"
				## make a new object with some juicy info (and a new property for the XMS "computer" name used here)
				$oObjToReturn = _New-Object_fromItemTypeAndContent -argItemType $strItemTypeToCreate -oContent $oThisXioItemInfo -PSTypeNameForNewObj $strPSTypeNameForNewObj
				$oObjToReturn.ComputerName = $oThisXioItemInfo.ComputerName
				## return the object
				return $oObjToReturn
			} ## end foreach-object
		} ## end scriptblock
		if ($PSBoundParameters.ContainsKey("DurationSeconds") -or $PSBoundParameters.ContainsKey("FrequencySeconds")) {
			## datetime of the start and end of this monitoring session
			$dteStartOfGet = Get-Date; $dteEndOfGet = $dteStartOfGet.AddSeconds($DurationSeconds); $strEndDate = $dteEndOfGet.ToString($hshCfg.VerboseDatetimeFormat)
			while ((Get-Date) -lt $dteEndOfGet) {& $sbGetPerformanceInfo; if ((Get-Date).AddSeconds($FrequencySeconds) -lt $dteEndOfGet) {Write-Verbose -Verbose "$(Get-Date -Format $hshCfg['VerboseDatetimeFormat']); '$FrequencySeconds' sec sleep; ending run at/about $strEndDate ('$DurationSeconds' sec duration)"; Start-Sleep -Seconds $FrequencySeconds} else {break}}
		} ## end if
		else {& $sbGetPerformanceInfo}
	} ## end process
} ## end function


<#	.Description
	Function to get Cluster performance information

	.Example
	Get-XIOClusterPerformance
	Request info from all current XMS connections and return objects with the cluster performance info

	.Example
	Get-XIOClusterPerformance -ComputerName somexmsappl01.dom.com
	Request info from specified XMS connection and return object with peformance info

	.Example
	Get-XIOClusterPerformance -FrequencySeconds 5 -DurationSeconds 30
	Get peformance info every 5 seconds for 30 seconds

	.Outputs
	XioItemInfo.ClusterPerformance
#>
function Get-XIOClusterPerformance {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.ClusterPerformance])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][Alias("Name")][string[]]$Name_arr,
		## Duration for which to refresh performance info, in seconds
		[int]$DurationSeconds,
		## Frequency, in seconds, with which to refresh performance info
		[int]$FrequencySeconds
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOPerformanceInfo
		$ItemType_str = "cluster"
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOPerformanceInfo @PSBoundParameters -ItemType $ItemType_str
	} ## end process
} ## end function


<#	.Description
	Function to get data-protection-group performance information

	.Example
	Get-XIODataProtectionGroupPerformance
	Request info from all current XMS connections and return objects with the data-protection-group performance info

	.Example
	Get-XIODataProtectionGroupPerformance -ComputerName somexmsappl01.dom.com
	Request info from specified XMS connection and return object with the data-protection-group peformance info

	.Example
	Get-XIODataProtectionGroupPerformance -ComputerName somexmsappl01.dom.com -Cluster myCluster0
	Request info from specified XMS connection and return object with the data-protection-group peformance info for the objects just in the specified cluster

	.Example
	Get-XIODataProtectionGroupPerformance -FrequencySeconds 5 -DurationSeconds 30
	Get data-protection-group peformance info every 5 seconds for 30 seconds

	.Outputs
	XioItemInfo.DataProtectionGroupPerformance
#>
function Get-XIODataProtectionGroupPerformance {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.DataProtectionGroupPerformance])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][Alias("Name")][string[]]$Name_arr,
		## Duration for which to refresh performance info, in seconds
		[int]$DurationSeconds,
		## Frequency, in seconds, with which to refresh performance info
		[int]$FrequencySeconds
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOPerformanceInfo
		$ItemType_str = "data-protection-group"
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOPerformanceInfo @PSBoundParameters -ItemType $ItemType_str
	} ## end process
} ## end function


<#	.Description
	Function to get initiator-group-folder performance information

	.Example
	Get-XIOInitiatorGroupFolderPerformance
	Request info from all current XMS connections and return objects with the ig-folder performance info

	.Example
	Get-XIOInitiatorGroupFolderPerformance -ComputerName somexmsappl01.dom.com
	Request info from specified XMS connection and return objects with the ig-folder peformance info

	.Example
	Get-XIOInitiatorGroupFolderPerformance -FrequencySeconds 5 -DurationSeconds 30
	Get ig-folder peformance info every 5 seconds for 30 seconds

	.Outputs
	XioItemInfo.IgFolderPerformance
#>
function Get-XIOInitiatorGroupFolderPerformance {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.IgFolderPerformance])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][Alias("Name")][string[]]$Name_arr,
		## Duration for which to refresh performance info, in seconds
		[int]$DurationSeconds,
		## Frequency, in seconds, with which to refresh performance info
		[int]$FrequencySeconds
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOPerformanceInfo
		$ItemType_str = "ig-folder"
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOPerformanceInfo @PSBoundParameters -ItemType $ItemType_str
	} ## end process
} ## end function


<#	.Description
	Function to get initiator-group performance information

	.Example
	Get-XIOInitiatorGroupPerformance
	Request info from all current XMS connections and return objects with the initiator-group performance info

	.Example
	Get-XIOInitiatorGroupPerformance -ComputerName somexmsappl01.dom.com -Cluster myCluster0
	Request info from specified XMS connection and return objects with the initiator-group performance info for the objects just in the specified cluster

	.Example
	Get-XIOInitiatorGroupPerformance -ComputerName somexmsappl01.dom.com -Name someig*,otherig*
	Request info from specified XMS connection and return objects with the initiator-group peformance info for initiator groups with names like someig* and otherig*

	.Example
	Get-XIOInitiatorGroupPerformance -FrequencySeconds 5 -DurationSeconds 30
	Get initiator-group peformance info every 5 seconds for 30 seconds

	.Outputs
	XioItemInfo.InitiatorGroupPerformance
#>
function Get-XIOInitiatorGroupPerformance {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.InitiatorGroupPerformance])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][Alias("Name")][string[]]$Name_arr,
		## Duration for which to refresh performance info, in seconds
		[int]$DurationSeconds,
		## Frequency, in seconds, with which to refresh performance info
		[int]$FrequencySeconds
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOPerformanceInfo
		$ItemType_str = "initiator-group"
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOPerformanceInfo @PSBoundParameters -ItemType $ItemType_str
	} ## end process
} ## end function


<#	.Description
	Function to get initiator performance information

	.Example
	Get-XIOInitiatorPerformance
	Request info from all current XMS connections and return objects with the initiator performance info

	.Example
	Get-XIOInitiatorPerformance -ComputerName somexmsappl01.dom.com
	Request info from specified XMS connection and return an object with the initiator peformance info

	.Example
	Get-XIOInitiatorPerformance -ComputerName somexmsappl01.dom.com -Cluster myCluster0
	Request info from specified XMS connection and return an object with the initiator peformance info for the objects just in the specified cluster

	.Example
	Get-XIOInitiatorPerformance -FrequencySeconds 5 -DurationSeconds 30
	Get initiator peformance info every 5 seconds for 30 seconds

	.Outputs
	XioItemInfo.InitiatorPerformance
#>
function Get-XIOInitiatorPerformance {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.InitiatorPerformance])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][Alias("Name")][string[]]$Name_arr,
		## Duration for which to refresh performance info, in seconds
		[int]$DurationSeconds,
		## Frequency, in seconds, with which to refresh performance info
		[int]$FrequencySeconds
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOPerformanceInfo
		$ItemType_str = "initiator"
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOPerformanceInfo @PSBoundParameters -ItemType $ItemType_str
	} ## end process
} ## end function


<#	.Description
	Function to get SSD performance information

	.Example
	Get-XIOSsdPerformance
	Request info from all current XMS connections and return objects with the SSD performance info

	.Example
	Get-XIOSsdPerformance -ComputerName somexmsappl01.dom.com
	Request info from specified XMS connection and return objects with the SSD peformance info

	.Example
	Get-XIOSsdPerformance -ComputerName somexmsappl01.dom.com -Cluster myCluster0
	Request info from specified XMS connection and return objects with the SSD peformance info for the objects just in the specified cluster

	.Example
	Get-XIOSsdPerformance -FrequencySeconds 5 -DurationSeconds 30
	Get SSD peformance info every 5 seconds for 30 seconds

	.Outputs
	XioItemInfo.SsdPerformance
#>
function Get-XIOSsdPerformance {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.SsdPerformance])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][Alias("Name")][string[]]$Name_arr,
		## Duration for which to refresh performance info, in seconds
		[int]$DurationSeconds,
		## Frequency, in seconds, with which to refresh performance info
		[int]$FrequencySeconds
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOPerformanceInfo
		$ItemType_str = "ssd"
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOPerformanceInfo @PSBoundParameters -ItemType $ItemType_str
	} ## end process
} ## end function


<#	.Description
	Function to get target performance information

	.Example
	Get-XIOTargetPerformance
	Request info from all current XMS connections and return objects with the target performance info

	.Example
	Get-XIOTargetPerformance X1-SC2-fc1,X1-SC2-fc2
	Get the target peformance info for targets X1-SC2-fc1 and X1-SC2-fc2

	.Example
	Get-XIOTargetPerformance X1-SC2-fc1,X1-SC2-fc2 -ComputerName somexmsappl01.dom.com -Cluster myCluster0
	Get the target peformance info for targets X1-SC2-fc1 and X1-SC2-fc2 for the objects just in the specified cluster

	.Example
	Get-XIOTargetPerformance -FrequencySeconds 5 -DurationSeconds 30
	Get target peformance info every 5 seconds for 30 seconds

	.Outputs
	XioItemInfo.TargetPerformance
#>
function Get-XIOTargetPerformance {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.TargetPerformance])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][Alias("Name")][string[]]$Name_arr,
		## Duration for which to refresh performance info, in seconds
		[int]$DurationSeconds,
		## Frequency, in seconds, with which to refresh performance info
		[int]$FrequencySeconds
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOPerformanceInfo
		$ItemType_str = "target"
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOPerformanceInfo @PSBoundParameters -ItemType $ItemType_str
	} ## end process
} ## end function


<#	.Description
	Function to get volume-folder performance information

	.Example
	Get-XIOVolumeFolderPerformance
	Request info from all current XMS connections and return objects with the volume-folder performance info

	.Example
	Get-XIOVolumeFolderPerformance /someVolFolder/someDeeperFolder
	Get the volume-folder peformance info for the given volume folder

	.Example
	Get-XIOVolumeFolderPerformance -FrequencySeconds 5 -DurationSeconds 30
	Get volume-folder peformance info every 5 seconds for 30 seconds

	.Outputs
	XioItemInfo.VolumeFolderPerformance
#>
function Get-XIOVolumeFolderPerformance {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.VolumeFolderPerformance])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][Alias("Name")][string[]]$Name_arr,
		## Duration for which to refresh performance info, in seconds
		[int]$DurationSeconds,
		## Frequency, in seconds, with which to refresh performance info
		[int]$FrequencySeconds
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOPerformanceInfo
		$ItemType_str = "volume-folder"
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOPerformanceInfo @PSBoundParameters -ItemType $ItemType_str
	} ## end process
} ## end function


<#	.Description
	Function to get volume performance information

	.Example
	Get-XIOVolumePerformance
	Request info from all current XMS connections and return objects with the volume performance info

	.Example
	Get-XIOVolumePerformance *somevols*.02[5-8]
	Get the volume peformance info for volumes with names like *somevols*.025, *somevols*.026, *somevols*.027, *somevols*.028

	.Example
	Get-XIOVolumePerformance -ComputerName somexmsappl01.dom.com -Cluster myCluster0
	Request info from all current XMS connections and return objects with the volume performance info for the objects just in the specified cluster

	.Example
	Get-XIOVolumePerformance -FrequencySeconds 5 -DurationSeconds 30
	Get volume peformance info every 5 seconds for 30 seconds

	.Outputs
	XioItemInfo.VolumePerformance
#>
function Get-XIOVolumePerformance {
	[CmdletBinding(DefaultParameterSetName="ByComputerName")]
	[OutputType([XioItemInfo.VolumePerformance])]
	param(
		## XMS address to use; if none, use default connections
		[parameter(ParameterSetName="ByComputerName")][string[]]$ComputerName,
		## Cluster name(s) for which to get info (or, get info from all XIO Clusters managed by given XMS(s) if no name specified here)
		[parameter(ParameterSetName="ByComputerName")][string[]]$Cluster,
		## Item name(s) for which to get info (or, all items of given type if no name specified here)
		[parameter(Position=0,ParameterSetName="ByComputerName")][Alias("Name")][string[]]$Name_arr,
		## Duration for which to refresh performance info, in seconds
		[int]$DurationSeconds,
		## Frequency, in seconds, with which to refresh performance info
		[int]$FrequencySeconds
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
		## the itemtype to get via Get-XIOPerformanceInfo
		$ItemType_str = "volume"
	} ## end begin

	Process {
		## call the base function to get the given item
		Get-XIOPerformanceInfo @PSBoundParameters -ItemType $ItemType_str
	} ## end process
} ## end function
#endregion  performance section #####################################################################################
