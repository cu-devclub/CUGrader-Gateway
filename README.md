# CUGrader-Gateway

APISIX gateway for CUGrader. Runs in standalone mode: there is no etcd and no Admin API. Routes live in `conf/apisix.yaml` and are baked into the image.

Deployed by Argo CD from [CUGrader-infrastructure](https://github.com/cu-devclub/CUGrader-infrastructure) (`apps/gateway/`).

## Routes

Path convention: `/<svc>/<access>/...`. The gateway strips `/<svc>`, so the service receives `/<access>/...`.

| Access prefix | Who | Gateway behavior |
|---------------|-----|------------------|
| `public/` | Everyone | Proxied. Client-sent `X-User-Id` removed. |
| `secure/` | Logged-in user | `forward-auth` calls `user` at `GET /private/auth/verify` with `Authorization` and `Cookie`. A 2xx response proxies the request with `X-User-Id` taken from the verify response. Any other response goes back to the client. |
| `private/` | Internal only | 403 for every service. Services call each other directly at `<svc>.<ns>.svc.cluster.local/private/...`. |

Any other path returns 404.

Services must:
- Serve endpoints under `/public`, `/secure` or `/private`.
- Trust `X-User-Id` only on `/secure` routes.
- The `user` service must implement `GET /private/auth/verify`.

Upstream hosts use `<svc>.${{UPSTREAM_NAMESPACE}}.svc.cluster.local`. The Deployment sets `UPSTREAM_NAMESPACE` to the pod namespace. PR previews set it to `cugrader-sit`. One image works in every env.

To add a service, copy the `user` upstream and its `user-public` and `user-secure` routes in `conf/apisix.yaml`. The `private/` deny already covers every service. Keep `#END` as the last line. Write upstream nodes in array form (`host`/`port`/`weight`). APISIX does not fully substitute `${{VAR}}` inside map keys.

## CI / release

- PR labelled `preview` → pushes `ghcr.io/cu-devclub/cugrader-gateway:<head sha>` → Argo CD deploys `gateway-pr-<n>`.
- Merge to `main` → pushes `:<sha>` and `:latest`, then bumps `newTag` in `apps/gateway/overlays/sit/` of the infra repo → SIT auto-syncs.
- UAT and production are promoted by PR in the infra repo.

Repo secret needed: `INFRA_REPO_TOKEN`, a PAT with contents write on `cu-devclub/CUGrader-infrastructure`.

## Run locally

```sh
docker build -t cugrader-gateway .
docker run --rm -p 9080:9080 -e UPSTREAM_NAMESPACE=cugrader-sit cugrader-gateway
```

Outside the cluster the upstream hosts do not resolve, so proxied routes return 502.
