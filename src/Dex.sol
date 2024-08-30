// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Dex {
    IERC20 public token_x; 
    IERC20 public token_y; 

    uint public total_supply; 
    mapping(address => uint) public balanceOf; 
    uint public reserve_x; 
    uint public reserve_y; 

    constructor(address _tokenX, address _tokenY) {
        token_x = IERC20(_tokenX);
        token_y = IERC20(_tokenY);
    }

    function addLiquidity(uint amount_x, uint amount_y, uint min_liquidity) external returns (uint liquidity) {
        require(amount_x > 0 && amount_y > 0, "Invalid input amounts");
        require(token_x.allowance(msg.sender, address(this)) >= amount_x, "ERC20: insufficient allowance");
        require(token_y.allowance(msg.sender, address(this)) >= amount_y, "ERC20: insufficient allowance");
        require(token_x.balanceOf(msg.sender) >= amount_x, "ERC20: transfer amount exceeds balance");
        require(token_y.balanceOf(msg.sender) >= amount_y, "ERC20: transfer amount exceeds balance");
        
        reserve_x = token_x.balanceOf(address(this));

        if (total_supply == 0) {
            liquidity = sqrt(amount_x * amount_y);
        } else {
            liquidity = min(amount_x * total_supply / reserve_x, amount_y * total_supply / reserve_y);
        }

        require(liquidity >= min_liquidity, "Dex: insufficient liquidity minted");

        balanceOf[msg.sender] += liquidity; 
        total_supply += liquidity; 
        
        reserve_x += amount_x; 
        reserve_y += amount_y; 

        require(token_x.transferFrom(msg.sender, address(this), amount_x), "Dex: transfer of token_x failed");
        require(token_y.transferFrom(msg.sender, address(this), amount_y), "Dex: transfer of token_y failed");
        return liquidity;
    }


    function removeLiquidity(uint liquidity, uint min_amount_x, uint min_amount_y) external returns (uint amount_x, uint amount_y) {
        require(balanceOf[msg.sender] >= liquidity, "Dex: insufficient liquidity balance");

        amount_x = liquidity * reserve_x / total_supply;
        amount_y = liquidity * reserve_y / total_supply;

        require(amount_x >= min_amount_x && amount_y >= min_amount_y, "Dex: insufficient liquidity burned");

        balanceOf[msg.sender] -= liquidity; 
        total_supply -= liquidity; 

        reserve_x -= amount_x; 
        reserve_y -= amount_y; 

        require(token_x.transfer(msg.sender, amount_x), "Dex: transfer of token_x failed");
        require(token_y.transfer(msg.sender, amount_y), "Dex: transfer of token_y failed");
        return (amount_x, amount_y);
    }

    function swap(uint amount_x_in, uint amount_y_in, uint min_out) external returns (uint amount_out) {
        require((amount_x_in == 0 && amount_y_in > 0) || (amount_x_in > 0 && amount_y_in == 0), "Dex: invalid swap amounts");

        uint amount_x_out;
        uint amount_y_out;

        if (amount_x_in > 0) {
            uint k = reserve_x * reserve_y; 
            reserve_x += amount_x_in; 
            amount_y_out = reserve_y - k / reserve_x; 
            amount_y_out = amount_y_out * 999 / 1000; 
            require(amount_y_out >= min_out, "Dex: insufficient output amount"); 
            reserve_y -= amount_y_out; 

            require(token_x.transferFrom(msg.sender, address(this), amount_x_in), "Dex: transfer of token_x failed");
            require(token_y.transfer(msg.sender, amount_y_out), "Dex: transfer of token_y failed");

            amount_out = amount_y_out; 
        } else {
            uint k = reserve_x * reserve_y; 
            reserve_y += amount_y_in; 
            amount_x_out = reserve_x - k / reserve_y; 
            amount_x_out = amount_x_out * 999 / 1000; 
            require(amount_x_out >= min_out, "Dex: insufficient output amount"); 
            reserve_x -= amount_x_out; 

            require(token_y.transferFrom(msg.sender, address(this), amount_y_in), "Dex: transfer of token_y failed");
            require(token_x.transfer(msg.sender, amount_x_out), "Dex: transfer of token_x failed");

            amount_out = amount_x_out; 
        }
    }

    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min(uint x, uint y) internal pure returns (uint) {
        return x <= y ? x : y;
    }

}
