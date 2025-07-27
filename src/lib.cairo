
use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20<TContractState>{
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn decimals(self: @TContractState) -> u8;

    fn balanceOf(self: @TContractState, address: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn totalSupply(self: @TContractState) -> u256;

    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transferFrom(ref self: TContractState, from: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;

    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
}

#[derive(Drop, starknet::Event)]
pub struct Approval {
    #[key]
    owner: ContractAddress,
    #[key]
    spender: ContractAddress,
    amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct Transfer {
    #[key]
    from: ContractAddress,
    #[key]
    recipient: ContractAddress,
    amount: u256,
}

#[starknet::contract]
mod ERC20 {

    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, 
                            StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use super::{Approval, Transfer, IERC20};
    use core::num::traits::Zero;

    #[storage]
    pub struct Storage {
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
        total_supply: u256,

        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,

        owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Approval: Approval,
        Transfer: Transfer
    }

    #[constructor]
    fn constructor(ref self: ContractState, _owner: ContractAddress) {
        self.name.write("CodeJamToken");
        self.symbol.write("CJT");
        self.decimals.write(18);

        self.total_supply.write(1000000);
        self.owner.write(_owner);
    }

    #[abi(embed_v0)]
    impl ERC20Impl of IERC20<ContractState> {

        fn name(self: @ContractState) -> ByteArray {
            self.name.read()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn balanceOf(self: @ContractState, address: ContractAddress) -> u256 {
            self.balances.read(address)
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn totalSupply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            assert!(!recipient.is_zero(), "ADDRESS INVALID");
            
            let _balance = self.balances.read(get_caller_address());
            assert!(_balance >= amount, "INSUFFICIENT FUNDS");
            let _new_balance = _balance - amount;
            self.balances.write(get_caller_address(), _new_balance);
            let _recipient_balance = self.balances.read(recipient);
            self.balances.write(recipient, _recipient_balance + amount);

            self.emit(Transfer {from: get_caller_address(), recipient, amount});
            true
        }

        fn transferFrom(ref self: ContractState, from: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
            assert!(!from.is_zero(), "ADDRESS INVALID");
            assert!(!recipient.is_zero(), "ADDRESS INVALID");

            let _allowance = self.allowances.read((from, get_caller_address()));
            assert!(_allowance >= amount, "INSUFFICIENT ALLOWANCE");

            let _balance = self.balances.read(from);
            assert!(_balance >= amount, "INSUFFICIENT FUNDS");

            self.allowances.write((from, get_caller_address()), _allowance - amount);

            let _new_balance = _balance - amount;
            self.balances.write(from, _new_balance);

            let _recipient_balance = self.balances.read(recipient);
            self.balances.write(recipient, _recipient_balance + amount);

            self.emit(Transfer {from, recipient, amount});
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            assert!(!spender.is_zero(), "INVALID ADDRESS");

            self.allowances.write((get_caller_address(), spender), amount);

            self.emit(Approval {owner: get_caller_address(), spender, amount});
            true
        }

        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            assert!(!recipient.is_zero(), "INVALID ADDRESS");
            assert!(get_caller_address() == self.owner.read(), "NOT OWNER");
            
            let _balance = self.balances.read(recipient);
            self.balances.write(recipient, _balance + amount); 

            let _total_supply = self.total_supply.read();
            self.total_supply.write(_total_supply + amount);

            self.emit(Transfer {from: get_caller_address(), recipient, amount});
            true
        }
    }
}