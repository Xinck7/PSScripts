
$Credentials = Get-Credential
$root = $Credentials.UserName
$plinkopt = $Credentials.GetNetworkCredential().Password
$remotecommand = "ls -lha /tmp | grep Manual" 
$servers = 


#echo Y for old SSH handshakes

foreach ($server in $servers)
{
$server
echo y | plink -pw $plinkopt $root@$server "$remotecommand" 2>$null
}


#Syntax for job notes
#commands from CP for executing scripts remote for using Jobs from windows to linux

$remotecommand = "`"/vmfs/volumes/ds1*/ManualVribsBackup.sh`"" 
foreach ($server in $servers)
{
    $loopcount += @( [array]::indexof($servers,$server) )
    $scriptblock = [scriptblock]::Create("plink" + " " + $plinkopt + " " + $root + "@" + $server + " " + $remotecommand)
    $job = Start-Job -name $server -ScriptBlock $scriptblock
    $jobarray += @($job)
}



#For limiting file size
<#
Found stuff on limiting by bytes in an obscure place for PS
You can use Get-content -encoding bytes -totalcount to use make the file to the amount you want
#>

#For prepending a string to the top of a document
Function do-thing{
get-date 
get-service -Name *bits*}

#do-thing >> test1.txt

$a = get-content test1.txt
$b = get-service -name Spooler
Set-Content -path test1.txt -value $b, $a
ii test1.txt


#Background script block Notes for real specific with plink

#jobarray and loopcount array's are used for manual verification during the PowerShell Start-Job
#$jobarray = @()
#$loopcount = @()

#Runs the staged scripts in parallel and in the background 
foreach ($server in $servers)
{
   $loopcount += @( [array]::indexof($servers,$server) )
   $scriptblock = [scriptblock]::Create("plink" + " " + $plinkopt + " " + $root + "@" + $server + " " + $remotecommand)
   $job = Start-Job -name $server -ScriptBlock $scriptblock
   $jobarray += @($job)
}

get-job
