function Add-DateToName {
    [CmdletBinding()]
    param (
        # Name to which the date will be added
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $Name,

        # Date to be added to the Name
        [Parameter(Mandatory = $false, Position = 1)]
        [datetime]
        $Date = (Get-Date),

        # Date format
        [Parameter(Mandatory = $false, Position = 2)]
        [string]
        $Format = 'yyyyMMdd.HHmmss',
        
        # Delimiter between Date and Name
        [Parameter(Mandatory = $false, Position = 3)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]
        $Delimiter = '',

        # Specifies to add a Date to the beginning of the Name
        [Parameter(Mandatory = $false, Position = 4)]
        [switch]
        $Starts,

        # Specifies to add a Date to the ending of the Name
        [Parameter(Mandatory = $false, Position = 5)]
        [switch]
        $Ends
    )

    process {
        $stringDate = Get-Date -Date $Date -Format $Format
        
        if ($Starts) {
            $Name = ('{0}{1}{2}' -f $stringDate, $Delimiter, $Name)
        }

        if ($Ends) {
            $Name = ('{0}{1}{2}' -f $Name, $Delimiter, $stringDate)
        }
        
        $Name
    }
}