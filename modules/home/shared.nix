{ config, pkgs, lib, inputs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/nixos-dotfiles/config";
  bindir = "${config.home.homeDirectory}/nixos-dotfiles/bin";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;

  # Cross-platform config dirs symlinked to ~/.config/
  configs = {
    nvim = "nvim";
    ghostty = "ghostty";
    zed = "zed";
    fastfetch = "fastfetch";
    btop = "btop";
  };
in
{
  home.username = "dustin";
  home.homeDirectory =
    if pkgs.stdenv.isDarwin then "/Users/dustin" else "/home/dustin";
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    # --- Language Servers & Formatters ---
    nixd
    nil
    nixfmt-rfc-style
    nixpkgs-fmt
    rust-analyzer
    rustfmt
    pyright
    black
    lua-language-server
    stylua
    gopls
    gotools
    nodePackages.typescript-language-server
    nodePackages.prettier
    nodePackages.bash-language-server
    shfmt
    nodePackages.vscode-langservers-extracted
    sqls
    fish-lsp

    # --- CLI tools ---
    neovim
    bat
    ripgrep
    jq
    curl
    unzip
    unrar
    p7zip
    gnutar
    gzip
    bzip2
    nodejs_22
    python3
    fastfetch
    btop
    nmap
    (pkgs.lib.hiPrio sox)
    imagemagick
    libheif

    # --- Database tools ---
    pgcli
    pspg

    # --- From flake inputs / overlays ---
    claude-code
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [
    # fresh's flake only exposes Linux systems
    inputs.fresh.packages.${pkgs.system}.default
  ];

  home.sessionVariables = {
    TERMINAL = "ghostty";
  };

  programs.git = {
    enable = true;
    userName = "Dustin";
    userEmail = "dustinromey@gmail.com";
  };

  programs.bash = {
    enable = true;
    initExtra = ''
      export PATH="$HOME/.local/bin:$PATH"
      ${builtins.readFile ../../config/bash_aliases.sh}
      ${builtins.readFile ../../config/bash_functions.sh}
    '';
  };

  xdg.configFile = builtins.mapAttrs
    (name: subpath: {
      source = create_symlink "${dotfiles}/${subpath}";
      recursive = true;
    })
    configs;

  home.file.".local/bin" = {
    source = create_symlink bindir;
    recursive = true;
  };
}
