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
			$oWebClient.DownloadString($hshParamsForRequest["Uri"]) | Foreach-Object {Write-Verbose "$strLogEntry_ToAdd API reply JSON length (KB): $([Math]::Round($_.Length/1KB, 3))"; $_} | ConvertFrom-Json
		} ## end try
		catch {
			_Invoke-WebExceptionErrorCatchHandling -URI $hshParamsForRequest['Uri'] -ErrorRecord $_
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
		[switch]$TestPort,
		## XtremIO REST API version to use -- which will determine a part of the URI
		[System.Version]$RestApiVersion
	) ##end param

	## string to add to messages written by this function; function name in square brackets
	$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"

	$strRestApiSpecificUriPiece = if ($PSBoundParameters.ContainsKey("RestApiVersion") -and ($RestApiVersion -ge [System.Version]"2.0")) {"/v$($RestApiVersion.Major)"} else {$null}

	$intPortToUse = $(
		## if a port was specified, try to use it
		$intPortToTry = if ($PSBoundParameters.ContainsKey("Port_int")) {$Port_int} else {$hshCfg["DefaultApiPort"]["intSSL"]}
		if ($TestPort -eq $true) {
			if (dTest-Port -Name $ComputerName_str -Port $intPortToTry -Verbose) {$intPortToTry}
			else {Throw "machine '$ComputerName_str' not responding on port '$intPortToTry'. Valid port that is listening? Not continuing"}
		} ## end if
		else {$intPortToTry}
	) ## end subexpression
	$strURIToUse = if ($intPortToUse -eq 443) {"https://${ComputerName_str}/api/json$strRestApiSpecificUriPiece$RestCommand_str"}
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


<#	.Description
	Helper function to uniformly handle web exceptions, returning valuable info as to the exception response, if any
#>
function _Invoke-WebExceptionErrorCatchHandling {
	param (
		## the URI that was being used when exception was encountered
		[parameter(Mandatory=$true)][string]$URI,
		## the error record that was caught
		[parameter(Mandatory=$true)][System.Management.Automation.ErrorRecord]$ErrorRecord
	) ## end param
	process {
		Write-Verbose -Verbose "Uh-oh -- something went awry trying to get data from that URI ('$URI')"
		if ($null -ne $ErrorRecord.Exception.InnerException.Response) {
			Write-Verbose -Verbose "(exception status of '$($ErrorRecord.Exception.InnerException.Status)', message of '$($ErrorRecord.Exception.InnerException.Message)')"
			## get the Response from the InnerException if available
			Write-Verbose -Verbose ("Inner WebException response:`n{0}" -f ([System.IO.StreamReader]($ErrorRecord.Exception.InnerException.Response.GetResponseStream())).ReadToEnd())
		} ## end if
		if ($null -ne $ErrorRecord.Exception.Response) {
			## how to get the rest of the exception response; based on a stackoverflow.com thread, of course
			$oStreamReader = New-Object System.IO.StreamReader($ErrorRecord.Exception.Response.GetResponseStream())
			$oStreamReader.BaseStream.Position = 0; $oStreamReader.DiscardBufferedData()
			$strExceptionResponseBody = $oStreamReader.ReadToEnd()
			Write-Verbose -Verbose "(exception status of '$($ErrorRecord.Exception.Status)', message of '$($ErrorRecord.Exception.Message)')"
			## get the Response from the Exception if available
			Write-Verbose -Verbose ("WebException response:`n{0}" -f $strExceptionResponseBody)
		} ## end else if
		## if both of those were $null, say that there was no additional web exception response
		if ($null -eq $ErrorRecord.Exception.InnerException.Response -and $null -eq $ErrorRecord.Exception.Response) {Write-Verbose -Verbose "no additional web exception response value to report"}
		## throw the caught error (instead of breaking, which adversely affects subsequent calls; say, if in a try/catch statement in a Foreach-Object loop, "break" breaks all the way out of the foreach-object, vs. using Throw to just throw the error for this attempt, and then letting the calling item continue in the Foreach-Object
		Throw $ErrorRecord
		#Write-Error $ErrorRecord -Category ConnectionError -RecommendedAction "Check creds, URL ('$($hshParamsForRequest["Uri"])') -- valid?"; break;
	} ## end process
} ## end fn


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
			else {"Connected to {0} XMS servers:  {1}." -f $intNumConnectedXmsServers, (($Global:DefaultXmsServers | Foreach-Object {$_.ComputerName}) -Join ", ")}
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
	$strItemType_plural = ([RegEx]("^(/api/json)?(/v\d{1,2})?/types/(?<itemType>[^/]+)/")).Match(([System.Uri]($URI_str)).AbsolutePath).Groups.Item("itemType").Value
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
		$StringToConvert_arr | Foreach-Object {
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


function _New-ScheduleDisplayString {
<#	.Description
	Helper function to take a schedule type and schedule "triplet" and return a display string
	.Outputs
	String
#>
	param (
		## Type of scheduler:  explicit or interval
		[parameter(Mandatory=$true)][ValidateSet("explicit","interval")][string]$ScheduleType,
		## Schedule string.  Like "hrs:mins:secs" for interval scheduler, or "intDayOfWeek_1-basedIndex:h:min" for explicit scheduler
		[string]$ScheduleTriplet
	)
	process {
		[int]$intSchedPiece0,[int]$intSchedPiece1,[int]$intSchedPiece2 = $ScheduleTriplet.Split(":")
		Switch ($ScheduleType) {
			"explicit" {
				## the day of the week is either "Every day" when the first piece is 0, or the <piece0 - 1> for the DayOfWeek enum (zero-based index)
				$strDayOfWeek = if ($intSchedPiece0 -eq 0) {"Every day"} else {[System.Enum]::GetName([System.DayOfWeek], ($intSchedPiece0 - 1))}
				$strTimeOfDay = "{0:00}:{1:00}" -f $intSchedPiece1, $intSchedPiece2
				"{0} at {1}" -f $strDayOfWeek, $strTimeOfDay
			} ## end case
			"interval" {
				$strHrOutput = if ($intSchedPiece0 -gt 0) {"$intSchedPiece0 hour{0}" -f $(if ($intSchedPiece0 -ne 1) {"s"})}
				$strMinOutput = if ($intSchedPiece1 -gt 0) {"$intSchedPiece1 min{0}" -f $(if ($intSchedPiece1 -ne 1) {"s"})}
				$strSecOutput = if ($intSchedPiece2 -gt 0) {"$intSchedPiece2 sec{0}" -f $(if ($intSchedPiece2 -ne 1) {"s"})}
				(@("Every",$strHrOutput,$strMinOutput,$strSecOutput) | Where-Object {$null -ne $_}) -join " "
			} ## end case
			default {Write-Verbose "scheduler type '$ScheduleType' not expected"}
		} ## end switch
	} ## end process
} ## end fn


function _Get-NumSecondSinceUnixEpoch {
<#	.Description
	Helper function to get the number of whole seconds it has been since the UNIX Epoch until the "now" local datetime
#>
	process {
		[int64](New-TimeSpan -Start (Get-Date "01 Jan 1970 00:00:00").ToLocalTime()).TotalSeconds
	} ## end process
} ## end fn


function _Get-LocalDatetimeFromUTCUnixEpoch {
<#	.Description
	Helper function to get the current, local datetime from a UNIX Epoch time
#>
	param(
		## UNIX Epoch time (number of seconds since 00:00:00 on 01 Jan 1970)
		[Double]$UnixEpochTime
	) ## end param

	process {
		(Get-Date "01 Jan 1970 00:00:00").AddSeconds($UnixEpochTime).ToLocalTime()
	} ## end process
} ## end fn


function _New-ObjListFromProperty {
<#	.Description
	Helper function to create objects from typical XIO "list" object arrays, which have members that are like:  <someLongId>, <theObjectDisplayName>, <theObjectIndex>
#>
	param(
		## The prefix to add to the Id property name
		[string]$IdPropertyPrefix,
		## The array of objects from which to get Id, Name, and Index
		[PSObject[]]$ObjectArray
	) ## end param

	process {
		$ObjectArray | Where-Object {($null -ne $_) -and ($null -ne $_[0])} | Foreach-Object {
			New-Object -TypeName PSObject -Property ([ordered]@{
				"${IdPropertyPrefix}Id" = $_[0]
				Name = $_[1]
				Index = $_[2]
			}) ## end new-object
		} ## end foreach-object
	} ## end process
} ## end fn


function _New-ObjListFromProperty_byObjName {
<#	.Description
	Helper function to eventually call function to create objects from typical XIO "list" object arrays, based on the object type name (like Storagecontroller or Switch (IBSwitch))
#>
	param(
		## The name of the object type, like Storagecontroller or Switch
		[string]$Name,
		## The array of objects from which to get Id, Name, and Index
		[PSObject[]]$ObjectArray
	) ## end param

	begin {
		## mapping of "raw" object name from API to desired display name used for object ID prefix in subsequent helper function
		$hshObjNameToObjPrefixMap = @{
			Brick = "Brick"
			Cluster = "Cluster"
			ConsistencyGroup = "ConsistencyGrp"
			DataProtectionGroup = "DataProtectionGrp"
			Folder = "Folder"
			Initiator = "Initiator"
			InitiatorGroup = "InitiatorGrp"
			Scheduler = "SnapshotScheduler"
			SnapSet = "SnapshotSet"
			Storagecontroller = "StorageController"
			"Switch" = "IbSwitch"
			Tag = "Tag"
			TargetGroup = "TargetGrp"
			Volume = "Vol"
		} ## end hashtable
		$strObjPrefixToUse = if ($hshObjNameToObjPrefixMap.ContainsKey($Name)) {$hshObjNameToObjPrefixMap[$Name]} else {"UnkItemType"}
	} ## end begin

	process {
		## for some objects (like ports with no connection on them), the Name value is "none", indicating that it has no connection; return nothing for those
		if ($Name -ne "none") {_New-ObjListFromProperty -IdPropertyPrefix $strObjPrefixToUse -ObjectArray $ObjectArray}
	} ## end process
} ## end fn


<#	.Description
	Helper function to take "raw" API object and create new XIO Item Info object for return to consumer
#>
function _New-ObjectFromApiObject {
	param (
		## Object returned from API call and that has all of the juicy properties from which to make an object to return to the user
		[parameter(Mandatory=$true)][PSObject]$ApiObject,
		## Item type as defined by the REST API (plural)
		[parameter(Mandatory=$true)][String]$ItemType,
		## The XMS Computer Name from which this object came, for populating that property on the return object
		[parameter(Mandatory=$true)][String]$ComputerName,
		## The URI for this item
		[parameter(Mandatory=$true)][String]$ItemUri,
		## Switch:  is this object from the API call that returns a "full" object view, instead of from other subsequent calls to the API (such as calls to v1 API)?
		[Switch]$UsingFullApiObjectView
	)
	## FYI:  for all types except Events, $ApiObject is an array of items whose Content property is a PSCustomObject with all of the juicy properties of info
	##   for type Events, $ApiObject is one object with an Events property, which is an array of PSCustomObject
	$ApiObject | Foreach-Object {
		$oThisResponseObj = $_
		## FYI:  name of the property of the response object that holds the details about the XIO item is "content" for nearly all types, but "events" for event type
		## if the item type is events, access the "events" property of the response object; else, if "performance", use whole object, else, access the "Content" property
		$(if ($ItemType -eq "events") {$oThisResponseObj.$ItemType} elseif (($ItemType -eq "performance") -or $UsingFullApiObjectView) {$oThisResponseObj} else {$oThisResponseObj."Content"}) | Foreach-Object {
			$oThisResponseObjectContent = $_
			## the TypeName to use for the new object
			$strPSTypeNameForNewObj = Switch ($ItemType) {
				"infiniband-switches" {"XioItemInfo.InfinibandSwitch"; break}
				"performance" {"XioItemInfo.PerformanceCounter"; break}
				"schedulers" {"XioItemInfo.SnapshotScheduler"; break}
				"xms" {"XioItemInfo.XMS"; break}
				default {"XioItemInfo.$((Get-Culture).TextInfo.ToTitleCase($_.TrimEnd('s').ToLower()).Replace('-',''))"}
			} ## end switch
			## make new object(s) with some juicy info (and a new property for the XMS "computer" name used here); usually just one object returned per call to _New-Object_from..., but if of item type "performance", could be multiple
			_New-Object_fromItemTypeAndContent -argItemType $ItemType -oContent $oThisResponseObjectContent -PSTypeNameForNewObj $strPSTypeNameForNewObj | Foreach-Object {
				$oObjToReturn = $_
				## set ComputerName property
				$oObjToReturn.ComputerName = $ComputerName
				## set URI property that uniquely identifies this object
				$oObjToReturn.Uri = $ItemUri
				## if this is a PerformanceCounter item, add the EntityType property
				if ("performance" -eq $ItemType_str) {$oObjToReturn.EntityType = $strPerformanceCounterEntityType}
				## return the object
				return $oObjToReturn
			} ## end foreach-object
		} ## end foreach-object
	} ## end foreach-object
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
	## scriptblock to create a new, bare-bones XioItemInfo.Cluster object (useful for populating .Cluster property of objects)
	$sblkNewXioiteminfoClusterObj = {New-Object -TypeName XIOItemInfo.Cluster -Property @{Guid = $oContent."sys-id"[0]; Name = $oContent."sys-id"[1]; Index = $oContent."sys-id"[2]}}
	## if this is a PerformanceCounter object to be
	if ($argItemType -eq "performance") {
		## a new variable, to be clear by the name that this is not just a ".content" property of the API return -- it's the whole object
		$oFullPerfCounterReturn = $oContent
		## the .members values that are handled separately
		$arrMembersToAddManually = Write-Output name, guid, timestamp, index
		## for each set of counters, make a new object to return
		$oFullPerfCounterReturn.counters | Foreach-Object {
			$arrThisSetOfCounters = $_
			$hshPropertiesForNewObj = ([ordered]@{
				Name = $arrThisSetOfCounters[($oFullPerfCounterReturn.members.IndexOf("name"))]
				Guid = $arrThisSetOfCounters[($oFullPerfCounterReturn.members.IndexOf("guid"))]
				Datetime = (Get-Date "00:00:00 01 Jan 1970").AddMilliseconds($arrThisSetOfCounters[($oFullPerfCounterReturn.members.IndexOf("timestamp"))]).ToLocalTime()
				Index = $arrThisSetOfCounters[($oFullPerfCounterReturn.members.IndexOf("index"))]
				Granularity = $oFullPerfCounterReturn.granularity
			}) ## end hashtable

			## now, for the rest of the members for this returned-from-API performance object, add a key/value to the hashtable
			$oFullPerfCounterReturn.members | Where-Object {$arrMembersToAddManually -notcontains $_} | ForEach-Object -begin {$hshCounterObjProperties = @{}} -Process {
				$strThisMemberName = $_
				$intIndexToAccess = $oFullPerfCounterReturn.members.IndexOf($strThisMemberName)
				$hshCounterObjProperties[$strThisMemberName] = $arrThisSetOfCounters[$intIndexToAccess]
			} ## end foreach-object
			## add a new object as the value for the new Counters key in the overall hashtable
			$hshPropertiesForNewObj["Counters"] = New-Object -Type PSObject -Property $hshCounterObjProperties
			## create the actual object to eventually return
			New-Object -Type $PSTypeNameForNewObj -Property $hshPropertiesForNewObj
		} ## end foreach-object
	} ## end if
	## else, create new object as per usual
	else {
		$hshPropertyForNewObj = Switch ($argItemType) {
			"initiator-groups" {
				[ordered]@{
					## check for "sys-id" property (not present for this object type on API from XIOS v2.4)
					Cluster = $(if ($null -ne $oContent."sys-id") {& $sblkNewXioiteminfoClusterObj})
					Folder = _New-ObjListFromProperty -IdPropertyPrefix "Folder" -ObjectArray @(,$oContent."folder-id")
					Guid = $oContent.guid
					Index = $oContent.index
					InitiatorGrpId = $oContent."ig-id"[0]
					IOPS = [int64]$oContent.iops
					Name = $oContent.Name
					NumInitiator = $oContent."num-of-initiators"
					NumVol = $oContent."num-of-vols"
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
					Severity = $oContent."obj-severity"
					TagList = _New-ObjListFromProperty -IdPropertyPrefix "Tag" -ObjectArray $oContent."tag-list"
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"initiators" {
				[ordered]@{
					Certainty = $oContent.certainty
					## check for "sys-id" property (not present for this object type on API from XIOS v2.4)
					Cluster = $(if ($null -ne $oContent."sys-id") {& $sblkNewXioiteminfoClusterObj})
					ConnectionState = $oContent."initiator-conn-state"
					Guid = $oContent.guid
					Index = $oContent.index
					InitiatorGrpId = $oContent."ig-id"[0]
					InitiatorGroup = _New-ObjListFromProperty_byObjName -Name "InitiatorGroup" -ObjectArray (,$oContent."ig-id")
					InitiatorId = $oContent."initiator-id"[0]
					IOPS = [int64]$oContent.iops
					Name = $oContent.Name
					OperatingSystem = $oContent."operating-system"
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
					PortAddress = $oContent."port-address"
					PortType = $oContent."port-type"
					Severity = $oContent."obj-severity"
					TagList = _New-ObjListFromProperty -IdPropertyPrefix "Tag" -ObjectArray $oContent."tag-list"
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"bricks" {
				[ordered]@{
					BBU = _New-ObjListFromProperty -IdPropertyPrefix "BBU" -ObjectArray $oContent."ups-list"
					BrickGuid = $oContent."brick-guid"
					BrickId = $oContent."brick-id"
					Cluster = & $sblkNewXioiteminfoClusterObj
					ClusterName = $oContent."sys-id".Item(1)
					DAE = _New-ObjListFromProperty -IdPropertyPrefix "DAE" -ObjectArray $oContent."jbod-list"
					DataProtectionGroup = _New-ObjListFromProperty_byObjName -Name "DataProtectionGroup" -ObjectArray (,$oContent."rg-id")
					Guid = $oContent."brick-id"[0]
					Index = $oContent."index-in-system"
					Name = $oContent."brick-id".Item(1)
					## deprecated; replacing with StorageController
					NodeList = $oContent."node-list"
					## deprecated; replacing with NumStorageController
					NumNode = $oContent."num-of-nodes"
					NumSSD = $oContent."num-of-ssds"
					NumStorageController = $oContent."num-of-nodes"
					RGrpId = $oContent."rg-id"
					Severity = $oContent."obj-severity"
					## the SSD info, which is apparently in an object at index 3 in the "ssd-slot-array" property
					Ssd = $($oContent."ssd-slot-array" | Foreach-Object {_New-ObjListFromProperty -IdPropertyPrefix "Ssd" -ObjectArray (,$_[3])})
					SsdSlotInfo = $oContent."ssd-slot-array"
					State = $oContent."brick-state"
					StorageController = _New-ObjListFromProperty_byObjName -Name "StorageController" -ObjectArray $oContent."node-list"
					TagList = _New-ObjListFromProperty -IdPropertyPrefix "Tag" -ObjectArray $oContent."tag-list"
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"clusters" {
				## new API (v3) changes value provided for dedup-ratio; previously it was the percentage (like "0.4" for 2.5:1 dedupe); as of v3, it is the dedupe value (like 2.5 in the "2.5:1" text)
				#   check if "compression-factor" property exists; if so, this is at least API v3, and has the switched-up value for dedup-ratio
				$dblDedupeRatio = $(if ($null -ne $oContent."dedup-ratio") {if ($null -eq $oContent."compression-factor") {1/$oContent."dedup-ratio"} else {$oContent."dedup-ratio"}})
				[ordered]@{
					Brick = _New-ObjListFromProperty_byObjName -Name "Brick" -ObjectArray $oContent."brick-list"
					BrickList = $oContent."brick-list"
					ClusterId = $oContent."sys-id"[0]
					## available in 3.0 and up
					CompressionFactor = $(if ($null -ne $oContent."compression-factor") {$oContent."compression-factor"})
					## available in 3.0 and up
					CompressionMode = $(if ($null -ne $oContent."compression-mode") {$oContent."compression-mode"})
					ConfigurableVolumeType = $oContent."configurable-vol-type-capability"
					ConsistencyState = $oContent."consistency-state"
					## available in 3.x, but went away in v4.0.0-54 (beta) and v4.0.1-7; if not present on this object (due to say, older or newer XIOS/API version on this appliance), the data reduction rate _is_ either the dedupe ratio or the dedupe ratio * compression factor, if compression factor is not $null
					DataReduction = $(if ($null -ne $oContent."data-reduction-ratio") {$oContent."data-reduction-ratio"} else {if ($null -ne $oContent."compression-factor") {$dblDedupeRatio * $oContent."compression-factor"} else {$dblDedupeRatio}})
					DedupeRatio = $dblDedupeRatio
					## available in 2.4.0 and up
					EncryptionMode = $oContent."encryption-mode"
					## available in 2.4.0 and up
					EncryptionSupported = $oContent."encryption-supported"
					ExpansionDataTransferPct = $oContent."max-data-transfer-percent-done"
					FcPortSpeed = $oContent."fc-port-speed"
					FreespaceLevel = $oContent."free-ud-ssd-space-level"
					## older API version has "free-ud-ssd-space", whereas newer API version does not (as of 2.2.3 rel 25); so, using different math if the given property does not exist
					FreeSSDTB = $(if (Get-Member -Input $oContent -Name "free-ud-ssd-space") {$oContent."free-ud-ssd-space" / 1GB} else {($oContent."ud-ssd-space" - $oContent."ud-ssd-space-in-use") / 1GB})
					Guid = $oContent.guid
					Index = [int]$oContent.index
					InfinibandSwitch = _New-ObjListFromProperty_byObjName -Name "Switch" -ObjectArray $oContent."ib-switch-list"
					InfiniBandSwitchList = $oContent."ib-switch-list"
					IOPS = [int64]$oContent.iops
					LicenseId = $oContent."license-id"
					MaintenanceMode = $(if ($null -ne $oContent."under-maintenance") {$oContent."under-maintenance" -eq "false"})
					MemoryInUseGB = $(if ($null -ne $oContent."total-memory-in-use") {$oContent."total-memory-in-use" / 1KB})
					MemoryInUsePct = $(if ($null -ne $oContent."total-memory-in-use-in-percent") {$oContent."total-memory-in-use-in-percent"})
					NaaSysId = $oContent."naa-sys-id"
					Name = $oContent.Name
					NumBrick = $oContent."num-of-bricks"
					NumInfiniBandSwitch = $oContent."num-of-ib-switches"
					NumSSD = $oContent."num-of-ssds"
					NumVol = $oContent."num-of-vols"
					NumXenv = $oContent."num-of-xenvs"
					OverallEfficiency = $(if ($oContent."space-saving-ratio") {"{0}:1" -f ([Math]::Round(1/$oContent."space-saving-ratio", 0))})
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
					Severity = $oContent."obj-severity"
					## available in 3.0 and up
					SharedMemEfficiencyLevel = $oContent."shared-memory-efficiency-level"
					## available in 3.0 and up
					SharedMemInUseRatioLevel = $oContent."shared-memory-in-use-ratio-level"
					## available in 2.4.0 and up
					SizeAndCapacity = $oContent."size-and-capacity"
					SshFirewallMode = $oContent."ssh-firewall-mode"
					SWVersion = $oContent."sys-sw-version"
					SystemActivationDateTime = _Get-LocalDatetimeFromUTCUnixEpoch -UnixEpochTime $oContent."sys-activation-timestamp"
					SystemActivationTimestamp = $oContent."sys-activation-timestamp"
					SystemSN = $oContent."sys-psnt-serial-number"
					SystemState = $oContent."sys-state"
					SystemStopType = $oContent."sys-stop-type"
					TagList = _New-ObjListFromProperty -IdPropertyPrefix "Tag" -ObjectArray $oContent."tag-list"
					ThinProvSavingsPct = (1-$oContent."thin-provisioning-ratio") * 100
					TotProvTB = $oContent."vol-size" / 1GB
					TotSSDTB = $oContent."ud-ssd-space" / 1GB
					UpgradeState = $oContent."upgrade-state"
					UsedLogicalTB = $oContent."logical-space-in-use" / 1GB
					UsedSSDTB = $oContent."ud-ssd-space-in-use" / 1GB
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"data-protection-groups" {
				[ordered]@{
					Name = $oContent.name
					DataProtectionGrpId = $oContent."rg-id"[0]
					Guid = $oContent.guid
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
					RebalanceInProg = ("False","done" -notcontains $oContent."rebalance-in-progress")
					## the "raw" value returned from the API
					# RebalanceInProgRaw = $oContent."rebalance-in-progress"
					RebalanceProgress = $oContent."rebalance-progress"
					RebuildInProg = ("False","done" -notcontains $oContent."rebuild-in-progress")
					## the "raw" value returned from the API
					# RebuildInProgRaw = $oContent."rebuild-in-progress"
					RebuildPreventionReason = $oContent."rebuild-prevention-reason"
					RebuildProgress = [int]$oContent."rebuild-progress"
					Severity = $oContent."obj-severity"
					## the "raw" value returned from the API
					# SSDPrepInProgRaw = $oContent."ssd-preparation-in-progress"
					SSDPrepProgress = $oContent."ssd-preparation-progress"
					AvailableRebuild = $oContent."available-rebuilds"
					Brick = _New-ObjListFromProperty_byObjName -Name "Brick" -ObjectArray (,$oContent."brick-id")
					BrickName = $oContent."brick-id"[1]
					BrickIndex = $oContent."brick-id"[2]
					Cluster = & $sblkNewXioiteminfoClusterObj
					ClusterName = $oContent."sys-id"[1]
					ClusterIndex = $oContent."sys-id"[2]
					NumNode = $oContent."num-of-nodes"
					NumSSD = $oContent."num-of-ssds"
					NumStorageController = $oContent."num-of-nodes"
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
				$arrDirectObjsThatAreNotSubfolders = $(if (($oContent."subfolder-list" | Measure-Object).Count -eq 0) {$oContent."direct-list"} else {$oContent."direct-list" | Where-Object {($oContent."subfolder-list" | Foreach-Object {$_[0]}) -notcontains $_[0]}})
				[ordered]@{
					Name = $oContent.name
					Caption = $oContent.caption
					ColorHex = $oContent.color
					CreationTime = $(if ($null -ne $oContent."creation-time-long") {_Get-LocalDatetimeFromUTCUnixEpoch -UnixEpochTime ($oContent."creation-time-long" / 1000)})
					Index = $oContent.index
					InitiatorGroup = _New-ObjListFromProperty_byObjName -Name InitiatorGroup -ObjectArray $arrDirectObjsThatAreNotSubfolders
					## the initiator group IDs for IGs directly in this ig-folder, as determined by getting the IDs in the "direct-list" where said IDs are not also in the "subfolder-list" list of object IDs
					InitiatorGrpIdList = @($arrDirectObjsThatAreNotSubfolders | Foreach-Object {$_[0]})
					IOPS = [int64]$oContent.iops
					FolderId = $oContent."folder-id"[0]
					FullName = $oContent."folder-id"[1]
					Guid = $oContent.guid
					## the number of objects that are not subfolders; should equal ."direct-list".Count - ."num-of-subfolders"
					NumIG = ($arrDirectObjsThatAreNotSubfolders | Measure-Object).Count
					NumSubfolder = $oContent."num-of-subfolders"
					ObjectType = $oContent."object-type"
					ParentFolder = _New-ObjListFromProperty -IdPropertyPrefix Folder -ObjectArray @(,$oContent."parent-folder-id")
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
					Severity = $oContent."obj-severity"
					SubfolderList = _New-ObjListFromProperty_byObjName -Name "Folder" -ObjectArray $oContent."subfolder-list"
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"lun-maps" {
				[ordered]@{
					## check for "sys-id" property (not present for this object type on API from XIOS v2.4)
					Cluster = $(if ($null -ne $oContent."sys-id") {& $sblkNewXioiteminfoClusterObj})
					VolumeName = $oContent."vol-name"
					LunId = $oContent.lun
					LunMapId = $(if ($null -ne $oContent."mapping-id") {$oContent."mapping-id"[0]})
					Name = $(if ($null -ne $oContent."mapping-id") {$oContent."mapping-id"[1]})
					Guid = $oContent.guid
					## changed property name from "ig-name" after v0.6.0 release
					InitiatorGroup = $oContent."ig-name"
					InitiatorGrpIndex = $oContent."ig-index"
					TargetGrpName = $oContent."tg-name"
					TargetGrpIndex = $oContent."tg-index"
					## changed from lm-id to mapping-id in v2.4
					MappingId = $oContent."mapping-id"
					## available in 2.4.0 and up
					Index = $oContent.index
					MappingIndex = $oContent."mapping-index"
					Severity = $oContent."obj-severity"
					XmsId = $oContent."xms-id"
					VolumeIndex = $oContent."vol-index"
				} ## end ordered dictionary
				break} ## end case
			"ssds" {
				[ordered]@{
					BrickId = $oContent."brick-id"
					CapacityGB = $oContent."ssd-size-in-kb"/1MB
					Cluster = & $sblkNewXioiteminfoClusterObj
					DataProtectionGroup = _New-ObjListFromProperty_byObjName -Name "DataProtectionGroup" -ObjectArray (,$oContent."rg-id")
					DiagHealthState = $oContent."diagnostic-health-state"
					Enabled = ($oContent."enabled-state" -eq "enabled")
					EnabledState = $oContent."enabled-state"
					## available in 2.4.0 and up
					EncryptionStatus = $oContent."encryption-status"
					FWVersion = $oContent."fw-version"
					FWVersionError = $oContent."fw-version-error"
					Guid = $oContent.guid
					HealthState = $oContent."health-state"
					HWRevision = $oContent."hw-revision"
					IdLED = $oContent."identify-led"
					Index = $oContent."index"
					IOPS = [int64]$oContent."iops"
					LifecycleState = $oContent."fru-lifecycle-state"
					Model = $oContent."model-name"
					ModelName = $oContent."model-name"
					Name = $oContent.name
					ObjSeverity = $oContent."obj-severity"
					PartNumber = $oContent."part-number"
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
					RGrpId = $oContent."rg-id"
					SerialNumber = $oContent."serial-number"
					Severity = $oContent."obj-severity"
					SlotNum = $oContent."slot-num"
					SSDFailureReason = $oContent."ssd-failure-reason"
					SsdId = $oContent."ssd-id"[0]
					SSDLink1Health = $oContent."ssd-link1-health-state"
					SSDLink2Health = $oContent."ssd-link2-health-state"
					SSDPositionState = $oContent."ssd-position-state"
					SsdRGrpState = $oContent."ssd-rg-state"
					SsdUid = $oContent."ssd-uid"
					StatusLED = $oContent."status-led"
					SwapLED = $oContent."swap-led"
					SysId = $oContent."sys-id"
					TagList = _New-ObjListFromProperty -IdPropertyPrefix "Tag" -ObjectArray $oContent."tag-list"
					UsedGB = $oContent."ssd-space-in-use"/1MB
					UsefulGB = $oContent."useful-ssd-space"/1MB
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"storage-controllers" {
				[ordered]@{
					BiosFWVersion = $oContent."bios-fw-version"
					## hm, seems to be second item in the 'brick-id' property
					BrickName = $oContent."brick-id".Item(1)
					Cluster = & $sblkNewXioiteminfoClusterObj
					DataProtectionGroup = _New-ObjListFromProperty_byObjName -Name "DataProtectionGroup" -ObjectArray (,$oContent."rg-id")
					Enabled = ($oContent."enabled-state" -eq "enabled")
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
					FWVersion = $oContent."bios-fw-version"
					Guid = $oContent.guid
					HealthState = $oContent."node-health-state"
					## no overall HWRevision property, but adding here so that can be a hardwarebase object
					HWRevision = "n/a"
					IBAddr1 = $oContent."ib-addr1"
					IBAddr2 = $oContent."ib-addr2"
					IdLED = $oContent."identify-led"
					Index = $oContent.index
					IPMIAddr = $oContent."ipmi-addr"
					IPMIState = $oContent."ipmi-conn-state"
					## available in 2.4.0 and up
					JournalState = $oContent."journal-state"
					LifecycleState = $oContent."fru-lifecycle-state"
					## available in 2.4.0 and up
					MgmtPortSpeed = $oContent."mgmt-port-speed"
					## available in 2.4.0 and up
					MgmtPortState = $oContent."mgmt-port-state"
					MgrAddr = $oContent."node-mgr-addr"
					## no overall model property, but adding here so that can be a hardwarebase object
					Model = $null
					Name = $oContent.name
					NodeMgrConnState = $oContent."node-mgr-conn-state"
					NumSSD = $oContent."num-of-ssds"
					NumSSDDown = $oContent."ssd-dn"
					NumTargetDown = $oContent."targets-dn"
					OSVersion = $oContent."os-version"
					PartNumber = $oContent."part-number"
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
					## available in 2.4.0 and up
					SdrFWVersion = $oContent."sdr-fw-version"
					SerialNumber = $oContent."serial-number"
					Severity = $oContent."obj-severity"
					State = $oContent."backend-storage-controller-state"
					StatusLED = $oContent."status-led"
					StorageControllerId = $oContent."node-id"[0]
					SWVersion = $oContent."sw-version"
					TagList = _New-ObjListFromProperty -IdPropertyPrefix "Tag" -ObjectArray $oContent."tag-list"
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"target-groups" {
				[ordered]@{
					Cluster = & $sblkNewXioiteminfoClusterObj
					ClusterName = $oContent."sys-id"[1]
					Guid = $oContent.guid
					Index = $oContent.index
					Name = $oContent.name
					Severity = $oContent."obj-severity"
					SysId = $oContent."sys-id"
					TagList = _New-ObjListFromProperty -IdPropertyPrefix "Tag" -ObjectArray $oContent."tag-list"
					TargetGrpId = $oContent."tg-id"[0]
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"targets" {
				[ordered]@{
					Brick = _New-ObjListFromProperty_byObjName -Name "Brick" -ObjectArray (,$oContent."brick-id")
					BrickId = $oContent."brick-id"
					## check for "sys-id" property (not present for this object type on API from XIOS v2.4)
					Cluster = $(if ($null -ne $oContent."sys-id") {& $sblkNewXioiteminfoClusterObj})
					DriverVersion = $oContent."driver-version"  ## renamed from "driver-version"
					ErrorReason = $oContent."tar-error-reason"
					FCIssue = New-Object -Type PSObject -Property ([ordered]@{
						InvalidCrcCount = [int]$oContent."fc-invalid-crc-count"
						LinkFailureCount = [int]$oContent."fc-link-failure-count"
						LossOfSignalCount = [int]$oContent."fc-loss-of-signal-count"
						LossOfSyncCount = [int]$oContent."fc-loss-of-sync-count"
						NumDumpedFrame = [int]$oContent."fc-dumped-frames"
						PrimSeqProtErrCount = [int]$oContent."fc-prim-seq-prot-err-count"
					}) ## end New-Object
					FWVersion = $oContent."fw-version"  ## renamed from "fw-version"
					Guid = $oContent.guid
					Index = $oContent.index
					IOPS = [int64]$oContent.iops
					JumboFrameEnabled = $oContent."jumbo-enabled"
					MTU = $oContent.mtu
					Name = $oContent.name
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
					PortAddress = $oContent."port-address"
					PortMacAddress = ($oContent."port-mac-addr" -split "(\w{2})" | Where-Object {$_ -ne ""}) -join ":"
					PortSpeed = $oContent."port-speed"
					PortState = $oContent."port-state"
					PortType = $oContent."port-type"
					Severity = $oContent."obj-severity"
					StorageController = _New-ObjListFromProperty_byObjName -Name "StorageController" -ObjectArray (,$oContent."node-id")
					TagList = _New-ObjListFromProperty -IdPropertyPrefix "Tag" -ObjectArray $oContent."tag-list"
					TargetGroup = _New-ObjListFromProperty_byObjName -Name "TargetGroup" -ObjectArray (,$oContent."tg-id")
					TargetGrpId = $oContent."tg-id"
					TargetId = $oContent."tar-id"[0]
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			## snapshots and volumes have the same properties
			{"snapshots","volumes" -contains $_} {
				[ordered]@{
					Cluster = & $sblkNewXioiteminfoClusterObj
					Name = $oContent.name
					NaaName = $oContent."naa-name"
					VolSizeTB = $(if ($null -ne $oContent."vol-size") {$oContent."vol-size" / 1GB})
					VolId = $(if ($null -ne $oContent."vol-id") {$oContent."vol-id"[0]})  ## renamed from "vol-id"
					AlignmentOffset = $oContent."alignment-offset"  ## renamed from "alignment-offset"
					AncestorVolId = $oContent."ancestor-vol-id"  ## renamed from "ancestor-vol-id"
					DestSnapList = $oContent."dest-snap-list"  ## renamed from "dest-snap-list"
					Folder = _New-ObjListFromProperty_byObjName -Name "Folder" -ObjectArray (,$oContent."folder-id")
					LBSize = $oContent."lb-size"  ## renamed from "lb-size"
					NumDestSnap = $oContent."num-of-dest-snaps"  ## renamed from "num-of-dest-snaps"
					NumLunMap = $oContent."num-of-lun-mappings"
					NumLunMapping = $oContent."num-of-lun-mappings"
					LunMapList = $oContent."lun-mapping-list" | Where-Object {$null -ne $_} | Foreach-Object {
						New-Object -Type PSObject -Property ([ordered]@{
							InitiatorGroup = _New-ObjListFromProperty_byObjName -Name "InitiatorGroup" -ObjectArray (,$_[0])
							TargetGroup = _New-ObjListFromProperty_byObjName -Name "TargetGroup" -ObjectArray (,$_[1])
							LunId = $_[2]
						}) ## end New-Object
					} ## end foreach-object
					LunMappingList = $oContent."lun-mapping-list"
					Guid = $oContent.guid
					## the initiator group IDs for IGs for this volume; Lun-Mapping-List property is currently array of @( @(<initiator group ID string>, <initiator group name>, <initiator group object index number>), @(<target group ID>, <target group name>, <target group object index number>), <host LUN ID>)
					InitiatorGrpIdList = @($(if (($oContent."lun-mapping-list" | Measure-Object).Count -gt 0) {$oContent."lun-mapping-list" | Foreach-Object {$_[0][0]}}))
					## available in 2.4.0 and up
					UsedLogicalTB = $(if ($null -ne $oContent."logical-space-in-use") {$oContent."logical-space-in-use" / 1GB})
					IOPS = $oContent.iops
					Index = $oContent.index
					## available in 3.0 and up
					Compressible = $oContent.compressible
					CreationTime = $(if ($null -ne $oContent."creation-time") {[System.DateTime]$oContent."creation-time"})
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
					Severity = $oContent."obj-severity"
					SmallIORatio = $oContent."small-io-ratio"
					SmallIORatioLevel = $oContent."small-io-ratio-level"
					SnapGrpId = $oContent."snapgrp-id"
					SnapshotType = $oContent."snapshot-type"
					TagList = _New-ObjListFromProperty -IdPropertyPrefix "Tag" -ObjectArray $oContent."tag-list"
					UnalignedIORatio = $oContent."unaligned-io-ratio"
					UnalignedIORatioLevel = $oContent."unaligned-io-ratio-level"
					SysId = $oContent."sys-id"
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"volume-folders" {
				[ordered]@{
					Caption = $oContent.caption
					ColorHex = $oContent.color
					CreationTime = $(if ($null -ne $oContent."creation-time-long") {_Get-LocalDatetimeFromUTCUnixEpoch -UnixEpochTime ($oContent."creation-time-long" / 1000)})
					Name = $oContent.name
					ParentFolder = $oContent."parent-folder-id"[1]
					NumVol = [int]$oContent."num-of-vols"
					VolSizeTB = $oContent."vol-size" / 1GB
					FolderId = $oContent."folder-id"[0]
					Guid = $oContent.guid
					ParentFolderId = $oContent."parent-folder-id"[0]
					NumChild = [int]$oContent."num-of-direct-objs"
					NumSubfolder = [int]$oContent."num-of-subfolders"
					ObjectType = $oContent."object-type"
					SubfolderList = _New-ObjListFromProperty_byObjName -Name "Folder" -ObjectArray $oContent."subfolder-list"
					## the volume IDs for volumes directly in this volume-folder, as determined by getting the IDs in the "direct-list" where said IDs are not also in the "subfolder-list" list of object IDs
					VolIdList = @($oContent."direct-list" | Foreach-Object {$_[0]} | Where-Object {($oContent."subfolder-list" | Foreach-Object {$_[0]}) -notcontains $_})
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
					Severity = $oContent."obj-severity"
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"xenvs" {
				[ordered]@{
					Brick = _New-ObjListFromProperty_byObjName -Name "Brick" -ObjectArray (,$oContent."brick-id")
					BrickId = $oContent."brick-id"
					Cluster = & $sblkNewXioiteminfoClusterObj
					CPUUsage = $oContent."cpu-usage"
					Guid = $oContent.guid
					Index = $oContent.index
					Name = $oContent.name
					NumMdl = $oContent."num-of-mdls"
					NumModule = $oContent."num-of-mdls"
					Severity = $oContent."obj-severity"
					StorageController = _New-ObjListFromProperty_byObjName -Name "StorageController" -ObjectArray (,$oContent."node-id")
					TagList = _New-ObjListFromProperty -IdPropertyPrefix "Tag" -ObjectArray $oContent."tag-list"
					XEnvId = $oContent."xenv-id"[0]
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
			"alerts" {
				[ordered]@{
					Name = $oContent.name
					AlertCode = [string]$oContent."alert-code"
					AlertType = $oContent."alert-type"
					AssociatedObjId = $oContent."assoc-obj-id"[0]
					AssociatedObjIndex = $oContent."assoc-obj-index"
					AssociatedObjName = $oContent."assoc-obj-name"
					Class = $oContent."class-name"
					ClusterId = $oContent."sys-id"[0]
					ClusterName = $oContent."sys-name"
					## is milliseconds since UNIX epoch (not seconds like a "regular" UNIX epoch time)
					CreationTime = _Get-LocalDatetimeFromUTCUnixEpoch -UnixEpochTime ($oContent."raise-time" / 1000)
					Description = $oContent.description
					Guid = $oContent.guid
					Index = $oContent.index
					Severity = $oContent.severity
					State = $oContent."alert-state"
					Threshold = $oContent.threshold
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"bbus" {
				[ordered]@{
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
					## this should be the same value as the .guid property
					BBUId = $oContent."ups-id"[0]
					Brick = _New-ObjListFromProperty -IdPropertyPrefix "Brick" -ObjectArray @(,$oContent."brick-id")
					BrickId = $oContent."brick-id"
					BypassActive = ([string]"true" -eq $oContent."is-bypass-active")
					ConnectedToSC = ($oContent."ups-conn-state" -eq "connected")
					Cluster = & $sblkNewXioiteminfoClusterObj
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
					Name = $oContent.name
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
					Severity = $oContent."obj-severity"
					Status = $oContent."ups-status"
					StatusLED = $oContent."status-led"
					StorageController = _New-ObjListFromProperty -IdPropertyPrefix "StorageController" -ObjectArray @($oContent."monitoring-nodes-obj-id-list" | Select-Object -First 1)
					TagList = _New-ObjListFromProperty -IdPropertyPrefix "Tag" -ObjectArray $oContent."tag-list"
					UPSAlarm = $oContent."ups-alarm"
					UPSOverloaded = ([string]"true" -eq $oContent."is-ups-overload")
					SysId = $oContent."sys-id"
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"consistency-groups" {
				[ordered]@{
					Name = $oContent.name
					Certainty = $oContent.certainty
					Cluster = & $sblkNewXioiteminfoClusterObj
					ClusterId = $oContent."sys-id"[0]
					ClusterName = $oContent."sys-id"[1]
					CreatedByApp = $oContent."created-by-app"
					ConsistencyGrpId = $oContent."cg-id"[0]
					ConsistencyGrpShortId = $oContent."cg-short-id"
					Guid = $oContent.guid
					Index = $oContent.index
					NumVol = $oContent."num-of-vols"
					Severity = $oContent."obj-severity"
					SysId = $oContent."sys-id"
					TagList = _New-ObjListFromProperty -IdPropertyPrefix "Tag" -ObjectArray $oContent."tag-list"
					VolList = _New-ObjListFromProperty -IdPropertyPrefix "Vol" -ObjectArray $oContent."vol-list"
					## $null?  (property not defined on Consistency-groups?)
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"daes" {
				[ordered]@{
					Brick = _New-ObjListFromProperty -IdPropertyPrefix "Brick" -ObjectArray @(,$oContent."brick-id")
					BrickId = $oContent."brick-id"
					Cluster = & $sblkNewXioiteminfoClusterObj
					ClusterId = $oContent."sys-id"[0]
					ClusterName = $oContent."sys-id"[1]
					## this should be the same value as the .guid property
					DAEId = $oContent."jbod-id"[0]
					FWVersion = $oContent."fw-version"
					Guid = $oContent.guid
					HWRevision = $oContent."hw-revision"
					IdLED = $oContent."identify-led"
					Index = $oContent.index
					LifecycleState = $oContent."fru-lifecycle-state"
					Model = $oContent."model-name"
					Name = $oContent.name
					NumDAEController = [int]$oContent."num-of-jbod-controllers"
					NumDAEPSU = [int]$oContent."num-of-jbod-psus"
					PartNumber = $oContent."part-number"
					ReplacementReason = $oContent."fru-replace-failure-reason"
					SerialNumber = $oContent."serial-number"
					Severity = $oContent."obj-severity"
					StatusLED = $oContent."status-led"
					SysId = $oContent."sys-id"
					TagList = _New-ObjListFromProperty -IdPropertyPrefix "Tag" -ObjectArray $oContent."tag-list"
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"dae-controllers" {
				[ordered]@{
					Brick = _New-ObjListFromProperty -IdPropertyPrefix "Brick" -ObjectArray @(,$oContent."brick-id")
					BrickId = $oContent."brick-id"
					Cluster = & $sblkNewXioiteminfoClusterObj
					ClusterId = $oContent."sys-id"[0]
					ClusterName = $oContent."sys-id"[1]
					ConnectivityState = $oContent."jbod-controller-connectivity-state"
					DAE = _New-ObjListFromProperty -IdPropertyPrefix "DAE" -ObjectArray (,$oContent."jbod-id")
					DAEId = $oContent."jbod-id"[0]
					DAEControllerId = $oContent."jbod-controller-id"[0]
					Enabled = ($oContent."enabled-state" -eq "enabled")
					FailureReason = $oContent."failure-reason"
					FWVersion = $oContent."fw-version"
					FWVersionError = $oContent."fw-version-error"
					Guid = $oContent.guid
					HealthLevel = $oContent."lcc-health-level"
					HWRevision = $oContent."hw-revision"
					Identification = $oContent.identification
					IdLED = $oContent."identify-led"
					Index = $oContent.index
					LifecycleState = $oContent."fru-lifecycle-state"
					Location = $oContent.location
					Name = $oContent.name
					Model = $oContent."model-name"
					PartNumber = $oContent."part-number"
					ReplacementReason = $oContent."fru-replace-failure-reason"
					SAS = New-Object -Type PSObject -Property ([ordered]@{
						ConnectivityState = $oContent."sas-connectivity-state"
						PortInfo = $(1..2 | Foreach-Object {
							$intI = $_
							New-Object -Type PSObject -Property ([ordered]@{
								Location = $oContent."sas${intI}-port-location"
								NodeIndex = [int]$oContent."sas${intI}-node-index"
								Port = "SAS${intI}"
								PortInNodeIndex = [int]$oContent."sas${intI}-port-in-node-index"
								Rate = $oContent."sas${intI}-port-rate"
								State = $oContent."sas${intI}-port-state"
								XbrickIndex = [int]$oContent."sas${intI}-brick-index"
							}) ## end new-object
						} ## end Foreach-Object
						) ## end sub-expression
					}) ## end new-object
					SerialNumber = $oContent."serial-number"
					Severity = $oContent."obj-severity"
					StatusLED = $oContent."status-led"
					SysId = $oContent."sys-id"
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"dae-psus" {
				[ordered]@{
					Brick = _New-ObjListFromProperty -IdPropertyPrefix "Brick" -ObjectArray @(,$oContent."brick-id")
					BrickId = $oContent."brick-id"
					Cluster = & $sblkNewXioiteminfoClusterObj
					DAE = _New-ObjListFromProperty -IdPropertyPrefix "DAE" -ObjectArray (,$oContent."jbod-id")
					DAEPSUId = $oContent."jbod-psu-id"[0]
					Enabled = ($oContent."enabled-state" -eq "enabled")
					FWVersion = $oContent."fw-version"
					FWVersionError = $oContent."fw-version-error"
					Guid = $oContent.guid
					HWRevision = $oContent."hw-revision"
					Identification = $oContent.identification
					IdLED = $oContent."identify-led"
					Index = $oContent.index
					Input = $oContent.input
					LifecycleState = $oContent."fru-lifecycle-state"
					Location = $oContent.location
					Model = $oContent."model-name"
					Name = $oContent.name
					PartNumber = $oContent."part-number"
					PowerFailure = $oContent."power-failure"
					PowerFeed = $oContent."power-feed"
					ReplacementReason = $oContent."fru-replace-failure-reason"
					SerialNumber = $oContent."serial-number"
					Severity = $oContent."obj-severity"
					StatusLED = $oContent."status-led"
					SysId = $oContent."sys-id"
					## $null?  (property not defined on dae-psus?)
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"email-notifier" {
				[ordered]@{
					Name = $oContent.name
					CompanyName = $oContent."company-name"
					ContactDetails = $oContent."contact-details"
					Enabled = ($oContent.enabled -eq "true")
					Frequency = New-TimeSpan -Seconds $oContent.frequency
					FrequencySec = [int]$oContent.frequency
					Guid = $oContent.guid
					Index = $oContent.index
					MailRelayAddress = $oContent."mail-relay-address"
					MailUsername = $oContent."mail-user"
					ProxyAddress = $oContent."proxy-address"
					ProxyPort = $oContent."proxy-port"
					ProxyUser = $oContent."proxy-user"
					Recipient = $oContent.recipients
					Sender = $oContent."sender"
					Severity = $oContent."obj-severity"
					TransportProtocol = $oContent.transport
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"infiniband-switches" {
				[ordered]@{
					Cluster = & $sblkNewXioiteminfoClusterObj
					Enabled = ($oContent."enabled-state" -eq "enabled")
					Fan1RPM = [int]$oContent."fan-1-rpm"
					Fan2RPM = [int]$oContent."fan-2-rpm"
					Fan3RPM = [int]$oContent."fan-3-rpm"
					Fan4RPM = [int]$oContent."fan-4-rpm"
					FanDrawerStatus = $oContent."fan-drawer-status"
					FWId = $oContent."fw-psid"
					FWVersion = $oContent."fw-version"
					FWVersionError = $oContent."fw-version-error"
					Guid = $oContent.guid
					HWRevision = $oContent."hw-revision"
					IbSwitchId = $oContent."ib-switch-id"[0]
					IdLED = $oContent."identify-led"
					Index = $oContent.index
					InterswitchIb1Port = $oContent."inter-switch-ib1-port-state"
					InterswitchIb2Port = $oContent."inter-switch-ib2-port-state"
					LifecycleState = $oContent."fru-lifecycle-state"
					Model = $oContent."model-name"
					Name = $oContent.name
					PartNumber = $oContent."part-number"
					Port = $oContent.ports | Foreach-Object {
						New-Object -TypeName PSObject -Property ([ordered]@{
							PortNumber = $_[0]
							SpeedGbps = $_[1]
							State = $_[2]
							Connection =  _New-ObjListFromProperty_byObjName -Name $_[4] -ObjectArray (,$_[3])
						}) ## end new-object
					} ## end foreach-object
					ReplacementReason = $oContent."fru-replace-failure-reason"
					SerialNumber = $oContent."serial-number"
					Severity = $oContent."obj-severity"
					StatusLED = $oContent."status-led"
					SysId = $oContent."sys-id"
					TagList = _New-ObjListFromProperty -IdPropertyPrefix "Tag" -ObjectArray $oContent."tag-list"
					TemperatureSensor = $oContent."temp-sensors-array" | Foreach-Object {
						New-Object -TypeName PSObject -Property ([ordered]@{
							SensorDescription = $_[0]
							TemperatureC = $_[1]
							TemperatureF = ($_[1] * 9/5) + 32
						}) ## end new-object
					} ## end foreach-object
					VoltageSensor = $oContent."voltage-sensors-array" | Foreach-Object {
						New-Object -TypeName PSObject -Property ([ordered]@{
							SensorDescription = $_[0]
							Voltage = $_[1]
						}) ## end new-object
					} ## end foreach-object
					WrongSCConnection = $oContent."wrong-sc-connection-detected"
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"ldap-configs" {
				[ordered]@{
					Name = $oContent.name
					BindDN = $oContent."bind-dn"
					CACertData = $oContent."ca-cert-data"
					CACertFile = $oContent."ca-cert-file"
					CacheExpireH = [int]$oContent."cache-expire-hours"
					Guid = $oContent.guid
					Index = $oContent.index
					Role = $oContent.roles
					SearchBaseDN = $oContent."search-base"
					SearchFilter = $oContent."search-filter"
					ServerUrl = $oContent."server-url"
					ServerUrlExample = $oContent."server-urls"
					## LDAP configs do not have this yet, apparently; adding here so class can still inherit from InfoBase object type
					Severity = $oContent."obj-severity"
					TimeoutSec = [int]$oContent.timeout
					UserToDnRule = $oContent."user-to-dn-rule"
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"local-disks" {
				[ordered]@{
					Name = $oContent.name
					BrickId = $oContent."brick-id"
					Cluster = & $sblkNewXioiteminfoClusterObj
					ClusterId = $oContent."sys-id"[0]
					ClusterName = $oContent."sys-id"[1]
					EncryptionStatus = $oContent."encryption-status"
					Enabled = ($oContent."enabled-state" -eq "enabled")
					ExpectedType = $oContent."local-disk-expected-type"
					FailureReason = $oContent."disk-failure"
					FWVersion = $oContent."fw-version"
					FWVersionError = $oContent."fw-version-error"
					Guid = $oContent.guid
					HWRevision = $oContent."hw-revision"
					IdLED = $oContent."identify-led"
					Index = $oContent.index
					LifecycleState = $oContent."fru-lifecycle-state"
					LocalDiskId = $oContent."local-disk-id"[0]
					Model = $oContent."model-name"
					NumBadSector = $oContent."num-bad-sectors"
					PartNumber = $oContent."part-number"
					Purpose = $oContent."local-disk-purpose"
					ReplacementReason = $oContent."fru-replace-failure-reason"
					## have to string-manip to get this and Wwn -- weak
					SerialNumber = $oContent."local-disk-uid".Split("_")[3].Trim("][")
					Severity = $oContent."obj-severity"
					SlotNum = $oContent."slot-num"
					StatusLED = $oContent."status-led"
					StorageControllerId = $oContent."node-id"[0]
					StorageControllerName = $oContent."node-id"[1]
					SysId = $oContent."sys-id"
					TagList = _New-ObjListFromProperty -IdPropertyPrefix "Tag" -ObjectArray $oContent."tag-list"
					Type = $oContent."local-disk-type"
					Wwn = $oContent."local-disk-uid".Split("_")[1].Trim("][")
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"schedulers" {
				[ordered]@{
					Name = $oContent.name
					Guid = $oContent.guid
					Index = $oContent.index
					Enabled = ($oContent."enabled-state" -eq "enabled")
					LastActivated = $(if ($oContent."last-activation-time" -gt 0) {_Get-LocalDatetimeFromUTCUnixEpoch -UnixEpochTime $oContent."last-activation-time"})
					LastActivationResult = $oContent."last-activation-status"
					NumSnapToKeep = [int]$oContent."snapshots-to-keep-number"
					Retain = (New-TimeSpan -Seconds $oContent."snapshots-to-keep-time")
					Schedule = (_New-ScheduleDisplayString -ScheduleType $oContent."scheduler-type" -ScheduleTriplet $oContent.schedule)
					SnappedObject = New-Object -Type PSObject -Property ([ordered]@{
						Guid = $oContent."snapped-object-id"[0]
						Index = $oContent."snapped-object-index"
						Name = $oContent."snapped-object-id"[1]
						Type = $oContent."snapped-object-type"
					}) ## end new-object
					SnapshotSchedulerId = $oContent.guid
					SnapType = $oContent."snapshot-type"
					State = $oContent."scheduler-state"
					Suffix = $oContent.suffix
					Type = $oContent."scheduler-type"
				} ## end ordered dictionary
				break} ## end case
			"slots" {
				[ordered]@{
					Name = $oContent.name
					BrickId = $oContent."brick-id"
					Cluster = & $sblkNewXioiteminfoClusterObj
					ErrorReason = $oContent."slot-error-reason"
					FailureReason = $oContent."failure-reason"
					Guid = $oContent.guid
					Index = $oContent.index
					SlotNum = [int]$oContent."slot-num"
					SsdId = $oContent."ssd-o-signature"
					SsdModel = $oContent."product-model"
					SsdSizeGB = [Double]($oContent."ssd-size" / 1MB)
					SsdUid = $oContent."ssd-uid"
					State = $oContent."slot-state"
					## Slots do not have this yet, apparently; adding here so class can still inherit from InfoBase object type
					Severity = $oContent."obj-severity"
					SysId = $oContent."sys-id"
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"snapshot-sets" {
				[ordered]@{
					Name = $oContent.name
					Cluster = & $sblkNewXioiteminfoClusterObj
					ClusterId = $oContent."sys-id"[0]
					ClusterName = $oContent."sys-id"[1]
					ConsistencyGrpId = $(if ($null -ne $oContent."cg-id") {$oContent."cg-id"[0]})
					ConsistencyGrpName = $oContent."cg-name"
					## "creation-time-long" is milliseconds since UNIX epoch (instead of traditional seconds)
					CreationTime = _Get-LocalDatetimeFromUTCUnixEpoch -UnixEpochTime ($oContent."creation-time-long" / 1000)
					Guid = $oContent.guid
					Index = $oContent.index
					NumVol = $oContent."num-of-vols"
					Severity = $oContent."obj-severity"
					SnapshotSetId = $oContent."snapset-id"[0]
					SnapshotSetShortId = $oContent."snapset-short-id"
					SysId = $oContent."sys-id"
					TagList = _New-ObjListFromProperty -IdPropertyPrefix "Tag" -ObjectArray $oContent."tag-list"
					VolList = _New-ObjListFromProperty -IdPropertyPrefix "Vol" -ObjectArray $oContent."vol-list"
					## $null?  (property not defined on Consistency-groups?)
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"snmp-notifier" {
				[ordered]@{
					Name = $oContent.name
					AuthProtocol = $oContent."auth-protocol"
					Community = $oContent.community
					Enabled = ($oContent.enabled -eq "true")
					Guid = $oContent.guid
					HeartbeatFreqSec = [int]$oContent."heartbeat-frequency"
					Index = $oContent.index
					Port = [int]$oContent.port
					PrivacyProtocol = $oContent."priv-protocol"
					Recipient = $oContent.recipients
					Severity = $oContent."obj-severity"
					SNMPVersion = $oContent.version
					Username = $oContent.username
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"storage-controller-psus" {
				[ordered]@{
					Name = $oContent.name
					BrickId = $oContent."brick-id"
					Cluster = & $sblkNewXioiteminfoClusterObj
					Enabled = ($oContent."enabled-state" -eq "enabled")
					FWVersionError = $oContent."fw-version-error"
					Guid = $oContent.guid
					HWRevision = $oContent."hw-revision"
					Index = $oContent.index
					Input = $oContent.input
					LifecycleState = $oContent."fru-lifecycle-state"
					Location = $oContent.location
					Model = $oContent."model-name"
					PartNumber = $oContent."part-number"
					PowerFailure = $oContent."power-failure"
					PowerFeed = $oContent."power-feed"
					ReplacementReason = $oContent."fru-replace-failure-reason"
					SerialNumber = $oContent."serial-number"
					Severity = $oContent."obj-severity"
					StatusLED = $oContent."status-led"
					StorageController = _New-ObjListFromProperty -IdPropertyPrefix "StorageController" -ObjectArray (,$oContent."node-id")
					StorageControllerPSUId = $oContent."node-psu-id"[0]
					SysId = $oContent."sys-id"
					## $null?  (property not defined on storage-controller-psus?)
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"syslog-notifier" {
				[ordered]@{
					Name = $oContent.name
					Enabled = ($oContent.enabled -eq "true")
					Guid = $oContent.guid
					Index = $oContent.index
					Severity = $oContent."obj-severity"
					SyslogNotifierId = $oContent.guid
					Target = $oContent.targets
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"tags" {
				[ordered]@{
					Name = $oContent.name
					Caption = $oContent.caption
					ChildTagList = _New-ObjListFromProperty -IdPropertyPrefix "Tag" -ObjectArray $oContent."child-list"
					ColorHex = $oContent.color
					## "creation-time-long" is milliseconds since UNIX epoch (instead of traditional seconds)
					CreationTime = _Get-LocalDatetimeFromUTCUnixEpoch -UnixEpochTime ($oContent."creation-time-long" / 1000)
					## if the name is one of the currently six predefined tags (as determined by the fact that they have just one "/" and are "root" tags), use Tag, else, use the object-type
					DirectObjectList = _New-ObjListFromProperty_byObjName -Name $(if ([System.Text.RegularExpressions.Regex]::Matches($oContent.name, "/").Count -eq 1) {"Tag"} else {$oContent."object-type"}) -ObjectArray $oContent."direct-list"
					Guid = $oContent.guid
					Index = $oContent.index
					NumChildTag = $oContent."num-of-children"
					NumDirectObject = $oContent."num-of-direct-objs"
					NumItem = $oContent."num-of-items"
					ObjectList = _New-ObjListFromProperty_byObjName -Name $oContent."object-type" -ObjectArray $oContent."obj-list"
					ObjectType = $oContent."object-type"
					ParentTag = _New-ObjListFromProperty -IdPropertyPrefix "Tag" (,$oContent."parent-id")
					## Tags do not have this yet, apparently; adding here so class can still inherit from InfoBase object type
					Severity = $oContent."obj-severity"
					TagId = $oContent.guid
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"user-accounts" {
				[ordered]@{
					Name = $oContent.name
					Guid = $oContent.guid
					InactivityTimeoutMin = [int]$oContent."inactivity-timeout"
					Index = $oContent.index
					IsExternal = ($oContent."external-user" -eq "true")
					Role = $oContent.role
					Severity = $oContent."obj-severity"
					UserAccountId = $oContent."user-id"[0]
					XmsId = $oContent."xms-id"
				} ## end ordered dictionary
				break} ## end case
			"xms" {
				[ordered]@{
					Name = $oContent.name
					Index = $oContent.index
					XmsId = $oContent."xms-id"
					## the software version's build; like, "41" for SWVersion "4.0.1-41", or "41_hotfix_1" for "4.0.1-41_hotfix_1"
					Build = $oContent.build
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
					## "The aggregated value of the ratio of provisioned Volume capacity to the cluster’s actual used physical capacity"
					OverallEfficiency = [System.Double]$oContent."overall-efficiency-ratio"
					RestApiVersion = [System.Version]($oContent."restapi-protocol-version")
					Severity = $oContent."obj-severity"
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
	} ## end else
} ## end function
