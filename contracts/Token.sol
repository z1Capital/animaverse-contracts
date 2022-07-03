// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract AnimaverseToken is Ownable, ERC20 {
    constructor() ERC20('AnimaVerse Token', 'AVT') {}

    function mint(address target, uint256 amount) public onlyOwner {
        _mint(target, amount);
    }
}
