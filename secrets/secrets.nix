let
  nixie = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFLpijNKLQTJJXToZRGjRWb2f1EgPG9IzzO85mvbjbaY nixie@router";
  users = [ nixie ];

  k3s = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMSbrvT9MxZ0MbWmCcPVSr3/b5/2BZjnQXgXgXvVvaMg";
  router = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGBDq/R7YmJXybqsf0zRG5bfxQUZmAm3uU+UEcXt+ud4";
  media = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPQDszu8au1EAjZp0T3HRoNA6twCWcRPGrtHhZyI7KDk";
  systems = [ k3s router media ];
in
{
  "secret1.age".publicKeys = users ++ systems;
}
