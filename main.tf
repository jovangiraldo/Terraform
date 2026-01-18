terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Busca automáticamente una AMI válida en la región
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "nginx-server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  tags = {
    Name = "nginx-server"
  }

#Instala y configura Nginx al iniciar la instancia
    user_data = <<-EOF
                #!/bin/bash
                sudo yum update -y
                sudo amazon-linux-extras install nginx1 -y
                sudo systemctl start nginx
                sudo systemctl enable nginx
                EOF

    # Nombre de la clave SSH para acceder a la instancia
    key_name = aws_key_pair.nginx-server-ssh.key_name          
    # referencia al grupo de seguridad creado  
    vpc_security_group_ids = [aws_security_group.nginx-sg.id]
}

# Configura el grupo de seguridad para permitir tráfico HTTP y SSH
# Asocia el grupo de seguridad a la instancia EC2 (agregar vpc_security_group_ids en aws_instance)
# Para obtener el ID del VPC predeterminado, puedes usar el data source aws_vpc
# abre los puertos 22 (SSH) y 80 (HTTP) en el grupo de seguridad

resource "aws_security_group" "nginx-sg" {
  name        = "nginx-sg"
  description = "Allow HTTP and SSH traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } 
  
  ingress {
    from_port   = 80
    to_port     = 80
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


#para crear una clave SSH y poder acceder a la instancia
#1)Nombre del servidor o tag definido
# para generar llave  ssh primero hay que generarla en la maquina:  ssh-keygen -t rsa -b 2048 -f "nginx-server.key"

#2) Crear el recurso de par de claves en AWS usando la clave pública generada
#3) Asociar el par de claves a la instancia EC2 (agregar key_name en aws_instance)
resource "aws_key_pair" "nginx-server-ssh" {
  key_name = "nginx-server-ssh"
  public_key = file("nginx-server.key.pub")
}

output "ami_usada" {
  value = data.aws_ami.amazon_linux.id
}
