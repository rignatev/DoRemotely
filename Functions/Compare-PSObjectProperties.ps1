function Compare-PSObjectProperties {
    [CmdletBinding()]
    param (
        # Input object
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [AllowNull()]
        [psobject[]]
        $InputObject,
    
        # Reference object
        [Parameter(Mandatory = $true, Position = 1)]
        [psobject]
        $ReferenceObject,

        # Set depth level of compare. 
        [Parameter(Mandatory = $false, Position = 2)]
        [int]
        $Depth = 0,

        # Skip Type check
        [Parameter(Mandatory = $false, Position = 3)]
        [switch]
        $NoType,

        # Skip properties count check
        [Parameter(Mandatory = $false, Position = 4)]
        [switch]
        $NoCount,

        # Current Depth level. Used for recursion
        [Parameter(Mandatory = $false)]
        [int]
        $CurrentDepth = 0
    )

    process {
        $CurrentDepth++
        foreach ($item in $InputObject) {
            # Verify that the objects are not $null
            if (-not $ReferenceObject -or -not $item) {
                return $false
            }

            # Verify that the objects are equal
            if ($ReferenceObject -eq $item) {
                return $true
            }

            # Verify properties count
            if (-not $NoCount) {
                if ($($ReferenceObject.PSObject.Properties).Count -ne $($item.PSObject.Properties).Count) {
                    return $false
                }
            }
            
            $inpPropertyNames = @(($item | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name))
            foreach ($refProperty in $ReferenceObject.PSObject.Properties) {
                # Verify if InputObject contains ReferenceObject property
                if ($inpPropertyNames -notcontains $refProperty.Name) {
                    return $false
                }
                
                # Verify that the InputObject property of the same name has the same type
                if (-not $NoType) {
                    if ($refProperty.Value.GetType().FullName -ne ($item.$($refProperty.Name)).GetType().FullName) {
                        return $false
                    }
                }

                # If the properties are PSObject, we call this function recursively
                if ($ReferenceObject.$($refProperty.Name) -is [psobject] -or $ReferenceObject.$($refProperty.Name) -is [PSCustomObject]) {
                    if ($Depth -and $CurrentDepth -ge $Depth) {
                        continue
                    }
                    if (-not (Compare-PSObjectProperties -ReferenceObject $ReferenceObject.$($refProperty.Name) -InputObject $item.$($refProperty.Name) -Depth $Depth -NoType:$NoType -NoCount:$NoCount -CurrentDepth $CurrentDepth)) {
                        return $false
                    }
                }
            }

            $true
        }
    }
}