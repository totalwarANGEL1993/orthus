-- ########################################################################## --
-- #  Multiplayer Ruleset                                                   # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module aims to create a ruleset for multiplayer for the vanilla game
-- but also be able to use the EMS ruleset from the community server.
--
-- Just copy the content of MPRuleset_Default into your mapscript and rename
-- the table there to MPRuleset_Rules.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.oop</li>
-- <li>qsb.mpsync</li>
-- <li>qsb.questbehavior</li>
-- </ul>
--
-- @set sort=true
--

MPRuleset = {
    Data = {
        GameStartOffset = 0,
        WeatherChangeTimestamp = 0,
        BlessTimestamp = {},

        Technologies = {
            Gunsmith = {
                Rifle = {
                    Technologies.T_LeadShot,
                    Technologies.T_Sights,
                },
                Armor = {
                    Technologies.T_FleeceArmor,
                    Technologies.T_FleeceLinedLeatherArmor,
                },
            },

            Laboratory = {
                Cannon = {
                    Technologies.T_EnhancedGunPowder,
                    Technologies.T_BlisteringCannonballs,
                },
                Weather = {
                    Technologies.T_WeatherForecast,
                    Technologies.T_ChangeWeather,
                },
            },

            Masory = {
                Walls = {
                    Technologies.T_Masonry,
                },
            },

            Sawmill = {
                Bowmen = {
                    Technologies.T_Fletching,
                    Technologies.T_BodkinArrow,
                },
                Spearmen = {
                    Technologies.T_WoodAging,
                    Technologies.T_Turnery,
                },
            },

            Smith = {
                Light = {
                    Technologies.T_SoftArcherArmor,
                    Technologies.T_PaddedArcherArmor,
                    Technologies.T_LeatherArcherArmor,
                },
                Heavy = {
                    Technologies.T_LeatherMailArmor,
                    Technologies.T_ChainMailArmor,
                    Technologies.T_PlateMailArmor,
                },
                Weapons = {
                    Technologies.Research_MasterOfSmithery,
                    Technologies.Research_IronCasting,
                },
            },

            University = {
                Construction = {
                    Technologies.GT_Construction,
                    Technologies.GT_GearWheel,
                    Technologies.GT_ChainBlock,
                    Technologies.GT_Architecture,
                },
                Civil = {
                    Technologies.GT_Literacy,
                    Technologies.GT_Trading,
                    Technologies.GT_Printing,
                    Technologies.GT_Library,
                },
                Industrial = {
                    Technologies.GT_Alchemy,
                    Technologies.GT_Alloying,
                    Technologies.GT_Metallurgy,
                    Technologies.GT_Chemistry,
                },
                Millitary = {
                    Technologies.GT_Mercenaries,
                    Technologies.GT_StandingArmy,
                    Technologies.GT_Tactics,
                    Technologies.GT_Strategies,
                },
                Addon = {
                    Technologies.GT_Mathematics,
                    Technologies.GT_Binocular,
                    Technologies.GT_Matchlock,
                    Technologies.GT_PulledBarrel,
                },
                -- TODO: Implement
                Money = {},
            },

            Village = {
                Civil = {
                    Technologies.T_CityGuard,
                    Technologies.T_Loom,
                    Technologies.T_Shoes,
                },
            },
        }
    },

    Maps = {
        EntityTypeToTechnologyType = {
            [Entities.PB_Market1]             = Technologies.B_Market,
            [Entities.PB_Tower1]              = Technologies.B_Tower,
            [Entities.PB_VillageCenter1]      = Technologies.B_Village,
            [Entities.PB_University1]         = Technologies.B_University,

            [Entities.PU_LeaderBow1]          = Technologies.MU_LeaderBow,
            [Entities.PU_LeaderBow2]          = Technologies.MU_LeaderBow,
            [Entities.PU_LeaderBow3]          = Technologies.MU_LeaderBow,
            [Entities.PU_LeaderBow4]          = Technologies.MU_LeaderBow,
            [Entities.PU_LeaderCavalry1]      = Technologies.MU_LeaderLightCavalry,
            [Entities.PU_LeaderCavalry2]      = Technologies.T_UpgradeLightCavalry1,
            [Entities.PU_LeaderHeavyCavalry1] = Technologies.MU_LeaderHeavyCavalry,
            [Entities.PU_LeaderHeavyCavalry2] = Technologies.T_UpgradeHeavyCavalry1,
            [Entities.PU_LeaderPoleArm1]      = Technologies.MU_LeaderSpear,
            [Entities.PU_LeaderPoleArm2]      = Technologies.T_UpgradeSpear1,
            [Entities.PU_LeaderPoleArm3]      = Technologies.T_UpgradeSpear2,
            [Entities.PU_LeaderPoleArm4]      = Technologies.T_UpgradeSpear3,
            [Entities.PU_LeaderSword1]        = Technologies.MU_LeaderSword,
            [Entities.PU_LeaderSword2]        = Technologies.T_UpgradeSword1,
            [Entities.PU_LeaderSword3]        = Technologies.T_UpgradeSword2,
            [Entities.PU_LeaderSword4]        = Technologies.T_UpgradeSword3,
            [Entities.PU_Serf]                = Technologies.MU_Serf,
        },

        LimitToUpgradeCategory = {
            Market       = UpgradeCategories.Market,
            Tower        = UpgradeCategories.Tower,
            University   = UpgradeCategories.University,
            Village      = UpgradeCategories.Village,
            Bow          = UpgradeCategories.LeaderBow,
            LightCavalry = UpgradeCategories.LeaderCavalry,
            HeavyCavalry = UpgradeCategories.LeaderHeavyCavalry,
            Spear        = UpgradeCategories.LeaderPoleArm,
            Serf         = UpgradeCategories.Serf,
            Sword        = UpgradeCategories.LeaderSword,
            Cannon1      = UpgradeCategories.Cannon1,
            Cannon2      = UpgradeCategories.Cannon2,
            Cannon3      = UpgradeCategories.Cannon3,
            Cannon4      = UpgradeCategories.Cannon4,
        },

        EntityTypeToBuyHeroAvailability = {
            [Entities.PU_Hero1c]             = "Dario",
            [Entities.PU_Hero2]              = "Pilgrim",
            [Entities.PU_Hero3]              = "Salim",
            [Entities.PU_Hero4]              = "Erec",
            [Entities.PU_Hero5]              = "Ari",
            [Entities.PU_Hero6]              = "Helias",
            [Entities.CU_BlackKnight]        = "Kerberos",
            [Entities.CU_Mary_de_Mortfichet] = "Mary",
            [Entities.CU_Barbarian_Hero]     = "Varg",
        },
    },

    Text = {
        Messages = {
            IllegalVillage = {
                de = "{red}Ihr dürft an dieser Stelle kein Dorfzentrum errichten! Die Rohstoffe wurden konfisziert!",
                en = "{red}It is not allowed to build a village center here! The resources have been confiscated!",
            },
            WeatherChangeDelay = {
                de = "Es ist noch nicht genug Zeit seit dem letzten Wetterwechsel vergangen!",
                en = "Not enough time has passed since the last weather change!",
            },
            BlessDelay = {
                de = "Es ist noch nicht genug Zeit seit der letzten Segnung vergangen!",
                en = "Not enough time has passed since the last blessing!",
            },
        },
        Quests = {
            Peacetime = {
                Title = {
                    de = "Friedenszeit",
                    en = "Peacetime",
                },
                Text  = {
                    de = "Es herrscht Frieden. Nutzt die Zeit und bereitet euch auf den Kampf vor. Das Gefecht beginnt in %d Minuten!",
                    en = "There is peace. Use the time and prepare for battle. The engagement starts in %d minutes!"
                }
            },
            DeathPenalty = {
                Title = {
                    de = "Todesurteil",
                    en = "Death Penalty",
                },
                Text  = {
                    de = "Ihr müsst vor Ablauf der Zeit alle gegnerischen Teams besiegen, sonst droht Euch ein Todesurteil! Ihr habt dafür %d Minuten Zeit!",
                    en = "You have to defeat all hostile teams. If there is no winner by then, everyone get's the death penalty. You have %d minutes!"
                }
            }
        }
    },
};

function MPRuleset:Install()
    if not self:IsUsingEMS() then
        -- TODO: Rule selection
        local Rules = MPRuleset_Rules;
        if not Rules then
            MPRuleset_Rules = MPRuleset_Default;
            Rules = MPRuleset_Rules;
        end
        for k, v in pairs(MPSync:GetActivePlayers()) do
            Logic.SetNumberOfBuyableHerosForPlayer(v, Rules.Limits.Hero);
        end

        self:CreateEvents();
        self:CreateQuests(Rules);
        self:GiveResources(Rules);
        self:ForbidTechnologies(Rules);
        self:ActivateLogicEventJobs();
        self:OverrideUIStuff();
        self:AddExtraStuff();

        QuestSystem.Workplace:EnableMod(MPRuleset_Rules.Commandment.Workplace == 1);
        MPRuleset_Rules.Callbacks.OnMapConfigured();
    end
end

function MPRuleset:IsUsingEMS()
    return EMS ~= nil;
end

function MPRuleset:CreateEvents()
    self.Data.ScriptEventWeatherChange = MPSync:CreateScriptEvent(function()
        MPRuleset.Data.WeatherChangeTimestamp = Logic.GetTime();
    end);
    self.Data.ScriptEventBless = MPSync:CreateScriptEvent(function(_PlayerID)
        MPRuleset.Data.BlessTimestamp[_PlayerID] = Logic.GetTime();
    end);
end

function MPRuleset:AddExtraStuff()
    local Version = Framework.GetProgramVersion();
    gvExtensionNumber = tonumber(string.sub(Version, string.len(Version)));
    if gvExtensionNumber ~= nil and gvExtensionNumber > 0 then
        self.Maps.EntityTypeToTechnologyType[Entities.PU_LeaderRifle1] = Technologies.MU_LeaderRifle;
        self.Maps.EntityTypeToTechnologyType[Entities.PU_LeaderRifle2] = Technologies.T_UpgradeRifle1;
        self.Maps.EntityTypeToTechnologyType[Entities.PU_Scout]        = Technologies.MU_Scout;
        self.Maps.EntityTypeToTechnologyType[Entities.PU_Thief]        = Technologies.MU_Thief;

        self.Maps.EntityTypeToBuyHeroAvailability[Entities.PU_Hero10]     = "Drake";
        self.Maps.EntityTypeToBuyHeroAvailability[Entities.PU_Hero11]     = "Yuki";
        self.Maps.EntityTypeToBuyHeroAvailability[Entities.CU_Evil_Queen] = "Kala";

        self.Maps.LimitToUpgradeCategory.Rifle = UpgradeCategories.LeaderRifle;
        self.Maps.LimitToUpgradeCategory.Scout = UpgradeCategories.Scout;
        self.Maps.LimitToUpgradeCategory.Thief = UpgradeCategories.Thief;
    end
end

function MPRuleset:OverrideUIStuff()
    BuyHeroWindow_Update_BuyHero_Orig_QSB_MPRuleset = BuyHeroWindow_Update_BuyHero;
    BuyHeroWindow_Update_BuyHero = function(_Type)
        -- Hero limit
        local LimitName = MPRuleset.Maps.EntityTypeToBuyHeroAvailability[_Type];
        if LimitName and MPRuleset_Rules.Heroes[LimitName] and MPRuleset_Rules.Heroes[LimitName] == 0 then
            XGUIEng.DisableButton(XGUIEng.GetCurrentWidgetID(), 1);
            return;
        end
        BuyHeroWindow_Update_BuyHero_Orig_QSB_MPRuleset(_Type);
    end

    GUIAction_ToDestroyBuildingWindow_Orig_QSB_MPRuleset = GUIAction_ToDestroyBuildingWindow;
    GUIAction_ToDestroyBuildingWindow = function()
        -- Crush building fix
        if MPRuleset_Rules.Commandment.CrushBuilding == 1 then
            local BuildingID = GUI.GetSelectedEntity();
            if IsExisting(BuildingID) then
                GUI.DeselectEntity(BuildingID);
                GUI.SellBuilding(BuildingID);
            end
            return;
        end
        GUIAction_ToDestroyBuildingWindow_Orig_QSB_MPRuleset();
    end

    GUIUpdate_BuildingButtons_Orig_QSB_MPRuleset = GUIUpdate_BuildingButtons;
    GUIUpdate_BuildingButtons = function(_Button, _Technology)
        -- Formation fix
        if string.find(_Button, "Formation0") and MPRuleset_Rules.Commandment.Formaition == 1 then
            local PlayerID = GUI.GetPlayerID();
            local WidgetID = XGUIEng.GetCurrentWidgetID();
            XGUIEng.ShowWidget(_Button, 1);
            if Logic.IsTechnologyResearched(PlayerID, Technologies.GT_StandingArmy) == 1 then
                XGUIEng.DisableButton(WidgetID, 0);
            else
                XGUIEng.DisableButton(WidgetID, 1);
            end
        else
            GUIUpdate_BuildingButtons_Orig_QSB_MPRuleset(_Button, _Technology);
        end
    end

    GameCallback_GUI_SelectionChanged_Orig_QSB_MPRuleset = GameCallback_GUI_SelectionChanged;
    GameCallback_GUI_SelectionChanged = function()
        GameCallback_GUI_SelectionChanged_Orig_QSB_MPRuleset();
        -- Formation fix
        if MPRuleset_Rules.Commandment.Formaition == 1 then
            local EntityID = GUI.GetSelectedEntity();
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

    GUIAction_ChangeWeather = function(_Weathertype)
        local Waittime = MPRuleset_Rules.Commandment.WeatherChangeDelay * 60;
        if Waittime > 0 then
            local LastUsed = MPRuleset.Data.WeatherChangeTimestamp;
            if LastUsed > 0 and Logic.GetTime() < (LastUsed + Waittime) then
                GUI.AddNote(XGUIEng.GetStringTableText("InGameMessages/GUI_WeathermashineNotReady"));
                return;
            end
        end

        if Logic.IsWeatherChangeActive() == true then
            GUI.AddNote(XGUIEng.GetStringTableText("InGameMessages/Note_WeatherIsCurrentlyChanging"));	
            return;
        end
        local PlayerID = GUI.GetPlayerID();
        local CurrentWeatherEnergy = Logic.GetPlayersGlobalResource( PlayerID, ResourceType.WeatherEnergy );
        local NeededWeatherEnergy = Logic.GetEnergyRequiredForWeatherChange();
        if CurrentWeatherEnergy >= NeededWeatherEnergy then		
            GUI.AddNote(XGUIEng.GetStringTableText("InGameMessages/GUI_WeathermashineActivated"));
            GUI.SetWeather(_weathertype);
            MPSync:SnchronizedCall(self.Data.ScriptEventWeatherChange);
        else
            GUI.AddNote(XGUIEng.GetStringTableText("InGameMessages/GUI_WeathermashineNotReady"));
        end
    end

    GUIAction_BlessSettlers = function(_BlessCategory)
        local PlayerID = GUI.GetPlayerID();
        local Waittime = MPRuleset_Rules.Commandment.BlessDelay * 60;
        local LastUsed = MPRuleset.Data.BlessTimestamp[PlayerID] or 0;
        if Waittime > 0 then
            if LastUsed > 0 and Logic.GetTime() < (LastUsed + Waittime) then
                GUI.AddNote(XGUIEng.GetStringTableText("InGameMessages/GUI_NotEnoughFaith"));
                Sound.PlayFeedbackSound(Sounds.VoicesMentor_INFO_MonksNeedMoreTime_rnd_01, 0);
                return;
            end
        end

        if InterfaceTool_IsBuildingDoingSomething(GUI.GetSelectedEntity()) == true then		
            return;
        end
        local CurrentFaith = Logic.GetPlayersGlobalResource(PlayerID, ResourceType.Faith)	;
        local BlessCosts = Logic.GetBlessCostByBlessCategory(_BlessCategory);
        if BlessCosts <= CurrentFaith then
            GUI.BlessByBlessCategory(_BlessCategory);
            MPSync:SnchronizedCall(self.Data.ScriptEventBless, PlayerID);
        else	
            GUI.AddNote(XGUIEng.GetStringTableText("InGameMessages/GUI_NotEnoughFaith"));
            Sound.PlayFeedbackSound(Sounds.VoicesMentor_INFO_MonksNeedMoreTime_rnd_01, 0);
        end
    end
end

function MPRuleset:GiveResources(_Data)
    for i= 1, table.getn(Score.Player), 1 do
        local Index = _Data.Resources.Choosen;
        if table.getn(_Data.Resources) < Index then
            Index = table.getn(_Data.Resources);
        end
        Tools.GiveResources(
            i,
            _Data.Resources[Index].Gold,
            _Data.Resources[Index].Clay,
            _Data.Resources[Index].Wood,
            _Data.Resources[Index].Stone,
            _Data.Resources[Index].Iron,
            _Data.Resources[Index].Sulfur
        );
    end
end

function MPRuleset:ActivateLogicEventJobs()
    QuestSystem:StartInlineJob(
        Events.LOGIC_EVENT_ENTITY_CREATED,
        function()
            local EntityID = Event.GetEntityID();
            MPRuleset:LogicEventOnEntityCreated(MPRuleset_Rules, Logic.EntityGetPlayer(EntityID), EntityID);
        end
    );

    QuestSystem:StartInlineJob(
        Events.LOGIC_EVENT_ENTITY_DESTROYED,
        function()
            local EntityID = Event.GetEntityID();
            MPRuleset:LogicEventOnEntityDestroyed(MPRuleset_Rules, Logic.EntityGetPlayer(EntityID), EntityID);
        end
    );

    QuestSystem:StartInlineJob(
        Events.LOGIC_EVENT_ENTITY_HURT_ENTITY,
        function()
            local PlayerID = Event.GetPlayerID1();
            local EntityID = Event.GetEntityID1();
            local VictimList = {Event.GetEntityID2()};
            MPRuleset:LogicEventOnEntityHurtEntity(MPRuleset_Rules, PlayerID, EntityID, VictimList);
        end
    );

    QuestSystem:StartInlineJob(
        Events.LOGIC_EVENT_EVERY_TURN,
        function()
            MPRuleset:LogicEventOnEveryTurn(MPRuleset_Rules);
        end
    );
end

function MPRuleset:LogicEventOnEntityCreated(_Data, _PlayerID, _EntityID)
    local EntityType = Logic.GetEntityType(_EntityID);
    local EntityTypeName = Logic.GetEntityTypeName(EntityType);
    
    -- Invincible bridges
    if _Data.Commandment.InvincibleBridges == 1 then
        if string.find(EntityTypeName, "^PB_.*Bridge") then
            MakeInvulnerable(_EntityID);
        end
    end

    -- Village center placement
    if _Data.Commandment.AssociateVillages == 1 then
        if string.find(EntityTypeName, "^PB_VillageCenter") then
            local IsOk = false;
            for k, v in pairs(GetEntitiesByPrefix("P" .._PlayerID.. "VC")) do
                if GetDistance(_EntityID, v) > 100 then
                    IsOk = true;
                end
            end
            if IsOk == false then
                if GUI.GetPlayerID() == _PlayerID then
                    local Language = (XNetworkUbiCom.Tool_GetCurrentLanguageShortName() == "de" and "de") or "en";
                    Message(ReplacePlacholders(self.Text.Messages.IllegalVillage[Language]));
                end
                Logic.HurtEntity(_EntityID, Logic.GetEntityHealth(_EntityID));
            end
        end
    end

    -- Resource heaps amount
    if _Data.Commandment.ResourceHeapSize > 0 then
        if EntityTypeName == "XD_Clay1" or EntityTypeName == "XD_Iron1"
        or EntityTypeName == "XD_Stone1" or EntityTypeName == "XD_Sulfur1" then
            Logic.SetResourceDoodadGoodAmount(
                _EntityID,
                _Data.Commandment.ResourceHeapSize
            );
        end
    end
end

function MPRuleset:LogicEventOnEntityDestroyed(_Data, _PlayerID, _EntityID)
    -- For future rules ...
end

function MPRuleset:LogicEventOnEntityHurtEntity(_Data, _PlayerID, _EntityID, _VictimList)
    -- For future rules ...
end

function MPRuleset:HasPlayerVillageCenters(_PlayerID)
    local Members = {Logic.GetBuildingTypesInUpgradeCategory(UpgradeCategories.Village)};
    for i= 2, Members[1]+1, 1 do
        local VillageCenters = {Logic.GetPlayerEntities(_PlayerID, Members[i], 16)};
        for j= 2, VillageCenters[1]+1, 1 do
            if Logic.IsConstructionComplete(VillageCenters[j]) == 1 then
                return true;
            end
        end
    end
    return false;
end

function MPRuleset:GetFirstHQOfPlayer(_PlayerID)
    local Members = {Logic.GetBuildingTypesInUpgradeCategory(UpgradeCategories.Headquarters)};
    for i= 2, Members[1]+1, 1 do
        local Headquarters = {Logic.GetPlayerEntities(_PlayerID, Members[i], 16)};
        for j= 2, Headquarters[1]+1, 1 do
            if Logic.IsConstructionComplete(Headquarters[j]) == 1 then
                return Headquarters[j];
            end
        end
    end
    return 0;
end

function MPRuleset:ForbidTechnologies(_Data)
    local Players = MPSync:GetActivePlayers();
    for k, v in pairs(self.Data.Technologies) do
        for Category, Content in pairs(v) do
            for i= 1, table.getn(Players), 1 do
                local PlayerID = Players[i];
                for j= table.getn(Content), 1, -1 do
                    if j > _Data.Technologies[k][Category] then
                        ForbidTechnology(Content[j], PlayerID);
                    end
                end
            end
        end
    end
end

function MPRuleset:LogicEventOnEveryTurn(_Data)
    local Players = MPSync:GetActivePlayers();
    for i= 1, table.getn(Players), 1 do
        -- Building and unit limits
        for k, v in pairs(_Data.Limits) do
            if v and self.Maps.LimitToUpgradeCategory[k] then
                self:CheckUnitOrBuildingLimit(
                    Players[i],
                    self.Maps.LimitToUpgradeCategory[k],
                    v
                );
            end
        end
    
        -- HQ rush
        if MPRuleset_Rules.Commandment.HQRushBlock == 1 then
            local ID = self:GetFirstHQOfPlayer(Players[i]);
            if ID ~= 0 then
                if self:HasPlayerVillageCenters(Players[i]) then
                    MakeInvulnerable(Players[i]);
                else
                    MakeVulnerable(Players[i]);
                end
            end
        end
    end
end

function MPRuleset:CheckUnitOrBuildingLimit(_PlayerID, _UpgradeCategory, _Limit)
    local Players = MPSync:GetActivePlayers();
    local Amount = 0;
    local Members = {Logic.GetBuildingTypesInUpgradeCategory(_UpgradeCategory)};
    if Members[1] > 0 and self.Maps.EntityTypeToTechnologyType[Members[2]] then
        if _Limit > 0 then
            for i= 2, Members[1]+1, 1 do
                Amount = Amount + Logic.GetNumberOfEntitiesOfTypeOfPlayer(_PlayerID, Members[i]);
            end
        end
        if Amount >= _Limit then
            if Logic.GetTechnologyState(_PlayerID, self.Maps.EntityTypeToTechnologyType[Members[2]]) > 0 then
                ForbidTechnology(self.Maps.EntityTypeToTechnologyType[Members[2]], _PlayerID);
                if _PlayerID == GUI.GetPlayerID() then
                    GameCallback_GUI_SelectionChanged();
                end
            end
        else
            if Logic.GetTechnologyState(_PlayerID, self.Maps.EntityTypeToTechnologyType[Members[2]]) < 1 then
                AllowTechnology(self.Maps.EntityTypeToTechnologyType[Members[2]], _PlayerID);
                if _PlayerID == GUI.GetPlayerID() then
                    GameCallback_GUI_SelectionChanged();
                end
            end
        end
    end
end

function MPRuleset:CreateQuests(_Data)
    local Players = MPSync:GetActivePlayers();
    for i= 1, table.getn(Players), 1 do   
        -- Peacetime
        if _Data.Timer.Peacetime > 0 then
            CreateQuest {
                Name        = "MPRuleset_PeacetimeQuest_Player" ..Players[i],
                Time        = _Data.Timer.Peacetime * 60,
                Receiver    = Players[i],
                Description = {
                    Title = self.Text.Quests.Peacetime.Title.de,
                    Text  = string.format(self.Text.Quests.Peacetime.Text.de, _Data.Timer.Peacetime),
                    Type  = MAINQUEST_OPEN,
                    Info  = 1
                },

                Goal_NoChange(),
                Reward_MapScriptFunction(MPRuleset_Rules.Callbacks.OnPeacetimeOver),
                Trigger_Time(self.Data.GameStartOffset)
            };
        else
            MPRuleset_Rules.Callbacks.OnPeacetimeOver();
        end

        -- Death Penalty
        if _Data.Timer.DeathPenalty > 0 then
            CreateQuest {
                Name        = "MPRuleset_DeathPenaltyQuest_Player" ..Players[i],
                Time        = _Data.Timer.DeathPenalty *60,
                Receiver    = Players[i],
                Description = {
                    Title = self.Text.Quests.DeathPenalty.Title.de,
                    Text  = string.format(self.Text.Quests.DeathPenalty.Text.de, _Data.Timer.DeathPenalty),
                    Type  = MAINQUEST_OPEN,
                    Info  = 1
                },

                Goal_MapScriptFunction(function(_Behavior, _Quest)
                    local Team = MPSync:GetTeamOfPlayer(_Quest.m_Receiver)
                    local ActivePlayers = MPSync:GetActivePlayers();
                    if table.getn(ActivePlayers) > 1 then
                        for k, v in pairs(ActivePlayers) do
                            if v and MPSync:GetTeamOfPlayer(v) ~= Team then
                                return;
                            end
                        end
                    end
                    return true;
                end),
                Reprisal_Defeat(),
                Reward_Victory(),
                Trigger_Time(self.Data.GameStartOffset + (_Data.Timer.Peacetime * 60) +2)
            };
        end
    end
end

-- -------------------------------------------------------------------------- --

---
-- Default Rules. DO NOT CHANGE THEM!!!
--
-- Copy this table and rename it to MPRuleset_Rules. Paste it into your
-- mapscript or load it from an extern file. If you consider using EMS
-- then you can not use this configuration. Use EMS configuration instead.
--
-- @within Rules
--
MPRuleset_Default = {
    Resources = {
        Choosen = 1,

        [1] = {
            Gold            = 1000,
            Clay            = 1500,
            Wood            = 1200,
            Stone           = 800,
            Iron            = 50,
            Sulfur          = 50,
        },
        [2] = {
            Gold            = 2000,
            Clay            = 3500,
            Wood            = 2400,
            Stone           = 1600,
            Iron            = 800,
            Sulfur          = 800,
        },
        [3] = {
            Gold            = 5000,
            Clay            = 8000,
            Wood            = 8000,
            Stone           = 5000,
            Iron            = 5000,
            Sulfur          = 5000,
        },
    },

    Timer = {
        -- Peacetime in minutes (0 = off)
        Peacetime           = 20,

        -- Minutes until everyone loses (0 = off)
        DeathPenalty        = 0,
    },

    Commandment = {

        -- Crush building glitch fixed. Buildings will deselect the building
        -- and then destroy it right away without warning. (0 = off)
        CrushBuilding       = 1,

        -- Formation tech fix (0 = off)
        -- Formations will only require GT_StandingArmy researched and not 
        -- GT_Tactics to also be allowed.
        Formaition          = 1,

        -- Associate village centers to players (0 = off)
        -- Give sequential names to village centers for each player. Players
        -- can not build village centers expect there where they allowed to.
        -- Example: (P1VC1, P1VC2, ..)
        AssociateVillages   = 0,

        -- Block HQ rush (0 = off)
        -- Player HQs can not be damaged until the player has village
        -- centers left.
        HQRushBlock         = 1,

        -- Bridges can not be destroyed (0 = off)
        InvincibleBridges   = 1,

        -- Control worker amount in workplaces (0 = off)
        Workplace           = 1,

        -- Minutes the weather can not be changed again after a change was
        -- triggered by the weather tower.
        WeatherChangeDelay  = 3,

        -- Minutes a player must wait between two blesses.
        BlessDelay          = 3,

        -- Amount of Resources in resource heaps
        ResourceHeapSize    = 2000,
    },

    Limits = {
        -- Limit of heroes the player can buy
        Hero         =  3,

        -- Building Limit  (-1 = off)
        Market       = 1,
        Tower        =  5,
        University   = -1,
        Village      = -1,

        -- Unit limits (-1 = off)
        Bow          = -1,
        LightCavalry = -1,
        HeavyCavalry = -1,
        Rifle        = -1,
        Spear        = -1,
        Serf         = -1,
        Scout        = -1,
        Sword        = -1,
        Thief        = -1,

        -- vehicle limit (-1 = off)
        Cannon1      = -1,
        Cannon2      = -1,
        Cannon3      = -1,
        Cannon4      = -1,
    },

    -- Heroes available (0 = forbidden)
    Heroes = {
        Dario               = 1,
        Pilgrim             = 1,
        Salim               = 1,
        Erec                = 1,
        Ari                 = 1,
        Helias              = 1,
        Drake               = 1,
        Yuki                = 1,
        -- ---------- --
        Varg                = 1,
        Kerberos            = 1,
        Mary                = 1,
        Kala                = 1,
    },

    Technologies = {
        -- Gunsmith technologies
        Gunsmith            = {
            Rifle           = 2, -- Weapons branch (0 to 2)
            Armor           = 2, -- Armor branch (0 to 2)
        },

        -- Laboratory technologies
        Laboratory          = {
            Cannon          = 2, -- Cannon branch (0 to 2)
            Weather         = 2, -- Weather branch (0 to 2)
        },

        -- Masory technologies
        Masory              = {
            Walls           = 1, -- Building defence
        },

        Sawmill             = {
            Spearmen        = 2, -- Sear branch (0 to 2)
            Bowmen          = 2, -- Bow branch (0 to 2)
        },

        -- Smith technologies
        Smith               = {
            Light           = 3, -- Light armor branch (0 to 3)
            Heavy           = 3, -- Heavy armor branch (0 to 3)
            Weapons         = 2, -- Weapon branch (0 to 2)
        },

        -- University technologies
        University          = {
            Construction    = 4, -- Construction branch (0 to 4)
            Civil           = 4, -- Civil branch (0 to 4)
            Industrial      = 4, -- Industrial branch (0 to 4)
            Millitary       = 4, -- Millitary branch (0 to 4)
            Addon           = 4, -- Addon branch (0 to 4)
        },

        Village             = {
            Civil           = 3, -- Village center (0 to 3)
        }
    },

    Callbacks = {
        -- After configuration has been loaded
        OnMapConfigured = function()
        end,

        -- After peacetime ended (no peacetime means immediate execution)
        OnPeacetimeOver = function()
        end,
    },
};

