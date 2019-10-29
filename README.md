# Light Hosting Kube

Automated Kubernetes setup using Hetzner Cloud, Cloudflare, Terraform, Ansible &amp; Rancher.

## Requirements

- Terraform 0.12
- Ansible
- Hetzner Cloud account
- Cloudflare account
- Azure account - For remote Terraform backend

The Azure backend can easily be swapped for S3 if needed, refer to Terraform manual.

## Structure

The solution is made up of modules and clusters.

### Modules

Modules are placed in the `/modules` directory, and implement different areas of provisoning, modules can be replaced by implementing compatible modules with the same input/output, an example would be to use another DNS service or hosting provider.

- `provider/hcloud` - Provision servers with Hetzner Cloud
- `dns/cloudflare` - Provision DNS with Cloudflare
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

### Provisioning In-Cluster

In order to get a cluster up and running fast, an extra Ansible playbook is provided, for provisioning services in-cluster.

- Deploy [Hetzner Cloud Controller](https://github.com/hetznercloud/hcloud-cloud-controller-manager)
- Deploy [Hetzner CSI Driver](https://github.com/hetznercloud/csi-driver) - Container Storage Interface for persistent volumes
- Deploy [cbeneke's Hetzner FIP controller v0.1.0](https://github.com/cbeneke/hcloud-fip-controller) - Assigns the cluster floating IP to the node running the controller, effectively keeping the cluster resources HA
- Deploy [Jetstack cert-manager](https://github.com/jetstack/cert-manager)
- Deploy [Traefik](https://github.com/containous/traefik/)
- Deploy Traefik Dashboard - with LetsEncrypt cert available on traefik.(cluster-domain), eg. traefik.default.cluster.example.com
- Deploy [Kubernetes Dashboard v1.10.1](https://github.com/kubernetes/dashboard) - available through `kubectl proxy`

Running the playbook requires the Ansible variables that Terraform generates.

```bash
cd k8s
ansible-playbook --extra-vars "@../ansible/clusters/default/vars.yml" provision-k8s.yml
```

#### Kubernetes Dashboard

The dashboard can be accessed through `kubectl proxy` using the url as follows:

```env
http://localhost:8001/k8s/clusters/<CLUSTER ID>/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/
```

The cluster ID is the ID attached by Rancher on cluster creation, looking something like this: c-heka4

The access token needed to sign in can be fetched using 

```bash
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep kubernetes-dashboard-user | awk '{print $1}')
```

## Inspirations

Light Hosting Kube is the third iteration of my personal hosting setup.

The previous iteration used terraform and ansible to provision, harden and configure a Kubernetes cluster hosted with Hetzner. It included a lot of manual work, managing the servers and ansible roles.

After having read [Vito Botta](https://github.com/vitobotta)'s article [From zero to Kubernetes in Hetzner Cloud with Terraform, Ansible and Rancher](https://vitobotta.com/2019/10/14/kubernetes-hetzner-cloud-terraform-ansible-rancher/) where he used Rancher to configure the Kubernetes cluster, I wanted to recreate my setup in a similar fashion, using Ubuntu servers, and adding Cloudflare DNS on top.

Harden Linux Ansible role was inspired by [Githubixx's ansible-role-harden-linux](https://github.com/githubixx/ansible-role-harden-linux).

Rancher Ansible role was inspired by [Sylflo's rancher2-ansible](https://github.com/sylflo-ansible-kubernetes/rancher2-ansible).
