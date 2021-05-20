<#
    author: nickolaus vendel
    date: 2-11-2021
    version: 2
    status: adjusted to fit 20 character limit and also naming requirements
#>

#region variables
#department names
$dept1_name    = "dept1"
$dept2_name    = "dept2"
$dept3_name    = "dept3"
$dept4_name    = "dept4"
$dept5_name    = "dept5"
# $dept6_name    = "dept6"

#abreviated for account name 20 char limit
$dept1_abr     = "dept1"
$dept2_abr     = "dept2"
$dept3_abr     = "dept3"
$dept4_abr     = "dept4"
$dept6_abr     = "dept5"

#software
$nexus_name       = "Nexus"
$artifactory_name = "Artifactory"
$jenkins_name     = "Jenkins"
# $foreman_name     = "Forman"

#software options
$nexus_abr       = "Nex"
$artifactory_abr = "Art"
$jenkins_abr     = "Jenk"
# $foreman_abr     = "Form"

#privileges
$RO    = "Read"
$Write = "User"

#privileges abreviations
$RO_abr    = "RO"
$Write_abr = "WR"

#password input
$default_password = Read-Host -AsSecureString "Input default Password"

#Hashs
$dept_names = [ordered]@{}
$dept_names.add($dept1_name,$dept1_abr)
$dept_names.add($dept2_name,$dept2_abr)
$dept_names.add($dept3_name,$dept3_abr)
$dept_names.add($dept4_name,$dept4_abr)
$dept_names.add($dept5_name,$dept6_abr)

$service_account_softwares = [ordered]@{}
$service_account_softwares.add($nexus_name,$nexus_abr)
$service_account_softwares.add($artifactory_name,$artifactory_abr)
$service_account_softwares.add($jenkins_name,$jenkins_abr)
# $service_account_softwares.add($foreman_name,$foreman_abr)

$service_account_privileges = [ordered]@{}
$service_account_privileges.add($RO,$RO_abr)
$service_account_privileges.add($Write,$Write_abr)

$software_matrix = [ordered]@{}
foreach ($software in $service_account_softwares) {
    $software_matrix[$nexus_name]       = $software
    $software_matrix[$artifactory_name] = $software
    $software_matrix[$jenkins_name]     = $software
    # $software_matrix[$foreman_name]     = $software
}
#endregion variables

#region Troubleshooting write-hosts
<# write host information in case for troubleshooting

        write-host dept name is $dept_names[$name]
            write-host software source is $softwaresource
                write-host software destination $softwaredestination
                    # write-host svc account name is $service_account_name
                    # write-host character count is $service_account_name.length
                    # write-host $Read_Role
                    # write-host $Write_Role
                    # write-host description would be service account for $name for $source to $dest with $group privileges
#>
#endregion Troubleshooting write-hosts

#region Script Section
#Create svc accounts in form and unique permutations for 
$service_accounts = @()
foreach ($name in $dept_names.keys){
    foreach ($softwaresource in $software_matrix.keys){
        foreach ($softwaredestination in $software_matrix[$softwaresource].keys){
            foreach ($access in $service_account_privileges.keys) {
                if ($softwaresource -notmatch $softwaredestination){
                    if($softwaresource -ne $jenkins_name){
                        if($softwaredestination -match $jenkins_name){
                            #Define links to hash table information
                            $dept = $dept_names[$name] 
                            $source = $software_matrix.$softwaresource.$softwaresource
                            $dest = $software_matrix.$softwaresource.$softwaredestination
                            $priv = $service_account_privileges[$access]
                            $service_account_name = "S" + "-" + $dept + "-" + $source + "-" + $dest + "-" +"$priv"
                            $Read_Role = "$name-view-rbac"
                            $Write_Role = "$name-user-rbac"
                            if ($priv -eq $RO_abr){
                                $group = $Read_Role
                            }
                            if ($priv -eq $Write_abr){
                                $group = $Write_Role
                            }
                            #Create Users
                            New-ADUser `
                            -Name $service_account_name `
                            -AccountPassword $default_password `
                            -ChangePasswordAtLogon $false `
                            -Description "service account for $name for $source to $dest with $group privileges" `
                            -Enabled $true
                            write-host svc account name created $service_account_name
                            $service_accounts += $service_account_name

                            #Add groups to users
                            Add-ADGroupMember -Identity $group -Members $service_account_name
                            write-host added $group with member $service_account_name
                            write-host _________________________
                        }
                    }
                    else{
                        #Define links to hash table information
                        $dept = $dept_names[$name] 
                        $source = $software_matrix.$softwaresource.$softwaresource
                        $dest = $software_matrix.$softwaresource.$softwaredestination
                        $priv = $service_account_privileges[$access]
                        $service_account_name = "S" + "-" + $dept + "-" + $source + "-" + $dest + "-" +"$priv"
                        $Read_Role = "$name-view-rbac"
                        $Write_Role = "$name-user-rbac"
                        if ($priv -eq $RO_abr){
                            $group = $Read_Role
                        }
                        if ($priv -eq $Write_abr){
                            $group = $Write_Role
                        }

                        #Create Users
                        New-ADUser `
                        -Name $service_account_name `
                        -AccountPassword $default_password `
                        -ChangePasswordAtLogon $false `
                        -Description "service account for $name for $source to $dest with $group privileges" `
                        -path "<long OU= path for service accounts>" `
                        -Enabled $true
                        write-host svc account name created $service_account_name
                        $service_accounts += $service_account_name

                        #Add groups to users
                        Add-ADGroupMember -Identity $group -Members $service_account_name
                        write-host added $group with member $service_account_name
                        write-host _________________________
                    }
                }
            }
        }
    }
}

#Add other team read permissions to users 

#get WR users
$WR_users = get-aduser -filter {name -like "S-*WR"}

#get all view groups
$view_groups = Get-ADGroup -filter {name -like "*view*"}

#for each WR cycle through each group and add
foreach ($account in $WR_users){
    foreach ($group in $view_groups) {
        if ($group.name -match "cisco*"){
            continue
        }
        Add-ADGroupMember -Identity $group -Members $account
    }
}
#endregion Script Section
