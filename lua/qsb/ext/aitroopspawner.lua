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
-- <li>qsb.core.questsync</li>
-- <li>qsb.core.questtools</li>
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
        Spawner:SetDelay(_Data.Delay or 90);
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
    IsSpawner = true,
    LastRecruitedTime = 0,
    Delay = 2*60,
    Troops = {
        Maximum = 999,
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

function AiTroopSpawner:Initalize()
    if not self.Initalized then
        self.Initalized = true;
        
        -- Save approach position
        local Position = GetPosition(self.ScriptName);
        local ID = AI.Entity_CreateFormation(8, Entities.PU_Serf, 0, 0, Position.X, Position.Y, 0, 0, 0, 0);
        self.ApproachPosition = GetPosition(ID);
        DestroyEntity(ID);

        -- Buys soldiers for the leader
        self.SoldierJobID = QuestTools.StartInlineJob(Events.LOGIC_EVENT_EVERY_SECOND, function(_ScriptName)
            if not IsExisting(_ScriptName) then
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
            if not QuestTools.AreEnemiesInArea(GetPlayer(ID), GetPosition(ID), 2000) then
                local BarracksID = Logic.LeaderGetBarrack(ID);
                if BarracksID == 0 then
                    if not Task or not string.find(Task, "BATTLE") then
                        local CurrentSoldiers = Logic.LeaderGetNumberOfSoldiers(ID);
                        local MaxSoldiers = Logic.LeaderGetMaxNumberOfSoldiers(ID);
                        if CurrentSoldiers < MaxSoldiers then
                            if QuestTools.GetDistance(ID, self.ApproachPosition) < 1200 then
                                Tools.CreateSoldiersForLeader(ID, 1);
                            else
                                local Position = self.ApproachPosition;
                                if Logic.IsEntityMoving(ID) == false then
                                    if QuestTools.GetReachablePosition(ID, Position) ~= nil then
                                        Logic.MoveSettler(ID, Position.X, Position.Y);
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

function AiTroopSpawner:IsAlive()
    return IsExisting(self.ScriptName);
end

function AiTroopSpawner:AddType(_Type, _Exp)
    table.insert(self.Troops.Types, {_Type, _Exp});
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

function AiTroopSpawner:ClearTypes()
    self.Troops.Types = {};
    return self;
end

function AiTroopSpawner:SetApproachPosition(_Position)
    self.ApproachPosition = _Position;
    return self;
end

function AiTroopSpawner:SetMaxTroops(_Max)
    self.Troops.Maximum = _Max;
    return self;
end

function AiTroopSpawner:SetDelay(_Time)
    self.Delay = _Time;
    return self;
end

function AiTroopSpawner:IsReady(_Initial)
    if self.ScriptName and IsExisting(self.ScriptName) then
        if _Initial or Logic.GetTime() > self.LastRecruitedTime + self.Delay then
            if table.getn(self.Troops.Created) < self.Troops.Maximum then
                return true;
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
                local Position = self.ApproachPosition;

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

