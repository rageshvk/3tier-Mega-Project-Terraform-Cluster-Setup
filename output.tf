output "cluster_id" {
  value = aws_eks_cluster.rvk.id
}

output "node_group_id" {
  value = aws_eks_node_group.rvk.id
}

output "vpc_id" {
  value = aws_vpc.rvk_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.rvk_subnet[*].id
}
