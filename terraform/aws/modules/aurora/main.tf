# Módulo Terraform para AWS Aurora PostgreSQL
#
# Este módulo é projetado para provisionar um cluster Amazon Aurora com compatibilidade PostgreSQL.
# Ele encapsula as melhores práticas para segurança, escalabilidade e gerenciamento, servindo como
# um recurso de aprendizado e um template para ambientes de produção.
#
# O principal objetivo deste código é ser didático. Cada recurso e parâmetro é extensivamente
# comentado para explicar não apenas "o que" está sendo feito, mas também "o porquê" daquela
# decisão de arquitetura, suas implicações e alternativas.
#
# Arquitetura do Módulo:
# 1.  **aws_db_subnet_group**: Agrupa sub-redes para o cluster, garantindo que ele seja lançado
#     em uma VPC com a conectividade de rede necessária.
# 2.  **aws_security_group**: Atua como um firewall virtual para o cluster, controlando o tráfego
#     de entrada e saída. A configuração inicial é permissiva para fins de teste, mas deve ser
#     restringida em produção.
# 3.  **aws_secretsmanager_secret & aws_secretsmanager_secret_version**: Gerencia a senha mestre
#     do banco de dados de forma segura, evitando a exposição de credenciais no código (hardcoding).
#     O Secrets Manager permite a rotação automática de senhas e o controle de acesso via IAM.
# 4.  **random_password**: Gera uma senha aleatória e segura para o usuário mestre, garantindo que
#     senhas fracas ou padrão não sejam utilizadas.
# 5.  **aws_rds_cluster**: Define o cluster Aurora em si. Este é o recurso central que gerencia o
#     armazenamento, a replicação e o failover. Parâmetros como `engine`, `engine_version`,
#     `database_name`, e `master_username` são configurados aqui.
# 6.  **aws_rds_cluster_instance**: Provisiona a instância de computação (writer) que executa o
#     motor do banco de dados e processa as consultas. A escolha do tipo de instância (`instance_class`)
#     é crucial para o desempenho e custo.

# ==============================================================================
# RECURSO: GRUPO DE SUB-REDES PARA O RDS (aws_db_subnet_group)
# ==============================================================================
#
# O `aws_db_subnet_group` é um pré-requisito para criar um cluster RDS em uma VPC.
# Ele informa ao RDS em quais sub-redes da sua VPC ele pode lançar as instâncias do banco de dados.
# Para alta disponibilidade, é uma prática recomendada especificar sub-redes em pelo menos duas
# Zonas de Disponibilidade (Availability Zones - AZs) diferentes.

resource "aws_db_subnet_group" "aurora_subnet_group" {
  # Nome do grupo de sub-redes. É útil para identificação e referência em outros recursos.
  name       = "${var.project_name}-sng"
  # Descrição amigável do propósito deste grupo.
  description = "Subnet group para o cluster Aurora do projeto ${var.project_name}"

  # Lista de IDs das sub-redes onde o RDS pode operar. Estas devem ser sub-redes privadas
  # para garantir que o banco de dados não seja exposto diretamente à internet.
  subnet_ids = var.private_subnet_ids

  # Tags são metadados que ajudam a organizar e gerenciar recursos na AWS.
  # É uma boa prática taguear todos os recursos com informações como projeto, ambiente e proprietário.
  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-sng"
    }
  )
}

# ==============================================================================
# RECURSO: GRUPO DE SEGURANÇA (aws_security_group)
# ==============================================================================
#
# O `aws_security_group` funciona como um firewall no nível da instância para controlar o tráfego.
# As regras definidas aqui (ingress e egress) determinam quais pacotes de rede podem entrar ou sair.
#
# IMPORTANTE: Para este ambiente de aprendizado, a regra de entrada (ingress) está configurada
# para aceitar tráfego de qualquer endereço IP (`0.0.0.0/0`) na porta do PostgreSQL (5432).
# ISTO NÃO É SEGURO PARA PRODUÇÃO. Em um ambiente real, você deve restringir o CIDR de origem
# para apenas os IPs ou grupos de segurança que precisam de acesso (ex: o security group das
# suas instâncias de aplicação).

resource "aws_security_group" "aurora_sg" {
  # Nome do grupo de segurança.
  name        = "${var.project_name}-sg"
  # Descrição clara da sua finalidade.
  description = "Controla o acesso ao cluster Aurora PostgreSQL"
  # ID da VPC onde este grupo de segurança será criado.
  vpc_id      = var.vpc_id

  # Regra de Entrada (Ingress)
  # Permite conexões de entrada na porta do banco de dados.
  ingress {
    description      = "Permite tráfego PostgreSQL de qualquer lugar (NÃO SEGURO PARA PRODUÇÃO)"
    from_port        = var.db_port
    to_port          = var.db_port
    protocol         = "tcp"
    # ATENÇÃO: `0.0.0.0/0` significa "qualquer IP". Em produção, substitua por uma lista de
    # IPs específicos ou IDs de outros security groups. Ex: ["10.0.1.0/24", "sg-12345678"].
    cidr_blocks      = ["0.0.0.0/0"]
  }

  # Regra de Saída (Egress)
  # Por padrão, a maioria dos security groups permite toda a comunicação de saída.
  # Esta configuração é geralmente aceitável, mas pode ser restringida se houver
  # requisitos de segurança mais rigorosos.
  egress {
    description      = "Permite todo o tráfego de saída"
    from_port        = 0
    to_port          = 0
    protocol         = "-1" # "-1" significa "todos os protocolos".
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-sg"
    }
  )
}

# ==============================================================================
# RECURSO: GERAÇÃO DE SENHA RANDÔMICA (random_password)
# ==============================================================================
#
# Usar senhas "hardcoded" (fixas no código) é uma péssima prática de segurança.
# O recurso `random_password` do provider `random` gera uma senha forte e aleatória
# a cada execução do `terraform apply`, que então usamos para configurar o banco de dados.
# Essa senha é armazenada de forma segura no AWS Secrets Manager.

resource "random_password" "master_password" {
  # Comprimento da senha. 16 caracteres é um bom ponto de partida para segurança.
  length           = 16
  # Garante que a senha inclua caracteres especiais, aumentando sua complexidade.
  special          = true
  # Evita o uso de caracteres que podem ser ambíguos em algumas fontes (ex: / \ ' " @).
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ==============================================================================
# RECURSO: SEGREDO NO AWS SECRETS MANAGER (aws_secretsmanager_secret)
# ==============================================================================
#
# O AWS Secrets Manager é o serviço ideal para armazenar, gerenciar e rotacionar
# credenciais de banco de dados, chaves de API e outros segredos.
# Este recurso cria o "contêiner" para o nosso segredo.

resource "aws_secretsmanager_secret" "aurora_master_password" {
  # Nome do segredo. Usar um caminho hierárquico (ex: /<ambiente>/<app>/db_password)
  # é uma boa prática para organizar segredos.
  name = "${var.project_name}/${var.environment}/aurora-master-password"
  # Descrição do que este segredo contém.
  description = "Senha mestre para o cluster Aurora ${var.project_name}"

  # IMPORTANTE: `recovery_window_in_days = 0` desabilita a janela de recuperação. Isso significa
  # que se o segredo for excluído, ele será permanentemente removido imediatamente. Para produção,
  # use um valor entre 7 e 30 dias para permitir a recuperação em caso de exclusão acidental.
  recovery_window_in_days = var.secrets_recovery_window

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-aurora-master-password"
    }
  )
}

# ==============================================================================
# RECURSO: VERSÃO DO SEGREDO (aws_secretsmanager_secret_version)
# ==============================================================================
#
# Depois de criar o contêiner do segredo, este recurso insere o valor real do segredo nele.
# O valor é um JSON que contém o nome de usuário e a senha gerada aleatoriamente.
# O Aurora pode se integrar nativamente com o Secrets Manager para buscar essas credenciais,
# mas aqui estamos gerenciando o processo via Terraform para fins didáticos.

resource "aws_secretsmanager_secret_version" "aurora_master_password_version" {
  # ID do segredo que esta versão irá popular.
  secret_id     = aws_secretsmanager_secret.aurora_master_password.id

  # O conteúdo do segredo. É uma prática comum armazenar credenciais como um JSON,
  # pois muitos serviços e SDKs da AWS sabem como analisar essa estrutura.
  secret_string = jsonencode({
    username = var.db_username,
    password = random_password.master_password.result
  })

  # O `lifecycle` com `ignore_changes` é usado aqui para dizer ao Terraform para não
  # tentar atualizar o `secret_string` se ele for alterado fora do Terraform (por exemplo,
  # por uma rotação de senha automática). Sem isso, o Terraform detectaria uma "deriva"
  # e tentaria reverter a senha para a versão gerada originalmente.
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ==============================================================================
# RECURSO: CLUSTER AURORA POSTGRESQL (aws_rds_cluster)
# ==============================================================================
#
# Este é o coração da nossa infraestrutura de banco de dados. O `aws_rds_cluster` representa
# o cluster Aurora, que é uma camada de armazenamento distribuído, tolerante a falhas e
# auto-reparável. Ele gerencia os dados, enquanto as `aws_rds_cluster_instance` fornecem
# o poder de computação.

resource "aws_rds_cluster" "aurora_cluster" {
  # Identificador único para o cluster na sua conta AWS.
  cluster_identifier = "${var.project_name}-cluster"

  # Motor do banco de dados e sua compatibilidade. Aurora pode ser compatível com MySQL ou PostgreSQL.
  engine               = "aurora-postgresql"
  # Versão específica do motor. É importante fixar a versão para garantir consistência
  # entre ambientes e evitar atualizações automáticas inesperadas.
  engine_version       = var.db_engine_version

  # Nome do banco de dados inicial que será criado quando o cluster for provisionado.
  database_name        = var.db_name

  # Credenciais do usuário mestre. Em vez de passar a senha diretamente, estamos passando
  # o ARN do segredo no Secrets Manager. Isso é mais seguro.
  master_username      = var.db_username
  manage_master_user_password = true
  master_user_secret_kms_key_id = var.kms_key_id_for_secrets

  # Configurações de Rede
  db_subnet_group_name = aws_db_subnet_group.aurora_subnet_group.name
  vpc_security_group_ids = [aws_security_group.aurora_sg.id]

  # Configurações de Backup e Manutenção
  # Período de retenção de backups automáticos (em dias). Para produção, 7 a 35 dias é comum.
  # Para este laboratório, definimos um valor baixo para reduzir custos de armazenamento de snapshots.
  backup_retention_period = var.backup_retention_days
  # Janela de tempo preferencial para backups automáticos (em UTC).
  preferred_backup_window = "02:00-03:00"
  # Janela de tempo preferencial para manutenção (patches, atualizações de versão) (em UTC).
  preferred_maintenance_window = "sun:03:00-sun:04:00"

  # Criptografia
  # A criptografia em repouso (at-rest) é uma exigência de segurança para a maioria das aplicações.
  # O Aurora usa o AWS KMS (Key Management Service) para gerenciar as chaves de criptografia.
  storage_encrypted  = true
  # Se você não especificar um `kms_key_id`, a AWS usará a chave padrão do RDS para a conta.
  # Para maior controle, você pode criar e especificar sua própria Chave Gerenciada pelo Cliente (CMK).

  # Custo e Proteção contra Exclusão
  # IMPORTANTE: `skip_final_snapshot = true` instrui a AWS a NÃO criar um snapshot final
  # quando o cluster for destruído. Isso é útil e econômico para ambientes de teste/desenvolvimento,
  # mas em produção, você quase sempre vai querer `false` para poder recuperar o banco de dados
  # mesmo após a exclusão do cluster.
  skip_final_snapshot  = var.skip_final_snapshot
  # `deletion_protection = false` permite que o cluster seja excluído via API/Terraform.
  # Em produção, defina como `true` para evitar exclusões acidentais. A exclusão só será
  # possível se este atributo for alterado para `false` primeiro.
  deletion_protection  = var.deletion_protection

  # O `apply_immediately = true` força as alterações a serem aplicadas imediatamente, em vez de
  # esperar pela próxima janela de manutenção. Útil para desenvolvimento, mas pode causar
  # tempo de inatividade em produção.
  apply_immediately    = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-cluster"
    }
  )

  # Este bloco `lifecycle` impede que o Terraform destrua o recurso se a senha for alterada.
  # É uma camada extra de proteção quando se gerencia senhas fora do fluxo padrão do Terraform.
  lifecycle {
    ignore_changes = [master_password]
  }
}

# ==============================================================================
# RECURSO: INSTÂNCIA DO CLUSTER AURORA (aws_rds_cluster_instance)
# ==============================================================================
#
# Enquanto o `aws_rds_cluster` gerencia o armazenamento, a `aws_rds_cluster_instance`
# representa a camada de computação (CPU, RAM). Você pode ter uma ou mais instâncias em um cluster.
# A primeira instância é tipicamente a "writer" (leitura e escrita), e as subsequentes
# podem ser "readers" (apenas leitura) para escalar a capacidade de leitura.

resource "aws_rds_cluster_instance" "aurora_instance" {
  # Identificador único para a instância.
  identifier           = "${var.project_name}-instance-1"
  # Associa esta instância ao cluster que criamos acima.
  cluster_identifier   = aws_rds_cluster.aurora_cluster.id

  # Classe da Instância (Tipo de Máquina)
  # A escolha da `instance_class` é a decisão mais impactante no custo e desempenho.
  # `db.t4g.small` é uma instância da família `t` (burst-capable) com processador Graviton2 (ARM).
  # É uma escolha extremamente econômica para desenvolvimento, teste e cargas de trabalho leves.
  # Para produção, você usaria classes maiores das famílias `r` (otimizada para memória) ou `m` (uso geral).
  instance_class       = var.db_instance_class

  # Motor do banco de dados. Deve corresponder ao motor do cluster.
  engine               = aws_rds_cluster.aurora_cluster.engine
  engine_version       = aws_rds_cluster.aurora_cluster.engine_version

  # Disponibilidade Pública
  # `publicly_accessible = false` é a configuração recomendada. A instância não receberá um IP público
  # e só poderá ser acessada de dentro da VPC. O acesso externo deve ser feito através de
  # bastiões (bastion hosts), VPNs ou Direct Connect.
  publicly_accessible  = false

  # Monitoramento
  # Habilita o Enhanced Monitoring, que fornece métricas do sistema operacional em tempo real.
  # É altamente recomendado para diagnosticar problemas de desempenho.
  monitoring_interval  = 60 # Coleta métricas a cada 60 segundos.
  monitoring_role_arn  = var.rds_monitoring_role_arn # ARN da IAM Role com permissões para o monitoramento.

  # Manutenção
  # Habilita atualizações automáticas de versões menores (minor version upgrades).
  # Ex: de 15.4.1 para 15.4.2. É uma boa prática para manter o banco de dados seguro e atualizado.
  auto_minor_version_upgrade = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-instance-1"
    }
  )
}

