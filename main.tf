terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.59.0"
    }
  }

   backend "s3" {

    bucket="tfstatemihailo"
    key="terraforms3prem.tfstate"
    region="eu-central-1"
  
  }
}

provider "aws" {
region="eu-central-1"
}






resource "aws_s3_bucket" "my_s3_bucket" {

  bucket = "mihailos3bucketforediting"
  acl = "private"

  versioning {
    enabled = true
  }

}


//aws role za ec2 innstancu
resource "aws_iam_role" "s3_access_role_for_ec2" { //rola za ec2 instance profile
  name = "s3_access_role_for_ec2_instance"       

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com" //za ec2 instancu
        }
      },
    ]
  })

}

//IAM roles za policy , gde smo samo dodali jos policies na ec2 role
resource "aws_iam_role_policy" "s3_limited_access" { //policy dodat na rolu
  name = "s3_limited_access"
  role = aws_iam_role.s3_access_role_for_ec2.id

 

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {//iam role instance profile za ec2. u iam dodati policy koji omogcuju ec2 instanci da pristupi s3 = pristup resursu bez dodavanja kljuca npr. pa tako ec2 sme da pristupi s3-u  //neka moze da izlista sve
        Action = [
          "s3:ListAllMyBuckets",
        ]
        Effect   = "Allow"
        Resource = "*"
      },{ //rw samo nad gore napravljenim bucketom
        Action = [
            "s3:ListBucket",
            "s3:GetObject",
            "s3:PutObject"

        ]
        Effect = "Allow"
        Resource = ["arn:aws:s3:::${aws_s3_bucket.my_s3_bucket.bucket}","arn:aws:s3:::${aws_s3_bucket.my_s3_bucket.bucket}/*" ]
      }
    ]
  })
}
     




resource "aws_security_group" "ec2_sg" {
  name   = "ec2_sg_onee1"
  description = "Security group for EC2 instance." 
  vpc_id = "vpc-0769af89e3dff6849"



  ingress {
    from_port   =  22
    to_port     =  22
    protocol    = "tcp" 
    cidr_blocks = ["0.0.0.0/0"]  
  }

 egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1" 
    cidr_blocks     = ["0.0.0.0/0"]
    //prefix_list_ids = []
  }

}


//pravjenje iam instance profila na osnovu role
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_instance_profilee"
  role = aws_iam_role.s3_access_role_for_ec2.name
}


resource "aws_instance" "aws_instance_1" {

ami="ami-0e872aee57663ae2d"
instance_type="t2.micro"
subnet_id = "subnet-0c988bbc1a2d11109"
associate_public_ip_address = true
key_name = "first_key"
iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
security_groups = [aws_security_group.ec2_sg.id] 
}





resource "aws_security_group" "db_sg" {
  name        = "db_sg_one"
  description = "Security group for db"
 
  vpc_id = "vpc-0769af89e3dff6849"
  
  ingress {
    from_port   =  3306
    to_port     =  3306
    protocol    = "tcp" 
    security_groups = [ aws_security_group.ec2_sg.id ]  
  }
 
}



resource "aws_db_subnet_group" "subnet_group" {
  name       = "dbsubnetgroup"
  subnet_ids = ["subnet-0c988bbc1a2d11109","subnet-0c43693d56d99314e"] // 2 subnets

  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_db_instance" "rds_db" {
   allocated_storage = 20
  db_name              = "rdsdb"
  engine               = "mysql"
  engine_version       = "8.0.35"
  instance_class       = "db.t3.micro"
  username             = "admin"
  password             = "admin12345"
  skip_final_snapshot = true
  db_subnet_group_name = aws_db_subnet_group.subnet_group.name //!!!
  vpc_security_group_ids = [aws_security_group.db_sg.id]  
}

