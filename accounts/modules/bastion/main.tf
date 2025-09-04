
data "aws_ssm_parameter" "this" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

resource "aws_instance" "this" {
  ami                  = data.aws_ssm_parameter.this.value
  instance_type        = "t2.nano"
  subnet_id            = var.subnet_id
  iam_instance_profile = aws_iam_instance_profile.this.name

  vpc_security_group_ids = [aws_security_group.this.id]

  user_data = <<-EOF
    #!/bin/bash
    # SSHサーバーのセットアップ
    sudo yum install -y openssh-server
    sudo systemctl enable sshd
    sudo systemctl start sshd

    # パスワード認証を無効化
    sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

    # ルートログインを禁止
    sudo sed -i 's/^#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

    # 設定変更の反映
    sudo systemctl restart sshd

    # ユーザーの作成と公開鍵の登録
    sudo useradd -m ec2-user
    sudo mkdir -p /home/ec2-user/.ssh
    echo "DUMMY_PUBLIC_SSH_KEY" > /home/ec2-user/.ssh/authorized_keys
    sudo chmod 600 /home/ec2-user/.ssh/authorized_keys
    sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh

    sudo yum install -y amazon-ssm-agent
    sudo systemctl enable amazon-ssm-agent
    sudo systemctl start amazon-ssm-agent
    sudo amazon-linux-extras enable postgresql14
    sudo yum install -y postgresql
  EOF

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Terraform = "true"
  }
}

resource "aws_eip" "this" {
  instance = aws_instance.this.id
  domain   = "vpc"

  tags = {
    Terraform = "true"
  }
}


resource "aws_security_group" "this" {
  name   = "security-group-bastion"
  vpc_id = var.vpc_id

  // bastionへのアクセスは公開鍵認証方式となっている
  ingress {
    description = "Allow SSH from anywhere"
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

  tags = {
    Terraform = "true"
  }
}


resource "aws_iam_role" "this" {
  name = "Bastion"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Terraform = "true"
  }
}

resource "aws_iam_instance_profile" "this" {
  name = "iam-instance-profile-bastion"
  role = aws_iam_role.this.name

  tags = {
    Terraform = "true"
  }
}

data "aws_iam_policy" "this" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = data.aws_iam_policy.this.arn
}
