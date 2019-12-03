$ReportName = "path"
Add-Type -AssemblyName Microsoft.Office.Interop.Excel
$Excel = New-Object -ComObject Excel.Application
$Excel.Visible = $false
$Excel.DisplayAlerts = $false
$ExcelBook = $Excel.workbooks.Open($ReportName)
$ExcelAllWorksheets = $ExcelBook.Worksheets
$FinalWorkSheet = $ExcelBook.worksheets.item(1)

# Configure starting selection points
$StartTop = "A1" #Starting point for the cells
$StartEnd ="H" #The row number gets the last
$DestinationTop = "A" #Select destination column
$DestinationEnd = "H" #Select end of the destination column field

# loop through sheets
for ($i = 2; $i -le $ExcelAllWorksheets.count; $i++) {
    $CurrentSheet = $ExcelBook.worksheets.item($i)
    $CurrentSheet.activate()
    $lastRow1 = $CurrentSheet.UsedRange.rows.count
    $range1 = $CurrentSheet.Range("$StartTop : $StartEnd$lastRow1")
    $range1.copy() | Out-Null
    
    $FinalWorkSheet.activate()
    $lastRow2 = $FinalWorkSheet.UsedRange.rows.count + 2
    $range2 = $FinalWorkSheet.Range("$DestinationTop$($lastRow2):$DestinationEnd$($range1.Rows.Count + $lastRow2)")
    $FinalWorkSheet.Paste($range2)
}
# Delete sheets that are after the 1st
while ($ExcelAllWorksheets.count -gt 1)
{
  for ($i = 2; $i -le $ExcelAllWorksheets.count; $i++){
    $CurrentSheet = $ExcelBook.worksheets.item($i)  
    $CurrentSheet.Delete()
  }
}

# Autofit the cells to view easier
$Autofitrange = $FinalWorkSheet.range("A:H").columns
$Autofitrange.autofit()
$ExcelBook.SaveAs($ReportName)
$ExcelBook.Close()
$Excel.Quit()
