# Lucid-project: VPC,ALB,Internet gateway,NAT gateway,subnets,RDS postgressSQL DB,Nginx docker container creation using Terraform

VPC with 2 Availability Zones with a public/private subnet for each Availability Zones
 
2 containers in private subnets behind a Application Load Balancer (ALB) with AutoScaling Group and Auto Scaling policy

RDS postgress SQL database available in 2 availability zones in private subnet

## AutoScaling Policy
+ Here, we specified increasing instance by 1 (scaling_adjustment = “1”) period without scaling (5 minutes-cooldown)
+ policy type, Simple scaling—Increase or decrease the current capacity of the group based on a single scaling adjustment.
+ Then, we creates cloudwatch alarm which triggers autoscaling policy which will compare CPU utilization.
+ If average of CPU utilization is higher than 60% for 2 consecutive periods (120*2 sec), then a new instance will be created.
+ If average of CPU utilization is lower than 50% for 2 consecutive periods (120*2 sec), then an instance will be downsized.


## Summary
A Terraform configuration to launch a cluster of EC2 instances.  Each EC2 instance runs a single nginx Docker container (based on the latest official nginx Docker image).  One EC2 instance is launched in each availability zone of the region.  The load balancer and EC2 instances are launched in a **custom VPC**, and use custom security groups.

Applying the configuration takes about 30 seconds (in US east Virigina), and another two or three minutes for the EC2 instances to become healthy and for the load balancer DNS record to propagate.

## Files
+ `provider.tf` - AWS Provider details 
+ `main.tf` - main terraform configuration file that launches all the resources for this project. Usually we have separate files for providers, VPC and its resources, ALB and its resources, EC2 instances and its resources, Autoscaling Group and policies,  RDS DB and it's resources. 
+ `vars.tf` - Used by other files, sets default AWS region, calculates availability zones, etc.
+ `userdata.sh` - Used to install docker and nginx application in the EC2 instances

## Access credentials
AWS access credentials must be supplied on the command line (see example below).  This Terraform script should be executed with a user that has the `AmazonEC2FullAccess` and `AmazonVPCFullAccess` policies and also with `AdministratorAccess` policy.

## Command Line Examples
To setup provisioner
```
$ terraform init
```

To launch the EC2 demo cluster:
```
$ terraform plan -out=aws.tfplan -var "aws_access_key=······" -var "aws_secret_key=······"
$ terraform apply aws.tfplan
```
To teardown the EC2 demo cluster:
```
$ terraform destroy -var "aws_access_key=······" -var "aws_secret_key=······"
```

## Regions
The default AWS region is US East Virginia (us-east-1).  However, varaibles can be overridden based on the deployment environment by passing the corresponding variable file while running the terraform apply command. For Example:
```
$ terraform plan -out=aws.tfplan -var "aws_access_key=······" -var "aws_secret_key=······" -var-file dev-variable.tfvar
$ terraform apply aws.tfplan
$ terraform destroy -var "aws_access_key=······" -var "aws_secret_key=······" -var-file dev-variable.tfvar
```
Note: we can skip the keys args in the command if they are set via shell/env exported variables.

## URL
Applying this Terraform configuration returns the load balancer's public URL on the last line of output.  This URL can be used to view the default nginx homepage.




