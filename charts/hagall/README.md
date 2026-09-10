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
helm upgrade --install hagall auki/hagall --version 1.0.0 \
  --namespace default -f /path/to/relay-values.yaml
```

When consuming this chart as a dependency, nest overrides under `hagall:` in the
parent chart. The wrapper and dev defaults are maintained in the Hagall repo.

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
