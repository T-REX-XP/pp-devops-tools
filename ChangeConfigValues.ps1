param(
  [Parameter(Mandatory = $true)]
  [string]$ConfigPath
)
$Replacements = @{
    '\$TenantId' = "$env:TenantId"
    '\$ClientId' = "$env:ClientId"
    '\$ClientSecret' = "$env:ClientSecret"

}

write-verbose "Starting to process $ConfigPath"

(Get-Content -Path $ConfigPath) | ForEach-Object { 
    
	$EachLine = $_

    $Replacements.GetEnumerator() | ForEach-Object {
		
        if ($EachLine -match $_.Key)
        {
            write-verbose "Changing $EachLine to $($_.Value)" 
            $EachLine = $EachLine -replace $($_.Key), $($_.Value)

            write-verbose "Line is now $EachLine"
        }
   }

    $EachLine
} | Out-File $ConfigPath

write-verbose "Completed processing for $ConfigPath"