# 🚨 Monitoramento de Recursos (Disco, CPU e Memória) com Alertas por E-mail (Direcionado para sistema operacional Windows)

Este projeto contém **scripts PowerShell** e **prompts em .BAT** que monitoram:
- Espaço em disco
- Uso de CPU
- Uso de memória

Quando o uso ultrapassar **limites críticos**, será enviado um **e-mail automático com HTML formatado** para o ou os endereços configurado.

A motivação para o desenvolvimento surgiu da ausência de recursos simples e acessíveis para monitoramento ativo, que não exigissem complexidade na implementação nem custos adicionais.

---

## 📁 Estrutura de arquivos

A estrutura de arquivos do projeto segue como abaixo:

```
├── AlertaDisco-static.ps1         # Verifica espaço em disco e envia alerta usando informações de e-mail/envio estático
├── AlertaCPU-static.ps1           # Verifica uso de CPU e envia alerta usando informações de e-mail/envio estático
├── AlertaMEM-static.ps1           # Verifica uso de memória e envia alerta usando informações de e-mail/envio estático
├── AlertaDisco-aws.ps1            # Verifica espaço em disco e envia alerta usando informações de e-mail/envio do Key Vault da AWS
├── AlertaCPU-aws.ps1              # Verifica uso de CPU e envia alerta usando informações de e-mail/envio do Key Vault da AWS
├── AlertaMEM-aws.ps1              # Verifica uso de memória e envia alerta usando informações de e-mail/envio do Key Vault da AWS
├── AlertaDisco-azure.ps1          # Verifica espaço em disco e envia alerta usando informações de e-mail/envio do Key Vault da Azure
├── AlertaCPU-azure.ps1            # Verifica uso de CPU e envia alerta usando informações de e-mail/envio do Key Vault da Azure
├── AlertaMEM-azure.ps1            # Verifica uso de memória e envia alerta usando informações de e-mail/envio do Key Vault da Azure
├── ExecutaAlertaDisco.bat         # Script .bat configurado no Cron para chamada do PowerShell
├── ExecutaAlertaCPU.bat           # Script .bat configurado no Cron para chamada do PowerShell
├── ExecutaAlertaMEM.bat           # Script .bat configurado no Cron para chamada do PowerShell
├── criaCron.ps1                   # Script .ps1 para a criação automatizada das schedules no serviço de Cron
├── libs\
    ├── MimeKit.dll                # Biblioteca para envio de e-mail (MimeKit)
    ├── MimeKit.dll.config         # Biblioteca para envio de e-mail (MimeKit)
    ├── MimeKit.pdb                # Biblioteca para envio de e-mail (MimeKit)
    ├── MimeKit.xml                # Biblioteca para envio de e-mail (MimeKit)
    ├── MailKit.dll                # Biblioteca para envio de e-mail (MailKit)
    ├── MailKit.dll.config         # Biblioteca para envio de e-mail (MailKit)
    ├── MailKit.pdb                # Biblioteca para envio de e-mail (MailKit)
    └── MailKit.xml                # Biblioteca para envio de e-mail (MailKit)
```
Para que tudo funcione como o esperado e já configurado nos scripts você precisar ter a estrutura abaixo:
```
C:\alertas\
├── AlertaDisco.ps1         # Verifica espaço em disco e envia alerta
├── AlertaCPU.ps1           # Verifica uso de CPU e envia alerta
├── AlertaMEM.ps1           # Verifica uso de memória e envia alerta
├── ExecutaAlertaDisco.bat  # Script .bat configurado no Cron para chamada do PowerShell
├── ExecutaAlertaCPU.bat    # Script .bat configurado no Cron para chamada do PowerShell
├── ExecutaAlertaMEM.bat    # Script .bat configurado no Cron para chamada do PowerShell
├── criaCron.ps1            # Script .ps1 para a criação automatizada das schedules no serviço de Cron
├── libs\
    ├── MimeKit.dll                # Biblioteca para envio de e-mail (MimeKit)
    ├── MimeKit.dll.config         # Biblioteca para envio de e-mail (MimeKit)
    ├── MimeKit.pdb                # Biblioteca para envio de e-mail (MimeKit)
    ├── MimeKit.xml                # Biblioteca para envio de e-mail (MimeKit)
    ├── MailKit.dll                # Biblioteca para envio de e-mail (MailKit)
    ├── MailKit.dll.config         # Biblioteca para envio de e-mail (MailKit)
    ├── MailKit.pdb                # Biblioteca para envio de e-mail (MailKit)
    └── MailKit.xml                # Biblioteca para envio de e-mail (MailKit)
```
Observe que os arquivos `AlertaDisco.ps1`, `AlertaMEM.ps1`, `AlertaCPU.ps1` não recebem mais as indicações de "aws", "azure" ou "static". Agora, é necessário definir qual método será utilizado e realizar a configuração correspondente. Mais detalhes seguem abaixo.

---

## ⚙️ Requisitos

- PowerShell 7
- Acesso à internet
- SMTP configurado para envio
- Bibliotecas `MimeKit.dll` e `MailKit.dll` na pasta `libs` (contém as libs no projeto)

🔗 Baixe o PowerShell 7 aqui:  

DOC: [https://learn.microsoft.com/pt-br/shows/it-ops-talk/how-to-install-powershell-7](https://learn.microsoft.com/pt-br/shows/it-ops-talk/how-to-install-powershell-7)

URL download pacote .MSI PowerShell 7: https://github.com/PowerShell/PowerShell/releases/download/v7.5.2/PowerShell-7.5.2-win-x64.msi

---

## 🔧 Configuração

Edite os seguintes campos em cada script (`AlertaDisco.ps1`, `AlertaMEM.ps1`, `AlertaCPU.ps1`):

Para o "static":
```powershell
$smtpServer = "[SERVIDORSMTP]"
$smtpPort = [PORTASMTP]
$smtpUsername = "[CONTAEMAIL]"
$smtpPassword = "[SENHAEMAIL]"
$from = "[CONTAEMAIL]"
$to = "[REMETENTE]"
```

Para o "aws":
```powershell
$secretName = "[NOMESECRET]"   # Nome do segredo no AWS Secrets Manager
$region     = "[REGIAO]"       # Região da AWS
```

Para o "azure":
```powershell
$KeyVaultName = "[NOMEKEYVAULT]"          # Nome do Key Vault
$secretUser   = "[NOMESEGREDO]"           # Nome do segredo do usuário
$secretPass   = "[NOMESEGREDOSENHA]"      # Nome do segredo da senha
$secretServer = "[NOMESEGREDOSMTPSERVER]" # Nome do segredo do servidor SMTP
$secretPort   = "[NOMESEGREDOSMTPPORT]"   # Nome do segredo da porta SMTP
$secretFrom   = "[NOMESEGREDOFROM]"       # Nome do segredo do e-mail remetente
```

---

## 📤 Execução Manual

Execute os scripts manualmente com:

```powershell
powershell7 -ExecutionPolicy Bypass -File "C:\alertas\AlertaDisco.ps1"
powershell7 -ExecutionPolicy Bypass -File "C:\alertas\AlertaCPU.ps1"
powershell7 -ExecutionPolicy Bypass -File "C:\alertas\AlertaMEM.ps1"
```

---

## ⏰ Agendamento com Tarefa Agendada (Cron)

**Forma manual**:
1. Abra o **Agendador de Tarefas do Windows** (taskschd.msc)
2. Crie uma nova tarefa
3. Em **Ação**, selecione `Iniciar um programa` e informe:
   - Programa/script: `"C:\alertas\ExecutaAlertaDisco.bat"`
4. Defina a frequência desejada (ex: a cada 1 hora)

**Forma automatizada**: Executar "criaCron.ps1".

### ExecutaAlertaCPU
✔ Executa das **08:00 às 22:00**, a cada **20 minutos**, somente de **segunda a sexta-feira**.  
**Descrição:** Alerta para monitoramento contínuo de uso de CPU durante horário comercial.

### ExecutaAlertaMEM
✔ Executa das **08:00 às 22:00**, a cada **20 minutos**, somente de **segunda a sexta-feira**.  
**Descrição:** Alerta para monitoramento contínuo de uso de memória durante horário comercial.
### ExecutaAlertaDisco
✔ Executa **todos os dias**, a cada **2 horas**, **sem restrição de horário**.  
**Descrição:** Alerta contínuo de uso de disco para detecção de anomalias a qualquer momento.


**Importante:** Certifique-se de que o PowerShell 7 está instalado, pois as bibliotecas `MimeKit` e `MailKit` funcionam melhor nele.

---

## 📩 Alerta por E-mail

Limites críticos configurados nos scripts:
- Disco: **>= 90%**
- CPU: **>= 95%**
- Memória disponível: **>= 95%**

Será enviado um e-mail com os detalhes da VM, IPs e o recurso em estado crítico.

---

## 📌 Observações

- Os scripts são independentes e podem ser executados separadamente
- Ideal para monitoramento de servidores locais ou em nuvem
- O `.bat` invoca automaticamente o PowerShell7, não sendo necessário agendar diretamente o `.ps1`

## ➡️ Próximos passos

- Desenvolver script principal para mover arquivos para "C:/alertas", realizar a instalação do "PowerShell 7" e setar se é "static", "aws" ou "azure"

---

## 👨‍💻 Autor

**Khaio Lopes** – khaioaugusto@gmail.com

---
