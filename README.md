# wordpress-app
1. It create wordpress docker image and push it to docker hub using Jenkins

2. . It has terraform to deploy container on AWS using fargate 
   
   a. creates ALB 
   
   b. creates efs
   
   c. module itslef creates IAM role 
   
   d. module itself creates cloudwatch resouce for logging
   
   e. creates terraform ecs cluster 
