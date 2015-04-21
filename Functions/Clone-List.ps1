Function Clone-List{
<#
	.Synopsis
	 Will initiate a clone for a list of VMs.
	
	.Description
	 This function expands the standard New-VM cmdlet by dynamically assigning
	 specific parameters for the clone task.
	 
	.Example
	 Get-VM "*P1app*" | Clone-List
	 
	 You can pull list of VMs with Get-VM and pass to Clone-List.  
	 
	.Example
	 Get-Content "C:\Temp\YourList.txt" | Clone-List
	 	 
	.Link
	 http://www.vtesseract.com/
	.Description
====================================================================
Author(s):		Josh Atwell <josh.c.atwell@gmail.com>
 				
File: 			Clone-List.ps1
 
Date:			2012-01-12
Revision: 		1.0
Items added: 	1. 
				2. 
Items to Add:	1. 
				2. 
 
References:		www.vtesseract.com

====================================================================
Disclaimer: This script is written as best effort and provides no 
warranty expressed or implied. Please contact the author(s) if you 
have questions about this script before running or modifying
====================================================================
#>

Param(
[CmdletBinding()]
[Parameter(ValueFromPipeline=$true,
	Position=0,
	Mandatory=$true,
	HelpMessage="Insert Message")]
	[ValidateNotNullOrEmpty()]
	$InputObject,
[Parameter(Position=1,
	Mandatory=$false,
	HelpMessage="Insert Preferred Folder")]
	$folder,
[Parameter(Position=2,
	Mandatory=$false,
	HelpMessage="Insert Preferred Target Datastore")]
	$datastore,
[Parameter(Position=3,
	Mandatory=$false,
	HelpMessage="Insert Preferred Target Host")]
	$vmhost,
[Parameter(Position=4,
	Mandatory=$false,
	HelpMessage="Insert Preferred Disk Storage Format")]
	[ValidateSet("Thick","Thin")]
	$format = "Thin"
)
PROCESS{
	$InputObject | %{
		$vm = Get-VM $_
		$name = $vm.name
		$newname = -join("clone-",$name)
		If ($datastore -eq $null){
			$datastore = Get-Datastore -VM $vm
			}
		If ($folder -eq $null){
			$folder = $vm.Folder
			}
		#	Select Random host to assign clones to.  Prevents single host assignment
		If ($vmhost -eq $null){
			$vmhost = Get-Cluster -VM $vm | Get-VMHost | Get-Random | Where{$_ -ne $null}
			}
			
	New-VM -Name $newname -VM $vm -Location $folder -Datastore $datastore -VMHost $vmhost -DiskStorageFormat $format -RunAsync
	}
}
}