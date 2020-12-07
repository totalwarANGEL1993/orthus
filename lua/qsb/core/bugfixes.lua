-- ########################################################################## --
-- #  Bugfixes                                                              # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module fixes some minor bugs in the game.
--
-- <h4>Crush Building</h4>
-- Removes the confirmation menu from destroy building button. The building is
-- deselected and then immedaitly destroyed.
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

QuestSystem.Bugfixes = {
    UseCrushBuilding = true,
    UseFormation = true,
    UseBlessLimit = false,
    UseWeatherChangeLimit = false,

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
};

-- -------------------------------------------------------------------------- --

---
-- Activates or deactivates the crush building fix.
-- @param[type=boolean] _Flag Active
-- @within Methods
--
function ActivateCrushBuildingBugfix(_Flag)
    QuestSystem.Bugfixes.UseCrushBuilding = _Flag == true;
end

---
-- Activates or deactivates the formation fix.
-- @param[type=boolean] _Flag Active
-- @within Methods
--
function ActivateFormationBugfix(_Flag)
    QuestSystem.Bugfixes.UseFormation = _Flag == true;
end

---
-- Activates or deactivates the bless limit.
-- @param[type=boolean] _Flag Active
-- @within Methods
--
function ActivateBlessLimitBugfix(_Flag)
    QuestSystem.Bugfixes.UseBlessLimit = _Flag == true;
end

---
-- Activates or deactivates the weather change limit.
-- @param[type=boolean] _Flag Active
-- @within Methods
--
function ActivateWeatherChangeLimitBugfix(_Flag)
    QuestSystem.Bugfixes.WeatherChangeLimit = _Flag == true;
end

---
-- Sets the delay between blesses. The time is shared between all types.
-- @param[type=number] _Time Delay
-- @within Methods
--
function SetBlessDelay(_Time)
    _Time = (_Time <= 30 and 30) or _Time;
    QuestSystem.Bugfixes.BlessLimit.Limit = _Time;
end

---
-- Sets the delay between weather changes.
-- @param[type=number] _Time Delay
-- @within Methods
--
function SetWeatherChangeDelay(_Time)
    _Time = (_Time <= 30 and 30) or _Time;
    QuestSystem.Bugfixes.WeatherChangeLimit.Limit = _Time;
end

-- -------------------------------------------------------------------------- --

---
-- Installs the module.
-- @within QuestSystem.Bugfixes
-- @local
--
function QuestSystem.Bugfixes:Install()
    Tools.GiveResources = Tools.GiveResouces;
    
    self:CreateScriptEvents();
    self:OverrideGUIActions();
    self:OverrideGUITooltip();
    self:OverrideGUIUpdate();
    self:OverrideGameCallback();
end

function QuestSystem.Bugfixes:CreateScriptEvents()
    self.ScriptEvents.PostPlayerBlessed = MPSync:CreateScriptEvent(function(_PlayerID, _Time, _Bless)
        QuestSystem.Bugfixes.BlessLimit[_Bless][_PlayerID] = _Time;
    end);
    self.ScriptEvents.PostWeatherChanged = MPSync:CreateScriptEvent(function(_Time)
        QuestSystem.Bugfixes.WeatherChangeLimit.Last = _Time;
    end);
end

function QuestSystem.Bugfixes:PostPlayerBlessed(_PlayerID, _Time, _Bless)
    MPSync:SnchronizedCall(self.ScriptEvents.PostPlayerBlessed, _PlayerID, _Time, _Bless);
end

function QuestSystem.Bugfixes:PostWeatherChanged(_Time)
    MPSync:SnchronizedCall(self.ScriptEvents.PostWeatherChanged, _Time);
end

function QuestSystem.Bugfixes:OverrideGUIActions()
    -- Crush building fix
    GUIAction_ToDestroyBuildingWindow_Orig_QSB_Bugfix = GUIAction_ToDestroyBuildingWindow;
    GUIAction_ToDestroyBuildingWindow = function()
        if QuestSystem.Bugfixes.UseCrushBuilding then
            local BuildingID = GUI.GetSelectedEntity();
            if IsExisting(BuildingID) then
                GUI.DeselectEntity(BuildingID);
                GUI.SellBuilding(BuildingID);
            end
            return;
        end
        GUIAction_ToDestroyBuildingWindow_Orig_QSB_Bugfix();
    end

    -- Bless Settlers delay
    GUIAction_BlessSettlers = function(_Type)
        local PlayerID = GUI.GetPlayerID();
        local Time = math.floor(Logic.GetTime());
        local Bless = "BlessSettler1";
        if _BlessCategory == BlessCategories.Research then
            Bless = "BlessSettler2";
        end
        if _BlessCategory == BlessCategories.Weapons then
            Bless = "BlessSettler3";
        end
        if _BlessCategory == BlessCategories.Financial then
            Bless = "BlessSettler4";
        end
        if _BlessCategory == BlessCategories.Canonisation then
            Bless = "BlessSettler5";
        end

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
        QuestSystem.Bugfixes:PostPlayerBlessed(PlayerID, Time, Bless);
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
        QuestSystem.Bugfixes:PostWeatherChanged(Time);
        GUI.SetWeather(_Weathertype);
    end
end

function QuestSystem.Bugfixes:OverrideGUITooltip()
    -- Bless Limit
    GUITooltip_BlessSettlers_Orig_QSB_Bugfix = GUITooltip_BlessSettlers;
    GUITooltip_BlessSettlers = function(_Disabled, _Normal, _Researched, _Key)
        GUITooltip_BlessSettlers_Orig_QSB_Bugfix(_Disabled, _Normal, _Researched, _Key);
        local PlayerID = GUI.GetPlayerID();
        local WidgetID = XGUIEng.GetCurrentWidgetID();
        local s, e = string.find(_Normal, "MenuMonastery/");
        local Button = string.sub(_Normal, e+1, string.len(_Normal) -7);
        if QuestSystem.Bugfixes.UseBlessLimit then
            if QuestSystem.Bugfixes:GetBlessDelayForPlayer(PlayerID, Button) > 0 then
                XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, QuestSystem:ReplacePlaceholders("{red}(" ..Time.. ")"));
            end
        end
    end

    -- Weather change Limit
    GUITooltip_ResearchTechnologies_Orig_QSB_Bugfix = GUITooltip_ResearchTechnologies;
    GUITooltip_ResearchTechnologies = function(_Technology, _Text, _Key)
        GUITooltip_ResearchTechnologies_Orig_QSB_Bugfix(_Technology, _Text, _Key);
        local PlayerID = GUI.GetPlayerID();
        local WidgetID = XGUIEng.GetCurrentWidgetID();

        if QuestSystem.Bugfixes.UseWeatherChangeLimit then
            local Data = QuestSystem.Bugfixes.WeatherChangeLimit;
            local Time = Data.Last + Data.Limit - math.floor(Logic.GetTime());
            if Data.Last > 0 and Time > 0 then
                XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, QuestSystem:ReplacePlaceholders("{red}(" ..Time.. ")"));
            end
        end
    end
end

function QuestSystem.Bugfixes:OverrideGUIUpdate()
    GUIUpdate_BuildingButtons_Orig_QSB_Bugfix = GUIUpdate_BuildingButtons;
    GUIUpdate_BuildingButtons = function(_Button, _Technology)
        GUIUpdate_BuildingButtons_Orig_QSB_Bugfix(_Button, _Technology);
        local PlayerID = GUI.GetPlayerID();
        local WidgetID = XGUIEng.GetCurrentWidgetID();

        -- Formation fix
        if QuestSystem.Bugfixes.UseFormation then
            if string.find(_Button, "Formation0") then
                XGUIEng.ShowWidget(_Button, 1);
                if Logic.IsTechnologyResearched(PlayerID, Technologies.GT_StandingArmy) == 1 then
                    XGUIEng.DisableButton(WidgetID, 0);
                else
                    XGUIEng.DisableButton(WidgetID, 1);
                end
            end
        end
        -- Bless Limit
        if QuestSystem.Bugfixes.UseBlessLimit then
            if string.find(_Button, "BlessSettler") then
                if QuestSystem.Bugfixes:GetBlessDelayForPlayer(PlayerID, _Button) > 0 then
                    XGUIEng.DisableButton(WidgetID, 1);
                end
            end
        end
    end
end

function QuestSystem.Bugfixes:OverrideGameCallback()
    GameCallback_GUI_SelectionChanged_Orig_QSB_Bugfix = GameCallback_GUI_SelectionChanged;
    GameCallback_GUI_SelectionChanged = function()
        GameCallback_GUI_SelectionChanged_Orig_QSB_Bugfix();
        QuestSystem.Bugfixes:UpdateFormation();
    end

    GameCallback_OnBuildingConstructionComplete_Orig_QSB_Bugfix = GameCallback_OnBuildingConstructionComplete;
    GameCallback_OnBuildingConstructionComplete = function(_BuildingID, _PlayerID)
        GameCallback_GUI_SelectionChanged_Orig_QSB_Bugfix(_BuildingID, _PlayerID);
        QuestSystem.Bugfixes:UpdateFormation();
    end

    GameCallback_OnBuildingUpgradeComplete_Orig_QSB_Bugfix = GameCallback_OnBuildingUpgradeComplete;
    GameCallback_OnBuildingUpgradeComplete = function(_BuildingIDOld, _BuildingIDNew)
        GameCallback_OnBuildingUpgradeComplete_Orig_QSB_Bugfix(_BuildingIDOld, _BuildingIDNew);
        QuestSystem.Bugfixes:UpdateFormation();
    end

    GameCallback_OnTechnologyResearched_Orig_QSB_Bugfix = GameCallback_OnBuildingConstructionComplete;
    GameCallback_OnTechnologyResearched = function(_PlayerID, _TechnologyType)
        GameCallback_OnTechnologyResearched_Orig_QSB_Bugfix(_PlayerID, _TechnologyType);
        QuestSystem.Bugfixes:UpdateFormation();
    end
end

function QuestSystem.Bugfixes:UpdateFormation()
    local EntityID = GUI.GetSelectedEntity();
    if QuestSystem.Bugfixes.UseFormation then
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
    end
end

function QuestSystem.Bugfixes:GetBlessDelayForPlayer(_PlayerID, _Button)
    local Last = QuestSystem.Bugfixes.BlessLimit[_Button][PlayerID] or 0;
    if Last == 0 then
        return 0;
    end
    return Last + QuestSystem.Bugfixes.BlessLimit.Limit - math.floor(Logic.GetTime());
end

