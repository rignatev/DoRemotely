param (
    # PSObject with Dolet settings
    [Parameter(Mandatory=$true, Position=0)]
    [psobject]
    $Settings,

    # PSObject with Dolet result
    [Parameter(Mandatory=$true, Position=1)]
    [psobject]
    $Result,

    # PSObject with Dolet settings
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
    
    $Result.ReportResults.MachineName = [System.Environment]::MachineName
    $Result.ReportResults.CustomText = $Settings.Custom.Text
	if ($Settings.Custom.Boolean) {
		$Result.ReportResults.Result = $true
	}
	else {
		$Result.ReportResults.Result = $false
	}
	
	$rawResult = '{0} on the computer {1}' -f $Result.ReportResults.CustomText, $Result.ReportResults.MachineName
	$Result.Result = $rawResult
	
    #endregion Dolet code
    $Result.Status = $true
}
catch {
    $Result.Status = $false
    $Result.Error = $Error[0]
}

return $Result