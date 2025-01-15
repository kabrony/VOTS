# syntax=docker/dockerfile:1

##############################
# 1) BUILDER STAGE
##############################
FROM node:18-alpine AS builder

WORKDIR /app

# If you have package-lock.json or yarn.lock, you can copy them
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of your code
COPY . ./

# Build the Next.js app
RUN npm run build

##############################
# 2) RUNTIME STAGE
##############################
FROM node:18-alpine

WORKDIR /app

# Copy only the build output & package info from builder
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package*.json ./

# Install only production deps
RUN npm install --omit=dev

EXPOSE 3000

CMD ["npm", "run", "start"]
