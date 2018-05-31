#requires -Version 2.0

$credentialFilePath = Join-Path -Path (Split-Path -Path $MyInvocation.MyCommand.Path -Parent) -ChildPath 'credential.xml'
Export-Clixml -InputObject $(Get-Credential) -Path $credentialFilePath -Encoding UTF8