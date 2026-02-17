# Guardrail to prevent deprovisioning
resource "aws_bedrock_guardrail" "main" {
  name                      = "${var.project_name}-guardrail"
  blocked_input_messaging   = "I cannot help with deprovisioning or deleting resources. I can only help with provisioning and deployment."
  blocked_outputs_messaging = "I cannot provide guidance on deprovisioning or deleting resources."
  
  content_policy_config {
    filters_config {
      input_strength  = "HIGH"
      output_strength = "HIGH"
      type            = "HATE"
    }
    filters_config {
      input_strength  = "HIGH"
      output_strength = "HIGH"
      type            = "VIOLENCE"
    }
  }
  
  word_policy_config {
    words_config {
      text = "delete"
    }
    words_config {
      text = "destroy"
    }
    words_config {
      text = "deprovision"
    }
    words_config {
      text = "remove"
    }
    words_config {
      text = "terminate"
    }
    words_config {
      text = "teardown"
    }
    managed_word_lists_config {
      type = "PROFANITY"
    }
  }
}
