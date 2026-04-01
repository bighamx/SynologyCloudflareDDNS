# Synology Cloudflare DDNS 脚本 📜

这是一个用于在 [Synology](https://www.synology.com/) 群晖 NAS 上添加 [Cloudflare](https://www.cloudflare.com/) 作为 DDNS 服务商的脚本。

## 功能特性

- 支持IPv4和IPv6地址更新,并可配置仅更新IPV4/IPv6地址
- 可配置的Cloudflare代理(小黄云)设置


## 安装和使用方法

### 通过SSH访问Synology

1. 登录到您的DSM
2. 进入 **控制面板** > **终端机和SNMP** > **启用SSH服务**
3. 使用您的SSH客户端通过SSH访问Synology


### 在Synology中运行命令

1. 从本仓库下载 `cloudflareddns.sh` 到 `/sbin/cloudflareddns.sh`

```bash
wget https://raw.githubusercontent.com/bighamx/SynologyCloudflareDDNS/master/cloudflareddns.sh -O /sbin/cloudflareddns.sh
```

2. 给予执行权限

```bash
chmod +x /sbin/cloudflareddns.sh
```

3. 将 `cloudflare` 添加到Synology DDNS服务提供商列表

```bash
cat >> /etc.defaults/ddns_provider.conf << 'EOF'
[Cloudflare]
        modulepath=/sbin/cloudflareddns.sh
        queryurl=https://www.cloudflare.com
        website=https://www.cloudflare.com
EOF
```

`queryurl` 并不重要，因为我们将使用自己的脚本，但它是必需的。

### 获取Cloudflare参数

1. 进入您的Cloudflare域名概览页面，复制您的区域ID（Zone ID）
2. 进入您的Cloudflare个人资料 > **API令牌** > **创建令牌**。它应该具有 `Zone > DNS > Edit` 的权限。复制API令牌。

### 在Synology DSM中配置DDNS

1. 进入 **控制面板** > **外部访问** > **DDNS**
2. 点击 **新增**
3. 选择 **Cloudflare** 服务提供商
4. 配置以下参数：
   - **服务提供商**: Cloudflare
   - **主机名**: 使用新格式，如 `www.example.com-46-T`，或简单格式如 `www.example.com`
   - **用户名**: 您的Cloudflare区域ID
   - **密码**: 您的Cloudflare API令牌


#### 主机名格式

新的主机名格式使用连字符分隔三个部分：

```
host.domain.com-46-T
```

##### 第一个部分（域名）
- 即是你要更新的域名

##### 第二个部分（IP类型）
- `4`: 仅更新IPv4记录
- `6`: 仅更新IPv6记录  
- `46`: 同时更新IPv4和IPv6记录

##### 第三个部分（Cloudflare代理设置）
- `T`: 开启Cloudflare代理
- `F`: 关闭Cloudflare代理

点击确定, 完成设置, 现在你可以开始使用DDNS服务了


## 注意事项

- IPv6地址会自动从系统获取，无需手动指定
- 如果无法获取IPv6地址，脚本会自动跳过IPv6更新
- 默认情况下，如果检测到IPv6地址可用，会自动更新IPv4和IPv6记录
- 新创建的DNS记录会使用指定的代理设置
- 现有记录的代理设置会被更新为新的设置
- 脚本会验证IP地址格式和参数有效性

以下部分如果你不理解，请忽略

## 脚本直接使用方法

### 基本语法

```bash
./cloudflareddns.sh <zone_id> <api_token> <hostname> <ip_address>
```

### 参数说明

- `zone_id`: Cloudflare区域的ID
- `api_token`: Cloudflare API令牌
- `hostname`: 域名和配置参数，格式为 `host.domain.com-46-T`
- `ip_address`: IPv4地址（IPv6地址会自动获取）

### 使用示例

#### 使用默认设置（自动检测IPv6地址，关闭代理）
```bash
./cloudflareddns.sh your_zone_id your_api_token "www.example.com" 192.168.1.100
```


### 高级使用示例

#### 仅更新IPv4，开启代理
```bash
./cloudflareddns.sh your_zone_id your_api_token "www.example.com-4-T" 192.168.1.100
```

#### 仅更新IPv6，关闭代理
```bash
./cloudflareddns.sh your_zone_id your_api_token "www.example.com-6-F" 192.168.1.100
```

#### 同时更新IPv4和IPv6，开启代理
```bash
./cloudflareddns.sh your_zone_id your_api_token "www.example.com-46-T" 192.168.1.100
```


## 错误代码

- `good`: 更新成功
- `nochg`: 无需更新
- `badauth`: 认证失败
- 其他错误会显示具体的错误信息

## 许可证

详见 [LICENCE](LICENCE) 文件。
