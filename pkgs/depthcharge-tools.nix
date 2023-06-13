{python3Packages}: let
  inherit (python3Packages) buildPythonPackage fetchPypi setuptools;
in
  buildPythonPackage rec {
    pname = "depthcharge-tools";
    version = "0.6.1";

    propagatedBuildInputs = [setuptools];

    src = fetchPypi {
      inherit pname version;
      sha256 = "sha256-JICP7+Zfn4EBg793mvXv4U4zccbM8KYJoiW1NNKFCTI=";
    };
  }
