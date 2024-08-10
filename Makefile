# Variables
CONFIG_NAME = media
# HOST_IP ?= # export(HOST_IP)

.PHONY: setup
setup:
		nix shell nixpkgs#nixos-rebuild

.PHONY: all
all:
		nixos-rebuild switch \
			--fast \
			--flake .#$(CONFIG_NAME) \
			--use-remote-sudo \
			--target-host nixie@$(HOST_IP) \
			--build-host nixie@$(HOST_IP) \
			--show-trace \
			--verbose \
			--cores 16 \
			--upgrade-all \
			--option eval-cache false

# SET GH_TOKEN via the following:
# export GH_TOKEN=$(gh auth status --show-token 2>&1 | grep 'Token: '| awk '{print $3}')
.PHONY: renovate
renovate:
	@echo "Running Renovate..."
	ORG_REPO=$$(git config --get remote.origin.url | sed -E 's|^https://github.com/||; s|\.git$$||'); \
	GH_TOKEN=$$(gh auth status --show-token | grep 'Token:' | awk '{print $$3}'); \
	GIT_USERNAME="$$(git config --global user.name)"; \
	GIT_EMAIL="$$(git config --global user.email)"; \
	docker run --rm \
		 -v "$$(pwd)":/usr/src/app \
		 -v ./.github/renovate.json5:/github-action/renovate.json5 \
		 -w /usr/src/app \
		 -e LOG_LEVEL=DEBUG \
		 -e RENOVATE_TOKEN=$$GH_TOKEN \
		 --env RENOVATE_CONFIG_FILE=/github-action/renovate.json5 \
		 renovate/renovate "$$ORG_REPO" \
		 --git-author "$$GIT_USERNAME <$$GIT_EMAIL>"
