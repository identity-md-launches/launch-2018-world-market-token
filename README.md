# World Market Token (WORLD)

A fixed-supply ERC-20 implemented by `src/WorldMarketToken.sol`, using the vendored
OpenZeppelin Contracts v5.0.2 ERC-20 implementation.

| Parameter | Value |
| --- | --- |
| Solidity contract identifier | `WorldMarketToken` |
| Token name | `World Market Token` |
| Symbol | `WORLD` |
| Decimals | `18` |
| Supply in whole tokens | `1,000,000,000` |
| Supply in smallest units | `1000000000000000000000000000` (`10^27`) |
| Constructor arguments | None (`[]`) |
| Initial recipient | The immediate deployer, `msg.sender` |
| Intended launch chain | Ethereum, chain ID `1` |
| Admin, initializer, upgrade mechanism | None |

`INITIAL_SUPPLY` is a public constant. The constructor mints this amount once and
emits the standard `Transfer` event from the zero address. A factory deployment
credits the factory, not the account calling it. The constructor makes no external
calls and can run on an empty chain. There are no application contracts to deploy.

## Behavior and assumptions

The brief is implemented as a standard, transferable ERC-20. Transfers deliver the
exact requested amount. There are no token taxes, transfer burns, rebasing,
blacklists, pause controls, seizure powers, or post-deployment minting. Total supply
remains constant. A holder cannot burn tokens through this contract.

`transfer`, `approve`, and `transferFrom` return `true` on success and revert on
failure with OpenZeppelin's ERC-6093 custom errors. Zero-value transfers and
self-transfers are supported; a self-transfer still requires enough balance.
Transfers to the zero address and approvals to a zero spender revert.

An approval replaces the previous allowance. Finite allowances decrease when
spent; `type(uint256).max` is an unlimited allowance and does not decrease.
`approve` emits `Approval`; transfers emit `Transfer`. This OpenZeppelin version
does not emit `Approval` when `transferFrom` spends an allowance, so integrations
should read `allowance` rather than reconstructing it solely from approval events.
There is no permit/signature extension.

No recipient, owner, oracle, router, or signer configuration is needed. The token
does not embed launch economics or distribute the supply itself. The launch
factory handles distribution and liquidity after receiving the entire issuance.
Test-only factories, actors, and recipient addresses are local fixtures and are
not deployment parameters.

## Build and test

Run from the repository root with Foundry and Solidity 0.8.26 available:

```sh
forge build
FOUNDRY_FUZZ_SEED=0xd0f9f8948d4b98dba44b821d76305412991b259e39d410e9c80a14c168fa7d33 forge test
forge fmt --check
```

`foundry.toml` pins `solc = "0.8.26"`, the Cancun EVM target, optimizer settings
(enabled, 200 runs), and `bytecode_hash = "none"`. All dependencies are ordinary
source files in `lib/`; no install step, network, submodule, environment-based
test configuration, FFI, or filesystem permissions are needed. The fuzz seed above
is supplied to Foundry by the runner, not read by the Solidity tests.

The unit and fuzz suite covers exact metadata and issuance, mint events, direct
and CREATE2 factory deployment, exact distribution and claim transfers, transfer
and approval events, allowance isolation/replacement/revocation, infinite
allowances, zero and maximum values, unauthorized spending, and atomic rollback
on failures. Stateful invariants exercise transfers, approvals, delegated
spending, and rejected overdrafts, comparing all actor balances and allowances
against an independent model while checking supply conservation. Configuration
uses 512 cases per fuzz test and 128 invariant sequences of up to 64 operations.

The local distribution test models the token movements of the supplied launch
checks. It is not a Uniswap integration test. The supplied protected harness also
requires network-owned launch infrastructure and resolved deployment inputs that
are not part of this repository; that harness runs in the independent verifier.

Dependency versions, source URLs, licenses, and file hashes are documented in
[DEPENDENCIES.md](DEPENDENCIES.md). Security review scope and limitations are in
[docs/SECURITY.md](docs/SECURITY.md).

## Deployment and operations

The deployable artifact is
`out/WorldMarketToken.sol/WorldMarketToken.json`. Deploy its creation bytecode
with no appended constructor arguments and no ETH value. There are no linked
libraries or initialization transactions. Do not deploy it behind a proxy: its
supply and metadata are initialized by its constructor.

For the IdentityMD launch, the network's deployer and factory perform deployment;
the factory receives the entire supply and performs the launch's allocation and
pool operations. The separate manifest step records `WorldMarketToken`, the exact
metadata and supply above, and an empty constructor argument list. No manifest,
wallet configuration, private key, or broadcasting script is included here.

After launch, the deployment operator should verify the source and compiler
settings on the explorer, confirm metadata and `totalSupply()`, and reconcile the
constructor mint and factory distribution events with the accepted launch terms.
No token settings or ownership handovers are required. No keeper or administrator
is needed for transfers. An independent adversarial review remains a release
responsibility; local tests are not a security audit.

Holders control their own transfers and approvals. Approve trusted spenders only,
prefer bounded allowances, and revoke unused approvals. Changing an existing
nonzero approval can race with spending; applications should clear it first and
wait for confirmation before approving a replacement when appropriate. The
deployer has no exception to allowance checks.

There is no rescue function. Tokens sent to this token's own address or to a
contract that cannot send them back can become inaccessible. Ordinary ETH sends
are rejected; forcibly delivered ETH and unrelated assets cannot be recovered
through this contract. Distribution and custody after issuance are the receiving
factory's and holders' responsibilities.
