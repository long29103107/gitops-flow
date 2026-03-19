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

### Phase 1 — Tạo repo product-api

Tạo repo GitHub `product-api` với cấu trúc:

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
- **ci.yml:** Push image `ghcr.io/<org>/product-api:<sha>` → cập nhật tag trong repo GitOps

### Phase 2 — Tạo repo GitOps

Tạo repo GitHub `gitops` với cấu trúc:

```
gitops/
├── .github/
│   └── workflows/
│       └── deploy.yaml  # ArgoCD sync khi có commit
└── projects/
    └── dev/
        └── backend/
            └── product-api/
                ├── application.yaml   # ArgoCD Application
                └── chart/
                    └── values.yaml    # image: ghcr.io/org/product-api:<tag>
```

CI của product-api sẽ thay thế image tag trong `values.yaml` mỗi khi build.

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


> **Lưu ý bảo mật:** Trong setup này, endpoint ArgoCD được public ra ngoài để GitHub Actions có thể gọi sync. **Trên thực tế (production), ArgoCD không nên public** — nên để internal (VPN, private network, hoặc GitHub Actions self-hosted trong cùng cluster) để đảm bảo an toàn cho hệ thống.

#### Get Secret

**product-api (lấy từ PAT):**

- Tạo PAT tại: **GitHub** → **Settings** → **Developer settings** → **Personal access tokens** → **Generate new token (classic)**
- Chọn scope tương ứng cho từng secret (xem bảng trên)

**gitops (ArgoCD token):**

1. Tạo bot account trong ArgoCD: **Settings** → **Accounts** → **+ New Account**
2. Generate token: `argocd account generate-token <bot-username>` hoặc trong ArgoCD UI: **Settings** → **Accounts** → chọn bot user → **Generate new token**

#### Set Secret

- **Repo product-api:** **Settings** → **Secrets and variables** → **Actions** → thêm `GHCR_PAT`, `PULL_PACKAGE`, `ARGO_CD_TOKEN`
- **Repo gitops:** **Settings** → **Secrets and variables** → **Actions** → thêm `ARGOCD_SERVER`, `ARGOCD_TOKEN`

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