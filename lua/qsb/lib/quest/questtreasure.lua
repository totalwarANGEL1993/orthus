-- ########################################################################## --
-- #  Treasure Script (Extra 1/2)                                           # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module creates better chests.
--
-- Chests are opened by any hero but you can set a custom condition that is
-- checked first.
--
-- By default resources are given as reward. It is also possible to write
-- a custom funktion that will be called after the chest is opened.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.oop</li>
-- <li>qsb.questtools</li>
-- <li>qsb.questsystem</li>
-- <li>qsb.questbehavior</li>
-- </ul>
--
-- @set sort=true
--

QuestTreasure = {};

---
-- Simplified call to create a chest.
--
-- Entries in data table:
-- <ul>
-- <li>ScriptName: Script name of entity</li>
-- <li>Gold: Amount of gold</li>
-- <li>Clay: Amount of clay</li>
-- <li>Wood: Amount of wood</li>
-- <li>Stone: Amount of stone</li>
-- <li>Iron: Amount of iron</li>
-- <li>Sulfur: Amount of sulfur</li>
-- <li>Condition: Additional opening condition</li>
-- <li>Callback Additional opening callback</li>
-- </ul>
--
-- <b>Note</b>: Condition and callback are optional. The data of the instance
-- is passed to these function when they are called.
--
-- @param[type=table] _Data Data table
-- @return[type=table] Treasure instance
-- @within Methods
--
function SetupTreasureChest(_Data)
    return new(TreasureTemplate, _Data.ScriptName)
        :SetGold(_Data.Rewards.Gold or 0)
        :SetClay(_Data.Rewards.Clay or 0)
        :SetWood(_Data.Rewards.Wood or 0)
        :SetStone(_Data.Rewards.Stone or 0)
        :SetIron(_Data.Rewards.Iron or 0)
        :SetSulfur(_Data.Rewards.Sulfur or 0)
        :SetCondition(_Data.Condition)
        :SetCallback(_Data.Callback)
        :Activate();
end

TreasureTemplate = {}

---
-- Creates an new instance.
-- @param[type=string] _ScriptName Script name of entity
-- @within TreasureTemplate
--
function TreasureTemplate:construct(_ScriptName)
    self.m_ScriptName = _ScriptName
    self.m_Rewards = {0, 0, 0, 0, 0, 0};

    QuestTreasure[_ScriptName] = self;
end

class(TreasureTemplate);

---
-- Activates the treasure chest.
-- @return[type=table] Instance
-- @within TreasureTemplate
--
function TreasureTemplate:Activate()
    ReplaceEntity(self.m_ScriptName, Entities.XD_ChestClose);
    if not self.m_JobID then
        self.m_JobID = self:StartController();
    end
    return self;
end

---
-- Deactivates the treasure chest.
-- @return[type=table] Instance
-- @within TreasureTemplate
--
function TreasureTemplate:Deactivate()
    EndJob(self.m_JobID);
    self.m_JobID = nil;
    return self;
end

---
-- Sets the optional opening condition.
-- @param[type=function] _Function Condition method
-- @return[type=table] Instance
-- @within TreasureTemplate
--
function TreasureTemplate:SetCondition(_Function)
    self.m_Condition = _Function;
    return self;
end

---
-- Sets the optional opening callback.
-- @param[type=function] _Function Callback method
-- @return[type=table] Instance
-- @within TreasureTemplate
--
function TreasureTemplate:SetCallback(_Function)
    self.m_Callback = _Function;
    return self;
end

---
-- Sets the amount of gold.
-- @param[type=number] _Amount Amount of resource
-- @return[type=table] Instance
-- @within TreasureTemplate
--
function TreasureTemplate:SetGold(_Amount)
    self.m_Rewards[1] = _Amount;
    return self;
end

---
-- Sets the amount of clay.
-- @param[type=number] _Amount Amount of resource
-- @return[type=table] Instance
-- @within TreasureTemplate
--
function TreasureTemplate:SetClay(_Amount)
    self.m_Rewards[2] = _Amount;
    return self;
end

---
-- Sets the amount of wood.
-- @param[type=number] _Amount Amount of resource
-- @return[type=table] Instance
-- @within TreasureTemplate
--
function TreasureTemplate:SetWood(_Amount)
    self.m_Rewards[3] = _Amount;
    return self;
end

---
-- Sets the amount of stone.
-- @param[type=number] _Amount Amount of resource
-- @return[type=table] Instance
-- @within TreasureTemplate
--
function TreasureTemplate:SetStone(_Amount)
    self.m_Rewards[4] = _Amount;
    return self;
end

---
-- Sets the amount of iron.
-- @param[type=number] _Amount Amount of resource
-- @return[type=table] Instance
-- @within TreasureTemplate
--
function TreasureTemplate:SetIron(_Amount)
    self.m_Rewards[5] = _Amount;
    return self;
end

---
-- Sets the amount of sulfur.
-- @param[type=number] _Amount Amount of resource
-- @return[type=table] Instance
-- @within TreasureTemplate
--
function TreasureTemplate:SetSulfur(_Amount)
    self.m_Rewards[6] = _Amount;
    return self;
end

---
-- Applies the default rewards of the treasure chest.
--
-- The amount of each resource inside the chest is printed to screen.
--
-- @param[type=number] _PlayerID Receiver
-- @within TreasureTemplate
-- @local
--
function TreasureTemplate:GiveTreasureReward(_PlayerID)
    Tools.GiveResources(_PlayerID, unpack(self.m_Rewards));
    
    local Language = QuestTools.GetLanguage();
    local RewardString = "";
    if GUI.GetPlayerID() == _PlayerID then
        -- Gold
        if self.m_Rewards[1] ~= 0 then
            RewardString = RewardString .. self.m_Rewards[1] .. ((Language == "de" and " Taler ") or " gold ");
        end
        -- Clay
        if self.m_Rewards[2] ~= 0 then
            RewardString = RewardString .. self.m_Rewards[2] .. ((Language == "de" and " Lehm ") or " clay ");
        end
        -- Wood
        if self.m_Rewards[3] ~= 0 then
            RewardString = RewardString .. self.m_Rewards[3] .. ((Language == "de" and " Holz ") or " wood ");
        end
        -- Stone
        if self.m_Rewards[4] ~= 0 then
            RewardString = RewardString .. self.m_Rewards[4] .. ((Language == "de" and " Stein ") or " stone ");
        end
        -- Iron
        if self.m_Rewards[5] ~= 0 then
            RewardString = RewardString .. self.m_Rewards[5] .. ((Language == "de" and " Eisen ") or " iron ");
        end
        -- Sulfur
        if self.m_Rewards[6] ~= 0 then
            RewardString = RewardString .. self.m_Rewards[6] .. ((Language == "de" and " Schwefel ") or " sulfur ");
        end
        -- Print text
        if RewardString ~= "" then
            RewardString = ((Language == "de" and "Ihr findet: ") or "You received: ") .. RewardString;
            Message(RewardString);
        end
    else
        local UserName = UserTool_GetPlayerName(_PlayerID);
        local R, G, B = GUI.GetPlayerColor(_PlayerID);
        local Text = {
            de = "@color:%d,%d,%d %s @color:233,214,180 hat eine Schatztruhe gefunden!",
            en = "@color:%d,%d,%d %s @color:233,214,180 has found a treasure chest!"
        }
        Message(string.format(Text[Language], R, G, B, UserName));
    end
end

---
-- Starts the controller job of the treasure chest and returns the ID.
-- @return[type=number] ID of job
-- @within TreasureTemplate
-- @local
--
function TreasureTemplate:StartController()
    return QuestTools.StartSimpleJobEx(function(_ScriptName)
        local Chest = QuestTreasure[_ScriptName];
        if not Chest then
            return true;
        end
        if not IsExisting(_ScriptName) then
            QuestTreasure[_ScriptName].JobID = nil;
            return true;
        end
        if Chest.m_Condition and not Chest:m_Condition() then
            return;
        end
        local Position = GetPosition(_ScriptName);
        for i= 1, table.getn(Score.Player), 1 do
            if Logic.IsPlayerEntityOfCategoryInArea(i, Position.X, Position.Y, 350, "Hero") == 1 then
                if GUI.GetPlayerID() == i then
                    Sound.PlayFeedbackSound(Sounds.VoicesMentor_CHEST_FoundTreasureChest_rnd_01);
                end
                ReplaceEntity(_ScriptName, Entities.XD_ChestOpen);
                Chest:Deactivate();
                Chest:GiveTreasureReward(i);
                if Chest.m_Callback then
                    Chest:m_Callback();
                end
                QuestTreasure[_ScriptName].JobID = nil;
                return true;
            end
        end
    end, self.m_ScriptName);
end

-- -------------------------------------------------------------------------- --

---
-- Creates a simple treasure chest with the desired amount of resources
-- @param[type=string] _ScriptName Name of chest
-- @param[type=string] _ResourceType Resource Type or "Random"
-- @param[type=number] _Amount Amount of resource
-- @within Rewards
--
function Reward_CreateChest(...)
    return b_Reward_CreateChest:New(unpack(arg));
end

b_Reward_CreateChest = {
    Data = {
        Name = "Reward_CreateChest",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_CreateChest:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.ScriptName = _Parameter;
    elseif _Index == 2 then
        self.Data.ResourceType = _Parameter or "Random";
    elseif _Index == 3 then
        self.Data.Amount = _Parameter;
    end
end

function b_Reward_CreateChest:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_CreateChest:CustomFunction(_Quest)
    local ResourceMap = {Gold = 1, Clay = 2, Wood = 3, Stone = 4, Iron = 5, Sulfur = 6,};
    local Chest = new(TreasureTemplate, self.Data.ScriptName);
    Chest.m_Rewards[ResourceMap[self.Data.ResourceType] or math.random(1, 6)] = self.Data.Amount;
    Chest:Activate();
end

function b_Reward_CreateChest:Debug(_Quest)
    if not IsExisting(self.Data.ScriptName) then
        dbg(_Quest, self, "Script entity is missing: " ..tostring(self.Data.ScriptName));
        return true;
    end
    if not self.Data.Amount or self.Data.Amount < 1 then
        dbg(_Quest, self, "Amount must be greater than 0!");
        return true;
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Reward_CreateChest);

