FROM node:lts-alpine3.21

# Arguments
ARG APP_HOME=/home/node/app

# Install system dependencies
RUN apk add --no-cache gcompat tini git git-lfs dos2unix

# Create app directory
WORKDIR ${APP_HOME}

# Set NODE_ENV to production
ENV NODE_ENV=production

# Bundle app source
COPY . ./

RUN \
  echo "*** Install npm packages ***" && \
  npm i --no-audit --no-fund --loglevel=error --no-progress --omit=dev && npm cache clean --force

# Create config directory and link config.yaml
RUN \
  rm -f "config.yaml" || true && \
  ln -s "./config/config.yaml" "config.yaml" || true && \
  mkdir "config" || true

# Pre-compile public libraries
RUN \
  echo "*** Run Webpack ***" && \
  node "./docker/build-lib.js"

# 创建支持环境变量的启动脚本
RUN cat > ./docker-entrypoint-env.sh << 'EOF'
#!/bin/sh

# 环境变量配置（注意：这里是shell脚本语法，不是Dockerfile语法）
ST_LISTEN=${ST_LISTEN:-true}
ST_PORT=${ST_PORT:-8000}
ST_HOST=${ST_HOST:-0.0.0.0}
ST_WHITELIST_MODE=${ST_WHITELIST_MODE:-false}
ST_BASIC_AUTH_MODE=${ST_BASIC_AUTH_MODE:-false}
ST_USERNAME=${ST_USERNAME:-user}
ST_PASSWORD=${ST_PASSWORD:-password}

# 创建配置文件
mkdir -p /home/node/app/config

cat > /home/node/app/config/config.yaml << YAML_EOF
listen: ${ST_LISTEN}
port: ${ST_PORT}
whitelistMode: ${ST_WHITELIST_MODE}
basicAuthMode: ${ST_BASIC_AUTH_MODE}
basicAuthUser:
  username: "${ST_USERNAME}"
  password: "${ST_PASSWORD}"
listenAddress:
  ipv4: ${ST_HOST}
  ipv6: "::"
autorun: true
avoidLocalhost: false
whitelistDockerHosts: true
protocol:
  ipv4: true
  ipv6: false
enableForwardedWhitelist: true
dataRoot: ./data
enableCorsProxy: false
enableUserAccounts: false
enableDiscreetLogin: false
disableCsrfProtection: false
securityOverride: false
allowKeysExposure: true
skipContentCheck: false
enableServerPlugins: false
sessionTimeout: 86400
dnsPreferIPv6: false
autorunHostname: auto
autorunPortOverride: -1
enableDownloadableTokenizers: true
rateLimiting:
  preferRealIpHeader: false
YAML_EOF

# 启动应用
exec node server.js
EOF

# Set the entrypoint script
RUN \
  echo "*** Cleanup ***" && \
  rm -rf "./docker" && \
  echo "*** Make docker-entrypoint-env.sh executable ***" && \
  chmod +x "./docker-entrypoint-env.sh" && \
  echo "*** Convert line endings to Unix format ***" && \
  dos2unix "./docker-entrypoint-env.sh"

# Fix extension repos permissions
RUN git config --global --add safe.directory "*"

EXPOSE 8000

# Ensure proper handling of kernel signals
ENTRYPOINT ["tini", "--", "./docker-entrypoint-env.sh"]
