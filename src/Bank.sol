// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "lib/solady/src/tokens/ERC20.sol";
import {SafeTransferLib} from "lib/solady/src/utils/SafeTransferLib.sol";

contract Bank {
    using SafeTransferLib for address;

    error NotAContract();
    error InsufficientBalance();

    event Deposited(address indexed owner, address token, uint256 amount);
    event Withdrawn(address indexed owner, address token, uint256 amount);

    mapping(address => mapping(ERC20 => uint256)) public balance;

    function deposit(address _token, address _owner, uint256 _amount) external {
        // checks
        if (address(_token).code.length == 0) revert NotAContract();

        // state change
        balance[_owner][ERC20(_token)] += _amount;

        // emit event
        emit Deposited(_owner, _token, _amount);

        // external call
        _token.safeTransferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(address _token, address _to, uint256 _amount) external {
        // checks
        if (address(_token).code.length == 0) revert NotAContract();
        if (balance[msg.sender][ERC20(_token)] < _amount) revert InsufficientBalance();

        // state change
        balance[msg.sender][ERC20(_token)] -= _amount;

        // emit event
        emit Withdrawn(msg.sender, _token, _amount);

        // external call
        _token.safeTransfer(_to, _amount);
    }
}
