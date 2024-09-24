# Royalty Distribution Smart Contract

This Clarity smart contract manages the distribution of royalties to multiple recipients based on predefined percentages. It's designed to run on the Stacks blockchain.

## Features

- Set royalty percentages for recipients
- Distribute royalties to individual recipients
- Track total distributed amount
- Query contract state (recipient percentages, total distributed, etc.)

## Functions

### Public Functions

1. `set-royalty-percentage`
   - Sets the royalty percentage for a recipient
   - Parameters: 
     - `recipient`: `principal`
     - `percentage`: `uint`
   - Only the contract owner can call this function

2. `distribute-to-recipient`
   - Distributes royalties to a single recipient
   - Parameters:
     - `recipient-index`: `uint`
     - `amount`: `uint`
   - Returns the amount transferred or an error

### Read-Only Functions

1. `get-royalty-percentage`
   - Gets the royalty percentage for a recipient
   - Parameter: `recipient`: `principal`

2. `get-total-distributed`
   - Gets the total amount distributed so far

3. `get-num-recipients`
   - Gets the number of recipients

4. `get-recipient-by-index`
   - Gets a recipient by their index
   - Parameter: `index`: `uint`

## Error Codes

- `err-owner-only (u100)`: Only the contract owner can perform this action
- err-owner-only (u100): Only the contract owner can perform this action
- err-invalid-percentage (u101): The percentage must be between 0 and 100
- err-no-recipients (u102): There are no recipients set
- err-invalid-recipient (u103): The recipient index is invalid
- err-transfer-failed (u104): The STX transfer failed
- err-distribution-failed (u105): The batch distribution failed
- err-invalid-interval (u106): The interval must be a positive value

## Usage

1. Deploy the contract to the Stacks blockchain.
2. As the contract owner, use set-royalty-percentage to set percentages for each recipient.
3. To remove a recipient, call remove-recipient.
4. To distribute royalties, call distribute-to-recipient for individual recipients or batch-distribute-royalties for all recipients with the total amount to be distributed.
5. Use the read-only functions to query the contract's state at any time.
6. To set automated recurring distributions, use set-distribution-interval with the desired interval.

## Example

```clarity
;; Set royalty percentage
(contract-call? .royalty-distribution set-royalty-percentage 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 30)

;; Distribute royalties
(contract-call? .royalty-distribution distribute-to-recipient u0 u1000000)
```

In this example, we set a 30% royalty for a recipient and then distribute 1,000,000 microSTX (1 STX) according to the set percentages.

## Notes

- All percentages and amounts are in micro-units (e.g., micro-percentages, microSTX).
- The contract uses block height to track distributions, so multiple distributions in the same block will overwrite each other in the `total-distributed` map.

## Security Considerations

- Only the contract owner can set royalty percentages.
- The contract uses `as-contract` when transferring STX to ensure it's using its own balance.
- Input validation is performed to prevent invalid percentages or recipient indices.

## Author

Blessing Eze