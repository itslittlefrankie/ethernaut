// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import './base/Level.sol';
import './Example.sol';

contract ExampleFactory is Level {
  uint public insertCoin = 0.001 ether;

  function createInstance(address _player) override public payable returns (address) {
    _player;
    require(msg.value >= insertCoin, "Must send at least 0.001 ETH");
    return address((new Example){value:msg.value}());
  }

  function validateInstance(address payable _instance, address _player) override public returns (bool) {
    _player;
    Example instance = Example(_instance);
    (bool result,) = address(instance).call{value:0}("");
    !result;
    return instance._king() != address(this);
  }

  receive() external payable {}
}
