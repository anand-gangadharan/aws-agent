import json
import os
import boto3
import uuid

bedrock_agent_runtime = boto3.client('bedrock-agent-runtime')
orchestrator_agent_id = os.environ['ORCHESTRATOR_AGENT_ID']

def handler(event, context):
    """Lambda handler for chat interface"""
    
    print(f"Event: {json.dumps(event)}")
    
    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        message = body.get('message', '')
        session_id = body.get('session_id', str(uuid.uuid4()))
        
        if not message:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': 'Message is required'})
            }
        
        # Invoke orchestrator agent
        response = bedrock_agent_runtime.invoke_agent(
            agentId=orchestrator_agent_id,
            agentAliasId='TSTALIASID',  # Use test alias
            sessionId=session_id,
            inputText=message
        )
        
        # Collect response chunks
        completion = ""
        for event in response.get('completion', []):
            if 'chunk' in event:
                chunk = event['chunk']
                if 'bytes' in chunk:
                    completion += chunk['bytes'].decode('utf-8')
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'response': completion,
                'session_id': session_id
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': str(e)})
        }
