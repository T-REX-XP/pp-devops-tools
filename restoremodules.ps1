param(
    $Path
)
if(-not (Test-Path -Path $Path)) {
    $null = New-Item -Path $Path -ItemType Directory
}
Save-Module -Name ModuleBuilder -RequiredVersion '2.0.0' -Path $Path