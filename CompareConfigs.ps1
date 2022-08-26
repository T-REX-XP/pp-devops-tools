#.\CompareUSDConfigs.ps1 -DevFolder ".\dev\d365-agentsource-usdconfig\AgentSourceUSDConfig\Solution\package\data_split\" -TargetFolder ".\prod\d365-agentsource-usdconfig\AgentSourceUSDConfig\Solution\package\data_split\" -OutputFolder ".\output\"
param(
  [Parameter(Mandatory = $true)]
  [string]$SourceFolder,
  [Parameter(Mandatory = $true)]
  [string]$TargetFolder,
  [Parameter(Mandatory = $true)]
  [string]$OutputFolder
)
$enc = [Microsoft.PowerShell.Commands.FileSystemCmdletProviderEncoding]::UTF8
$startTime = $(Get-Date)
$lookupAttrsArray = New-Object System.Collections.ArrayList

#define folders with entities
$sourceEntitiesPath = "$SourceFolder\Entities\"
$targetEntitiesPath = "$TargetFolder\Entities\"
$outEntitiesPath = "$OutputFolder\Entities\"

If (!(Test-Path -Path $outEntitiesPath)) {
  Write-Host "Creating Entities dir in the output folder"
  New-Item -ItemType "directory" -Path $outEntitiesPath
}
else {
  Write-Verbose "Entities dir already existed in output folder"
}

#copy additional files
Get-ChildItem -Path "$($SourceFolder)\*" -Include *.xml | Copy-Item -Destination $OutputFolder

#get files from dev
$sourceFiles = Get-ChildItem $sourceEntitiesPath -recurse | Where-Object { $_.extension -eq ".xml" } | Sort-Object Length
Write-Host "Dev entities count: " ($sourceFiles | Measure-Object).Count

#get files from target
$targetFiles = Get-ChildItem $targetEntitiesPath -recurse | Where-Object { $_.extension -eq ".xml" }
Write-Host "Target entities count: " ($targetFiles | Measure-Object).Count

function Format-XML() {
  [CmdletBinding()]
  Param ([Parameter(ValueFromPipeline = $true, Mandatory = $true)][string]$xmlcontent)
  $xmldoc = New-Object -TypeName System.Xml.XmlDocument
  $xmldoc.LoadXml($xmlcontent)
  $sw = New-Object System.IO.StringWriter
  $writer = New-Object System.Xml.XmlTextwriter($sw)
  $writer.Formatting = [System.XML.Formatting]::Indented
  $xmldoc.WriteContentTo($writer)
  $sw.ToString()
}


function SaveEntityRecordsToDisk() {
  param(
    [Parameter(Mandatory)][string]$outRecordsList,
    [Parameter(Mandatory)][string]$nodeDevHeader1,
    [Parameter(Mandatory)][string]$filePath1,
    [Parameter()][string]$m2mRel  
  )
  #if out records are exist, then save to fs
  if ($outRecordsList.Count -gt 0) {
    #set header
    $finalXml = "$($nodeDevHeader1)<records>$($outRecordsList)</records>"
    if ($m2mRel -eq "") {
      $finalXml += "<m2mrelationships />"
    }
    else {
      $finalXml += "<m2mrelationships>$($m2mRel)</m2mrelationships>"
    }
    $finalXml += "</entity>"
    $result = Format-XML $finalXml
    #save outRecordsList to fs
    Set-Content  -Path $filePath1 -Value $result -Encoding $enc
  } 
}

function ProcessDataSchema() {
  $finalDataSchema = ""

  [xml]$dataSchema = Get-Content "$SourceFolder\data_schema.xml" -Encoding $enc
  $devEntites = $dataSchema.SelectNodes("//entity")

  $entitiesForPatch = Get-ChildItem $outEntitiesPath -recurse | Where-Object { $_.extension -eq ".xml" }
    
  foreach ( $fEntity in $entitiesForPatch) {
    $eMetadata = $devEntites | Where-Object { $_.name -eq $fEntity.BaseName }
    $finalDataSchema += $eMetadata.OuterXml
  }

  if ($finalDataSchema -ne "") {
    $finalDataSchema = Format-XML "<entities>$($finalDataSchema)</entities>"
    Set-Content  -Path "$OutputFolder\data_schema.xml" -Value $finalDataSchema -Encoding $enc
  }
}

function ProcessDeps() {
  foreach ($l in $lookupAttrsArray) {
    $entity = $l.lookupentity
    #load data from entity
    [xml]$xmlDev = Get-Content "$sourceEntitiesPath\$($entity).xml" -Encoding $enc
    $records = $xmlDev.SelectSingleNode("//records")
    $record = $records.record | Where-Object { $_.id -eq $l.value }
    If ($record) {
      #if file exist in Out folder, load itm then insert record
      $outFile = "$outEntitiesPath\$($entity).xml"      
      If (Test-Path -Path  $outFile) {
        [xml]$xmlOutput = Get-Content  $outFile -Encoding $enc
        $outRecords = $xmlOutput.SelectSingleNode("//records")
        #find existed record
        $existOutRecord = $outRecords.record | Where-Object { $_.id -eq $l.value }

        if (!$existOutRecord) {
          $newNode = $xmlOutput.ImportNode($record, $true)
          $outRecords.AppendChild($newNode)
          $m2mrelations = $xmlDev.SelectSingleNode("//m2mrelationships")
          $m2m = $m2mrelations.m2mrelationship | Where-Object { $_.sourceid -eq $record.id }
          If ($m2m) {
            $newNode = $xmlOutput.ImportNode($m2m, $true)
            $m2mrelations.AppendChild($newNode)
          }
          $xmlOutput.Save($outFile)
        }
      }
      else {
        $nodeDevHeader = Get-Content "$sourceEntitiesPath\$($entity).xml" -First 1 -Encoding $enc
        $m2mrelations = $xmlDev.SelectSingleNode("//m2mrelationships")
        $m2m = $m2mrelations.m2mrelationship | Where-Object { $_.sourceid -eq $record.id }
        if ($m2m) {
          $m2m = $m2m.OuterXml
        }
        SaveEntityRecordsToDisk -outRecordsList $record.OuterXml -nodeDevHeader1 $nodeDevHeader -filePath1 $outFile -m2mRel $m2m
      }
    }
  }

}

function ProcessRecordM2m($m2mrelationsDev, $recordId) {
  $m2m = $m2mrelationsDev.m2mrelationship | Where-Object { $_.sourceid -eq $recordDev.id }
  if ($m2m) {
    return $m2m.OuterXml;
  }
  else {
    return "";
  }
}

function CollectDeps($attrsLookup) {
  If ($attrsLookup) {
    If ($attrsLookup.GetType().BaseType.Name -eq "Array") {
      foreach ( $a in $attrsLookup) {
        $existedRecords = $lookupAttrsArray | Where-Object -Property value -eq $a.value
        If ( $existedRecords.Count -eq 0) {
          $lookupAttrsArray.Add($a)
        }                
      }
    }
    else {
      $existedRecords = $lookupAttrsArray | Where-Object -Property value -eq $attrsLookup.value
      If ( $existedRecords.Count -eq 0) {
        $lookupAttrsArray.Add($attrsLookup)
      }       
    }
  }
}

function GenerateHash($outerXml) {
  return (Get-FileHash -InputStream ([System.IO.MemoryStream]::New([System.Text.Encoding]::ASCII.GetBytes($outerXml)))).Hash
}

#Process files 
foreach ($file in $sourceFiles) {
  Write-Host "Process file: $($file.Name)"

  $prodFilePath = $targetEntitiesPath + $file.Name
  Write-Verbose "Prod File Path: $($prodFilePath)"

  #if the file exist in prod
  If (Test-Path -Path $prodFilePath) {
    # check sha265 hash of the source and target file      
    If ((Get-FileHash $file.PSPath).Hash -ne (Get-FileHash $prodFilePath).Hash) {       
      #load xml from dev file
      [xml]$xmlDev = Get-Content $file.PSPath -Encoding $enc
    
      $nodeDevHeader = Get-Content $file.PSPath -First 1 -Encoding $enc
      $nodeDev = $xmlDev.SelectNodes("//record")
      Write-Host "-Records Count: $($nodeDev.Count)"

      $m2mrelationsDev = $xmlDev.SelectSingleNode("//m2mrelationships")
      Write-Host "-M2M Count: $($m2mrelationsDev.m2mrelationship.Count)"
    
      #load xml from dev file
      [xml]$xmlProd = Get-Content $prodFilePath -Encoding $enc
      $nodeProd = $xmlProd.SelectNodes("//record")

      $m2mrelationsProd = $xmlProd.SelectSingleNode("//m2mrelationships")
      Write-Host "-Prod M2M Count: $($m2mrelationsProd.m2mrelationship.Count)"

      $finalRecordsXml = ""
      $finalM2mXml = ""
      $countProcessedFiles = 0
      #compare records
      foreach ($recordDev in $nodeDev) {
        $countProcessedFiles += 1
        Write-Verbose "-- Process record Id: $($recordDev.id)"
        Write-Progress -Activity "$($file.Name): Total records ($($nodeDev.Count)): " -status "processed $countProcessedFiles" -percentComplete ($countProcessedFiles / $nodeDev.Count * 100)
        #find the same record in prod config
        $recordProd = $nodeProd | Where-Object { $_.id -eq $recordDev.id }
        if ( $recordProd ) {
          $devRecordHash = GenerateHash($recordDev.OuterXml) 
          $prodRecordHash = GenerateHash($recordProd.OuterXml)         
          Write-Debug "Record hash: $($devRecordHash), Prod record hash: $($prodRecordHash)"
          
          $devRecordM2m = $m2mrelationsDev.m2mrelationship | Where-Object { $_.sourceid -eq $recordDev.id }
          $prodRecordM2m = $m2mrelationsProd.m2mrelationship | Where-Object { $_.sourceid -eq $recordDev.id }
          If ($devRecordM2m -and $prodRecordM2m) {
            $devM2mHash = GenerateHash($devRecordM2m.OuterXml)
            $prodM2mHash = GenerateHash($prodRecordM2m.OuterXml)
          }
        
          #Add Additional check: if records not equal or records reltions is not equal
          If ($devRecordHash -eq $prodRecordHash) {
            Write-Verbose "Record attributes are the same"
            If ($devRecordM2m) {
              if ($prodRecordM2m) {
                if ($devM2mHash -ne $prodM2mHash) {
                  Write-Host "m2m are different"
                  $finalRecordsXml += $recordDev.OuterXml;                 
                  #get lookup attributes
                  $attrsLookup = $recordDev.field | Where-Object { $_.Attributes.Count -eq 4 }
                  CollectDeps($attrsLookup)
                  $finalM2mXml += $devRecordM2m.OuterXml;
                }
              }
              else {
                $finalM2mXml += $devRecordM2m.OuterXml;
              }             
            }
          }
          else {
            Write-Host "---Attributes are different, record will be added to patch"
            $finalRecordsXml += $recordDev.OuterXml;
            $finalM2mXml += ProcessRecordM2m($m2mrelationsDev, $recordDev.id)   
          }
        }
        else {
          Write-Debug "---Record $($recordDev.id) doesn't exist in prod, will be added to patch"
          #add to the resut entity list 
          $finalRecordsXml += $recordDev.OuterXml;
          #get lookup attributes
          $attrsLookup = $recordDev.field | Where-Object { $_.Attributes.Count -eq 4 }
          CollectDeps($attrsLookup)            
          $finalM2mXml += ProcessRecordM2m($m2mrelationsDev, $recordDev.id)
        }
      }

      if ($finalRecordsXml -ne "") {
        SaveEntityRecordsToDisk -outRecordsList "$finalRecordsXml" -nodeDevHeader1 $nodeDevHeader -filePath1 "$outEntitiesPath$file" -m2mRel "$finalM2mXml"
      }
      else {
        Write-Host "Entity: $($file.Name) skipped. Records are the same."
      }
    }
    else {
      Write-Host "-SHA256 Hash is the same, entity skipped!"
    }
  }
  else {
    Write-Host "Prod file not found"
    #copy file to output folder
    Copy-Item $file.FullName -Destination $outEntitiesPath
  }
}

ProcessDeps
#process data schema
ProcessDataSchema
$elapsedTime = $(Get-Date) - $StartTime
$totalTime = "{0:HH:mm:ss}" -f ([datetime]$elapsedTime.Ticks)
Write-Host "Done! Calculating USD diff has been completed!!! Elapsed $($totalTime)"