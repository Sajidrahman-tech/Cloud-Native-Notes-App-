provider "aws" {
  region = "us-east-1"
}

# 🔄 Import backend output (API URL)
data "terraform_remote_state" "backend" {
  backend = "local"
  config = {
    path = "../backend/terraform.tfstate"
  }
}

# ✅ Create a Key Pair (for SSH if needed)
resource "aws_key_pair" "frontend_key" {
  key_name   = "frontend-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# ✅ Security Group to allow HTTP (80) and SSH (22)
resource "aws_security_group" "frontend_sg" {
  name        = "frontend-sg"
  description = "Allow HTTP and SSH"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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

# ✅ EC2 Instance for frontend
resource "aws_instance" "frontend_vm" {
  ami           = "ami-0c02fb55956c7d316" # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  key_name      = aws_key_pair.frontend_key.key_name
  security_groups = [aws_security_group.frontend_sg.name]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y git curl

              # Install Node.js
              curl -sL https://rpm.nodesource.com/setup_18.x | bash -
              sudo yum install -y nodejs

              # Clone the frontend app
              git clone https://github.com/Sajidrahman-tech/note-frontend.git /home/ec2-user/note-frontend

              cd /home/ec2-user/note-frontend

              # Inject backend API URL from Terraform
              echo "REACT_APP_API_BASE=${data.terraform_remote_state.backend.outputs.api_url}" > .env

              # Install and build
              npm install
              npm run build

              # Serve using serve package
              npm install -g serve
              serve -s build -l 80
            EOF

  tags = {
    Name = "React-Frontend-EC2"
  }
}

# ✅ Output public IP
output "frontend_public_ip" {
  value = aws_instance.frontend_vm.public_ip
}

output "frontend_app_url" {
  value = "http://${aws_instance.frontend_vm.public_ip}"
}
