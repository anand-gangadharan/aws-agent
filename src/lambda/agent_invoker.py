"""
Lambda function for orchestrator to invoke specialized agents.
This enables true agent-to-agent collaboration via Bedrock.
"""

import json
import os
import boto3
import uuid

bedrock_agent_runtime = boto3.client('bedrock-agent-runtime')

# Agent IDs from environment
AGENT_IDS = {
    'bootstrap': os.environ.get('BOOTSTRAP_AGENT_ID'),
    'compute': os.environ.get('COMPUTE_AGENT_ID'),
    'app': os.environ.get('APP_AGENT_ID')
}

def handler(event, context):
    """
    Lambda handler for agent-to-agent invocation.
    The orchestrator calls this to delegate work to specialized agents.
    """
    
    print(f"Event: {json.dumps(event)}")
    
    action = event.get('actionGroup', '')
    api_path = event.get('apiPath', '')
    request_body = event.get('requestBody', {})
    
    # Parse request body
    params = {}
    if request_body and 'content' in request_body:
        body_content = request_body['content']
        if isinstance(body_content, dict) and 'application/json' in body_content:
            params = json.loads(body_content['application/json'])
    
    try:
        if api_path == '/invoke-agent':
            result = invoke_specialized_agent(params)
        else:
            result = {'error': f'Unknown API path: {api_path}'}
        
        return {
            'messageVersion': '1.0',
            'response': {
                'actionGroup': action,
                'apiPath': api_path,
                'httpMethod': event.get('httpMethod', 'POST'),
                'httpStatusCode': 200,
                'responseBody': {
                    'application/json': {
                        'body': json.dumps(result)
                    }
                }
            }
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'messageVersion': '1.0',
            'response': {
                'actionGroup': action,
                'apiPath': api_path,
                'httpMethod': event.get('httpMethod', 'POST'),
                'httpStatusCode': 500,
                'responseBody': {
                    'application/json': {
                        'body': json.dumps({'error': str(e)})
                    }
                }
            }
        }

def invoke_specialized_agent(params):
    """
    Invoke a specialized agent via Bedrock Agent Runtime.
    This is where the LLM-driven workflow happens - the specialized agent
    will use its knowledge base and MCP tools to complete the task.
    """
    
    agent_type = params.get('agent_type')
    instruction = params.get('instruction')
    environment = params.get('environment')
    tenant_id = params.get('tenant_id')
    additional_params = params.get('parameters', {})
    
    # Get the agent ID
    agent_id = AGENT_IDS.get(agent_type)
    if not agent_id:
        return {'error': f'Unknown agent type: {agent_type}'}
    
    # Create a session ID for this invocation
    session_id = str(uuid.uuid4())
    
    # Build the instruction with context
    full_instruction = f"""
{instruction}

Environment: {environment}
"""
    
    if tenant_id:
        full_instruction += f"Tenant ID: {tenant_id}\n"
    
    if additional_params:
        full_instruction += f"\nAdditional parameters: {json.dumps(additional_params)}\n"
    
    full_instruction += """
Please use your MCP tools to execute the pipeline and your knowledge base for guidance.
Store the results in memory when complete.
"""
    
    print(f"Invoking {agent_type} agent with instruction: {full_instruction}")
    
    # Invoke the specialized agent
    # The agent's LLM will:
    # 1. Understand the instruction
    # 2. Search its knowledge base for relevant info
    # 3. Decide which MCP tools to call
    # 4. Execute the tools
    # 5. Store results in memory
    # 6. Return a response
    response = bedrock_agent_runtime.invoke_agent(
        agentId=agent_id,
        agentAliasId='TSTALIASID',  # Use test alias
        sessionId=session_id,
        inputText=full_instruction,
        enableTrace=True  # Enable trace for debugging
    )
    
    # Collect response chunks
    agent_response = ""
    execution_id = None
    trace_info = []
    
    for event in response.get('completion', []):
        if 'chunk' in event:
            chunk = event['chunk']
            if 'bytes' in chunk:
                agent_response += chunk['bytes'].decode('utf-8')
        
        # Capture trace information for debugging
        if 'trace' in event:
            trace_info.append(event['trace'])
    
    # Try to extract execution_id from response
    try:
        response_data = json.loads(agent_response)
        execution_id = response_data.get('execution_id')
    except:
        pass
    
    return {
        'agent_type': agent_type,
        'agent_response': agent_response,
        'execution_id': execution_id,
        'session_id': session_id,
        'status': 'completed',
        'trace': trace_info if trace_info else None
    }
