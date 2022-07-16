-- ########################################################################## --
-- #  AI Troop Recruiter                                                    # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module creates troop producer for armies or other purposes.
--
-- This producer type is an recruiter. This means the AI must have the resources
-- to build the unit in buildings like barracks, archeries, stables or foundrys.
-- The AI can also cheat the resources, if needed.
--
-- Those soldiers/cannons must be fully trained/constructed before they're
-- add to the producers list of created entities. 
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
-- Creates an new producer that creates units by recruiting them.
--
-- @param[type=table] _Data Description
-- @return[type=table] Created instance
--
function CreateTroopRecruiter(_Data)
    if not AiTroopRecruiterList[_Data.ScriptName] then
        local Recruiter = new(AiTroopRecruiter, _Data.ScriptName);
        Recruiter:SetCheatCosts(_Data.Cheat == true);
        Recruiter:SetDelay(_Data.Delay or 5);
        for i= 1, table.getn(_Data.Types), 1 do
            Recruiter:AddType(_Data.Types[i]);
        end
    end
    return AiTroopRecruiterList[_Data.ScriptName];
end

---
-- Destroys an producer.
-- 
-- <b>Note</b>: The producer should first be removed from all armies!
--
-- @param[type=string] _ScriptName Script name of building
--
function DropTroopRecruiter(_ScriptName)
    if AiTroopRecruiterList[_ScriptName] then
        if JobIsRunning(AiTroopRecruiterList[_ScriptName].CreationJobID) then
            EndJob(AiTroopRecruiterList[_ScriptName].CreationJobID);
        end
        if JobIsRunning(AiTroopRecruiterList[_ScriptName].AllocationJobID) then
            EndJob(AiTroopRecruiterList[_ScriptName].AllocationJobID);
        end
        if JobIsRunning(AiTroopRecruiterList[_ScriptName].SoldierJobID) then
            EndJob(AiTroopRecruiterList[_ScriptName].SoldierJobID);
        end
        DestroyEntity(AiTroopRecruiterList[_ScriptName].ApproachPosition);
        AiTroopRecruiterList[_ScriptName] = nil;
    end
end

---
-- Returns the instance of the producer if it exists.
--
-- @param[type=string] _ScriptName Script name of building
-- @return[type=table] Producer instance
--
function GetTroopRecruiter(_ScriptName)
    if AiTroopRecruiterList[_ScriptName] then
        return AiTroopRecruiterList[_ScriptName];
    end
end

-- -------------------------------------------------------------------------- --

AiTroopRecruiter = {
    ScriptName = nil,
    ApproachPosition = 0,
    IsRecruiter = true,
    LastRecruitedTime = 0,
    Enabled = true,
    Cheat = true,
    Delay = 5,
    Troops = {
        Selector = function(self)
            local Size = table.getn(self.Troops.Types);
            return self.Troops.Types[math.random(1, Size)];
        end,
        Types = {},
        Created = {},
    },

    BarracksUnits = {
        UpgradeCategories.BlackKnightLeaderMace1,
        UpgradeCategories.Evil_LeaderBearman,
        UpgradeCategories.LeaderBandit,
        UpgradeCategories.LeaderBarbarian,
        UpgradeCategories.LeaderPoleArm,
        UpgradeCategories.LeaderSword,
    },
    ArcheryUnits = {
        UpgradeCategories.Evil_LeaderSkirmisher,
        UpgradeCategories.LeaderBanditBow,
        UpgradeCategories.LeaderBow,
        UpgradeCategories.LeaderRifle,
    },
    StableUnits = {
        UpgradeCategories.LeaderCavalry,
        UpgradeCategories.LeaderHeavyCavalry,
    },
    Foundry1Units = {
        UpgradeCategories.Cannon1,
        UpgradeCategories.Cannon2,
        Entities.PV_Cannon1,
        Entities.PV_Cannon2,
    },
    Foundry2Units = {
        UpgradeCategories.Cannon3,
        UpgradeCategories.Cannon4,
        Entities.PV_Cannon3,
        Entities.PV_Cannon4,
    },
}

AiTroopRecruiterList = {};
AiTroopRecruiterCreated = {};

function AiTroopRecruiter:construct(_ScriptName)
    self.ScriptName = _ScriptName;
    self:Initalize();
    AiTroopRecruiterList[_ScriptName] = self;
end;
class(AiTroopRecruiter);

function AiTroopRecruiter:IsAlive()
    return IsExisting(self.ScriptName);
end

function AiTroopRecruiter:AddType(_Type)
    if not IsInTable(_Type, self.Troops.Types) then
        table.insert(self.Troops.Types, _Type);
    end
    return self;
end

function AiTroopRecruiter:AddTypes(_List)
    for i= 1, table.getn(_List), 1 do
        self:AddType(_List[i]);
    end
    return self;
end

function AiTroopRecruiter:ClearTypes()
    self.Troops.Types = {};
    return self;
end

function AiTroopRecruiter:SetCheatCosts(_Flag)
    self.Cheat = _Flag;
    return self;
end

function AiTroopRecruiter:SetEnabled(_Flag)
    self.Enabled = _Flag == true;
    return self;
end

function AiTroopRecruiter:SetDelay(_Time)
    self.Delay = _Time;
    return self;
end

function AiTroopRecruiter:SetSelector(_Selector)
    self.Troops.Selector = _Selector;
    return self;
end

function AiTroopRecruiter:IsManagedByProducer(_TroopID)
    return IsInTable(_TroopID, self.Troops.Created) == true;
end

function AiTroopRecruiter:GetApproachPosition()
    return self.ApproachPosition;
end

function AiTroopRecruiter:SetApproachPosition(_Position)
    DestroyEntity(self.ApproachPosition);
    local ID = AI.Entity_CreateFormation(8, Entities.PU_Serf, 0, 0, _Position.X, _Position.Y, 0, 0, 0, 0);
    local x, y, z = Logic.EntityGetPos(ID);
    local ApproachID = Logic.CreateEntity(Entities.XD_ScriptEntity, x, y, 0, 8);
    self.ApproachPosition = ApproachID;
    DestroyEntity(ID);
    return self;
end

function AiTroopRecruiter:Initalize()
    if not self.Initalized then
        self.Initalized = true;
        
        -- Save approach position
        self:SetApproachPosition(GetPosition(self.ScriptName));

        -- Registers new recruited units
        self.CreationJobID = StartInlineJob(Events.LOGIC_EVENT_ENTITY_CREATED, function(_ScriptName)
            if not IsExisting(_ScriptName) then
                return true;
            end
            local ID = GetID(_ScriptName);
            local PlayerID = Logic.EntityGetPlayer(ID);
            for k, v in pairs({Event.GetEntityID()}) do
                -- TODO: what is with cannons?
                if Logic.IsEntityInCategory(v, EntityCategories.Cannon) == 1 then
                    AiTroopRecruiter:HandleCreatedCannon(PlayerID, v);
                else
                    if Logic.IsLeader(v) == 1 then
                        if GetDistance(v, ID) < 1000 then
                            table.insert(AiTroopRecruiterCreated, v);
                        end
                    end
                end
            end
        end, self.ScriptName);

        -- Associates created units to the recuiter
        self.AllocationJobID = StartInlineJob(Events.LOGIC_EVENT_EVERY_SECOND, function(_ScriptName)
            if not IsExisting(_ScriptName) then
                return true;
            end
            local ID = GetID(_ScriptName);
            for i= table.getn(AiTroopRecruiterCreated), 1, -1 do
                local BarracksID = Logic.LeaderGetBarrack(AiTroopRecruiterCreated[i]);
                if BarracksID == ID then
                    table.insert(AiTroopRecruiterList[_ScriptName].Troops.Created, AiTroopRecruiterCreated[i]);
                    table.remove(AiTroopRecruiterCreated, i);
                end
            end
        end, self.ScriptName);

        -- Buys soldiers for the leader
        self.SoldierJobID = StartInlineJob(Events.LOGIC_EVENT_EVERY_SECOND, function(_ScriptName)
            if not IsExisting(_ScriptName) then
                DestroyEntity(AiTroopRecruiterList[_ScriptName].ApproachPosition);
                return true;
            end
            if AiTroopRecruiterList[_ScriptName] then
                AiTroopRecruiterList[_ScriptName]:HandleSoldierRefill();
            end
        end, self.ScriptName);
    end
    return self;
end

function AiTroopRecruiter:HandleCreatedCannon(_PlayerID, _EntityID)
    local x, y, z = Logic.EntityGetPos(_EntityID);
    local n, Foundry1 = Logic.GetPlayerEntitiesInArea(_PlayerID, Entities.PB_Foundry1, x, y, 1000, 1);
    if n > 0 then
        local ScriptName = Logic.GetEntityName(Foundry1);
        if AiTroopRecruiterList[ScriptName] then
            if not IsInTable(_EntityID, AiTroopRecruiterList[ScriptName].Troops.Created) then
                table.insert(AiTroopRecruiterList[ScriptName].Troops.Created, _EntityID);
            end
        end
    end
    local n, Foundry2 = Logic.GetPlayerEntitiesInArea(_PlayerID, Entities.PB_Foundry2, x, y, 1000, 1);
    if n > 0 then
        local ScriptName = Logic.GetEntityName(Foundry2);
        if AiTroopRecruiterList[ScriptName] then
            if not IsInTable(_EntityID, AiTroopRecruiterList[ScriptName].Troops.Created) then
                table.insert(AiTroopRecruiterList[ScriptName].Troops.Created, _EntityID);
            end
        end
    end
end

function AiTroopRecruiter:HandleSoldierRefill()
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
                                if self.Cheat then
                                    Tools.CreateSoldiersForLeader(ID, 1);
                                else
                                    local PlayerID = Logic.EntityGetPlayer(ID);
                                    local SoldierType = Logic.LeaderGetSoldiersType(ID);
                                    local SoldierCosts = GetSoldierCostsTable(PlayerID, SoldierType);
                                    if HasEnoughResources(PlayerID, SoldierCosts) then
                                        RemoveResourcesFromPlayer(PlayerID, SoldierCosts)
                                        Tools.CreateSoldiersForLeader(ID, 1);
                                    end
                                end
                            else
                                if Logic.IsEntityMoving(ID) == false then
                                    if SameSector(ID, self.ApproachPosition) then
                                        local x, y, z = Logic.EntityGetPos(self.ApproachPosition);
                                        Logic.MoveSettler(ID, x, y, -1);
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
-- Obtains the next unit from the producer.
--
-- If there is no troops ready 0 is returned.
--
-- @return[type=number] ID of troop or 0 if not available
-- @within AiTroopSpawner
--
function AiTroopRecruiter:GetTroop()
    for i= table.getn(self.Troops.Created), 1, -1 do
        local ID = self.Troops.Created[i];
        if IsExisting(ID) then
            local CurrentSoldiers = Logic.LeaderGetNumberOfSoldiers(ID);
            local MaxSoldiers = Logic.LeaderGetMaxNumberOfSoldiers(ID);
            if CurrentSoldiers == MaxSoldiers then
                return table.remove(self.Troops.Created, i);
            else
                if Logic.LeaderGetBarrack(ID) == 0 then
                    return -1;
                end
            end
        else
            table.remove(self.Troops.Created, i);
        end
    end
    return 0;
end

function AiTroopRecruiter:IsRecruiterBuilding()
    if self.ScriptName then
        local TypeName = Logic.GetEntityTypeName(Logic.GetEntityType(GetID(self.ScriptName)));
        if string.find(TypeName, "PB_Barracks") or string.find(TypeName, "PB_Archery")
        or string.find(TypeName, "PB_Stable") or string.find(TypeName, "PB_Foundry") then
            return true;
        end
    end
    return false;
end

function AiTroopRecruiter:IsReady()
    if self.Enabled then
        if table.getn(self.Troops.Created) < 3 then
            if self.ScriptName and IsExisting(self.ScriptName) then
                local ID = GetID(self.ScriptName);
                local PlayerID = Logic.EntityGetPlayer(ID);
                -- TODO: Should the worker in the foundry be checked here?
                if Logic.GetTime() > self.LastRecruitedTime + self.Delay then
                    if Logic.IsConstructionComplete(ID) == 1 then
                        if self:IsRecruiterBuilding() then
                            return true;
                        end
                    end
                end
            end
        end
    end
    return false;
end

---
-- Creates an new unit.
--
-- @param[type=string] _IgnoreCreated Ignore already created units
-- @within AiTroopSpawner
--
function AiTroopRecruiter:CreateTroop(_IgnoreCreated)
    if self:IsReady() then
        if self:CountTrainingTroops() < 3 or _IgnoreCreated then
            if table.getn(self.Troops.Types) > 0 then
                local TroopType = self.Troops.Selector(self);
                -- currently not used because it makes AI to easy
                -- if self:HasSpaceForUnit(TroopType) then
                    if self:IsSuitableBuilding(TroopType) then
                        local ID = GetID(self.ScriptName);
                        local BuildingType = Logic.GetEntityTypeName(Logic.GetEntityType(ID));
                        if string.find(BuildingType, "PB_Foundry") then
                            if  not InterfaceTool_IsBuildingDoingSomething(ID)
                            and Logic.GetCannonProgress(ID) == 100 then
                                if self.Cheat then
                                    self:CheatCannonCosts(TroopType);
                                end
                                local ControllingPlayerID = GUI.GetPlayerID();
                                local PlayerID = Logic.EntityGetPlayer(ID);
                                local SelectedEntities = {GUI.GetSelectedEntities()};
                                GUI.ClearSelection();
                                GUI.SetControlledPlayer(PlayerID);
                                GUI.BuyCannon(ID, TroopType);
                                GUI.SetControlledPlayer(ControllingPlayerID);
                                Logic.PlayerSetGameStateToPlaying(ControllingPlayerID);
                                Logic.ForceFullExplorationUpdate();
                                for i = 1, table.getn(SelectedEntities), 1 do
                                    GUI.SelectEntity(SelectedEntities[i]);
                                end
                            end
                        else
                            if self.Cheat then
                                self:CheatLeaderCosts(TroopType);
                            end
                            Logic.BarracksBuyLeader(ID, TroopType);
                        end
                        self.LastRecruitedTime = Logic.GetTime();
                    end
                -- end
            end
        end
    end
end

function AiTroopRecruiter:CountTrainingTroops()
    if table.getn(self.Troops.Created) == 0 then
        return 0;
    end
    local Amount = 0;
    for i= 1, table.getn(self.Troops.Created), 1 do
        local ID = self.Troops.Created[i];
        if IsExisting(ID) then
            if Logic.LeaderGetBarrack(ID) ~= 0 then
                Amount = Amount +1;
            end
        end
    end
    return Amount;
end

function AiTroopRecruiter:CheatLeaderCosts(_UnitType)
    local PlayerID = Logic.EntityGetPlayer(GetID(self.ScriptName));
    AddResourcesToPlayer(
        PlayerID,
        GetMilitaryCostsTable(PlayerID, _UnitType)
    );
end

function AiTroopRecruiter:CheatCannonCosts(_UnitType)
    local ArmyCannonTypeToUpgradeCategory = {
        ["PV_Cannon1"] = UpgradeCategories.Cannon1,
        ["PV_Cannon2"] = UpgradeCategories.Cannon2,
        ["PV_Cannon3"] = UpgradeCategories.Cannon3,
        ["PV_Cannon4"] = UpgradeCategories.Cannon4,
    };
    local PlayerID = Logic.EntityGetPlayer(GetID(self.ScriptName));
    local CannonCosts = {};
    local CannonUpCat = ArmyCannonTypeToUpgradeCategory[Logic.GetEntityTypeName(_UnitType)];
    if CannonUpCat then
        AddResourcesToPlayer(
            PlayerID,
            GetMilitaryCostsTable(PlayerID, CannonUpCat)
        );
    end
end

function AiTroopRecruiter:HasSpaceForUnit(_UnitType)
    local PlayerID = Logic.EntityGetPlayer(GetID(self.ScriptName));

    -- Get current usage
    local MaximumUsage = Logic.GetPlayerAttractionLimit(PlayerID);
    local CurrentUsage = Logic.GetPlayerAttractionUsage(PlayerID);
    -- Calculate future usage (reserved space for soldiers)
    local FutureUsage = 0;
    for k, v in pairs(GetAllLeader(PlayerID)) do
        local MaximumSoldiers = Logic.LeaderGetMaxNumberOfSoldiers(v);
        local CurrentSoldiers = Logic.LeaderGetNumberOfSoldiers(v);
        FutureUsage = FutureUsage + (MaximumSoldiers - CurrentSoldiers);
    end
    FutureUsage = FutureUsage + table.getn(GetAllCannons(PlayerID));

    local Usage = MaximumUsage - (CurrentUsage + FutureUsage);
    return Usage >= self:GetSpaceNeededForUnit(_UnitType);
end

function AiTroopRecruiter:GetSpaceNeededForUnit(_UnitType)
    local PlayerID = Logic.EntityGetPlayer(GetID(self.ScriptName));
    if string.find(Logic.GetEntityTypeName(_UnitType), "Cannon") ~= nil then
        return 5;
    end
    local LeaderType = Logic.GetSettlerTypeByUpgradeCategory(_UnitType, PlayerID);
    local LeaderTypeName = Logic.GetEntityTypeName(LeaderType);
    if string.find(LeaderTypeName, "Evil") ~= nil then
        return 17;
    end
    if string.find(LeaderTypeName, "Cavalry") ~= nil then
        return 8;
    end
    if string.find(LeaderTypeName, "Sword3") ~= nil or string.find(LeaderTypeName, "Sword4") ~= nil
    or string.find(LeaderTypeName, "PoleArm3") ~= nil or string.find(LeaderTypeName, "PoleArm4") ~= nil
    or string.find(LeaderTypeName, "Bow3") ~= nil or string.find(LeaderTypeName, "Bow4") ~= nil
    or string.find(LeaderTypeName, "Rifle2") ~= nil then
        return 9;
    end
    return 5;
end

function AiTroopRecruiter:IsSuitableUnitType(_Type)
    local LeaderTypeToBarracksType = {
        ["CU_BanditLeaderSword1"]      = {Entities.PB_Barracks1, Entities.PB_Barracks2},
        ["CU_BanditLeaderSword2"]      = {Entities.PB_Barracks1, Entities.PB_Barracks2},
        ["CU_Barbarian_LeaderClub1"]   = {Entities.PB_Barracks1, Entities.PB_Barracks2},
        ["CU_Barbarian_LeaderClub2"]   = {Entities.PB_Barracks1, Entities.PB_Barracks2},
        ["CU_BlackKnight_LeaderMace1"] = {Entities.PB_Barracks1, Entities.PB_Barracks2},
        ["CU_BlackKnight_LeaderMace2"] = {Entities.PB_Barracks1, Entities.PB_Barracks2},
        ["CU_Evil_Bearman1"]           = {Entities.PB_Barracks1, Entities.PB_Barracks2},
        ["CU_Bandit_LeaderBow1"]       = {Entities.PB_Archery1, Entities.PB_Archery2},
        ["CU_Evil_Skirmisher1"]        = {Entities.PB_Archery1, Entities.PB_Archery2},
        
        ["PU_LeaderSword1"]            = {Entities.PB_Barracks1, Entities.PB_Barracks2},
        ["PU_LeaderSword2"]            = {Entities.PB_Barracks1, Entities.PB_Barracks2},
        ["PU_LeaderSword3"]            = {Entities.PB_Barracks1, Entities.PB_Barracks2},
        ["PU_LeaderSword4"]            = {Entities.PB_Barracks1, Entities.PB_Barracks2},
        ["PU_LeaderPoleArm1"]          = {Entities.PB_Barracks1, Entities.PB_Barracks2},
        ["PU_LeaderPoleArm2"]          = {Entities.PB_Barracks1, Entities.PB_Barracks2},
        ["PU_LeaderPoleArm3"]          = {Entities.PB_Barracks1, Entities.PB_Barracks2},
        ["PU_LeaderPoleArm4"]          = {Entities.PB_Barracks1, Entities.PB_Barracks2},
        ["PU_LeaderBow1"]              = {Entities.PB_Archery1, Entities.PB_Archery2},
        ["PU_LeaderBow2"]              = {Entities.PB_Archery1, Entities.PB_Archery2},
        ["PU_LeaderBow3"]              = {Entities.PB_Archery1, Entities.PB_Archery2},
        ["PU_LeaderBow4"]              = {Entities.PB_Archery1, Entities.PB_Archery2},
        ["PU_LeaderRifle1"]            = {Entities.PB_Archery1, Entities.PB_Archery2},
        ["PU_LeaderRifle2"]            = {Entities.PB_Archery1, Entities.PB_Archery2},
        ["PU_LeaderCavalry1"]          = {Entities.PB_Stable1, Entities.PB_Stable2},
        ["PU_LeaderCavalry2"]          = {Entities.PB_Stable1, Entities.PB_Stable2},
        ["PU_LeaderHeavyCavalry1"]     = {Entities.PB_Stable1, Entities.PB_Stable2},
        ["PU_LeaderHeavyCavalry2"]     = {Entities.PB_Stable1, Entities.PB_Stable2},

        ["PV_Cannon1"]                  = {Entities.PB_Foundry1, Entities.PB_Foundry2},
        ["PV_Cannon2"]                  = {Entities.PB_Foundry1, Entities.PB_Foundry2},
        ["PV_Cannon3"]                  = {Entities.PB_Foundry2},
        ["PV_Cannon4"]                  = {Entities.PB_Foundry2},
    };
    local TypeName = Logic.GetEntityTypeName(_Type);
    local ProducerType = Logic.GetEntityType(GetID(self.ScriptName));
    return IsInTable(ProducerType, LeaderTypeToBarracksType[TypeName]);
end

function AiTroopRecruiter:IsSuitableBuilding(_Type)
    local BuildingType = Logic.GetEntityTypeName(Logic.GetEntityType(GetID(self.ScriptName)));
    if string.find(BuildingType, "PB_Barracks") then
        return IsInTable(_Type, self.BarracksUnits) == true;
    elseif string.find(BuildingType, "PB_Archery") then
        return IsInTable(_Type, self.ArcheryUnits) == true;
    elseif string.find(BuildingType, "PB_Stable") then
        return IsInTable(_Type, self.StableUnits) == true;
    elseif string.find(BuildingType, "PB_Foundry") then
        if IsInTable(_Type, self.Foundry1Units) == true then
            return true;
        end
        if BuildingType == "PB_Foundry2" then
            return IsInTable(_Type, self.Foundry2Units) == true;
        end
    end
    return false;
end

