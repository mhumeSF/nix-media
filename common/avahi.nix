{
  config,
  pkgs,
  ...
}:

{
  services.avahi = {
    enable = true;
    nssmdns = true;
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
