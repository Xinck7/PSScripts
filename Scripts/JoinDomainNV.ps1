<#
Author: Nickolaus Vendel
Date: 1-14-20
Notes: update from 5/20/21 - this script is to run through a secure way of passing the password to the this script and so the code itself doesn't contain any password
but ruby can encrypt/hide it during provisioning/deployment until its required
#>

#Params as ran from script
Param(
    [Parameter(Mandatory=$true, Position=0)]$puppetusername,
    [Parameter(Mandatory=$true, Position=1)]$puppetpassword,
    [Parameter(Mandatory=$true, Position=2)]$ADUsername
)

#Initial variables 
$Dom = "dayton"

#OU information
$model = (Get-WmiObject win32_computersystem).model
If ( $model -like "*virt*" -or $model -like "*vm*"){
    $OU = "<vm ou path>"
}
ElseIF (((Get-WmiObject win32_computersystem).PCSystemType) -eq 2 ){
    $OU = "<workstation OU path>"
}
Else {
    $OU = "<baremetal workstation OU path>"
}

#Pass puppet credentials from foreman
function Get-PuppetCreds (){
    [Cmdletbinding()]
    $password = ConvertTo-SecureString “$puppetpassword” -AsPlainText -Force
    $Cred = New-Object System.Management.Automation.PSCredential (“$puppetusername”, $password)
    $PuppetCreds = Get-Credential -Credential $Cred
    return $PuppetCreds
}
$PuppetCreds = Get-PuppetCreds

#Join Domain
Add-Computer -ComputerName "$env:COMPUTERNAME" -DomainName $dom -credential $PuppetCreds -OUPath $OU -Confirm:$false

#Grab User to populate owned by field in AD for the computer

#if we don't need the server flag
$User = (Get-ADUser -Identity "$ADUsername" -Credential $PuppetCreds).DistinguishedName

#Sets the computer in AD to be owned by the owner of the laptop
Set-ADComputer -Identity "$env:COMPUTERNAME" -ManagedBy "$User" -Credential $PuppetCreds -Confirm:$false
