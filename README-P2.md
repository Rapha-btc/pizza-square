# Trustless Runes Bridge to Stacks: Grant Proposal

## Problem

Runes assets on Bitcoin cannot move to Stacks without trusted intermediaries. Current bridge designs rely on multisigs or centralized oracles to verify Runes balances and execute transfers. This introduces counterparty risk and contradicts Bitcoin's trustless ethos.

## Solution

We propose building a one-way trustless Runes bridge using Clarity's native Bitcoin state reading capabilities. The bridge requires no oracles because Clarity reads Bitcoin transactions directly. Users complete a one-time address registration by sending a dust Bitcoin transaction with their Stacks address in OP_RETURN. The contract then monitors Bitcoin for Runes transfers and mints wrapped tokens automatically when Runes are sent to registered Taproot addresses.

## Technical Architecture

The address registration system establishes permanent linkage between Stacks and Taproot addresses through on-chain verification. Users send a dust transaction from their Taproot address with OP_RETURN containing their Stacks principal encoded using consensus buffer format. The Clarity contract uses the clarity-bitcoin-lib-v7 library to verify the transaction was mined via `was-tx-mined-compact` or `was-segwit-tx-mined-compact`. The contract parses the transaction using `parse-tx` or `parse-wtx` to extract outputs. The payload parsing functions `parse-payload-legacy` and `parse-payload-segwit` decode the OP_RETURN data by slicing the scriptPubKey and deserializing with `from-consensus-buff?`. The contract extracts the Taproot address from transaction inputs and stores the mapping in a Clarity map linking Taproot address to Stacks principal. This registration can only occur once per Taproot address and is immutable once set.

The Runes protocol parser implementation reads OP_RETURN data from Bitcoin Runes transfer transactions. Runes transactions encode transfer data in OP_RETURN outputs using varint encoding in LEB128 format. The parser extracts the Rune protocol identifier, decodes the edicts containing Rune ID and transfer amounts, and identifies which output indices receive which amounts. We implement complete varint decoding in Clarity to parse the compact binary format used by Runes. The parser validates protocol structure and extracts all necessary transfer information without external dependencies.

The bridge monitoring mechanism combines address mapping with Runes parsing. When a Runes transfer occurs on Bitcoin where the recipient output corresponds to a registered Taproot address in the address map, the contract detects this through Bitcoin state reading. The contract parses the OP_RETURN to determine transfer amount and Rune identifier. Using the address map, the contract identifies the corresponding Stacks principal. The contract mints equivalent wrapped Runes tokens on Stacks to the mapped Stacks address. All verification happens on-chain through Clarity's Bitcoin reading capabilities with zero trust assumptions.

The wrapped token system implements SIP-010 fungible token standard with protocol fee enforcement through code-body verification. Each unique Rune gets a corresponding wrapped token contract deployed on Stacks. The token contracts use `contract-hash?` to verify the calling contract matches approved templates for DEX integrations. Only DEXes that implement the required fee-paying mechanism in their contract code can interact with the wrapped Runes tokens. This enforces a protocol tax at the token level while maintaining complete decentralization since the enforcement is purely code-based rather than relying on operator permissions. DEXes must include the tax payment logic in their contract bodies to pass the hash verification. This creates sustainable revenue for token community without introducing centralized gatekeepers. The pattern allows new DEX templates to be added through governance while preserving the trustless nature of the tokens.

## Bridge Out Limitation

The bridge supports only trustless one-way transfers from Bitcoin to Stacks. Bridging wrapped Runes back to native Bitcoin Runes requires a multisig or federation to control Bitcoin UTXOs and execute Runes protocol transfers. This asymmetry is unavoidable because writing to Bitcoin requires controlling private keys for UTXOs. We prioritize the trustless bridge-in direction as it represents the primary value flow and eliminates custody risk for users moving assets into Stacks DeFi.

## Reference Implementation

Our architecture follows proven patterns from existing Stacks Bitcoin bridges. The codebase demonstrates parsing Bitcoin transaction payloads using `parse-payload-segwit` and `parse-payload-legacy` functions that extract OP_RETURN data and decode it using `from-consensus-buff?`. The transaction verification flow uses clarity-bitcoin-lib-v7 to confirm transactions were mined on Bitcoin. The pattern of storing transaction data in maps and preventing replay attacks through `processed-btc-txs` tracking applies directly to Runes bridge implementation. The allowlist proposal system with multi-signature approval demonstrates how to manage DEX integrations while maintaining decentralization. The code-body verification pattern using `contract-hash?` to validate calling contracts provides the foundation for tax-enforcing wrapped tokens.

## Why This Matters

This bridge eliminates trusted third parties from Runes-to-Stacks transfers by making Clarity the verification layer through direct Bitcoin state reading. The address registration requires only a single dust transaction with no signatures or complex proofs. The Runes parser reads protocol data directly from Bitcoin OP_RETURN outputs without indexer dependencies. The code-body verification system enforces token community and protocol sustainability through decentralized tax collection without relying on centralized operators or permissions. Success unlocks Runes liquidity for Stacks DeFi with zero custody risk or trust assumptions for inbound transfers while creating sustainable revenue for bridge maintenance and liquidity provision. The architecture establishes a reusable pattern for other Bitcoin protocols seeking trustless Stacks integration with built-in economic sustainability.

## Team

Lead developer @raphastacks with proven track record building production Stacks infrastructure including fak.fun meme token launchpad and faktory.fun AI DAO launchpad. Notable achievements include launching B Blocks token that reached $100k volume and topped Alex trading charts. Expert Clarity consultant engaged contingent on feasibility assessment of Runes OP_RETURN parsing in Clarity confirming technical viability of varint decoding implementation.

## Budget

Total grant amount is $75,000 USD with 50% paid upfront. Budget covers three core technical components: Runes OP_RETURN parser development implementing varint LEB128 decoding in Clarity, Taproot to Stacks address mapping system using consensus buffer encoding and clarity-bitcoin-lib-v7 integration, and SIP-010 wrapped token contracts with code-body tax enforcement using `contract-hash?` verification. Additional budget allocation covers security audit from recognized Clarity auditing firm, frontend development for address registration and bridge monitoring interface with Leather and Xverse wallet integration, and comprehensive technical documentation.

## Timeline

Total delivery timeline is 12 weeks maximum. Milestone 1 covers weeks 1-4 with deliverables including feasibility confirmation of Runes OP_RETURN parsing, complete varint decoder implementation in Clarity, address registration system with Bitcoin transaction verification, and core bridge monitoring contract. Milestone 2 covers weeks 5-8 with deliverables including wrapped token deployment with code-body tax enforcement, DEX template system with `contract-hash?` verification, security audit completion, mainnet deployment and simulated testing, frontend interface launch, and comprehensive documentation. Each milestone includes working demonstrations on mainnet before proceeding to next phase.

## Grant Impact

This grant captures Runes liquidity for Stacks DeFi by providing the first trustless bridge solution. With existing Runes trading volume demonstrating clear demand and no current trustless bridge options available, this infrastructure fills a critical gap. The code-body tax enforcement creates sustainable economics without centralized control. The pattern established enables future Bitcoin protocol integrations using the same trustless verification approach. Success metrics include number of unique Runes bridged, total value locked in wrapped tokens, and DEX integration adoption rates.

## Grant Risks

Primary risk involves technical feasibility of parsing Runes OP_RETURN data in Clarity given varint encoding complexity. We mitigate this through expert consultation and proof-of-concept validation in Milestone 1 before proceeding. Secondary risk involves bridge security vulnerabilities addressed through comprehensive audit and simulated validation period. The one-way bridge design eliminates custody risks for inbound transfers while acknowledging limitations for bridge-out functionality requiring multisig solutions.
