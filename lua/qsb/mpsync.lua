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
};

---
-- Installs the module.
-- @within MPSync
-- @local
--
function MPSync:Install()
    self:OverrideMessageReceived();
end

---
-- Creates an script event and returns the event ID. Use the ID to call the
-- created event.
-- @param[type=function] _Function Function to call
-- @param                ...       Optional parameters
-- @within MPSync
-- @see MPSync:SnchronizedCall
--
function MPSync:CreateScriptEvent(_Function, ...)
    self.UniqueActionCounter = self.UniqueActionCounter +1;
    local ActionIndex = self.UniqueActionCounter;

    self.ScriptEvents[ActionIndex] = {
        Function  = _Function,
        Arguments = copy(arg or {}),
    }
    return self.UniqueActionCounter;
end

---
-- Calls the script event synchronous for all players.
-- @param[type=number] _Function ID of script event
-- @within MPSync
-- @see MPSync:CreateScriptEvent
--
function MPSync:SnchronizedCall(_ID)
    local Msg = "___MPSync:" .._ID.. ";";
    if XNetwork ~= nil and XNetwork.Manager_DoesExist() == 1 then
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
    self.ScriptEvents[ActionID].Function(unpack(self.ScriptEvents[ActionID].Arguments));
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

-- MPSync:SnchronizedCall(TestAction1)