# MMAI Install Guide

## Prerequisites

- Access to a Kubernetes v1.28+ cluster with `cluster-admin` role.
- CRI runtime support (https://kubernetes.io/docs/setup/production-environment/container-runtimes/):
  - `Containerd`: v1.7+.
  - `CRI-O`: v1.28+.
  - Others are not supported.
- Ingress Controller is set up in the cluster. There are many choices. See https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/.
- A default storage class is set up in the cluster to dynamically create persistent volume claims.
  - To support checkpoint feature, the storage class must be able to move a persistent volume from one node to another.
- `NVIDIA GPU Operator` is NOT installed in the cluster. MMAI will install it.
- `kubectl` version v1.28+.
- `Helm` version v3.14+.

## Acquire GitHub Token

Contact MemVerge Customer Support (support@memverge.com) to acquire a personal access token of GitHub account `mv-customer-support` for downloading MMAI helm chart and container images.

## Login to GitHub Registry

```sh
helm registry login ghcr.io/memverge
# Username: mv-customer-support
# Password: <personal-access-token>
```

## Create Image Pull Secret

```sh
kubectl create namespace cattle-system

kubectl create secret generic memverge-dockerconfig --namespace cattle-system \
  --from-file=.dockerconfigjson=$HOME/.config/helm/registry/config.json \
  --type=kubernetes.io/dockerconfigjson
```

## Install cert-manager

```sh
helm repo add jetstack https://charts.jetstack.io --force-update

helm install cert-manager jetstack/cert-manager --namespace cert-manager \
  --create-namespace --set crds.enabled=true
```
Or check https://cert-manager.io/docs/installation for other options.

## Install MMAI

The MMAI management server is designed to be secure by default and requires SSL/TLS configuration.
There are three recommended options for the source of the certificate used for TLS termination at the MMAI server:

### 1.  MMAI-generated Certificate

The default is for MMAI to generate a CA and uses `cert-manager` to issue the certificate for access to the MMAI server interface.

```sh
helm install --namespace cattle-system mmai oci://ghcr.io/memverge/charts/mmai \
  --wait --timeout 20m --version <version> \
  --set hostname=<load-balancer-hostname> --set bootstrapPassword=admin
```
- Set the `hostname` to the DNS name of the load balancer.
  - If there is only one control-plane node and there is no load balancer, the `hostname` can be the DNS name of the control-plane node.
  - If this single control-plane node has no DNS name, a fake domain name `<IP_OF_NODE>.sslip.io` can be used.
- Set the `bootstrapPassword` to something unique for the admin user.
- To install the latest development version, replace the `--version <version>` option with `--devel` in the install command.

### 2.  Let's Encrypt

This option uses `cert-manager` to automatically request and renew `Let's Encrypt` certificates. This is a free service that provides you with a valid certificate as `Let's Encrypt` is a trusted CA.

```sh
helm install --namespace cattle-system mmai oci://ghcr.io/memverge/charts/mmai \
  --wait --timeout 20m --version <version> \
  --set hostname=<load-balancer-hostname> --set bootstrapPassword=admin \
  --set ingress.tls.source=letsEncrypt --set letsEncrypt.email=<me@example.org> \
  --set letsEncrypt.ingress.class=<ingress-controller-name>
```

### 3.  Bring Your Own Certificate

In this option, Kubernetes secrets are created from your own certificates for MMAI to use.

When you run this command, the hostname option must match the Common Name or a Subject Alternative Names entry in the server certificate or the Ingress controller will fail to configure correctly.

```sh
helm install --namespace cattle-system mmai oci://ghcr.io/memverge/charts/mmai \
  --wait --timeout 20m --version <version> \
  --set hostname=<load-balancer-hostname> --set bootstrapPassword=admin \
  --set ingress.tls.source=secret
```

If you are using a Private CA signed certificate , add `--set privateCA=true` to the command:

```sh
helm install --namespace cattle-system mmai oci://ghcr.io/memverge/charts/mmai \
  --wait --timeout 20m --version <version> \
  --set hostname=<load-balancer-hostname> --set bootstrapPassword=admin \
  --set ingress.tls.source=secret --set privateCA=true
```
Now that MMAI is deployed, see [Adding TLS Secrets](add-tls-secrets.md) to publish your certificate files so MMAI and the Ingress controller can use them.

## Uninstall MMAI

This command deletes the MMAI deployment, but leave MMAI CRDs and user-created MMAI CRs in the cluster.

```sh
helm uninstall --namespace cattle-system mmai
```

To completely cleanup MMAI resources, run the [cleanup.sh](cleanup.sh) script.
