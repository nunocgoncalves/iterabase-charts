CHARTS_DIR := charts
CHARTS := $(notdir $(wildcard $(CHARTS_DIR)/*))
UMBRELLA := iterabase-platform
CONTROLPLANE := control-plane
RENDER := /tmp/$(UMBRELLA).rendered.yaml
RENDER_CP := /tmp/$(CONTROLPLANE).rendered.yaml
RENDER_TLS := /tmp/$(UMBRELLA).tls.rendered.yaml

.PHONY: build-deps lint template kubeconform template-controlplane kubeconform-controlplane template-tls kubeconform-tls check check-tls clean

# control-plane has its own file:// dep (postgresql); build it first so the
# umbrella vendors control-plane with its nested dependency baked in.
build-deps:
	helm dependency build $(CHARTS_DIR)/$(CONTROLPLANE)
	helm dependency build $(CHARTS_DIR)/$(UMBRELLA)

lint: build-deps
	@for c in $(CHARTS); do echo ":: helm lint $$c"; helm lint $(CHARTS_DIR)/$$c || exit 1; done

template: build-deps
	helm template $(UMBRELLA) $(CHARTS_DIR)/$(UMBRELLA) > $(RENDER)
	@echo "rendered $(RENDER)"

kubeconform: template
	# The umbrella now renders the control-plane's CRDs (enabled by default);
	# kubeconform's bundled schema set doesn't resolve apiextensions CRDs.
	kubeconform -strict -kubernetes-version 1.31.0 -ignore-missing-schemas $(RENDER)

# The umbrella keeps control-plane disabled by default, so validate the
# control-plane chart standalone (renders with its own enabled=true default).
template-controlplane: build-deps
	helm template $(CONTROLPLANE) $(CHARTS_DIR)/$(CONTROLPLANE) > $(RENDER_CP)
	@echo "rendered $(RENDER_CP)"

kubeconform-controlplane: template-controlplane
	# The chart renders a CRD (kubebuilder-generated, sourced verbatim from the
	# control-plane repo); kubeconform's bundled schema set does not resolve the
	# apiextensions CRD schema, so ignore missing schemas rather than failing.
	kubeconform -strict -kubernetes-version 1.31.0 -ignore-missing-schemas $(RENDER_CP)

# Static check with internal TLS on (values-tls.yaml flips global.internalTLS).
# Catches conditional/render errors in the TLS-on path that the default
# (plaintext) `make check` doesn't exercise. cert-manager Certificate/
# ClusterIssuer CRs are ignored (no bundled schema), like the CRDs above.
template-tls: build-deps
	helm template $(UMBRELLA) $(CHARTS_DIR)/$(UMBRELLA) -f values-tls.yaml > $(RENDER_TLS)
	@echo "rendered $(RENDER_TLS)"

kubeconform-tls: template-tls
	kubeconform -strict -kubernetes-version 1.31.0 -ignore-missing-schemas $(RENDER_TLS)

check: lint kubeconform kubeconform-controlplane

check-tls: kubeconform-tls

clean:
	rm -f $(RENDER) $(RENDER_CP)
	rm -rf $(CHARTS_DIR)/$(UMBRELLA)/charts $(CHARTS_DIR)/$(CONTROLPLANE)/charts
