.PHONY: all

# Variables
CONFIG_NAME = media
# HOST_IP ?= # export(HOST_IP)

all:
		nixos-rebuild switch \
			--fast \
			--flake .#$(CONFIG_NAME) \
			--use-remote-sudo \
			--target-host nixie@$(HOST_IP) \
			--build-host nixie@$(HOST_IP)

