#author: Nickolaus Vendel
#date: 6/12/19
#Revision 1
#further improvements would be to select the folder you wish to have as the packages location and the drive with a gui popup
#These changes were made but not accessible at this time.

$EnglishPackagesDir = "C:\v1903FOD\EnglishPackages" 
$FrenchPackagesDir = "C:\v1903FOD\FrenchPackages"
$ISOMount= "H:\" 
#$ImportPrepDestination = 'C:\users\<user>\Desktop\Windows 10 v1903 Required FOD\Extracted to then be deleted from'

$ISOLocation = dir $ISOMount 

#grabs the specific language pieces for each deployment type for the 64 bit only
$FrenchCollectionRefined = $ISOLocation | where-object -property name -like *fr-CA* | where-object -property name -like *amd64*
$EnglishCollectionRefined = $ISOLocation | where-object -property name -like *en-US* | where-object -property name -like *amd64* 

#Add new array piece if you're adding a new language
$Collections = @($EnglishCollectionRefined, $FrenchCollectionRefined)

#Sets the variable through the loop so that you can easily change behavior within the loop
$i=0
#tools go to their own folders
foreach($Collection in $Collections)
{
    write-host "Starting loop $i"
        if($i -eq 0)
        {
            $PackagesDir = mkdir $EnglishPackagesDir\RSATTools
            $DotnetDir = mkdir $EnglishPackagesDir\dotnet3.5
            
            #dotnet 3.5 base
            $DotNetBaseFile = $ISOLocation | where-object -Property name -like *netfx* | Where-Object -Property name -like *~~*
            $DotNetBaseFile | Copy-Item -Destination $DotnetDir
            
            #dotnet 3.5 language pack
            $dotnet3_5 = $Collection | where-object -Property Name -like *Netfx*
            $dotnet3_5| Copy-Item -Destination $DotnetDir
        }
        else{}
        #Copy this form if new language
        if($i -eq 1)
        {
            $PackagesDir = mkdir $FrenchPackagesDir\RSATTools
            $DotnetDir = mkdir $FrenchPackagesDir\dotnet3.5
            
            #Language Packs
            $FrenchLanguagePacks = $Collection | Where-Object -Property name -like *language*
            $LanguagePackagesDir = mkdir "$FrenchPackagesDir\LanguagePack"
            $FrenchLanguagePacks | Copy-Item -Destination $LanguagePackagesDir
            
            #dotnetbase
            $DotNetBaseFile | Copy-Item -Destination $DotnetDir
            #dotnet 3.5 language pack
            $dotnet3_5 = $Collection | where-object -Property Name -like *Netfx*
            $dotnet3_5| Copy-Item -Destination $DotnetDir
        }
        else{}
    #RSAT Tools
    $CollectionTools = $Collection | where-object -Property name -like *tools* 
    $CollectionTools | Copy-Item -Destination $PackagesDir 
    $i++
}

#Rename to shorter names - gets rid of the "Microsoft-Windows-" piece of the name

$EnglishRenamePending = Get-ChildItem -Recurse $EnglishPackagesDir | Where-Object -property name -like *.cab
$FrenchRenamePending = Get-ChildItem -Recurse $FrenchPackagesDir | Where-Object -property name -like *.cab

foreach($EnglishFile in $EnglishRenamePending)
{
    $NewEnglishName = $EnglishFile.name.Substring(18)
    Rename-Item -Path $EnglishFile.FullName -NewName $NewEnglishName
}
foreach($FrenchFile in $FrenchRenamePending)
{
    $NewFrenchName = $FrenchFile.name.Substring(18)
    Rename-Item -Path $FrenchFile.FullName -NewName $NewFrenchName
}