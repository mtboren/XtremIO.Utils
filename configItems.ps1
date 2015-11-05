## configuration items for XIO module (not meant to be user-configurable)
$hshCfg = @{
	## default ports for API (varies based on XMS appliance version)
	DefaultApiPort = @{
		## stopped using after v0.6.0 of module; to be removed at some point (this is from the XIOS v2.2.2 and older days)
		#intNonSSL = 42503
		intSSL = 443
	} ## end hashtable
	## standard response status codes and descriptions
	StdResponse = @{
		## expected returns for successful item creation via Post method
		Post = @{
			StatusCode = 201
			StatusDescription = "Created"
		} ## end hashtable
		## expected returns for successful item modification via Put method (in Set-* cmdlets)
		Put = @{
			StatusCode = 200
			StatusDescription = "Ok"
		} ## end hashtable
	} ## end hashtable
	## filespec of encrypted credential file
	EncrCredFilespec = "${env:temp}\xioCred_by_${env:username}_on_${env:computername}.enc.xml"
	VerboseDatetimeFormat = "yyyy.MMM.dd HH:mm:ss"
	GetEventDatetimeFormat = "yyyy-MM-dd HH:mm:ss"
	ItemTypeInfoPerXiosVersion = @{
		"3.0" = "clusters", "data-protection-groups", "events", "ig-folders", "initiator-groups", "initiators", "lun-maps", "target-groups", "targets", "volumes", "volume-folders", "bricks", "snapshots", "ssds", "storage-controllers", "xenvs"
		"4.0" = "alert-definitions", "bbus", "daes", "dae-controllers", "email-notifier", "ldap-configs", "local-disks", "schedulers", "slots", "snmp-notifier", "user-accounts", "xms"
	}
} ## end hashtable
