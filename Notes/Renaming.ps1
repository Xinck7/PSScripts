#You can use this by making slight modifications to swap the information depending on what you need
#this case I used it for making txt's into csv's and also wanted to rename a set of videos without manually doing it

#used to change the .txt to .csv
Get-ChildItem -File -Recurse | % { Rename-Item -Path $_.PSPath -NewName $_.Name.replace(".txt",".csv")}


#Used for changing larger properties within a location for name
#at location to be ran at this point
$videos = Get-ChildItem -File -Recurse 
$listtocovert = $videos.name -like "*advpwr*"
$i=1
foreach($item in $listtocovert)
{
    $item | Rename-Item -NewName "DSC Video $i .mp4"
    $i++
}
