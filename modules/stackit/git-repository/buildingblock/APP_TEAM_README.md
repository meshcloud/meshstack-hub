This building block provisions a **Git repository on STACKIT Git** — the platform's self-hosted Forgejo/Gitea instance at [git-service.git.onstackit.cloud](https://git-service.git.onstackit.cloud). Within seconds you get a fully configured repository, optionally pre-populated from an application template, with CI/CD webhooks ready to fire 🚀.

## 🎯 Who is this for?

This building block is for **application teams** that:

- Need a Git repository hosted on STACKIT infrastructure (data sovereignty, no external SaaS)
- Want to start from a **pre-configured application template** (e.g., Python, Node.js) with Dockerfile, Kubernetes manifests, and CI/CD pipelines already in place
- Are integrating with **Argo Workflows** for automated container builds triggered on every `git push`
- Require a private repository within a shared STACKIT Git organization

## 🛠️ Usage Examples

### Example 1 – Empty private repository

Use this when you already have existing code to push or prefer a clean slate.

```bash
# After the building block is provisioned, clone and start working:
git clone https://git-service.git.onstackit.cloud/my-org/payments-service.git
cd payments-service
git add .
git commit -m "Initial commit"
git push origin main
```

### Example 2 – Repository from Python application template

Use this when starting a new application. The `app-template-python` template provides a ready-to-run Python app with Docker and Kubernetes manifests.

```
# After provisioning, your repo contains:
your-repo/
├── app/
│   ├── Dockerfile          ← Container build instructions
│   ├── requirements.txt    ← Python dependencies
│   └── main.py             ← Application entrypoint
└── manifests/
    └── base/
        ├── kustomization.yaml
        ├── deployment.yaml
        └── service.yaml
```

Clone it, modify `app/main.py`, and push — an Argo Workflows build will trigger automatically if a webhook was configured.

## 🤝 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|---|:---:|:---:|
| Provision STACKIT Git infrastructure | ✅ | ❌ |
| Create and configure the repository | ✅ | ❌ |
| Set up webhooks for CI/CD | ✅ | ❌ |
| Manage STACKIT Git API tokens | ✅ | ❌ |
| Develop and maintain application source code | ❌ | ✅ |
| Commit and push code changes | ❌ | ✅ |
| Manage branches and pull requests | ❌ | ✅ |
| Review and merge code | ❌ | ✅ |
| Application runtime security & updates | ❌ | ✅ |

## ℹ️ Additional Resources

- STACKIT Git: [https://git-service.git.onstackit.cloud](https://git-service.git.onstackit.cloud)
- Contact the platform team for infrastructure issues or token access
- Check Argo Workflows UI for build status after pushing code
