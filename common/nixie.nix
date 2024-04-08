{
  config,
  pkgs,
  ...
}:

{
  boot.kernelPackages = pkgs.linuxPackages_latest;

  security.sudo.wheelNeedsPassword = false;

  users.users = {
    nixie = {
      isNormalUser                = true;
      home                        = "/home/nixie";
      description                 = "Nixie Admin";
      extraGroups                 = [ "wheel" ];
      openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFLpijNKLQTJJXToZRGjRWb2f1EgPG9IzzO85mvbjbaY nixie@router" ];
    };
  };

  environment.variables.EDITOR = "nvim";
  environment.systemPackages = with pkgs; [
    amdgpu_top
    linuxKernel.packages.linux_6_8.amdgpu-pro
    htop
    ripgrep
    starship
    powertop
    neovim
    git
    tree
    tmux
    pciutils
    iptables
  ];

  environment.shellAliases = {
    vi = "nvim";
    vim = "nvim";
  };

  time.timeZone = "America/New_York";

  services.openssh.enable = true;

  system.stateVersion = "23.11";
}

