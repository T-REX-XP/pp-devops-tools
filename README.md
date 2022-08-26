# Introduction 
That repo contains the scripts for the PowerPlatform developers.


1. `ExportSolution.ps1` - Exporting solution based on config file. Supporting interactive login and progress indicator. This script using config file with the following location: `..\solution.json`

```Json
{
    "solutionName": "",
    "timeout": "00:05:00",
    "packageType": "Both",
    "outFolder": ""
}
```


## Data 
That scripts working with artifacts produced by `Configuration migration tool`.

1. `UnpackConfig.ps1` - Unpack zip package from `Configuration migration tool`. Data will be extracted by entity.

|Parameter|Description|Default Value|
|-|-|-|
|zipfile| Path to the zip file that produced by `Configuration migration tool` ||
|folder| Output folder, where data will be extracted||
|extractFiles| Extract files to filesystem |false|


2. `PackConfig.ps1` - Pack unpacked config into the zip package.

|Parameter|Description|Default Value|
|-|-|-|
|folder| Input folder with extracted files||
|zipfile| Path to the output zip file||

   
3. `CompareConfigs.ps1` - Create zip package that contains difference between two configs

|Parameter|Description|Default Value|
|-|-|-|
|SourceFolder| Folder with current configuration ||
|TargetFolder| Folder with already deployed configuration||
|OutputFolder| Outhut folder that contains diffs||

4. `UnpackAll.ps1` - Wrapper around UnpackConfig, to batch unpacking files.