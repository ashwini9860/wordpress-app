# wordpress-app
1. It create wordpress docker image and push it to docker hub using Jenkins

2. . It has terraform to deploy container on AWS using fargate
 
   a. VPC with public subnet, internet gateway and route table
   
   b. creates efs
   
   c. create efs mount point
   
   d. create IAM role with policy 

   e. create security group with port 80,22,2049 open to all 
   
   f. create ECS cluster
 
   g. create ecs task defination

   h. run ecs service with fargate
 
   i. create ECS autoscalling
