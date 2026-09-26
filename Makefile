.PHONY: backend-build runtime docker-build docker-up docker-down

backend-build:
	cd backend && corepack enable && pnpm install --frozen-lockfile && pnpm bundle:esbuild

runtime:
	./deploy/node/prepare-runtime.sh

docker-build:
	docker compose build

docker-up:
	test -f .env || cp .env.example .env
	docker compose up -d --build

docker-down:
	docker compose down
