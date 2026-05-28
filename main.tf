provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's official AWS Account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ------------------------------------------------------
# Security Group
# ------------------------------------------------------
resource "aws_security_group" "minecraft_k3s_sg" {
  name        = "minecraft-k3s-security-group"
  description = "Minimalist SG for k3s Minecraft server"

  ingress {
    description = "SSH administrative access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_PERSONAL_PUBLIC_IP/32"] 
  }

  ingress {
    description = "Minecraft game traffic"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------
# EC2 Instance
# ------------------------------------------------------
resource "aws_instance" "minecraft_node" {
  ami                  = "ami-0c7217cdde317cfec" 
  instance_type        = "t3.medium"             
  security_groups      = [aws_security_group.minecraft_k3s_sg.name]
  iam_instance_profile = "YourExistingOps3Profile" 

  user_data = file("${path.module}/bootstrap.sh")

  tags = {
    Name = "Minecraft-k3s-Host"
  }
}

resource "aws_security_group" "minecraft_sg" {
  name        = "minecraft-server-sg"
  description = "Allow SSH and Minecraft traffic"
  vpc_id      = data.aws_vpc.default.id

  # SSH for Ansible and Admin
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # minecraft traffic
  ingress {
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound traffic (Needed for updates/Docker pulls)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. EC2 Instance
resource "aws_instance" "mc_server" {
  ami                  = data.aws_ami.ubuntu.id  #"ami-0c7217cdde317cfec"  Ubuntu 22.04 LTS (Verify latest in your region)
  instance_type        = "t3.medium"             # Minimum 4GB RAM recommended for Minecraft

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  key_name             = var.key_name            # Reference your existing .pem key name
  iam_instance_profile = "LabInstanceProfile"    # Required for ECR/S3 access without keys
  
  vpc_security_group_ids = [aws_security_group.minecraft_sg.id]

  tags = {
    Name = "minecraftTake2"
  }

  # 4. Trigger Ansible Hand-off
  # This runs after the instance is "ready" according to AWS. 
  provisioner "local-exec" {
    command = <<EOT
      sleep 60 && \
      ansible-playbook -i '${self.public_ip},' \
      --private-key ${var.private_key_path} \
      -u ubuntu \
      playbook.yml
    EOT
  }
}

# 5. Outputs
output "instance_public_ip" {
  value = aws_instance.mc_server.public_ip
}
