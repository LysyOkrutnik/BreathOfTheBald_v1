FROM node:24-alpine AS build
WORKDIR /app
COPY package*.json ./
COPY prisma ./prisma
COPY prisma.config.ts ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run prisma:generate
RUN npm run build

FROM node:24-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
COPY prisma ./prisma
COPY prisma.config.ts ./
# `prisma` (the CLI, not just @prisma/client) is a regular dependency, not a
# devDependency — this image doubles as the `migrate` one-off job's image
# when deployed straight from ghcr (no local Dockerfile/build stage access
# on the host), so `npx prisma migrate deploy` must work against this exact
# published image.
RUN npm ci --omit=dev
COPY --from=build /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=build /app/dist ./dist

EXPOSE 8080
CMD ["node", "dist/index.js"]
