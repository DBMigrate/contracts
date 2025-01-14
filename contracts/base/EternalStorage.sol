pragma solidity 0.6.12;

/**
 * @dev Base contract for any upgradeable contract that wishes to store data.
 */
contract EternalStorage {
  // scalars
  mapping(string => address) dataAddress;
  mapping(string => string) dataString;
  mapping(string => bytes32) dataBytes32;
  mapping(string => int256) dataInt256;
  mapping(string => uint256) dataUint256;
  mapping(string => bool) dataBool;
  // arrays
  mapping(string => address[]) dataManyAddresses;
  mapping(string => bytes32[]) dataManyBytes32s;
  mapping(string => int256[]) dataManyInt256;
  mapping(string => uint256[]) dataManyUint256;
  mapping(string => bool[]) dataManyBool;
  // helpers
  function __i (uint256 i1, string memory s) internal pure returns (string memory) {
    return string(abi.encodePacked(i1, s));
  }
  function __a (address a1, string memory s) internal pure returns (string memory) {
    return string(abi.encodePacked(a1, s));
  }
  function __ii (uint256 i1, uint256 i2, string memory s) internal pure returns (string memory) {
    return string(abi.encodePacked(i1, i2, s));
  }
  function __ia (uint256 i1, address a1, string memory s) internal pure returns (string memory) {
    return string(abi.encodePacked(i1, a1, s));
  }
  function __iaa (uint256 i1, address a1, address a2, string memory s) internal pure returns (string memory) {
    return string(abi.encodePacked(i1, a1, a2, s));
  }
  function __ab (address a1, bytes32 b1) internal pure returns (string memory) {
    return string(abi.encodePacked(a1, b1));
  }
}
