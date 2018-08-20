-- ########################################################################## --
-- #  Interaction                                                           # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- Implements a npc system that can be run seperatly to the vanilla npc system.
-- Normal npcs can be configured just as the vanilla npcs. To create a normal
-- npc use the following:
-- <pre>local NPC = new(NonPlayerCharacter, "myNPC")
--     :SetCallback(SomeFunction)
--     :Activate();</pre>
--
-- The system also allows to create special traders based of the merchant
-- widget. Units, resources and custom actions can be traded and all offers
-- can respawn. Example for a merchant:
-- <pre>local NPC = new(NonPlayerMerchant, "myMerchant")
--     :AddResourceOffer(ResourceType.Clay, 300, {Gold = 150}, 15, 2*60);
--     :Activate();</pre>
-- This merchant sells 15x300 clay for 150 gold each. After 2 minutes the
-- offer is restored by 1.
--
-- Normal settlers can either be npcs or merchants!
--
-- @set sort=true
--

Interaction = {
    IO = {},
}

---
-- Installs the interaction mod.
--
function Interaction:Install()
    NPCTable_Heroes = {};
    NPCTable_Heroes.LastUpdate = 0;

    self:OverrideNpcInteraction();
    self:OverrideMerchantOffers();
    self:OverrideBriefing();
end

---
-- Overrides the npc interaction callback.
-- @within Interaction
-- @local
--
function Interaction:OverrideNpcInteraction()
    GameCallback_NPCInteraction_Orig_Interaction = GameCallback_NPCInteraction;
    GameCallback_NPCInteraction = function(_Hero, _NPC)
        if IsBriefingActive() then
            return;
        end

        Interaction.LastInteractionHero = _Hero;
        Interaction.LastInteractionNpc = _NPC;
        
        local EntityName = Logic.GetEntityName(_NPC);
        local ID = Logic.GetMerchantBuildingId(_NPC);

        if ID ~= 0 then
            EntityName = Logic.GetEntityName(ID);
            if EntityName and Interaction.IO[EntityName] then
                Interaction:OnMerchantInteraction(_Hero, Interaction.IO[EntityName], ID);
                return;
            end
        end

        if EntityName and Interaction.IO[EntityName] then
            if Interaction.IO[EntityName].m_Merchant then
                Interaction:OnMerchantInteraction(_Hero, Interaction.IO[EntityName], _NPC);
            else
                Interaction:OnNpcInteraction(_Hero, Interaction.IO[EntityName]);
            end
            return;
        end
        GameCallback_NPCInteraction_Orig_Interaction(_Hero, _Hero);
    end
end

---
-- Overrides starting methods of briefing and cutscene to avoid the access
-- violation when merchant is shown at cinematic start.
-- @within Interaction
-- @local
--
function Interaction:OverrideBriefing()
    StartBriefing_Orig_Interaction = StartBriefing;
    StartBriefing = function(_briefing)
        GUIAction_MerchantReady();
        return StartBriefing_Orig_Interaction(_briefing);
    end

    if StartCutscene then 
        StartCutscene_Orig_Interaction = StartCutscene;
        StartCutscene = function(_Cutscene, _EscapeMode)
            GUIAction_MerchantReady();
            return StartCutscene_Orig_Interaction(_Cutscene, _EscapeMode);
        end
    end
end

---
-- Overrides the troop merchant functions.
-- @within Interaction
-- @local
--
function Interaction:OverrideMerchantOffers()
    GUIUpdate_MerchantOffers_Orig_Interaction = GUIUpdate_MerchantOffers;
    GUIUpdate_MerchantOffers = function(_WidgetTable)
        local CurrentWitgetID = XGUIEng.GetCurrentWidgetID();
        local MerchantID = Logic.GetMerchantBuildingId(Interaction.LastInteractionNpc);
        local ScriptName = Logic.GetEntityName(MerchantID);
        if MerchantID == 0 then
            ScriptName = Logic.GetEntityName(Interaction.LastInteractionNpc);
        end

        if ScriptName and Interaction.IO[ScriptName] and Interaction.IO[ScriptName].m_Merchant then
            Interaction.IO[ScriptName]:UpdateOfferWidgets();
        else
            GUIUpdate_MerchantOffers_Orig_Interaction(_WidgetTable);
        end
    end

    GUIUpdate_TroopOffer_Orig_Interaction = GUIUpdate_TroopOffer;
    GUIUpdate_TroopOffer = function(_SlotIndex)
        local MerchantID = Logic.GetMerchantBuildingId(Interaction.LastInteractionNpc);
        local ScriptName = Logic.GetEntityName(MerchantID);
        if MerchantID == 0 then
            ScriptName = Logic.GetEntityName(Interaction.LastInteractionNpc);
        end

        if ScriptName and Interaction.IO[ScriptName] and Interaction.IO[ScriptName].m_Merchant then
            if Interaction.IO[ScriptName].m_Active then
                Interaction.IO[ScriptName]:UpdateOffer(_SlotIndex);
            end
        else
            GUIUpdate_TroopOffer_Orig_Interaction(_SlotIndex);
        end
    end

    GUIAction_BuyMerchantOffer_Orig_Interaction = GUIAction_BuyMerchantOffer;
    GUIAction_BuyMerchantOffer = function(_SlotIndex)
        local MerchantID = Logic.GetMerchantBuildingId(Interaction.LastInteractionNpc);
        local ScriptName = Logic.GetEntityName(MerchantID);
        if MerchantID == 0 then
            ScriptName = Logic.GetEntityName(Interaction.LastInteractionNpc);
        end

        if ScriptName and Interaction.IO[ScriptName] and Interaction.IO[ScriptName].m_Merchant then
            Interaction.IO[ScriptName]:BuyOffer(_SlotIndex);
        else
            GUIAction_BuyMerchantOffer_Orig_Interaction(_SlotIndex);
        end
    end

    GUITooltip_TroopOffer_Orig_Interaction = GUITooltip_TroopOffer;
    GUITooltip_TroopOffer = function(_SlotIndex)
        local MerchantID = Logic.GetMerchantBuildingId(Interaction.LastInteractionNpc);
        local ScriptName = Logic.GetEntityName(MerchantID);
        if MerchantID == 0 then
            ScriptName = Logic.GetEntityName(Interaction.LastInteractionNpc);
        end

        if ScriptName and Interaction.IO[ScriptName] and Interaction.IO[ScriptName].m_Merchant then
            Interaction.IO[ScriptName]:TooltipOffer(_SlotIndex);
        else
            GUITooltip_TroopOffer_Orig_Interaction(_SlotIndex);
        end
    end
end

---
-- Function called when a hero speaks to a normal npc.
-- @param _Hero [number] Entity id of hero
-- @param _NpcInstance [table] Instance of npc
-- @within Interaction
-- @local
--
function Interaction:OnNpcInteraction(_Hero, _NpcInstance)
    if not _NpcInstance then 
        return;
    end
    _NpcInstance:Interact(_Hero);
end

---
-- Function called when a hero speaks to a merchant npc.
-- @param _Hero [number] Entity id of hero
-- @param _NpcInstance [table] Instance of npc
-- @param _MerchantID [number] EntityID of merchant
-- @within Interaction
-- @local
--
function Interaction:OnMerchantInteraction(_Hero, _NpcInstance, _MerchantID)
    if not _NpcInstance then 
        return;
    end
    _NpcInstance:Interact(_Hero, _MerchantID);
end

-- -------------------------------------------------------------------------- --

---
-- Calls the controller method of the npc instance.
-- @param _ScriptName [string] Script name of NPC
-- @local
--
function Interaction_Npc_Controller(_ScriptName)
    if not Interaction.IO[_ScriptName] and not IsDead(_ScriptName) then 
        return true;
    end
    return Interaction.IO[_ScriptName]:Controller();
end

-- -------------------------------------------------------------------------- --

NPC_ARRIVED_DISTANCE = 1200;

---
-- Base class for NPCs that implements the vanilla functionality of an npc.
--
-- @within Classes
--
NonPlayerCharacter = {}
function NonPlayerCharacter:construct(_ScriptName)
    self.m_ScriptName  = _ScriptName;
    self.m_Callback    = function() end;
    self.m_Active      = false;
    -- optional
    self.m_VanishPos   = nil;
    self.m_Hero        = nil;
    self.m_HeroInfo    = nil;
    self.m_Follow      = nil;
    self.m_Target      = nil;
    self.m_WayCallback = nil;
    self.m_Waypoints   = {};

    Interaction.IO[_ScriptName] = self;
    Trigger.RequestTrigger(
        Events.LOGIC_EVENT_EVERY_SECOND,
        "",
        "Interaction_Npc_Controller",
        1,
        {},
        {_ScriptName}
    );
end
class(NonPlayerCharacter);

---
-- Sets the hero this npc is following. To let him follow anybody set hero
-- as true.
-- @param _Hero [string|boolean] Hero to follow
-- @return self
-- @within NonPlayerCharacter
--
function NonPlayerCharacter:SetFollow(_Hero)
    self.m_Follow = _Hero;
    return self;
end

---
-- Adds a waypoint to the npc. The npc will move over every waypoint to the
-- destination. The last waypoint is used as destination.
-- Waypoints must be reachable!
-- @param _Waypoint [string] Waypoint to pass
-- @return self
-- @within NonPlayerCharacter
--
function NonPlayerCharacter:AddWaypoint(_Waypoint)
    table.insert(self.m_Waypoints, _Waypoint);
    return self;
end

---
-- Overwrites the default waittime between two waypoints.
-- @param _Waittime [number] time to wait
-- @return self
-- @within NonPlayerCharacter
--
function NonPlayerCharacter:SetWaittime(_Waittime)
    table.insert(self.m_Waittime, _Waittime);
    return self;
end

---
-- Sets a talking callback for the npc.
-- @param _Callback [function] Function to call
-- @return self
-- @within NonPlayerCharacter
--
function NonPlayerCharacter:SetCallback(_Callback)
    self.m_Callback = _Callback;
    return self;
end

---
-- Sets a target destination until the npc is following the hero.
-- Must be reachable!
-- @param _Target [string] Destination of npc
-- @return self
-- @within NonPlayerCharacter
--
function NonPlayerCharacter:SetTarget(_Target)
    self.m_Target = _Target;
    return self;
end

---
-- Sets an alternate callback that will be triggered when the npc is on his
-- way to a destination.
-- @param _Callback [function] Function to call
-- @return self
-- @within NonPlayerCharacter
--
function NonPlayerCharacter:SetWayCallback(_Callback)
    self.m_WayCallback = _Callback;
    return self;
end

---
-- Activates the NPC
-- @return self
-- @within NonPlayerCharacter
--
function NonPlayerCharacter:Activate()
    local ID = GetID(self.m_ScriptName);
    if Logic.IsSettler(ID) == 1 then
        Logic.SetOnScreenInformation(ID, 1);
        if self.m_Waypoints then
            self.m_Waypoints.Current = false;
        end
        self.m_Active = true;
        self.m_Arrived = false;
        self.m_TalkedTo = nil;
    end
    return self;
end

---
-- Deactivates the NPC.
-- @return self
-- @within NonPlayerCharacter
--
function NonPlayerCharacter:Deactivate()
    local ID = GetID(self.m_ScriptName);
    if Logic.IsSettler(ID) == 1 then
        Logic.SetOnScreenInformation(ID, 0);
        self.m_Active = false;
    end
    return self;
end

---
-- Checks, if some hero talked to this npc.
-- @return [boolean] Talked to
-- @within NonPlayerCharacter
--
function NonPlayerCharacter:TalkedTo()
    return self.m_TalkedTo ~= nil;
end

---
-- Sets the hero that can speak to the npc.
-- @param _Hero [string] Scriptname of hero
-- @return self
-- @within NonPlayerCharacter
--
function NonPlayerCharacter:SetHero(_Hero)
    self.m_Hero = _Hero;
    return self;
end

---
-- Sets the information text, if the wrong hero talked to the npc
-- @param _Info [string] Info message
-- @return self
-- @within NonPlayerCharacter
--
function NonPlayerCharacter:SetHeroInfo(_Info)
    self.m_HeroInfo = _Info;
    return self;
end

---
-- Controlls the actions of a vanilla NPC if it is active.
-- @within NonPlayerCharacter
-- @local
--
function NonPlayerCharacter:Controller()
    if self.m_Active == true then
        UpdateHeroesTable();

        -- Follow hero
        if self.m_Follow ~= nil and not self.m_Arrived then
            local FollowID;
            if type(self.m_Follow) == "string" then
                FollowID = GetEntityId(self.m_Follow);
            else
                FollowID = GetNearestHero(self.m_ScriptName, 2000);
            end
            if FollowID ~= nil and IsAlive(FollowID) then
                if self.m_Target and IsNear(self.m_ScriptName, self.m_Target, self.m_ArrivedDistance or NPC_ARRIVED_DISTANCE) then
                    Move(self.m_ScriptName, self.m_Target);
                    self.m_Arrived = true;
                end
                if Logic.IsEntityMoving(GetID(self.m_ScriptName)) == false then
                    Move(self.m_ScriptName, FollowID, 500);
                end
            end

        -- Walk a path
        elseif table.getn(self.m_Waypoints) > 0 and not self.m_Arrived then
            self.m_Waypoints.LastTime = self.m_Waypoints.LastTime or 0;
            self.m_Waypoints.Current = self.m_Waypoints.Current or 1;

            local CurrentTime = Logic.GetTime();
            local x, y, z = Logic.EntityGetPos(GetID(self.m_ScriptName));
            if self.m_Waypoints.LastTime < CurrentTime then
                -- Check each 2 minutes
                self.m_Waypoints.LastTime = CurrentTime + (self.m_Waittime or 2*60);
                -- Set waypoint
                if IsNear(self.m_ScriptName, self.m_Waypoints[self.m_Waypoints.Current], self.m_ArrivedDistance or NPC_ARRIVED_DISTANCE) then
                    self.m_Waypoints.Current = self.m_Waypoints.Current +1;
                    if self.m_Waypoints.Current > table.getn(self.m_Waypoints) then
                        self.m_Arrived = true;
                    end
                end
                -- Move to waypoint
                if not self.m_Arrived then
                    if Logic.IsEntityMoving(GetID(self.m_ScriptName)) == false then
                        Move(self.m_ScriptName, self.m_Waypoints[self.m_Waypoints.Current]);
                    end
                end
            end
        else
            self.m_Arrived = true;
        end

        if self.m_Arrived then
            local NearestHero = GetNearestHero(self.m_ScriptName);
            LookAt(self.m_ScriptName, NearestHero);
        end
    end
end

---
-- Controlls how the NPC interacts with the hero if spoken to.
-- @param _HeroID [number] ID of hero
-- @within NonPlayerCharacter
-- @local
--
function NonPlayerCharacter:Interact(_HeroID)
    GUIAction_MerchantReady();
    if self.m_Follow then 
        if self.m_Target then
            if IsNear(self.m_ScriptName, self.m_Target, 1200) then
                self.m_Callback(self, _HeroID);
                self.m_TalkedTo = _HeroID;
                self:HeroesLookAtNpc();
                self:Deactivate();
            else
                if self.m_WayCallback then 
                    self.m_WayCallback(self, _HeroID);
                end
            end
        else
            if self.m_WayCallback then 
                self.m_WayCallback(self, _HeroID);
            end
        end

    elseif table.getn(self.m_Waypoints) > 0 then
        local LastWaypoint = self.m_Waypoints[table.getn(self.m_Waypoints)];
        if IsNear(self.m_ScriptName, LastWaypoint, 1200) then
            self.m_Callback(self, _HeroID);
            self.m_TalkedTo = _HeroID;
            self:HeroesLookAtNpc();
            self:Deactivate();
        else
            if self.m_WayCallback then 
                self.m_WayCallback(self, _HeroID);
            end
        end

    else
        if self.m_Hero then
            if _HeroID ~= GetID(self.m_Hero) then
                if self.m_HeroInfo then 
                    Message(self.m_HeroInfo);
                end
                return;
            end
        end
        self.m_Callback(self, _HeroID);
        self.m_TalkedTo = _HeroID;
        self:HeroesLookAtNpc();
        self:Deactivate();
    end
end

---
-- Let all heroes of the player look at the npc.
-- @within NonPlayerCharacter
-- @local
--
function NonPlayerCharacter:HeroesLookAtNpc()
    for k, v in pairs(NPCTable_Heroes) do 
        if v and IsExisting(v) and IsNear(v, self.m_ScriptName, 2000) then
            LookAt(v, self.m_ScriptName);
        end
    end
end

-- -------------------------------------------------------------------------- --

MerchantOfferTypes = {
    Unit = 1,
    Custom = 3,
    Resource = 4,
}

---
-- Base class for NPCs that implements the vanilla functionality of an npc.
-- @param _ScriptName [string] Script name of merchant
-- @within Classes
--
NonPlayerMerchant = {}
function NonPlayerMerchant:construct(_ScriptName)
    self.m_ScriptName = _ScriptName;
    self.m_Spawnpoint = nil;
    self.m_Merchant   = true;
    self.m_Offers     = {};

    Logic.AddMercenaryOffer(GetID(_ScriptName), Entities.CU_Barbarian_LeaderClub1, 1, ResourceType.Gold, 1);

    Interaction.IO[_ScriptName] = self;
    Trigger.RequestTrigger(
        Events.LOGIC_EVENT_EVERY_SECOND,
        "",
        "Interaction_Npc_Controller",
        1,
        {},
        {_ScriptName}
    );
end
class(NonPlayerMerchant);

---
-- Sets a different spawnpoint for units bought at the merchant.
-- @param _Spawnpoint [string] Script name of spawnpoint.
-- @return self
-- @within NonPlayerMerchant
--
function NonPlayerMerchant:SetSpawnpoint(_Spawnpoint)
    self.m_Spawnpoint = _Spawnpoint;
    return self;
end

---
-- Activates the merchant if it is not a vanilla merchant.
-- @return self
-- @within NonPlayerMerchant
--
function NonPlayerMerchant:Activate()
    local ID = GetID(self.m_ScriptName);
    if Logic.IsSettler(ID) == 1 then
        Logic.SetOnScreenInformation(ID, 1);
    end
    self.m_Active = true;
    return self;
end

---
-- Deactivates the merchant if it is not a vanilla merchant.
-- @return self
-- @within NonPlayerMerchant
--
function NonPlayerMerchant:Deactivate()
    local ID = GetID(self.m_ScriptName);
    if Logic.IsSettler(ID) == 1 then
        Logic.SetOnScreenInformation(ID, 0);
    end
    GUIAction_MerchantReady();
    self.m_Active = false;
    return self;
end

---
-- Calls the merchant menu of the merchant if a hero talks to him.
-- @param _HeroID [number] ID of hero
-- @param _TraderID [number] ID of merchant
-- @within NonPlayerMerchant
-- @local
--
function NonPlayerMerchant:Interact(_HeroID, _TraderID)
    local CurrentPlayerID = GUI.GetPlayerID();
    local HeroOfPlayerID = Logic.EntityGetPlayer(_HeroID);
    
    if HeroOfPlayerID == CurrentPlayerID then
        GUI.SelectEntity(_HeroID);
        XGUIEng.ShowAllSubWidgets(gvGUI_WidgetID.SelectionView, 0);
        XGUIEng.ShowWidget(gvGUI_WidgetID.SelectionGeneric, 1);
        XGUIEng.ShowWidget(gvGUI_WidgetID.BackgroundFull, 1);
        XGUIEng.ShowAllSubWidgets(gvGUI_WidgetID.SelectionBuilding, 0);
        XGUIEng.ShowWidget(gvGUI_WidgetID.SelectionBuilding, 1);
        XGUIEng.ShowWidget(gvGUI_WidgetID.TroopMerchant, 1);
        self:UpdateOfferWidgets();
    end
end

---
-- Controlls the refreshing rate of the merchant offers.
-- @within NonPlayerMerchant
-- @local
--
function NonPlayerMerchant:Controller()
    for k, v in pairs(self.m_Offers) do 
        if v and v.Refresh > -1 then
            self.m_Offers[k].LastRefresh = v.LastRefresh or Logic.GetTime();
            if Logic.GetTime() > v.LastRefresh + v.Refresh then 
                -- Update load
                if self.m_Offers[k].Load < self.m_Offers[k].LoadMax then
                    self.m_Offers[k].Load = v.Load +1;
                end
                -- Update inflation
                self.m_Offers[k].Inflation = self.m_Offers[k].Inflation - 0.05;
                if self.m_Offers[k].Inflation < 0.75 then
                    self.m_Offers[k].Inflation = 0.75;
                end
                -- Delete refresh time
                self.m_Offers[k].LastRefresh = nil;
            end
        end
    end
end

---
-- Returns how often the offer at the index was accepted by the player.
-- @param _SlotIndex [number] Index of offer
-- @return [number] Trading volume
-- @within NonPlayerMerchant
--
function NonPlayerMerchant:GetTradingVolume(_SlotIndex)
    if self.m_Offers[_SlotIndex] then
        return self.m_Offers[_SlotIndex].Volume;
    end
    return 0;
end

---
-- DONT EVER CALL THIS MANUALLY! Adds a offer to the merchant.
-- @param _Type [number] Type of offer
-- @param _Costs [table] Costs table
-- @param _Amount [number] Amount buyed units
-- @param _Good [number] Entity or leader type
-- @param _Load [number] Amount of wagon loads
-- @param _Icon [string] Button icon
-- @param _Refresh [number] Refresh rate
-- @param _Description [table] Button description
-- @return self
-- @within NonPlayerMerchant
-- @local
--
function NonPlayerMerchant:AddOffer(_Type, _Costs, _Amount, _Good, _Load, _Icon, _Refresh, _Description)
    local CostsTable = {
        [ResourceType.Gold]   = _Costs.Gold or 0,
        [ResourceType.Clay]   = _Costs.Clay or 0,
        [ResourceType.Wood]   = _Costs.Wood or 0,
        [ResourceType.Stone]  = _Costs.Stone or 0,
        [ResourceType.Iron]   = _Costs.Iron or 0,
        [ResourceType.Sulfur] = _Costs.Sulfur or 0,
        [ResourceType.Silver] = 0,
    };

    local Length = table.getn(self.m_Offers);
    if Length < 4 then 
        self.m_Offers[Length+1] = {
            Type = _Type,
            Costs = CostsTable,
            Amount = _Amount,
            Good = _Good,
            Load = _Load, 
            LoadMax = _Load, 
            Icon = _Icon, 
            Refresh = _Refresh or -1,
            Inflation = 1.0,
            Volume = 0,
            Description = _Description
        };
    end
    return self;
end

---
-- Adds a troop offer to the merchant.
-- @param _Good [number] Entity or leader type
-- @param _Costs [table] Costs table
-- @param _Amount [number] Amount of offers
-- @param _Refresh [number] Refresh rate
-- @return self
-- @within NonPlayerMerchant
--
function NonPlayerMerchant:AddTroopOffer(_Good, _Costs, _Amount, _Refresh)
    -- Get icon
    local Icon = "Buy_LeaderSword";
    if Logic.IsEntityTypeInCategory(_Good, EntityCategories.Bow) == 1 then
		Icon = "Buy_LeaderBow";
	elseif Logic.IsEntityTypeInCategory(_Good, EntityCategories.Spear)== 1 then
		Icon = "Buy_LeaderSpear";
	elseif Logic.IsEntityTypeInCategory(_Good, EntityCategories.CavalryHeavy)== 1 then
		Icon = "Buy_LeaderCavalryHeavy";
	elseif Logic.IsEntityTypeInCategory(_Good, EntityCategories.CavalryLight) == 1 then
		Icon = "Buy_LeaderCavalryLight";
	elseif Logic.IsEntityTypeInCategory(_Good, EntityCategories.Rifle) == 1 then	
		Icon = "Buy_LeaderRifle";		
	elseif _Good == Entities.PV_Cannon1 then	
		Icon = "Buy_Cannon1";		
	elseif _Good == Entities.PV_Cannon2 then	
		Icon = "Buy_Cannon2";		
	elseif _Good == Entities.PV_Cannon3 then	
		Icon = "Buy_Cannon3";		
	elseif _Good == Entities.PV_Cannon4 then	
		Icon = "Buy_Cannon4";		
	elseif _Good == Entities.PU_Serf then
		Icon = "Buy_Serf";
	elseif _Good == Entities.PU_Thief then
		Icon = "Buy_Thief";				
	elseif _Good == Entities.PU_Scout then
        Icon = "Buy_Scout";
    end
    -- Add offer
    return self:AddOffer(MerchantOfferTypes.Unit, _Costs, 0, _Good, _Amount, Icon, _Refresh or -1);
end

---
-- Adds a resource offer to the merchant. Raw resources are not supported!
-- @param _Good [number] Resource type
-- @param _Amount [number] Amount of resource
-- @param _Costs [table] Costs table
-- @param _Load [number] Amount of offers
-- @param _Refresh [number] Refresh rate
-- @return self
-- @within NonPlayerMerchant
--
function NonPlayerMerchant:AddResourceOffer(_Good, _Amount, _Costs, _Load, _Refresh)
    -- Get icon
    local Icon = "Statistics_SubResources_Money";
    if _Good == ResourceType.Clay or _Good == ResourceType.ClayRaw then
        Icon = "Statistics_SubResources_Clay";
    elseif _Good == ResourceType.Wood or _Good == ResourceType.WoodRaw then
        Icon = "Statistics_SubResources_Wood";
    elseif _Good == ResourceType.Stone or _Good == ResourceType.StoneRaw then
        Icon = "Statistics_SubResources_Stone";
    elseif _Good == ResourceType.Iron or _Good == ResourceType.IronRaw then
        Icon = "Statistics_SubResources_Iron";
    elseif _Good == ResourceType.Sulfur or _Good == ResourceType.SulfurRaw then
        Icon = "Statistics_SubResources_Sulphur";
    end
    -- Add offer
    return self:AddOffer(MerchantOfferTypes.Resource, _Costs, _Amount, _Good, _Load, Icon, _Refresh or -1);
end

---
-- Adds an offer with a custom function. The function receives the data of
-- the offer and the data of the whole npc.
-- @param _Action [function] Custom function
-- @param _Amount [number] Amount of offers
-- @param _Costs [table] Costs table
-- @param _Icon [string] Icon texture
-- @param _Description [table] Tooltip content
-- @param _Refresh [number] Refresh rate
-- @return self
-- @within NonPlayerMerchant
-- @usage Merchant:AddCustomOffer(SomeFunction, 5, {Gold = 340}, {Title = "Titel", Text = "Das ist die Beschreibung."});
--
function NonPlayerMerchant:AddCustomOffer(_Action, _Amount, _Costs, _Icon, _Description, _Refresh)
    return self:AddOffer(MerchantOfferTypes.Custom, _Costs, 0, _Action, _Amount, _Icon, _Refresh or -1, _Description);
end

---
-- Updates all merchant offer widgets.
-- @param _WidgetTable [table] Offer widget table
-- @within NonPlayerMerchant
-- @local
--
function NonPlayerMerchant:UpdateOfferWidgets()  
    XGUIEng.ShowAllSubWidgets("TroopMerchantOffersContainer", 0);
    for k, v in pairs (self.m_Offers) do
        XGUIEng.ShowWidget("BuyTroopOfferContainer" ..k, 1);
        XGUIEng.ShowWidget("Amount_TroopOffer" ..k, 1);
        XGUIEng.ShowWidget("Buy_TroopOffer" ..k, 1);
    end
end

---
-- Updates the merchant offer at the index.
-- @param _SlotIndex [number] Index of offer
-- @within NonPlayerMerchant
-- @local
--
function NonPlayerMerchant:UpdateOffer(_SlotIndex)
    local EntityID = GUI.GetSelectedEntity();
    if not IsExisting(EntityID) or string.find(Logic.GetCurrentTaskList(EntityID), "WALK") then
        GUIAction_MerchantReady();
        return;
    end
    
    local CurrentWidgetID = XGUIEng.GetCurrentWidgetID();
    local AmountOfOffers = table.getn(self.m_Offers);
    local SourceButton = self.m_Offers[_SlotIndex].Icon;
    XGUIEng.TransferMaterials(SourceButton, CurrentWidgetID);

    local Amount = self.m_Offers[_SlotIndex].Load;
    if Amount < 1 then
        Amount = "";
        XGUIEng.DisableButton(CurrentWidgetID, 1);
    else
        XGUIEng.DisableButton(CurrentWidgetID, 0);
    end
    XGUIEng.SetText(gvGUI_WidgetID.TroopMerchantOfferAmount[_SlotIndex], "@center " ..Amount);
end

---
-- Executes the purchase of the player if there are enough resources.
-- @param _SlotIndex [number] Index of offer
-- @within NonPlayerMerchant
-- @local
--
function NonPlayerMerchant:BuyOffer(_SlotIndex)
    local Costs = copy(self.m_Offers[_SlotIndex].Costs);
    for k, v in pairs(Costs) do
        Costs[k] = math.ceil(v * self.m_Offers[_SlotIndex].Inflation);
    end

    if InterfaceTool_HasPlayerEnoughResources_Feedback(Costs) == 1 then
        local PlayerID = GUI.GetPlayerID();
        if self.m_Offers[_SlotIndex].Type == MerchantOfferTypes.Unit then
            if Logic.GetPlayerAttractionUsage(PlayerID) >= Logic.GetPlayerAttractionLimit(PlayerID) then
                GUI.SendPopulationLimitReachedFeedbackEvent(PlayerID);
                return;
            end
        end

        -- Remove costs
        for k, v in pairs(Costs) do 
            Logic.SubFromPlayersGlobalResource(PlayerID, k, v);
        end

        -- Add trading volume
        self.m_Offers[_SlotIndex].Volume = self.m_Offers[_SlotIndex].Volume +1;
        -- Remove load
        self.m_Offers[_SlotIndex].Load = self.m_Offers[_SlotIndex].Load -1;

        -- Handle inflation
        self.m_Offers[_SlotIndex].Inflation = self.m_Offers[_SlotIndex].Inflation + 0.05;
        if self.m_Offers[_SlotIndex].Inflation > 1.75 then
            self.m_Offers[_SlotIndex].Inflation = 1.75;
        end

        -- Mercenary
        if self.m_Offers[_SlotIndex].Type == MerchantOfferTypes.Unit then
            local Position = GetPosition(self.m_ScriptName);
            if self.m_Spawnpoint then
                Position = GetPosition(self.m_Spawnpoint);
            else
                Position = GetPosition(self.m_ScriptName);
            end
            local ID = AI.Entity_CreateFormation(PlayerID, self.m_Offers[_SlotIndex].Good, 0, 0, Position.X, Position.Y, 0, 0, 3, 0);
            Tools.CreateSoldiersForLeader(ID, 16);
        -- Resource
        elseif self.m_Offers[_SlotIndex].Type == MerchantOfferTypes.Resource then
            Logic.AddToPlayersGlobalResource(PlayerID, self.m_Offers[_SlotIndex].Good +1, self.m_Offers[_SlotIndex].Amount);
        -- Custom
        else
            self.m_Offers[_SlotIndex].Good(self.m_Offers[_SlotIndex], self);
        end
        
        GUIUpdate_TroopOffer(_SlotIndex);
    end
end

---
-- Prints the tooltip text for a merchant offer.
-- @param _SlotIndex [number] Index of offer
-- @within NonPlayerMerchant
-- @local
--
function NonPlayerMerchant:TooltipOffer(_SlotIndex)
    local Costs = copy(self.m_Offers[_SlotIndex].Costs);
    for k, v in pairs(Costs) do
        Costs[k] = math.ceil(v * self.m_Offers[_SlotIndex].Inflation);
    end

    local CostString = InterfaceTool_CreateCostString(Costs);
    local Language = (XNetworkUbiCom.Tool_GetCurrentLanguageShortName() == "de" and "de") or "en";
    local Description;
    
    -- Mercenary
    if self.m_Offers[_SlotIndex].Type == MerchantOfferTypes.Unit then
        local EntityTypeName = Logic.GetEntityTypeName(self.m_Offers[_SlotIndex].Good);
        if EntityTypeName == nil then
            return;
        end
        local NameString = "names/" .. EntityTypeName
        Description = " @color:180,180,180,255 " .. XGUIEng.GetStringTableText(NameString) .. " @cr ";
        Description = Description .. XGUIEng.GetStringTableText("MenuMerchant/TroopOfferTooltipText");
    
    -- Resource
    elseif self.m_Offers[_SlotIndex].Type == MerchantOfferTypes.Resource then
        local GoodName = XGUIEng.GetStringTableText("InGameMessages/GUI_NameMoney");
        if self.m_Offers[_SlotIndex].Good == ResourceType.Clay or self.m_Offers[_SlotIndex].Good == ResourceType.ClayRaw then
            GoodName = XGUIEng.GetStringTableText("InGameMessages/GUI_NameClay");
        elseif self.m_Offers[_SlotIndex].Good == ResourceType.Wood or self.m_Offers[_SlotIndex].Good == ResourceType.WoodRaw then
            GoodName = XGUIEng.GetStringTableText("InGameMessages/GUI_NameWood");
        elseif self.m_Offers[_SlotIndex].Good == ResourceType.Stone or self.m_Offers[_SlotIndex].Good == ResourceType.StoneRaw then
            GoodName = XGUIEng.GetStringTableText("InGameMessages/GUI_NameStone");
        elseif self.m_Offers[_SlotIndex].Good == ResourceType.Iron or self.m_Offers[_SlotIndex].Good == ResourceType.IronRaw then
            GoodName = XGUIEng.GetStringTableText("InGameMessages/GUI_NameIron");
        elseif self.m_Offers[_SlotIndex].Good == ResourceType.Sulfur or self.m_Offers[_SlotIndex].Good == ResourceType.Sulfur then
            GoodName = XGUIEng.GetStringTableText("InGameMessages/GUI_NameSulfur");
        end

        local Title = GoodName.. " kaufen";
        if Language ~= "de" then
            Title = "Buy " ..GoodName;
        end
        local Text = "Kauft " ..self.m_Offers[_SlotIndex].Amount.. " Einheiten dieses Rohstoffes.";
        if Language ~= "de" then
            Title = "Buy " ..self.m_Offers[_SlotIndex].Amount.. " of this resource.";
        end
        Description = " @color:180,180,180,255 " .. Title .. " @cr @color:255,255,255,255 " ..Text;
        
    -- Custom
    else
        local Title = self.m_Offers[_SlotIndex].Description.Title;
        if type(Title) == "table" then 
            Title = Title[Language];
        end
        local Text  = self.m_Offers[_SlotIndex].Description.Text;
        if type(Text) == "table" then 
            Text = Text[Language];
        end
        Description = " @color:180,180,180,255 " .. Title .. " @cr @color:255,255,255,255 " ..Text;
    end

    XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, Description);
    XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomCosts, CostString);
    XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomShortCut, "");
end

