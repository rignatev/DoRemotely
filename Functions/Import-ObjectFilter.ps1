function Import-ObjectFilter {
    [CmdletBinding()]
    param (
        # Specifies a path to location of json settings file
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({
            if (-not ($_ | Test-Path -PathType Leaf)) {
                throw 'File does not exist'
            }

            return $true
        })]
        [string]
        $Path
    )
    
    process {
        $importedFilters = (Get-Content -Path $Path -Raw -ErrorAction Stop) -replace '\s*//.*' | ConvertFrom-Json -ErrorAction Stop
        
        if (-not $importedFilters.Count) {
            throw 'The file does not contain any filters. Path - {0}' -f $Path
        }

        $filters = New-Object -TypeName System.Collections.ArrayList
        foreach ($filter in $importedFilters) {
            if ($filter -isnot [psobject] ) {
                throw 'The file does not contain a valid filters. Path - {0}' -f $Path
            }

            $mergedFilter = Merge-PSObjectsProperties -InputObject $filter -ReferenceObject (New-ObjectFilter) -Strict 2
            $null = $filters.Add($mergedFilter)
        }

        $filters
    }
}