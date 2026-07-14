# AWX 24.6.1

Ansible AWX — Web UI, REST API, 任务引擎。Red Hat Ansible Automation Platform 的上游项目。

## 架构

```
Operator → Web (nginx+uwsgi+daphne) + Task (task+ee+redis+rsyslog) + PostgreSQL
```

详见 [容器架构说明](chart/README.md#架构)（chart 目录内）。

## 目录

```
products/awx/
├── chart/               # Helm Chart（主推部署方式）
│   ├── Chart.yaml
│   ├── values.yaml      # 所有可配参数
│   ├── crds/            # AWX Operator CRD
│   └── templates/       # K8s 资源模板
├── osc-package/         # OSC 服务包
│   └── awx/
│       ├── metadata.yaml
│       ├── lifecycle.yaml
│       ├── manifests/   # CRD + CSD（驱动 OSC 表单）
│       └── raw/         # Helm Chart 源文件
└── deploy/              # 手动部署 YAML（参考）
    ├── 01-*.yaml
    └── deploy.sh
```

## 存储

| 卷 | 类型 | 大小 | 用途 |
|----|------|------|------|
| PostgreSQL PVC | `csi-disk` (SSD) | 10Gi | 数据库 |
| Projects PV | `csi-sfsturbo` (SFS Turbo RWX) | 100Gi | Playbook 项目 |

## Helm 部署

```bash
cd products/awx/chart
helm template awx . --namespace cloud \
  --set swr.username="..." --set swr.password="..." \
  --set admin.password="<your-password>" \
  --set storage.projects.existingClaim="awx-projects-claim" \
  | kubectl apply --server-side --force-conflicts -f -
```

## OSC 部署

```bash
# 构建
cd products/awx/osc-package
zip -r /tmp/awx-24.6.1.zip awx/

# 上传 OSC 控制台 → 我的服务 → 私有服务 → 上传服务
```

## SWR 镜像

| 镜像 | 版本 |
|------|------|
| awx | 24.6.1 |
| awx-operator | 2.19.1 |
| awx-ee | 24.6.1 |
| redis | 7 |
| postgresql-15 | latest |

注册中心: `swr.cn-east-2.myhuaweicloud.com/dx_x2era/`

## Release

[v1.0.0](https://github.com/linglun-scheduler/cce-deploy/releases/tag/v1.0.0) — 包含 `.zip`(OSC) + `.tgz`(Helm)
