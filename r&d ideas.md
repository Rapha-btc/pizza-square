# R&D Grant Ideas - Concise Summary

## 1. Tax-Enforced Token Standard (SIP-010 Extension)

Code-body verification using `contract-hash?` to enforce royalties/taxes at token level for both fungible and non-fungible tokens. DEXes must implement tax-paying logic in contract code to interact with tokens. Solves Ethereum's royalty enforcement problem on Stacks. Backward compatible with existing SIP-010 infrastructure. Enables sustainable tokenomics for AI DAOs and creator economies without centralized gatekeepers.

## 2. One-Way Trustless Runes Bridge

Clarity reads Bitcoin OP_RETURN data directly where Runes protocol encodes transfer amounts using varint. Users register Taproot-to-Stacks address mapping via dust transaction with OP_RETURN containing Stacks principal. Bridge mints wrapped Runes when transfers detected to registered addresses. Clarity acts as oracle through native Bitcoin state reading. No oracle other than Clarity for bridge-in. Implements tax-enforced wrapped tokens using code-body verification (from 1 above).

## 3. DEX-Baked Liquid Staking Yield

Integrates staking yield directly at DEX level to eliminate arbitrage opportunities in liquid staking token pools. Removes yield leakage from LPs. Makes providing LP more efficient by baking yield into AMM mechanics.

## 4. Isolated CDPs for Governance Tokens

Collateralized debt positions enabling borrowing against hard-to-borrow assets like DIKO, ALEX, VELAR, and even STX using sBTC as collateral. Isolated risk pools prevent contagion. Staked asset pools determine borrowing capacity. Enables shorting governance tokens versus sBTC. Unlocks capital efficiency for ecosystem tokens with limited borrowing markets.

## 5. Passkey Smart Wallet ("Onboard Your Mom")

Mobile-first smart contract wallet using passkeys for authentication. Enables credit card to Bitcoin purchases with Stacks wallet custody. Requires SIP-256 integration for passkey support on Stacks. Targets non-crypto-native users with familiar UX. Removes seed phrase friction for mainstream adoption. Smart contract governance allows social recovery and enhanced security features.
