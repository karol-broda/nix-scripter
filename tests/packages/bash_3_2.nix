{
  lib,
  stdenv,
  fetchurl,
  bison,
}:
stdenv.mkDerivation {
  pname = "bash";
  version = "3.2.57";

  src = fetchurl {
    url = "mirror://gnu/bash/bash-3.2.57.tar.gz";
    sha256 = "1906zs5qc1fblyjb2w5wnmgcgczfvn1i5r8c167hcddzbvwdma9z";
  };

  nativeBuildInputs = [ bison ];

  # Tests never edit lines interactively. The bundled readline and termcap
  # also define the same globals, which modern linkers reject.
  configureFlags = [
    "--without-bash-malloc"
    "--disable-nls"
    "--disable-readline"
  ];

  # The sources predate C99 and modern compilers reject them by default.
  env.NIX_CFLAGS_COMPILE = toString [
    "-std=gnu89"
    "-fcommon"
    "-Wno-error=implicit-function-declaration"
    "-Wno-error=implicit-int"
    "-Wno-error=incompatible-pointer-types"
    "-Wno-error=int-conversion"
    "-Wno-error=return-mismatch"
  ];

  hardeningDisable = [ "format" ];
  enableParallelBuilding = false;
  doCheck = false;

  meta = {
    description = "GNU Bash 3.2, the /bin/bash of macOS, for compatibility tests";
    license = lib.licenses.gpl2Plus;
    mainProgram = "bash";
    platforms = lib.platforms.unix;
  };
}
