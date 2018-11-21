tempsurvive={
	step_timer=0,
	step_time=1,
	player={},
	perlin={
		offset=50,
		scale=50,
		spread={x=1000,y=1000,z=1000},
		seed=5349,
		octaves=3,
		persist=0.5,
		lacunarity=2,
		flags="default"
	},
	bar={
		hud_elem_type="statbar",
		position={x=0.5,y=1.025},
		text="tempsurvive_bar.png",
		number=40,
		size={x=24,y=4},
		direction=0,
		offset={x=-244, y=-88}, --offset={x=-265, y=-88},
	},
	screen={
		hud_elem_type = "image",
		text ="tempsurvive_screen.png",
		scale = {x=-100, y=-100},
		alignment = {x=1, y=1},
	},
	nodes={
		["snowy"]={add=-1,rad=2},
		["default:ice"]={add=-2,rad=3},
		["water"]={add=-10,rad=0},
		["torch"]={add=5,rad=5},
		["igniter"]={add=15,rad=5},
		["default:furnace_active"]={add=10,rad=10},
	}
}

minetest.after(0.1, function()
	local groups_to_change={}
	for i,v in pairs(tempsurvive.nodes) do
		if string.find(i,":")==nil then
			groups_to_change[i]=v
		else
			local group=table.copy(minetest.registered_nodes[i].groups or {})
			group.tempsurvive=1
			group.tempsurvive_add=v.add
			group.tempsurvive_rad=v.rad
			minetest.override_item(i, {groups=group})
		end
	end
	for i,v in pairs(minetest.registered_nodes) do
		for ii,vv in pairs(groups_to_change) do
			if v.groups[ii] then
				local group=table.copy(v.groups or {})
				group.tempsurvive=1
				group.tempsurvive_add=vv.add
				group.tempsurvive_rad=vv.rad
				minetest.override_item(i, {groups=group})
			end
		end
	end
end)


tempsurvive.exposed=function(pos1,pos2,add)
	local d=vector.distance(pos1,pos2)
	if d<1 then
		return add
	end
	local v = {x = pos1.x - pos2.x, y = pos1.y - pos2.y-1, z = pos1.z - pos2.z}
	v.y=v.y-1
	local amount = (v.x ^ 2 + v.y ^ 2 + v.z ^ 2) ^ 0.5
	v.x = (v.x  / amount)*-1
	v.y = (v.y  / amount)*-1
	v.z = (v.z  / amount)*-1
	for i=1,d,1 do
		local node=minetest.registered_nodes[minetest.get_node({x=pos1.x+(v.x*i),y=pos1.y+(v.y*i),z=pos1.z+(v.z*i)}).name]
		if node and node.walkable then
			local c=minetest.get_node_group(node.name,"cracky")
			if add<0 then
				return 0
			elseif c>0 then
				c=c+1
			else
				c=2
			end
			add=add/c
		end
	end
	return add/d
end



tempsurvive.spread_temperature=function(target_pos,pos,add,rad)
	local td=vector.distance(target_pos,pos)
	if td<1 then
		return add
	end
	local jobs={pos}
	local checked={}
	while #jobs>0 and #jobs<1000 do
		for i,p in pairs(jobs) do
			for x=-1,1,1 do
			for y=-1,1,1 do
			for z=-1,1,1 do
				local np={x=p.x+x,y=p.y+y,z=p.z+z}
				local ta=minetest.pos_to_string(np)
				local d=vector.distance(pos,np)
				local nod=minetest.registered_nodes[minetest.get_node(np).name]
				if d<=rad and not checked[ta] and nod and not nod.walkable then

--minetest.add_entity(np, "tempsurvive:dot")

					if vector.distance(target_pos,np)<=1 then
						return add/td
					end
					checked[ta]=true
					table.insert(jobs,np)
				end
			end
			end
			end
			table.remove(jobs,i)
		end
	end
	return 0
end


minetest.register_entity("tempsurvive:dot",{
	hp_max = 1,
	physical = false,
	collisionbox = {0,0,0,0,0,0},
	visual = "sprite",
	visual_size = {x=0.2, y=0.2},
	textures = {"bubble.png^[colorize:#0000ff"},
	on_step = function(self, dtime)
		self.timer=self.timer+dtime
		if self.timer<0.5 then return self end
		self.object:remove()
	end,
	timer=0,
})

tempsurvive.get_bio_temperature=function(pos)
	if pos.y<-50 then return 0 end
	local p={x=math.floor(pos.x),y=0,z=math.floor(pos.z)}
	local l=minetest.get_node_light(pos) or 0

	local temp=minetest.get_perlin(tempsurvive.perlin):get2d({x=p.x,y=p.z})-40

	if temp>0 then
		return temp+((l*0.025)*temp)
	else
		return temp,temp+(l*0.1)
	end
end

tempsurvive.new=function(player)
	tempsurvive.player[player:get_player_name()]={
		temp=0,
		status=10,
		heat_resistance=40,
		coldness_resistance=-10,
	}
end

minetest.register_globalstep(function(dtime)
	if tempsurvive.step_timer>tempsurvive.step_time then
		tempsurvive.step_timer=0
	else
		tempsurvive.step_timer=tempsurvive.step_timer+dtime
		return
	end
	for _,player in ipairs(minetest.get_connected_players()) do

		local ptemp=tempsurvive.player[player:get_player_name()]
		if not ptemp then return end
		local pos=player:get_pos()
		local temp=tempsurvive.get_bio_temperature(pos)

		local a=minetest.find_nodes_in_area({x=pos.x-3, y=pos.y-3, z=pos.z-3}, {x=pos.x+3, y=pos.y+3, z=pos.z+3}, {"group:tempsurvive"})

		for i,no in pairs(a) do
			local name=minetest.get_node(no).name
			temp=temp+tempsurvive.spread_temperature(
				pos,
				no,
				minetest.get_item_group(name,"tempsurvive_add"),
				minetest.get_item_group(name,"tempsurvive_rad")
			)
		end

		ptemp.temp=ptemp.temp-(math.floor(ptemp.temp-temp)*0.01)

		if ptemp.temp<ptemp.coldness_resistance then
			player:punch(player,1+math.floor((ptemp.temp-ptemp.coldness_resistance)*-0.1),{full_punch_interval=1,damage_groups={fleshy=1}})
		elseif ptemp.temp>ptemp.heat_resistance then
			player:punch(player,1+math.floor((ptemp.temp-ptemp.heat_resistance)*0.5),{full_punch_interval=1,damage_groups={fleshy=1}})
		end


		local pt=math.floor(math.abs(ptemp.temp))
print("temp, ptemp",temp,ptemp.temp)
--print("% heat",(pt/math.abs(ptemp.heat_resistance))*20)
--print("% cold",(pt/math.abs(ptemp.coldness_resistance))*20)


		if ptemp.temp<0 and pt<=ptemp.coldness_resistance*-1 then
			local t=math.floor(pt/math.abs(ptemp.coldness_resistance)*15)
			local ht=tempsurvive.n2dhex(math.ceil(t/2))
			player:hud_change(ptemp.bar, "text", tempsurvive.bar.text .."^[colorize:#00" .. tempsurvive.n2dhex(15-t) .. tempsurvive.n2dhex(t) .."cc")
			player:hud_change(ptemp.bar, "number", 20-math.floor(pt/math.abs(ptemp.coldness_resistance)*20))
			player:hud_change(ptemp.screen, "text", tempsurvive.screen.text .."^[colorize:#00" .. ht .. tempsurvive.n2dhex(t) ..  ht)
		elseif ptemp.temp>=0 and pt<=ptemp.heat_resistance then
			local t=math.floor(pt/math.abs(ptemp.heat_resistance)*15)
			local ht=tempsurvive.n2dhex(math.ceil(t/2))
			player:hud_change(ptemp.bar, "text", tempsurvive.bar.text .."^[colorize:#" .. tempsurvive.n2dhex(t) ..tempsurvive.n2dhex(15-t) .."00cc")
			player:hud_change(ptemp.bar, "number", 20+math.floor(pt/math.abs(ptemp.heat_resistance)*20))
			player:hud_change(ptemp.screen, "text", tempsurvive.screen.text .."^[colorize:#" .. tempsurvive.n2dhex(t) .. ht .. "00" ..  ht)
		end
	end
end)

tempsurvive.n2dhex=function(n)
	if n<0 then n=0 end
	local a={0,1,2,3,4,5,6,7,8,9,"a","b","c","d","e","f"}
	local a2=a[n+1] or "f"
	return a2 .. a2
end


minetest.register_on_joinplayer(function(player)
	tempsurvive.new(player)
	tempsurvive.player[player:get_player_name()].bar=player:hud_add(tempsurvive.bar)



	tempsurvive.player[player:get_player_name()].screen=player:hud_add(tempsurvive.screen)


if 1 then return end
	tempsurvive.player[player:get_player_name()].screen=player:hud_add({
			hud_elem_type = "image",
			text ="tempsurvive_screen.png",
			name = "screen",
			scale = {x=-100, y=-100},
			position = {x=0, y=0},
			alignment = {x=1, y=1},
		})



end)
--minetest.after(0, function() end,)
minetest.register_on_leaveplayer(function(player)
	tempsurvive.player[player:get_player_name()]=nil
end)




minetest.register_node("tempsurvive:thermometer", {
	description = "Thermometer",
	tiles = {"tempsurvive_thermometer.png"},
	inventory_image="tempsurvive_thermometer_item.png",
	wield_image="tempsurvive_thermometer_item.png",
	groups = {dig_immediate=3},
	drawtype="nodebox",
	paramtype="light",
	paramtype2="facedir",
	walkable=false,
	node_box = {
		type = "fixed",
		fixed = {
			{-0.1, -0.25, 0.43, 0.1, 0.25, 0.5} --{-0.06, -0.2, 0.43, 0.06, 0.2, 0.5}
		}
	},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", math.floor(tempsurvive.get_bio_temperature(pos)*10)*0.1)
		minetest.get_node_timer(pos):start(2)
	end,
	on_timer = function (pos, elapsed)
		local meta=minetest.get_meta(pos)


		local temp=tempsurvive.get_bio_temperature(pos)

		local a=minetest.find_nodes_in_area({x=pos.x-3, y=pos.y-3, z=pos.z-3}, {x=pos.x+3, y=pos.y+3, z=pos.z+3}, {"group:tempsurvive"})

		for i,no in pairs(a) do
			local name=minetest.get_node(no).name
			temp=temp+tempsurvive.spread_temperature(
				pos,
				no,
				minetest.get_item_group(name,"tempsurvive_add"),
				minetest.get_item_group(name,"tempsurvive_rad")
			)
		end
		meta:set_string("infotext", math.floor(temp*10)*0.1)
		return true
	end,
})
