
#working with Hashtable - unique item to unique value only allowed
$IPList = @{}
    Foreach($FilteredCSVEvent in $FilteredCSV)
    {
        $IPList.add($FilteredCSVEvent.source ,$FilteredCSVEvent.service) > $null
    }

#This was using some more advanced processes to zip them together 
$HDD_Disks = Get-DiskSpaceUsage -ComputerName $ComputerName  
        $i = 0
        $HDD_Names = @()
        $HDD_Disk_Values = 0
        foreach($HDD_Disk in $HDD_Disks)
        {
            <#
            This uses modulus function to determine if index is divisible by 3.
            As the name is always in an index divisible by 3 based on the output object of $HDD_Disks
            If $HDD_Disks is changed the modulus for the $i will need changed
            #>

            #if data is the name of the drive it will add to the name array
            if($i%3 -eq 0)
            {
                $HDD_Names += "$HDD_Disk"
            }

            #If data is the Disk usage number it will add to the number array
            if(($HDD_Disk.GetType()).basetype -like "system.valuetype")
            {
                $HDD_Disk_Values += $HDD_Disk
            }
        
        $i++
            
        } #end $HDD_disks loop

        #Creates a hash table of the 2 arrays of data
        $Performance.HDD_HashTable = [ordered]@{}
        $i = 0
        for ($i = 0; $i -lt $HDD_Names.Count; $i++)
        {
            $Performance.HDD_HashTable[$HDD_Names[$i]] = $HDD_Disk_Values[$i]
        } #end hashtable creation