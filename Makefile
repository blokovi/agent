# Copyright (c) Mainflux
# SPDX-License-Identifier: Apache-2.0

BUILD_DIR = build
SERVICES = agent
DOCKERS = $(addprefix docker_,$(SERVICES))
DOCKERS_DEV = $(addprefix docker_dev_,$(SERVICES))
CGO_ENABLED ?= 0
GOOS ?= linux

define compile_service
	CGO_ENABLED=$(CGO_ENABLED) GOOS=$(GOOS) GOARCH=$(GOARCH) GOARM=$(GOARM) go build -ldflags "-s -w" -o ${BUILD_DIR}/mainflux-$(1) cmd/main.go
endef

define make_docker
	$(eval svc=$(subst docker_,,$(1)))

	docker build \
		--no-cache \
		--build-arg SVC=$(svc) \
		--build-arg GOARCH=$(GOARCH) \
		--build-arg GOARM=$(GOARM) \
		--tag=mainflux/$(svc) \
		-f docker/Dockerfile .
endef

define make_docker_dev
	$(eval svc=$(subst docker_dev_,,$(1)))

	docker build \
		--no-cache \
		--build-arg SVC=$(svc) \
		--tag=mainflux/$(svc) \
		-f docker/Dockerfile.dev ./build
endef

all: $(SERVICES) ui

.PHONY: all $(SERVICES) dockers dockers_dev

clean:
	rm -rf ${BUILD_DIR}

install:
	cp ${BUILD_DIR}/* $(GOBIN)

test:
	go test -v -race -count 1 -tags test $(shell go list ./... | grep -v 'vendor\|cmd')

$(SERVICES):
	$(call compile_service,$(@))

docker_ui:
	$(MAKE) -C ui docker

dockers: $(DOCKERS) docker_ui

dockers_dev: $(DOCKERS_DEV)

define docker_push
	for svc in $(SERVICES); do \
		docker push mainflux/$$svc:$(1); \
	done
	docker push mainflux/mqtt:$(1)
endef

release:
	$(eval version = $(shell git describe --abbrev=0 --tags))
	git checkout $(version)
	$(MAKE) dockers
	for svc in $(SERVICES); do \
		docker tag mainflux/$$svc mainflux/$$svc:$(version); \
	done
	docker tag mainflux/agent-ui mainflux/agent-ui:$(version)
	$(call docker_push,$(version))

ui:
	$(MAKE) -C ui

run:
	cd $(BUILD_DIR) && ./mainflux-$(SERVICES)
