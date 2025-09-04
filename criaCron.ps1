# Lista de tarefas com intervalos, dias e descrições específicos
$Tarefas = @(
    @{ Nome = "ExecutaAlertaCPU";   
       Caminho = "C:\alertas\ExecutaAlertaCPU.bat";   
       Intervalo = "PT20M"; 
       Dias = "Weekdays"; 
       LimitaHorario = $true;
       Descricao = "Executa o alerta de CPU das 08:00 às 22:00, de segunda a sexta-feira, a cada 20 minutos para monitoramento de carga de processamento."
    },
    @{ Nome = "ExecutaAlertaMEM";   
       Caminho = "C:\alertas\ExecutaAlertaMEM.bat";   
       Intervalo = "PT20M"; 
       Dias = "Weekdays"; 
       LimitaHorario = $true;
       Descricao = "Executa o alerta de Memória das 08:00 às 22:00, de segunda a sexta-feira, a cada 20 minutos para monitoramento de uso de memória RAM."
    },
    @{ Nome = "ExecutaAlertaDisco"; 
       Caminho = "C:\alertas\ExecutaAlertaDisco.bat"; 
       Intervalo = "PT2H";  
       Dias = "Daily"; 
       LimitaHorario = $false;
       Descricao = "Executa o alerta de Disco todos os dias, 24 horas por dia, a cada 2 horas para monitoramento de espaço em disco."
    }
)

foreach ($tarefa in $Tarefas) {
    $taskName = $tarefa.Nome
    $batPath = $tarefa.Caminho
    $intervalo = $tarefa.Intervalo
    $dias = $tarefa.Dias
    $limitaHorario = $tarefa.LimitaHorario
    $descricao = $tarefa.Descricao

    $service = New-Object -ComObject "Schedule.Service"
    $service.Connect()

    $rootFolder = $service.GetFolder("\")
    $taskDefinition = $service.NewTask(0)

    # Definições da tarefa
    $taskDefinition.RegistrationInfo.Description = $descricao
    $taskDefinition.Principal.UserId = "SYSTEM"
    $taskDefinition.Principal.LogonType = 5  # ServiceAccount
    $taskDefinition.Principal.RunLevel = 1   # Highest

    if ($dias -eq "Weekdays") {
        # Gatilho semanal - Segunda a Sexta
        $trigger = $taskDefinition.Triggers.Create(3)  # 3 = WeeklyTrigger
        $trigger.DaysOfWeek = 62   # Segunda (2) + Terça (4) + Quarta (8) + Quinta (16) + Sexta (32)
        $trigger.WeeksInterval = 1
    } else {
        # Gatilho diário - Todos os dias
        $trigger = $taskDefinition.Triggers.Create(2)  # 2 = DailyTrigger
        $trigger.DaysInterval = 1
    }

    if ($limitaHorario) {
        $trigger.StartBoundary = (Get-Date).Date.ToString("yyyy-MM-ddT08:00:00")
        $trigger.Repetition.Duration = "PT14H"  # 08:00 até 22:00
    } else {
        $trigger.StartBoundary = (Get-Date).Date.ToString("yyyy-MM-ddT00:00:00")
        $trigger.Repetition.Duration = "P1D"   # 24 horas
    }

    $trigger.Repetition.Interval = $intervalo

    # Ação
    $action = $taskDefinition.Actions.Create(0)
    $action.Path = $batPath

    # Registrar a tarefa
    $rootFolder.RegisterTaskDefinition($taskName, $taskDefinition, 6, $null, $null, 3, $null)
}
