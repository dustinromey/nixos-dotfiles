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
  vulkan-loader,
  vulkan-headers,
  shaderc,
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

  # Hash will change after patching Cargo.toml
  cargoHash = "sha256-W2pfYDPFyo/ICZ5Y0nLsP4ZeUe7lBffItelnWXrOSLc=";

  # Enable vulkan feature for GPU acceleration
  postPatch = ''
    substituteInPlace Cargo.toml \
      --replace 'whisper-rs = "0.15"' 'whisper-rs = { version = "0.15", features = ["vulkan"] }'
  '';

  nativeBuildInputs = [
    pkg-config
    cmake
    git
    llvmPackages.clang
    shaderc  # provides glslc for Vulkan shader compilation
  ];

  buildInputs = [
    openssl
    alsa-lib
    llvmPackages.libclang
    vulkan-loader
    vulkan-headers
    shaderc
  ];

  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";

  # Help cmake find Vulkan during cargo build
  preBuild = ''
    export Vulkan_INCLUDE_DIR="${vulkan-headers}/include"
    export Vulkan_LIBRARY="${vulkan-loader}/lib/libvulkan.so"
    export CMAKE_PREFIX_PATH="${vulkan-headers}:${vulkan-loader}:${shaderc}:$CMAKE_PREFIX_PATH"
    export PATH="${shaderc}/bin:$PATH"
  '';

  meta = with lib; {
    description = "Minimal signal-driven speech-to-text for Wayland";
    homepage = "https://github.com/sevos/waystt";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "waystt";
  };
}
