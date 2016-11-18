## making module: (May 2013, Matt Boren)
#   0) make the PowerShell Script Module (.psm1) file with the exported functions/variables/aliases/etc.
#   1) make the PowerShell Data (.psd1) file (the Module Manifest) by calling New-ModuleManifest as shown below

## PowerShell v4 version:
$strFilespecForPsd1 = "$PSScriptRoot\XtremIO.Utils\XtremIO.Utils.psd1"

$hshModManifestParams = @{
	Path = $strFilespecForPsd1
	Author = "Matt Boren"
	CompanyName = "None"
	Copyright = "None"
	FormatsToProcess = "XioInfo.format.ps1xml"
	ModuleToProcess = "XtremIO_UtilsMod.psm1"
	ModuleVersion = "1.2.0"
	## scripts (.ps1) that are listed in the NestedModules key are run in the module's session state, not in the caller's session state. To run a script in the caller's session state, list the script file name in the value of the ScriptsToProcess key in the manifest
	NestedModules = "XIO_SupportingFunctions.ps1"
	PowerShellVersion = "4.0"
	Description = "Module with functions to interact with XtremIO management server (XMS appliance) via RESTful API"
	## specifies script (.ps1) files that run in the caller's session state when the module is imported. You can use these scripts to prepare an environment, just as you might use a login script
	ScriptsToProcess = $null
	#VariablesToExport = ''
	FileList = "XtremIO.Utils.psd1","XtremIO.Utils.init.ps1","XtremIO_UtilsMod.psm1","XIO_SupportingFunctions.ps1","GetXIOItem.ps1","NewXIOItem.ps1","OtherXIOMgmt.ps1","RemoveXIOItem.ps1","SetXIOItem.ps1","XioInfo.format.ps1xml","configItems.ps1","MITLicense.txt","about_XtremIO.Utils.help.txt"
	Verbose = $true
}
## using -PassThru so as to pass the generated module manifest contents to a var for later output as ASCII (instead of having a .psd1 file of default encoding, Unicode)
$oManifestOutput = New-ModuleManifest @hshModManifestParams -PassThru
## have to do in separate step, as PSD1 file is "being used by another process" -- the New-ModuleManifest cmdlet, it seems
$oManifestOutput | Out-File -Verbose $strFilespecForPsd1 -Encoding ASCII
