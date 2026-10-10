FROM scratch
# The build context MUST be the exported kernel package directory, not the repo.
COPY . /
LABEL org.opencontainers.image.title="Quantum Talos 1.14.2 PL011 AXI kernel"
LABEL org.opencontainers.image.version="v1.14.2-rp1-axi1"
LABEL org.opencontainers.image.source="https://github.com/siderolabs/pkgs"
LABEL home.antonu.org.pkgs-commit="6c312e4b77817a9c1bd4975a532b3fd23d33430c"
LABEL home.antonu.org.backport-sha256="b4dad001ddc873347ddf2bbc3458aafdbabf11d2f07fbfce9bf2a5e6662e42dd"
