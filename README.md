# Light Hosting Kube

An opinionated Kubernetes setup using Hetzner Cloud, Cloudflare, Terraform, Ansible &amp; Rancher.

## Requirements

- Terraform 0.12
- Ansible
- Hetzner Cloud account
- Cloudflare account
- Azure account - For remote Terraform backend

The Azure backend can easily be swapped for S3 if needed, refer to Terraform manual.

## Minimum viable cluster

The clusters size may be anything from one to many nodes, a one node cluster is valid, but not the best solution due to having a single point of failure, which kind of defeats the point in using Kubernetes for production loads.

In this setup, the minimum recommended cluster is the following

### Rancher management cluster - `core` cluster

One node of any size, this cluster doesn't receive any traffic, and is only used for managing the other clusters. Even with multiple workload clusters, only one management cluster is needed.

At Hetzner, the CX11 node is recommended with 1 vCPU and 2 GB RAM. This is also the cheapest node at €2.49. Feel free to pick any size, this one however, is enough.

A floating IP is optional for this cluster.

### Kubernetes workload clusters

For a workload cluster receiving production traffic, there shouldn't be a single point of failure anywhere, this means we need to utilize a floating IP for dynamic ingress routing and multiple nodes configured with both etcd, Kubernetes controlplanes and Kubernetes workers.

In the optimal setup, three servers would run etcd and controlplanes, with at least three other servers running as workers, however for the minimum viable cluster we can put these on the same three nodes, without sacrificing High Availability.

The sizes of the nodes, and the number of them is highly dependant on the workloads being run.

At Hetzner, three CX21 nodes are recommended, each with 2vCPUs and 4 GB RAM. These are priced at €4.90 each, giving a total of €14.70 for compute.

A floating IP is required for these clusters, adding €1.00 to the bill.

### Billing summary

Multiple workload clusters can be run on the same Rancher management cluster, and the workload clusters can of course contain more nodes and bigger nodes.

This however gives a total cost of running a minimum viable production cluster with proper HA €18.19, or roughly $20, using the following resources at Hetzner:

1x CX11 node for rancher management cluster  
3x CX21 node for workload cluster  
1x Floating IP for workload cluster  

## Structure

The solution is made up of modules and clusters.

### Modules

Modules are placed in the `/modules` directory, and implement different areas of provisoning, modules can be replaced by implementing compatible modules with the same input/output, an example would be to use another DNS service or hosting provider.

- `provider/hcloud` - Provision servers with Hetzner Cloud
- `dns/cloudflare` - Provision DNS with Cloudflare
- `dns/digitalocean` - Provision DNS with DigitalOcean (by @lukaspj)
- `ansible/ansible-inventory` - Provision Ansible Inventory files

### Clusters

The solution supports multiple clusters, each with their own configuration, clusters are defined by sub-directories under `/clusters`, a default cluster is included, however the backend should be configured for your own needs.

New clusters can be created by copying the `default` cluster directory, remember to rename the backend state key.

Copy the `terraform.tfvars.example` as `terraform.tfvars` to configure the cluster.

Terraform actions such as `terraform init` and `terraform apply` should be executed with the cluster directory as working directory.

**Server and cluster names with dots in them are not supported, due to not being supported by the Hetzner Cloud Controller.**

## Cluster naming and DNS entries

A cluster is given a name and domain trough the configuration, the name is used for naming and tagging resources.

The domain is used for creating DNS entries for the Floating IP and the nodes.

Given the cluster domain `default.cluster.example.com`, the following DNS records would be created:

```env
default.cluster.example.com             >   Floating IP
master01.default.cluster.example.com    >   Node: master01
worker01.default.cluster.example.com    >   Node: worker01
worker02.default.cluster.example.com    >   Node: worker02
```

Reverse DNS entries will also be added to the Floating IP and nodes at Hetzner matching the above.

## SSH keys

This setup requires the SSH keys being used to be added to your systems SSH agent as recommended by HashiCorp. See [GitHub issue reply](https://github.com/hashicorp/terraform/issues/13734#issuecomment-294848530).

The underlying reason is that loading the private key contents in not supported on encrypted keys. Suggesting the use of unencrypted keys is not something this setup wants to do.

However, if it's a requirement to use SSH keys not in the agent, the following line may be added to the remote-exec blocks in the hcloud provider main file: `terraform/modules/provider/hcloud/main.tf`

```HCL
private_key = file(var.ssh_private_key)
```

It is however recommend to use the SSH agent if possible.

## Setup

### Ansible

Copy the `/ansible/group_vars/all/vars.yml.example` as `/ansible/group_vars/all/vars.yml` to configure ansible.

The `root_password` and `user_password` should be the password part of a .htaccess user. After the configuration the user `deploy` should be used.

Terraform exports node IPs as an Ansible inventory file located at `/ansible/clusters/<cluster-name>/inventory` and extra variables to `/ansible/clusters/<cluster-name>/vars.yml`. This inventory can be used to call re-provision the cluster using Ansible after Terraform has provisioned it the first time.

Using the inventory:

```bash
ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i clusters/default/inventory --extra-vars "@clusters/default/vars.yml" provision.yml
```

### Rancher2

Setting up a self-contained Rancher2 cluster in Terraform runs into the chicken and the egg issues.

Setting up a Rancher Agent node requires a cluster registration token from the Rancher node, however in order to get this, Rancher must be running, which it does after provisioning, where it's already too late, as all servers have been provisioned. Furthermore, starting a Rancher Agent on the Rancher server is impossible using Terraform, due to the same simple provisioning run.

The solution was to add a `core` cluster, where the Rancher node lives, and then connect all other clusters with Rancher Agent nodes to it. This gives a shared management interface, which technically allows embracing hybrid-cloud clusters, however no providers have been written for this on my part.

The `core` cluster is provisioned like other clusters, runs an extra ansible script - `provision-rancher2.yml` - to provision the Rancher setup with LetsEncrypt cert.

After the `core` cluster has been created, an API token should be created, to manage new clusters from Terraform.

## Quick start

Create configuration files:

```bash
cp ansible/group_vars/all/vars.yml.example ansible/group_vars/all/vars.yml
cp terraform/clusters/core/terraform.tfvars.example terraform/clusters/core/terraform.tfvars
cp terraform/clusters/default/terraform.tfvars.example terraform/clusters/default/terraform.tfvars
```

Fill in configurations in the three files.

Start the core setup:

```bash
cd terraform/clusters/core
terraform init
terraform apply
```

Review the result, and confirm with `yes`.

Open the newly provisioned Rancher2 instance, and create an API token, insert it into the `terraform/clusters/default/terraform.tfvars` configuration along with the Rancher url.

Start the k8s cluster setup:

```bash
cd terraform/clusters/default
terraform init
terraform apply
```

Review the result, and confirm with `yes`.

A kubernetes cluster will now be provisioned, registered with Rancher.

Copy the `kube_config` from the Rancher UI to your local config, and test the connection by fetching the nodes:

```bash
kubectl config use-context <cluster-name>
kubectl get nodes -o=wide
```

`kubectl` is now be ready to go!

### Monitoring

Post setup, the monitoring init operator may not be able to start up, and the cluster may report `Monitoring API is not ready` in the Rancher UI. This can be fixed by heading to the Monitoring section, disabling the monitoring and enabling it again.

### Provisioning In-Cluster

In order to get a cluster up and running fast, an extra Ansible playbook is provided, for provisioning services in-cluster.

- Deploy [Hetzner Cloud Controller](https://github.com/hetznercloud/hcloud-cloud-controller-manager)
- Deploy [Hetzner CSI Driver](https://github.com/hetznercloud/csi-driver) - Container Storage Interface for persistent volumes
- Deploy [cbeneke's Hetzner FIP controller v0.3.5](https://github.com/cbeneke/hcloud-fip-controller) - Assigns the cluster floating IP to the node running the controller, effectively keeping the cluster resources HA
- Deploy [Jetstack cert-manager](https://github.com/jetstack/cert-manager)
- Deploy [Traefik](https://github.com/containous/traefik/)
- Deploy Traefik Dashboard - with LetsEncrypt cert available on traefik.(cluster-domain), eg. traefik.default.cluster.example.com
- Deploy [Kubernetes Dashboard v2.0.4](https://github.com/kubernetes/dashboard) - available through `kubectl proxy`

Running the playbook requires the Ansible variables that Terraform generates.

```bash
cd k8s
ansible-playbook --extra-vars "@../ansible/clusters/default/vars.yml" provision-k8s.yml
```

#### Kubernetes Dashboard

The dashboard can be accessed through the following urls:

Over HTTPS:

```env
https://<core-rancher-url>/k8s/clusters/<CLUSTER ID>/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

Using kubectl:

```env
Through Rancher:    http://localhost:8001/k8s/clusters/<CLUSTER ID>/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
Through worker:     http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

The cluster ID is the ID attached by Rancher on cluster creation, looking something like this: c-heka4

The access token needed to sign in can be fetched using:

```bash
kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep kubernetes-dashboard-user | awk '{print $1}')
```

## Inspirations

Light Hosting Kube is the third iteration of my personal hosting setup.

The previous iteration used Terraform and Ansible to provision, harden and configure a Kubernetes cluster hosted with Hetzner, using WireGuard for inter-node connections, as Hetzners networks wasn't out at the time. It included a lot of steps to setup and manage, which led to the cluster not being treated as immutable, as setting up a new was a time consuming task.

After having read [Vito Botta](https://github.com/vitobotta)'s article [From zero to Kubernetes in Hetzner Cloud with Terraform, Ansible and Rancher](https://vitobotta.com/2019/10/14/kubernetes-hetzner-cloud-terraform-ansible-rancher/) where he used Rancher to configure the Kubernetes cluster, I wanted to recreate my setup in a similar fashion, using Ubuntu servers, and adding Cloudflare DNS on top.

A cluster can be booted up in under 15 minutes, and town down in a fraction of that, allowing spinning up new clusters for testing, development and seperating workloads.

Harden Linux Ansible role was inspired by [Githubixx's ansible-role-harden-linux](https://github.com/githubixx/ansible-role-harden-linux).

Rancher Ansible role was inspired by [Sylflo's rancher2-ansible](https://github.com/sylflo-ansible-kubernetes/rancher2-ansible).
