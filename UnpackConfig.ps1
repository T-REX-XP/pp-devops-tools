param(
    [Parameter(Mandatory = $true)]
    [string]$zipfile,
    [Parameter(Mandatory = $true)]
    [string]$folder,
    [Parameter()]
    [string]$extractFiles = $false
)
$enc = [Microsoft.PowerShell.Commands.FileSystemCmdletProviderEncoding]::UTF8
$filesDir = "$($folder)\\files"

function ExtractFile($record) {
    $attibutes = $record.field
    $fileName = ($attibutes | Where-Object -Property "name" -eq -Value "filename").value
    $body = $attibutes | Where-Object -Property "name" -eq -Value "documentbody"
    if ($body -ne "") {
        try{
            $decodedFile = [System.Convert]::FromBase64String($body.value)
        }catch{
            Write-host "Error during unpacking file: $($fileName). $($_.Error)"
        }
       [IO.File]::WriteAllBytes("$filesDir\$($fileName)", $decodedFile)
    }
}

function UnpackFiles($itemsData) {
    $records = $itemsData.record
    Write-Host "Unpacking files..."
    If (!(Test-Path -Path $filesDir)) {
        Write-Host "Creating files dir in the output folder"
        New-Item -ItemType "directory" -Path $filesDir
    }

    If ($records -is [array]) {
        Write-Host "Entities is array: $($records.Count)"
        for ($i = 0; $i -lt $records.Count; $i++) {
            $record = $records[$i]
            ExtractFile($record)       
        }
    }
    else {
        $record = $records
        Write-Host "Entities is object: $($record)"     
        ExtractFile($record)       
    }
}

#Function to encode xml
function Format-XML ([xml]$xml, $indent = 2) {
    $StringWriter = New-Object System.IO.StringWriter
    $XmlWriter = New-Object System.XMl.XmlTextWriter $StringWriter
    $xmlWriter.Formatting = "indented"
    $xmlWriter.Indentation = $Indent
    $xml.WriteContentTo($XmlWriter)
    $XmlWriter.Flush()
    $StringWriter.Flush()
    Write-Output $StringWriter.ToString()
}

$entitypath = "$folder\Entities"
Expand-Archive -LiteralPath $zipfile -DestinationPath $folder -Force


#Creating folder
$condition = Test-Path -Path $entitypath
if ($condition -eq $true) {
    Write-host "Folder Entity exist"
}
else {
    New-Item -Path $entitypath -ItemType Directory
    Write-host "Folder Entity created"
}

#Spliting xml to another files
[xml]$xmlObject = Get-Content -Path "$folder\data.xml" -Encoding $enc
$entitylist = $xmlObject.entities.entity
$entitiesCount = ($entitylist | Measure-Object).Count
for ($i = 0; $i -lt $entitiesCount; $i++) {
    If ($entitylist -is [array]) {
        $entity = $entitylist[$i]
    }
    else {
        $entity = $entitylist
    }

    if($extractFiles -eq $true){
        if ($entity.name -eq "annotation" ) {
            UnpackFiles($entity.records)
        }
    }
    Format-XML $entity.OuterXml 2 | Out-File $entitypath/$($entity.name).xml
}

Write-Host "Files splitting was successful"

#Remove child nodes in data.xml
$newFile = [xml]$xmlObject
$newparent = $newFile.SelectSingleNode("//entity").ParentNode
$newparent.SelectNodes("entity") | ForEach-Object { $newparent.RemoveChild($_) } > $null
Format-XML $newFile.OuterXml | Out-File "$folder\data.xml"