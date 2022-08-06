# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
GAS_REPORT=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```


Some tips while installing the echidna environment:

- Make sure solc is installed. For that on mac,
brew update                                             
brew upgrade
brew tap ethereum/ethereum
brew install solidity

- Then install slither ,  pip3 install slither-analyzer --user 
- If encountered slither not found in path message, add the slither to the path variable. usually by going to sudo nano /etc/paths and adding the path to slither at the end.

