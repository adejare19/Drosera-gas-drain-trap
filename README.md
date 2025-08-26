# GasDrainTrap

A proof-of-concept trap contract built for Drosera.  
This trap monitors an arbitrary condition and drains funds to a safe address when triggered.  

## Features
- Whitelisting of allowed users
- Trigger condition check
- Drain function to safe address
- Tested with Foundry

## Setup
```bash
forge install
forge build
forge test -vv
