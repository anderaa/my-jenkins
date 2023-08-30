# my-jenkins

# Setup

### Create terraform backend

`cd my-jenkins/tf_backend`

Make sure section of code at top of `tf_backend.tf` is commented out so you start with a local backed.

```
terraform init
terraform apply
```

Uncomment the section of code and run `terraform init` again. This will move your state to S3.


### Create ECR repo

```
cd my-jenkins/ecr
terraform init
terraform apply
```

### Create docker container and push to ECR
```
cd my-jenkins
docker build --platform=linux/amd64 -t myjenkins-blueocean:2.414.1-1 .
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 806152608109.dkr.ecr.us-east-1.amazonaws.com
docker tag myjenkins-blueocean:2.414.1-1 806152608109.dkr.ecr.us-east-1.amazonaws.com/my-jenkins:2.414.1-1
docker push 806152608109.dkr.ecr.us-east-1.amazonaws.com/my-jenkins:2.414.1-1
```

### Create infra and deploy Jenkins
```
cd my-jenkins/web
terraform init
terraform apply
```
Note the public IP address that is returned here.


### Jenkins setup
```
ssh -i "<your_key>.pem" ec2-user@<instance_ip>
docker exec -it <container_id> /bin/bash
cat /var/jenkins_home/secrets/initialAdminPassword
```
Navigate to `http://<instance_ip>:8080` and enter the initial pw from above.