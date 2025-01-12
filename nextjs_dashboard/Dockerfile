# syntax=docker/dockerfile:1

FROM node:18-alpine as builder

WORKDIR /app

# Copy package info first, install dependencies
COPY package.json ./
RUN npm install

# Copy the rest of the project
COPY . .

# Build your Next.js project
RUN npm run build

# === Final stage: minimal runtime ===
FROM node:18-alpine
WORKDIR /app

# Copy the compiled .next folder
COPY --from=builder /app/.next ./.next

# (Removed the line that copies /app/public since it doesn't exist)
# COPY --from=builder /app/public ./public

COPY --from=builder /app/package.json ./package.json

EXPOSE 3000
CMD ["npm", "run", "start"]
