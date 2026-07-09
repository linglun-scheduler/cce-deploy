# awx-cce-deploy — AWX 部署到华为云 CCE

## TL;DR (For humans)

**What you'll get:** 在华为云 CCE Kubernetes 集群的 `cloud` 命名空间中，通过 AWX Operator 部署一套生产就绪的 AWX 实例。使用已在 SWR 就绪的镜像，配置 PostgreSQL 持久化存储 (10Gi SSD) 和 Projects 持久化存储 (8Gi NFS RWX)，通过 LoadBalancer 对外暴露服务。

**Why this approach:** AWX Operator 是官方推荐的生产部署方式；使用 SWR 镜像避免依赖海外源；持久化确保升级/重启不丢数据；LoadBalancer 直接利用 CCE 的云负载均衡能力。

**What it will NOT do:** ❌ 不配置 HTTPS 证书（LoadBalancer 默认 HTTP）；❌ 不创建外部 DNS 域名；❌ 不配置 LDAP/OAuth 等外部认证；❌ 不安装 Prometheus/Grafana 监控

**Effort:** Medium — 安装 Operator + 部署 AWX CR + 配置存储  
**Risk:** Low-Medium — 标准 Kubernetes 部署流程，但需确保 CCE 存储类可用

Your next move: 确认决策后批准执行。

---

> TL;DR (machine): Medium | Low-Medium | AWX Operator + CR + PV/PVC → cloud namespace

## Scope

### Must have
- 在 `cloud` 命名空间部署 AWX Operator (v2.19.1)
- 创建 AWX 实例 CR (awx:24.6.1)
- PostgreSQL 持久化存储 (10Gi, csi-disk-ssd)
- Projects 持久化存储 (8Gi, csi-nfs, ReadWriteMany)
- 通过 LoadBalancer 暴露 AWX Web UI (端口 80/443)
- 创建 admin 密码 Secret
- 验证部署: Web UI 可访问、API 响应正常

### Must NOT have (guardrails, anti-slop, scope boundaries)
- ❌ 不配置 HTTPS 证书 (后续可补)
- ❌ 不部署外部 PostgreSQL (使用 Operator 内置)
- ❌ 不修改 AWX 源代码或自定义镜像
- ❌ 不打 latest tag

## Execution strategy

### Wave 1 — 基础设施
### Wave 2 — AWX Operator 安装
### Wave 3 — AWX 实例部署
### Wave 4 — 验证

### Dependency matrix
| Todo | Depends on | Blocks |
| --- | --- | --- |
| T1. 创建 cloud namespace | — | T2,T3,T4 |
| T2. 创建 StorageClass 引用 (PV/PVC) | — | T3 |
| T3. 安装 AWX Operator | T1 | T4 |
| T4. 部署 AWX 实例 CR | T1,T2,T3 | T5 |
| T5. 验证部署 | T4 | — |

## 完整 YAML 资源清单

### 1. cloud-namespace.yaml
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cloud
```

### 2. awx-admin-password.yaml
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: awx-admin-password
  namespace: cloud
type: Opaque
stringData:
  password: "AWXAdmin123!"  # 请修改为强密码
```

### 3. awx-operator.yaml (需要先安装 CRD)
```yaml
# 从 GitHub 安装 AWX Operator (在 cloud 命名空间)
# kubectl apply -f https://raw.githubusercontent.com/ansible/awx-operator/2.19.1/config/crd/bases/awx.ansible.com_awxs.yaml
# 然后部署 Operator:
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: awx-operator
  namespace: cloud
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: awx-operator
  template:
    metadata:
      labels:
        app.kubernetes.io/name: awx-operator
    spec:
      serviceAccountName: awx-operator
      containers:
        - name: awx-operator
          image: swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx-operator:2.19.1
          args:
            - --leader-elect
          env:
            - name: ANSIBLE_GATHERING
              value: explicit
            - name: WATCH_NAMESPACE
              value: cloud
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8081
            initialDelaySeconds: 15
            periodSeconds: 20
          readinessProbe:
            httpGet:
              path: /readyz
              port: 8081
            initialDelaySeconds: 5
            periodSeconds: 10
---
# RBAC (ServiceAccount, Role, RoleBinding)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: awx-operator
  namespace: cloud
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: awx-operator
  namespace: cloud
rules:
  - apiGroups: [""]
    resources: ["configmaps", "endpoints", "events", "persistentvolumeclaims", "pods", "secrets", "services", "serviceaccounts"]
    verbs: ["*"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets"]
    verbs: ["*"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["*"]
  - apiGroups: ["route.openshift.io"]
    resources: ["routes"]
    verbs: ["*"]
  - apiGroups: ["awx.ansible.com"]
    resources: ["awxs", "awxmeshingresses"]
    verbs: ["*"]
  - apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
    verbs: ["*"]
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: awx-operator
  namespace: cloud
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: awx-operator
subjects:
  - kind: ServiceAccount
    name: awx-operator
    namespace: cloud
```

### 4. awx-instance.yaml (核心 AWX CR)
```yaml
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx
  namespace: cloud
spec:
  # --- 镜像配置 (使用 SWR) ---
  image: swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx
  image_version: 24.6.1
  image_pull_policy: IfNotPresent

  # --- EE 执行环境 ---
  ee_images:
    - name: "AWX EE 24.6.1"
      image: swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx-ee:24.6.1

  # --- 管理员 ---
  admin_user: admin
  admin_password_secret: awx-admin-password

  # --- 服务暴露 ---
  service_type: LoadBalancer
  loadbalancer_protocol: http
  loadbalancer_port: 80

  # --- Web 副本 ---
  web_replicas: 1
  task_replicas: 1

  # --- PostgreSQL 持久化 ---
  postgres_storage_requirements:
    requests:
      storage: 8Gi
  postgres_resource_requirements:
    requests:
      cpu: 100m
      memory: 256Mi

  # --- Projects 持久化 (Playbook 项目文件) ---
  projects_persistence: true
  projects_storage_size: 8Gi
  projects_storage_access_mode: ReadWriteMany

  # --- 资源限制 ---
  web_resource_requirements:
    requests:
      cpu: 500m
      memory: 2Gi
  task_resource_requirements:
    requests:
      cpu: 500m
      memory: 2Gi

  # --- 创建预加载数据 ---
  create_preload_data: true
```

## Todos

- [ ] 1. **创建 cloud 命名空间**
  What to do / Must NOT do: 执行 `kubectl create ns cloud` 或 apply namespace YAML
  Parallelization: Wave 1 | Blocked by: — | Blocks: T2,T3,T4
  Files: `01-cloud-namespace.yaml`
  Acceptance criteria: `kubectl get ns cloud` 返回 Active
  QA: `kubectl get namespace cloud -o jsonpath='{.status.phase}'` → Active
  Commit: N

- [ ] 2. **创建 admin 密码 Secret**
  What to do / Must NOT do: 创建 Secret `awx-admin-password`，包含初始 admin 密码。⚠️ 请修改默认密码 `AWXAdmin123!`
  Parallelization: Wave 1 | Blocked by: T1 | Blocks: T4
  Files: `02-awx-admin-password.yaml`
  Acceptance criteria: `kubectl -n cloud get secret awx-admin-password` 存在
  QA: `kubectl -n cloud get secret awx-admin-password -o jsonpath='{.data.password}' | base64 -d` → 显示密码
  Commit: N

- [ ] 3. **安装 AWX Operator CRD**
  What to do / Must NOT do: 安装 AWX Operator 的 CRD (CustomResourceDefinition)，然后部署 Operator Deployment + RBAC
  Parallelization: Wave 2 | Blocked by: T1 | Blocks: T4
  Files: `03-awx-operator-crd.yaml`, `04-awx-operator.yaml`
  Commands:
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/ansible/awx-operator/2.19.1/config/crd/bases/awx.ansible.com_awxs.yaml
    kubectl apply -f 04-awx-operator.yaml
    ```
  Acceptance criteria: `kubectl -n cloud get pod -l app.kubernetes.io/name=awx-operator` → Running
  QA: `kubectl -n cloud logs deployment/awx-operator` → 启动日志无报错
  Commit: N

- [ ] 4. **检查 CCE 存储类**
  What to do / Must NOT do: 确认集群中的 StorageClass 名称。CCE 典型值: `csi-disk-ssd` (SSD), `csi-disk-sas` (SAS), `csi-nfs` (文件存储)
  ⚠️ 如果 `csi-nfs` 不存在，需修改 AWX CR 中 projects_persistence 的 storage class，或改为 false
  Parallelization: Wave 2 | Blocked by: — | Blocks: T4
  Commands:
    ```bash
    kubectl get storageclass
    ```
  Acceptance criteria: 确认可用的 StorageClass 名称，更新到 AWX CR 中

- [ ] 5. **部署 AWX 实例 CR**
  What to do / Must NOT do: 提交 AWX CR，Operator 会自动创建 PostgreSQL、Redis、Web、Task 等全部组件
  ⚠️ 根据 T4 结果，可能需要调整 `projects_storage_access_mode` 对应的 storage class
  Parallelization: Wave 3 | Blocked by: T1,T2,T3,T4 | Blocks: T5
  Files: `05-awx-instance.yaml`
  Commands:
    ```bash
    kubectl apply -f 05-awx-instance.yaml
    ```
  Acceptance criteria: `kubectl -n cloud get awx awx -o jsonpath='{.status}'` → 显示部署进度
  QA: 等待 `kubectl -n cloud get pods -l app.kubernetes.io/instance=awx` 全部 Running
  Commit: N

- [ ] 6. **验证 AWX 部署状态**
  What to do / Must NOT do: 等待 AWX Operator 完成部署（约 3-5 分钟），检查所有 Pod 状态
  Parallelization: Wave 4 | Blocked by: T5 | Blocks: —
  Commands:
    ```bash
    # 查看部署进度
    kubectl -n cloud get pods -w
    
    # 查看 AWX 实例状态
    kubectl -n cloud describe awx awx
    
    # 查看 Service
    kubectl -n cloud get svc -l app.kubernetes.io/instance=awx
    ```
  Acceptance criteria:
    - Pods: awx-web, awx-task, awx-postgres, awx-redis 全部 Running/Ready
    - Service: awx-service 类型 LoadBalancer，EXTERNAL-IP 已分配
  QA: `curl http://<EXTERNAL-IP>/api/v2/` → 返回 AWX API JSON
  Commit: N

- [ ] 7. **初始化 admin 用户**
  What to do / Must NOT do: 如果 `create_preload_data: true` 则自动创建预加载数据；等待数据库迁移完成
  Parallelization: Wave 4 (与 T6 并行) | Blocked by: T5 | Blocks: —
  Commands:
    ```bash
    # 在 task pod 中创建超级用户 (如果需要)
    kubectl -n cloud exec deployment/awx-task -- awx-manage createsuperuser
    ```
  Acceptance criteria: 可通过 admin 用户登录 AWX Web UI
  QA: `curl -u admin:'<password>' http://<EXTERNAL-IP>/api/v2/me/` → 返回用户信息
  Commit: N

## 一键部署脚本

将以下命令在有 kubectl 权限且能连 CCE 的机器上执行:

```bash
#!/bin/bash
KUBECONFIG=/path/to/infra-cce.yaml

# 1. 创建命名空间
kubectl apply -f 01-cloud-namespace.yaml

# 2. 创建密码 Secret (⚠️ 先修改密码)
kubectl apply -f 02-awx-admin-password.yaml

# 3. 安装 AWX Operator CRD + Operator
kubectl apply -f https://raw.githubusercontent.com/ansible/awx-operator/2.19.1/config/crd/bases/awx.ansible.com_awxs.yaml
kubectl apply -f 04-awx-operator.yaml

# 4. 确认存储类
kubectl get storageclass

# 5. 部署 AWX 实例
kubectl apply -f 05-awx-instance.yaml

# 6. 等待部署完成 (约 3-5 分钟)
kubectl -n cloud wait --for=condition=ready pods --all --timeout=300s
kubectl -n cloud get pods
kubectl -n cloud get svc -l app.kubernetes.io/instance=awx
```

## 验证策略

### 自动验证
- `kubectl -n cloud get pods` → 全部 Running
- `kubectl -n cloud get svc -l app.kubernetes.io/instance=awx` → EXTERNAL-IP 非 pending
- `curl -k https://<EXTERNAL-IP>/api/v2/` → HTTP 200 + JSON

### 手动验证
- 浏览器访问 `http://<EXTERNAL-IP>` → AWX 登录页面
- 使用 admin 密码登录 → Dashboard 可见
- 创建测试 Job Template → 执行成功

## 验证波次
- [ ] F1. 所有 Pod 状态 Running
- [ ] F2. LoadBalancer EXTERNAL-IP 已分配
- [ ] F3. API v2 端点可访问
- [ ] F4. admin 用户可登录 Web UI
- [ ] F5. PostgreSQL PV/PVC 绑定成功 (数据持久化)
- [ ] F6. Projects PV/PVC 绑定成功 (文件持久化)
