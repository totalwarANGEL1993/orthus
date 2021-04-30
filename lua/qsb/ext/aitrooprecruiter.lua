-- ########################################################################## --
-- #  AI Troop Recruiter                                                    # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

-- -------------------------------------------------------------------------- --

AiTroopRecruiter = {
    ScriptName = nil,
    LastRecruitedTime = 0,
    Delay = 30,
    Troops = {
        Selector = function(self)
            local Size = table.getn(self.Troops.Types);
            return self.Troops.Types[math.random(1, Size)];
        end,
        Types = {},
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
        UpgradeCategories.Evil_LeaderSkirmishery,
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

function AiTroopRecruiter:New(_ScriptName)
    local Recruiter = copy(AiTroopRecruiter);
    Recruiter.ScriptName = _ScriptName;
    AiTroopRecruiterList[_ScriptName] = Recruiter;
    return Recruiter;
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

function AiTroopRecruiter:BuyTroop(_CheatResources)
    if self:IsReady() then
        if table.getn(self.Troops.Types) > 0 then
            local TroopType = self.Troops.Selector(self);
            if self:IsSuitableBuilding(TroopType) then
                local ID = GetID(self.ScriptName);
                local BuildingType = Logic.GetEntityTypeName(Logic.GetEntityType(ID));
                if string.find(BuildingType, "PB_Foundry") then
                    if _CheatResources then
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
                    if _CheatResources then
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

