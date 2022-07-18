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
-- <li>qsb.oop</li>
-- <li>qsb.quest.questsync</li>
-- <li>qsb.ext.svlib</li>
-- </ul>
--
-- @set sort=true
--

QuestTools = {
    InlineJobs = {Counter = 0},
    WaypointData = {},
    EntityNameCounter = 0,
};

-- Utils --

---
-- Returns the extension number. This function can be used to identify the
-- current expansion of the game.
-- @return[type=number] Extension
-- @within Utils
--
function GetExtensionNumber()
    local Version = Framework.GetProgramVersion();
    local extensionNumber = tonumber(string.sub(Version, string.len(Version))) or 0;
    return extensionNumber;
end

---
-- Returns the short name of the game language.
-- @return[type=string] Short name
-- @within Utils
--
function GetLanguage()
    local ShortLang = string.lower(XNetworkUbiCom.Tool_GetCurrentLanguageShortName());
    return (ShortLang == "de" and "de") or "en";
end

---
-- Returns the localized text from the input.
-- @param _Text Text to translate
-- @return[type=string] 
-- @within Utils
--
function GetLocalizedTextInTable(_Text)
    if type(_Text) == "table" then
        return _Text[GetLanguage()] or " ERROR_TEXT_INVALID ";
    end
    return _Text;
end

---
-- Checks if a value is inside a table.
--
-- <b>Alias</b>: IstDrin
--
-- @param             _Value Value to find
-- @param[type=table] _Table Table to search
-- @return[type=boolean] Value found
-- @within Utils
--
function IsInTable(_Value, _Table)
	return GetKeyByValue(_Value, _Table) ~= nil;
end
IstDrin = IsInTable;

---
-- Returns the key of the given value in the table if value is existing.
--
-- <b>Alias</b>: KeyOf
--
-- @param             _Value Value of key
-- @param[type=table] _Table Table to search
-- @return Key of value
-- @within Utils
--
function GetKeyByValue(_Value, _Table)
    for k, v in pairs(_Table) do 
        if v == _Value then
            return k;
        end
    end
end
KeyOf = GetKeyByValue;

---
-- Displays the name of any function that is to large to be loaded when a
-- savegame is loaded.
-- @param[type=table] t Table to check
-- @within Utils
-- @local
--
function CheckFunctionSize(t)
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
            CheckFunctionSize(v);
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
-- SaveCall returns the return value of the function if no errors
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
function SaveCall(_Data)
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
                    return SaveCall{_Data.ErrorHandler, Values[2], unpack(_Data)};
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
-- <b>Alias</b>: Round
--
-- <b>Alias</b>: round
--
-- @param[type=number] _Value Number to round
-- @return[type=number] Rounded number
-- @within Utils
-- @local
--
--
function Round(_Value)
    return math.floor(_Value + 0.5);
end
Round = Round;
round = Round;

-- Entities --

---
-- Returns the relative health of the entity.
--
-- <b>Alias</b>: GetHealth
--
-- @param               _Entity Skriptname or ID of entity
-- @return[type=number] Relative health
-- @within Entities
--
function GetHealth(_Entity)
    local EntityID = GetEntityId(_Entity);
    if not Tools.IsEntityAlive(EntityID) then
        return 0;
    end
    local MaxHealth = Logic.GetEntityMaxHealth(EntityID);
    local Health = Logic.GetEntityHealth(EntityID);
    return (Health / MaxHealth) * 100;
end
GetHealth = GetHealth;

---
-- Sets the visibility of the entity.
--
-- @param               _Entity Skriptname or ID of entity
-- @param[type=boolean] _Flag   Visibility flag
-- @within Entities
--
function SetVisible(_Entity, _Flag)
    SVLib.SetInvisibility(GetID(_Entity), not _Flag);
end

---
-- Returns true if the entity is visible.
--
-- @param _Entity Skriptname or ID of entity
-- @return[type=boolean] Entity is visible
-- @within Entities
--
function IsVisible(_Entity)
    return not SVLib.GetInvisibility(GetID(_Entity));
end

---
-- Sets the height of the building.
--
-- @param _Entity              Skriptname or ID of entity
-- @param[type=number] _Height New building height
-- @within Entities
--
function SetBuildingHeight(_Entity, _Height)
    local ID = GetID(_Entity);
    if Logic.IsBuilding(ID) == 0 then
        return;
    end
    SVLib.SetHightOfBuilding(ID, _Height);
end

---
-- Returns the height of the building.
--
-- @param _Entity Skriptname or ID of entity
-- @return[type=number] Building height
-- @within Entities
--
function GetBuildingHeight(_Entity)
    local ID = GetID(_Entity);
    if Logic.IsBuilding(ID) == 0 then
        return 1;
    end
    return SVLib.GetHightOfBuilding(ID);
end

---
-- Changes the relative health of an entity.
--
-- <b>Alias</b>: SetHealth
--
-- @param _Entity               Skriptname or ID of entity
-- @param[type=number] _Percent Amount of health
-- @within Entities
--
function SetHealthWrapper(_Entity, _Percent)
    local ID = GetID(_Entity);
    if Logic.IsLeader(ID) == 1 then
        local Soldiers = {Logic.GetSoldiersAttachedToLeader(ID)};
        for i= 2, Soldiers[1]+1, 1 do
            SetHealthOrig(Soldiers[i], _Percent);
        end
    end
    SetHealthOrig(ID, _Percent);
end
SetHealthOrig = SetHealth;
SetHealth = SetHealthWrapper;

---
-- Sets the sub task index of the entity.
--
-- @param _Entity             Skriptname or ID of entity
-- @param[type=number] _Index Index of Task
-- @within Entities
--
function SetSubTask(_Entity, _Index)
    local ID = GetID(_Entity);
    if not IsExisting(ID) then
        return;
    end
    SVLib.SetTaskSubIndexNumber(ID, _Index);
end

---
-- Returns the index of the sub task of the entity.
--
-- @param _Entity       Skriptname or ID of entity
-- @return[type=number] Sub task index
-- @within Entities
--
function GetSubTask(_Entity)
    local ID = GetID(_Entity);
    if not IsExisting(ID) then
        return;
    end
    return SVLib.GetTaskSubIndexNumber(ID);
end

---
-- Changes the size of an entity. Only influences the model and not the
-- blocking or collision.
--
-- @param _Entity            Skriptname or ID of entity
-- @param[type=number] _Size Size as float (1.3 ect)
-- @within Entities
--
function SetEntitySize(_Entity, _Size)
    local ID = GetID(_Entity);
    if not IsExisting(ID) then
        return;
    end
    SVLib.SetEntitySize(ID, _Size);
end

---
-- Returns the size of the entity.
--
-- @param _Entity       Skriptname or ID of entity
-- @return[type=number] Entity size
-- @within Entities
--
function GetEntitySize(_Entity)
    local ID = GetID(_Entity);
    if not IsExisting(ID) then
        return;
    end
    return SVLib.GetEntitySize(ID);
end

---
-- Changes the resource type obtained from the resource entity.
--
-- @param _Entity                    Skriptname or ID of entity
-- @param[type=number] _ResourceType Type of resource
-- @within Entities
--
function SetEntitySize(_Entity, _ResourceType)
    local ID = GetID(_Entity);
    if not IsExisting(ID) then
        return;
    end
    SVLib.SetResourceType(ID, _ResourceType);
end

---
-- Returns a list of all leader of the player.
--
-- @param[type=number] _PlayerID ID of player
-- @return[type=table] List of leaders
-- @within Entities
--
function GetAllLeader(_PlayerID)
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
function GetAllCannons(_PlayerID)
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
--
-- <b>Alias</b>: GetPlayerEntities
--
-- @param[type=number] _PlayerID   ID of player
-- @param[type=number] _EntityType Type to search
-- @return[type=table] List of entities
-- @within Entities
--
function GetPlayerEntities(_PlayerID, _EntityType)
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
GetPlayerEntities = GetPlayerEntities;

---
-- Finds all entities numbered from 1 to n with a common prefix.
--
-- <b>Alias</b>: GetEntitiesByPrefix
--
-- @param[type=string] _Prefix Prefix of scriptnames
-- @return[type=table] List of entities
-- @within Entities
--
function GetEntitiesByPrefix(_Prefix)
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
GetEntitiesByPrefix = GetEntitiesByPrefix;

---
-- Checks worldwide for doodad entities or player entities.
--
-- Be careful: This method is using expensive area checks. Do better not use
-- it inside of jobs.
--
-- <b>Alias</b>: SucheAufDerWelt
--
-- @param[type=number] _PlayerID ID of player
-- @param[type=number] _Type     Type of entity
-- @param[type=number] _AreaSize (Optional) Area size
-- @param[type=table]  _Position (Optional) Area center
-- @return[type=table] Result set
-- @within Entities
--
function FindAllEntities(_PlayerID, _Type, _AreaSize, _Position, _Depth)
	local ResultSet = {};
    -- Hack: prevent stack overflow
    _Depth = _Depth or 0;
    if _Depth > 16 then
        return ResultSet;
    end
    
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
		local ResultSetRecursive = FindAllEntities(_PlayerID, _Type, HalfAreaSize, {X=PositionX1,Y=PositionY1}, _Depth+1);
		for i = 1, table.getn(ResultSetRecursive) do
			if not IsInTable(ResultSetRecursive[i], ResultSet) then
				table.insert(ResultSet, ResultSetRecursive[i]);
			end
		end
		local ResultSetRecursive = FindAllEntities(_PlayerID, _Type, HalfAreaSize, {X=PositionX1,Y=PositionY2}, _Depth+1);
		for i = 1, table.getn(ResultSetRecursive) do
			if not IsInTable(ResultSetRecursive[i], ResultSet) then
				table.insert(ResultSet, ResultSetRecursive[i]);
			end
		end
		local ResultSetRecursive = FindAllEntities(_PlayerID, _Type, HalfAreaSize, {X=PositionX2,Y=PositionY1}, _Depth+1);
		for i = 1, table.getn(ResultSetRecursive) do
			if not IsInTable(ResultSetRecursive[i], ResultSet) then
				table.insert(ResultSet, ResultSetRecursive[i]);
			end
		end
		local ResultSetRecursive = FindAllEntities(_PlayerID, _Type, HalfAreaSize, {X=PositionX2,Y=PositionY2}, _Depth+1);
		for i = 1, table.getn(ResultSetRecursive) do
			if not IsInTable(ResultSetRecursive[i], ResultSet) then
				table.insert(ResultSet, ResultSetRecursive[i]);
			end
		end
	else
		table.remove(Data, 1);
		for i = 1, table.getn(Data) do
			if not IsInTable(Data[i], ResultSet) then
				table.insert(ResultSet, Data[i]);
			end
		end
	end
	return ResultSet
end
SucheAufDerWelt = FindAllEntities

---
-- Returns the distance between two positions or entities.
--
-- <b>Alias</b>: GetDistance
--
-- @param _pos1 Position 1 (string, number oder table)
-- @param _pos2 Position 2 (string, number oder table)
-- @return[type=number] Distance between positions
-- @within Entities
--
function GetDistance(_pos1, _pos2)
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
GetDistance = GetDistance;

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
function GetGeometricFocus(...)
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
function GetReachablePosition(_Entity, _Target)
    local PlayerID = Logic.EntityGetPlayer(GetID(_Entity));
    local Position1 = GetPosition(_Entity);
    local Position2 =_Target;
    if (type(Position2) == "string") or (type(Position2) == "number") then
        Position2 = GetPosition(_Target);
    end
	assert(type(Position1) == "table");
    assert(type(Position2) == "table");
    local ID = AI.Entity_CreateFormation(PlayerID, Entities.PU_Serf, 0, 0, Position2.X, Position2.Y, 0, 0, 0, 0);
    if SameSector(_Entity, ID) then
        local NewPosition = GetPosition(ID);
        DestroyEntity(ID);
        return NewPosition;
    end
    DestroyEntity(ID);
    return nil;
end

function IsDeadWrapper(_input)
    if type(_input) == "table" and not _input.created then
        _input.created = not IsDeadOrig(_input);
        return false;
    end
    return IsDeadOrig(_input);
end
IsDeadOrig = IsDead;

---
-- Checks if an army or entity is dead. If an Blue Byte army has not been
-- created yet then it will not falsely assumed to be dead.
--
-- <b>Alias</b>: IsDead
--
-- @param _input Army or entity (string, number oder table)
-- @return[type=boolean] Army or entity is dead
-- @within Entities
--
IsDead = IsDeadWrapper;

---
-- Checks if the position table contains a valid position on the map.
--
-- <b>Alias</b>: IsValidPosition
--
-- @param[type=table] _pos Position to check
-- @return[type=boolean] Position valid
-- @within Entities
--
function IsValidPosition(_pos)
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
IsValidPosition = IsValidPosition;

---
-- Returns a position on a circle at the given angle.
--
-- <b>Alias</b>: GetCirclePosition
--
-- @param _Position              Schriptname or id of building
-- @param[type=number] _AreaSize Radius of circle
-- @param[type=number] _Angle    Angle on circle
-- @return[type=table] Position on circle
-- @within Entities
--
function GetCirclePosition(_Position, _AreaSize, _Angle)
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
GetCirclePosition = GetCirclePosition;

---
-- Returns Returns the angle between the two given positions or entities.
--
-- <b>Alias</b>: GetAngleBetween
--
-- <b>Alias</b>: Winkel
--
-- @param _Pos1 First position
-- @param _Pos2 Second position
-- @return[type=number] Angle between positions
-- @within Entities
--
function GetAngleBetween(_Pos1,_Pos2)
	local delta_X = 0;
	local delta_Y = 0;
	local alpha   = 0;
	if type (_Pos1) == "string" or type (_Pos1) == "number" then
		_Pos1 = GetPosition(GetEntityId(_Pos1));
	end
	if type (_Pos2) == "string" or type (_Pos2) == "number" then
		_Pos2 = GetPosition(GetEntityId(_Pos2));
	end
	delta_X = _Pos1.X - _Pos2.X;
	delta_Y = _Pos1.Y - _Pos2.Y;
	if delta_X == 0 and delta_Y == 0 then
		return 0;
	end
	alpha = math.deg(math.asin(math.abs(delta_X)/(math.sqrt(delta_X^2 + delta_Y^2))));
	if delta_X >= 0 and delta_Y > 0 then
		alpha = 270 - alpha ;
	elseif delta_X < 0 and delta_Y > 0 then
		alpha = 270 + alpha;
	elseif delta_X < 0 and delta_Y <= 0 then
		alpha = 90  - alpha;
	elseif delta_X >= 0 and delta_Y <= 0 then
		alpha = 90  + alpha;
	end
	return alpha;
end
GetAngleBetween = GetAngleBetween;
Winkel = GetAngleBetween;

---
-- Checks if a building is currently being upgraded.
--
-- <b>Alias</b>: IsBuildingBeingUpgraded
--
-- @param _Entity Schriptname or id of building
-- @return[type=boolean] Building is being upgraded
-- @within Entities
--
function IsBuildingBeingUpgraded(_Entity)
    local BuildingID = GetID(_Entity);
    if Logic.IsBuilding(BuildingID) == 0 then
        return false;
    end
    local Value = Logic.GetRemainingUpgradeTimeForBuilding(BuildingID);
    local Limit = Logic.GetTotalUpgradeTimeForBuilding(BuildingID);
    return Limit - Value > 0;
end
IsBuildingBeingUpgraded = IsBuildingBeingUpgraded;

---
-- Returns the leader entity ID of the soldier.
--
-- <b>Alias</b>: SoldierGetLeader
--
-- @param[type=number] _Soldier Entity ID of soldier
-- @return[type=number] Entity ID of leader
-- @within Entities
--
function SoldierGetLeader(_Soldier)    
    if Logic.IsEntityInCategory(_Soldier, EntityCategories.Soldier) == 1 then
        return SVLib.GetLeaderOfSoldier(GetID(_Soldier));
    end
    return GetID(_Soldier);
end
SoldierGetLeader = SoldierGetLeader;

---
-- Returns true, if the entity has one of the passed entity types.
--
-- <b>Alias</b>: HasOneOfTypes
--
-- @param              _Entity Scriptname or ID
-- @param[type=number] ...     List of types
-- @return[type=boolean] Has one type
-- @within Entities
--
function HasOneOfTypes(_Entity, ...)
    for k, v in pairs(arg) do
        if Logic.GetEntityType(GetID(_Entity)) == v then
            return true;
        end
    end
    return false;
end
HasOneOfTypes = HasOneOfTypes;

---
-- Returns true, if the entity has one of the passed entity categories.
--
-- <b>Alias</b>: HasOneOfCategories
--
-- @param              _Entity Scriptname or ID
-- @param[type=number] ...     List of categories
-- @return[type=boolean] Has one type
-- @within Entities
--
function HasOneOfCategories(_Entity, ...)
    for k, v in pairs(arg) do
        if Logic.IsEntityInCategory(GetID(_Entity), v) == 1 then
            return true;
        end
    end
    return false;
end
HasOneOfCategories = HasOneOfCategories;

---
-- Returns all categories the entity is in.
--
-- <b>Alias</b>: GetEntityCategories
--
-- @param _Entity Scriptname or ID
-- @return[type=table] Category list
-- @within Entities
--
function GetEntityCategories(_Entity)
    local Categories = {};
    for k, v in pairs(EntityCategories) do
        if Logic.IsEntityInCategory(GetID(_Entity), v) == 1 then
            table.insert(Categories, v);
        end
    end
    return Categories;
end
GetEntityCategories = GetEntityCategories;

---
-- Returns all keys of the categories the entity is in.
--
-- <b>Alias</b>: GetEntityCategoriesAsString
--
-- @param _Entity Scriptname or ID
-- @return[type=table] Category list
-- @within Entities
--
function GetEntityCategoriesAsString(_Entity)
    local Categories = {};
    for k, v in pairs(EntityCategories) do
        if Logic.IsEntityInCategory(GetID(_Entity), v) == 1 then
            table.insert(Categories, k);
        end
    end
    return Categories;
end
GetEntityCategoriesAsString = GetEntityCategoriesAsString;

---
-- Returns the script name of the entity. If the entity do not have a name a
-- unique ongoing name is added to the entity and returned
--
-- <b>Alias</b>: GiveEntityName
--
-- @param[type=number] _eID EntityID
-- @return[type=string] Script name
-- @within Entities
--
function CreateNameForEntity(_eID)
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
GiveEntityName = CreateNameForEntity;

---
-- Moves an entity to the destination and replaces it with an script entity
-- on arrival.
--
-- <b>Alias</b>: MoveAndVanish
--
-- @param[type=number] _Entity   Entity to move
-- @param[type=number] _Target   Position where to move
-- @param[type=number] _PlayerID Area size
-- @return[type=number] ID of moving job
-- @within Entities
--
function MoveAndVanish(_Entity, _Target)
    if SameSector(_Entity, _Target) then
        Move(_Entity, _Target);
    end

    local JobID = StartSimpleJobEx(function(_EntityID, _Target)
        if not IsExisting(_EntityID) then
            return true;
        end
        if not Logic.IsEntityMoving(_EntityID) then
            if SameSector(_Entity, _Target) then
                Move(_EntityID, _Target);
            end
        end
        if IsNear(_EntityID, _Target, 150) then
            local PlayerID = Logic.EntityGetPlayer(_EntityID);
            local Orientation = Logic.GetEntityOrientation(_EntityID);
            local ScriptName = Logic.GetEntityName(_EntityID);
            local x, y, z = Logic.EntityGetPos(_EntityID);
            DestroyEntity(_EntityID);
            local ID = Logic.CreateEntity(Entities.XD_ScriptEntity, x, y, Orientation, PlayerID);
            Logic.SetEntityName(ID, ScriptName);
            return true;
        end
    end, GetID(_Entity), _Target);
    return JobID;
end
MoveAndVanish = MoveAndVanish;

---
-- Moves an entity over the passed waypoints. The entity can be replaced with
-- an script entity once it reaches the final destination.
--
-- Waypoints are passed as table. They can contain the following fields:
-- <table border="1">
-- <tr>
-- <td><b>Field</b></td>
-- <td><b>Description</b></td>
-- </tr>
-- <tr>
-- <td>Target</td>
-- <td>Script name of the waypoint</td>
-- </tr>
-- <tr>
-- <td>Distance</td>
-- <td>(Optional) Radius the entity must be in around the target.</td>
-- </tr>
-- <tr>
-- <td>IgnoreBlocking</td>
-- <td>(Optional) Entity is using the direct way and ignores evenry blocking. (This can
-- be used to move them in and out of buildings)</td>
-- </tr>
-- <tr>
-- <td>Waittime</td>
-- <td>(Optional) Time in seconds the entity waits until moving to the next waypoint.</td>
-- </tr>
-- <tr>
-- <td>Callback</td>
-- <td>(Optional) Function called when entity passes waypoint. (If a waittime is
-- set the function is called after waittime is over)</td>
-- </tr>
-- </table>
--
-- <b>Alias</b>: MoveOnWaypoints
--
-- @param[type=number]  _Entity Entity to move
-- @param[type=boolean] _Vanish Delete on last waypoint
-- @param[type=table]   ...     List of waypoints
-- @return[type=number] ID of moving job
-- @within Entities
--
function MoveOnWaypoints(_Entity, _Vanish, ...)
    if not IsExisting(_Entity) then
        return;
    end

    local ID = GetID(_Entity);
    QuestTools.WaypointData[ID] = {
        Vanish = _Vanish == true,
        Current = 1,
    };
    for i= 1, table.getn(arg), 1 do
        table.insert(
            QuestTools.WaypointData[ID],
            {arg[i].Target,
             arg[i].Distance or 50,
             arg[i].IgnoreBlocking == true,
             (arg[i].Waittime or 0) * 10,
             arg[i].Callback}
        );
    end

    local JobID = StartSimpleHiResJobEx(function(_ID)
        if not IsExisting(_ID) or not QuestTools.WaypointData[_ID] then
            return true;
        end
        local Index = QuestTools.WaypointData[_ID].Current;
        local Data  = QuestTools.WaypointData[_ID][Index];

        local Task = Logic.GetCurrentTaskList(_ID);
        if not string.find(Task or "", "WALK") then
            local x, y, z = Logic.EntityGetPos(GetID(Data[1]));
            if Data[3] then
                Logic.SetTaskList(_ID, TaskLists.TL_NPC_WALK);
                Logic.MoveEntity(_ID, x, y);
            else
                Logic.MoveSettler(_ID, x, y);
            end
        end

        if IsNear(_ID, Data[1], Data[2]) then
            if QuestTools.WaypointData[_ID][Index][4] > 0 then
                QuestTools.WaypointData[_ID][Index][4] = Data[4] -1;
                if string.find(Task or "", "WALK") then
                    Logic.SetTaskList(_ID, TaskLists.TL_NPC_IDLE);
                end
            else
                QuestTools.WaypointData[_ID].Current = Index +1;
                if Data[5] then
                    Data[5](Data);
                end
            end
            if Index == table.getn(QuestTools.WaypointData[_ID]) then
                if QuestTools.WaypointData[_ID].Vanish then
                    local PlayerID = Logic.EntityGetPlayer(_ID);
                    local Orientation = Logic.GetEntityOrientation(_ID);
                    local ScriptName = Logic.GetEntityName(_ID);
                    local x, y, z = Logic.EntityGetPos(_ID);
                    DestroyEntity(_ID);
                    local NewID = Logic.CreateEntity(Entities.XD_ScriptEntity, x, y, Orientation, PlayerID);
                    Logic.SetEntityName(NewID, ScriptName);
                end
                QuestTools.WaypointData[_ID] = nil;
                return true;
            end
        end
    end, ID);
    return JobID;
end
MoveOnWaypoints = MoveOnWaypoints;

-- Diplomacy --

---
-- Checks the area for entities of an enemy player.
--
-- <b>Alias</b>: AreEnemiesInArea
--
-- @param[type=number] _player   Player ID
-- @param[type=table]  _position Area center
-- @param[type=number] _range    Area size
-- @return[type=boolean] Enemies near
-- @within Diplomacy
--
function AreEnemiesInArea( _player, _position, _range)
    return AreEntitiesOfDiplomacyStateInArea(_player, _position, _range, Diplomacy.Hostile);
end
AreEnemiesInArea = AreEnemiesInArea;

---
-- Checks the area for entities of an allied player.
--
-- <b>Alias</b>: AreAlliesInArea
--
-- @param[type=number] _player   Player ID
-- @param[type=table]  _position Area center
-- @param[type=number] _range    Area size
-- @return[type=boolean] Allies near
-- @within Diplomacy
--
function AreAlliesInArea( _player, _position, _range)
    return AreEntitiesOfDiplomacyStateInArea(_player, _position, _range, Diplomacy.Friendly);
end
AreAlliesInArea = AreAlliesInArea;

---
-- Checks the area for entities of other parties with a diplomatic state to
-- the player.
--
-- @param[type=number] _player   Player ID
-- @param[type=table]  _position Area center
-- @param[type=number] _range    Area size
-- @param[type=number] _state    Diplomatic state
-- @return[type=boolean] Entities near
-- @within Diplomacy
--
function AreEntitiesOfDiplomacyStateInArea(_player, _Position, _range, _state)
	local Position = _Position;
    if type(Position) ~= "table" then
        Position = GetPosition(Position);
    end
    for i = 1, 8 do
        if i ~= _player and Logic.GetDiplomacyState(_player, i) == _state then
            if Logic.IsPlayerEntityOfCategoryInArea(i, Position.X, Position.Y, _range, "DefendableBuilding", "Military", "MilitaryBuilding") == 1 then
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
-- <b>Alias</b>: StartInlineJob
--
-- @param[type=number]   _EventType Event type
-- @param[type=function] _Function Lua function reference
-- @param ...            Optional arguments
-- @return[type=number] ID of started job
-- @within Jobs
--
function StartInlineJob(_EventType, _Function, ...)
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
StartInlineJob = StartInlineJob;

---
-- Creates an inline job that is executed every second.
--
-- <b>Alias</b>: StartSimpleJobEx
--
-- @param[type=function] _Function Lua function reference
-- @param                ... Optional arguments
-- @return[type=number] Job ID
-- @within Jobs
--
function StartSimpleJobEx(_Function, ...)
    return StartInlineJob(Events.LOGIC_EVENT_EVERY_SECOND, _Function, unpack(arg));
end
StartSimpleJobEx = StartSimpleJobEx;

---
-- Creates an inline job that is executed ten times per second.
--
-- <b>Alias</b>: StartSimpleHiResJobEx
--
-- @param[type=function] _Function Lua function reference
-- @param                ... Optional arguments
-- @return[type=number] Job ID
-- @within Jobs
--
function StartSimpleHiResJobEx(_Function, ...)
    return StartInlineJob(Events.LOGIC_EVENT_EVERY_TURN, _Function, unpack(arg));
end
StartSimpleHiResJobEx = StartSimpleHiResJobEx;

---
-- Creates an classic countdown in the top left of the screen. A counter ticks
-- down to 0 and can trigger an optional callback function.
--
-- <b>Alias</b>: StartCountdown
--
-- @param[type=number]   _Limit    Time in seconds
-- @param[type=function] _Callback Callback function on counter finishes
-- @param[type=boolean]  _Show     Countdown is visible
-- @return[type=number] Counter ID
-- @within Jobs
--
function StartCountdown(_Limit, _Callback, _Show)
    assert(type(_Limit) == "number");
    assert( not _Callback or type(_Callback) == "function" );
    Counter.Index = (Counter.Index or 0) + 1;
    if _Show and CountdownIsVisisble() then
        assert(false, "StartCountdown: A countdown is already visible");
    end
    Counter["counter" .. Counter.Index] = {
        Limit = _Limit, 
        TickCount = 0, 
        Callback = _Callback, 
        Show = _Show, 
        Finished = false
    };
    if _Show then
        MapLocal_StartCountDown(_Limit);
    end
    if Counter.JobId == nil then
        Counter.JobId = StartSimpleJobEx(CountdownTick);
    end
    return Counter.Index;
end
StartCountdown = StartCountdown;

---
-- Stops an running countdown.
--
-- <b>Alias</b>: StopCountdown
--
-- @param[type=number]   _Id Index of Counter to stop
-- @within Jobs
--
function StopCountdown(_Id)
    if Counter.Index == nil then
        return;
    end
    if _Id == nil then
        for i = 1, Counter.Index do
            if Counter.IsValid("counter" .. i) then
                if Counter["counter" .. i].Show then
                    MapLocal_StopCountDown();
                end
                Counter["counter" .. i] = nil;
            end
        end
    else
        if Counter.IsValid("counter" .. _Id) then
            if Counter["counter" .. _Id].Show then
                MapLocal_StopCountDown();
            end
            Counter["counter" .. _Id] = nil;
        end
    end
end
StopCountdown = StopCountdown;

function CountdownTick()
    local empty = true;
    for i = 1, Counter.Index do
        if Counter.IsValid("counter" .. i) then
            if Counter.Tick("counter" .. i) then
                Counter["counter" .. i].Finished = true;
            end
            if Counter["counter" .. i].Finished and not IsBriefingActive() then
                if Counter["counter" .. i].Show then
                    MapLocal_StopCountDown();
                end
                if type(Counter["counter" .. i].Callback) == "function" then
                    Counter["counter" .. i].Callback();
                end
                Counter["counter" .. i] = nil;
            end
            empty = false;
        end
    end
    if empty then
        Counter.JobId = nil;
        Counter.Index = nil;
        return true;
    end
end
function CountdownIsVisisble()
    for i = 1, Counter.Index do
        if Counter.IsValid("counter" .. i) and Counter["counter" .. i].Show then
            return true;
        end
    end
    return false;
end
CountdownIsVisisble = CountdownIsVisisble;

-- AI --

---
-- Returns a table with the costs of a building type.
--
-- <b>Alias</b>: GetBuildingCostsTable
--
-- @param[type=number] _EntityType Building type
-- @return[type=table] Costs table
-- @within AI
--
function GetBuildingCostsTable(_EntityType)
    local BuildingCosts = {};
    Logic.FillBuildingCostsTable(_EntityType, BuildingCosts);
    return BuildingCosts;
end
GetBuildingCostsTable = GetBuildingCostsTable;

---
-- Returns a table with the upgrade costs of a building type.
--
-- <b>Alias</b>: GetBuildingUpgradeCostsTable
--
-- @param[type=number] _EntityType Building type
-- @return[type=table] Costs table
-- @within AI
--
function GetBuildingUpgradeCostsTable(_EntityType)
    local BuildingUpgradeCosts = {};
    Logic.FillBuildingUpgradeCostsTable(_EntityType, BuildingUpgradeCosts);
    return BuildingUpgradeCosts;
end
GetBuildingUpgradeCostsTable = GetBuildingUpgradeCostsTable;

---
-- Returns a table with the technology research costs.
--
-- <b>Alias</b>: GetTechnologyCostsTable
--
-- @param[type=number] _Technology Technology
-- @return[type=table] Costs table
-- @within AI
--
function GetTechnologyCostsTable(_Technology)
    local TechnologyCosts = {};
    Logic.FillTechnologyCostsTable(_Technology, TechnologyCosts);
    return TechnologyCosts;
end
GetTechnologyCostsTable = GetTechnologyCostsTable;

---
-- Returns a table with the soldier costs.
--
-- <b>Alias</b>: GetSoldierCostsTable
--
-- @param[type=number] _PlayerID     ID of player
-- @param[type=number] _SoldierUpCat Upgrade category soldier
-- @return[type=table] Costs table
-- @within AI
--
function GetSoldierCostsTable(_PlayerID, _SoldierUpCat)
    local SoldierCosts = {};
    Logic.FillSoldierCostsTable(_PlayerID, _SoldierUpCat, SoldierCosts);
    return SoldierCosts;
end
GetSoldierCostsTable = GetSoldierCostsTable;

---
-- Returns a table with the leader costs.
--
-- <b>Alias</b>: GetMilitaryCostsTable
--
-- @param[type=number] _PlayerID    ID of player
-- @param[type=number] _LeaderUpCat Upgrade category leader
-- @return[type=table] Costs table
-- @within AI
--
function GetMilitaryCostsTable(_PlayerID, _LeaderUpCat)
    local MilitaryCosts = {};
    Logic.FillLeaderCostsTable(_PlayerID, _LeaderUpCat, MilitaryCosts);
    return MilitaryCosts;
end
GetMilitaryCostsTable = GetMilitaryCostsTable;

---
-- Returns true if the player has enough resources.
--
-- <b>Alias</b>: HasEnoughResources
--
-- @param[type=number] _PlayerID ID of player
-- @param[type=table]  _Costs    Costs table
-- @return[type=boolean] Enough resources
-- @within AI
--
function HasEnoughResources(_PlayerID, _Costs)
	local Gold   = Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.Gold ) + Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.GoldRaw);
    local Clay   = Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.Clay ) + Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.ClayRaw);
	local Wood   = Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.Wood ) + Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.WoodRaw);
	local Iron   = Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.Iron ) + Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.IronRaw);
	local Stone  = Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.Stone ) + Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.StoneRaw);
    local Sulfur = Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.Sulfur ) + Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.SulfurRaw);
    
	if _Costs[ResourceType.Gold] ~= nil and Gold < _Costs[ResourceType.Gold] then
		return false;
    end
	if _Costs[ResourceType.Clay] ~= nil and Clay < _Costs[ResourceType.Clay]  then
		return false;
	end
	if _Costs[ResourceType.Wood] ~= nil and Wood < _Costs[ResourceType.Wood]  then
		return false;
	end
	if _Costs[ResourceType.Iron] ~= nil and Iron < _Costs[ResourceType.Iron] then		
		return false;
	end
	if _Costs[ResourceType.Stone] ~= nil and Stone < _Costs[ResourceType.Stone] then		
		return false;
	end
    if _Costs[ResourceType.Sulfur] ~= nil and Sulfur < _Costs[ResourceType.Sulfur] then		
		return false;
	end
    return true;
end
HasEnoughResources = HasEnoughResources;

---
-- Adds resources to the player by the given resource table.
--
-- <b>Alias</b>: AddResourcesToPlayer
--
-- @param[type=number] _PlayerID  ID of player
-- @param[type=table]  _Resources Resource table
-- @within AI
--
function AddResourcesToPlayer(_PlayerID, _Resources)

    if _Resources[ResourceType.Gold] ~= nil then
		AddGold(_PlayerID, _Resources[ResourceType.Gold] or _Resources[ResourceType.GoldRaw]);
    end
	if _Resources[ResourceType.Clay] ~= nil then
		AddClay(_PlayerID, _Resources[ResourceType.Clay] or _Resources[ResourceType.ClayRaw]);
	end
	if _Resources[ResourceType.Wood] ~= nil then
		AddWood(_PlayerID, _Resources[ResourceType.Wood] or _Resources[ResourceType.WoodRaw]);
	end
	if _Resources[ResourceType.Iron] ~= nil then		
		AddIron(_PlayerID, _Resources[ResourceType.Iron] or _Resources[ResourceType.IronRaw]);
	end
	if _Resources[ResourceType.Stone] ~= nil then		
		AddStone(_PlayerID, _Resources[ResourceType.Stone] or _Resources[ResourceType.StoneRaw]);
	end
    if _Resources[ResourceType.Sulfur] ~= nil then		
		AddSulfur(_PlayerID, _Resources[ResourceType.Sulfur] or _Resources[ResourceType.SulfurRaw]);
	end
end
AddResourcesToPlayer = AddResourcesToPlayer;

---
-- Removes Resources from the player by the given costs table.
--
-- <b>Alias</b>: RemoveResourcesFromPlayer
--
-- @param[type=number] _PlayerID ID of player
-- @param[type=table]  _Costs    Costs table
-- @within AI
--
function RemoveResourcesFromPlayer(_PlayerID, _Costs)
	local Gold   = Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.Gold ) + Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.GoldRaw);
    local Clay   = Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.Clay ) + Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.ClayRaw);
	local Wood   = Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.Wood ) + Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.WoodRaw);
	local Iron   = Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.Iron ) + Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.IronRaw);
	local Stone  = Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.Stone ) + Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.StoneRaw);
    local Sulfur = Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.Sulfur ) + Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.SulfurRaw);

    if _Costs[ResourceType.Gold] ~= nil and _Costs[ResourceType.Gold] > 0 and Gold >= _Costs[ResourceType.Gold] then
		AddGold(_PlayerID, _Costs[ResourceType.Gold] * (-1));
    end
	if _Costs[ResourceType.Clay] ~= nil and _Costs[ResourceType.Clay] > 0 and Clay >= _Costs[ResourceType.Clay]  then
		AddClay(_PlayerID, _Costs[ResourceType.Clay] * (-1));
	end
	if _Costs[ResourceType.Wood] ~= nil and _Costs[ResourceType.Wood] > 0 and Wood >= _Costs[ResourceType.Wood]  then
		AddWood(_PlayerID, _Costs[ResourceType.Wood] * (-1));
	end
	if _Costs[ResourceType.Iron] ~= nil and _Costs[ResourceType.Iron] > 0 and Iron >= _Costs[ResourceType.Iron] then		
		AddIron(_PlayerID, _Costs[ResourceType.Iron] * (-1));
	end
	if _Costs[ResourceType.Stone] ~= nil and _Costs[ResourceType.Stone] > 0 and Stone >= _Costs[ResourceType.Stone] then		
		AddStone(_PlayerID, _Costs[ResourceType.Stone] * (-1));
	end
    if _Costs[ResourceType.Sulfur] ~= nil and _Costs[ResourceType.Sulfur] > 0 and Sulfur >= _Costs[ResourceType.Sulfur] then		
		AddSulfur(_PlayerID, _Costs[ResourceType.Sulfur] * (-1));
	end
end
RemoveResourcesFromPlayer = RemoveResourcesFromPlayer;

---
-- Checks, if the positions are in the same sector. If 2 possitions are not
-- in the same sector then they are not connected.
--
-- <b>Alias</b>: SameSector
--
-- @param _pos1 Position 1
-- @param _pos2 Position 2
-- @return[type=boolean] Same sector
-- @within AI
--
function SameSector(_pos1, _pos2)
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
SameSector = SameSector;

