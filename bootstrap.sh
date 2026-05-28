#!/bin/bash
# ------------------------------------------------------------------
# k3s Node Bootstrap and AWS Credential Orchestration
# ------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive

# Update host package indexes
apt-get update -y
apt-get upgrade -y
apt-get install -y curl unzip awscli amazon-ecr-credential-helper

# Install k3s without Traefik (Minecraft doesn't require HTTP routing engines)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik" sh -

# Loop until local control plane is actively responding
until k3s kubectl get nodes &>/dev/null; do
  sleep 3
done

# Configure host-level Containerd to pull from private ECR using IAM Roles
mkdir -p /etc/rancher/k3s
cat <<EOF > /etc/rancher/k3s/registries.yaml
mirrors:
  "441688139382.dkr.ecr.us-east-1.amazonaws.com":
    endpoint:
      - "https://441688139382.dkr.ecr.us-east-1.amazonaws.com"
configs:
  "441688139382.dkr.ecr.us-east-1.amazonaws.com":
    credHelpers:
      - "ecr-login"
EOF

# Restart k3s service to seamlessly apply registry credential mappings
systemctl restart k3s

# Bubble up cluster configs to the 'ubuntu' user for direct SSH debugging
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube
chmod 600 /home/ubuntu/.kube/config
echo "export KUBECONFIG=/home/ubuntu/.kube/config" >> /home/ubuntu/.bashrc
