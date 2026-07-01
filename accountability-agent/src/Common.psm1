function Get-AgentConfig {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-Content -Path $Path -Raw | ConvertFrom-Json)
}

function Write-AgentLog {
    param([string]$Message, [string]$LogDir = "C:\ProgramData\AccountabilityAgent")
    $line = "{0} {1}" -f (Get-Date -Format "s"), $Message
    Add-Content -Path (Join-Path $LogDir "agent.log") -Value $line
}

function Send-WitnessEmail {
    param(
        [Parameter(Mandatory)]$Smtp,
        [Parameter(Mandatory)][string]$To,
        [Parameter(Mandatory)][string]$Subject,
        [Parameter(Mandatory)][string]$Body
    )
    $msg = New-Object System.Net.Mail.MailMessage($Smtp.fromAddress, $To, $Subject, $Body)
    $client = New-Object System.Net.Mail.SmtpClient($Smtp.host, [int]$Smtp.port)
    $client.EnableSsl = [bool]$Smtp.useSsl
    $client.Credentials = New-Object System.Net.NetworkCredential($Smtp.username, $Smtp.appPassword)
    $client.Send($msg)
    $msg.Dispose(); $client.Dispose()
}

Export-ModuleMember -Function Get-AgentConfig, Write-AgentLog, Send-WitnessEmail
