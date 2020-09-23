# FROM gcr.io/google.com/cloudsdktool/cloud-sdk:latest
FROM google/cloud-sdk:311.0.0-alpine
RUN gcloud components install nomos kpt && gcloud components remove bq && rm -rf $(find google-cloud-sdk/ -regex ".*/__pycache__") && rm -rf google-cloud-sdk/.install/.backup
COPY src/addons/ /opt/addons
COPY src/anthos-lab /opt/anthos-lab
WORKDIR /opt
CMD [ "/opt/anthos-lab", "$ACTION" ] 
