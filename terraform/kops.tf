resource "local_file" "kops_cluster_config" {
  content = templatefile("${path.module}/kops/cluster.yaml.tpl", {
    vpc_id               = aws_vpc.main.id
    vpc_cidr             = var.vpc_cidr
    azs                  = data.aws_availability_zones.available.names
    private_subnet_ids   = aws_subnet.private[*].id
    private_subnet_cidrs = aws_subnet.private[*].cidr_block
    public_subnet_ids    = aws_subnet.public[*].id
    public_subnet_cidrs  = aws_subnet.public[*].cidr_block
  })

  filename = "${path.module}/kops/cluster.yaml"
}
