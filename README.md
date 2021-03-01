# TiсkTockContract
This is a prototype of future wake up contract for other contracts.

To wake up a contract, it must implement certain interface which is defined inside of TickTockContract.sol.\
This interface has one function - wakeMeUp() that accepts TvmCell as parameter.\
This cell may contrain any useful information that may be required for contract logic.

## Old Solidity support
FreeTON created a new version of the compiler, which requires specifying a different compiler version in the pragma. For older compilers use TickTockContractOldSlidity.sol

## Authors
* [Paul Mikhaylov](https://github.com/Pafaul)
* [Антон Щербаков](https://github.com/4erpakOFF)
* [Daniil Taldykin](https://github.com/DaTaLe) 
* [Andrey Nedobylsky](https://github.com/lailune) 
