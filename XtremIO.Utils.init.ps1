Add-Type -TypeDefinition @"
	namespace XioItemInfo {
		// connection to XMS appliance
		public class XioConnection {
			public string ComputerName;
			public System.DateTime ConnectDatetime;
			public System.Management.Automation.PSCredential Credential;
			public System.Int32 Port;
			public System.Boolean TrustAllCert;

			// Implicit constructor
			public XioConnection () {}
		}
	}
"@
