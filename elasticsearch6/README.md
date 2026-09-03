# Elasticsearch 6 集群 Ansible 自动化部署

> ⚠️ **开发本项目前，请先阅读 [CLAUDE.md](./CLAUDE.md)** — 包含跨平台兼容性、隐私安全、Git 提交等强制规范。

本项目用于自动化部署基于 **Elasticsearch 6.x** 的三节点高可用集群，集成 Kibana、Nginx 负载均衡和 Keepalived VIP，实现用户通过统一虚拟 IP 访问 Elasticsearch 与 Kibana 服务。

## 支持的操作系统

| 操作系统 | 版本 | 安装方式 |
|----------|------|----------|
| CentOS | 7.x / 8.x | `yum` 包管理器 |
| RockyLinux | 8.x / 9.x / 10.x | `dnf` / `yum` 包管理器 |
| Ubuntu | 18.04 / 20.04 / 22.04 / 24.04 / 26.04 | `apt` 包管理器 |

## 项目架构

```
                    ┌─────────────────────────────────────┐
                    │          用户 / Client              │
                    └──────────────┬──────────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────────────┐
                    │     Keepalived VIP (10.0.0.100)    │
                    │     (高可用浮动IP，单播VRRP协议)       │
                    └──────────────┬───────────────────────┘
                                   │
                    ┌──────────────┴───────────────┐
                    │       Nginx 负载均衡层        │
                    │  (least_conn 算法，健康检查)   │
│   es.example.com → ES 后端       │
│   kibana.example.com → Kibana 后端 │
                    └──────┬───────────────┬───────┘
                           │               │
              ┌────────────┴────┐   ┌──────┴──────────┐
              │                 │   │                 │
              ▼                 ▼   ▼                 ▼
      ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
      │   node01    │  │   node02    │  │   node03    │
      │ 10.0.0.1 │  │ 10.0.0.2 │  │ 10.0.0.3 │
      │              │  │              │  │              │
      │ ES 节点(Priority 80)  │ ES 节点(Priority 90)  │ ES 节点(Priority 100)  │
      │ Kibana 容器  │  │ Kibana 容器  │  │ Kibana 容器  │
      │ Nginx + Keepalived    │ Nginx + Keepalived    │ Nginx + Keepalived    │
      └──────────────┘  └──────────────┘  └──────────────┘
```

## 组件版本

| 组件 | 版本 | 说明 |
|------|------|------|
| Elasticsearch | 6.5.1 | 基于 sebp/elk:651 镜像 |
| Kibana | 6.5.1 | 与 ES 同镜像 |
| Nginx | 系统包 | CentOS/RockyLinux: yum/dnf / Ubuntu: apt |
| Keepalived | 系统包 | CentOS/RockyLinux: yum/dnf / Ubuntu: apt |
| Docker CE | 最新稳定版 | 配置阿里云加速器 |
| Ansible | 2.9+ | 控制端使用，需开启 fact 收集 |

> **注意**: Nginx 和 Keepalived 使用系统包管理器安装，无阿里云/中科大加速器配置。如需使用第三方仓库，请自行配置。

## 环境要求

### 目标节点
- **操作系统**: CentOS 7.x/8.x、RockyLinux 8.x/9.x 或 Ubuntu 18.04/20.04/22.04/24.04/26.04
- **数量**: 至少 3 台节点
- **网络**: 同一局域网内互通
- **SSH**: 允许 root 密码或密钥登录
- **systemd**: 所有目标机器必须启用 systemd

### 控制端
- Python 2.7+ 或 Python 3.5+
- Ansible 2.9 及以上版本
- 网络可达目标节点（SSH 22端口）
- 确保 fact 收集已启用（默认启用，`ansible.cfg` 中已配置 `gathering = smart`）

## 节点规划

| 主机名 | IP 地址 | 角色 | Keepalived Priority |
|--------|---------|------|---------------------|
| node01 | 10.0.0.1 | ES + Kibana + Nginx + Keepalived | 80 (BACKUP) |
| node02 | 10.0.0.2 | ES + Kibana + Nginx + Keepalived | 90 (BACKUP) |
| node03 | 10.0.0.3 | ES + Kibana + Nginx + Keepalived | 100 (MASTER) |
| **VIP** | **10.0.0.100** | 浮动IP | - |

## 快速开始

### 1. 克隆/同步项目

```bash
cd /opt/
git clone <repository-url> elasticsearch6
cd elasticsearch6
```

### 2. 编辑清单文件

修改 `inventory.ini` 中的 IP 地址和 SSH 用户信息为你实际的节点信息：

```ini
[elk_nodes]
node01 ansible_host=10.0.0.1 ansible_user=root
node02 ansible_host=10.0.0.2 ansible_user=root
node03 ansible_host=10.0.0.3 ansible_user=root

[elasticsearch]
node01
node02
node03

[kibana]
node01
node02
node03

[nginx_nodes]
node01
node02
node03
```

### 3. 配置密钥登录（推荐）

```bash
ssh-copy-id root@10.0.0.1
ssh-copy-id root@10.0.0.2
ssh-copy-id root@10.0.0.3
```

### 4. 配置敏感变量

```bash
cp group_vars/all/secrets.yml.example group_vars/all/secrets.yml
vim group_vars/all/secrets.yml
```

填入 Keepalived 认证密码、钉钉 Webhook Token、邮件密码等敏感信息。

### 5. 准备 Docker 镜像

项目使用的 `sebp/elk:651` 是第三方 Docker Hub 镜像，在国内可能拉取缓慢。已配置以下镜像加速器：
- 阿里云：`https://registry.cn-hangzhou.aliyuncs.com`
- 中科大：`https://docker.mirrors.ustc.edu.cn`
- 网易：`https://hub-mirror.c.163.com`

如果加速器仍无法使用，可在有网络的机器上执行 `./scripts/prepare-image.sh pull` 拉取镜像后导出，再复制到目标服务器用 `docker load` 加载。

### 6. 执行部署

```bash
# 全部部署
ansible-playbook site.yml

# ========== 独立部署示例 ==========

# 仅部署 Docker（底层依赖）
ansible-playbook site.yml --tags docker

# 仅部署 Nginx
ansible-playbook site.yml --tags nginx

# 仅部署 Keepalived
ansible-playbook site.yml --tags keepalived

# 仅部署 Nginx + Keepalived
ansible-playbook site.yml --tags nginx,keepalived

# 仅部署 Elasticsearch 集群
ansible-playbook site.yml --tags elasticsearch

# 仅部署 Kibana
ansible-playbook site.yml --tags kibana

# 检查模式（不实际执行变更）
ansible-playbook site.yml --check

# 限制单台节点执行
ansible-playbook site.yml --limit eslog01

# 后台执行
ansible-playbook site.yml --forks 10
```

## 独立部署说明

本项目支持灵活组合部署，您可根据需求仅部署部分组件：

### 场景一：仅部署负载均衡层（Nginx + Keepalived）

适用于已有 Elasticsearch 集群，需要添加负载均衡和高可用的场景。

先确保 `inventory.ini` 中 `nginx_nodes` 组包含目标主机，然后执行：

```bash
ansible-playbook site.yml --tags nginx,keepalived
```

> **依赖**: 无需其他角色依赖。Nginx 配置中的 upstream 地址将由 `group_vars/all/all.yml` 中的变量提供。

### 场景二：仅部署 Elasticsearch 集群

```bash
ansible-playbook site.yml --tags docker,elasticsearch
```

> **依赖**: Elasticsearch 依赖 Docker 容器运行时，建议先部署 `docker` tag。

### 场景三：仅部署 Kibana

```bash
ansible-playbook site.yml --tags docker,kibana
```

### 场景四：部署完整集群后，单独更新负载均衡配置

```bash
ansible-playbook site.yml --tags nginx
ansible-playbook site.yml --tags keepalived
```

### 混合环境支持

所有 role 均支持跨操作系统部署。当您的 `nginx_nodes` 组中同时存在 CentOS 和 Ubuntu 主机时，Ansible 会根据 `ansible_os_family` fact 自动选择正确的安装流程：

- **CentOS**: 使用 `yum` 安装，`firewalld` 配置防火墙，EPEL 源提供 Nginx/Keepalived
- **Ubuntu**: 使用 `apt` 安装，`ufw` 配置防火墙，`nginx_user` 为 `www-data`

## Ansible Role 说明

### docker
- 安装 Docker CE 和 Docker Compose（支持 CentOS/Ubuntu）
- 配置阿里云镜像加速器
- 配置 Docker daemon（overlay2 存储驱动、insecure registries）
- 设置系统内核参数（vm.max_map_count, vm.swappiness, nofile）
- 下载 ELK Docker 镜像

### elasticsearch
- 创建数据、日志、快照目录
- 生成 Elasticsearch 配置文件（elasticsearch.yml.j2）
- 生成 Docker Compose 配置文件
- 启动 Elasticsearch 容器
- 等待集群健康状态变为 green/yellow

### kibana
- 创建 Kibana 数据、日志目录
- 生成 Kibana 配置文件和 Docker Compose
- 等待 Elasticsearch 就绪后启动 Kibana
- 健康检查确认 Kibana 可用

### nginx
- 安装 Nginx（CentOS/Ubuntu 双系统支持）
- 配置反向代理和负载均衡（least_conn 算法）
- 分别代理 Elasticsearch (es.example.com) 和 Kibana (kibana.example.com)
- 提供健康检查端点 `/nginx-health`
- 自动配置系统防火墙

### keepalived
- 安装 Keepalived（CentOS/Ubuntu 双系统支持，邮件工具 CentOS 用 mailx / Ubuntu 用 mailutils）
- 部署健康检查脚本（检查 Nginx + ES 状态）
- 配置单播 VRRP 模式，避免广播风暴
- 配置 VIP 浮动 IP
- 支持钉钉/邮件状态通知
- 自动配置系统防火墙放行 VRRP

## 全局变量配置

编辑 `group_vars/all/all.yml` 调整配置：

```yaml
# Docker 镜像
elk_image: sebp/elk:651

# 集群名称
cluster_name: eslog-cluster

# Elasticsearch
es_heap_size: 8192m              # JVM 堆内存
es_http_port: 9200               # HTTP API 端口
es_transport_port: 9300          # 节点通信端口
es_memory_limit: 16g             # 容器内存限制

# Kibana
kibana_port: 5601

# Nginx
nginx_listen_port: 80
es_domain: es.example.com           # ES 访问域名
kibana_domain: kibana.example.com     # Kibana 访问域名

# Keepalived
keepalived_virtual_ip: 10.0.0.100/24
keepalived_interface: eth0       # 网络接口名，需根据实际情况调整
keepalived_virtual_router_id: 170
keepalived_priority_node01: 80
keepalived_priority_node02: 90
keepalived_priority_node03: 100

# 系统参数
vm_max_map_count: 262144         # ES 要求最小值
vm_swappiness: 0                 # 禁用 swap
```

## 操作系统差异对照表

| 配置项 | CentOS | RockyLinux | Ubuntu |
|--------|--------|------------|--------|
| 包管理器 | `yum` | `dnf` / `yum` | `apt` |
| Nginx 运行用户 | `nginx` | `nginx` | `www-data` |
| Nginx PID 路径 | `/run/nginx.pid` | `/run/nginx.pid` | `/run/nginx.pid` |
| 防火墙工具 | `firewalld` | `firewalld` | `ufw` |
| EPEL 源 | 需要启用 | 需要启用 | 不适用 |
| 邮件包名 | `mailx` | `mailx` | `mailutils` |
| 默认站点配置 | `/etc/nginx/conf.d/default.conf` | `/etc/nginx/conf.d/default.conf` | `/etc/nginx/sites-enabled/default` |
| Docker CE 仓库 | `centos` | `centos` (兼容) | `ubuntu` |
| 基础镜像源 | `mirrors.aliyun.com/centos` | `mirrors.aliyun.com/rocky` | `mirrors.aliyun.com/ubuntu` |

## 访问方式

部署完成后，通过 Keepalived VIP 统一访问：

- **Elasticsearch**: `http://10.0.0.100` 或 `http://es.example.com`
- **Kibana**: `http://10.0.0.100`（通过 server_name kibana.example.com 路由）

也可以直接访问各节点：
- `http://10.0.0.1:9200` (ES)
- `http://10.0.0.1:5601` (Kibana)

## 部署后验证

### 查看集群健康状态

```bash
curl http://10.0.0.100:9200/_cluster/health?pretty
```

### 查看集群节点

```bash
curl http://10.0.0.100:9200/_cat/nodes?v
```

### 查看 VIP 当前指向

```bash
ansible nginx_nodes -m shell -a "ip addr show eth0 | grep 10.0.0.100"
```

### 检查服务状态

```bash
ansible elk_nodes -m shell -a "systemctl status nginx keepalived docker -o short"
ansible elk_nodes -m shell -a "docker ps -a --format 'table {{.Names}}\t{{.Status}}'"
```

## 项目结构

```
elasticsearch6/
├── ansible.cfg                    # Ansible 配置文件
├── inventory.ini                  # 主机清单
├── site.yml                       # 主入口 Playbook
├── group_vars/
│   └── all/
│       ├── all.yml                # 全局变量
│       ├── secrets.yml            # 敏感变量（需手动创建）
│       └── secrets.yml.example    # 敏感变量模板
├── host_vars/                     # 主机级变量（按需使用）
├── roles/
│   ├── docker/                    # Docker 安装配置
│   │   ├── defaults/main.yml      # 独立默认变量
│   │   ├── vars/                  # OS 特定变量 (RedHat.yml/Debian.yml)
│   │   └── tasks/main.yml         # 支持双系统的任务
│   ├── elasticsearch/             # ES 集群部署
│   │   ├── defaults/main.yml
│   │   ├── vars/
│   │   └── tasks/main.yml
│   ├── kibana/                    # Kibana 部署
│   │   ├── defaults/main.yml
│   │   ├── vars/
│   │   └── tasks/main.yml
│   ├── nginx/                     # Nginx 负载均衡
│   │   ├── defaults/main.yml
│   │   ├── vars/                  # OS 特定变量
│   │   └── tasks/main.yml         # 支持双系统的任务
│   └── keepalived/                # VIP 高可用
│       ├── defaults/main.yml
│       ├── vars/                  # OS 特定变量
│       └── tasks/main.yml         # 支持双系统的任务
├── scripts/
│   └── prepare-image.sh           # 镜像下载辅助脚本
├── IMAGE_GUIDE.md                 # Docker 镜像问题解决方案
└── README.md                      # 本文件
```

## 高可用机制说明

### Keepalived VIP 高可用
- 使用 VRRP 协议在 3 个节点间选举 MASTER
- 优先级：eslog03(100) > eslog02(90) > eslog01(80)
- 采用**单播模式**（unicast），避免生产环境广播风暴
- 健康检查脚本每 1 秒检测 Nginx 和 ES 状态
- 失败时自动降低优先级触发 VIP 漂移，权重 -20
- 支持钉钉 Webhook 和邮件通知切换事件

### Elasticsearch 集群容错
- 三节点集群，`discovery.zen.minimum_master_nodes: 2`，防止脑裂
- 任一节点故障不影响集群读写，只影响性能
- 单节点恢复后自动重新加入集群

### Nginx 负载均衡
- 上游服务器采用 `least_conn` 最少连接算法
- 健康检查参数 `max_fails=3 fail_timeout=30s`
- 任一后端节点故障时自动摘除
- Keepalived 健康检查脚本会在 Nginx 异常时尝试重启一次

## 故障处理

### VIP 漂移
1. 确认当前 MASTER 节点：`ip addr show eth0 | grep 10.0.0.100`
2. 查看 Keepalived 日志：`journalctl -u keepalived -f`
3. 检查通知日志：`cat /var/log/keepalived-notify.log`

### ES 集群变红/黄
1. 查看集群健康：`curl http://localhost:9200/_cluster/health?pretty`
2. 查看未分配分片：`curl http://localhost:9200/_cat/shards?v&h=index,shard,state`
3. 查看节点状态：`curl http://localhost:9200/_cat/nodes?v`

### Nginx 无法代理
1. 检查 Nginx 自身状态：`curl http://localhost/nginx-health`
2. 检查后端可达性：`curl http://localhost:9200/_cluster/health`
3. 查看 Nginx 错误日志：`tail -f /var/log/nginx/es_error.log`

## 维护操作

### 滚动重启 Kibana（更新配置后）
```bash
ansible-playbook site.yml --tags kibana-vip
```

### 重新部署 Elasticsearch（注意：会先停止容器）
```bash
ansible-playbook site.yml --tags elasticsearch -e "ansible_check_mode=false"
```

### 更新 Nginx 配置
```bash
ansible-playbook site.yml --tags nginx
```

### 重新配置 Keepalived
```bash
ansible-playbook site.yml --tags keepalived

# 手动重启 Keepalived
ansible nginx_nodes -m systemd -a "name=keepalived state=restarted" -b
```

## 注意事项

1. **数据备份**: Elasticsearch 快照目录为 `/opt/eslog-cluster/es-snapshots`，建议定期备份
2. **内存配置**: 默认 JVM 堆内存 8GB，容器内存限制 16GB，请根据实际硬件调整
3. **防火墙**: 脚本会自动放行 TCP 80 和 VRRP 协议，请确保 9200/9300 端口互通
4. **SELinux**: CentOS/RockyLinux 如遇权限问题，可临时 `setenforce 0` 或配置 SELinux 策略
5. **网络接口名**: 默认 `eth0`，若实际不同请在 `group_vars/all/all.yml` 中修改 `keepalived_interface`
6. **sebp/elk 镜像**: 此为 6.5.1 版本，如需升级到 6.8.x 请修改镜像标签并相应调整 Ansible 配置
7. **Fact 收集**: 多系统支持依赖 `ansible_os_family`、`ansible_distribution` 等 fact，请勿在 `ansible.cfg` 或 playbook 中禁用 fact 收集
8. **RockyLinux 兼容性**: RockyLinux 8/9 与 RHEL 8/9 二进制兼容，yum/dnf 包名、systemd 路径、firewalld 配置均一致，无需额外适配
