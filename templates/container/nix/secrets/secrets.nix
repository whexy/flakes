# Agenix secret rules.
#
# IMPORTANT: the recipient below is the PUBLIC half of the *external* age
# identity. The corresponding private identity is injected into the
# container at runtime (SETUP.md) and must never be stored on the Incus
# storage volume or in this repository.
let
  # TODO: replace with your external identity's public key, from:
  #   age-keygen -o encrypted-home-identity.txt   (run on a trusted machine)
  #   grep 'public key:' encrypted-home-identity.txt
  external-home-identity = "age1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq";

  # Optional: an admin key so you can rekey/edit secrets from your
  # workstation with `agenix -e` / `agenix -r`.
  # admin = "age1...";
in
{
  "home-gocryptfs-key.age".publicKeys = [
    external-home-identity
    # admin
  ];
}
