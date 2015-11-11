Add-Type -TypeDefinition @"
	namespace XioItemInfo {
		// Alert (inherites from class InfoBase)
		public class Alert : InfoBase {
			public System.String AlertCode;
			public System.String AlertType;
			public System.String AssociatedObjId;
			public System.String AssociatedObjIndex;
			public System.String AssociatedObjName;
			public System.String Class;
			public System.String ClusterId;
			public System.String ClusterName;
			public System.DateTime CreationTime;
			public System.String Description;
			public System.String State;
			public System.String Threshold;

			// Implicit constructor
			public Alert () {}
		}

		public class AlertDefinition : InfoBase {
			public System.String AlertCode;
			public System.String AlertType;
			public System.String Class;
			public System.String ClearanceMode;
			public System.Boolean Enabled;
			public System.Boolean SendToCallHome;
			public System.String ThresholdType;
			public System.Int32 ThresholdValue;
			public System.Boolean UserModified;

			// Implicit constructor
			public AlertDefinition () {}
		}

		// XIO BBU (inherites from class HardwareBase)
		public class BBU : HardwareBase {
			public System.Object[] Battery;
			public System.Int32 BatteryChargePct;
			public System.String BBUId;
			public System.Object[] BrickId;
			public System.Boolean BypassActive;
			public System.Boolean ConnectedToSC;
			public System.String ClusterId;
			public System.String ClusterName;
			public System.Boolean Enabled;
			public System.String FWVersionError;
			public System.Int32 IndexInXbrick;
			public System.String Input;
			public System.Double InputHz;
			public System.Int32 InputVoltage;
			public System.Int32 LoadPct;
			public System.String LoadPctLevel;
			public System.String Outlet1Status;
			public System.String Outlet2Status;
			public System.Double OutputA;
			public System.Double OutputHz;
			public System.Double OutputVoltage;
			public System.String PowerFeed;
			public System.Int32 PowerW;
			public System.Int32 RealPowerW;
			public System.String Status;
			public System.Object[] StorageController;
			public System.Object[] TagList;
			public System.String UPSAlarm;
			public System.Boolean UPSOverloaded;
			public System.Object[] SysId;

			// Implicit constructor
			public BBU () {}
		}

		// XIO Brick
		public class Brick {
			public System.Object[] BrickId;
			public string BrickGuid;
			public string ClusterName;
			public string ComputerName;
			public System.Int32 Index;
			public string Name;
			// Storage Controller info
			public System.Object[] NodeList;
			public System.Int32 NumNode;
			public System.Int32 NumSSD;
			// Data Protection Group info
			public System.Object[] RGrpId;
			// array of SSD Slot info items
			public System.Object[] SsdSlotInfo;
			public string State;
			// URI of given object
			public string Uri;
			public System.Object[] XmsId;

			// Implicit constructor
			public Brick () {}
		}

		public class Cluster {
			public System.Object[] BrickList;
			public System.Decimal CompressionFactor;
			public System.String CompressionMode;
			public System.String ComputerName;
			public System.String ConsistencyState;
			public System.Decimal DataReduction;
			public System.Decimal DedupeRatio;
			public System.String EncryptionMode;
			public System.Boolean EncryptionSupported;
			public System.String FcPortSpeed;
			public System.String FreespaceLevel;
			public System.Double FreeSSDTB;
			public System.Int32 Index;
			public System.Object[] InfiniBandSwitchList;
			public System.Int64 IOPS;
			public System.String LicenseId;
			public System.String NaaSysId;
			public System.String Name;
			public System.Int32 NumBrick;
			public System.Int32 NumInfiniBandSwitch;
			public System.Int32 NumSSD;
			public System.Int32 NumVol;
			public System.Int32 NumXenv;
			public System.String OverallEfficiency;
			public System.Object PerformanceInfo;
			public System.String SharedMemEfficiencyLevel;
			public System.String SharedMemInUseRatioLevel;
			public System.String SizeAndCapacity;
			public System.String SWVersion;
			public System.DateTime SystemActivationDateTime;
			public System.Int32 SystemActivationTimestamp;
			public System.String SystemSN;
			public System.String SystemState;
			public System.String SystemStopType;
			public System.Decimal ThinProvSavingsPct;
			public System.Double TotProvTB;
			public System.Double TotSSDTB;
			public System.String Uri;
			public System.Double UsedLogicalTB;
			public System.Double UsedSSDTB;

			// Implicit constructor
			public Cluster() {}
		}

		// ClusterPerformance (inherits from class PerformanceTotal)
		public class ClusterPerformance : PerformanceTotal {}

		// ConsistencyGroup (inherits from InfoBase)
		public class ConsistencyGroup : InfoBase {
			public System.String Certainty;
			public System.String ClusterId;
			public System.String ClusterName;
			public System.String ConsistencyGrpId;
			public System.String ConsistencyGrpShortId;
			public System.String CreatedByApp;
			public System.Int32 NumVol;
			public System.Object[] SysId;
			public System.Object[] TagList;
			public System.Object[] VolList;

			// Implicit constructor
			public ConsistencyGroup () {}
		}

		// XIO DAE (Disk Array Enclosure) (inherits from class HardwareBase)
		public class DAE : HardwareBase {
			public System.Object[] BrickId;
			public System.String ClusterId;
			public System.String ClusterName;
			public System.String DAEId;
			public System.Int32 NumDAEController;
			public System.Int32 NumDAEPSU;
			public System.String ReplacementReason;
			public System.Object[] TagList;
			public System.Object[] SysId;

			// Implicit constructor
			public DAE () {}
		}

		// XIO DAE (Disk Array Enclosure) PSU (inherits from class HardwareBase)
		public class DAEPsu : HardwareBase {
			public System.Object[] BrickId;
			public System.Object[] DAE;
			public System.String DAEPSUId;
			public System.Boolean Enabled;
			public System.String FWVersionError;
			public System.String Identification;
			public System.String Input;
			public System.String Location;
			public System.String PowerFailure;
			public System.String PowerFeed;
			public System.String ReplacementReason;
			public System.Object[] SysId;

			// Implicit constructor
			public DAEPsu () {}
		}

		// XIO DAE Controller (inherits from class HardwareBase)
		public class DAEController : HardwareBase {
			public System.Object[] BrickId;
			public System.String ConnectivityState;
			public System.String ClusterId;
			public System.String ClusterName;
			public System.String DAEId;
			public System.String DAEControllerId;
			public System.Boolean Enabled;
			public System.String FailureReason;
			public System.String FWVersionError;
			public System.String HealthLevel;
			public System.String Identification;
			public System.String Location;
			public System.String ReplacementReason;
			public System.Object[] SAS;
			public System.Object[] SysId;

			// Implicit constructor
			public DAEController () {}
		}

		public class DataProtectionGroup {
			public System.Int32 AvailableRebuild;
			public System.Int32 BrickIndex;
			public System.String BrickName;
			public System.Int32 ClusterIndex;
			public System.String ClusterName;
			public System.String ComputerName;
			public System.Int32 Index;
			public System.Int64 IOPS;
			public System.String Name;
			public System.Int32 NumNode;
			public System.Int32 NumSSD;
			public System.Object PerformanceInfo;
			public System.Boolean RebalanceInProg;
			public System.Int32 RebalanceProgress;
			public System.Boolean RebuildInProg;
			public System.String RebuildPreventionReason;
			public System.Int32 RebuildProgress;
			public System.Object[] RGrpId;
			public System.Boolean SSDPrepInProg;
			public System.Int32 SSDPrepProgress;
			public System.String State;
			public System.Double TotSSDTB;
			public System.String Uri;
			public System.Double UsedSSDTB;
			public System.Double UsefulSSDTB;
			public System.Object[] XmsId;

			// Implicit constructor
			public DataProtectionGroup() {}
		}

		// DataProtectionGroupPerformance (inherits from class PerformanceBase)
		public class DataProtectionGroupPerformance : PerformanceBase {}


		// XIO Email Notifier
		public class EmailNotifier {
			public System.String CompanyName;
			public System.String ContactDetails;
			public System.Boolean Enabled;
			public System.Int32 FrequencySec;
			public System.String Guid;
			public System.Int32 Index;
			public System.String MailRelayAddress;
			public System.String MailUsername;
			public System.String Name;
			public System.String ProxyAddress;
			public System.String ProxyPort;
			public System.String ProxyUser;
			public System.String[] Recipient;
			public System.String Severity;
			public System.String TransportProtocol;
			public System.String ComputerName;
			public System.String Uri;
			public System.Object[] XmsId;

			// Implicit constructor
			public EmailNotifier () {}
		}

		// XIO Events
		public class Event {
			public System.String Category;
			public System.String ComputerName;
			public System.DateTime DateTime;
			public System.String Description;
			public System.String EntityDetails;
			public System.String EntityType;
			public System.Int32 EventID;
			public System.String RelAlertCode;
			public System.String Severity;
			public System.String Uri;

			// Implicit constructor
			public Event () {}
		}

		// general HardwareBase class (inherits from class InfoBase)
		public class HardwareBase : InfoBase {
			public System.String FWVersion;
			public System.String HWRevision;
			public System.String IdLED;
			public System.String LifecycleState;
			public System.String Model;
			public System.String PartNumber;
			public System.String SerialNumber;
			public System.String StatusLED;

			// Implicit constructor
			public HardwareBase() {}
		}

		// Initiator Group Folder
		public class IgFolder {
			public System.String Caption;
			public System.String ComputerName;
			public System.Object[] FolderId;
			public System.Int32 Index;
			public System.String[] InitiatorGrpIdList;
			public System.Int64 IOPS;
			public System.String Name;
			public System.Int32 NumIG;
			public System.Int32 NumSubfolder;
			public System.String ParentFolder;
			public System.String ParentFolderId;
			public System.Object PerformanceInfo;
			public System.Object[] SubfolderList;
			public System.String Uri;
			public System.Object[] XmsId;

			// Implicit constructor
			public IgFolder () {}
		}

		// InfiniBand Switch (inherits from class HardwareBase)
		public class InfinibandSwitch : HardwareBase {
			public System.Boolean Enabled;
			public System.Int32 Fan1RPM;
			public System.Int32 Fan2RPM;
			public System.Int32 Fan3RPM;
			public System.Int32 Fan4RPM;
			public System.String FanDrawerStatus;
			public System.String FWVersionError;
			public System.String IbSwitchId;
			public System.String InterswitchIb1Port;
			public System.String InterswitchIb2Port;
			public System.Object[] Port;
			public System.String ReplacementReason;
			public System.Object[] SysId;
			public System.Object[] TagList;
			public System.Object[] TemperatureSensor;
			public System.Object[] VoltageSensor;
			public System.String WrongSCConnection;

			// Implicit constructor
			public InfinibandSwitch () {}
		}

		// general InfoBase class
		public class InfoBase {
			public System.String ComputerName;
			public System.String Guid;
			public System.Int32 Index;
			public System.String Name;
			public System.String Severity;
			public System.String Uri;
			public System.Object[] XmsId;

			// Implicit constructor
			public InfoBase() {}
		}

		// Initiator Group Folder Performance (inherits from class PerformanceTotal)
		public class IgFolderPerformance : PerformanceTotal {}

		public class Initiator {
			public System.String ComputerName;
			public System.String ConnectionState;
			public System.Int32 Index;
			public System.String InitiatorGrpId;
			public System.Object[] InitiatorId;
			public System.Int64 IOPS;
			public System.String Name;
			public System.Object PerformanceInfo;
			public System.String PortAddress;
			public System.String PortType;
			public System.String Uri;

			// Implicit constructor
			public Initiator () {}
		}

		public class InitiatorGroup {
			public System.String ComputerName;
			public System.Int32 Index;
			public System.String InitiatorGrpId;
			public System.Int64 IOPS;
			public System.String Name;
			public System.Int32 NumInitiator;
			public System.Int32 NumVol;
			public System.Object PerformanceInfo;
			public System.String Uri;
			public System.Object[] XmsId;

			// Implicit constructor
			public InitiatorGroup () {}
		}

		// InitiatorGroupPerformance (inherits from class PerformanceTotal)
		public class InitiatorGroupPerformance : PerformanceTotal {}

		// InitiatorPerformance (inherits from class PerformanceTotal)
		public class InitiatorPerformance : PerformanceTotal {}

		// LDAP Config (inherits from class InfoBase)
		public class LdapConfig : InfoBase {
			public System.String BindDN;
			public System.String CACertData;
			public System.String CACertFile;
			public System.Int32 CacheExpireH;
			public System.String[] Role;
			public System.String SearchBaseDN;
			public System.String SearchFilter;
			public System.String[] ServerUrl;
			public System.String[] ServerUrlExample;
			public System.Int32 TimeoutSec;
			public System.String UserToDnRule;

			// Implicit constructor
			public LdapConfig () {}
		}

		// XIO LocalDisk in StorageControllers (inherits from class HardwareBase)
		public class LocalDisk : HardwareBase {
			public System.Object[] BrickId;
			public System.String ClusterId;
			public System.String ClusterName;
			public System.Boolean Enabled;
			public System.String EncryptionStatus;
			public System.String ExpectedType;
			public System.String FailureReason;
			public System.String FWVersionError;
			public System.String LocalDiskId;
			public System.Int32 NumBadSector;
			public System.String Purpose;
			public System.String ReplacementReason;
			public System.Int32 SlotNum;
			public System.String StorageControllerId;
			public System.String StorageControllerName;
			public System.Object[] SysId;
			public System.Object[] TagList;
			public System.String Type;
			public System.String Wwn;

			// Implicit constructor
			public LocalDisk () {}
		}

		public class LunMap {
			public System.String ComputerName;
			public System.String InitiatorGroup;
			public System.Int32 InitiatorGrpIndex;
			public System.Int32 LunId;
			public System.Object[] MappingId;
			public System.Int32 MappingIndex;
			public System.Int32 TargetGrpIndex;
			public System.String TargetGrpName;
			public System.String Uri;
			public System.Int32 VolumeIndex;
			public System.String VolumeName;
			public System.Object[] XmsId;

			// Implicit constructor
			public LunMap () {}
		}

		// general PerformanceBase class
		public class PerformanceBase {
			public System.Double BW_MBps;
			public System.String ComputerName;
			public System.Int32 Index;
			public System.Int64 IOPS;
			public System.String Name;
			public System.Double ReadBW_MBps;
			public System.Int32 ReadIOPS;
			public System.Double WriteBW_MBps;
			public System.Int32 WriteIOPS;

			// Implicit constructor
			public PerformanceBase() {}
		}

		// Performance class with Totals (inherits from class PerformanceBase)
		public class PerformanceTotal : PerformanceBase {
			public System.Int64 TotReadIOs;
			public System.Int64 TotWriteIOs;
		}

		// Snapshot Scheduler
		public class SnapshotScheduler {
			public System.String Name;
			public System.Boolean Enabled;
			public System.String Guid;
			public System.Int32 Index;
			public System.DateTime? LastActivated;
			public System.String LastActivationResult;
			public System.Int32 NumSnapToKeep;
			public System.TimeSpan Retain;
			public System.String Schedule;
			public System.Object SnappedObject;
			public System.String SnapshotSchedulerId;
			public System.String SnapType;
			public System.String State;
			public System.String Suffix;
			public System.String Type;
			public System.String ComputerName;
			public System.String Uri;

			// Implicit constructor
			public SnapshotScheduler () {}
		}

		// Snapshot (inherits Volume class)
		public class Snapshot : Volume {}

		// SnapshotSet (inherits from InfoBase)
		public class SnapshotSet : InfoBase {
			public System.String ClusterId;
			public System.String ClusterName;
			public System.String ConsistencyGrpId;
			public System.String ConsistencyGrpName;
			public System.DateTime CreationTime;
			public System.Int32 NumVol;
			public System.String SnapshotSetId;
			public System.String SnapshotSetShortId;
			public System.Object[] SysId;
			public System.Object[] TagList;
			public System.Object[] VolList;

			// Implicit constructor
			public SnapshotSet () {}
		}

		// SNMP Notifier (inherits from class InfoBase)
		public class SnmpNotifier : InfoBase {
			public System.String AuthProtocol;
			public System.String Community;
			public System.Boolean Enabled;
			public System.Int32 HeartbeatFreqSec;
			public System.Int32 Port;
			public System.String PrivacyProtocol;
			public System.String[] Recipient;
			public System.String SNMPVersion;
			public System.String Username;

			// Implicit constructor
			public SnmpNotifier () {}
		}

		// Slot (inherits from class InfoBase)
		public class Slot : InfoBase {
			public System.Object[] BrickId;
			public System.String ErrorReason;
			public System.String FailureReason;
			public System.String SsdModel;
			public System.Int32 SlotNum;
			public System.String SsdId;
			public System.Double SsdSizeGB;
			public System.String SsdUid;
			public System.String State;
			public System.Object[] SysId;

			// Implicit constructor
			public Slot () {}
		}

		// SSD
		public class Ssd {
			public System.Object[] BrickId;
			public System.Double CapacityGB;
			public System.String ComputerName;
			public System.String DiagHealthState;
			public System.String EnabledState;
			public System.String EncryptionStatus;
			public System.String FWVersion;
			public System.String FWVersionError;
			public System.String HealthState;
			public System.String HWRevision;
			public System.String IdLED;
			public System.Int32 Index;
			public System.Int64 IOPS;
			public System.String LifecycleState;
			public System.String ModelName;
			public System.String Name;
			public System.String ObjSeverity;
			public System.String PartNumber;
			public System.Int32 PctEnduranceLeft;
			public System.String PctEnduranceLeftLvl;
			public System.Object PerformanceInfo;
			public System.Object[] RGrpId;
			public System.String SerialNumber;
			public System.Int32 SlotNum;
			public System.String SSDFailureReason;
			public System.Object[] SsdId;
			public System.String SSDLink1Health;
			public System.String SSDLink2Health;
			public System.String SSDPositionState;
			public System.String SsdRGrpState;
			public System.String SsdUid;
			public System.String StatusLED;
			public System.String SwapLED;
			public System.Object[] SysId;
			public System.String Uri;
			public System.Double UsedGB;
			public System.Double UsefulGB;
			public System.Object[] XmsId;

			// Implicit constructor
			public Ssd () {}
		}

		// SsdPerformance (inherits from class PerformanceBase)
		public class SsdPerformance : PerformanceBase {}

		public class StorageController {
			public System.String BiosFWVersion;
			public System.String BrickName;
			public System.String Cluster;
			public System.String ComputerName;
			public System.String EnabledState;
			public System.String EncryptionMode;
			public System.String EncryptionSwitchStatus;
			public System.Object FcHba;
			public System.String HealthState;
			public System.String IBAddr1;
			public System.String IBAddr2;
			public System.String IPMIAddr;
			public System.String IPMIState;
			public System.String JournalState;
			public System.String MgmtPortSpeed;
			public System.String MgmtPortState;
			public System.String MgrAddr;
			public System.String Name;
			public System.String NodeMgrConnState;
			public System.Int32 NumSSD;
			public System.Int32 NumSSDDown;
			public System.Int32 NumTargetDown;
			public System.String OSVersion;
			public System.Object PCI;
			public System.String PoweredState;
			public System.String RemoteJournalHealthState;
			public System.Object[] SAS;
			public System.String SdrFWVersion;
			public System.String SerialNumber;
			public System.String State;
			public System.String SWVersion;
			public System.String Uri;

			// Implicit constructor
			public StorageController () {}
		}

		// XIO StorageController (inherites from class HardwareBase)
		public class StorageControllerPsu : InfoBase {
			public System.Object[] BrickId;
			public System.Boolean Enabled;
			public System.String FWVersionError;
			public System.String HWRevision;
			public System.String Input;
			public System.String LifecycleState;
			public System.String Location;
			public System.String Model;
			public System.String PartNumber;
			public System.String PowerFailure;
			public System.String PowerFeed;
			public System.String ReplacementReason;
			public System.String SerialNumber;
			public System.String StatusLED;
			public System.Object[] StorageController;
			public System.String StorageControllerPSUId;
			public System.Object[] SysId;

			// Implicit constructor
			public StorageControllerPsu () {}
		}

		// SyslogNotifier (inherits from class InfoBase)
		public class SyslogNotifier : InfoBase {
			public System.Boolean Enabled;
			public System.String SyslogNotifierId;
			public System.String[] Target;

			// Implicit constructor
			public SyslogNotifier () {}
		}

		// Tag (inherits from class InfoBase)
		public class Tag : InfoBase {
			public System.String Caption;
			public System.Object[] ChildTagList;
			public System.String ColorHex;
			public System.DateTime CreationTime;
			public System.Object[] DirectObjectList;
			public System.Int32 NumChildTag;
			public System.Int32 NumDirectObject;
			public System.Int32 NumItem;
			public System.Object[] ObjectList;
			public System.String ObjectType;
			public System.Object ParentTag;
			public System.String TagId;

			// Implicit constructor
			public Tag () {}
		}

		// Target
		public class Target {
			public System.Object[] BrickId;
			public System.String ComputerName;
			public System.String DriverVersion;
			public System.Object FCIssue;
			public System.String FWVersion;
			public System.Int32 Index;
			public System.Int64 IOPS;
			public System.Boolean JumboFrameEnabled;
			public System.Int32 MTU;
			public System.String Name;
			public System.Object PerformanceInfo;
			public System.String PortAddress;
			public System.String PortSpeed;
			public System.String PortState;
			public System.String PortType;
			public System.Object[] TargetGrpId;
			public System.String Uri;

			// Implicit constructor
			public Target () {}
		}

		public class TargetGroup {
			public System.String ClusterName;
			public System.String ComputerName;
			public System.Int32 Index;
			public System.String Name;
			public System.Object[] SysId;
			public System.Object[] TargetGrpId;
			public System.String Uri;
			public System.Object[] XmsId;

			// Implicit constructor
			public TargetGroup () {}
		}

		// TargetPerformance (inherits from class PerformanceTotal)
		public class TargetPerformance : PerformanceTotal {}

		// User Account (inherits from class InfoBase)
		public class UserAccount : InfoBase {
			public System.Int32 InactivityTimeoutMin;
			public System.Boolean IsExternal;
			public System.String Role;
			public System.String UserAccountId;

			// Implicit constructor
			public UserAccount () {}
		}

		public class Volume {
			public System.Int32 AlignmentOffset;
			public System.Object[] AncestorVolId;
			public System.String Compressible;
			public System.String ComputerName;
			public System.DateTime CreationTime;
			public System.Object[] DestSnapList;
			public System.Int32 Index;
			public System.String[] InitiatorGrpIdList;
			public System.Int64 IOPS;
			public System.Int32 LBSize;
			public System.String LuName;
			public System.Object[] LunMappingList;
			public System.String NaaName;
			public System.String Name;
			public System.Int32 NumDestSnap;
			public System.Int32 NumLunMapping;
			public System.Object PerformanceInfo;
			public System.String SmallIOAlertsCfg;
			public System.String SmallIORatio;
			public System.String SmallIORatioLevel;
			public System.Object[] SnapGrpId;
			public System.Object[] SysId;
			public System.String UnalignedIOAlertsCfg;
			public System.String UnalignedIORatio;
			public System.String UnalignedIORatioLevel;
			public System.String Uri;
			public System.Double UsedLogicalTB;
			public System.String VaaiTPAlertsCfg;
			public System.String VolId;
			public System.Double VolSizeTB;
			public System.Object[] XmsId;

			// Implicit constructor
			public Volume () {}
		}

		public class VolumeFolder {
			public System.String ComputerName;
			public System.String FolderId;
			public System.Int32 Index;
			public System.Int64 IOPS;
			public System.String Name;
			public System.Int32 NumChild;
			public System.Int32 NumSubfolder;
			public System.Int32 NumVol;
			public System.String ParentFolder;
			public System.String ParentFolderId;
			public System.Object PerformanceInfo;
			public System.String Uri;
			public System.String[] VolIdList;
			public System.Double VolSizeTB;
			public System.Object[] XmsId;

			// Implicit constructor
			public VolumeFolder () {}
		}

		// VolumeFolderPerformance (inherits from class PerformanceTotal)
		public class VolumeFolderPerformance : PerformanceTotal {}

		// VolumePerformance (inherits from class PerformanceTotal)
		public class VolumePerformance : PerformanceTotal {}

		public class XEnv {
			public System.Object[] BrickId;
			public System.String ComputerName;
			public System.Int32 CPUUsage;
			public System.Int32 Index;
			public System.String Name;
			public System.Int32 NumMdl;
			public System.String Uri;
			public System.Object[] XEnvId;
			public System.String XEnvState;
			public System.Object[] XmsId;

			// Implicit constructor
			public XEnv () {}
		}

		// XMS itself (inherits from class InfoBase)
		public class XMS : InfoBase {
			public System.Int32 BuildNumber;
			public System.Object[] Config;
			public System.String DiskSpaceUtilizationLevel;
			public System.String DiskSpaceSecUtilizationLevel;
			public System.Version DBVersion;
			public System.Object[] EventlogInfo;
			public System.String IPVersion;
			public System.String ISO8601DateTime;
			public System.Double LogSizeTotalGB;
			public System.Double MemoryTotalGB;
			public System.Double MemoryUsageGB;
			public System.String MemoryUtilizationLevel;
			public System.Int32 NumCluster;
			public System.Int32 NumInitiatorGroup;
			public System.Int32 NumIscsiRoute;
			public System.Double OverallEfficiency;
			public System.Version RestApiVersion;
			public System.String ServerName;
			public System.String SWVersion;
			public System.Int32 ThinProvSavingsPct;
			public System.Version Version;
			public System.Object[] PerformanceInfo;

			// Implicit constructor
			public XMS () {}
		}

		// connection to XMS appliance
		public class XioConnection {
			public System.String ComputerName;
			public System.DateTime ConnectDatetime;
			public System.Management.Automation.PSCredential Credential;
			public System.Int32 Port;
			public System.Version RestApiVersion;
			public System.Boolean TrustAllCert;
			public System.Version XmsDBVersion;
			public System.String XmsSWVersion;
			public System.Version XmsVersion;

			// Implicit constructor
			public XioConnection () {}
		}
	} // end namespace

	// Enumerations
	namespace XioItemInfo.Enums.PerfCounter {
		public enum AggregationType {avg, max, min}
		public enum EntityType {Cluster, DataProtectionGroup, Initiator, InitiatorGroup, SnapshotGroup, SSD, Tag, Target, TargetGroup, Volume, XEnv, Xms}
		public enum Granularity {auto, one_minute, ten_minutes, one_hour, one_day, raw}
	} // end namespace
"@
