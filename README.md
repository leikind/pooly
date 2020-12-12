# Modernized version of the pool codebase from book The Little Elixir & OTP Guidebook, using newer APIs like Registry and DynamicSupervisor

```
Pooly.status("pool-1")

worker1 = Pooly.checkout("pool-1")

Pooly.status("pool-1")

worker2 = Pooly.checkout("pool-1")

Pooly.status("pool-1")

Pooly.checkin("pool-1", worker1)
Pooly.checkin("pool-1", worker2)

Pooly.status("pool-1")
```
