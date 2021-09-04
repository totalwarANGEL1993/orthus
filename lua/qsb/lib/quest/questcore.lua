-- ########################################################################## --
-- #  QuestCore                                                                  # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module fixes some minor bugs in the game.
--
-- <h4>Crush Building</h4>
-- When a building is crushed it is deselected before the command is executed.
-- This way it is (for humans) impossilbe to reselect the building in time to
-- use the crush building exploit.
--
-- <h4>Formations</h4>
-- Formations no longer additionally need GT_Tactics to be allowed to be shown.
-- Just GT_StandingArmy researched as described in the tooltip.
--
-- <h4>Bless limit</h4>
-- Adds a limit to blesses for each player and each category. Players must
-- wait some seconds before they can bless their settlers again.
--
-- <h4>Weather change limit</h4>
-- Adds a global limit to weather changes. If a wheater change is triggered
-- by any player all players can't change the weather until the end of the
-- delay.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.oop</li>
-- <li>qsb.quest.questsync</li>
-- <li>qsb.quest.questsystem</li>
-- </ul>
--
-- @set sort=true
--

QuestCore = {
    UseCrushBuildingFix = true,
    UseFormationFix = true,
    UseBlessLimit = false,
    UseWeatherChangeLimit = false,
    UseFindViewFix = true,
    UseTradeAmountFix = true,

    SaveLoadedActions = {},
    ScriptEvents = {},
    TradeLimit = -1,
    WeatherChangeLimit = {
        Limit = 3 * 60,
        Last  = 0,
    },
    BlessLimit = {
        Limit = 90,
        BlessSettlers1 = {};
        BlessSettlers2 = {};
        BlessSettlers3 = {};
        BlessSettlers4 = {};
        BlessSettlers5 = {};
    },

    Maps = {
        EntityCategoryToFindView = {
            ["Sword"]        = "FindSwordmen",
            ["Spear"]        = "FindSpearmen",
            ["Bow"]          = "FindBowmen",
            ["CavalryLight"] = "FindLightCavalry",
            ["CavalryHeavy"] = "FindHeavyCavalry",
            ["Rifle"]        = "FindRiflemen",
        },
        BlessCategoryToButton = {
            [BlessCategories.Construction] = "BlessSettlers1",
            [BlessCategories.Research]     = "BlessSettlers2",
            [BlessCategories.Weapons]      = "BlessSettlers3",
            [BlessCategories.Financial]    = "BlessSettlers4",
            [BlessCategories.Canonisation] = "BlessSettlers5",
        }
    },
};

-- -------------------------------------------------------------------------- --

---
-- Activates or deactivates the crush building fix.
-- @param[type=boolean] _Flag Active
-- @within Methods
--
function ActivateCrushBuildingBugfix(_Flag)
    QuestCore.UseCrushBuildingFix = _Flag == true;
end

---
-- Activates or deactivates the formation fix.
-- @param[type=boolean] _Flag Active
-- @within Methods
--
function ActivateFormationBugfix(_Flag)
    QuestCore.UseFormationFix = _Flag == true;
end

---
-- Activates or deactivates the bless limit.
-- @param[type=boolean] _Flag Active
-- @within Methods
--
function ActivateBlessLimitBugfix(_Flag)
    QuestCore.UseBlessLimit = _Flag == true;
end

---
-- Activates or deactivates the weather change limit.
-- @param[type=boolean] _Flag Active
-- @within Methods
--
function ActivateWeatherChangeLimitBugfix(_Flag)
    QuestCore.UseWeatherChangeLimit = _Flag == true;
end

---
-- Activates or deactivates the find view fix.
-- @param[type=boolean] _Flag Active
-- @within Methods
--
function ActivateFindViewBugfix(_Flag)
    QuestCore.UseFindViewFix = _Flag == true;
end

---
-- Sets the delay between blesses. The time is shared between all types.
-- @param[type=number] _Time Delay
-- @within Methods
--
function SetBlessDelay(_Time)
    _Time = (_Time <= 30 and 30) or _Time;
    QuestCore.BlessLimit.Limit = _Time;
end

---
-- Sets the delay between weather changes.
-- @param[type=number] _Time Delay
-- @within Methods
--
function SetWeatherChangeDelay(_Time)
    _Time = (_Time <= 30 and 30) or _Time;
    QuestCore.WeatherChangeLimit.Limit = _Time;
end

---
-- Sets the limit for transactions. Set limit to -1 do deactivate it. The limit
-- can only be set in 2500 steps.
-- @param[type=number] _Limit Limit
-- @within Methods
--
function SetTradeAmountLimit(_Limit)
    if math.mod(_Limit, 250) ~= 0 then
        _Limit = 250 * math.floor((_Limit / 250) + 0.5);
    end
    QuestCore.TradeLimit = _Limit;
end

---
-- Adds an action that is performed after a save is loaded.
-- @param[type=function] _Function Action
-- @param                ...       Data
-- @within Methods
--
function AddOnSaveLoadedAction(_Function, ...)
    QuestCore:AddSaveLoadActions(_Function, unpack(copy(arg)));
end

-- -------------------------------------------------------------------------- --

---
-- Installs the module.
-- @within Bugfix
-- @local
--
function QuestCore:Install()
    Tools.GiveResources = Tools.GiveResouces;
    if MultiplayerTools then
        Mission_OnSaveGameLoaded_Orig_QSB_QuestCore = MultiplayerTools.OnSaveGameLoaded;
        MultiplayerTools.OnSaveGameLoaded = function()
            Mission_OnSaveGameLoaded_Orig_QSB_QuestCore();
            QuestCore:CallSaveLoadActions();
            QuestCore:OverrideGuiSellBuilding();
        end
    else
        Mission_OnSaveGameLoaded_Orig_QSB_QuestCore = Mission_OnSaveGameLoaded;
        Mission_OnSaveGameLoaded = function()
            Mission_OnSaveGameLoaded_Orig_QSB_QuestCore();
            QuestCore:CallSaveLoadActions();
            QuestCore:OverrideGuiSellBuilding();
        end
    end
    
    self:OverrideGuiSellBuilding();
    self:CreateScriptEvents();
    self:OverrideGUIActions();
    self:OverrideGUITooltip();
    self:OverrideGUIUpdate();
end

function QuestCore:AddSaveLoadActions(_Function, ...)
    table.insert(self.SaveLoadedActions, {_Function, unpack(copy(arg))});
end

function QuestCore:CallSaveLoadActions()
    for k, v in pairs(self.SaveLoadedActions) do
        v[1](v);
    end
end

function QuestCore:CreateScriptEvents()
    self.ScriptEvents.PostPlayerBlessed = QuestSync:CreateScriptEvent(function(name, _PlayerID, _Time, _Bless)
        if CNetwork and not CNetwork.IsAllowedToManipulatePlayer(name, _PlayerID) then
            return;
        end
        QuestCore.BlessLimit[_Bless][_PlayerID] = _Time;
    end);
    self.ScriptEvents.PostWeatherChanged = QuestSync:CreateScriptEvent(function(name, _Time)
        QuestCore.WeatherChangeLimit.Last = _Time;
    end);
end

function QuestCore:PostPlayerBlessed(_PlayerID, _Time, _Bless)
    QuestSync:SynchronizedCall(self.ScriptEvents.PostPlayerBlessed, _PlayerID, _Time, _Bless);
end

function QuestCore:PostWeatherChanged(_Time)
    QuestSync:SynchronizedCall(self.ScriptEvents.PostWeatherChanged, _Time);
end

function QuestCore:OverrideGuiSellBuilding()
    QuestCore.GUI_SellBuilding = nil;
    QuestCore.GUI_SellBuilding = GUI.SellBuilding;
    GUI.SellBuilding = function(_BuildingID)
        if QuestCore.UseCrushBuildingFix then
            GUI.DeselectEntity(_BuildingID);
        end
        QuestCore.GUI_SellBuilding(_BuildingID);
    end
end

function QuestCore:OverrideGUIActions()
    -- Bless Settlers delay
    GUIAction_BlessSettlers = function(_BlessCategory)
        local PlayerID = GUI.GetPlayerID();
        local Time = math.floor(Logic.GetTime());
        if InterfaceTool_IsBuildingDoingSomething(GUI.GetSelectedEntity()) == true then		
            return;
        end
        local CurrentFaith = Logic.GetPlayersGlobalResource(PlayerID, ResourceType.Faith);
        local BlessCosts = Logic.GetBlessCostByBlessCategory(_BlessCategory);
        if BlessCosts > CurrentFaith then
            GUI.AddNote(XGUIEng.GetStringTableText("InGameMessages/GUI_NotEnoughFaith"));
            Sound.PlayFeedbackSound(Sounds.VoicesMentor_INFO_MonksNeedMoreTime_rnd_01);
            return;
        end
        QuestCore:PostPlayerBlessed(
            PlayerID,
            Time,
            QuestCore.Maps.BlessCategoryToButton[_BlessCategory]
        );
        GUI.BlessByBlessCategory(_BlessCategory);
    end

    -- Change weather delay
    GUIAction_ChangeWeather = function(_Weathertype)
        if Logic.IsWeatherChangeActive() == true then
            GUI.AddNote(XGUIEng.GetStringTableText("InGameMessages/Note_WeatherIsCurrentlyChanging"))		
            return;
        end
        local PlayerID = GUI.GetPlayerID();
        local Time = math.floor(Logic.GetTime());
        local CurrentWeatherEnergy = Logic.GetPlayersGlobalResource(PlayerID, ResourceType.WeatherEnergy);
        local NeededWeatherEnergy = Logic.GetEnergyRequiredForWeatherChange();
        if CurrentWeatherEnergy < NeededWeatherEnergy then		
            GUI.AddNote(XGUIEng.GetStringTableText("InGameMessages/GUI_WeathermashineNotReady"));
            return;
        end
        GUI.AddNote(XGUIEng.GetStringTableText("InGameMessages/GUI_WeathermashineActivated"));
        QuestCore:PostWeatherChanged(Time);
        GUI.SetWeather(_Weathertype);
    end

    function GUIAction_MarketToggleResource(_value, _resource)
        if QuestCore.UseTradeAmountFix then
            _value = _value * 5;
            if XGUIEng.IsModifierPressed( Keys.ModifierControl ) == 1 then
                _value = _value * 10;
            end
        else
            _value = _value;
            if XGUIEng.IsModifierPressed( Keys.ModifierControl ) == 1 then
                _value = _value * 5;
            end
        end
        _resource = _resource + _value;
        if QuestCore.TradeLimit > -1 then
            if _resource > QuestCore.TradeLimit then
                _resource = QuestCore.TradeLimit;
            end
        end
        if _resource <= 0 then
            _resource = 0;
        end
        return _resource;
    end
end

function QuestCore:OverrideGUITooltip()
    -- Bless Limit
    GUITooltip_BlessSettlers_Orig_QSB_Bugfix = GUITooltip_BlessSettlers;
    GUITooltip_BlessSettlers = function(_Disabled, _Normal, _Researched, _Key)
        GUITooltip_BlessSettlers_Orig_QSB_Bugfix(_Disabled, _Normal, _Researched, _Key);
        local PlayerID = GUI.GetPlayerID();
        local WidgetID = XGUIEng.GetCurrentWidgetID();
        local s, e = string.find(_Normal, "MenuMonastery/");
        local Button = string.sub(_Normal, e+1, string.len(_Normal) -7);
        if QuestCore.UseBlessLimit then
            local Time = QuestCore:GetBlessDelayForPlayer(PlayerID, Button);
            if Time > 0 then
                XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, XGUIEng.GetStringTableText(_Normal));
                XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomCosts, QuestSystem:ReplacePlaceholders("{red}" ..Time));
            end
        end
    end

    -- Weather change Limit
    GUITooltip_ResearchTechnologies_Orig_QSB_Bugfix = GUITooltip_ResearchTechnologies;
    GUITooltip_ResearchTechnologies = function(_Technology, _Text, _Key)
        GUITooltip_ResearchTechnologies_Orig_QSB_Bugfix(_Technology, _Text, _Key);
        local PlayerID = GUI.GetPlayerID();
        local WidgetID = XGUIEng.GetCurrentWidgetID();
        if QuestCore.UseWeatherChangeLimit then
            local Data = QuestCore.WeatherChangeLimit;
            local Time = Data.Last + Data.Limit - math.floor(Logic.GetTime());
            if Data.Last > 0 and Time > 0 then
                XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, XGUIEng.GetStringTableText(_Text));
                XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomCosts, QuestSystem:ReplacePlaceholders("{red}" ..Time));
            end
        end
    end
end

function QuestCore:OverrideGUIUpdate()
    GUIUpdate_FindView_Orig_QSB_Bugfix = GUIUpdate_FindView
    GUIUpdate_FindView = function()
        local PlayerID = GUI.GetPlayerID();
        local EntityID = GUI.GetSelectedEntity();
        
        -- Find view fix
        if not QuestCore.UseFindViewFix then
            GUIUpdate_FindView_Orig_QSB_Bugfix();
        else
            QuestCore:UpdateFindViewButtons();
        end
        -- Find View
        QuestCore:UpdateFormationButtons();
        -- Bless limit
        QuestCore:UpdateBlessSettlerButtons();
        -- Weather change limit
        QuestCore:UpdateChangeWeatherButtons();
    end
end

function QuestCore:UpdateChangeWeatherButtons()
    if QuestCore.UseWeatherChangeLimit then
        local Data = QuestCore.WeatherChangeLimit;
        local Time = Data.Last + Data.Limit - math.floor(Logic.GetTime());
        GUIUpdate_ChangeWeatherButtons("WeatherTower_MakeSummer", Technologies.T_MakeSummer, 1);
        GUIUpdate_ChangeWeatherButtons("WeatherTower_MakeRain", Technologies.T_MakeRain, 1);
        GUIUpdate_ChangeWeatherButtons("WeatherTower_MakeSnow", Technologies.T_MakeSnow, 1);
        if Data.Last > 0 and Time > 0 then
            XGUIEng.DisableButton("WeatherTower_MakeSummer", 1);
            XGUIEng.DisableButton("WeatherTower_MakeRain", 1);
            XGUIEng.DisableButton("WeatherTower_MakeSnow", 1);
        end
    end
end

function QuestCore:UpdateFindViewButtons()
    local PlayerID = GUI.GetPlayerID();
    local EntityID = GUI.GetSelectedEntity();
    if QuestCore.UseFindViewFix then
        local ScoutAmount = 0;
        if Entities.PU_Scout then
            ScoutAmount = Logic.GetNumberOfEntitiesOfTypeOfPlayer(PlayerID, Entities.PU_Scout);
        end
        local ThiefAmount = 0;
        if Entities.PU_Thief then
            ThiefAmount = Logic.GetNumberOfEntitiesOfTypeOfPlayer(PlayerID, Entities.PU_Thief);
        end
        local AllCannons  = QuestTools.GetAllCannons(PlayerID);
        local AllLeader   = QuestTools.GetAllLeader(PlayerID);

        local ExistingMap = {}
        for i= 1, table.getn(AllLeader), 1 do
            for k, v in pairs(QuestCore.Maps.EntityCategoryToFindView) do
                if Logic.IsEntityInCategory(AllLeader[i], EntityCategories[k]) == 1 then
                    ExistingMap[k] = (ExistingMap[k] or 0) +1;
                end
            end
        end
        for k, v in pairs(QuestCore.Maps.EntityCategoryToFindView) do
            XGUIEng.ShowWidget(
                QuestCore.Maps.EntityCategoryToFindView[k],
                ((ExistingMap[k] or 0) > 0 and 1) or 0
            );
        end
        XGUIEng.ShowWidget("FindCannon", (table.getn(AllCannons) > 0 and 1) or 0);
        XGUIEng.ShowWidget("FindScout", (ScoutAmount > 0 and 1) or 0);
        XGUIEng.ShowWidget("FindThief", (ThiefAmount > 0 and 1) or 0);
    end
end

function QuestCore:UpdateBlessSettlerButtons()
    local PlayerID = GUI.GetPlayerID();
    local EntityID = GUI.GetSelectedEntity();
    if QuestCore.UseBlessLimit then
        if EntityID then
            local EntityTypeName = Logic.GetEntityTypeName(Logic.GetEntityType(EntityID));
            if string.find(EntityTypeName, "PB_Monastery") then
                GUIUpdate_BuildingButtons("BlessSettlers1", Technologies.T_BlessSettlers1);
                GUIUpdate_BuildingButtons("BlessSettlers2", Technologies.T_BlessSettlers2);
                GUIUpdate_GlobalTechnologiesButtons("BlessSettlers3", Technologies.T_BlessSettlers3,Entities.PB_Monastery2);
                GUIUpdate_GlobalTechnologiesButtons("BlessSettlers4", Technologies.T_BlessSettlers4,Entities.PB_Monastery2);
                GUIUpdate_GlobalTechnologiesButtons("BlessSettlers5", Technologies.T_BlessSettlers5,Entities.PB_Monastery3);
                for i= 1, 5, 1 do
                    if QuestCore:GetBlessDelayForPlayer(PlayerID, "BlessSettlers" ..i) > 0 then
                        XGUIEng.DisableButton("BlessSettlers" ..i, 1);
                    end
                end
            end
        end
    end
end

function QuestCore:UpdateFormationButtons()
    local PlayerID = GUI.GetPlayerID();
    local EntityID = GUI.GetSelectedEntity();
    if QuestCore.UseFormationFix then
        -- Vilibility
        if IsExisting(EntityID) and Logic.IsLeader(EntityID) == 1
        and Logic.LeaderGetMaxNumberOfSoldiers(EntityID) > 0 then
            local TypeID = Logic.GetEntityType(EntityID);
            local TypeName = Logic.GetEntityTypeName(TypeID);
            if string.find(TypeName, "Scout") or string.find(TypeName, "Scout") 
            or string.find(TypeName, "Thief") then
                for i= 1, 4, 1 do
                    XGUIEng.ShowWidget("Formation0" ..i, 0);
                end
            else
                for i= 1, 4, 1 do
                    XGUIEng.ShowWidget("Formation0" ..i, 1);
                end
            end
        end
        -- Availability
        for i= 1, 4, 1 do
            XGUIEng.ShowWidget("Formation0" ..i, 1);
            if Logic.IsTechnologyResearched(PlayerID, Technologies.GT_StandingArmy) == 1 then
                XGUIEng.DisableButton("Formation0" ..i, 0);
            else
                XGUIEng.DisableButton("Formation0" ..i, 1);
            end
        end
    end
end

function QuestCore:GetBlessDelayForPlayer(_PlayerID, _Button)
    local Last = QuestCore.BlessLimit[_Button][_PlayerID] or 0;
    if Last == 0 then
        return 0;
    end
    return Last + QuestCore.BlessLimit.Limit - math.floor(Logic.GetTime());
end

