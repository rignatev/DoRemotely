function New-ObjectFilter {
    [CmdletBinding()]
    param (
        # Returns the default settings in the JSON plain text 
        [Parameter(Mandatory = $false, Position = 0)]
        [switch]
        $PlainText
    ) 
    begin {
    $filterJson = @'
[
    {
        "TypeName": "ObjectFilter",

        // Enables filter
        "Enabled": true,

        // Filter settings
        "Settings": {
            
            // Enables Include section
            "IncludeEnabled": true,

            // Enables Exclude section
            "ExcludeEnabled": true,

            // The action priority of the filter if both actions enabled. True - Include first, false - Exlude first
            "IncludeFirst": true,

            // Makes a comparison case-sensitive
            "CaseSensitive": false,

            // Use Equality or Matching comparison method
            "Equality": false,

            // Use regex or wildcard matching comparison method. Used when Equality = false
            "Regex": false
        },
        // Filter actions
        "Actions": {
            "Include": {
                // The properties of the object and the text to be found
                //"PropertyName1": [],
                //"PropertyName2": []
            },
            "Exclude": {
                // The properties of the object and the text to be found
                //"PropertyName1": [],
                //"PropertyName2": []
            }
        }
    }
]
'@    
    }

    process {
        if ($PlainText) {
            $filterJson
        }
        else {
            $filter = $filterJson -replace '\s*//.*' | ConvertFrom-Json
            $filter[0]
        }
    }
}