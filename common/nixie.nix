{
  config,
  pkgs,
  ...
}:

{
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

  environment.shellAliases = {
    vi = "nvim";
    vim = "nvim";
  };
}

