MKFILE_DIR      :=  $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

include $(MKFILE_DIR)/make-helpers/Makefile.*

.PHONY: dd-checks
dd-checks: ## For <TAG> (default: latest), list all config examples found in "/etc/datadog-agent/conf.d"
	@docker run --rm -it datadog/agent:$${TAG:-latest} find /etc/datadog-agent/conf.d/ -name conf.yaml.example -exec sh -c 'basename $$(dirname $$0) | cut -d. -f 1' {} \; | sort

.PHONY: dd-check/%
dd-check/%: ## For <TAG> (default: latest), output the "/etc/datadog-agent/conf.d/<%>.d/conf.yaml.example"
dd-check/%:
	@docker run --rm -it datadog/agent:$${TAG:-latest} cat /etc/datadog-agent/conf.d/$*.d/conf.yaml.example
