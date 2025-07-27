#[cfg(test)]
mod tests {
    use starknet::ContractAddress;
    use starknet::testing::set_caller_address;
    use core::num::traits::Zero;
    
    // Import from the main crate (hello_starknet)
    use hello_starknet::{ERC20, IERC20};

    // Helper function to deploy the contract for testing
    fn deploy_contract() -> (ERC20::ContractState, ContractAddress) {
        let owner = starknet::contract_address_const::<'owner'>();
        let mut contract_state = ERC20::contract_state_for_testing();
        ERC20::constructor(ref contract_state, owner);
        
        (contract_state, owner)
    }

    // Helper addresses for testing
    fn alice() -> ContractAddress { starknet::contract_address_const::<'alice'>() }
    fn bob() -> ContractAddress { starknet::contract_address_const::<'bob'>() }
    fn charlie() -> ContractAddress { starknet::contract_address_const::<'charlie'>() }

    #[test]
    fn test_constructor_sets_initial_values() {
        let (contract, _owner) = deploy_contract();
        
        // Test token metadata
        assert(contract.name() == "CodeJamToken", 'Wrong name');
        assert(contract.symbol() == "CJT", 'Wrong symbol');
        assert(contract.decimals() == 18, 'Wrong decimals');
        assert(contract.totalSupply() == 1000000, 'Wrong total supply');
        
        // Test initial balances are zero
        assert(contract.balanceOf(alice()) == 0, 'Alice should have 0');
        assert(contract.balanceOf(bob()) == 0, 'Bob should have 0');
    }

    #[test]
    fn test_mint_success() {
        let (mut contract, owner) = deploy_contract();
        let alice_addr = alice();
        let mint_amount: u256 = 1000;
        
        // Set caller to owner (only owner can mint)
        set_caller_address(owner);
        
        // Mint tokens to Alice
        let result = contract.mint(alice_addr, mint_amount);
        assert(result == true, 'Mint should succeed');
        
        // Check Alice's balance
        assert(contract.balanceOf(alice_addr) == mint_amount, 'Alice balance wrong');
        
        // Check total supply increased
        assert(contract.totalSupply() == 1000000 + mint_amount, 'Total supply wrong');
    }

    #[test]
    #[should_panic(expected: ('NOT OWNER',))]
    fn test_mint_only_owner() {
        let (mut contract, _owner) = deploy_contract();
        let alice_addr = alice();
        
        // Set caller to Alice (not owner)
        set_caller_address(alice_addr);
        
        // Try to mint - should fail
        contract.mint(alice_addr, 1000);
    }

    #[test]
    #[should_panic(expected: ('INVALID ADDRESS',))]
    fn test_mint_invalid_address() {
        let (mut contract, owner) = deploy_contract();
        
        set_caller_address(owner);
        
        // Try to mint to zero address - should fail
        contract.mint(Zero::zero(), 1000);
    }

    #[test]
    fn test_transfer_success() {
        let (mut contract, owner) = deploy_contract();
        let alice_addr = alice();
        let bob_addr = bob();
        let initial_amount: u256 = 1000;
        let transfer_amount: u256 = 300;
        
        // First, mint some tokens to Alice
        set_caller_address(owner);
        contract.mint(alice_addr, initial_amount);
        
        // Now Alice transfers to Bob
        set_caller_address(alice_addr);
        let result = contract.transfer(bob_addr, transfer_amount);
        assert(result == true, 'Transfer should succeed');
        
        // Check balances
        assert(contract.balanceOf(alice_addr) == initial_amount - transfer_amount, 'Alice balance wrong');
        assert(contract.balanceOf(bob_addr) == transfer_amount, 'Bob balance wrong');
    }

    #[test]
    #[should_panic(expected: ('INSUFFICIENT FUNDS',))]
    fn test_transfer_insufficient_funds() {
        let (mut contract, _owner) = deploy_contract();
        let alice_addr = alice();
        let bob_addr = bob();
        
        // Alice has 0 tokens, tries to send 100
        set_caller_address(alice_addr);
        contract.transfer(bob_addr, 100);
    }

    #[test]
    #[should_panic(expected: ('ADDRESS INVALID',))]
    fn test_transfer_invalid_recipient() {
        let (mut contract, owner) = deploy_contract();
        let alice_addr = alice();
        
        // Mint tokens to Alice first
        set_caller_address(owner);
        contract.mint(alice_addr, 1000);
        
        // Alice tries to send to zero address
        set_caller_address(alice_addr);
        contract.transfer(Zero::zero(), 100);
    }

    #[test]
    fn test_approve_and_allowance() {
        let (mut contract, _owner) = deploy_contract();
        let alice_addr = alice();
        let bob_addr = bob();
        let approve_amount: u256 = 500;
        
        // Alice approves Bob to spend 500 tokens
        set_caller_address(alice_addr);
        let result = contract.approve(bob_addr, approve_amount);
        assert(result == true, 'Approve should succeed');
        
        // Check allowance
        assert(contract.allowance(alice_addr, bob_addr) == approve_amount, 'Allowance wrong');
    }

    #[test]
    #[should_panic(expected: ('INVALID ADDRESS',))]
    fn test_approve_invalid_spender() {
        let (mut contract, _owner) = deploy_contract();
        let alice_addr = alice();
        
        set_caller_address(alice_addr);
        contract.approve(Zero::zero(), 100);
    }

    #[test]
    fn test_transfer_from_success() {
        let (mut contract, owner) = deploy_contract();
        let alice_addr = alice();
        let bob_addr = bob();
        let charlie_addr = charlie();
        let initial_amount: u256 = 1000;
        let approve_amount: u256 = 500;
        let transfer_amount: u256 = 300;
        
        // Setup: Mint tokens to Alice
        set_caller_address(owner);
        contract.mint(alice_addr, initial_amount);
        
        // Alice approves Bob to spend 500 tokens
        set_caller_address(alice_addr);
        contract.approve(bob_addr, approve_amount);
        
        // Bob transfers 300 of Alice's tokens to Charlie
        set_caller_address(bob_addr);
        let result = contract.transferFrom(alice_addr, charlie_addr, transfer_amount);
        assert(result == true, 'TransferFrom should succeed');
        
        // Check balances
        assert(contract.balanceOf(alice_addr) == initial_amount - transfer_amount, 'Alice balance wrong');
        assert(contract.balanceOf(charlie_addr) == transfer_amount, 'Charlie balance wrong');
        
        // Check remaining allowance
        assert(contract.allowance(alice_addr, bob_addr) == approve_amount - transfer_amount, 'Allowance wrong');
    }

    #[test]
    #[should_panic(expected: ('INSUFFICIENT ALLOWANCE',))]
    fn test_transfer_from_insufficient_allowance() {
        let (mut contract, owner) = deploy_contract();
        let alice_addr = alice();
        let bob_addr = bob();
        let charlie_addr = charlie();
        
        // Mint tokens to Alice
        set_caller_address(owner);
        contract.mint(alice_addr, 1000);
        
        // Alice approves Bob for only 100 tokens
        set_caller_address(alice_addr);
        contract.approve(bob_addr, 100);
        
        // Bob tries to transfer 200 tokens (more than allowance)
        set_caller_address(bob_addr);
        contract.transferFrom(alice_addr, charlie_addr, 200);
    }

    #[test]
    #[should_panic(expected: ('INSUFFICIENT FUNDS',))]
    fn test_transfer_from_insufficient_funds() {
        let (mut contract, _owner) = deploy_contract();
        let alice_addr = alice();
        let bob_addr = bob();
        let charlie_addr = charlie();
        
        // Alice has 0 tokens but approves Bob for 1000
        set_caller_address(alice_addr);
        contract.approve(bob_addr, 1000);
        
        // Bob tries to transfer 500 tokens (Alice has 0)
        set_caller_address(bob_addr);
        contract.transferFrom(alice_addr, charlie_addr, 500);
    }

    #[test]
    #[should_panic(expected: ('ADDRESS INVALID',))]
    fn test_transfer_from_invalid_from_address() {
        let (mut contract, _owner) = deploy_contract();
        let bob_addr = bob();
        let charlie_addr = charlie();
        
        set_caller_address(bob_addr);
        contract.transferFrom(Zero::zero(), charlie_addr, 100);
    }

    #[test]
    #[should_panic(expected: ('ADDRESS INVALID',))]
    fn test_transfer_from_invalid_recipient_address() {
        let (mut contract, _owner) = deploy_contract();
        let alice_addr = alice();
        let bob_addr = bob();
        
        set_caller_address(bob_addr);
        contract.transferFrom(alice_addr, Zero::zero(), 100);
    }

    #[test]
    fn test_multiple_operations_integration() {
        let (mut contract, owner) = deploy_contract();
        let alice_addr = alice();
        let bob_addr = bob();
        let charlie_addr = charlie();
        
        // 1. Owner mints 1000 tokens to Alice
        set_caller_address(owner);
        contract.mint(alice_addr, 1000);
        assert(contract.balanceOf(alice_addr) == 1000, 'Alice should have 1000');
        assert(contract.totalSupply() == 1001000, 'Total supply should be 1001000');
        
        // 2. Alice transfers 300 to Bob
        set_caller_address(alice_addr);
        contract.transfer(bob_addr, 300);
        assert(contract.balanceOf(alice_addr) == 700, 'Alice should have 700');
        assert(contract.balanceOf(bob_addr) == 300, 'Bob should have 300');
        
        // 3. Alice approves Charlie for 200 tokens
        contract.approve(charlie_addr, 200);
        assert(contract.allowance(alice_addr, charlie_addr) == 200, 'Allowance should be 200');
        
        // 4. Charlie transfers 150 of Alice's tokens to Bob
        set_caller_address(charlie_addr);
        contract.transferFrom(alice_addr, bob_addr, 150);
        assert(contract.balanceOf(alice_addr) == 550, 'Alice should have 550');
        assert(contract.balanceOf(bob_addr) == 450, 'Bob should have 450');
        assert(contract.allowance(alice_addr, charlie_addr) == 50, 'Allowance should be 50');
        
        // 5. Final balance check
        assert(contract.balanceOf(alice_addr) + contract.balanceOf(bob_addr) + contract.balanceOf(charlie_addr) == 1000, 'Total user balance wrong');
    }

    #[test]
    fn test_approve_overwrite() {
        let (mut contract, _owner) = deploy_contract();
        let alice_addr = alice();
        let bob_addr = bob();
        
        set_caller_address(alice_addr);
        
        // First approval
        contract.approve(bob_addr, 100);
        assert(contract.allowance(alice_addr, bob_addr) == 100, 'First allowance wrong');
        
        // Second approval overwrites the first
        contract.approve(bob_addr, 200);
        assert(contract.allowance(alice_addr, bob_addr) == 200, 'Second allowance wrong');
        
        // Approve zero to revoke
        contract.approve(bob_addr, 0);
        assert(contract.allowance(alice_addr, bob_addr) == 0, 'Revoked allowance wrong');
    }
}