# Terraform ICP Provision Module
## About this module
This [ICP Provisioning module](https://github.com/pjgunadi/terraform-module-icp-deploy) is forked from [IBM Cloud Architecture](https://github.com/ibm-cloud-architecture/terraform-module-icp-deploy)
with few modifications:
- Added Management nodes section
- Separate Local IP and Public IP variables
- Added boot-node IP variable
- Added script to download ICP enterprise edition installation file
- Added option to install GlusterFS

## Compatibility
This module has been tested on:
- SoftLayer: Ubuntu 16.04 and RHEL 7.4 [Download terraform tempalte here](https://github.com/pjgunadi/ibm-cloud-private-terraform-softlayer)
- VMware vSphere: Ubuntu 16.04 and RHEL 7.4 [Download terraform template here](https://github.com/pjgunadi/ibm-cloud-private-terraform-vmware)
- ICP Versions: 2.1.0, 2.1.0.1

## Pre-requisites
- The VMs should have been provisioned before running this module

## Inputs

| variable  |  default  | required |  description    |
|-----------|-----------|---------|--------|
|  icp-version   |      |  Yes  |   Version of ICP to provision. <br>For example `2.1.0.1`, `2.1.0.1-ee` | 
|  icp-master   |      |  Yes  |   IP address of ICP Masters. First master will also be boot master. CE edition only supports single master                 | 
|  icp-worker   |      |  Yes  |   IP addresses of ICP Worker nodes.                | 
|  cluster_size   |      |  Yes  |   Define total clustersize. Workaround for terraform issue #10857.                | 
|  icp-proxy   |      |  Yes  |   IP addresses of ICP Proxy nodes.                | 
|  icp_configuration   |   {}   |  No  |   Configuration items for ICP installation.                | 
|  ~~enterprise-edition~~   |   False   |  No  |   *Deprecated*                | 
|  ssh_key   |   ~/.ssh/id_rsa   |  No  |   Private key corresponding to the public key that the cloud servers are provisioned with                | 
|  icpuser   |   admin   |  No  |   Username of initial admin user. Default: Admin                | 
|  config_strategy   |   merge   |  No  |   Strategy for original config.yaml shipped with ICP. Default is merge, everything else means override                | 
|  icppassword   |   admin   |  No  |   Password of initial admin user. Default: Admin                | 
|  ssh_user   |   root   |  No  |   Username to ssh into the ICP cluster. This is typically the default user with for the relevant cloud vendor                | 
|  icp_pub_keyfile   |   /dev/null   |  No  |   Public ssh key for ICP Boot master to connect to ICP Cluster. Only use when generate_key = false                | 
|  generate_key   |   False   |  No  |   Whether to generate a new ssh key for use by ICP Boot Master to communicate with other nodes                | 
| icp_source_server | *Empty* | No | Optional. SFTP Server to download Enterprise Edition installation file |
| icp_source_user | *Empty* | No | Optional. SFTP Username |
| icp_source_password | *Empty* | No | Optional. SFTP Password |
|  image_file   |   /dev/null   |  No  |   Filename of image. Only required for enterprise edition                | 
|  icp_priv_keyfile   |   /dev/null   |  No  |   Private ssh key for ICP Boot master to connect to ICP Cluster. Only use when generate_key = false                | 
|  icp_config_file   |   /dev/null   |  No  |   Yaml configuration file for ICP installation                | 

## Usage example

```hcl
module "icpprovision" {
  source = "github.com/pjgunadi/terraform-module-icp-deploy"
  //Connection IPs
  icp-ips = "${concat(vsphere_virtual_machine.master.*.default_ip_address, vsphere_virtual_machine.proxy.*.default_ip_address, vsphere_virtual_machine.management.*.default_ip_address, vsphere_virtual_machine.worker.*.default_ip_address)}"
  boot-node = "${element(vsphere_virtual_machine.master.*.default_ip_address, 0)}"

  //Configuration IPs
  icp-master = ["${vsphere_virtual_machine.master.*.default_ip_address}"] //private_ip
  icp-worker = ["${vsphere_virtual_machine.worker.*.default_ip_address}"] //private_ip
  icp-proxy = ["${vsphere_virtual_machine.proxy.*.default_ip_address}"] //private_ip
  icp-management = ["${vsphere_virtual_machine.management.*.default_ip_address}"] //private_ip

  icp-version = "${var.icp_version}"

  icp_source_server = "${var.icp_source_server}"
  icp_source_user = "${var.icp_source_user}"
  icp_source_password = "${var.icp_source_password}"
  image_file = "${var.icp_source_path}"

  # Workaround for terraform issue #10857
  # When this is fixed, we can work this out autmatically
  cluster_size  = "${var.master["nodes"] + var.worker["nodes"] + var.proxy["nodes"] + var.management["nodes"]}"

  icp_configuration = {
    "cluster_name"              = "${var.cluster_name}"
    "network_cidr"              = "${var.network_cidr}"
    "service_cluster_ip_range"  = "${var.cluster_ip_range}"
    "ansible_user"              = "${var.ssh_user}"
    "ansible_become"            = "${var.ssh_user == "root" ? false : true}"
    "default_admin_password"    = "${var.icpadmin_password}"
    "docker_log_max_size"       = "10m"
    "docker_log_max_file"       = "10"
    "cluster_vip"     = "${var.cluster_vip == "" ? element(vsphere_virtual_machine.master.*.default_ip_address, 0) : var.cluster_vip}"
    "vip_iface"       = "${var.cluster_vip_iface == "" ? "eth0" : var.cluster_vip_iface}"    
    "proxy_vip"       = "${var.proxy_vip == "" ? element(vsphere_virtual_machine.proxy.*.default_ip_address, 0) : var.proxy_vip}"
    "proxy_vip_iface" = "${var.proxy_vip_iface == "" ? "eth0" : var.proxy_vip_iface}"
  }

    generate_key = true
    
    ssh_user  = "ubuntu"
    ssh_key   = "~/.ssh/id_rsa"
    
} 
```

## ICP Configuration 
Configuration file is generated from items in the following order

1. config.yaml shipped with ICP (if config_strategy = merge, else blank)
2. config.yaml specified in `icp_config_file`
3. key: value items specified in `icp_configuration`

Details on configuration items on ICP KnowledgeCenter
* [ICP 2.1.0](https://www.ibm.com/support/knowledgecenter/en/SSBS6K_2.1.0/installing/config_yaml.html)


## Scaling
The module supports automatic scaling of worker nodes.
To scale simply add more nodes in the root resource supplying the `icp-worker` variable.
You can see working examples for softlayer [in the icp-softlayer](https://github.com/ibm-cloud-architecture/terraform-icp-softlayer) repository

Please note, because of how terraform handles module dependencies and triggers, it is currently necessary to retrigger the scaling resource **after scaling down** nodes.
If you don't do this ICP will continue to report inactive nodes until the next scaling event.
To manually trigger the removal of deleted node, run these commands:

1. `terraform taint --module icpprovision null_resource.icp-worker-scaler`
2. `terraform apply`



