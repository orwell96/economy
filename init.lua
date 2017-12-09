--MONEY!!!
-- ŧ

-- Boilerplate to support localized strings if intllib mod is installed.
local S
if minetest.get_modpath("intllib") then
	S = intllib.Getter()
else
	-- If you use insertions, but not insertion escapes this will work:
	S = function(s,a,...)a={a,...}return s:gsub("@(%d+)",function(n)return a[tonumber(n)]end)end
end

economy={}

--Limit stacks players may hold in machines. 10 = one page, 20 = two pages, etc.
--Set machinecapacity=0 for unlimited.
economy.machinecapacity=30

economy.itemprices_pr={
	["default:wood"]=1,
	["default:tree"]=4,
	--["default:cobble"]=1,
	["default:stone"]=2,
	["default:coalblock"]=50,
	["default:iron"]=100,
	["moreores:tin_block"]=100,
	["default:bronzeblock"]=300,
	["default:obsidian"]=450,
	["moreores:silver_block"]=500,
	["default:goldblock"]=600,
	["default:mese"]=1111,
	["intersecting:luxore"]=100,
	["uw:glowstone"]=300,
	["homedecor:piano"]=3773,
	["moreores:mithril_block"]=4444,
	["nyancat:nyancat_rainbow"]=10000,
	["nyancat:nyancat"]=50000,
	["default:apple"]=2,
	["farming:wheat"]=3,
	--["default:dirt"]=2,
	--["default:sand"]=2,
	["default:desert_sand"]=2,
	["default:mossycobble"]=10,
	
	--["group:leaves"]=1,
}
economy.mobkillrewards={
	["mobs:sand_monster"]=10,
	["mobs:stone_monster"]=100,
	["mobs:kitten"]=20,
	["mobs:cow"]=30,
	["mobs:mese_monster"]=200,
	["mobs:dungeonmaster"]=2500,
	["mobs:oerkki"]=350,
}

economy.itemprices={}
minetest.after(0, function()
	for k,v in pairs(economy.itemprices_pr) do
		if not minetest.registered_items[k] then
			print("[economy]unknown item in prices list: "..k)
		else
			economy.itemprices[k]=v
		end
	end
end)

economy.balance={}
economy.accountlog={}

--[[
	save version history:
	{balance=economy.balance, accountlog=economy.accountlog, version=1}
]]

economy.fpath=minetest.get_worldpath().."/economy"
local file, err = io.open(economy.fpath, "r")
if not file then
	economy.balance = economy.balance or {}
	local er=err or "Unknown Error"
	print("[economy]Failed loading economy save file "..er)
else
	local deserialize=minetest.deserialize(file:read("*a"))
	economy.balance = deserialize.balance or deserialize
	economy.accountlog = deserialize.accountlog or {}
	if type(economy.balance) ~= "table" then
		economy.balance={}
	end
	if type(economy.accountlog) ~= "table" then
		economy.balance={}
	end
	file:close()
end


economy.save = function()
local datastr = minetest.serialize({balance=economy.balance, accountlog=economy.accountlog, version=1})
if not datastr then
	minetest.log("error", "[economy] Failed to serialize balance data!")
	return
end
local file, err = io.open(economy.fpath, "w")
if err then
	return err
end
file:write(datastr)
file:close()
end

--economy globalstep
economy.save_cntdn=10
minetest.register_globalstep(function(dtime)
	if economy.save_cntdn<=0 then
		economy.save()
		economy.save_cntdn=10 --10 seconds interval!
	end
	economy.save_cntdn=economy.save_cntdn-dtime
end)

local svm_cbox = {
	type = "fixed",
	fixed = {-0.5, -0.5, -0.5, 0.5, 1.5, 0.5}
}

minetest.register_node("economy:vending", {
	drawtype = "mesh",
	description = S("Vending Machine"),
	
	mesh = "economy_vending.obj",
	tiles = {"economy_vending.png"},
	groups = {snappy=3},
	selection_box = svm_cbox,
	collision_box = svm_cbox,
	light_source = 10,
	inventory_image = "economy_vending_inv.png",
	paramtype = "light",
	paramtype2 = "facedir",
	groups = {cracky=2},
	on_rightclick = function(pos, node, clicker, itemstack)
		economy.open_vending(pos, clicker)
	end,
	on_place = function(itemstack, placer, pointed_thing)
		local pos = pointed_thing.above
		if minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name ~= "air" then
			minetest.chat_send_player( placer:get_player_name(), S("Not enough vertical space to place a @1!", S("Vending Machine")) )
			return
		end
		return minetest.item_place(itemstack, placer, pointed_thing)
	end,
	after_place_node=function(pos, placer, itemstack, pointed_thing)
		local meta=minetest.get_meta(pos)
		if meta then
			meta:set_string("infotext", S("Vending Machine"))
			local inv=meta:get_inventory()
			inv:set_size("main", 0)
			inv:set_size("sell", 1)
		end
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if listname=="sell" then
			if economy.itemprices[stack:get_name()] then
				return stack:get_count()
			else
				economy.formspecs.vendingsell.open(player, pos, true)
			end
		end
		return 0
	end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
	return 0
	end,
	allow_metadata_inventory_move = function(pos, listname, index, stack, player)
		return 0
	end,
	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		if listname=="sell" then
			local priceper=economy.itemprices[stack:get_name()]
			economy.deposit(player, priceper*stack:get_count(), S("Selling @1x @2", stack:get_count(), (minetest.registered_items[stack:get_name()] and minetest.registered_items[stack:get_name()].description.." ("..stack:get_name()..")" or stack:get_name()) ) )
			
			local meta=minetest.get_meta(pos)
			local inv=meta:get_inventory()
			if meta:get_int(stack:get_name()) then
				local i=meta:get_int(stack:get_name())
				i=i+stack:get_count()
				meta:set_int(stack:get_name(), i)
			end
			
			inv:set_stack("sell", 1, "ignore 0")
			economy.formspecs.vendingsell.open(player, pos)
		end
	end
})
minetest.register_node("economy:bank", {
	drawtype = "mesh",
	description = S("Banking Machine"),
	
	mesh = "economy_vending.obj",
	tiles = {"economy_bank.png"},
	groups = {snappy=3},
	selection_box = svm_cbox,
	collision_box = svm_cbox,
	light_source = 10,
	inventory_image = "economy_bank_inv.png",
	paramtype = "light",
	paramtype2 = "facedir",
	groups = {cracky=2},
	on_rightclick = function(pos, node, clicker, itemstack)
		economy.open_bank(pos, clicker)
	end,
	on_place = function(itemstack, placer, pointed_thing)
		local pos = pointed_thing.above
		if minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name ~= "air" then
			minetest.chat_send_player( placer:get_player_name(), S("Not enough vertical space to place a @1!", S("Vending Machine")) )
			return
		end
		return minetest.item_place(itemstack, placer, pointed_thing)
	end,
	after_place_node=function(pos, placer, itemstack, pointed_thing)
		local meta=minetest.get_meta(pos)
		if meta then
			meta:set_string("infotext", S("Banking Machine"))
		end
	end,
})
minetest.register_node("economy:playervendor", {
	drawtype = "mesh",
	description = S("Player-operated Vending Machine"),
	
	mesh = "economy_vending.obj",
	tiles = {"economy_playervendor.png"},
	selection_box = svm_cbox,
	collision_box = svm_cbox,
	light_source = 10,
	inventory_image = "economy_playervendor_inv.png",
	paramtype = "light",
	paramtype2 = "facedir",
	groups = {cracky=2},
	on_rightclick = function(pos, node, clicker, itemstack)
		economy.open_playervendor(pos, clicker)
	end,
	on_place = function(itemstack, placer, pointed_thing)
		local pos = pointed_thing.above
		if minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name ~= "air" then
			minetest.chat_send_player( placer:get_player_name(), S("Not enough vertical space to place a @1!", S("Player-operated Vending Machine")) )
			return
		end
		return minetest.item_place(itemstack, placer, pointed_thing)
	end,
	after_place_node=function(pos, placer, itemstack, pointed_thing)
		local meta=minetest.get_meta(pos)
		if meta then
			meta:set_string("infotext", S("Vending machine of @1",placer:get_player_name()))
			meta:set_string("owner", placer:get_player_name())
			local inv=meta:get_inventory()
			inv:set_size("main", 0)
			inv:set_size("sell", 1)
		end
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if listname=="sell" then
			local meta=minetest.get_meta(pos)
			local stacklist={}
			local nametable={}
			local metatable=meta:to_table().fields
			for i,j in pairs(metatable) do
				local category, item=string.match(i, "^i([cp])_(.+)$")
				if category and item then
					if not nametable[item] then
						nametable[item]={}
					end
					nametable[item][category]=meta:get_int("i"..category.."_"..item)
				end
			end
			for i,j in pairs(nametable) do
				if j.p and j.c and j.c>0 then
					table.insert(stacklist,1,{name=i, price=j.p, count=j.c})
				end
			end
			if #stacklist<economy.machinecapacity or economy.machinecapacity==0 then
				return stack:get_count()
			else
				economy.formspecs.pvendinginput.open(player, pos, true)
				return 0
			end
		end
		return 0
	end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		return 0
	end,
	allow_metadata_inventory_move = function(pos, listname, index, stack, player)
		return 0
	end,
	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		if listname=="sell" then
			local meta=minetest.get_meta(pos)
			local inv=meta:get_inventory()
			local i=meta:get_int("ic_"..stack:get_name())
			i=i+stack:get_count()
			meta:set_int("ic_"..stack:get_name(), i)
			
			if meta:get_int("ip_"..stack:get_name())==0 then
				meta:set_int("ip_"..stack:get_name(),economy.itemprices[stack:get_name()] or 100)
			end
			inv:set_stack("sell", 1, "ignore 0")
			economy.formspecs.pvendinginput.open(player, pos)
		end
	end
})
economy.pname=function(player_or_name)
	if player_or_name then
		if type(player_or_name)=="userdata" and player_or_name.get_player_name then
			return player_or_name:get_player_name()
		end
	end
	return player_or_name
end
economy.deposit=function(player, amount, reason)
	local pname=economy.pname(player)
	if not economy.balance[pname] then
		economy.balance[pname]=0
	end
	economy.balance[pname]=economy.balance[pname]+amount
	if not economy.accountlog[pname] then
		economy.accountlog[pname]={}
	end
	table.insert(economy.accountlog[pname], 1, {action=reason or S("Unknown deposition"), amount="+ "..amount})
end
economy.moneyof=function(player)
	local pname=economy.pname(player)
	if not economy.balance[pname] then
		economy.balance[pname]=0
	end
	return economy.balance[pname]
end
economy.canpay=function(player, amount)
	local pname=economy.pname(player)
	if not economy.balance[pname] then
		economy.balance[pname]=0
	end
	return economy.balance[pname]>=amount
end
economy.buyprice=function(sellprice)
	return math.ceil(sellprice*1.2)
end
economy.withdraw=function(player, amount, reason)
	local pname=economy.pname(player)
	if not economy.balance[pname] then
		economy.balance[pname]=0
	end
	if not economy.canpay(player, amount) then
		return false
	end
	economy.balance[pname]=economy.balance[pname]-amount
	if not economy.accountlog[pname] then
		economy.accountlog[pname]={}
	end
	table.insert(economy.accountlog[pname], 1, {action=reason or S("Unknown withdrawal"), amount="- "..amount})
	return true
end
economy.itemdesc=function(iname)
	return minetest.registered_items[iname] and minetest.registered_items[iname].description or iname
end
economy.itemdesc_ext=function(iname)
	return minetest.registered_items[iname] and minetest.registered_items[iname].description.." ("..iname..")" or iname
end

economy.formspecs={
	
	vendingsell={
		open=function(player, pos, cantsell)
			minetest.show_formspec(economy.pname(player), "economy_vendingsell_"..minetest.pos_to_string(pos), [[
				size[8,8]
				label[0,0;]]..S("Your balance: @1ŧ",economy.moneyof(player:get_player_name()))..[[]
				button[1,1;3,1;buy;]]..S("Buy Items/Price List")..[[]
				list[nodemeta:]]..pos.x..","..pos.y..","..pos.z..[[;sell;2,2;1,1;]
				]]..(cantsell and "label[1,3;"..S("You can't sell this item. Please see price list.").."]" or "label[1,3;"..S("Put items here to sell them.").."]")..default.gui_bg..default.gui_bg_img..[[
				list[current_player;main;0,4;8,4;]
				]])
		end,
		hdlr=function(player, restformname, fields)
			if fields.buy then
				local pos=minetest.string_to_pos(restformname)
				economy.formspecs.vendingbuy.open(player, pos)
			end
		end
	},
	vendingbuy={
		open=function(player, pos, page, shownoavailable)
			page=tonumber(page)
			if not page then
				page=1
			end
			local meta=minetest.get_meta(pos)
			if not meta then return end
			
			local idsp={}
			for k,v in pairs(economy.itemprices) do
				if meta:get_int(k)>0 then
					table.insert(idsp,1,{name=k, price=v, count=meta:get_int(k)})
				else
					table.insert(idsp,{name=k, price=v, count=0})
				end
			end
			local totalPages=math.ceil(#idsp/10)
			if page<1 then page=1 end
			if page>totalPages then page=totalPages end
			
			local formspec="size[8,8]button[1,6.5;3,1;sell;"..S("Sell items").."]label[0,0;"..S("Your balance: @1ŧ",economy.moneyof(player:get_player_name())).."]"
			..default.gui_bg..default.gui_bg_img.."]"
			if page~=1 then formspec=formspec.."button[5,6.5;1,1;page_"..(page-1)..";<<]" end
			if page~=totalPages then formspec=formspec.."button[6,6.5;1,1;page_"..(page+1)..";>>]" end
			
			
			for i=page*10-9,page*10 do
				if idsp[i] then
					if idsp[i].count>0 then
						--formspec=formspec.."item_image_button[1,"..(((i-1)%10)*0.5+1)..";0.6,0.6;"..idsp[i].name..";buy_"..idsp[i].name..";]"
						--.."label[2,"..(((i-1)%10)*0.5+1)..";Verkauf "..idsp[i].price.." ŧ / Kauf "..economy.buyprice(idsp[i].price).." ŧ ("..idsp[i].count.." verfügbar)]"
						formspec=formspec.."item_image_button[0,"..(((i-1)%10)*0.5+1)..";0.6,0.6;"..idsp[i].name..";buy_"..idsp[i].name..";]"..
						"label[0.5,"..(((i-1)%10)*0.5+1)..";("..idsp[i].count..") "..economy.itemdesc(idsp[i].name).."]"..
						"label[4,"..(((i-1)%10)*0.5+1)..";"..S("Buy @1 ŧ / Sell @2 ŧ", economy.buyprice(idsp[i].price), idsp[i].price).."]"
					else
						--formspec=formspec.."item_image_button[1,"..(((i-1)%10)*0.5+1)..";0.6,0.6;"..idsp[i].name..";noavail_"..(page)..";]"
						--.."label[2,"..(((i-1)%10)*0.5+1)..";Verkauf "..idsp[i].price.." ŧ / Kauf "..economy.buyprice(idsp[i].price).." ŧ (nicht verfügbar)]"
						formspec=formspec.."item_image_button[0,"..(((i-1)%10)*0.5+1)..";0.6,0.6;"..idsp[i].name..";noavail_"..(page)..";X]"..
						"label[0.5,"..(((i-1)%10)*0.5+1)..";(-) "..economy.itemdesc(idsp[i].name).."]"..
						"label[4,"..(((i-1)%10)*0.5+1)..";"..S("Sell @1 ŧ",idsp[i].price).."]"
						
					end
				end
			end
			if shownoavailable then
				formspec=formspec.."label[0,7.5;"..S("The selected item is not available here!").."]"
			end
			
			minetest.show_formspec(economy.pname(player), "economy_vendingbuy_"..minetest.pos_to_string(pos), formspec)
		end,
		hdlr=function(player, restformname, fields)
			if fields.sell then
				local pos=minetest.string_to_pos(restformname)
				economy.formspecs.vendingsell.open(player, pos)
			elseif not fields.quit then
				local pos=minetest.string_to_pos(restformname)
				for k,_ in pairs(fields) do
					local d=string.match(k, "^buy_(.+)$")
					if d then
						economy.formspecs.vendingbuyitem.open(player, pos, d)
					end
					d=string.match(k, "^page_(%d+)$")
					if d then
						economy.formspecs.vendingbuy.open(player, pos, d)
						return
					end
					d=string.match(k, "^noavail_(%d+)$")
					if d then
						economy.formspecs.vendingbuy.open(player, pos, d, true)
						return
					end
				end
			end
		end
	},
	vendingbuyitem={
		open=function(player, pos, iname, buying, cantafford, toomanyitems)
			
			local meta=minetest.get_meta(pos)
			if not meta then return end
			local available=meta:get_int(iname)
			if available<1 then return end
			
			if not minetest.registered_items[iname] then return end
			
			local maxcount=math.min(minetest.registered_items[iname].stack_max, available)
			local buyprice=economy.buyprice(economy.itemprices[iname])
			
			local buyingstr=""
			if cantafford then
				buyingstr="label[0,5;"..S("Insufficient funds!").."]"
			elseif toomanyitems then
				buyingstr="label[0,5;"..S("Inventory full!").."]"
			elseif buying then
				if buying>maxcount then
					buyingstr="label[0,5;"..S("You specified too many items.").."]"
				elseif buying<1 then
					buyingstr="label[0,5;"..S("You can't buy negative amounts of items!").."]"
				else
					buyingstr="label[0,5;"..S("@1 items cost @2 ŧ.",buying,buying*buyprice).."]"
				end
			end
			
			minetest.show_formspec(economy.pname(player), "economy_vendingbuyitem_"..minetest.pos_to_string(pos).."_"..iname, 
				"size[8,8]item_image[5,2;2,2;"..iname.."]"..
				default.gui_bg..default.gui_bg_img.."]"..
				"label[0,0;"..S("Your balance: @1ŧ",economy.moneyof(economy.pname(player))).."]"..
				"label[0,1;"..S("You are buying @1",economy.itemdesc_ext(iname)).."]"..
				"label[0,2;"..S("Price per item: @1 ŧ",buyprice).."]"..
				"label[0,3;"..S("There are @1 items available.",available).."]"..
				"label[0,4;"..S("You can buy a maximum of @1 in one step.", maxcount).."]"..
				buyingstr..
				"field[0.5,6.4;1.5,1;icnt;"..S("count:")..";"..(buying or maxcount).."]button[2,6;3,1;spr;"..S("Show price").."]button[5,6;3,1;buy;"..S("Buy!").."]button[2,7;3,1;back;"..S("Back").."]"
				
				
			)
		end,
		hdlr=function(player, restformname, fields)
			local posstr, iname=string.match(restformname, "^([^_]+)_(.+)$")
			--print(restformname)
			local pos=posstr and minetest.string_to_pos(posstr)
			if fields.spr then
				economy.formspecs.vendingbuyitem.open(player, pos, iname, tonumber(fields.icnt))
			elseif fields.back then
				economy.formspecs.vendingbuy.open(player, pos, 1)
			elseif fields.buy then
				local tobuy=tonumber(fields.icnt)
				if not tobuy then
					economy.formspecs.vendingbuyitem.open(player, pos, iname)
					return
				end
				
				local meta=minetest.get_meta(pos)
				if not meta then return end
				local available=meta:get_int(iname)
				if available<1 then 
					economy.formspecs.vendingbuy.open(player, pos, 1)
				end
				
				if not minetest.registered_items[iname] then return end
				
				local maxcount=math.min(minetest.registered_items[iname].stack_max, available)
				local buyprice=economy.buyprice(economy.itemprices[iname])
				
				if tobuy>maxcount or tobuy<1 then
					economy.formspecs.vendingbuyitem.open(player, pos, iname, tobuy)
					return
				end
				local totalprice=tobuy*buyprice
				if economy.canpay(player, totalprice) then
					local inv=player:get_inventory()
					local stack=ItemStack(iname.." "..tobuy)
					if inv:room_for_item("main", stack) then
						inv:add_item("main", stack)
						meta:set_int(iname, available-tobuy)
						economy.withdraw(player, totalprice, S("Bought @1x @2", tobuy, economy.itemdesc_ext(iname)))
						economy.formspecs.vendingbuy.open(player, pos, 1)
					else
						economy.formspecs.vendingbuyitem.open(player, pos, iname, tobuy, false, true)
					end
				else
					economy.formspecs.vendingbuyitem.open(player, pos, iname, tobuy, true)
					return
				end
				
			end
			
		end
	},
	pvendingown={
		open=function(player, pos, page, shownoavailable)
			page=tonumber(page)
			if not page then
				page=1
			end
			local meta=minetest.get_meta(pos)
			if not meta then return end
			if not meta:get_string("owner")==economy.pname(player) then return end
			
			local idsp={}
			local inametbl={}
			local metatable=meta:to_table().fields
			for k,v in pairs(metatable) do
				-- c:count, p: price
				-- format: i[c/p]_iname
				local what,iname=string.match(k, "^i([cp])_(.+)$")
				if what and iname then
					if not inametbl[iname] then inametbl[iname]={} end
					inametbl[iname][what]=meta:get_int("i"..what.."_"..iname)
				end
			end
			for k,v in pairs(inametbl) do
				if v.p and v.c and v.c>0 then
					table.insert(idsp,1,{name=k, price=v.p, count=v.c})
				end
			end
			
			local totalPages=math.ceil(#idsp/10)
			if page<1 then page=1 end
			if page>totalPages then page=totalPages end
			
			local formspec="size[8,8]button[1,6.5;3,1;sell;"..S("Add items to sell").."]label[0,0;"..S("Your balance: @1ŧ",economy.moneyof(player:get_player_name())).." "..S("\nThis machine sells:").."]"
			..default.gui_bg..default.gui_bg_img.."]"
			if #idsp==0 then
				formspec=formspec.."label[0,2;"..S("This machine has nothing to sell at the moment.").."]"
			end
			
			if page~=1 then formspec=formspec.."button[5,6.5;1,1;page_"..(page-1)..";<<]" end
			if page~=totalPages then formspec=formspec.."button[6,6.5;1,1;page_"..(page+1)..";>>]" end
			
			
			for i=page*10-9,page*10 do
				if idsp[i] then
					if idsp[i].count>0 then
						--formspec=formspec.."item_image_button[1,"..(((i-1)%10)*0.5+1)..";0.6,0.6;"..idsp[i].name..";buy_"..idsp[i].name..";]"
						--.."label[2,"..(((i-1)%10)*0.5+1)..";Verkauf "..idsp[i].price.." ŧ / Kauf "..economy.buyprice(idsp[i].price).." ŧ ("..idsp[i].count.." verfügbar)]"
						formspec=formspec.."item_image_button[0,"..(((i-1)%10)*0.5+1)..";0.6,0.6;"..idsp[i].name..";buy_"..idsp[i].name..";]"..
						"label[0.5,"..(((i-1)%10)*0.5+1)..";("..idsp[i].count..") "..economy.itemdesc(idsp[i].name).."]"..
						"label[4,"..(((i-1)%10)*0.5+1)..";"..S("Price: @1ŧ", idsp[i].price).."]"..
						"button[6,"..(((i-1)%10)*0.5+1)..";2,0.6;chpr_"..idsp[i].name..";"..S("Change").."]"
					end
				end
			end
			formspec=formspec.."label[0,7.5;"..S("Click item icons to retrieve items.").."]"
			
			minetest.show_formspec(economy.pname(player), "economy_pvendingown_"..minetest.pos_to_string(pos), formspec)
		end,
		hdlr=function(player, restformname, fields)
			if fields.sell then
				local pos=minetest.string_to_pos(restformname)
				economy.formspecs.pvendinginput.open(player, pos)
			elseif not fields.quit then
				local pos=minetest.string_to_pos(restformname)
				for k,_ in pairs(fields) do
					local d=string.match(k, "^buy_(.+)$")
					if d then
						economy.formspecs.pvendingitemtakeout.open(player, pos, d)
					end
					local d=string.match(k, "^chpr_(.+)$")
					if d then
						economy.formspecs.pvendingitemchpr.open(player, pos, d)
					end
					d=string.match(k, "^page_(%d+)$")
					if d then
						economy.formspecs.pvendingown.open(player, pos, d)
						return
					end
				end
			end
		end
	},
	pvendingitemchpr={
		open=function(player, pos, iname)
			local meta=minetest.get_meta(pos)
			if not meta then return end
			if not meta:get_string("owner")==economy.pname(player) then return end
			
			local price=meta:get_int("ip_"..iname)
			
			minetest.show_formspec(economy.pname(player), "economy_pvendingitemchpr_"..minetest.pos_to_string(pos).."_"..iname, 
				default.gui_bg..default.gui_bg_img.."field[newprice;"..S("New price for @1:",economy.itemdesc(iname))..";"..(price or "").."]"
			)
		end,
		hdlr=function(player, restformname, fields)
			local posstr, iname=string.match(restformname, "^([^_]+)_(.+)$")
			--print(restformname)
			local pos=posstr and minetest.string_to_pos(posstr)
			if tonumber(fields.newprice) and tonumber(fields.newprice)>0 then
				local meta=minetest.get_meta(pos)
				if not meta then return end
				if not meta:get_string("owner")==economy.pname(player) then return end
				meta:set_int("ip_"..iname, tonumber(fields.newprice))
				economy.formspecs.pvendingown.open(player, pos)
			end
		end
	},
	pvendingitemtakeout={
		open=function(player, pos, iname, buying, toomanyitems)
			
			local meta=minetest.get_meta(pos)
			if not meta then return end
			if not meta:get_string("owner")==economy.pname(player) then return end
			local available=meta:get_int("ic_"..iname)
			if available<1 then return end
			
			if not minetest.registered_items[iname] then return end
			
			local maxcount=math.min(minetest.registered_items[iname].stack_max, available)
			
			local buyingstr=""
			if toomanyitems then
				buyingstr="label[0,5;"..S("Inventory full!").."]"
			elseif buying then
				if buying>maxcount then
					buyingstr="label[0,5;"..S("You specified too many items.").."]"
				elseif buying<1 then
					buyingstr="label[0,5;"..S("You can't buy negative amounts of items!").."]"
				end
			end
			
			minetest.show_formspec(economy.pname(player), "economy_pvendingitemtakeout_"..minetest.pos_to_string(pos).."_"..iname, 
				"size[8,8]item_image[5,2;2,2;"..iname.."]"..
				default.gui_bg..default.gui_bg_img..
				"label[0,0;"..S("Your balance: @1ŧ",economy.moneyof(economy.pname(player))).."]"..
				"label[0,1;"..S("You are taking @1 out of the machine.",economy.itemdesc_ext(iname)).."]"..
				"label[0,3;"..S("There are @1 items available.",available).."]"..
				"label[0,4;"..S("You can take out a maximum of @1 in one step.", maxcount, S("buy")).."]"..
				buyingstr..
				"field[0.5,6.4;1.5,1;icnt;"..S("count:")..";"..(buying or maxcount).."]button[2,6;3,1;buy;"..S("Take!").."]button[2,7;3,1;back;"..S("Back").."]"
			)
		end,
		hdlr=function(player, restformname, fields)
			local posstr, iname=string.match(restformname, "^([^_]+)_(.+)$")
			--print(restformname)
			local pos=posstr and minetest.string_to_pos(posstr)
			if fields.back then
				economy.formspecs.pvendingown.open(player, pos, 1)
			elseif fields.buy then
				local tobuy=tonumber(fields.icnt)
				if not tobuy then
					economy.formspecs.pvendingitemtakeout.open(player, pos, iname)
					return
				end
				
				local meta=minetest.get_meta(pos)
				if not meta then return end
				if not meta:get_string("owner")==economy.pname(player) then return end
				local available=meta:get_int("ic_"..iname)
				if available<1 then 
					economy.formspecs.pvendingown.open(player, pos, 1)
				end
				
				if not minetest.registered_items[iname] then return end
				
				local maxcount=math.min(minetest.registered_items[iname].stack_max, available)
				
				if tobuy>maxcount or tobuy<1 then
					economy.formspecs.pvendingitemtakeout.open(player, pos, iname, tobuy)
					return
				end
				local inv=player:get_inventory()
				local stack=ItemStack(iname.." "..tobuy)
				if inv:room_for_item("main", stack) then
					inv:add_item("main", stack)
					meta:set_int("ic_"..iname, available-tobuy)
					economy.formspecs.pvendingown.open(player, pos, 1)
				else
					economy.formspecs.pvendingitemtakeout.open(player, pos, iname, tobuy, true)
				end
				
			end
			
		end
	},
	pvendinginput={
		open=function(player, pos, cantadd)
			minetest.show_formspec(economy.pname(player), "economy_pvendinginput_"..minetest.pos_to_string(pos), [[
				size[8,8]
				label[0,0;]]..S("Your balance: @1ŧ",economy.moneyof(player:get_player_name()))..[[]
				button[1,1;3,1;buy;]]..S("Back")..[[]
				list[nodemeta:]]..pos.x..","..pos.y..","..pos.z..[[;sell;2,2;1,1;]
				]]..(cantadd and "label[1,3;"..S("This vending machine is full.").."]" or "label[1,3;"..S("Put items here to offer them for sale.").."]")..[[
				list[current_player;main;0,4;8,4;]
			]]..default.gui_bg..default.gui_bg_img)
		end,
		hdlr=function(player, restformname, fields)
			if fields.buy then
				local pos=minetest.string_to_pos(restformname)
				economy.formspecs.pvendingown.open(player, pos)
			end
		end
	},
	--other players system
	pvending={
		open=function(player, pos, page)
			page=tonumber(page)
			if not page then
				page=1
			end
			local meta=minetest.get_meta(pos)
			if not meta then return end
			
			local idsp={}
			local inametbl={}
			local metatable=meta:to_table().fields
			for k,v in pairs(metatable) do
				-- c:count, p: price
				-- format: i[c/p]_iname
				local what,iname=string.match(k, "^i([cp])_(.+)$")
				if what and iname then
					if not inametbl[iname] then inametbl[iname]={} end
					inametbl[iname][what]=meta:get_int("i"..what.."_"..iname)
					
				end
			end
			for k,v in pairs(inametbl) do
				if v.p and v.c and v.c>0 then
					table.insert(idsp,1,{name=k, price=v.p, count=v.c})
				end
			end
			
			local totalPages=math.ceil(#idsp/10)
			if page<1 then page=1 end
			if page>totalPages then page=totalPages end
			
			local formspec="size[8,8]label[0,7.5;"..S("Click item icons to purchase items.").."]label[0,0;"..S("Your balance: @1ŧ",economy.moneyof(player:get_player_name())).." "..S("\nMachine of @1",meta:get_string("owner").." sells:").."]"
			..default.gui_bg..default.gui_bg_img.."]"
			if #idsp==0 then
				formspec=formspec.."label[0,2;"..S("This machine has nothing to sell at the moment.").."]"
			end
			
			if page~=1 then formspec=formspec.."button[5,6.5;1,1;page_"..(page-1)..";<<]" end
			if page~=totalPages then formspec=formspec.."button[6,6.5;1,1;page_"..(page+1)..";>>]" end
			
			for i=page*10-9,page*10 do
				if idsp[i] then
					if idsp[i].count>0 then
						--formspec=formspec.."item_image_button[1,"..(((i-1)%10)*0.5+1)..";0.6,0.6;"..idsp[i].name..";buy_"..idsp[i].name..";]"
						--.."label[2,"..(((i-1)%10)*0.5+1)..";Verkauf "..idsp[i].price.." ŧ / Kauf "..economy.buyprice(idsp[i].price).." ŧ ("..idsp[i].count.." verfügbar)]"
						formspec=formspec.."item_image_button[0,"..(((i-1)%10)*0.5+1)..";0.6,0.6;"..idsp[i].name..";buy_"..idsp[i].name..";]"..
						"label[0.5,"..(((i-1)%10)*0.5+1)..";("..idsp[i].count..") "..economy.itemdesc(idsp[i].name).."]"..
						"label[4,"..(((i-1)%10)*0.5+1)..";"..S("Price: @1ŧ", idsp[i].price).."]"
					end
				end
			end
			
			minetest.show_formspec(economy.pname(player), "economy_pvending_"..minetest.pos_to_string(pos), formspec)
		end,
		hdlr=function(player, restformname, fields)
			if not fields.quit then
				local pos=minetest.string_to_pos(restformname)
				for k,_ in pairs(fields) do
					local d=string.match(k, "^buy_(.+)$")
					if d then
						economy.formspecs.pvendingbuyitem.open(player, pos, d)
					end
					d=string.match(k, "^page_(%d+)$")
					if d then
						economy.formspecs.pvending.open(player, pos, d)
						return
					end
				end
			end
		end
	},
	pvendingbuyitem={
		open=function(player, pos, iname, buying, cantafford, toomanyitems)
			
			local meta=minetest.get_meta(pos)
			if not meta then return end
			local available=meta:get_int("ic_"..iname)
			if available<1 then return end
			
			if not minetest.registered_items[iname] then return end
			
			local maxcount=math.min(minetest.registered_items[iname].stack_max, available)
			local buyprice=meta:get_int("ip_"..iname)
			
			local buyingstr=""
			if cantafford then
				buyingstr="label[0,5;"..S("Insufficient funds!").."]"
			elseif toomanyitems then
				buyingstr="label[0,5;"..S("Inventory full!").."]"
			elseif buying then
				if buying>maxcount then
					buyingstr="label[0,5;"..S("You specified too many items.").."]"
				elseif buying<1 then
					buyingstr="label[0,5;"..S("You can't buy negative amounts of items!").."]"
				else
					buyingstr="label[0,5;"..S("@1 items cost @2 ŧ.",buying,buying*buyprice).."]"
				end
			end
			
			minetest.show_formspec(economy.pname(player), "economy_pvendingbuyitem_"..minetest.pos_to_string(pos).."_"..iname, 
			"size[8,8]item_image[5,2;2,2;"..iname.."]"..
			default.gui_bg..default.gui_bg_img..
			"label[0,0;"..S("Your balance: @1ŧ",economy.moneyof(economy.pname(player))).."]"..
			"label[0,1;"..S("You are buying @1",economy.itemdesc_ext(iname)).."]"..
			"label[0,2;"..S("Price per item: @1 ŧ",buyprice).."]"..
			"label[0,3;"..S("There are @1 items available.",available).."]"..
			"label[0,4;"..S("You can buy a maximum of @1 in one step.", maxcount).."]"..
			buyingstr..
				"field[0.5,6.4;1.5,1;icnt;"..S("count:")..";"..(buying or maxcount).."]button[2,6;3,1;spr;"..S("Show price").."]button[5,6;3,1;buy;"..S("Buy!").."]button[2,7;3,1;back;"..S("Back").."]"
			)
		end,
		hdlr=function(player, restformname, fields)
			local posstr, iname=string.match(restformname, "^([^_]+)_(.+)$")
			--print(restformname)
			local pos=posstr and minetest.string_to_pos(posstr)
			if fields.spr then
				economy.formspecs.pvendingbuyitem.open(player, pos, iname, tonumber(fields.icnt))
			elseif fields.back then
				economy.formspecs.pvending.open(player, pos, 1)
			elseif fields.buy then
				local tobuy=tonumber(fields.icnt)
				if not tobuy then
					economy.formspecs.pvendingbuyitem.open(player, pos, iname)
					return
				end
				
				local meta=minetest.get_meta(pos)
				if not meta then return end
				local available=meta:get_int("ic_"..iname)
				if available<1 then 
					economy.formspecs.pvending.open(player, pos, 1)
				end
				
				if not minetest.registered_items[iname] then return end
				
				local maxcount=math.min(minetest.registered_items[iname].stack_max, available)
				local buyprice=meta:get_int("ip_"..iname)
				
				if tobuy>maxcount or tobuy<1 then
					economy.formspecs.vendingbuyitem.open(player, pos, iname, tobuy)
					return
				end
				local totalprice=tobuy*buyprice
				if economy.canpay(player, totalprice) then
					local inv=player:get_inventory()
					local stack=ItemStack(iname.." "..tobuy)
					if inv:room_for_item("main", stack) then
						inv:add_item("main", stack)
						meta:set_int("ic_"..iname, available-tobuy)
						economy.withdraw(player, totalprice, S("Bought @1x @2 from @3", tobuy, economy.itemdesc_ext(iname), meta:get_string("owner")))
						economy.deposit(meta:get_string("owner"), totalprice, S("@1 buys @2x @3 at @5", tobuy, economy.itemdesc_ext(iname), minetest.pos_to_string(pos)))
						economy.formspecs.pvending.open(player, pos, 1)
					else
						economy.formspecs.pvendingbuyitem.open(player, pos, iname, tobuy, false, true)
					end
				else
					economy.formspecs.pvendingbuyitem.open(player, pos, iname, tobuy, true)
					return
				end
				
			end
		end
	},
	
	
	bank={
		open=function(player, trans_sum, trans_player, trans_complete, trans_fail)
		local log_form="label[0.5,5.5;"..S("Nothing to show").."]"
		if economy.accountlog[economy.pname(player)] then
			local acc=economy.accountlog[economy.pname(player)]
			log_form=
			(acc[1] and "label[0.5,5;"..acc[1].action.."]label[6,5;"..acc[1].amount.." ŧ]" or "")..
			(acc[2] and "label[0.5,5.5;"..acc[2].action.."]label[6,5.5;"..acc[2].amount.." ŧ]" or "")..
			(acc[3] and "label[0.5,6;"..acc[3].action.."]label[6,6;"..acc[3].amount.." ŧ]" or "")..
			(acc[4] and "label[0.5,6.5;"..acc[4].action.."]label[6,6.5;"..acc[4].amount.." ŧ]" or "")..
			(acc[5] and "label[0.5,7;"..acc[5].action.."]label[6,7;"..acc[5].amount.." ŧ]" or "")..
			(acc[6] and "label[0.5,7.5;"..acc[6].action.."]label[6,7.5;"..acc[6].amount.." ŧ]" or "")
			
		end
		
		minetest.show_formspec(economy.pname(player), "economy_bank_", [[
			size[8,8]
			label[0,0;]]..S("Your balance: @1ŧ",economy.moneyof(economy.pname(player)))..[[]
			label[1,0.5;--- ]]..S("Money transfer")..[[ ---]
			field[1,1.5;4,1;sum;]]..S("Transfer sum:")..";"..(trans_sum or "100")..[[]field[1,2.5;4,1;plr;]]..S("Player:")..";"..(trans_player or "???").."]button[1,3.5;2,1;trans;"..S("Transfer!").."]"
			..(trans_complete and "label[0,3;"..S("Transfer successful. @1ŧ have been transferred to @2.", trans_sum, trans_player).."]" or "")..(trans_fail and "label[0,3;"..S("Transfer failed. Please check all values.").."]" or "")..
			"label[1,4.5;--- "..S("Transaction history (latest entry at bottom)").." ---]"..default.gui_bg..default.gui_bg_img..
			log_form
	)
		end,
		hdlr=function(player, restformname, fields)
		if fields.trans then
			if fields.sum and tonumber(fields.sum) and tonumber(fields.sum)>0 and economy.canpay(player, tonumber(fields.sum))
			and fields.plr and economy.balance[fields.plr] then
				
				economy.withdraw(player, tonumber(fields.sum), S("Transfer to @1",fields.plr))
				economy.deposit(fields.plr, tonumber(fields.sum), S("Transfer from @1",economy.pname(player)))
				if minetest.get_player_by_name(fields.plr) then
					minetest.chat_send_player(fields.plr, S("@1ŧ have been transferred to you from @2. You now have @3ŧ.", fields.sum, economy.pname(player), economy.moneyof(fields.plr)))
				end
				economy.formspecs.bank.open(player, tonumber(fields.sum), fields.plr, true)
				return
			end
			
			economy.formspecs.bank.open(player, tonumber(fields.sum), fields.plr, false, true)
		end
		end
	},
}

economy.open_vending=function(pos, player)
	economy.formspecs.vendingsell.open(player, pos)
end
economy.open_bank=function(pos, player)
	economy.formspecs.bank.open(player)
end
economy.open_playervendor=function(pos, player)
	local meta=minetest.get_meta(pos)
	if meta then
		if economy.pname(player)==meta:get_string("owner") then
			economy.formspecs.pvendingown.open(player, pos)
		else
			economy.formspecs.pvending.open(player, pos)
		end
	end
end
minetest.register_on_player_receive_fields(function(player, formname, fields)
	local k,r=string.match(formname, "^economy_([^_]+)_(.*)")
	if k and r then
		if economy.formspecs[k] then
			economy.formspecs[k].hdlr(player, r, fields)
		end
	end
end)
minetest.register_craft({
	output = "economy:playervendor",
	recipe = {
		{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
		{"dye:dark_green", "dye:red", "dye:green"},
		{"default:steel_ingot", "default:copperblock", "default:steel_ingot"},
	},
})

--chatcommands
minetest.register_privilege("economy_admin", {
	description = "Can use the economy chat commands.",
})
core.register_chatcommand("dps", {
	description = "Economy deposit money.",
	params = "player amount [reason]",
	privs = {economy_admin=true},
	func = function(name, param)
		local plr, amt, rsn=string.match(param, "(%S+) (%d+) (.+)")
		if plr and amt and rsn and economy.balance[plr] and tonumber(amt) then
			economy.deposit(plr, amt, rsn)
			return true, "Successfully deposited "..amt.."ŧ on "..plr.."'s account. "..plr.." has now "..economy.balance[plr].."ŧ."
		end
		local plr, amt=string.match(param, "(%S+) (%d+)")
		if plr and amt and economy.balance[plr] and tonumber(amt) then
			economy.deposit(plr, amt, S("Administrative deposition").." ("..name..")")
			return true, "Successfully deposited "..amt.."ŧ on "..plr.."'s account. "..plr.." has now "..economy.balance[plr].."ŧ."
		end
		return false, "Failed running command. Check syntax and player existence."
	end,
})
core.register_chatcommand("wdr", {
	description = "Economy withdraw money.",
	params = "player amount [reason]",
	privs = {economy_admin=true},
	func = function(name, param)
		local plr, amt, rsn=string.match(param, "(%S+) (%d+) (.+)")
		if plr and amt and rsn and economy.balance[plr] and tonumber(amt) then
			local res=economy.withdraw(plr, amt+0, rsn)
			if res then
				return true, "Successfully witdrawn "..amt.."ŧ from "..plr.."'s account. "..plr.." has now "..economy.balance[plr].."ŧ."
			else
				return false, "Can't withdraw "..amt.."ŧ from "..plr.."'s account. "..plr.." has only "..economy.balance[plr].."ŧ."
			end
		end
		local plr, amt=string.match(param, "(%S+) (%d+)")
		if plr and amt and economy.balance[plr] and tonumber(amt) then
			local res=economy.withdraw(plr, amt+0, S("Administrative withdrawal").." ("..name..")")
			if res then
				return true, "Successfully witdrawn "..amt.."ŧ from "..plr.."'s account. "..plr.." has now "..economy.balance[plr].."ŧ."
			else
				return false, "Can't withdraw "..amt.."ŧ from "..plr.."'s account. "..plr.." has only "..economy.balance[plr].."ŧ."
			end
		end
		return false, "Failed running command. Check syntax and player existence."
	end,
})
core.register_chatcommand("blc", {
	description = "Economy balance. player, no param shows all.",
	params = "[player]",
	privs = {economy_admin=true},
	func = function(name, param)
		if param~="" then
			if economy.balance[param] then
				return true, param.." has "..economy.balance[param].."ŧ."
			end
			return false, "Failed running command. Check syntax and player existence."
		end
		for plr, amt in pairs(economy.balance) do
			minetest.chat_send_player(name, plr..": "..amt.."ŧ")
		end
		return true
	end,
})



