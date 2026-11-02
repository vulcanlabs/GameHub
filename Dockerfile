FROM node:22-alpine

RUN apk add --no-cache openssl libc6-compat

WORKDIR /app

COPY package.json package-lock.json ./
COPY prisma ./prisma
# Dummy URL so `prisma generate` (postinstall) can read the schema.
# Coolify replaces DATABASE_URL at runtime.
ENV DATABASE_URL="file:./dev.db"
# Coolify sets NODE_ENV=production at build time, which skips devDependencies.
# Tailwind, TypeScript, and Prisma CLI are required for `next build`.
RUN npm install --include=dev

COPY . .
RUN npm run build

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME=0.0.0.0
EXPOSE 3000

ENTRYPOINT ["/docker-entrypoint.sh"]
