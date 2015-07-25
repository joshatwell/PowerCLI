Function Set-LocalDatastoreName{
<#
	.Synopsis
 	 Renames the local datastore of an ESX(i) host to a name based
	 on Hostname and a defined suffix.  Default suffix is "-local"
	.Example
	 
	 Get-Cluster "Test1" | Get-VMHost | Set-LocalDatastoreName

	 This will rename the local datastores of all VMHosts in cluster Test1
	
	.Example
	 
	 Get-Cluster "Test1" | Get-VMHost | Set-LocalDatastoreName -suffix "-localvmfs"
	 
	 This will rename the local datastores of all VMHosts in cluster Test1 with
	 specified suffix "-localvmfs".

	.Example
	 
	 Set-LocalDatastoreName "HostName"
	 
	 Result: <HostName>-local
	 
	.Example
	 
	 $hst = Get-VMHost "HostName"
	 Set-LocalDatastoreName $hst -suffix "-localvmfs"
	 
	 Renames local datastore with specified suffix "-localvmfs"
	 Result: <HostName>-localvmfs

	.Link
	 
	 
	.Description
====================================================================
Author(s):		Josh Atwell <josh.c.atwell@gmail.com>
				
File: 			Set-LocalDatastoreName.ps1
Purpose: 		Renames the local datastore of an ESX(i) host to a name based
	 			on Hostname and a defined suffix.  Default suffix is "-local"
 
Date:			2011-10-19
Revision: 		1.1
Items added: 	Ability to define suffix other than default "-local"
Items to Add:	
 
References:		

Notes:			

====================================================================
Disclaimer: This script is written as best effort and provides no 
warranty expressed or implied. Please contact the author(s) if you 
have questions about this script before running or modifying
====================================================================
	
#>

param(
[CmdletBinding()]
[Parameter(
	ValueFromPipeline=$true,
	Position=0,
	Mandatory=$true,
	HelpMessage="Provide VMHost whose local datastore you wish to rename")]
	$InputObject,
[Parameter(
	ValueFromPipeline=$false,
	Position=1,
	Mandatory=$false,
	HelpMessage="Provide preferred suffix.  -local is default")]
	$suffix = "-local"
)
Begin{
}

Process{
$InputObject | %{
$hst = Get-VMHost $_
$localds = $hst | Get-Datastore | Where {$_.Extensiondata.Summary.MultipleHostAccess -eq $False}
	if($localds.Count -gt 1){
		Write-Host "too many local disks found for $hst"}
	Else{
	
	$newdsname = $hst.Name.Split(".")[0] + $suffix
	Get-Datastore $localds | Set-Datastore -Name $newdsname
	}
}
}
End{
}
#	End Function
}
