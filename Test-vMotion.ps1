Function Test-vMotion{
<#
	.Synopsis
	
 	 Performs .CheckMigrate method for all VMs in a cluster to determine if they
	 are capable of being migrated.  
	 
	.Description 
	 Performs .CheckMigrate method for all VMs in a cluster to determine if they
	 are capable of being migrated. Also able to check a single VM against a random
	 host in its parent cluster. User may designate a preferred target host.
	 
	.Parameter Cluster
	
	 Specifies a target Cluster.  Choosing a cluster will check every VM in the cluster.  
	 If no VMHost is specified by the user then a random one will be selected from the cluster.
	
	.Parameter VM
	 
	 Specifies a VM that should be migrated to another host.  If function is called with only
	 this parameter then a random host will be selected from the VM's parent Cluster.
	
	.Parameter VMHost
	 
	 Specifies the preferred VMHost to test vMotion against.  This parameter can be used with
	 both the VM and Cluster parameters.  See Examples for details.
	
	.Parameter Console
	
	 Allows user to disable console writes so that function can be used in scheduled tasks.
	 Default setting is True
	 
	.Example
	
	 Get-Cluster <ClusterName> | Test-vMotion
	 
	 This will test all VMs in the cluster against randomly chosen hosts in the cluster.
	 
	 Cluster functionality is working only in pipeline at this time.
	 
	.Example
	 
	 Get-Cluster <ClusterName> | Test-vMotion -VMHost <HostName>
	 
	 This will test all VMs against a specified VMhost unless that host is the same host the VM lives on.
	 
	.Example
	
	 Test-vMotion -VM <VMname> -VMHost <VMhost>
	 
	 In this scenario you will test capability to migrate the selected VM to the select Destination host.
	
	.Example
	
	 Test-vMotion -VM <VMname>
	 
	 In this scenario the function will randomly select a Destination host based on the cluster that the VM is located on.

	.Link
	 http://poshcode.org/3005
	 
	.Notes
	====================================================================
	Author(s):		
	Josh Atwell <joatwell@cisco.com>
	Jade Lester <jadleste@cisco.com>
	Hal Rottenberg <hal@halr9000.com> http://www.halr9000.com/
	Alan Renouf <renoufa@vmware.com> http://www.virtu-al.net/
					
	Date:			2011-12-21
	Revision: 		1.0

	2015/04/21
	This function has not been tested with vSphere 5.5 and vSphere 6

	Output includes the following data
		 - VM - VM to be migrated
		 - Host - Destination host for migration.  Must be in same Datacenter.
		 - Error - Error Message on condition that will prevent vMotion of that VM.
		 - Warning - Indicates that something may interfere with success.
		 - CanMigrate - True/False as to whether VM can migrate to Destination host
	====================================================================
	Disclaimer: This script is written as best effort and provides no 
	warranty expressed or implied. Please contact the author(s) if you 
	have questions about this script before running or modifying
	====================================================================
		
#>
	param(
		[CmdletBinding()]
		[Parameter(ValueFromPipeline=$true,Position=0,Mandatory=$false,HelpMessage="Enter the Cluster to be checked")]
		[PSObject[]]$Cluster,
		
		[Parameter(ValueFromPipeline=$false,Position=1,Mandatory=$false,HelpMessage="Enter the VM you wish to migrate")]
		[PSObject[]]$VM,

		[Parameter(ValueFromPipeline=$false,Position=2,Mandatory=$false,HelpMessage="Enter the Destination Host")]
		[PSObject[]]$VMHost,
		
		[Parameter(ValueFromPipeline=$false,Position=3,Mandatory=$false,HelpMessage="Set to false to Turn off console writing for use in Scheduled Tasks")]
		[Boolean]$Console=$true
	)

	$report = @()
	
	#	Sets information based on type of work being done. Whole cluster or single VM
	If($Cluster -ne $null){
		If($VM -ne $null){
				If($Console = $true){
					Write-Host "VM value $VM can not be used when using -Cluster paramenter.  Value is being set to null"
				}
				$VM = $null
		}
		
		If($VMHost -ne $null){
			$DestHost = Get-VMHost $VMHost
			If(($DestHost.ConnectionState -ne "Connected") -or ($DestHost.PowerState -ne "PoweredOn")){
				Return "You must provide a target host that is Powered on and not in Maintenance Mode or Disconnected"
			}
		}
		
		$singlevm = $false
		$targetcluster = Get-Cluster $Cluster
		$vms = $targetcluster | Get-VM | Where{$_.PowerState -eq "PoweredON"} | Sort-Object
		$vmhosts = $targetcluster | Get-VMHost | Where{($_.ConnectionState -eq "Connected") -and ($_.PowerState -eq "PoweredOn")}
			If ($vmhosts.Count -lt 2){
				Return "You must provide a target host that is not the source host $sourcehost"
			}
		
		$count = $vms.Count
		If($Console = $true){
			Write-Host "Checking $count VMs in cluster $cluster"
		}
		
	} ELSE {
		$vms = Get-VM $VM
		If($VMHost -eq $null){
			$DestHost = Get-Cluster -VM $vms | Get-VMHost | Where{($_.ConnectionState -eq "Connected") -and ($_.PowerState -eq "PoweredOn")} | Get-Random | Where{$_ -ne $vms.VMhost}
		} ELSE {
			$DestHost = Get-VMHost $VMHost
		}
		$singlevm = $true
	}
	
	#	Functional Loop
	foreach($v in $vms) {
		If($Console = $true){
			Write-Host "-------------------------"
			Write-Host "Checking $v ..."
		}
		$sourcehost = $v.VMhost
		
		If($singlevm -eq $false){
			
			While(($DestHost -eq $null) -or ($DestHost -eq $sourcehost)){
				#	Select random host from the cluster in the event that Source and Destination are the same or Destination is Null.
				$DestHost = $vmhosts | Get-Random | Where{($_ -ne $sourcehost) -and ($_ -ne $null)}
			}
		}
		If($Console = $true){
			Write-Host "from $sourcehost to $DestHost"
		}
		#	Set Variables needed for CheckMigrate Method
		$pool = ($v.ResourcePool).ExtensionData.MoRef
		$vmMoRef = $v.ExtensionData.MoRef
		$hsMoRef = $DestHost.ExtensionData.MoRef

		$si = Get-View ServiceInstance -Server $global:DefaultVIServer
		$VmProvCheck = get-view $si.Content.VmProvisioningChecker
		$result = $VmProvCheck.CheckMigrate( $vmMoRef, $hsMoRef, $pool, $null, $null )
		
		#	Organize Output
		$Output = "" | Select VM, SourceHost, DestinationHost, Error, Warning, CanMigrate
		$Output.VM = $v.Name
		$Output.SourceHost = $sourcehost
		$Output.DestinationHost = $DestHost.Name
		
		#	Parse Error and Warning messages
		If($result[0].Warning -ne $null){
			$Output.Warning = $result[0].Warning[0].LocalizedMessage
			$Output.CanMigrate = $true
			If($Console = $true){
				Write-Host -ForegroundColor Yellow "$v has warning but can still migrate"
			}
		} 
		If($result[0].Error -ne $null){
			$Output.Error = $result[0].Error[0].LocalizedMessage
			$Output.CanMigrate = $False
			If($Console = $true){
				Write-Host -ForegroundColor Red "$v has error and can not migrate"
			}
		}Else {
			$Output.CanMigrate = $true
			If($Console = $true){
				Write-Host -ForegroundColor Green "$v is OK"
			}
		}
		
		$report += $Output
		#	This resets the Destination Host to the preferred host in case it had to be changed.
		If($VMHost -ne $null){
			$DestHost = Get-VMHost $VMHost
		}
	}
	
	Return $report
	#	End Function
}