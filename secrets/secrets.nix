let
  finn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFjkND6b+zYkXSG5YlUmbD4ammjF60qv+A/3f+nslQIq mhumesf@gmail.com";
  nixie = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFLpijNKLQTJJXToZRGjRWb2f1EgPG9IzzO85mvbjbaY nixie@router";
  users = [ nixie ];

  k3s = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGsDGg0hCjEJVAjvYcIuB/wCAtT8OW1ml3Ncp251YZJm";
  router = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID9EXglVJoj2Ql0E4F0GK5BRjAIKrrCej974LGTo7Yau";
  media = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPQDszu8au1EAjZp0T3HRoNA6twCWcRPGrtHhZyI7KDk";
  systems = [ k3s router media ];
in
{
  "tokenFile.age".publicKeys = [ finn k3s ];
  "bootstrap.yaml.age".publicKeys = [ finn k3s ];
}
