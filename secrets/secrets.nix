let
  nixie = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFLpijNKLQTJJXToZRGjRWb2f1EgPG9IzzO85mvbjbaY nixie@router";
  users = [ nixie ];

  k3s = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGsDGg0hCjEJVAjvYcIuB/wCAtT8OW1ml3Ncp251YZJm";
  router = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID9EXglVJoj2Ql0E4F0GK5BRjAIKrrCej974LGTo7Yau";
  media = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPQDszu8au1EAjZp0T3HRoNA6twCWcRPGrtHhZyI7KDk";
  systems = [ k3s router media ];
in
{
  "tokenFile.age".publicKeys = [ k3s ];
  "bootstrap.yaml.age".publicKeys = [ k3s ];
}
