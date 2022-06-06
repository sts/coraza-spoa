# Copyright 2022 The Corazawaf Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

.DEFAULT_GOAL := build

BINARY = "coraza-spoa"

BUILD ?= $(shell git rev-parse HEAD)

LDFLAGS=-ldflags "-X main.Version=${VERSION} -X main.Build=${BUILD}"

PLATFORMS=linux

ARCHITECTURES=amd64 arm64


default: build

build:
	go build -v ${LDFLAGS} -o ${BINARY} cmd/main.go

build_all:
	$(foreach GOOS, $(PLATFORMS),\
	$(foreach GOARCH, $(ARCHITECTURES), \
	  $(shell \
	     export GOOS=$(GOOS); \
	     export GOARCH=$(GOARCH); \
	     go build -v -o $(BINARY)_$(VERSION)_$(GOOS)_$(GOARCH) cmd/main.go )))

clean:
	$(foreach GOOS, $(PLATFORMS),\
	$(foreach GOARCH, $(ARCHITECTURES), \
	  $(shell \
	     rm $(BINARY)_*_$(GOOS)_$(GOARCH))))
