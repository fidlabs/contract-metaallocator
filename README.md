# Contract metaallocator

Management system to provide simpler allowance transfer between RKH, notaries, and clients

## Getting started

### Install foundry

[Foundry documentation.](https://book.getfoundry.sh/)

### Install deps

```shell
$ forge install
```

### Build contracts

```shell
$ forge build
```

### Run tests

```shell
$ forge clean && forge test --ffi -vv
```

### Deploy manually to Filecoin

```shell
forge create --rpc-url <your_rpc_url>  --private-key <your_private_key> src/Allocator.sol:Allocator
```

```shell
forge create --rpc-url <your_rpc_url>  --private-key <your_private_key> src/Factory.sol:Factory --constructor-args "<initial_owner_address>" "<implementation_address>"
```

```shell
cast send --rpc-url <your_rpc_url> --private-key=<your_private_key> <factory_contract_address> 'deploy(address)' <address_owner>
```

## Contracts

## Allocator.sol

Upgradeable smart contract to manage the allowance.

### Functions

`allowance(address allocator) public view returns (uint256 amount)`

Returns the amount of the allowance for the notary.

- **Parameters:**

  - `allocator`: Address of the notary whose allowance is queried.

- **Returns:**
  - `amount`: The amount of allowance for the specified notary.

`addAllowance(address allocatorAddress, uint256 amount) external onlyOwner`

Function to add an allowance for the notary. Invoked only by the contract owner.

- **Parameters:**
  - `allocatorAddress`: Address of the notary to add allowance for.
  - `amount`: The amount of allowance to add.

`setAllowance(address allocatorAddress, uint256 amount) external onlyOwner`

Function to set an allowance for the notary. Invoked only by the contract owner. Allowance can be set to 0.

- **Parameters:**
  - `allocatorAddress`: Address of the notary to set allowance for.
  - `amount`: The amount of allowance to set.

`addVerifiedClient(bytes calldata clientAddress, uint256 amount) external`

Function to add allowance to the client. Invoked only by the notary.

- **Parameters:**
  - `clientAddress`: Address of the client to add allowance for.
  - `amount`: The amount of allowance to add.

`getAllocators() external view returns (address[] memory)`

Function to return all active notaries.

- **Returns:**
  - `address[] memory`: Array of addresses representing all active notaries.

## Factory.sol

Smart contract for deploying and managing instances of Allocator.sol

### Constructor

`constructor(address initialOwner, address implementation_)`

Constructor to initialize the `Factory` contract.

- **Parameters:**
  - `initialOwner`: Address of the initial owner of the contract.
  - `implementation_`: Address of the implementation contract.

## Functions

`getContracts() external view returns (address[] memory)`

Function to retrieve the addresses of all deployed contracts.

- **Returns:**
  - `address[] memory`: Array of addresses representing deployed contracts.

`deploy(address owner) external`

Function to deploy a new instance of a contract.

- **Parameters:**
  - `owner`: Address of the owner for the new instance.

`setImplementation(address implementation_) external onlyOwner`

Function to set the implementation contract address.

- **Parameters:**
  - `implementation_`: Address of the new implementation contract.

### [ABIs](https://github.com/fidlabs/contract-metaallocator/tree/main/abis)

### Related tools

[Filecoin PLUS](https://filplus-registry.netlify.app/)

Website to communicate with the smart contract

[contract-metaallocator-cli](https://github.com/fidlabs/contract-metaallocator-cli)

CLI to communicate with the smart contract
