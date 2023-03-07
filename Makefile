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

build/%:
	@echo "Building for $*"
	@- if ! test -e $*; then echo "No such version"; exit 1; fi

	@$(MAKE) build-tag/$*-mysql
	@$(MAKE) build-tag/$*-mysql-nginx
	@$(MAKE) build-tag/$*-pgsql
	@$(MAKE) build-tag/$*-pgsql-nginx

build-tag/%:
	@echo "Building for $*"
	$(eval DOCKERFILE_PATH=$(shell echo $* | awk '!x{x=sub("-","/")}1'))
	@- if ! test -e $(DOCKERFILE_PATH); then echo "No such version"; exit 1; fi
	docker build -t 8sistemas/laravel-alpine:$*-alpine3.16 -f $(DOCKERFILE_PATH)/Dockerfile .

build-tag-xdebug/%:
	@echo "Building for $*"
	$(eval DOCKERFILE_PATH=$(shell echo $* | awk '!x{x=sub("-","/")}1'))
	@- if ! test -e $(DOCKERFILE_PATH); then echo "No such version"; exit 1; fi
	docker build -t 8sistemas/laravel-alpine:$*-xdebug-alpine3.16 -f $(DOCKERFILE_PATH)/Dockerfile . --build-arg BUILD_XDEBUG=1

buildx-tag/%:
	@echo "Building for $*"
	$(eval DOCKERFILE_PATH=$(shell echo $* | awk '!x{x=sub("-","/")}1'))
	@- if ! test -e $(DOCKERFILE_PATH); then echo "No such version"; exit 1; fi
	docker buildx build -t 8sistemas/laravel-alpine:$*-alpine3.16 -f $(DOCKERFILE_PATH)/Dockerfile --platform linux/amd64,linux/arm64 .