# CICD Pipeline Orchestration Guide

## Overview
The orchestrator is responsible for analyzing requests and delegating tasks to specialized agents.

## Pipeline Dependencies

1. **Bootstrap Pipeline** - Must run first
   - Creates VPC, subnets, ACLs
   - Required before any compute or app deployments
   - Run once per environment

2. **Compute Pipeline** - Runs after Bootstrap
   - Provisions EC2 instances for tenants
   - Requires bootstrap infrastructure to exist
   - Can run multiple times for different tenants

3. **App Pipeline** - Runs after Compute
   - Deploys applications to EC2 instances
   - Requires compute resources to exist
   - Can run multiple times for different apps

## Decision Making

### New Environment Setup
When setting up a new environment (dev or prod):
1. Check if bootstrap has run for this environment
2. If not, delegate to Bootstrap Agent first
3. Then delegate to Compute Agent for tenant provisioning
4. Finally delegate to App Agent for application deployment

### Adding New Tenant
When adding a new tenant to existing environment:
1. Verify bootstrap exists (check memory)
2. Delegate to Compute Agent for EC2 provisioning
3. Delegate to App Agent for application deployment

### Deploying New Application
When deploying application to existing tenant:
1. Verify compute resources exist (check memory)
2. Delegate to App Agent only

## Memory Usage
Always query memory before making decisions:
- Check environment history
- Check tenant deployment status
- Verify prerequisites are met
