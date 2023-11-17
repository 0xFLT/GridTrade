// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

//@title Ownable
//@dev The Ownable contract has an owner address and provides basic authorization control functions, simplifying the implementation of "user permissions".

contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    //@dev Initializes the contract setting the deployer as the initial owner.
    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }


    //@dev Returns the address of the current owner.
    function owner() public view returns (address) {
        return _owner;
    }


    //@dev Throws if called by any account other than the owner.
    modifier onlyOwner() {
        require(isOwner(), "Ownable: Caller is not the owner");
        _;
    }


    //@dev Returns true if the caller is the current owner.
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }


    // @dev Allows the current owner to relinquish control of the contract.
    // It will not be possible to call the functions with the `onlyOwner` modifier anymore if this function is called.
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }


    // @dev Allows the current owner to transfer control of the contract to a newOwner.
    //@param newOwner The address to transfer ownership to.
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: New owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}
