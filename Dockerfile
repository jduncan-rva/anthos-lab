FROM gcr.io/google.com/cloudsdktool/cloud-sdk:latest
COPY cfg /opt/cfg 
COPY addons/ /opt/addons 
COPY anthos-lab /opt/anthos-lab 
