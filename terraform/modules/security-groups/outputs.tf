# terraform/modules/security-groups/outputs.tf
output "alb_sg_id"      { value = aws_security_group.alb.id }
output "node_sg_id"     { value = aws_security_group.nodes.id }
output "database_sg_id" { value = aws_security_group.database.id }
