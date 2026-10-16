# Vendored dependencies

Dependencies are checked in as ordinary files, with no submodules, package
installation, or compiler binaries. Production code uses only the five Solidity
files in the OpenZeppelin subset below. Forge standard library is for tests only.

| Dependency | Pinned release | Included files | License |
| --- | --- | --- | --- |
| [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/v5.0.2) | `v5.0.2` | `ERC20.sol`, `IERC20.sol`, `IERC20Metadata.sol`, `Context.sol`, `draft-IERC6093.sol`, `LICENSE` | MIT |
| [Forge Standard Library](https://github.com/foundry-rs/forge-std/tree/v1.9.7) | `v1.9.7` | Complete `src/` directory, `LICENSE-MIT`, `LICENSE-APACHE` | MIT OR Apache-2.0 |

OpenZeppelin files were fetched from the tagged official raw source at
`https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/`.
Forge standard library was extracted from the official release archive at
`https://codeload.github.com/foundry-rs/forge-std/tar.gz/refs/tags/v1.9.7`.
That archive's SHA-256 is
`45157353ab49eab01d294565866731e599b32401757229689ee459aa26b7ee94`.

Vendored source files and license texts are unmodified. Their SHA-256 checksums
are recorded in `DEPENDENCIES.sha256`; verify them offline from the root with:

```sh
sha256sum -c DEPENDENCIES.sha256
```

Some forge-std helpers expose Foundry's environment, file, or FFI cheatcodes.
This project's tests do not use those capabilities, and Foundry configuration
does not grant filesystem permissions or enable FFI.
