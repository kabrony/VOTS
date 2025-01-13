# syntax=docker/dockerfile:1

############### (1) BUILDER
FROM node:18-alpine AS builder
WORKDIR /app

COPY package.json ./
# If you have package-lock.json:
# COPY package-lock.json ./
RUN npm install

COPY . .
RUN npm run build

############### (2) PRODUCTION
FROM node:18-alpine
WORKDIR /app

COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json
# If you have package-lock.json:
# COPY --from=builder /app/package-lock.json ./package-lock.json

RUN npm install --production

EXPOSE 3000
CMD ["npm", "run", "start"]
