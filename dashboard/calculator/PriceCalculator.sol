// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
* MIT License
* ===========
*

* Copyright (c) 2021 Astarnova
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../../uniswapv2/interfaces/IUniswapV2Pair.sol";
import "../../uniswapv2/interfaces/IUniswapV2Router02.sol";
import "../interfaces/IPriceCalculator.sol";

contract PriceCalculator is IPriceCalculator, Ownable {
  using SafeMath for uint;

  /* ========== STATE VARIABLES ========== */

  mapping(address => bool) public isLpToken;
  mapping(address => address[]) public tokenPathToUSD;
  mapping(address => address) public tokenRouter;

  /* ========== RESTRICTED FUNCTIONS ========== */

  function addNewTokens(address[] memory lpToken, bool[] memory isLp, address[][] memory path, address[] memory router) public override onlyOwner {
    for (uint i = 0; i < lpToken.length; i++) {
      setIsLpToken(lpToken[i], isLp[i]);
      setTokenPathToUSD(lpToken[i], path[i]);
      setTokenRouter(lpToken[i], router[i]);
    }
  }

  function setIsLpToken(address lpToken, bool isLp) public override onlyOwner {
    isLpToken[lpToken] = isLp;
  }

  function setTokenPathToUSD(address asset, address[] memory path) public override onlyOwner {
    tokenPathToUSD[asset] = path;
  }

  function setTokenRouter(address asset, address router) public override onlyOwner {
    tokenRouter[asset] = router;
  }

  /* ========== VIEWS ========== */

  function pricesIn(address[] memory assets) public view override returns (uint[] memory) {
    uint[] memory prices = new uint[](assets.length);
    for (uint i = 0; i < assets.length; i++) {
      IERC20Metadata token = IERC20Metadata(assets[i]);
      prices[i] = valueOfAsset(assets[i], 10 ** token.decimals());
    }
    return prices;
  }

  function valueOfAsset(address asset, uint amount) public view override returns (uint) {
    if (amount == 0) return 0;

    return unsafeValueOfAsset(asset, amount);
  }

  /* ========== PRIVATE FUNCTIONS ========== */

  function unsafeValueOfAsset(address asset, uint amount) private view returns (uint) {
    if (isLpToken[asset]) {
      (uint reserve0,,) = IUniswapV2Pair(asset).getReserves();
      IERC20Metadata token = IERC20Metadata(IUniswapV2Pair(asset).token0());
      uint token0PriceInUSDC = valueOfAsset(address(token), 10 ** token.decimals());
      return amount.mul(reserve0).mul(2).mul(token0PriceInUSDC).div(10 ** token.decimals()).div(IUniswapV2Pair(asset).totalSupply());
    }

    if (tokenPathToUSD[asset].length > 1) {
      IERC20Metadata token = IERC20Metadata(asset);
      uint tokenPriceInUSDC = IUniswapV2Router02(tokenRouter[asset]).getAmountsOut(10 ** token.decimals(), tokenPathToUSD[asset])[tokenPathToUSD[asset].length.sub(1)];
      return tokenPriceInUSDC.mul(amount).div(10 ** token.decimals());
    }

    return amount;
  }

}

