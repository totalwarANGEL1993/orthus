--[[
			EntityFind			mcb				2.1
	Schnelle Möglichkeit Entitys zu suchen & sortieren.
	Geht alle Entity-Ids durch, anstatt diese zu erfragen. (bobbys Methode)
	
	
	EntityFind.GetEntities(_amount, _acceptFunc, ...)
	_amount == nil => alle
	[ _acceptFunc: muss für jedes Entity true zurückgeben, das ausgegeben werden soll: id, unpack(arg)
	]
	
	EntityFind.GetPlayerEntities(_player, _entityType, _amount, _acceptFunc, ...)
	_player: 1-8 => player
				oder 0 => neutral (player 0)
				oder nil => alle
	_entityType: EntityTypeId oder EntityTypeName oder table
				oder 0 oder nil => alle
				oder function => muss true zurückgeben, wenn nach EntityTyp gesucht werden soll: EntityTypeName, unpack(arg)
	_amount == nil => alle
	
	
	EntityFind.GetPlayerEntitiesInArea(_player, _entityType, _pos, _range, _amount, _acceptFunc, ...)
	_pos: Position oder existierendes Entity
	_range: Radius um _pos
	_amount: "dist" oder "distance" => alle suchen und nach Entfernung zu _pos sortieren (sort wird überschrieben)
	Rückgabe standardmäßig NICHT nach Entfernung zu _pos sortiert!
	
	Argumente können auch in einem table abgelegt sein:
		{player = ,		--in diesem Fall kann player auch ein table mit Playern sein
		entityType = ,
		amount = ,
		[acceptFunc = ,
		arg = {},		-- Argumente für alle übergebenen Funktionen
		entities = {},	-- schon gefundene Entities
		sort = ,		-- um entities zu sortieren, muss jedem Entity einen Wert zuweisen
							(in entities vorhandene werden mit 0 bewertet): id, unpack(arg)]
		[pos = ,		-- bei Area
		range = ,]
		}
	
	
	EntityFind.Set enthält vorgefertigte Entity-tables:
	Leader (ohne Helden)
	Hero
	MilitaryBuilding (Türme)
	Military (Leader + Hero + MilitaryBuilding)
	Building (mit Wällen)
	PU (mit Kanonen)
	PB
	CU
	CB (mit Wällen)
	P (PU + PB)
	C (CU + CB)
	XD
	
	und Mengen-Operationen für tables:
	Add: Alle Elemente, die in einem der tables vorkommen, werden übernommen
	All: Alle Elemente, die in allen tables vorkommen, werden übernommen (Schnittmenge)
	Dif: Entfernt aus dem ersten table alle Elemente die in weiteren tables gegeben sind
	(übergebene tables werden nicht geändert)
	
	Benötigt:
	IstDrin				! vor EntityFind im Script !
	GetDistance
	unpack-fix
]]
-- -------------------------------------------------------------------------- --
EntityFind = EntityFind or {oldId = {}, highest = 65537}
function EntityFind_EntityCreated()
	local id = Event.GetEntityID()
	if id > 131072 then
		old = (id - math.floor(id/65536)*65536) + 65536
		EntityFind.oldId[old] = id
	else
		EntityFind.highest = id
	end
end
Trigger.RequestTrigger(Events.LOGIC_EVENT_ENTITY_CREATED, nil, "EntityFind_EntityCreated", 1)
Logic.DestroyEntity(Logic.CreateEntity(Entities.XD_ScriptEntity, 2, 2, 0, 0))

function EntityFind.GetEntities(_amount, _acceptFunc, ...)
	--  table für gefundene
	local entitySafe = {}
	
	local sort
	
	-- table-aufruf entpacken
	if type(_amount) == "table" then
		_acceptFunc = _amount.acceptFunc
		arg = _amount.arg or {}
		sort = _amount.sort
		entitySafe = _amount.entities or {}
		_amount = _amount.amount
	end
	
	assert(type(arg)=="table" and type(entitySafe)=="table")
	
	-- sort prüfen
	assert(type(sort)=="function" or not sort, "EntityFind: Keine Sortierfunktion: "..tostring(sort).." Funktion oder nil erlaubt")
	local value = {}
	if sort then
		for k,_ in pairs(entitySafe) do
			value[k] = 0
		end
		_amount = nil
	end
	
	--  Menge prüfen
	assert(_amount==nil or type(_amount)=="number", "EntityFind: Keine Anzahl: "..tostring(_amount).." Zahl oder nil erlaubt!")
	
	--   acceptFunc prüfen
	_acceptFunc =  _acceptFunc or function() return true end
	assert(type(_acceptFunc)=="function", "EntityFind: Keine Prüffunktion: "..tostring(_acceptFunc).." Funktion oder nil erlaubt!")
	
	--   suchen!
	for i = 65536, EntityFind.highest do --   gehe alle ids durch
		local id = i
		if EntityFind.oldId[id] then -- eventuell ersatzid
			id = EntityFind.oldId[id]
		end
		if IsValid(id) and _acceptFunc(id, unpack(arg)) then -- prüfen
			if sort then
				local v = sort(id, unpack(arg))
				for i,val in ipairs(value) do
					if val > v then
						table.insert(entitySafe, i, id)
						table.insert(value, i, v)
						v = nil
						break
					end
				end
				if v then
					table.insert(entitySafe, id)
					table.insert(value, v)
				end
			else
				table.insert(entitySafe, id)
			end
		end
		if _amount and table.getn(entitySafe) >= _amount then -- genug gefunden: abbruch
			break
		end
	end
	
	return entitySafe
end

function EntityFind.GetPlayerEntities(_player, _entityType, _amount, _acceptFunc, ...)
	--  table für gefundene
	local entitySafe = {}
	
	
	local sort
	
	--  tableaufruf entpacken
	if type(_player) == "table" then
		_entityType = _player.entityType
		_amount = _player.amount
		_acceptFunc = _player.acceptFunc
		arg = _player.arg or {}
		entitySafe = _player.entities or {}
		sort = _player.sort
		_player = _player.player
	end
	
	-- sort prüfen
	assert(type(sort)=="function" or not sort, "EntityFind: Keine Sortierfunktion: "..tostring(sort).." Funktion oder nil erlaubt")
	local value = {}
	if sort then
		for k,_ in pairs(entitySafe) do
			value[k] = 0
		end
	end
	
	--   acceptFunc prüfen
	_acceptFunc =  _acceptFunc or function() return true end
	assert(type(_acceptFunc)=="function", "EntityFind: Keine Prüffunktion: "..tostring(_acceptFunc).." Funktion oder nil erlaubt!")
	
	--  player prüfen
	if _player == nil then
		_player = {0,1,2,3,4,5,6,7,8}
	elseif type(_player)~="table" then
		_player = {_player}
	end
	for _,pl in ipairs(_player) do
		assert(type(pl)=="number" and pl < 9 and pl >= 0, "EntityFind: Kein Spieler: "..tostring(pl))
	end
	
	--  typ prüfen
	if type(_entityType)=="function" then -- type-accepter
		local entityTypeAccept = _entityType
		_entityType = {}
		for tEntityTypeName, tEntityType in pairs(Entities) do
			if entityTypeAccept(tEntityTypeName, unpack(arg)) then
				table.insert(_entityType, tEntityType)
			end
		end
	end
	if _entityType == 0 or _entityType == nil then --alle
		_entityType = Entities
	end
	if type(_entityType)~="table" then
		_entityType = {_entityType}
	end
	for k,ty in pairs(_entityType) do
		if type(ty)=="string" then
			_entityType[k] = Entities[ty]
		end
		assert(type(_entityType[k])=="number" and type(Logic.GetEntityTypeName(_entityType[k]))=="string", 
			"EntityFind: Kein Entity-Typ: "..tostring(_entityType[k])
		)
	end
	
	-- key = true ist wesentlich schneller als IstDrin
	local ety = {}
	for _,et in pairs(_entityType) do
		ety[et] = true
	end
	_entityType = ety
	local pla = {}
	for _,pl in pairs(_player) do
		pla[pl] = true
	end
	_player = pla
	
	-- neue acceptFunc & sort
	local acc = function(id, player, entityType, acceptFunc, sortOld, ...)
		if player[GetPlayer(id)] and entityType[Logic.GetEntityType(id)] then	
			return acceptFunc(id, unpack(arg))
		end
		return false
	end
	local so = function(id, player, entityType, acceptFunc, sortOld, ...)
		return sortOld(id, unpack(arg))
	end
	
	--Übergabe
	return EntityFind.GetEntities{amount = _amount,
		acceptFunc = acc,
		arg = {_player, _entityType, _acceptFunc, sort or false, unpack(arg)},
		entities = entitySafe,
		sort = sort and so,
	}
end
function EntityFind.GetPlayerEntitiesInArea(_player, _entityType, _pos, _range, _amount, _acceptFunc, ...)
	--  table für gefundene
	local entitySafe = {}
	
	
	local sort
	
	--  tableaufruf entpacken
	if type(_player) == "table" then
		_entityType = _player.entityType
		_amount = _player.amount
		_acceptFunc = _player.acceptFunc
		arg = _player.arg or {}
		entitySafe = _player.entities or {}
		_pos = _player.pos
		_range = _player.range
		sort = _player.sort
		_player = _player.player
	end
	
	--Position prüfen
	if type(_pos) ~= "table" and IsValid(_pos) then
		_pos = GetPosition(_pos)
	end
	assert(type(_pos)=="table" and type(_pos.X)=="number" and type(_pos.Y)=="number",
		"EntityFind: keine Positionsangabe: "..tostring(_pos)
	)
	
	--Reichweite prüfen
	assert(type(_range)=="number" and _range > 0, "EntityFind: Keine Reichweitenangabe "..tostring(_range))
	
	-- acceptFunc prüfen
	_acceptFunc =  _acceptFunc or function() return true end
	assert(type(_acceptFunc)=="function", "EntityFind: Keine Prüffunktion: "..tostring(_acceptFunc).." Funktion oder nil erlaubt!")
	
	--Funktion um Reichweite zu prüfen
	local func = function(id, pos, range, acceptFunc, sortOld, entityTypeOld, ...)
		return GetDistance(GetPosition(id), pos) <= range and acceptFunc(id, unpack(arg))
	end
	
	-- Sortierung
	local sortOld
	if _amount == "distance" or _amount == "dist" then
		_amount = nil
		sort = function(id, pos)
			return GetDistance(id, pos)
		end
	elseif sort then
		sortOld = sort
		sort = function(id, pos, range, acceptFunc, sortOld, entityTypeOld, ...)
			return sortOld(id, unpack(arg))
		end
	end
	
	entityTypeOld = nil
	-- entityType-accepter
	if type(_entityType) == "function" then
		entityTypeOld = _entityType
		_entityType = function(typeName, pos, range, acceptFunc, sortOld, entityTypeOld, ...)
			return entityTypeOld(typeName, unpack(arg))
		end
	end
	
	--Übergabe
	return EntityFind.GetPlayerEntities{player = _player,
		entityType = _entityType,
		amount = _amount,
		acceptFunc = func,
		arg = {_pos, _range, _acceptFunc, sortOld or false, entityTypeOld or false, unpack(arg)},
		entities = entitySafe,
		sort = sort,
	}
end
EntityFind.Set = {
	Leader = {Entities.CU_AggressiveWolf, Entities.PU_Thief, Entities.PU_Scout,
		Entities.PU_BattleSerf, Entities.CU_Barbarian_Hero_wolf,
	},
	Hero = {Entities.CU_Barbarian_Hero, Entities.CU_BlackKnight, Entities.CU_Mary_de_Mortfichet, Entities.CU_Evil_Queen},
	Building = {},
	MilitaryBuilding = {Entities.PB_Tower2, Entities.PB_Tower3, Entities.PB_DarkTower2, Entities.PB_DarkTower3,
		Entities.CB_Evil_Tower1,
	},
	C = {},
	P = {},
	XD = {},
}
function EntityFind.Set.Add(...)
	local r = {}
	for _,t in ipairs(arg) do
		for _,ty in ipairs(t) do
			if not IstDrin(ty, r) then
				table.insert(r, ty)
			end
		end
	end
	return r
end
function EntityFind.Set.All(...)
	local r = {}
	local t1 = table.remove(arg)
	for _,ty in ipairs(t1) do
		local ok=true
		for _,t in ipairs(arg) do
			if not IstDrin(ty, t) then
				ok = false
				break
			end
		end
		if ok then
			table.insert(r, ty)
		end
	end
	return r
end
function EntityFind.Set.Dif(t1, ...)
	local r = {}
	for _,ty in ipairs(t1) do
		local ok = true
		for _,t in ipairs(arg) do
			if IstDrin(ty, t) then
				ok = false
				break
			end
		end
		if ok then
			table.insert(r, ty)
		end
	end
	return r
end
function EntityFind.LoadSet()
	local ig = {"PB_Tower2_Ballista", "PB_Tower3_Cannon", "PB_DarkTower2_Ballista",
		"PB_DarkTower3_Cannon", "CB_Evil_Tower1_ArrowLauncher",
	}
	for na, ty in pairs(Entities) do
		if not IstDrin(na, ig) then
			if string.find(na, "Leader") then
				table.insert(EntityFind.Set.Leader, ty)
			end
			if string.find(na, "Hero") then
				table.insert(EntityFind.Set.Hero, ty)
			end
			if string.find(na, "CU_") or string.find(na, "CB_") or string.find(na, "XD_Wall") or string.find(na, "XD_DarkWall") then
				table.insert(EntityFind.Set.C, ty)
			end
			if string.find(na, "PU_") or string.find(na, "PB_") or string.find(na, "PV_") then
				table.insert(EntityFind.Set.P, ty)
			end
			if string.find(na, "CB_") or string.find(na, "PB_") or string.find(na, "XD_Wall") or string.find(na, "XD_DarkWall") then
				table.insert(EntityFind.Set.Building, ty)
			end
			if string.find(na, "XD_") then
				table.insert(EntityFind.Set.XD, ty)
			end
		end
	end
	EntityFind.Set.Military = EntityFind.Set.Add(EntityFind.Set.Leader, EntityFind.Set.Hero, EntityFind.Set.MilitaryBuilding)
	EntityFind.Set.CU = EntityFind.Set.Dif(EntityFind.Set.C, EntityFind.Set.Building)
	EntityFind.Set.CB = EntityFind.Set.All(EntityFind.Set.C, EntityFind.Set.Building)
	EntityFind.Set.PU = EntityFind.Set.Dif(EntityFind.Set.P, EntityFind.Set.Building)
	EntityFind.Set.PB = EntityFind.Set.All(EntityFind.Set.P, EntityFind.Set.Building)
end
EntityFind.LoadSet()

