# Sub-Store 自维护部署指南

本仓库以 `meyifan20-icloud/Sub-Store` 为后端源码与客户端资源的可信源。上游只用于手动同步代码更新。

## 能力矩阵

| 方式 | 后端来源 | 本地前端 | HTTP-META + mihomo | shoutrrr | 数据持久化 | 适用场景 |
| --- | --- | --- | --- | --- | --- | --- |
| Docker / Compose | 本仓库源码构建 | ✅ | ✅ | ✅ | ✅ | 推荐，完整能力 |
| Linux Node.js | 本仓库源码构建 | ✅ | ✅ | ✅ | ✅ | VPS / 裸机，完整能力 |
| Termux | 本仓库源码构建 | ✅ | 默认关闭 | 默认关闭 | ✅ | Android 轻量自建 |
| 代理 App 模块 | 本仓库 RAW | 使用官方前端 | 不需要 | App 能力 | App 存储 | Loon / Surge / QX / Stash / Shadowrocket / Egern |
| Android SubCase / Root 模块 | 独立 Android 项目 | 由对应项目提供 | 由对应项目决定 | 由对应项目决定 | 由对应项目提供 | 不把独立 Android 工程复制进本仓库 |

> “完整能力”在本仓库内指：Sub-Store Node 后端 + 本地前端 + HTTP-META + mihomo + shoutrrr + 持久化数据目录。

## 版本基线

- Node.js：以根目录 `.node-version` 为准，当前为 Node.js 24.15.0。
- pnpm：以后端 `package.json` 的 `packageManager` 为准，当前为 pnpm 11.0.9。
- 后端：始终从本仓库当前分支源码构建。
- 前端：Sub-Store-Front-End 最新 Release。
- HTTP-META：xream/http-meta 最新 Release。
- mihomo：MetaCubeX/mihomo Prerelease-Alpha。
- shoutrrr：containrrr/shoutrrr 最新 Release。

外部组件属于独立项目依赖，不等同于重新从 `sub-store-org/Sub-Store` 拉取后端源码。

## 1. Docker / Docker Compose（推荐）

这是本仓库维护的完整能力部署方式。

### 准备

```bash
git clone https://github.com/meyifan20-icloud/Sub-Store.git
cd Sub-Store
cp .env.example .env
```

至少修改：

```env
SUB_STORE_FRONTEND_BACKEND_PATH=/换成你自己的长随机路径
```

如使用自己的前端域名，再把它加入：

```env
SUB_STORE_CORS_ALLOWED_ORIGINS=https://你的前端域名
```

### 启动

```bash
docker compose up -d --build
```

或者：

```bash
make docker-up
```

默认仅映射宿主机：

```
127.0.0.1:3001 -> container:3001
```

适合继续通过 Caddy / Nginx / Cloudflare Tunnel 等反向代理对外提供 HTTPS。

数据保存在：

```
./data
```

容器内对应：

```
/opt/app/data
```

健康检查：

```
http://127.0.0.1:3001/<你的后端路径>/api/utils/env
```

### Docker 构建包含的完整依赖

Docker 镜像会：

1. 使用本仓库 `backend/` 源码安装 pnpm 依赖并构建 `sub-store.bundle.js`。
2. 拉取前端 Release 并放入 `/opt/app/frontend`。
3. 拉取 HTTP-META bundle 与模板。
4. 拉取与架构匹配的 mihomo 内核。
5. 拉取与架构匹配的 shoutrrr。
6. 使用 Node 24 运行后端。
7. 通过 `/opt/app/data` 持久化数据。

当前 Dockerfile支持：

- amd64
- arm64
- arm/v7

## 2. Linux / VPS Node.js 直装

适合不想使用 Docker 的场景。

系统至少需要：

- Node.js 24+
- curl
- unzip
- tar
- gzip
- ca-certificates

在本仓库根目录执行：

```bash
sh deploy/node/prepare-runtime.sh
```

该脚本会：

- 使用本仓库源码构建后端。
- 自动准备 pnpm 11.0.9。
- 准备本地前端。
- 下载 HTTP-META。
- 下载当前架构对应的 mihomo。
- 下载 shoutrrr。
- 生成 `.runtime/start.sh`。

然后：

```bash
cp .env.example .env
set -a
. ./.env
set +a
.runtime/start.sh
```

如需长期运行，建议再由 systemd、supervisord 或你现有的进程管理器托管 `.runtime/start.sh`。

## 3. Termux / Android

执行：

```bash
bash deploy/termux/install.sh
```

会安装/检查：

- Node.js
- git
- curl
- unzip
- tar
- gzip
- pnpm

并从本仓库源码构建后端、安装本地前端。

启动：

```bash
~/.sub-store/start.sh
```

Termux 默认不自动安装 HTTP-META/mihomo/shoutrrr 原生二进制，因为 Android/Termux ABI 与常规 Linux 容器不同，不能把普通 Linux 二进制兼容性当作必然成立。

如果需要 Android 侧更完整的原生运行环境，优先使用官方 Android 独立项目：

- SubCase: https://github.com/sub-store-org/subcase
- Magisk / KernelSU / APatch 模块：参考 Sub-Store 官方 Wiki

这样不会把另一套 Android 工程强行复制进本仓库，也不会破坏本仓库的独立维护边界。

## 4. 代理 App 模块

这些资源已经由本仓库提供：

- Loon: `config/Loon.plugin`
- Loon Parser: `config/Loon-parser.plugin`
- Surge: `config/Surge.sgmodule`
- Surge Beta: `config/Surge-Beta.sgmodule`
- Quantumult X: `config/QX.snippet`
- Stash: `config/Stash.stoverride`
- Shadowrocket: 使用仓库内兼容模块
- Egern: `config/Egern.yaml`

运行脚本和安装 RAW 已由同步保护机制维持在：

```
https://raw.githubusercontent.com/meyifan20-icloud/Sub-Store/master/
```

上游仅作为代码更新源。

## 5. 环境变量

完整模板见根目录：

```
.env.example
```

重点变量：

- `SUB_STORE_BACKEND_API_HOST`
- `SUB_STORE_BACKEND_API_PORT`
- `SUB_STORE_BACKEND_MERGE`
- `SUB_STORE_FRONTEND_BACKEND_PATH`
- `SUB_STORE_FRONTEND_PATH`
- `SUB_STORE_DATA_BASE_PATH`
- `SUB_STORE_CORS_ALLOWED_ORIGINS`
- `SUB_STORE_BACKEND_DEFAULT_PROXY`
- `SUB_STORE_PUSH_SERVICE`
- `SUB_STORE_BACKEND_SYNC_CRON`
- `SUB_STORE_BACKEND_UPLOAD_CRON`
- `SUB_STORE_BACKEND_DOWNLOAD_CRON`
- `SUB_STORE_PRODUCE_CRON`
- `SUB_STORE_MMDB_COUNTRY_PATH`
- `SUB_STORE_MMDB_ASN_PATH`
- `SUB_STORE_MMDB_CRON`
- `SUB_STORE_MMDB_COUNTRY_URL`
- `SUB_STORE_MMDB_ASN_URL`
- `SUB_STORE_DATA_URL`
- `SUB_STORE_DATA_URL_POST`
- `SUB_STORE_MAX_HEADER_SIZE`
- `SUB_STORE_BODY_JSON_LIMIT`
- `HTTP_META_ENABLED`
- `HTTP_META_HOST`
- `HTTP_META_PORT`
- `META_DISABLE_AUTO_CLEAN`
- `META_TEMP_FOLDER`

## 6. 安全注意事项

- 不要把 `SUB_STORE_BACKEND_API_HOST` 的裸后端端口直接暴露到公网。
- `SUB_STORE_FRONTEND_BACKEND_PATH` 应使用足够长的随机路径，不建议使用 `/`。
- CORS 不建议长期设置为 `*`。
- `.env` 不应提交到 Git。
- Docker Compose 默认只监听宿主机 `127.0.0.1:3001`。
- 对外访问时建议使用 HTTPS 反向代理。
