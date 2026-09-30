
######### AWS subnet#################
resource "aws_vpc" "main"{
    cidr_block= "10.0.0.0/16"
    enable_dns_support= true
    enable_dns_hostnames= true

    tags= {
        Name=  "devops-prod-vpc"
    }

}


############first public subnet ###############


resource "aws_subnet" "public_1"{
    vpc_id = aws_vpc.main.id
    cidr_block= "10.0.1.0/24"
    availability_zone= "eu-north-1a"

    tags={
        Name= "devops-prod-public-1"
    }
}


###########second public subnet#############

resource "aws_subnet" "public_2"{
    cidr_block= "10.0.2.0/24"
    vpc_id= aws_vpc.main.id
    availability_zone= "eu-north-1b"

    tags= {
        Name= "devops-prod-public-2"
    }
}

###########first private subnet##############

resource "aws_subnet" "private_1"{
    vpc_id= aws_vpc.main.id
    cidr_block= "10.0.11.0/24"
    availability_zone= "eu-north-1a"

    tags={
        Name= "devops-prod-private-1"
    }
}

############second  private subnet###############

resource "aws_subnet" "private_2" {
    vpc_id= aws_vpc.main.id
    cidr_block= "10.0.12.0/24"
    availability_zone= "eu-north-1b"

    tags={
        Name= "devops-prod-private-2"
    }
}

##############  Internet Gateway ################


resource "aws_internet_gateway" "main"{
    vpc_id= aws_vpc.main.id

    tags={
        Name= "devops-prod-igw"
    }
}

######### Route table ######################

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main.id
    }

    tags = {
        Name = "devops-prod-public-rt"
    }
}


########### Public Table 1 association ###############


resource "aws_route_table_association" "public_1" {
    subnet_id      = aws_subnet.public_1.id
    route_table_id = aws_route_table.public.id
}

########### Public Table 2 association ###############

resource "aws_route_table_association" "public_2"{
    subnet_id= aws_subnet.public_2.id
    route_table_id= aws_route_table.public.id
}


############# NAT Gateway for public EIP ################

resource "aws_eip" "nat" {
    domain= "vpc"

    tags={
        Name= "devops-prod-nat-eip"
    }
}


############ NAT Gateway Resource ###################



resource "aws_nat_gateway" "main" {
    allocation_id = aws_eip.nat.id
    subnet_id     = aws_subnet.public_1.id
    depends_on = [aws_internet_gateway.main]

    tags = {
        Name = "devops-prod-nat"
    }
}


############## private route table ###############



resource "aws_route_table" "private"{
    vpc_id= aws_vpc.main.id


    route{
        cidr_block= "0.0.0.0/0"
        nat_gateway_id= aws_nat_gateway.main.id
        
    }

    tags={
        Name= "devops-prod-private-rt"
    }

}

############ association private route table to private subnet ########

resource "aws_route_table_association" "private_1"{
    subnet_id= aws_subnet.private_1.id
    route_table_id = aws_route_table.private.id

}

resource "aws_route_table_association" "private_2" {
    subnet_id= aws_subnet.private_2.id
    route_table_id= aws_route_table.private.id
}