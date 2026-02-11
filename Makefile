.PHONY: new-skill validate help

VALID_CATEGORIES := security quality code data delivery operations meta

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

new-skill: ## Create a new knowledge skill (CATEGORY=security NAME=rbac)
	@if [ -z "$(CATEGORY)" ] || [ -z "$(NAME)" ]; then echo "Usage: make new-skill CATEGORY=security NAME=rbac"; exit 1; fi
	@if ! echo "$(CATEGORY)" | grep -qE '^(security|quality|code|data|delivery|operations|meta)$$'; then echo "ERROR: CATEGORY must be one of: security, quality, code, data, delivery, operations, meta"; exit 1; fi
	@if ! echo "$(NAME)" | grep -qE '^[a-z][-a-z]*$$'; then echo "ERROR: NAME must match ^[a-z][-a-z]*$$ (lowercase, hyphenated)"; exit 1; fi
	@if echo "$(NAME)" | grep -qE '^x-'; then echo "ERROR: NAME must NOT start with x- (knowledge skills don't use x- prefix)"; exit 1; fi
	@if [ -d "skills/$(CATEGORY)/$(NAME)" ]; then echo "ERROR: skills/$(CATEGORY)/$(NAME) already exists"; exit 1; fi
	@mkdir -p "skills/$(CATEGORY)/$(NAME)/references"; \
	cp .templates/knowledge-skill/SKILL.md "skills/$(CATEGORY)/$(NAME)/SKILL.md"; \
	sed -i "s/__NAME__/$(NAME)/g" "skills/$(CATEGORY)/$(NAME)/SKILL.md"; \
	sed -i "s/__CATEGORY__/$(CATEGORY)/g" "skills/$(CATEGORY)/$(NAME)/SKILL.md"; \
	echo "Created skills/$(CATEGORY)/$(NAME)/SKILL.md"; \
	echo "Next: edit skills/$(CATEGORY)/$(NAME)/SKILL.md and replace __DESCRIPTION__ with actual description"

validate: ## Run repository validation
	@./scripts/validate-rules.sh
