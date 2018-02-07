---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: glusterfs-storage
  annotations: 
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/glusterfs
parameters:
  resturl: "http://${heketi_svc_ip}:8080"
  restauthenabled: "false"
  volumetype: none