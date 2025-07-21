provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "rvk_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "rvk-vpc"
  }
}

resource "aws_subnet" "rvk_subnet" {
  count = 2
  vpc_id                  = aws_vpc.rvk_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.rvk_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["ap-south-1a", "ap-south-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "rvk-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "rvk_igw" {
  vpc_id = aws_vpc.rvk_vpc.id

  tags = {
    Name = "rvk-igw"
  }
}

resource "aws_route_table" "rvk_route_table" {
  vpc_id = aws_vpc.rvk_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.rvk_igw.id
  }

  tags = {
    Name = "rvk-route-table"
  }
}

resource "aws_route_table_association" "rvk_association" {
  count          = 2
  subnet_id      = aws_subnet.rvk_subnet[count.index].id
  route_table_id = aws_route_table.rvk_route_table.id
}

resource "aws_security_group" "rvk_cluster_sg" {
  vpc_id = aws_vpc.rvk_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rvk-cluster-sg"
  }
}

resource "aws_security_group" "rvk_node_sg" {
  vpc_id = aws_vpc.rvk_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rvk-node-sg"
  }
}

resource "aws_eks_cluster" "rvk" {
  name     = "rvk-cluster"
  role_arn = aws_iam_role.rvk_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.rvk_subnet[*].id
    security_group_ids = [aws_security_group.rvk_cluster_sg.id]
  }
}


resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name    = aws_eks_cluster.rvk.name
  addon_name      = "aws-ebs-csi-driver"
  
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}


resource "aws_eks_node_group" "rvk" {
  cluster_name    = aws_eks_cluster.rvk.name
  node_group_name = "rvk-node-group"
  node_role_arn   = aws_iam_role.rvk_node_group_role.arn
  subnet_ids      = aws_subnet.rvk_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  instance_types = ["t2.medium"]

  remote_access {
    ec2_ssh_key = var.ssh_key_name
    source_security_group_ids = [aws_security_group.rvk_node_sg.id]
  }
}

resource "aws_iam_role" "rvk_cluster_role" {
  name = "rvk-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "rvk_cluster_role_policy" {
  role       = aws_iam_role.rvk_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "rvk_node_group_role" {
  name = "rvk-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "rvk_node_group_role_policy" {
  role       = aws_iam_role.rvk_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "rvk_node_group_cni_policy" {
  role       = aws_iam_role.rvk_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "rvk_node_group_registry_policy" {
  role       = aws_iam_role.rvk_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "rvk_node_group_ebs_policy" {
  role       = aws_iam_role.rvk_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
