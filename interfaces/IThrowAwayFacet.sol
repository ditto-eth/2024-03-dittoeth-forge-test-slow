// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;



interface IThrowAwayFacet {

  // functions from contracts/facets/ThrowAwayFacet.sol
  function zeroOutLastRedemption() external;
}