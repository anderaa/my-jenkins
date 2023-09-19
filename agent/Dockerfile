FROM jenkins/agent:alpine-jdk11
USER root
RUN apk add python3
RUN apk add py3-pip
RUN apk add --update docker openrc
RUN rc-update add docker boot
RUN addgroup jenkins docker
RUN apk --no-cache add aws-cli
USER jenkins
COPY .aws/config /home/jenkins/.aws/config
COPY .aws/credentials /home/jenkins/.aws/credentials
USER root
RUN chown -R jenkins:jenkins /home/jenkins/.aws
USER jenkins
