{ config, ... }:

{
  # sops-nix configuration for vigilant
  sops = {
    # Default sops file for this host
    defaultSopsFile = ../../secrets/ssh/vigilant.yaml;

    # Validate sops files at build time
    validateSopsFiles = false;

    # Age key for decryption (derived from SSH host key)
    age = {
      # Use SSH host key to generate age key
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      # Where to store the generated age key
      keyFile = "/var/lib/sops-nix/key.txt";
      # Generate the key if it doesn't exist
      generateKey = true;
    };

    # Define secrets to decrypt
    secrets = {
      # SSH private key
      "ssh_private_key" = {
        sopsFile = ../../secrets/ssh/vigilant.yaml;
        path = "/home/dustin/.ssh/id_ed25519";
        owner = "dustin";
        group = "users";
        mode = "0600";
      };

      # SSH public key
      "ssh_public_key" = {
        sopsFile = ../../secrets/ssh/vigilant.yaml;
        path = "/home/dustin/.ssh/id_ed25519.pub";
        owner = "dustin";
        group = "users";
        mode = "0644";
      };

      # Syncthing private key
      "syncthing_key" = {
        sopsFile = ../../secrets/syncthing/vigilant.yaml;
        path = "/home/dustin/.local/state/syncthing/key.pem";
        owner = "dustin";
        group = "users";
        mode = "0600";
      };

      # Syncthing certificate
      "syncthing_cert" = {
        sopsFile = ../../secrets/syncthing/vigilant.yaml;
        path = "/home/dustin/.local/state/syncthing/cert.pem";
        owner = "dustin";
        group = "users";
        mode = "0644";
      };
    };
  };

  # Ensure directories exist
  systemd.tmpfiles.rules = [
    "d /home/dustin/.ssh 0700 dustin users"
    "d /home/dustin/.local/state/syncthing 0700 dustin users"
  ];
}
