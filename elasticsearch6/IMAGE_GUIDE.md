# Docker镜像在中国拉取问题说明

## 问题描述

`sebp/elk:651` 是一个第三方Docker Hub镜像，在中国大陆直接拉取可能遇到以下问题：

1. **拉取速度极慢**：Docker Hub在中国没有CDN节点
2. **连接超时**：网络不稳定导致连接中断
3. **拉取失败**：某些时段完全无法访问

## 解决方案

### 方案1：使用Docker镜像加速器（推荐）

已自动配置以下加速器：
- 阿里云：`https://registry.cn-hangzhou.aliyuncs.com`
- 中科大：`https://docker.mirrors.ustc.edu.cn`
- 网易：`https://hub-mirror.c.163.com`

**验证加速器是否生效：**
```bash
docker info | grep -A 5 "Registry Mirrors"
```

**手动配置加速器：**
```bash
# 运行镜像准备脚本
./scripts/prepare-image.sh mirror
```

### 方案2：离线导入镜像（最可靠）

适用于完全无法访问外网的环境。

**步骤1：在有网络的机器上保存镜像**
```bash
# 配置加速器后拉取
./scripts/prepare-image.sh pull

# 或手动拉取并保存
docker pull sebp/elk:651
docker save sebp/elk:651 | gzip > elk-image-651.tar.gz
```

**步骤2：复制文件到目标服务器**
```bash
scp elk-image-651.tar.gz user@target-server:/opt/
```

**步骤3：在目标服务器加载镜像**
```bash
./scripts/prepare-image.sh load

# 或手动加载
docker load < elk-image-651.tar.gz
```

### 方案3：使用阿里云私有镜像仓库

**步骤1：创建阿里云容器镜像服务实例**
1. 登录 [阿里云容器镜像服务](https://cr.console.aliyun.com/)
2. 创建命名空间（例如：`your_namespace`）
3. 创建仓库（例如：`elk`）

**步骤2：推送镜像到阿里云**
```bash
# 登录阿里云容器镜像服务
docker login registry.cn-hangzhou.aliyuncs.com

# 推送镜像
./scripts/prepare-image.sh push your_namespace

# 或手动推送
docker tag sebp/elk:651 registry.cn-hangzhou.aliyuncs.com/your_namespace/elk:651
docker push registry.cn-hangzhou.aliyuncs.com/your_namespace/elk:651
```

**步骤3：修改Ansible配置**
编辑 `group_vars/all.yml`：
```yaml
elk_image: registry.cn-hangzhou.aliyuncs.com/your_namespace/elk:651
```

### 方案4：使用官方分离镜像

如果`sebp/elk`镜像无法获取，可以使用Elastic官方镜像分别部署ES和Kibana。

**修改 `group_vars/all.yml`：**
```yaml
# 使用官方镜像
es_image: docker.elastic.co/elasticsearch/elasticsearch:6.8.23
kibana_image: docker.elastic.co/kibana/kibana:6.8.23
```

**注意：** 官方镜像需要单独配置，且版本号与`sebp/elk:651`不同（651对应ES 6.5.1）

## Ansible部署时的镜像处理

### 自动重试机制

已配置Docker角色在拉取镜像时自动重试5次，每次间隔10秒。

### 手动预拉取

在运行Ansible之前，可以手动在各节点拉取镜像：

```bash
# 在每个节点执行
ansible elk_nodes -m shell -a "docker pull sebp/elk:651" -f 3
```

### 批量导入

如果已经准备好镜像文件，可以批量导入到所有节点：

```bash
# 分发镜像文件到所有节点
ansible elk_nodes -m copy -a "src=elk-image-651.tar.gz dest=/tmp/elk-image-651.tar.gz"

# 在所有节点加载镜像
ansible elk_nodes -m shell -a "docker load < /tmp/elk-image-651.tar.gz"
```

## 故障排除

### 检查网络连通性
```bash
# 测试Docker Hub连通性
curl -v https://registry-1.docker.io/v2/

# 测试加速器连通性
curl -v https://registry.cn-hangzhou.aliyuncs.com/v2/
```

### 检查Docker配置
```bash
# 查看当前配置
docker info

# 查看镜像源
cat /etc/docker/daemon.json
```

### 清理重试
```bash
# 清理Docker缓存
docker system prune -a

# 重新配置并重启
./scripts/prepare-image.sh mirror
```

## 推荐流程

对于新环境部署，推荐以下流程：

1. **准备阶段**（在有网络的机器上）：
   ```bash
   cd ansible
   ./scripts/prepare-image.sh pull
   ```

2. **分发阶段**：
   ```bash
   # 将镜像文件和ansible目录一起复制到控制节点
   scp -r ansible/ elk-image-651.tar.gz control-node:/opt/
   ```

3. **部署阶段**（在控制节点上）：
   ```bash
   cd /opt/ansible
   # 可选：先在各节点加载镜像
   ansible elk_nodes -m copy -a "src=../elk-image-651.tar.gz dest=/tmp/"
   ansible elk_nodes -m shell -a "docker load < /tmp/elk-image-651.tar.gz"
   
   # 运行部署
   ansible-playbook site.yml
   ```