## sample code to create new initiator-groups for all hosts in a cluster; May 2014, Matt Boren

## general params to use for each New-XIOInitiatorGroup call
$hshGeneralParamsForNewXioIG = @{
	Computer = "somexms0.dom.com"
	TrustAllCert = $true
	Port = 443
	WhatIf = $true
}

## doing it this way instead of Get-Cluster cluster0,cluster1,cluster..., as the behavior of the PipelineVariable variable is different the 2nd way, and does not result in desired output in this case, whereas one cluster at a time _does_
Write-Output cluster0,cluster1 | %{
	Get-Cluster -Name $_ -PipelineVariable cluThisOne | Get-VMHostHBAWWN.ps1 | Group-Object -Property @{e={$_.VMHostName.Split(".")[0]}} | %{
		$strVMHostShortname = $_.Name
		## make a hashtable of key/value pairs that are initiator-name => HBA WWN
		$_.Group | % -begin {$hshInitList = @{}} {$hshInitList["${strVMHostShortname}-$($_.DeviceName.Replace("vmhba","hba"))"] = $_.HBAPortWWN}
		## make a hashtable of parameters specific to this new initiator group to make
		$hshParamForNewXioIG = @{
			Name = $strVMHostShortname
			InitiatorList = $hshInitList
			ParentFolder = "/$($cluThisOne.Name)"
		} ## end hashtable
		New-XIOInitiatorGroup @hshGeneralParamsForNewXioIG @hshParamForNewXioIG
		#$hshParamForNewXioIG
	} ## end foreach-object
} ## end foreach-object


## doing it this way instead of Get-Cluster cluster0,cluster1,cluster..., as the behavior of the PipelineVariable variable is different the 2nd way, and does not result in desired output in this case, whereas one cluster at a time _does_
"somevmhost0.dom.com" | %{Get-VMHostHBAWWN.ps1 -HostName $_} | Group-Object -Property @{e={$_.VMHostName.Split(".")[0]}} | %{
	$strVMHostShortname = $_.Name
	## make a hashtable of key/value pairs that are initiator-name => HBA WWN
	$_.Group | % -begin {$hshInitList = @{}} {$hshInitList["${strVMHostShortname}-$($_.DeviceName.Replace("vmhba","hba"))"] = $_.HBAPortWWN}
	## make a hashtable of parameters specific to this new initiator group to make
	$hshParamForNewXioIG = @{
		Name = $strVMHostShortname
		InitiatorList = $hshInitList
		ParentFolder = "/SomeCluster0"
	} ## end hashtable
	New-XIOInitiatorGroup @hshGeneralParamsForNewXioIG @hshParamForNewXioIG
	#$hshParamForNewXioIG
} ## end foreach-object
