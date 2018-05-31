function Get-StringHash
{
    [cmdletbinding()]
    param (
        # Specifies a string from which the hash is calculated
        [Parameter(Mandatory = $true, Position = 0)]
        [String]
        $String,

        # Specifies a hash algorithm. Allowed values: <MD5|RIPEMD160|SHA1|SHA256|SHA384|SHA512>
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