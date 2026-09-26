{
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "modscan";
  version = src.rev;
  src = fetchFromGitHub {
    owner = "sysedwinistrator";
    repo = "modscan";
    rev = "731ce4e573a7816d8554549098636e134ae693da";
    sha256 = "sha256-U5xdQESgqpA/nyIAK6ifjTkKbvg42bN11FjxAWgA9SQ=";
  };
  vendorHash = null;
}
