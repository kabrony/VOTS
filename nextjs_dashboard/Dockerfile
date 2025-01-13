# syntax=docker/dockerfile:1
FROM node:18-alpine as builder
WORKDIR /app

# If you have package-lock.json, uncomment the COPY line
COPY package.json .
# COPY package-lock.json . 
RUN npm install

COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/package.json ./package.json
# If you have a public/ folder, uncomment:
# COPY --from=builder /app/public ./public

EXPOSE 3000
CMD ["npm", "run", "start"]
