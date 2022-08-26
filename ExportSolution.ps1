#Update name of solution in below line, instead of rte_V1 add name of solution
#https://docs.microsoft.com/uk-ua/power-platform/alm/powershell-api
Set-StrictMode -Version latest
$configFileName = "..\solution.json"

if ((Test-Path -Path $configFileName) -ne $True) {
    throw "Can't read solution.json file inside project root. Please create it and try again."
}
##
##Read config
##
$config = Get-Content $configFileName | ConvertFrom-Json

$solutionName = $config.solutionName
$connectionTimeout = $config.timeout
#Both,Unmanaged,Managed
$packageType = $config.packageType
$outFolder = $config.outFolder

Write-Host "Start Exporting Solution: $($solutionName)"
Write-Host "-Mode: $($packageType)"
Write-Host "-Timeout: $($connectionTimeout)"
Write-Host "-Output Folder: $($outFolder)"


[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$sourceNugetExe = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
$targetNugetExe = "..\nuget.exe"
if ((Test-Path -Path $targetNugetExe) -ne $True) {
    Invoke-WebRequest -Uri:"$sourceNugetExe" -OutFile: "$targetNugetExe"
}




Write-Host "Restore nuget packages..."
Set-Location ..
.\nuget.exe restore -SolutionDirectory "." -Verbosity quiet
Set-Location  .\Tools\

Write-Host "Restore nuget packages completed"
$solPackagerTool = "..\bin\coretools\SolutionPackager.exe"
Set-Alias SolutionPackager $solPackagerTool

##
##Install dependencies
##
function InstallModule {
    #Set-ExecutionPolicy –ExecutionPolicy RemoteSigned –Scope CurrentUser
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    $moduleName = "Microsoft.Xrm.Data.Powershell"
    Write-Verbose "Install dependency $moduleName"
    #$moduleVersion = "2.7.2"
    if (!(Get-Module -ListAvailable -Name $moduleName )) {
        Write-Host "Module Not found, installing now"
        #$moduleVersion
        Install-Module -Name $moduleName -Force -Scope CurrentUser #-MinimumVersion $moduleVersion -Force
        Import-Module Microsoft.Xrm.Data.Powershell
    }
    else {
        Write-Host "Module $moduleName Found"
    }
}
function GetCrmConn {
    param(
        [string]$user,
        [string]$secpasswd,
        [string]$crmUrl)
    Write-Host "UserId: $user Password: $secpasswd CrmUrl: $crmUrl"
    $secpasswd2 = ConvertTo-SecureString -String $secpasswd -AsPlainText -Force
    Write-Host "Creating credentials"
    $mycreds = New-Object System.Management.Automation.PSCredential ($User, $secpasswd2)
    Write-Host "Credentials object created"
    Write-Host "Establishing crm connection next"
    $crm = Connect-CrmOnline -Credential $mycreds -ServerUrl $CrmUrl
    Write-Host "Crm connection established"
    return $crm
}

function ExportSolution {
    if (($packageType -eq "Both") -or ($packageType -eq "Unmanaged") ) {
        Write-Progress -Activity "[0/2] $($solutionName), Download Solutions, unmanaged" -Status "$i% Complete:" -PercentComplete $i
        Export-CrmSolution -conn $connection -SolutionName "$solutionName" -SolutionFilePath "$env:TEMP" -SolutionZipFileName "$($solutionName).zip"     
    }

    if (($packageType -eq "Both") -or ($packageType -eq "Managed") ) {
        $i = 50
        Write-Progress -Activity "[1/2]  $($solutionName), Download Solutions, managed" -Status "$i% Complete:" -PercentComplete $i  
        Export-CrmSolution -conn $connection -SolutionName "$solutionName" -Managed -SolutionFilePath "$env:TEMP" -SolutionZipFileName "$($solutionName)_managed.zip"
        $i = 100
        Write-Progress -Activity "[2/2] $($solutionName), Download Solutions" -Status "$i% Complete:" -PercentComplete $i       
    }
    Write-Host "Solutions succesfully exported!"
}

InstallModule

##
##Create connection
##
Set-CrmConnectionTimeout -TimeoutInSeconds $connectionTimeout
$connection = Connect-CrmOnlineDiscovery -InteractiveMode

$i = 0
if ($null -ne $connection) {        
    ExportSolution
    SolutionPackager /action:"Extract" /zipfile: "$($env:TEMP)\$($solutionName).zip" /packagetype: "$packageType" /folder: $outFolder /errorlevel:"Warning"  /allowDelete:"No" 
    Write-Host "Unpacking solutions DONE!"
}
else {
    Write-Error "Can't create the connection"
}
