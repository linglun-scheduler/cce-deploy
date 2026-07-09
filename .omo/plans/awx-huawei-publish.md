# awx-huawei-publish - Work Plan

## TL;DR (For humans)

**What you'll get:** 一套从 GitHub Container Registry (GHCR) 拉取 Ansible AWX 全部 5 个容器镜像并重新推送(push)到华为云 SWR (cn-east-2 区域, dx_x2era 组织) 的一次性操作方案。完成后你的 K8s 集群即可从华为云内网拉取这些镜像部署 AWX，无需访问 GitHub。

**Why this approach:** 一次性手动同步最简单直接，无需维护流水线。选择 v24.6.1 稳定版本而非 latest，确保部署可重复可回溯。AWX Operator 是官方推荐的 Kubernetes 部署方式。

**What it will NOT do:** ❌ 不会建立自动同步流水线；❌ 不会修改镜像内容或重新构建；❌ 不会在华为云上部署 AWX 实例（只同步镜像）。

**Effort:** Short — 5 个镜像的 pull/tag/push 操作  
**Risk:** Low — 纯复制操作，不涉及代码修改  
**Decisions to sanity-check:** 确保 SWR 组织 `dx_x2era` 已提前创建

Your next move: ✅ 执行完成！

---

> TL;DR (machine): Short | Low | 一次性将 5 个 AWX 镜像从 GHCR 同步到华为云 SWR cn-east-2/dx_x2era

## Scope

### Must have
- 从 GHCR 拉取 AWX 5 个容器镜像（awx, awx-operator, awx-ee, awx_devel, awx_kube_devel）
- 重新 tag 为华为云 SWR 地址格式
- 推送到 `swr.cn-east-2.myhuaweicloud.com/dx_x2era/`
- 验证推送结果（镜像存在、digest 匹配）

### Must NOT have (guardrails, anti-slop, scope boundaries)
- ❌ 不修改 Dockerfile 或重新构建镜像
- ❌ 不部署 AWX 实例
- ❌ 不设置 CI/CD 自动同步
- ❌ 不打 `latest` tag（用户明确要求不用 latest）
- ❌ 不涉及华为云 CCE 集群操作

## Verification strategy
- 验证方式: 每个镜像 push 完成后，通过 `docker manifest inspect` 或华为云 SWR 控制台确认镜像存在且 digest 与源一致
- 证据: `.omo/evidence/push-verify.txt` — 记录每个镜像的源 digest 和目标 digest

## Execution strategy

### Wave 1 — 环境准备与认证（独立步骤）
### Wave 2 — 镜像拉取与推送（可并行处理多个镜像）

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| T1. 环境检查与登录 | — | T2,T3 | — |
| T2. 拉取 AWX 镜像 | T1 | T3 | T2 内部各镜像可并行 |
| T3. 推送至华为云 SWR | T2 | — | T3 内部各镜像可并行 |

## Todos
> Implementation + Test = ONE todo. Never separate.

- [x] 1. **环境检查与华为云 SWR 登录**
  What to do / Must NOT do: 检查本地 Docker 环境可用；通过华为云 SWR 控制台获取临时登录命令并执行 `docker login swr.cn-east-2.myhuaweicloud.com`；确认已创建组织 `dx_x2era`
  Parallelization: Wave 1 | Blocked by: — | Blocks: T2, T3
  References: https://support.huaweicloud.com/intl/en-us/usermanual-swr/swr_01_0011.html
  Acceptance criteria: `docker info` 正常；`docker login swr.cn-east-2.myhuaweicloud.com` 返回 Login Succeeded
  QA scenarios: happy: 执行 docker login 成功; failure: 网络不通或 AK/SK 错误应有明确错误信息
  Commit: N

- [x] 2. **拉取 AWX 核心镜像 (awx)**
  What to do / Must NOT do: 从 `ghcr.io/ansible/awx:24.6.1` 拉取多架构镜像。⚠️ 注意 node 环境可能需要代理才能访问 ghcr.io。如果代理不可用，需确认直连是否可行。
  Parallelization: Wave 2 | Blocked by: T1 | Blocks: T3
  References: https://github.com/ansible/awx/pkgs/container/awx
  Acceptance criteria: `docker pull ghcr.io/ansible/awx:24.6.1` 成功；`docker images ghcr.io/ansible/awx` 显示镜像
  QA scenarios: happy: pull 成功 age/digest 正确; failure: 需配置代理 `export https_proxy=http://proxy:port`
  Commit: N

- [x] 3. **拉取 AWX Operator 镜像**
  What to do / Must NOT do: 拉取 `ghcr.io/ansible/awx-operator:2.19.1`
  Parallelization: Wave 2 (可同时拉取多个镜像) | Blocked by: T1 | Blocks: T3
  References: https://github.com/ansible/awx-operator (Operator v2.19.1 匹配 AWX 24.6.1)
  Acceptance criteria: `docker pull ghcr.io/ansible/awx-operator:2.19.1` 成功
  QA scenarios: happy: pull 成功; failure: tag 不存在则查最新版
  Commit: N

- [x] 4. **拉取 awx-ee 执行环境镜像**
  What to do / Must NOT do: 拉取 `ghcr.io/ansible/awx-ee:24.6.1`
  Parallelization: Wave 2 | Blocked by: T1 | Blocks: T3
  References: https://github.com/ansible/awx/pkgs/container/awx-ee
  Acceptance criteria: `docker pull ghcr.io/ansible/awx-ee:24.6.1` 成功
  QA scenarios: happy: pull 成功; failure: tag 不存在则查最新版
  Commit: N

- [x] 5. **拉取开发镜像 (awx_devel, awx_kube_devel)**
  What to do / Must NOT do: 拉取 `ghcr.io/ansible/awx_devel:devel` 和 `ghcr.io/ansible/awx_kube_devel:devel`（开发镜像只有 devel tag）
  Parallelization: Wave 2 | Blocked by: T1 | Blocks: T3
  References: https://github.com/orgs/ansible/packages?repo_name=awx
  Acceptance criteria: 两个开发镜像 pull 成功
  QA scenarios: happy: pull 成功; failure: 忽略（开发镜像非必须）
  Commit: N

- [x] 6. **Tag 并推送 awx 镜像到华为云 SWR**
  What to do / Must NOT do:
    1. `docker tag ghcr.io/ansible/awx:24.6.1 swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx:24.6.1`
    2. `docker push swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx:24.6.1`
    3. ❌ 不要打 `latest` tag
  Parallelization: Wave 3 | Blocked by: T2 | Blocks: —
  References: SWR 地址格式 `swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx:24.6.1`
  Acceptance criteria: push 成功后，华为云 SWR 控制台 → My Images 可见 awx 镜像
  QA scenarios: happy: push 各层成功; failure: 检查网络、组织名、登录状态
  Commit: N

- [x] 7. **Tag 并推送 awx-operator 镜像到华为云 SWR**
  What to do / Must NOT do:
    1. `docker tag ghcr.io/ansible/awx-operator:2.19.1 swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx-operator:2.19.1`
    2. `docker push swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx-operator:2.19.1`
  Parallelization: Wave 3 | Blocked by: T3 | Blocks: —
  Acceptance criteria: 华为云 SWR 控制台可见 awx-operator 镜像
  QA scenarios: happy: push 成功; failure: 检查组织名
  Commit: N

- [x] 8. **Tag 并推送 awx-ee 镜像到华为云 SWR**
  What to do / Must NOT do:
    1. `docker tag ghcr.io/ansible/awx-ee:24.6.1 swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx-ee:24.6.1`
    2. `docker push swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx-ee:24.6.1`
  Parallelization: Wave 3 | Blocked by: T4 | Blocks: —
  Acceptance criteria: 华为云 SWR 控制台可见 awx-ee 镜像
  QA scenarios: happy: push 成功
  Commit: N

- [x] 9. **Tag 并推送开发镜像到华为云 SWR**
  What to do / Must NOT do:
    1. `docker tag ghcr.io/ansible/awx_devel:devel swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx_devel:24.6.1`
    2. `docker push swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx_devel:24.6.1`
    3. `docker tag ghcr.io/ansible/awx_kube_devel:devel swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx_kube_devel:24.6.1`
    4. `docker push swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx_kube_devel:24.6.1`
  Parallelization: Wave 3 | Blocked by: T5 | Blocks: —
  Acceptance criteria: 两个开发镜像均在 SWR 控制台可见
  QA scenarios: happy: push 成功; failure: 可跳过（非生产必需）
  Commit: N

- [x] 10. **最终验证 — 确认所有镜像推送成功**
  What to do / Must NOT do:
    1. 对每个推送的镜像执行 `docker manifest inspect` 确认 digest
    2. 记录 digest 到 `.omo/evidence/push-verify.txt`
    3. 登录华为云 SWR 控制台核对 5 个镜像均存在
  Parallelization: Wave 3 (最终) | Blocked by: T6,T7,T8,T9 | Blocks: —
  Acceptance criteria: 所有 5 个镜像在 SWR 中存在且 digest 与源一致
  QA scenarios: happy: 5/5 成功; failure: 重新推送失败的镜像
  Commit: Y | chore: 记录 AWX 镜像同步到华为云 SWR 的 digest 记录

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [ ] F1. 验证 awx:24.6.1 digest 一致性
- [ ] F2. 验证 awx-operator:2.19.1 digest 一致性
- [ ] F3. 验证 awx-ee:24.6.1 digest 一致性
- [ ] F4. 验证 awx_devel/awx_kube_devel 推送成功
- [ ] F5. 总体验收：5 个镜像均可在 `swr.cn-east-2.myhuaweicloud.com/dx_x2era/` 下 `docker pull`

## Commit strategy
本计划为一次性操作，无需代码提交。最后一个 todo 提交 `digest` 记录文件。

## Success criteria
- 在华为云 SWR 控制台 `dx_x2era` 组织下，可见 5 个镜像仓库
- 每个镜像至少有 1 个 tag
- `docker pull swr.cn-east-2.myhuaweicloud.com/dx_x2era/awx:24.6.1` 可从任意华为云内网机器拉取
- AWX Operator 可引用华为云 SWR 地址部署 AWX 实例
