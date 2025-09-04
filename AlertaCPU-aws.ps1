# Carregar DLLs MimeKit e MailKit
[Reflection.Assembly]::LoadFrom("C:\alertas\libs\MimeKit.dll") | Out-Null
[Reflection.Assembly]::LoadFrom("C:\alertas\libs\MailKit.dll") | Out-Null

# Config SMTP do Secrets Manager
Import-Module AWSPowerShell

$secretName = "alerta-smtp-credentials"   # Nome do segredo no AWS Secrets Manager
$region     = "us-east-1"                 # Região da AWS

# Recupera segredo
$secret     = Get-SECSecretValue -SecretId $secretName -Region $region
$secretObj  = $secret.SecretString | ConvertFrom-Json

$smtpServer   = $secretObj.'smtp-server'
$smtpPort     = [int]$secretObj.'smtp-port'
$smtpUsername = $secretObj.'smtp-username'
$smtpPassword = $secretObj.'smtp-password'
$from         = $smtpUsername

# Info VM
$vmName  = $env:COMPUTERNAME
$iplocal = (Get-NetIPAddress -AddressFamily IPv4 `
    | Where-Object { $_.InterfaceAlias -notmatch "Loopback" -and $_.IPAddress -notlike "169.*" -and $_.PrefixOrigin -ne "WellKnown" } `
    | Sort-Object InterfaceIndex `
    | Select-Object -First 1).IPAddress
$ipvalido = Invoke-RestMethod -Uri "https://api.ipify.org"

# Destinatários
$toList = @(
    "email1@serveremail.com",
    "email2@serveremail.com",
    "email3@serveremail.com",
    "email4@serveremail.com"
)

$subject = "🚨 Alerta: CPU acima de 90% - $vmName"

# Coleta de uso de CPU por 5 minutos (20 segundos de intervalo)
$cpuUsageSamples = @()
$iterations = 15   # 5 minutos / 20 segundos = 15 coletas

for ($i = 1; $i -le $iterations; $i++) {
    $cpu = Get-Counter '\Processor(_Total)\% Processor Time'
    $cpuUsage = [math]::Round($cpu.CounterSamples.CookedValue, 2)
    $cpuUsageSamples += $cpuUsage
    Write-Host "Coleta ${i}: Uso de CPU = $cpuUsage%"
    Start-Sleep -Seconds 20
}

$averageCpuUsage = [math]::Round(($cpuUsageSamples | Measure-Object -Average).Average, 2)
Write-Host "Média de uso de CPU nos últimos 5 minutos: $averageCpuUsage%"

if ($averageCpuUsage -ge 90) {
    $bodyHtml = @"
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        table { border-collapse: collapse; width: 100%; }
        td, th { border: 1px solid #ddd; padding: 8px; }
    </style>
</head>
<body>
    <h2 style='color:red;'>🚨 <strong>Alerta de uso de CPU</strong> 🚨</h2>
    <p><b>Servidor:</b> $vmName<br/>
       <b>IP Local:</b> $iplocal<br/>
       <b>IP Público:</b> $ipvalido<br/>
       <b>Data:</b> $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')</p>
    <h3>Média de uso de CPU nos últimos 5 minutos:</h3>
    <table>
        <tr><th>Uso Médio (%)</th></tr>
        <tr><td>$averageCpuUsage%</td></tr>
    </table>
</body>
</html>
"@

    $message = New-Object MimeKit.MimeMessage
    $message.From.Add($from)
    foreach ($to in $toList) { $message.To.Add($to) }
    $message.Subject = $subject
    $bodyBuilder = New-Object MimeKit.BodyBuilder
    $bodyBuilder.HtmlBody = $bodyHtml
    $message.Body = $bodyBuilder.ToMessageBody()

    $client = New-Object MailKit.Net.Smtp.SmtpClient
    $client.ServerCertificateValidationCallback = { $true }

    try {
        $client.Connect($smtpServer, $smtpPort, [MailKit.Security.SecureSocketOptions]::TlsOnConnect)
        $client.Authenticate($smtpUsername, $smtpPassword)
        $client.Send($message)
        Write-Host "E-mail de alerta de CPU enviado!"
    } catch {
        Write-Host "Erro ao enviar e-mail: $_"
    } finally {
        $client.Disconnect($true)
        $client.Dispose()
    }
} else {
    Write-Host "Uso médio de CPU dentro do normal: $averageCpuUsage%"
}
