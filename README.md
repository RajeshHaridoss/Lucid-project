# Lucid-project: VPC creation using Terraform

# High level Design details:
==========================
Deployment in AWS region us-east-1 in 2 availability zones for high availability
1 VPC in AWS cloud platform
1 internet gateway for public facing applications
2 public subnets one each in an availability zone
1 main route table 
2 private subnets one each in an availability zone
2 Ec2 instances one each in availability zone with auto scaling group (minimum 1 and maximum 6 instances) in private subnet
Auto Scaling Group is attached to Auto scaling policy which is triggered based on cloudwatch alarm
RDS postgress SQL database available in 2 availability zones in private subnet

# Recommendation for Production Implementation:
=============================================

How would a future application obtain the load balancer’s DNS name if it wanted to use this service?
DNS name is obtained from the output variable http://${aws_alb.main_alb.dns_name}-. "A" record will be created in Route53 for this DNS name. 

What aspects need to be considered to make the code work in a CD pipeline (how does it successfully and safely get into production)?

A Jenkins pipeline can be created for each of the above steps and the infrastructure can be provisioned.
All the code will be stored in github for version control and code migration to Developement, UAT and Production. 
Variables can be overridden based on the deployment environment by passing the variable file while running the terraform apply command.  
Password should be stored in secret vault and should not be exposed in the terminal or any logs while creating the infrastructure.
Authentication process can be run in side car to reduce the load in application container
