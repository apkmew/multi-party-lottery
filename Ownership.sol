// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

contract Ownership {

    address private _owner;

    constructor() {
        _owner = msg.sender;
    }

    function owner() public view returns ( address ) {
        return _owner;
    }

    modifier onlyOwner() {
        require( isOwner(), "Only owner can call this function" );
        _;
    }

    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

}