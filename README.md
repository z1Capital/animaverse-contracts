# Networks

You can replace `NETWORK_NAME` by following options
`mainnet`, `rinkeby`, `localhost`, `hardhat`

# Requirements

Nodejs v16 or higher

## 1. Install dependencies

```sh
npm i
```

## 2. Build

```sh
npm run build
```

## 3. Deploy

### 3.1 Add private key

Add deployer private key in a file with `.secret` name at root of the project.

### 3.2 run task

```sh
INFURA_KEY=API_KEY npm run deploy --network NETWORK_NAME
```

## 4. Verify

```sh
ETHSCAN_KEY=API_KEY npm run verify --network NETWORK_NAME CONTRACT_ADDRESS "param1(contractMetadata)" " param2(baseURI)"
```

## 5. Audit
```sh
mythx --api-key=MYTHX_API_KEY analyze
```

## 6. Test
Add more private keys to `.secret` file (at least 3).
```sh
npm run test
```
