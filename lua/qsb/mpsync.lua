-- ########################################################################## --
-- #  MP Syncing                                                            # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module provides a simple synchronization for multiplayer maps.
--
-- Synchronization is done by creating an event that houses a function and
-- optional parameters. These Events can be fired to synchronize code called
-- from the GUI hence only by one player.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.oop</li>
-- </ul>
--
-- @set sort=true
--

MPSync = {
    ScriptEvents = {},
    UniqueActionCounter = 0,
    UniqueIdCounter = 0,
};

---
-- Installs the module.
-- @within MPSync
-- @local
--
function MPSync:Install()
    self:OverrideMessageReceived();

    self.ScriptEventNewIdRequested = MPSync:CreateScriptEvent(function()
        MPSync.UniqueIdCounter = MPSync.UniqueIdCounter +1;
    end);
end

---
-- Creates an script event and returns the event ID. Use the ID to call the
-- created event.
-- @param[type=function] _Function Function to call
-- @within MPSync
-- @see MPSync:SnchronizedCall
--
function MPSync:CreateScriptEvent(_Function)
    self.UniqueActionCounter = self.UniqueActionCounter +1;
    local ActionIndex = self.UniqueActionCounter;

    self.ScriptEvents[ActionIndex] = {
        Function  = _Function,
    }    
    return self.UniqueActionCounter;
end

---
-- Sends an event that will create an new ID on every machine and returns
-- the result.
-- @return[type=number] New synchronized ID
-- @within MPSync
-- @see MPSync:SnchronizedCall
--
function MPSync:RequestNewID()
    MPSync:SnchronizedCall(self.ScriptEventNewIdRequested);
    return self.UniqueActionCounter;
end

---
-- Calls the script event synchronous for all players.
-- @param[type=number] _Function ID of script event
-- @param              ...       List of Parameters (String or Number)
-- @within MPSync
-- @see MPSync:CreateScriptEvent
--
function MPSync:SnchronizedCall(_ID, ...)
    local Msg = "___MPSync:" .._ID.. ";";
    if arg and table.getn(arg) > 0 then
        for i= 1, table.getn(arg), 1 do
            Msg = Msg .. tostring(arg[i]) .. ";";
        end
    end
    if self:IsMultiplayerGame() then
        XNetwork.Chat_SendMessageToAll(Msg);
        return;
    end
    MPGame_ApplicationCallback_ReceivedChatMessage(Msg, 1, GUI.GetPlayerID());
end

---
-- Parses the action to call from the synchronization message.
-- @param[type=string] _Message Synchronization message
-- @within MPSync
-- @local
--
function MPSync:SyncronizeMessageReceived(_Message)
    local s1, e1 = string.find(_Message, ":");
    local s2, e2 = string.find(_Message, ";");
    if not e1 or not e2 then
        return;
    end
    local ActionID = tonumber(string.sub(_Message, e1+1, e2-1));
    if not ActionID then
        return;
    end
    local Parameter = self:GetParameterFromSyncronizeMessage(string.sub(_Message, e2+1));
    self.ScriptEvents[ActionID].Function(unpack(Parameter));
end

---
-- Gets the parameters from the input string and returns them.
-- @param[type=string] _String Parameter string
-- @return[type=table] Parameter
-- @within MPSync
-- @local
--
function MPSync:GetParameterFromSyncronizeMessage(_String)
    local String = _String;
    local Parameter = {};
    while string.len(String) > 1 do
        local s, e = string.find(String, ";");
        local Part = string.sub(String, 1, e-1);
        local PartNumber = tonumber(Part);
        table.insert(Parameter, (PartNumber ~= nil and PartNumber) or Part);
        String = string.sub(String, e+1);
    end
    return Parameter;
end

---
-- Overrides the internal message callback.
-- @within MPSync
-- @local
--
function MPSync:OverrideMessageReceived()
    if self.IsActive then
        return true;
    end
    self.IsActive = true;

    MPGame_ApplicationCallback_ReceivedChatMessage_Orig_MPSync = MPGame_ApplicationCallback_ReceivedChatMessage
    MPGame_ApplicationCallback_ReceivedChatMessage = function(_Message, _AlliedOnly, _SenderPlayerID)
        if string.find(_Message, "^___MPSync") then
            MPSync:SyncronizeMessageReceived(_Message);
            return;
        end
        MPGame_ApplicationCallback_ReceivedChatMessage_Orig_MPSync(_Message, _AlliedOnly, _SenderPlayerID);
    end
end

---
-- Checks if the current mission is running as a Multiplayer game.
-- @return[type=boolean] Mission runs in multiplayer
-- @within MPSync
-- @local
--
function MPSync:IsMultiplayerGame()
    return XNetwork.Manager_DoesExist() == 1;
end

---
-- Returns true, if the copy of the game is the History Edition.
-- @return[type=boolean] Game is History Edition
-- @within MPSync
-- @local
--
function MPSync:IsHistoryEdition()
    return XNetwork.Manager_IsNATReady ~= nil;
end

---
-- Returns true, if the copy of the game is the Community Edition.
-- (e.g. Kimichuras Community Server)
-- @return[type=boolean] Game is Community Edition
-- @within MPSync
-- @local
--
function MPSync:IsCommunityEdition()
    return CNetwork ~= nil;
end

---
-- Returns true, if the copy of the game is the original version.
-- @return[type=boolean] Game is Original Edition
-- @within MPSync
-- @local
--
function MPSync:IsOriginal()
    return not self:IsHistoryEdition() and not self:IsCommunityEdition();
end

---
-- Returns true, if the game is properly patched to version 1.06.0217. If the
-- copy of the game is not the original than it is assumed that the game has
-- been patched.
-- @return[type=boolean] Game has latest patch
-- @within MPSync
-- @local
--
function MPSync:IsPatched()
    if not self:IsOriginal() then
        return true;
    end
    return string.find(Framework.GetProgramVersion(), "1.06.0217") ~= nil;
end

---
-- Returns the number of human players. In Singleplayer this will always be 1.
-- @return[type=number] Amount of humans
-- @within MPSync
-- @local
--
function MPSync:GetActivePlayers()
    local Players = {};
    if self:IsMultiplayerGame() then
        -- TODO: Does that fix everything for Community Server?
        for i= 1, table.getn(Score.Player), 1 do
            if  XNetwork.GameInformation_IsHumanPlayerAttachedToPlayerID(i)
            and Logic.PlayerGetGameState(i) == 1 then
                table.insert(Players, i);
            end
        end
    else
        table.insert(Players, GUI.GetPlayerID());
    end
    return Players;
end

