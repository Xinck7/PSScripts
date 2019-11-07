########################
#My portion of a script from optimizing from complete rewrite: includes arraylists, multiple if's, md5, shorter comparison of 2 large files, sorting export
########################
#Sets the filepath for CSV if available and error file location
$CSVFilePath = $ConfigProfile.outfile.path + $ConfigProfile.name + ".csv"
$RenamedErrorFile = $configprofile.outfile.path + $configprofile.name + "_Error.csv"     
    
#If CSV file exists takes the events and combines with newest list    
If( test-path $CSVFilePath )
{
    $SavedHash = $ConfigProfile.outfile.md5
    $CSVFileHash = Get-FileHash -path $CSVFilePath
    #If the hash has changed, moves it as an error file and writes a new CSV with collected events
    If ( $SavedHash -ne $($CSVFileHash.hash) )
    {
        #when it doesn't equal move the renamed file as error file and creates the CSV
        Move-Item -path $CSVFilePath -destination $RenamedErrorFile -force
        $InitialEvents = @()
        foreach( $event in $EventListArray.Toarray() )
        {
            $InitialEvents += $Event
        }
        "" | Export-CSV -Force -Path $CSVFilePath
        $InitialEvents | sort-object {[int]$_.recordnumber} -Descending | Export-CSV -force -Path $CSVFilePath
    }
    
    #If the hash has not changed will collect and continue
    Else 
    {
        #Collects the Events as an arraylist that are within retention
        $CSVEvents = new-object system.collections.arraylist
        $CSVImportEvents = import-csv "C:\users\locktest\Desktop\TestingLargeEvents.csv"#$CSVFilePath 
        foreach ( $ImportedEvent in $CSVImportEvents )
        {
            $Time = [Management.ManagementDateTimeConverter]::ToDateTime( $ImportedEvent.TimeGenerated )  
            If( $Time -gt ( (get-date).AddDays(-30) ) )
            {  
                $CSVEvents.add( $ImportedEvent ) > $null
            }
        }
        
        #Compares events and adds newest records only
        foreach( $Event in $EventListArray.ToArray() )
        {
            if($Event.recordnumber -gt $CSVEvents[0].recordnumber)
            {
                $CSVEvents.add( $Event ) > $null
            }
        }
        
        #exports all the events and sorts
        $FilteredEvents = @()
        foreach( $Event in $CSVEvents.Toarray() )
        {
            $FilteredEvents += $Event
        }
        "" | Export-CSV -Force -Path $CSVFilePath
        $FilteredEvents | sort-object {[int]$_.recordnumber} -Descending | Export-CSV -force -Path $CSVFilePath
    }
}

#If not found writes all events already collected to a CSV
Else
{
    $InitialEvents = @()
    foreach( $event in $EventListArray.Toarray() )
    {
        $InitialEvents += $Event
    }
    "" | Export-CSV -Force -Path $CSVFilePath
    $InitialEvents | sort-object {[int]$_.recordnumber} -Descending | Export-CSV -force -Path $CSVFilePath  
}

#Applies newest Hash of the file to the JSON config file
$CSVFileHash = Get-FileHash -path $CSVFilePath
$config.profiles | where{$_.name -eq $configprofile.name} | %{$($_.Outfile).MD5 = $csvfilehash.hash}
Convertto-JSON $config -depth 10 | set-content $JsonPath

#######################################################################################
#Testing Lab event information- includes casting, listarrays, csv import/export
$time = [system.management.managementdatetimeconverter]::ToDmtfDateTime((get-date).AddDays(-1))
$DCEvents = Get-WmiObject Win32_NTLogEvent -Filter "(logfile='security') AND (EventCode='4688') AND (TimeGenerated>='$time')" 
                        Foreach( $DCevent in $DCevents ) 
                        {
                            $EventListArray.add( $DCEvent ) > $null
                        }  
$CSVFilePath = "C:\users\vendelni\Desktop\test1.csv"
$CSVEvents = new-object System.Collections.ArrayList
$CSVImportEvents = import-csv $CSVFilePath 
            foreach ( $ImportEvent in $CSVImportEvents )
            {
                $CSVEvents.add( $importEvent ) >$null
            }


$ExportArray = @()
foreach( $event in $CSVEvents.Toarray() )
{
    $exportarray += $event
}
   
$CSVFilePath2 = "C:\users\vendelni\Desktop\test2.csv"         
"" | Export-CSV -Force -Path $CSVFilePath2
$exportarray | sort-object {[int]$_.eventcode}, {[int]$_.recordnumber} -Descending | Export-CSV -force -Path $CSVFilePath2 
ii test2.csv
ii test1.csv

##########################################

