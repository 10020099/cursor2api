# ==== Stage 1: 前端构建阶段 (Vue UI Builder) ====
FROM node:22-alpine AS vue-builder

WORKDIR /app/vue-ui

COPY vue-ui/package.json vue-ui/package-lock.json ./
RUN npm ci

COPY vue-ui/ ./
RUN npm run build

# ==== Stage 2: 后端构建阶段 (Backend Builder) ====
FROM node:22-slim AS builder

WORKDIR /app

# 安装编译依赖（better-sqlite3 需要）
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# ==== Stage 3: 生产运行阶段 (Runner) ====
FROM node:22-slim AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV NODE_OPTIONS="--max-old-space-size=4096"

# 安装运行时依赖 + 创建用户
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 1001 nodejs \
    && useradd --system --uid 1001 --gid nodejs cursor

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# 从 builder 拷贝编译产物
COPY --from=builder --chown=cursor:nodejs /app/dist ./dist

# 从 vue-builder 拷贝 Vue UI 构建产物
COPY --from=vue-builder --chown=cursor:nodejs /app/vue-ui/../public/vue ./public/vue

# 拷贝前端静态资源
COPY --chown=cursor:nodejs public ./public

# 创建日志目录
RUN mkdir -p /app/logs && chown cursor:nodejs /app/logs

USER cursor

EXPOSE 3010
VOLUME ["/app/logs"]

CMD ["npm", "start"]
