# GitLab CE 17.3.0

GitLab Community Edition — Git 仓库管理、CI/CD、DevOps 平台。

## 架构

```
LoadBalancer :80 / :443 / :22
       │
  ┌────▼───────────────────┐
  │  gitlab-ce:17.3.0-ce.0 │  Omnibus 单容器
  │                        │
  │  data     /var/opt/gitlab   50Gi  仓库/DB/制品
  │  config   /etc/gitlab       10Gi  配置
  │  logs     /var/log/gitlab   10Gi  日志
  └────────────────────────┘
```

采用 GitLab 官方 omnibus 镜像，所有组件（Unicorn、Sidekiq、PostgreSQL、Redis、Nginx）运行在单容器内，适合中小规模部署。

## 目录

```
products/gitlab/
├── chart/               # Helm Chart
│   ├── Chart.yaml
│   ├── values.yaml      # 所有可配参数
│   └── templates/       # K8s 资源模板
└── osc-package/         # OSC 服务包
    └── gitlab/
        ├── metadata.yaml
        ├── lifecycle.yaml
        ├── manifests/   # CRD + CSD
        └── raw/         # Helm Chart 源文件
```

## 存储

| 卷 | 大小 | 类型 | 挂载路径 | 用途 |
|----|------|------|---------|------|
| data | 50Gi | csi-disk | /var/opt/gitlab | Git 仓库、DB、制品 |
| config | 10Gi | csi-disk | /etc/gitlab | gitlab.rb 配置 |
| logs | 10Gi | csi-disk | /var/log/gitlab | 日志 |

支持通过 `storage.<name>.existingClaim` 引用已有的 PV。

## Helm 部署

```bash
cd products/gitlab/chart

helm template gitlab . --namespace gitlab \
  --set domain=gitlab.yourdomain.com \
  --set admin.password="<your-password>" \
  --set swr.username="..." --set swr.password="..." \
  | kubectl apply --server-side --force-conflicts -f -
```

### 首次部署后

```bash
# 等待就绪 (约 2-3 分钟)
kubectl -n gitlab wait --for=condition=ready pod -l app=gitlab --timeout=300s

# 获取 LoadBalancer IP
kubectl -n gitlab get svc gitlab
```

### 访问

| 方式 | 地址 | 说明 |
|------|------|------|
| ELB (内网) | `http://10.240.201.166` | VPC 内网访问 |
| NodePort | `http://<节点IP>:30661` | 外网访问 |

### 首次使用

注册页面创建第一个用户（自动成为管理员）：
```
http://10.240.201.166/users/sign_up
```

## OSC 部署

```bash
# 构建
cd products/gitlab/osc-package
zip -r /tmp/gitlab-1.0.0.zip gitlab/

# 上传 OSC 控制台 → 我的服务 → 私有服务 → 上传服务
```

## SMTP 配置

编辑 `chart/values.yaml` 或通过 `--set` 传入：

```yaml
smtp:
  enabled: true
  host: smtp.example.com
  port: 587
  user: gitlab@example.com
  password: "..."
```

## SWR 镜像

| 镜像 | 版本 |
|------|------|
| gitlab-ce | 17.3.0-ce.0 |

注册中心: `swr.cn-east-2.myhuaweicloud.com/dx_x2era/`

## Release

[v1.1.0](https://github.com/linglun-scheduler/cce-deploy/releases/tag/v1.1.0) — 包含 `.zip`(OSC) + `.tgz`(Helm)
