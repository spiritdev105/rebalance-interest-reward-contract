
Methods:

- deposit(amount)
- withdraw(amount, pools[])
- rebalance(fromPool, toPool, amount)
- setPool(pair, allowed)
- totalRate
- addFactory (for migrations)
- removeFactory

rebalance:
- result must end up with higher % than before
- next rebalance from toPool possible after 24 hours
- method pays for gas

withdraw:
- from staging first
- then from specified pools

deposit:
- into staging area

totalRate:

- for each pool:
  - get rate
  - sum rates


fromPool: $100k at 10%
toPool: $10k at 100%
total rate: 100 * 0.1 + 10 * 1 = 20%

->

fromPool: $50k at 20%
toPool: $60k at 50%
total rate: 50 * 0.2 + 60 * 0.5 = 40%