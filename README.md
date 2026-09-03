# Ansible Monorepo

本仓库收录基于 Ansible 的各中间件/服务自动化部署项目。

## 项目结构

```
.
├── elasticsearch6/   # Elasticsearch 6.x + Kibana + Nginx + Keepalived 集群
├── redis/            # （待建）Redis 集群
├── rabbitmq/         # （待建）RabbitMQ 集群
└── ...
```

## 各子项目独立运作

每个子项目是一个独立完整的 Ansible 工程，可单独 clone 子目录使用，也可统一在 monorepo 根目录编排。

## 开发注意事项

开发任意子项目前，请先阅读该子项目目录下的 `CLAUDE.md`（如有）或 `README.md` 中的开发规范。

公共规则：
- 编码和存储不涉及真实 IP、密码、Token、内部域名
- 跨 OS 兼容性（CentOS / Rocky / Ubuntu）是硬性要求
