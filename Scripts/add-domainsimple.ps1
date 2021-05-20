$OU = "<Long OU= path to OU>"
$dom = "<domain>"
Add-Computer -ComputerName "$env:COMPUTERNAME" -DomainName $dom -OUPath $OU