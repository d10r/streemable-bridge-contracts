const PrivateKeyProvider = require('truffle-privatekey-provider');

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*",
      gasPrice: 1000000000
    },
    test: {
      host: "localhost",
      port: 8545,
      network_id: "*",
      gasPrice: 1000000000
    },
    kovan: {
      host: "localhost",
      port: "8591",
      network_id: "*",
      gas: 4700000,
      gasPrice: 1000000000
    },
    kovan_infura: {
      provider: () => new PrivateKeyProvider(process.env.PRIVKEY || null, `https://kovan.infura.io/v3/${process.env.INFURAKEY}`),
      network_id: "*",
      gas: 4700000,
      gasPrice: 1000000000
    },
    ethereum_infura: {
      provider: () => new PrivateKeyProvider(process.env.PRIVKEY || null, `https://mainnet.infura.io/v3/${process.env.INFURAKEY}`),
      network_id: "1",
      gas: 4700000,
      gasPrice: process.env.GASPRICE_MWEI * 1000000,
    },
    tau1_rpc: {
      provider: () => new PrivateKeyProvider(process.env.PRIVKEY || null, 'https://rpc.tau1.artis.network'),
      network_id: 246785,
      gas: 4700000,
      gasPrice: 1000000000
    },
    sigma1_rpc: {
      provider: () => new PrivateKeyProvider(process.env.PRIVKEY || null, 'https://rpc.sigma1.artis.network'),
      network_id: 246529,
      gas: 4700000,
      gasPrice: 1000000000
    },
    core: {
      host: "localhost",
      port: "8777",
      network_id: "*",
      gas: 4700000,
      gasPrice: 1000000000
    },
    sokol: {
      host: "localhost",
      port: "8545",
      network_id: "*",
      gas: 4700000,
      gasPrice: 1000000000
    },
    coverage: {
      host: 'localhost',
      network_id: '*', // eslint-disable-line camelcase
      port: 8555,
      gas: 0xfffffffffff,
      gasPrice: 0x01,
    },
    ganache: {
      host: 'localhost',
      port: 8545,
      network_id: '*', // eslint-disable-line camelcase
      gasPrice: 1000000000
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  },
  mocha: {
    reporter: 'eth-gas-reporter',
    reporterOptions : {
      currency: 'USD',
      gasPrice: 1
    }
  }
};
