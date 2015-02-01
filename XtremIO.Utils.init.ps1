Add-Type -TypeDefinition @"
	namespace XioItemInfo {
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
			public System.Management.Automation.PSCustomObject PerformanceInfo;
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

		// connection to XMS appliance
		public class XioConnection {
			public System.String ComputerName;
			public System.DateTime ConnectDatetime;
			public System.Management.Automation.PSCredential Credential;
			public System.Int32 Port;
			public System.Boolean TrustAllCert;

			// Implicit constructor
			public XioConnection () {}
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

		public class Initiator {
			public System.String ComputerName;
			public System.String ConnectionState;
			public System.Int32 Index;
			public System.Object[] InitiatorGrpId;
			public System.Object[] InitiatorId;
			public System.Int64 IOPS;
			public System.String Name;
			public System.Management.Automation.PSCustomObject PerformanceInfo;
			public System.String PortAddress;
			public System.String PortType;
			public System.String Uri;

			// Implicit constructor
			public Initiator () {}
		}

		// InitiatorPerformance (inherits from class PerformanceTotal)
		public class InitiatorPerformance : PerformanceTotal {}

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

		// Snapshot (inherits Volume class)
		public class Snapshot : Volume {}

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
			public System.Management.Automation.PSCustomObject PerformanceInfo;
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

		// Target
		public class Target {
			public System.Object[] BrickId;
			public System.String ComputerName;
			public System.String DriverVersion;
			public System.Management.Automation.PSCustomObject FCIssue;
			public System.String FWVersion;
			public System.Object[] Id;
			public System.Int32 Index;
			public System.Int64 IOPS;
			public System.Boolean JumboFrameEnabled;
			public System.Int32 MTU;
			public System.String Name;
			public System.Management.Automation.PSCustomObject PerformanceInfo;
			public System.String PortAddress;
			public System.String PortSpeed;
			public System.String PortState;
			public System.String PortType;
			public System.String Uri;

			// Implicit constructor
			public Target () {}
		}

		// TargetPerformance (inherits from class PerformanceTotal)
		public class TargetPerformance : PerformanceTotal {}

		public class Volume {
			public System.Int32 AlignmentOffset;
			public System.Object[] AncestorVolId;
			public System.String Compressible;
			public System.String ComputerName;
			public System.DateTime CreationTime;
			public System.Object[] DestSnapList;
			public System.Int32 Index;
			public System.Int64 IOPS;
			public System.Int32 LBSize;
			public System.String LuName;
			public System.Object[] LunMappingList;
			public System.String NaaName;
			public System.String Name;
			public System.Int32 NumDestSnap;
			public System.Int32 NumLunMapping;
			public System.Management.Automation.PSCustomObject PerformanceInfo;
			public System.String SmallIOAlertsCfg;
			public System.String SmallIORatio;
			public System.String SmallIORatioLevel;
			public System.Object[] SnapGrpId;
			public System.Object[] SysId;
			public System.String UnalignedIOAlertsCfg;
			public System.String UnalignedIORatio;
			public System.String UnalignedIORatioLevel;
			public System.String Uri;
			public System.Int32 UsedLogicalTB;
			public System.String VaaiTPAlertsCfg;
			public System.Object[] VolId;
			public System.Double VolSizeTB;
			public System.Object[] XmsId;

			// Implicit constructor
			public Volume () {}
		}

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
	}
"@
