const contracts = {
  Proxy: require('./build/contracts/Proxy.json'),
  ACL: require('./build/contracts/ACL.json'),
  FUCDeployer: require('./build/contracts/FUCDeployer.json'),
  IFUCImpl: require('./build/contracts/IFUCImpl.json'),
  IERC20: require('./build/contracts/IERC20.json'),
  IERC777: require('./build/contracts/IERC777.json'),
  DummyERC777TokensSender: require('./build/contracts/DummyERC777TokensSender.json'),
  DummyERC777TokensRecipient: require('./build/contracts/DummyERC777TokensRecipient.json'),
}

const events = Object.values(contracts).reduce((output, contract) => {
  contract.abi.filter(({ type, name }) => type === 'event').forEach(e => {
    if (output[e.name]) {
      throw new Error(`Already got an event named ${e.name}`)
    }
    output[e.name] = e
  })

  return output
}, {})

module.exports = {
  contracts,
  events,
}