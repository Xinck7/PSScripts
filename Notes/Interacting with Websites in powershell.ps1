
#region Auto Ticket by Censored Friend's Name and I
#Auto Ticket script by Censored Friend's Name and I
<#
##############################################################################################################
# Author(s): Censored Friend's Name, Nickolaus Vendel
# Date:8/2/2019
# Version: 1.0
# Version Control:
#
# Major Changes - yyyy.mm.dd - Lastname, First (userid)
# Minor Changes - yyyy.mm.dd - Lastname, First (userid)
##############################################################################################################
#>
#If any error occurs, treat it as a terminating error and stop running the script
$ErrorActionPreference = "Stop"


#Load WSUS assembly and save the update server name into a variable
[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
$wsusServer = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer("$env:COMPUTERNAME",$false)


#Discover whether UNAPPROVED Windows 10 Upgrades released within the last week are present and save them to a variable
#Takes several minutes to run
$win10upgrades = $wsusServer.GetUpdates() | Where-Object {$_.ProductTitles -eq "Windows 10" -and $_.UpdateClassificationTitle -eq "Upgrades"}
$filteredUpgrades = $win10upgrades | Where-Object {$_.CreationDate -ge (Get-Date).AddDays(-6) -and $_.IsDeclined -eq $false -and $_.IsApproved -eq $false -and $_.IsSuperseded -eq $false}


#Declare universal email variables
$PSEmailServer = "censoredIP" #email 
$From = "Win10_Upgrade_Notice@donotreply.com" #fabricated address
$To = "Windows_Upgrades@censored.com" #exchange distribution list


#Define success email function
Function Send-SuccessEmail 
{
    [Cmdletbinding()]
    Param()
        Send-MailMessage -From $From -To $To -Subject $SubjectSuccess -BodyAsHtml $BodySuccess -SmtpServer $PSEmailServer
}


#Define failure email function
Function Send-FailureEmail 
{
    [Cmdletbinding()]
    Param()
        Send-MailMessage -From $From -To $To -Subject $SubjectFailure -BodyAsHtml $BodyFailure -SmtpServer $PSEmailServer
}


try
{
    #Begin main script
    if ($filteredUpgrades -eq $null) 
    {
        Exit
    }
        else
        {
        #Create an Event Log source for this script so that errors can be shipped to it
        if ([System.Diagnostics.EventLog]::SourceExists('Windows 10 Upgrade Script') -eq $False)
        {
        New-EventLog -LogName Application -Source "Windows 10 Upgrade Script"
        }


        #Declare variables for eforms webservices site and furnish credentials required to create ticket
        $EFSsite = "https:///censored"
        $createcensored = "https:///censored"
        $userName = ""
        $encryptedPassword = "" | ConvertTo-SecureString
        $siteCredential = New-Object System.Management.Automation.PSCredential -ArgumentList $userName,$encryptedPassword


        #Declare variables for field values
        $ContactID = ""
        $ContactName = ""
        $AddedForID = ""
        $ContactPhone = ""
        $ContactDept = ""
        $ContactNad = ""
        $Location = ""
        $Priority = ""
        $Summary = "Windows 10 Upgrade Review and Approval"
        $NeedBy = (Get-Date).AddDays(27).GetDateTimeFormats()[2]
        $Category = ""
        $Group = ""
        $SubGroup = ""
        $Description = "A Windows 10 feature update released within the past seven days has been detected by censored. Please refer to the Review and Approval process outlined by censored and take action as appropriate."
        $AddedByID = "censored"
        $QueueName = "censored"


        #Obtain and store a session variable so credentials do not have to be re-entered for each request
        Invoke-WebRequest $EFSsite -SessionVariable session -Credential $siteCredential


        #Enter the field values
        $getForm = Invoke-WebRequest -uri $createcensored -WebSession $session
        $form = $getForm.Forms[0]
        $form.Fields.strContactID = $ContactID
        $form.Fields.strContactName = $ContactName
        $form.Fields.strAddedForID = $AddedForID
        $form.Fields.strContactPhone = $ContactPhone
        $form.Fields.strContactDept = $ContactDept
        $form.Fields.strContactNad = $ContactNad
        $form.Fields.strLocation = $Location
        $form.Fields.strPriority = $Priority
        $form.Fields.strSummary = $Summary
        $form.Fields.dtNeedBy = $NeedBy
        $form.Fields.strCategory = $Category
        $form.Fields.strGroup = $Group
        $form.Fields.strSubGroup = $SubGroup
        $form.Fields.strDescription = $Description
        $form.Fields.strAddedByID = $AddedByID
        $form.Fields.strQueueName = $QueueName


        #Submit the form and read the response into a variable
        $formResponse = Invoke-WebRequest -uri $form.Action -WebSession $session -method POST -body $form.Fields


        #Parse the xml response to obtain censored ticket info
        $Censorednumber = ([xml]$formResponse.content).string.InnerText


        #Concatenate the ticket number to create link that can be included with the email
        $Censoredlink = "https://Censored/Pages/View.aspx?EformID=$Censorednumber"


        #Declare variables for Success Email
        $SubjectSuccess = "Windows 10 Upgrade Script - SUCCESS"
        $BodySuccess = "The Windows 10 Upgrade Script has been successfully executed by Powershell.<br><br>"
        $BodySuccess += "Result generated: #Censored <a href=$Censoredlink>$Censorednumber</a>."


        #Send a success email if no failure occurred to this point
        Send-SuccessEmail
        }
}


catch
{
    # Ship Error events to Application event log
    Write-EventLog -LogName Application -Source "Windows 10 Upgrade Script" -EventId 1 -EntryType Error -Message $PSItem.ToString()


    #Declare variables for Failure Email
    $SubjectFailure = "Windows 10 Upgrade Script - FAILURE"
    $BodyFailure = "The Windows 10 Upgrade script on #Censored encountered the error pasted below.<br><br>"
    $BodyFailure += "Please investigate whether the script generated #Censored information <br><br>"
    $BodyFailure += "Error message:<br>"
    $BodyFailure += $PSItem.ToString()


    #Send a failure email if an error occurred
    Send-FailureEmail
}

#endregion Auto Ticket by Censored Friend's Name and I
