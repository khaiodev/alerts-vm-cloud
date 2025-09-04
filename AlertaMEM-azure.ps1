# Carregar DLLs MimeKit e MailKit
[Reflection.Assembly]::LoadFrom("C:\alertas\libs\MimeKit.dll") | Out-Null
[Reflection.Assembly]::LoadFrom("C:\alertas\libs\MailKit.dll") | Out-Null

# ========================
# Configuração do Key Vault
# ========================
$KeyVaultName = "kv-alertas-prd"   # Nome do Key Vault
$secretUser   = "smtp-username"    # Nome do segredo do usuário
$secretPass   = "smtp-password"    # Nome do segredo da senha
$secretServer = "smtp-server"      # Nome do segredo do servidor SMTP
$secretPort   = "smtp-port"        # Nome do segredo da porta SMTP
$secretFrom   = "smtp-from"        # Nome do segredo do e-mail remetente

# Autenticação via Managed Identity
try {
    Write-Host "🔑 Conectando ao Azure com identidade gerenciada..."
    Connect-AzAccount -Identity | Out-Null
} catch {
    Write-Host "❌ Erro ao autenticar no Azure: $_"
    exit 1
}

# Buscar segredos no Key Vault
try {
    $smtpUsername = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secretUser).SecretValueText
    $smtpPassword = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secretPass).SecretValueText
    $smtpServer   = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secretServer).SecretValueText
    $smtpPort     = [int](Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secretPort).SecretValueText
    $from         = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secretFrom).SecretValueText
} catch {
    Write-Host "❌ Erro ao recuperar segredos do Key Vault: $_"
    exit 1
}

# ========================
# Info VM
# ========================
$vmName = $env:COMPUTERNAME
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

$subject = "🚨 Alerta: Memória acima de 95% - $vmName"

# ========================
# Coleta de uso de memória por 5 minutos (20s intervalo)
# ========================
$memoryUsageSamples = @()
$iterations = 15  # 5 minutos / 20 segundos = 15 coletas

for ($i = 1; $i -le $iterations; $i++) {
    $mem = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalMem = [math]::Round($mem.TotalVisibleMemorySize / 1MB, 2)
    $freeMem = [math]::Round($mem.FreePhysicalMemory / 1MB, 2)
    $usedMem = $totalMem - $freeMem
    $usedPercent = [math]::Round(($usedMem / $totalMem) * 100, 2)
    
    $memoryUsageSamples += $usedPercent
    Write-Host "Coleta ${i}: Uso de memória = $usedPercent%"
    Start-Sleep -Seconds 20
}

$averageMemoryUsage = [math]::Round(($memoryUsageSamples | Measure-Object -Average).Average, 2)
Write-Host "Média de uso de memória nos últimos 5 minutos: $averageMemoryUsage%"

# ========================
# Envio de alerta
# ========================
if ($averageMemoryUsage -ge 95) {
    $bodyHtml = @"
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        table { border-collapse: collapse; width: 100%; }
        td, th { border: 1px solid #ddd; padding: 8px; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        tr:hover { background-color: #ddd; }
    </style>
</head>
<body>
    <h2 style='color:red;'>🚨 <strong>Alerta de uso de Memória</strong> 🚨</h2>
    <hr />
    <p><strong>Servidor (VM):</strong> $vmName<br/>
    <strong>Endereço IP Local:</strong> $iplocal<br/>
    <strong>Endereço IP Público:</strong> $ipvalido<br/>
    <p><strong>Data do alerta:</strong> $(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')</p>
    <hr />
    <h3>Média de uso de memória nos últimos 5 minutos:</h3>
    <table>
        <tr><th>Média de Uso (%)</th></tr>
        <tr><td>$averageMemoryUsage%</td></tr>
    </table>
    <hr />
    <p>Recomenda-se verificar imediatamente o consumo de memória dos serviços ativos para evitar impacto em sistemas e serviços.</p>
    <p>Este é um alerta automático gerado pelo sistema de monitoramento de Memória.</p>
</body>
</html>
"@

    $message = New-Object MimeKit.MimeMessage
    $message.From.Add($from)
    foreach ($to in $toList) {
        $message.To.Add($to)
    }
    $message.Subject = $subject
    $bodyBuilder = New-Object MimeKit.BodyBuilder
    $bodyBuilder.HtmlBody = $bodyHtml
    $message.Body = $bodyBuilder.ToMessageBody()

    $client = New-Object MailKit.Net.Smtp.SmtpClient
    $client.ServerCertificateValidationCallback = { $true }

    try {
        Write-Host "Conectando ao servidor SMTP..."
        $client.Connect($smtpServer, $smtpPort, [MailKit.Security.SecureSocketOptions]::TlsOnConnect)
        $client.Authenticate($smtpUsername, $smtpPassword)
        $client.Send($message)
        Write-Host "✅ E-mail de alerta de memória enviado!"
    } catch {
        Write-Host "❌ Erro ao enviar e-mail: $_"
    } finally {
        $client.Disconnect($true)
        $client.Dispose()
    }
} else {
    Write-Host "✅ Uso médio de memória dentro do normal: $averageMemoryUsage%"
}
