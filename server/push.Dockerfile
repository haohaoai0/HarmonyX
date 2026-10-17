FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && mkdir /data && chown node:node /data
COPY src/push/ ./src/push/
USER node
ENV PUSH_HOST=0.0.0.0 PUSH_PORT=8788 PUSH_STORE_FILE=/data/subscriptions.local.json
EXPOSE 8788
VOLUME ["/data"]
CMD ["node", "src/push/index.mjs"]
