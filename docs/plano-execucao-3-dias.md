'''
# Plano de Execução Intensivo de 3 Dias: Migração para AWS Aurora com Terraform e DMS

Este documento detalha um plano de estudos e execução prático para realizar uma migração de banco de dados do seu ambiente Homelab para a AWS em 3 dias. O objetivo é simular um projeto real, focando no aprendizado profundo de Terraform, AWS Aurora e DMS.

---

## Dia 1: Fundação da Infraestrutura na AWS

**Objetivo do Dia:** Provisionar a infraestrutura de rede e o cluster de banco de dados Aurora na AWS usando Terraform, garantindo que a base esteja sólida antes de iniciar a migração.

### Manhã (3-4 horas): Preparação e Análise do Código

1.  **Configuração do Ambiente Local:**
    *   Garanta que você tenha a [AWS CLI](https://aws.amazon.com/cli/) instalada e configurada com suas credenciais (`aws configure`).
    *   Garanta que o [Terraform](https://www.terraform.io/downloads) (versão 1.6.0 ou superior) esteja instalado.
    *   Clone o repositório do projeto para sua máquina local.

2.  **Estudo do Código Terraform:**
    *   **Navegue pela estrutura:** Abra o diretório `terraform/aws` e analise a organização:
        *   `environments/dev`: Contém a configuração do nosso ambiente de desenvolvimento. É o ponto de entrada.
        *   `modules/network`: Módulo reutilizável que define a VPC, sub-redes, etc.
        *   `modules/aurora`: Módulo que define o cluster Aurora.
        *   `modules/dms`: Módulo que define os recursos de migração.
    *   **Leia os arquivos `.tf` com atenção:** Dedique tempo para ler todos os comentários nos arquivos `main.tf`, `variables.tf` e `outputs.tf`. O código foi escrito para ser um material de estudo. **Não pule esta etapa.**

### Tarde (4-5 horas): Provisionamento e Conexão

1.  **Primeiro Deploy (Rede + Aurora):**
    *   **Edite `main.tf`:** Navegue até `terraform/aws/environments/dev/main.tf` e comente (adicione `#` no início de cada linha) todo o bloco do módulo `dms`.
        ```terraform
        # module "dms" { ... }
        ```
    *   **Execute o Deploy:** Navegue para `terraform/aws/scripts` e execute o script de deploy:
        ```bash
        ./deploy.sh
        ```
    *   O Terraform irá mostrar um plano de execução. Revise os recursos que serão criados (VPC, Subnets, Aurora Cluster, etc.) e digite `yes` para aprovar.
    *   **Aguarde:** O provisionamento do cluster Aurora pode levar de 10 a 15 minutos.

2.  **Obtenção da Senha Mestra:**
    *   Após o `deploy.sh` ser concluído, o Terraform exibirá os `outputs`. Copie o valor do `aurora_master_password_secret_arn`.
    *   Acesse o console da AWS -> **Secrets Manager** ou use a AWS CLI para obter a senha:
        ```bash
        aws secretsmanager get-secret-value --secret-id "COLE_O_ARN_AQUI" --query SecretString --output text
        ```
    *   **Guarde esta senha em um local seguro.**

3.  **Teste de Conexão com o Aurora:**
    *   Execute o script de conexão:
        ```bash
        ./connect.sh
        ```
    *   Quando solicitado, informe o usuário (`masteruser`) e a senha que você acabou de obter.
    *   Se a conexão for bem-sucedida, você estará no prompt do `psql` conectado ao seu novo cluster Aurora na nuvem. Execute `\l` para listar os bancos de dados e `\q` para sair.

**Resultado ao Final do Dia 1:** Você terá uma VPC funcional e um cluster Aurora PostgreSQL rodando na AWS, totalmente provisionados via Terraform. Você terá compreendido a estrutura do código e validado a conectividade com o banco de dados.

---

## Dia 2: A Migração dos Dados

**Objetivo do Dia:** Provisionar os recursos do DMS e executar a migração completa (Full Load) do banco de dados do seu Homelab para o Aurora.

### Manhã (3-4 horas): Configuração da Migração

1.  **Configuração de Rede do Homelab:**
    *   **IP Público:** Descubra o endereço IP público da sua rede doméstica/escritório (pesquise "meu ip" no Google).
    *   **Port Forwarding:** No seu roteador, configure uma regra de *port forwarding* para direcionar o tráfego da porta `5432` (PostgreSQL) para o endereço IP interno do seu servidor PostgreSQL no Homelab.
    *   **Firewall:** Certifique-se de que qualquer firewall no seu servidor ou na sua rede permita conexões de entrada na porta `5432`.

2.  **Atualização do Terraform para o DMS:**
    *   **Edite `terraform.tfvars`:** Navegue até `terraform/aws/environments/dev/terraform.tfvars` e preencha os valores dos placeholders:
        *   `source_db_server_name`: Coloque o IP público do seu Homelab.
        *   `source_db_password`: Coloque a senha do seu banco de dados PostgreSQL no Homelab.
        *   `target_db_password`: Coloque a senha do Aurora que você obteve no Dia 1.
    *   **Edite `main.tf`:** Volte ao arquivo `terraform/aws/environments/dev/main.tf` e descomente o bloco do módulo `dms`.

### Tarde (4-5 horas): Execução e Monitoramento

1.  **Segundo Deploy (Recursos DMS):**
    *   Execute o script de deploy novamente:
        ```bash
        ./deploy.sh
        ```
    *   O Terraform irá planejar a criação dos recursos do DMS (Instância de Replicação, Endpoints, Tarefa). Revise e aprove.
    *   **Aguarde:** A criação da instância de replicação do DMS pode levar de 5 a 10 minutos.

2.  **Execução da Migração:**
    *   Com os recursos do DMS criados, inicie a migração com o script:
        ```bash
        ./migrate.sh
        ```
    *   O script irá iniciar a tarefa de replicação do DMS.

3.  **Monitoramento no Console da AWS:**
    *   Acesse o console da AWS -> **Database Migration Service (DMS)**.
    *   No menu à esquerda, clique em **Tarefas de migração de banco de dados**.
    *   Clique na sua tarefa (`fluxo-caixa-replication-task`) e monitore o progresso na aba **Detalhes da tarefa** e **Estatísticas da tabela**.
    *   Aguarde o status da "Carga total" mudar para **Concluído**.

4.  **Validação Inicial:**
    *   Use o script `./connect.sh` para se conectar ao Aurora.
    *   Execute algumas consultas simples para verificar se os dados estão lá:
        ```sql
        -- Verifique o número de registros nas tabelas principais
        SELECT 'transacoes' AS tabela, COUNT(*) FROM transacoes
        UNION ALL
        SELECT 'contas', COUNT(*) FROM contas
        UNION ALL
        SELECT 'categorias', COUNT(*) FROM categorias;

        -- Verifique alguns dados recentes
        SELECT * FROM transacoes ORDER BY data DESC LIMIT 10;
        ```

**Resultado ao Final do Dia 2:** Você terá executado uma migração de banco de dados do seu ambiente local para a nuvem AWS, orquestrando tudo com Terraform e DMS. Você terá validado que os dados foram copiados com sucesso.

---

## Dia 3: Validação, Limpeza e Consolidação do Conhecimento

**Objetivo do Dia:** Realizar uma validação mais aprofundada dos dados, destruir toda a infraestrutura para evitar custos e revisar o que foi aprendido.

### Manhã (3-4 horas): Validação Aprofundada e Testes

1.  **Scripts de Validação:**
    *   Conecte-se simultaneamente ao seu banco de dados do Homelab e ao Aurora.
    *   Execute consultas mais complexas em ambos os bancos e compare os resultados. Foque em:
        *   Views (`SELECT * FROM vw_saldo_diario_por_conta;`)
        *   Funções (`SELECT * FROM fn_extrato_conta(1, '2023-01-01', '2023-12-31');`)
        *   Procedures (se aplicável, chame-as e verifique os resultados).
    *   O objetivo é garantir que a lógica de negócio (views, funções) foi migrada corretamente e produz os mesmos resultados.

2.  **Análise de Logs (Opcional):**
    *   No console do DMS, selecione sua tarefa e vá para a aba **Logs do CloudWatch**. Explore os logs para entender como o DMS registra o processo de migração.

### Tarde (2-3 horas): Destruição e Revisão

1.  **Destruição da Infraestrutura:**
    *   **IMPORTANTE:** Esta é a etapa final para garantir que você não incorra em custos desnecessários.
    *   Execute o script de destruição:
        ```bash
        ./destroy.sh
        ```
    *   Digite `sim` quando solicitado para confirmar a destruição.
    *   **Aguarde:** O processo pode levar de 15 a 20 minutos.
    *   **Verificação Final:** Após a conclusão, acesse o console da AWS (VPC, RDS, DMS) para confirmar que todos os recursos foram removidos.

2.  **Revisão e Consolidação:**
    *   Releia o código Terraform e os scripts.
    *   Anote os principais aprendizados, desafios e "pegadinhas" que você encontrou.
    *   Pense em como você aplicaria isso em um ambiente de produção real (ex: uso de `terraform.tfvars` para produção, `deletion_protection = true`, múltiplos NAT Gateways, etc.).

**Resultado ao Final do Dia 3:** Você terá completado o ciclo de vida de um projeto de IaC, desde o provisionamento, passando pela execução da tarefa principal (migração), até a validação e o descomissionamento seguro da infraestrutura, consolidando seu conhecimento prático para o projeto real da próxima semana.
'''
