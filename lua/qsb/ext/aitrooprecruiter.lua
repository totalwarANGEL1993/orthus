-- ########################################################################## --
-- #  AI Troop Recruiter                                                    # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

-- -------------------------------------------------------------------------- --

AiTroopRecruiter = {
    ScriptName = nil,
    LastRecruitedTime = 0,
    Cheat = true,
    Delay = 30,
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
        Entities.PV_Cannon1,
        Entities.PV_Cannon2,
    },
    Foundry2Units = {
        Entities.PV_Cannon3,
        Entities.PV_Cannon4,
    },
}

AiTroopRecruiterList = {};
AiTroopRecruiterCreated = {};

function AiTroopRecruiter:New(_ScriptName)
    local Recruiter = copy(AiTroopRecruiter);
    Recruiter.ScriptName = _ScriptName;
    AiTroopRecruiterList[_ScriptName] = Recruiter;

    Recruiter:Initalize();
    return Recruiter;
end

function AiTroopRecruiter:AddType(_Type)
    if not QuestTools.IsInTable(_Type, self.Troops.Types) then
        table.insert(self.Troops.Types, _Type);
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

function AiTroopRecruiter:SetDelay(_Time)
    self.Delay = _Time;
    return self;
end

function AiTroopRecruiter:Initalize()
    if not self.Initalized then
        self.Initalized = true;
        
        -- Save approach position
        local Position = GetPosition(self.ScriptName);
        local ID = AI.Entity_CreateFormation(8, Entities.PU_Serf, 0, 0, Position.X, Position.Y, 0, 0, 0, 0);
        self.ApproachPosition = GetPosition(ID);
        DestroyEntity(ID);

        -- Registers new recruited units
        self.CreationJobID = QuestTools.StartInlineJob(Events.LOGIC_EVENT_ENTITY_CREATED, function(_ScriptName)
            if not IsExisting(_ScriptName) then
                return true;
            end
            local ID = GetID(_ScriptName);
            local PlayerID = Logic.EntityGetPlayer(ID);
            for k, v in pairs({Event.GetEntityID()}) do
                -- TODO: what is with cannons?
                if Logic.IsLeader(v) == 1 then
                    if QuestTools.GetDistance(v, ID) < 1000 then
                        table.insert(AiTroopRecruiterCreated, v);
                    end
                end
            end
        end, self.ScriptName);

        -- Associates created units to the recuiter
        self.AllocationJobID = QuestTools.StartInlineJob(Events.LOGIC_EVENT_EVERY_SECOND, function(_ScriptName)
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
        self.SoldierJobID = QuestTools.StartInlineJob(Events.LOGIC_EVENT_EVERY_SECOND, function(_ScriptName)
            if not IsExisting(_ScriptName) then
                return true;
            end
            for i= table.getn(AiTroopRecruiterList[_ScriptName].Troops.Created), 1, -1 do
                local ID = AiTroopRecruiterList[_ScriptName].Troops.Created[i];
                if IsExisting(ID) then
                    local Task = Logic.GetCurrentTaskList(ID);
                    local BarracksID = Logic.LeaderGetBarrack(ID);
                    if BarracksID == 0 and not string.find(Task, "BATTLE") then
                        local CurrentSoldiers = Logic.LeaderGetNumberOfSoldiers(ID);
                        local MaxSoldiers = Logic.LeaderGetMaxNumberOfSoldiers(ID);
                        if CurrentSoldiers < MaxSoldiers then
                            if QuestTools.GetDistance(ID, AiTroopRecruiterList[_ScriptName].ApproachPosition) < 1200 then
                                if AiTroopRecruiterList[_ScriptName].Cheat then
                                    Tools.CreateSoldiersForLeader(ID, 1);
                                else
                                    local PlayerID = Logic.EntityGetPlayer(ID);
                                    local SoldierType = Logic.LeaderGetSoldiersType(ID);
                                    local SoldierCosts = QuestTools.GetSoldierCostsTable(PlayerID, SoldierType);
                                    if QuestTools.HasEnoughResources(PlayerID, SoldierCosts) then
                                        QuestTools.RemoveResourcesFromPlayer(PlayerID, SoldierCosts)
                                        Tools.CreateSoldiersForLeader(ID, 1);
                                    end
                                end
                            end
                        end
                    end
                else
                    table.remove(AiTroopRecruiterList[_ScriptName].Troops.Created, i);
                end
            end
        end, self.ScriptName);
    end
    return self;
end

function AiTroopRecruiter:GetTroop()
    for i= table.getn(self.Troops.Created), 1, -1 do
        local ID = self.Troops.Created[i];
        if IsExisting(ID) then
            local CurrentSoldiers = Logic.LeaderGetNumberOfSoldiers(ID);
            local MaxSoldiers = Logic.LeaderGetMaxNumberOfSoldiers(ID);
            if CurrentSoldiers == MaxSoldiers then
                return table.remove(self.Troops.Created, i);
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
    if self.ScriptName and IsExisting(self.ScriptName) then
        local ID = GetID(self.ScriptName);
        local PlayerID = Logic.EntityGetPlayer(ID);
        -- TODO: Should the worker in the foundry be checked here?
        if Logic.GetTime() > self.LastRecruitedTime + self.Delay then
            if Logic.IsConstructionComplete(ID) == 1 then
                if self:IsRecruiterBuilding() then
                    local x, y, z = Logic.EntityGetPos(ID);
                    if Logic.GetPlayerEntitiesInArea(PlayerID, 0, x, y, 800, 4) < 4 then
                        return true;
                    end
                end
            end
        end
    end
    return false;
end

function AiTroopRecruiter:CreateTroop()
    if self:IsReady() then
        if table.getn(self.Troops.Types) > 0 then
            local TroopType = self.Troops.Selector(self);
            if self:IsSuitableBuilding(TroopType) then
                local ID = GetID(self.ScriptName);
                local BuildingType = Logic.GetEntityTypeName(Logic.GetEntityType(ID));
                if string.find(BuildingType, "PB_Foundry") then
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
                else
                    if self.Cheat then
                        self:CheatLeaderCosts(TroopType);
                    end
                    Logic.BarracksBuyLeader(ID, TroopType);
                end
                self.LastRecruitedTime = Logic.GetTime();
            end
        end
    end
end

function AiTroopRecruiter:CheatLeaderCosts(_UnitType)
    local PlayerID = Logic.EntityGetPlayer(GetID(self.ScriptName));
    QuestTools.AddResourcesToPlayer(
        PlayerID,
        QuestTools.GetMilitaryCostsTable(PlayerID, _UnitType)
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
        QuestTools.AddResourcesToPlayer(
            PlayerID,
            QuestTools.GetMilitaryCostsTable(PlayerID, CannonUpCat)
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
    for k, v in pairs(QuestTools.GetAllLeader(PlayerID)) do
        local MaximumSoldiers = Logic.LeaderGetMaxNumberOfSoldiers(v);
        local CurrentSoldiers = Logic.LeaderGetNumberOfSoldiers(v);
        FutureUsage = FutureUsage + (MaximumSoldiers - CurrentSoldiers);
    end
    FutureUsage = FutureUsage + table.getn(QuestTools.GetAllCannons(PlayerID));

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

function AiTroopRecruiter:IsSuitableBuilding(_Type)
    local BuildingType = Logic.GetEntityTypeName(Logic.GetEntityType(GetID(self.ScriptName)));
    if string.find(BuildingType, "PB_Barracks") then
        return QuestTools.IsInTable(_Type, self.BarracksUnits) == true;
    elseif string.find(BuildingType, "PB_Archery") then
        return QuestTools.IsInTable(_Type, self.ArcheryUnits) == true;
    elseif string.find(BuildingType, "PB_Stable") then
        return QuestTools.IsInTable(_Type, self.StableUnits) == true;
    elseif string.find(BuildingType, "PB_Foundry") then
        if QuestTools.IsInTable(_Type, self.Foundry1Units) == true then
            return true;
        end
        if BuildingType == "PB_Foundry2" then
            return QuestTools.IsInTable(_Type, self.Foundry2Units) == true;
        end
    end
    return false;
end

