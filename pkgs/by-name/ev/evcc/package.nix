{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  fetchNpmDeps,
  cacert,
  git,
  go,
  enumer,
  mockgen,
  nodejs,
  npmHooks,
  nix-update-script,
  nixosTests,
}:

let
  version = "0.132.0";

  src = fetchFromGitHub {
    owner = "evcc-io";
    repo = "evcc";
    tag = version;
    hash = "sha256-9HF9Beu2nLUoRViFluEc4kqGah2NfN/K0hqTZ4Bmo5c=";
  };

  vendorHash = "sha256-xxE/KBZvPBMd9cLE/uU74iyLaOYRd6m9HokTDi0FnRg=";

  commonMeta = with lib; {
    license = licenses.mit;
    maintainers = with maintainers; [ hexa ];
  };

  decorate = buildGoModule {
    pname = "evcc-decorate";
    inherit version src vendorHash;

    subPackages = "cmd/decorate";

    meta = commonMeta // {
      description = "EVCC decorate helper";
      homepage = "https://github.com/evcc-io/evcc/tree/master/cmd/decorate";
    };
  };
in

buildGoModule rec {
  pname = "evcc";
  inherit version src vendorHash;

  npmDeps = fetchNpmDeps {
    inherit src;
    hash = "sha256-AlwmMipGBnUSaqXxVBlC1c1IZ5utxLYx01T9byXOTrQ=";
  };

  nativeBuildInputs = [
    nodejs
    npmHooks.npmConfigHook
  ];

  overrideModAttrs = _: {
    nativeBuildInputs = [
      decorate
      enumer
      go
      git
      cacert
      mockgen
    ];

    preBuild = ''
      make assets
    '';
  };

  tags = [
    "release"
    "test"
  ];

  ldflags = [
    "-X github.com/evcc-io/evcc/server.Version=${version}"
    "-X github.com/evcc-io/evcc/server.Commit=${src.tag}"
    "-s"
    "-w"
  ];

  preBuild = ''
    make ui
  '';

  doCheck = !stdenv.hostPlatform.isDarwin; # darwin sandbox limitations around network access, access to /etc/protocols and likely more

  checkFlags =
    let
      skippedTests = [
        # network access
        "TestOctopusConfigParse"
        "TestTemplates"
        "TestOcpp"
      ];
    in
    [ "-skip=^${lib.concatStringsSep "$|^" skippedTests}$" ];

  passthru = {
    inherit decorate;
    tests = {
      inherit (nixosTests) evcc;
    };
    updateScript = nix-update-script { };
  };

  meta = commonMeta // {
    description = "EV Charge Controller";
    homepage = "https://evcc.io";
    changelog = "https://github.com/evcc-io/evcc/releases/tag/${version}";
  };
}
