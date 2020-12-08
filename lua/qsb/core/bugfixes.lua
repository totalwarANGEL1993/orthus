-- ########################################################################## --
-- #  Bugfixes                                                              # --
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
-- <li>qsb.core.oop</li>
-- <li>qsb.core.mpsync</li>
-- <li>qsb.core.questsystem</li>
-- </ul>
--
-- @set sort=true
--

Bugfixes = {
    UseCrushBuildingFix = true,
    UseFormationFix = true,
    UseBlessLimit = false,
    UseWeatherChangeLimit = false,
    UseFindViewFix = true,

    ScriptEvents = {},
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
    Bugfixes.UseCrushBuildingFix = _Flag == true;
end

---
-- Activates or deactivates the formation fix.
-- @param[type=boolean] _Flag Active
-- @within Methods
--
function ActivateFormationBugfix(_Flag)
    Bugfixes.UseFormationFix = _Flag == true;
end

---
-- Activates or deactivates the bless limit.
-- @param[type=boolean] _Flag Active
-- @within Methods
--
function ActivateBlessLimitBugfix(_Flag)
    Bugfixes.UseBlessLimit = _Flag == true;
end

---
-- Activates or deactivates the weather change limit.
-- @param[type=boolean] _Flag Active
-- @within Methods
--
function ActivateWeatherChangeLimitBugfix(_Flag)
    Bugfixes.UseWeatherChangeLimit = _Flag == true;
end

---
-- Activates or deactivates the find view fix.
-- @param[type=boolean] _Flag Active
-- @within Methods
--
function ActivateFindViewBugfix(_Flag)
    Bugfixes.UseFindViewFix = _Flag == true;
end

---
-- Sets the delay between blesses. The time is shared between all types.
-- @param[type=number] _Time Delay
-- @within Methods
--
function SetBlessDelay(_Time)
    _Time = (_Time <= 30 and 30) or _Time;
    Bugfixes.BlessLimit.Limit = _Time;
end

---
-- Sets the delay between weather changes.
-- @param[type=number] _Time Delay
-- @within Methods
--
function SetWeatherChangeDelay(_Time)
    _Time = (_Time <= 30 and 30) or _Time;
    Bugfixes.WeatherChangeLimit.Limit = _Time;
end

-- -------------------------------------------------------------------------- --

---
-- Installs the module.
-- @within Bugfix
-- @local
--
function Bugfixes:Install()
    Tools.GiveResources = Tools.GiveResouces;
    Mission_OnSaveGameLoaded_Orig_QSB_Bugfixes = Mission_OnSaveGameLoaded;
    Mission_OnSaveGameLoaded = function()
        Mission_OnSaveGameLoaded_Orig_QSB_Bugfixes();
        Bugfixes:OverrideGuiSellBuilding();
    end
    
    self:OverrideGuiSellBuilding();
    self:CreateScriptEvents();
    self:OverrideGUIActions();
    self:OverrideGUITooltip();
    self:OverrideGUIUpdate();
end

function Bugfixes:CreateScriptEvents()
    self.ScriptEvents.PostPlayerBlessed = MPSync:CreateScriptEvent(function(_PlayerID, _Time, _Bless)
        Bugfixes.BlessLimit[_Bless][_PlayerID] = _Time;
    end);
    self.ScriptEvents.PostWeatherChanged = MPSync:CreateScriptEvent(function(_Time)
        Bugfixes.WeatherChangeLimit.Last = _Time;
    end);
end

function Bugfixes:PostPlayerBlessed(_PlayerID, _Time, _Bless)
    MPSync:SnchronizedCall(self.ScriptEvents.PostPlayerBlessed, _PlayerID, _Time, _Bless);
end

function Bugfixes:PostWeatherChanged(_Time)
    MPSync:SnchronizedCall(self.ScriptEvents.PostWeatherChanged, _Time);
end

function Bugfixes:OverrideGuiSellBuilding()
    Bugfixes.GUI_SellBuilding = nil;
    Bugfixes.GUI_SellBuilding = GUI.SellBuilding;
    GUI.SellBuilding = function(_BuildingID)
        if Bugfixes.UseCrushBuildingFix then
            GUI.DeselectEntity(_BuildingID);
        end
        Bugfixes.GUI_SellBuilding(_BuildingID);
    end
end

function Bugfixes:OverrideGUIActions()
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
            Sound.PlayFeedbackSound(Sounds.VoicesMentor_INFO_MonksNeedMoreTime_rnd_01, 0);
            return;
        end
        Bugfixes:PostPlayerBlessed(
            PlayerID,
            Time,
            Bugfixes.Maps.BlessCategoryToButton[_BlessCategory]
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
        Bugfixes:PostWeatherChanged(Time);
        GUI.SetWeather(_Weathertype);
    end
end

function Bugfixes:OverrideGUITooltip()
    -- Bless Limit
    GUITooltip_BlessSettlers_Orig_QSB_Bugfix = GUITooltip_BlessSettlers;
    GUITooltip_BlessSettlers = function(_Disabled, _Normal, _Researched, _Key)
        GUITooltip_BlessSettlers_Orig_QSB_Bugfix(_Disabled, _Normal, _Researched, _Key);
        local PlayerID = GUI.GetPlayerID();
        local WidgetID = XGUIEng.GetCurrentWidgetID();
        local s, e = string.find(_Normal, "MenuMonastery/");
        local Button = string.sub(_Normal, e+1, string.len(_Normal) -7);
        if Bugfixes.UseBlessLimit then
            local Time = Bugfixes:GetBlessDelayForPlayer(PlayerID, Button);
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
        if Bugfixes.UseWeatherChangeLimit then
            local Data = Bugfixes.WeatherChangeLimit;
            local Time = Data.Last + Data.Limit - math.floor(Logic.GetTime());
            if Data.Last > 0 and Time > 0 then
                XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, XGUIEng.GetStringTableText(_Text));
                XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomCosts, QuestSystem:ReplacePlaceholders("{red}" ..Time));
            end
        end
    end
end

function Bugfixes:OverrideGUIUpdate()
    GUIUpdate_FindView_Orig_QSB_Bugfix = GUIUpdate_FindView
    GUIUpdate_FindView = function()
        local PlayerID = GUI.GetPlayerID();
        local EntityID = GUI.GetSelectedEntity();
        
        -- Find view fix
        if not Bugfixes.UseFindViewFix then
            GUIUpdate_FindView_Orig_QSB_Bugfix();
        else
            Bugfixes:UpdateFindViewButtons();
        end
        -- Find View
        Bugfixes:UpdateFormationButtons();
        -- Bless limit
        Bugfixes:UpdateBlessSettlerButtons();
        -- Weather change limit
        Bugfixes:UpdateChangeWeatherButtons();
    end
end

function Bugfixes:UpdateChangeWeatherButtons()
    if Bugfixes.UseWeatherChangeLimit then
        local Data = Bugfixes.WeatherChangeLimit;
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

function Bugfixes:UpdateFindViewButtons()
    local PlayerID = GUI.GetPlayerID();
    local EntityID = GUI.GetSelectedEntity();
    if Bugfixes.UseFindViewFix then
        local ScoutAmount = 0;
        if Entities.PU_Scout then
            ScoutAmount = Logic.GetNumberOfEntitiesOfTypeOfPlayer(PlayerID, Entities.PU_Scout);
        end
        local ThiefAmount = 0;
        if Entities.PU_Thief then
            ThiefAmount = Logic.GetNumberOfEntitiesOfTypeOfPlayer(PlayerID, Entities.PU_Thief);
        end
        local AllCannons  = QSBTools.GetAllCannons(PlayerID);
        local AllLeader   = QSBTools.GetAllLeader(PlayerID);

        local ExistingMap = {}
        for i= 1, table.getn(AllLeader), 1 do
            for k, v in pairs(Bugfixes.Maps.EntityCategoryToFindView) do
                if Logic.IsEntityInCategory(AllLeader[i], EntityCategories[k]) == 1 then
                    ExistingMap[k] = (ExistingMap[k] or 0) +1;
                end
            end
        end
        for k, v in pairs(Bugfixes.Maps.EntityCategoryToFindView) do
            XGUIEng.ShowWidget(
                Bugfixes.Maps.EntityCategoryToFindView[k],
                ((ExistingMap[k] or 0) > 0 and 1) or 0
            );
        end
        XGUIEng.ShowWidget("FindCannon", (table.getn(AllCannons) > 0 and 1) or 0);
        XGUIEng.ShowWidget("FindScout", (ScoutAmount > 0 and 1) or 0);
        XGUIEng.ShowWidget("FindThief", (ThiefAmount > 0 and 1) or 0);
    end
end

function Bugfixes:UpdateBlessSettlerButtons()
    local PlayerID = GUI.GetPlayerID();
    local EntityID = GUI.GetSelectedEntity();
    if Bugfixes.UseBlessLimit then
        if EntityID then
            local EntityTypeName = Logic.GetEntityTypeName(Logic.GetEntityType(EntityID));
            if string.find(EntityTypeName, "PB_Monastery") then
                GUIUpdate_BuildingButtons("BlessSettlers1", Technologies.T_BlessSettlers1);
                GUIUpdate_BuildingButtons("BlessSettlers2", Technologies.T_BlessSettlers2);
                GUIUpdate_GlobalTechnologiesButtons("BlessSettlers3", Technologies.T_BlessSettlers3,Entities.PB_Monastery2);
                GUIUpdate_GlobalTechnologiesButtons("BlessSettlers4", Technologies.T_BlessSettlers4,Entities.PB_Monastery2);
                GUIUpdate_GlobalTechnologiesButtons("BlessSettlers5", Technologies.T_BlessSettlers5,Entities.PB_Monastery3);
                for i= 1, 5, 1 do
                    if Bugfixes:GetBlessDelayForPlayer(PlayerID, "BlessSettlers" ..i) > 0 then
                        XGUIEng.DisableButton("BlessSettlers" ..i, 1);
                    end
                end
            end
        end
    end
end

function Bugfixes:UpdateFormationButtons()
    local PlayerID = GUI.GetPlayerID();
    local EntityID = GUI.GetSelectedEntity();
    if Bugfixes.UseFormationFix then
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

function Bugfixes:GetBlessDelayForPlayer(_PlayerID, _Button)
    local Last = Bugfixes.BlessLimit[_Button][_PlayerID] or 0;
    if Last == 0 then
        return 0;
    end
    return Last + Bugfixes.BlessLimit.Limit - math.floor(Logic.GetTime());
end

