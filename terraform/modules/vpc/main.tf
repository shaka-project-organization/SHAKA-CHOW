# ============================================================
# FILE: terraform/modules/vpc/main.tf
# PURPOSE: Builds the entire network foundation.
# Everything runs inside this VPC — EKS nodes, ALB, database.
# The three-tier subnet design isolates each layer:
#   PUBLIC   → only internet-facing resources (ALB, NAT GW)
#   PRIVATE  → compute (EKS pods, worker nodes)
#   ISOLATED → data (MongoDB, RDS — no internet access at all)
# ============================================================

# ─────────────────────────────────────────────
# VPC
# The top-level network boundary.
# All resources in this project live inside this VPC.
# Resources in different VPCs cannot communicate unless
# you explicitly set up VPC Peering or Transit Gateway.
# ─────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  # 10.0.0.0/16 gives 65,536 IP addresses to distribute
  # across all subnets in all AZs.

  # enable_dns_hostnames: assigns DNS names like
  # "ec2-10-0-1-50.compute-1.amazonaws.com" to instances.
  # Required for EKS nodes to resolve each other by hostname
  # and for the EKS control plane to communicate with nodes.
  enable_dns_hostnames = true

  # enable_dns_support: enables the Route 53 Resolver inside
  # the VPC so resources can resolve AWS service endpoints
  # (e.g. ecr.us-east-1.amazonaws.com, s3.amazonaws.com).
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name}-vpc"
    # These two tags are REQUIRED for the AWS Load Balancer
    # Controller to discover this VPC and place ALBs in it.
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# ─────────────────────────────────────────────
# INTERNET GATEWAY
# Attaches to the VPC and provides a path for
# public subnet resources to reach the internet.
# The Internet Gateway is highly available by default —
# AWS manages redundancy for you.
# Only resources in PUBLIC subnets use this directly.
# Private subnet resources go through the NAT Gateway.
# ─────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# ─────────────────────────────────────────────
# PUBLIC SUBNETS
# One per AZ. The ALB spans both for high availability.
# "count" creates one subnet per element in the list.
# count.index is the loop counter: 0, 1, ...
# ─────────────────────────────────────────────
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  # length(["10.0.1.0/24", "10.0.2.0/24"]) = 2
  # So this creates 2 subnets.

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # map_public_ip_on_launch: automatically assigns a public IP
  # to any instance launched in this subnet.
  # The ALB needs public IPs to receive traffic from the internet.
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name}-public-${var.availability_zones[count.index]}"
    # "elb" tag tells the AWS Load Balancer Controller
    # that internet-facing ALBs can be placed in this subnet.
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# ─────────────────────────────────────────────
# PRIVATE SUBNETS
# EKS worker nodes live here.
# No public IPs. Outbound internet goes through NAT GW.
# Inbound traffic only comes from the ALB.
# ─────────────────────────────────────────────
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # No public IPs — private resources must not be
  # reachable directly from the internet.
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.cluster_name}-private-${var.availability_zones[count.index]}"
    # "internal-elb" tag allows internal-facing load balancers
    # (e.g. for internal services) to use private subnets.
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# ─────────────────────────────────────────────
# ISOLATED SUBNETS (DATABASE TIER)
# No internet access in any direction.
# No NAT Gateway route, no Internet Gateway route.
# Only accessible from the EKS node security group.
# ─────────────────────────────────────────────
resource "aws_subnet" "isolated" {
  count = length(var.isolated_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.isolated_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = false

  tags = {
    Name = "${var.cluster_name}-isolated-${var.availability_zones[count.index]}"
    Tier = "database"
  }
}

# ─────────────────────────────────────────────
# ELASTIC IPs FOR NAT GATEWAYS
# A NAT Gateway needs a static public IP address.
# We create one EIP per AZ — each NAT GW in each AZ
# gets its own EIP. This means private resources in
# us-east-1a use the NAT GW in us-east-1a, and vice
# versa. If one AZ fails, the other AZ's NAT GW
# continues working independently.
# "domain = vpc" is required for EIPs used with NAT GWs.
# ─────────────────────────────────────────────
resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  # The EIP must be created after the Internet Gateway exists.
  # This is an explicit dependency Terraform can't infer automatically.
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.cluster_name}-nat-eip-${var.availability_zones[count.index]}"
  }
}

# ─────────────────────────────────────────────
# NAT GATEWAYS
# One per AZ, placed in the PUBLIC subnet of that AZ.
# Private subnet resources send outbound traffic here.
# The NAT GW forwards it to the Internet Gateway using
# the Elastic IP as the source address, then returns
# the response to the originating private resource.
# This lets EKS nodes pull from ECR and npm registries
# without being reachable from the internet.
# ─────────────────────────────────────────────
resource "aws_nat_gateway" "main" {
  count = length(var.availability_zones)

  # connectivity_type = "public" means this NAT GW uses
  # an EIP and can reach the public internet.
  connectivity_type = "public"

  # Place in the public subnet of the same AZ
  subnet_id     = aws_subnet.public[count.index].id
  allocation_id = aws_eip.nat[count.index].id

  tags = {
    Name = "${var.cluster_name}-nat-${var.availability_zones[count.index]}"
  }
}

# ─────────────────────────────────────────────
# ROUTE TABLE — PUBLIC SUBNETS
# One route table shared by both public subnets.
# Default route (0.0.0.0/0) goes to the Internet Gateway.
# This is what makes a subnet "public" — the default
# route points to the IGW, not a NAT GW.
# ─────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    # All traffic not destined for the VPC CIDR (10.0.0.0/16)
    # goes to the Internet Gateway — i.e., to the internet.
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.cluster_name}-rt-public"
  }
}

# Associate the public route table with EACH public subnet.
# Without this association, the subnet uses the VPC's
# default route table, which has no internet route.
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ─────────────────────────────────────────────
# ROUTE TABLES — PRIVATE SUBNETS (one per AZ)
# Each private subnet gets its own route table
# pointing to the NAT Gateway IN THE SAME AZ.
# This is important for high availability: if us-east-1a's
# NAT GW fails, us-east-1b's private subnet isn't affected.
# ─────────────────────────────────────────────
resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    # Route outbound traffic to the NAT GW in the same AZ.
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.cluster_name}-rt-private-${var.availability_zones[count.index]}"
  }
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ─────────────────────────────────────────────
# ROUTE TABLE — ISOLATED SUBNETS
# One route table with NO routes to the internet.
# The VPC local route (10.0.0.0/16 → local) exists
# implicitly in every route table. Isolated resources
# can only communicate with other resources in the VPC.
# ─────────────────────────────────────────────
resource "aws_route_table" "isolated" {
  vpc_id = aws_vpc.main.id

  # No routes added here — only the implicit local route exists.
  # Traffic can reach other VPC resources but not the internet.

  tags = {
    Name = "${var.cluster_name}-rt-isolated"
  }
}

resource "aws_route_table_association" "isolated" {
  count = length(aws_subnet.isolated)

  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated.id
}
