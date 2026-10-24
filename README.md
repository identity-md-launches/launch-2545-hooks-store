# Hooks Store (HOOKS)

A fixed-supply ERC-20 token. The only production contract is
[`HooksStoreToken`](src/HooksStoreToken.sol); it uses the vendored OpenZeppelin
Contracts v5.1.0 ERC-20 implementation.

## Token and deployment parameters

| Parameter | Value |
| --- | --- |
| Solidity contract | `HooksStoreToken` |
| Source | `src/HooksStoreToken.sol` |
| Token name | `Hooks Store` |
| Symbol | `HOOKS` |
| Decimals | `18` |
| Whole-token supply | `1,000,000,000` |
| Supply in smallest units | `1000000000000000000000000000` (`10^27`) |
| Named supply constant | `INITIAL_SUPPLY` |
| Constructor arguments | None; ABI encoding is empty (`0x`) |
| Constructor value | `0` ETH |
| Initial recipient | Immediate deploying address, `msg.sender` |
| Intended launch chain | Ethereum, chain ID `1` |
| Compiler | Solidity `0.8.26` |
| EVM target | Cancun |
| Optimizer | Enabled, `200` runs |
| Bytecode metadata hash | `none` |

The constructor mints the entire supply once and emits one
`Transfer(address(0), deployer, 10^27)` event. When the launch factory creates
the token, the factory receives every token. The wallet that initiated the
transaction does not receive the factory's mint. The constructor calls no
external contracts and needs no existing on-chain infrastructure.

The production artifact is `out/HooksStoreToken.sol/HooksStoreToken.json`.
Its creation bytecode is deployable without constructor arguments or library
linking. Deploy it directly, without a proxy or initializer. Contracts under
`test/` are local test scaffolding and are not launch contracts.

The network's separate launch process prepares its manifest and deploys the
built bytecode. This project does not broadcast transactions or include a
launch manifest. No deployment key or address configuration is required to
build or test it.

## Behavior and assumptions

- The request specifies a plain token. There are no fees, taxes, rebases,
  transfer hooks, caps per wallet, or transfer restrictions beyond ERC-20
  balance, allowance, and zero-address checks. “Hooks Store” is the token's
  name; it does not add a Uniswap hook.
- The supply stays fixed. No public or external mint or burn function exists.
  There is no owner, administrator, pause, blacklist, seizure, or upgrade power.
- Successful transfers deliver the exact requested amount and return `true`.
  Invalid operations revert with OpenZeppelin's ERC-6093 custom errors.
  Zero-amount transfers and self-transfers are supported and emit `Transfer`.
- Transfers to the zero address and approvals to the zero address revert.
  Transfers do not call recipients or require them to implement a callback.
- `approve` replaces the caller's allowance for one spender. `transferFrom`
  requires the caller's allowance, including when caller and holder are the
  same address. Finite allowances decrease; `type(uint256).max` remains
  unchanged until the holder replaces or revokes it. Failed transfers roll
  back allowance changes as well as balance changes.
- `approve` emits `Approval`. OpenZeppelin v5 does not emit another `Approval`
  when `transferFrom` spends an allowance; integrations should query
  `allowance` for the current value.
- Pool creation, launch allocations, pricing, liquidity, and distributor
  claims are external launch responsibilities. The token grants those
  participants no special privileges and imposes no transfer taxes.

## Build and test

Use Foundry with Solidity `0.8.26` installed. All Solidity dependencies and
their licenses are ordinary files under `lib/`; no package installation,
submodule, RPC endpoint, environment configuration, FFI, or filesystem
cheatcode permissions are needed. Once the pinned compiler is available,
these checks work without network access:

```sh
forge build
FOUNDRY_FUZZ_SEED=0x802129092527ed78bd3942c95c591bf3c3e02fda04076ed6adeeab7ff18e5445 forge test
forge fmt --check
```

The fuzz seed is provided on the test command, not pinned in the configuration.
Tests do not read or modify environment variables and create fresh state for
each test. The configuration runs each fuzz test 512 times and each invariant
for 128 sequences of 64 actions.

The suite covers metadata, exact initial supply and its mint event, factory
CREATE/CREATE2 deployments, transfers and approval events, zero/self/full
balance transfers, maximum amounts, revocation, finite and infinite
allowances, unauthorized spending, insufficient balances and allowances,
zero-address rejection, atomic rollback, and rejection of mint, burn, admin,
upgrade, and ordinary ETH-send calls.

The stateful handler maintains an independent balance and allowance ledger.
It mixes successful and rejected operations, checking conservation of the
whole supply and all tracked balances and allowances after each action.
Expected token reverts are caught by the handler; unexpected handler failures
fail the invariant campaign (`fail_on_revert = true`).

The local launch test checks exact token movements for factory distribution,
claims, and transfers to and from a pool participant. It is not a Uniswap pool
or swap simulation. The supplied protected tests were read as acceptance
definitions; their full network harness, launch artifacts, and supporting
contracts are not part of this standalone repository, so those protected
suites are run by the independent verifier.

## After launch

There are no owner-settable parameters, external integrations to configure,
initialization calls, or token maintenance jobs.

The launch operator is responsible for deploying the exact reviewed artifact,
checking the metadata, supply, constructor mint recipient, and distribution,
then verifying the source with the same compiler settings. The launch factory
and distributor perform the allocations and claims according to the launch
policy; the token constructor retains or reserves no portion for another
contract. No administrative ownership handover is necessary.

Holders control transfers and approvals. They must validate recipients and
spenders, revoke unused approvals, and account for the standard ERC-20
allowance replacement race: revoke an existing allowance to zero and confirm
that transaction before setting a replacement. Unlimited approvals expose
the holder's available balance to the approved spender. Tokens sent to this
token contract or another contract unable to return them cannot be recovered
by an administrator. Ordinary ETH sends revert; forcibly sent ETH has no
recovery mechanism.

Local verification consists of Foundry compilation, unit tests, fuzz tests,
stateful invariants, and formatting checks. Slither and Mythril were not run.
These checks are not an independent security audit; the network's separate
adversarial review and launch checks remain release responsibilities.

## Dependencies and license

See [THIRD_PARTY.md](THIRD_PARTY.md) for vendored versions, source archive
checksums, and license locations. Project code is MIT licensed; dependency
files retain their upstream licenses.
