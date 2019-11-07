<#
Author: Nickolaus Vendel
Date: 5-16-2019

1.
    Your templates will need to use the following as the names for it to work without modification:
    *in.oft
    *out.oft
    *EOW.oft
    Your EOW summary needs to have "EOW Summary" in the email subject somewhere for it to match
    the Check out and EOW need to include a line at the top that has #Content# for setting previous content into it

2. Schedule this as a startup task at first login 

3. By default the script opens your starting applications and by default outlook only - you can configure the csv to open other applications as well

Additional configuration options:
    If you want to include times to easier see how your 8 hours line up include a #Time# line where you want it to be inserted into your template
    you can also use the application model where it looks for outlook to also look for another application like firefox or chrome or add a similar line in the csv file 
If you do use the templated ensure that you update the emailtable variable with the starting letter you want it to look for - if you're using a C:\ putting a path closer to the 
destination file will allow it to work faster
#>    


#region Variable Definitions

#Gets both check in and check out variables
Write-verbose "Configuring Email templates"
$EmailTable = @{}
$EmailTable.CheckoutTime = ( ( (get-date).AddHours(9) ).AddMinutes(-2).GetDateTimeFormats('t')[1] ) 
$EmailTable.CheckInTemplate  = get-childitem "U:\" -Recurse *.oft | Where-Object {$_.Name | select-string -Pattern "in.oft"} 
$EmailTable.CheckOutTemplate = get-childitem "U:\" -Recurse *.oft | Where-Object {$_.name | select-string -Pattern 'out.oft'} 
$EmailTable.EOWTemplate      = get-childitem "U:\" -Recurse *.oft | Where-Object {$_.name | select-string -Pattern 'EOW.oft'} 

#endregion Variable Definitions


#region Script Functions

Function Restart-Function{
    [Cmdletbinding()]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)] ${FunctionName}
    )
    Read-Host "There was an error executing function $FunctionName Press enter to retry, type 'continue' to ignore error and proceed, type 'exit to exit script' " -OutVariable $choice
    switch ($choice)
    { 
        'continue' { 
                       Write-Verbose "Continuing"
                       return continue
                   }
        'exit'     {
                       Write-Verbose "exiting"
                       return exit
                   }
        Default    { 
                       Write-Verbose "Executing Last function"
                       Invoke-Command{ [scriptblock]::Create($FunctionName).invoke($FunctionName) } 
                   }
    }
}#End Function Restart-Function

#region Outlook Functions

Function Get-OutlookSentItems{
<#

   .Synopsis

    This function returns sent items from default Outlook profile

   .Description

    This function returns sent items from default Outlook profile. It

    uses the Outlook interop assembly to use the olFolderSentMail enumeration.

    It creates a custom object consisting of Subject, SentOn, Importance, To

    for each sent item.

    *** Important *** depending on the size of your sent items this function

    may take several minutes to gather your sent items. If you anticipate

    doing multiple analysis of the data, you should consider storing the

    results into a variable, and using that.

   .Example

    Get-OutlookSentItems |

    where { $_.SentOn -gt [datetime]"5/5/11" -AND $_.SentOn -lt `

    [datetime]"5/10/11" } | sort importance

    Displays Subject, SentOn, Importance, To for all sent items that were sent

    between 5/5/11 and 5/10/11 and sorts by importance of the email.

   .Example

    Get-OutlookSentItems | Group-Object -Property To | sort-Object Count

    Displays Count, To and grouping information for all sent items. The most

    frequently used contacts appear at bottom of list.

   .Example

    $sentItems = Get-OutlookSentItems

    Stores Outlook sent items into the $sentItems variable for further

    "offline" processing.

   .Example

    ($sentItems | Measure-Object).count

    Displays the number of messages in Sent Items

   .Example

    $sentItems | where { $_.subject -match '2011 Scripting Games' } |

     sort SentOn -Descending | select subject, senton -last 5

    Uses $sentItems variable (previously created) and searches subject field

    for the string '2011 Scripting Games' it then sorts by the date sent.

    This sort is descending which puts the oldest messages at bottom of list.

    The Select-Object cmdlet is then used to choose only the subject and sentOn

    properties and then only the last five messages are displayed. These last

    five messages are the five oldest messages that meet the string.

   .Notes

    NAME:  Get-OutlookSentItems

    AUTHOR: ed wilson, msft

    LASTEDIT: 05/10/2011 08:36:42

    KEYWORDS: Microsoft Outlook, Office

    HSG: HSG-05-25-2011

   .Link

     Http://www.ScriptingGuys.com/blog

 #Requires -Version 2.0

 #>
    [Cmdletbinding()]
    Param()
    #Author heyscripting guy - gets sent items including the message
    Add-type -assembly "Microsoft.Office.Interop.Outlook" | out-null
    
    $outlookFolders   = "Microsoft.Office.Interop.Outlook.olDefaultFolders" -as [type]
    $outlook          = New-Object -ComObject outlook.application
    $OutlookNamespace = $outlook.GetNameSpace("MAPI")
    
    $folder = $OutlookNamespace.getDefaultFolder($outlookFolders::olFolderSentMail)
    $folder.items 
}#End Function Get-OutlookSentItems

Function Get-OutlookDraftItems{
    [Cmdletbinding()]
    Param()
    #allows you to look at your draft items more info in the get-outlooksentitems comment block
    Add-type -assembly "Microsoft.Office.Interop.Outlook" | out-null
    
    $outlookFolders   = "Microsoft.Office.Interop.Outlook.olDefaultFolders" -as [type]
    $outlook          = new-object -ComObject outlook.application
    $OutlookNamespace = $outlook.GetNameSpace("MAPI")
    
    $folder = $OutlookNamespace.getDefaultFolder($outlookFolders::olFolderDrafts)
    $folder.items 
}#End Function Get-OutlookDraftItems

#endregion Outlook Functions

#region Application Opening

Function Get-CSVinformation{
    [Cmdletbinding()]
    Param()
    #grabs and parses username for directory info
    $User = whoami
    $Username += $user.Split("{\}")
    $desktoplocation = "C:\users\$($username[1])\desktop"
    Set-Location $desktoplocation       
            
    #Reads from config file if present - if not it writes it for faster evaluation since get-childitem is slow
    $ApplicationList = New-Object System.Collections.ArrayList
    Write-Verbose "Checking for Config File"
    If(test-path "$desktoplocation\Config_File.csv")
    {
        write-verbose "Config File found! Importing Settings"
        $ImportedContent = Import-Csv "$($desktoplocation)\Config_File.csv" -erroraction silentlycontinue
        foreach($object in $ImportedContent)
        {
            $ApplicationList.add($object) >$null
        }#End Object
    }
    
    #Configure Applications Here (or in CSV)
    else
    {
        write-verbose "Application list not found writing..."  
        
        write-verbose "Outlook"
        $Outlook = get-childitem "C:\Program Files (x86)\", "C:\Program Files\" -Recurse -include "outlook.exe" -OutBuffer 1000
        $Outlook | Export-Csv "$($Desktoplocation)\Config_File.csv"
        write-verbose "Outlook done"
  
        write-verbose "Appending to application list"
        $ImportedContent = Import-Csv "$($desktoplocation)\Config_File.csv" -erroraction silentlycontinue
        
        foreach($object in $ImportedContent)
        {
            $ApplicationList.add($object) >$null
        }#End object
    }
    return $ApplicationList
}#End Function Get-CSVInformation

Function Start-Applications{
    [Cmdletbinding()]
    Param()
    #Starts the programs configured in application list and ensures they open
    
    $Applicationlist = Get-CSVinformation
    foreach($Process in $Applicationlist)
    {
        if( !(Get-Process -name $process.basename -ErrorAction SilentlyContinue) )
        {
            Write-Verbose "$process.basename found not running... Starting... "
            Start-Process -FilePath $Process.fullname -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 10 
        }
        $i=0
        #Start While
        while( ( !(Get-Process -Name $Process.basename -ErrorAction SilentlyContinue) ) -and ($i -le 5) )
        {
            Write-Verbose "Process $process.basename not running"
            Start-Process -FilePath $Process.fullname -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 10
            Write-Verbose "Process attempted to start"
            $i++
        }#End While
    }#End Process
}#End Function Start-Applications

#endregion Application Opening

#region Outlook Email Configurations

Function Start-CheckIn{
    [Cmdletbinding()]
    Param()
    Write-verbose "Email templates configured"
    Write-Verbose "Starting check in email"
    Try
    {
        #Start Do while
        $i=0
        do
        {
            If(Get-Process -name outlook -ErrorAction SilentlyContinue)
            {      
                Write-Verbose "Configuring Check In email"
                #Creates the Check In email with the start time
                $OutlookObjectCI = New-Object -ComObject outlook.application -ErrorAction Inquire
                $MailCI = $OutlookObjectCI.CreateItemFromTemplate($EmailTable.CheckInTemplate.FullName)
                #$MailCI.HTMLBody = $MailCI.HTMLBody.Replace("#Time#", $CheckinTime)
                $MailCI.Display()
            }
        $i++
        }
        while($i -le 3 -and (! (get-process -ErrorAction SilentlyContinue | Where-Object {$_.mainwindowtitle -match "check in" } | Format-Table MainWindowTitle) ) )
        #End Do While
    }
    Catch
    { 
        Restart-Function -FunctionName "Start-CheckIn"
    }      
}#End Start-CheckIn

Function Get-PreviousCheckoutEmail{
    [Cmdletbinding()]
    Param()
    Write-Verbose "starting to open last checkout"
    Try
    {
        if( (get-date).DayOfWeek -eq "Monday")
        {
            #CheckOut from previous friday
            $LastCheckOut = Get-OutlookSentItems | 
            Where-Object {$_.subject -match "Daily Check out" } |
            Where-Object {$_.senton -ge (Get-Date).AddDays(-3)}
            $LastCheckOut.display()
        }
        Else
        {
            #CheckOut from previous day
            $LastCheckOut = Get-OutlookSentItems | 
            Where-Object {$_.subject -match "Daily Check out" } |
            Where-Object {$_.senton -ge (Get-Date).AddDays(-1)}
            $LastCheckOut.Display()
        }
    }
    Catch
    { 
        Restart-Function -FunctionName "Get-PreviousCheckoutEmail"    
    }   
}#End Get-PreviousCheckoutEmail

Function Start-EOWSummaryEmail{
    [Cmdletbinding()]
    Param()
    Write-Verbose "Starting to open EOW summary and if Friday opens a new one and last weeks"
    Try
    {       
        #EOW Summary
        $LastEOW = Get-OutlookDraftItems | 
        Where-Object {$_.subject -match "EOW Summary"} |
        Where-Object {$_.senton -le (Get-Date).AddDays(-1)}
            
            
        #If it's Monday it shows last week at the top to be able to make one for the week and adjust for the week
        #Also if it's monday it will open the friday's checkout, else opens the day before's checkin
        if( (get-date).DayOfWeek -eq "Friday")
        {
            #EOW
            $PreviousEOW = $LastEOW.HTMLbody
            $OutlookObjectEOW = New-Object -ComObject outlook.application -ErrorAction Inquire
            $EOWMail = $OutlookObjectEOW.CreateItemFromTemplate($EmailTable.EOWTemplate.FullName)
            $EOWMail.HTMLBody = $EOWMail.HTMLBody.Replace('#Content#', $PreviousEOW)
            $EOWMail.Display()
        }
        else
        {
            #EOW of the week
            $LastEOW.display()
        }
    }
    Catch
    {
        Restart-Function -FunctionName "Start-EOWSummaryEmail"
    }   
}#End Start-EOWSummaryEmail

Function Start-Checkout{
    [Cmdletbinding()]
    Param()
    try
    {
        #Gets the stuff formatted before inserting
        Write-Verbose "Configuring Check Out email"
        $OriginalCheckIn = Get-OutlookSentItems | 
        Where-Object {$_.subject -match "Daily Check in" } |
        Where-Object {$_.senton -ge (Get-Date).AddMinutes(-30)}
            
        $FilteredCheckIn =  $OriginalCheckIn.HTMLBody
     
        #Creates the message with the formatting adjustments
        $OutlookObject = New-Object -ComObject outlook.application
        $Mail = $OutlookObject.CreateItemFromTemplate($EmailTable.CheckOutTemplate.FullName)
        $Mail.HTMLBody = $Mail.HTMLBody.Replace("#Time#", $EmailTable.CheckoutTime)
        $Mail.HTMLBody = $Mail.HTMLBody.Replace("#Content#", $FilteredCheckIn)
        $Mail.Display() 
    }
    Catch
    {
        Restart-Function -FunctionName "Start-Checkout"
    }
}#End Start-Checkout

#endregion Outlook Email Configurations

#endregion Script Functions


#region To be created later

#Add function for releasing outlook? - idea captured on 9/6
<#
Function Release-Program
{
    [Cmdletbinding()]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)] $ProgramName
    )
    #Start here
    
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($word)
    Remove-Variable -Name word

}#end Release-Program
#>

#Change function EOW to have friday template of the checkin/out and use as a positional param more or less
#Also add opening the week's work of checkouts
##better would be just bring in the specific section only of the planned work of what was recordedinstead of unplanned section

#endregion To be created later


Function Start-WorkProcesses{
    [Cmdletbinding()]
    Param()
    
    Start-Applications
    Start-CheckIn
    Get-PreviousCheckoutEmail
    #Start-EOWSummaryEmail
    Read-Host "Press enter after submitting your check-in email to populate your check out email"
    Start-Checkout

}#End Start-WorkProcesses

#There are many Verbose messages if you wish to view to verify functionality use the -verbose switch can also selectively use within Start-WorkProcesses
Start-WorkProcesses #-Verbose
