---
apiVersion: v1
kind: Secret
metadata:
  name: heketi-secret
  namespace: default
data:
  key: ${heketi_admin_pwd}
type: kubernetes.io/glusterfs
