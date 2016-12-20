### XtremIO.Utils PowerShell module

Some examples and their sample output (see each cmdlet's help for more examples):

#### Create new stored credential, connect to an XIO XMS

```powershell
PS C:\> New-XIOStoredCred -Credential (Get-Credential admin)
Windows PowerShell credential request
Enter your credentials.
Password for user admin: **********************************

VERBOSE: Credentials encrypted (via Windows Data Protection API) and saved to:
'C:\Users\someuser0\AppData\Local\Temp\xioCred_by_someuser0_on_somecomputer0.enc.xml'


PS C:\> Connect-XIOServer xms01.dom.com -TrustAllCert
ComputerName                    ConnectDatetime                         Port
------------                    ---------------                         ----
xms01.dom.com                   12/15/2015 6:36:31 PM                   443
```

#### Get XtremIO hardware and configuration items

```powershell
PS C:\> Get-XIOCluster
Name           TotSSDTB    UsedSSDTB   FreeSSDTB   UsedLogicalTB  TotProvTB  DataReduction  IOPS
----           --------    ---------   ---------   -------------  ---------  -------------  ----
xio01          7.59        4.67        2.92        14.80          85.67      3.2            4648


PS C:\> Get-XIOSsd -Name wwn-0x500000000abc0123
Name                   CapacityGB UsedGB SlotNum Model          FWVersion  PctEnduranceLeft IOPS
----                   ---------- ------ ------- -----          ---------  ---------------- ----
wwn-0x500000000abc0123 372.53     193.58 5       HITACHI  HU... C337       99               325


PS C:\> Get-XIOBrick
Name     Index    ClusterName          NumSSD   State
----     -----    -----------          ------   -----
X1       1        xio01                25       in_sys


PS C:\> Get-XIOStorageController
Name      State     MgrAddr       IPMIAddr      BrickName    Cluster NodeMgrConnState IPMIState
----      -----     -------       --------      ---------    ------- ---------------- ---------
X1-SC1    normal    10.0.0.10                   X1           xio01   connected        obsolete
X1-SC2    normal    10.0.0.11                   X1           xio01   connected        obsolete


PS C:\> Get-XIOTarget *fc*
Name              PortType          PortAddress                    PortState       Index    IOPS
----              --------          -----------                    ---------       -----    ----
X1-SC1-fc1        fc                99:00:aa:bb:cc:dd:ee:00        up              1        1286
X1-SC1-fc2        fc                99:00:aa:bb:cc:dd:ee:01        up              2        977
X1-SC2-fc1        fc                99:00:aa:bb:cc:dd:ee:04        up              5        823
X1-SC2-fc2        fc                99:00:aa:bb:cc:dd:ee:05        up              6        1274


PS C:\> Get-XIOTargetGroup
Name            Index    ClusterName
----            -----    -----------
Default         1        xio01


PS C:\> Get-XIOConsistencyGroup someTestCG0
Name                    ClusterName         NumVol               CreatedByApp        Certainty
----                    -----------         ------               ------------        ---------
someTestCG0             xio01               2                    xms                 ok
```

#### Fun with intitators, intiator groups, volumes

```powershell
PS C:\> Get-XIOInitiatorGroup vmhost06
Name                    Index                   NumInitiator            NumVol             IOPS
----                    -----                   ------------            ------             ----
vmhost06                6                       2                       23                 4067


PS C:\> Get-XIOInitiatorGroupFolder -Name /Group0/Cluster0 | Get-XIOInitiatorGroup
Name                    Index                   NumInitiator            NumVol            IOPS
----                    -----                   ------------            ------            ----
vmhost021               13                      2                       23                289
vmhost071u              14                      2                       23                137
vmhost100101            16                      2                       23                0
vmhostdev91             15                      2                       23                0
vmhost07                1                       2                       23                0
vmhost1011              5                       2                       23                146
vmhost06                6                       2                       23                3464


PS C:\> Get-XIOInitiatorGroup vmhost06 | Get-XIOInitiatorGroupFolder
Name                          ParentFolder                  NumIG               IOPS
----                          ------------                  -----               ----
/Group0/Cluster0              /InitiatorGroup/Group0        7                   0


PS C:\> Get-XIOVolumeFolder /Group0 | Get-XIOVolume
Name                    NaaName                 VolSizeTB          UsedLogicalTB         IOPS
----                    -------                 ---------          -------------         ----
clus01.xio01.004        514f000000000005        5.00               1.05                  16
clus01.xio01.008        514f000000000009        5.00               0.94                  2641
clus01.xio01.003        514f000000000004        5.00               1.23                  440
clus01.xio01.007        514f000000000008        5.00               1.13                  36
clus01.xio01.002        514f000000000003        5.00               0.87                  15
clus01.xio01.006        514f000000000007        5.00               1.11                  57
clus01.xio01.009        514f000000000019        5.00               0.19                  7
clus01.xio01.001        514f000000000002        5.00               0.75                  9
clus01.xio01.005        514f000000000006        5.00               1.17                  25


PS C:\> Get-XIOInitiatorGroup vmhost06
Name                    Index                   NumInitiator            NumVol           IOPS
----                    -----                   ------------            ------           ----
vmhost06                6                       2                       23               2320


PS C:\> Get-XIOInitiatorGroup vmhost06 | Get-XIOVolume
Name                    NaaName                 VolSizeTB            UsedLogicalTB         IOPS
----                    -------                 ---------            -------------         ----
clus01.xio01.008        514f000000000009        5.00                 0.94                  2214
clus01.xio01.007        514f000000000008        5.00                 1.13                  553
clus01.xio01.006        514f000000000007        5.00                 1.11                  54
clus01.xio01.009        514f000000000019        5.00                 0.19                  3
clus01.xio01.005        514f000000000006        5.00                 1.17                  61


PS C:\> Get-XIOInitiatorGroup vmhost06 | Get-XIOInitiator
Name                          PortAddress                   PortType                      IOPS
----                          -----------                   --------                      ----
vmhost06-hba2                 10:00:00:00:00:00:00:01       fc                            1113
vmhost06-hba3                 10:00:00:00:00:00:01:02       fc                            1320


PS C:\> Get-XIOVolume lab001.xio01.030 | Get-XIOVolumeFolder
Name                    ParentFolder            NumVol                  VolSizeTB         IOPS
----                    ------------            ------                  ---------         ----
/LabGroup1              /Volume                 2                       0.00              0


PS C:\> Get-XIOVolume clus01.xio01.082 | Get-XIOInitiatorGroup
Name                    Index                   NumInitiator            NumVol          IOPS
----                    -----                   ------------            ------          ----
vmhost021               13                      2                       23              358
vmhost071u              14                      2                       23              126
vmhost100101            16                      2                       23              0
vmhostdev91             15                      2                       23              0
vmhost06                1                       2                       23              0
vmhost300100            3                       2                       22              0
vmhost100101            2                       2                       22              215
vmhost1011              5                       2                       23              109
vmhost07                6                       2                       23              4031


PS C:\> Get-XIOLunMap -InitiatorGroup vmhost06 -Volume *0[23]
VolumeName                            LunId   InitiatorGroup                       TargetGrpName
----------                            -----   --------------                       -------------
clus01.xio01.003                      23      vmhost06                             Default
clus01.xio01.002                      22      vmhost06                             Default
```

#### Use -Property parameter to retrieve only given property values (good for efficiency)

```powershell
PS C:\> Get-XIOLunMap -Property VolumeName,LunId
VolumeName                            LunId   InitiatorGroup                       TargetGrpName
----------                            -----   --------------                       -------------
testvol02                             101
testvol02                             101
testvol03                             102
testvol03                             102
...
```

#### Use API filtering feature (available in XtremIO REST API v2.0 and up)
Initially supported in `Get-XIOItemInfo` cmdlet

```powershell
PS C:\> Get-XIOItemInfo -ItemType lun-map -Filter "filter=vol-name:eq:myVol02"
VolumeName           LunId   InitiatorGroup     TargetGrpName
----------           -----   --------------     -------------
myVol02              21      myIG0              Default
```

#### Create things

```powershell
PS C:\> New-XIOVolume -Name testvol02 -SizeGB 5KB -EnableVAAITPAlert -WhatIf
What if: Performing the operation "Create new 'volume' object named 'testvol02'" on target
"xms01.dom.com".


PS C:\> New-XIOVolume -Name testvol02 -SizeGB 5KB -EnableVAAITPAlert | New-XIOTagAssignment -Tag `
>> (Get-XIOTag -Name /Volume/myTestVolumes)
Tag                                  Entity
---                                  ------
/Volume/myTestVolumes                XioItemInfo.Volume


PS C:\> New-XIOLunMap -InitiatorGroup vmhost0IG,vmhost1IG -Volume testvol02 -HostLunId 101
VolumeName                   LunId   InitiatorGroup                       TargetGrpName
----------                   -----   --------------                       -------------
testvol02                    101     vmhost00IG                           Default
testvol02                    101     vmhost10IG                           Default


PS C:\> Get-XIOConsistencyGroup someTestCG0 | New-XIOSnapshot -Type ReadOnly
Name                     NaaName       VolSizeTB   UsedLogicalTB  IOPS   CreationTime
----                     -------       ---------   -------------  ----   ------------
someTestVol0.snapsh...                 0.00        0.00           0      12/15/2015 6:58:06 PM
someTestVol1.snapsh...                 0.00        0.00           0      12/15/2015 6:58:06 PM


PS C:\> New-XIOUserAccount -Credential (Get-Credential test_RoUser) -Role read_only
Windows PowerShell credential request
Enter your credentials.
Password for user test_RoUser: *****************

Name                 Role               InactivityTimeoutMin   IsExternal
----                 ----               --------------------   ----------
test_RoUser          read_only          10                     False


PS C:\> New-XIOSnapshotScheduler -RelatedObject (Get-XIOVolume myVol02) -Interval `
>> (New-Timespan -Days 2 -Hours 6 -Minutes 9) -SnapshotRetentionCount 20 -Name PeriodicSnaps_myVol
Name                   SnapType   Enabled  NumSnapToKeep  Retain         LastActivated
----                   --------   -------  -------------  ------         -------------
PeriodicSnaps_myVol    regular    False    20             1825.00:00:00


PS C:\> Get-XIOVolume myVol03 | New-XIOSnapshotScheduler -ExplicitDay EveryDay -ExplicitTimeOfDay `
>> 3am -SnapshotRetentionCount 500 -Suffix myScheduler0 -Name DailySnaps_myVol
Name                   SnapType   Enabled  NumSnapToKeep  Retain         LastActivated
----                   --------   -------  -------------  ------         -------------
DailySnaps_myVol       regular    False    500            1825.00:00:00
```

#### Get Events

```powershell
PS C:\> Get-XIOEvent -Start (Get-Date).AddMonths(-1) -End (Get-Date).AddMonths(-1).AddDays(1)
EventID  DateTime               Severity     EntityDetails    Description
-------  --------               --------     -------------    -----------
10626    11/16/2015 3:55:17 PM  minor                         Debug info collection output: L...
10625    11/16/2015 3:52:32 PM  information                   Calling collector command: /xtr...
10624    11/16/2015 3:50:33 PM  information                   Removed 0 old events...
10623    11/16/2015 12:05:48 PM information  xio01 [1]        Existing Initiators for Cluster...
10622    11/16/2015 12:05:48 PM information                   User: admin, Command: get_class...


PS C:\> Get-XIOEvent -Severity major
EventID  DateTime               Severity     EntityDetails    Description
-------  --------               --------     -------------    -----------
11871    12/9/2015 2:06:00 PM   major        xio01 [1]        Raised alert: "The cluster stat...
11867    12/9/2015 2:04:44 PM   major        X1-SC2 [2]       Raised alert: "The Storage Cont...
11866    12/9/2015 2:04:44 PM   major        X1-SC1 [1]       Raised alert: "The Storage Cont...
10000    11/11/2015 2:30:20 PM  major        xio01 [1]        Raised alert: "The cluster stat...
9998     11/11/2015 2:29:01 PM  major        X1-SC2 [2]       Raised alert: "The Storage Cont...
9997     11/11/2015 2:29:01 PM  major        X1-SC1 [1]       Raised alert: "The Storage Cont...


PS C:\> Get-XIOEvent -EntityType StorageController
EventID  DateTime               Severity     EntityDetails    Description
-------  --------               --------     -------------    -----------
12762    12/13/2015 11:02:14 AM information  X1-SC2 [2]       Removed alert: "Internal proces...
12761    12/13/2015 11:02:14 AM information  X1-SC2 [2]       Removed alert: "Storage Control...
12760    12/13/2015 11:02:12 AM information  X1-SC2 [2]       Storage Controller internal IPM...
12759    12/13/2015 11:02:12 AM information  X1-SC2 [2]       Storage Controller IPMI tempera...
10639    11/19/2015 9:12:05 AM  information  X1-SC2 [2]       XMS connection to the Storage C...
10638    11/19/2015 9:12:04 AM  information  X1-SC1 [1]       XMS connection to the Storage C...
9995     11/11/2015 2:28:27 PM  information  X1-SC2 [2]       XMS connection to the Storage C...


PS C:\> Get-XIOEvent -EntityType StorageController -SearchText level_3_warning
EventID  DateTime               Severity     EntityDetails    Description
-------  --------               --------     -------------    -----------
12760    12/13/2015 11:02:12 AM information  X1-SC2 [2]       Storage Controller internal IPM...
```

#### Get Performance information

```powershell
PS C:\> Get-XIOPerformanceCounter -EntityType Volume -TimeFrame real_time
Name              EntityType  DateTime                Granularity  Counters
----              ----------  --------                -----------  --------
lab001.xio01.030  Volume      12/15/2015 1:49:45 PM   raw          {@{rd_bw=0.0; acc_num_of_u...
lab001.xio01.029  Volume      12/15/2015 1:49:45 PM   raw          {@{rd_bw=3.0; acc_num_of_u...
clus01.xio01.009  Volume      12/15/2015 1:49:45 PM   raw          {@{rd_bw=0.0; acc_num_of_u...
clus01.xio01.001  Volume      12/15/2015 1:49:45 PM   raw          {@{rd_bw=7.0; acc_num_of_u...
clus01.xio01.003  Volume      12/15/2015 1:49:45 PM   raw          {@{rd_bw=16.0; acc_num_of_...
clus01.xio01.002  Volume      12/15/2015 1:49:45 PM   raw          {@{rd_bw=0.0; acc_num_of_u...
clus01.xio01.005  Volume      12/15/2015 1:49:45 PM   raw          {@{rd_bw=0.0; acc_num_of_u...
clus01.xio01.004  Volume      12/15/2015 1:49:45 PM   raw          {@{rd_bw=16.0; acc_num_of_...
clus01.xio01.007  Volume      12/15/2015 1:49:45 PM   raw          {@{rd_bw=0.0; acc_num_of_u...
clus01.xio01.006  Volume      12/15/2015 1:49:45 PM   raw          {@{rd_bw=12.0; acc_num_of_...
clus01.xio01.008  Volume      12/15/2015 1:49:45 PM   raw          {@{rd_bw=48599.0; acc_num_...


PS C:\> Get-XIOClusterPerformance
Name       WriteBW_MBps  WriteIOPS  ReadBW_MBps ReadIOPS BW_MBps  IOPS  TotWriteIOs  TotReadIOs
----       ------------  ---------  ----------- -------- -------  ----  -----------  ----------
xio01      13.736        1973       18.991      649      32.728   2622  27220416741  18105848654


PS C:\> Get-XIODataProtectionGroupPerformance
Name     WriteBW_MBps   WriteIOPS         ReadBW_MBps   ReadIOPS          BW_MBps           IOPS
----     ------------   ---------         -----------   --------          -------           ----
X1-DPG   27.643         3299              24.608        2904              52.251            6203


PS C:\> Get-XIOInitiatorGroupPerformance
Name          WriteBW_MBps WriteIOPS ReadBW_MBps ReadIOPS BW_MBps  IOPS  TotWriteIOs  TotReadIOs
----          ------------ --------- ----------- -------- -------  ----  -----------  ----------
vmhost021     4.278        296       0.030       1        4.309    297   2676254940   2394267297
vmhost10011   0.219        44        0.009       0        0.228    44    277720388    211296970
vmhost071u    0.667        94        0.008       0        0.675    94    2739502085   736298913
vmhost100101  0.025        4         0.000       0        0.025    4     247693       301492
vmhostdev91   0.000        0         0.000       0        0.000    0     381310       2946383
vmhost07      0.000        0         0.000       0        0.000    0     150076       413400
vmhost300100  0.000        0         0.000       0        0.000    0     927675147    212556672
vmhost100101  0.554        365       0.412       9        0.966    374   2888039621   620820053
vmhost1011    2.833        170       0.188       5        3.021    175   10641032708  7740983079
vmhost06      15.883       2158      49.646      1733     65.528   3891  6818089149   6059703551


PS C:\> Get-XIOVolumePerformance x*.00[5-8]
Name       WriteBW_MBps WriteIOPS ReadBW_MBps ReadIOPS BW_MBps  IOPS  TotWriteIOs TotReadIOs
----       ------------ --------- ----------- -------- -------  ----  ----------- ----------
xio01.008  16.146       2227      49.489      1732     65.636   3959  12997679660 10094555455
xio01.007  0.415        30        0.000       0        0.415    30    1006378979  2663027601
xio01.006  0.525        69        0.063       4        0.588    73    1513875264  748707640
xio01.005  0.096        14        0.000       0        0.096    14    618641301   192291561


PS C:\> Get-XIOVolumePerformance xio01.008 -FrequencySeconds 5 -DurationSeconds 30
Name       WriteBW_MBps WriteIOPS ReadBW_MBps ReadIOPS BW_MBps  IOPS  TotWriteIOs TotReadIOs
----       ------------ --------- ----------- -------- -------  ----  ----------- ----------
xio01.008  6.254        681       14.791      504      21.045   1185  12997711340 1009457...
VERBOSE: 2015.Dec.15 18:51:22; '5' sec sleep; ending run at/about 2015.Dec.15 18:51:52 ('30'...
xio01.008  6.254        681       14.791      504      21.045   1185  12997711340 1009457...
VERBOSE: 2015.Dec.15 18:51:27; '5' sec sleep; ending run at/about 2015.Dec.15 18:51:52 ('30'...
xio01.008  12.872       1719      46.272      1615     59.145   3334  12997719821 1009458...
VERBOSE: 2015.Dec.15 18:51:32; '5' sec sleep; ending run at/about 2015.Dec.15 18:51:52 ('30'...
xio01.008  14.411       1860      45.508      1582     59.919   3442  12997735148 1009459...
VERBOSE: 2015.Dec.15 18:51:37; '5' sec sleep; ending run at/about 2015.Dec.15 18:51:52 ('30'...
xio01.008  8.673        1133      24.227      839      32.899   1972  12997740730 1009460...
VERBOSE: 2015.Dec.15 18:51:42; '5' sec sleep; ending run at/about 2015.Dec.15 18:51:52 ('30'...
xio01.008  11.037       1587      41.355      1441     52.393   3028  12997748547 1009460...
```

#### Get raw API return items, and check out the "children" property for v1 and v2 of the API

```powershell
PS C:\> Get-XIOItemInfo -Uri https://xms01.dom.com/api/json/types -ReturnFullResponse | `
>> Select-Object -ExpandProperty children | ft -a
href                                                                   name
----                                                                   ----
https://xms01.dom.com/api/json/types/alert-definitions                 alert-definitions
https://xms01.dom.com/api/json/types/alerts                            alerts
https://xms01.dom.com/api/json/types/bbus                              bbus
https://xms01.dom.com/api/json/types/bricks                            bricks
https://xms01.dom.com/api/json/types/clusters                          clusters
https://xms01.dom.com/api/json/types/consistency-group-volumes         consistency-group-volumes
https://xms01.dom.com/api/json/types/consistency-groups                consistency-groups
https://xms01.dom.com/api/json/types/dae-controllers                   dae-controllers
https://xms01.dom.com/api/json/types/dae-psus                          dae-psus
https://xms01.dom.com/api/json/types/daes                              daes
https://xms01.dom.com/api/json/types/data-protection-groups            data-protection-groups
https://xms01.dom.com/api/json/types/email-notifier                    email-notifier
https://xms01.dom.com/api/json/types/events                            events
https://xms01.dom.com/api/json/types/ig-folders                        ig-folders
https://xms01.dom.com/api/json/types/infiniband-switches               infiniband-switches
https://xms01.dom.com/api/json/types/initiator-groups                  initiator-groups
https://xms01.dom.com/api/json/types/initiators                        initiators
https://xms01.dom.com/api/json/types/iscsi-portals                     iscsi-portals
https://xms01.dom.com/api/json/types/iscsi-routes                      iscsi-routes
https://xms01.dom.com/api/json/types/ldap-configs                      ldap-configs
https://xms01.dom.com/api/json/types/local-disks                       local-disks
https://xms01.dom.com/api/json/types/lun-maps                          lun-maps
https://xms01.dom.com/api/json/types/performance                       performance
https://xms01.dom.com/api/json/types/schedulers                        schedulers
https://xms01.dom.com/api/json/types/slots                             slots
https://xms01.dom.com/api/json/types/snapshot-sets                     snapshot-sets
https://xms01.dom.com/api/json/types/snapshots                         snapshots
https://xms01.dom.com/api/json/types/snmp-notifier                     snmp-notifier
https://xms01.dom.com/api/json/types/ssds                              ssds
https://xms01.dom.com/api/json/types/storage-controller-psus           storage-controller-psus
https://xms01.dom.com/api/json/types/storage-controllers               storage-controllers
https://xms01.dom.com/api/json/types/syslog-notifier                   syslog-notifier
https://xms01.dom.com/api/json/types/tags                              tags
https://xms01.dom.com/api/json/types/target-groups                     target-groups
https://xms01.dom.com/api/json/types/targets                           targets
https://xms01.dom.com/api/json/types/user-accounts                     user-accounts
https://xms01.dom.com/api/json/types/volume-folders                    volume-folders
https://xms01.dom.com/api/json/types/volumes                           volumes
https://xms01.dom.com/api/json/types/xenvs                             xenvs
https://xms01.dom.com/api/json/types/xms                               xms


PS C:\> Get-XIOItemInfo -Uri https://xms01.dom.com/api/json/v2/types -ReturnFullResponse | `
>> Select-Object -ExpandProperty children
href                                                                   name
----                                                                   ----
https://xms01.dom.com/api/json/v2/types/alert-definitions              alert-definitions
https://xms01.dom.com/api/json/v2/types/alerts                         alerts
https://xms01.dom.com/api/json/v2/types/bbus                           bbus
https://xms01.dom.com/api/json/v2/types/bricks                         bricks
https://xms01.dom.com/api/json/v2/types/clusters                       clusters
https://xms01.dom.com/api/json/v2/types/consistency-group-volumes      consistency-group-volumes
https://xms01.dom.com/api/json/v2/types/consistency-groups             consistency-groups
https://xms01.dom.com/api/json/v2/types/dae-controllers                dae-controllers
https://xms01.dom.com/api/json/v2/types/dae-psus                       dae-psus
https://xms01.dom.com/api/json/v2/types/daes                           daes
https://xms01.dom.com/api/json/v2/types/data-protection-groups         data-protection-groups
https://xms01.dom.com/api/json/v2/types/email-notifier                 email-notifier
https://xms01.dom.com/api/json/v2/types/events                         events
https://xms01.dom.com/api/json/v2/types/infiniband-switches            infiniband-switches
https://xms01.dom.com/api/json/v2/types/initiator-groups               initiator-groups
https://xms01.dom.com/api/json/v2/types/initiators                     initiators
https://xms01.dom.com/api/json/v2/types/iscsi-portals                  iscsi-portals
https://xms01.dom.com/api/json/v2/types/iscsi-routes                   iscsi-routes
https://xms01.dom.com/api/json/v2/types/ldap-configs                   ldap-configs
https://xms01.dom.com/api/json/v2/types/local-disks                    local-disks
https://xms01.dom.com/api/json/v2/types/lun-maps                       lun-maps
https://xms01.dom.com/api/json/v2/types/performance                    performance
https://xms01.dom.com/api/json/v2/types/schedulers                     schedulers
https://xms01.dom.com/api/json/v2/types/slots                          slots
https://xms01.dom.com/api/json/v2/types/snapshot-sets                  snapshot-sets
https://xms01.dom.com/api/json/v2/types/snapshots                      snapshots
https://xms01.dom.com/api/json/v2/types/snmp-notifier                  snmp-notifier
https://xms01.dom.com/api/json/v2/types/ssds                           ssds
https://xms01.dom.com/api/json/v2/types/storage-controller-psus        storage-controller-psus
https://xms01.dom.com/api/json/v2/types/storage-controllers            storage-controllers
https://xms01.dom.com/api/json/v2/types/syslog-notifier                syslog-notifier
https://xms01.dom.com/api/json/v2/types/tags                           tags
https://xms01.dom.com/api/json/v2/types/target-groups                  target-groups
https://xms01.dom.com/api/json/v2/types/targets                        targets
https://xms01.dom.com/api/json/v2/types/user-accounts                  user-accounts
https://xms01.dom.com/api/json/v2/types/volumes                        volumes
https://xms01.dom.com/api/json/v2/types/xenvs                          xenvs
https://xms01.dom.com/api/json/v2/types/xms                            xms
```

#### Get and remove stored credentials

```powershell
PS C:\> Get-XIOStoredCred
UserName                                     Password
--------                                     --------
admin                    System.Security.SecureString

PS C:\> Remove-XIOStoredCred -Verbose
VERBOSE: Performing the operation "Remove file" on target
"C:\Users\someuser0\AppData\Local\Temp\xioCred_by_someuser0_on_somecomputer0.enc.xml".
```

#### Open the Java management console and the WebUI

```powershell
PS C:\> Open-XIOMgmtConsole xms01.dom.com

PS C:\> Open-XIOXMSWebUI xms01.dom.com
```
