#requires -version 3.0
#requires -Modules PoshRSJob

<#
    .SYNOPSIS
    Running Powershell scripts on remote hosts via PSSession with saving the returned results

    .DESCRIPTION
    The script processes the collection of hosts and on each runs dolets (powershell scripts) via PSSession.
    Each dolet returns the result of its work. The results are saved in files and in the summary report.
    Requirements for use:
        PowerShell V3
        Necessary rights to pull information from remote hosts
        PoshRSJob module to assist with data gathering

    .NOTES
    Version:          1.0.0
    License:          MIT License
    Author:           Roman Ignatyev
    Email:            rignatev@gmail.com
    Creation Date:    22.05.2018
    Modified Date:    31.05.2018
#>

[CmdletBinding()]
param (
    # Specifies a path to the location of the CSV file containing the list of hosts
    [Parameter(Mandatory = $false, Position = 0)]
    [AllowNull()]
    [string]
    $HostsFilePath,

    # Specifies a path to location of a settings file
    [Parameter(Mandatory = $false, Position = 1)]
    [AllowNull()]
    [string]
    $SettingsFilePath,

    # Specifies a path to location of a list of enabled dolets
    [Parameter(Mandatory = $false, Position = 2)]
    [AllowNull()]
    [string]
    $DoletsSetFilePath,

    # Specifies a path to location of credentials sets file
    [Parameter(Mandatory = $false, Position = 3)]
    [AllowNull()]
    [string]
    $CredsSetFilePath,

    # Specifies a path to location of a filter settings file
    [Parameter(Mandatory = $false, Position = 5)]
    [AllowNull()]
    [string]
    $FiltersFilePath    
)

#region Initializing data
# Set Debug Preferences
Set-PSDebug -Strict

# Initialize start time
$startTime = Get-Date

# Set paths
$rootPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition)
$credentialsPath = "$rootPath\Credentials"
$doletsPath = "$rootPath\Dolets"
$functionsPath = "$rootPath\Functions"
$logsPath = "$rootPath\Logs"
$resultsPath = "$rootPath\Results"
$hostsPath = "$rootPath\Hosts"
$settingsPath = "$rootPath\Settings"
$log4PoShFilePath = "$rootPath\Helpers\Log4PoSh.ps1"
$log4PoShConfigMainFilePath = "$settingsPath\!Log4PoSh\Log4PoShMain.xml"
$log4PoShConfigThreadsFilePath = "$settingsPath\!Log4PoSh\Log4PoShThreads.xml"

if (-not $SettingsFilePath) {
    $SettingsFilePath = "$settingsPath\user.settings.json"  
}

# Create probably missing directories 
if (-not (Test-Path -Path $resultsPath)) {
    $null = New-Item -Path $resultsPath -ItemType Container
}
if (-not (Test-Path -Path $logsPath)) {
    $null = New-Item -Path $logsPath -ItemType Container
}

# Import Log4PoSh
Import-Module -Name $log4PoShFilePath -Force
$logger = New-Log4Posh -Config $log4PoShConfigMainFilePath
$log4PoShLevels = New-Log4PoShLevels
foreach ($appender in $logger.Appenders) {
    if ($appender.ClassName -eq 'RollerFileAppender') {
        $appender.SetFileFolderPath($logsPath)
    }
}
$logger.Info('Start DoRemotely')
# $null = $logger.SetCurrentLevel($log4PoShLevels.Debug)

# Import functions
$logger.Info('Import functions')
$functionsFiles = Get-Item -Path ('{0}\*.ps1' -f $functionsPath) | Where-Object {$_.Name -notmatch '.test.'}
foreach ($functionFiles in $functionsFiles) {
    try {
        . $functionFiles.FullName
    }
    catch {
        $errorMessage = 'Error importing the function from a file. Path - {0}' -f $functionFiles.FullName
        $logger.Fatal($errorMessage)
        $logger.Debug(($Error[0] | Out-String))
        throw $errorMessage            
    }
}
$logger.Debug(('functionsFiles = {0}' -f ($functionsFiles | Out-String)))

# Import the settings
$logger.Info('Import the settings')
try {
    $settings = Import-DoRemotelySettings -Path $SettingsFilePath
}
catch {
    $errorMessage = 'Error importing settings file. Path - {0}' -f $SettingsFilePath
    $logger.Fatal($errorMessage)
    $logger.Debug(($Error[0] | Out-String))
    throw $errorMessage
}

# Set log levels from settings data
$null = $logger.SetCurrentLevel($log4PoShLevels.GetIdByName($settings.'Logs.Level.Main'))

$logger.Debug(('settings = {0}' -f ($settings | ConvertTo-Json)))

# Set paths from settings data
if (-not $HostsFilePath) {
    $HostsFilePath = "$hostsPath\$($settings.'HostsFile.Name')"
}
if (-not (Test-Path -Path $HostsFilePath)) {
    $errorMessage = 'Hosts file is missing. Path - {0}' -f $HostsFilePath
    $logger.Fatal($errorMessage)
    throw $errorMessage
}
$logger.Debug(('HostsFilePath = {0}' -f $HostsFilePath))

if (-not $DoletsSetFilePath) {
    $DoletsSetFilePath = "$settingsPath\$($settings.DoletsSetFilePath)"
}
$logger.Debug(('DoletsSetFilePath = {0}' -f $DoletsSetFilePath))

if (-not $CredsSetFilePath) {
    $CredsSetFilePath = "$settingsPath\$($settings.CredsSetFilePath)"
}
$logger.Debug(('CredsSetFilePath = {0}' -f $CredsSetFilePath))

if (-not $FiltersFilePath) {
    $FiltersFilePath = "$settingsPath\$($settings.FiltersFilePath)"
}
$logger.Debug(('FiltersFilePath = {0}' -f $FiltersFilePath))

# Define reportFilePath
$dateToNameHashArguments = @{
    Name = $settings.'ReportFile.Name'
    Date = $startTime
    Starts = $settings.'ReportFile.Name.Date.Starts'
    Ends = $settings.'ReportFile.Name.Date.Ends'
    Format = $settings.'ReportFile.Name.Date.Fromat'
    Delimiter = $settings.'ReportFile.Name.Date.Delimiter'
}    
$reportFileName = Add-DateToName @dateToNameHashArguments
$reportFilePath = ('{0}\{1}' -f $resultsPath, $reportFileName)
if (-not $settings.'ReportFile.CSV.Append') {
    if ((Test-Path -Path $reportFilePath)) {
        if (-not $settings.'ReportFile.CSV.NoClobber') {
            Remove-Item -Path $reportFilePath -Force
        }
    }
}
$logger.Debug(('reportFilePath = {0}' -f $reportFilePath))

# Import the set of dolets
$logger.Info('Import the set of dolets')
try {
    $dolets = (Get-Content -Path $DoletsSetFilePath -Raw -ErrorAction Stop) -replace '\s*//.*' | ConvertFrom-Json -ErrorAction Stop
    $doletsNames = $dolets.PSObject.Properties.Name
}
catch {
    $errorMessage = 'Error importing the set of dolets. Path - {0}' -f $DoletsSetFilePath
    $logger.Fatal($errorMessage)
    $logger.Debug(($Error[0] | Out-String))
    throw $errorMessage
}
if (-not $doletsNames.Count) {
    $errorMessage = 'A file with the set of dolets is empty. Path - {0}' -f $DoletsSetFilePath
    $logger.Fatal($errorMessage)
    $logger.Debug(($Error[0] | Out-String))
    throw $errorMessage
}
$logger.Debug(('dolets = {0}{1}' -f [System.Environment]::NewLine, ($dolets | Out-String)))

# Import settings and scripts for dolets
$logger.Info('Import settings and scripts for dolets')
$doletsSettings = @{}
$doletsScriptBlocks = @{}
foreach ($doletName in $doletsNames) {
    $doletsSettingsFilePath = '{0}\{1}' -f $settingsPath, $dolets.$doletName
    $doletsScriptFilePath = '{0}\{1}\{1}.dolet.ps1' -f $doletsPath, $doletName
    
    try {
        $doletSettings = Import-DoletSettings -Path $doletsSettingsFilePath
    }
    catch {
        $errorMessage = 'Error importing settings for {0} dolet. Path - {1}' -f $doletName, $doletsSettingsFilePath
        $logger.Fatal($errorMessage)
        $logger.Debug(($Error[0] | Out-String))
        throw $errorMessage
    }
    $null = $doletsSettings.Add($doletName, $doletSettings)

    try {
        $scriptBlock = [scriptblock]::Create((Get-Content -Path $doletsScriptFilePath -Raw -ErrorAction Stop))
    }
    catch {
        $errorMessage = 'Error converting {0} dolet into a script block. Path - {1}' -f $doletName, $doletsScriptFilePath
        $logger.Fatal($errorMessage)
        $logger.Debug(($Error[0] | Out-String))
        throw $errorMessage
    }
    $null = $doletsScriptBlocks.Add($doletName, $scriptBlock)
}
$logger.Debug(('doletsSettings = {0}' -f ($doletsSettings | ConvertTo-Json)))

# Import credentials
$credentialsHash = [ordered]@{}
if ($settings.'EnableCredentials') {
    $logger.Info('Import credentials')
    try {
        $credentialsFileNames = (Get-Content -Path $CredsSetFilePath -Raw -ErrorAction Stop) -replace '\s*//.*' | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $errorMessage = 'Error importing credentials. Path - {0}' -f $CredsSetFilePath
        $logger.Fatal($errorMessage)
        $logger.Debug(($Error[0] | Out-String))
        throw $errorMessage
    }
    foreach ($property in $credentialsFileNames.PSObject.Properties) {
        $credentialsCollection = New-Object -TypeName System.Collections.ArrayList
        foreach ($credentialsFileName in $property.Value) {
            $credentialsFilePath = "$credentialsPath\$credentialsFileName"
            try {
                $credentials = Import-Clixml -Path $credentialsFilePath
            }
            catch {
                $errorMessage = 'Error importing credentials file. Path - {0}' -f $credentialsFilePath
                $logger.Fatal($errorMessage)
                $logger.Debug(($Error[0] | Out-String))
                throw $errorMessage
            }
            $null = $credentialsCollection.Add($credentials)
        }
        $null = $credentialsHash.Add($property.Name, $credentialsCollection)
    }
}
$logger.Debug(('credentialsHash = {0}' -f ($credentialsHash | ConvertTo-Json)))

# Import filters
$filters = $null
if ($settings.EnableFilter) {
    $logger.Info('Import filters')
    try {
        $filters = Import-ObjectFilter -Path $FiltersFilePath
    }
    catch {
        $errorMessage = 'Error importing filters. Path - {0}' -f $FiltersFilePath
        $logger.Fatal($errorMessage)
        $logger.Debug(($Error[0] | Out-String))
        throw $errorMessage
    }
}
$logger.Debug(('filters = {0}' -f ($filters | ConvertTo-Json)))

# Merging CSV host headers
$logger.Info('Merging CSV host headers')
$settings.'HostsFile.CSV.Header' = New-HostCsvHeader -CustomHeader $settings.'HostsFile.CSV.Header'
$logger.Debug(('settings.HostsFile.CSV.Header = {0}' -f ($settings.'HostsFile.CSV.Header' | ConvertTo-Json)))
#endregion Initializing data

#region MainScriptBlock
$mainScriptBlock = {
    # Using paths
    $rootPath = $Using:rootPath
    $resultsPath = $Using:resultsPath
    $reportFilePath = $Using:reportFilePath
    $functionsPath = $Using:functionsPath
    $logsPath = $Using:logsPath
    $log4PoShFilePath = $Using:log4PoShFilePath
    $log4PoShConfigFilePath = $Using:log4PoShConfigThreadsFilePath
    # Using data
    # $threadId = $Using:threadId
    # $threadId = [System.AppDomain]::GetCurrentThreadId()
    $threadId = [guid]::NewGuid().ToString()
    $settings = $Using:settings
    $startTime = $Using:startTime
    $doletsNames = $Using:doletsNames
    $doletsSettings = $Using:doletsSettings
    $doletsScriptBlocks = $Using:doletsScriptBlocks
    $hostObject = $_
    $credentialsHash = $Using:credentialsHash
    
    # Import Log4PoSh
    Import-Module -Name $log4PoShFilePath -Force
    $logger = New-Log4Posh -Config $log4PoShConfigFilePath
    $log4PoShLevels = New-Log4PoShLevels
    $null = $logger.SetCurrentLevel($log4PoShLevels.GetIdByName($settings.'Logs.Level.Threads'))
    foreach ($appender in $logger.Appenders) {
        if ($appender.ClassName -eq 'RollerFileAppender') {
            $appender.SetFileFolderPath($logsPath)
        }
    }
    $logger.Info(('[ID={0}]{1}Start thread {2} for processing host {3}' -f $threadId, "`t", $threadId, $hostObject.HostName))

    if (-not $hostObject) {
        $logger.Info(('[ID={0}]{1}No host received' -f $threadId, "`t"))
        return
    }        

    # Import functions
    $logger.Info(('[ID={0}]{1}Import functions for thread' -f $threadId, "`t"))
    $functionsFiles = Get-Item -Path ('{0}\*.ps1' -f $functionsPath) | Where-Object {$_.Name -notmatch '.test.'}
    foreach ($functionFiles in $functionsFiles) {
        try {
            . $functionFiles.FullName
        }
        catch {
            $errorMessage = ('[ID={0}]{1}Error importing function from file. Path - {2}' -f $threadId, "`t", $functionFiles.FullName)
            $logger.Fatal($errorMessage)
            $logger.Debug(('[ID={0}]{1}{2}' -f $threadId, "`t", ($Error[0] | Out-String)))
            throw $errorMessage            
        }
    }

    # Add dolets ReportResults with default values to the doletReport object
    $logger.Info(('[ID={0}]{1}Prepare the doletReport with ReportResults of enabled dolets on the {2}' -f $threadId, "`t", $hostObject.HostName))
    $doletReport = New-DoletReport -HostObject $hostObject
    foreach ($doletName in $doletsNames) {
        foreach ($property in $doletsSettings.$doletName.ReportResults.PSObject.Properties) {
            $newPropertyName = ('[{0}]: {1}' -f $doletName, $property.Name)
            $doletReport | Add-Member -MemberType NoteProperty -Name $newPropertyName -Value $property.Value
        }
    }
    $logger.Debug(('[ID={0}]{1}doletReport = {2}' -f $threadId, "`t", ($doletReport | ConvertTo-Json)))

    try {
        # Test connection
        $logger.Info(('[ID={0}]{1}Testing connection to computer {2}' -f $threadId, "`t", $hostObject.HostName))
        $pingResult = Test-Connection -ComputerName $hostObject.HostName -Count $settings.'Ping.Count' -Quiet
        if ($pingResult)
        {
            $doletReport.Ping = $true
        }
        else {
            $doletReport.Ping = $false
            if (-not $settings.'Ping.Ignore') {
                throw 'Testing connection to computer {0} failed' -f $hostObject.HostName
            }
            $logger.Error(('[ID={0}]{1}Testing connection to computer {2} failed. Used parameter Ping.Ignore, continue to process' -f $threadId, "`t", $hostObject.HostName))
        }

        # Test WSMan
        $logger.Info(('[ID={0}]{1}Testing the availability of the service WSMan on {2}' -f $threadId, "`t", $hostObject.HostName))
        $null = Test-WSMan -ComputerName $hostObject.HostName -ErrorAction SilentlyContinue -ErrorVariable wsmanError
        if ($wsmanError)
        {
            $doletReport.WSMan = $false
            throw $wsmanError[0]
        }
        $doletReport.WSMan = $true

        # Create PSSession
        $doletReport.PSSession = $false
        if ($settings.'EnableCredentials') {
            if (-not $credentialsHash.$($hostObject.HostType)) {
                throw 'No credentials found for the type {0}' -f $hostObject.HostType
            }
            foreach ($credentials in $credentialsHash.$($hostObject.HostType)) {
                $logger.Debug(('[ID={0}]{1}credentials = {2}' -f $threadId, "`t", ($credentials | ConvertTo-Json)))
                $logger.Info(('[ID={0}]{1}Create a remote session with {2}' -f $threadId, "`t", $hostObject.HostName))
                $remoteSession = New-PSSession -ComputerName $hostObject.HostName -Credential $credentials -ErrorAction SilentlyContinue -ErrorVariable psSessionError
                if (-not $psSessionError) {
                    break
                }
                $logger.Warn(('[ID={0}]{1}Cannot create a remote session with {2} using credentials {3}' -f $threadId, "`t", $hostObject.HostName, $credentials.UserName))
                $logger.Debug(('[ID={0}]{1}Error:{2}{3}' -f $threadId, "`t", [System.Environment]::NewLine, $psSessionError[0]))
            }            
        }
        else {
            $remoteSession = New-PSSession -ComputerName $hostObject.HostName -ErrorAction SilentlyContinue -ErrorVariable psSessionError
        }
        if ($psSessionError -or -not $remoteSession) {
            throw '[ID={0}]{1}Cannot create a remote session with {2}' -f $threadId, "`t", $hostObject.HostName
        }
        $doletReport.PSSession = $true

        # $logger.Debug(('[ID={0}]{1}remoteSession = {2}' -f $threadId, "`t", ($remoteSession | ConvertTo-Json -Depth 1)))
        
        # Invoke dolets script on the remote host
        foreach ($doletName in $doletsNames) {
            $doletResult = New-DoletResult -DoletSettings $doletsSettings.$doletName
            $logger.Debug(('[ID={0}]{1}doletResult = {2}' -f $threadId, "`t", ($doletResult | ConvertTo-Json)))

            $logger.Info(('[ID={0}]{1}Invoke the dolet {2} on the {3}' -f $threadId, "`t", $doletName, $hostObject.HostName))
            $remoteResults = Invoke-Command -Session $remoteSession -ScriptBlock $doletsScriptBlocks.$doletName -ArgumentList $doletsSettings.$doletName, $doletResult, $hostObject
            foreach ($item in $remoteResults) { # Some times result has additional powershell objects
                if ($item.TypeName -eq 'DoletResult') {
                    $remoteResult = $item
                    break
                }
            }
            # $logger.Debug(('[ID={0}]{1}remoteResult = {2}' -f $threadId, "`t", ($remoteResult | ConvertTo-Json)))
            
            # If returned result is not a doletResult object, recreate it
            if (-not (Compare-PSObjectProperties -InputObject $remoteResult -ReferenceObject $doletResult -NoType -NoCount)) {
                $remoteResult = New-DoletResult -DoletSettings $doletsSettings.$doletName
                $remoteResult.Error = '[ID={0}]{1}The dolet {2} on the {3} returned a null result or result in the wrong format' -f $threadId, "`t", $doletName, $hostObject.HostName
            }

            # Log the dolet error
            if (-not $remoteResult.Status) {
                $logger.Error(('[ID={0}]{1}Error while invoke the dolet {2} on the {3}' -f $threadId, "`t", $doletName, $hostObject.HostName))
                $logger.Debug(('[ID={0}]{1}Error in dolet {2}:{3}{4}' -f $threadId, "`t", $doletName, [System.Environment]::NewLine, ($remoteResult.Error | Out-String)))
            }

            # Fill the report
            $logger.Info(('[ID={0}]{1}Add result for dolet {2} on the {3} to the doletReport' -f $threadId, "`t", $doletName, $hostObject.HostName))
            try {
                foreach ($propertyName in $doletsSettings.$doletName.ReportResults.PSObject.Properties.Name) {
                    $newPropertyName = ('[{0}]: {1}' -f $doletName, $propertyName)
                    if ($remoteResult.Status) {
                        $doletReport.$newPropertyName = $remoteResult.ReportResults.$propertyName
                    }
                    else {
                        $doletReport.$newPropertyName = 'Fail'
                    }
                }
                $logger.Debug(('[ID={0}]{1}doletReport = {2}' -f $threadId, "`t", ($doletReport | ConvertTo-Json)))
                # $logger.Debug(('[ID={0}]{1}remoteResult = {2}' -f $threadId, "`t", ($remoteResult | ConvertTo-Json)))                
            }
            catch {
                $logger.Error(('[ID={0}]{1}Error while filling the report for {2} on the {3}' -f $threadId, "`t", $doletName, $hostObject.HostName))
                $logger.Debug(('[ID={0}]{1}Error in dolet {2}:{3}{4}' -f $threadId, "`t", $doletName, [System.Environment]::NewLine, ($remoteResult.Error | Out-String)))
            }
            
            # Export Result to the file
            if ($remoteResult.Status -and $doletsSettings.$doletName.'File.Export') {
                $logger.Info(('[ID={0}]{1}Export result for dolet {2} on the {3} to the file' -f $threadId, "`t", $doletName, $hostObject.HostName))
                $resultDoletPath = "$resultsPath\$doletName"
                if (-not (Test-Path -Path $resultDoletPath -PathType Container -ErrorAction SilentlyContinue)) {
                    $null = New-Item -Path $resultDoletPath -ItemType Container
                }
                
                # Define resultDoletFileName
                if ($doletsSettings.$doletName.'File.Name') {
                    $fileName = $doletsSettings.$doletName.'File.Name'
                }
                else {
                    $fileName = $hostObject.HostName
                }
                $dateToNameHashArguments = @{
                    Name = $fileName
                    Date = $startTime
                    Starts = $doletsSettings.$doletName.'File.Name.Date.Starts'
                    Ends = $doletsSettings.$doletName.'File.Name.Date.Ends'
                    Format = $doletsSettings.$doletName.'File.Name.Date.Fromat'
                    Delimiter = $doletsSettings.$doletName.'File.Name.Date.Delimiter'
                }
                $resultDoletFileName = Add-DateToName @dateToNameHashArguments
                $logger.Debug(('[ID={0}]{1}resultDoletFileName = {2}' -f $threadId, "`t", $resultDoletFileName))
                
                # Export dolet result to a file
                try {
                    switch ($doletsSettings.$doletName.'File.Type') {
                        'txt' {
                            $resultDoletFilePath = ('{0}\{1}.{2}' -f $resultDoletPath, $resultDoletFileName, 'txt')
                            if ($doletsSettings.$doletName.'File.TXT.Append') {
                                Add-Content -Path $resultDoletFilePath -Value $remoteResult.Result -Encoding $doletsSettings.$doletName.'File.Encoding' -NoNewline:$doletsSettings.$doletName.'File.TXT.NoNewline' -Force
                            }
                            else {
                                Set-Content -Path $resultDoletFilePath -Value $remoteResult.Result -Encoding $doletsSettings.$doletName.'File.Encoding' -NoNewline:$doletsSettings.$doletName.'File.TXT.NoNewline' -Force
                            }
                            break
                        }
                        'csv' {
                            $resultDoletFilePath = ('{0}\{1}.{2}' -f $resultDoletPath, $resultDoletFileName, 'csv')
                            $csvHashArguments = @{
                                Path = $resultDoletFilePath
                                Append = $doletsSettings.$doletName.'File.CSV.Append'
                                Delimiter = $doletsSettings.$doletName.'File.CSV.Delimiter'
                                Encoding = $doletsSettings.$doletName.'File.Encoding'
                                Force = $true
                                NoClobber = $doletsSettings.$doletName.'File.CSV.NoClobber'
                                NoTypeInformation = $doletsSettings.$doletName.'File.CSV.NoTypeInformation'
                            }
                            $remoteResult.Result | Export-Csv @csvHashArguments
                            break
                        }
                        'xml' {
                            $resultDoletFilePath = ('{0}\{1}.{2}' -f $resultDoletPath, $resultDoletFileName, 'xml')
                            $xmlHashArguments = @{
                                Path = $resultDoletFilePath
                                Depth = $doletsSettings.$doletName.'File.XML.Depth'
                                Encoding = $doletsSettings.$doletName.'File.Encoding'
                                Force = $true
                                NoClobber = $doletsSettings.$doletName.'File.NoClobber'
                            }
                            $remoteResult.Result | Export-Clixml @xmlHashArguments
                            break
                        }
                        'json' {
                            $resultDoletFilePath = ('{0}\{1}.{2}' -f $resultDoletPath, $resultDoletFileName, 'json')
                            $jsonHashArguments = @{
                                Depth = $doletsSettings.$doletName.'File.JSON.Depth'
                                Compress = $doletsSettings.$doletName.'File.JSON.Compress'
                            }
                            Set-Content -Path $resultDoletFilePath -Value ($remoteResult.Result | ConvertTo-Json @jsonHashArguments) -Encoding $doletsSettings.$doletName.'File.Encoding' -Force
                            break
                        }
                    }
                }
                catch {
                    $logger.Error(('[ID={0}]{1}Error export {2} result to the file {3}' -f $threadId, "`t", $doletName, $resultDoletFilePath))
                    $logger.Debug(('[ID={0}]{1}Error in dolet {2}:{3}{4}' -f $threadId, "`t", $doletName, [System.Environment]::NewLine, ($Error[0] | Out-String)))
                }
            }
        }
    }
    catch {
        $logger.Error(('[ID={0}]{1}{2}' -f $threadId, "`t", ($Error[0] | Out-String)))
    }
    finally
    {
        if($remoteSession)
        {
            $logger.Info(('[ID={0}]{1}Close the remote session with {2}' -f $threadId, "`t", $hostObject.HostName))
            Remove-PSSession $remoteSession
        }    
    }


    $logger.Info(('[ID={0}]{1} Add the report to a CSV report file' -f $threadId, "`t"))
    try {
        Invoke-ActionWithMutex -Name (Get-StringHash -String $reportFilePath) -Prefix Global -ScriptBlock {
            $reportCsvHashArguments = @{
                Path = $reportFilePath
                Append = $true
                Delimiter = $settings.'ReportFile.CSV.Delimiter'
                Encoding = $settings.'ReportFile.CSV.Encoding'
                Force = $true
                NoTypeInformation = $settings.'ReportFile.CSV.NoTypeInformation'
            }
        
            $doletReport | Export-Csv @reportCsvHashArguments       
        }
    }
    catch {
        $logger.Error(('[ID={0}]{1}Error export report result for {2} to the file {3}' -f $threadId, "`t", $hostObject.HostName, $reportFilePath))
        $logger.Debug(('[ID={0}]{1}Error:{2}{3}' -f $threadId, "`t", [System.Environment]::NewLine, ($Error[0] | Out-String)))
    }

    $logger.Info(('[ID={0}]{1}End thread {2}' -f $threadId, "`t", $threadId))
    
    Start-Sleep -Milliseconds $settings.'Threads.Sleep'
}
#endregion MainScriptBlock

Write-Host "`nProcessing hosts."
$startProcessing = Get-Date
#region Threads spawning
# $threadId = 0
$logger.Info('Start threads spawning')
Import-Csv -Path $HostsFilePath -Delimiter $settings.'HostsFile.CSV.Delimiter' -Header $settings.'HostsFile.CSV.Header'.PSObject.Properties.Name |
    Add-HostDefaultData -HostsCsvHeader $settings.'HostsFile.CSV.Header' |
    Invoke-ObjectFilters -Filters $filters -Enable:$settings.EnableFilter |
    Start-RSJob -ScriptBlock $mainScriptBlock -Name {$_.HostName} -Throttle $settings.'Threads.Throttle' | Wait-RSJob -ShowProgress | Remove-RSJob # Comment this row for debugging mainScriptBlock
    # ForEach-Object -Process {Invoke-Command -ScriptBlock $mainScriptBlock} # Uncomment this row for debugging mainScriptBlock
#endregion Threads spawning

Write-Host "`nDone."
Write-Host "Total minutes spent on processing:" $($((Get-Date) - $startProcessing).TotalMinutes)
Start-Sleep -Seconds 1

if ($settings.SessionCleanup) {
    # Cleaning up
    $logger.Info('Cleaning up')
    
    # Get-RSJob | Remove-RSJob
    Set-Variable -Name PoshRS_JobID -Value 0 -Scope Global -Force
    
    # Force to run Garbage Collector
    [System.GC]::Collect()
}

$logger.Info('End DoRemotely')