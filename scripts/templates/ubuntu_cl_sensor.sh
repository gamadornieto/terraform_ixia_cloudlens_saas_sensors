#!/bin/bash
yum update -y
yum -y install docker
service docker start
systemctl enable docker
# Start Cloudlens Docker service and register to correct project
docker run --name cl_sensor -v /:/host -d --restart=always --net=host --privileged ixiacom/cloudlens-sandbox-agent \
--server agent.ixia-sandbox.cloud --accept_eula y --apikey ${cl_project_key}
