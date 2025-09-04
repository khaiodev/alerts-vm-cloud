# Carregar DLLs MimeKit e MailKit (ajuste caminho se precisar)
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

# Lista de destinatários
$toList = @(
    "khaio.lopes@tecnogroup.com.br",
    "rubens.sanches@tecnogroup.com.br",
    "humberto.santos@tecnogroup.com.br"
)

$subject = "🚨 Alerta: Espaço em disco acima de 90% - $vmName"

# ========================
# Obter informações de todos os discos, exceto 'Temp'
# ========================
$alertas = @()
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -ne 'Temp' }

foreach ($drive in $drives) {
    $total = $drive.Used + $drive.Free
    if ($total -gt 0) {
        $usedPercent = [math]::Round(($drive.Used / $total) * 100, 2)
        if ($usedPercent -ge 90) {
            $alertas += "<tr><td><b>$($drive.Name):</b></td><td><b>$usedPercent%</b></td></tr>"
        }
    }
}

if ($alertas.Count -gt 0) {
    # Corpo do e-mail em HTML
    $bodyHtml = @"
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        table { border-collapse: collapse; width: 100%; }
        td { border: 1px solid #ddd; padding: 8px; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        tr:hover { background-color: #ddd; }
    </style>
</head>
<body>
    <h2 style='color:red;'>🚨 <strong>Alerta de espaço em disco</strong> 🚨</h2>
    <hr />
    <p><strong>Servidor (VM):</strong> $vmName<br/>
    <strong>Endereço IP Local:</strong> $iplocal<br/>
    <strong>Endereço IP Público:</strong> $ipvalido<br/>
    <strong>Data do alerta:</strong> $(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')</p>
    <hr />
    <h3>Discos com uso crítico (acima de 90%):</h3>
    <table>
        <tr><th>Disco</th><th>Uso (%)</th></tr>
        $(($alertas -join "`n"))
    </table>
    <hr />
    <p>Recomenda-se verificar imediatamente os volumes listados para evitar impacto em sistemas e serviços.</p>
    <p>Este é um alerta automático gerado pelo sistema de monitoramento de discos.</p>
</body>
</html>
"@

    # Criar mensagem
    $message = New-Object MimeKit.MimeMessage
    $message.From.Add($from)

    foreach ($to in $toList) {
        $message.To.Add($to)
    }

    $message.Subject = $subject
    $bodyBuilder = New-Object MimeKit.BodyBuilder
    $bodyBuilder.HtmlBody = $bodyHtml
    $message.Body = $bodyBuilder.ToMessageBody()

    # Criar cliente SMTP
    $client = New-Object MailKit.Net.Smtp.SmtpClient
    $client.ServerCertificateValidationCallback = { $true }

    try {
        Write-Host "Conectando ao servidor SMTP..."
        $client.Connect($smtpServer, $smtpPort, [MailKit.Security.SecureSocketOptions]::TlsOnConnect)
        $client.Authenticate($smtpUsername, $smtpPassword)
        $client.Send($message)
        Write-Host "✅ E-mail enviado com sucesso!"
    } catch {
        Write-Host "❌ Erro ao enviar e-mail: $_"
    } finally {
        $client.Disconnect($true)
        $client.Dispose()
    }
} else {
    Write-Host "✅ Nenhum disco com uso crítico detectado."
}
