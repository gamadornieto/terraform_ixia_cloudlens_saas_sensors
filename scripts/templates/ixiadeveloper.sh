#!/bin/bash -v
apt-get update
apt-get install -y docker.io
docker pull ixiacom/cloudlens-sandbox-agent
# Sniff only test interfaces
docker run --name cl_sensor -v /:/host -d --restart=always --net=host --privileged ixiacom/cloudlens-sandbox-agent \
  --server agent.ixia-sandbox.cloud --accept_eula y --apikey ${cl_project_key} --listen veth1 --listen veth2
