{ modulesPath, config, lib, pkgs, ... }: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./hardware-configuration.nix
    ./disk-config.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "media";
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
  };

  time.timeZone = "America/New_York";

  environment.systemPackages = with pkgs; [
    usbutils
    pciutils
    htop
    vim
    tcpdump
    ripgrep
    starship
  ];

  security.sudo.wheelNeedsPassword = false;
  users.users = {
    nixie = {
      isNormalUser = true;
      home = "/home/nixie";
      description = "Nixie Admin";
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFLpijNKLQTJJXToZRGjRWb2f1EgPG9IzzO85mvbjbaY nixie@media" ];
    };
  };

  programs.zsh.enable = true;
  services = {
    openssh.enable = true;
  };

  system.stateVersion = "23.05";
}
