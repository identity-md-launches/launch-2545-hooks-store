# Vendored dependencies

The dependencies below are checked in as ordinary files, without submodules,
generated bindings, installation hooks, or external paths. The selected
upstream files are unmodified. Only the listed subsets are included.

| Dependency | Pinned release | Included files | License |
| --- | --- | --- | --- |
| [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/v5.1.0) | `v5.1.0` | `ERC20.sol`, `IERC20.sol`, `IERC20Metadata.sol`, `Context.sol`, `draft-IERC6093.sol` and license | [MIT](lib/openzeppelin-contracts/LICENSE) |
| [Forge Standard Library](https://github.com/foundry-rs/forge-std/tree/v1.9.7) | `v1.9.7` | Solidity files under `src/` and licenses; used only by tests | [MIT](lib/forge-std/LICENSE-MIT) / [Apache-2.0](lib/forge-std/LICENSE-APACHE) |

SHA-256 checksums of the downloaded upstream source archives:

```text
8a3b08cfc756437ba3343901565b18182adb42ec1e621960240a19da5d738686  openzeppelin-contracts-v5.1.0.tar.gz
45157353ab49eab01d294565866731e599b32401757229689ee459aa26b7ee94  forge-std-v1.9.7.tar.gz
```

Archive URLs:

- `https://codeload.github.com/OpenZeppelin/openzeppelin-contracts/tar.gz/refs/tags/v5.1.0`
- `https://codeload.github.com/foundry-rs/forge-std/tar.gz/refs/tags/v1.9.7`

The archives are not required to build. `vendor-checksums.txt` records SHA-256
checksums for every delivered dependency file. Verify them locally with:

```sh
sha256sum --check vendor-checksums.txt
```
