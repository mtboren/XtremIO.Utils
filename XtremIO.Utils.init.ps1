Add-Type -TypeDefinition @"
using System;
namespace XioItemInfo {
	// Alert (inherits from class InfoBase)
	public class Alert : InfoBase {
		public String AlertCode;
		public String AlertType;
		public String AssociatedObjId;
		public String AssociatedObjIndex;
		public String AssociatedObjName;
		public String Class;
		public String ClusterId;
		public String ClusterName;
		public DateTime CreationTime;
		public String Description;
		public String State;
		public String Threshold;

		// Implicit constructor
		public Alert () {}
	}

	public class AlertDefinition : InfoBase {
		public String AlertCode;
		public String AlertType;
		public String Class;
		public String ClearanceMode;
		public Boolean Enabled;
		public Boolean SendToCallHome;
		public String ThresholdType;
		public Int32 ThresholdValue;
		public Boolean UserModified;

		// Implicit constructor
		public AlertDefinition () {}
	}

	// XIO BBU (inherits from class HardwareBase)
	public class BBU : HardwareBase {
		public Object[] Battery;
		public Int32 BatteryChargePct;
		public String BBUId;
		public Object[] BrickId;
		public Boolean BypassActive;
		public Boolean ConnectedToSC;
		public String ClusterId;
		public String ClusterName;
		public Boolean Enabled;
		public String FWVersionError;
		public Int32 IndexInXbrick;
		public String Input;
		public Double InputHz;
		public Int32 InputVoltage;
		public Int32 LoadPct;
		public String LoadPctLevel;
		public String Outlet1Status;
		public String Outlet2Status;
		public Double OutputA;
		public Double OutputHz;
		public Double OutputVoltage;
		public String PowerFeed;
		public Int32 PowerW;
		public Int32 RealPowerW;
		public String Status;
		public Object[] StorageController;
		public Object TagList;
		public String UPSAlarm;
		public Boolean UPSOverloaded;
		public Object[] SysId;

		// Implicit constructor
		public BBU () {}
	}

	// XIO Brick
	public class Brick : InfoBase {
		public Object[] BrickId;
		public string BrickGuid;
		public string ClusterName;
		public Object[] DataProtectionGroup;
		// Storage Controller info -- deprecated
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'StorageController' instead", false)]
		public Object[] NodeList { get; set; }
		// Num Storage Controller -- deprecated
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'NumStorageController' instead", false)]
		public Int32 NumNode { get; set; }
		public Int32 NumSSD;
		public Int32 NumStorageController;
		// Data Protection Group info -- deprecated
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'DataProtectionGroup' instead", false)]
		public Object[] RGrpId;
		// array of SSD Slot info items
		public Object[] SsdSlotInfo;
		public Object[] StorageController;
		public string State;

		// Implicit constructor
		public Brick () {}
	}

	public class Cluster : InfoBase {
		public Object[] Brick;
		// Brick list info -- deprecated
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'Brick' instead", false)]
		public Object[] BrickList;
		public String ClusterId;
		public Decimal CompressionFactor;
		public String CompressionMode;
		public String ConsistencyState;
		public Decimal DataReduction;
		public Decimal DedupeRatio;
		public String EncryptionMode;
		public Boolean EncryptionSupported;
		public String FcPortSpeed;
		public String FreespaceLevel;
		public Double FreeSSDTB;
		public Object[] InfinibandSwitch;
		// InfinibandSwitch list info -- deprecated
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'InfinibandSwitch' instead", false)]
		public Object[] InfiniBandSwitchList;
		public Int64 IOPS;
		public String LicenseId;
		public String NaaSysId;
		public Int32 NumBrick;
		public Int32 NumInfiniBandSwitch;
		public Int32 NumSSD;
		public Int32 NumVol;
		public Int32 NumXenv;
		public String OverallEfficiency;
		public Object PerformanceInfo;
		public String SharedMemEfficiencyLevel;
		public String SharedMemInUseRatioLevel;
		public String SizeAndCapacity;
		public String SWVersion;
		public DateTime SystemActivationDateTime;
		public Int32 SystemActivationTimestamp;
		public String SystemSN;
		public String SystemState;
		public String SystemStopType;
		public Decimal ThinProvSavingsPct;
		public Double TotProvTB;
		public Double TotSSDTB;
		public Double UsedLogicalTB;
		public Double UsedSSDTB;

		// Implicit constructor
		public Cluster() {}
	}

	// ClusterPerformance (inherits from class PerformanceTotal)
	public class ClusterPerformance : PerformanceTotal {}

	// ConsistencyGroup (inherits from InfoBase)
	public class ConsistencyGroup : InfoBase {
		public String Certainty;
		public String ClusterId;
		public String ClusterName;
		public String ConsistencyGrpId;
		public String ConsistencyGrpShortId;
		public String CreatedByApp;
		public Int32 NumVol;
		public Object[] SysId;
		public Object TagList;
		public Object[] VolList;

		// Implicit constructor
		public ConsistencyGroup () {}
	}

	// XIO DAE (Disk Array Enclosure) (inherits from class HardwareBase)
	public class DAE : HardwareBase {
		public Object[] BrickId;
		public String ClusterId;
		public String ClusterName;
		public String DAEId;
		public Int32 NumDAEController;
		public Int32 NumDAEPSU;
		public String ReplacementReason;
		public Object TagList;
		public Object[] SysId;

		// Implicit constructor
		public DAE () {}
	}

	// XIO DAE (Disk Array Enclosure) PSU (inherits from class HardwareBase)
	public class DAEPsu : HardwareBase {
		public Object[] BrickId;
		public Object[] DAE;
		public String DAEPSUId;
		public Boolean Enabled;
		public String FWVersionError;
		public String Identification;
		public String Input;
		public String Location;
		public String PowerFailure;
		public String PowerFeed;
		public String ReplacementReason;
		public Object[] SysId;

		// Implicit constructor
		public DAEPsu () {}
	}

	// XIO DAE Controller (inherits from class HardwareBase)
	public class DAEController : HardwareBase {
		public Object[] BrickId;
		public String ConnectivityState;
		public String ClusterId;
		public String ClusterName;
		public String DAEId;
		public String DAEControllerId;
		public Boolean Enabled;
		public String FailureReason;
		public String FWVersionError;
		public String HealthLevel;
		public String Identification;
		public String Location;
		public String ReplacementReason;
		public Object[] SAS;
		public Object[] SysId;

		// Implicit constructor
		public DAEController () {}
	}

	public class DataProtectionGroup : InfoBase {
		public Int32 AvailableRebuild;
		public Object Brick;
		// Brick info -- deprecated
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'Brick' instead", false)]
		public Int32 BrickIndex;
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'Brick' instead", false)]
		public String BrickName;
		public Object Cluster;
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'Cluster' instead", false)]
		public Int32 ClusterIndex;
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'Cluster' instead", false)]
		public String ClusterName;
		public String DataProtectionGrpId;
		public Int64 IOPS;
		public Int32 NumNode;
		public Int32 NumSSD;
		public Object PerformanceInfo;
		public Boolean RebalanceInProg;
		public Int32 RebalanceProgress;
		public Boolean RebuildInProg;
		public String RebuildPreventionReason;
		public Int32 RebuildProgress;
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'DataProtectionGrpId' instead", false)]
		public Object[] RGrpId;
		public Boolean SSDPrepInProg;
		public Int32 SSDPrepProgress;
		public String State;
		public Double TotSSDTB;
		public Double UsedSSDTB;
		public Double UsefulSSDTB;

		// Implicit constructor
		public DataProtectionGroup() {}
	}

	// DataProtectionGroupPerformance (inherits from class PerformanceBase)
	public class DataProtectionGroupPerformance : PerformanceBase {}


	// XIO Email Notifier
	public class EmailNotifier : InfoBase {
		public String CompanyName;
		public String ContactDetails;
		public Boolean Enabled;
		public Int32 FrequencySec;
		public String MailRelayAddress;
		public String MailUsername;
		public String ProxyAddress;
		public String ProxyPort;
		public String ProxyUser;
		public String[] Recipient;
		public String TransportProtocol;

		// Implicit constructor
		public EmailNotifier () {}
	}

	// XIO Events
	public class Event {
		public String Category;
		public String ComputerName;
		public DateTime DateTime;
		public String Description;
		public String EntityDetails;
		public String EntityType;
		public Int32 EventID;
		public String RelAlertCode;
		public String Severity;
		public String Uri;

		// Implicit constructor
		public Event () {}
	}

	// general HardwareBase class (inherits from class InfoBase)
	public class HardwareBase : InfoBase {
		public String FWVersion;
		public String HWRevision;
		public String IdLED;
		public String LifecycleState;
		public String Model;
		public String PartNumber;
		public String SerialNumber;
		public String StatusLED;

		// Implicit constructor
		public HardwareBase() {}
	}

	// Initiator Group Folder
	public class IgFolder : InfoBase {
		public String Caption;
		public String ColorHex;
		public System.Nullable<DateTime> CreationTime;
		public String FolderId;
		public String[] InitiatorGrpIdList;
		public Int64 IOPS;
		public Int32 NumIG;
		public Int32 NumSubfolder;
		public String ObjectType;
		public String ParentFolder;
		public String ParentFolderId;
		public Object PerformanceInfo;
		public Object SubfolderList;

		// Implicit constructor
		public IgFolder () {}
	}

	// InfiniBand Switch (inherits from class HardwareBase)
	public class InfinibandSwitch : HardwareBase {
		public Boolean Enabled;
		public Int32 Fan1RPM;
		public Int32 Fan2RPM;
		public Int32 Fan3RPM;
		public Int32 Fan4RPM;
		public String FanDrawerStatus;
		public String FWVersionError;
		public String IbSwitchId;
		public String InterswitchIb1Port;
		public String InterswitchIb2Port;
		public Object[] Port;
		public String ReplacementReason;
		public Object[] SysId;
		public Object TagList;
		public Object[] TemperatureSensor;
		public Object[] VoltageSensor;
		public String WrongSCConnection;

		// Implicit constructor
		public InfinibandSwitch () {}
	}

	// general InfoBase class
	public class InfoBase {
		public String ComputerName;
		public String Guid;
		public System.Nullable<Int32> Index;
		public String Name;
		public String Severity;
		public String Uri;
		public Object[] XmsId;

		// Implicit constructor
		public InfoBase() {}
	}

	// Initiator Group Folder Performance (inherits from class PerformanceTotal)
	public class IgFolderPerformance : PerformanceTotal {}

	public class Initiator : InfoBase {
		public String ConnectionState;
		public String InitiatorGrpId;
		public Object InitiatorGroup;
		public String InitiatorId;
		public Int64 IOPS;
		public Object PerformanceInfo;
		public String PortAddress;
		public String PortType;

		// Implicit constructor
		public Initiator () {}
	}

	public class InitiatorGroup : InfoBase {
		public String InitiatorGrpId;
		public Int64 IOPS;
		public Int32 NumInitiator;
		public Int32 NumVol;
		public Object PerformanceInfo;

		// Implicit constructor
		public InitiatorGroup () {}
	}

	// InitiatorGroupPerformance (inherits from class PerformanceTotal)
	public class InitiatorGroupPerformance : PerformanceTotal {}

	// InitiatorPerformance (inherits from class PerformanceTotal)
	public class InitiatorPerformance : PerformanceTotal {}

	// LDAP Config (inherits from class InfoBase)
	public class LdapConfig : InfoBase {
		public String BindDN;
		public String CACertData;
		public String CACertFile;
		public Int32 CacheExpireH;
		public String[] Role;
		public String SearchBaseDN;
		public String SearchFilter;
		public String[] ServerUrl;
		public String[] ServerUrlExample;
		public Int32 TimeoutSec;
		public String UserToDnRule;

		// Implicit constructor
		public LdapConfig () {}
	}

	// XIO LocalDisk in StorageControllers (inherits from class HardwareBase)
	public class LocalDisk : HardwareBase {
		public Object[] BrickId;
		public String ClusterId;
		public String ClusterName;
		public Boolean Enabled;
		public String EncryptionStatus;
		public String ExpectedType;
		public String FailureReason;
		public String FWVersionError;
		public String LocalDiskId;
		public Int32 NumBadSector;
		public String Purpose;
		public String ReplacementReason;
		public Int32 SlotNum;
		public String StorageControllerId;
		public String StorageControllerName;
		public Object[] SysId;
		public Object TagList;
		public String Type;
		public String Wwn;

		// Implicit constructor
		public LocalDisk () {}
	}

	public class LunMap : InfoBase {
		public String InitiatorGroup;
		public System.Nullable<Int32> InitiatorGrpIndex;
		public System.Nullable<Int32> LunId;
		public String LunMapId;
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'LunMapId' instead", false)]
		public Object[] MappingId;
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'Index' instead", false)]
		public System.Nullable<Int32> MappingIndex;
		public System.Nullable<Int32> TargetGrpIndex;
		public String TargetGrpName;
		public System.Nullable<Int32> VolumeIndex;
		public String VolumeName;

		// Implicit constructor
		public LunMap () {}
	}

	// general PerformanceBase class
	public class PerformanceBase {
		public Double BW_MBps;
		public String ComputerName;
		public Int32 Index;
		public Int64 IOPS;
		public String Name;
		public Double ReadBW_MBps;
		public Int32 ReadIOPS;
		public Double WriteBW_MBps;
		public Int32 WriteIOPS;

		// Implicit constructor
		public PerformanceBase() {}
	}

	// PerformanceCounter class
	public class PerformanceCounter {
		public String Name;
		public Object[] Counters;
		public DateTime DateTime;
		public XioItemInfo.Enums.PerfCounter.EntityType EntityType;
		public XioItemInfo.Enums.PerfCounter.Granularity Granularity;
		public String Guid;
		public Int32 Index;
		public String ComputerName;
		public String Uri;

		// Implicit constructor
		public PerformanceCounter() {}
	}

	// Performance class with Totals (inherits from class PerformanceBase)
	public class PerformanceTotal : PerformanceBase {
		public Int64 TotReadIOs;
		public Int64 TotWriteIOs;
	}

	// Snapshot Scheduler
	public class SnapshotScheduler {
		public String Name;
		public Boolean Enabled;
		public String Guid;
		public Int32 Index;
		public System.Nullable<DateTime> LastActivated;
		public String LastActivationResult;
		public Int32 NumSnapToKeep;
		public TimeSpan Retain;
		public String Schedule;
		public Object SnappedObject;
		public String SnapshotSchedulerId;
		public String SnapType;
		public String State;
		public String Suffix;
		public String Type;
		public String ComputerName;
		public String Uri;

		// Implicit constructor
		public SnapshotScheduler () {}
	}

	// Snapshot (inherits Volume class)
	public class Snapshot : Volume {}

	// SnapshotSet (inherits from InfoBase)
	public class SnapshotSet : InfoBase {
		public String ClusterId;
		public String ClusterName;
		public String ConsistencyGrpId;
		public String ConsistencyGrpName;
		public DateTime CreationTime;
		public Int32 NumVol;
		public String SnapshotSetId;
		public String SnapshotSetShortId;
		public Object[] SysId;
		public Object TagList;
		public Object[] VolList;

		// Implicit constructor
		public SnapshotSet () {}
	}

	// SNMP Notifier (inherits from class InfoBase)
	public class SnmpNotifier : InfoBase {
		public String AuthProtocol;
		public String Community;
		public Boolean Enabled;
		public Int32 HeartbeatFreqSec;
		public Int32 Port;
		public String PrivacyProtocol;
		public String[] Recipient;
		public String SNMPVersion;
		public String Username;

		// Implicit constructor
		public SnmpNotifier () {}
	}

	// Slot (inherits from class InfoBase)
	public class Slot : InfoBase {
		public Object[] BrickId;
		public String ErrorReason;
		public String FailureReason;
		public String SsdModel;
		public Int32 SlotNum;
		public String SsdId;
		public Double SsdSizeGB;
		public String SsdUid;
		public String State;
		public Object[] SysId;

		// Implicit constructor
		public Slot () {}
	}

	// SSD
	public class Ssd : HardwareBase {
		public Object[] BrickId;
		public Double CapacityGB;
		public Object DataProtectionGroup;
		public String DiagHealthState;
		public Boolean Enabled;
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'Enabled' instead", false)]
		public String EnabledState;
		public String EncryptionStatus;
		public String FWVersionError;
		public String HealthState;
		public Int64 IOPS;
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'Model' instead", false)]
		public String ModelName;
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'Severity' instead", false)]
		public String ObjSeverity;
		public Int32 PctEnduranceLeft;
		public String PctEnduranceLeftLvl;
		public Object PerformanceInfo;
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'DataProtectionGroup' instead", false)]
		public Object[] RGrpId;
		public Int32 SlotNum;
		public String SSDFailureReason;
		public String SsdId;
		public String SSDLink1Health;
		public String SSDLink2Health;
		public String SSDPositionState;
		public String SsdRGrpState;
		public String SsdUid;
		public String SwapLED;
		public Object[] SysId;
		public Double UsedGB;
		public Double UsefulGB;

		// Implicit constructor
		public Ssd () {}
	}

	// SsdPerformance (inherits from class PerformanceBase)
	public class SsdPerformance : PerformanceBase {}

	public class StorageController : HardwareBase {
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'FWVersion' instead", false)]
		public String BiosFWVersion;
		public String BrickName;
		public String Cluster;
		public Object DataProtectionGroup;
		public Boolean Enabled;
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'Enabled' instead", false)]
		public String EnabledState;
		public String EncryptionMode;
		public String EncryptionSwitchStatus;
		public Object FcHba;
		public String HealthState;
		public String IBAddr1;
		public String IBAddr2;
		public String IPMIAddr;
		public String IPMIState;
		public String JournalState;
		public String MgmtPortSpeed;
		public String MgmtPortState;
		public String MgrAddr;
		public String NodeMgrConnState;
		public Int32 NumSSD;
		public Int32 NumSSDDown;
		public Int32 NumTargetDown;
		public String OSVersion;
		public Object PCI;
		public String PoweredState;
		public String RemoteJournalHealthState;
		public Object[] SAS;
		public String SdrFWVersion;
		public String State;
		public String StorageControllerId;
		public String SWVersion;

		// Implicit constructor
		public StorageController () {}
	}

	// XIO StorageControllerPsu
	public class StorageControllerPsu : InfoBase {
		public Object[] BrickId;
		public Boolean Enabled;
		public String FWVersionError;
		public String HWRevision;
		public String Input;
		public String LifecycleState;
		public String Location;
		public String Model;
		public String PartNumber;
		public String PowerFailure;
		public String PowerFeed;
		public String ReplacementReason;
		public String SerialNumber;
		public String StatusLED;
		public Object[] StorageController;
		public String StorageControllerPSUId;
		public Object[] SysId;

		// Implicit constructor
		public StorageControllerPsu () {}
	}

	// SyslogNotifier (inherits from class InfoBase)
	public class SyslogNotifier : InfoBase {
		public Boolean Enabled;
		public String SyslogNotifierId;
		public String[] Target;

		// Implicit constructor
		public SyslogNotifier () {}
	}

	// Tag (inherits from class InfoBase)
	public class Tag : InfoBase {
		public String Caption;
		public Object ChildTagList;
		public String ColorHex;
		public DateTime CreationTime;
		public Object DirectObjectList;
		public Int32 NumChildTag;
		public Int32 NumDirectObject;
		public Int32 NumItem;
		public Object ObjectList;
		public String ObjectType;
		public Object ParentTag;
		public String TagId;

		// Implicit constructor
		public Tag () {}
	}

	// Target (iSCSI/FC target)
	public class Target : InfoBase {
		public Object Brick;
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'Brick' instead", false)]
		public Object[] BrickId;
		public String DriverVersion;
		public String ErrorReason;
		public Object FCIssue;
		public String FWVersion;
		public Int64 IOPS;
		public Boolean JumboFrameEnabled;
		public Int32 MTU;
		public Object PerformanceInfo;
		public String PortAddress;
		public String PortMacAddress;
		public String PortSpeed;
		public String PortState;
		public String PortType;
		public Object StorageController;
		public Object TargetGroup;
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'TargetGroup' instead", false)]
		public Object[] TargetGrpId;
		public String TargetId;

		// Implicit constructor
		public Target () {}
	}

	public class TargetGroup : InfoBase {
		public String ClusterName;
		public Object[] SysId;
		public String TargetGrpId;

		// Implicit constructor
		public TargetGroup () {}
	}

	// TargetPerformance (inherits from class PerformanceTotal)
	public class TargetPerformance : PerformanceTotal {}

	// User Account (inherits from class InfoBase)
	public class UserAccount : InfoBase {
		public Int32 InactivityTimeoutMin;
		public Boolean IsExternal;
		public String Role;
		public String UserAccountId;

		// Implicit constructor
		public UserAccount () {}
	}

	public class Volume : InfoBase {
		public System.Nullable<Int32> AlignmentOffset;
		public Object AncestorVolId;
		public String Compressible;
		public System.Nullable<DateTime> CreationTime;
		public Object DestSnapList;
		public Object Folder;
		public String[] InitiatorGrpIdList;
		public System.Nullable<Int64> IOPS;
		public System.Nullable<Int32> LBSize;
		public String LuName;
		public Object LunMapList;
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'LunMapList' instead", false)]
		public Object LunMappingList;
		public String NaaName;
		public System.Nullable<Int32> NumDestSnap;
		public System.Nullable<Int32> NumLunMap;
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'NumLunMap' instead", false)]
		public System.Nullable<Int32> NumLunMapping;
		public Object PerformanceInfo;
		public String SmallIOAlertsCfg;
		public String SmallIORatio;
		public String SmallIORatioLevel;
		public Object SnapGrpId;
		public String SnapshotType;
		public Object[] SysId;
		public Object TagList;
		public String UnalignedIOAlertsCfg;
		public String UnalignedIORatio;
		public String UnalignedIORatioLevel;
		public System.Nullable<Double> UsedLogicalTB;
		public String VaaiTPAlertsCfg;
		public String VolId;
		public System.Nullable<Double> VolSizeTB;

		// Implicit constructor
		public Volume () {}
	}

	public class VolumeFolder : InfoBase {
		public String Caption;
		public String ColorHex;
		public System.Nullable<DateTime> CreationTime;
		public String FolderId;
		public Int64 IOPS;
		public Int32 NumChild;
		public Int32 NumSubfolder;
		public Int32 NumVol;
		public String ObjectType;
		public String ParentFolder;
		public String ParentFolderId;
		public Object PerformanceInfo;
		public Object SubfolderList;
		public String[] VolIdList;
		public Double VolSizeTB;

		// Implicit constructor
		public VolumeFolder () {}
	}

	// VolumeFolderPerformance (inherits from class PerformanceTotal)
	public class VolumeFolderPerformance : PerformanceTotal {}

	// VolumePerformance (inherits from class PerformanceTotal)
	public class VolumePerformance : PerformanceTotal {}

	public class XEnv : InfoBase {
		public Object Brick;
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'Brick' instead", false)]
		public Object[] BrickId;
		public Int32 CPUUsage;
		[System.ObsoleteAttribute("This property is deprecated and will go away in a future release. Use property 'NumModule' instead", false)]
		public Int32 NumMdl;
		public Int32 NumModule;
		public Object StorageController;
		public String XEnvId;
		public String XEnvState;

		// Implicit constructor
		public XEnv () {}
	}

	// XMS itself (inherits from class InfoBase)
	public class XMS : InfoBase {
		public Int32 BuildNumber;
		public Object[] Config;
		public String DiskSpaceUtilizationLevel;
		public String DiskSpaceSecUtilizationLevel;
		public Version DBVersion;
		public Object[] EventlogInfo;
		public String IPVersion;
		public String ISO8601DateTime;
		public Double LogSizeTotalGB;
		public Double MemoryTotalGB;
		public Double MemoryUsageGB;
		public String MemoryUtilizationLevel;
		public Int32 NumCluster;
		public Int32 NumInitiatorGroup;
		public Int32 NumIscsiRoute;
		public Double OverallEfficiency;
		public Version RestApiVersion;
		public String ServerName;
		public String SWVersion;
		public Int32 ThinProvSavingsPct;
		public Version Version;
		public Object[] PerformanceInfo;

		// Implicit constructor
		public XMS () {}
	}

	// connection to XMS appliance
	public class XioConnection {
		public String ComputerName;
		public DateTime ConnectDatetime;
		public System.Management.Automation.PSCredential Credential;
		public Int32 Port;
		public Version RestApiVersion;
		public Boolean TrustAllCert;
		public Version XmsDBVersion;
		public String XmsSWVersion;
		public Version XmsVersion;

		// Implicit constructor
		public XioConnection () {}
	}
} // end namespace

// Enumerations
namespace XioItemInfo.Enums.PerfCounter {
	public enum AggregationType {avg, min, max}
	//public enum EntityType {Cluster, DataProtectionGroup, Initiator, InitiatorGroup, SnapshotGroup, SSD, Tag, Target, TargetGroup, Volume, XEnv, Xms}
	public enum EntityType {Cluster, DataProtectionGroup, Initiator, InitiatorGroup, SnapshotGroup, SSD, Target, TargetGroup, Volume, XEnv, Xms}
	public enum Granularity {auto, one_minute, ten_minutes, one_hour, one_day, raw}
	public enum TimeFrame {real_time, last_hour, last_day, last_week, last_year}
} // end namespace
"@
