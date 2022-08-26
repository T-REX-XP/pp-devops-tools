param(
    [Parameter(Mandatory = $true)]
    [string]$folder,
    [Parameter(Mandatory = $true)]
    [string]$zipfile
)
$enc = [Microsoft.PowerShell.Commands.FileSystemCmdletProviderEncoding]::UTF8
$entitypath = "$folder\Entities"

#Making common xml
$files = Get-ChildItem $entitypath -recurse | Where-Object { $_.extension -eq ".xml" }
$shemaname = Get-Content "$folder\data.xml" -First 1 -Encoding $enc
$finalXml = "$shemaname"


function PackFile($record) {
    $attibutes = $record.field
    $fileName = ($attibutes | Where-Object -Property "name" -eq -Value "filename").value
    $documentBody = $attibutes | Where-Object -Property "name" -eq -Value "documentbody"
    $b64FileContent = [System.Text.Encoding]::UTF8.GetString([char[]][Convert]::ToBase64String([IO.File]::ReadAllBytes("$($folder)\files\$fileName")))
    $documentBody.value = $b64FileContent
    return $record
}

function PrepareAnnotations($file) {
    [xml]$xml = Get-Content $file.PSPath -Encoding $enc
    $records = $xml.entity.records.record
    If ($records -is [array]) {
        Write-Verbose "Entities is array: $($records.Count)"
        for ($i = 0; $i -lt $records.Count; $i++) {
            $record = $records[$i]
            PackFile($record)
            $xml.ImportNode($record, $true)
            Set-Content  -Path $file.PSPath -Value $xml.OuterXml -Encoding $enc       
        }
        Set-Content  -Path $file.PSPath -Value $xml.OuterXml -Encoding $enc
    }
    else {
        $record = $records
        $record = PackFile($record)   
        $xml.ImportNode($record, $true)
        Set-Content -Path $file.PSPath -Value $xml.OuterXml -Encoding $enc
        Write-Verbose "Entities is object:"
    }
}

foreach ($file in $files) {
    if ($file.Name -eq "annotation.xml") {
        PrepareAnnotations($file)
    }
    [xml]$xml = Get-Content $file.PSPath -Encoding $enc
    $node = $xml.SelectNodes("//entity")
    $finalXml += $node.OuterXml
}

$finalXml += "</entities>"
([xml]$finalXml).Save("$folder\data.xml")
Write-Host "Common file is created"

#Create zipfile
Compress-Archive -Path "$folder\*.xml" -DestinationPath $zipfile -CompressionLevel Optimal -Force
Write-Host "$($zipfile) is created"