variable "queue_name" {
  type = string
}

resource "aws_sqs_queue" "events" {
  name                       = var.queue_name
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20

  tags = {
    Name = var.queue_name
  }
}

output "sqs_queue_url" {
  value = aws_sqs_queue.events.id
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.events.arn
}

