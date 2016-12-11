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
		## expected returns for successful item deletion via Delete method (in Remove-* cmdlets)
		Delete = @{
			StatusCode = 200
			StatusDescription = "Ok"
		} ## end hashtable
	} ## end hashtable
	## filespec of encrypted credential file
	EncrCredFilespec = "${env:temp}\xioCred_by_${env:username}_on_${env:computername}.enc.xml"
	VerboseDatetimeFormat = "yyyy.MMM.dd HH:mm:ss"
	GetEventDatetimeFormat = "yyyy-MM-dd HH:mm:ss"
	## minimump REST API version that provides Filtering support
	MinimumRESTAPIVerForFiltering = [System.Version]"2.0"
	## the API type names that are available at the given minimum XIOS version
	ItemTypeInfoPerXiosVersion = @{
		"3.0" = "clusters", "data-protection-groups", "events", "ig-folders", "initiator-groups", "initiators", "lun-maps", "target-groups", "targets", "volumes", "volume-folders", "bricks", "snapshots", "ssds", "storage-controllers", "xenvs"
		"4.0" = "alert-definitions", "alerts", "bbus", "consistency-groups", "daes", "dae-controllers", "dae-psus", "email-notifier", "infiniband-switches", "ldap-configs", "local-disks", "performance", "schedulers", "slots", "snapshot-sets", "snmp-notifier", "storage-controller-psus", "syslog-notifier", "tags", "user-accounts", "xms"
	} ## end hashtable
	## item types that support specifying ?cluster-name=<somename> in the URI to retrieve items specific to the given cluster (per the API reference)
	ItemTypesSupportingClusterNameInput = "bbus", "bricks", "consistency-group-volumes", "consistency-groups", "dae-controllers", "dae-psus", "daes", "data-protection-groups", "infiniband-switches", "initiator-groups", "initiators", "iscsi-portals", "iscsi-routes", "local-disks", "lun-maps", "performance", "schedulers", "slots", "snapshot-sets", "snapshots", "ssds", "storage-controller-psus", "storage-controllers", "target-groups", "targets", "volumes", "xenvs"
	LinkRateTextToSpeedMapping = @{
		unknown = $null
		sdr = 2.5	## single data rate
		ddr = 5		## double data rate
		qdr = 10	## quad data rate
		fdr = 14.0625	## fourteen data rate
		fdr10 = 10.31
	} ## end hashtable
	## mapping of PowerShell object property names to their property names in the XtremIO REST API; useful for the -Property parameter in Get-XIOItemInfo and others
	TypePropMapping = @{
		"lun-maps" = @{
			VolumeName = "vol-name"
			LunId = "lun"
			LunMapId = "mapping-id"
			Name = "mapping-id"
			Guid = "guid"
			InitiatorGroup = "ig-name"
			InitiatorGrpIndex = "ig-index"
			TargetGrpName = "tg-name"
			TargetGrpIndex = "tg-index"
			MappingId = "mapping-id"
			MappingIndex = "mapping-index"
			Severity = "obj-severity"
			XmsId = "xms-id"
			VolumeIndex = "vol-index"
		} ## end hsh
	} ## end hsh
	## mapping of PSModule types' names to the URI values expected for entity types for Tag objects
	TagEntityTypeMapping = @{
		BBU = "BatteryBackupUnit"
		Brick = "X-Brick"
		Cluster = "Cluster"
		ConsistencyGroup = "ConsistencyGroup"
		DAE = "DAE"
		DataProtectionGroup = "DataProtectionGroup"
		InfinibandSwitch = "InfinibandSwitch"
		Initiator = "Initiator"
		InitiatorGroup = "InitiatorGroup"
		SSD = "SSD"
		SnapshotScheduler = "Scheduler"
		SnapshotSet = "SnapshotSet"
		StorageController = "StorageController"
		Target = "Target"
		Volume = "Volume"
	} ## end hash
	MessageStrings = @{
		## when RelatedObject of non-supported type is passed; expects to be used as base for a string formatting expression, where {0} is the full typename of the non-supported object
		NonsupportedRelatedObjectType = "RelatedObject was not of expected/accepted type (was of type [{0}]). The valid RelatedObject types supported by this cmdlet are:  {1}"
		## when Entity of non-supported type is passed; expects to be used as base for a string formatting expression, where {0} is the full typename of the non-supported object
		NonsupportedEntityObjectType = "Entity was not of expected/accepted type (was of type [{0}]). The valid Entity types supported by this cmdlet are:  {1}"
	} ## end hash
} ## end hashtable
