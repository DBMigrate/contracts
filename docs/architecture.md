# Architectural overview

This is high-level architectural guide to the Nayms smart contracts.

## Upgradeability

Our [Entity](#entities) and [Policy](#policies) contracts are fully upgradeable, meaning we can fix bugs and release new features for these without have to redeploy existing contracts at new addresses. 

We use the [Diamond Standard](https://hiddentao.com/archives/2020/05/28/upgradeable-smart-contracts-using-diamond-standard) to allow for virtually infinite-size smart contracts where every single function can be implemented within a separate contract if we so wished. The main entrypoint contract acts as a proxy, forwarding every incoming call to the appropriate implementation contract based on an internal lookup-table:

![delegateproxy](https://user-images.githubusercontent.com/266594/118700115-35feb200-b80a-11eb-87b6-6fa22d501135.png)

Taking entities as example, we have an [EntityDelegate](https://github.com/nayms/contracts/blob/master/contracts/EntityDelegate.sol) contract which acts as a singleton proxy. All actual entities then _virtually point_ to this one:

![delegateproxy2](https://user-images.githubusercontent.com/266594/118700852-fe443a00-b80a-11eb-94ea-e71614ccee41.png)

When a call comes in to an `Entity` it uses the lookup table inside the `EntityDelegate` to work out which implementation contract to call. Thus, when we wish to upgrade the code for our entities we only need to update the `EntityDelegate` singleton!

Note that contract upgrades can only be performed by a [System admin](#system-admin).

## ACL

There are numerous stakeholders in the Nayms platform, all of whom have varying degrees of control and access to different parts of the platform. To accomodate for this complexity we utilize an [ACL](https://github.com/nayms/contracts/commits/master/contracts/ACL.sol) (access control list). This is a singleton contract instance into which all of our other contracts call.

The address to the ACL is stored in the [Settings](#settings) contract.

### Contexts

Roles are assigned within a **context**, which are like separate namespaces. This allows for fine-grained role assignment,e.g: _Address A can have role B in context C but not context D_:

![PNG image-9019824EE033-1](https://user-images.githubusercontent.com/266594/118675754-c4ffd000-b7f2-11eb-8c3b-f13b44f4ee3a.png)

Thus, when we look up role assignemnts we always supply a role context.

Note, however, that there is such a thing as the **System context**. This is the core context of the ACL contract itself. If an address is assigned a role within this context then it is taken to have that role in _all_ contexts. For this reason you should be 
very careful about assigning roles within the System context:

![syscontext](https://user-images.githubusercontent.com/266594/118675360-73efdc00-b7f2-11eb-8bef-d546f201d673.png)

A context is just a `bytes32` value, and so the easiest way to generate a context value is to use the `keccak256` method to hash an input string, address, whatever. By convention the context of a given contract or user address is the `keccak256` hash of the address.

### Assigning roles

Any address can be assigned to any role within any context, as long as the _assigner_ (i.e. `msg.sender`) has permission to make such an assignment. Permission is based on atleast one of the following conditions being true:

* The context is the caller's own
* The caller is a [System admin](#system-admin)
* The caller has a role which belongs to a role group that is allowed to assign this role

Note what the first condition states: any caller can assign roles within _their own_ context. Since by convention the context of an address is simply the `keccak256` hash of that address it's possible for the ACL to calculate the context of the caller and then check to see if the assignment is being made within that context.

This means that smart contracts can assign roles within their own contexts - and indeed we make use of this functionality in our Policy smart contracts.

Note that the permissions required to un-assign a role are the same as for assigning.

### Role groups

Authorization within our smart contracts is processed on the basis of role groups. Role groups are simply groupings of on or more under specific labels. This allows us to enable multiple roles access to certain parts of the platform without having to individually check for each role.

![rolegroups](https://user-images.githubusercontent.com/266594/118687840-5ffda780-b7fd-11eb-84b5-2e488c4640c4.png)

Role groups can be allowed to assign roles. For example, the `ENTITY_ADMINS` role group is allowed to assign the `ENTITY_MANAGER` role. This means that an address that has been assigned a role belonging to the `ENTITY_ADMINS` role group will be able to assign the `ENTITY_MANAGER` role to itself and others. 
### System admin

**System admins** are the most powerful actors in the Nayms system since they have access to anything and everything, including upgrading the smart contract logic. To be precise, any address which has a role that is part of the `SYSTEM_ADMINS` role group can do this. And since the only role in this group is the `SYSTEM_ADMIN` role, this means that only addresses with the `SYSTEM_ADMIN` role assigned have this level of access. Furthermore, assignment must be made in the System context.

They can assign any role within any context. And they are also the only group of actors who are allowed to modify the assigning capabilities of role groups.

Since this role is so powerful, upon initial of our smart contracts we set our [Gnosis SAFE](https://gnosis-safe.io/) multisig as the sole address with this role. This ensures that all future actions taken at the System admin level require n-of-m signatures via the multisig.  

## Role architecture

The [ACL deployment script](https://github.com/nayms/contracts/blob/master/migrations/modules/acl.js) has the full list of roles and role groups.

## Settings

Our [Settings contract](https://github.com/nayms/contracts/blob/master/contracts/Settings.sol) is a singleton contract instance that acts as a global data store for our platfom. 

It exposes a simple key-value storage interface where setting a value can only be done by [System admins](#system-admin).

We pass the address of the Settings contract in the constructor when deploying all other contracts (except the [ACL](#acl), since Settings uses the ACL to authorize writes). Once deployed, a contract can lookup the addresses of other relevant contracts in the system via the Settings contract.

## Entities

All stakeholders are represented by [Entity](https://github.com/nayms/contracts/blob/master/contracts/Entity.sol) contracts.

Anyone can deposit funds into an entity but only entity admins can withdraw. Entities can use these balances to invest in (i.e. collateralize) policies. 

Entities can create policies, though the rule is that the entity itself must be set as either the broker or capital provider of the created policy.

### Treasury

Entities also have an internal _treasury_ which is where policy collateral (and premium payments) is actually stored. Funds can be transferred between the entity's "normal" balance and its treasury balance as long as its treasury's collateralization ratio is honoured.

The treasury has a _virtual balance_, which is the balance it expects to have according to the policies it has collateralized as well as pending claims. It has a _real/actual balance_, which is its real balance. And it has a collateralization ratio set, which is essentially of the virtual balance to the real balance. 

_For example, if the collateraliation ration is 25% then the real balance must always be atleast 25% of the virtual balance._

![entity](https://user-images.githubusercontent.com/266594/118809113-1a46ea80-b8a2-11eb-94e6-ca53a70e35fd.png)

When a claim needs to be paid out and there is not enough balance to do so, the claim gets added to the internal claim queue in the treasury. As soon as new funds are received (via transfer from the entity "normal" balance) any pending claims get paid out automatically in the order in which they were originally created (FIFO):

![claims](https://user-images.githubusercontent.com/266594/118810406-c0dfbb00-b8a3-11eb-90a0-d3ee615cdfcd.png)

Entites can create insurance [policies](#policies).

## Policies

Policies are created and collateralized by [entities](#entities).

The four main types of entities are: _Capital providers, brokers, insured parties and claims administrators_. Only Capital providers and brokers are allowed to create policies. However, every policy must have a nominated entity representing each of the 4 types. 

Every policy operates according to the following timeline:

1. **Initiation date** - _The point in time when the policy's tranch tokens will go up for an initial sale._
2. **Start date** - _The point in time after the initiation date when the policy's sale should have been completed by, and after which the policy is considered active._
3. **Maturation date** - _The point in time after the start date when the policy stops being active and stop accepting new claims._

Policies transition between the following [states](https://github.com/nayms/contracts/blob/master/contracts/base/IPolicyStates.sol), in order:

1. **Created** - _The policy has been created. Tranches can now be created._
2. **Ready for approval** - _All tranches have been created. The policy must now be approved by all its nominated entities._
3. **In approval** - _The approval process is underway._
4. **Approved** - _The policy has been approved by all its nominated entities. Once the initiation date has passed the initial tranch sale can begin._
5. **Initiated** - _The policy initial sale is now in progress, whereby all tranches have been put up for sale in order for the policy to be become collateralized._
6. **Active** - _The start date has passed and the initial sale has completed successfully (i.e. at least one tranch has fully sold out). The policy is now active and will accept claims._
7. **Matured** - _The maturation date has passed and the policy is now longer active. New claims are now longer accepted._
8. **Buyback** - _All claims have been paid out and the policy is now buying back its tranch tokens from the initial sale using its leftover collateral._
9. **Closed** - _The buyback has completed and the policy is now fully closed._
10. **Cancelled** - _The policy has been cancelled. This state is reached if the initial tranch sale fails or if a premium payment is missed._

Except for the **Ready for approval** state, all other states are transitioned to via our heartbeat mechanism.

![policystates](https://user-images.githubusercontent.com/266594/118973688-d7504a00-b969-11eb-81e1-e436ab6a7da2.png)


### Heartbeat

The [`checkAndUpdateState()`](https://github.com/nayms/contracts/blob/master/contracts/base/IPolicyCoreFacet.sol#L109) function is responsible for checking the current state of a policy and progressing it to the next state if necessary. It roughly does the following:

* If the initiation date has passed then begin the initial tranch sale.
* If the start date has passed then check to see if the tranch sale succeeded and that premium payments are up-to-date. If so then mark the policy as **Active**. If not then mark the policy as **Cancelled**.
* If the maturation date has passed then mark the policy as **Matured**.
* If the policy has matured and all claims have been dealt with then initiate the tranch token **Buyback**.
* Check that premium payments are up-to-date. If not then mark the policy as **Cancelled**.

The heartbeat is currently called automatically by our backend.

### Tranches

Every policy can have one or more tranches created. Each tranch has a configurable fixed no. of "shares" (similar to equity) as well as an initial price-per-share for during the initial sale period. All tranches are priced in the same currency as the policy.

Tranches, like their parent policies, also have states:

* **Created** - _Tranch created._
* **Selling** - _Tranch tokens have been put for sale as part of the initial sale triggered by the policy initiation date._
* **Active** - _All tranch tokens sold out by the policy start date, and the tranch is thus active. Only tranches in this state can have claims made against them._
* **Matured** - _Policy has matured, and the tranch has thus matured._
* **Cancelled** - _The tranch tokens did not fully sell out by the policy start date, and thus the tranch is cancelled._

Tranche shares are [represented as ERC-20 tokens](https://github.com/nayms/contracts/blob/master/contracts/TranchToken.sol), meaning that each each tranch gets its own ERC-20 token. Since we want to restrict access to these tranch tokens to authorized entities they can only be [transferred through our Matching market](https://github.com/nayms/contracts/blob/master/contracts/PolicyTranchTokens.sol#L74).

The Tranch token logic is actually implemented within the policy, thus allowing us to upgrade tranch token code when upgrading policy code:

![token](https://user-images.githubusercontent.com/266594/118975104-8a6d7300-b96b-11eb-88f7-e883c34a155d.png)

### Claims

Claims can be made representatives of insured parties against a specific active policy tranch. Claims go through the following state transitions:

1. **Created** - _A claim has been created._
2. **Approved** - _A claim has been approved the claims administrator_.
3. **Declined** - _A claim has been declined the claims administrator_.
4. **Paid** - _A claim has been approved and paid_.

Note that when a claim is in the **Paid** state it doesn't guarantee that the funds have actually reached the insured party. This only happens once there are enough funds in the [treasury](#treasury) to pay the claim. If there are already enough funds in the treasury then the claim will get paid out straight away, i.e. as soon as the [payClaims()](https://github.com/nayms/contracts/blob/master/contracts/base/IPolicyClaimsFacet.sol#L60) method gets called. Otherwise the claim will be placed in queue within the treasury.

Claims can also be _acknowledged_ by the capital provider. This is simply a flag on the claim data and is not considered to be a separate state. 

At present there is no deadline for approving or declining claims. This also means that once a policy matures, the **Buyback** phase cannot be triggered until all pending claims are resolved (i.e. either approved or declined).

### Treasury usage

Every policy has an associated [treasury](#treasury) which stores all its funds. The treasury is usually the capital provider entity associated with the policy.

Initially, all tranch tokens are owned by the treasury. This means the initial token sale is coordinated between the treasury and the [matching market](#matching-market) on behalf of the policy. And the collateral obtained as a result of the purchase is also then automatically help in the treasury. 

Premium payments are forward to the treasury, minus [commision](#commissions) payments.

### Commissions

Commission payments for the various associated entities are taken out of incoming premium payments and stored within the policy itself. They are then distributed to all the relevant parties whenever the [payComissions()](https://github.com/nayms/contracts/blob/master/contracts/base/IPolicyCommissionsFacet.sol#L10) method is invoked.

## Matching market

We use an unmodified fork of the [Maker OTC matching market](https://github.com/nayms/maker-otc) to facilitate tranch token sales and trades. In fact, at present the tranch tokens can only be transferred by our on-chain market, though we will likely loosen this restriction later.


## Deployments

We deploy contracts to Rinkeby and/or Mainnet and publish NPM packages which have the contract ABIs needed to deploy and manipulate these contracts. 

Deployments are configured through a `releaseConfig.json` file set in the root of the project. This file gets generated when you run one of the `setup-release-config-for-*` commands and typically looks like this:

```js
{
  "npmTag": "latest",  /* The tag to use for the published NPM package */
  "npmPkgVersion": "1.0.0-build.local",   /* The version to use for the published NPM package */
  "deployRinkeby": true, /* Whether we are deploying to Rinkeby */
  "deployMainnet": false, /* Whether we are deploying to Mainnet */
  "multisig": "0x52A1A89bF7C028f889Bf57D50aEB7B418c2Fc79B",  /* The Gnosis SAFE address for the network we are deploying to */ 
  "adminDappPath": "1.0.0-build.local",  /* Path to admin dapp folder relative to project root folder */
  "freshDeployment": false, /* Whether we are deploying everything from scratch or just upgrading entities and policies */
  "extractAddresses": false, /* Whether to overwrite the ACL, Settings, etc contract addresses that are in deployedAddresses.json with the on-chain ones */
  "hash": "1095e9f83d7bdd93441bb23af23258db062a11ae", /* Latest git commit hash */
  "date": "2021-05-20T10:05:19.119Z"  /* Datetime for when the releaseConfig.json was generated */
}
```

The last two attributes - `hash` and `date` - get inserted into `contracts/CommonUpgradeFacet.sol`, which looks like:

```solidity
...

contract CommonUpgradeFacet is ... {
  ...
  
  function getVersionInfo () public override pure returns (string memory num_, uint256 date_, string memory hash_) {
    num_ = "1.0.0-build.dev1620912256601";   // matches NPM package version
    date_ = 1620912256;
    hash_ = "6088a4b34ede677319b09fa3239bf8ca7454c602";
  }
}
```

Thus both [entities](#entities) and [policies](#policies) can be queried for their deployment version - and this can then be matched to the correct NPM package version, allowing us to know which versino of the package to use to talk to a given on-chain contract.

**Fresh deployments vs Upgrades**

If `freshDeployment` is set to `true` then the [deployment script](https://github.com/nayms/contracts/blob/master/migrations/1_deploy_contracts.js) will deploy the `ACL`, `Settings`, `EntityDeployer` and `MatchingMarket` contracts. It will also deploy a new _Nayms_ entity using the `EntityDeployer`. After this it will deploy all entity and policy implementation contracts and save all the addresses into the [Settings](#settings) contract. 

If `freshDeployment` is set to `false` then the script will instead obtain the addresses of the existing `ACL`, `Settings`, `EntityDeployer` and `MatchingMarket` contracts from the `deployedAddresses.json` file in the project folder. It will still freshly deploy all entity and policy implementation contracts and then upgrade all existing entities and policies to point to the new implementations. This type deployment is known as an _Upgrade_.

By default we want to do upgrade deployments (instead of fresh ones) since this preserves all existing on-chain data in correlation with what's in our backend. Also, we are designing our core contracts (`ACL`, `Settings`, etc.) to not require upgrades so that we only have to deploy them once.

**Continuous deployment (CD)**

Our CD process auto-deploys contract code and auto-publishes NPM packages in certain circumstances. Specifically:

1. Every commit to a PR branch results in a fresh deployment in Rinkeby and an associated fresh NPM package. This is so that the tech team can test out new features in isolation.
2. Every commit to the `release` branch results in an upgrade deployment on Rinkeby and an associated fresh NPM package. These deployments are considered to be production-quality.

Note that we don't auto-deploy to Mainnet at the moment. In fact, we haven't yet deployed our v2 contracts to Mainnet at all. 

**Multisig**

If `multisig` is set then upgrade deployments behave slightly differently. New entity and policy implementations will get deployed to chain as normal but the calls to actually upgrade existing entities and policies will be set to go via the multisig. Thus, these calls will need to be separately approved by the multisig signers in order to actually get executed on-chain.

We envision using system this as our Mainnet upgrade deployement process.
