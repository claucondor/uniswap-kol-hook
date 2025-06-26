# Build stage
FROM node:18 AS builder

WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./
COPY tsconfig.json ./

# Install all dependencies (including devDependencies for building)
RUN npm install

# Copy the rest of the application source code
COPY src ./src

# Build the TypeScript application
RUN npm run build

# Production stage  
FROM node:18-slim AS production

WORKDIR /app

# Install dumb-init for proper signal handling
RUN apt-get update && apt-get install -y dumb-init && rm -rf /var/lib/apt/lists/*

# Argument for the port, defaults to 3001 if not provided during build
ARG APP_PORT=3001

# Set environment variables
ENV PORT=${APP_PORT}
ENV NODE_ENV=production

# Copy built application (dist) and package files from builder stage
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./

# Install only production dependencies
RUN npm install --omit=dev

# Create non-root user
RUN useradd -m -u 1001 appuser && chown -R appuser:appuser /app
USER appuser

# Expose the port the app runs on
EXPOSE ${PORT}

# Use dumb-init to handle signals properly with Hono
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/index.js"] 