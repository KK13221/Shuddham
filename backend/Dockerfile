FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY src ./src
COPY scripts ./scripts
USER node
EXPOSE 4000 1883 8883
CMD ["node", "src/server.js"]
