# DittoETH audit details

- Total Prize Pool: $60,500 in USDC
  - HM awards: $45,750 in USDC
  - Analysis awards: $1,500 in USDC
  - QA awards: $1,250 in USDC
  - Bot Race awards: $1,500 in USDC
  - Gas awards: $0 in USDC
  - Judge awards: $6,000 in USDC
  - Lookout awards: $4,000 USDC
  - Scout awards: $500 in USDC
- Join [C4 Discord](https://discord.gg/code4rena) to register
- Submit findings [using the C4 form](https://code4rena.com/contests/2024-03-dittoeth/submit)
- [Read our guidelines for more details](https://docs.code4rena.com/roles/wardens)
- Starts March 15, 2024 20:00 UTC
- Ends April 5, 2024 20:00 UTC

## Automated Findings / Publicly Known Issues

The 4naly3er report can be found [here](https://github.com/code-423n4/2024-03-dittoeth/blob/main/4naly3er-report.md).

Automated findings output for the audit can be found [here](https://github.com/code-423n4/YYYY-MM-contest-candidate/blob/main/bot-report.md) within 24 hours of audit opening.

_Note for C4 wardens: Anything included in this `Automated Findings / Publicly Known Issues` section is considered a publicly known issue and is ineligible for awards._

> See [known issues from Codehawks](https://github.com/Cyfrin/2023-09-ditto/tree/a93b4276420a092913f43169a353a6198d3c21b9?tab=readme-ov-file#known-considerations-from-previous-stablecoin-codehawk-report)

- Oracle is very dependent on Chainlink, stale/invalid prices fallback to a Uniswap TWAP. 2 hours staleness means it can be somewhat out of date.
- Issues related to the start/bootstrap of the protocol
  - When there are few ShortRecords or TAPP is low, it's easy to fall into black swan scenario
  - Ditto rewards: first claimer gets 100% of ditto reward, also `dittoShorterRate` can give more/less ditto than expected (see [L-21](https://www.codehawks.com/report/clm871gl00001mp081mzjdlwc#L-21)).
  - Empty order book can lead to issues: matching self can get ditto rewards/yield. Creating a low bid (see [L-16](https://www.codehawks.com/report/clm871gl00001mp081mzjdlwc#L-16)) isn't likely since anyone would want to simply match against it. Creating a high short that eventually matches seems impossible with real orders. Can also prevent creating an order too far away from the oracle.
- Issues related to front-running: can front-run someone's order, liquidation, the chainlink/uniswap oracle update.
- Not finished with governance/token setup
- Bridge credit system:
  - If user has LST credit but that bridge is empty, LST credit can be redemeed for the other base collateral at 1-1 ratio
  - In NFT transfer, LST credit is transferred up to the amount of the collateral in the ShortRecord, which includes collateral that comes from bidder
- Incentives should mitigate actions from bad/lazy actors and promote correct behavior, but they do not guarantee perfect behavior:
  - Primary Liquidation
  - Redemptions in the correct order
- There is an edge case where a short meets erc requirements because of ercDebtRate application
- `disburseCollateral` in `proposeRedemption()` can cause user to lose yield if their SR was recently modified and it’s still below 2.0 CR (modified through order fill, or increase collateral)
- Redemption proposal is intentionally overly conservative in considering SR ineligible (with regards to `minShortErc`) to prevent scenarios of ercDebt under `minShortErc`
- Recovery Mode: currently not checking `recoveryCR` in secondary liquidation unlike primary, may introduce later.
- Redemptions: there is an issue when `claimRemaningCollateral()` is called on a SR that is included in a proposal and is later correctly disputed.

# Overview

## About Ditto

The Ditto protocol is a new decentralized stable asset protocol for Ethereum mainnet. It takes in overcollateralized liquid staked ETH (rETH, stETH) to create stablecoins using a gas optimized orderbook (starting with a USD stablecoin, dUSD).

On the orderbook, bidders and shorters bring ETH, askers can sell their dUSD. Bidders get the dUSD, shorters get the bidders collateral and a ShortRecord to manage their debt position (similar to a CDP). Shorters get the collateral of the position (and thus the LST yield), with the bidder getting the stable asset, rather than a CDP where the user also gets the asset.

## Resources

> I'm happy to answer any questions on the discord/twitter!

- **Previous audits:** [Codehawks](https://www.codehawks.com/contests/clm871gl00001mp081mzjdlwc)
  - [Findings Report](https://www.codehawks.com/report/clm871gl00001mp081mzjdlwc)
  - [Archived GitHub repo](https://github.com/Cyfrin/2023-09-ditto)
- **Documentation:** https://dittoeth.com/technical/concepts
  - **Website:** https://dittoeth.com
  - **Litepaper:** https://dittoeth.com/litepaper
  - **Blog:** https://dittoeth.com/blog
- **Twitter:** https://twitter.com/dittoproj
- **GitHub Org:** https://github.com/dittoeth

# Scope

> Run [Solidity Metrics](https://marketplace.visualstudio.com/items?itemName=tintinweb.solidity-metrics) on `contracts/` using exclusions with length 120 (`forge fmt`)

| Contract | nSLOC | Purpose | Changes | External Libraries |
| -------- | ----- | ------- | ------- | ------------------ |
| [facets/BidOrdersFacet.sol](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BidOrdersFacet.sol)                   | 234   | Facet for creating and matching bids                    | dust checks                                                   |                          |
| [facets/ShortOrdersFacet.sol](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ShortOrdersFacet.sol)               | 54    | Facet for creating and matching short orders            | SR created with Short Order, recoveryMode, minShortErc checks |                          |
| [facets/BridgeRouterFacet.sol](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BridgeRouterFacet.sol)             | 101   | Facet to handle depositing and withdrawing LSTs         | Credit mechanism for withdraw                                 | IBridge                  |
| [facets/ExitShortFacet.sol](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ExitShortFacet.sol)                   | 126   | Facet for a shorter to exit their short                 | minShortErc checks                                            | IDiamond.createForcedBid |
| [facets/RedemptionFacet.sol](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)                 | 241   | Ability to swap dUSD for ETH, akin to Liquity           | new                                                           |                          |
| [libraries/LibBridgeRouter.sol](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBridgeRouter.sol)           | 151   | Helper library used in BridgeRouterFacet                | new                                                           | Uniswap                  |
| [libraries/LibBytes.sol](https://github.com/code-423n4/2024-03-dittoeth/)                                                         | 35    | Library in RedemptionFacet to save proposals in SSTORE2 | new                                                           |                          |
| [libraries/LibOracle.sol](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)                       | 125   | Library to get price with Chainlink + backup            | handle reverts                                                | Chainlink/Uniswap        |
| [libraries/LibOrders.sol](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)                       | 575   | Library Order Facets to do matching                     | dust, oracle price changes, auto adjust dethTithePercent      |                          |
| [libraries/LibSRRecovery.sol](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRRecovery.sol)               | 23    | Library to check if hits recovery CR                    | new                                                           |                          |
| [libraries/LibSRMin.sol](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRMin.sol)                         | 47    | Library to help do checks around minShortErc            | new                                                           |                          |
| [libraries/LibSRTransfer.sol](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRTransfer.sol)               | 29    | Library to transfer ShortRecord as NFT                  | new checks                                                    |                          |
| [libraries/UniswapOracleLibrary.sol](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/UniswapOracleLibrary.sol) | 34    | Used to get TWAP from Uniswap                           | didn't audit last time                                        | Uniswap                  |

## Out of scope

> Out of scope but helpful or necessary to understand the system
> (notes/changes from last audit in parens)

- `contracts/bridges/BridgeReth.sol` (addition of `getUnitDethValue()`)
- `contracts/bridges/BridgeSteth.sol` (addition of `getUnitDethValue()`)
- `facets/AskOrdersFacet.sol`
- `facets/ERC721Facet.sol` (new checks to mint)
- `facets/MarketShutdownFacet.sol`
- `facets/OrdersFacet.sol` (the changes are in LibOrders.sol)
- `facets/OwnerFacet.sol` (mostly renames, new set functions)
- `facets/PrimaryLiquidationFacet.sol` (minShortErc, renamed, remove flagging, recoveryMode)
- `facets/SecondaryLiquidationFacet.sol` (minShortErc, renamed, recoveryMode)
- `facets/ShortRecordFacet.sol` (minShortErc, recoveryMode)
- `facets/TWAPFacet.sol`
- `facets/YieldFacet.sol`
- `facets/VaultFacet.sol`
- `facets/ViewFacet.sol`
- `libraries/LibShortRecord.sol`
- `libraries/LibVault.sol` (new withdraw methods)
- `libraries/AppStorage.sol` (holds structs)
- `libraries/Constants.sol`
- `libraries/DataTypes.sol` (struct packing)
- `libraries/LibAsset.sol`
- `libraries/LibBridge.sol` (only removal)
- `libraries/PRBMathHelper.sol` (also out of scope previously)

---

- `facets/DiamondCutFacet.sol` (unchanged)
- `facets/DiamondEtherscanFacet.sol` (new, but view only)
- `facets/DiamondLoupeFacet.sol` (unchanged)
- `facets/TestFacet.sol`
- `governance/DittoGovernor.sol` (also out of scope previously)
- `governance/DittoTimelockController.sol` (also out of scope previously)
- `interfaces/*.sol`
- `libraries/console.sol`
- `libraries/Errors.sol`
- `libraries/Events.sol`
- `libraries/LibDiamond.sol` (old version had bug with removing functions in 0.8.20)
- `libraries/LibDiamondEtherscan.sol`
- `libraries/UniswapOracleLibrary.sol` (also out of scope previously)
- `libraries/UniswapTickMath.sol` (also out of scope previously)
- `mocks/*.sol`
- `tokens/Asset.sol` (no change, ERC)
- `tokens/Ditto.sol` (no change, ERC)
- `Diamond.sol` (unchanged)
- `EtherscanDiamondImpl.sol` (used for etherscan)

## High Level Changes

This is large update to the original [codebase](https://github.com/Cyfrin/2023-09-ditto), so the scope doesn't encompass everything that will be relevant to review it. Most of the changes are to address previously known issues or findings from the last audit (if you want to review previous findings, you can filter by "finding-x" in the [Codehawk submissions](https://www.codehawks.com/submissions/clm871gl00001mp081mzjdlwc)).

- Enable better enforcement of minimum Orders (see Codehawks "finding-145": [M-02. User can create small position after exit with bid](https://www.codehawks.com/report/clm871gl00001mp081mzjdlwc#M-02)), and in particular a minimum ShortRecord debt requirement (makes liquidation worth it).
  - Previously this only included `minBidEth`, `minAskEth`, `minShortErc` which was checked during the start of `createBid`,`createAsk`, `createLimitShort` calls.
  - Tries to enforce a min Order after partial matches by cancelling the dust amount of an order, rather than only if the result is less than 1 wei.
  - Now it checks _after_ execution, in any function that relates to ShortRecords (primary liquidation, secondary liquidation, exit short, etc). If a ShortRecord has less than the minShortErc, some operations may _cancel_ the corresponding Short Order (adding the collateral/debt into the SR like a CDP) to enable the ShortRecord to contain at least minShortErc.
- Fix issues related to withdrawals (see "finding-579" [L-13. Instant arbitrage opportunity through rETH and stETH price discrepancy](https://www.codehawks.com/report/clm871gl00001mp081mzjdlwc#L-13)): introduce a "credit" system for when LST (rETH/stETH) is deposited to handle arbitrage between depositing and withdrawing. Users can only withdraw what type of LST they deposit with. Any extra withdrawals due to yield gain will be given based on checking the oracle price difference between the LSTs. Also remove
- Add redemptions feature similar in purpose to Liquity (not a fork): allows redeeming stable asset (dusd) for eth, from lowest collateral ratio ShortRecord to highest. However, ShortRecords are not sorted on-chain, so users must propose a set of ShortRecords will a calculated dispute time (if disputed there is a penalty). Then after the time passes, users can claim their corresponding redemption. There is also a maximum limit CR that is allowed (at the moment, 2 CR) to be redeemable, meaning if the lowest CR short is 2 CR, the redemption function cannot be used.
- Help with a potential DUSD discount: when matches happen (bid/ask) below oracle price, the fee/tithe increases accordingly, meaning shorters decrease in yield and some may be incentivized to exit, which happens until some equilibrium is reached.
- A simple "Recovery Mode" like functionality, when the overal total CR of the system is under 150%, liquidation can happen at 150% instead of 110%.
- Remove flagging concept from primary liquidations.
- Redemptions have been introduced with the intention to be available before primary/secondary liquidation methods. Upon deploy/release, the associated threshold for liquidations should be lower than the redemption CR.
- Allow Short Orders to be leveraged, assuming they provide enough to cover minShortErc when matched against a bid.

# Additional Context

- [x] Describe any novel or unique curve logic or mathematical models implemented in the contracts
- [x] Please list specific ERC20 that your protocol is anticipated to interact with. Could be "any" (literally anything, fee on transfer tokens, ERC777 tokens and so forth) or a list of tokens you envision using on launch.
  - Lido (stETH) and Rocketpool (rETH) and potentially other LSTs in the future
- [x] Please list specific ERC721 that your protocol is anticipated to interact with.
  - Ditto's own ShortRecord(s) _can_ become an NFT if it's minted/transfered
- [x] Which blockchains will this code be deployed to, and are considered in scope for this audit?
  - Ethereum mainnet only
- [x] Please list all trusted roles (e.g. operators, slashers, pausers, etc.), the privileges they hold, and any conditions under which privilege escalation is expected/allowable
  - Owner: Highest level of access, ablility to create new vaults and markets, in addition to parameter changes
  - Admin: Secondary role to allow quicker response time to sensitive actions, includes parameter changes
- [ ] In the event of a DOS, could you outline a minimum duration after which you would consider a finding to be valid? This question is asked in the context of most systems' capacity to handle DoS attacks gracefully for a certain period.
- [ ] Is any part of your implementation intended to conform to any EIP's? If yes, please list the contracts in this format:
  - `Contract1`: Should comply with `ERC/EIPX`
  - `Contract2`: Should comply with `ERC/EIPY`

## Attack ideas (Where to look for bugs)

_List specific areas to address - see [this blog post](https://medium.com/code4rena/the-security-council-elections-within-the-arbitrum-dao-a-comprehensive-guide-aa6d001aae60#9adb) for an example_

- Redemptions, as this is an entirely new concept to the protocol.
- Anything related to Orderbook matching logic, can get complicated in terms of what was done to save gas
  - The Orderbook only allows matching a Short Order at or above oracle price, unlike bids/asks so that part acts differently than an usual orderbook
  - Oracle price is cached to 15m, mostly done to allow the hint system to work (placing bids in sorted position in a mapping as a linked list is expensive, so the hint is used to know where in the list an order should go). This is worse with a short order because short orders can't be matched below oracle price. But if the oracle price is always changing, it is difficult to pick a hint that will be valid when the transaction happens, so the system allows for 0.5% buffer and allows matching backwards in this scenario until it reaches the correct "starting short id", which is the short order id that represents the first short order that can be correctly matched (at or above oracle).
- Dust amounts: want to prevent small orders on the orderbook to prevent skyrocketing gas costs for large orders that match with multiple limit orders
- Concept of `minShortErc`: Primary liquidators should always have a large enough incentive to liquidate (`callerFeePct` tied to liquidated collateral) risky debt because every ShortRecord must either contain enough ercDebt or have access to enough ercDebt (through cancelling the associated short order). The one noted exception is listed in known issues (ercDebt requirements met from application of ercDebtRate)
- Anything related to being able to correctly liquidate/exit ShortRecords that are a certain collateral ratio

## Main invariants

_Describe the project's main invariants (properties that should NEVER EVER be broken)._

## Scoping Details

```
- If you have a public code repo, please share it here: Previous archive is https://github.com/Cyfrin/2023-09-ditto
- How many contracts are in scope?: 13
- Total SLoC for these contracts?: 1775
- How many external imports are there?: 8
- How many separate interfaces and struct definitions are there for the contracts within scope?:  Every contract has a generated interface from a script given use of Diamond. 8 Structs are in contracts/libraries/DataTypes.sol in STypes (Storage Types): Order, ShortRecord, NFT, Asset, Vault, AssetUser, VaultUser, Bridge
- Does most of your code generally use composition or inheritance?: Composition: mostly Diamond Facets and Libraries
- How many external calls?: 18
- What is the overall line coverage percentage provided by your tests?: 96%
- Is this an upgrade of an existing system?: True
- Check all that apply (e.g. timelock, NFT, AMM, ERC20, rollups, etc.): Ditto token and Stable Assets like dUSD are ERC20s, ShortRecords can become ERC721s
- Is there a need to understand a separate part of the codebase / get context in order to audit this part of the protocol?: True, since not everything is in scope
- Please describe required context:
- Does it use an oracle?:  Chainlink ETH/USD and Uniswap stETH and RETH
- Describe any novel or unique curve logic or mathematical models your code uses: No
- Is this either a fork of or an alternate implementation of another project?: False
- Does it use a side-chain?: No
- Describe any specific areas you would like addressed: OrderBook logic, issues with dust, redemptions, underwater ShortRecords, also below
```

# Tests

> removed extra ui/subgraph code

```sh
git clone https://github.com/code-423n4/2024-03-dittoeth
cd 2024-03-dittoeth

# For node: use volta to get node/npm
curl https://get.volta.sh | bash
volta install node

# Use Bun to run TypeScript
curl -fsSL https://bun.sh/install | bash

# download files from package.json into node_modules
npm install

# Install foundry for solidity
curl -L https://foundry.paradigm.xyz | bash
# project as a `npm run prebuild` check for foundry version
foundryup -v nightly-5b7e4cb3c882b28f3c32ba580de27ce7381f415a

# .env for tests
echo 'ANVIL_9_PRIVATE_KEY=0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6' >> .env
echo 'MAINNET_RPC_URL=http://eth.drpc.org' >> .env

# create interfaces (should already be committed into `interfaces/`, but usually in .gitignore)
bun run interfaces-force

# build
bun run build

# unit/fork/invariant tests
bun run test

# gas tests, check `/.gas.json`
bun run test-gas

# invariant tests only
bun run invariant

# view coverage as is (brew install lcov)
genhtml \
        --output-directory coverage \
        filtered-lcov.info
    open coverage/index.html

# run coverage from scratch
bun run coverage
```

- `bun run` to check commands
- If you want to reset everything not tracked in git: `git clean -xfd`
- To run local node: `bun run anvil-fork`, then deploy with `bun run deploy-local`
- `bun run interfaces` to re-compile solidity interfaces to `interfaces/`
- `bun run build` to compile contracts, foundry cache in `foundry/`

tests are located in `/test/` and `test-gas/`: contains unit, fork, gas, invariant tests

- `bun run test`
  - `-- --vv` for verbosity
  - `-- --watch` to watch files
  - `-- -m testX` to match tests
- `bun run test-fork`: gas fork tests read from `MAINNET_RPC_URL`
- `bun run test-gas` for gas tests, reads `test-gas/`, writes gas to `.gas.json`
- `bun run coverage` (first `brew install lcov`)

> https://book.getfoundry.sh/forge/writing-tests.html#writing-tests
> For info on `v`, https://book.getfoundry.sh/forge/tests.html?highlight=vvvv#logs-and-traces

## Miscellaneous

If you get an error like:

> Error (9582): Member "asdf" not found or not visible after argument-dependent lookup in contract IDiamond.

It means you need to rebuild the `interfaces/` and run `bun run interfaces-force`, which generates `interfaces/Interface.sol` which are imported in the `contracts/`

If there's an error with fork tests due to RPC, may need to disable those tests or switch RPC to local node or a different one via changing the `.env` like so: `MAINNET_RPC_URL=https://eth.drpc.org`. I would suggest any at [Chainlist](https://chainlist.org/chain/1).

> [FAIL. Reason: setup failed: Could not instantiate forked environment with fork url
> [FAIL. Reason: setup failed: backend: failed while inspecting: Database error

Aliases:

```sh
alias i='bun run interfaces-force'
alias t="forge test "
alias tm="forge test --match-test "
alias ts="forge test --match-test statefulFuzz"
alias g="bun run test-gas"
alias gm="FOUNDRY_PROFILE=gas forge build && FOUNDRY_PROFILE=testgas forge test --match-test "
alias w='forge test -vv --watch '

# t -m testA
# gm testA
# w -m testA
```
