-- ########################################################################## --
-- #  AI Troop Spawner                                                      # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module creates troop producer for armies or other purposes.
--
-- This producer type is an spawner. This means it will spawn the troops when
-- they are requested. The AI won't need the resources to build them and they
-- can be spawned at any building type.
-- You do not need to set the spawn position. It is calculated automatically.
-- If you wish to change the position, it is possible to do so. Once a unit is
-- created it is added to the list of created entities.
--
-- Finished units can be obtained by requesting one of them from the created
-- entities. If no troops are available the create command must be called.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.oop</li>
-- <li>qsb.quest.questsync</li>
-- <li>qsb.quest.questtools</li>
-- </ul>
--
-- @set sort=true
--

---
-- Creates an new producer that creates units by spawning them.
--
-- @param[type=table] _Data Description
-- @return[type=table] Created instance
--
function CreateTroopGenerator(_Data)
    if not AiTroopSpawnerList[_Data.ScriptName] then
        local Spawner = new(AiTroopSpawner, _Data.ScriptName);
        Spawner:SetDelay(_Data.Delay or 30);
        if _Data.Spawnpoint then
            Spawner:SetApproachPosition(GetPosition(_Data.Spawnpoint));
        end
        if _Data.Limit then
            Spawner:SetMaxTroops(_Data.Limit);
        end
        for i= 1, table.getn(_Data.Types), 1 do
            Spawner:AddType(_Data.Types[i][1], _Data.Types[i][2]);
        end
    end
    return AiTroopSpawnerList[_Data.ScriptName];
end

---
-- Destroys an producer.
-- 
-- <b>Note</b>: The producer should first be removed from all armies!
--
-- @param[type=string] _ScriptName Script name of building
--
function DropTroopGenerator(_ScriptName)
    if AiTroopSpawnerList[_ScriptName] then
        if JobIsRunning(AiTroopSpawnerList[_ScriptName].SoldierJobID) then
            EndJob(AiTroopSpawnerList[_ScriptName].SoldierJobID);
        end
        DestroyEntity(AiTroopSpawnerList[_ScriptName].ApproachPosition);
        AiTroopSpawnerList[_ScriptName] = nil;
    end
end

---
-- Returns the instance of the producer if it exists.
--
-- @param[type=string] _ScriptName Script name of building
-- @return[type=table] Producer instance
--
function GetTroopGenerator(_ScriptName)
    if AiTroopSpawnerList[_ScriptName] then
        return AiTroopSpawnerList[_ScriptName];
    end
end

-- -------------------------------------------------------------------------- --

AiTroopSpawner = {
    ScriptName = nil,
    ApproachPosition = 0,
    IsSpawner = true,
    LastRecruitedTime = 0,
    Enabled = true,
    Delay = 30,
    Troops = {
        Maximum = 9999,
        Selector = function(self)
            local Size = table.getn(self.Troops.Types);
            return self.Troops.Types[math.random(1, Size)];
        end,
        Types = {},
        Created = {},
    },
}

AiTroopSpawnerList = {};

function AiTroopSpawner:construct(_ScriptName)
    self.ScriptName = _ScriptName;
    self:Initalize();
    AiTroopSpawnerList[_ScriptName] = self;
end;
class(AiTroopSpawner);

function AiTroopSpawner:IsManagedByProducer(_TroopID)
    return IsInTable(_TroopID, self.Troops.Created) == true;
end

---
-- Changes the active flag of the spawner.
-- @param[type=boolean] _Flag Spawner is active
-- @within AiTroopSpawner
--
function AiTroopSpawner:SetEnabled(_Flag)
    self.Enabled = _Flag == true;
    return self;
end

---
-- Returns the position where troops are spawned.
-- @return[type=number] ID of approach position
-- @within AiTroopSpawner
--
function AiTroopSpawner:GetApproachPosition()
    return self.ApproachPosition;
end

---
-- Creates a new approach position at the location.
-- @param[type=table] _Position Location of approach position
-- @within AiTroopSpawner
--
function AiTroopSpawner:SetApproachPosition(_Position)
    DestroyEntity(self.ApproachPosition);
    local ID = AI.Entity_CreateFormation(8, Entities.PU_Serf, 0, 0, _Position.X, _Position.Y, 0, 0, 0, 0);
    local x, y, z = Logic.EntityGetPos(ID);
    local ApproachID = Logic.CreateEntity(Entities.XD_ScriptEntity, x, y, 0, 8);
    self.ApproachPosition = ApproachID;
    DestroyEntity(ID);
    return self;
end

function AiTroopSpawner:Initalize()
    if not self.Initalized then
        self.Initalized = true;

        -- Save approach position
        self:SetApproachPosition(GetPosition(self.ScriptName));

        -- Buys soldiers for the leader
        self.SoldierJobID = StartInlineJob(Events.LOGIC_EVENT_EVERY_SECOND, function(_ScriptName)
            if not IsExisting(_ScriptName) then
                DestroyEntity(AiTroopSpawnerList[_ScriptName].ApproachPosition);
                return true;
            end
            if AiTroopSpawnerList[_ScriptName] then
                AiTroopSpawnerList[_ScriptName]:HandleSoldierRefill();
            end
        end, self.ScriptName);
    end
end

function AiTroopSpawner:HandleSoldierRefill()
    for i= table.getn(self.Troops.Created), 1, -1 do
        local ID = self.Troops.Created[i];
        local Task = Logic.GetCurrentTaskList(ID);
        if IsExisting(ID) and (not Task or not string.find(Task, "DIE")) then
            if not AreEnemiesInArea(GetPlayer(ID), GetPosition(ID), 2000) then
                local BarracksID = Logic.LeaderGetBarrack(ID);
                if BarracksID == 0 then
                    if not Task or not string.find(Task, "BATTLE") then
                        local CurrentSoldiers = Logic.LeaderGetNumberOfSoldiers(ID);
                        local MaxSoldiers = Logic.LeaderGetMaxNumberOfSoldiers(ID);
                        if CurrentSoldiers < MaxSoldiers then
                            if GetDistance(ID, self.ApproachPosition) < 1200 then
                                Tools.CreateSoldiersForLeader(ID, 1);
                            else
                                if Logic.IsEntityMoving(ID) == false then
                                    if SameSector(ID, self.ApproachPosition) then
                                        local x, y, z = Logic.EntityGetPos(self.ApproachPosition);
                                        Logic.MoveSettler(ID, x, y);
                                    else
                                        Logic.DestroyGroupByLeader(ID);
                                    end
                                end
                            end
                        end
                    end
                end
            end
        else
            table.remove(self.Troops.Created, i);
        end
    end
end

---
-- Returns if the spawner ist existing.
-- @return[type=boolean] Spawner is existing
-- @within AiTroopSpawner
--
function AiTroopSpawner:IsAlive()
    return IsExisting(self.ScriptName);
end

---
-- Adds an troop type to the spawner.
-- @param[type=number] _Type Type to spawn
-- @param[type=number] _Exp  Experience
-- @within AiTroopSpawner
--
function AiTroopSpawner:AddType(_Type, _Exp)
    if not self:IsInTypeList(_Type) then
        table.insert(self.Troops.Types, {_Type, _Exp});
    end
    return self;
end

function AiTroopSpawner:IsInTypeList(_Type)
    for i= 1, table.getn(self.Troops.Types), 1 do
        if self.Troops.Types[i][1] == _Type then
            return true;
        end
    end
    return false;
end

---
-- Clears the type list of the spawner.
-- @within AiTroopSpawner
--
function AiTroopSpawner:ClearTypes()
    self.Troops.Types = {};
    return self;
end

function AiTroopSpawner:SetMaxTroops(_Max)
    self.Troops.Maximum = _Max;
    return self;
end

---
-- Changes the delay between spawned troops.
-- @param[type=number] _Time Time between spawns
-- @within AiTroopSpawner
--
function AiTroopSpawner:SetDelay(_Time)
    self.Delay = _Time;
    return self;
end

function AiTroopSpawner:IsReady(_Initial)
    if self.Enabled then
        if self.ScriptName and IsExisting(self.ScriptName) then
            if _Initial or Logic.GetTime() > self.LastRecruitedTime + self.Delay then
                if table.getn(self.Troops.Created) < self.Troops.Maximum then
                    return true;
                end
            end
        end
    end
    return false;
end

---
-- Obtains the next unit from the producer.
--
-- If there is no troops ready 0 is returned.
--
-- @return[type=number] ID of troop or 0 if not available
-- @within AiTroopSpawner
--
function AiTroopSpawner:GetTroop()
    for i= table.getn(self.Troops.Created), 1, -1 do
        local ID = self.Troops.Created[i];
        if IsExisting(ID) then
            local CurrentSoldiers = Logic.LeaderGetNumberOfSoldiers(ID);
            local MaxSoldiers = Logic.LeaderGetMaxNumberOfSoldiers(ID);
            if CurrentSoldiers == MaxSoldiers then
                return table.remove(self.Troops.Created, i);
            else
                return -1;
            end
        else
            table.remove(self.Troops.Created, i);
        end
    end
    return 0;
end

---
-- Creates an new unit.
--
-- @param[type=string] _IgnoreCreated Ignore already created units
-- @param[type=string] _Initial       Do initial spawns
-- @within AiTroopSpawner
--
function AiTroopSpawner:CreateTroop(_IgnoreCreated, _Initial)
    if self:IsReady(_Initial) then
        if table.getn(self.Troops.Created) == 0 or _IgnoreCreated then
            if table.getn(self.Troops.Types) > 0 then
                local TroopType = self.Troops.Selector(self);
                local ID = GetID(self.ScriptName);
                local PlayerID = Logic.EntityGetPlayer(ID);
                local Position = GetPosition(self.ApproachPosition);

                local TroopID = AI.Entity_CreateFormation(
                    PlayerID,
                    TroopType[1],
                    0,
                    16,
                    Position.X,
                    Position.Y,
                    0,
                    0,
                    TroopType[2] or 0,
                    16
                );
                table.insert(self.Troops.Created, TroopID);
                self.LastRecruitedTime = Logic.GetTime();
            end
        end
    end
end

