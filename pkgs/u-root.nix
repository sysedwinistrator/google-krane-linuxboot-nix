{
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  name = "uroot";
  version = src.rev;

  CGO_ENABLED = 0;

  src = fetchFromGitHub {
    owner = "u-root";
    repo = "u-root";
    rev = "b4273b092637ad78ca07f36da43bda09d7276b6b";
    sha256 = "K6j1xn+Pz4YTMR6eIhFr3xhEKML8rJV5GtV9J3sGx4g=";
  };

  vendorHash = null;

  doCheck = false; # currently broken as it expects /bin/bash and /bin/ls
}
