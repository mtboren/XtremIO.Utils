<#
take creds
if $global:DefaultXmsServers -contains $thisXmsServer {write-verbose "already connected to $thisXmsServer"}
else {
	try {connect; create hsh or add value to existing hsh for this server; return some snippet of info about connected XMS server}
	catch {write-error couldn't connect + message}
}

$global:DefaultXmsServers is PSObject @{ComputerName = "somexms.dom.com"; Credential = $SomePSCred; ConnectDatetime = $someDatetime; XIOSVersion = "someVersion"}


todo:
update all other cmdlets to check for and use $global:DefaultXmsServers for ComputerName and Credentials (via the default value for their $Credential param)
	-if connected
		if -ComputerName, act on only those valid XMS servers
		else act on all connected XMS servers
	-if not connected
		behave same as now (maybe prompt "could connect to XMS server to not be prompted for creds each time")
done:
	update titlebar for successful connection/disconnection
	add type for XmsServerConnection; add format that does not show Credential property in table
	testing:
		connect with invalid name
		connect with invalid cred
		connect with valid name/cred
		connect again with valid name/cred to XMS machine to which already connected
#>

function Connect-XIOServer {
	<#	.Description
		Function to make a "connection" to an XtremIO XMS machine, such that subsequent interactions with that XMS machine will not require additional credentials be supplied.  Updates PowerShell title bar to show connection information
		.Example
		Connect-XIOServer somexms02.dom.com
		Connect to the given XMS server.  Will prompt for credential to use
		.Example
		Connect-XIOServer -Credential $credMe -ComputerName somexms01.dom.com -Port 443 -TrustAllCert
		Connect to the given XMS server using the given credential
	#>
	[CmdletBinding()]
	param(
		## Credential for connecting to XMS appliance; if a credential has been encrypted and saved, this will automatically use that credential
		[System.Management.Automation.PSCredential]$Credential = $(_Find-CredentialToUse),
		## XMS appliance address to which to connect
		[parameter(Mandatory=$true,Position=0)][string[]]$ComputerName,
		## Port to use for API call (if none, will try to autodetect proper port; may be slightly slower due to port probe activity)
		[int]$Port,
		## switch: Trust all certs?  Not necessarily secure, but can be used if the XMS appliance is known/trusted, and has, say, a self-signed cert
		[switch]$TrustAllCert
	) ## end param
	begin {
		## if the global connection info variable does not yet exist, initialize it
		if ($null -eq $Global:DefaultXmsServers) {$Global:DefaultXmsServers = @()}
		## args for the Get-XIOCluster call
		$hshArgsForGetXIOCluster = @{Credential = $Credential}
		if ($TrustAllCert) {$hshArgsForGetXIOCluster["TrustAllCert"] = $true}
		if ($PSBoundParameters.ContainsKey("Port")) {$hshArgsForGetXIOCluster["Port"] = $Port}
	} ## end begin
	process {
		$ComputerName | Foreach-Object {
			$strThisXmsName = $_
			## if the global var already holds connection info for this XMS machine
			if ($Global:DefaultXmsServers | Where-Object {$_.ComputerName -eq $strThisXmsName}) {Write-Verbose "already connected to '$strThisXmsName'"}
			else {
				Try {
					## get the XIO cluster object for this XMS machine
					$oThisXioClusterInfo = Get-XIOInfo -ComputerName $strThisXmsName @hshArgsForGetXIOCluster
					if ($oThisXioClusterInfo) {
						 $oTmpThisXmsConnection = New-Object -Type PSObject -Property ([ordered]@{
							ComputerName = $strThisXmsName
							XIOSSwVersion = $oThisXioClusterInfo.SWVersion
							ConnectDatetime = (Get-Date)
							Port = $Port
							Credential = $Credential
							TrustAllCert = if ($TrustAllCert) {$true} else {$false}
							PSTypeName = "XioItemInfo.XioConnection"
						}) ## end New-Object
						## add connection object to global connection variable
						$Global:DefaultXmsServers += $oTmpThisXmsConnection
						## update PowerShell window titlebar
						Update-TitleBarForXmsConnection
						## return the connection object
						$oTmpThisXmsConnection
					} ## end if
					else {"Unable to connect to XMS machine '$strThisXmsName'. What the"}
				} ## end try
				Catch {Write-Error "Failed to connect to XMS '$strThisXmsName'.  See error below for details"; Throw $_}
			} ## end else
		} ## end Foreach-Object
	} ## end process
} ## end function


<#
Disconnect-XIOServer:
$arrXmsServerFromWhichToDisconnect = $Global:DefaultXmsServers | ?{$_.ComputerName -like $thisXmsServer}
if ($arrXmsServerFromWhichToDisconnect) {$arrXmsServerFromWhichToDisconnect | %{remove connection object from $Global:DefaultXmsServers}}
else {Write-Warning "was not connected to any XMS machine whose name is like $thisXmsServer"}
#>
function Disconnect-XIOServer {
	<#	.Description
		Function to remove a "connection" that exists to an XtremIO XMS machine
		.Example
		Disconnect-XIOServer somexms02.*
		Disconnect from the given XMS server
		.Example
		Disconnect-XIOServer *
		Disconnect from all connected XMS servers
	#>
	[CmdletBinding()]
	param(
		## XMS appliance address from which to disconnect
		[parameter(Mandatory=$true,Position=0)][string[]]$ComputerName
	)
	process {
		$ComputerName | Foreach-Object {
			$strThisXmsName = $_
			$arrXmsServerFromWhichToDisconnect = $Global:DefaultXmsServers | Where-Object {$_.ComputerName -like $strThisXmsName}
			## if connected to such an XMS machine, take said connection out of the global variable
			if ($arrXmsServerFromWhichToDisconnect) {
				$Global:DefaultXmsServers = @($Global:DefaultXmsServers | Where-Object {$_.ComputerName -notlike $strThisXmsName})
				## update PowerShell window titlebar
				Update-TitleBarForXmsConnection
			} ## end if
			else {Write-Warning "Not connected to any XMS machine whose name is like '$strThisXmsName'. No action taken"}
		} ## end Foreach-Object
	} ## end process
} ## end function


<#
Set PowerShell title bar to include XMS servers' names
#>
## change PowerShell title bar to reflect currently connected XMS machines
function Update-TitleBarForXmsConnection {
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
