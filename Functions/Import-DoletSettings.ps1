function Import-DoletSettings {
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
        $settings = (Get-Content -Path $Path -Raw -ErrorAction Stop) -replace '\s*//.*' | ConvertFrom-Json -ErrorAction Stop

        if ($settings -isnot [psobject] ) {
            throw 'The file does not contain a valid dolet settings. Path - {0}' -f $Path
        }

        if (-not (Compare-PSObjectProperties -ReferenceObject (New-DoletSettings) -InputObject $settings -Depth 1)) {
            throw 'The file does not contain a valid dolet settings. Path - {0}' -f $Path
        }

        $settings
    }
}