FROM jenkins/jenkins:2.414.1-jdk17
USER root
RUN apt-get update && apt-get install -y lsb-release
RUN curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \
  https://download.docker.com/linux/debian/gpg
RUN echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y docker-ce-cli
USER jenkins
RUN jenkins-plugin-cli --plugins "blueocean docker-workflow"

# docker build --platform=linux/amd64 -t myjenkins-blueocean:2.414.1-1 .
# aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 806152608109.dkr.ecr.us-east-1.amazonaws.com
# docker tag myjenkins-blueocean:2.414.1-1 806152608109.dkr.ecr.us-east-1.amazonaws.com/my-jenkins:2.414.1-1
# docker push 806152608109.dkr.ecr.us-east-1.amazonaws.com/my-jenkins:2.414.1-1
