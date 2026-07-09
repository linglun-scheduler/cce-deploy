# Draft: awx-huawei-publish

## Intent

CLEAR — 分析 AWX 功能并将 AWX 容器镜像发布到华为云 SWR 镜像仓。

## Research Findings

### AWX 项目概览

**仓库**: https://github.com/ansible/awx  
**Stars**: 15.5k | **License**: Apache 2.0 | **语言**: Python (98.1%)  
**最后发布**: v24.6.1 (2024-07-02) — 项目正在大规模重构，新版本发布暂停

**描述**: AWX 是基于 Ansible 的 Web 用户界面、REST API 和任务引擎。它是 Red Hat Ansible Automation Platform 的上游项目。

### AWX 核心功能

1. **Web UI** — 基于 React 的前端界面，提供可视化 Ansible 作业管理
2. **REST API** — 完整的 RESTful API (v2)，支持所有操作自动化
3. **任务引擎** — 基于 Receptor 的分布式任务执行系统
4. **作业管理** — 运行、调度和监控 Ansible Playbook 作业
5. **清单管理** — 动态和静态清单管理，支持云提供商动态清单
6. **凭据管理** — 加密存储 SSH 密钥、密码、云凭据
7. **基于角色的访问控制 (RBAC)** — 组织、团队、用户权限管理
8. **项目与 SCM 同步** — 从 Git/SVN 同步 Playbook 项目
9. **作业模板** — 可复用的作业配置模板
10. **执行环境 (EE)** — 容器化作业执行环境 (ansible-builder)
11. **集群/高可用** — 多节点 AWX 集群，Receptor 网格网络
12. **通知集成** — Slack、Email、Webhook 等通知
13. **日志聚合** — 支持 Splunk、Elasticsearch、Logstash 等
14. **AWX CLI (awxkit)** — 命令行客户端
15. **OpenTelemetry** — 分布式追踪和指标

### AWX 架构演进

AWX 当前正在从单体架构重构为**可插拔的面向服务架构 (SOA)**。新架构下：
- 旧的 docker-compose 部署方式仅用于开发/测试
- **生产部署推荐使用 AWX Operator (Kubernetes)**
- 项目发布已暂停，专注于重构

### AWX 容器镜像清单

从 GitHub Container Registry (ghcr.io/ansible) 发布的容器包:

| 镜像名称 | 下载量 | 说明 |
|---------|--------|------|
| `ghcr.io/ansible/awx` | 181k | 主要 AWX 运行时镜像 |
| `ghcr.io/ansible/awx_devel` | 411k | AWX 开发镜像 |
| `ghcr.io/ansible/awx-operator` | 32.7k | Kubernetes Operator 镜像 |
| `ghcr.io/ansible/awx-ee` | 12.7k | 默认执行环境镜像 |
| `ghcr.io/ansible/awx_kube_devel` | 10.9k | Kubernetes 开发镜像 |

**需要同步到华为云的镜像**:
1. **awx** — 核心应用镜像 (多架构: linux/amd64, linux/arm64)
2. **awx-operator** — Kubernetes Operator (可选，如果用 K8s 部署)
3. **awx-ee** — 默认执行环境 (可选，如果使用自定义 EE 则不需要)
4. **awx_devel** — 可选，仅开发用途
5. **awx_kube_devel** — 可选，仅开发用途

### AWX 部署方式

**方式 1: AWX Operator (推荐 — v18.0+)**
- 在 Kubernetes 集群上通过 CRD 管理 AWX 实例
- 需要镜像: awx, awx-operator, awx-ee
- 部署文档: https://github.com/ansible/awx-operator

**方式 2: Docker Compose (仅开发/测试)**
- 需要 awx 镜像 + PostgreSQL + Redis
- 参考: tools/docker-compose/README.md

### 华为云 SWR 推送流程

**步骤概要**:
1. 登录华为云 SWR 控制台
2. 创建组织 (Organization)
3. 获取登录命令 (临时或长期 AK/SK)
4. 本地执行 `docker login` 到 SWR 地址
5. 对镜像打标签 (tag) 为 SWR 地址格式
6. 执行 `docker push` 推送到 SWR

**SWR 镜像地址格式**:
```
swr.{region}.myhuaweicloud.com/{organization}/{image-name}:{tag}
```

**登录方式**:
- 临时: 控制台获取临时登录命令 (有效期 6-24 小时)
- 长期: 使用 AK/SK 获取长期有效命令

### 已确认的决策

| 决策项 | 选择 |
|--------|------|
| Region | cn-east-2 (华东-上海二) |
| 组织名 | dx_x2era |
| 发布镜像 | 全部 5 个 (awx, awx-operator, awx-ee, awx_devel, awx_kube_devel) |
| 版本策略 | 最新稳定发行版 (24.6.1)，不使用 `latest` tag |
| 部署方式 | Kubernetes + AWX Operator |
| 同步策略 | 一次性手动同步 |

### SWR 镜像地址格式

```
swr.cn-east-2.myhuaweicloud.com/dx_x2era/{image-name}:{tag}
```

### 需要同步的镜像清单

| # | 源镜像 (GHCR) | 目标 (SWR) |
|---|--------------|------------|
| 1 | `ghcr.io/ansible/awx:24.6.1` | `swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx:24.6.1` |
| 2 | `ghcr.io/ansible/awx-operator:2.19.1` | `swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx-operator:2.19.1` |
| 3 | `ghcr.io/ansible/awx-ee:24.6.1` | `swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx-ee:24.6.1` |
| 4 | `ghcr.io/ansible/awx_devel:devel` | `swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx_devel:24.6.1` |
| 5 | `ghcr.io/ansible/awx_kube_devel:devel` | `swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx_kube_devel:24.6.1` |

**注意**: 最新稳定发行版 = AWX v24.6.1, Operator v2.19.1（匹配版本）

## Status

awaiting-approval

## Pending Action

- [x] 完成研究分析
- [x] 完成决策收集
- [x] 编写完整计划 (`.omo/plans/awx-huawei-publish.md`)
- [ ] 等待用户批准后执行

## 执行命令速查

推送全部 5 个镜像的最终命令汇总：

```bash
# 1. 登录华为云 SWR（从控制台获取临时命令）
docker login swr.cn-east-2.myhuaweicloud.com

# 2. 拉取镜像
docker pull ghcr.io/ansible/awx:24.6.1
docker pull ghcr.io/ansible/awx-operator:2.19.1
docker pull ghcr.io/ansible/awx-ee:24.6.1
docker pull ghcr.io/ansible/awx_devel:devel
docker pull ghcr.io/ansible/awx_kube_devel:devel

# 3. 标记并推送
IMAGES="awx:24.6.1 awx-operator:2.19.1 awx-ee:24.6.1"
for img in $IMAGES; do
  docker tag ghcr.io/ansible/$img swr.cn-east-2.myhuaweicloud.com/dx_x2era/$img
  docker push swr.cn-east-2.myhuaweicloud.com/dx_x2era/$img
done

docker tag ghcr.io/ansible/awx_devel:devel swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx_devel:24.6.1
docker push swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx_devel:24.6.1

docker tag ghcr.io/ansible/awx_kube_devel:devel swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx_kube_devel:24.6.1
docker push swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx_kube_devel:24.6.1
```
