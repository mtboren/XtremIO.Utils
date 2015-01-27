## configuration items for XIO module
$hshCfg = @{
	## default ports for API (varies based on XMS appliance version)
	DefaultApiPort = @{
		## stopped using after v0.6.0 of module; to be removed at some point (this is from the XIOS v2.2.2 and older days)
		#intNonSSL = 42503
		intSSL = 443
	} ## end hashtable
	## standard response status codes and descriptions
	StdResponse = @{
		## for item creation via Post method
		Post = @{
			StatusCode = 201
			StatusDescription = "Created"
		} ## end hashtable
	} ## end hashtable
	## filespec of encrypted credential file
	EncrCredFilespec = "${env:temp}\xioCred_by_${env:username}_on_${env:computername}.enc.xml"
	VerboseDatetimeFormat = "yyyy.MMM.dd HH:mm:ss"
	GetEventDatetimeFormat = "yyyy-MM-dd HH:mm:ss"
} ## end hashtable
