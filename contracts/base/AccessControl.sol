pragma solidity >=0.5.8;

import "./Address.sol";
import "./EternalStorage.sol";
import "./IACL.sol";

/**
 * @dev Base contract for interacting with the ACL.
 */
contract AccessControl is EternalStorage {
  using Address for address;

  // BEGIN: Generated by script outputConstants.js
  // DO NOT MANUALLY MODIFY THESE VALUES!
  bytes32 constant public ROLE_ASSET_MANAGER = 0x89ce14d20697a788f57260f7690044299bde7ea88cfb7e43d120a0c031f1ffc1;
  bytes32 constant public ROLE_BROKER = 0x2623111b4a77e415ab5147aeb27da976c7a27950b6ec4022b4b9e77176266992;
  bytes32 constant public ROLE_CLIENT_MANAGER = 0x7c3eeefc9b3007f7ad0d2726d617f1550372ce34cb63eb4d0106c781132ec92d;
  bytes32 constant public ROLE_ENTITY_ADMIN = 0x0922a3d5a8713fcf92ec8607b882fd2fcfefd8552a3c38c726d96fcde8b1d053;
  bytes32 constant public ROLE_ENTITY_MANAGER = 0xcfd13d23f7313d54f3a6d98c505045c58749561dd04531f9f2422a8818f0c5f8;
  bytes32 constant public ROLE_ENTITY_REP = 0xcca1ad0e9fb374bbb9dc3d0cbfd073ef01bd1d01d5a35bd0a93403fbee64318d;
  bytes32 constant public ROLE_NAYM = 0xb2346b08a83bcd9171a329ae4b5b6d26c0a707eaa92d3e2398882cb2f37828dd;
  bytes32 constant public ROLE_POLICY_OWNER = 0x7f7cc8b2bac31c0e372310212be653d159f17ff3c41938a81446553db842afb6;
  bytes32 constant public ROLE_SOLE_PROP = 0xc1f14b8056fa2cfffa3660aa4dd1fc19ddfed708f59f00283fd97b7a73d1577f;
  bytes32 constant public ROLE_SYSTEM_ADMIN = 0xd708193a9c8f5fbde4d1c80a1e6f79b5f38a27f85ca86eccac69e5a899120ead;
  bytes32 constant public ROLE_SYSTEM_MANAGER = 0x807c518efb8285611b15c88a7701e4f40a0e9a38ce3e59946e587a8932410af8;
  bytes32 constant public ROLEGROUP_ASSET_MANAGERS = 0x2aa55fd4092650f0625aba8c453fd2225934e3fde512872b7ed991227e5456c2;
  bytes32 constant public ROLEGROUP_BROKERS = 0x8d632412946eb879ebe5af90230c7db3f6d17c94c0ecea207c97e15fa9bb77c5;
  bytes32 constant public ROLEGROUP_CLIENT_MANAGERS = 0x42768a1e635c0fdc7108fc57c0ef96925a14bcf20836ab6eee37dbb995ad3e2f;
  bytes32 constant public ROLEGROUP_ENTITY_ADMINS = 0x251766d8c7c7a6b927647b0f20c99f490db1c283eb0c482446085aaaa44b5e73;
  bytes32 constant public ROLEGROUP_ENTITY_MANAGERS = 0xa33a59233069411012cc12aa76a8a426fe6bd113968b520118fdc9cb6f49ae30;
  bytes32 constant public ROLEGROUP_ENTITY_REPS = 0x610cf17b5a943fc722922fc6750fb40254c24c6b0efd32554aa7c03b4ca98e9c;
  bytes32 constant public ROLEGROUP_FUND_MANAGERS = 0x657a54cbfc103f0ce15bf3a9a186074960385d6dd73ee46a7d6176e097de820a;
  bytes32 constant public ROLEGROUP_POLICY_APPROVERS = 0xe1606495964604a03e8fd88f45e7b36bdaadbb9c36b3f62f6a56866499f3b6c1;
  bytes32 constant public ROLEGROUP_POLICY_CREATORS = 0xdd53f360aa973c3daf7ff269398ced1ce7713d025c750c443c2abbcd89438f83;
  bytes32 constant public ROLEGROUP_POLICY_OWNERS = 0xc59d706f362a04b6cf4757dd3df6eb5babc7c26ab5dcc7c9c43b142f25da10a5;
  bytes32 constant public ROLEGROUP_SYSTEM_ADMINS = 0xab789755f97e00f29522efbee9df811265010c87cf80f8fd7d5fc5cb8a847956;
  bytes32 constant public ROLEGROUP_SYSTEM_MANAGERS = 0x7c23ac65f971ee875d4a6408607fabcb777f38cf73b3d6d891648646cee81f05;
  bytes32 constant public ROLEGROUP_TRADERS = 0x9f4d1dc1107c7d9d9f533f41b5aa5dbbb3b830e3b597338a8aee228ab083eb3a;
  // END: Generated by script outputConstants.js

  /**
   * @dev Constructor.
   * @param _acl Address of ACL.
   */
  constructor (address _acl) public {
    dataAddress["acl"] = _acl;
    dataBytes32["aclContext"] = acl().generateContextFromAddress(address(this));
  }

  /**
   * @dev Check that sender is an admin.
   */
  modifier assertIsAdmin () {
    require(isAdmin(msg.sender), 'must be admin');
    _;
  }

  /**
   * @dev Check if given address has admin privileges.
   * @param _addr Address to check.
   * @return true if so
   */
  function isAdmin (address _addr) public view returns (bool) {
    return acl().isAdmin(_addr);
  }

  /**
   * @dev Check if given address has a role in the given role group in the current context.
   * @param _addr Address to check.
   * @param _roleGroup Rolegroup to check against.
   * @return true if so
   */
  function inRoleGroup (address _addr, bytes32 _roleGroup) public view returns (bool) {
    return inRoleGroupWithContext(aclContext(), _addr, _roleGroup);
  }

  /**
   * @dev Check if given address has given role in the current context.
   * @param _addr Address to check.
   * @param _role Role to check against.
   * @return true if so
   */
  function hasRole (address _addr, bytes32 _role) public view returns (bool) {
    return hasRoleWithContext(aclContext(), _addr, _role);
  }

  /**
   * @dev Check if given address has a role in the given rolegroup in the given context.
   * @param _ctx Context to check against.
   * @param _addr Address to check.
   * @param _roleGroup Role group to check against.
   * @return true if so
   */
  function inRoleGroupWithContext (bytes32 _ctx, address _addr, bytes32 _roleGroup) public view returns (bool) {
    return acl().hasRoleInGroup(_ctx, _addr, _roleGroup);
  }

  /**
   * @dev Check if given address has given role in the given context.
   * @param _ctx Context to check against.
   * @param _addr Address to check.
   * @param _role Role to check against.
   * @return true if so
   */
  function hasRoleWithContext (bytes32 _ctx, address _addr, bytes32 _role) public view returns (bool) {
    return acl().hasRole(_ctx, _addr, _role);
  }

  /**
   * @dev Get ACL reference.
   * @return ACL reference.
   */
  function acl () internal view returns (IACL) {
    return IACL(dataAddress["acl"]);
  }

  /**
   * @dev Get current ACL context.
   * @return the context.
   */
  function aclContext () public view returns (bytes32) {
    return dataBytes32["aclContext"];
  }
}
