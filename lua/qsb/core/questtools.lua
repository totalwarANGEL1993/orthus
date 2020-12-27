-- ########################################################################## --
-- #  QSB Library                                                           # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module provides some helpful tools.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.core.oop</li>
-- <li>qsb.lib.questsync</li>
-- </ul>
--
-- @set sort=true
--

QuestTools = {
    InlineJobs = {Counter = 0},
    EntityNameCounter = 0,
};

-- Utils --

---
-- Returns the extension number. This function can be used to identify the
-- current expansion of the game.
-- @return[type=number] Extension
-- @within Utils
--
function QuestTools.GetExtensionNumber()
    local Version = Framework.GetProgramVersion();
    local extensionNumber = tonumber(string.sub(Version, string.len(Version))) or 0;
    return extensionNumber;
end

---
-- Returns the short name of the game language.
-- @return[type=string] Short name
-- @within Utils
--
function QuestTools.GetLanguage()
    return (XNetworkUbiCom.Tool_GetCurrentLanguageShortName() == "de" and "de") or "en";
end

---
-- Returns the localized text from the input.
-- @param _Text Text to translate
-- @return[type=string] 
-- @within Utils
--
function QuestTools.GetLocalizedTextInTable(_Text)
    if type(_Text) == "table" then
        return _Text[QuestTools.GetLanguage()] or " ERROR_TEXT_INVALID ";
    end
    return _Text;
end

---
-- Checks if a value is inside a table.
--
-- @param             _Value Value to find
-- @param[type=table] _Table Table to search
-- @return[type=boolean] Value found
-- @within Utils
--
function QuestTools.IsInTable(_Value, _Table)
	return QuestTools.GetKeyByValue(_Value, _Table) ~= nil;
end
IstDrin = QuestTools.IsInTable;

---
-- Returns the key of the given value in the table if value is existing.
--
-- @param             _Value Value of key
-- @param[type=table] _Table Table to search
-- @return Key of value
-- @within Utils
--
function QuestTools.GetKeyByValue(_Value, _Table)
    for k, v in pairs(_Table) do 
        if v == _Value then
            return k;
        end
    end
end
KeyOf = QuestTools.GetKeyByValue;

---
-- Displays the name of any function that is to large to be loaded when a
-- savegame is loaded.
-- @param[type=table] t Table to check
-- @within Utils
-- @local
--
function QuestTools.CheckFunctionSize(t)
    table.foreach(t, function(k, v)
        if type(v) == "function" then
            local res, dmp = xpcall(
                function()return string.dump(v) end,
                function() end
            );
            if res and dmp then
                local size = string.len(dmp);
                if size > 16000 then
                    GUI.AddStaticNote(k .. " -> " .. size);
                    if LuaDebugger.Log then
                        LuaDebugger.Log(k .. " -> " .. size);
                    end
                end
            end
        end
        if type(v) == "table" and not tonumber(k) and v ~= _G then
            QuestTools.CheckFunctionSize(v);
        end
    end);
end

---
-- Calls a function in protected mode.
--
-- The function and the arguments must be passed as a table. If there is a
-- field ErrorHandler in the table, the handler will be called in case of
-- error. The error handler <i>must</i> be a function.
--
-- The error handler gets the actual error and all arguments from the original
-- call passed when executed.
--
-- QuestTools.SaveCall returns the return value of the function if no errors
-- occur. Ifsomething went wrong the return value of the error handler is 
-- returned. If no handler is present the return value will always be nil.
--
-- <b>Note>/b>: Protected mode is <u>only</u>used when the field 
-- QuestSystem.IgnoreLuaDebugger is set to <i>true</i> or the LuaDebugger 
-- (the one coded by yoq) is absend. If non of these conditions met, simply
-- the original function will be executed.
--
-- @param[type=table] _Data Function to call (in a table)
-- @return Return value of function or of error handler
-- @within Utils
-- @local
--
--
function QuestTools.SaveCall(_Data)
    if type(_Data == "table" and type(_Data[1]) == "function") then
        local Function = table.remove(_Data, 1);
        if QuestSystem.IgnoreLuaDebugger or LuaDebugger.Log == nil then
            local Values = {xpcall(
                function() return Function(unpack(_Data)); end,
                function(_Error) return _Error; end
            )};
            if Values[1] == false then
                GUI.AddStaticNote("Runtime error: " ..tostring(Values[2]));
                if type(_Data.ErrorHandler) == "function" then
                    return QuestTools.SaveCall{_Data.ErrorHandler, Values[2], unpack(_Data)};
                end
            end
            return Values[2];
        else
            return Function(unpack(_Data));
        end
    end
end

---
-- Rounds the given value to the next integer.
--
-- Values below x.5 will be floored to the previous integer. Values greater
-- than x.5 will be risen to the next integer.
--
-- @param[type=number] _Value Number to round
-- @return[type=number] Rounded number
-- @within Utils
-- @local
--
--
function QuestTools.Round(_Value)
    return math.floor(_Value + 0.5);
end
Round = QuestTools.Round;
round = QuestTools.Round;

-- Entities --

---
-- Sets the visibility of the entity.
--
-- @param               _Entity Skriptname or ID of entity
-- @param[type=boolean] _Flag   Visibility flag
-- @within Entities
--
function QuestTools.SetVisible(_Entity, _Flag)
    local VisibleFlag = (_Flag == true and 513) or 65793;
    local ValueIndex  = (QuestSync:IsHistoryEdition() == true and -26) or -30;
    Logic.SetEntityScriptingValue(id, ValueIndex, VisibleFlag);
end

---
-- Returns true if the entity is visible.
--
-- @param _Entity Skriptname or ID of entity
-- @return[type=boolean] Entity is visible
-- @within Entities
--
function QuestTools.IsVisible(_Entity)
    local ValueIndex  = (QuestSync:IsHistoryEdition() == true and -26) or -30;
    return Logic.GetEntityScriptingValue(id, ValueIndex, VisibleFlag) == 513;
end

---
-- Returns a list of all leader of the player.
--
-- @param[type=number] _PlayerID ID of player
-- @return[type=table] List of leaders
-- @within Entities
--
function QuestTools.GetAllLeader(_PlayerID)
    local LeaderList = {};
    local FirstID = Logic.GetNextLeader(_PlayerID, 0);
    if FirstID ~= 0 then
        local PrevID = FirstID;
        table.insert(LeaderList, FirstID);
        while true do
            local NextID = Logic.GetNextLeader(_PlayerID, PrevID);
            if NextID == FirstID then
                break;
            end
            table.insert(LeaderList, NextID);
            PrevID = NextID;
        end
    end
    return LeaderList;
end

---
-- Returns a list of all cannons of the player.
--
-- @param[type=number] _PlayerID ID of player
-- @return[type=table] List of cannons
-- @within Entities
--
function QuestTools.GetAllCannons(_PlayerID)
    local CannonList = {};
    for i= 1, 4, 1 do
        local n, FirstID = Logic.GetPlayerEntities(_PlayerID, Entities["PV_Cannon" ..i], 1);
        if n > 0 then
            local PrevID = FirstID;
            table.insert(CannonList, FirstID);
            while true do
                local NextID = Logic.GetNextEntityOfPlayerOfType(PrevID);
                if NextID == FirstID then
                    break;
                end
                table.insert(CannonList, NextID);
                PrevID = NextID;
            end
        end
    end
    return CannonList;
end

---
-- Finds all entities of the player that have the type.
-- @param[type=number] _PlayerID   ID of player
-- @param[type=number] _EntityType Type to search
-- @return[type=table] List of entities
-- @within Entities
--
function QuestTools.GetPlayerEntities(_PlayerID, _EntityType)
    local PlayerEntities = {}
    if _EntityType ~= 0 then
        local n,eID = Logic.GetPlayerEntities(_PlayerID, _EntityType, 1);
        if (n > 0) then
            local firstEntity = eID;
            repeat
                table.insert(PlayerEntities,eID)
                eID = Logic.GetNextEntityOfPlayerOfType(eID);
            until (firstEntity == eID);
        end
    elseif _EntityType == 0 then
        for k,v in pairs(Entities) do
            if string.find(k, "PU_") or string.find(k, "PB_") or string.find(k, "CU_") or string.find(k, "CB_")
            or string.find(k, "XD_DarkWall") or string.find(k, "XD_Wall") or string.find(k, "PV_") then
                local n,eID = Logic.GetPlayerEntities(_PlayerID, v, 1);
                if (n > 0) then
                local firstEntity = eID;
                repeat
                    table.insert(PlayerEntities,eID)
                    eID = Logic.GetNextEntityOfPlayerOfType(eID);
                until (firstEntity == eID);
                end
            end
        end
    end
    return PlayerEntities
end
GetPlayerEntities = QuestTools.GetPlayerEntities;

---
-- Finds all entities numbered from 1 to n with a common prefix.
-- @param[type=string] _Prefix Prefix of scriptnames
-- @return[type=table] List of entities
-- @within Entities
--
function QuestTools.GetEntitiesByPrefix(_Prefix)
    local list = {};
    local i = 1;
    local bFound = true;
    while (bFound) do
        local entity = GetID(_Prefix ..i);
        if entity ~= 0 then
            table.insert(list, entity);
        else
            bFound = false;
        end
        i = i + 1;
    end
    return list;
end
GetEntitiesByPrefix = QuestTools.GetEntitiesByPrefix;

---
-- Checks worldwide for doodad entities or player entities.
--
-- Be careful: This method is using expensive area checks. Do better not use
-- it inside of jobs.
--
-- @param[type=number] _PlayerID ID of player
-- @param[type=number] _Type     Type of entity
-- @param[type=number] _AreaSize (Optional) Area size
-- @param[type=table]  _Position (Optional) Area center
-- @return[type=table] Result set
-- @within Entities
--
function QuestTools.FindAllEntities(_PlayerID, _Type, _AreaSize, _Position)
	local ResultSet = {};
    
    _AreaSize = _AreaSize or Logic.WorldGetSize();
    _Position = _Position or {X = _AreaSize/2, Y = _AreaSize/2};
    
    local Data;
	if _PlayerID == 0 then
		Data = {Logic.GetEntitiesInArea(_Type, _Position.X, _Position.Y, math.floor(_AreaSize * 0.71), 16)};
	else
		Data = {Logic.GetPlayerEntitiesInArea(_PlayerID, _Type, _Position.X, _Position.Y, math.floor(_AreaSize * 0.71), 16)};
    end
    
	if Data[1] >= 16 then
		local HalfAreaSize = _AreaSize / 2;
		local PositionX1 = _Position.X - _AreaSize / 4;
		local PositionX2 = _Position.X + _AreaSize / 4;
		local PositionY1 = _Position.Y - _AreaSize / 4;
		local PositionY2 = _Position.Y + _AreaSize / 4;
		local ResultSetRecursive = QuestTools.FindAllEntities(_PlayerID, _Type, HalfAreaSize, {X=PositionX1,Y=PositionY1});
		for i = 1, table.getn(ResultSetRecursive) do
			if not QuestTools.IsInTable(ResultSetRecursive[i], ResultSet) then
				table.insert(ResultSet, ResultSetRecursive[i]);
			end
		end
		local ResultSetRecursive = QuestTools.FindAllEntities(_PlayerID, _Type, HalfAreaSize, {X=PositionX1,Y=PositionY2});
		for i = 1, table.getn(ResultSetRecursive) do
			if not QuestTools.IsInTable(ResultSetRecursive[i], ResultSet) then
				table.insert(ResultSet, ResultSetRecursive[i]);
			end
		end
		local ResultSetRecursive = QuestTools.FindAllEntities(_PlayerID, _Type, HalfAreaSize, {X=PositionX2,Y=PositionY1});
		for i = 1, table.getn(ResultSetRecursive) do
			if not QuestTools.IsInTable(ResultSetRecursive[i], ResultSet) then
				table.insert(ResultSet, ResultSetRecursive[i]);
			end
		end
		local ResultSetRecursive = QuestTools.FindAllEntities(_PlayerID, _Type, HalfAreaSize, {X=PositionX2,Y=PositionY2});
		for i = 1, table.getn(ResultSetRecursive) do
			if not QuestTools.IsInTable(ResultSetRecursive[i], ResultSet) then
				table.insert(ResultSet, ResultSetRecursive[i]);
			end
		end
	else
		table.remove(Data, 1);
		for i = 1, table.getn(Data) do
			if not QuestTools.IsInTable(Data[i], ResultSet) then
				table.insert(ResultSet, Data[i]);
			end
		end
	end
	return ResultSet
end
SucheAufDerWelt = QuestTools.FindAllEntities

---
-- Returns the distance between two positions or entities.
--
-- @param _pos1 Position 1 (string, number oder table)
-- @param _pos2 Position 2 (string, number oder table)
-- @return[type=number] Distance between positions
-- @within Entities
--
function QuestTools.GetDistance(_pos1, _pos2)
    if (type(_pos1) == "string") or (type(_pos1) == "number") then
        _pos1 = GetPosition(_pos1);
    end
    if (type(_pos2) == "string") or (type(_pos2) == "number") then
        _pos2 = GetPosition(_pos2);
    end
	assert(type(_pos1) == "table");
	assert(type(_pos2) == "table");
    local xDistance = (_pos1.X - _pos2.X);
    local yDistance = (_pos1.Y - _pos2.Y);
    return math.sqrt((xDistance^2) + (yDistance^2));
end
GetDistance = QuestTools.GetDistance;

---
-- Returns the geometric focus of the passed positions.
--
-- The geometric focus is a average position somewhere between the given
-- coordinates.
--
-- @param _pos1 ... Positions (string, number oder table)
-- @return[type=table] Average position
-- @within Entities
--
function QuestTools.GetGeometricFocus(...)
    local SumX = 0;
    local SumY = 0;
    local SumZ = 0;
    for i= 1, table.getn(arg), 1 do
        local Position = arg[i];
        if type(arg[i]) ~= "table" then
            Position = GetPosition(arg[i]);
        end
        SumX = SumX + Position.X;
        SumY = SumY + Position.Y;
        if Position.Z then
            SumZ = SumZ + Position.Z;
        end
    end
    return {
        X= 1/table.getn(arg) * SumX,
        Y= 1/table.getn(arg) * SumY,
        Z= 1/table.getn(arg) * SumZ
    };
end

---
-- Returns a reachable position for the entity or nil if no position was found.
--
-- @param _Entity Entity (string, number)
-- @param _Target Target position (string, number oder table)
-- @return[type=number] Erreichbare Position
-- @within Entities
--
function QuestTools.GetReachablePosition(_Entity, _Target)
    local PlayerID = Logic.EntityGetPlayer(GetID(_Entity));
    local Position1 = GetPosition(_Entity);
    local Position2 =_Target;
    if (type(Position2) == "string") or (type(Position2) == "number") then
        Position2 = GetPosition(_Target);
    end
	assert(type(Position1) == "table");
    assert(type(Position2) == "table");

    local ID = AI.Entity_CreateFormation(PlayerID, Entities.PU_Serf, 0, 0, Position2.X, Position2.Y, 0, 0, 0, 0);
    local NewPosition = GetPosition(ID);
    DestroyEntity(ID);
    if QuestTools.SameSector(_Entity, NewPosition) then
        return NewPosition;
    end
    return nil;
end

---
-- Checks if an army or entity is dead. If an army has not been created yet
-- then it will not falsely assumed to be dead.
--
-- @param _input Army or entity (string, number oder table)
-- @return[type=boolean] Army or entity is dead
-- @within Entities
--
function QuestTools.IsDead(_input)
    if type(_input) == "table" and not _input.created then
        _input.created = not IsDeadOrig(_input);
        return false;
    end
    return IsDeadOrig(_input);
end
IsDeadOrig = IsDead;
IsDead = QuestTools.IsDead;

---
-- Checks if the position table contains a valid position on the map.
--
-- @param[type=table] _pos Position to check
-- @return[type=boolean] Position valid
-- @within Entities
--
function QuestTools.IsValidPosition(_pos)
	if type(_pos) == "table" then
		if (_pos.X ~= nil and type(_pos.X) == "number") and (_pos.Y ~= nil and type(_pos.Y) == "number") then
			local world = {Logic.WorldGetSize()};
			if _pos.X <= world[1] and _pos.X >= 0 and _pos.Y <= world[2] and _pos.Y >= 0 then
				return true;
			end
		end
	end
	return false;
end
IsValidPosition = QuestTools.IsValidPosition;

---
-- Returns a position on a circle at the given angle.
--
-- @param _Position              Schriptname or id of building
-- @param[type=number] _AreaSize Radius of circle
-- @param[type=number] _Angle    Angle on circle
-- @return[type=table] Position on circle
-- @within Entities
--
function QuestTools.GetCirclePosition(_Position, _AreaSize, _Angle)
    if type(_Position) ~= "table" then
        _Position = GetPosition(_Position);
    end
    assert(type(_Position) == "table")
    local Angle = math.rad(_Angle)
    assert(type(Angle) == "number")
    assert(type(_AreaSize) == "number")
    return {
        X = _Position.X + math.cos(Angle) * _AreaSize,
        Y = _Position.Y + math.sin(Angle) * _AreaSize  
    }
end
GetCirclePosition = QuestTools.GetCirclePosition;

---
-- Returns Returns the angle between the two given positions or entities.
--
-- @param _Pos1 First position
-- @param _Pos2 Second position
-- @return[type=number] Angle between positions
-- @within Entities
--
function QuestTools.GetAngleBetween(_Pos1,_Pos2)
	local delta_X = 0;
	local delta_Y = 0;
	local alpha   = 0
	if type (_Pos1) == "string" or type (_Pos1) == "number" then
		_Pos1 = GetPosition(GetEntityId(_Pos1));
	end
	if type (_Pos2) == "string" or type (_Pos2) == "number" then
		_Pos2 = GetPosition(GetEntityId(_Pos2));
	end
	delta_X = _Pos1.X - _Pos2.X
	delta_Y = _Pos1.Y - _Pos2.Y
	if delta_X == 0 and delta_Y == 0 then -- Gleicher Punkt
		return 0
	end
	alpha = math.deg(math.asin(math.abs(delta_X)/(math.sqrt(__pow(delta_X, 2)+__pow(delta_Y, 2)))))
	if delta_X >= 0 and delta_Y > 0 then
		alpha = 270 - alpha 
	elseif delta_X < 0 and delta_Y > 0 then
		alpha = 270 + alpha
	elseif delta_X < 0 and delta_Y <= 0 then
		alpha = 90  - alpha
	elseif delta_X >= 0 and delta_Y <= 0 then
		alpha = 90  + alpha
	end
	return alpha
end
GetAngleBetween = QuestTools.GetAngleBetween;
Winkel = QuestTools.GetAngleBetween;

---
-- Checks if a building is currently being upgraded.
--
-- @param _Entity Schriptname or id of building
-- @return[type=boolean] Building is being upgraded
-- @within Entities
--
function QuestTools.IsBuildingBeingUpgraded(_Entity)
    local BuildingID = GetID(_Entity);
    if Logic.IsBuilding(BuildingID) == 0 then
        return false;
    end
    local Value = Logic.GetRemainingUpgradeTimeForBuilding(BuildingID);
    local Limit = Logic.GetTotalUpgradeTimeForBuilding(BuildingID);
    return Limit - Value > 0;
end

---
-- Returns the leader entity ID of the soldier.
--
-- @param[type=number] _eID Entity ID of soldier
-- @return[type=number] Entity ID of leader
-- @within Entities
--
function QuestTools.SoldierGetLeader(_eID)
    if Logic.IsEntityInCategory(_eID, EntityCategories.Soldier) == 1 then
        if QuestSync:IsHistoryEdition() then
            return Logic.GetEntityScriptingValue(_eID, 66) or _eID;
        else
            return Logic.GetEntityScriptingValue(_eID, 69) or _eID;
        end
    end
    return _eID;
end
SoldierGetLeader = QuestTools.SoldierGetLeader;

---
-- Returns all categories the entity is in.
--
-- @param _Entity Scriptname or ID
-- @return[type=table] Category list
-- @within Entities
--
function QuestTools.GetEntityCategories(_Entity)
    local Categories = {};
    for k, v in pairs(EntityCategories) do
        if Logic.IsEntityInCategory(GetID(_Entity), v) == 1 then
            table.insert(Categories, v);
        end
    end
    return Categories;
end
GetEntityCategories = QuestTools.GetEntityCategories;

---
-- Returns the script name of the entity. If the entity do not have a name a
-- unique ongoing name is added to the entity and returned
--
-- @param[type=number] _eID EntityID
-- @return[type=string] Script name
-- @within Entities
--
function QuestTools.CreateNameForEntity(_eID)
    if type(_eID) == "string" then
        return _eID;
    else
        assert(type(_eID) == "number");
        local name = Logic.GetEntityName(_eID);
        if (type(name) ~= "string" or name == "" ) then
            QuestTools.EntityNameCounter = QuestTools.EntityNameCounter + 1;
            name = "eName_"..QuestTools.EntityNameCounter;
            Logic.SetEntityName(_eID,name);
        end
        return name;
    end
end
GiveEntityName = QuestTools.CreateNameForEntity;

-- Diplomacy --

---
-- Checks the area for entities of an enemy player.
--
-- @param[type=number] _player   Player ID
-- @param[type=table]  _position Area center
-- @param[type=number] _range    Area size
-- @return[type=boolean] Enemies near
-- @within Diplomacy
--
function QuestTools.AreEnemiesInArea( _player, _position, _range)
    return QuestTools.AreEntitiesOfDiplomacyStateInArea(_player, _position, _range, Diplomacy.Hostile);
end
AreEnemiesInArea = QuestTools.AreEnemiesInArea;

---
-- Checks the area for entities of an allied player.
--
-- @param[type=number] _player   Player ID
-- @param[type=table]  _position Area center
-- @param[type=number] _range    Area size
-- @return[type=boolean] Allies near
-- @within Diplomacy
--
function QuestTools.AreAlliesInArea( _player, _position, _range)
    return QuestTools.AreEntitiesOfDiplomacyStateInArea(_player, _position, _range, Diplomacy.Friendly);
end
AreAlliesInArea = QuestTools.AreAlliesInArea;

---
-- Checks the area for entities of other parties with a diplomatic state to
-- the player.
--
-- The first 16 player entities in the area will be evaluated. If they're not
-- settler, heroes or buldings, they will be ignored.
--
-- @param[type=number] _player   Player ID
-- @param[type=table]  _position Area center
-- @param[type=number] _range    Area size
-- @param[type=number] _state    Diplomatic state
-- @return[type=boolean] Entities near
-- @within Diplomacy
--
function QuestTools.AreEntitiesOfDiplomacyStateInArea(_player, _position, _range, _state)
	for i = 1,8 do
        if Logic.GetDiplomacyState(_player, i) == _state then
            local Data = {Logic.GetPlayerEntitiesInArea(i, 0, _position.X, _position.Y, _range, 16)};
            table.remove(Data, 1);
            for j= table.getn(Data), 1, -1 do
                if Logic.IsSettler(Data[j]) == 0 and Logic.IsBuilding(Data[j]) == 0 and Logic.IsHero(Data[j]) == 0 then
                    table.remove(Data, j);
                end
            end
            if table.getn(Data) > 0 then
				return true;
			end
		end
	end
	return false;
end

-- Jobs --

---
-- Creates a new inline job.
--
-- If a table is passed as one of the arguments then a copy will be created.
-- It will not be a reference because of saving issues.
--
-- @param[type=number]   _EventType Event type
-- @param[type=function] _Function Lua function reference
-- @param ...            Optional arguments
-- @return[type=number] ID of started job
-- @within Jobs
--
function QuestTools.StartInlineJob(_EventType, _Function, ...)
    -- Who needs a trigger fix. :D
    QuestTools.InlineJobs.Counter = QuestTools.InlineJobs.Counter +1;
    _G["QuestTools_InlineJob_Data_" ..QuestTools.InlineJobs.Counter] = copy(arg);
    _G["QuestTools_InlineJob_Function_" ..QuestTools.InlineJobs.Counter] = _Function;
    _G["QuestTools_InlineJob_Executor_" ..QuestTools.InlineJobs.Counter] = function(i)
        if _G["QuestTools_InlineJob_Function_" ..i](unpack(_G["QuestTools_InlineJob_Data_" ..i])) then
            return true;
        end
    end
    return Trigger.RequestTrigger(
        _EventType,
        "",
        "QuestTools_InlineJob_Executor_" ..QuestTools.InlineJobs.Counter,
        1,
        {},
        {QuestTools.InlineJobs.Counter}
    );
end
StartInlineJob = QuestTools.StartInlineJob;

---
-- Creates an inline job that is executed every second.
-- @param[type=function] _Function Lua function reference
-- @param                ... Optional arguments
-- @return[type=number] Job ID
-- @within Jobs
--
function QuestTools.StartSimpleJobEx(_Function, ...)
    return QuestTools.StartInlineJob(Events.LOGIC_EVENT_EVERY_SECOND, _Function, unpack(arg));
end
StartSimpleJobEx = QuestTools.StartSimpleJobEx;

---
-- Creates an inline job that is executed ten times per second.
-- @param[type=function] _Function Lua function reference
-- @param                ... Optional arguments
-- @return[type=number] Job ID
-- @within Jobs
--
function QuestTools.StartSimpleHiResJobEx(_Function, ...)
    return QuestTools.StartInlineJob(Events.LOGIC_EVENT_EVERY_TURN, _Function, unpack(arg));
end
StartSimpleHiResJobEx = QuestTools.StartSimpleHiResJobEx;

-- AI --

---
-- Checks, if the positions are in the same sector. If 2 possitions are not
-- in the same sector then they are not connected.
--
-- @param _pos1 Position 1
-- @param _pos2 Position 2
-- @return[type=boolean] Same sector
-- @within AI
--
function QuestTools.SameSector(_pos1, _pos2)
	local sectorEntity1 = _pos1;
	local toVanish1;
	if type(sectorEntity1) == "table" then
		sectorEntity1 = Logic.CreateEntity(Entities.XD_ScriptEntity, _pos1.X, _pos1.Y, 0, 8);
		toVanish1 = true;
    end
    
	local sectorEntity2 = _pos2;
	local toVanish2;
	if type(sectorEntity2) == "table" then
		sectorEntity2 = Logic.CreateEntity(Entities.XD_ScriptEntity, _pos2.X, _pos2.Y, 0, 8);
		toVanish2 = true;
	end

	local eID1 = GetID(sectorEntity1);
	local eID2 = GetID(sectorEntity2);
	if (eID1 == nil or eID1 == 0) or (eID2 == nil or eID2 == 0) then
		return false;
	end

	local sector1 = Logic.GetSector(eID1)
	if toVanish1 then
		DestroyEntity(eID1);
	end
	local sector2 = Logic.GetSector(eID2)
	if toVanish2 then
		DestroyEntity(eID2);
	end
    return (sector1 ~= 0 and sector2 ~= 0 and sector1 == sector2);
end
SameSector = QuestTools.SameSector;

