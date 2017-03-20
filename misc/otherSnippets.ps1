## some various snippets used for testing, type/property determination/exploration, etc.

## for observing property changes to handle between versions
$strV40XmsName = "somexms00.dom.com"
$strV30XmsName = "somexms01.dom.com"
$strV241XmsName = "somexms02.dom.com"
$strV223XmsName = "somexms3.dom.com"
$credSomeAdmin_noDom = Get-Credential someXioAdmin

$arrTypesFor30 = (Get-XIOItemInfo -Credential $credSomeAdmin_noDom -URI https://$strV30XmsName/api/json/types -ReturnFullResponse).children
$arrTypesFor241 = (Get-XIOItemInfo -Credential $credSomeAdmin_noDom -URI https://$strV241XmsName/api/json/types -ReturnFullResponse).children
$arrTypesInBothVersions = $arrTypesFor30 | %{$_.name} | ?{($arrTypesFor241 | %{$_.Name}) -contains $_}
$hshObjPropertyDifferencesInfo = @{}
foreach ($strItemtype in ($arrTypesInBothVersions | %{$_.TrimEnd("s")})) {
#foreach ($strItemtype in $arrTypesInBothVersions) {
	Write-Verbose -Verbose "working on '$strItemtype'"
	$arrXioClusterInfoRaw_v241 = Get-XIOItemInfo -ItemType $strItemtype -computer $strV241XmsName -TrustAllCert -ReturnFullResponse -port 443 -cred $credSomeAdmin_noDom
	$arrXioClusterInfoRaw_v30 = Get-XIOItemInfo -ItemType $strItemtype -computer $strV30XmsName -TrustAllCert -ReturnFullResponse -port 443 -cred $credSomeAdmin_noDom
	## not working, yet
	#$arrXioClusterInfoRaw_v241 = Get-XIOItemInfo -Uri https://$strV241XmsName/api/json/types/$strItemtype -TrustAllCert -ReturnFullResponse -cred $credSomeAdmin_noDom
	#$arrXioClusterInfoRaw_v30 = Get-XIOItemInfo -ItemType $strItemtype -computer $strV30XmsName -TrustAllCert -ReturnFullResponse -port 443 -cred $credSomeAdmin_noDom

	$hshObjPropertyDifferencesInfo["$strItemtype"] = @{
		"inV241NotInV30" = ($arrXioClusterInfoRaw_v241.content | gm -Type NoteProperty).Name | ?{($arrXioClusterInfoRaw_v30.content | gm -Type NoteProperty).name -notcontains $_}
		"inV30NotInV241" = ($arrXioClusterInfoRaw_v30.content | gm -Type NoteProperty).Name | ?{($arrXioClusterInfoRaw_v241.content | gm -Type NoteProperty).name -notcontains $_}
	} ## end hashtable
}


## between 3.0 and 2.2.3
$arrTypesFor30 = (Get-XIOItemInfo -Credential $credSomeAdmin_noDom -URI https://$strV30XmsName/api/json/types -ReturnFullResponse).children
$arrTypesFor223 = (Get-XIOItemInfo -URI https://$strV223XmsName/api/json/types -ReturnFullResponse).children
$arrTypesInBothVersions = $arrTypesFor30 | %{$_.name} | ?{($arrTypesFor223 | %{$_.Name}) -contains $_}
$hshObjPropertyDifferencesInfo = @{}
foreach ($strItemtype in ($arrTypesInBothVersions | %{$_.TrimEnd("s")})) {
#foreach ($strItemtype in $arrTypesInBothVersions) {
	Write-Verbose -Verbose "working on '$strItemtype'"
	$arrXioClusterInfoRaw_v223 = Get-XIOItemInfo -ItemType $strItemtype -computer $strV223XmsName -TrustAllCert -ReturnFullResponse -port 443
	$arrXioClusterInfoRaw_v30 = Get-XIOItemInfo -ItemType $strItemtype -computer $strV30XmsName -TrustAllCert -ReturnFullResponse -port 443 -cred $credSomeAdmin_noDom
	## not working, yet
	#$arrXioClusterInfoRaw_v223 = Get-XIOItemInfo -Uri https://$strV223XmsName/api/json/types/$strItemtype -TrustAllCert -ReturnFullResponse -cred $credSomeAdmin_noDom
	#$arrXioClusterInfoRaw_v30 = Get-XIOItemInfo -ItemType $strItemtype -computer $strV30XmsName -TrustAllCert -ReturnFullResponse -port 443 -cred $credSomeAdmin_noDom

	$hshObjPropertyDifferencesInfo["$strItemtype"] = @{
		"inV223NotInV30" = ($arrXioClusterInfoRaw_v223.content | gm -Type NoteProperty).Name | ?{($arrXioClusterInfoRaw_v30.content | gm -Type NoteProperty).name -notcontains $_}
		"inV30NotInV223" = ($arrXioClusterInfoRaw_v30.content | gm -Type NoteProperty).Name | ?{($arrXioClusterInfoRaw_v223.content | gm -Type NoteProperty).name -notcontains $_}
	} ## end hashtable
}


<#  older (2.4, 2.2.3)
foreach ($strItemtype in @("cluster", "initiator-group", "initiator", "lun-map", "target-group", "target", "volume", "brick", "ssd", "storage-controller", "xenv")) {
	Write-Verbose -Verbose "working on '$strItemtype'"
	$arrXioClusterInfoRaw_v24 = Get-XIOItemInfo -ItemType $strItemtype -computer $strV24XmsName -TrustAllCert -ReturnFullResponse -port 443 -cred $credSomeAdmin_noDom
	$arrXioClusterInfoRaw_v223 = Get-XIOItemInfo -ItemType $strItemtype -computer $strV223XmsName -TrustAllCert -ReturnFullResponse -port 443
	$hshObjPropertyDifferencesInfo["$strItemtype"] = @{
		"inV24NotInV223" = ($arrXioClusterInfoRaw_v24.content | gm -Type NoteProperty).Name | ?{($arrXioClusterInfoRaw_v223.content | gm -Type NoteProperty).name -notcontains $_}
		"inV223NotInV24" = ($arrXioClusterInfoRaw_v223.content | gm -Type NoteProperty).Name | ?{($arrXioClusterInfoRaw_v24.content | gm -Type NoteProperty).name -notcontains $_}
	} ## end hashtable
}
#>

## get all properties and values, sorted by property name
(Get-XIOItemInfo -ItemType storage-controller -ReturnFullResponse).content | %{Select -InputObject $_ -Property (gm -in $_ -MemberType NoteProperty | %{$_.name} | sort)}
(Get-XIOItemInfo -Uri https://somexms01.dom.com/api/json/types/data-protection-groups/1 -ReturnFullResponse).content | %{Select -InputObject $_ -Property (gm -in $_ -MemberType NoteProperty | %{$_.name} | sort)}

# -clusters obj
# 	-add "brick-list" property (available in 2.2.3 and 2.4, at least)


# testing:
gc GetXIOItem.ps1 | sls "^\s+.Example" -Context 0,1 | select -ExpandProperty Context | select -ExpandProperty postcontext
