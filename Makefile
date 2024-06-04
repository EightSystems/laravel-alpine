.PHONY: help build
.DEFAULT_GOAL := build

help:
	@echo "Makefile commands:"
	@echo ""
	@echo "help"
	@echo "build"
	@echo "build/VERSION"
	@echo "build-tag/TAGNAME"

build:
	@$(MAKE) build/8.0
	@$(MAKE) build/8.1
	@$(MAKE) build/8.2
	@$(MAKE) build/8.3

build/%:
	@echo "Building for $*"
	@- if ! test -e $*; then echo "No such version"; exit 1; fi

	@$(MAKE) build-tag-mysql/$*
	@$(MAKE) build-tag-mysql-nginx/$*
	@$(MAKE) build-tag-pgsql/$*
	@$(MAKE) build-tag-pgsql-nginx/$*

build-tag-mysql/%:
	@echo "Building for $*"
	docker build -t 8sistemas/laravel-alpine:$*-mysql-alpine3.20 \
		--build-arg="PHP_VERSION=$*" \
		--build-arg="DATABASE_MODULE=mysqli" \
		--build-arg="HAS_NGINX=0" \
		 -f ./Dockerfile3.20 .

build-tag-mysql-nginx/%:
	@echo "Building for $*"
	docker build -t 8sistemas/laravel-alpine:$*-mysql-nginx-alpine3.20 \
		--build-arg="PHP_VERSION=$*" \
		--build-arg="DATABASE_MODULE=mysqli" \
		--build-arg="HAS_NGINX=1" \
		 -f ./Dockerfile3.20 .

build-tag-pgsql/%:
	@echo "Building for $*"
	docker build -t 8sistemas/laravel-alpine:$*-pgsql-alpine3.20 \
		--build-arg="PHP_VERSION=$*" \
		--build-arg="DATABASE_MODULE=pgsql" \
		--build-arg="HAS_NGINX=0" \
		 -f ./Dockerfile3.20 .

build-tag-pgsql-nginx/%:
	@echo "Building for $*"
	docker build -t 8sistemas/laravel-alpine:$*-pgsql-nginx-alpine3.20 \
		--build-arg="PHP_VERSION=$*" \
		--build-arg="DATABASE_MODULE=pgsql" \
		--build-arg="HAS_NGINX=1" \
		 -f ./Dockerfile3.20 .
