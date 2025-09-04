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
# Informações da VM
# ========================
$vmName = $env:COMPUTERNAME
$iplocal = (Get-NetIPAddress -AddressFamily IPv4 `
    | Where-Object { $_.InterfaceAlias -notmatch "Loopback" -and $_.IPAddress -notlike "169.*" -and $_.PrefixOrigin -ne "WellKnown" } `
    | Sort-Object InterfaceIndex `
    | Select-Object -First 1).IPAddress
$ipvalido = Invoke-RestMethod -Uri "https://api.ipify.org"

# Lista de destinatários
$toList = @(
    "email1@serveremail.com",
    "email2@serveremail.com",
    "email3@serveremail.com",
    "email4@serveremail.com"
)

# ========================
# Parâmetros de Coleta
# ========================
$intervaloSegundos = 20      # Intervalo entre coletas
$duracaoMinutos = 5          # Total de minutos para medir
$limiteCPU = 95              # Limite de média para alerta
$coletasTotais = [math]::Ceiling(($duracaoMinutos * 60) / $intervaloSegundos)
$valoresCPU = @()

Write-Host "Iniciando coleta de CPU por $duracaoMinutos minutos a cada $intervaloSegundos segundos..."

for ($i = 0; $i -lt $coletasTotais; $i++) {
    $cpuUsage = Get-Counter '\Processor(_Total)\% Processor Time'
    $cpuValue = [math]::Round($cpuUsage.CounterSamples.CookedValue, 2)
    $valoresCPU += $cpuValue
    Write-Host "[$($i+1)/$coletasTotais] Uso de CPU: $cpuValue%"
    Start-Sleep -Seconds $intervaloSegundos
}

# ========================
# Cálculo da média
# ========================
$mediaCPU = [math]::Round(($valoresCPU | Measure-Object -Average).Average, 2)
Write-Host "Média de CPU nos últimos $duracaoMinutos minutos: $mediaCPU%"

if ($mediaCPU -ge $limiteCPU) {
    Write-Host "⚠️ Alerta: Média de CPU acima de $limiteCPU% - enviando e-mail..."

    $subject = "🚨 Alerta: CPU Média acima de $limiteCPU% - $vmName"

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
    <h2 style='color:red;'>🚨 <strong>Alerta de uso de CPU (Média)</strong> 🚨</h2>
    <hr />
    <p><strong>Servidor (VM):</strong> $vmName<br/>
    <strong>Endereço IP Local:</strong> $iplocal<br/>
    <strong>Endereço IP Público:</strong> $ipvalido<br/>
    <strong>Data do alerta:</strong> $(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')</p>
    <hr />
    <h3>Média de uso de CPU nos últimos $duracaoMinutos minutos:</h3>
    <table>
        <tr><th>Componente</th><th>Média Uso (%)</th></tr>
        <tr><td>CPU Total</td><td>$mediaCPU%</td></tr>
    </table>
    <hr />
    <p>Recomenda-se verificar imediatamente os processos que estão consumindo CPU para evitar impacto em sistemas e serviços.</p>
    <p>Este é um alerta automático gerado pelo sistema de monitoramento de CPU.</p>
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
        Write-Host "✅ E-mail de alerta de CPU enviado com sucesso!"
    } catch {
        Write-Host "❌ Erro ao enviar e-mail: $_"
    } finally {
        $client.Disconnect($true)
        $client.Dispose()
    }

} else {
    Write-Host "✅ CPU dentro do normal: Média de $mediaCPU%."
}