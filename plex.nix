{ lib, pkgs, ... }: {
  # plexmediaserver is unfree; allow just that package on the host.
  nixpkgs.config.allowUnfreePredicate =
    pkg: builtins.elem (lib.getName pkg) [ "plexmediaserver" ];

  # Plex Media Server runs natively on the host (moved out of the k3s cluster).
  # Config lives on the ZFS pool so it persists and gets snapshotted; libraries
  # are read straight off tank0 with no virtiofs hop.
  services.plex = {
    enable       = true;
    openFirewall = true;
    dataDir      = "/tank0/plex";
    user         = "plex";
    group        = "plex";
  };

  # Hardware transcoding via the reclaimed Ryzen iGPU (radeonsi VAAPI).
  # Requires amdgpu unblacklisted + the GPU removed from vfio-pci.ids in
  # hardware-configuration.nix.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      libva-vdpau-driver
      libva-utils      # `vainfo` for verifying the VAAPI device
    ];
  };

  # Plex needs access to the DRI render node for HW transcode.
  users.users.plex.extraGroups = [ "render" "video" ];
}
