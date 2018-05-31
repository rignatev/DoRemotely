function New-DoletSettings {
    [CmdletBinding()]
    param (
        # Returns the default settings in the JSON plain text 
        [Parameter(Mandatory = $false, Position = 0)]
        [switch]
        $PlainText
    ) 
    begin {
    $doletSettingsJson = @'
{
    "TypeName": "DoletSettings",

    // The name of the dolet. This name is used as a part of the name of the dolet files
    "Name": "Template",

    // The version of the settings file. Must match with the version of the dolet script file
    "Version": "1.0",

    // Export the $Result.Result to a file
    "File.Export": true,
    // Export to a specific type. Value: <txt|csv|xml|json>
    "File.Type": "json",   
    // // Specifies the file name. If value is empty the HostName will be used
    "File.Name": "",
    // Add date to the begining of the file name
    "File.Name.Date.Starts": true,
    // Add date to the ending of the file name
    "File.Name.Date.Ends": false,
    // Date format
    "File.Name.Date.Fromat": "yyyyMMdd.HHmmss",
    // Delimiter between date and file name
    "File.Name.Date.Delimiter": "_",
    // Specifies the encoding for the exported file
    "File.Encoding": "UTF8",

    // TXT section
    "File.TXT.Append": false,
    "File.TXT.NoNewline": false,

    // CSV section
    "File.CSV.Append": false,
    "File.CSV.Delimiter": ";",
    "File.CSV.NoClobber": false,
    "File.CSV.NoTypeInformation": true,
    "File.CSV.UseCulture": false,
    
    // XML section
    "File.XML.Depth": 2,
    "File.XML.NoClobber": false,
    
    // JSON section
    "File.JSON.Depth": 2,
    "File.JSON.Compress": false,   

    // The results headers and their default values. These headers will be included in the report
    "ReportResults": {
        "Result": "-"
    },

    // Custom section. This section is for various settings that you can use in the dolet script file
    "Custom": {
    }
}
'@    
    }

    process {
        if ($PlainText) {
            $doletSettingsJson
        }
        else {
            $doletSettings = $doletSettingsJson -replace '\s*//.*' | ConvertFrom-Json
            $doletSettings[0]
        }
    }
}