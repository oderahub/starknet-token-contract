#[starknet::contract]
mod ERC20Token {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::contract_address_const;
    use core::num::traits::Zero;

    #[storage]
    struct Storage {
        name: felt252,
        symbol: felt252,
        decimals: u8,
        total_supply: u256,
        balances: LegacyMap::<ContractAddress, u256>,
        allowances: LegacyMap::<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Copy, Drop, starknet::Event, PartialEq)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
    }

    #[derive(Copy, Drop, starknet::Event, PartialEq)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        value: u256,
    }

    #[derive(Copy, Drop, starknet::Event, PartialEq)]
    struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        spender: ContractAddress,
        value: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        decimals: u8,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(decimals);
        self.total_supply.write(initial_supply);
        self.balances.write(recipient, initial_supply);

        self.emit(Transfer {
            from: contract_address_const::<0>(),
            to: recipient,
            value: initial_supply
        });
    }

    #[abi(embed_v0)]
    impl ERC20Impl of IERC20<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        fn symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self._transfer(caller, to, amount);
            true
        }

        fn transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            let current_allowance = self.allowances.read((from, caller));
            
            assert(current_allowance >= amount, 'ERC20: insufficient allowance');
            
            self._approve(from, caller, current_allowance - amount);
            self._transfer(from, to, amount);
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, amount);
            true
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _transfer(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) {
            assert(!from.is_zero(), 'ERC20: transfer from 0');
            assert(!to.is_zero(), 'ERC20: transfer to 0');
            
            let from_balance = self.balances.read(from);
            assert(from_balance >= amount, 'ERC20: insufficient balance');
            
            self.balances.write(from, from_balance - amount);
            let to_balance = self.balances.read(to);
            self.balances.write(to, to_balance + amount);

            self.emit(Transfer { from, to, value: amount });
        }

        fn _approve(
            ref self: ContractState,
            owner: ContractAddress,
            spender: ContractAddress,
            amount: u256
        ) {
            assert(!owner.is_zero(), 'ERC20: approve from 0');
            assert(!spender.is_zero(), 'ERC20: approve to 0');
            
            self.allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }

        fn _mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            assert(!to.is_zero(), 'ERC20: mint to 0');
            
            let supply = self.total_supply.read();
            self.total_supply.write(supply + amount);
            
            let balance = self.balances.read(to);
            self.balances.write(to, balance + amount);

            self.emit(Transfer {
                from: contract_address_const::<0>(),
                to,
                value: amount
            });
        }

        fn _burn(ref self: ContractState, from: ContractAddress, amount: u256) {
            assert(!from.is_zero(), 'ERC20: burn from 0');
            
            let balance = self.balances.read(from);
            assert(balance >= amount, 'ERC20: insufficient balance');
            
            self.balances.write(from, balance - amount);
            let supply = self.total_supply.read();
            self.total_supply.write(supply - amount);

            self.emit(Transfer {
                from,
                to: contract_address_const::<0>(),
                value: amount
            });
        }
    }

    #[starknet::interface]
    trait IERC20<TContractState> {
        fn name(self: @TContractState) -> felt252;
        fn symbol(self: @TContractState) -> felt252;
        fn decimals(self: @TContractState) -> u8;
        fn total_supply(self: @TContractState) -> u256;
        fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
        fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
        fn transfer(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
        fn transfer_from(ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256) -> bool;
        fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    }
}