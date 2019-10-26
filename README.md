# Light Hosting Kube

Automated Kubernetes setup using Hetzner Cloud, Cloudflare, Terraform, Ansible &amp; Rancher.

## Requirements

- Terraform 0.12
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

### Clusters

The solution supports multiple clusters, each with their own configuration, clusters are defined by sub-directories under `/clusters`, a default cluster is included, however the backend should be configured for your own needs.

New clusters can be created by copying the `default` cluster directory, remember to rename the backend state key.

Copy the `terraform.tfvars.example` as `terraform.tfvars` to configure the cluster.

Terraform actions such as `terraform init` and `terraform apply` should be executed with the cluster directory as working directory.

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

## Inspirations

Light Hosting Kube is the third iteration of my personal hosting setup.

The previous iteration used terraform and ansible to provision, harden and configure a Kubernetes cluster hosted with Hetzner. It included a lot of manual work, managing the servers and ansible roles.

After having read [Vito Botta](https://github.com/vitobotta)'s article [From zero to Kubernetes in Hetzner Cloud with Terraform, Ansible and Rancher](https://vitobotta.com/2019/10/14/kubernetes-hetzner-cloud-terraform-ansible-rancher/) where he used Rancher to configure the Kubernetes cluster, I wanted to recreate my setup in a similar fashion, using Ubuntu servers, and adding Cloudflare DNS on top.
