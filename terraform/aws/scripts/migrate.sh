#!/bin/bash
# ==============================================================================
# SCRIPT: migrate.sh
# ==============================================================================
# Propósito: Iniciar a tarefa de migração do AWS DMS.
#
# Uso: ./migrate.sh
#
# Este script inicia a tarefa de replicação do DMS que foi criada pelo Terraform.
# Ele usa a AWS CLI para iniciar a tarefa e monitorar seu progresso.

set -e

# Cores para output legível
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Diretório do ambiente de desenvolvimento
ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../environments/dev" && pwd)"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  INICIAR MIGRAÇÃO DMS${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Navega para o diretório do ambiente
cd "$ENV_DIR"

# Verifica se a AWS CLI está instalada
if ! command -v aws &> /dev/null; then
    echo -e "${RED}ERRO: AWS CLI não está instalada.${NC}"
    echo "Por favor, instale a AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Obtém o ARN da tarefa de replicação a partir dos outputs do Terraform
echo -e "${GREEN}Obtendo informações da tarefa de replicação...${NC}"
TASK_ARN=$(terraform output -raw dms_replication_task_arn 2>/dev/null)

if [ -z "$TASK_ARN" ]; then
    echo -e "${RED}ERRO: Não foi possível obter o ARN da tarefa de replicação.${NC}"
    echo "Certifique-se de que o módulo DMS foi criado com 'terraform apply'."
    exit 1
fi

echo -e "${GREEN}ARN da Tarefa: ${NC}$TASK_ARN"
echo ""

# Verifica o status atual da tarefa
echo -e "${GREEN}Verificando o status da tarefa...${NC}"
TASK_STATUS=$(aws dms describe-replication-tasks --filters "Name=replication-task-arn,Values=$TASK_ARN" --query 'ReplicationTasks[0].Status' --output text)

echo -e "${GREEN}Status Atual: ${NC}$TASK_STATUS"
echo ""

# Se a tarefa já estiver em execução, pergunta se deseja pará-la primeiro
if [ "$TASK_STATUS" == "running" ]; then
    echo -e "${YELLOW}A tarefa já está em execução.${NC}"
    read -p "Deseja parar e reiniciar a tarefa? (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Parando a tarefa...${NC}"
        aws dms stop-replication-task --replication-task-arn "$TASK_ARN"
        echo -e "${GREEN}Aguardando a tarefa parar...${NC}"
        aws dms wait replication-task-stopped --filters "Name=replication-task-arn,Values=$TASK_ARN"
    else
        echo -e "${GREEN}Mantendo a tarefa em execução.${NC}"
        exit 0
    fi
fi

# Inicia a tarefa de replicação
echo -e "${GREEN}Iniciando a tarefa de replicação...${NC}"
aws dms start-replication-task \
    --replication-task-arn "$TASK_ARN" \
    --start-replication-task-type start-replication

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  TAREFA DE MIGRAÇÃO INICIADA${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "A tarefa de migração está em execução."
echo -e "Para monitorar o progresso, use:"
echo -e "  ${GREEN}aws dms describe-replication-tasks --filters \"Name=replication-task-arn,Values=$TASK_ARN\"${NC}"
echo ""
echo -e "Ou acesse o console do AWS DMS:"
echo -e "  ${GREEN}https://console.aws.amazon.com/dms/v2/home${NC}"
echo ""

