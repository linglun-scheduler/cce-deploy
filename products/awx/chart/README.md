# AWX Helm Chart

## 架构

```
┌─────────────────────────────────────────────────────────────┐
│                     cloud 命名空间                           │
│                                                              │
│  ┌────────────────────────┐   ┌────────────────────────┐    │
│  │      awx-operator      │   │     awx-postgres-15     │    │
│  │  (1 容器)              │   │  (1 容器: postgresql)   │    │
│  │  监听 AWX CR，自动管理  │   │  持久化: 10Gi SSD       │    │
│  └──────────┬─────────────┘   └────────────────────────┘    │
│             │                                                │
│             ▼                                                │
│  ┌────────────────────────────────────────────────────┐     │
│  │                    awx-web  (3 容器)                │     │
│  │  ┌─────────┐ ┌──────────┐ ┌──────────┐            │     │
│  │  │  nginx  │ │  uwsgi   │ │  daphne  │            │     │
│  │  │ (反向代理│ │ (Django  │ │ (WS + WS)│            │     │
│  │  └─────────┘ └──────────┘ └──────────┘            │     │
│  └────────────────────────────────────────────────────┘     │
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │                    awx-task  (4 容器)               │     │
│  │  ┌──────────┐ ┌────────┐ ┌────────┐ ┌─────────┐   │     │
│  │  │ awx-task │ │ awx-ee │ │  redis │ │ rsyslog │   │     │
│  │  │ (作业执行│ │ (Recep-│ │ (缓存  │ │ (日志   │   │     │
│  │  │  + 调度) │ │  tor)  │ │  队列) │ │  收集)  │   │     │
│  │  └──────────┘ └────────┘ └────────┘ └─────────┘   │     │
│  └────────────────────────────────────────────────────┘     │
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │           awx-projects-claim (PVC) 100Gi           │     │
│  │   SFS Turbo /var/lib/awx/projects Web+Task 共享    │     │
│  └────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

### 容器角色

| Pod | 容器数 | 主要容器 |
|-----|--------|---------|
| awx-operator | 1 | awx-operator (监听 CR、编排部署) |
| awx-postgres-15 | 1 | PostgreSQL 15 (数据库) |
| awx-web | 3 | redis + awx-web (nginx/uwsgi/daphne) + rsyslog |
| awx-task | 4 | redis + awx-task + awx-ee (receptor) + rsyslog |

### 请求流向

```
用户 → LoadBalancer:80 → nginx:8052 → uwsgi (Django API) ──→ PostgreSQL
                                      → daphne (WebSocket) ──→ Redis
```

### 作业执行

```
API 启动作业 → awx-task 调度 → Receptor 网格 → awx-ee 执行 Ansible
                                                          ↓
                                                    实时日志 → rsyslog
```

## 关键参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `global.imageRegistry` | `swr.cn-east-2.../dx_x2era` | SWR 仓库 |
| `swr.username` | `""` | SWR 登录用户 |
| `swr.password` | `""` | SWR 登录 Token |
| `admin.password` | `"CHANGE-ME-PLEASE!"` | 管理员密码 |
| `service.type` | `LoadBalancer` | 服务暴露 |
| `storage.postgres.size` | `10Gi` | PG 磁盘 |
| `storage.projects.existingClaim` | `""` | 已有 PVC 名称 |
