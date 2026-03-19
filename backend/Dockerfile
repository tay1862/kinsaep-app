FROM node:20-alpine AS deps

WORKDIR /app

COPY package*.json ./
RUN npm ci

FROM node:20-alpine AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY package*.json ./
COPY tsconfig.json ./
COPY prisma/ ./prisma/
COPY src/ ./src/

RUN npx prisma generate
RUN npm run build

FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

COPY package*.json ./
COPY prisma/ ./prisma/
RUN npm ci --omit=dev && npm install -g prisma@6.19.2 && prisma generate

COPY --from=builder /app/dist/ ./dist/

EXPOSE 4000

CMD ["sh", "-c", "prisma migrate deploy && node dist/server.js"]
