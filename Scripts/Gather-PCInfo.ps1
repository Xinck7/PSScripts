<#
Author Nickolaus Vendel
Date 3/24
Version - Alpha testing

Install requirements 
Requires -version 7.0 
Nmap
notes from 5-20-21: this was to build a report to scan and show the network information with things like make,model, ip etc for subnets
sanitized to now have the actual ip ranges but have been offset to be able to allow the code to still make sense
#>

function Start-Main{
    [CmdletBinding()]
    Param()
    
    #region Setup Variables
    $Dhcp_Server = '192.18.108.22'
    $Check_Networks = @(
        '192.18.108.0/22'
        )
    $network_no_subnet = '192.18.108.0'
    
    Write-Output "Please enter your Foreman Credentials"
    $Foreman_creds = Get-Credential
    
    Write-Output "Please enter your admin Credentials for DHCP call"
    $AD_Creds = Get-Credential

    ###todo Needs logic checks and automatic scp to get the list from dayforeman
    $User_list_location = "C:\Audits\ForemanUserList.csv"
    $Master_Hash_Save_Location = "C:\Audits\"
    if (!(Test-Path $Master_Hash_Save_Location)){
        New-Item $Master_Hash_Save_Location -Force
    }
    if (!(Test-Path $User_list_location)){
        Start-Process "C:\Program Files\Git\git-bash.exe"
        Set-Location $Master_Hash_Save_Location
        Write-Output "No UserList Found Please SCP the list from dayforeman using gitbash"
        Write-Output "in git bash cd /c/Audits/"
        Write-Output "Generate with command - Hammer User List > /tmp/<date>ForemanUserList.csv"
        Write-Output "scp <user>@dayforeman:/tmp/<date>ForemanUserList.csv ./"
    }
    #endregion Setup Variables
    
    #region Foreman Check
    #API GET requests for all hosts from foreman
    $foreman_sec_pass = $Foreman_creds.GetNetworkCredential().Password
    $foreman_user = "$($Foreman_creds.UserName)" + ":" + "$foreman_sec_pass"
    $Site = "https://dayforeman.<domain>"

    Write-Verbose "Gathering device information from foreman API"
    $get_hosts_form = curl --user "$foreman_user" "$site/api/v2/hosts?search=&per_page=1000" -k
    
    <#todo
    hammer user list 
    Need to figure out a way to remote execute and transfer or just return into shell
    might be able to type in 2 separate commands and use like a winscp from cli and then 
    parse from that point
    #>
    
    #Formats as hashtable
    Write-Verbose "Converting results into Hash tables for effecient iteration"
    $json_host_hash = $get_hosts_form | ConvertFrom-Json -AsHashtable
    
    #Select only Specified field for new hashtable
    $Master_Hash = [ordered]@{}
    
    #Collects a filtered list into the Master Hash table
    for ($i = 0; $i -lt $json_host_hash.results.Count; $i++) {
        $FilterableHashItem = $json_host_hash.results[$i]
        $Object = [ordered]@{}
        $Object['DeviceName'] = $FilterableHashItem.name
        $Object['IP']    = $FilterableHashItem.ip
        $Object['MacAddress'] = $FilterableHashItem.mac
        $Object['Owner'] = $FilterableHashItem.owner_id
        if ($null -ne $FilterableHashItem.comment){
            $Object['Usage'] = $FilterableHashItem.comment
        }else{
            $Object['Usage'] = "TBD - no value found"
        }
        $Object['Operating System'] = $FilterableHashItem.operatingsystem_name
        $vmform = '00:50:56'
        if ($FilterableHashItem.mac -match $vmform){
            $Object['Make'] = 'vm'
        }
        else{
            $Object['Make'] = 'Workstation - Needs Verification'
        }        
        $Object['Model'] = $FilterableHashItem.model_name       

        #Adds to the Master collection list Hash
        $counter_to_convert_to_json = "Item" + "$i"
        $Master_Hash[$counter_to_convert_to_json] = $Object
    }
    Write-Verbose "Found $($Master_Hash.count) hosts"
    
    #Collects the CSV generated from the hammer cli command hammer user list
    Write-Verbose "Generating user ID list and saving locally(empty code for now to be completed)"
    <#
    psuedo code process:
    -Should be able to script using gitbash sh.exe to script this section out to grab the CSV
    -If its possible to scp the script it may be possible to remote command generate the CSV as well
    -uses $User_list_location as the storage point - so you don't have to scroll
    - additional formatting required through excel to make sure the fields have been text-to-columned correctly
        also solvable by doing a multi step delimiter possible have to experiment with it
    #>

    #Matching owners to ID numbers
    write-verbose "matching users from CSV collection from foreman to update owner_id field from $User_list_location"
    $Import_CSV = Import-Csv $User_list_location
    for ($i = 0; $i -lt $Master_Hash.Count; $i++) {
        foreach ($User_entry in $Import_CSV){
            $item = "Item" + "$i"
            if ($Master_Hash[$item].Owner -eq $User_entry.'ID '){
                $Master_Hash[$item].Owner = $User_entry.'LOGIN '
            }
        }
    }

    #endregion Foreman Check

    #region Nmap Check    
    #Create list of ip ranges using nmap to find instead of pinglist
    
    Write-Verbose "networks to check for nmap are $Check_Networks"

    #Setup hash table for easier structure passing and calls
    $Network_Info_Hash = [ordered]@{}
    $Hostname_Hash = [ordered]@{}

    #Start Gathering network information
    $i = 0 
    foreach ($network in $Check_Networks){
        Write-Verbose "starting for $network"
        set-location -path "C:\Program Files (x86)\Nmap\"
        $hostlist = .\nmap.exe -sn $network #for running on VM or in actual network space 
        #$hostlist = .\nmap.exe -sn $network --unprivileged #for running on vpn
        $Network_Info_Hash[$network] = $hostlist
        $i++
    }
    Write-Verbose "Network check completed now parsing the data"

    #Zips hostnames/ip addresses to a single hashtable
    #Entries don't line up properly by default splits - requires further matching to ensure proper data matching
    $hostnames = [ordered]@{}
    $MacandOSInfo = [ordered]@{}
    foreach ($key in $Network_Info_Hash.values){
        $i=0
        foreach ($line in $key){
                #Nice trick to repeating patterns using modulus value of N%3 to return conditions throughout a loop
                $item = "Item" + "$i"
                if ($i%3 -eq 1){
                    $host_filtered = $line.Substring(21)
                    $Object = [ordered]@{}
                    if ($host_filtered.length -le 16){
                        $Object['Name'] = "No Hostname Found"
                        $Object['IP'] = $host_filtered
                    }
                    else{
                        $Object['Name'] = $host_filtered.split(" ")[0]
                        $Object['IP'] = $host_filtered.split(" ")[1]
                    }
                    $hostnames[$item] += $Object
                }
                if ($i%3 -eq 0){
                    $line = $line.Substring(13)
                    if ($line -notmatch ":"){
                        # Write-Verbose "no mac addr line hit"
                        $Object = [ordered]@{}
                        $Object['MAC']= "No MAC Found"
                        $Object['Make']= "No Make Found"
                        $MacandOSInfo[$item] += $Object
                    }
                    else{
                        # Write-Verbose "Mac addr reported as normal"
                        $Object = [ordered]@{}
                        $Object['MAC']= $line.split(" ")[0]
                        $Object['Make']= $line.split(" ")[1]
                        $MacandOSInfo[$item] += $Object
                    }
                }
                $i++
        }
    }
    Write-Verbose "Creating hash table from the arrays"
    $i = 0
    $Filler_Hash_Value = "NMAP property Not found - (Hostname possibly in IP found)"
    #Last 13 characters is IP if string longer than 15 characters
    for ($i -eq 0; $i -lt $hostnames.Count; $i++){
        $item = "Item" + "$i"
        $Object = [ordered]@{}
        $Object['DeviceName'] = $hostnames[$i].Name
        $Object['IP'] = $hostnames[$i].IP
        $Object['Mac'] = $MacandOSInfo[($i+1)].MAC
        $Object['Owner'] = $Filler_Hash_Value
        $Object['Usage'] = $Filler_Hash_Value
        $Object['Make'] = $MacandOSInfo[($i+1)].Make
        $Object['Model'] = $Filler_Hash_Value
        $Hostname_Hash[$item] = $Object
    }
    Write-Verbose "found $($Hostname_Hash.count) hosts from nmap to be compared to foremans list"
    #endregion Nmap Check
    
    #region DHCP check and compare
    Write-Verbose "Starting IP from DHCP"
    #Assorted activity status
    <#todo improvements - For potential "trust" of results 
    $ActiveRes_IP = $IP_List_Dhcp | where -Property 'addressstate' -like "ActiveReservation"
    $Active_IP = $IP_List_Dhcp | where -Property 'addressstate' -eq "Active"
    $Inactive_IP = $IP_List_Dhcp | where -Property 'addressstate' -like "InactiveReservation"
    #>
    
    #Set Object For hash table comparison
    $IP_Hash_List = [ordered]@{}
    $IP_List_Dhcp = Get-DhcpServerv4lease -computername $Dhcp_Server -ScopeId $network_no_subnet
    $Filler_Hash_Value = "Property not found by DHCP server"
    foreach ($ip in $IP_List_Dhcp){
        $Object = [ordered]@{}
        $item = "Item" + "$i"
        $Object['DeviceName'] = $ip.HostName
        $Object['IP'] = $ip.Ipaddress.IPAddressToString
        $Object['Mac'] = $ip.ClientId
        $Object['Owner'] = $Filler_Hash_Value
        $Object['Usage'] = $Filler_Hash_Value
        $Object['Make'] = $Filler_Hash_Value
        $Object['Model'] = $Filler_Hash_Value
        $IP_Hash_List[$item] = $Object
    }
    Write-Verbose "Found $($IP_Hash_List.count) hosts from DHCP to be compared to foremans list"
    #endregion DHCP check and compare

    #region Compare and add unique
    #todo Optimize with functions

    #Comparing NMAP
    Write-Verbose "Starting comparison and additions to the master hash table"
    $Diff_to_add = [ordered]@{}
    $i = 0
    $k = $Master_Hash.Count
    for ($i = 0; $i -lt $Hostname_Hash.Count; $i++) {
        for ($j = 0; $j -lt $Master_Hash.Count; $j++) {
            if ($Master_Hash[$j].IP -ne $Hostname_Hash[$i].IP){
                $key = "Item" + "$K"
                $Diff_to_add["$key"] = $Hostname_Hash[$i]
                $k++
                break
            }
        }
    }
    $Master_Hash += $Diff_to_add
    Write-Verbose "Comparison complete - Added $($Diff_to_add.count) entries from NMAP to master list"

    #Comparing DHCP
    $Diff_to_add = [ordered]@{}
    $i = 0
    $k = $Master_Hash.Count
    for ($i = 0; $i -lt $IP_Hash_List.Count; $i++) {
        for ($j = 0; $j -lt $Master_Hash.Count; $j++) {
            if ($Master_Hash[$j].IP -ne $IP_Hash_List[$i].IP){
                $key = "Item" + "$K"
                $Diff_to_add["$key"] = $IP_Hash_List[$j]
                $k++
                break
            }
        }
    }
    $Master_Hash += $Diff_to_add
    Write-Verbose "Comparison complete - Added $($Diff_to_add.count) entries from DHCP to master list"
    #endregion Compare and add unique
    
    #region Save and Exporting
    Write-Verbose "Writing to files"
    $Array_to_export = @()
    foreach ($item in $Master_Hash){
        $Array_to_export += $item.Values.GetEnumerator()    
    }
    $date_to_append = Get-Date -Format "MM-dd-yyyy"
    $Final_save_location = "$Master_Hash_Save_Location" + "$date_to_append" + "MasterHash.csv"
    if (Test-Path $Final_save_location){
        Write-Verbose "Found existing CSV from today -moving before saving new list to $Final_save_location"
        $move_location = "$Master_Hash_Save_Location" + "BackupCopy-ToBeDeletedOnNextRun" + " - Masterhash.csv"
        Move-Item $Final_save_location -Destination $move_location -Force
        $Array_to_export | ForEach-Object{ [pscustomobject]$_ } | sort-object {$_.devicename} | Export-Csv -Path $Final_save_location
    }
    else{
        Write-Verbose "Saving new CSV to $Final_save_location"
        New-Item -Path $Final_save_location -Force
        $Array_to_export | ForEach-Object{ [pscustomobject]$_ } | sort-object {$_.devicename} | Export-Csv -Path $Final_save_location
    }
    Invoke-Item $Final_save_location
    #endregion Save and Exporting
}
Start-Main -Verbose
