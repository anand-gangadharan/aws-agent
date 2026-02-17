# Bootstrap Pipeline Guide

## Purpose
Create foundational infrastructure for an environment.

## Components Created
- VPC with CIDR blocks
- Public and private subnets across availability zones
- Internet Gateway
- NAT Gateways
- Route tables
- Network ACLs
- Security groups

## Prerequisites
- AWS account access
- Target region specified
- Environment name (dev or prod)

## Execution
The bootstrap pipeline creates all networking infrastructure needed for compute and application resources.

## Best Practices
- Run once per environment
- Use consistent CIDR ranges
- Enable VPC flow logs
- Tag all resources with environment
