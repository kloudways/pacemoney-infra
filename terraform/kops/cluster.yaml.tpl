apiVersion: kops.k8s.io/v1alpha2
kind: Cluster
metadata:
  name: pacemoney.k8s.local
spec:
  api:
    loadBalancer:
      class: Network
      type: Public
  authorization:
    rbac: {}
  channel: stable
  cloudProvider: aws
  configBase: s3://pacemoney-kops-state/pacemoney.k8s.local
  etcdClusters:
  - cpuRequest: 200m
    etcdMembers:
    - encryptedVolume: true
      instanceGroup: control-plane-${azs[0]}
      name: a
    manager:
      backupRetentionDays: 90
    memoryRequest: 100Mi
    name: main
  - cpuRequest: 100m
    etcdMembers:
    - encryptedVolume: true
      instanceGroup: control-plane-${azs[0]}
      name: a
    manager:
      backupRetentionDays: 90
    memoryRequest: 100Mi
    name: events
  additionalPolicies:
    node: |
      [
        {
          "Effect": "Allow",
          "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
          "Resource": "${db_url_secret_arn}"
        }
      ]
  iam:
    allowContainerRegistry: true
    legacy: false
  kubelet:
    anonymousAuth: false
  kubernetesApiAccess:
  - ${operator_ip_cidr}
  kubernetesVersion: 1.36.2
  networkCIDR: ${vpc_cidr}
  networkID: ${vpc_id}
  networking:
    calico: {}
  nonMasqueradeCIDR: 100.64.0.0/10
  sshAccess:
  - ${operator_ip_cidr}
  subnets:
  - cidr: ${private_subnet_cidrs[0]}
    id: ${private_subnet_ids[0]}
    name: ${azs[0]}
    type: Private
    zone: ${azs[0]}
  - cidr: ${private_subnet_cidrs[1]}
    id: ${private_subnet_ids[1]}
    name: ${azs[1]}
    type: Private
    zone: ${azs[1]}
  - cidr: ${private_subnet_cidrs[2]}
    id: ${private_subnet_ids[2]}
    name: ${azs[2]}
    type: Private
    zone: ${azs[2]}
  - cidr: ${public_subnet_cidrs[0]}
    id: ${public_subnet_ids[0]}
    name: utility-${azs[0]}
    type: Utility
    zone: ${azs[0]}
  - cidr: ${public_subnet_cidrs[1]}
    id: ${public_subnet_ids[1]}
    name: utility-${azs[1]}
    type: Utility
    zone: ${azs[1]}
  - cidr: ${public_subnet_cidrs[2]}
    id: ${public_subnet_ids[2]}
    name: utility-${azs[2]}
    type: Utility
    zone: ${azs[2]}
  topology:
    dns:
      type: None
