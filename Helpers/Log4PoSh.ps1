#requires -Version 2.0

<#
        .SYNOPSIS
        Logger for PowerShell.

        .DESCRIPTION
        The modular logger for PowerShell with support of XML file configurations and Appenders.
        Based on the https://gallery.technet.microsoft.com/scriptcenter/Powershell-Logger-5b02b410

        .NOTES
        Version:          1.2
        Author:           Roman Ignatyev
        Email:            rignatev@gmail.com
        Creation Date:    27.10.2017
        Modified Date:    13.05.2018

        Version History:
        1.2 - 13.05.2018
        + Added a method SetFileFolderPath to the New-Log4PoShRollerFileAppender.

        1.1 - 09.03.2018
        + Added a multithreading support to the New-Log4PoShRollerFileAppender. A Mutex has used for writing to a log file.
        * Fixed looping when calling proxy functions in this script.
        * Fixed error when retrieving a main script path if a main script launched from a context menu in explorer or from ScriptBlock.
        * Code optimiztion in New-Log4PoShRollerFileAppender methods.

        1.0 - 27.10.2017
        Initial release

#>

function New-Log4PoShLevels
{
    <#
        .SYNOPSIS
        Levels of logging.

        .DESCRIPTION
        Object with levels for New-Log4PoSh and appenders.

        .EXAMPLE
        Use in code:
            $obj | Add-Member -MemberType ScriptProperty -Name 'Levels' {
                New-Log4PoShLevels
            }
            $obj.Levels.Debug
        This adds a readonly property with a psobject containing the levels of logging.

        .EXAMPLE
            PS > $levels = New-Log4PoShLevels
            PS > $levels.Debug
            0
            PS > $levels.Error
            3
            PS > $levels.GetNameById(2)
            Warn
            PS > $levels.GetNameById(999)
            $null
            PS > $levels.GetNameById($levels.Info)
            1
            PS > ($levels.GetNameById(4)).ToUpper()
            FATAL
            PS > $levels.GetIdByName('Warn')
            2
            PS > $levels.GetIdByName('blabla')
            $null

        .OUTPUTS
        [psobject]
    #>

    Process
    {
        # Declare pseudo Class 'Log4PoShLevels'
        $obj = New-Object -TypeName psobject -Property @{
            ClassName = 'Log4PoShLevels'
        }

        # Readonly Property 'Debug'
        $obj | Add-Member -MemberType ScriptProperty -Name 'Debug' -Value {
            0
        }

        # Readonly Property 'Info'
        $obj | Add-Member -MemberType ScriptProperty -Name 'Info' -Value {
            1
        }

        # Readonly Property 'Warn'
        $obj | Add-Member -MemberType ScriptProperty -Name 'Warn' -Value {
            2
        }

        # Readonly Property 'Error'
        $obj | Add-Member -MemberType ScriptProperty -Name 'Error' -Value {
            3
        }

        # Readonly Property 'Fatal'
        $obj | Add-Member -MemberType ScriptProperty -Name 'Fatal' -Value {
            4
        }

        # Readonly Property 'Off'
        $obj | Add-Member -MemberType ScriptProperty -Name 'Off' -Value {
            5
        }
        
        # Method 'GetNameById'
        $obj | Add-Member -MemberType ScriptMethod -Name 'GetNameById' -Value {
            param
            (
                [Parameter(Mandatory = $true)]
                [int]
                $Id
            )
            
            $result = $null
            $properties = $this | Get-Member -MemberType ScriptProperty | Select-Object -ExpandProperty Name
                
            foreach ($property in $properties)
            {
                if ($this.$property -eq $Id)
                {
                    $result = $property
                    break
                }
            }

            $result
        }

        # Method 'GetIdByName'
        $obj | Add-Member -MemberType ScriptMethod -Name 'GetIdByName' -Value {
            param
            (
                [Parameter(Mandatory = $true)]
                [AllowNull()]
                [AllowEmptyString()]
                [string]
                $Level
            )
            
            $result = $null
            $properties = $this | Get-Member -MemberType ScriptProperty | Select-Object -ExpandProperty Name
                
            if ($Level)
            {
                if ($properties -contains $Level)
                {
                    $result = $this.$Level
                }
            }

            $result
        }

        $obj
    }
}


function New-Log4Posh
{
    <#
        .SYNOPSIS
        Logger for PowerShell.

        .DESCRIPTION
        The modular logger for PowerShell with support XML file configurations and Appenders.

        .PARAMETER Config
        Full path to XML configuration file or string with XML data.

        .EXAMPLE
            PS > $logger = New-Log4Posh -Config 'FullPathToXMLConfigFile' #creates a new Log4PoSh object instance with a configuration from the file 'FullPathToXMLConfigFile'.
            PS > $logger.Warn('This is a warning!') #writes the message to a log with the Warn level.
            PS > $logger.Error('This is an error!') #writes the message to a log with the Error level.

        .NOTES
        Default appender is a RollerFileAppender.
        A new appenders can be added by creating a function with the name 'New-Log4PoshAPPENDERNAME' and a parameter $InputObject.
        The function must return a psobject. The psobject must implemetnt a method 'WriteLog()' with three parameters:
            param (
                [Parameter(Mandatory = $true, Position = 0)]
                [int]
                $Level,

                [Parameter(Mandatory = $true, Position = 1)]
                [string]
                $Message,

                [Parameter(Mandatory = $false, Position = 2)]
                $InputObject = $null
            )
        Also you must add XML data to the configuration file in the format:
            <Appender Type="APPENDERNAME" param1="" param2="" paramX=""/>
        The data from a configuration file will be passed to your function in a XML format. See the function 'New-Log4PoShRollerFileAppender' as an example.

        .INPUTS
        [string]
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $false)]
        [string]
        $Config = $null
    )

    Process
    {
        # Declare pseudo Class 'Log4Posh'
        $obj = New-Object -TypeName psobject -Property @{
            ClassName            = 'Log4Posh'
            Appenders            = $null
            poshDebugIntegration = $null
            currentLogLevel      = $null
            lastLogLevel         = $null
        }
        
        # Readonly Property 'Levels' (Make the property Levels readonly using ScriptProperty 
        $obj | Add-Member -MemberType ScriptProperty -Name 'Levels' -Value {
            New-Log4PoShLevels
        }

        # Method 'Initialize'
        $obj | Add-Member -MemberType ScriptMethod -Name Initialize -Value {
            param (
                [Parameter(Mandatory = $false)]
                [string]
                $Config = $null
            )

            # Set default values
            $this.Appenders = @()
            $this.currentLogLevel = 0
            $this.lastLogLevel = -1
            $this.poshDebugIntegration = $true

            # Load data from config if it exists
            if ($Config)
            {
                $this.loadConfig($Config)
            }
        
            # Add the default appender (RollerFileAppender) if no one exists
            if (-not $this.Appenders.Count)
            {
                $this.Appenders = @(New-Log4PoShRollerFileAppender)
            }

            # Integrate the Log4PoSh into a PowerShell debug system
            $null = $this.SetPoshDebugIntegration($this.poshDebugIntegration)
        }

        # Method 'loadConfig'
        $obj | Add-Member -MemberType ScriptMethod -Name loadConfig -Value {
            param (
                [Parameter(Mandatory = $true)]
                [string]
                $Config
            )

            $xmlObj = $null
            if ((Test-Path -Path $Config -PathType Leaf))
            {
                try 
                {
                    [xml]$xmlObj = Get-Content -Path $Config -Encoding UTF8
                }
                catch
                {
                    $warningParams = @{
                        'Message' = ('[{0}]: The configuration file does not contain XML data. Default settings will be used.' -f $this.ClassName)
                    }
                    if ((Get-Alias -Name 'Write-Warning' -ErrorAction SilentlyContinue))
                    {
                        $warningParams.Add('SkipWriteLog', $true)
                    }
                    Write-Warning @warningParams
                }
            }
            else
            {
                try
                {
                    [xml]$xmlObj = $Config
                }
                catch
                {
                    $warningParams = @{
                        'Message' = ('[{0}]: The provided data is not XML data. Default settings will be used.' -f $this.ClassName)
                    }
                    if ((Get-Alias -Name 'Write-Warning' -ErrorAction SilentlyContinue))
                    {
                        $warningParams.Add('SkipWriteLog', $true)
                    }
                    Write-Warning @warningParams
                }
            }

            if ($xmlObj)
            {
                try
                {
                    $logLevelName = $xmlObj.Log4Posh.Level
                    $logLevelId = $this.Levels.GetIdByName($logLevelName)
                    $null = $this.SetCurrentLevel($logLevelId)
                    $this.poshDebugIntegration = [System.Convert]::ToBoolean($xmlObj.Log4Posh.PoshDebugIntegration)
                    $this.Appenders = @()
                    $appendersNode = $xmlObj.Log4Posh.SelectNodes('Appender')
                    foreach ($appenderNode in $appendersNode)
                    {
                        $appenderType = $appenderNode.Type
                        $appenderInstance = & (Get-ChildItem -Path "Function:New-Log4PoSh$appenderType") -InputObject $appenderNode
                        $this.Appenders += $appenderInstance
                    }
                }
                catch
                {
                    $warningParams = @{
                        'Message' = ('[{0}]: Can not read the configuration, please check the provided XML data. Default settings will be used. Error: {1}' -f $this.ClassName, $_)
                    }
                    if ((Get-Alias -Name 'Write-Warning' -ErrorAction SilentlyContinue))
                    {
                        $warningParams.Add('SkipWriteLog', $true)
                    }
                    Write-Warning @warningParams
                }
            }
        }

        # Method 'callAppenders'
        $obj | Add-Member -MemberType ScriptMethod -Name callAppenders -Value {
            param (
                [Parameter(Mandatory = $true, Position = 0)]
                [int]
                $Level,

                [Parameter(Mandatory = $true, Position = 1)]
                [string]
                $Message,

                [Parameter(Mandatory = $false, Position = 2)]
                $InputObject = $null
            )

            if ($Level -ne $this.Levels.Off)
            {
                if ($Level -ge $this.currentLogLevel)
                {
                    foreach($appender in $this.Appenders)
                    {
                        $appender.WriteLog($Level, $Message, $InputObject)
                    }
                }
            }
        }

        # Method 'Debug'
        $obj | Add-Member -MemberType ScriptMethod -Name Debug -Value {
            param (
                [Parameter(Mandatory = $true, Position = 0)]
                [string]
                $Message,

                [Parameter(Mandatory = $false, Position = 1)]
                $InputObject = $null
            )
        
            $this.callAppenders($this.Levels.Debug, $Message, $InputObject)
        }

        # Method 'Info'
        $obj | Add-Member -MemberType ScriptMethod -Name Info -Value {
            param (
                [Parameter(Mandatory = $true, Position = 0)]
                [string]
                $Message,

                [Parameter(Mandatory = $false, Position = 1)]
                $InputObject = $null
            )
        
            $this.callAppenders($this.Levels.Info, $Message, $InputObject)
        }

        # Method 'Warn'
        $obj | Add-Member -MemberType ScriptMethod -Name Warn -Value {
            param (
                [Parameter(Mandatory = $true, Position = 0)]
                [string]
                $Message,

                [Parameter(Mandatory = $false, Position = 1)]
                $InputObject = $null
            )
        
            $this.callAppenders($this.Levels.Warn, $Message, $InputObject)
        }

        # Method 'Error'
        $obj | Add-Member -MemberType ScriptMethod -Name Error -Value {
            param (
                [Parameter(Mandatory = $true, Position = 0)]
                [string]
                $Message,

                [Parameter(Mandatory = $false, Position = 1)]
                $InputObject = $null
            )
        
            $this.callAppenders($this.Levels.Error, $Message, $InputObject)
        }

        # Method 'Fatal'
        $obj | Add-Member -MemberType ScriptMethod -Name Fatal -Value {
            param (
                [Parameter(Mandatory = $true, Position = 0)]
                [string]
                $Message,

                [Parameter(Mandatory = $false, Position = 1)]
                $InputObject = $null
            )
        
            $this.callAppenders($this.Levels.Fatal, $Message, $InputObject)
        }

        # Method 'SetCurrentLevel'
        $obj | Add-Member -MemberType ScriptMethod -Name SetCurrentLevel -Value {
            param (
                [Parameter(Mandatory = $true)]
                [int]
                $Level
            )

            if ($this.Levels.GetNameById($Level) -ne $null)
            {
                if ($Level -eq $this.Levels.Off)
                {
                    $this.DisableLogging()
                }
                else
                {
                    $this.currentLogLevel = $Level
                    $this.lastLogLevel = -1

                    $true
                }
            }
            else
            {
                $warningParams = @{
                    'Message' = ('[{0}]: Invalid Level data, the current Level has not changed.' -f $this.ClassName)
                }
                if ((Get-Alias -Name 'Write-Warning' -ErrorAction SilentlyContinue))
                {
                    $warningParams.Add('SkipWriteLog', $true)
                }
                Write-Warning @warningParams
                
                $false
            }
        }

        # Method 'GetCurrentLevelId'
        $obj | Add-Member -MemberType ScriptMethod -Name GetCurrentLevelId -Value {
            $this.currentLogLevel 
        }

        # Method 'IsEnabled'
        $obj | Add-Member -MemberType ScriptMethod -Name IsEnabled -Value {
            if ($this.currentLogLevel -ne $this.Levels.Off)
            {
                $true
            }
            else
            {
                $false
            }
        }

        # Method 'GetCurrentLevelName'
        $obj | Add-Member -MemberType ScriptMethod -Name GetCurrentLevelName -Value {
            $this.Levels.GetNameById($this.currentLogLevel)
        }

        # Method 'EnableLogging'
        $obj | Add-Member -MemberType ScriptMethod -Name EnableLogging -Value {
            if (-not $this.IsEnabled())
            {
                if ($this.Levels.GetNameById($this.lastLogLevel) -ne $null)
                {
                    $this.currentLogLevel = $this.lastLogLevel
                }
                $this.lastLogLevel = -1

                $true
            }
            else
            {
                $false
            }
        }

        # Method 'DisableLogging'
        $obj | Add-Member -MemberType ScriptMethod -Name DisableLogging -Value {
            if ($this.IsEnabled())
            {
                $this.lastLogLevel = $this.currentLogLevel
                $this.currentLogLevel = $this.Levels.Off
                
                $true
            }
            else
            {
                $false
            }
            
        }
        
        # Method SetPoshDebugIntegration
        $obj | Add-Member -MemberType ScriptMethod -Name SetPoshDebugIntegration -Value {
            param (
                [Parameter(Mandatory = $false)]
                [bool]
                $Enable = $false
            )
            
            if ($Enable)
            {
                if (-not (Get-Variable -Name 'Log4Posh' -Scope Script -ErrorAction SilentlyContinue))
                {
                    if (-not (Get-Alias -Name 'Write-Debug' -ErrorAction SilentlyContinue))
                    {
                        New-Alias -Name 'Write-Debug' -Value Write-Log4PoShDebug -Scope Script
                    }

                    if (-not (Get-Alias -Name 'Write-Verbose' -ErrorAction SilentlyContinue))
                    {
                        New-Alias -Name 'Write-Verbose' -Value Write-Log4PoShVerbose -Scope Script
                    }

                    if (-not (Get-Alias -Name 'Write-Warning' -ErrorAction SilentlyContinue))
                    {
                        New-Alias -Name 'Write-Warning' -Value Write-Log4PoShWarning -Scope Script
                    }

                    if (-not (Get-Alias -Name 'Write-Error' -ErrorAction SilentlyContinue))
                    {
                        New-Alias -Name 'Write-Error' -Value Write-Log4PoShError -Scope Script
                    }

                    Set-Variable -Name 'Log4Posh' -Value $this -Scope Script
                }
            }
            else
            {
                if ((Get-Variable -Name 'Log4Posh' -Scope Script -ErrorAction SilentlyContinue))
                {
                    if ((Get-Alias -Name 'Write-Debug' -ErrorAction SilentlyContinue))
                    {
                        Remove-Item -Path 'Alias:Write-Debug' -Force -ErrorAction SilentlyContinue
                    }

                    if ((Get-Alias -Name 'Write-Verbose' -ErrorAction SilentlyContinue))
                    {
                        Remove-Item -Path 'Alias:Write-Verbose' -Force -ErrorAction SilentlyContinue
                    }

                    if ((Get-Alias -Name 'Write-Warning' -ErrorAction SilentlyContinue))
                    {
                        Remove-Item -Path 'Alias:Write-Warning' -Force -ErrorAction SilentlyContinue
                    }

                    if ((Get-Alias -Name 'Write-Error' -ErrorAction SilentlyContinue))
                    {
                        Remove-Item -Path 'Alias:Write-Error' -Force -ErrorAction SilentlyContinue
                    }

                    Remove-Variable -Name 'Log4Posh' -Scope Script
                }
            }

            $this.poshDebugIntegration = $Enable
        }

        # Method 'Finalize'
        $obj | Add-Member -MemberType ScriptMethod -Name Finalize -Value {
            # Remove integration the Log4PoSh from a PowerShell debug system
            $null = $this.SetPoshDebugIntegration($false)

            $this = $null
        }
        
        $obj.Initialize($Config)
           
        $obj
    }
}


#region Helper Functions
function Invoke-ActionWithMutex
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [String]
        $Name,

        [Parameter(Mandatory = $true, Position = 1)]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateSet('Local', 'Global')]
        [String]
        $Prefix = 'Local'
    )
    
    process
    {
        $mutex = $null
        try
        {
            $mutexWasCreated = $false
            $mutex = New-Object -TypeName System.Threading.Mutex -ArgumentList ($true, ('{0}\{1}' -f $Prefix, $Name), [ref]$mutexWasCreated)
        
            if (-not $mutexWasCreated)
            {
                try
                {
                    $null = $mutex.WaitOne()
                }
                catch [System.Threading.AbandonedMutexException]
                {
                    $warningParams = @{
                        'Message' = ('[{0}]:[{1}]:[PROCESS]: {2}'  -f (Get-Date).TimeOfDay, $MyInvocation.MyCommand.Name, $_)
                    }
                    if ((Get-Alias -Name 'Write-Warning' -ErrorAction SilentlyContinue))
                    {
                        $warningParams.Add('SkipWriteLog', $true)
                    }
                    Write-Warning @warningParams
                }
            }
            
            Invoke-Command -ScriptBlock $ScriptBlock
        }
        finally
        {
            if ($mutex -ne $null)
            {
                $mutex.ReleaseMutex()
                $mutex.Dispose()
            }
        }
    }
}

function Get-StringHash
{
    <#
        .SYNOPSIS
        Describe purpose of "Get-StringHash" in 1-2 sentences.

        .DESCRIPTION
        Add a more complete description of what the function does.

        .PARAMETER String
        Describe parameter -String.

        .PARAMETER HashName
        Describe parameter -HashName.

        .EXAMPLE
        Get-StringHash -String Value -HashName Value
        Describe what this call does

        .NOTES
        Place additional notes here.

        .LINK
        URLs to related sites
        The first link is opened by Get-Help -Online Get-StringHash

        .INPUTS
        List of input types that are accepted by this function.

        .OUTPUTS
        List of output types produced by this function.
    #>


    [cmdletbinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String]
        $String,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet('MD5', 'RIPEMD160', 'SHA1', 'SHA256', 'SHA384', 'SHA512')]
        [String]
        $HashName = 'MD5'
    )

    process
    {
        $StringBuilder = New-Object -TypeName System.Text.StringBuilder
        [System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String)) |
        ForEach-Object -Process {
            $null = $StringBuilder.Append($_.ToString('x2'))
        }

        $StringBuilder.ToString()
    }
}
#endregion Helper Functions


#region Appenders
function New-Log4PoShRollerFileAppender
{
    <#
        .SYNOPSIS
        RollerFileAppender for Log4Posh.

        .DESCRIPTION
        Writes logs to a file.

        .PARAMETER InputObject
        XML node in format:
        <!--
            Appender 'RollerFileAppender'
            Type="RollerFileAppender" - identifies RollerFileAppender configuration node.
            FileFolderPath="" - the path to a folder where a log file will be created. If empty - a folder of a main script will be used.
            FileBaseName="base_name" - the base name for a log file. If empty - a base name of a main script will be used.
            FileExtension=".txt" - the extension for a log file. If empty - a '.log' extension will be used.
            BackupFolderPath="" - the path to a folder where a backup log files will be stored. If empty - a folder of a main script will be used.
            MaxFileSize="10Mb" - the maximum size that the output file is allowed to reach before being rolled over to backup files. If empty - the log backup will be never used.
            MaxFilesCount="" - the maximum number of backup files that are kept before the oldest is erased. If empty or 0 - the log backup will never be erased.
            ThreadingSupport="[True|False]" - enables/disables multitreading support with concurency access to a log file. True - threads will waiting for releasing a log file. Turning on this parameter may slow down your script working.
        -->
        <Appender Type="RollerFileAppender" FileFolderPath="" FileBaseName="example3_log1" FileExtension=".log" BackupFolderPath="" MaxFileSize="" MaxFilesCount="" ThreadingSupport="False">
            <!--
                Layout 'PatternLayout'
                Type="PatternLayout" - identifies PatternLayout configuration node.
                Pattern="%d %t [%lvl]: %log_data" - the layout of a string for a inputed message, where %d=date %t=time %lvl=level %log_data=message to log.
                DataFormat="dd/MM/yyyy" - the date formatter. Uses .NET standard.
                TimeFormat="HH:mm:ss" - the time formatter. Uses .NET standard.
                ExpandString="[True|False]" - allows to process special characters like `t,`n. False - do not process string, True - process string.

                Custom Date and Time Format Strings:
                https://docs.microsoft.com/en-us/dotnet/standard/base-types/custom-date-and-time-format-strings#escape
                Use '\' for escape custom format specifiers ('/' is one of them), for example DataFormat="dd\/MM\/yyyy"
            -->
            <Layout Type="PatternLayout" Pattern="%d %t [%lvl]: %log_data" DataFormat="dd\/MM\/yyyy" TimeFormat="HH:mm:ss" ExpandString="False"/>
            <!--
                Filter 'Filter'
                Type="Filter" - identifies Filter configuration node.
                AllowedLevels="" - this is an array of allowed for logging levels, comma separated. Example: AllowedLevels="Info,Error". If the value is empty, then the level is inherited from the Log4PoSh node.
                IncludeText="" - logs only messages they contains the IncludeText value. If the value is empty, then logs all messages.
                ExcludeText="" - logs only messages they doesn't contain the ExcludeText value. If is empty then logs all messages.
                First the IncludeText applies, after that the ExcludeText applies.
            -->
            <Filter Type="Filter" AllowedLevels="" IncludeText="" ExcludeText=""/>
        </Appender>
        
        .NOTES
        This function is called by the function New-Log4Posh.

        .INPUTS
        [object]
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $false)]
        $InputObject = $null
    )

    Begin
    {
        #$scriptFilePath = $Script:MyInvocation.InvocationName
        $scriptFilePath = $Script:MyInvocation.MyCommand.Path
        if ($scriptFilePath)
        {
            $scriptFolder = [IO.Path]::GetDirectoryName($scriptFilePath)
            $scriptFileBaseName = [IO.Path]::GetFileNameWithoutExtension($scriptFilePath)
        }
        else
        {
            $scriptFolder = Get-Location
            $scriptFileBaseName = 'Log4PoSh'
            $warningParams = @{
                'Message' = ('[{0}]: Cannot get the script path. Using a path {1} and a name {2} as a default values for a log file.' -f $this.ClassName, $scriptFolder, $scriptFileBaseName)
            }
            if ((Get-Alias -Name 'Write-Warning' -ErrorAction SilentlyContinue))
            {
                $warningParams.Add('SkipWriteLog', $true)
            }
            Write-Warning @warningParams
            
        }
        $logFileExtension = '.log'
        $logFileName = $scriptFileBaseName + $logFileExtension
        $logFilePath = Join-Path -Path $scriptFolder -ChildPath $logFileName
    }

    Process
    {
        # Declare pseudo Class 'RollerFileAppender'
        $obj = New-Object -TypeName psobject -Property @{
            ClassName          = 'RollerFileAppender'
            ThreadingSupport = $true
            FileFolderPath   = $scriptFolder
            BackupFolderPath = $scriptFolder
            FileBaseName     = $scriptFileBaseName
            FileExtension    = $logFileExtension
            FileName         = $logFileName
            FilePath         = $logFilePath
            MaxFileSize      = 10Mb
            MaxFilesCount    = 10
            Layout           = $null
            Filter           = $null
        }    

        # Property 'LogFilesCount'
        $obj | Add-Member -MemberType ScriptProperty -Name LogFilesCount -Value {
            $logFilesCount = 1
            $logFiles = $this.GetLogFiles()
            
            if ($logFiles)
            {
                $logFilesCount += $logFiles.Count
            }

            $logFilesCount
        }

        # Property 'CurrentFileSize'
        $obj | Add-Member -MemberType ScriptProperty -Name CurrentFileSize -Value {
            $currentFileSize = 0

            if ((Test-Path -Path $this.FilePath -PathType Leaf))
            {
                $currentFileSize = (Get-Item -Path $this.FilePath).Length
            }

            $currentFileSize
        }

        # Method 'SetFileFolderPath'
        $obj | Add-Member -MemberType ScriptMethod -Name SetFileFolderPath -Value {
            Param
            (
                [Parameter(Mandatory = $true, Position = 0)]
                [string]
                $Path
            )

            $this.FileFolderPath = $Path
            $this.BackupFolderPath = $Path
            $this.FileName = $this.FileBaseName + $this.FileExtension
            $this.FilePath = Join-Path -Path $this.FileFolderPath -ChildPath $this.FileName  
        }
        
        # Method 'SetPatternLayout'
        $obj | Add-Member -MemberType ScriptMethod -Name SetPatternLayout -Value {
            Param
            (
                [Parameter(Mandatory = $false, Position = 0)]
                $InputObject = $null
            )
            
            # Declare pseudo Class 'PatternLayout'
            $patternObj = New-Object -TypeName psobject -Property @{
                ClassName    = 'PatternLayout'
                Pattern      = '%d %t [%lvl] %log_data'
                DataFormat   = 'dd/MM/yyyy'
                TimeFormat   = 'HH:mm:ss'
                ExpandString = $true
            }
            
            # Method 'FormatData'
            $patternObj | Add-Member -MemberType ScriptMethod -Name FormatData -Value {
                param (
                    [Parameter(Mandatory = $true, Position = 0)]
                    [string]
                    $LevelTypeName,

                    [Parameter(Mandatory = $true, Position = 1)]
                    [string]
                    $Message
                )

                $dateString = Get-Date -Format $this.DataFormat
                $timeString = Get-Date -Format $this.TimeFormat
                $formatedData = $this.Pattern.Replace('%d', $dateString)
                $formatedData = $formatedData.Replace('%t', $timeString)
                $formatedData = $formatedData.Replace('%lvl', $LevelTypeName)
                $formatedData = $formatedData.Replace('%log_data', $Message)

                if ($this.ExpandString)
                {
                    # ExpandString allows to process special characters like `t,`n
                    $ExecutionContext.InvokeCommand.ExpandString($formatedData)
                }
                else
                {
                    $formatedData
                }
            }

            try
            {
                # Loading the PatternLayout from the config
                if ($InputObject)
                {
                    if ($InputObject.Type -eq $patternObj.ClassName)
                    {
                        if ($InputObject.Pattern)
                        {
                            $patternObj.Pattern = $InputObject.Pattern
                        }

                        if ($InputObject.DataFormat)
                        {
                            $patternObj.DataFormat = $InputObject.DataFormat
                        }

                        if ($InputObject.TimeFormat)
                        {
                            $patternObj.TimeFormat = $InputObject.TimeFormat
                        }

                        if ($InputObject.ExpandString)
                        {
                            try
                            {
                                $patternObj.ExpandString = [System.Convert]::ToBoolean($InputObject.ExpandString)
                            }
                            catch
                            {
                                $warningParams = @{
                                    'Message' = ('[{0}]: Cannot read the parameter ExpandString from the configuration. Default value will be used.' -f $this.ClassName)
                                }
                                if ((Get-Alias -Name 'Write-Warning' -ErrorAction SilentlyContinue))
                                {
                                    $warningParams.Add('SkipWriteLog', $true)
                                }
                                Write-Warning @warningParams
                            }
                        }
                    }
                }
            }
            catch
            {
                $warningParams = @{
                    'Message' = ('[{0}]: Cannot read the PatternLayout from the configuration. Default value will be used.' -f $this.ClassName)
                }
                if ((Get-Alias -Name 'Write-Warning' -ErrorAction SilentlyContinue))
                {
                    $warningParams.Add('SkipWriteLog', $true)
                }
                Write-Warning @warningParams
            }
            
            $this.Layout = $patternObj
        }
        
        # Method 'SetFilter'
        $obj | Add-Member -MemberType ScriptMethod -Name SetFilter -Value {
            Param
            (
                [Parameter(Mandatory = $false, Position = 0)]
                $InputObject = $null
            )
            
            # Declare pseudo Class 'Filter'
            $filterObj = New-Object -TypeName psobject -Property @{
                ClassName     = 'Filter'
                AllowedLevels = $null
                IncludeText   = $null
                ExcludeText   = $null
            }

            try
            {
                # Loading the Filter from the config
                if ($InputObject)
                {
                    if ($InputObject.Type -eq $filterObj.ClassName)
                    {
                        if ($InputObject.AllowedLevels)
                        {
                            $filterObj.AllowedLevels = $InputObject.AllowedLevels -split ','
                            $levels = New-Log4PoShLevels
                            foreach ($level in $filterObj.AllowedLevels)
                            {
                                if ($levels.GetIdByName($level) -eq $null)
                                {
                                    throw
                                }
                            }
                        }

                        if ($InputObject.IncludeText)
                        {
                            $filterObj.IncludeText = $InputObject.IncludeText
                        }

                        if ($InputObject.ExcludeText)
                        {
                            $filterObj.ExcludeText = $InputObject.ExcludeText
                        }
                    }
                }
            }
            catch
            {
                $warningParams = @{
                    'Message' = ('[{0}]: Cannot read the Filter from the configuration. Default value will be used.' -f $this.ClassName)
                }
                if ((Get-Alias -Name 'Write-Warning' -ErrorAction SilentlyContinue))
                {
                    $warningParams.Add('SkipWriteLog', $true)
                }
                Write-Warning @warningParams
                $filterObj.AllowedLevels = $null
                $filterObj.IncludeText = $null
                $filterObj.ExcludeText = $null
            }
            
            $this.Filter = $filterObj
        }

        # Method 'GetLogFiles'
        $obj | Add-Member -MemberType ScriptMethod -Name GetLogFiles -Value {
            $logFiles = $null

            if ((Test-Path -Path $this.BackupFolderPath -PathType Container))
            {
                $searchFileName = $this.FileBaseName + '_'
                $searchFilterPattern = $searchFileName + '*' + $this.FileExtension
                $searchRegexPattern = ('^{0}\d+$' -f $searchFileName)  # A Pattern for searching for a specific file name with numbers at the end
                # Gets all files matching 'FileName_*.log' and selects only those whose number less than or equal the MaxFilesCount
                $logFiles = Get-ChildItem -Path $this.BackupFolderPath -Filter $searchFilterPattern | Where-Object -FilterScript {
                    ($_.BaseName -match $searchRegexPattern) -and ([int]($_.BaseName -replace $searchFileName) -le $this.MaxFilesCount)
                }
            }
        
            $logFiles
        }

        # Method 'RollLogFiles'
        $obj | Add-Member -MemberType ScriptMethod -Name RollLogFiles -Value {
            $logFilesCount = 0
            $searchFileName = $this.FileBaseName + '_'
            $logFiles = $this.GetLogFiles() | Sort-Object -Property {
                [int]($_.BaseName -replace $searchFileName)
            } -Descending
            

            if ($logFiles)
            {
                # Without this in PowerShell v2.0 $logFiles with 1 element was not an array
                if ($logFiles -isnot [array])
                {
                    $logFiles = @($logFiles)
                }
                
                $logFilesCount = $logFiles.Count
            }

            if ($logFilesCount)
            {
                # Roll files
                $newLogFileNumber = $logFilesCount + 1
                foreach ($logFile in $logFiles)
                {
                    if ($this.MaxFilesCount)
                    {
                        # Skip the most old log file, it will be overwritten
                        if ($newLogFileNumber -gt $this.MaxFilesCount)
                        {
                            $newLogFileNumber--
                            continue
                        }
                    }

                    $newLogFileName = $this.FileBaseName + '_' + $newLogFileNumber + $this.FileExtension
                    $newLogFileDestination = Join-Path -Path $this.BackupFolderPath -ChildPath $newLogFileName
                    $logFilePath = Join-Path -Path $this.BackupFolderPath -ChildPath $logFile.Name
                    Move-Item -Path $logFilePath -Destination $newLogFileDestination -Force
                    $newLogFileNumber--
                }
            }

            # Move master log file
            if ((Test-Path -Path $this.FilePath -PathType Leaf))
            {
                $newLogFileName = $this.FileBaseName + '_1' + $this.FileExtension
                $newLogFileDestination = Join-Path -Path $this.BackupFolderPath -ChildPath $newLogFileName
                Move-Item -Path $this.FilePath -Destination $newLogFileDestination -Force
            }
        }
        
        # Method 'WriteLog'
        $obj | Add-Member -MemberType ScriptMethod -Name WriteLog -Value {
            param (
                [Parameter(Mandatory = $true, Position = 0)]
                [int]
                $Level,

                [Parameter(Mandatory = $true, Position = 1)]
                [string]
                $Message,

                [Parameter(Mandatory = $false, Position = 2)]
                $InputObject = $null
            )

            $levels = New-Log4PoShLevels
            $LevelTypeName = $levels.GetNameById($Level)
            
            $logThisMessage = $true
            # ($this.Filter.AllowedLevels -eq $null) - allows all levels
            if ($this.Filter.AllowedLevels -ne $null)
            {
                if (-not ($this.Filter.AllowedLevels -contains $LevelTypeName))
                {
                    $logThisMessage = $false
                }
            }

            if ($this.Filter.IncludeText)
            {
                if (-not $Message.Contains($this.Filter.IncludeText))
                {
                    $logThisMessage = $false
                }
            }
                
            if ($this.Filter.ExcludeText)
            {
                if ($Message.Contains($this.Filter.ExcludeText))
                {
                    $logThisMessage = $false
                }
            }
                
            if ($logThisMessage)
            {
                if ($InputObject)
                {
                    if ($InputObject.Exception)
                    {
                        $Message += ' Exception: ' + $InputObject.Exception.Message
                    }
                }
                
                $dataToLog = $this.Layout.FormatData($LevelTypeName.ToUpper(), $Message)

                if ($this.MaxFileSize)
                {
                    $currentFileSize = $this.CurrentFileSize
                    if ($currentFileSize -and (($currentFileSize + $dataToLog.Length) -ge $this.MaxFileSize))
                    {
                        $this.RollLogFiles()
                    }
                }

                $addDataToLog = {
                    try
                    {
                        Add-Content -Path $this.FilePath -Value $dataToLog -Force -Encoding UTF8
                    }
                    catch
                    {
                        $warningParams = @{
                            'Message' = ('[{0}]: Cannot append a message to the log file.' -f $this.ClassName)
                        }
                        if ((Get-Alias -Name 'Write-Warning' -ErrorAction SilentlyContinue))
                        {
                            $warningParams.Add('SkipWriteLog', $true)
                        }
                        Write-Warning @warningParams
                    }
                    #Start-Sleep -Seconds 5
                }

                if ($this.ThreadingSupport)
                {
                    
                    Invoke-ActionWithMutex -Name (Get-StringHash -String $this.FilePath) -ScriptBlock $addDataToLog -Prefix Global
                }
                else
                {
                    Invoke-Command -ScriptBlock $addDataToLog
                }
            }
        }

        try
        {
            # Loading the RollerFileAppender from the config
            if ($InputObject)
            {
                if ($InputObject.Type -eq $obj.ClassName)
                {


                    if ($InputObject.FileFolderPath)
                    {
                        $obj.FileFolderPath = $InputObject.FileFolderPath
                    }

                    if ($InputObject.BackupFolderPath)
                    {
                        $obj.BackupFolderPath = $InputObject.BackupFolderPath
                    }

                    if ($InputObject.FileBaseName)
                    {
                        $obj.FileBaseName = $InputObject.FileBaseName
                    }

                    if ($InputObject.FileExtension)
                    {
                        $obj.FileExtension = $InputObject.FileExtension
                    }

                    if ($InputObject.MaxFileSize)
                    {
                        # [scriptblock]::Create('10Gb').Invoke()[0] - Allows convert from shortcuts Kb, Mb and etc. to integer bytes
                        $obj.MaxFileSize = [scriptblock]::Create($InputObject.MaxFileSize).Invoke()[0]
                    }

                    if ($InputObject.MaxFilesCount)
                    {
                        $obj.MaxFilesCount = [int]$InputObject.MaxFilesCount
                    }

                    if ($InputObject.ThreadingSupport)
                    {
                        try
                        {
                            $obj.ThreadingSupport = [System.Convert]::ToBoolean($InputObject.ThreadingSupport)
                        }
                        catch
                        {
                            $warningParams = @{
                                'Message' = ('[{0}]: Cannot read the parameter ThreadingSupport from the configuration. Default value will be used.' -f $this.ClassName)
                            }
                            if ((Get-Alias -Name 'Write-Warning' -ErrorAction SilentlyContinue))
                            {
                                $warningParams.Add('SkipWriteLog', $true)
                            }
                            Write-Warning @warningParams
                        }
                    }

                    $obj.FileName = $obj.FileBaseName + $obj.FileExtension
                    $obj.FilePath = Join-Path -Path $obj.FileFolderPath -ChildPath $obj.FileName
                    $obj.SetPatternLayout($InputObject.SelectSingleNode('Layout'))
                    $obj.SetFilter($InputObject.SelectSingleNode('Filter'))
                }
            }
        }
        catch
        {
            $warningParams = @{
                'Message' = ('[{0}]: Cannot read the RollerFileAppender from the configuration. Default value will be used.' -f $this.ClassName)
            }
            if ((Get-Alias -Name 'Write-Warning' -ErrorAction SilentlyContinue))
            {
                $warningParams.Add('SkipWriteLog', $true)
            }
            Write-Warning @warningParams
        }
        
        if (-not $obj.Layout)
        {
            $obj.SetPatternLayout()
        }

        if (-not $obj.Filter)
        {
            $obj.SetFilter()
        }

        $obj
    }
}
#endregion Appenders


#region Proxy Functions
function Write-Log4PoShDebug
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [Alias('Msg')]
        [AllowEmptyString()]
        [string]
        ${Message},

        [Parameter(Mandatory=$false)]
        [switch]
        $SkipWriteLog
    )

    begin
    {
        try {
            $null = $PSBoundParameters.Remove('SkipWriteLog')
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
            {
                $PSBoundParameters['OutBuffer'] = 1
            }
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Write-Debug', [System.Management.Automation.CommandTypes]::Cmdlet)
            $scriptCmd = {& $wrappedCmd @PSBoundParameters }
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        } catch {
            throw
        }
    }

    process
    {
        try {
            if (-not $SkipWriteLog)
            {
                $log4PoShObj = Get-Variable -Name 'Log4Posh' -ValueOnly -Scope Script
                $log4PoShObj.Debug($Message)
            }
            $steppablePipeline.Process($_)
        } catch {
            throw
        }
    }

    end
    {
        try {
            $steppablePipeline.End()
        } catch {
            throw
        }
    }
    <#

    .ForwardHelpTargetName Microsoft.PowerShell.Utility\Write-Debug
    .ForwardHelpCategory Cmdlet

    #>
}


function Write-Log4PoShVerbose
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [Alias('Msg')]
        [AllowEmptyString()]
        [string]
        ${Message},

        [Parameter(Mandatory=$false)]
        [switch]
        $SkipWriteLog
    )

    begin
    {
        try {
            $null = $PSBoundParameters.Remove('SkipWriteLog')
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
            {
                $PSBoundParameters['OutBuffer'] = 1
            }
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Write-Verbose', [System.Management.Automation.CommandTypes]::Cmdlet)
            $scriptCmd = {& $wrappedCmd @PSBoundParameters }
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        } catch {
            throw
        }
    }

    process
    {
        try {
            if (-not $SkipWriteLog)
            {
                $log4PoShObj = Get-Variable -Name 'Log4Posh' -ValueOnly -Scope Script
                $log4PoShObj.Info($Message)
            }
            $steppablePipeline.Process($_)
        } catch {
            throw
        }
    }

    end
    {
        try {
            $steppablePipeline.End()
        } catch {
            throw
        }
    }
    <#

    .ForwardHelpTargetName Microsoft.PowerShell.Utility\Write-Verbose
    .ForwardHelpCategory Cmdlet

    #>
}


function Write-Log4PoShWarning
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [Alias('Msg')]
        [AllowEmptyString()]
        [string]
        ${Message},

        [Parameter(Mandatory=$false)]
        [switch]
        $SkipWriteLog
    )

    begin
    {
        try {
            $null = $PSBoundParameters.Remove('SkipWriteLog')
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
            {
                $PSBoundParameters['OutBuffer'] = 1
            }
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Write-Warning', [System.Management.Automation.CommandTypes]::Cmdlet)
            $scriptCmd = {& $wrappedCmd @PSBoundParameters }
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        } catch {
            throw
        }
    }

    process
    {
        try {
            if (-not $SkipWriteLog)
            {
                $log4PoShObj = Get-Variable -Name 'Log4Posh' -ValueOnly -Scope Script
                $log4PoShObj.Warn($Message)
            }
            $steppablePipeline.Process($_)
        } catch {
            throw
        }
    }

    end
    {
        try {
            $steppablePipeline.End()
        } catch {
            throw
        }
    }
    <#

    .ForwardHelpTargetName Microsoft.PowerShell.Utility\Write-Warning
    .ForwardHelpCategory Cmdlet

    #>
}


function Write-Log4PoShError
{
    [CmdletBinding(DefaultParameterSetName='NoException')]
    param(
        [Parameter(ParameterSetName='WithException', Mandatory=$true)]
        [System.Exception]
        ${Exception},

        [Parameter(ParameterSetName='WithException')]
        [Parameter(ParameterSetName='NoException', Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [Alias('Msg')]
        [AllowNull()]
        [AllowEmptyString()]
        [string]
        ${Message},

        [Parameter(ParameterSetName='ErrorRecord', Mandatory=$true)]
        [System.Management.Automation.ErrorRecord]
        ${ErrorRecord},

        [Parameter(ParameterSetName='WithException')]
        [Parameter(ParameterSetName='NoException')]
        [System.Management.Automation.ErrorCategory]
        ${Category},

        [Parameter(ParameterSetName='WithException')]
        [Parameter(ParameterSetName='NoException')]
        [string]
        ${ErrorId},

        [Parameter(ParameterSetName='NoException')]
        [Parameter(ParameterSetName='WithException')]
        [System.Object]
        ${TargetObject},

        [string]
        ${RecommendedAction},

        [Alias('Activity')]
        [string]
        ${CategoryActivity},

        [Alias('Reason')]
        [string]
        ${CategoryReason},

        [Alias('TargetName')]
        [string]
        ${CategoryTargetName},

        [Alias('TargetType')]
        [string]
        ${CategoryTargetType},

        [Parameter(Mandatory=$false)]
        [switch]
        $SkipWriteLog
    )

    begin
    {
        try {
            $null = $PSBoundParameters.Remove('SkipWriteLog')
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
            {
                $PSBoundParameters['OutBuffer'] = 1
            }
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Write-Error', [System.Management.Automation.CommandTypes]::Cmdlet)
            $scriptCmd = {& $wrappedCmd @PSBoundParameters }
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        } catch {
            throw
        }
    }

    process
    {
        try {
            if (-not $SkipWriteLog)
            {
                $log4PoShObj = Get-Variable -Name 'Log4Posh' -ValueOnly -Scope Script
                $object = New-Object -TypeName psobject -Property @{
                    Exception = $Exception
                }
                $log4PoShObj.Error($Message, $object)
            }
            $steppablePipeline.Process($_)
        } catch {
            throw
        }
    }

    end
    {
        try {
            $steppablePipeline.End()
        } catch {
            throw
        }
    }
    <#

    .ForwardHelpTargetName Microsoft.PowerShell.Utility\Write-Error
    .ForwardHelpCategory Cmdlet

    #>
}
#endregion Proxy Functions

#Export-ModuleMember -Alias * -Function *

# SIG # Begin signature block
# MIIEIwYJKoZIhvcNAQcCoIIEFDCCBBACAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUMSkH57241pe/9gytOk1qhBAO
# PtKgggIrMIICJzCCAZCgAwIBAgIQSzflm3z/vKRKwh32UPWSxjANBgkqhkiG9w0B
# AQUFADAuMSwwKgYDVQQDDCNSb21hbiBJZ25hdHlldiAocmlnbmF0ZXZAZ21haWwu
# Y29tKTAeFw0xNzA2MzAwNTI1NTNaFw0yMTA2MzAwMDAwMDBaMC4xLDAqBgNVBAMM
# I1JvbWFuIElnbmF0eWV2IChyaWduYXRldkBnbWFpbC5jb20pMIGfMA0GCSqGSIb3
# DQEBAQUAA4GNADCBiQKBgQCw0bH8l/sD4qmImVGEElTP+Nt2Zc+yHZX8uJTC5zD+
# Qb4wMqRMzip9/Rl4Bgxle2viGVoTMXhpxrOdaJotffb4g+KSG8jNQpv38tmrolB1
# wWOtP2r4Zi+H/BCtmSs+Cb2RsZPnRryDDpcw0z+v0Ad+8Osy5B4pMbNK982w1qCI
# RQIDAQABo0YwRDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUqIwamc4j
# wLPY+coFgbRSykPQjOgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBBQUAA4GB
# AGwY2k28oP5CU9yhjKWfXvHGXBxYRfhYHCO4H0+QMTqmW7GNGf71Hp/dJTJAaDu/
# OrrEye9wLIR7kv8Bsy9yqO0DZtsYzKlJgQa+smtjxbnF5p9gtMRkqJy5zpuEqyXw
# 6fRZHUp/8wtFCNq6J0p4EDAhFx/t6igZPN66LtbstOOlMYIBYjCCAV4CAQEwQjAu
# MSwwKgYDVQQDDCNSb21hbiBJZ25hdHlldiAocmlnbmF0ZXZAZ21haWwuY29tKQIQ
# Szflm3z/vKRKwh32UPWSxjAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUJUQX7gtc/IdCAhg2kVjO
# xjjAgdMwDQYJKoZIhvcNAQEBBQAEgYCfO3IPRwSTdzqi/6HsnpjFi2+JLFCxzLaG
# UR3Qfnohslvcs+kZWFcTbr+SBBbhB0FclcIJuNNDy4NATqt4PPmVONfsgzi6KUEa
# eCFAaOWHgzETPw1+HU4b2GjGPM7h7xQ1GZ/ldn1xusJdo6PgyFHsP5XWoND8ye4H
# oxfRoMa+Uw==
# SIG # End signature block
