let
  finn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFjkND6b+zYkXSG5YlUmbD4ammjF60qv+A/3f+nslQIq mhumesf@gmail.com";
  nixie = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFLpijNKLQTJJXToZRGjRWb2f1EgPG9IzzO85mvbjbaY nixie@router";
  users = [ nixie ];

  k3s = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGsDGg0hCjEJVAjvYcIuB/wCAtT8OW1ml3Ncp251YZJm";
  media = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPKUyAjV0GEcF8CTUI7p90vja7BHWaWKuUEkwqdMNp6d";
  systems = [ media ];
in
{
  "tokenFile.age".publicKeys = [ finn media k3s ];
  "k8s-sops-key.age".publicKeys = [ finn media k3s ];
}
