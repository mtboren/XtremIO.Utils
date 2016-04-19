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
				$strPropertiesBeingSet = ($SpecForSetItem.Trim("{}").Split("`n") | Where-Object {-not [System.String]::IsNullOrEmpty($_.Trim())} | Foreach-Object {if ($_ -match '^\s+"(proxy-)?password": ') {$_ -replace '^(\s+"(proxy-)?password":\s+)".+"', ('$1'+("*"*10))} else {$_}}) -join "`n"
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



# <#	.Description
# 	Modify an XtremIO Alert
# 	.Example
# 	Get-XIOAlert | Where-Object {$_.AlertCode -eq "0200302"} | Set-XIOAlert -Acknowledged
# 	Acknowledge this given Alert
# 	.Outputs
# 	XioItemInfo.Alert object for the modified object if successful
# #>
# function Set-XIOAlert {
# 	[CmdletBinding(SupportsShouldProcess=$true)]
# 	[OutputType([XioItemInfo.Alert])]
# 	param(
# 		## Alert object to modify
# 		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.Alert]$Alert,
# 		## Switch:  Acknowledge this alert?
# 		[parameter(Mandatory=$true)][Switch]$Acknowledged
# 	) ## end param

# 	Process {
# 		## the API-specific pieces for modifying the XIO object's properties
# 		$hshSetItemSpec = @{
# 			"alert-id" = $Alert.Index
# 			## it's not "command" or "acknowledge" or "acknowledged"; with none of these, the return message is:  "message": "Command Syntax Error: At least one property from the following list is mandatory: ['new-name','new-caption']"; have not had these succeed, yet
# 			# command = $(if ($Acknowledged) {"acknowledged"} else {"not_ack"})
# 			# state = $(if ($Acknowledged) {"acknowledged"} else {"not_ack"})
# 		}

# 		## the params to use in calling the helper function to actually modify the object
# 		$hshParamsForSetItem = @{
# 			SpecForSetItem = $hshSetItemSpec | ConvertTo-Json
# 			XIOItemInfoObj = $Alert
# 		} ## end hashtable

# 		## call the function to actually modify this item
# 		Set-XIOItemInfo @hshParamsForSetItem
# 	} ## end process
# } ## end function


<#	.Description
	Modify an XtremIO ConsistencyGroup
	.Example
	Set-XIOConsistencyGroup -ConsistencyGroup (Get-XIOConsistencyGroup myConsistencyGroup0) -Name newConsistencyGroupName0
	Rename the given ConsistencyGroup to have the new name.
	.Example
	Get-XIOConsistencyGroup -Name myConsistencyGroup0 -Cluster myCluster0 -ComputerName somexms.dom.com | Set-XIOConsistencyGroup -Name newConsistencyGroupName0
	Get the given ConsistencyGroup from the specified cluster managed by the specified XMS, and set its name to a new value.
	.Outputs
	XioItemInfo.ConsistencyGroup object for the modified object if successful
#>
function Set-XIOConsistencyGroup {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.ConsistencyGroup])]
	param(
		## ConsistencyGroup object to modify
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.ConsistencyGroup]$ConsistencyGroup,
		## New name to set for this ConsistencyGroup
		[parameter(Mandatory=$true)][string]$Name
	) ## end param

	Process {
		## the API-specific pieces for modifying the XIO object's properties
		$hshSetItemSpec = @{
			## Cluster's name or index number -- not a valid property per the error the API returns (this module should always have the "?cluster-name=<blahh>" in the URI from the source object, anyway)
			# "cluster-id" = $ConsistencyGroup.Cluster.Name
			"new-name" = $Name
			## ConsistencyGroup's current name or index number -- seems to not matter if this is passed or not
			# "cg-id" = $ConsistencyGroup.Name
		} ## end hashtable

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForSetItem = @{
			SpecForSetItem = $hshSetItemSpec | ConvertTo-Json
			XIOItemInfoObj = $ConsistencyGroup
		} ## end hashtable

		## call the function to actually modify this item
		Set-XIOItemInfo @hshParamsForSetItem
	} ## end process
} ## end function


<#	.Description
	Modify an XtremIO EmailNotifier
	.Example
	Get-XIOEmailNotifier | Set-XIOEmailNotifier -Sender myxms.dom.com -Recipient me@dom.com,someoneelse@dom.com
	Modify this given EmailNotifier, changing the Sender and Recipient list of email addresses (overwrites the recipients list with this list)
	.Example
	Get-XIOEmailNotifier | Set-XIOEmailNotifier -CompanyName MyCompany -MailRelayServer mysmtp.dom.com
	Modify this given EmailNotifier, changing the Company Name, and changing to use the given SMTP mail relay and mail relay credentials
	.Example
	Get-XIOEmailNotifier | Set-XIOEmailNotifier -ProxyServer myproxy.dom.com -ProxyServerPort 10101 -ProxyCredential (Get-Credential dom\myProxyUser) -Enable:$false
	Modify this given EmailNotifier, changing it to use the given HTTP proxy and port, and proxy user credentials, and disabling the notifier
	.Outputs
	XioItemInfo.EmailNotifier object for the modified object if successful
#>
function Set-XIOEmailNotifier {
	[CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName="Default")]
	[OutputType([XioItemInfo.EmailNotifier])]
	param(
		## EmailNotifier object to modify
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.EmailNotifier]$EmailNotifier,
		## Company Name
		[string]$CompanyName,
		## Contact details for this EmailNotifier
		[string]$ContactDetail,
		## Proxy-server name/address, if using HTTP transport
		[parameter(Mandatory=$true, ParameterSetName="UsingHttpTransport")][string]$ProxyServer,
		## Proxy-server credential, if using HTTP transport and if the proxy server requires credentials
		[parameter(ParameterSetName="UsingHttpTransport")][System.Management.Automation.PSCredential]$ProxyCredential,
		## Proxy-server port, if using HTTP transport
		[parameter(ParameterSetName="UsingHttpTransport")][int]$ProxyServerPort,
		## SMTP mail relay address, if using SMTP transport
		[parameter(Mandatory=$true, ParameterSetName="UsingSmtpTransport")][string]$MailRelayServer,
		## SMTP mail relay credential, if using SMTP transport and if the mail server requires credentials
		[parameter(ParameterSetName="UsingSmtpTransport")][System.Management.Automation.PSCredential]$MailRelayCredential,
		## List of recipient email addresses for notification emails. Overwrites current list of recipient email addresses
		[string[]]$Recipient,
		## Email address to use as "sender" address for notification emails
		[string]$Sender,
		## Switch:  Enable/disable EmailNotifier (enable via -Enable, disable via -Enable:$false)
		[Switch]$Enable
	) ## end param

	Process {
		## the API-specific pieces for modifying the XIO object's properties
		$hshSetItemSpec = @{}

		if ($PSBoundParameters.ContainsKey("CompanyName")) {$hshSetItemSpec["company-name"] = $CompanyName}
		if ($PSBoundParameters.ContainsKey("ContactDetail")) {$hshSetItemSpec["contact-details"] = $ContactDetail}
		if ($PSBoundParameters.ContainsKey("Recipient")) {$hshSetItemSpec["recipient-list"] = $Recipient}
		if ($PSBoundParameters.ContainsKey("Sender")) {$hshSetItemSpec["sender"] = $Sender}
		if ($PSBoundParameters.ContainsKey("Enable")) {
			$strEnableOrDisablePropertyToSet = if ($Enable) {"enable"} else {"disable"}
			$hshSetItemSpec[$strEnableOrDisablePropertyToSet] = $true
		} ## end if

		## set the transport value based on the parameter set (if using Proxy, "http", if using Mail server, "smtp")
		Switch ($PsCmdlet.ParameterSetName) {
			"UsingHttpTransport" {
				$hshSetItemSpec["transport"] = "http"
				if ($PSBoundParameters.ContainsKey("ProxyServer")) {$hshSetItemSpec["proxy-address"] = $ProxyServer}
				## this must be a quoted string, apparently
				if ($PSBoundParameters.ContainsKey("ProxyServerPort")) {$hshSetItemSpec["proxy-port"] = '"{0}"' -f $ProxyServerPort.ToString()}
				if ($PSBoundParameters.ContainsKey("ProxyCredential")) {$hshSetItemSpec["proxy-user"] = $ProxyCredential.UserName; $hshSetItemSpec["proxy-password"] = $ProxyCredential.GetNetworkCredential().Password}
				break
			} ## end case
			"UsingSmtpTransport" {
				$hshSetItemSpec["transport"] = "smtp"
				if ($PSBoundParameters.ContainsKey("MailRelayServer")) {$hshSetItemSpec["mail-relay-address"] = $MailRelayServer}
				if ($PSBoundParameters.ContainsKey("MailRelayCredential")) {$hshSetItemSpec["mail-user"] = $MailRelayCredential.UserName; $hshSetItemSpec["mail-password"] = $MailRelayCredential.GetNetworkCredential().Password}
			} ## end case
		} ## end switch

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForSetItem = @{
			SpecForSetItem = $hshSetItemSpec | ConvertTo-Json
			XIOItemInfoObj = $EmailNotifier
		} ## end hashtable

		## call the function to actually modify this item
		Set-XIOItemInfo @hshParamsForSetItem
	} ## end process
} ## end function


<#	.Description
	Modify an XtremIO Initiator
	.Example
	Set-XIOInitiator -Initiator (Get-XIOInitiator myInitiator0) -Name newInitiatorName0 -OperatingSystem ESX
	Rename the given Initiator to have the new name, and set its OperatingSystem property to ESX.
	.Example
	Get-XIOInitiator -Name myInitiator0 -Cluster myCluster0 -ComputerName somexms.dom.com | Set-XIOInitiator -Name newInitiatorName0 -PortAddress 10:00:00:00:00:00:00:54
	Get the given Initiator from the specified cluster managed by the specified XMS, set its name and port address to a new values.
	.Outputs
	XioItemInfo.Initiator object for the modified object if successful
#>
function Set-XIOInitiator {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.Initiator])]
	param(
		## Initiator object to modify
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.Initiator]$Initiator,
		## New name to set for this Initiator
		[String]$Name,
		## The initiator's port address.  The following rules apply:
		#-For FC initiators, any of the following formats are allowed ("X" is a hexadecimal digit – uppercase and lower case are allowed):
		#	XX:XX:XX:XX:XX:XX:XX:XX
		#	XXXXXXXXXXXXXXXX
		#	0xXXXXXXXXXXXXXXXX
		#-For iSCSI initiators, IQN and EUI formats are allowed
		#-Two initiators cannot share the same port address
		#-You cannot specify an FC address for an iSCSI target and vice-versa
		[string][ValidateScript({$_ -match "^((0x)?[0-9a-f]{16}|(([0-9a-f]{2}:){7}[0-9a-f]{2}))$"})][string]$PortAddress,
		## The operating system of the host whose HBA this Initiator involves. One of Linux, Windows, ESX, Solaris, AIX, HPUX, or Other
		[XioItemInfo.Enums.General.OSType]$OperatingSystem
	) ## end param

	Process {
		## the API-specific pieces for modifying the XIO object's properties
		$hshSetItemSpec = @{
			## Cluster's name or index number -- not a valid property per the error the API returns (this module should always have the "?cluster-name=<blahh>" in the URI from the source object, anyway)
			"cluster-id" = $Initiator.Cluster.Name
			## Initiator's current name or index number -- seems to not matter if this is passed or not
			"initiator-id" = $Initiator.Name
		} ## end hashtable

		if ($PSBoundParameters.ContainsKey("Name"))	{$hshSetItemSpec["initiator-name"] = $Name}
		if ($PSBoundParameters.ContainsKey("OperatingSystem"))	{$hshSetItemSpec["operating-system"] = $OperatingSystem.ToString().ToLower()}
		if ($PSBoundParameters.ContainsKey("PortAddress"))	{$hshSetItemSpec["port-address"] = $PortAddress}

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForSetItem = @{
			SpecForSetItem = $hshSetItemSpec | ConvertTo-Json
			## for this particular obj type, API v2 in at least XIOS v4.0.2-80 does not deal well with URI that has "?cluster-name=myclus01" in it -- API tries to use the "name=myclus01" part when determining the ID of this object; so, removing that bit from this object's URI (if there)
			Uri = _Remove-ClusterNameQStringFromURI -URI $Initiator.Uri
		} ## end hashtable

		## call the function to actually modify this item
		Set-XIOItemInfo @hshParamsForSetItem
	} ## end process
} ## end function


<#	.Description
	Modify an XtremIO InitiatorGroup
	.Example
	Set-XIOInitiatorGroup -InitiatorGroup (Get-XIOInitiatorGroup myInitiatorGroup0) -Name newInitiatorGroupName0
	Rename the given InitiatorGroup to have the new name.
	.Example
	Get-XIOInitiatorGroup -Name myInitiatorGroup0 -Cluster myCluster0 -ComputerName somexms.dom.com | Set-XIOInitiatorGroup -Name newInitiatorGroupName0
	Get the given InitiatorGroup from the specified cluster managed by the specified XMS, and set its name to a new value.
	.Outputs
	XioItemInfo.InitiatorGroup object for the modified object if successful
#>
function Set-XIOInitiatorGroup {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.InitiatorGroup])]
	param(
		## InitiatorGroup object to modify
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.InitiatorGroup]$InitiatorGroup,
		## New name to set for this InitiatorGroup
		[parameter(Mandatory=$true)][string]$Name
	) ## end param

	Process {
		## the API-specific pieces for modifying the XIO object's properties
		$hshSetItemSpec = @{
			## Cluster's name or index number -- not a valid property per the error the API returns (this module should always have the "?cluster-name=<blahh>" in the URI from the source object, anyway)
			# "cluster-id" = $InitiatorGroup.Cluster.Name
			"new-name" = $Name
			## InitiatorGroup's current name or index number -- seems to not matter if this is passed or not
			# "ig-id" = $InitiatorGroup.Name
		} ## end hashtable

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForSetItem = @{
			SpecForSetItem = $hshSetItemSpec | ConvertTo-Json
			XIOItemInfoObj = $InitiatorGroup
		} ## end hashtable

		## call the function to actually modify this item
		Set-XIOItemInfo @hshParamsForSetItem
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
	Modify an XtremIO SnapshotScheduler
	.Example
	Set-XIOSnapshotScheduler -SnapshotScheduler (Get-XIOSnapshotScheduler mySnapshotScheduler0) -Suffix someSuffix0 -SnapshotRetentionCount 20
	Set the given properties of this SnapshotScheduler:  change its Suffix value and the number of snapshots to retain
	.Example
	Get-XIOSnapshotScheduler -Name mySnapshotScheduler0 | Set-XIOSnapshotScheduler -SnapshotRetentionDuration (New-TimeSpan -Days (365*3)) -SnapshotType Regular
	Get the given SnapshotScheduler and set its snapshot retention duration to three years, and the snapshot types to "Regular" (read/write)
	.Example
	Get-XIOSnapshotScheduler -Name mySnapshotScheduler0 | Set-XIOSnapshotScheduler -Interval (New-TimeSpan -Hours 54 -Minutes 21)
	Get the given SnapshotScheduler and change the interval at which it takes snapshots to be every 54 hours and 21 minutes
	.Example
	Get-XIOSnapshotScheduler -Name mySnapshotScheduler0 | Set-XIOSnapshotScheduler -ExplicitDay Everyday -ExplicitTimeOfDay (Get-Date 2am) -RelatedObject (Get-XIOConsistencyGroup -Name myConsistencyGrp0)
	Get the given SnapshotScheduler and set its schedule to be everyday at 2am, and change the object of which to take a snapshot to be items in the given ConsistencyGroup
	.Example
	Get-XIOSnapshotScheduler -Name mySnapshotScheduler0 -Cluster myCluster0 -ComputerName somexms.dom.com | Set-XIOSnapshotScheduler -Enable:$false
	Get the given SnapshotScheduler from the specified cluster managed by the specified XMS, and disable it (see NOTES for more information on -Enable parameter)
	.Notes
	While the parameter sets of this cmdlet will allow for specifying the "-Enable" parameter along with a few other parameters, doing so will result in an error.  Due to the way the API handles the enabling/disabling of a SnapshotScheduler, the -Enable (or -Enable:$false) operation must be done with no other parameters (aside from, of course, the -SnapshotScheduler parameter that will specify the object to enable/disable).  This may change when either the API supports concurrent opertions involving enable/disable, or if the Enable-SnapshotScheduler and Disable-SnapshotScheduler cmdlets come to be (preferrably the former).
	.Outputs
	XioItemInfo.SnapshotScheduler object for the modified object if successful
#>
function Set-XIOSnapshotScheduler {
	[CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName="Default")]
	[OutputType([XioItemInfo.SnapshotScheduler])]
	param(
		## SnapshotScheduler object to modify
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.SnapshotScheduler]$SnapshotScheduler,
		## Source object of which to create snapshots with this snapshot scheduler. Can be an XIO object of type Volume, SnapshotSet, or ConsistencyGroup
		[ValidateScript({($_ -is [XioItemInfo.Volume]) -or ($_ -is [XioItemInfo.ConsistencyGroup]) -or ($_ -is [XioItemInfo.SnapshotSet])})]
		[PSObject]$RelatedObject,
		## The timespan to wait between each run of the scheduled snapshot action (maximum is 72 hours). Specify either the -Interval parameter or both of -ExplicitDay and -ExplicitTimeOfDay
		[parameter(ParameterSetName="ByTimespanInterval")][ValidateScript({$_ -le (New-TimeSpan -Hours 72)})][System.TimeSpan]$Interval,
		## The day of the week on which to take the scheduled snapshot (or, every day).  Expects the name of the day of the week, or "Everyday". Specify either the -Interval parameter or both of -ExplicitDay and -ExplicitTimeOfDay
		[parameter(Mandatory=$true,ParameterSetName="ByExplicitSchedule")]
		[ValidateSet('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Everyday')][string]$ExplicitDay,
		## The hour and minute to use for the explicit schedule, along with the explicit day of the week. Specify either the -Interval parameter or both of -ExplicitDay and -ExplicitTimeOfDay
		[parameter(Mandatory=$true,ParameterSetName="ByExplicitSchedule")][System.DateTime]$ExplicitTimeOfDay,
		## Number of Snapshots to be saved. Use either this parameter or -SnapshotRetentionDuration. With either retention Count or Duration, the oldest snapshot age to be kept is 5 years. And, the maximum count is 511 snapshots
		[parameter(ParameterSetName="SpecifySnapNum")][ValidateRange(1,511)][int]$SnapshotRetentionCount,
		## The timespan for which a Snapshot should be saved. When the defined timespan has elapsed, the XtremIO cluster automatically removes the Snapshot.  Use either this parameter or -SnapshotRetentionCount
		##   The minimum value is 1 minute, and the maximum value is 5 years
		[parameter(ParameterSetName="SpecifySnapAge")]
		[ValidateScript({($_ -ge (New-TimeSpan -Minutes 1)) -and ($_ -le (New-TimeSpan -Days (5*365)))})][System.TimeSpan]$SnapshotRetentionDuration,
		## Switch:  Snapshot Scheduler enabled-state. To enable the SnapshotScheduler, use -Enable.  To disable, use -Enable:$false. When enabling/disabling, one can apparently not make other changes, as the API uses a different method in the backend on the XMS ("resume_scheduler" and "suspend_scheduler" instead of "modify_scheduler").  See Notes section below for further information
		[parameter(ParameterSetName="EnableDisable")][Switch]$Enable,
		## Type of snapshot to create:  "Regular" (readable/writable) or "ReadOnly"
		[ValidateSet("Regular","ReadOnly")][string]$SnapshotType = "Regular",
		## String to injected into the resulting snapshot's name. For example, a value of "mySuffix" will result in a snapshot named something like "<baseVolumeName>.mySuffix.<someTimestamp>"
		[string]$Suffix
	) ## end param

	Process {
		## the API-specific pieces for modifying the XIO object's properties
		$hshSetItemSpec = @{
			## excluding Cluster's name or index number -- SnapshotScheduler objects do not have the property, as the API does not provide the "sys-id" property from which to get the info
			# "cluster-id" = $SnapshotScheduler.Cluster.Name
			## SnapshotScheduler's current name or index number; using index (which is rare), but due to the fact that SnapshotSchedulers are made via API with an empty name (no means by which to set name via API), index is actually preferrable in this rare case
			"scheduler-id" = $SnapshotScheduler.Index
		} ## end hashtable

		## set the scheduler type and schedule (time) string, based on the ParameterSetName
		#    time is either (Hours:Minutes:Seconds) for interval or (NumberOfDayOfTheWeek:Hour:Minute) for explicit
		Switch($PsCmdlet.ParameterSetName) {
			"ByTimespanInterval" {
				$hshSetItemSpec["scheduler-type"] = "interval"
				## (Hours:Minutes:Seconds)
				$hshSetItemSpec["time"] = $("{0}:{1}:{2}" -f [System.Math]::Floor($Interval.TotalHours), $Interval.Minutes, $Interval.Seconds)
				break
			} ## end case
			"ByExplicitSchedule" {
				$hshSetItemSpec["scheduler-type"] = "explicit"
				## (NumberOfDayOfTheWeek:Hour:Minute), with 0-7 for NumberOfDayOfTheWeek, and 0 meaning "everyday"
				$intNumberOfDayOfTheWeek = if ($ExplicitDay -eq "Everyday") {0}
					## else, get the value__ for this name in the DayOfWeek enum, and add one (DayOfWeek is zero-based index, this XIO construct is 1-based for day names, with "0" being used as "everyday")
					else {([System.Enum]::GetValues([System.DayOfWeek]) | Where-Object {$_.ToString() -eq $ExplicitDay}).value__ + 1}
				$hshSetItemSpec["time"] = $("{0}:{1}:{2}" -f $intNumberOfDayOfTheWeek, $ExplicitTimeOfDay.Hour, $ExplicitTimeOfDay.Minute)
				break
			} ## end case
			"SpecifySnapNum" {
				$hshSetItemSpec["snapshots-to-keep-number"] = $SnapshotRetentionCount
				break
			}
			"SpecifySnapAge" {
				$hshSetItemSpec["snapshots-to-keep-time"] = [System.Math]::Floor($SnapshotRetentionDuration.TotalMinutes)
			}
		} ## end switch

		if ($PSBoundParameters.ContainsKey("RelatedObject")) {
			## type of snapsource:  Volume, SnapshotSet, ConsistencyGroup
			$strSnapshotSourceObjectTypeAPIValue = Switch ($RelatedObject.GetType().FullName) {
				"XioItemInfo.Volume" {"Volume"; break}
				## API requires "SnapSet" string for this
				"XioItemInfo.SnapshotSet" {"SnapSet"; break}
				## not yet supported by API per API error (even though API reference says "Tag List", too)
				# "XioItemInfo.Tag" {"Tag"; break}
				"XioItemInfo.ConsistencyGroup" {"ConsistencyGroup"}
			} ## end switch

			## name of snaphot source; need to be single item array if taglist?; could use index, too, it seems, but why would we?
			$hshSetItemSpec["snapshot-object-id"] = $RelatedObject.Name
			$hshSetItemSpec["snapshot-object-type"] = $strSnapshotSourceObjectTypeAPIValue
		}
		if ($PSBoundParameters.ContainsKey("Enable")) {$hshSetItemSpec["state"] = $(if ($Enable) {'enabled'} else {'user_disabled'})}
		if ($PSBoundParameters.ContainsKey("SnapshotType")) {$hshSetItemSpec["snapshot-type"] = $SnapshotType.ToLower()}
		if ($PSBoundParameters.ContainsKey("Suffix")) {$hshSetItemSpec["suffix"] = $Suffix}

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForSetItem = @{
			SpecForSetItem = $hshSetItemSpec | ConvertTo-Json
			## for this particular obj type, API v2 in at least XIOS v4.0.2-80 does not deal well with URI that has "?cluster-name=myclus01" in it -- API tries to use the "name=myclus01" part when determining the ID of this object; so, removing that bit from this object's URI (if there)
			Uri = _Remove-ClusterNameQStringFromURI -URI $SnapshotScheduler.Uri
		} ## end hashtable

		## call the function to actually modify this item
		Set-XIOItemInfo @hshParamsForSetItem
	} ## end process
} ## end function


<#	.Description
	Modify an XtremIO SnapshotSet
	.Example
	Set-XIOSnapshotSet -SnapshotSet (Get-XIOSnapshotSet mySnapshotSet0) -Name newSnapsetName0
	Rename the given SnapshotSet to have the new name.
	.Example
	Get-XIOSnapshotSet -Name mySnapshotSet0 -Cluster myCluster0 -ComputerName somexms.dom.com | Set-XIOSnapshotSet -Name newSnapsetName0
	Get the given SnapshotSet from the specified cluster managed by the specified XMS, and set its name to a new value.
	.Outputs
	XioItemInfo.SnapshotSet object for the modified object if successful
#>
function Set-XIOSnapshotSet {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.SnapshotSet])]
	param(
		## SnapshotSet object to modify
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.SnapshotSet]$SnapshotSet,
		## New name to set for this SnapshotSet
		[parameter(Mandatory=$true)][string]$Name
	) ## end param

	Process {
		## the API-specific pieces for modifying the XIO object's properties
		$hshSetItemSpec = @{
			## Cluster's name or index number -- not a valid property per the error the API returns (this module should always have the "?cluster-name=<blahh>" in the URI from the source object, anyway)
			# "cluster-id" = $SnapshotSet.Cluster.Name
			"new-name" = $Name
			## SnapshotSet's current name or index number -- not a valid property per the error the API returns
			# "snapshot-set-id" = $SnapshotSet.Name
		} ## end hashtable

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForSetItem = @{
			SpecForSetItem = $hshSetItemSpec | ConvertTo-Json
			XIOItemInfoObj = $SnapshotSet
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
	Modify an XtremIO Target
	.Example
	Set-XIOTarget -Target (Get-XIOTarget X1-SC2-iscsi1) -MTU 9000
	Set the given Target to have 9000 as its MTU value
	.Example
	Get-XIOTarget -Name X1-SC2-iscsi1 -Cluster myCluster0 -ComputerName somexms.dom.com | Set-XIOTarget -MTU 1500
	Get the given Target from the specified cluster managed by the specified XMS, and set its MTU value back to 1500 (effectively "disabling" jumbo frames for it).
	.Outputs
	XioItemInfo.Target object for the modified object if successful
#>
function Set-XIOTarget {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([XioItemInfo.Target])]
	param(
		## Target object to modify
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.Target]$Target,
		## MTU value to set for this Target
		[parameter(Mandatory=$true)][ValidateRange(1500,9KB)]$MTU
	) ## end param

	Process {
		## the API-specific pieces for modifying the XIO object's properties
		$hshSetItemSpec = @{
			## Cluster's name or index number
			"cluster-id" = $Target.Cluster.Name
			mtu = $MTU
			## Target's current name or index number -- does it matter if this is passed or not?
			"tar-id" = $Target.Name
		} ## end hashtable

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForSetItem = @{
			SpecForSetItem = $hshSetItemSpec | ConvertTo-Json
			## for this particular obj type, API v2 in at least XIOS v4.0.2-80 does not deal well with URI that has "?cluster-name=myclus01" in it -- API tries to use the "name=myclus01" part when determining the ID of this object; so, removing that bit from this object's URI (if there)
			Uri = _Remove-ClusterNameQStringFromURI -URI $Target.Uri
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
	Modify an XtremIO Volume
	.Example
	Set-XIOVolume -Volume (Get-XIOVolume myVolume) -Name myVolume_renamed
	Set a new Name for the given Volume from the existing object itself
	.Example
	Get-XIOVolume myVolume | Set-XIOVolume -Name myVolume_renamed
	Set a new Name for the given Volume from the existing object itself (via pipeline)
	.Example
	Get-XIOVolume myVolume0 | Set-XIOVolume -SizeTB 10 -AccessRightLevel Read_Access -SmallIOAlertEnabled:$false -VaaiTPAlertEnabled
	Set the size and access level for the volume, disable small IO alerts, and enable VAAI thin provisioning alerts
	.Outputs
	XioItemInfo.Volume object for the modified object if successful
#>
function Set-XIOVolume {
	[CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName="Default")]
	[OutputType([XioItemInfo.Volume])]
	param(
		## Volume object to modify
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][XioItemInfo.Volume]$Volume,
		## New Name to set for the volume
		[string]$Name,
		## New, larger size in MB for the volume (decreasing volume size is not supported, at least not via the API). Maximum volume size is 2PB (2,147,483,648 MB)
		[parameter(ParameterSetName="SizeByMB")][ValidateRange(1, ([int32]::MaxValue + 1))][Int64]$SizeMB,
		## New, larger size in GB for the volume (decreasing volume size is not supported, at least not via the API). Maximum volume size is 2PB (2,097,152 GB)
		[parameter(ParameterSetName="SizeByGB")][ValidateRange(1, ([int32]::MaxValue + 1)/1KB)][Int]$SizeGB,
		## New, larger size in TB for the volume (decreasing volume size is not supported, at least not via the API). Maximum volume size is 2PB (2,048 TB)
		[parameter(ParameterSetName="SizeByTB")][ValidateRange(1, 2048)][Int]$SizeTB,
		## Switch:  Enable or disable small input/output alerts. To disable, use: -UnalignedIOAlertEnabled:$false
		[Switch]$SmallIOAlertEnabled,
		## Switch:  Enable or disable unaligned input/output alerts. To disable, use: -UnalignedIOAlertEnabled:$false
		[Switch]$UnalignedIOAlertEnabled,
		## Switch:  Enable or disable VAAI thin-provisioning alerts. To disable, use: -VaaiTPAlertEnabled:$false
		[Switch]$VaaiTPAlertEnabled,
		## Set the access level of the volume.  Volumes can have one of the following access right levels:
		#	- No_Access:  All SCSI commands for accessing data on the Volume (read commands and write commands) fail, and all SCSI discovery commands (i.e. inquiries on Volume characteristics and not accessing the data on the Volume) succeed.
		#	- Read_Access:  All SCSI write commands fail and all SCSI read commands and discovery commands succeed.
		#	- Write_Access:  All commands succeed and the host can write to the Volume.
		## One of "No_Access", "Read_Access", "Write_Access"
		[ValidateSet("No_Access", "Read_Access", "Write_Access")][string]$AccessRightLevel
	) ## end param

	Process {
		## the API-specific pieces for modifying the XIO object's properties
		$hshSetItemSpec = @{
			## Cluster's name or index number
			"cluster-id" = $Volume.Cluster.Name
			## Volume's current name or index number -- does it matter if this is passed or not?
			"vol-id" = $Volume.Name
		} ## end hashtable

		if ($PSBoundParameters.ContainsKey("Name")) {$hshSetItemSpec["vol-name"] = $Name}
		## if the size is being set
		if ("SizeByMB", "SizeByGB", "SizeByTB" -contains $PSCmdlet.ParameterSetName) {
			$strSizeWithUnitLabel = Switch ($PSCmdlet.ParameterSetName) {
				"SizeByMB" {"${SizeMB}M"}
				"SizeByGB" {"${SizeGB}G"}
				"SizeByTB" {"${SizeTB}T"}
			}
			$hshSetItemSpec["vol-size"] = $strSizeWithUnitLabel
		}
		if ($PSBoundParameters.ContainsKey("SmallIOAlertEnabled")) {$hshSetItemSpec["small-io-alerts"] = $(if ($SmallIOAlertEnabled) {"enabled"} else {"disabled"})}
		if ($PSBoundParameters.ContainsKey("UnalignedIOAlertEnabled")) {$hshSetItemSpec["unaligned-io-alerts"] = $(if ($UnalignedIOAlertEnabled) {"enabled"} else {"disabled"})}
		if ($PSBoundParameters.ContainsKey("VaaiTPAlertEnabled")) {$hshSetItemSpec["vaai-tp-alerts"] = $(if ($VaaiTPAlertEnabled) {"enabled"} else {"disabled"})}
		if ($PSBoundParameters.ContainsKey("AccessRightLevel")) {$hshSetItemSpec["vol-access"] = $AccessRightLevel.ToLower()}

		## the params to use in calling the helper function to actually modify the object
		$hshParamsForSetItem = @{
			SpecForSetItem = $hshSetItemSpec | ConvertTo-Json
			Uri = _Remove-ClusterNameQStringFromURI -URI $Volume.Uri
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
