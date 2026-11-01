output "function_names" {
  value = {
    api_handler      = aws_lambda_function.api_handler.function_name
    orders_worker    = aws_lambda_function.orders_worker.function_name
    inventory_worker = aws_lambda_function.inventory_worker.function_name
  }
}

output "function_arns" {
  value = {
    api_handler      = aws_lambda_function.api_handler.arn
    orders_worker    = aws_lambda_function.orders_worker.arn
    inventory_worker = aws_lambda_function.inventory_worker.arn
  }
}

output "function_invoke_arns" {
  value = {
    api_handler      = aws_lambda_function.api_handler.invoke_arn
    orders_worker    = aws_lambda_function.orders_worker.invoke_arn
    inventory_worker = aws_lambda_function.inventory_worker.invoke_arn
  }
}
