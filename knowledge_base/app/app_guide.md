# Application Pipeline Guide

## Purpose
Deploy applications to provisioned EC2 instances.

## Prerequisites
- Compute resources must exist for tenant
- EC2 instances running and healthy
- Application artifacts available

## Parameters
- Tenant ID (required)
- Application name (required)
- Application version (optional, defaults to latest)
- Environment (dev or prod)

## Deployment Process
1. Download application artifacts
2. Copy to target EC2 instances
3. Install dependencies
4. Configure application
5. Start services
6. Run health checks

## Supported Applications
The pipeline supports deploying various application types:
- Web applications
- API services
- Background workers
- Microservices
