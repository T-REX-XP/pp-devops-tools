#.\UnpackAll.ps1 -InputFolder "C:\Users\YuriiNazarenko\OneDrive - LogiqApps AS\Documents\Tino\KB" -OutputFolder "C:\Users\YuriiNazarenko\OneDrive - LogiqApps AS\Documents\Tino\KB\out\"
param(
  [Parameter(Mandatory = $true)]
  [string]$InputFolder,
  [Parameter(Mandatory = $true)]
  [string]$OutputFolder
)


#Creating folder
$condition = Test-Path -Path $OutputFolder
if ($condition -eq $true) {
    Write-host "Output Folder Entity exist"
}
else {
    New-Item -Path $OutputFolder -ItemType Directory
    Write-host "Output Folder Entity created"
}

$files = Get-ChildItem $InputFolder -recurse | Where-Object { $_.extension -eq ".zip" }
$count = $files.Length
Write-Host "Found Files fo unpacking: $count."

foreach ($file in $files) {   
    $folder= $file.Name.Split(".")[0]
    $folderName= "$InputFolder\out\$folder"
    $fname=$file.FullName
    #Write-Host "Unpack: ./UnpackConfig.ps1 -zipfile: ""$fname"" -folder: ""$folderName"" -extractFiles: $True"
    Write-Host "Process file: $file."
    ./UnpackConfig.ps1 -zipfile: "$fname" -folder: "$folderName" -extractFiles: $True
}
Write-Host "Unpacking has been successfully completed."