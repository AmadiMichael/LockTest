// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {Bank, ERC20} from "../src/Bank.sol";
import {AccountAccessHelper} from "./AccountAccessHelper.sol";

contract BankTest is Test, AccountAccessHelper {
    Bank public bank;
    Token public token;

    uint256 private constant _BALANCE_SLOT_SEED = 0x87a211a2;
    uint256 private constant _ALLOWANCE_SLOT_SEED = 0x7f5e9f20;

    function setUp() public {
        vm.warp(vm.unixTime() / 100);

        bank = new Bank();
        token = new Token();
    }

    function test_lock_fuzz_deposit(address _msg_sender, address _owner, uint256 _amount) external {
        if (uint256(uint160(_msg_sender)) < 10) _msg_sender = mutateAddress(_msg_sender); // no address(0) or precompile
        if (uint256(uint160(_owner)) < 10) _owner = mutateAddress(_owner); // no address(0) or precompile
        _amount = bound(_amount, 0, 1_000_000_000e18);

        token.mint(_msg_sender, _amount);

        vm.startPrank(_msg_sender);
        token.approve(address(bank), _amount);

        vm.startStateDiffRecording();
        bank.deposit(address(token), _owner, _amount);
        VmSafe.AccountAccess[] memory accountAccesses = vm.stopAndReturnStateDiff();

        /**
         * expected account accesses and state transitions
         *  - first access is this test contract making an extcodesize call on the value since it's wrapped in an interface/contract type
         *  - second access should be our pranked address making the call to the bank to make the deposit
         *  - third access should be the bank contract checking the extcodesize of the token we parsed in
         *  - fourth access should be execution resuming back to the call of pranked address to the bank contract
         *      - this does some storage read and writes and as follows
         *          - first should be to read the balance of the slot, since we are incrementing and not overwriting we need to read first before writing
         *          - second we write to the same slot. We write the balance + amount
         *          - TIP: slot for balance is calculated as keccak256(token, keccak256(owner, slot))
         *  - fifth access should be a call to the token contract (we are using solady, we checked initially if the token had code deployed to it in access 2 above because solady safeTransferLib does not check for this)
         *      - this does some storage read and writes and as follows (in deployment this would vary based on the token's storage layout but since we use a pre-known test token we can assert the transfer took place here)
         *          - first should be to read and write (decrement) the allowance slot for owner -> pranked address
         *          - second should be to read and write (decrement) the balance slot of owner
         *          - third should be to read and write (increment) the balance slot of pranked address
         */
        VmSafe.AccountAccess[] memory expected = new VmSafe.AccountAccess[](5); // we expect 5 account accesses as explained above

        // - first access is this test contract making an extcodesize call on the value since it's wrapped in an interface/contract type
        expected[0] = VmSafe.AccountAccess({
            chainInfo: VmSafe.ChainInfo({forkId: 0, chainId: 31337}), // expected to be on testnet
            kind: VmSafe.AccountAccessKind.Extcodesize, // expected to be an extcodesize check on bank address since it's wrapped in an interface/contract type
            account: address(bank), // access bank's extcodesize,
            accessor: address(this), // address(this)/test contract is the one that checks for extcodesize
            initialized: true, // because bank contract already had code before being called
            oldBalance: 0, // no balance prior
            newBalance: 0, // no balance after
            deployedCode: new bytes(0), // no code deployed in this access
            value: 0, // no value sent with tx,
            data: new bytes(0), // no data sent, this is an extcodesize access kind
            reverted: false, // access was not reverted
            storageAccesses: new VmSafe.StorageAccess[](0) // no storage reads or writes
        });

        // - second access should be our pranked address making the call to the bank to make the deposit
        expected[1] = VmSafe.AccountAccess({
            chainInfo: VmSafe.ChainInfo({forkId: 0, chainId: 31337}), // expected to be on testnet
            kind: VmSafe.AccountAccessKind.Call, // expected to be a call
            account: address(bank), // calling bank contract,
            accessor: _msg_sender, // pranked address is the one that calls bank contract
            initialized: true, // because bank contract already had code before being called
            oldBalance: 0, // no balance prior
            newBalance: 0, // no balance after
            deployedCode: new bytes(0), // no code deployed in this access
            value: 0, // no value sent with tx,
            data: abi.encodeWithSelector(Bank.deposit.selector, address(token), _owner, _amount), // abi encoded calldata sent with tx
            reverted: false, // access was not reverted
            storageAccesses: new VmSafe.StorageAccess[](0) // no storage reads or writes (yet)
        });

        // - third access should be the bank contract checking the extcodesize of the token we parsed in
        expected[2] = VmSafe.AccountAccess({
            chainInfo: VmSafe.ChainInfo({forkId: 0, chainId: 31337}), // expected to be on testnet
            kind: VmSafe.AccountAccessKind.Extcodesize, // expected to be an extcodesize check on token address, the bank contract does this in it's impl
            account: address(token), // access token's extcodesize,
            accessor: address(bank), // bank address is the one that checks for extcodesize
            initialized: true, // because token contract already had code before being called
            oldBalance: 0, // no balance prior
            newBalance: 0, // no balance after
            deployedCode: new bytes(0), // no code deployed in this access
            value: 0, // no value sent with tx,
            data: new bytes(0), // no data sent, this is an extcodesize access kind
            reverted: false, // access was not reverted
            storageAccesses: new VmSafe.StorageAccess[](0) // no storage reads or writes
        });

        /**
         *  - fourth access should be execution resuming back to the call of pranked address to the bank contract
         *      - this does some storage read and writes and as follows
         *          - first should be to read the balance of the slot, since we are incrementing and not overwriting we need to read first before writing
         *          - second we write to the same slot. We write the balance + amount
         *          - TIP: slot for balance is calculated as keccak256(token, keccak256(owner, slot))
         */
        expected[3] = VmSafe.AccountAccess({
            chainInfo: VmSafe.ChainInfo({forkId: 0, chainId: 31337}), // expected to be on testnet
            kind: VmSafe.AccountAccessKind.Resume, // expected to be a Resumumption of the execution before the last access (extcodesize)
            account: expected[1].account, // same as index 1
            accessor: expected[1].accessor, // same as index 1
            initialized: expected[1].initialized, // same as index 1
            oldBalance: expected[1].oldBalance, // same as index 1
            newBalance: expected[1].newBalance, // same as index 1
            deployedCode: expected[1].deployedCode, // same as index 1
            value: expected[1].value, // same as index 1
            data: expected[1].data, // same as index 1
            reverted: false, // access was not reverted
            storageAccesses: new VmSafe.StorageAccess[](2) // here we expect 2 storage read and write to occur
        });
        bytes32 ownersBankBalanceStorageSlot =
            getMappingSlot(bytes32(uint256(uint160(_owner))), bytes32(uint256(uint160(address(token)))), bytes32(0));
        expected[3].storageAccesses[0] = VmSafe.StorageAccess({
            account: expected[3].account, // same as index 3
            slot: ownersBankBalanceStorageSlot, // first storage access is a read to the owners bank balance storage slot
            isWrite: false, // we read first not write
            previousValue: bytes32(0), // no balance intially
            newValue: bytes32(0), // still no balance since this was a read not write
            reverted: false // was not reverted
        });
        expected[3].storageAccesses[1] = VmSafe.StorageAccess({
            account: expected[3].account, // same as index 3
            slot: ownersBankBalanceStorageSlot, // first storage access is a read to the owners bank balance storage slot
            isWrite: true, // we read first not write
            previousValue: bytes32(0), // no balance intially
            newValue: bytes32(_amount), // should increase by `_amount`,
            reverted: false // was not reverted
        });

        /**
         * - fifth access should be a call to the token contract (we are using solady, we checked initially if the token had code deployed to it in access 2 above because solady safeTransferLib does not check for this)
         *      - this does some storage read and writes and as follows (in deployment this would vary based on the token's storage layout but since we use a pre-known test token we can assert the transfer took place here)
         *          - first should be to read and write (decrement) the allowance slot for owner -> pranked address
         *          - second should be to read and write (decrement) the balance slot of owner
         *          - third should be to read and write (increment) the balance slot of pranked address
         */
        expected[4] = VmSafe.AccountAccess({
            chainInfo: VmSafe.ChainInfo({forkId: 0, chainId: 31337}), // expected to be on testnet
            kind: VmSafe.AccountAccessKind.Call, // expected a call
            account: address(token), // call token contract
            accessor: address(bank), // bank contract called token
            initialized: true, // because the token contract already had code
            oldBalance: 0, // no balance prior
            newBalance: 0, // no balance after
            deployedCode: new bytes(0), // no code deployed in this access
            value: 0, // no value sent with tx,
            data: abi.encodeWithSelector(ERC20.transferFrom.selector, _msg_sender, address(bank), _amount), // abi encoded calldata sent with tx
            reverted: false, // access was not reverted
            storageAccesses: new VmSafe.StorageAccess[](6) // here we expect 6 storage read and write to occur
        });
        bytes32 msgSendersAllowanceToBankStorageSlot = getSoladyAddressAllowanceMappingSlot(_msg_sender, address(bank));
        bytes32 msgSendersBalanceOfStorageSlot = getSoladyAddressBalanceMappingSlot(_msg_sender);
        bytes32 banksBalanceOfStorageSlot = getSoladyAddressBalanceMappingSlot(address(bank));
        expected[4].storageAccesses[0] = VmSafe.StorageAccess({
            account: expected[4].account, // same as index 4
            slot: msgSendersAllowanceToBankStorageSlot, // first storage access is a read to the `msg sender's allowance to bank`'s slot
            isWrite: false, // we read first not write
            previousValue: bytes32(_amount), // allowance is _amount initialy since this is what we approved in the start of this test function
            newValue: bytes32(_amount), // still no balance changes since this was a read not write
            reverted: false // was not reverted
        });
        expected[4].storageAccesses[1] = VmSafe.StorageAccess({
            account: expected[4].account, // same as index 4
            slot: msgSendersAllowanceToBankStorageSlot, // second storage access is a write to decrement the `msg sender's allowance to bank`'s slot by the amount to be transfered
            isWrite: true, // we write
            previousValue: bytes32(_amount), // allowance is _amount initialy since this is what we approved in the start of this test function
            newValue: bytes32(0), // set allowance to 0 since we transfer all allowed amount
            reverted: false // was not reverted
        });
        expected[4].storageAccesses[2] = VmSafe.StorageAccess({
            account: expected[4].account, // same as index 4
            slot: msgSendersBalanceOfStorageSlot, // third storage access is a read to the `msg sender's balance slot
            isWrite: false, // we read first not write
            previousValue: bytes32(_amount), // allowance is _amount initialy since this is what we minted in the start of this test function
            newValue: bytes32(_amount), // still no balance changes sunce this was a read not write
            reverted: false // was not reverted
        });
        expected[4].storageAccesses[3] = VmSafe.StorageAccess({
            account: expected[4].account, // same as index 4
            slot: msgSendersBalanceOfStorageSlot, // fourth storage access is a write to decrement the `msg sender's balance by amount transferred
            isWrite: true, // we write
            previousValue: bytes32(_amount), // balance is _amount initialy since this is what was minted in the start of this test function
            newValue: bytes32(0), // set to 0 since we transfer everything
            reverted: false // was not reverted
        });
        expected[4].storageAccesses[4] = VmSafe.StorageAccess({
            account: expected[4].account, // same as index 4
            slot: banksBalanceOfStorageSlot, // fifth storage access is a read to the bank's balance slot
            isWrite: false, // we read first not write
            previousValue: bytes32(0), // no balance intially
            newValue: bytes32(0), // still no balance since this was a read not write
            reverted: false // was not reverted
        });
        expected[4].storageAccesses[5] = VmSafe.StorageAccess({
            account: expected[4].account, // same as index 4
            slot: banksBalanceOfStorageSlot, // sixth storage access is a read to the bank's balance slot
            isWrite: true, // we write
            previousValue: bytes32(0), // no balance intially
            newValue: bytes32(_amount), // balance increases by _amount
            reverted: false // was not reverted
        });

        assertEq(accountAccesses, expected);
    }

    function mutateAddress(address addr) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(addr)))));
    }

    function getSoladyAddressBalanceMappingSlot(address addr) internal pure returns (bytes32 x) {
        assembly {
            mstore(0x0c, _BALANCE_SLOT_SEED)
            mstore(0x00, addr)
            x := keccak256(0x0c, 0x20)
        }
    }

    function getSoladyAddressAllowanceMappingSlot(address addr, address addr2) internal pure returns (bytes32 x) {
        assembly {
            mstore(0x20, addr2)
            mstore(0x0c, _ALLOWANCE_SLOT_SEED)
            mstore(0x00, addr)
            x := keccak256(0x0c, 0x34)
        }
    }
}

contract Token is ERC20 {
    constructor() ERC20() {}

    /// @dev Returns the name of the token.
    function name() public pure override returns (string memory) {
        return "Token";
    }

    /// @dev Returns the symbol of the token.
    function symbol() public pure override returns (string memory) {
        return "TKN";
    }

    function mint(address to, uint256 amount) external virtual {
        _mint(to, amount);
    }
}
