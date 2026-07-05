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

function New-PasswordHash {
    # Stored form is "salt:sha256(salt+password)". The raw password is never persisted.
    param([Parameter(Mandatory)][string]$Password, [string]$Salt = ([guid]::NewGuid().ToString("N")))
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes("$Salt$Password")
    $hex = (($sha.ComputeHash($bytes)) | ForEach-Object { $_.ToString("x2") }) -join ''
    $sha.Dispose()
    return "$Salt`:$hex"
}

function Test-PasswordHash {
    param([Parameter(Mandatory)][string]$Password, [Parameter(Mandatory)][string]$Stored)
    $parts = $Stored -split ':', 2
    if ($parts.Count -ne 2) { return $false }
    return (New-PasswordHash -Password $Password -Salt $parts[0]) -eq $Stored
}

Export-ModuleMember -Function Get-AgentConfig, Write-AgentLog, Send-WitnessEmail, New-PasswordHash, Test-PasswordHash
