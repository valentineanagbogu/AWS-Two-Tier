# Outputs
# Ec2 instance public ipv4 address
output "ec2_public_ip" {
  value = aws_instance.web-server-1.public_ip
}

# Db instance address
output "db_instance_address" {
  value = aws_db_instance.mysqldb.address
}

# Getting the DNS of load balancer
output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.alb.dns_name
}
