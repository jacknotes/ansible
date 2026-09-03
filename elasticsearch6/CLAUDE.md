# 项目开发规则

> **开发本项目前，请完整阅读本文件。所有代码变更必须遵守以下规则。**

---

## 一、跨平台兼容性（强制）

本项目支持以下操作系统，所有 Ansible 任务必须确保全部兼容：

| 系统族 | 发行版 | 版本 | 包管理器 |
|--------|--------|------|----------|
| RedHat | CentOS | 7, 8 | yum |
| RedHat | RockyLinux | 9, 10 | dnf (兼容 yum) |
| Debian | Ubuntu | 18.04, 20.04, 22.04, 24.04, 26.04 | apt |

### 1.1 编写 Ansible 任务时的硬性要求

- **禁止使用 `yum` 或 `apt` 模块**，统一使用 `package` 模块（自动适配 yum/dnf/apt）
- 必须通过 `when: ansible_os_family == "RedHat"` / `"Debian"` 做系统分流
- 使用 `include_vars` + `with_first_found` 加载 OS 特定变量文件，加载顺序：
  1. `{{ distribution }}-{{ major_version }}.yml` （如 rocky-9.yml）
  2. `{{ distribution }}.yml`
  3. `{{ os_family }}.yml`
  4. `default.yml`
- 所有系统差异的变量（用户名、路径、包名等）必须定义在 `roles/<role>/vars/` 目录
- 不得在模板或任务中硬编码 OS 相关的路径、用户名、包名

### 1.2 已知差异对照表

| 差异项 | CentOS / RockyLinux | Ubuntu |
|--------|---------------------|--------|
| Nginx 运行用户 | `nginx` | `www-data` |
| 防火墙工具 | `firewalld` | `ufw` |
| 邮件包名 | `mailx` | `mailutils` |
| Nginx 默认站点路径 | `/etc/nginx/conf.d/default.conf` | `/etc/nginx/sites-enabled/default` |

### 1.3 其他注意事项

- Alpine/Arch 等其他发行版不在支持范围，无需考虑
- `systemd` 在所有目标系统上可用，可直接使用 `systemd` 模块
- `firewalld` 和 `ufw` 的使用必须用 `ignore_errors: yes`，因为目标系统可能未启用防火墙
- 涉及 GPG 密钥的仓库配置，建议关闭 gpgcheck（`gpgcheck=0`），避免镜像同步问题

---

## 二、隐私与安全管理（强制）

### 2.1 禁止提交到 Git 的内容

以下**绝对不得**出现在任何提交中：

- 真实 IP 地址（公网或内网）
- 真实邮箱地址
- 内部域名（含公司/组织域名）
- 密码、API Key、Token、Secret
- SSH 私钥、SSL 证书
- 服务器主机名（除 example.com 等示例外）
- 任何可关联到真实环境的信息

### 2.2 .gitignore 规则（必须遵守）

以下文件已被 `.gitignore` 排除，**不要**尝试将其加入追踪：

```
inventory.ini          # 真实环境清单
secrets.yml            # 真实密码/密钥
*.pem, *.key, *.pub   # SSL/SSH 密钥
*.retry                # Ansible 重试文件（含主机信息）
IMPLEMENTATION_PLAN.md # 内部规划文档
```

### 2.3 文件替换规则

| 禁止出现（真实值） | 必须使用（示例值） |
|-------------------|-------------------|
| `192.168.x.x` / `10.x.x.x` | `10.0.0.1` |
| `user@company.com` | `admin@example.com` |
| `smtp.company.com` | `smtp.example.com` |
| `harbor.company.com` | 变量 `{{ harbor_registry_url }}`（默认空列表） |
| `elk_password_2024` | `YOUR_PASSWORD_HERE`（在 .example 文件中） |

### 2.4 模板变量的处理方式

涉及敏感信息时，采用"变量定义在 `defaults/main.yml`（公开值），真实值在 `secrets.yml`"的模式：

```yaml
# roles/<role>/defaults/main.yml（公开）
db_password: ""  # 请在 secrets.yml 中覆盖

# group_vars/all/secrets.yml（gitignore，不提交）
db_password: "真实密码"
```

对应的 `secrets.yml.example` 文件**必须**同步提供：

```yaml
# group_vars/all/secrets.yml.example（提交）
db_password: "YOUR_DB_PASSWORD_HERE"
```

---

## 三、Git 提交规范

### 3.1 提交前检查清单

推送前**必须**确认：

- [ ] `git status` 无意外文件（尤其 inventory.ini、secrets.yml）
- [ ] `git diff --staged` 无真实 IP、邮箱、密码
- [ ] 新变量在 `defaults/main.yml` 有默认值
- [ ] 敏感变量已在 `.gitignore` 排除
- [ ] 对应的 `.example` 文件已创建/更新

### 3.2 提交消息规范

```
type(scope): subject

body
```

类型：`feat`/`fix`/`security`/`docs`/`refactor`

---

## 四、Docker 相关

- 默认使用公共镜像（如 `sebp/elk:651`），不硬编码私有仓库
- 私有仓库应通过变量 + secrets.yml 配置
- `insecure-registries` 默认空列表，不要在 daemon.json 模板中硬编码内网地址
- 使用阿里云镜像加速器，但允许变量覆盖

---

## 五、其他规范

- 代码注释使用中文
- 任务/文件头部注释说明功能
- 新增 OS 支持时，需同步更新 `vars/` 中对应的 OS 变量文件
- 每个 role 的 `defaults/main.yml` 应包含该 role 所有变量的默认值，确保可独立部署
