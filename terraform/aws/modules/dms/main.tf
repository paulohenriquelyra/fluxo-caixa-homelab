# ==============================================================================
# MÓDULO TERRAFORM: AWS DATABASE MIGRATION SERVICE (DMS)
# ==============================================================================
#
# Este módulo provisiona os recursos necessários para realizar uma migração de banco
# de dados usando o AWS DMS. Ele é projetado para migrar dados de uma fonte
# externa (como um banco de dados on-premises ou em outra nuvem) para um banco de
# dados na AWS (neste caso, o Aurora PostgreSQL).
#
# Arquitetura do Módulo:
# 1.  **aws_dms_replication_subnet_group**: Define as sub-redes onde a instância de
#     replicação do DMS será criada. É crucial que estas sub-redes tenham conectividade
#     tanto com a origem quanto com o destino.
# 2.  **aws_dms_replication_instance**: Uma instância EC2 gerenciada pela AWS que executa
#     o software de replicação. Ela se conecta à origem, lê os dados e os escreve no
#     destino.
# 3.  **aws_dms_endpoint (Source)**: Configura os detalhes de conexão para o banco de
#     dados de origem. Para uma fonte externa, isso inclui o endereço IP, porta e
#     credenciais.
# 4.  **aws_dms_endpoint (Target)**: Configura os detalhes de conexão para o banco de
#     dados de destino (o cluster Aurora). Ele pode usar o endpoint do cluster e
#     credenciais do Secrets Manager.
# 5.  **aws_dms_replication_task**: Define a tarefa de migração em si. Ela une a
#     instância de replicação, os endpoints de origem e destino, e define as regras
#     de mapeamento de tabelas (quais esquemas e tabelas migrar).

# ==============================================================================
# RECURSO: GRUPO DE SUB-REDES DE REPLICAÇÃO DMS
# ==============================================================================
# Informa ao DMS em quais sub-redes da VPC a instância de replicação pode ser criada.

resource "aws_dms_replication_subnet_group" "dms_subnet_group" {
  replication_subnet_group_identifier = "${var.project_name}-dms-sng"
  replication_subnet_group_description = "Subnet group para a instância de replicação DMS"
  # A instância de replicação deve estar em sub-redes que possam alcançar tanto a origem
  # (potencialmente via internet/VPN) quanto o destino (dentro da VPC).
  subnet_ids = var.private_subnet_ids

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-dms-sng"
    }
  )
}

# ==============================================================================
# RECURSO: INSTÂNCIA DE REPLICAÇÃO DMS
# ==============================================================================
# Esta é a instância de computação que executa a migração.

resource "aws_dms_replication_instance" "dms_instance" {
  replication_instance_identifier = "${var.project_name}-dms-instance"
  # A classe da instância determina o poder de processamento (CPU, RAM) e a largura
  # de banda da rede. `dms.t3.medium` é uma boa escolha de baixo custo para migrações
  # de pequeno a médio porte.
  replication_instance_class = var.dms_instance_class
  allocated_storage          = 20 # Espaço em disco (GB) para logs de transação e cache.

  # Conecta a instância à nossa VPC e ao grupo de sub-redes.
  replication_subnet_group_identifier = aws_dms_replication_subnet_group.dms_subnet_group.id
  # Se `true`, a instância recebe um IP público. Necessário se a origem for um banco de
  # dados na internet (como nosso homelab) e não houver VPN ou Direct Connect.
  publicly_accessible = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-dms-instance"
    }
  )
}

# ==============================================================================
# RECURSO: ENDPOINT DE ORIGEM (SOURCE)
# ==============================================================================
# Define a conexão com o banco de dados de origem (PostgreSQL no Homelab).

resource "aws_dms_endpoint" "source" {
  endpoint_identifier = "${var.project_name}-source-endpoint"
  endpoint_type       = "source"
  engine_name         = "postgres"

  # Detalhes de conexão com o banco de dados de origem.
  # Estes valores serão passados como variáveis, pois são específicos do ambiente de origem.
  server_name = var.source_db_server_name
  port        = var.source_db_port
  database_name = var.source_db_name
  username    = var.source_db_username
  # A senha é marcada como um valor sensível no Terraform.
  password    = var.source_db_password

  # Configurações extras específicas do PostgreSQL.
  postgres_settings {
    # `None` é o padrão e geralmente funciona bem. Outras opções como `require`, `verify-ca`,
    # `verify-full` podem ser usadas se o seu servidor de origem exigir SSL.
    ssl_mode = "none"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-source-endpoint"
    }
  )
}

# ==============================================================================
# RECURSO: ENDPOINT DE DESTINO (TARGET)
# ==============================================================================
# Define a conexão com o banco de dados de destino (Aurora PostgreSQL na AWS).

resource "aws_dms_endpoint" "target" {
  endpoint_identifier = "${var.project_name}-target-endpoint"
  endpoint_type       = "target"
  engine_name         = "aurora-postgresql"

  # Detalhes de conexão com o banco de dados de destino.
  # Usamos os outputs do módulo Aurora para obter estes valores dinamicamente.
  server_name   = var.target_db_server_name # Endpoint do cluster Aurora
  port          = var.target_db_port
  database_name = var.target_db_name
  username      = var.target_db_username
  password      = var.target_db_password

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-target-endpoint"
    }
  )
}

# ==============================================================================
# RECURSO: TAREFA DE REPLICAÇÃO DMS
# ==============================================================================
# A tarefa de replicação une tudo e executa a migração.

resource "aws_dms_replication_task" "dms_task" {
  replication_task_identifier = "${var.project_name}-replication-task"
  # Associa a tarefa à instância de replicação e aos endpoints.
  replication_instance_arn = aws_dms_replication_instance.dms_instance.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target.endpoint_arn

  # Tipo de Migração:
  # - `full-load`: Copia todos os dados existentes. A tarefa para após a cópia inicial.
  # - `cdc`: (Change Data Capture) Replica apenas as alterações de dados que ocorrem após o início da tarefa.
  # - `full-load-and-cdc`: Faz uma carga completa e, em seguida, continua a replicar as alterações.
  #   Esta é a opção mais comum para migrações com tempo de inatividade mínimo.
  migration_type = "full-load"

  # Mapeamento de Tabelas: Define quais dados migrar.
  # Este JSON instrui o DMS a migrar todas as tabelas do esquema `public`.
  table_mappings = jsonencode({
    rules = [
      {
        "rule-type" = "selection",
        "rule-id" = "1",
        "rule-name" = "MigratePublicSchema",
        "object-locator" = {
          "schema-name" = "public",
          "table-name" = "%"
        },
        "rule-action" = "include"
      }
    ]
  })

  # Configurações da Tarefa: Ajusta o comportamento da migração.
  replication_task_settings = jsonencode({
    # Controla como o DMS lida com as tabelas no destino.
    # - `DO_NOTHING`: Assume que as tabelas já existem.
    # - `DROP_AND_CREATE`: Apaga e recria as tabelas no destino. Útil para testes repetidos.
    # - `TRUNCATE_BEFORE_LOAD`: Esvazia as tabelas antes de carregar os dados.
    TargetMetadata = {
      TargetSchema = ""
      SupportLobs = true
      FullLobMode = false
      LobChunkSize = 64
      LimitedSizeLobMode = true
      LobMaxSize = 32
      InlineLobMaxSize = 0
      LoadMaxFileSize = 0
      ParallelLoadThreads = 0
      ParallelLoadBufferSize = 0
      BatchApplyEnabled = false
      TaskRecoveryTableEnabled = false
      ParallelLoadQueuesPerThread = 0
    }
    FullLoadSettings = {
      TargetTablePrepMode = "DROP_AND_CREATE"
      CreatePkAfterFullLoad = false
      StopTaskCachedChangesApplied = false
      StopTaskCachedChangesNotApplied = false
      MaxFullLoadSubTasks = 8
      TransactionConsistencyTimeout = 600
      CommitRate = 10000
    }
    Logging = {
      EnableLogging = true
    }
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-replication-task"
    }
  )
}

