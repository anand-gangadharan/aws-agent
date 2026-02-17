"""Bedrock Agent client utilities"""

import boto3
import json
from typing import Dict, Any, Iterator

class BedrockAgentClient:
    def __init__(self, region: str = 'us-east-1'):
        self.client = boto3.client('bedrock-agent-runtime', region_name=region)
    
    def invoke_agent(
        self,
        agent_id: str,
        agent_alias_id: str,
        session_id: str,
        input_text: str
    ) -> str:
        """Invoke a Bedrock agent and return the response"""
        
        response = self.client.invoke_agent(
            agentId=agent_id,
            agentAliasId=agent_alias_id,
            sessionId=session_id,
            inputText=input_text
        )
        
        # Collect response chunks
        completion = ""
        for event in response.get('completion', []):
            if 'chunk' in event:
                chunk = event['chunk']
                if 'bytes' in chunk:
                    completion += chunk['bytes'].decode('utf-8')
        
        return completion
    
    def invoke_agent_stream(
        self,
        agent_id: str,
        agent_alias_id: str,
        session_id: str,
        input_text: str
    ) -> Iterator[str]:
        """Invoke agent and stream response"""
        
        response = self.client.invoke_agent(
            agentId=agent_id,
            agentAliasId=agent_alias_id,
            sessionId=session_id,
            inputText=input_text
        )
        
        for event in response.get('completion', []):
            if 'chunk' in event:
                chunk = event['chunk']
                if 'bytes' in chunk:
                    yield chunk['bytes'].decode('utf-8')
