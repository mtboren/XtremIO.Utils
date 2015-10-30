<#	.Description
	Wrapper for using REST API with XtremIO / XMS appliance; Mar 2014, Matt Boren
	Intended to be used by other code for getting the raw info, with the other code having the task of returning pretty/useful objects
	.Example
	Get-XIOInfo -Credential $credMyCreds -RestCommand_str /types/clusters/?name=myxioclustername01).Content | select Name,@{n="SSDSpaceTB"; e={[Math]::Round($_."ud-ssd-space" / 1GB, 2)}},@{n="SSDSpaceInUseTB"; e={[Math]::Round($_."ud-ssd-space-in-use" / 1GB, 2)}},@{n="DedupeRatio"; e={[Math]::Round(1/$_."dedup-ratio", 1)}}, @{n="ThinProvSavings"; e={[Math]::Round((1-$_."thin-provisioning-ratio") * 100, 0)}}
#>
function Get-XIOInfo {
	[CmdletBinding()]
	param(
		## credential for connecting to XMS appliance
		[System.Management.Automation.PSCredential]$Credential = $(Get-Credential),
		## authentication type; default is "basic"; to be expanded upon in the future?
		[ValidateSet("basic")][string]$AuthType_str = "basic",
		## XMS appliance address (FQDN) to which to connect
		[parameter(Mandatory=$true,Position=0,ParameterSetName="SpecifyUriComponents")][string]$ComputerName_str,
		## Port on which REST API is available
		[parameter(ParameterSetName="SpecifyUriComponents")][int]$Port_int,
		## REST command to issue; like, "/types/clusters" or "/types/initiators", for example
		[parameter(ParameterSetName="SpecifyUriComponents")][ValidateScript({$_.StartsWith("/")})][string]$RestCommand_str = "/types",
		## full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Position=0,ParameterSetName="SpecifyFullUri",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
		[ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][alias("href")][string]$URI_str,
		## switch: trust all certs?  Not necessarily secure, but can be used if the XMS appliance is known/trusted, and has, say, a self-signed cert
		[switch]$TrustAllCert_sw
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
	} ## end begin

	Process {
		## the params to use for the API invocation
		$hshParamsForRequest = @{
			Uri =
				if ($PSCmdlet.ParameterSetName -eq "SpecifyUriComponents") {
					$hshParamsForNewXioApiURI = @{ComputerName_str = $ComputerName_str; RestCommand_str = $RestCommand_str}
					if ($PSBoundParameters.ContainsKey("Port_int")) {$hshParamsForNewXioApiURI["Port_int"] = $Port_int}
					New-XioApiURI @hshParamsForNewXioApiURI
				} ## end if
				else {$URI_str}
			Method = "Get"
		} ## end hsh

		## add header if using Basic auth
		if ($AuthType_str -eq "basic") {
			$hshHeaders = @{Authorization = (Get-BasicAuthStringFromCredential -Credential $Credential)}
			$hshParamsForRequest['Headers'] = $hshHeaders
		} ## end if

		## if specified to do so, set session's CertificatePolicy to trust all certs (for now; will revert to original CertificatePolicy)
		if ($true -eq $TrustAllCert_sw) {Write-Verbose "$strLogEntry_ToAdd setting ServerCertificateValidationCallback method temporarily so as to 'trust' certs (should only be used if certs are known-good / trustworthy)"; $oOrigServerCertValidationCallback = Disable-CertValidation}
		try {
			#Invoke-RestMethod @hshParamsForRequest -ErrorAction:stop
			## issues with Invoke-RestMethod:  even after disabling cert validation, issue sending properly formed request; at the same time, using the WebClient object succeeds; furthermore, after a successful call to DownloadString() with the WebClient object, the Invoke-RestMethod succeeds.  What the world?  Something to investigate further
			#   so, working around that for now by using the WebClient class; Invoke-RestMethod will be far more handy, esp. when it's time for modification of XtremIO objects
			$oWebClient = New-Object System.Net.WebClient; $oWebClient.Headers.Add("Authorization", $hshParamsForRequest["Headers"]["Authorization"])
			$oWebClient.DownloadString($hshParamsForRequest["Uri"]) | ConvertFrom-Json
		} ## end try
		catch {
			Write-Verbose -Verbose "Uh-oh -- something went awry trying to get data from that URI ('$($hshParamsForRequest['Uri'])'). A pair of guesses:  no such XMS appliance, or that item type is not valid in the API version on the XMS appliance that you are contacting, maybe?  Should handle this in future module release.  Throwing error for now."
			## throw the caught error (instead of breaking, which adversely affects subsequent calls; say, if in a try/catch statement in a Foreach-Object loop, "break" breaks all the way out of the foreach-object, vs. using Throw to just throw the error for this attempt, and then letting the calling item continue in the Foreach-Object
			Throw
			#Write-Error $_ -Category ConnectionError -RecommendedAction "Check creds, URL ('$($hshParamsForRequest["Uri"])') -- valid?"; break;
		} ## end catch
		## if CertValidationCallback was altered, set back to original value
		if ($true -eq $TrustAllCert_sw) {
			[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $oOrigServerCertValidationCallback
			Write-Verbose "$strLogEntry_ToAdd set ServerCertificateValidationCallback back to original value of '$oOrigServerCertValidationCallback'"
		} ## end if
	} ## end process
} ## end function


function New-XioApiURI {
	<#	.Description
		Function to create the URI to be used for web calls to XtremIO API, based on computer name, and, if no port specified, the default port that is responding
		.Outputs
		String URI to use for the API call, built according to which version of XMS is deduced by determining
	#>
	param (
		## the name of the target machine to be used in URI (and, machine which to check if it is listening on given port)
		[parameter(Mandatory=$true)][string]$ComputerName_str,
		## port to use (if none specified, try defaults)
		[int]$Port_int,
		## REST command to use for URI
		[parameter(Mandatory=$true)][string]$RestCommand_str,
		## Switch:  return array output of URI,Port, instead of just URI?
		[switch]$ReturnURIAndPortInfo,
		## Switch:  test comms to the given port?  Likely only used at Connect- time (after which, somewhat safe assumption that the given port is legit)
		[switch]$TestPort
	) ##end param

	## string to add to messages written by this function; function name in square brackets
	$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"

	$intPortToUse = $(
		## if a port was specified, try to use it
		$intPortToTry = if ($PSBoundParameters.ContainsKey("Port_int")) {$Port_int} else {$hshCfg["DefaultApiPort"]["intSSL"]}
		if ($TestPort -eq $true) {
			if (dTest-Port -Name $ComputerName_str -Port $intPortToTry -Verbose) {$intPortToTry}
			else {Throw "machine '$ComputerName_str' not responding on port '$intPortToTry'. Valid port that is listening? Not continuing"}
		} ## end if
		else {$intPortToTry}
	) ## end subexpression
	$strURIToUse = if ($intPortToUse -eq 443) {"https://${ComputerName_str}/api/json$RestCommand_str"}
		else {"http://${ComputerName_str}:$intPortToUse$RestCommand_str"}
	Write-Verbose "$strLogEntry_ToAdd URI to use: '$strURIToUse'"
	if ($false -eq $ReturnURIAndPortInfo) {return $strURIToUse} else {return @($strURIToUse,$intPortToUse)}
} ## end function


function Get-BasicAuthStringFromCredential {
	<#	.Description
		Function to get a Basic authorization string value from a PSCredential.  Useful for creating the value for an Authorization header item for a web request, for example.  Based on code from Don Jones at http://powershell.org/wp/forums/topic/http-basic-auth-request/
		.Outputs
		String
	#>
	param(
		[parameter(Mandatory=$true)][System.Management.Automation.PSCredential]$Credential
	) ## end param

	return "Basic $( [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$($Credential.UserName.TrimStart('\')):$($Credential.GetNetworkCredential().Password)")) )"
} ## end function


function dTest-Port {
	[CmdletBinding()]
	<#	.Description
		Function to check if given port is responding on given machine.  Based on post by Aleksandar at http://powershell.com/cs/forums/p/2993/4034.aspx#4034
	#>
	param(
		[string]$nameOrAddr_str,
		[int]$port_int,
		## milliseconds to wait for connection
		[int]$WaitMilliseconds_int = 2000
	) ## end param

	## string to add to messages written by this function; function name in square brackets
	$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"

	## ref:  http://msdn.microsoft.com/en-us/library/system.net.sockets.tcpclient.aspx
	$oTcpClient = New-Object Net.Sockets.TcpClient
	## old way, synchronous
	#$oTcpClient.Connect($nameOrAddr_str, $port_int)
	## ref:  http://msdn.microsoft.com/en-us/library/xw3y33he.aspx
	$oIAsyncResult = $oTcpClient.BeginConnect($nameOrAddr_str, $port_int, $null, $null)
	## ref:  http://msdn.microsoft.com/en-us/library/kzy257t0.aspx
	$bConnectSucceeded = $oIAsyncResult.AsyncWaitHandle.WaitOne($WaitMilliseconds_int, $false)
	$oTcpClient.Close(); $oTcpClient = $null
	if (-not $bConnectSucceeded) {Write-Verbose "$strLogEntry_ToAdd No connection on port '$port_int' before timeout of '$WaitMilliseconds_int' ms"}
	return $bConnectSucceeded
} ## end fn


function Disable-CertValidation {
	<#	.Description
		function to set CertificatePolicy in current session to a custom, "TrustAllCerts" kind of policy; intended to be used as workaround for web calls to endpoints with self-signed certs
		.Outputs
		CertificatePolicy that was originally set before changing to TrustAllCert type of policy (if changed, and for later use in setting the policy back), or $null if CertificatePolicy was not changed
	#>
	$oOrigServerCertificateValidationCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
	return $oOrigServerCertificateValidationCallback
}


### replaced w/ Disable-CertValidation
##function Set-TrustAllCertPolicy {
##	<#	.Description
##		function to set CertificatePolicy in current session to a custom, "TrustAllCerts" kind of policy; intended to be used as workaround for web calls to endpoints with self-signed certs
##		.Outputs
##		CertificatePolicy that was originally set before changing to TrustAllCert type of policy (if changed, and for later use in setting the policy back), or $null if CertificatePolicy was not changed
##	#>
##	## the name of the custom CertificatePolicy
##	$strCustCertPolicyName = "XioUtils_TrustAllCertsPolicy"
##	## if this type is not already present in the current PowerShell session, add it
##	if (-not ($strCustCertPolicyName -as [type])) {
##		Add-Type -TypeDefinition @"
##			using System.Net; using System.Security.Cryptography.X509Certificates;
##			public class $strCustCertPolicyName : ICertificatePolicy {
##				public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) { return true; }
##			}
##"@
##		Write-Verbose "adding CertificatePolicy '$strCustCertPolicyName' type to current PowerShell session"
##	} ## end if
##	## if not already a TrustAllCerts policy, set it
##	if ([System.Net.ServicePointManager]::CertificatePolicy -isnot [type]$strCustCertPolicyName) {
##		## get the original (current) CertificatePolicy for this session
##		$oCertPolicy_orig = [System.Net.ServicePointManager]::CertificatePolicy
##		## set the CertificatePolicy to the TrustAllCerts policy
##		[System.Net.ServicePointManager]::CertificatePolicy = New-Object -TypeName $strCustCertPolicyName
##		Write-Verbose "set CertificatePolicy for this session: '$([System.Net.ServicePointManager]::CertificatePolicy)'"
##		## return the orig cert policy, for when someone wants to revert to said policy
##		return $oCertPolicy_orig
##	} ## end if
##	## else, just write some verbosity, and return $null
##	else {Write-Verbose "CertificatePolicy was already '$strCustCertPolicyName'; not setting it again"; return $null}
##} ## end fn


## credentials-handling functions; cleaned up a bit, but based entirely on Hal Rottenberg's http://halr9000.com/article/tag/lib-authentication.ps1
function hExport-PSCredential {
	param ([parameter(Mandatory=$true)][System.Management.Automation.PSCredential]$Credential, [parameter(Mandatory=$true)][string]$Path)
	# Create temporary object to be serialized to disk
	$export = New-Object -Type PSObject -Property @{Username = $null; EncryptedPassword = $null}

	# Give object a type name which can be identified later
	$export.PSObject.TypeNames.Insert(0,'ExportedPSCredential')

	$export.Username = $Credential.Username

	# Encrypt SecureString password using Data Protection API
	# Only the current user account can decrypt this cipher
	$export.EncryptedPassword = $Credential.Password | ConvertFrom-SecureString

	# Export using the Export-Clixml cmdlet
	$export | Export-Clixml $Path
	Write-Verbose -Verbose "Credentials encrypted (via Windows Data Protection API) and saved to: '$Path'"
} ## end function

function hImport-PSCredential {
	param ([parameter(Mandatory=$true)][ValidateScript({Test-Path $_})][string]$Path)
	# Import credential file
	$import = Import-Clixml $Path
	# Test for valid import
	if ( !$import.UserName -or !$import.EncryptedPassword ) {Throw "Input is not a valid ExportedPSCredential object, taking no action."}

	# Decrypt the password and store as a SecureString object for safekeeping
	$SecurePass = $import.EncryptedPassword | ConvertTo-SecureString

	# return new credential object
	return (New-Object System.Management.Automation.PSCredential $import.Username, $SecurePass)
} ## end function


<#	.Description
	Helper function for finding credentials to use (either a stored one, or will prompt user to enter one)
	To be used as default value for a Credential parameter to a function, to try to get stored Xio cred, or prompt for new
#>
function _Find-CredentialToUse {
	$credTmp = Get-XIOStoredCred
	## just prompt for creds; this way makes the user create a newXIOStoredCred on there own, and only leverages it if it already exists
	if ($credTmp -is [System.Management.Automation.PSCredential]) {return $credTmp} else {Get-Credential}
	## auto-make a storedCred if one doesn't exist, and return it (prompts user to make a credential)
	#if ($credTmp -is [System.Management.Automation.PSCredential]) {return $credTmp} else {New-XIOStoredCred -PassThru}
} ## end function


function _Test-TypeOrString {
	<# .Description
		Helper function to test if object is either of type String or $Type
		.Outputs
		Boolean -- $true if objects are all either String or the given $Type; $false otherwise
	#>
	param (
		## Object to test
		[parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][PSObject[]]$ObjectToTest,
		## Type of object for which to check
		[parameter(Mandatory=$true)][Type]$Type
	) ## end param

	process {
		## make sure that all values are either a String or a Cluster obj
		$arrCheckBoolValues = $ObjectToTest | Foreach-Object {($_ -is [System.String]) -or ($_ -is $Type)}
		return (($arrCheckBoolValues -contains $true) -and ($arrCheckBoolValues -notcontains $false))
	} ## end process
} ## end function


<#	.Description
	Set PowerShell title bar to reflect currently connected XMS servers' names
#>
function Update-TitleBarForXioConnection {
	$strOrigWindowTitle = $host.ui.RawUI.WindowTitle
	## the window titlebar text without the "connected to.." XMS info
	$strWinTitleWithoutOldXmsConnInfo = $strOrigWindowTitle -replace "(; )?Connected to( \d+)? XMS.+", ""
	## the number of XMS servers to which still connected
	$intNumConnectedXmsServers = ($Global:DefaultXmsServers | Measure-Object).Count
	$strNewWindowTitle = "{0}{1}{2}" -f $strWinTitleWithoutOldXmsConnInfo, $(if ((-not [System.String]::IsNullOrEmpty($strWinTitleWithoutOldXmsConnInfo)) -and ($intNumConnectedXmsServers -gt 0)) {"; "}), $(
		if ($intNumConnectedXmsServers -gt 0) {
			if ($intNumConnectedXmsServers -eq 1) {"Connected to XMS {0} as {1}" -f $Global:DefaultXmsServers[0].ComputerName, $Global:DefaultXmsServers[0].Credential.UserName}
			else {"Connected to {0} XMS servers:  {1}." -f $intNumConnectedXmsServers, (($Global:DefaultXmsServers | %{$_.ComputerName}) -Join ", ")}
		} ## end if
		#else {"Not Connected to XMS"}
	) ## end -f call
	$host.ui.RawUI.WindowTitle = $strNewWindowTitle
} ## end fn


<#	.Description
	Helper function to get the XIO connections to use for given command
#>
function Get-XioConnectionsToUse {
	param(
		## Computer names to check for in default XMS servers list (if any; if $null, will use all)
		[string[]]$ComputerName_arr
	)

	## string to add to messages written by this function; function name in square brackets
	$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"

	## if connected to any XIO servers
	if (($Global:DefaultXmsServers | Measure-Object).Count -gt 0) {
		## array of XIO connection names to potentially use
		$arrConnectionNamesToUse = $ComputerName_arr

		## get the XIO connections to use, per the params passed and by matching up with XIO names in current connections
		$arrXioConnectionsToUse =
			## if there are some connection names specified, see if there are actual connections like those names
			if ($null -ne $arrConnectionNamesToUse) {
				$arrConnectionNamesToUse | Foreach-Object {
					$strThisConnectionName = $_
					$oXioConnectionWithNameLikeThisConnectionName = $Global:DefaultXmsServers | Where-Object {$_.ComputerName -like $strThisConnectionName}
					## if there was a matching connection, return it
					if ($null -ne $oXioConnectionWithNameLikeThisConnectionName) {$oXioConnectionWithNameLikeThisConnectionName}
					else {Write-Verbose "$strLogEntry_ToAdd no connection to '$strThisConnectionName', not using"}
				} ## end foreach-object
			} ## end if
			## else, use all connections
			else {$Global:DefaultXmsServers}
	} ## end if
	else {Write-Warning "no XIO connections; connect first, and then try something"; break}

	$intNumConnectionsToUse = ($arrXioConnectionsToUse | Measure-Object).Count
	if ($null -ne $arrXioConnectionsToUse) { Write-Verbose ("$strLogEntry_ToAdd continuing with call, using '{0}' XIO connection{1}" -f $intNumConnectionsToUse, $(if ($intNumConnectionsToUse -ne 1) {"s"})); return $arrXioConnectionsToUse}
	else {Write-Warning ("not connected to specified computer{0}; check name{0} and try again" -f $(if (($arrConnectionNamesToUse | Measure-Object).Count -ne 1) {"s"})); break}
} ## end function


<#	.Description
	Helper function to get the XIO item type (which is plural) by parsing the URI; string manipulation, so not super best, but...
	.Outputs
	String (that is the plural form of the given word)
#>
function Get-ItemTypeFromURI {
	param(
		## Full URI to use for the REST call, instead of specifying components from which to construct the URI
		[parameter(Mandatory=$true)][ValidateScript({[System.Uri]::IsWellFormedUriString($_, "Absolute")})][string]$URI_str
	) ## end param
	$strItemType_plural = ([RegEx]("^(/api/json)?/types/(?<itemType>[^/]+)/")).Match(([System.Uri]($URI_str)).AbsolutePath).Groups.Item("itemType").Value
	Write-Debug "Item type grabbed from URI: '$strItemType_plural'"
	## get the plural item type from the URI (the part of the URI after "/types/")
	return $strItemType_plural
} ## end function


function Convert-UrlEncoding {
	<#	.Description
		Function to convert between regular strings and URL encoded strings (encode/decode)
		.Example
		Convert-UrlEncoding "mehh 1","some other, shiz"
		OriginalString     ConvertedString      Action
		--------------     ---------------      ------
		mehh 1             mehh+1               encoded
		some other, shiz   some+other%2c+shiz   encoded
		UrlEncode the given strings
		.Outputs
		PSCustomObject with the original string, the converted string, and the encoding type used if converting to encoded string
	#>
	[CmdletBinding(DefaultParameterSetName="Default")]
	param (
		## string(s) to either encode or decode
		[parameter(Mandatory=$true,Position=0)][string[]]$StringToConvert_arr,
		## switch:  decode the string passed in (assume that the string is URL encoded); default action is to encode
		[switch]$Decode_sw = $false
	) ## end param

	process {
		if (-not ("System.Web.HttpUtility" -as [type])) {Add-Type -AssemblyName System.Web}
		$StringToConvert_arr | %{
			$strThisStringToConvert = $_
			$strActionTaken,$strThisConvertedString = if ($Decode_sw -eq $true) {"decoded"; [System.Web.HttpUtility]::UrlDecode($strThisStringToConvert)}
				else {"encoded"; [System.Web.HttpUtility]::UrlEncode($strThisStringToConvert)}
			New-Object -Type PSObject -Property @{
				OriginalString = $strThisStringToConvert
				ConvertedString = $strThisConvertedString
				Action = $strActionTaken
			} ## end new-object
		} ## end foreach-object
	} ## end process
} ## end function


function dWrite-ObjectToTableString {
<#	.Description
	brief function to write an object (like, say, a hashtable) out to a log-friendly string, trimming the whitespace off of the end of each line
#>
	param ([parameter(Mandatory=$true)][PSObject]$ObjectToStringify)
	$strToReturn = ( ($ObjectToStringify | Format-Table -AutoSize | Out-String -Stream | Foreach-Object {$_.Trim()} | Where-Object {-not [System.String]::IsNullOrEmpty($_)}) ).Trim() -join "`n"
	return "`n${strToReturn}`n"
} ## end function


function _Test-XIOObjectIsInThisXIOSVersion {
<#	.Description
	function to determine if this API Item type is present in the given XIOS version, based on a config table of values -> XIOSVersion
	.Outputs
	Boolean
#>
	param(
		## API item type (like volumes, xms, ssds, etc.)
		[parameter(Mandatory=$true)][string]$ApiItemType,
		## XIOS version to check
		[AllowNull()][System.Version]$XiosVersion
	) ## end param
	process {
		## if XiosVersion was $null, which is the case with older XIOConnection objects, as their XmsVersion property is not populated, as the XMS type from which to get such info is not available until XIOS v4
		if ($null -eq $XiosVersion) {$XiosVersion = [System.Version]"3.0"}
		## get, from the given global config item, all of the API item types that are available for this API version
		$arrItemTypeNamesAvailableInThisRestXiosVersion = $hshCfg["ItemTypeInfoPerXiosVersion"].Keys | Where-Object {$XiosVersion -ge [System.Version]$_} | Foreach-Object {$hshCfg["ItemTypeInfoPerXiosVersion"][$_]} | Foreach-Object {$_}
		## does the resulting array of API item types contain this API item type?
		$arrItemTypeNamesAvailableInThisRestXiosVersion -contains $ApiItemType
	} ## end process
} ## end function


<#	.Description
	function to make an ordered dictionary of properties to return, based on the item type being retrieved; Apr 2014, Matt Boren
	All item types (including some that are only on XMS v2.2.3 rel 25):  "target-groups", "lun-maps", "storage-controllers", "bricks", "snapshots", "iscsi-portals", "xenvs", "iscsi-routes", "initiator-groups", "volumes", "clusters", "initiators", "ssds", "targets"
		The ones that are new as of XMS v2.2.3 rel 25:  bricks, snapshots, ssds, storage-controllers, xenvs
	to still add here:  "iscsi-portals", "iscsi-routes"
	.Outputs
	PSCustomObject with info about given XtremIO input item type
#>
function _New-Object_fromItemTypeAndContent {
	param (
		## the XIOS API item type; "initiator-groups", for example
		[parameter(Mandatory=$true)][string]$argItemType,
		## the raw content returned by the API GET call, from which to get data
		[parameter(Mandatory=$true)][PSCustomObject]$oContent,
		## TypeName of new object to create; "XioItemInfo.InitiatorGroup", for example
		[parameter(Mandatory=$true)][string]$PSTypeNameForNewObj
	)
	## string to add to messages written by this function; function name in square brackets
	$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
	Write-Debug "$strLogEntry_ToAdd argItemType: '$argItemType'"
	$hshPropertyForNewObj = Switch ($argItemType) {
		"initiator-groups" {
			[ordered]@{
				Name = $oContent.Name
				Index = $oContent.index
				NumInitiator = $oContent."num-of-initiators"
				NumVol = $oContent."num-of-vols"
				IOPS = [int64]$oContent.iops
				PerformanceInfo = New-Object -Type PSObject -Property ([ordered]@{
					Current = New-Object -Type PSObject -Property ([ordered]@{
						BandwidthMB = $oContent.bw / 1KB
						IOPS = [int64]$oContent.iops
						ReadBandwidthMB = $oContent."rd-bw" / 1KB
						ReadIOPS = [int]$oContent."rd-iops"
						WriteBandwidthMB = $oContent."wr-bw" / 1KB
						WriteIOPS = [int]$oContent."wr-iops"
						Small = New-Object -Type PSObject -Property ([ordered]@{
							BandwidthMB = $oContent."small-bw" / 1KB
							IOPS = [int]$oContent."small-iops"
							ReadBandwidthMB = $oContent."small-rd-bw" / 1KB
							ReadIOPS = [int]$oContent."small-rd-iops"
							WriteBandwidthMB = $oContent."small-wr-bw" / 1KB
							WriteIOPS = [int]$oContent."small-wr-iops"
						}) ## end object
						Unaligned = New-Object -Type PSObject -Property ([ordered]@{
							BandwidthMB = $oContent."unaligned-bw" / 1KB
							IOPS = [int]$oContent."unaligned-iops"
							ReadBandwidthMB = $oContent."unaligned-rd-bw" / 1KB
							ReadIOPS = [int]$oContent."unaligned-rd-iops"
							WriteBandwidthMB = $oContent."unaligned-wr-bw" / 1KB
							WriteIOPS = [int]$oContent."unaligned-wr-iops"
						}) ## end object
					}) ## end New-Object
					Total = New-Object -Type PSObject -Property ([ordered]@{
						NumRead = [int64]$oContent."acc-num-of-rd"
						NumWrite = [int64]$oContent."acc-num-of-wr"
						ReadTB = $oContent."acc-size-of-rd" / 1GB
						WriteTB =  $oContent."acc-size-of-wr" / 1GB
						Small = New-Object -Type PSObject -Property @{
							NumRead = [int64]$oContent."acc-num-of-small-rd"
							NumWrite = [int64]$oContent."acc-num-of-small-wr"
						} ## end New-Object
						Unaligned = New-Object -Type PSObject -Property @{
							NumRead = [int64]$oContent."acc-num-of-unaligned-rd"
							NumWrite = [int64]$oContent."acc-num-of-unaligned-wr"
						} ## end New-Object
					}) ## end New-Object
				}) ## end New-object PerformanceInfo
				InitiatorGrpId = $oContent."ig-id"[0]
				XmsId = $oContent."xms-id"
			} ## end ordered dictionary
			break} ## end case
		"initiators" {
			[ordered]@{
				Name = $oContent.Name
				PortAddress = $oContent."port-address"
				IOPS = [int64]$oContent.iops
				Index = $oContent.index
				ConnectionState = $oContent."initiator-conn-state"
				InitiatorGrpId = $oContent."ig-id"[0]
				InitiatorId = $oContent."initiator-id"
				PortType = $oContent."port-type"
				PerformanceInfo = New-Object -Type PSObject -Property ([ordered]@{
					Current = New-Object -Type PSObject -Property ([ordered]@{
						BandwidthMB = $oContent.bw / 1KB
						IOPS = [int64]$oContent.iops
						ReadBandwidthMB = $oContent."rd-bw" / 1KB
						ReadIOPS = [int]$oContent."rd-iops"
						WriteBandwidthMB = $oContent."wr-bw" / 1KB
						WriteIOPS = [int]$oContent."wr-iops"
						Small = New-Object -Type PSObject -Property ([ordered]@{
							BandwidthMB = $oContent."small-bw" / 1KB
							IOPS = [int]$oContent."small-iops"
							ReadBandwidthMB = $oContent."small-rd-bw" / 1KB
							ReadIOPS = [int]$oContent."small-rd-iops"
							WriteBandwidthMB = $oContent."small-wr-bw" / 1KB
							WriteIOPS = [int]$oContent."small-wr-iops"
						}) ## end object
						Unaligned = New-Object -Type PSObject -Property ([ordered]@{
							BandwidthMB = $oContent."unaligned-bw" / 1KB
							IOPS = [int]$oContent."unaligned-iops"
							ReadBandwidthMB = $oContent."unaligned-rd-bw" / 1KB
							ReadIOPS = [int]$oContent."unaligned-rd-iops"
							WriteBandwidthMB = $oContent."unaligned-wr-bw" / 1KB
							WriteIOPS = [int]$oContent."unaligned-wr-iops"
						}) ## end object
					}) ## end New-Object
					Total = New-Object -Type PSObject -Property ([ordered]@{
						NumRead = [int64]$oContent."acc-num-of-rd"
						NumWrite = [int64]$oContent."acc-num-of-wr"
						ReadTB = $oContent."acc-size-of-rd" / 1GB
						WriteTB =  $oContent."acc-size-of-wr" / 1GB
						Small = New-Object -Type PSObject -Property @{
							NumRead = [int64]$oContent."acc-num-of-small-rd"
							NumWrite = [int64]$oContent."acc-num-of-small-wr"
						} ## end New-Object
						Unaligned = New-Object -Type PSObject -Property @{
							NumRead = [int64]$oContent."acc-num-of-unaligned-rd"
							NumWrite = [int64]$oContent."acc-num-of-unaligned-wr"
						} ## end New-Object
					}) ## end New-Object
				}) ## end New-object PerformanceInfo
			} ## end ordered dictionary
			break} ## end case
		"bricks" {
			[ordered]@{
				Name = $oContent."brick-id".Item(1)
				Index = $oContent."index-in-system"
				ClusterName = $oContent."sys-id".Item(1)
				State = $oContent."brick-state"
				NumSSD = $oContent."num-of-ssds"
				NumNode = $oContent."num-of-nodes"
				NodeList = $oContent."node-list"
				BrickGuid = $oContent."brick-guid"
				BrickId = $oContent."brick-id"
				RGrpId = $oContent."rg-id"
				SsdSlotInfo = $oContent."ssd-slot-array"
				XmsId = $oContent."xms-id"
			} ## end ordered dictionary
			break} ## end case
		"clusters" {
			## new API (v3) changes value provided for dedup-ratio; previously it was the percentage (like "0.4" for 2.5:1 dedupe); as of v3, it is the dedupe value (like 2.5 in the "2.5:1" text)
			#   check if "compression-factor" property exists; if so, this is at least API v3, and has the switched-up value for dedup-ratio
			$dblDedupeRatio = $(if ($null -ne $oContent."dedup-ratio") {if ($null -eq $oContent."compression-factor") {1/$oContent."dedup-ratio"} else {$oContent."dedup-ratio"}})
			[ordered]@{
				Name = $oContent.Name
				TotSSDTB = $oContent."ud-ssd-space" / 1GB
				UsedSSDTB = $oContent."ud-ssd-space-in-use" / 1GB
				## older API version has "free-ud-ssd-space", whereas newer API version does not (as of 2.2.3 rel 25); so, using different math if the given property does not exist
				FreeSSDTB = $(if (Get-Member -Input $oContent -Name "free-ud-ssd-space") {$oContent."free-ud-ssd-space" / 1GB} else {($oContent."ud-ssd-space" - $oContent."ud-ssd-space-in-use") / 1GB})
				FreespaceLevel = $oContent."free-ud-ssd-space-level"
				UsedLogicalTB = $oContent."logical-space-in-use" / 1GB
				TotProvTB = $oContent."vol-size" / 1GB
				OverallEfficiency = $(if ($oContent."space-saving-ratio") {"{0}:1" -f ([Math]::Round(1/$oContent."space-saving-ratio", 0))})
				DedupeRatio = $dblDedupeRatio
				## available in 3.0 and up
				CompressionFactor = $(if ($null -ne $oContent."compression-factor") {$oContent."compression-factor"})
				## available in 3.0 and up
				CompressionMode = $(if ($null -ne $oContent."compression-mode") {$oContent."compression-mode"})
				## available in 3.x, but went away in v4.0.0-54 (beta) and v4.0.1-7; if not present on this object (due to say, older or newer XIOS/API version on this appliance), the data reduction rate _is_ either the dedupe ratio or the dedupe ratio * compression factor, if compression factor is not $null
				DataReduction = $(if ($null -ne $oContent."data-reduction-ratio") {$oContent."data-reduction-ratio"} else {if ($null -ne $oContent."compression-factor") {$dblDedupeRatio * $oContent."compression-factor"} else {$dblDedupeRatio}})
				ThinProvSavingsPct = (1-$oContent."thin-provisioning-ratio") * 100
				BrickList = $oContent."brick-list"
				Index = [int]$oContent.index
				ConsistencyState = $oContent."consistency-state"
				## available in 2.4.0 and up
				EncryptionMode = $oContent."encryption-mode"
				## available in 2.4.0 and up
				EncryptionSupported = $oContent."encryption-supported"
				FcPortSpeed = $oContent."fc-port-speed"
				InfiniBandSwitchList = $oContent."ib-switch-list"
				IOPS = [int64]$oContent.iops
				LicenseId = $oContent."license-id"
				NaaSysId = $oContent."naa-sys-id"
				NumBrick = $oContent."num-of-bricks"
				NumInfiniBandSwitch = $oContent."num-of-ib-switches"
				NumSSD = $oContent."num-of-ssds"
				NumVol = $oContent."num-of-vols"
				NumXenv = $oContent."num-of-xenvs"
				PerformanceInfo = New-Object -Type PSObject -Property ([ordered]@{
					Current = New-Object -Type PSObject -Property ([ordered]@{
						## latency in microseconds (µs)
						Latency = New-Object -Type PSObject -Property ([ordered]@{
							Average = New-Object -Type PSObject -Property ([ordered]@{
								AllBlockSize = [int64]$oContent."avg-latency"
								"512B" = [int64]$oContent."avg-latency-512b"
								"1KB" = [int64]$oContent."avg-latency-1kb"
								"2KB" = [int64]$oContent."avg-latency-2kb"
								"4KB" = [int64]$oContent."avg-latency-4kb"
								"8KB" = [int64]$oContent."avg-latency-8kb"
								"16KB" = [int64]$oContent."avg-latency-16kb"
								"32KB" = [int64]$oContent."avg-latency-32kb"
								"64KB" = [int64]$oContent."avg-latency-64kb"
								"128KB" = [int64]$oContent."avg-latency-128kb"
								"256KB" = [int64]$oContent."avg-latency-256kb"
								"512KB" = [int64]$oContent."avg-latency-512kb"
								"1MB" = [int64]$oContent."avg-latency-1mb"
								"GT1MB" = [int64]$oContent."avg-latency-gt1mb"
							}) ## end object
							Read = New-Object -Type PSObject -Property ([ordered]@{
								AllBlockSize = [int64]$oContent."rd-latency"
								"512B" = [int64]$oContent."rd-latency-512b"
								"1KB" = [int64]$oContent."rd-latency-1kb"
								"2KB" = [int64]$oContent."rd-latency-2kb"
								"4KB" = [int64]$oContent."rd-latency-4kb"
								"8KB" = [int64]$oContent."rd-latency-8kb"
								"16KB" = [int64]$oContent."rd-latency-16kb"
								"32KB" = [int64]$oContent."rd-latency-32kb"
								"64KB" = [int64]$oContent."rd-latency-64kb"
								"128KB" = [int64]$oContent."rd-latency-128kb"
								"256KB" = [int64]$oContent."rd-latency-256kb"
								"512KB" = [int64]$oContent."rd-latency-512kb"
								"1MB" = [int64]$oContent."rd-latency-1mb"
								"GT1MB" = [int64]$oContent."rd-latency-gt1mb"
							}) ## end object
							Write = New-Object -Type PSObject -Property ([ordered]@{
								AllBlockSize = [int64]$oContent."wr-latency"
								"512B" = [int64]$oContent."wr-latency-512b"
								"1KB" = [int64]$oContent."wr-latency-1kb"
								"2KB" = [int64]$oContent."wr-latency-2kb"
								"4KB" = [int64]$oContent."wr-latency-4kb"
								"8KB" = [int64]$oContent."wr-latency-8kb"
								"16KB" = [int64]$oContent."wr-latency-16kb"
								"32KB" = [int64]$oContent."wr-latency-32kb"
								"64KB" = [int64]$oContent."wr-latency-64kb"
								"128KB" = [int64]$oContent."wr-latency-128kb"
								"256KB" = [int64]$oContent."wr-latency-256kb"
								"512KB" = [int64]$oContent."wr-latency-512kb"
								"1MB" = [int64]$oContent."wr-latency-1mb"
								"GT1MB" = [int64]$oContent."wr-latency-gt1mb"
							}) ## end object
						}) ## end object
						BandwidthMB = $oContent.bw / 1KB
						IOPS = [int64]$oContent.iops
						ReadBandwidthMB = $oContent."rd-bw" / 1KB
						ReadIOPS = [int]$oContent."rd-iops"
						WriteBandwidthMB = $oContent."wr-bw" / 1KB
						WriteIOPS = [int]$oContent."wr-iops"
						Small = New-Object -Type PSObject -Property ([ordered]@{
							BandwidthMB = $oContent."small-bw" / 1KB
							IOPS = [int]$oContent."small-iops"
							ReadBandwidthMB = $oContent."small-rd-bw" / 1KB
							ReadIOPS = [int]$oContent."small-rd-iops"
							WriteBandwidthMB = $oContent."small-wr-bw" / 1KB
							WriteIOPS = [int]$oContent."small-wr-iops"
						}) ## end object
						Unaligned = New-Object -Type PSObject -Property ([ordered]@{
							BandwidthMB = $oContent."unaligned-bw" / 1KB
							IOPS = [int]$oContent."unaligned-iops"
							ReadBandwidthMB = $oContent."unaligned-rd-bw" / 1KB
							ReadIOPS = [int]$oContent."unaligned-rd-iops"
							WriteBandwidthMB = $oContent."unaligned-wr-bw" / 1KB
							WriteIOPS = [int]$oContent."unaligned-wr-iops"
						}) ## end object
					}) ## end New-Object
					Total = New-Object -Type PSObject -Property ([ordered]@{
						NumRead = [int64]$oContent."acc-num-of-rd"
						NumWrite = [int64]$oContent."acc-num-of-wr"
						ReadTB = $oContent."acc-size-of-rd" / 1GB
						WriteTB =  $oContent."acc-size-of-wr" / 1GB
						Small = New-Object -Type PSObject -Property @{
							NumRead = [int64]$oContent."acc-num-of-small-rd"
							NumWrite = [int64]$oContent."acc-num-of-small-wr"
						} ## end New-Object
						Unaligned = New-Object -Type PSObject -Property @{
							NumRead = [int64]$oContent."acc-num-of-unaligned-rd"
							NumWrite = [int64]$oContent."acc-num-of-unaligned-wr"
						} ## end New-Object
					}) ## end New-Object
				}) ## end New-object PerformanceInfo
				## available in 3.0 and up
				SharedMemEfficiencyLevel = $oContent."shared-memory-efficiency-level"
				## available in 3.0 and up
				SharedMemInUseRatioLevel = $oContent."shared-memory-in-use-ratio-level"
				## available in 2.4.0 and up
				SizeAndCapacity = $oContent."size-and-capacity"
				SWVersion = $oContent."sys-sw-version"
				SystemActivationDateTime = ([System.DateTime]"01 Jan 1970").AddSeconds($oContent."sys-activation-timestamp")
				SystemActivationTimestamp = $oContent."sys-activation-timestamp"
				SystemSN = $oContent."sys-psnt-serial-number"
				SystemState = $oContent."sys-state"
				SystemStopType = $oContent."sys-stop-type"
			} ## end ordered dictionary
			break} ## end case
		"data-protection-groups" {
			[ordered]@{
				Name = $oContent.name
				Index = $oContent.index
				State = $oContent."protection-state"
				TotSSDTB = $oContent."ud-ssd-space" / 1GB
				UsefulSSDTB = $oContent."useful-ssd-space" / 1GB
				UsedSSDTB = $oContent."ud-ssd-space-in-use" / 1GB
				PerformanceInfo = New-Object -Type PSObject -Property ([ordered]@{
					Current = New-Object -Type PSObject -Property ([ordered]@{
						BandwidthMB = $oContent.bw / 1KB
						IOPS = [int64]$oContent.iops
						ReadBandwidthMB = $oContent."rd-bw" / 1KB
						ReadIOPS = [int]$oContent."rd-iops"
						WriteBandwidthMB = $oContent."wr-bw" / 1KB
						WriteIOPS = [int]$oContent."wr-iops"
					}) ## end New-Object
				}) ## end New-object PerformanceInfo
				IOPS = [int64]$oContent.iops
				RebalanceInProg = [System.Convert]::ToBoolean($oContent."rebalance-in-progress")
				RebalanceProgress = $oContent."rebalance-progress"
				RebuildInProg = [System.Convert]::ToBoolean($oContent."rebuild-in-progress")
				RebuildPreventionReason = $oContent."rebuild-prevention-reason"
				RebuildProgress = [int]$oContent."rebuild-progress"
				SSDPrepInProg = [System.Convert]::ToBoolean($oContent."ssd-preparation-in-progress")
				SSDPrepProgress = $oContent."ssd-preparation-progress"
				AvailableRebuild = $oContent."available-rebuilds"
				BrickName = $oContent."brick-id"[1]
				BrickIndex = $oContent."brick-id"[2]
				ClusterName = $oContent."sys-id"[1]
				ClusterIndex = $oContent."sys-id"[2]
				NumNode = $oContent."num-of-nodes"
				NumSSD = $oContent."num-of-ssds"
				RGrpId = $oContent."rg-id"
				XmsId = $oContent."xms-id"
			} ## end ordered dictionary
			break} ## end case
		"events" {
			[ordered]@{
				EventID = $oContent.id
				DateTime = $(if ($null -ne $oContent.timestamp) {[System.DateTime]($oContent.timestamp)})
				RelAlertCode = $oContent.event_code
				Category = $oContent.classification
				Severity = $oContent.severity
				EntityType = $oContent.entity
				EntityDetails = $oContent.entity_details
				Description = $oContent.description
			} ## end ordered dictionary
			break} ## end case
		"ig-folders" {
			[ordered]@{
				Name = $oContent.name
				Caption = $oContent.caption
				Index = $oContent.index
				## the initiator group IDs for IGs directly in this ig-folder, as determined by getting the IDs in the "direct-list" where said IDs are not also in the "subfolder-list" list of object IDs
				InitiatorGrpIdList = $oContent."direct-list" | Foreach-Object {$_[0]} | Where-Object {($oContent."subfolder-list" | Foreach-Object {$_[0]}) -notcontains $_}
				FolderId = $oContent."folder-id"
				NumIG = $oContent."num-of-direct-objs"
				NumSubfolder = $oContent."num-of-subfolders"
				ParentFolder = $oContent."parent-folder-id"[1]
				ParentFolderId = $oContent."parent-folder-id"[0]
				PerformanceInfo = New-Object -Type PSObject -Property ([ordered]@{
					Current = New-Object -Type PSObject -Property ([ordered]@{
						BandwidthMB = $oContent.bw / 1KB
						IOPS = [int64]$oContent.iops
						ReadBandwidthMB = $oContent."rd-bw" / 1KB
						ReadIOPS = [int]$oContent."rd-iops"
						WriteBandwidthMB = $oContent."wr-bw" / 1KB
						WriteIOPS = [int]$oContent."wr-iops"
						Small = New-Object -Type PSObject -Property ([ordered]@{
							BandwidthMB = $oContent."small-bw" / 1KB
							IOPS = [int]$oContent."small-iops"
							ReadBandwidthMB = $oContent."small-rd-bw" / 1KB
							ReadIOPS = [int]$oContent."small-rd-iops"
							WriteBandwidthMB = $oContent."small-wr-bw" / 1KB
							WriteIOPS = [int]$oContent."small-wr-iops"
						}) ## end object
						Unaligned = New-Object -Type PSObject -Property ([ordered]@{
							BandwidthMB = $oContent."unaligned-bw" / 1KB
							IOPS = [int]$oContent."unaligned-iops"
							ReadBandwidthMB = $oContent."unaligned-rd-bw" / 1KB
							ReadIOPS = [int]$oContent."unaligned-rd-iops"
							WriteBandwidthMB = $oContent."unaligned-wr-bw" / 1KB
							WriteIOPS = [int]$oContent."unaligned-wr-iops"
						}) ## end object
					}) ## end New-Object
					Total = New-Object -Type PSObject -Property ([ordered]@{
						NumRead = [int64]$oContent."acc-num-of-rd"
						NumWrite = [int64]$oContent."acc-num-of-wr"
						ReadTB = $oContent."acc-size-of-rd" / 1GB
						WriteTB =  $oContent."acc-size-of-wr" / 1GB
						Small = New-Object -Type PSObject -Property @{
							NumRead = [int64]$oContent."acc-num-of-small-rd"
							NumWrite = [int64]$oContent."acc-num-of-small-wr"
						} ## end New-Object
						Unaligned = New-Object -Type PSObject -Property @{
							NumRead = [int64]$oContent."acc-num-of-unaligned-rd"
							NumWrite = [int64]$oContent."acc-num-of-unaligned-wr"
						} ## end New-Object
					}) ## end New-Object
				}) ## end New-object PerformanceInfo
				SubfolderList = $oContent."subfolder-list"
				IOPS = [int64]$oContent.iops
				XmsId = $oContent."xms-id"
			} ## end ordered dictionary
			break} ## end case
		"lun-maps" {
			[ordered]@{
				VolumeName = $oContent."vol-name"
				LunId = $oContent.lun
				## changed property name from "ig-name" after v0.6.0 release
				InitiatorGroup = $oContent."ig-name"
				InitiatorGrpIndex = $oContent."ig-index"
				TargetGrpName = $oContent."tg-name"
				TargetGrpIndex = $oContent."tg-index"
				## changed from lm-id to mapping-id in v2.4
				MappingId = $oContent."mapping-id"
				## available in 2.4.0 and up
				MappingIndex = $oContent."mapping-index"
				XmsId = $oContent."xms-id"
				VolumeIndex = $oContent."vol-index"
			} ## end ordered dictionary
			break} ## end case
		"ssds" {
			[ordered]@{
				Name = $oContent.name
				CapacityGB = $oContent."ssd-size-in-kb"/1MB
				UsefulGB = $oContent."useful-ssd-space"/1MB
				UsedGB = $oContent."ssd-space-in-use"/1MB
				SlotNum = $oContent."slot-num"
				ModelName = $oContent."model-name"
				SerialNumber = $oContent."serial-number"
				FWVersion = $oContent."fw-version"
				PartNumber = $oContent."part-number"
				LifecycleState = $oContent."fru-lifecycle-state"
				SSDFailureReason = $oContent."ssd-failure-reason"
				PctEnduranceLeft = $oContent."percent-endurance-remaining"
				PctEnduranceLeftLvl = $oContent."percent-endurance-remaining-level"
				PerformanceInfo = New-Object -Type PSObject -Property ([ordered]@{
					Current = New-Object -Type PSObject -Property ([ordered]@{
						BandwidthMB = $oContent.bw / 1KB
						IOPS = [int64]$oContent.iops
						ReadBandwidthMB = $oContent."rd-bw" / 1KB
						ReadIOPS = [int]$oContent."rd-iops"
						WriteBandwidthMB = $oContent."wr-bw" / 1KB
						WriteIOPS = [int]$oContent."wr-iops"
					}) ## end New-Object
				}) ## end New-Object
				IOPS = [int64]$oContent."iops"
				HealthState = $oContent."health-state"
				ObjSeverity = $oContent."obj-severity"
				Index = $oContent."index"
				FWVersionError = $oContent."fw-version-error"
				EnabledState = $oContent."enabled-state"
				## available in 2.4.0 and up
				EncryptionStatus = $oContent."encryption-status"
				IdLED = $oContent."identify-led"
				StatusLED = $oContent."status-led"
				SwapLED = $oContent."swap-led"
				HWRevision = $oContent."hw-revision"
				DiagHealthState = $oContent."diagnostic-health-state"
				SSDLink1Health = $oContent."ssd-link1-health-state"
				SSDLink2Health = $oContent."ssd-link2-health-state"
				SSDPositionState = $oContent."ssd-position-state"
				BrickId = $oContent."brick-id"
				RGrpId = $oContent."rg-id"
				SsdRGrpState = $oContent."ssd-rg-state"
				SsdId = $oContent."ssd-id"
				SsdUid = $oContent."ssd-uid"
				SysId = $oContent."sys-id"
				XmsId = $oContent."xms-id"
			} ## end ordered dictionary
			break} ## end case
		"storage-controllers" {
			[ordered]@{
				Name = $oContent.name
				State = $oContent."backend-storage-controller-state"
				MgrAddr = $oContent."node-mgr-addr"
				IBAddr1 = $oContent."ib-addr1"
				IBAddr2 = $oContent."ib-addr2"
				IPMIAddr = $oContent."ipmi-addr"
				BiosFWVersion = $oContent."bios-fw-version"
				## hm, seems to be second item in the 'brick-id' property
				BrickName = $oContent."brick-id".Item(1)
				## hm, seems to be second item in the 'sys-id' property
				Cluster = $oContent."sys-id".Item(1)
				EnabledState = $oContent."enabled-state"
				## available in 2.4.0 and up
				EncryptionMode = $oContent."encryption-mode"
				## available in 2.4.0 and up
				EncryptionSwitchStatus = $oContent."encryption-switch-status"
				FcHba = New-Object -Type PSObject -Property @{
					## renamed property in XIO module from "fc-hba-fw-version"
					FWVersion = $oContent."fc-hba-fw-version"
					HWRevision = $oContent."fc-hba-hw-revision"
					Model = $oContent."fc-hba-model"
				} ## end New-Object
				HealthState = $oContent."node-health-state"
				IPMIState = $oContent."ipmi-conn-state"
				## available in 2.4.0 and up
				JournalState = $oContent."journal-state"
				## available in 2.4.0 and up
				MgmtPortSpeed = $oContent."mgmt-port-speed"
				## available in 2.4.0 and up
				MgmtPortState = $oContent."mgmt-port-state"
				NodeMgrConnState = $oContent."node-mgr-conn-state"
				NumSSD = $oContent."num-of-ssds"
				NumSSDDown = $oContent."ssd-dn"
				NumTargetDown = $oContent."targets-dn"
				PCI = New-Object -Type PSObject -Property ([ordered]@{
					"10geHba" = New-Object -Type PSObject -Property @{
						FWVersion = $oContent."pci-10ge-hba-fw-version"
						HWRevision = $oContent."pci-10ge-hba-hw-revision"
						Model = $oContent."pci-10ge-hba-model"
					} ## end New-Object
					DiskController = New-Object -Type PSObject -Property @{
						FWVersion = $oContent."pci-disk-controller-fw-version"
						HWRevision = $oContent."pci-disk-controller-hw-revision"
						Model = $oContent."pci-disk-controller-model"
					} ## end New-Object
					IbHba = New-Object -Type PSObject -Property @{
						FWVersion = $oContent."pci-ib-hba-fw-version"
						HWRevision = $oContent."pci-ib-hba-hw-revision"
						Model = $oContent."pci-ib-hba-model"
					} ## end New-Object
				}) ## end New-Object
				PoweredState = $oContent."powered-state"
				RemoteJournalHealthState = $oContent."remote-journal-health-state"
				SAS = $(1..2 | Foreach-Object {
					New-Object -Type PSObject -Property ([ordered]@{
						Name = "SAS$_"
						HbaPortHealthLevel = $oContent."sas${_}-hba-port-health-level"
						PortRate = $oContent."sas${_}-port-rate"
						PortState = $oContent."sas${_}-port-state"
					}) ## end New-Object
				}) ## end sub call
				SerialNumber = $oContent."serial-number"
				## available in 2.4.0 and up
				SdrFWVersion = $oContent."sdr-fw-version"
				SWVersion = $oContent."sw-version"
				OSVersion = $oContent."os-version"
			} ## end ordered dictionary
			break} ## end case
		"target-groups" {
			[ordered]@{
				Name = $oContent.name
				Index = $oContent.index
				ClusterName = $oContent."sys-id"[1]
				TargetGrpId = $oContent."tg-id"
				SysId = $oContent."sys-id"
				XmsId = $oContent."xms-id"
			} ## end ordered dictionary
			break} ## end case
		"targets" {
			[ordered]@{
				Name = $oContent.name
				PortAddress = $oContent."port-address"
				PortSpeed = $oContent."port-speed"
				PortState = $oContent."port-state"
				PortType = $oContent."port-type"
				BrickId = $oContent."brick-id"
				DriverVersion = $oContent."driver-version"  ## renamed from "driver-version"
				FCIssue = New-Object -Type PSObject -Property ([ordered]@{
					InvalidCrcCount = [int]$oContent."fc-invalid-crc-count"
					LinkFailureCount = [int]$oContent."fc-link-failure-count"
					LossOfSignalCount = [int]$oContent."fc-loss-of-signal-count"
					LossOfSyncCount = [int]$oContent."fc-loss-of-sync-count"
					NumDumpedFrame = [int]$oContent."fc-dumped-frames"
					PrimSeqProtErrCount = [int]$oContent."fc-prim-seq-prot-err-count"
				}) ## end New-Object
				FWVersion = $oContent."fw-version"  ## renamed from "fw-version"
				TargetGrpId = $oContent."tg-id"
				Index = $oContent.index
				IOPS = [int64]$oContent.iops
				JumboFrameEnabled = $oContent."jumbo-enabled"
				MTU = $oContent.mtu
				PerformanceInfo = New-Object -Type PSObject -Property ([ordered]@{
					Current = New-Object -Type PSObject -Property ([ordered]@{
						BandwidthMB = $oContent.bw / 1KB
						IOPS = [int64]$oContent.iops
						ReadBandwidthMB = $oContent."rd-bw" / 1KB
						ReadIOPS = [int]$oContent."rd-iops"
						WriteBandwidthMB = $oContent."wr-bw" / 1KB
						WriteIOPS = [int]$oContent."wr-iops"
						Small = New-Object -Type PSObject -Property ([ordered]@{
							BandwidthMB = $oContent."small-bw" / 1KB
							IOPS = [int]$oContent."small-iops"
							ReadBandwidthMB = $oContent."small-rd-bw" / 1KB
							ReadIOPS = [int]$oContent."small-rd-iops"
							WriteBandwidthMB = $oContent."small-wr-bw" / 1KB
							WriteIOPS = [int]$oContent."small-wr-iops"
						}) ## end object
						Unaligned = New-Object -Type PSObject -Property ([ordered]@{
							BandwidthMB = $oContent."unaligned-bw" / 1KB
							IOPS = [int]$oContent."unaligned-iops"
							ReadBandwidthMB = $oContent."unaligned-rd-bw" / 1KB
							ReadIOPS = [int]$oContent."unaligned-rd-iops"
							WriteBandwidthMB = $oContent."unaligned-wr-bw" / 1KB
							WriteIOPS = [int]$oContent."unaligned-wr-iops"
						}) ## end object
					}) ## end New-Object
					Total = New-Object -Type PSObject -Property ([ordered]@{
						NumRead = [int64]$oContent."acc-num-of-rd"
						NumWrite = [int64]$oContent."acc-num-of-wr"
						ReadTB = $oContent."acc-size-of-rd" / 1GB
						WriteTB =  $oContent."acc-size-of-wr" / 1GB
						Small = New-Object -Type PSObject -Property @{
							NumRead = [int64]$oContent."acc-num-of-small-rd"
							NumWrite = [int64]$oContent."acc-num-of-small-wr"
						} ## end New-Object
						Unaligned = New-Object -Type PSObject -Property @{
							NumRead = [int64]$oContent."acc-num-of-unaligned-rd"
							NumWrite = [int64]$oContent."acc-num-of-unaligned-wr"
						} ## end New-Object
					}) ## end New-Object
				}) ## end New-object PerformanceInfo
				#UnalignedIOPS = [int64]$oContent."unaligned-iops"  ## changed in module v0.5.7 (moved into PerformanceInfo section)
				#AccSizeOfRdTB = $oContent."acc-size-of-rd" / 1GB  ## changed in module v0.5.7 (moved into PerformanceInfo section)
				#AccSizeOfWrTB = $oContent."acc-size-of-wr" / 1GB  ## changed in module v0.5.7 (moved into PerformanceInfo section)
			} ## end ordered dictionary
			break} ## end case
		## snapshots and volumes have the same properties
		{"snapshots","volumes" -contains $_} {
			[ordered]@{
				Name = $oContent.name
				NaaName = $oContent."naa-name"
				VolSizeTB = $oContent."vol-size" / 1GB
				VolId = $oContent."vol-id"[0]  ## renamed from "vol-id"
				AlignmentOffset = $oContent."alignment-offset"  ## renamed from "alignment-offset"
				AncestorVolId = $oContent."ancestor-vol-id"  ## renamed from "ancestor-vol-id"
				DestSnapList = $oContent."dest-snap-list"  ## renamed from "dest-snap-list"
				LBSize = $oContent."lb-size"  ## renamed from "lb-size"
				NumDestSnap = $oContent."num-of-dest-snaps"  ## renamed from "num-of-dest-snaps"
				NumLunMapping = $oContent."num-of-lun-mappings"
				LunMappingList = $oContent."lun-mapping-list"
				## the initiator group IDs for IGs for this volume; Lun-Mapping-List property is currently array of @( @(<initiator group ID string>, <initiator group name>, <initiator group object index number>), @(<target group ID>, <target group name>, <target group object index number>), <host LUN ID>)
				InitiatorGrpIdList = $oContent."lun-mapping-list" | Foreach-Object {$_[0][0]}
				## available in 2.4.0 and up
				UsedLogicalTB = $(if (Get-Member -Input $oContent -Name "logical-space-in-use") {$oContent."logical-space-in-use" / 1GB} else {$null})
				IOPS = [int64]$oContent.iops
				Index = $oContent.index
				## available in 3.0 and up
				Compressible = $oContent.compressible
				CreationTime = [System.DateTime]$oContent."creation-time"
				PerformanceInfo = New-Object -Type PSObject -Property ([ordered]@{
					Current = New-Object -Type PSObject -Property ([ordered]@{
						## latency in microseconds (µs)
						Latency = New-Object -Type PSObject -Property ([ordered]@{
							Average = New-Object -Type PSObject -Property ([ordered]@{
								AllBlockSize = [int64]$oContent."avg-latency"
							}) ## end object
							Read = New-Object -Type PSObject -Property ([ordered]@{
								AllBlockSize = [int64]$oContent."rd-latency"
							}) ## end object
							Write = New-Object -Type PSObject -Property ([ordered]@{
								AllBlockSize = [int64]$oContent."wr-latency"
							}) ## end object
						}) ## end object
						BandwidthMB = $oContent.bw / 1KB
						IOPS = [int64]$oContent.iops
						ReadBandwidthMB = $oContent."rd-bw" / 1KB
						ReadIOPS = [int]$oContent."rd-iops"
						WriteBandwidthMB = $oContent."wr-bw" / 1KB
						WriteIOPS = [int]$oContent."wr-iops"
						Small = New-Object -Type PSObject -Property ([ordered]@{
							BandwidthMB = $oContent."small-bw" / 1KB
							IOPS = [int]$oContent."small-iops"
							ReadBandwidthMB = $oContent."small-rd-bw" / 1KB
							ReadIOPS = [int]$oContent."small-rd-iops"
							WriteBandwidthMB = $oContent."small-wr-bw" / 1KB
							WriteIOPS = [int]$oContent."small-wr-iops"
						}) ## end object
						Unaligned = New-Object -Type PSObject -Property ([ordered]@{
							BandwidthMB = $oContent."unaligned-bw" / 1KB
							IOPS = [int]$oContent."unaligned-iops"
							ReadBandwidthMB = $oContent."unaligned-rd-bw" / 1KB
							ReadIOPS = [int]$oContent."unaligned-rd-iops"
							WriteBandwidthMB = $oContent."unaligned-wr-bw" / 1KB
							WriteIOPS = [int]$oContent."unaligned-wr-iops"
						}) ## end object
					}) ## end New-Object
					Total = New-Object -Type PSObject -Property ([ordered]@{
						NumRead = [int64]$oContent."acc-num-of-rd"
						NumWrite = [int64]$oContent."acc-num-of-wr"
						ReadTB = $oContent."acc-size-of-rd" / 1GB
						WriteTB =  $oContent."acc-size-of-wr" / 1GB
						Small = New-Object -Type PSObject -Property @{
							NumRead = [int64]$oContent."acc-num-of-small-rd"
							NumWrite = [int64]$oContent."acc-num-of-small-wr"
						} ## end New-Object
						Unaligned = New-Object -Type PSObject -Property @{
							NumRead = [int64]$oContent."acc-num-of-unaligned-rd"
							NumWrite = [int64]$oContent."acc-num-of-unaligned-wr"
						} ## end New-Object
					}) ## end New-Object
				}) ## end New-object PerformanceInfo
				SmallIOAlertsCfg = $oContent."small-io-alerts"
				UnalignedIOAlertsCfg = $oContent."unaligned-io-alerts"
				VaaiTPAlertsCfg = $oContent."vaai-tp-alerts"
				LuName = $oContent."lu-name"
				SmallIORatio = $oContent."small-io-ratio"
				SmallIORatioLevel = $oContent."small-io-ratio-level"
				SnapGrpId = $oContent."snapgrp-id"
				UnalignedIORatio = $oContent."unaligned-io-ratio"
				UnalignedIORatioLevel = $oContent."unaligned-io-ratio-level"
				SysId = $oContent."sys-id"
				XmsId = $oContent."xms-id"
			} ## end ordered dictionary
			break} ## end case
		"volume-folders" {
			[ordered]@{
				Name = $oContent.name
				ParentFolder = $oContent."parent-folder-id"[1]
				NumVol = [int]$oContent."num-of-vols"
				VolSizeTB = $oContent."vol-size" / 1GB
				FolderId = $oContent."folder-id"[0]
				ParentFolderId = $oContent."parent-folder-id"[0]
				NumChild = [int]$oContent."num-of-direct-objs"
				NumSubfolder = [int]$oContent."num-of-subfolders"
				## the volume IDs for volumes directly in this volume-folder, as determined by getting the IDs in the "direct-list" where said IDs are not also in the "subfolder-list" list of object IDs
				VolIdList = $oContent."direct-list" | Foreach-Object {$_[0]} | Where-Object {($oContent."subfolder-list" | Foreach-Object {$_[0]}) -notcontains $_}
				Index = [int]$oContent.index
				IOPS = [int64]$oContent.iops
				PerformanceInfo = New-Object -Type PSObject -Property ([ordered]@{
					Current = New-Object -Type PSObject -Property ([ordered]@{
						BandwidthMB = $oContent.bw / 1KB
						IOPS = [int64]$oContent.iops
						ReadBandwidthMB = $oContent."rd-bw" / 1KB
						ReadIOPS = [int]$oContent."rd-iops"
						WriteBandwidthMB = $oContent."wr-bw" / 1KB
						WriteIOPS = [int]$oContent."wr-iops"
						Small = New-Object -Type PSObject -Property ([ordered]@{
							BandwidthMB = $oContent."small-bw" / 1KB
							IOPS = [int]$oContent."small-iops"
							ReadBandwidthMB = $oContent."small-rd-bw" / 1KB
							ReadIOPS = [int]$oContent."small-rd-iops"
							WriteBandwidthMB = $oContent."small-wr-bw" / 1KB
							WriteIOPS = [int]$oContent."small-wr-iops"
						}) ## end object
						Unaligned = New-Object -Type PSObject -Property ([ordered]@{
							BandwidthMB = $oContent."unaligned-bw" / 1KB
							IOPS = [int]$oContent."unaligned-iops"
							ReadBandwidthMB = $oContent."unaligned-rd-bw" / 1KB
							ReadIOPS = [int]$oContent."unaligned-rd-iops"
							WriteBandwidthMB = $oContent."unaligned-wr-bw" / 1KB
							WriteIOPS = [int]$oContent."unaligned-wr-iops"
						}) ## end object
					}) ## end New-Object
					Total = New-Object -Type PSObject -Property ([ordered]@{
						NumRead = [int64]$oContent."acc-num-of-rd"
						NumWrite = [int64]$oContent."acc-num-of-wr"
						ReadTB = $oContent."acc-size-of-rd" / 1GB
						WriteTB =  $oContent."acc-size-of-wr" / 1GB
						Small = New-Object -Type PSObject -Property @{
							NumRead = [int64]$oContent."acc-num-of-small-rd"
							NumWrite = [int64]$oContent."acc-num-of-small-wr"
						} ## end New-Object
						Unaligned = New-Object -Type PSObject -Property @{
							NumRead = [int64]$oContent."acc-num-of-unaligned-rd"
							NumWrite = [int64]$oContent."acc-num-of-unaligned-wr"
						} ## end New-Object
					}) ## end New-Object
				}) ## end New-object PerformanceInfo
				XmsId = $oContent."xms-id"
			} ## end ordered dictionary
			break} ## end case
		"xenvs" {
			[ordered]@{
				Name = $oContent.name
				Index = $oContent.index
				CPUUsage = $oContent."cpu-usage"
				NumMdl = $oContent."num-of-mdls"
				BrickId = $oContent."brick-id"
				XEnvId = $oContent."xenv-id"
				XEnvState = $oContent."xenv-state"
				XmsId = $oContent."xms-id"
			} ## end ordered dictionary
			break} ## end case
		#### API v2 items
		"alert-definitions" {
			[ordered]@{
				Name = $oContent.name
				AlertCode = [string]$oContent."alert-code"
				## generally the same value as .name
				AlertType = $oContent."alert-type"
				Class = $oContent."class-name"
				ClearanceMode = $oContent."clearance-mode"
				Enabled = ($oContent."activity-mode" -eq "enabled")
				Guid = $oContent.guid
				Index = $oContent.index
				SendToCallHome = ($oContent."send-to-call-home" -eq "yes")
				Severity = $oContent.severity
				ThresholdType = $oContent."threshold-type"
				ThresholdValue = [int]$oContent."threshold-value"
				UserModified = ([string]"true" -eq $oContent."user-modified")
				XmsId = $oContent."xms-id"
			} ## end ordered dictionary
			break} ## end case
		"bbus" {
			[ordered]@{
				Name = $oContent.name
				Battery = New-Object -Type PSObject -Property ([ordered]@{
					LowBattery_hasInput = ([string]"true" -eq $oContent."is-low-battery-has-input")
					LowBattery_noInput = ([string]"true" -eq $oContent."is-low-battery-no-input")
					LowBatteryRuntime = ([string]"true" -eq $oContent."is-low-battery-runtime")
					NeedsReplacement = ([string]"true" -eq $oContent."ups-need-battery-replacement")
					ReplacementReason = $oContent."fru-replace-failure-reason"
					RuntimeSec = [int]$oContent."battery-runtime"
					Voltage = [Double]$oContent."battery-voltage"
				}) ## end new-object
				BatteryChargePct = [int]$oContent."ups-battery-charge-in-percent"
				BBUId = $oContent."ups-id"[0]
				BrickId = $oContent."brick-id"
				BypassActive = ([string]"true" -eq $oContent."is-bypass-active")
				ConnectedToSC = ($oContent."ups-conn-state" -eq "connected")
				ClusterId = $oContent."sys-id"[0]
				ClusterName = $oContent."sys-id"[1]
				Enabled = ($oContent."enabled-state" -eq "enabled")
				FWVersion = $oContent."fw-version"
				FWVersionError = $oContent."fw-version-error"
				Guid = $oContent.guid
				HWRevision = $oContent."hw-revision"
				IdLED = $oContent."identify-led"
				Index = $oContent.index
				IndexInXbrick = [int]$oContent."index-in-brick"
				Input = $oContent."ups-input"
				InputHz = [Double]$oContent."input-frequency"
				InputVoltage = [int]$oContent."ups-voltage"
				LifecycleState = $oContent."fru-lifecycle-state"
				LoadPct = [int]$oContent."ups-load-in-percent"
				LoadPctLevel = $oContent."ups-load-percent-level"
				Model = $oContent."model-name"
				Outlet1Status = $oContent."outlet1-status"
				Outlet2Status = $oContent."outlet2-status"
				OutputA = [Double]$oContent."output-current"
				OutputHz = [Double]$oContent."output-frequency"
				OutputVoltage = [Double]$oContent."output-voltage"
				PartNumber = $oContent."part-number"
				PowerFeed = $oContent."power-feed"
				PowerW = [int]$oContent.power
				RealPowerW = [int]$oContent."real-power"
				SerialNumber = $oContent."serial-number"
				Severity = $oContent.severity
				Status = $oContent."ups-status"
				StatusLED = $oContent."status-led"
				StorageController = $oContent."monitoring-nodes-obj-id-list" | Foreach-Object {
					New-Object -Type PSObject -Property ([ordered]@{
						Name = $_[1]
						StorageControllerId = $_[0]
					}) ## end New-Object
				} ## end foreach-object
				TagList = $oContent."tag-list"
				UPSAlarm = $oContent."ups-alarm"
				UPSOverloaded = ([string]"true" -eq $oContent."is-ups-overload")
				SysId = $oContent."sys-id"
				XmsId = $oContent."xms-id"
			} ## end ordered dictionary
			break} ## end case
		"xms" {
			[ordered]@{
				Name = $oContent.name
				Index = $oContent.index
				XmsId = $oContent."xms-id"
				## the software version's build number; like, "41" for SWVersion "4.0.1-41"
				BuildNumber = [int]$oContent.build
				Config = New-Object -Type PSObject -Property ([ordered]@{
					AllowEmptyPassword = [boolean]$oContent."allow-empty-password"
					DefaultUserInactivityTimeoutMin = [int]$oContent."default-user-inactivity-timeout"
					ManagementInterface = $oContent."mgmt-interface"
					## network config of XMS
					Network = New-Object -Type PSObject -Property ([ordered]@{
						DefaultGateway = $oContent."xms-gw"
						IP = $oContent."xms-ip"
						SubnetMask = $oContent."xms-ip-sn"
					}) ## end New-Object
					NTPMode = $oContent.mode
					NTPServer = $oContent."ntp-servers"
					NumUserAccount = [int]$oContent."num-of-user-accounts"
					WrongCnInCsr = $oContent."wrong-cn-in-csr"
				}) ## end New-Object Config
				DiskSpaceUtilizationLevel = $oContent."disk-space-utilization-level"
				DiskSpaceSecUtilizationLevel = $oContent."disk-space-secondary-utilization-level"
				DBVersion = [System.Version]($oContent."db-version")
				EventlogInfo = New-Object -Type PSObject -Property ([ordered]@{
					NumDaysInEventlog = [int]$oContent."days-in-num-event"
					MaxEventlogRecords = [int]$oContent."max-recs-in-eventlog"
					NumEventlogRecords = [int]$oContent."recs-in-event-log"
				}) ## end New-Object EventlogInfo
				## leaving as string for now, as casting to System.Guid adds dashes like a "real" GUID, whereas this string value has no dashes
				Guid = $oContent.guid
				IPVersion = $oContent."ip-version"
				ISO8601DateTime = $oContent.datetime
				LogSizeTotalGB = $oContent."logs-size" / 1MB
				MemoryTotalGB = $oContent."ram-total" / 1MB
				MemoryUsageGB = $oContent."ram-usage" / 1MB
				MemoryUtilizationLevel = $oContent."memory-utilization-level"
				NumCluster = [int]$oContent."num-of-systems"
				NumInitiatorGroup = [int]$oContent."num-of-igs"
				NumIscsiRoute = [int]$oContent."num-of-iscsi-routes"
				ObjSeverity = $oContent."obj-severity"
				## "The aggregated value of the ratio of provisioned Volume capacity to the cluster’s actual used physical capacity"
				OverallEfficiency = [System.Double]$oContent."overall-efficiency-ratio"
				RestApiVersion = [System.Version]($oContent."restapi-protocol-version")
				ServerName = $oContent."server-name"
				## string representation, like 4.0.1-41
				SWVersion = $oContent."sw-version"
				ThinProvSavingsPct = [int]$oContent."thin-provisioning-savings"
				Version = [System.Version]($oContent.version)
				PerformanceInfo = New-Object -Type PSObject -Property ([ordered]@{
					Current = New-Object -Type PSObject -Property ([ordered]@{
						## latency in microseconds (µs)
						Latency = New-Object -Type PSObject -Property ([ordered]@{
							Read = New-Object -Type PSObject -Property ([ordered]@{
								AllBlockSize = [int64]$oContent."rd-latency"
							}) ## end object
							Write = New-Object -Type PSObject -Property ([ordered]@{
								AllBlockSize = [int64]$oContent."wr-latency"
							}) ## end object
						}) ## end object
						BandwidthMB = $oContent.bw / 1KB
						BandwidthMBByBlock = $oContent."bw-by-block" / 1KB
						CPUUsagePct = [System.Double]$oContent.cpu
						IOPS = [int64]$oContent.iops
						IOPSByBlock = [int64]$oContent."iops-by-block"
						ReadBandwidthMB = $oContent."rd-bw" / 1KB
						ReadBandwidthMBByBlock = $oContent."rd-bw-by-block" / 1KB
						ReadIOPS = [int]$oContent."rd-iops"
						ReadIOPSByBlock = [int]$oContent."rd-iops-by-block"
						WriteBandwidthMB = $oContent."wr-bw" / 1KB
						WriteBandwidthMBByBlock = $oContent."wr-bw-by-block" / 1KB
						WriteIOPS = [int]$oContent."wr-iops"
						WriteIOPSByBlock = [int]$oContent."wr-iops-by-block"
					}) ## end New-Object
					TopObjectByCategory = New-Object -Type PSObject -Property ([ordered]@{
						InitiatorGrpByBandwidth = $oContent."top-n-igs-by-bw" | Foreach-Object {
							$oThisTopObj = $_
							New-Object -Type PSObject -Property ([ordered]@{
								## name of XIO cluster in which this IG resides
								Cluster = $oThisTopObj[7]
								InitiatorGrpId = $oThisTopObj[0][0]
								Name = $oThisTopObj[0][1]
								InitiatorGrpIndex = $oThisTopObj[0][2]
								LastBandwidthMB = $oThisTopObj[1..6] | Foreach-Object {$_ / 1KB}
							})
						} ## end Foreach-Object
						InitiatorGrpByIOPS = $oContent."top-n-igs-by-iops" | Foreach-Object {
							$oThisTopObj = $_
							New-Object -Type PSObject -Property ([ordered]@{
								## name of XIO cluster in which this IG resides
								Cluster = $oThisTopObj[7]
								InitiatorGrpId = $oThisTopObj[0][0]
								Name = $oThisTopObj[0][1]
								InitiatorGrpIndex = $oThisTopObj[0][2]
								LastIOPS = $oThisTopObj[1..6] | Foreach-Object {[int]$_}
							})
						} ## end Foreach-Object
						VolumeByLatency = $oContent."top-n-volumes-by-latency" | Foreach-Object {
							$oThisTopObj = $_
							New-Object -Type PSObject -Property ([ordered]@{
								## name of XIO cluster in which this IG resides
								Cluster = $oThisTopObj[7]
								VolId = $oThisTopObj[0][0]
								Name = $oThisTopObj[0][1]
								VolumeIndex = $oThisTopObj[0][2]
								LastLatency = $oThisTopObj[1..6] | Foreach-Object {[int]$_}
							})
						} ## end Foreach-Object
					}) ## end property
				}) ## end New-object PerformanceInfo
			} ## end ordered dictionary
			break} ## end case
		#### end API v2 items
		#### PerformanceInfo items
		{"ClusterPerformance","Ig-FolderPerformance","Initiator-GroupPerformance","InitiatorPerformance","TargetPerformance","Volume-FolderPerformance","VolumePerformance" -contains $_} {
			[ordered]@{
				Name = $oContent.name
				Index = $oContent.index
				WriteBW_MBps = $oContent.PerformanceInfo.Current.WriteBandwidthMB
				WriteIOPS = $oContent.PerformanceInfo.Current.WriteIOPS
				ReadBW_MBps = $oContent.PerformanceInfo.Current.ReadBandwidthMB
				ReadIOPS = $oContent.PerformanceInfo.Current.ReadIOPS
				BW_MBps = $oContent.PerformanceInfo.Current.BandwidthMB
				IOPS = $oContent.PerformanceInfo.Current.IOPS
				TotWriteIOs = $oContent.PerformanceInfo.Total.NumWrite
				TotReadIOs = $oContent.PerformanceInfo.Total.NumRead
			} ## end ordered dictionary
			break} ## end case
		{"Data-Protection-GroupPerformance","SsdPerformance" -contains $_} {
			[ordered]@{
				Name = $oContent.name
				Index = $oContent.index
				WriteBW_MBps = $oContent.PerformanceInfo.Current.WriteBandwidthMB
				WriteIOPS = $oContent.PerformanceInfo.Current.WriteIOPS
				ReadBW_MBps = $oContent.PerformanceInfo.Current.ReadBandwidthMB
				ReadIOPS = $oContent.PerformanceInfo.Current.ReadIOPS
				BW_MBps = $oContent.PerformanceInfo.Current.BandwidthMB
				IOPS = $oContent.PerformanceInfo.Current.IOPS
			} ## end ordered dictionary
			break} ## end case
		#### end PerformanceInfo items
		} ## end switch
	New-Object -Type $PSTypeNameForNewObj -Property $hshPropertyForNewObj
} ## end function
