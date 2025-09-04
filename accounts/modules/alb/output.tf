output "lb" {
  value = aws_lb.this
}

output "lb_security_group_id" {
  value = aws_security_group.this.id
}

output "lb_target_group" {
  value = aws_lb_target_group.this
}
