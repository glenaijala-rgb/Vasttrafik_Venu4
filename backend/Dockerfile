FROM node:24-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts
COPY backend/src ./backend/src
COPY scripts/validate-config.mjs ./scripts/validate-config.mjs
COPY config ./config
ENV HOST=0.0.0.0 PORT=8787 NODE_ENV=production
USER node
EXPOSE 8787
CMD ["node", "backend/src/server.mjs"]
