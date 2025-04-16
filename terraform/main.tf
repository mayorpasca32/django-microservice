provider "aws" {
  region  = "us-east-2"
  profile = "default"
}

resource "tls_private_key" "k8s" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "k8s_key" {
  key_name   = "k8s-key"
  public_key = tls_private_key.k8s.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.k8s.private_key_pem
  filename = "${path.module}/k8s-key.pem"
  file_permission = "0600"
}

resource "aws_security_group" "k8s_sg" {
  name        = "k8s-ssh-sg"
  description = "Allow SSH and Kubernetes ports"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
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

data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "k8s_node" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.medium"
  key_name                    = aws_key_pair.k8s_key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.k8s_sg.id]

  provisioner "remote-exec" {
    inline = [
      "sleep 30",
      "sudo apt-get update -y",
      "sudo apt-get install -y curl apt-transport-https ca-certificates gnupg lsb-release software-properties-common",
      "sudo apt-get install -y docker.io",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg",
      "echo 'deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update -y",
      "sudo apt-get install -y kubelet kubeadm kubectl",
      "sudo kubeadm init --pod-network-cidr=10.244.0.0/16 || true",   # prevents hard fail on exit 1
      "mkdir -p /home/ubuntu/.kube",
      "sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config",
      "sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config",
      "kubectl version --client",  # test it works
      "kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml || true"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.k8s.private_key_pem
      host        = self.public_ip
      timeout     = "3m"
    }
  }

  tags = {
    Name = "K8sNode"
  }
}

output "public_ip" {
  value = aws_instance.k8s_node.public_ip
}

output "k8s_private_key_pem" {
  value     = tls_private_key.k8s.private_key_pem
  sensitive = true
}
