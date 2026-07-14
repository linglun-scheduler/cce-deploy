# cce-deploy

华为云 CCE 云原生应用部署方案集合。通过 Helm Chart + OSC 服务包，将应用标准化交付到华为云容器引擎（CCE）及 UCS 多云平台。

---

## 📦 产品目录

| 产品 | 版本 | 描述 | 文档 |
|------|------|------|------|
| [**AWX**](products/awx/) | 24.6.1 | Ansible 自动化平台 Web UI + REST API + 任务引擎 | [README](products/awx/README.md) |
| [**GitLab CE**](products/gitlab/) | 17.3.0 | Git 仓库管理、CI/CD、DevOps 平台 | [README](products/gitlab/README.md) |

## 📁 仓库结构

```
├── products/
│   ├── awx/                  # AWX Helm + OSC 包
│   └── gitlab/               # GitLab CE Helm + OSC 包
├── .omo/                     # 规划/设计文档
└── README.md
```

## 🚀 快速使用

```bash
# 1. 选一个产品
cd products/<product>/chart

# 2. 配置 SWR 凭证
export SWR_USER="cn-east-2@..."
export SWR_PASS="<token>"
export ADMIN_PASS="<password>"

# 3. 部署
helm template . --namespace <ns> \
  --set swr.username="$SWR_USER" \
  --set swr.password="$SWR_PASS" \
  --set admin.password="$ADMIN_PASS" \
  | kubectl apply --server-side --force-conflicts -f -
```

## 📦 OSC 服务包

每个产品都提供 OSC 格式包，可直接上传到华为云 OSC 控制台：

```
OSC 控制台 → 我的服务 → 私有服务 → 上传服务 → 选择 .zip 文件
```

支持部署平台：

| 平台 | 适用场景 |
|------|---------|
| **CCE** | 华为云容器引擎 |
| **UCS** | 多云 / 混合云 / 边缘 |
| **AttachedCluster** | 任意 K8s 集群接入 |

## 🔖 Releases

| Tag | 产品 | 下载 |
|-----|------|------|
| [v1.0.0](https://github.com/linglun-scheduler/cce-deploy/releases/tag/v1.0.0) | AWX 24.6.1 | `.zip` + `.tgz` |
| [v1.1.0](https://github.com/linglun-scheduler/cce-deploy/releases/tag/v1.1.0) | GitLab CE 17.3.0 | `.zip` + `.tgz` |

## 🔒 安全

- 镜像仓库凭证 → 运行时 `--set`，不提交 git
- 管理员密码 → 运行时 `--set`，不提交 git
- 集群 kubeconfig → `.gitignore`
- TLS 证书 → `.gitignore`
