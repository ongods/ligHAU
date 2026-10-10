FROM node:22-bookworm-slim

WORKDIR /app
ENV NODE_ENV=production \
    CHAT_HOST=0.0.0.0 \
    CHAT_PORT=8787 \
    CAMPUS_DB_PATH=/data/campus.sqlite

COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund
# These files seed the catalog once, only when the target is empty.
COPY --chown=node:node server/*.mjs ./server/
COPY --chown=node:node lib/data/mock_data.dart ./lib/data/mock_data.dart
COPY --chown=node:node assets/data/hau_osm.json ./assets/data/hau_osm.json
RUN mkdir -p /data && chown node:node /data

USER node
EXPOSE 8787
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:'+(process.env.CHAT_PORT||8787)+'/health',{signal:AbortSignal.timeout(4000)}).then(async r=>{if(!r.ok||(await r.json()).service!=='ligHAU-chat')process.exit(1)}).catch(()=>process.exit(1))"
CMD ["node", "server/chat-server.mjs"]
