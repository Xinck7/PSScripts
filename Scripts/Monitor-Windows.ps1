#region Header
<#
    .NOTES
        Process Name: Monitor-WindowsServer2016.ps1
        Author: Nickolaus Vendel
        Date: 13-SEP-2019
        Revision: 1.3
        Modifications:
        :: Date         User        Version     Modifications
        :: 16-SEP-2019  <username>  1.1.0       Bug/Logic Fixes    
        :: 20-SEP-2019  <username>  1.2.0       Additional Logic 
        :: 23-SEP-2019  VendelNi    1.3.0       Running File Check Added
        :: 26-SEP-2019  VendelNi    1.3.1       HDD checks separated and outside of window checks - also added paging file, cpu queue length, and flag for maint. functionality
        :: 03-OCT-2019  VendelNi    1.4.1       Start/end times now map to a hashtable - Checks, configures and starts performance counter to pull better data from - Parameterized Drive check so that only C:\ always runs
                                                


    .SYNOPSIS 
        Windows Monitoring for Windows using event logs

    .DESCRIPTION 
        Monitoring CPU, Memory and HHD
            When it reaches the threshold it will make an create an event 
            within Windows Application log
    
    .COMPONENT
        Run_Window.txt (optional): Text file to set run window. If the file is not found, the script will still run. 
        MaintenanceModeFlag.flag (optional): If found will do check to see if older then 24 hours, If not older it will exit, if older it will delete file and continue like normal.
#>
#FUNCTIONALITY
#Requires -Version 5.1 
#endregion Header
#region run_Window.txt
<#
    #Date = full date with 4 digit military time eg midnight would be 00:00
    #need to include all dates at this time, if all day then set 00:00 start and 23:59 end

    SundayStart    = 00:00
    SundayEnd      = 02:00

    MondayStart    = 00:00
    MondayEnd      = 02:00

    TuesdayStart   = 02:00
    TuesdayEnd     = 21:00

    WednesdayStart = 02:00
    WednesdayEnd   = 21:00

    ThursdayStart  = 02:00
    ThursdayEnd    = 21:00

    FridayStart    = 00:00
    FridayEnd      = 19:00

    SaturdayStart  = 00:00
    SaturdayEnd    = 23:59


    #>
    #endregion Run_Window.txt
#region Variable Configuration

# Values for defining where and how the server is reporting errors
[string] $Event_Source = "Windows Server 2016"   

# Variables For Checking Thresholds
[int] $CPU_Threshold         = 90  #Percent Value
[int] $Memory_Threshold      = 90  #Percent Value
[int] $Disk_Space_Threshold  = 90  #Percent Value

###Edit Below variables with care###
# RunWindow Variables
$RunWindow = @{}
$RunWindow.Check_Window = $True 
[string]$RunWindow.File = "$PSScriptRoot\DEV\Run_Window.txt"
    
$MaintenanceFlag = @{}
[string]$MaintenanceFlag.File = "$PSScriptRoot\DEV\MaintenanceModeFlag.flag"

# Script Running File Flag Location
$ScriptIsRunningCheck = @{}
$ScriptIsRunningCheck.flag = "$PSScriptRoot\ScriptIsRunning.flag"

# Performance Log Path 
$PerformanceLog = @{}
[string]$PerformanceLog.Path = "C:\PerfLogs\Admin\Performance Monitoring.csv"
#endregion Variable Configuration

#region Script Functions

Function Get-AverageNumber{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$false, Position=0)] $ListOfNumbers
    ) 
    #Initialize Variable
    $Numbertotal = 0 
    $Subtractby = 0

    #Evaluate Total
    
    Foreach($Number in $ListOfNumbers){
        #If given something that isn't a number in the list then it will discard it to keep the average accurate
        try{
            $Number = [double]$Number
        }
        catch{
            $SubtractBy = $SubtractBy + 1
            continue
        }
        $Numbertotal = $Numbertotal + $Number
    }
    
    #Average the Total
    $AverageOfList =  $Numbertotal / ($ListOfNumbers.count - $Subtractby)
       
    Return $AverageOfList
}#End Function Get-AverageNumber

Function Get-HDDThresholds{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$false, Position=0)] [string]$DriveLetter
    )
    #Gets all normal drives
    $Drives = [System.IO.DriveInfo]::getdrives() | Where-Object {$_.DriveType -eq 'Fixed'}
    
    #If fed parameter properly it will look at C only else it will look at all the other drives
    If($DriveLetter -like 'C'){
        $Drives = $Drives | Where-Object {$_.name -eq 'C:\'}
    }
    Else{
        $Drives = $Drives | Where-Object {$_.name -ne 'C:\'}
    }

    #Evalutes the Drive's Diskspace
    $Drives | ForEach-Object { 
        $PercentUsed = (($_.TotalSize - $_.TotalFreeSpace) / $_.TotalSize)*100
        If ($PercentUsed -ge $Disk_Space_Threshold){
            Write-Verbose  "Writing Error message to event log for HDD"
            Write-EventMessage -Event_Source $Event_Source -ID 3 -Message "$($_.Name) Disk Space Threshold exceeded"
        }
    }
}#End Function Get-HDDThresholds

Function Get-LogmanStatus{
    [CmdletBinding()]
    Param()
    $LogmanHash = @{}
    $PerformanceCounterCheck = logman query "Performance Monitoring" 
    $ConfigurationCheck = logman query "Performance Monitoring" | findstr /i "Running"
    #Starts if the monitor counter isn't running
    if($PerformanceCounterCheck[1] -like "Error:"){
        $LogmanHash.CounterExists = $false
    }
    if($ConfigurationCheck -eq $null){
       $LogmanHash.IsStopped = $true 
    }
    Return $LogmanHash
}#End Function Get-LogmanConfiguration

Function Get-PerformanceThresholds{
    [CmdletBinding()]
    Param()
    
    #get preliminary variable information
    $localhost   = Hostname
    $PerfCSV     = import-csv $PerformanceLog.Path
    
    #Assign lists to be averaged
    $CPUPerformanceList = $PerfCSV."\\$localhost\Processor(_Total)\% Processor Time"
    $MemoryPerformanceList = $PerfCSV."\\$localhost\Memory\% Committed Bytes In Use"
    
    #Average the values
    $CPUAverage    = Get-AverageNumber -ListOfNumbers $CPUPerformanceList
    Write-Verbose "CPU average is: $CPUAverage"
    $MemoryAverage = Get-AverageNumber -ListOfNumbers $MemoryPerformanceList
    Write-Verbose "Memory Average is: $MemoryAverage"

    #CPU Threshold check
    If($CPUAverage -ge $CPU_Threshold){
        Write-Verbose "Writing CPU event log"
        Write-EventMessage -Event_Source $Event_Source -ID 3 -Message "CPU Threshold exceeded"        
    }
    
    #Memory Threshold check
    If($MemoryAverage -ge $Memory_Threshold){
        Write-Verbose "Writing Memory event log"
        Write-EventMessage -Event_Source $Event_Source -ID 3 -Message "Memory Threshold exceeded"
    }
} #End Function Get-PerformanceThresholds   

Function Get-RunWindow{
    [CmdletBinding()]
    Param()
    
    If(!($RunWindow.Check_Window)){
        $RunWindow.Window = $true
        Return $RunWindow.Window
    }

    Write-Verbose "Testing Path for Run Window Config Path" 
    If(Test-Path $RunWindow.File){
        Write-Verbose "Getting Setting from $($RunWindow.File)"
        $RunWindow.Current_Time = Get-Date
        $FileInput_RunWindowRaw = Get-Content $RunWindow.File
        $FileInput_RunWindow = $FileInput_RunWindowRaw | ConvertFrom-StringData
        Switch ((Get-Date).DayOfWeek){
            'Sunday'{
                Write-Verbose "Selected Sunday"
                [datetime]$RunWindow.Start_Time = $FileInput_RunWindow.SundayStart
                [datetime]$RunWindow.End_Time   = $FileInput_RunWindow.SundayEnd
            }
            'Monday'{
                Write-Verbose "Selected Monday"
                [datetime]$RunWindow.Start_Time = $FileInput_RunWindow.MondayStart    
                [datetime]$RunWindow.End_Time   = $FileInput_RunWindow.MondayEnd      
            }'Tuesday'{
                Write-Verbose "Selected Tuesday"
                [datetime]$RunWindow.Start_Time = $FileInput_RunWindow.TuesdayStart   
                [datetime]$RunWindow.End_Time   = $FileInput_RunWindow.TuesdayEnd     
            }'Wednesday'{
                Write-Verbose "Selected Wednesday"
                [datetime]$RunWindow.Start_Time = $FileInput_RunWindow.WednesdayStart 
                [datetime]$RunWindow.End_Time   = $FileInput_RunWindow.WednesdayEnd   
            }'Thursday'{
                Write-Verbose "Selected Thursday"
                [datetime]$RunWindow.Start_Time = $FileInput_RunWindow.ThursdayStart  
                [datetime]$RunWindow.End_Time   = $FileInput_RunWindow.ThursdayEnd    
            }'Friday'{
                Write-Verbose "Selected Friday" 
                [datetime]$RunWindow.Start_Time = $FileInput_RunWindow.FridayStart    
                [datetime]$RunWindow.End_Time   = $FileInput_RunWindow.FridayEnd      
            }'Saturday'{
                Write-Verbose "Selected Saturday"
                [datetime]$RunWindow.Start_Time = $FileInput_RunWindow.SaturdayStart  
                [datetime]$RunWindow.End_Time   = $FileInput_RunWindow.SaturdayEnd        
            }
        }
        Write-Verbose "The Current time is $($RunWindow.Current_Time)"
        Write-Verbose "The Selected Run Window start time is $($RunWindow.Start_Time)"
        Write-Verbose "The Selected Run Window end time is $($RunWindow.End_Time)"
        
        #Check if it is during the run window. 
        If( ($RunWindow.Current_Time -ge $RunWindow.Start_Time) -and ($RunWindow.Current_Time -le $RunWindow.End_Time) ){
            Write-Verbose "The time comparison states current time is during the Run Window"
            $RunWindow.Window = $True
        }
        Else{
            Write-Verbose "The time comparison states current time is NOT during the Run Window"
            $RunWindow.Window = $False
        }
    }
    #If file not found, set value to True
    Else{
        Write-Verbose "No config file found, default to run"
        $RunWindow.Window = $True
    }
    Return $RunWindow.Window
}#End Function Get-RunWindow

Function Set-LogmanConfiguration{
    [CmdletBinding()]
    Param()
        
    Write-Verbose "Creating Performance Counter"
    logman create counter -c '\Processor(_Total)\% Processor Time', '\Memory\% committed bytes in use' -f csv -si 30 -name "Performance Monitoring"-ow -rf 04:50 --v
    
}#End Function Set-LogmanConfiguration

Function Write-EventMessage {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)] [string]$Event_Source,
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=1)]    [int]$ID,
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=2)] [string]$Message
    )

    #Creates Event log source if it doesn't exist
    If ([System.Diagnostics.EventLog]::SourceExists($Event_Source) -eq $False){
        New-EventLog -LogName Application -Source $Event_Source
    }
    
    #Writes an eventlog based on fed data for the rest of the script
    Write-EventLog -LogName Application -Source $Event_Source -EventId $ID -EntryType Error -Message $Message

}#End Function Write-EventMessage 
#endregion Script Functions

Function Start-Main{
    [CmdletBinding()]
    Param()
    
    #Check if the script is already running
    Write-Verbose "Checking to see if script is running..."
    If(Test-Path $ScriptIsRunningCheck.flag){
        $ScriptRunningFileDate = (Get-ChildItem $ScriptIsRunningCheck -ErrorAction SilentlyContinue).LastWriteTime
        $YesterdayDate = (Get-Date).AddDays(-1)
        #Check if flag is newer then 24 hours
        If ($ScriptRunningFileDate -ge $YesterdayDate){
            Write-verbose "ScriptisRunning flag file found exiting"
            Exit 
        }
        Else{
            Write-verbose "Deleting File as its 24 hours old"
            Remove-Item $ScriptIsRunningCheck
        }
    }
    
    #region Performance Monitoring  
    #Start Performance on CPU Memory logic gates
    If(Test-Path $MaintenanceFlag.file){
        $MaintenanceFlagFileDate = (Get-ChildItem $MaintenanceFlag.file -ErrorAction SilentlyContinue).LastWriteTime
        $SixHoursAgo = (Get-Date).AddHours(-6)
        #Check if flag is newer then 24 hours
        If ($MaintenanceFlagFileDate -ge $SixHoursAgo){
            Write-verbose "Maintenance Flag Set, continuing script without CPU and Memory threshold checks"
            $RunNormalWindowCheck = $false
            Write-Verbose "Flag in use"
        }
        Else{
            Write-verbose "Deleting Maintenance Flag as its 6 hours old"
            Remove-Item $MaintenanceFlag.File
            $RunNormalWindowCheck = $true
            Write-Verbose "Continuing to normal window check"
        } 
    }
    Else{
        Write-Verbose "Test path didn't find flag, Continue to run normal window check"
        $RunNormalWindowCheck = $true
    }
    
    #If flag is not present check normal run window
    If($RunNormalWindowCheck){
        #Runs the check to see if its in Window to Run and the flag is off
        #Script will report on CPU and Memory if during window
        $RunWindow = Get-RunWindow
        If ($RunWindow){        
            
            Write-Verbose "In Run Window continuing to CPU and Memory checks"
            Write-Verbose "Checking if logs are being collected if not, setting the log configuration"
            
            $LogmanResult = Get-LogmanStatus
            If($LogmanResult.CounterExists -eq $false){
                Write-Verbose "Setting Log Configuration"
                Set-LogmanConfiguration
            }          
            Else{
                Write-Verbose "Running Threshold Checks"
                Get-PerformanceThresholds
                Write-Verbose "Checking non C:\ Drives"
                Get-HDDThresholds
            }
            Write-Verbose "Checking status for performance counter if stopped will start"
            If($LogmanResult.IsStopped){
                Write-Verbose "Starting Performance Counter for next run"
                logman start -n "SOS Performance Monitoring"
            }

        }
        Else{
            Write-Verbose "In a Maintenance Window exiting CPU and Memory checks"
        }
    }
    Else{
        Write-Verbose "Maintenance Flag is set exiting CPU and Memory checks"
    }
    #endregion Performance Monitoring

    #Runs C:\ Check regardless of maintenance window if within window checks both separately
    Write-Verbose "Checking C:\ Drive Threshold"
    Get-HDDThresholds -DriveLetter 'C'
}

Start-Main #-Verbose