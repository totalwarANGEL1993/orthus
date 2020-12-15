-- ########################################################################## --
-- #  Game Speed (Extra 1/2)                                                # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module allows the player to change the game speed.
--
-- If the player should be unable to this feature can be deactivated.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.oop</li>
-- <li>qsb.core.questsync</li>
-- <li>qsb.core.questsystem</li>
-- </ul>
--
-- @set sort=true
--

QuestSystem.GameSpeedSwitch = {
    m_CurrentSpeed = 1,
    m_SpeedLimit = 3,
    m_SpeedUpAllowed = true,
}

-- -------------------------------------------------------------------------- --

---
-- Allows or forbid to use speedup. Speedup is enabled by default.
-- @param[type=boolean] _Flag Speedup is allowed
-- @within Methods
--
function GameSpeedSetAllowed(_Flag)
    QuestSystem.GameSpeedSwitch:SetSpeedUpAllowed(_Flag);
end

---
-- Sets the speed limit for speedup.
-- @param[type=number] _Limit Speed limit
-- @within Methods
--
function GameSpeedSetLimit(_Limit)
    QuestSystem.GameSpeedSwitch:SetSpeedLimit(_Limit);
end

-- -------------------------------------------------------------------------- --

---
-- Starts the speedup mod.
-- @within QuestSystem.GameSpeedSwitch
-- @local
--
function QuestSystem.GameSpeedSwitch:Install()
    -- Speed up is not allowed in multiplayer hence will not be started.
    if XNetwork.Manager_DoesExist() == 1 then
        return;
    end
    if not self.m_Installed then
        self.m_Installed = true;
        self:OnSaveGameLoaded();
        self:OverrideGUI();
        AddOnSaveLoadedAction(function()
            QuestSystem.GameSpeedSwitch:OnSaveGameLoaded()
        end);
    end
end

---
-- Increments the current speed by 1.
-- @within QuestSystem.GameSpeedSwitch
-- @local
--
function QuestSystem.GameSpeedSwitch:IncrementSpeed()
    if self.m_SpeedUpAllowed then
        self.m_CurrentSpeed = self.m_CurrentSpeed +1;
        if self.m_CurrentSpeed > self.m_SpeedLimit then
            self.m_CurrentSpeed = 1;
        end
        Game.GameTimeSetFactor(self.m_CurrentSpeed);
    end
end

---
-- Allows or forbid to use speedup. Speedup is enabled by default.
-- @param[type=boolean] _Flag Speedup is allowed
-- @within QuestSystem.GameSpeedSwitch
-- @local
--
function QuestSystem.GameSpeedSwitch:SetSpeedUpAllowed(_Flag)
    if _Flag == false then
        Game.GameTimeSetFactor(1);
        self.m_CurrentSpeed = 1;
    end
    self.m_SpeedUpAllowed = _Flag == true;
end

---
-- Sets the speed limit for speedup.
-- @param[type=number] _Limit Speed limit
-- @within QuestSystem.GameSpeedSwitch
-- @local
--
function QuestSystem.GameSpeedSwitch:SetSpeedLimit(_Limit)
    _Limit = (_Limit >= 1 and _Limit) or 1;
    if self.m_CurrentSpeed > _Limit then
        Game.GameTimeSetFactor(_Limit);
        self.m_CurrentSpeed = _Limit;
    end
    self.m_SpeedLimit = _Limit;
end

---
-- Overrrides the gui to implement speedup.
-- @within QuestSystem.GameSpeedSwitch
-- @local
--
function QuestSystem.GameSpeedSwitch:OverrideGUI()
    GUIAction_OnlineHelp = function()
        QuestSystem.GameSpeedSwitch:IncrementSpeed();
    end
    
    GameCallback_GameSpeedChanged = function(_Speed)
        if _Speed == 0 then
            XGUIEng.ShowWidget("PauseScreen",1);
        else
            XGUIEng.ShowWidget("PauseScreen",0);
            QuestSystem.GameSpeedSwitch.m_CurrentSpeed = _Speed;
        end
    end

    if not GUITooltip_Generic_Orig_GameSpeed then
        GUITooltip_Generic_Orig_GameSpeed = GUITooltip_Generic;
        GUITooltip_Generic = function(a)
            if a == "MenuMap/OnlineHelp" then
                local Language = (XNetworkUbiCom.Tool_GetCurrentLanguageShortName() == "de" and "de") or "en";
                local Text;
                if QuestSystem.GameSpeedSwitch.m_SpeedUpAllowed then
                    local Template = {
                        de = " @color:180,180,180 Spielgeschwindigkeit ändern @color:255,255,255 @cr Erhöht die Spielgeschwindigkeit bis zum Limit oder setzt sie zurück. @cr (Aktuell: %d / %d)",
                        en = "@color:180,180,180 Accelerate game @color:255,255,255 @cr Increases the game speed up to the limit or resets it back to normal. @cr (Current: %d / %d)"
                    };
                    Text = string.format(
                        Template[Language],
                        QuestSystem.GameSpeedSwitch.m_CurrentSpeed,
                        QuestSystem.GameSpeedSwitch.m_SpeedLimit
                    );
                else
                    local Template = {
                        de = " @color:180,180,180 Spielgeschwindigkeit ändern @color:255,255,255 @cr Spielgeschwindikeit kann nicht geändert werden!",
                        en = "@color:180,180,180 Accelerate game @color:255,255,255 @cr Game speed is locked and can not be changed!"
                    };
                    Text = Template[Language];
                end
                
                XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, Text);
                XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomCosts, "");
                XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomShortCut, "");
            else
                GUITooltip_Generic_Orig_GameSpeed(a);
            end
        end
    end
end

---
-- Restores the icon and the adjusted speed after a savegame is loaded.
-- @within QuestSystem.GameSpeedSwitch
-- @local
--
function QuestSystem.GameSpeedSwitch:OnSaveGameLoaded()
    -- Speed up is not allowed in multiplayer hence will not be loaded.
    -- (if a multiplayer game is somehow saved...)
    if XNetwork.Manager_DoesExist() == 1 then
        return;
    end
    XGUIEng.TransferMaterials("StatisticsWindowTimeScaleButton", "OnlineHelpButton" );
    XGUIEng.SetWidgetPositionAndSize("OnlineHelpButton",200,2,35,35);
    self:OverrideGUI();
    Game.GameTimeSetFactor(QuestSystem.GameSpeedSwitch.m_CurrentSpeed);
end

-- Callbacks ---------------------------------------------------------------- --

GameCallback_OnQuestSystemLoaded_Orig_GameSpeed = GameCallback_OnQuestSystemLoaded;
GameCallback_OnQuestSystemLoaded = function()
    GameCallback_OnQuestSystemLoaded_Orig_GameSpeed();
    QuestSystem.GameSpeedSwitch:Install();
end

