function New-DoRemotelySettings {
    [CmdletBinding()]
    param (
        # Returns the default settings in the JSON plain text 
        [Parameter(Mandatory = $false, Position = 0)]
        [switch]
        $PlainText
    ) 
    begin {
    $settingsJson = @'
{
    "TypeName": "DoRemotelySettings",

    // Log level for main program: <Debug|Info|Warn|Error|Fatal|Off>
    "Logs.Level.Main": "Error",
    // Log level for threads: <Debug|Info|Warn|Error|Fatal|Off>
    "Logs.Level.Threads": "Error",

    // File name that contains collection of hosts in CSV
    "HostsFile.Name": "hosts.csv",
    // Custom CSV header with default data for a hosts file. it will be combined with the default Header {HostName;HostType}. The order is preserved
    "HostsFile.CSV.Header": {},
    // Hosts CSV delimiter
    "HostsFile.CSV.Delimiter": ";",
    
    // Report file name
    "ReportFile.Name": "report.csv",
    // Add date to the begining of the report file name
    "ReportFile.Name.Date.Starts": true,
    // Add date to the ending of the report file name
    "ReportFile.Name.Date.Ends": false,
    // Date format
    "ReportFile.Name.Date.Fromat": "yyyyMMdd.HHmmss",
    // Delimiter between date and file name
    "ReportFile.Name.Date.Delimiter": "_",
    // Reprot file CSV settings
    "ReportFile.CSV.Append": false,
    "ReportFile.CSV.Delimiter": ";",
    // Specifies the encoding for the report file. Value: <Unicode|UTF7|UTF8|ASCII|UTF32|BigEndianUnicode|Default|OEM>
    "ReportFile.CSV.Encoding": "UTF8",
    "ReportFile.CSV.NoClobber": false,
    "ReportFile.CSV.NoTypeInformation": true,
    "ReportFile.CSV.UseCulture": false,

    // Credentials sets file located at DoRemotely\Settings\
    "CredsSetFilePath": "user.credentials.json",
    // Enabled dolets sets file located at DoRemotely\Settings\
    "DoletsSetFilePath": "user.dolets.json",
    // Filter settings file located at DoRemotely\Settings\
    "FiltersFilePath": "user.filters.json",

    // Enable host filter
    "EnableFilter": false,
    
    // Enable the use of credentials when connecting to hosts
    "EnableCredentials": false,

    // Number of concurrent running runspace threads which are allowed at a time
    "Threads.Throttle": 6,

    // The time in milliseconds, to sleep the threads before closing
    "Threads.Sleep": 200,
    
    // Number of pings when checking hosts
    "Ping.Count": 2,

    // Continue processing if the ping failed
    "Ping.Ignore": false
}
'@    
    }

    process {
        if ($PlainText) {
            $settingsJson
        }
        else {
            $settings = $settingsJson -replace '\s*//.*' | ConvertFrom-Json
            $settings[0]
        }
    }
}