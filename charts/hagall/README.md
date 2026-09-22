# Hagall relay chart

This chart runs a standalone relay behind an AWS Load Balancer Controller NLB.
The chart is published at `https://charts.aukiverse.com`. Relay source and Docker
images are maintained in [aukilabs/hagall](https://github.com/aukilabs/hagall).

Supply `relay.ddsUrl`, `relay.ddsPublicKeyUrl`, `relay.dmsUrl`, `relay.publicHost`,
`relay.peerId`, `identity.existingSecret`, `service.public.subnetIds`, and
`service.public.certificateArn` through infrastructure values. Use `image.digest`
to pin a published image. `image.tag` defaults to the chart's application version
when no digest is supplied.

The existing Secret must contain these file keys:

| Key | File content |
| --- | --- |
| `registration-credentials` | Base64 text encoding the DDS node UUID and secret, separated by `:` |
| `wallet-private-key` | Trimmed secp256k1 private-key hex |
| `libp2p-private-key` | Binary go-libp2p Ed25519 private key |

The init container copies the projected files into a memory-backed volume with
mode `0600`, owned by UID/GID `10001`. The runtime mounts that volume read-only.
Keep these same identities across restarts; do not generate keys in the chart.

Only zero or one replica is allowed. The Deployment uses `Recreate` to prevent
two pods from using the same identity. SIGTERM allows `relay.shutdownDrainSeconds`
for draining, with an additional 30 seconds in the pod termination grace period.

The public Service exposes raw TCP on port `443` and TLS-terminated WebSocket on
port `4443`, forwarded to relay ports `4001` and `4002`. The controller owns the
NLB and target groups. Keep Service names, selectors, ports, and load balancer
class stable when adopting an existing deployment. Admin port `9090` and metrics
port `9091` are ClusterIP-only; the optional PodMonitor scrapes the metrics port.

## Install

```sh
helm repo add auki https://charts.aukiverse.com
helm repo update auki
helm upgrade --install hagall auki/hagall --version 1.1.0 \
  --namespace default -f /path/to/relay-values.yaml
```

When consuming this chart as a dependency, nest overrides under `hagall:` in the
parent chart. The wrapper and dev defaults are maintained in the Hagall repo.

## Capacity

`relay.capacity` is the configurable per-relay booking/reservation budget and
defaults to 32. Values such as 800 or 10000 require no source changes. The fixed
numeric upper bound is only DMS's PostgreSQL INTEGER representation. Values above
256 require the compatible Hagall image and DMS migration
`0013_relay_configurable_capacity`; the chart's default application image predates
that support, so pin a compatible image before enabling larger capacities.

DMS has an independent configurable provider ceiling
(`DMS_MAX_CAPABILITY_CONCURRENCY`, application default 2048) and organization
quota. DMS can grant fewer slots than the relay advertises. Adjust those settings
for the desired deployment and restart the services; configuration is not hot
reloaded. Larger budgets are not a measured throughput guarantee.

`relay.maxCircuitsPerPeer` independently accepts 1–256. When null it preserves
legacy behavior for existing capacities and caps at 256 for larger capacities.
For a 9-publisher/1-consumer topology, an explicit 32 leaves reconnection room.
Authentication concurrency and pod CPU/memory remain independently sized settings.

Connection and admission budgets grow with capacity, retaining existing defaults:

- Connection-manager low water: `max(768, capacity)`.
- High water: `max(1024, low water + 256)`.
- Resource-manager connections: `max(2048, high water)`.
- File descriptors: `max(4096, connections)`.
- Streams: `max(8192, connections, 4 * capacity)`.
- Admission-cache entries: `max(4096, 2 * capacity)`.

At 10000 slots these are 10000 / 10256 / 10256 / 10256 / 40000 / 20000.
The relay still validates the finite memory budget and all cross-field invariants;
size the pod and host resources for the workload before admitting that load.
Total/IP/ASN reservation quotas track capacity as before. One persisted relay
identity still permits only one pod.

## Migration from the legacy chart

Version 1.0.0 replaces the legacy Hagall runtime from chart versions 0.x. It uses
a different configuration and identity format. Existing 0.x packages remain
available; configure the relay's DDS registration, wallet, and libp2p identities
before switching. Legacy HAGALL_* settings and `secrets.privateKey` do not apply.

When adopting an existing standalone relay, preserve its Helm release name,
namespace, `fullnameOverride`, public Service ports, identity Secret, public host,
and Peer ID. Preserve the image digest when moving chart ownership. The single
replica and Recreate strategy prevent concurrent use of the same identity.

## Validation

```sh
bash .github/scripts/check-hagall.sh
```

`ci/default-values.yaml` contains rendering fixtures. CI lints the chart, checks
its schema, and compares direct and subchart rendering. A kind install cannot
exercise this chart's AWS NLB or DDS/DMS enrollment, so Hagall is excluded from
that install suite. Runtime integration remains in the Hagall repository and
deployment verification; CI does not use live credentials.
