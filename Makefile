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
	@$(MAKE) build/7.4
	@$(MAKE) build/8.0
	@$(MAKE) build/8.1

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
	docker build -t 8sistemas/laravel-alpine:$* $(DOCKERFILE_PATH)
