GO ?= go
GOFMT ?= gofmt

.PHONY: check fmt-check test vet

check: fmt-check test vet

fmt-check:
	@files="$$($(GOFMT) -l .)" || exit $$?; \
	if [ -n "$$files" ]; then \
		echo "gofmt needed:"; \
		echo "$$files"; \
		exit 1; \
	fi

test:
	$(GO) test ./...

vet:
	$(GO) vet ./...
