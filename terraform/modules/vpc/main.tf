locals {
  az_count = length(var.availability_zones)
}

resource "aws_vpc" "ninja" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.name
  }
}

resource "aws_internet_gateway" "ninja" {
  vpc_id = aws_vpc.ninja.id

  tags = {
    Name = "${var.name}-igw"
  }
}

resource "aws_subnet" "public" {
  count = local.az_count

  vpc_id                  = aws_vpc.ninja.id
  availability_zone       = var.availability_zones[count.index]
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-public-${count.index + 1}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  count = local.az_count

  vpc_id            = aws_vpc.ninja.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = var.private_subnet_cidrs[count.index]

  tags = {
    Name = "${var.name}-private-${count.index + 1}"
    Tier = "application"
  }
}

resource "aws_subnet" "database" {
  count = local.az_count

  vpc_id            = aws_vpc.ninja.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = var.database_subnet_cidrs[count.index]

  tags = {
    Name = "${var.name}-database-${count.index + 1}"
    Tier = "database"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.ninja.id

  tags = {
    Name = "${var.name}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ninja.id
}

resource "aws_route_table_association" "public" {
  count = local.az_count

  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}

resource "aws_eip" "nat" {
  count = var.single_nat_gateway ? 1 : local.az_count

  domain = "vpc"

  tags = {
    Name = "${var.name}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "ninja" {
  count = var.single_nat_gateway ? 1 : local.az_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[var.single_nat_gateway ? 0 : count.index].id

  depends_on = [aws_internet_gateway.ninja]

  tags = {
    Name = "${var.name}-nat-${count.index + 1}"
  }
}

resource "aws_route_table" "private" {
  count = var.single_nat_gateway ? 1 : local.az_count

  vpc_id = aws_vpc.ninja.id

  tags = {
    Name = "${var.name}-private-rt-${count.index + 1}"
  }
}

resource "aws_route" "private_nat" {
  count = var.single_nat_gateway ? 1 : local.az_count

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ninja[var.single_nat_gateway ? 0 : count.index].id
}

resource "aws_route_table_association" "private" {
  count = local.az_count

  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
  subnet_id      = aws_subnet.private[count.index].id
}

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.ninja.id

  tags = {
    Name = "${var.name}-database-rt"
  }
}

resource "aws_route_table_association" "database" {
  count = local.az_count

  route_table_id = aws_route_table.database.id
  subnet_id      = aws_subnet.database[count.index].id
}
