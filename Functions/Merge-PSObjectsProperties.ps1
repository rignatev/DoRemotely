function Merge-PSObjectsProperties {
    [CmdletBinding()]
    param (
        # Input object
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [psobject[]]
        $InputObject,
        
        # Reference object
        [Parameter(Mandatory = $true, Position = 1)]
        [psobject]
        $ReferenceObject,

        # Up to what level strictly check Properties. Value: <int>. Default value 0 - disabled. 
        [Parameter(Mandatory = $false, Position = 2)]
        [int]
        $Strict = 0,

        # Current Depth level. Used for recursion
        [Parameter(Mandatory = $false)]
        [int]
        $CurrentDepth = 0
    )

    process {
        $CurrentDepth++
        $resultObject = $ReferenceObject.PSObject.Copy()
        foreach ($item in $InputObject) {
            foreach ($property in $item.PSObject.Properties) {
                # Verify reference object has the same propery name
                $propertyNames = @(($resultObject | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name))
                if ($propertyNames -contains $property.Name) {
                    # Verify both properties values has the same type
                    if ($property.Value.GetType().FullName -ne ($resultObject.$($property.Name)).GetType().FullName) {
                        throw ('Invalid type for property {0} in the InputObject' -f $property.Name)
                    }

                    # If the properties are PSObject, we call this function recursively
                    if ($property.Value -is [psobject] -or $property.Value -is [PSCustomObject]) {
                        $resultObject.$($property.Name) = Merge-PSObjectsProperties -InputObject $property.Value -ReferenceObject $resultObject.$($property.Name) -Strict $Strict -CurrentDepth $CurrentDepth
                    }
                    else {
                        # If a Value of the InputObject property is not null, assing it to a similar property of the default settings
                        if (($property.Value) -ne $null) {
                            $resultObject.$($property.Name) = $property.Value
                        }
                    }
                }
                else {
                    if ($Strict -and $CurrentDepth -le $Strict) {
                        throw 'Strict level {0} mode is used. Unknown {1} property in the InputObject at depth {2}' -f $Strict, $property.Name, $CurrentDepth
                    }
                    else {
                        $resultObject | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value
                    }
                }
            }
        }
        
        $resultObject
    }
}