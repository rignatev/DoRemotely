function Invoke-ActionWithMutex
{
    [cmdletbinding()]
    param
    (
        # Specifies a name of the mutex object
        [Parameter(Mandatory = $true, Position = 0)]
        [String]
        $Name,

        # Specifies a script block that will be protected from simultaneous access by multiple threads or processes
        [Parameter(Mandatory = $true, Position = 1)]
        [scriptblock]
        $ScriptBlock,

        # Specifies an argumets for the script block
        [Parameter(Mandatory = $false, Position = 2)]
        [Object[]]
        $ArgumentList,

        # Specifies a scpope for mutex. Allowed values: <Local|Global>
        [Parameter(Mandatory = $false, Position = 3)]
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
                    Write-Warning '[{0}]:[{1}]:[PROCESS]: {2}' -f (Get-Date).TimeOfDay, $MyInvocation.MyCommand.Name, $Error[0]
                }
            }
            
            Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
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