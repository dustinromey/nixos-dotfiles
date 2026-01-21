{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  alsa-lib,
  llvmPackages,
  cmake,
  git,
}:

rustPlatform.buildRustPackage rec {
  pname = "waystt";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "sevos";
    repo = "waystt";
    rev = "v${version}";
    hash = "sha256-7RKYqED2/aPDvofNGAa48DTexQYdUqkQzb7BX0CsDCU=";
  };

  cargoHash = "sha256-W2pfYDPFyo/ICZ5Y0nLsP4ZeUe7lBffItelnWXrOSLc=";

  nativeBuildInputs = [
    pkg-config
    cmake
    git
    llvmPackages.clang
  ];

  buildInputs = [
    openssl
    alsa-lib
    llvmPackages.libclang
  ];

  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";

  meta = with lib; {
    description = "Minimal signal-driven speech-to-text for Wayland";
    homepage = "https://github.com/sevos/waystt";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "waystt";
  };
}
