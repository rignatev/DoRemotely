function New-DoletResult {
    [CmdletBinding()]
    param (
        # PSObject with dolet settings
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject]
        $DoletSettings
    )
    
    process {
        [PSCustomObject]@{
            'TypeName' = 'DoletResult'
            'Status' = $false
            'ReportResults' = [PSCustomObject]($DoletSettings.ReportResults).PSObject.Copy()
            'Result' = $null
            'Error' = 'Unknown error'
        }
    }
}