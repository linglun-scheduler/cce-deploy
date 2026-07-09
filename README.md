# Ansible AWX 华为云部署方案

在华为云 CCE 上部署 AWX，通过 Helm Chart + OSC 服务包实现跨平台交付。

## 目录结构

```
├── .omo/
│   ├── drafts/                     # 设计文档/草稿
│   ├── plans/                      # 实施计划
│   ├── deploy/
│   │   ├── awx-cce/                # 手动部署 YAML (参考)
│   │   ├── awx-chart/              # Helm Chart (主推)
│   │   │   ├── Chart.yaml          # 图表定义
│   │   │   ├── values.yaml         # 可配参数
│   │   │   ├── crds/               # AWX Operator CRD
│   │   │   └── templates/          # K8s 资源模板
│   │   └── awx-osc/                # OSC 服务包
│   │       ├── upload.sh           # 上传脚本
│   │       └── awx/images/
│   │           ├── mapping.yaml    # 镜像映射
│   │           └── package/        # Helm Chart tgz
│   └── evidence/                   # 验证证据 (git ignored)
├── infra-cce.yaml                   # CCE kubeconfig (git ignored)
├── ssl/                             # TLS 证书 (git ignored)
└── README.md
```

## 快速开始

### 前置条件

- 华为云 CCE 集群 (K8s v1.15+)
- 镜像已推送到 SWR: `swr.cn-east-2.myhuaweicloud.com/dx_x2era/`
- `kubectl` 可访问集群
- `helm` v3+

### Helm 部署

```bash
# 1. 设置 SWR 凭证 (从华为云控制台获取)
export SWR_USER="cn-east-2@..."
export SWR_PASS="<temporary-token>"
export ADMIN_PASS="<your-admin-password>"

# 2. 渲染并部署
cd .omo/deploy/awx-chart
helm template awx . \
  --namespace cloud \
  --set swr.username="$SWR_USER" \
  --set swr.password="$SWR_PASS" \
  --set admin.password="$ADMIN_PASS" \
  --set storage.projects.existingClaim="awx-projects-claim" \
  | kubectl apply --server-side --force-conflicts -f -
```

### OSC 服务包发布

```bash
# 1. 打包 Helm Chart
cd .omo/deploy/awx-chart
helm package . -d ../awx-osc/awx/package/

# 2. 打包 OSC 服务包
cd ../awx-osc
zip -r /tmp/awx-24.6.1.zip awx/

# 3. 上传到 OSC 控制台
#    https://console.huaweicloud.com/osc
#    我的服务 → 私有服务 → 上传服务
```

## 镜像清单

所有镜像已提前推送到华为云 SWR:

| 镜像 | 版本 | SWR 地址 |
|------|------|----------|
| awx | 24.6.1 | `swr.cn-east-2.../dx_x2era/awx:24.6.1` |
| awx-operator | 2.19.1 | `swr.cn-east-2.../dx_x2era/awx-operator:2.19.1` |
| awx-ee | 24.6.1 | `swr.cn-east-2.../dx_x2era/awx-ee:24.6.1` |
| redis | 7 | `swr.cn-east-2.../dx_x2era/redis:7` |
| postgresql-15 | latest | `swr.cn-east-2.../dx_x2era/postgresql-15:latest` |

## 存储

| 卷 | 类型 | 大小 | 用途 |
|----|------|------|------|
| PostgreSQL PVC | `csi-disk` (SSD) | 10Gi | AWX 数据库 |
| Projects PV | `csi-sfsturbo` (SFS Turbo) | 100Gi | Playbook 项目持久化 |

## 跨平台发布 (OSC)

通过华为云 OSC 服务包，可部署到:

| 平台 | 说明 |
|------|------|
| **CCE** | 华为云 K8s 集群 |
| **UCS** | 多云/混合云/边缘 |
| **AttachedCluster** | 任意 K8s 集群 |

## 安全说明

- `infra-cce.yaml` (kubeconfig) → `.gitignore`
- `ssl/` 目录 (TLS 证书) → `.gitignore`
- SWR 凭证 → 部署时通过 `--set` 传入，不写死
- admin 密码 → 部署时通过 `--set admin.password=` 设置

## 配置参考

### values.yaml 主要参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `global.imageRegistry` | `swr.cn-east-2.../dx_x2era` | SWR 镜像仓库 |
| `swr.username` | `""` | SWR 登录用户名 |
| `swr.password` | `""` | SWR 登录密码/token |
| `admin.password` | `"CHANGE-ME-PLEASE!"` | AWX admin 密码 |
| `service.type` | `LoadBalancer` | 服务暴露方式 |
| `storage.postgres.size` | `10Gi` | PostgreSQL 磁盘大小 |
| `storage.projects.enabled` | `true` | 是否启用 Projects 持久化 |
| `storage.projects.existingClaim` | `""` | 使用已有的 PVC 名称 |
