<#
author Nickolaus Vendel
date 5-17-2021
revision 1
notes: 
- Yes I know I can split up the multiple functions to have 1 role for its execution but who cares 
- passing on variables to other functions suck if you dont need to
#>
<#report reqs
rundate
computers scanned : <number>
programs scanned: <number>
Out of compliance computers: number
out of compliance programs: number

Out of compliance computer:
hostname:
software:

#>
# param (
#     [Parameter(Mandatory=$true, Position=0)]$Tenable_CSV_Input,
#     [Parameter(Mandatory=$false, Position=1)]$Banned_Software_List
# )

#region Variables
$Master_Computer_hash=[ordered]@{}
$Bad_software_hits_hash=[ordered]@{}
$Computer_Containing_bad_software_hash=[ordered]@{}

#Get current user path information
$User = whoami
$Username += $user.Split("{\}")
$desktoplocation = "C:\users\$($username[1])\desktop"

#Testing Variables - comment when filling through parameters - or don't w/e depends how you wanna run it
$Tenable_CSV_Input = "$desktoplocation\nessus_report.csv"
$Banned_Software_List = "$desktoplocation\NASL.txt"

$Manual_Computer_List_Review_Path = "$desktoplocation\Tenable-List-$(get-date -format 'MM-dd-yy').txt"
$Bad_Software_Report_Path = "$desktoplocation\Tenable-List-Bad-Software-Report-$(get-date -format 'MM-dd-yy').txt"
#endregion Variables

function Parse-CSV {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]$Tenable_CSV_Input,
        [Parameter(Mandatory=$false, Position=1)]$Banned_Software_List
    )
    ############
    #Import CSV#
    ############
    Write-Verbose "testing path for csv existing"
    if ( !(test-path -path $Tenable_CSV_Input) ){ 
        Write-Error -Message "Need to specify proper path for CSV to parse *shift+right-click copy as path*"
    }else{
        Write-Verbose "Importing CSV file"
        $Tenable_CSV_to_Parse = Import-Csv -Path $Tenable_CSV_Input
    }
    
    #Get bad list content
    if ( !(test-path -path $Banned_Software_List) ){ 
        Write-Error -Message "Need to specify proper path for bad software list (txt file) to parse *shift+right-click copy as path*"
    }else{
        Write-Verbose "Getting bad software list file"
        $Banned_Software_Content = Get-Content -Path $Banned_Software_List
    }

    #Output parsed reviewing format for manual review
    if ( !(test-path -path $Manual_Computer_List_Review_Path) ) {
        New-Item -Path  $Manual_Computer_List_Review_Path
    }
    Write-Verbose "writing the input file in readable format in $Manual_Computer_List_Review_Path"
    $Tenable_CSV_to_Parse | Format-List > $Manual_Computer_List_Review_Path
    
    #Link computer with software list instead of CSV
    Write-Verbose "Linking up master_computer_hash"
    $Master_Computer_hash=[ordered]@{}
    $i=0
    foreach ($computer_to_add in $Tenable_CSV_to_Parse.'DNS Name') {
        if ($computer_to_add -eq ""){
            $computer_to_add = "no-hostname - need to look at manual report"
        }
        
        #Splits the input by new line characters to make iterable lists
        $software_list = $Tenable_CSV_to_Parse.'plugin text'[$i].Split([Environment]::NewLine)
        
        #slims down the plugin to get rid of the crap for better list comparison in the master hash
        $Master_Computer_hash.add($computer_to_add, $software_list[3..$software_list.count])
        $i++
    }
    
    #Loop through and create hash table of hostname with software list as the pairing
    Write-Verbose "Linking up Bad_software_hits_hash and Computer_Containing_bad_software_hash"
    foreach ($bad_software in $Banned_Software_Content) {
        $Bad_software_hits_hash[$bad_software] = @()
        foreach ($found_computer in $Master_Computer_hash.keys) {
            $computer_software_to_check = $Master_Computer_hash.$found_computer
            #Adds to appropriate hash tables when computers are found for parsing later
            if ($computer_software_to_check -match $bad_software) {
                $Bad_software_hits_hash[$bad_software] += $found_computer
                if (!($Computer_Containing_bad_software_hash.$found_computer)){
                    $Computer_Containing_bad_software_hash.add($found_computer, "has bad software")
                }
            }
        }
    }
    
    #######################
    #Output overall report#
    #######################
    
    #Create Report File
    if ( !(test-path -path $Bad_Software_Report_Path) ) {
        Write-Verbose "creating bad software report path $Bad_Software_Report_Path"
        New-Item -Path  $Bad_Software_Report_Path
    }

    #Run date
    Write-Verbose "writing date to $Bad_Software_Report_Path"
    Write-Output "###########################" > $Bad_Software_Report_Path
    write-output "Date ran $(get-date -format 'MM-dd-yy')" >> $Bad_Software_Report_Path
    
    #computers scanned report
    Write-Verbose "writing computers scanned to $Bad_Software_Report_Path"
    write-output "$($Master_Computer_hash.Count) computers scanned" >> $Bad_Software_Report_Path
    
    #List Computer hits (number)
    Write-Verbose "writing computers found with bad software to $Bad_Software_Report_Path"
    Write-Output "$($Computer_Containing_bad_software_hash.Keys.count) computers have been found to have bad software installed" >> $Bad_Software_Report_Path
    
    #List computer specific information on hit scanned
    Write-Verbose "writing computers found with bad software hostnames to $Bad_Software_Report_Path"
    foreach ($pc_host in $($Computer_Containing_bad_software_hash.Keys.Split([Environment]::NewLine))){
        write-output "      $pc_host" >> $Bad_Software_Report_Path
    }
    Write-Output "###########################" >> $Bad_Software_Report_Path
    
    #List Software Hits
    Write-Output "The following software was found to be on a number of hosts:" >> $Bad_Software_Report_Path
    foreach ($item in $($Bad_software_hits_hash).keys.Split([Environment]::NewLine)) {
        if ($($Bad_software_hits_hash[$item].count -ne 0)){
            Write-Output "      $item" >> $Bad_Software_Report_Path
        }
    }
    Write-Output "###########################" >> $Bad_Software_Report_Path
    foreach ($software_name in $($Bad_software_hits_hash.keys.Split([Environment]::NewLine))){
        if ($($Bad_software_hits_hash[$software_name].count -ne 0)){
            Write-Output "Computers with software: $software_name " >> $Bad_Software_Report_Path
            foreach ($PC in $($Bad_software_hits_hash[$software_name].Split([Environment]::NewLine))) {
                Write-Output "      $PC" >> $Bad_Software_Report_Path
            }
        }
    }
}

#Runs the function
Parse-CSV -Tenable_CSV_Input $Tenable_CSV_Input -Banned_Software_List $Banned_Software_List  #-verbose


