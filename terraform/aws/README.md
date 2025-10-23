# Infraestrutura AWS para Migração de Banco de Dados com Terraform

Este diretório contém o código Terraform para provisionar a infraestrutura AWS necessária para migrar o banco de dados PostgreSQL do seu Homelab para o Amazon Aurora PostgreSQL usando o AWS Database Migration Service (DMS).

## Estrutura do Projeto

```
terraform/aws/
├── environments/
│   └── dev/                      # Configuração do ambiente de desenvolvimento
│       ├── main.tf               # Ponto de entrada, invoca os módulos
│       ├── variables.tf          # Declaração de variáveis
│       ├── outputs.tf            # Saídas (endpoints, ARNs, etc.)
│       └── terraform.tfvars      # Valores das variáveis (EDITE ESTE ARQUIVO)
├── modules/
│   ├── network/                  # Módulo de rede (VPC, Subnets, Gateways)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── aurora/                   # Módulo do cluster Aurora PostgreSQL
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── dms/                      # Módulo do AWS DMS (migração)
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── scripts/                      # Scripts auxiliares
│   ├── deploy.sh                 # Inicializa e aplica o Terraform
│   ├── destroy.sh                # Destrói toda a infraestrutura
│   ├── connect.sh                # Conecta ao cluster Aurora
│   └── migrate.sh                # Inicia a tarefa de migração do DMS
└── README.md                     # Este arquivo
```

## Pré-requisitos

Antes de começar, certifique-se de ter:

1.  **Terraform instalado:** Versão 1.6.0 ou superior. [Download](https://www.terraform.io/downloads)
2.  **AWS CLI instalada e configurada:** [Guia de Instalação](https://aws.amazon.com/cli/)
3.  **Credenciais da AWS configuradas:** Execute `aws configure` e forneça sua Access Key e Secret Key.
4.  **PostgreSQL Client (psql):** Para testar a conexão com o Aurora.

## Guia de Uso Rápido

### 1. Configuração Inicial

Edite o arquivo `environments/dev/terraform.tfvars` e preencha as informações necessárias:

```hcl
# IP público do seu Homelab (onde o PostgreSQL está rodando)
source_db_server_name = "203.0.113.42"  # Substitua pelo seu IP

# Senha do PostgreSQL no Homelab
source_db_password = "sua_senha_aqui"

# Senha do Aurora (será preenchida após o primeiro deploy)
target_db_password = "PREENCHER_DEPOIS"
```

### 2. Primeiro Deploy (Rede + Aurora)

**IMPORTANTE:** Antes do primeiro deploy, comente o módulo `dms` no arquivo `environments/dev/main.tf`:

```terraform
# module "dms" {
#   ...
# }
```

Execute o script de deploy:

```bash
cd terraform/aws/scripts
./deploy.sh
```

Aguarde a conclusão (10-15 minutos).

### 3. Obter a Senha do Aurora

Após o primeiro deploy, obtenha a senha gerada para o Aurora:

```bash
cd ../environments/dev
terraform output aurora_master_password_secret_arn
```

Copie o ARN e use a AWS CLI para obter a senha:

```bash
aws secretsmanager get-secret-value --secret-id "ARN_AQUI" --query SecretString --output text
```

Edite novamente o `terraform.tfvars` e preencha o `target_db_password` com a senha obtida.

### 4. Segundo Deploy (DMS)

Descomente o módulo `dms` no `main.tf` e execute o deploy novamente:

```bash
cd ../../scripts
./deploy.sh
```

### 5. Executar a Migração

Inicie a tarefa de migração do DMS:

```bash
./migrate.sh
```

Monitore o progresso no console da AWS (DMS -> Tarefas de migração de banco de dados).

### 6. Validar os Dados

Conecte-se ao Aurora e valide os dados:

```bash
./connect.sh
```

No prompt do `psql`, execute consultas para verificar os dados.

### 7. Destruir a Infraestrutura

**IMPORTANTE:** Para evitar custos, destrua a infraestrutura quando terminar:

```bash
./destroy.sh
```

Digite `sim` para confirmar.

## Custos Estimados

Para 3 dias de uso contínuo:

| Recurso                | Custo/hora | Custo (72h) |
|------------------------|------------|-------------|
| Aurora db.t4g.small    | $0.082     | $5.90       |
| DMS dms.t3.medium      | $0.164     | $11.81      |
| NAT Gateway            | $0.045     | $3.24       |
| **Total**              |            | **~$21.00** |

Para economizar, destrua os recursos quando não estiver usando.

## Documentação Adicional

*   **Plano de Execução de 3 Dias:** `../../docs/plano-execucao-3-dias.md`
*   **Estimativa de Custos Detalhada:** `../../docs/aws-aurora-cost-estimation.md`
*   **Guia de Migração para AWS:** `../../docs/migracao-aws.md`

## Suporte

Se encontrar problemas, consulte a documentação oficial:

*   [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
*   [AWS Aurora](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/CHAP_AuroraOverview.html)
*   [AWS DMS](https://docs.aws.amazon.com/dms/latest/userguide/Welcome.html)

---

**Autor:** Paulo Henrique Lyra  
**Data:** Outubro de 2025  
**Propósito:** Aprendizado e preparação para migração de banco de dados em produção

