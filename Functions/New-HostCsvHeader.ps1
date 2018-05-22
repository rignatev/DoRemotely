function New-HostCsvHeader {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject]
        $CustomHeader
    )
    
    process {
        $csvHeader = [PSCustomObject]@{
            'HostName' = $null
            'HostType' = $null
        }

        foreach ($property in $CustomHeader.PSObject.Properties) {
            if ($csvHeader.PSObject.Properties.Name -notcontains $property.Name) {
                $csvHeader | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value
            }
        }

        $csvHeader
    }
}