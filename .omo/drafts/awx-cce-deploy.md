# Draft: awx-cce-deploy — AWX 部署到华为云 CCE

## Intent

CLEAR — 将 AWX 部署到华为云 CCE K8s 集群 `cloud` 命名空间，使用已推送到 SWR 的镜像，配置持久化存储。

## 环境信息

| 项目 | 值 |
|------|-----|
| Kubeconfig | `/data/awx/infra-cce.yaml` |
| 集群 | 华为云 CCE (external: `119.3.17.222:5443`) |
| 命名空间 | `cloud` |
| 部署方式 | AWX Operator (Kubernetes CRD) |
| 镜像源 | `swr.cn-east-2.myhuaweicloud.com/dx_x2era/` |

## 网络状态

⚠️ 当前环境无法连接 CCE 集群（外网 endpoint EOF，内网 endpoint 不可达），需从能访问集群的机器执行部署。

## AWX Operator 架构

```
┌─────────────────────────────────────────────┐
│                 cloud namespace              │
│                                              │
│  ┌──────────────────┐   ┌──────────────────┐ │
│  │   AWX Operator    │   │     PostgreSQL    │ │
│  │   (Deployment)    │   │   (StatefulSet)   │ │
│  └────────┬─────────┘   │  PV: csi-disk 8Gi │ │
│           │ manages     └──────────────────┘ │
│           ▼                                   │
│  ┌──────────────────┐                        │
│  │   AWX Instance    │                        │
│  │   (awx CR)        │                        │
│  │                   │                        │
│  │  ┌──────┐ ┌────┐ │                        │
│  │  │ Web  │ │Task│ │                        │
│  │  │ Pod  │ │Pod │ │                        │
│  │  └──────┘ └────┘ │                        │
│  │  ┌──────┐ ┌────┐ │                        │
│  │  │Redis │ │EE  │ │                        │
│  │  └──────┘ └────┘ │                        │
│  └──────────────────┘                        │
└─────────────────────────────────────────────┘
```

## 持久化策略

### PostgreSQL 数据
- **存储类**: `csi-disk-ssd` (CCE EVS 高性能 SSD 云硬盘)
- **容量**: 8Gi (按需调整)
- **访问模式**: ReadWriteOnce
- **生命周期**: 由 AWX Operator 自动创建 PVC

### Projects 持久化 (Playbook 项目目录)
- **存储类**: `csi-nfs` (CCE SFS 文件存储，支持 ReadWriteMany)
- **容量**: 8Gi
- **访问模式**: ReadWriteMany
- **用途**: 持久化 Git 同步的项目文件

### 已确认的决策

| 决策项 | 选择 |
|--------|------|
| PostgreSQL 存储 | 10Gi (CCE csi-disk 最小) |
| Projects 持久化 | 启用 + ReadWriteMany |
| admin 初始密码 | AWXAdmin123! |
| Ingress | 无 → 使用 LoadBalancer IP 直连 |
| StorageClass | 需用户在集群上确认后填入 |

### 需要执行的步骤

**步骤 1**: 在可连接 CCE 的机器上，执行以下操作：

```bash
# 1.1 检查集群存储类
kubectl get storageclass

# 1.2 检查 csi-nfs 是否可用 (RWX)
kubectl get storageclass csi-nfs 2>/dev/null && echo "可用" || echo "不可用，需要替换"
```

**步骤 2**: 根据步骤 1 结果更新 `05-awx-instance.yaml` 中的 storage class 名称

**步骤 3**: 按顺序 apply 所有 YAML 文件

## Status

approved

## Deliverables

已生成部署文件包: `.omo/deploy/awx-cce/`

- `01-cloud-namespace.yaml` — 命名空间
- `02-awx-admin-password.yaml` — admin 密码 Secret
- `03-awx-operator-crd.yaml` — CRD 说明
- `04-awx-operator.yaml` — Operator Deployment + RBAC
- `05-awx-instance.yaml` — AWX 实例 CR (核心)
- `deploy.sh` — 一键部署脚本
- `README.md` — 部署说明

## Next Steps

用户在可连接 CCE 的机器上执行部署。
