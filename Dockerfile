FROM jenkins/jenkins:lts

USER root

# Install docker inside Jenkins container
RUN apt-get update && \
    apt-get install -y docker.io docker-compose-plugin && \
    usermod -aG docker jenkins

USER jenkins
