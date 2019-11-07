function Get-EventLogData{
    [cmdletbinding()]
    param()
        $logname="system"
        $events=@(
        7031, ` 
        7034
        )
        Write-Verbose "Gathering events: $events from the log named: $logname"
        foreach ($event in $events){
        [array]$eventdata += Get-EventLog -LogName $logname -InstanceId $events
        }#end event loop
        #look at output    
        $eventdata | Format-Table -Wrap
    
    }#end Function Get-EventLogData
    
    get-eventlogdata -Verbose