
resource "aws_security_group" "alb" {
  name        = "shakachow-alb-sg"
  description = "Security group for the Application Load Balancer. Accepts HTTP and HTTPS from the internet."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # 0.0.0.0/0 means any IPv4 address — the entire internet.
  }


  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"      # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "shakachow-alb-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "nodes" {
  name        = "shakachow-node-sg"
  description = "Security group for EKS worker nodes. Only accepts traffic from the ALB and other nodes."
  vpc_id      = var.vpc_id

  ingress {
    description              = "All traffic from ALB"
    from_port                = 0
    to_port                  = 0
    protocol                 = "-1"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Node-to-node communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true

  }

  ingress {
    description = "EKS control plane to nodes"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {
    description = "All outbound traffic via NAT Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "shakachow-node-sg"
    Environment = var.environment
    "kubernetes.io/cluster/shakachow-cluster" = "owned"
  }
}

resource "aws_security_group" "database" {
  name        = "shakachow-db-sg"
  description = "Security group for database tier. Only EKS nodes can connect."
  vpc_id      = var.vpc_id 
  ingress {
    description              = "MongoDB from EKS nodes"
    from_port                = 27017
    to_port                  = 27017
    protocol                 = "tcp"
    security_groups = [aws_security_group.nodes.id]
  }


  egress {
    description              = "Responses to EKS nodes"
    from_port                = 0
    to_port                  = 0
    protocol                 = "-1"
    security_groups = [aws_security_group.nodes.id]
  }

  tags = {
    Name        = "shakachow-db-sg"
    Environment = var.environment
    Tier        = "database"
  }
}
