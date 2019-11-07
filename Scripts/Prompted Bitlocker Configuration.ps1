#Author Nickolaus Vendel
#Revision 1.0 
#Date 5.6.2016

$TargetModel = "Insert Model Here"

#Records the password for the Pin for Bitlocker and confirms that it is the correctly typed password
do
{
    $SecureString = read-host "Please enter the PIN you wish to configure BitLocker With (6-20 characters)" -AsSecureString
    $SecureString2 = read-host "Please repeat your password" -AsSecureString
    $SecureStringCheck = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString))
    $SecureStringCheck2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString2))
    if($SecureStringCheck -ne $SecureStringCheck2)
                        {
        Write-Host "Passwords do not match please retype the passwords"
        }
}
while ($SecureString -ne $SecureStringCheck)
Write-Output "Passwords matched"

#Enables Bitlocker with TPM+PIN and adds Recovery Key and saves to be printable
Enable-BitLocker -MountPoint "C:" -UsedSpaceOnly -EncryptionMethod Aes256 -TpmAndPinProtector -Pin $SecureString -SkipHardwareTest |
Add-BitLockerKeyProtector -RecoveryPasswordProtector -WarningVariable BitLockerRecoveryKeyC

#Saves Key to a File to be printed later 
$Location = "C:\Windows"
"The C:\ recovery key" | Out-File  $Location\BitlockerKeyBackup.txt
$BitLockerRecoveryKeyC >> $Location\BitlockerKeyBackup.txt

#checks the make/model before it does the D drive as only applicable to the 7510
$PCModel = wmic computersystem get model
if($PCModel -match "$TargetModel")
{
    $DDrivePresent
    Enable-BitLocker -MountPoint "D:" -UsedSpaceOnly -EncryptionMethod Aes256 -TpmAndPinProtector -Pin $SecureString -SkipHardwareTest |
    Add-BitLockerKeyProtector -RecoveryPasswordProtector -WarningVariable BitLockerRecoveryKeyD
    Enable-BitLockerAutoUnlock -MountPoint "D:"
    "The D:\ recovery key" >>  $Location\BitlockerKeyBackup.txt
    $BitLockerRecoveryKeyD >> $Location\BitlockerKeyBackup.txt

}

Enable-BitLocker -MountPoint "Z:" -UsedSpaceOnly -EncryptionMethod Aes256 -TpmAndPinProtector -Pin $SecureString -SkipHardwareTest |
Add-BitLockerKeyProtector -RecoveryPasswordProtector -WarningVariable BitLockerRecoveryKeyD
Enable-BitLockerAutoUnlock -MountPoint "Z:"
"The Z:\ recovery key" >>  $Location\BitlockerKeyBackup.txt
$BitLockerRecoveryKeyZ >> $Location\BitlockerKeyBackup.txt

#Locates and sends to default printer
$BitLockerRecoveryKeyFile = Get-Content $Location\BitlockerKeyBackup.txt
$BitLockerRecoveryKeyFile | out-printer