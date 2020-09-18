FROM gcr.io/google.com/cloudsdktool/cloud-sdk:latest
RUN apt-get install google-cloud-sdk-kpt
COPY src/addons/ /opt/addons 
COPY src/anthos-lab /opt/anthos-lab
WORKDIR /opt
CMD [ "/opt/anthos-lab", "$ACTION" ] 
