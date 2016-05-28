Yet another money system!
Warning! This is not intended for singleplayer use! The machines need to be protected using area protection mods like denaid or areas!
This mod adds three new machines to Minetest:

### Vending machine
This machine is used to sell and buy items. Players can throw items into a slot to sell them. Once items have been sold to the machine, other players can buy back these items.

Only items that are on the price list can be sold. The price list is editable inside init.lua and is a table containing items that can be sold and their selling price.
This list needs to be extended!You can help by adding prices for items of mods you use and are useful to be able to sell and posting them into this thread.

Every item sold to the machine is stored inside it (as metadata keys, not as inventory!). Players can buy items from the machine by accessing the price list and clicking the wanted item. This is only possible if the machine has any items of this type(any player sold that item to the machine before)

### Banking machine
It is used 1. to see the last money transactions a player did and 2. to transfer money to other players. The menu appearing on right-clicking it should be self-explaining.

### Player-controlled vending machine
The player-controlled vending machine is a tool for players to offer their items for sale. They act almost like the regular vending machines: the player puts his items in and other players buy them, just with three differences:
- the owner can always put in and take out items as he wants, no money is transferred;
- if another player buys an item, the amount is directly transferred to the owner's account and
- players other than the owner can't sell items to the machine.

----

The currency used is TestDollar, abbreviated by the Unicode character ŧ (a 't' with 2 horizontal dashes). TestDollar do not exist as items and are only present as value on a virtual bank account.
The machines do not have crafting recipes, get them by /giveme-ing economy:vending or economy:bank
Of course there is an API to interface with the TestDollar money system. See documentation in readme.txt inside mod directory. Depend on this mod to use.

Depends on:
default
dye
(only for the crafting)

License:
Code: LGPL 3.0 (Node definition for the machines by VanessaE (homedecor soda vending machine))
Machine model and textures(modified) by VanessaE (homedecor soda vending machine): CC-by-SA 3.0


API:
economy.deposit=function(player, amount, reason)
	deposits 'amount' to 'player's account. The 'reason' is used as text for the transaction history. Returns nil.

economy.moneyof=function(player)
	returns the amount of TestDollar the given player has.

economy.canpay=function(player, amount)
	returns true if the given 'player' has equal or more money than the given 'amount'

economy.withdraw=function(player, amount, reason)
	withdraws 'amount' from 'player's account. The 'reason' is used as text for the transaction history. Returns true if everything succeeded, or false if the player could not pay the given 'amount' (has too les money).