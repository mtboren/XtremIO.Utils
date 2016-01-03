<#	.Description
	Script to launch the XtremIO Java management console.  Assumes that *.jnlp files are associated w/ the proper Java WebStart app.  For XMS versions of 4.0 and newer, expects that user has already connected to said XMS via Connect-XIOServer (for XIOS v4 and newer, the Open-XIOMgmtConsole cmdlet relies on XMS information from that XioConnection object for determining the correct URL for the JNLP file)
	.Example
	Open-XIOMgmtConsole -Computer somexmsappl01.dom.com
	Downloads the .jnlp file for launching the Java console for this XMS appliance, then tries to launch the console by calling the program associated with .jnlp files (should be Java WebStart or the likes)
	.Example
	Open-XIOMgmtConsole -TrustAllCert -Computer somenewerxmsappl10.dom.com
	Downloads the .jnlp file for launching the Java console for this XMS appliance, trusting the certificate for this interaction, then tries to launch the console by calling the program associated with .jnlp files (should be Java WebStart or the likes)
	.Example
	Open-XIOMgmtConsole -Computer somexmsappl02.dom.com -DownloadOnly
	Downloads the .jnlp file for launching the Java console for this XMS appliance
#>
function Open-XIOMgmtConsole {
	[CmdletBinding()]
	param(
		## Name(s) of XMS appliances for which to launch the Java management console
		[parameter(Mandatory=$true)][string[]]$ComputerName,
		## switch: Trust all certs?  Not necessarily secure, but can be used if the XMS appliance is known/trusted, and has, say, a self-signed cert
		[switch]$TrustAllCert,
		## switch:  Download the JNLP files only?  default is to open the files with the associate program
		[switch]$DownloadOnly
	) ## end param

	Begin {
		## string to add to messages written by this function; function name in square brackets
		$strLogEntry_ToAdd = "[$($MyInvocation.MyCommand.Name)]"
	} ## end begin

	Process {
		$ComputerName | Foreach-Object {
			$strThisXmsName = $_
			## if already connected to this XMS, see its version:  at XIOS v4.0, the JNLP files were named with the XMS software version in them (like "webstart-4.0.1-41.jnlp")
			if ($($oThisXioConnection = $DefaultXmsServers | Where-Object {$_.ComputerName -like $strThisXmsName}; ($oThisXioConnection | Measure-Object).Count -eq 1)) {
				$strXmsAddrToUse = $oThisXioConnection.ComputerName
				$strAddlJnlpFilenamePiece = if ($oThisXioConnection.XmsVersion -ge [System.Version]("4.0")) {"-$($oThisXioConnection.XmsSWVersion)"} else {$null}
			} ## end if
			## else, make sure this name is legit (in DNS)
			else {
				Try {$oIpAddress = [System.Net.DNS]::GetHostAddresses($strThisXmsName); $strAddlJnlpFilenamePiece,$strXmsAddrToUse = $null, $strThisXmsName}
				Catch [System.Net.Sockets.SocketException] {Write-Warning "'$strThisXmsName' not found in DNS. Valid name?"; break;}
			} ## end else

			## place to which to download this JNLP file
			$strDownloadFilespec = Join-Path ${env:\temp} "${strXmsAddrToUse}.jnlp"
			$strJnlpFileUri = "https://$strXmsAddrToUse/xtremapp/webstart${strAddlJnlpFilenamePiece}.jnlp"
			Write-Verbose "Using URL '$strJnlpFileUri'"
			$oWebClient = New-Object System.Net.WebClient
			## if specified to do so, set session's CertificatePolicy to trust all certs (for now; will revert to original CertificatePolicy)
			if ($true -eq $TrustAllCert) {Write-Verbose "$strLogEntry_ToAdd setting ServerCertificateValidationCallback method temporarily so as to 'trust' certs (should only be used if certs are known-good / trustworthy)"; $oOrigServerCertValidationCallback = Disable-CertValidation}

			try {
				$oWebClient.DownloadFile($strJnlpFileUri, $strDownloadFilespec)
				## if not DownloadOnly switch, open the item
				if ($DownloadOnly) {Write-Verbose -Verbose "downloaded to '$strDownloadFilespec'"} else {Invoke-Item $strDownloadFilespec}
			} catch {Write-Error $_}

			## if CertValidationCallback was altered, set back to original value
			if ($true -eq $TrustAllCert) {
				[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $oOrigServerCertValidationCallback
				Write-Verbose "$strLogEntry_ToAdd set ServerCertificateValidationCallback back to original value of '$oOrigServerCertValidationCallback'"
			} ## end if
		} ## end foreach-object
	} ## end process
} ## end function

<#	.Description
	Function to get the stored, encrypted credentials from file (if one exists)
	.Example
	Get-XIOStoredCred
	.Outputs
	System.Management.Automation.PSCredential or none
#>
function Get-XIOStoredCred {
	[CmdletBinding()][OutputType([System.Management.Automation.PSCredential])]param()

	Process {
		if (Test-Path $hshCfg["EncrCredFilespec"]) {
			try {$credImportedXioCred = hImport-PSCredential $hshCfg["EncrCredFilespec"]} ## end try
			catch {
				#Write-Error -ErrorRecord $_
			} ## end catch
			if ($null -ne $credImportedXioCred) {return $credImportedXioCred} else {Write-Verbose "Could not import credential from file '$($hshCfg["EncrCredFilespec"])'. Valid credential file?"}
		} ## end if
		else {Write-Verbose "No stored XIO credential found at '$($hshCfg["EncrCredFilespec"])'"}
	} ## end process
} ## end function


<#	.Description
	Function to create a new stored, encrypted credentials file
	.Example
	New-XIOStoredCred -Credential $credMyStuff
	.Outputs
	None or System.Management.Automation.PSCredential
#>
function New-XIOStoredCred {
	[OutputType("null",[System.Management.Automation.PSCredential])]
	param(
		## The credential to encrypt; if none, will prompt
		[System.Management.Automation.PSCredential]$Credential = (Get-Credential -Message "Enter credentials to use for XtremIO access"),
		## switch: Pass the credentials through, returning back to caller?
		[switch]$PassThru_sw
	) ## end param
	hExport-PSCredential -Credential $Credential -Path $hshCfg["EncrCredFilespec"]
	if ($true -eq $PassThru_sw) {$Credential}
} ## end function


<#	.Description
	Function to remove the stored, encrypted credentials file (if one exists)
	.Example
	Remove-XIOStoredCred -WhatIf
	Perform WhatIf run of removing the credentials (without actually removing them)
	.Outputs
	None
#>
function Remove-XIOStoredCred {
	[CmdletBinding(SupportsShouldProcess=$true)]param()
	begin {$strStoredXioCredFilespec = $hshCfg["EncrCredFilespec"]}
	process {
		if (Test-Path $strStoredXioCredFilespec) {
			if ($PSCmdlet.ShouldProcess($strStoredXioCredFilespec, "Remove file")) {
				Remove-Item $strStoredXioCredFilespec -Force
			} ## end if
		} else {Write-Warning "Creds file '$strStoredXioCredFilespec' does not exist; no action to take"}
	} ## end process
} ## end function


<#	.Description
	Function to make a "connection" to an XtremIO XMS machine, such that subsequent interactions with that XMS machine will not require additional credentials be supplied.  Updates PowerShell title bar to show connection information
	.Example
	Connect-XIOServer somexms02.dom.com
	Connect to the given XMS server.  Will prompt for credential to use
	.Example
	Connect-XIOServer -Credential $credMe -ComputerName somexms01.dom.com -Port 443 -TrustAllCert
	Connect to the given XMS server using the given credential.  "TrustAllCert" parameter is useful when the XMS appliance has a self-signed cert that will not be found valid, but that is trusted to be legit
#>
function Connect-XIOServer {
	[CmdletBinding()]
	[OutputType([XioItemInfo.XioConnection])]
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
		## args for the Get-XIOInfo call, and for New-XioApiURI call
		$hshArgsForGetXIOInfo = @{Credential = $Credential}; $hshArgsForNewXioApiURI = @{RestCommand = "/types"; ReturnURIAndPortInfo = $true; TestPort = $true}
		if ($TrustAllCert) {$hshArgsForGetXIOInfo["TrustAllCert"] = $true}
		if ($PSBoundParameters.ContainsKey("Port")) {$hshArgsForGetXIOInfo["Port"] = $Port; $hshArgsForNewXioApiURI["Port"] = $Port}
	} ## end begin
	process {
		$ComputerName | Foreach-Object {
			$strThisXmsName = $_
			## if the global var already holds connection info for this XMS machine
			if ($Global:DefaultXmsServers | Where-Object {$_.ComputerName -eq $strThisXmsName}) {Write-Verbose "already connected to '$strThisXmsName'"}
			else {
				Try {
					## get the URI and Port that should be used for this connection
					$strTmpUriInfo, $intPortToUse = New-XioApiURI -ComputerName $strThisXmsName @hshArgsForNewXioApiURI
					## get the XIO info object for this XMS machine
					$oThisXioInfo = Get-XIOInfo -ComputerName $strThisXmsName @hshArgsForGetXIOInfo
					if ($null -ne $oThisXioInfo) {
						$hshPropertiesForNewXmsConnectionObj = @{
							ComputerName = $strThisXmsName
							ConnectDatetime = (Get-Date)
							Port = $intPortToUse
							Credential = $Credential
							TrustAllCert = if ($TrustAllCert) {$true} else {$false}
						} ## end New-Object
						## check for versions of XIOS and REST API (based on presence/availability of XMS type)
						if ($oThisXioInfo.children.name -contains "xms") {
							## make URI for the first (only?) XMS object known to this XMS appliance; like https://somexms01.dom.com/api/json/types/xms/1
							$strThisXmsObjUri = "{0}/1" -f ($oThisXioInfo.children | Where-Object {$_.name -eq "xms"}).href
							$hshParamForGetXmsInfo = @{Credential = $Credential; "URI" = $strThisXmsObjUri}; if ($TrustAllCert) {$hshParamForGetXmsInfo["TrustAllCert"] = $true}
							## get the XMS object's info
							$oThisXmsInfo = Get-XIOInfo @hshParamForGetXmsInfo
							$hshPropertiesForNewXmsConnectionObj["RestApiVersion"] = [System.Version]($oThisXmsInfo.content."restapi-protocol-version")
							$hshPropertiesForNewXmsConnectionObj["XmsDBVersion"] = [System.Version]($oThisXmsInfo.content."db-version")
							$hshPropertiesForNewXmsConnectionObj["XmsSWVersion"] = $oThisXmsInfo.content."sw-version"
							$hshPropertiesForNewXmsConnectionObj["XmsVersion"] = [System.Version]($oThisXmsInfo.content.version)
						} ## end if
						## else, this must be older XIOS/XMS version, which uses the XMS REST API version 1.0
						else {$hshPropertiesForNewXmsConnectionObj["RestApiVersion"] = [System.Version]"1.0"}
						$oTmpThisXmsConnection = New-Object -Type XioItemInfo.XioConnection -Property $hshPropertiesForNewXmsConnectionObj
						## add connection object to global connection variable
						$Global:DefaultXmsServers += $oTmpThisXmsConnection
						## update PowerShell window titlebar
						Update-TitleBarForXioConnection
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


<#	.Description
	Function to remove a "connection" that exists to an XtremIO XMS machine
	.Example
	Disconnect-XIOServer somexms02.*
	Disconnect from the given XMS server
	.Example
	Disconnect-XIOServer
	Disconnect from all connected XMS servers
#>
function Disconnect-XIOServer {
	[CmdletBinding()]
	param(
		## XMS appliance address from which to disconnect
		[parameter(Position=0)][string[]]$ComputerName = "*"
	)
	process {
		$ComputerName | Foreach-Object {
			$strThisXmsName = $_
			$arrXmsServerFromWhichToDisconnect = $Global:DefaultXmsServers | Where-Object {$_.ComputerName -like $strThisXmsName}
			## if connected to such an XMS machine, take said connection out of the global variable
			if ($arrXmsServerFromWhichToDisconnect) {
				$Global:DefaultXmsServers = @($Global:DefaultXmsServers | Where-Object {$_.ComputerName -notlike $strThisXmsName})
				## update PowerShell window titlebar
				Update-TitleBarForXioConnection
			} ## end if
			else {Write-Warning "Not connected to any XMS machine whose name is like '$strThisXmsName'. No action taken"}
		} ## end Foreach-Object
	} ## end process
} ## end function
