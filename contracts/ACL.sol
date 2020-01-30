pragma solidity >=0.5.8;

import "./base/IACL.sol";

/**
 * @dev Library for managing addresses assigned to a Role within a context.
 */
library Assignments {
  struct User {
    mapping (bytes32 => uint256) map;
    bytes32[] list;
  }

  struct Context {
    mapping (address => User) users;
  }

  /**
   * @dev give an address access to this role
   */
  function add(Context storage _context, bytes32 _role, address _addr)
    internal
  {
    User storage u = _context.users[_addr];

    if (0 == u.map[_role]) {
      u.list.push(_role);
      u.map[_role] = u.list.length;
    }
  }

  /**
   * @dev remove an address' access to this role
   */
  function remove(Context storage _context, bytes32 _role, address _addr)
    internal
  {
    User storage u = _context.users[_addr];

    uint256 idx = u.map[_role];

    if (0 < idx) {
      uint256 actualIdx = idx - 1;

      // replace item to remove with last item in list and update mappings
      if (u.list.length - 1 > actualIdx) {
        u.list[actualIdx] = u.list[u.list.length - 1];
        u.map[u.list[actualIdx]] = actualIdx + 1;
      }

      u.list.length--;
      u.map[_role] = 0;
    }
  }

  /**
   * @dev check if an address has this role
   * @return bool
   */
  function has(Context storage _context, bytes32 _role, address _addr)
    internal
    view
    returns (bool)
  {
    User storage u = _context.users[_addr];

    return (0 < u.map[_role]);
  }


  /**
   * @dev get all roles for address
   * @return bytes32[]
   */
  function getRolesForUser(Context storage _context, address _addr)
    internal
    view
    returns (bytes32[] storage)
  {
    User storage u = _context.users[_addr];

    return u.list;
  }
}


/**
 * @dev Library for lists of byte32 value.
 */
library Bytes32 {
  struct List {
    mapping (bytes32 => uint256) map;
    bytes32[] list;
  }

  /**
   * @dev add a value
   */
  function add(List storage _obj, bytes32 _assignerRole)
    internal
  {
    if (0 == _obj.map[_assignerRole]) {
      _obj.list.push(_assignerRole);
      _obj.map[_assignerRole] = _obj.list.length;
    }
  }

  /**
   * @dev remove an value for this role
   */
  function remove(List storage _obj, bytes32 _assignerRole)
    internal
  {
    uint256 idx = _obj.map[_assignerRole];

    if (0 < idx) {
      uint256 actualIdx = idx - 1;

      // replace item to remove with last item in list and update mappings
      if (_obj.list.length - 1 > actualIdx) {
        _obj.list[actualIdx] = _obj.list[_obj.list.length - 1];
        _obj.map[_obj.list[actualIdx]] = actualIdx + 1;
      }

      _obj.list.length--;
      _obj.map[_assignerRole] = 0;
    }
  }

  /**
   * @dev remove all values
   */
  function clear(List storage _obj)
    internal
  {
    for (uint i = 0; i < _obj.list.length; i += 1) {
      _obj.map[_obj.list[i]] = 0;
    }

    _obj.list.length = 0;
  }

  /**
   * @dev Get all values.
   */
  function getAll(List storage _obj)
    internal
    view
    returns (bytes32[] storage)
  {
    return _obj.list;
  }
}




contract ACL is IACL {
  using Assignments for Assignments.Context;
  using Bytes32 for Bytes32.List;

  mapping (string => Assignments.Context) private assignments;
  mapping (bytes32 => Bytes32.List) private assigners;
  mapping (bytes32 => Bytes32.List) private roleToGroups;
  mapping (bytes32 => Bytes32.List) private groupToRoles;
  mapping (address => bool) public admins;
  mapping (address => bool) public pendingAdmins;
  uint256 public numAdmins;

  mapping (uint256 => string) public contexts;
  mapping (string => bool) public isContext;
  uint256 public numContexts;

  modifier assertIsAdmin () {
    require(admins[msg.sender], 'unauthorized - must be admin');
    _;
  }

  modifier assertIsAssigner (string memory _context, bytes32 _role) {
    // either they have the permission to assign or they're an admin
    require(canAssign(_context, msg.sender, _role) || isAdmin(msg.sender), 'unauthorized');
    _;
  }

  constructor () public {
    admins[msg.sender] = true;
    numAdmins = 1;
  }

  // Admins

  /**
   * @dev determine if addr is an admin
   */
  function isAdmin(address _addr) public view returns (bool) {
    return admins[_addr];
  }

  function proposeNewAdmin(address _addr) public assertIsAdmin {
    require(!admins[_addr], 'already an admin');
    require(!pendingAdmins[_addr], 'already proposed as an admin');
    pendingAdmins[_addr] = true;
    emit AdminProposed(_addr);
  }

  function cancelNewAdminProposal(address _addr) public assertIsAdmin {
    require(pendingAdmins[_addr], 'not proposed as an admin');
    pendingAdmins[_addr] = false;
    emit AdminProposalCancelled(_addr);
  }

  function acceptAdminRole() public {
    require(pendingAdmins[msg.sender], 'not proposed as an admin');
    pendingAdmins[msg.sender] = false;
    admins[msg.sender] = true;
    numAdmins++;
    emit AdminProposalAccepted(msg.sender);
  }

  function removeAdmin(address _addr) public assertIsAdmin {
    require(1 < numAdmins, 'cannot remove last admin');
    require(_addr != msg.sender, 'cannot remove oneself');
    require(admins[_addr], 'not an admin');
    admins[_addr] = false;
    numAdmins--;
    emit AdminRemoved(_addr);
  }

  // Contexts

  function getNumContexts() public view returns (uint256) {
    return numContexts;
  }

  function getContext(uint256 _index) public view returns (string memory) {
    return contexts[_index];
  }

  // Role groups

  function hasRoleInGroup(string memory _context, address _addr, bytes32 _roleGroup) public view returns (bool) {
    return hasAnyRole(_context, _addr, groupToRoles[_roleGroup].getAll());
  }

  function setRoleGroup(bytes32 _roleGroup, bytes32[] memory _roles) public assertIsAdmin {
    // remove old roles
    bytes32[] storage oldRoles = groupToRoles[_roleGroup].getAll();

    for (uint256 i = 0; i < oldRoles.length; i += 1) {
      bytes32 r = oldRoles[i];
      roleToGroups[r].remove(_roleGroup);
    }

    groupToRoles[_roleGroup].clear();

    // set new roles
    for (uint256 i = 0; i < _roles.length; i += 1) {
      bytes32 r = _roles[i];
      roleToGroups[r].add(_roleGroup);
      groupToRoles[_roleGroup].add(r);
    }

    emit RoleGroupUpdated(_roleGroup);
  }

  function getRoleGroup(bytes32 _roleGroup) public view returns (bytes32[] memory) {
    return groupToRoles[_roleGroup].getAll();
  }

  function getRoleGroupsForRole(bytes32 _role) public view returns (bytes32[] memory) {
    return roleToGroups[_role].getAll();
  }

  // Roles

  /**
   * @dev determine if addr has role
   */
  function hasRole(string memory _context, address _addr, bytes32 _role)
    public
    view
    returns (bool)
  {
    return assignments[_context].has(_role, _addr);
  }

  function hasAnyRole(string memory _context, address _addr, bytes32[] memory _roles)
    public
    view
    returns (bool)
  {
    bool hasAny = false;

    for (uint256 i = 0; i < _roles.length; i++) {
      if (hasRole(_context, _addr, _roles[i])) {
        hasAny = true;
        break;
      }
    }

    return hasAny;
  }

  /**
   * @dev assign a role to an address
   */
  function assignRole(string memory _context, address _addr, bytes32 _role)
    public
    assertIsAssigner(_context, _role)
  {
    // record new context if necessary
    if (!isContext[_context]) {
      contexts[numContexts] = _context;
      isContext[_context] = true;
      numContexts++;
    }

    assignments[_context].add(_role, _addr);
    emit RoleAssigned(_context, _addr, _role);
  }

  /**
   * @dev remove a role from an address
   */
  function unassignRole(string memory _context, address _addr, bytes32 _role)
    public
    assertIsAssigner(_context, _role)
  {
    assignments[_context].remove(_role, _addr);
    emit RoleUnassigned(_context, _addr, _role);
  }

  function getRolesForUser(string memory _context, address _addr) public view returns (bytes32[] memory) {
    return assignments[_context].getRolesForUser(_addr);
  }

  // Role assigners

  function addAssigner(bytes32 _role, bytes32 _assignerRole)
    public
    assertIsAdmin
  {
    assigners[_role].add(_assignerRole);
    emit AssignerAdded(_role, _assignerRole);
  }

  function removeAssigner(bytes32 _role, bytes32 _assignerRole)
    public
    assertIsAdmin
  {
    assigners[_role].remove(_assignerRole);
    emit AssignerRemoved(_role, _assignerRole);
  }

  function getAssigners(bytes32 _role)
    public
    view
    returns (bytes32[] memory)
  {
    return assigners[_role].getAll();
  }

  function canAssign(string memory _context, address _addr, bytes32 _role)
    public
    view
    returns (bool)
  {
    if (isAdmin(_addr)) {
      return true;
    }

    return hasAnyRole(_context, _addr, getAssigners(_role));
  }
}
