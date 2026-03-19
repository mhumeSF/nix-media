{
config,
pkgs,
...
}:

{
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      domain = true;
    };
  };

  environment.systemPackages = with pkgs; [
    avahi
  ];
}
