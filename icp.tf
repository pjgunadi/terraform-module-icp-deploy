# Generate a new key if this is required
resource "tls_private_key" "icpkey" {
  count     = "${var.generate_key ? 1 : 0}"
  algorithm = "RSA"

  provisioner "local-exec" {
    command = "cat > privatekey.pem <<EOL\n${tls_private_key.icpkey.private_key_pem}\nEOL"
  }
}

## Actions that has to be taken on all nodes in the cluster
resource "null_resource" "icp-cluster" {
  count = "${var.cluster_size}"

  connection {
    host                = "${element(var.icp-ips, count.index)}"
    user                = "${var.ssh_user}"
    private_key         = "${var.ssh_key}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${var.bastion_private_key}"
  }

  # Validate we can do passwordless sudo in case we are not root
  provisioner "remote-exec" {
    inline = [
      "sudo -n echo This will fail unless we have passwordless sudo access",
    ]
  }

  provisioner "file" {
    content     = "${var.generate_key ? tls_private_key.icpkey.public_key_openssh : file(var.icp_pub_keyfile)}"
    destination = "/tmp/icpkey"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /tmp/icp-common-scripts",
    ]
  }

  provisioner "file" {
    source      = "${path.module}/scripts/common/"
    destination = "/tmp/icp-common-scripts"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/.ssh",
      "cat /tmp/icpkey >> ~/.ssh/authorized_keys",
      "chmod a+x /tmp/icp-common-scripts/*",
      "/tmp/icp-common-scripts/prereqs.sh",
      "/tmp/icp-common-scripts/version-specific.sh ${var.icp-version}",
      "/tmp/icp-common-scripts/docker-user.sh",
      "/tmp/icp-common-scripts/download_installer.sh ${var.icp_source_server} ${var.icp_source_user} ${var.icp_source_password} ${var.image_file} /tmp/${basename(var.image_file)}",
    ]
  }
}

## Actions that needs to be taken on boot master only
resource "null_resource" "icp-boot" {
  depends_on = ["null_resource.icp-cluster"]

  # The first master is always the boot master where we run provisioning jobs from
  connection {
    host                = "${var.boot-node}"
    user                = "${var.ssh_user}"
    private_key         = "${var.ssh_key}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${var.bastion_private_key}"
  }

  # If this is enterprise edition we'll need to copy the image file over and load it in local repository
  // We'll need to find another workaround while tf does not support count for this
  # provisioner "file" {
  #     # count = "${var.enterprise-edition ? 1 : 0}"
  #     source = "${var.enterprise-edition ? var.image_file : "/dev/null" }"
  #     destination = "/tmp/${basename(var.image_file)}"
  # }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /tmp/icp-bootmaster-scripts",
    ]
  }
  provisioner "file" {
    source      = "${path.module}/scripts/boot-master/"
    destination = "/tmp/icp-bootmaster-scripts"
  }
  # store config yaml if it was specified
  provisioner "file" {
    source = "${var.icp_config_file}"

    #   content       = "${var.icp_config_file}"
    destination = "/tmp/config.yaml"
  }
  # JSON dump the contents of icp_configuration items
  provisioner "file" {
    content     = "${jsonencode(var.icp_configuration)}"
    destination = "/tmp/items-config.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod a+x /tmp/icp-bootmaster-scripts/*.sh",
      "/tmp/icp-bootmaster-scripts/load-image.sh ${var.icp-version} /tmp/${basename(var.image_file)}",
      "sudo mkdir -p /opt/ibm/cluster",
      "sudo chown ${var.ssh_user} /opt/ibm/cluster",
      "/tmp/icp-bootmaster-scripts/copy_cluster_skel.sh ${var.icp-version}",
      "sudo chown -R ${var.ssh_user} /opt/ibm/cluster/*",
      "chmod 600 /opt/ibm/cluster/ssh_key",
      "sudo pip install pyyaml",
      "python /tmp/icp-bootmaster-scripts/load-config.py ${var.config_strategy}",
    ]
  }
  # Copy the provided or generated private key
  provisioner "file" {
    content     = "${var.generate_key ? tls_private_key.icpkey.private_key_pem : file(var.icp_priv_keyfile)}"
    destination = "/opt/ibm/cluster/ssh_key"
  }
  provisioner "file" {
    content     = "${join(",", var.icp-worker)}"
    destination = "/opt/ibm/cluster/workerlist.txt"
  }
  provisioner "file" {
    content     = "${join(",", var.icp-master)}"
    destination = "/opt/ibm/cluster/masterlist.txt"
  }
  provisioner "file" {
    content     = "${join(",", var.icp-proxy)}"
    destination = "/opt/ibm/cluster/proxylist.txt"
  }
  provisioner "file" {
    content     = "${join(",", var.icp-management)}"
    destination = "/opt/ibm/cluster/managementlist.txt"
  }
  provisioner "file" {
    content     = "${length(var.icp-va) == 0 ? "" : join(",", var.icp-va)}"
    destination = "${length(var.icp-va) == 0 ? "/dev/null" : "/opt/ibm/cluster/valist.txt"}"
  }
  provisioner "remote-exec" {
    inline = [
      "/tmp/icp-bootmaster-scripts/generate_hostsfiles.sh",
      "/tmp/icp-bootmaster-scripts/start_install.sh ${var.icp-version}",
    ]
  }
}

resource "null_resource" "icp-management-scaler" {
  depends_on = ["null_resource.icp-cluster", "null_resource.icp-boot"]

  triggers {
    nodes = "${join(",", var.icp-management)}"
  }

  connection {
    host                = "${var.boot-node}"
    user                = "${var.ssh_user}"
    private_key         = "${var.ssh_key}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${var.bastion_private_key}"
  }

  provisioner "file" {
    content     = "${join(",", var.icp-management)}"
    destination = "/tmp/managementlist.txt"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/boot-master/scalenodes.sh"
    destination = "/tmp/icp-bootmaster-scripts/scalenodes.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod a+x /tmp/icp-bootmaster-scripts/scalenodes.sh",
      "/tmp/icp-bootmaster-scripts/scalenodes.sh ${var.icp-version} management",
    ]
  }
}

resource "null_resource" "icp-proxy-scaler" {
  depends_on = ["null_resource.icp-cluster", "null_resource.icp-boot"]

  triggers {
    nodes = "${join(",", var.icp-proxy)}"
  }

  connection {
    host                = "${var.boot-node}"
    user                = "${var.ssh_user}"
    private_key         = "${var.ssh_key}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${var.bastion_private_key}"
  }

  provisioner "file" {
    content     = "${join(",", var.icp-proxy)}"
    destination = "/tmp/proxylist.txt"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/boot-master/scalenodes.sh"
    destination = "/tmp/icp-bootmaster-scripts/scalenodes.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod a+x /tmp/icp-bootmaster-scripts/scalenodes.sh",
      "/tmp/icp-bootmaster-scripts/scalenodes.sh ${var.icp-version} proxy",
    ]
  }
}

resource "null_resource" "icp-worker-scaler" {
  depends_on = ["null_resource.icp-cluster", "null_resource.icp-boot"]

  triggers {
    nodes = "${join(",", var.icp-worker)}"
  }

  connection {
    host                = "${var.boot-node}"
    user                = "${var.ssh_user}"
    private_key         = "${var.ssh_key}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${var.bastion_private_key}"
  }

  provisioner "file" {
    content     = "${join(",", var.icp-worker)}"
    destination = "/tmp/workerlist.txt"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/boot-master/scalenodes.sh"
    destination = "/tmp/icp-bootmaster-scripts/scalenodes.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod a+x /tmp/icp-bootmaster-scripts/scalenodes.sh",
      "/tmp/icp-bootmaster-scripts/scalenodes.sh ${var.icp-version} worker",
    ]
  }
}

resource "tls_private_key" "heketikey" {
  count     = "${var.install_gluster ? 1 : 0}"
  algorithm = "RSA"

  provisioner "local-exec" {
    command = "cat > heketi_key <<EOL\n${tls_private_key.heketikey.private_key_pem}\nEOL"
  }
}

resource "null_resource" "create_gluster" {
  count      = "${var.install_gluster ? var.gluster_size : 0}"
  depends_on = ["null_resource.icp-cluster", "null_resource.icp-boot"]

  connection {
    host                = "${element(var.gluster_ips, count.index)}"
    user                = "${var.ssh_user}"
    private_key         = "${var.ssh_key}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${var.bastion_private_key}"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/gluster/creategluster.sh"
    destination = "/tmp/creategluster.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir /root/.ssh && sudo chmod 700 /root/.ssh",
      "echo \"${tls_private_key.heketikey.public_key_openssh}\" | sudo tee -a /root/.ssh/authorized_keys && sudo chmod 600 /root/.ssh/authorized_keys",
      "chmod +x /tmp/creategluster.sh && sudo /tmp/creategluster.sh",
      "echo Installation of Gluster is Completed",
    ]
  }
}

resource "null_resource" "create_heketi" {
  count      = "${var.install_gluster ? 1 : 0}"
  depends_on = ["null_resource.icp-boot", "null_resource.create_gluster"]

  connection {
    host = "${var.heketi_ip}"
    user = "${var.ssh_user}"

    #password = "${var.ssh_password}"
    private_key         = "${var.ssh_key}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${var.bastion_private_key}"
  }

  provisioner "file" {
    content     = "${tls_private_key.heketikey.private_key_pem}"
    destination = "~/heketi_key"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/gluster/createheketi.sh"
    destination = "/tmp/createheketi.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "[ -f ~/heketi_key ] && sudo mkdir -p /etc/heketi && sudo mv ~/heketi_key /etc/heketi/ && sudo chmod 600 /etc/heketi/heketi_key",
      "[ -f /tmp/createheketi.sh ] && chmod +x /tmp/createheketi.sh && sudo /tmp/createheketi.sh",
      "sudo heketi-cli cluster create | tee /tmp/create_cluster.log",
    ]
  }
}

data "template_file" "create_node_script" {
  count = "${var.install_gluster ? var.gluster_size : 0}"

  template = "${file("${path.module}/scripts/gluster/create_node.tpl")}"

  vars {
    nodeip      = "${element(var.gluster_svc_ips, count.index)}"
    nodefile    = "${format("/tmp/nodeid-%01d.txt", count.index + 1) }"
    device_name = "${var.device_name}"
  }
}

resource "null_resource" "create_node" {
  count      = "${var.install_gluster ? var.gluster_size : 0}"
  depends_on = ["null_resource.create_gluster", "null_resource.create_heketi"]

  connection {
    host = "${var.heketi_ip}"
    user = "${var.ssh_user}"

    #password = "${var.ssh_password}"
    private_key         = "${var.ssh_key}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${var.bastion_private_key}"
  }

  provisioner "file" {
    content     = "${element(data.template_file.create_node_script.*.rendered, count.index)}"
    destination = "/tmp/createnode-${count.index}.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/createnode-${count.index}.sh && sudo /tmp/createnode-${count.index}.sh",
    ]
  }
}

data "template_file" "storage_class" {
  count = "${var.install_gluster ? 1 : 0}"

  template = "${file("${path.module}/scripts/gluster/storageclass.yaml.tpl")}"

  vars {
    heketi_svc_ip = "${var.heketi_svc_ip}"
  }
}

resource "null_resource" "create_storage_class" {
  count      = "${var.install_gluster ? 1 : 0}"
  depends_on = ["null_resource.icp-boot", "null_resource.create_heketi"]

  connection {
    host = "${var.boot-node}"
    user = "${var.ssh_user}"

    #password = "${var.ssh_password}"
    private_key         = "${var.ssh_key}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${var.bastion_private_key}"
  }

  provisioner "file" {
    content     = "${data.template_file.storage_class.rendered}"
    destination = "/tmp/storageclass.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "which kubectl || curl -LO https://storage.googleapis.com/kubernetes-release/release/${var.k8_version}/bin/linux/amd64/kubectl",
      "[ -f ./kubectl ] && chmod +x ./kubectl && sudo mv ./kubectl /usr/local/bin/kubectl",
      "sudo kubectl config set-cluster ${var.cluster_name} --server=https://${var.boot-node}:8001 --insecure-skip-tls-verify=true",
      "sudo kubectl config set-context ${var.cluster_name} --cluster=${var.cluster_name}",
      "sudo kubectl config set-credentials ${var.cluster_name} --client-certificate=/opt/ibm/cluster/cfc-certs/kubecfg.crt --client-key=/opt/ibm/cluster/cfc-certs/kubecfg.key",
      "sudo kubectl config set-context ${var.cluster_name} --user=${var.cluster_name}",
      "sudo kubectl config use-context ${var.cluster_name}",
      "sudo kubectl create -f /tmp/storageclass.yaml",
      "echo completed",
    ]
  }
}
