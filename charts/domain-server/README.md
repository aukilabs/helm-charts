# domain-server

Helm chart for deploying the Domain Server on Kubernetes.

## Introduction

This chart bootstraps the Domain Server on a Kubernetes cluster using the [Helm](https://helm.sh/) package manager.

The Domain Server is responsible for storing poses of portals in domains and spatial domain data such as
scene reconstructions and occupancy maps.
See the Domain Server [repo](https://github.com/aukilabs/domain-server) for more information.

## Documentation

For documentation about requirements, installing, uninstalling and upgrading the domain-server using this chart,
please see the [deployment instructions](https://github.com/aukilabs/domain-server/blob/main/docs/deployment.md#kubernetes)
in the domain-server repository.

There are more documents to read in the [docs](https://github.com/aukilabs/domain-server/tree/main/docs) folder.
We recommend you take a look at most of the documents before you attempt to set up a Domain Server.

## Configuration

Please go through the whole [values.yaml](./values.yaml) file and follow the instructions in the comments to configure
the application to suit your environment and needs. The registration credentials can be obtained from the
[Auki console](https://console.auki.network/).

Also see the [configuration](https://github.com/aukilabs/domain-server/blob/main/docs/configuration.md) document
for more details if needed.

## Upgrading

To upgrade your deployment:

```console
helm upgrade cactus aukilabs/domain-server
```

**Important:**
Before upgrading, please review the following steps:

1. **Review the [values.yaml](./values.yaml) file** for any new, deprecated, or changed configuration options.
2. **Custom Values:** If you use a custom values file, compare it to the new `values.yaml` and update your overrides as needed.
3. **Breaking Changes:** Watch for any breaking changes to deployment templates, environment variables, or persistent storage.
   Consider using `helm diff` to preview changes:
   ```console
   helm plugin install https://github.com/databus23/helm-diff
   helm diff upgrade cactus aukilabs/domain-server -f my-values.yaml
   ```
4. **Backup:** If your deployment uses persistent data, ensure you have backups.
5. **Test:** Consider upgrading in a staging environment before production.

### Upgrading to 0.5.4

Version 0.5.4 of the chart has a small but **breaking change** for users that set the
`persistentVolume.statefulSetNameOverride` value.
This value has been renamed to `persistentVolume.nameOverride` as PVCs can now be used
even when `kind` is set to `Deployment`.

In fact, we encourage users to set up PVCs even for S3 storage because when
domain backups are restored, they first need to be stored locally. The alternative is to make sure that the K8s node
running the domain-server has enough of ephemeral storage, for example by configuring
`containerResources.requests.ephemeral-storage`. Then `persistentVolume.enabled` can be set to `false`
to use `emptyDir` instead of PVCs.
For more information, please see the comments in [values.yaml](./values.yaml).

## Chart Structure

- `Chart.yaml` - Chart metadata
- `values.yaml` - Default configuration values
- `templates/` - Kubernetes resource templates