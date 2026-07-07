CHARTS_DIR := charts
CHARTS := $(notdir $(wildcard $(CHARTS_DIR)/*))
UMBRELLA := iterabase-platform
RENDER := /tmp/$(UMBRELLA).rendered.yaml

.PHONY: build-deps lint template kubeconform check clean

build-deps:
	helm dependency build $(CHARTS_DIR)/$(UMBRELLA)

lint: build-deps
	@for c in $(CHARTS); do echo ":: helm lint $$c"; helm lint $(CHARTS_DIR)/$$c || exit 1; done

template: build-deps
	helm template $(UMBRELLA) $(CHARTS_DIR)/$(UMBRELLA) > $(RENDER)
	@echo "rendered $(RENDER)"

kubeconform: template
	kubeconform -strict -kubernetes-version 1.31.0 $(RENDER)

check: lint kubeconform

clean:
	rm -f $(RENDER)
	rm -rf $(CHARTS_DIR)/$(UMBRELLA)/charts
