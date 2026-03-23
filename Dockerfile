# ==== Stage 1: 前端构建阶段 (Vue UI Builder) ====
FROM node:22-alpine AS vue-builder

WORKDIR /app/vue-ui

# 复制 Vue UI 依赖文件并安装
COPY vue-ui/package.json vue-ui/package-lock.json ./
RUN npm ci

# 复制 Vue UI 源代码并构建
COPY vue-ui/ ./
RUN npm run build

# ==== Stage 2: 生产运行阶段 (Runner) ====
# 使用 Debian slim 镜像以支持 better-sqlite3 等原生模块
FROM node:22-slim AS runner

WORKDIR /app

# 设置为生产环境
ENV NODE_ENV=production

# 增大 Node.js 堆内存上限，防止日志文件过大时加载 OOM
ENV NODE_OPTIONS="--max-old-space-size=4096"

# 安装编译工具 + 运行时依赖 + 创建用户（一步完成减少层数）
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 1001 nodejs \
    && useradd --system --uid 1001 --gid nodejs cursor

# 复制包配置并安装依赖（包含 devDependencies 用于 TypeScript 编译）
COPY package.json package-lock.json ./
RUN npm ci

# 复制 TypeScript 配置和源代码，编译
COPY tsconfig.json ./
COPY src ./src
RUN npm run build \
    && rm -rf src tsconfig.json node_modules \
    && npm ci --omit=dev \
    && npm cache clean --force

# 从 vue-builder 阶段拷贝 Vue UI 构建产物
COPY --from=vue-builder --chown=cursor:nodejs /app/vue-ui/../public/vue ./public/vue

# 拷贝前端静态资源（日志查看器 Web UI）
COPY --chown=cursor:nodejs public ./public

# 创建日志目录并授权
RUN mkdir -p /app/logs && chown cursor:nodejs /app/logs

# 切换到非 root 用户
USER cursor

# 声明对外暴露的端口和持久化卷
EXPOSE 3010
VOLUME ["/app/logs"]

# 启动服务
CMD ["npm", "start"]
