# Security review scope

The review applies to `WorldMarketToken`, its vendored ERC-20 inheritance chain,
and the project's tests. The supplied pinned eth-security reference was used as
a checklist. It did not add features or change the requested token economics.

| Area | Design and verification |
| --- | --- |
| Issuance and units | Exactly `10^27` smallest units, representing one billion WORLD with 18 decimals, minted only in the constructor to its caller. Direct and factory deployments and the single mint event are tested. |
| Supply conservation | No exposed mint or burn methods. Transfer and allowance fuzz tests and stateful model invariants check constant total supply and exact balances. |
| Authorization | No owner or roles. Transfers act on the caller's balance; delegated transfers require that holder's allowance. Tests verify deployer and strangers cannot bypass allowances or reach common admin methods. |
| Arithmetic | Solidity 0.8.26 and unmodified OpenZeppelin ERC-20 accounting. Boundary tests include the whole supply, insufficient balance, insufficient allowance, and maximum `uint256`. |
| Atomicity | Tests check balances and allowances after failed delegated transfers, including failure after allowance deduction. |
| External interactions | No external calls, receiver hooks, token callbacks, or external dependencies in the deployed token. Reentrancy guards are unnecessary for this implementation. |
| Transfers | No fees, taxes, freezes, or address-dependent restrictions beyond standard zero-address checks. Tests simulate factory distribution, claims, and transfers into and out of a pool address. |
| Upgrades and destructive operations | No proxy, delegatecall, callcode, selfdestruct, or upgrade entry point. |
| Approvals | Standard ERC-20 replacement and unlimited-allowance behavior; holder approval and revocation responsibilities are documented in the README. |
| Out-of-scope features | No oracles, randomness, signatures, vault arithmetic, administrative maintenance, or DEX pricing logic. |

Local verification uses `forge build`, the Foundry unit/fuzz/invariant suite with
the assignment's seed, and `forge fmt --check`. No transactions are broadcast and
no wallets or deployment secrets are used. Slither and Mythril were not run.

Recorded local results with Solidity 0.8.26:

- Build and formatting checks passed.
- All 33 unit/fuzz tests passed, including 512 inputs for each of five fuzz tests.
- Both stateful invariants passed in one campaign: 128 runs, 8,192 calls, and no
  unexpected reverts. Foundry reports 34 passing tests across the two suites.
- Vendored file checksums matched `DEPENDENCIES.sha256`.
- The compiled runtime is 1,752 bytes and the creation bytecode is 2,648 bytes.
  A scan of runtime instructions, skipping PUSH operands as the protected check
  does, found no CALLCODE, DELEGATECALL, or SELFDESTRUCT. Library link references
  are empty and the constructor ABI takes no arguments.

The local pool-address test checks exact token movement only. The network's
protected checks cover real pool initialization, liquidity settlement, swaps,
and admission with resolved launch inputs. Those infrastructure sources and
inputs are not delivered here, so that protected suite is not claimed as a
locally executed integration test.

This is an implementation review, not an independent security audit. Production
release remains subject to the network's independent review and deployment
verification. Review also needs to cover the factory's distribution behavior and
the broader launch infrastructure, which are outside this token implementation.
