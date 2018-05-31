function Add-HostDefaultData {
    [CmdletBinding()]
    param (
        # Host object
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [psobject[]]
        $InputObject,

        # Host CSV header object with default values
        [Parameter(Mandatory = $true, Position = 1)]
        [psobject]
        $HostsCsvHeader
    )
        
    process {
        foreach ($item in $InputObject) {
            foreach ($property in $HostsCsvHeader.PSObject.Properties) {
                if (-not $item.$($property.Name)) {
                    $item.$($property.Name) = $property.Value
                }
            }

            $item
        }
    }

}