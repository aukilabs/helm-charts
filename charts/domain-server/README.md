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

## Chart Structure

- `Chart.yaml` - Chart metadata
- `values.yaml` - Default configuration values
- `templates/` - Kubernetes resource templates