pragma solidity 0.6.12;

import "./IDiamondFacet.sol";

abstract contract IDiamondUpgradeFacet is IDiamondFacet {
  // IDiamondFacet

  function getSelectors () public pure override returns (bytes memory) {
    return abi.encodePacked(
      IDiamondUpgradeFacet.upgrade.selector,
      IDiamondUpgradeFacet.getVersionInfo.selector
    );
  }

  // methods

  function upgrade (address[] calldata _facets) external virtual;

  function getVersionInfo () external virtual pure returns (string memory num_, uint256 date_, string memory hash_);
}


