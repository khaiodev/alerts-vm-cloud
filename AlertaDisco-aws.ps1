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
    "khaio.lopes@tecnogroup.com.br",
    "rubens.sanches@tecnogroup.com.br",
    "humberto.santos@tecnogroup.com.br"
)
$subject = "🚨 Alerta: Espaço em disco acima de 90% - $vmName"

# Checagem de discos
$alertas = @()
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -ne 'Temp' }

foreach ($drive in $drives) {
    $total = $drive.Used + $drive.Free
    if ($total -gt 0) {
        $usedPercent = [math]::Round(($drive.Used / $total) * 100, 2)
        if ($usedPercent -ge 90) {
            $alertas += "<tr><td>$($drive.Name):</td><td>$usedPercent%</td></tr>"
        }
    }
}

if ($alertas.Count -gt 0) {
    $bodyHtml = @"
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        table { border-collapse: collapse; width: 100%; }
        td { border: 1px solid #ddd; padding: 8px; }
    </style>
</head>
<body>
    <h2 style='color:red;'>🚨 <strong>Alerta de espaço em disco</strong> 🚨</h2>
    <p><b>Servidor:</b> $vmName<br/>
       <b>IP Local:</b> $iplocal<br/>
       <b>IP Público:</b> $ipvalido<br/>
       <b>Data:</b> $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')</p>
    <h3>Discos críticos:</h3>
    <table><tr><th>Disco</th><th>Uso (%)</th></tr>
    $(($alertas -join "`n"))
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
        Write-Host "E-mail enviado com sucesso!"
    } catch {
        Write-Host "Erro ao enviar e-mail: $_"
    } finally {
        $client.Disconnect($true)
        $client.Dispose()
    }
} else {
    Write-Host "Nenhum disco crítico detectado."
}
