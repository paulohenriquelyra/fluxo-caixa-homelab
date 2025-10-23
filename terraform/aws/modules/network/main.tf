'''
# ==============================================================================
# MÓDULO TERRAFORM: REDE AWS (VPC, Subnets, Roteamento)
# ==============================================================================
#
# Este módulo encapsula a criação de uma infraestrutura de rede fundamental na AWS.
# Ele é projetado para ser reutilizável e configurável para diferentes ambientes.
#
# Arquitetura do Módulo:
# 1.  **aws_vpc**: Cria uma Virtual Private Cloud, que é o contêiner de rede isolado
#     para todos os outros recursos.
# 2.  **aws_subnet (Públicas e Privadas)**: Divide a VPC em sub-redes. As sub-redes
#     públicas são para recursos que precisam de acesso direto à internet (como
#     NAT Gateways), enquanto as sub-redes privadas são para recursos que devem
#     permanecer isolados (como bancos de dados).
# 3.  **aws_internet_gateway**: Permite que a VPC se comunique com a internet.
# 4.  **aws_nat_gateway**: Permite que recursos em sub-redes privadas iniciem
#     comunicação com a internet (ex: para atualizações), mas impede que a internet
#     inicie conexões com eles.
# 5.  **aws_route_table**: Define as regras de roteamento para o tráfego de rede,
#     direcionando o tráfego da sub-rede para o gateway apropriado (Internet ou NAT).
#
# O módulo utiliza `count` e a fonte de dados `aws_availability_zones` para criar
# automaticamente uma arquitetura de alta disponibilidade, distribuindo sub-redes
# em múltiplas Zonas de Disponibilidade (AZs).

# ==============================================================================
# FONTES DE DADOS (Data Sources)
# ==============================================================================

# Bloco de dados para obter as zonas de disponibilidade (AZs) disponíveis na região selecionada.
# Isso torna o código dinâmico e resiliente, pois não fixa as AZs, adaptando-se a qualquer região.
data "aws_availability_zones" "available" {
  state = "available"
}

# ==============================================================================
# RECURSO: REDE VIRTUAL PRIVADA (VPC)
# ==============================================================================
# A VPC é o alicerce da sua rede na AWS. Ela fornece um ambiente de rede isolado.

resource "aws_vpc" "main" {
  # O bloco CIDR define o intervalo de IPs privados para a VPC. `10.0.0.0/16` fornece
  # 65,536 endereços IP, um tamanho comum para muitas aplicações.
  cidr_block = var.vpc_cidr

  # Habilita a resolução de DNS dentro da VPC, permitindo que os recursos se comuniquem
  # usando nomes de DNS privados (ex: ip-10-0-1-12.ec2.internal).
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-vpc"
    }
  )
}

# ==============================================================================
# RECURSO: SUB-REDES PÚBLICAS
# ==============================================================================
# Sub-redes com rota para o Internet Gateway. Usadas para NAT Gateways, Bastions, etc.

resource "aws_subnet" "public" {
  # Cria 2 sub-redes públicas, uma em cada uma das duas primeiras AZs disponíveis.
  count = 2

  vpc_id            = aws_vpc.main.id
  # `cidrsubnet` calcula os blocos CIDR para as sub-redes a partir do CIDR da VPC.
  # Aqui, criamos sub-redes /24 (256 IPs) para as sub-redes públicas.
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  # Atribui um IP público automaticamente a instâncias lançadas aqui.
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-public-subnet-${data.aws_availability_zones.available.names[count.index]}"
    }
  )
}

# ==============================================================================
# RECURSO: SUB-REDES PRIVADAS
# ==============================================================================
# Sub-redes sem rota direta para a internet. Usadas para bancos de dados e aplicações.

resource "aws_subnet" "private" {
  # Cria 2 sub-redes privadas, garantindo alta disponibilidade para o banco de dados.
  count = 2

  vpc_id            = aws_vpc.main.id
  # O offset `2` no `cidrsubnet` garante que os CIDRs das sub-redes privadas não
  # se sobreponham aos das públicas (que usaram index 0 e 1).
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-private-subnet-${data.aws_availability_zones.available.names[count.index]}"
    }
  )
}

# ==============================================================================
# RECURSOS DE ROTEAMENTO
# ==============================================================================

# Internet Gateway (IGW): Permite a comunicação entre a VPC e a internet.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-igw"
    }
  )
}

# Elastic IP (EIP) e NAT Gateway: Permitem que instâncias em sub-redes privadas
# acessem a internet de forma segura.
# ATENÇÃO: NAT Gateways têm um custo considerável (~$32/mês por gateway).
# Para este laboratório, criamos apenas um para reduzir custos, mas em produção
# você criaria um por AZ para alta disponibilidade.
resource "aws_eip" "nat" {
  domain   = "vpc"
  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-nat-eip"
    }
  )
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  # O NAT Gateway deve residir em uma sub-rede pública.
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-nat-gw"
    }
  )

  # Garante que o IGW seja criado antes do NAT Gateway.
  depends_on = [aws_internet_gateway.main]
}

# Tabela de Rota Pública: Direciona o tráfego destinado à internet (0.0.0.0/0) para o IGW.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-public-rt"
    }
  )
}

# Tabela de Rota Privada: Direciona o tráfego destinado à internet para o NAT Gateway.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-private-rt"
    }
  )
}

# Associações: Conectam as tabelas de rota às suas respectivas sub-redes.
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
'''
