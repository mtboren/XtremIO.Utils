## initialization code for use by multiple *.Tests.ps1 files for testing XtremIO.Utils PowerShell module

$strXioModuleName = "XtremIO.Utils"
## if module not already loaded, try to load it (assumes that module is in PSModulePath)
if (-not ($oModuleInfo = Get-Module $strXioModuleName)) {
	$oModuleInfo = Import-Module $strXioModuleName -PassThru
	if (-not ($oModuleInfo -is [System.Management.Automation.PSModuleInfo])) {Throw "Could not load module '$strXioModuleName' -- is it available in the PSModulePath? You can manually load the module and start tests again"}
} ## end if
Write-Verbose -Verbose ("Starting testing of module '{0}' (version '{1}' from '{2}')" -f $oModuleInfo.Name, $oModuleInfo.Version, $oModuleInfo.Path)

## get the XIO connection to use
$oXioConnectionToUse = if (-not (($DefaultXmsServers | Measure-Object).Count -gt 0)) {
	$hshParamForConnectXioServer = @{ComputerName = $(Read-Host -Prompt "XMS computer name to which to connect for testing"); TrustAllCert = $true}
	Connect-XIOServer @hshParamForConnectXioServer
} ## end if
else {$DefaultXmsServers[0]}
$strXmsComputerName = $oXioConnectionToUse.ComputerName
Write-Verbose -Verbose "Testing using all XMS connections, generally, but single-XMS tests are using computer name of '$strXmsComputerName'"

## get the XIO cluster name to use for -Cluster param testing -- use the first cluster available in the oXioConnectionToUse
$strClusterNameToUse = (Get-XIOCluster -ComputerName $strXmsComputerName | Select-Object -First 1).Name
Write-Verbose -Verbose "Testing using all XIO clusters, generally, but single-cluster tests are using cluster name of '$strClusterNameToUse'"
