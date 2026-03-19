# GitOps Flow

> GitOps-based CI/CD for backend microservices (product-api, ...) with GitHub Actions and ArgoCD.

## Tech stack

- **APIs:** .NET 10 (ASP.NET Core minimal APIs)
- **Containers:** Docker, GitHub Container Registry (ghcr.io)
- **CI/CD:** GitHub Actions
- **GitOps:** ArgoCD, Helm
- **Infrastructure:** Kubernetes, Traefik (ingress controller)

## Prerequisite

- [.NET 10 SDK](https://dotnet.microsoft.com/download)
- [Docker](https://docs.docker.com/get-docker/)
- GitHub account with access to the repositories
- ArgoCD (for deployment to Kubernetes)
- Traefik (as ingress controller for routing to services)

## GitOps flow

### Phase 1 — Create product-api repo

Create GitHub repo `product-api` with the following structure:

```
product-api/
├── .github/
│   └── workflows/
│       └── ci.yml       # Build, push GHCR, update GitOps
├── Dockerfile
├── Program.cs
├── Product.Api.csproj
├── appsettings.json
└── ...
```

- **Dockerfile:** Build .NET app, expose port 8080
- **ci.yml:** Push image `ghcr.io/<org>/product-api:<sha>` → update tag in GitOps repo

### Phase 2 — Create GitOps repo

Create GitHub repo `gitops` with the following structure:

```
gitops/
├── .github/
│   └── workflows/
│       └── deploy.yaml  # ArgoCD sync on commit
└── projects/
    └── dev/
        └── backend/
            └── product-api/
                ├── application.yaml   # ArgoCD Application
                └── chart/
                    └── values.yaml    # image: ghcr.io/org/product-api:<tag>
```

product-api CI replaces the image tag in `values.yaml` on each build.

### Phase 3 — Secrets

#### product-api secret

| Secret         | Purpose                                  | PAT scope                |
| -------------- | ---------------------------------------- | ------------------------ |
| `GHCR_PAT`     | Push images to GitHub Container Registry | `repo`, `write:packages` |
| `PULL_PACKAGE` | Pull images from GHCR                    | `read:packages`          |

#### gitops secret

| Secret          | Purpose                   |
| --------------- | ------------------------- |
| `ARGOCD_SERVER` | ArgoCD server URL         |
| `ARGOCD_TOKEN`  | ArgoCD API token for sync |

> **Security note:** In this setup, the ArgoCD endpoint is exposed publicly so GitHub Actions can call sync. **In production, ArgoCD should NOT be public** — keep it internal (VPN, private network, or GitHub Actions self-hosted in the same cluster) for system security.

#### Get Secret

**product-api (from PAT):**

- Create PAT at: **GitHub** → **Settings** → **Developer settings** → **Personal access tokens** → **Generate new token (classic)**
- Select the corresponding scope for each secret (see table above)

**gitops (ArgoCD token):**

1. Create bot account in ArgoCD: **Settings** → **Accounts** → **+ New Account**
2. Generate token: `argocd account generate-token <bot-username>` or in ArgoCD UI: **Settings** → **Accounts** → select bot user → **Generate new token**

#### Set Secret

- **Repo product-api:** **Settings** → **Secrets and variables** → **Actions** → add `GHCR_PAT`, `PULL_PACKAGE`, `ARGO_CD_TOKEN`
- **Repo gitops:** **Settings** → **Secrets and variables** → **Actions** → add `ARGOCD_SERVER`, `ARGOCD_TOKEN`

### Phase 4 — CI workflow (per service repo)

1. Checkout code
2. Login to GHCR
3. Build and push Docker image
4. Clone GitOps repo
5. Update image tag in `gitops/projects/dev/backend/<app-name>/chart/values.yaml`
6. Commit and push to GitOps repo

### Phase 5 — Expected flow

```
push code
    │
    ▼
GitHub Actions (build)
    │
    ▼
push image to GHCR
    │
    ▼
update GitOps repo (new image tag)
    │
    ▼
ArgoCD detects commit
    │
    ▼
deploy to Kubernetes
```

### Phase 6 — ArgoCD setup

Create an ArgoCD Application pointing to:

- `projects/dev/backend/product-api/chart` (or `application.yaml`)

ArgoCD auto-syncs when the GitOps repo is updated.
