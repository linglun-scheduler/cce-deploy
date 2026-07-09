#!/bin/bash
# ──────────────────────────────────────────────
# AWX OSC 上传帮助脚本
# ──────────────────────────────────────────────
echo "========================================"
echo "  AWX OSC 上传指引"
echo "========================================"
echo ""
echo "提供两种上传方式:"
echo ""
echo "方式一 (推荐): OSC 格式包"
echo "  文件: /tmp/awx-24.6.1.zip"
echo "  上传: OSC控制台 → 我的服务 → 私有服务 → 上传服务"
echo "  说明: 由 oscctl 转换的标准 OSC 格式"
echo ""
echo "方式二: 原生 Helm Chart"
echo "  文件: /tmp/awx-1.0.0.tgz"
echo "  上传: OSC控制台 → 我的服务 → 私有服务 → 上传服务"
echo "  注意: 选择仓库类型时选「容器镜像仓库」"
echo ""
echo "重新打包:"
echo "  cd osc-package && zip -r /tmp/awx-24.6.1.zip awx/"
echo "  cd awx-chart && helm package . -d /tmp/"
