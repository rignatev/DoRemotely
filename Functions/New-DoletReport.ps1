function New-DoletReport {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory =$true, Position = 0)]
        [psobject]
        $HostObject
    )
  
    process {
        $reportObject = $HostObject.PsObject.Copy()
        $reportObject | Add-Member -MemberType NoteProperty -Name 'Ping' -Value '-'
        $reportObject | Add-Member -MemberType NoteProperty -Name 'WSMan' -Value '-'
        $reportObject | Add-Member -MemberType NoteProperty -Name 'PSSession' -Value '-'

        $reportObject
    }
}