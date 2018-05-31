param (
    # PSObject with Dolet settings
    [Parameter(Mandatory=$true, Position=0)]
    [psobject]
    $Settings,

    # PSObject with Dolet result
    [Parameter(Mandatory=$true, Position=1)]
    [psobject]
    $Result,

    # PSObject with Host data
    [Parameter(Mandatory=$true, Position=2)]
    [psobject]
    $HostObject
)
$Version = '1.0'
try {
    if ($Version -ne $Settings.Version) {
        throw 'Dolet version and Settings version do not match'
    }
    #region Dolet code






    #endregion Dolet code
    $Result.Status = $true
}
catch {
    $Result.Status = $false
    $Result.Error = $Error[0]
}

return $Result