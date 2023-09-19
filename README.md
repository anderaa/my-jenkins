# my-jenkins

This repository deploys a Jenkins instance on AWS.


---
# Install requirements

1. Terraform
```
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

2. AWS CLI
```
brew install awscli
aws configure
```
Make sure you configure with credentials from the user that will be executing terraform.

---
# Setup

### Bootstrap terraform AWS backend

```
cd my-jenkins/infra/tf_backend
```

Make sure section of code at top of `tf_backend.tf` is commented out so you start with a local backend.

```
terraform init
terraform apply
```

Uncomment the section of code and run `terraform init` again. This will move your state to S3.


### Create ECR repo

```
cd my-jenkins/infra/ecr
terraform init
terraform apply
```

### Create docker container and push to ECR
Remember to push a new image if you've made changes to the Dockerfile.
```
cd my-jenkins
docker build --platform=linux/amd64 -t myjenkins-blueocean:2.414.1-1 .
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 806152608109.dkr.ecr.us-east-1.amazonaws.com
docker tag myjenkins-blueocean:2.414.1-1 806152608109.dkr.ecr.us-east-1.amazonaws.com/my-jenkins:2.414.1-1
docker push 806152608109.dkr.ecr.us-east-1.amazonaws.com/my-jenkins:2.414.1-1
```

### Create infra and deploy Jenkins
```
cd my-jenkins/infra/web
terraform init
terraform apply
```
Note the public IP address that is returned here.


### Jenkins setup

Connec to the instance.
```
ssh -i <path_to_pem_key_file> ec2-user@<instance_ip_from_above>
```

Verify the two docker containers are running. It might take a few minutes for them to start.
```
sudo docker ps
```

Now get the initial password.
```
docker exec -it <container_id> /bin/bash
cat /var/jenkins_home/secrets/initialAdminPassword
```
Navigate to `http://<instance_ip_from_aboved>:8080` and enter the initial pw from above.

Install the suggested plugins and create a new admin user.


### Cloud and agent setup
Manage Jenkins > Clouds > Install Plugin > Select 'Docker' plugin.

Now SSH into server, and get an IP address from the socat container.
```
docker inspect <container_id> | grep IPAddress
```

Now go back to Clouds and create cloud. Name it and select Docker as type. 

Click on details and in Docker Host URI enter `tcp://<ip_grepped_above>:2375`.

Test the connnection and make sure the 'Enabled' is checked.

Now click Docker Agent templates. Create a label and name.

Enter `anderaa13/jenky-agent:latest` for the Docker image.

Enter 2 for instance capacity and `home/jenkins` for remote file system root.


### Create a freestyle project
New item > Free style project

Click on "Restrict where this project can run" and enter the tag you assinged to your agent.

Enter the url of your Github repo.

For build triggers click on Github hook trigger. Then in your repo, go to webhooks and create one:
```
http://<server_ip>:8080/github-webhook/
```

Click delete workspace before build starts.

Under Build Steps, select "execute shell".

In the script put:
```
pip install -r requirements.txt
python -m pytest .
```


### Get build status in Github
https://stackoverflow.com/questions/14274293/show-current-state-of-jenkins-build-on-github-repo

In Github, go to global settings, then Developer Settings (lower left).
Then click on Personal Access Tokens, and select Tokens (classic).
Generate a new token, give it a name, a give it `repo:status` scope. Copy it.

Now go to Manage Jenkins > System > Github
Enter "Personal_Access_Token_USER" for the name.
Click add credentials, then in the popup, select 'Secret text' for kind, and then paste in your token. Click add.
Make sure you test the connection and make sure you save it.

Now in your Jenkins project configuration, select Post Build Actions and select "Set github commit status (universal).
Leave the default options except for Status result, select "One of default messages and statuses".


### Have agent build an image

There is some config needed to allow this to happen.
- In the host instance, `sudo chmod 666 /var/run/docker.sock`

