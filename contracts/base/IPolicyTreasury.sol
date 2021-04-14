pragma solidity >=0.6.7;

interface IPolicyTreasury {

  /**
   * @dev Get aggregate treasury info for given token.
   *
   * @param _unit Token unit.
   * @return realBalance_ Current real balance.
   * @return virtualBalance_ Current virtual balance (sum of all policy balances).
   */
  function getEconomics (address _unit) external view returns (
    uint256 realBalance_,
    uint256 virtualBalance_
  );

  /**
   * @dev Get treasury info for given policy.
   *
   * @param _policy Policy address.
   * @return unit_ Token.
   * @return balance_ Current balance.
   * @return minBalance_ Min. requried balance to fully collateralize policy.
   */
  function getPolicyEconomics (address _policy) external view returns (
    address unit_,
    uint256 balance_,
    uint256 minBalance_
  );

  /**
   * @dev Get total pending claims info.
   *
   * @param _unit Token unit.
   * @return count_ No. of pending claims.
   * @return totalAmount_ Total amount of all pending claims.
   */
  function getPendingClaims (address _unit) external view returns (
    uint256 count_,
    uint256 totalAmount_
  );


  /**
   * @dev Get pending claim.
   *
   * @param _unit Token unit.
   * @param _index 1-based claim index.
   * @return policy_ The policy.
   * @return recipient_ Claim recipient.
   * @return amount_ Claim amount.
   */
  function getPendingClaim (address _unit, uint256 _index) external view returns (
    address policy_,
    address recipient_,
    uint256 amount_
  );


  /**
   * @dev Create a market order.
   *
   * @param _type Order type.
   * @param _sellUnit Unit to sell.
   * @param _sellAmount Amount to sell.
   * @param _buyUnit Unit to buy.
   * @param _buyAmount Amount to buy.
   *
   * @return Market order id.
   */
  function createOrder (bytes32 _type, address _sellUnit, uint256 _sellAmount, address _buyUnit, uint256 _buyAmount) external returns (uint256);
  /**
   * @dev Cancel token sale order.
   *
   * @param _orderId Market order id
   */
  function cancelOrder (uint256 _orderId) external;
  /**
   * Pay a claim.
   *
   * Once paid the internal minimum collateral level required for the policy will be automatically reduced.
   *
   * @param _recipient Recipient address.
   * @param _amount Amount to pay.
   */
  function payClaim (address _recipient, uint256 _amount) external;
  /**
   * Increase policy treasury balance.
   *
   * This should only be called by a policy to inform the treasury to update its 
   * internal record of the policy's current balance, e.g. after premium payments are sent to the treasury.
   *
   * @param _amount Amount to add or remove.
   */
  function incPolicyBalance (uint256 _amount) external;
  /**
   * Set minimum balance required to fully collateralize the policy.
   *
   * This can only be called once.
   *
   * @param _amount Amount to increase by.
   */
  function setMinPolicyBalance (uint256 _amount) external;

  // Events

  /**
   * @dev Emitted when policy balance is updated.
   * @param policy The policy address.
   * @param newBal The new balance.
   */
  event UpdatePolicyBalance(
    address indexed policy,
    uint256 indexed newBal
  );

  /**
   * @dev Emitted when the minimum expected policy balance gets set.
   * @param policy The policy address.
   * @param bal The balance.
   */
  event SetMinPolicyBalance(
    address indexed policy,
    uint256 indexed bal
  );
}