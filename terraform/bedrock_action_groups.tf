# Action group for orchestrator to invoke other agents
resource "aws_bedrockagent_agent_action_group" "orchestrator_delegate" {
  action_group_name          = "invoke-specialized-agent"
  agent_id                   = aws_bedrockagent_agent.orchestrator.id
  agent_version              = "DRAFT"
  action_group_executor {
    lambda = aws_lambda_function.agent_invoker.arn
  }
  
  api_schema {
    payload = jsonencode({
      openapi = "3.0.0"
      info = {
        title   = "Agent Invocation"
        version = "1.0.0"
        description = "Invoke specialized agents for pipeline execution"
      }
      paths = {
        "/invoke-agent" = {
          post = {
            summary     = "Invoke a specialized agent"
            description = "Delegate work to Bootstrap, Compute, or App agent. The agent will use its MCP tools and knowledge base to complete the task."
            operationId = "invokeAgent"
            requestBody = {
              required = true
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                    properties = {
                      agent_type = {
                        type        = "string"
                        enum        = ["bootstrap", "compute", "app"]
                        description = "Which specialized agent to invoke"
                      }
                      instruction = {
                        type        = "string"
                        description = "Natural language instruction for the agent"
                      }
                      environment = {
                        type        = "string"
                        enum        = ["dev", "prod"]
                        description = "Target environment"
                      }
                      tenant_id = {
                        type        = "string"
                        description = "Tenant identifier (required for compute and app agents)"
                      }
                      parameters = {
                        type        = "object"
                        description = "Additional parameters for the agent"
                      }
                    }
                    required = ["agent_type", "instruction", "environment"]
                  }
                }
              }
            }
            responses = {
              "200" = {
                description = "Agent invocation result"
                content = {
                  "application/json" = {
                    schema = {
                      type = "object"
                      properties = {
                        agent_response = {
                          type = "string"
                          description = "Response from the invoked agent"
                        }
                        execution_id = {
                          type = "string"
                          description = "Pipeline execution ID if applicable"
                        }
                        status = {
                          type = "string"
                          description = "Execution status"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    })
  }
}

resource "aws_bedrockagent_agent_action_group" "orchestrator_memory" {
  action_group_name = "memory-operations"
  agent_id          = aws_bedrockagent_agent.orchestrator.id
  agent_version     = "DRAFT"
  
  action_group_executor {
    lambda = aws_lambda_function.memory_manager.arn
  }
  
  api_schema {
    payload = jsonencode({
      openapi = "3.0.0"
      info = {
        title   = "Memory Operations"
        version = "1.0.0"
      }
      paths = {
        "/memory/query" = {
          post = {
            summary     = "Query deployment history"
            description = "Get deployment history for environment or tenant"
            requestBody = {
              required = true
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                    properties = {
                      environment = {
                        type = "string"
                      }
                      tenant_id = {
                        type = "string"
                      }
                    }
                  }
                }
              }
            }
          }
        }
        "/memory/store" = {
          post = {
            summary     = "Store deployment record"
            description = "Save deployment information to memory"
            requestBody = {
              required = true
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                    properties = {
                      environment = {
                        type = "string"
                      }
                      tenant_id = {
                        type = "string"
                      }
                      pipeline_type = {
                        type = "string"
                      }
                      status = {
                        type = "string"
                      }
                      details = {
                        type = "object"
                      }
                    }
                    required = ["environment", "pipeline_type", "status"]
                  }
                }
              }
            }
          }
        }
      }
    })
  }
}

# MCP tools exposed as action groups for specialized agents
resource "aws_bedrockagent_agent_action_group" "bootstrap_mcp" {
  action_group_name = "mcp-pipeline-tools"
  agent_id          = aws_bedrockagent_agent.bootstrap.id
  agent_version     = "DRAFT"
  
  action_group_executor {
    lambda = aws_lambda_function.mcp_proxy.arn
  }
  
  api_schema {
    payload = jsonencode({
      openapi = "3.0.0"
      info = {
        title   = "Bootstrap Pipeline MCP Tools"
        version = "1.0.0"
        description = "MCP tools for executing bootstrap pipelines"
      }
      paths = {
        "/mcp/execute-bootstrap" = {
          post = {
            summary     = "Execute bootstrap pipeline via MCP"
            description = "Creates VPC, subnets, ACLs, and networking infrastructure"
            operationId = "executeBootstrapPipeline"
            requestBody = {
              required = true
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                    properties = {
                      environment = {
                        type = "string"
                        enum = ["dev", "prod"]
                        description = "Target environment"
                      }
                      region = {
                        type = "string"
                        description = "AWS region"
                        default = "us-east-1"
                      }
                    }
                    required = ["environment"]
                  }
                }
              }
            }
          }
        }
        "/mcp/get-status" = {
          post = {
            summary     = "Get pipeline execution status"
            description = "Check the status of a running pipeline"
            operationId = "getPipelineStatus"
            requestBody = {
              required = true
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                    properties = {
                      execution_id = {
                        type = "string"
                        description = "Pipeline execution ID"
                      }
                    }
                    required = ["execution_id"]
                  }
                }
              }
            }
          }
        }
      }
    })
  }
}

resource "aws_bedrockagent_agent_action_group" "compute_mcp" {
  action_group_name = "mcp-pipeline-tools"
  agent_id          = aws_bedrockagent_agent.compute.id
  agent_version     = "DRAFT"
  
  action_group_executor {
    lambda = aws_lambda_function.mcp_proxy.arn
  }
  
  api_schema {
    payload = jsonencode({
      openapi = "3.0.0"
      info = {
        title   = "Compute Pipeline MCP Tools"
        version = "1.0.0"
        description = "MCP tools for executing compute pipelines"
      }
      paths = {
        "/mcp/execute-compute" = {
          post = {
            summary     = "Execute compute pipeline via MCP"
            description = "Provisions EC2 instances for a tenant"
            operationId = "executeComputePipeline"
            requestBody = {
              required = true
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                    properties = {
                      environment = {
                        type = "string"
                        enum = ["dev", "prod"]
                      }
                      tenant_id = {
                        type = "string"
                        description = "Tenant identifier"
                      }
                      instance_type = {
                        type = "string"
                        description = "EC2 instance type"
                        default = "t3.medium"
                      }
                      instance_count = {
                        type = "integer"
                        description = "Number of instances"
                        default = 1
                      }
                    }
                    required = ["environment", "tenant_id"]
                  }
                }
              }
            }
          }
        }
        "/mcp/get-status" = {
          post = {
            summary     = "Get pipeline execution status"
            operationId = "getPipelineStatus"
            requestBody = {
              required = true
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                    properties = {
                      execution_id = { type = "string" }
                    }
                    required = ["execution_id"]
                  }
                }
              }
            }
          }
        }
      }
    })
  }
}

resource "aws_bedrockagent_agent_action_group" "app_mcp" {
  action_group_name = "mcp-pipeline-tools"
  agent_id          = aws_bedrockagent_agent.app.id
  agent_version     = "DRAFT"
  
  action_group_executor {
    lambda = aws_lambda_function.mcp_proxy.arn
  }
  
  api_schema {
    payload = jsonencode({
      openapi = "3.0.0"
      info = {
        title   = "App Pipeline MCP Tools"
        version = "1.0.0"
        description = "MCP tools for executing app deployment pipelines"
      }
      paths = {
        "/mcp/execute-app" = {
          post = {
            summary     = "Execute app deployment pipeline via MCP"
            description = "Deploys applications to EC2 instances"
            operationId = "executeAppPipeline"
            requestBody = {
              required = true
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                    properties = {
                      environment = {
                        type = "string"
                        enum = ["dev", "prod"]
                      }
                      tenant_id = {
                        type = "string"
                        description = "Tenant identifier"
                      }
                      app_name = {
                        type = "string"
                        description = "Application name"
                      }
                      app_version = {
                        type = "string"
                        description = "Application version"
                        default = "latest"
                      }
                    }
                    required = ["environment", "tenant_id", "app_name"]
                  }
                }
              }
            }
          }
        }
        "/mcp/get-status" = {
          post = {
            summary     = "Get pipeline execution status"
            operationId = "getPipelineStatus"
            requestBody = {
              required = true
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                    properties = {
                      execution_id = { type = "string" }
                    }
                    required = ["execution_id"]
                  }
                }
              }
            }
          }
        }
      }
    })
  }
}
