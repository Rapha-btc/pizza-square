# Trustless Runes Bridge to Stacks: Grant Proposal

## Problem

Runes assets on Bitcoin cannot move to Stacks without trusted intermediaries. Current bridge designs rely on multisigs or centralized oracles to verify Runes balances and execute transfers. This introduces counterparty risk and contradicts Bitcoin's trustless ethos.

## Solution

We propose building a one-way trustless Runes bridge using Clarity's native Bitcoin state reading capabilities. The bridge requires no oracles because Clarity reads Bitcoin transactions directly. Users complete a one-time address registration by sending a dust Bitcoin transaction with their Stacks address in OP_RETURN. The contract then monitors Bitcoin for Runes transfers and mints wrapped tokens automatically when Runes are sent to registered Taproot addresses.

## Technical Architecture

The address registration system establishes permanent linkage between Stacks and Taproot addresses through on-chain verification. Users send a dust transaction from their Taproot address with OP_RETURN containing their Stacks principal encoded using consensus buffer format. The Clarity contract uses the clarity-bitcoin-lib-v7 library to verify the transaction was mined via `was-tx-mined-compact` or `was-segwit-tx-mined-compact`. The contract parses the transaction using `parse-tx` or `parse-wtx` to extract outputs. The payload parsing functions `parse-payload-legacy` and `parse-payload-segwit` decode the OP_RETURN data by slicing the scriptPubKey and deserializing with `from-consensus-buff?`. The contract extracts the Taproot address from transaction inputs and stores the mapping in a Clarity map linking Taproot address to Stacks principal. This registration can only occur once per Taproot address and is immutable once set.

The Runes protocol parser implementation reads OP_RETURN data from Bitcoin Runes transfer transactions. Runes transactions encode transfer data in OP_RETURN outputs using varint encoding in LEB128 format. The parser extracts the Rune protocol identifier, decodes the edicts containing Rune ID and transfer amounts, and identifies which output indices receive which amounts. We implement complete varint decoding in Clarity to parse the compact binary format used by Runes. The parser validates protocol structure and extracts all necessary transfer information without external dependencies.

The bridge monitoring mechanism combines address mapping with Runes parsing. When a Runes transfer occurs on Bitcoin where the recipient output corresponds to a registered Taproot address in the address map, the contract detects this through Bitcoin state reading. The contract parses the OP_RETURN to determine transfer amount and Rune identifier. Using the address map, the contract identifies the corresponding Stacks principal. The contract mints equivalent wrapped Runes tokens on Stacks to the mapped Stacks address. All verification happens on-chain through Clarity's Bitcoin reading capabilities with zero trust assumptions.

The wrapped token system implements SIP-010 fungible token standard for each Rune type. Each unique Rune gets a corresponding wrapped token contract deployed on Stacks. The bridge contract acts as minter for wrapped tokens based on verified Bitcoin transfers. The tokens integrate with existing Stacks DeFi infrastructure including DEXes and lending protocols. Code-body verification using `contract-hash?` ensures protocol compliance and enables template-based integrations while maintaining decentralization.

## Bridge Out Limitation

The bridge supports only trustless one-way transfers from Bitcoin to Stacks. Bridging wrapped Runes back to native Bitcoin Runes requires a multisig or federation to control Bitcoin UTXOs and execute Runes protocol transfers. This asymmetry is unavoidable because writing to Bitcoin requires controlling private keys for UTXOs. We prioritize the trustless bridge-in direction as it represents the primary value flow and eliminates custody risk for users moving assets into Stacks DeFi.

## Reference Implementation

Our architecture follows proven patterns from existing Stacks Bitcoin bridges. The codebase demonstrates parsing Bitcoin transaction payloads using `parse-payload-segwit` and `parse-payload-legacy` functions that extract OP_RETURN data and decode it using `from-consensus-buff?`. The transaction verification flow uses clarity-bitcoin-lib-v7 to confirm transactions were mined on Bitcoin. The pattern of storing transaction data in maps and preventing replay attacks through `processed-btc-txs` tracking applies directly to Runes bridge implementation. The cooldown periods and operator patterns provide security models we adapt for Runes-specific requirements.

## Deliverables

Production-ready Clarity smart contract implementing one-time Taproot to Stacks address registration with consensus buffer encoding. Complete Runes protocol parser in Clarity supporting varint LEB128 decoding and full edict interpretation. Bridge monitoring contract that reads Bitcoin Runes transactions via clarity-bitcoin-lib-v7 and mints wrapped tokens to registered addresses. SIP-010 compliant wrapped token contracts for each Rune type with code-body verification for DEX compatibility. Open-source frontend enabling users to register address mapping and monitor bridge transfers with Leather and Xverse integration. Comprehensive documentation covering registration process, security model, parser implementation, and DeFi integration patterns. Testnet deployment with security audit from recognized Clarity auditing firm focusing on Bitcoin transaction parsing and replay attack prevention.

## Why This Matters

This bridge eliminates trusted third parties from Runes-to-Stacks transfers by making Clarity the verification layer through direct Bitcoin state reading. The address registration requires only a single dust transaction with no signatures or complex proofs. The Runes parser reads protocol data directly from Bitcoin OP_RETURN outputs without indexer dependencies. Success unlocks Runes liquidity for Stacks DeFi with zero custody risk or trust assumptions for inbound transfers. The architecture establishes a reusable pattern for other Bitcoin protocols seeking trustless Stacks integration. The proven Bitcoin transaction parsing patterns from existing Stacks bridges demonstrate technical feasibility and reduce implementation risk.

## Team

[Your team credentials including experience with Clarity smart contract development, Bitcoin transaction parsing, Runes protocol specification, bridge architecture, and security auditing]

## Budget

[Itemized budget covering Runes varint parser development, address registration system implementation, bridge monitoring contract, wrapped token deployment, clarity-bitcoin-lib-v7 integration, security audit, frontend development, and comprehensive documentation]

## Timeline

[Phase-based delivery schedule with milestones for parser implementation including varint decoder, address registration system with consensus buffer encoding, bridge monitoring integration with clarity-bitcoin-lib-v7, wrapped token deployment, security audit, testnet launch, and mainnet deployment]
