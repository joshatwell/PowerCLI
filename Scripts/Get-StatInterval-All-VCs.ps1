<#
====================================================================
Author(s):		Josh Atwell <josh.c.atwell@gmail.com>
File: 			Get-StatInterval-All-VCs.ps1
Purpose: 		Email report of the StatIntervals for All VCs listed
				in array.  Needed because Statistics level is not
				provided in Get-StatInterval cmdlet.
Date:			2011-07-08
Sanitized:		2015-04-21
Revision: 		2.1
Items added: 	1. Time conversions for easy reading.
				2. Export Location check with Date-based file naming
				3. Email Report
				4. Only notify when stat level /= 2
				5. List non-compliant vCenter servers in Email
Items to Add:	

References:		http://www.vmware.com/support/developer/PowerCLI/PowerCLI41/html/Get-StatInterval.html
				http://www.lucd.info/2009/12/30/powercli-vsphere-statistics-part-1-the-basics/
				Level	Description
				1 		Basic metrics. Device metrics excluded. Only average rollups.
				2 		All metrics except those for devices. Maximum and minimum rollups excluded.
				3 		All metrics, maximim and minimum rollups excluded
				4 		All metrics
				
====================================================================
Disclaimer: This script is written as best effort and provides no 
warranty expressed or implied. Please contact the author(s) if you 
have questions about this script before running or modifying
====================================================================
#>
# load VMware snapin
Add-PSSnapin vmware.VimAutomation.core -ErrorAction SilentlyContinue
<#
====================================================================
	***User Input Section***
	This Section has arrays and variables that require user input
====================================================================
#>
#	Define vCenter Servers array
$viservers = @()
$viservers += "<your-vCenter>"
#$viservers += "<your-vCenter>"


#	Define email recipient array
$rcpt = @()
$rcpt += "<your-email>"
#$rcpt += "<your-email>"


#	Sets global ALERT variable.  If a Statistics Level value is not set to what you want, it will send alert.
#	Otherwise the script will only write out the full report.
[Boolean]$alert = $false

#	Full Settings Report location.  Set for date based file name.
$FullReportLocation = "<your-report-file-location>-{0:yyyy-MM-dd}.csv" -f (Get-Date)
#	Error Only Report Location.  Set for date based filename.
$ErrorReportLocation = "<your-error-file-location>-{0:yyyy-MM-dd}.txt" -f (Get-Date)

#	Initiates the reporting object
$report = @()
#	Initiates object for identifying non-compliant systems.
$NonCompliantvCenters = @()

<#
====================================================================
	***Script Execution***
	This Section has the script execution tasks
====================================================================
#>
$viservers | % {
	connect-viserver $_
	$vCenterName = $_
	
	$getview = Get-View ServiceInstance
	$perfcounter = Get-View ($getview).Content.PerfManager
	$histint = $perfcounter.HistoricalInterval
	
	foreach($inter in $histint) {
		$row = "" | Select-Object "vCenterServer", "Interval Duration", "Save For", "Stat Level", "Enabled"
		
		#	Object used to collection information on vCenter servers with misconfigurations
		$vcenters = "" | Select-Object "vCenterServer", "Save For", "Stat Level", "Enabled"
		
		$row.vCenterServer = $vCenterName
		
		#	If statement to make time value easier to read.
		if ($inter.SamplingPeriod -gt 60 -and $inter.SamplingPeriod -le 3599) {  #Anything more than 1 Min and less than 1 Hour
			 $row."Interval Duration" = ((New-TimeSpan -Seconds $inter.SamplingPeriod).TotalMinutes -as [String]) + " Minutes"
		
		} elseif ($inter.SamplingPeriod -gt 3600 -and $inter.SamplingPeriod -le 86399) {	#Format for 1 Hour to 23:59:59
			$row."Interval Duration" = ((New-TimeSpan -Seconds $inter.SamplingPeriod).TotalHours -as [String]) + " Hour(s)"
		
		} elseif ($inter.SamplingPeriod -ge 86400) {	#Format for days.
			$row."Interval Duration" = ((New-TimeSpan -Seconds $inter.SamplingPeriod).TotalDays -as [String]) + " Day(s)"
		
		} else {$row.IntervalDuration = (($inter.SamplingPeriod).TotalSeconds + " Seconds" -as [String]) + " Seconds"	#Format for less than 1 Min
		}
		
		$row."Save For" = $inter.Name
		
		#	If statement will tell script to alert if the level is not set where you want it.
		$row."Stat Level" = $inter.Level
		if($inter.level -ne 3){
			$alert = $true
				#	This adds the vCenter Server name and misconfiguration to $vcenters object
				$vcenters.vCenterServer = $vCenterName
				$vcenters."Save For" = $inter.Name
				$vcenters."Stat Level" = ($inter.Level -as [String])
			}
		
		#	If statement will tell script to alert if Statistics are not enabled.
		$row.Enabled = $inter.Enabled
		if($inter.Enabled -ne $True){
			$alert = $true
				#	This adds the vCenter Server name and misconfiguration to $vcenters object
				$vcenters.vCenterServer = $vCenterName
				$vcenters."Save For" = $inter.Name
				$vcenters.Enabled = $inter.Enabled
			}
	
	$NonCompliantvCenters += $vcenters				
	$report += $row
	}
	#	This disconnects any current connections.  Could also use $_ or $vCenterName instead of *
	Disconnect-VIserver * -Confirm:$False
	}
	
#	Export reports to files.  You can comment out if you do not wish to maintain logs
$report | Export-Csv $FullReportLocation -NoTypeInformation

<#
====================================================================
	***Send Error Report***
	Compose and send email only if there was a misconfiguration.
====================================================================
#>
If($alert -eq $true){	
	$NonCompliantvCenters | Export-Csv $ErrorReportLocation -NoTypeInformation
	
	#	Build table style
	$a = "<style>"
	$a = $a + "BODY{background-color:white;}"
	$a = $a + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
	$a = $a + "TH{border-width: 1px;padding: 2px;border-style: solid;border-color: black;}"
	$a = $a + "TD{border-width: 1px;padding: 2px;border-style: solid;border-color: black;}"
	$a = $a + "</style>"
	
	#	Build body of email message to include the misconfigured vCenter servers with their misconfiguration.
	$body = "The following vCenter server(s) has an incorrect Statistics Configuration.<br> Please see log $ErrorReportLocation for full report.<br><br>" 
	$body = $body + ($NonCompliantvCenters | ConvertTo-Html -Head $a)


foreach ($person in $rcpt){
	Send-MailMessage -to $person -from <your-from-Email-Address> -sub "vCenter Server found with incorrect Statistics Settings" -Body $body -BodyAsHtml -smtpserver <your-smtp-server> #-attachments $report #<--Report Object attached
	}
}
#End Script
#====================================================================