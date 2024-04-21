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
			--upgrade-all
