# .envファイルから環境変数(AWS_ACCOUNT_ID/AWS_REGION等)を読み込む
include .env
export $(shell sed 's/=.*//' .env)

# Docker
up:
	docker-compose up -d

down:
	docker-compose down

build:
	docker-compose build --no-cache

restart:
	make down
	make up

logs:
	docker-compose logs -f terraform

enter:
	docker exec -it terraform ash

# AWSアカウントにおいてiphoneで2段階認証をしている時にセッションを取得する
get-session-token:
	@read -p "Enter token code: " token_code; \
	aws sts get-session-token --serial-number arn:aws:iam::$(AWS_ACCOUNT_ID):mfa/iphone --token-code $$token_code
