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

---
-- Default Rules. DO NOT CHANGE THEM!!!
--
MPRuleset_Default = {
    Basic = {
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

        -- Crush building glitch fixed
        CrushBuilding       = 1,

        -- Formations will only require GT_StandingArmy and not GT_Tactics 
        -- to also be allowed.
        Formaition          = 1,

        -- Peacetime in minutes (0 = off)
        Peacetime           = 20,
    },

    Limits = {
        Hero         =  3,

        Market       = -1,
        Tower        =  5,
        University   = -1,
        Village      = -1,

        Bow          = -1,
        LightCavalry = -1,
        HeavyCavalry = -1,
        Rifle        = -1,
        Spear        = -1,
        Serf         = -1,
        Scout        = -1,
        Sword        = -1,
        Thief        = -1,

        Cannon1      = -1,
        Cannon2      = -1,
        Cannon3      = -1,
        Cannon4      = -1,
    },

    Special = {
        -- Give sequential names to village centers for each player. Players
        -- can not build village centers expect there where they allowed to.
        -- Example: (P1VC1, P1VC2, ..)
        AssociateVillages   = 0,

        -- Minutes until everyone loses (0 = off)
        DeathPenalty        = 0,

        -- Cannons and towers inflict damage to allies.
        FriendlyFire        = 1,

        -- Player HQs can not be damaged until the player has village
        -- centers left.
        -- (building plots don't count)
        HQRushBlock         = 1,

        -- Bridges can not be destroyed (0 = off)
        InvincibleBridges   = 1,
    },

    Heroes = {
        Dario               = 1, -- (0 = forbidden)
        Pilgrim             = 1, -- (0 = forbidden)
        Salim               = 1, -- (0 = forbidden)
        Erec                = 1, -- (0 = forbidden)
        Ari                 = 1, -- (0 = forbidden)
        Helias              = 1, -- (0 = forbidden)
        Drake               = 1, -- (0 = forbidden)
        Yuki                = 1, -- (0 = forbidden)
        -- ---------- --
        Varg                = 1, -- (0 = forbidden)
        Kerberos            = 1, -- (0 = forbidden)
        Mary                = 1, -- (0 = forbidden)
        Kala                = 1, -- (0 = forbidden)
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
};

MPRuleset = {
    Data = {
        GameStartOffset = 0,

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

    Callback = {
        PeacetimeOver = function()
        end,
    },

    Text = {
        Messages = {
            IllegalVillage = {
                de = "{red}Ihr dürft an dieser Stelle kein Dorfzentrum errichten! Die Rohstoffe wurden konfisziert!",
                en = "{red}It is not allowed to build a village center here! The resources have been confiscated!",
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
    }
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

        self:CreateQuests(Rules);
        self:GiveResources(Rules);
        self:ForbidTechnologies(Rules);
        self:ActivateLogicEventJobs();
        self:OverrideUIStuff();
        self:AddExtraStuff();
    end
end

function MPRuleset:IsUsingEMS()
    -- TODO: Implement EMS check
    return false;
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

--EntityTypeToBuyHeroAvailability

function MPRuleset:OverrideUIStuff()
    BuyHeroWindow_Update_BuyHero_Orig_QSB_MPRuleset = BuyHeroWindow_Update_BuyHero;
    BuyHeroWindow_Update_BuyHero = function(_Type)
        local LimitName = MPRuleset.Maps.EntityTypeToBuyHeroAvailability[_Type];
        if LimitName and MPRuleset_Rules.Heroes[LimitName] and MPRuleset_Rules.Heroes[LimitName] == 0 then
            XGUIEng.DisableButton(XGUIEng.GetCurrentWidgetID(), 1);
            return;
        end
        BuyHeroWindow_Update_BuyHero_Orig_QSB_MPRuleset(_Type);
    end
end

function MPRuleset:GiveResources(_Data)
    for i= 1, table.getn(Score.Player), 1 do
        local Index = _Data.Basic.Resources.Choosen;
        if table.getn(_Data.Basic.Resources) < Index then
            Index = table.getn(_Data.Basic.Resources);
        end
        Tools.GiveResources(
            i, 
            _Data.Basic.Resources[Index].Gold, 
            _Data.Basic.Resources[Index].Clay, 
            _Data.Basic.Resources[Index].Wood, 
            _Data.Basic.Resources[Index].Iron, 
            _Data.Basic.Resources[Index].Stone, 
            _Data.Basic.Resources[Index].Sulfur
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
    if _Data.Special.InvincibleBridges == 1 then
        if string.find(EntityTypeName, "^PB_.*Bridge") then
            MakeInvulnerable(_EntityID);
        end
    end

    -- Village center placement
    if _Data.Special.AssociateVillages == 1 then
        if string.find(EntityTypeName, "^PB_VillageCenter") then
            local IsOk = false;
            for k, v in pairs(GetEntitiesByPrefix("P1VC")) do
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
end

function MPRuleset:LogicEventOnEntityDestroyed(_Data, _PlayerID, _EntityID)
end

function MPRuleset:LogicEventOnEntityHurtEntity(_Data, _PlayerID, _EntityID, _VictimList)
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
        if _Data.Basic.Peacetime > 0 then
            CreateQuest {
                Name        = "MPRuleset_PeacetimeQuest_Player" ..Players[i],
                Time        = _Data.Basic.Peacetime * 60,
                Receiver    = Players[i],
                Description = {
                    Title = self.Text.Quests.Peacetime.Title.de,
                    Text  = string.format(self.Text.Quests.Peacetime.Text.de, _Data.Basic.Peacetime),
                    Type  = MAINQUEST_OPEN,
                    Info  = 1
                },

                Goal_NoChange(),
                Trigger_Time(self.Data.GameStartOffset)
            };
        else
            self.Callback.PeacetimeOver();
        end

        -- Death Penalty
        if _Data.Special.DeathPenalty > 0 then
            CreateQuest {
                Name        = "MPRuleset_DeathPenaltyQuest_Player" ..Players[i],
                Time        = _Data.Special.DeathPenalty *60,
                Receiver    = Players[i],
                Description = {
                    Title = self.Text.Quests.DeathPenalty.Title.de,
                    Text  = string.format(self.Text.Quests.DeathPenalty.Text.de, _Data.Special.DeathPenalty),
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
                Trigger_Time(self.Data.GameStartOffset + (_Data.Basic.Peacetime * 60) +1)
            };
        end
    end
end

