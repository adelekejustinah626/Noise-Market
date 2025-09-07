📖 README – Noise-Market

Overview

Noise-Market is a decentralized marketplace for trading random on-chain data streams.
Users can:

Create and manage noise streams (random data generators)

Deposit and withdraw STX for trading

Place buy and sell orders for noise streams

Fulfill or cancel existing orders

Generate reproducible noise data hashes on-chain

This smart contract is written in Clarity and is designed for experimentation with novel data-based market mechanisms.

✨ Features

Deposit & Withdraw STX: Manage balances directly in the contract.

Noise Stream Creation: Generate random on-chain data using keccak256 from block-height and tx-sender.

Order System:

Create buy and sell orders with expiration.

Fulfill orders to exchange STX for data rights.

Cancel orders and reclaim locked funds.

Data Access: Retrieve metadata and noise hashes for streams.

Read-only Utilities: Get balances, active orders, and generate pseudo-random noise data from seeds.

🔐 Error Codes

ERR-NOT-AUTHORIZED (u100) – Unauthorized action

ERR-INSUFFICIENT-BALANCE (u101) – Insufficient funds

ERR-INVALID-AMOUNT (u102) – Amount must be > 0

ERR-STREAM-NOT-FOUND (u103) – Noise stream does not exist

ERR-ORDER-NOT-FOUND (u104) – Order does not exist

ERR-ORDER-EXPIRED (u105) – Order is past expiration

📜 Key Functions
Public Functions

deposit (amount uint) → Add STX to user balance

withdraw (amount uint) → Withdraw STX

create-noise-stream (name price) → Create a new stream with on-chain noise

create-buy-order (stream-id amount price expires-in) → Place buy order

create-sell-order (stream-id amount price expires-in) → Place sell order

fulfill-buy-order (order-id) → Fulfill buy order as seller

fulfill-sell-order (order-id) → Fulfill sell order as buyer

cancel-buy-order (order-id) → Cancel buy order

cancel-sell-order (order-id) → Cancel sell order

Read-only Functions

get-noise-stream (stream-id) → Retrieve stream metadata

get-user-balance (user) → Check balance

get-buy-order (order-id) → Fetch buy order

get-sell-order (order-id) → Fetch sell order

get-next-stream-id → Next stream ID

get-next-order-id → Next order ID

generate-noise-data (seed) → Deterministically generate noise

🚀 Example Flow

User deposits STX with deposit.

User creates a noise stream with create-noise-stream.

Other users place buy or sell orders linked to that stream.

Orders are fulfilled or canceled, transferring STX accordingly.

📌 Notes

This is an experimental market concept, useful for research or gamified applications.

Noise streams are not guaranteed to be cryptographically secure randomness, but they serve as verifiable pseudo-randomness derived from chain data.