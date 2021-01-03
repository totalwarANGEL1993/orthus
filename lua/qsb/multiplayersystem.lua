-- ########################################################################## --
-- #  Multiplayer Ruleset                                                   # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module aims to create a ruleset for multiplayer for the vanilla game
-- and the History Edition but also be able to use the EMS ruleset from the
-- community server if the map is published there.
--
-- Just copy the content of MultiplayerRules_Default into your mapscript and rename
-- the table there to MPRuleset_Rules.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.lib.oop</li>
-- <li>qsb.core.questsync</li>
-- <li>qsb.core.questtools</li>
-- <li>qsb.questbehavior</li>
-- <li>qsb.ext.optionsmenu</li>
-- <li>qsb.ext.timer</li>
-- </ul>
--
-- @set sort=true
--

MultiplayerSystem = {
    Data = {
        GameStartEntities = {},
        GameStartEntitiesBlacklist = {
            Entities.XD_BuildBlockScriptEntity,
            Entities.XD_Explore10,
            Entities.XD_ScriptEntity,
            Entities.XD_StandardLarge,
            Entities.XD_StandartePlayerColor,
            Entities.XD_DarkWallCorner,
            Entities.XD_DarkWallDistorted,
            Entities.XD_DarkWallStraight,
            Entities.XD_DarkWallStraightGate,
            Entities.XD_DarkWallStraightGate_Closed,
            Entities.XD_WallCorner,
            Entities.XD_WallDistorted,
            Entities.XD_WallStraight,
            Entities.XD_WallStraightGate,
            Entities.XD_WallStraightGate_Closed,
            Entities.XS_Ambient,
        },

        GameStartOffset = 0,
        RuleSelectionActive = false,

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

    Menu = {
        PlayerID = 1,

        -- Main page
        {
            Identifier  = "Main",
            Parent      = nil,
            OnClose     = function()
                MultiplayerSystem:RuleChangeSubmit(OptionMenu:GetCurrentPage());
            end,
            Title       = {
                de = "Regeleinstellungen", en = "Rule settings"
            },
            Description = {
                de = "Wählt in den Kategorien die Regeln aus. Bestätigt, um"..
                     " das Spiel zu beginnen.",
                en = "Select the rules for this game. Confirm your settings"..
                     " once you have finished."
            },
            Options     = {
                {Text   = {de = "Rohstoffe", en = "Resources"},
                 Target = function()
                    return "Rule_Resources";
                 end},
                {Text   = {de = "Zähler", en = "Counters"},
                 Target = function()
                    return "Rule_Timers";
                 end},
                {Text   = {de = "Beschränkungen", en = "Limits"},
                 Target = function()
                    return "Rule_Limits";
                 end},
                {Text   = {de = "Helden", en = "Heroes"},
                 Target = function()
                    return "Rule_Heroes";
                 end},
                {Text   = {de = "Dekrete", en = "Commandments"},
                 Target = function()
                    return "Rule_Commandments";
                 end},
                {Text   = {de = "Fehlerbehebung", en = "Bug Fixes"},
                 Target = function()
                     return "Rule_Fixes";
                 end},
            }
        },

        -- Resources
        {
            Identifier  = "Rule_Resources",
            Parent      = "Main",
            Title       = {
                de = "Rohstoffe", en = "Resources"
            },
            Description = {
                de = "Wählt Startrohstoffe und Haufengröße aus.",
                en = "Choose start resources and heap size.",
            },
            Options     = {
                {Text   = function()
                    return ((QuestTools.GetLanguage() == "de" and "Rohstoffe: ") or "Resources: ") ..
                           (MPRuleset_Rules.Resources.Choosen == 2 and ((QuestTools.GetLanguage() == "de" and "{yellow}viel") or "{yellow}plenty") or
                            MPRuleset_Rules.Resources.Choosen == 3 and ((QuestTools.GetLanguage() == "de" and "{orange}absurd") or "{orange}insane") or
                            "{grey}normal") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Resources", "Choosen", 1, 1, 3);
                    return "Rule_Resources";
                 end},
                {Text   = function()
                    return ((QuestTools.GetLanguage() == "de" and "Haufengröße:{grey}") or "Heap size:{grey}") ..
                           (MPRuleset_Rules.Resources.ResourceHeapSize.. "{white}");
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Resources", "ResourceHeapSize", 100, 400, 5000);
                    return "Rule_Resources";
                 end},
            }
        },

        -- Timers
        {
            Identifier  = "Rule_Timers",
            Parent      = "Main",
            Title       = {
                de = "Zähler", en = "Counters"
            },
            Description = {
                de = "Wählt Friedenszeit und Todeststrafe aus.",
                en = "Choose peacetime and death penalty.",
            },
            Options     = {
                {Text   = function()
                    return ((QuestTools.GetLanguage() == "de" and "Friedenszeit: ") or "Peacetime: ") ..
                           ((MPRuleset_Rules.Timer.Peacetime == 0 and "-") or MPRuleset_Rules.Timer.Peacetime .. " min");
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Timer", "Peacetime", 5, 0, 50);
                    return "Rule_Timers";
                 end},
                {Text   = function()
                    return ((QuestTools.GetLanguage() == "de" and "Todesstrafe: ") or "Death penalty: ") ..
                           ((MPRuleset_Rules.Timer.DeathPenalty == 0 and "-") or MPRuleset_Rules.Timer.DeathPenalty .. " min");
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Timer", "DeathPenalty", 5, 0, 50);
                    return "Rule_Timers";
                 end},
            }
        },

        -- Fixes
        {
            Identifier  = "Rule_Fixes",
            Parent      = "Main",
            Title       = {
                de = "Fehlerbehebung", en = "Bug Fixes"
            },
            Description = {
                de = "Schaltet Patches für Fehler im Spiel hinzu oder deaktiviert sie.",
                en = "Activat or deactivate serveral bugfixes to improve game experience.",
            },
            Options     = {
                {Text   = function()
                    return ((MPRuleset_Rules.Fixes.CrushBuilding == 0 and "{red}") or "{green}") ..
                           ((QuestTools.GetLanguage() == "de" and "Abrissfix") or "Demolish fix") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeToggleRule("Fixes", "CrushBuilding", 1);
                    return "Rule_Fixes";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Fixes.Formaition == 0 and "{red}") or "{green}") ..
                           ((QuestTools.GetLanguage() == "de" and "Formationsfix") or "Formation fix") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeToggleRule("Fixes", "Formaition", 1);
                    return "Rule_Fixes";
                 end},
                {Text   = function()
                     return ((MPRuleset_Rules.Fixes.FindView == 0 and "{red}") or "{green}") ..
                            ((QuestTools.GetLanguage() == "de" and "Einheiten finden Fix") or "Find button fix") .. "{white}";
                 end,
                 Target = function()
                     MultiplayerSystem:RuleChangeToggleRule("Fixes", "FindView", 1);
                     return "Rule_Fixes";
                 end},
            }
        },

        -- Commandments
        {
            Identifier  = "Rule_Commandments",
            Parent      = "Main",
            Title       = {
                de = "Gebote", en = "Commandments"
            },
            Description = {
                de = "Wählt spezielle Dekrete für dieses Spiel aus.",
                en = "Choos special commandments for this game.",
            },
            Options     = {
                {Text   = function()
                    return ((MPRuleset_Rules.Commandment.AssociateVillages == 0 and "{red}") or "{green}") ..
                           ((QuestTools.GetLanguage() == "de" and "Dorfzentren binden") or "Bind villages") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeToggleRule("Commandment", "AssociateVillages", 1);
                    return "Rule_Commandments";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Commandment.HQRushBlock == 0 and "{red}") or "{green}") ..
                           ((QuestTools.GetLanguage() == "de" and "Anti-Rush") or "Anti rush") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeToggleRule("Commandment", "HQRushBlock", 1);
                    return "Rule_Commandments";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Commandment.InvincibleBridges == 0 and "{red}") or "{green}") ..
                           ((QuestTools.GetLanguage() == "de" and "Brücken unzerstörbar") or "Indescrutable bridges") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeToggleRule("Commandment", "InvincibleBridges", 1);
                    return "Rule_Commandments";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Commandment.Workplace == 0 and "{red}") or "{green}") ..
                           ((QuestTools.GetLanguage() == "de" and "Arbeiterzahl ändern") or "Change worker amount") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeToggleRule("Commandment", "Workplace", 1);
                     return "Rule_Commandments";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Commandment.WeatherChangeDelay == 0 and "{red}") or "{green}") ..
                           ((QuestTools.GetLanguage() == "de" and "Wetterwechsellimit") or "Weather change limit") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeToggleRule("Commandment", "WeatherChangeDelay", 5 * 60);
                    return "Rule_Commandments";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Commandment.BlessDelay == 0 and "{red}") or "{green}") ..
                           ((QuestTools.GetLanguage() == "de" and "Segenlimit") or "Bless limit") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeToggleRule("Commandment", "BlessDelay", 90);
                    return "Rule_Commandments";
                 end},
            }
        },

        -- Limits
        {
            Identifier  = "Rule_Limits",
            Parent      = "Main",
            Title       = {
                de = "Beschränkungen", en = "Limits"
            },
            Description = {
                de = "In den unten stehenden Kategorien könnt Ihr Einheiten,"..
                     " Gebäude, Kanonen und Spezialeinheiten limitieren.",
                en = "In the categories below you are able to limit the amount"..
                     " of buildings, units, cannons and special units."
            },
            Options     = {
                {Text   = {de = "Gebäude", en = "Buildings"},
                 Target = function()
                    return "Rule_Limits_Buildings"
                 end},
                {Text   = {de = "Kanonen", en = "Cannons"},
                 Target = function()
                    return "Rule_Limits_Cannons"
                 end},
                {Text   = {de = "Militär", en = "Military"},
                 Target = function()
                    return "Rule_Limits_Units"
                 end},
                {Text   = {de = "Spezial", en = "Special"},
                  Target = function()
                    return "Rule_Limits_Special"
                 end},
            }
        },
        {
            Identifier  = "Rule_Limits_Buildings",
            Parent      = "Rule_Limits",
            Title       = {
                de = "Gebäude", en = "Buildings"
            },
            Description = {
                de = "Wählt die Menge der erlaubten Gebäude aus.",
                en = "Choose the max amount for these buildings.",
            },
            Options     = {
                {Text   = function()
                    return ((MPRuleset_Rules.Limits.Market ~= 0 and "{green}") or "{red}") ..
                           ((QuestTools.GetLanguage() == "de" and "Lagerhäuser") or "Warehouses") ..
                           ((MPRuleset_Rules.Limits.Market > 0 and "{white}(" ..MPRuleset_Rules.Limits.Market.. "/3)") or "{white}");
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Limits", "Market", 1, -1, 3);
                    return "Rule_Limits_Buildings";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Limits.Tower ~= 0 and "{green}") or "{red}") ..
                           ((QuestTools.GetLanguage() == "de" and "Türme") or "Towers") ..
                           ((MPRuleset_Rules.Limits.Tower > 0 and "{white}(" ..MPRuleset_Rules.Limits.Tower.. "/10)") or "{white}");
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Limits", "Tower", 1, -1, 10);
                    return "Rule_Limits_Buildings";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Limits.University ~= 0 and "{green}") or "{red}") ..
                           ((QuestTools.GetLanguage() == "de" and "Schulen") or "Collages") ..
                           ((MPRuleset_Rules.Limits.University > 0 and "{white}(" ..MPRuleset_Rules.Limits.University.. "/5)") or "{white}");
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Limits", "University", 1, -1, 5);
                    return "Rule_Limits_Buildings";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Limits.Village ~= 0 and "{green}") or "{red}") ..
                           ((QuestTools.GetLanguage() == "de" and "Dorfzentren") or "Villages") ..
                           ((MPRuleset_Rules.Limits.Village > 0 and "{white}(" ..MPRuleset_Rules.Limits.Village.. "/5)") or "{white}");
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Limits", "Village", 1, -1, 5);
                    return "Rule_Limits_Buildings";
                 end},
            }
        },
        {
            Identifier  = "Rule_Limits_Cannons",
            Parent      = "Rule_Limits",
            Title       = {
                de = "Kanonen", en = "Cannons"
            },
            Description = {
                de = "Wählt aus, welche Kannonen erlaubt sind.",
                en = "Choose which cannon types you want to allow.",
            },
            Options     = {
                {Text   = function()
                    return ((MPRuleset_Rules.Limits.Cannon1 == 0 and "{red}") or "{green}") ..
                           ((QuestTools.GetLanguage() == "de" and "Bombarde") or "Bombard") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Limits", "Cannon1", -1, -1, 0);
                    return "Rule_Limits_Cannons";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Limits.Cannon2 == 0 and "{red}") or "{green}") ..
                           ((QuestTools.GetLanguage() == "de" and "Bronzekanone") or "Bronze cannon") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Limits", "Cannon2", -1, -1, 0);
                    return "Rule_Limits_Cannons";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Limits.Cannon3 == 0 and "{red}") or "{green}") ..
                           ((QuestTools.GetLanguage() == "de" and "Eisenkanone") or "Iron cannon") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Limits", "Cannon3", -1, -1, 0);
                    return "Rule_Limits_Cannons";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Limits.Cannon4 == 0 and "{red}") or "{green}") ..
                           ((QuestTools.GetLanguage() == "de" and "Belagerungskanone") or "Siege cannon") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Limits", "Cannon4", -1, -1, 0);
                    return "Rule_Limits_Cannons";
                 end},
            }
        },
        {
            Identifier  = "Rule_Limits_Units",
            Parent      = "Rule_Limits",
            Title       = {
                de = "Millitär", en = "Military"
            },
            Description = {
                de = "Wählt aus, welche Einheiten erlaubt sind.",
                en = "Choose which unit types you want to allow.",
            },
            Options     = {
                {Text   = function()
                    return ((MPRuleset_Rules.Limits.Bow == 0 and "{red}") or "{green}") ..
                           ((QuestTools.GetLanguage() == "de" and "Bogenschützen") or "Archer") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Limits", "Bow", -1, -1, 0);
                    return "Rule_Limits_Units";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Limits.LightCavalry == 0 and "{red}") or "{green}") ..
                           ((QuestTools.GetLanguage() == "de" and "Leichte Kavalerie") or "Light Cavalry") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Limits", "LightCavalry", -1, -1, 0);
                    return "Rule_Limits_Units";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Limits.HeavyCavalry == 0 and "{red}") or "{green}") ..
                           ((QuestTools.GetLanguage() == "de" and "Schwere Kavalerie") or "Heavy Cavalry") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Limits", "HeavyCavalry", -1, -1, 0);
                    return "Rule_Limits_Units";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Limits.Rifle == 0 and "{red}") or "{green}") ..
                           ((QuestTools.GetLanguage() == "de" and "Scharfschützen") or "Marksmen") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Limits", "Rifle", -1, -1, 0);
                    return "Rule_Limits_Units";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Limits.Spear == 0 and "{red}") or "{green}") ..
                           ((QuestTools.GetLanguage() == "de" and "Speerträger") or "Spearmen") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Limits", "Spear", -1, -1, 0);
                    return "Rule_Limits_Units";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Limits.Sword == 0 and "{red}") or "{green}") ..
                           ((QuestTools.GetLanguage() == "de" and "Schwertkämpfer") or "Swordsmen") .. "{white}";
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Limits", "Sword", -1, -1, 0);
                    return "Rule_Limits_Units";
                 end},
            }
        },
        {
            Identifier  = "Rule_Limits_Special",
            Parent      = "Rule_Limits",
            Title       = {
                de = "Spezial", en = "Special"
            },
            Description = {
                de = "Wählt die Menge der erlaubten Spezialisten aus.",
                en = "Choose the max amount for the special units.",
            },
            Options     = {
                {Text   = function()
                     return ((MPRuleset_Rules.Limits.Hero == 0 and "{red}") or "{green}") ..
                            ((QuestTools.GetLanguage() == "de" and "Helden") or "Heroes") ..
                            ((MPRuleset_Rules.Limits.Hero > 0 and "{white}(" ..MPRuleset_Rules.Limits.Hero.. "/6)") or "{white}");
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Limits", "Hero", 1, 0, 6);
                    return "Rule_Limits_Special";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Limits.Thief ~= 0 and "{green}") or "{red}") ..
                           ((QuestTools.GetLanguage() == "de" and "Diebe") or "Thieves") ..
                           ((MPRuleset_Rules.Limits.Thief > 0 and "{white}(" ..MPRuleset_Rules.Limits.Thief.. "/10)") or "{white}");
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Limits", "Thief", 1, -1, 10);
                    return "Rule_Limits_Special";
                 end},
                {Text   = function()
                    return ((MPRuleset_Rules.Limits.Scout ~= 0 and "{green}") or "{red}") ..
                           ((QuestTools.GetLanguage() == "de" and "Kundschafter") or "Scouts") ..
                           ((MPRuleset_Rules.Limits.Scout > 0 and "{white}(" ..MPRuleset_Rules.Limits.Scout.. "/10)") or "{white}");
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeAlterValue("Limits", "Scout", 1, -1, 10);
                    return "Rule_Limits_Special";
                 end},
            }
        },

        -- Heroes
        {
            Identifier  = "Rule_Heroes",
            Parent      = "Main",
            Title       = {
                de = "Helden", en = "Heroes"
            },
            Description = {
                de = "Wechselt in die entsprechende Kategorie, um die Helden"..
                     " zu erlaben oder zu verbieten.",
                en = "Enter the corresponding category to toggle hero"..
                     " availability."
            },
            Options     = {
                {Text   = {de = "Gute Helden", en = "Good heroes"},
                 Target = "Rule_Heroes_Good"},
                {Text   = {de = "Böse Helden", en = "Evil heroes"},
                 Target = "Rule_Heroes_Evil"},
            }
        },
        {
            Identifier  = "Rule_Heroes_Good",
            Parent      = "Rule_Heroes",
            Title       = {
                de = "Böse Helden", en = "Good heroes"
            },
            Description = {
                de = "Wählt die Helden aus, welche verfügbar sind.",
                en = "Choos which heroes should be available.",
            },
            Options     = {
                {Text   = function()
                     return ((MPRuleset_Rules.Heroes.Ari == 0 and "{red}") or "{green}") .. "Ari{white}"
                 end,
                 Target = function()
                     MultiplayerSystem:RuleChangeToggleRule("Heroes", "Ari", 1);
                     return "Rule_Heroes_Good";
                 end},
                {Text   = function()
                     return ((MPRuleset_Rules.Heroes.Dario == 0 and "{red}") or "{green}") .. "Dario{white}"
                 end,
                 Target = function()
                     MultiplayerSystem:RuleChangeToggleRule("Heroes", "Dario", 1);
                     return "Rule_Heroes_Good";
                 end},
                {Text   = function()
                     return ((MPRuleset_Rules.Heroes.Drake == 0 and "{red}") or "{green}") .. "Drake{white}"
                 end,
                 Target = function()
                     MultiplayerSystem:RuleChangeToggleRule("Heroes", "Drake", 1);
                     return "Rule_Heroes_Good";
                 end},
                {Text   = function()
                     return ((MPRuleset_Rules.Heroes.Erec == 0 and "{red}") or "{green}") .. "Erec{white}"
                 end,
                 Target = function()
                     MultiplayerSystem:RuleChangeToggleRule("Heroes", "Erec", 1);
                     return "Rule_Heroes_Good";
                 end},
                {Text   = function()
                     return ((MPRuleset_Rules.Heroes.Helias == 0 and "{red}") or "{green}") .. "Helias{white}"
                 end,
                 Target = function()
                     MultiplayerSystem:RuleChangeToggleRule("Heroes", "Helias", 1);
                     return "Rule_Heroes_Good";
                 end},
                {Text   = function()
                     return ((MPRuleset_Rules.Heroes.Pilgrim == 0 and "{red}") or "{green}") .. "Pilgrim{white}"
                 end,
                 Target = function()
                     MultiplayerSystem:RuleChangeToggleRule("Heroes", "Pilgrim", 1);
                     return "Rule_Heroes_Good";
                 end},
                {Text   = function()
                     return ((MPRuleset_Rules.Heroes.Salim == 0 and "{red}") or "{green}") .. "Salim{white}"
                 end,
                 Target = function()
                     MultiplayerSystem:RuleChangeToggleRule("Heroes", "Salim", 1);
                     return "Rule_Heroes_Good";
                 end},
                {Text   = function()
                     return ((MPRuleset_Rules.Heroes.Yuki == 0 and "{red}") or "{green}") .. "Yuki{white}"
                 end,
                 Target = function()
                     MultiplayerSystem:RuleChangeToggleRule("Heroes", "Yuki", 1);
                     return "Rule_Heroes_Good";
                 end},
            }
        },
        {
            Identifier  = "Rule_Heroes_Evil",
            Parent      = "Rule_Heroes",
            Title       = {
                de = "Böse Helden", en = "Evil heroes"
            },
            Description = {
                de = "Wählt die Helden aus, welche verfügbar sind.",
                en = "Choos which heroes should be available.",
            },
            Options     = {
                {Text   = function()
                     return ((MPRuleset_Rules.Heroes.Kala == 0 and "{red}") or "{green}") .. "Kala{white}"
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeToggleRule("Heroes", "Kala", 1);
                    return "Rule_Heroes_Evil";
                 end},
                {Text   = function()
                     return ((MPRuleset_Rules.Heroes.Kerberos == 0 and "{red}") or "{green}") .. "Kerberos{white}"
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeToggleRule("Heroes", "Kerberos", 1);
                    return "Rule_Heroes_Evil";
                 end},
                {Text   = function()
                     return ((MPRuleset_Rules.Heroes.Mary == 0 and "{red}") or "{green}") .. "Mary de Mortfichet{white}"
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeToggleRule("Heroes", "Mary", 1);
                    return "Rule_Heroes_Evil";
                 end},
                {Text   = function()
                     return ((MPRuleset_Rules.Heroes.Varg == 0 and "{red}") or "{green}") .. "Varg{white}"
                 end,
                 Target = function()
                    MultiplayerSystem:RuleChangeToggleRule("Heroes", "Varg", 1);
                    return "Rule_Heroes_Evil";
                 end},
            }
        },
    },

    Text = {
        Messages = {
            IllegalVillage = {
                de = "Ihr dürft an dieser Stelle kein Dorfzentrum errichten! Die Rohstoffe wurden konfisziert!",
                en = "It is not allowed to build a village center here! The resources have been confiscated!",
            },
            RulesDefined = {
                de = "{green}Die Regeln wurden festgelegt! Das Spiel beginnt!",
                en = "{green}Rules have been defined! The game starts!",
            },
            PeacetimeOver = {
                de = "{orange}Die Friedenszeit ist vorrüber! Nun beginnt das Gemetzel!",
                en = "{orange}The peacetime is over! Let the slaughter begin!",
            },
            ImpendingDeath = {
                de = "{red}Euch bleibt nicht viel Zeit, bis das Urteil gesprochen wird!",
                en = "{red}There isn't much time left until judgement fall upon you!",
            },
        },
        Quests = {
            Mainquest = {
                Title = {
                    de = "Missionsziel",
                    en = "Mission Objective",
                },
                Text  = {
                    de = "Dies ist eine Eroberungsmission! Euer Ziel ist es, alle Eure Widersacher zu schlagen und Euch und Eurem Team den Sieg zu sichern!",
                    en = "This is a conquest mission! Your objective is it to destroy all your opponents who dare to offend you and your team!"
                }
            },
            Peacetime = {
                Title = {
                    de = "Friedenszeit",
                    en = "Peacetime",
                },
                Text  = {
                    de = "Es herrscht Frieden.{cr}Nutzt die Zeit und bereitet euch auf den Kampf vor.{cr}Das Gefecht beginnt in %d Minuten!",
                    en = "There is peace.{cr}Use the time and prepare for battle.{cr}The engagement starts in %d minutes!"
                }
            },
            ConquestVictoryCondition = {
                Title = {
                    de = "Eroberungsfeldzug",
                    en = "Conquest campaign",
                },
                Text  = {
                    de = "Nun müsst Ihr alle gegnerischen Teams besiegen, um zum Sieger dieses Spiels zu werden!",
                    en = "Now you have to defeat all hostile teams to be declared victor of this game!"
                }
            },
            DeathPenaltyVictoryCondition = {
                Title = {
                    de = "Nahendes Todesurteil",
                    en = "Inpending Cataclysm",
                },
                Text  = {
                    de = "Ihr müsst vor Ablauf der Zeit alle gegnerischen Teams besiegen, sonst droht Euch ein Todesurteil!{cr}Ihr habt dafür %d Minuten Zeit!",
                    en = "You have to defeat all hostile teams. If there is no winner by then, everyone receives the death penalty!{cr}You have %d minutes!"
                }
            }
        }
    },
};

---
-- Installs the module.
-- @within MultiplayerSystem
-- @local
--
function MultiplayerSystem:Install()
    -- Using EMS?
    if self:IsUsingEMS() then
        return;
    end
    -- Load default
    local Rules = MPRuleset_Rules;
    if not Rules then
        MPRuleset_Rules = MultiplayerRules_Default;
        Rules = MPRuleset_Rules;
    end
    -- Select the rules
    self:OverrideUIStuff();
    self:SuspendEverythingAtGameStart();
    if MPRuleset_Rules.Changeable then
        self.Data.RuleSelectionActive = true;
        StartSimpleJobEx(function()
            if Logic.GetTime() > 1 then
                MPRuleset_Rules.Callbacks.OnMapLoaded();
                MultiplayerSystem.Menu.PlayerID = QuestSync:GetHostPlayerID();
                ShowOptionMenu(MultiplayerSystem.Menu);
                return true;
            end
        end);
            
        return;
    end
    MPRuleset_Rules.Callbacks.OnMapLoaded();
    self:ConfigurationFinished();
end

function MultiplayerSystem:ConfigurationFinished()
    local PlayersTable = QuestSync:GetActivePlayers();
    for i= 1, table.getn(PlayersTable), 1 do
        if MPRuleset_Rules.Limits.Hero < 0 then
            MPRuleset_Rules.Limits.Hero = 0;
        end
        if MPRuleset_Rules.Limits.Hero > 6 then
            MPRuleset_Rules.Limits.Hero = 6;
        end
        Logic.SetNumberOfBuyableHerosForPlayer(PlayersTable[i], MPRuleset_Rules.Limits.Hero);
    end
    self.Data.GameStartOffset = math.floor(Logic.GetTime() + 0.5);
    
    Message(ReplacePlacholders(self.Text.Messages.RulesDefined[QuestTools.GetLanguage()]));

    self:SetupDiplomacyForPeacetime();
    self:FillResourceHeaps(MPRuleset_Rules);
    self:GiveResources(MPRuleset_Rules);
    self:ForbidTechnologies(MPRuleset_Rules);
    self:ActivateLogicEventJobs();
    self:AddExtraStuff();

    ActivateCrushBuildingBugfix(MPRuleset_Rules.Fixes.CrushBuilding == 1);
    ActivateFormationBugfix(MPRuleset_Rules.Fixes.Formaition == 1);
    ActivateFindViewBugfix(MPRuleset_Rules.Fixes.FindView == 1);
    ActivateBlessLimitBugfix(MPRuleset_Rules.Commandment.BlessDelay > 0);
    SetBlessDelay(MPRuleset_Rules.Commandment.BlessDelay);
    ActivateWeatherChangeLimitBugfix(MPRuleset_Rules.Commandment.WeatherChangeDelay > 0);
    SetWeatherChangeDelay(MPRuleset_Rules.Commandment.WeatherChangeDelay);
    if GameSpeedSetAllowed then
        GameSpeedSetAllowed(false);
    end
    if AllowChangingWorkerAmount then
        AllowChangingWorkerAmount(MPRuleset_Rules.Commandment.Workplace == 1);
    end

    self:ResumeEverythingAtGameStart();
    MPRuleset_Rules.Callbacks.OnMapConfigured();
    self:CreateQuests(MPRuleset_Rules);
end

function MultiplayerSystem:IsUsingEMS()
    return EMS ~= nil;
end

function MultiplayerSystem:AddExtraStuff()
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

function MultiplayerSystem:SuspendEverythingAtGameStart()
    for k, v in pairs(QuestSync:GetActivePlayers()) do
        self.Data.GameStartEntities[v] = {};
        local PlayerEntities = QuestTools.GetPlayerEntities(v, 0);
        for i= 1, table.getn(PlayerEntities), 1 do
            local EntityType = Logic.GetEntityType(PlayerEntities[i]);
            if Logic.IsEntityInCategory(PlayerEntities[i], EntityCategories.Headquarters) == 0 then
                if not QuestTools.IsInTable(EntityType, self.Data.GameStartEntitiesBlacklist) then
                    local IsLeader = Logic.IsLeader(PlayerEntities[i]) == 1;
                    local Soldiers = {0};
                    if IsLeader then
                        Soldiers = {Logic.GetSoldiersAttachedToLeader(PlayerEntities[i])};
                        for j= 2, Soldiers[1]+1, 1 do
                            DestroyEntity(Soldiers[j]);
                        end
                    end
                    local ID = ReplaceEntity(PlayerEntities[i], Entities.XD_ScriptEntity);
                    table.insert(self.Data.GameStartEntities[v], {ID, EntityType, IsLeader, Soldiers[1]});
                end
            end
        end
    end
end

function MultiplayerSystem:ResumeEverythingAtGameStart()
    for k, v in pairs(QuestSync:GetActivePlayers()) do
        for i= 1, table.getn(self.Data.GameStartEntities[v]), 1 do
            local Entry = self.Data.GameStartEntities[v][i];
            local ID = ReplaceEntity(Entry[1], Entry[2]);
            if Entry[3] then
                Tools.CreateSoldiersForLeader(ID, Entry[4]);
            end
        end
        self.Data.GameStartEntities[v] = {};
    end
end

function MultiplayerSystem:OverrideUIStuff()
    BuyHeroWindow_Update_BuyHero_Orig_QSB_MultiplayerSystem = BuyHeroWindow_Update_BuyHero;
    BuyHeroWindow_Update_BuyHero = function(_Type)
        -- Hero limit
        local LimitName = MultiplayerSystem.Maps.EntityTypeToBuyHeroAvailability[_Type];
        if LimitName and MPRuleset_Rules.Heroes[LimitName] and MPRuleset_Rules.Heroes[LimitName] == 0 then
            XGUIEng.DisableButton(XGUIEng.GetCurrentWidgetID(), 1);
            return;
        end
        BuyHeroWindow_Update_BuyHero_Orig_QSB_MultiplayerSystem(_Type);
    end

    GameCallback_GUI_SelectionChanged_Orig_QSB_MultiplayerSystem = GameCallback_GUI_SelectionChanged;
    GameCallback_GUI_SelectionChanged = function()
        GameCallback_GUI_SelectionChanged_Orig_QSB_MultiplayerSystem();
        -- Rule selection
        if MultiplayerSystem.Data.RuleSelectionActive then
            for k, v in pairs{GUI.GetSelectedEntities()} do
                GUI.DeselectEntity(v);
            end
        end
    end
end

function MultiplayerSystem:GiveResources(_Data)
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

function MultiplayerSystem:SetupDiplomacyForPeacetime()
    local PlayersTable = QuestSync:GetActivePlayers();
    for i= 1, table.getn(PlayersTable), 1 do
        local Team1 = QuestSync:GetTeamOfPlayer(PlayersTable[i]);
        for j= 1, table.getn(PlayersTable), 1 do
            local Team2 = QuestSync:GetTeamOfPlayer(PlayersTable[j]);
            if PlayersTable[i] ~= PlayersTable[j] then
                SetNeutral(PlayersTable[i], PlayersTable[j]);
                if Team1 == Team2 then
                    Logic.SetShareExplorationWithPlayerFlag(PlayersTable[i], PlayersTable[j], 1);
                    Logic.SetShareExplorationWithPlayerFlag(PlayersTable[j], PlayersTable[i], 1);
                else
                    Logic.SetShareExplorationWithPlayerFlag(PlayersTable[i], PlayersTable[j], 0);
		            Logic.SetShareExplorationWithPlayerFlag(PlayersTable[j], PlayersTable[i], 0);
                end
            end
        end
    end
end

function MultiplayerSystem:SetupDiplomacy()
    local PlayersTable = QuestSync:GetActivePlayers();
    for i= 1, table.getn(PlayersTable), 1 do
        local Team1 = QuestSync:GetTeamOfPlayer(PlayersTable[i]);
        for j= 1, table.getn(PlayersTable), 1 do
            if PlayersTable[i] ~= PlayersTable[j] then
                local Team2 = QuestSync:GetTeamOfPlayer(PlayersTable[j]);
                if Team1 == Team2 then
                    SetFriendly(PlayersTable[j], PlayersTable[i]);
                    Logic.SetShareExplorationWithPlayerFlag(PlayersTable[j], PlayersTable[i], 1);
                    Logic.SetShareExplorationWithPlayerFlag(PlayersTable[i], PlayersTable[j], 1);
                else
                    SetHostile(PlayersTable[j], PlayersTable[i]);
                    Logic.SetShareExplorationWithPlayerFlag(PlayersTable[j], PlayersTable[i], 0);
                    Logic.SetShareExplorationWithPlayerFlag(PlayersTable[i], PlayersTable[j], 0);
                end
            end
        end
    end
end

function MultiplayerSystem:ActivateLogicEventJobs()
    QuestTools.StartInlineJob(
        Events.LOGIC_EVENT_ENTITY_CREATED,
        function()
            local EntityID = Event.GetEntityID();
            MultiplayerSystem:LogicEventOnEntityCreated(MPRuleset_Rules, Logic.EntityGetPlayer(EntityID), EntityID);
        end
    );

    QuestTools.StartInlineJob(
        Events.LOGIC_EVENT_ENTITY_DESTROYED,
        function()
            local EntityID = Event.GetEntityID();
            MultiplayerSystem:LogicEventOnEntityDestroyed(MPRuleset_Rules, Logic.EntityGetPlayer(EntityID), EntityID);
        end
    );

    QuestTools.StartInlineJob(
        Events.LOGIC_EVENT_ENTITY_HURT_ENTITY,
        function()
            local PlayerID = Event.GetPlayerID1();
            local EntityID = Event.GetEntityID1();
            local VictimList = {Event.GetEntityID2()};
            MultiplayerSystem:LogicEventOnEntityHurtEntity(MPRuleset_Rules, PlayerID, EntityID, VictimList);
        end
    );

    QuestTools.StartInlineJob(
        Events.LOGIC_EVENT_EVERY_TURN,
        function()
            MultiplayerSystem:LogicEventOnEveryTurn(MPRuleset_Rules);
        end
    );
end

function MultiplayerSystem:LogicEventOnEntityCreated(_Data, _PlayerID, _EntityID)
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
            for k, v in pairs(QuestTools.GetEntitiesByPrefix("P" .._PlayerID.. "VC")) do
                if QuestTools.GetDistance(_EntityID, v) < 100 then
                    IsOk = true;
                end
            end
            if IsOk == false then
                if GUI.GetPlayerID() == _PlayerID then
                    local Language = QuestTools.GetLanguage();
                    Message(ReplacePlacholders(self.Text.Messages.IllegalVillage[Language]));
                end
                Logic.HurtEntity(_EntityID, Logic.GetEntityHealth(_EntityID));
            end
        end
    end

    -- Resource heaps amount
    if _Data.Resources.ResourceHeapSize > 0 then
        if EntityTypeName == "XD_Clay1" or EntityTypeName == "XD_Iron1"
        or EntityTypeName == "XD_Stone1" or EntityTypeName == "XD_Sulfur1" then
            Logic.SetResourceDoodadGoodAmount(
                _EntityID,
                _Data.Resources.ResourceHeapSize
            );
        end
    end
end

function MultiplayerSystem:LogicEventOnEntityDestroyed(_Data, _PlayerID, _EntityID)
    -- For future rules ...
end

function MultiplayerSystem:LogicEventOnEntityHurtEntity(_Data, _PlayerID, _EntityID, _VictimList)
    -- For future rules ...
end

function MultiplayerSystem:HasPlayerVillageCenters(_PlayerID)
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

function MultiplayerSystem:GetFirstHQOfPlayer(_PlayerID)
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

function MultiplayerSystem:FillResourceHeaps(_Data)
    if _Data.Resources.ResourceHeapSize == 0 then
        return false;
    end
    -- Clay
    local Heaps = QuestTools.FindAllEntities(0, Entities.XD_Clay1);
    for i= 1, table.getn(Heaps), 1 do
        Logic.SetResourceDoodadGoodAmount(Heaps[i], _Data.Resources.ResourceHeapSize);
    end
    -- Iron
    local Heaps = QuestTools.FindAllEntities(0, Entities.XD_Iron1);
    for i= 1, table.getn(Heaps), 1 do
        Logic.SetResourceDoodadGoodAmount(Heaps[i], _Data.Resources.ResourceHeapSize);
    end
    -- Stone
    local Heaps = QuestTools.FindAllEntities(0, Entities.XD_Stone1);
    for i= 1, table.getn(Heaps), 1 do
        Logic.SetResourceDoodadGoodAmount(Heaps[i], _Data.Resources.ResourceHeapSize);
    end
    -- Sulfur
    local Heaps = QuestTools.FindAllEntities(0, Entities.XD_Sulfur1);
    for i= 1, table.getn(Heaps), 1 do
        Logic.SetResourceDoodadGoodAmount(Heaps[i], _Data.Resources.ResourceHeapSize);
    end
end

function MultiplayerSystem:ForbidTechnologies(_Data)
    local Players = QuestSync:GetActivePlayers();
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

function MultiplayerSystem:LogicEventOnEveryTurn(_Data)
    local Players = QuestSync:GetActivePlayers();
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

function MultiplayerSystem:CheckUnitOrBuildingLimit(_PlayerID, _UpgradeCategory, _Limit)
    local Players = QuestSync:GetActivePlayers();
    local Amount = 0;
    local Members = {Logic.GetBuildingTypesInUpgradeCategory(_UpgradeCategory)};
    if Members[1] > 0 and self.Maps.EntityTypeToTechnologyType[Members[2]] then
        if _Limit >= 0 then
            for i= 2, Members[1]+1, 1 do
                Amount = Amount + Logic.GetNumberOfEntitiesOfTypeOfPlayer(_PlayerID, Members[i]);
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
end

function MultiplayerSystem:PeacetimeOverMessage(_PlayerID)
    Message(ReplacePlacholders(MultiplayerSystem.Text.Messages.PeacetimeOver[QuestTools.GetLanguage()]));
    if MPRuleset_Rules.Timer.DeathPenalty > 0 then
        Message(ReplacePlacholders(MultiplayerSystem.Text.Messages.ImpendingDeath[QuestTools.GetLanguage()]));
    end
    Sound.PlayGUISound(Sounds.OnKlick_Select_kerberos, 127);
end

function Global_PeaceTimeGoal(_Behavior, _Quest)
    if MultiplayerSystem.Data.GameStartOffset + (MPRuleset_Rules.Timer.Peacetime * 60) < Logic.GetTime() then
        return true;
    end
end

function Global_VictoryConditionGoal(_Behavior, _Quest)
    local Team = QuestSync:GetTeamOfPlayer(_Quest.m_Receiver)
    local ActivePlayers = QuestSync:GetActivePlayers();
    if table.getn(ActivePlayers) > 1 then
        for k, v in pairs(ActivePlayers) do
            if v and QuestSync:GetTeamOfPlayer(v) ~= Team then
                return;
            end
        end
    end
    if QuestSync:IsMultiplayerGame() then
        return true;
    end
end

function Global_PeaceTimeReward(_Data, _Quest)
    -- Only execute this once. We are using the host player to
    -- ensure that this realy only happens once.
    local HostPlayerID = QuestSync:GetHostPlayerID();
    if HostPlayerID == _Quest.m_Receiver then
        MultiplayerSystem:SetupDiplomacy(_Quest.m_Receiver);
        MultiplayerSystem:PeacetimeOverMessage(_Quest.m_Receiver);
        MPRuleset_Rules.Callbacks.OnPeacetimeOver();
    end
end

function MultiplayerSystem:CreateQuests(_Data)
    local Language = QuestTools.GetLanguage();
    local Players = QuestSync:GetActivePlayers();

    -- Peacetime goal and description
    local PeaceTime = 0;
    local PeaceTimeDescription = nil;
    local PeaceTimeGoal = Goal_InstantSuccess();
    if _Data.Timer.Peacetime > 0 then
        PeaceTime = (_Data.Timer.Peacetime * 60) +1;
        -- Goal_NoChange is immedaitly successful when used with Goal_WinQuest
        -- thus we must create our own nochange...
        -- PeaceTimeGoal = Goal_NoChange();
        PeaceTimeGoal = Goal_MapScriptFunction("Global_PeaceTimeGoal");
        PeaceTimeDescription = {
            Title = self.Text.Quests.Peacetime.Title[Language],
            Text  = string.format(self.Text.Quests.Peacetime.Text[Language], _Data.Timer.Peacetime),
            Type  = FRAGMENTQUEST_OPEN,
            Info  = 1
        };
    end

    -- Victory condition goal and description
    local VictoryCondition = 0;
    local VictoryConditionDescription = {
        Title = self.Text.Quests.ConquestVictoryCondition.Title[Language],
        Text  = self.Text.Quests.ConquestVictoryCondition.Text[Language],
        Type  = FRAGMENTQUEST_OPEN,
        Info  = 1
    };
    local VictoryConditionGoal = Goal_MapScriptFunction("Global_VictoryConditionGoal");
    if _Data.Timer.DeathPenalty > 0 then
        VictoryCondition = (_Data.Timer.DeathPenalty * 60);
        VictoryConditionDescription = {
            Title = self.Text.Quests.DeathPenaltyVictoryCondition.Title[Language],
            Text  = string.format(self.Text.Quests.DeathPenaltyVictoryCondition.Text[Language], _Data.Timer.DeathPenalty),
            Type  = FRAGMENTQUEST_OPEN,
            Info  = 1
        };
    end

    for i= 1, table.getn(Players), 1 do
        CreateQuest {
            Name        = "MultiplayerRules_Mainquest_Player" ..Players[i],
            Receiver    = Players[i],
            Description = {
                Title = self.Text.Quests.Mainquest.Title[Language],
                Text  = string.format(self.Text.Quests.Mainquest.Text[Language], _Data.Timer.Peacetime),
                Type  = MAINQUEST_OPEN,
                Info  = 1
            },

            Goal_WinQuest("MultiplayerRules_Peacetime_Player" ..Players[i]),
            Goal_WinQuest("MultiplayerRules_VictoryCondition_Player" ..Players[i]),
            Trigger_Time(self.Data.GameStartOffset)
        };

        CreateQuest {
            Name        = "MultiplayerRules_Peacetime_Player" ..Players[i],
            Receiver    = Players[i],
            Description = PeaceTimeDescription,
            Time        = PeaceTime,

            PeaceTimeGoal,
            Reward_MapScriptFunction("Global_PeaceTimeReward"),
            Trigger_QuestActive("MultiplayerRules_Mainquest_Player" ..Players[i])
        };

        CreateQuest {
            Name        = "MultiplayerRules_VictoryCondition_Player" ..Players[i],
            Receiver    = Players[i],
            Description = VictoryConditionDescription,
            Time        = VictoryCondition,
            
            VictoryConditionGoal,
            Reprisal_Defeat(),
            Reward_Victory(),
            Trigger_QuestSuccess("MultiplayerRules_Peacetime_Player" ..Players[i], 1)
        };
    end
end

-- -------------------------------------------------------------------------- --

function MultiplayerSystem:RuleChangeSubmit(_Current)
    MultiplayerSystem.Data.RuleSelectionActive = false;
    OptionMenu:SetCurrentPage(_Current);
    OptionMenu:Render();
    MultiplayerSystem:ConfigurationFinished();
end

function MultiplayerSystem:RuleChangeToggleRule(_Group, _Subject, _Value)
    if MPRuleset_Rules[_Group] then
        if MPRuleset_Rules[_Group][_Subject] then
            MPRuleset_Rules[_Group][_Subject] = (MPRuleset_Rules[_Group][_Subject] == _Value and 0) or _Value;
        end
    end
end

function MultiplayerSystem:RuleChangeAlterValue(_Group, _Subject, _Value, _Min, _Max)
    _Min = _Min or 0;
    _Max = _Max or 1000000;
    if MPRuleset_Rules[_Group] then
        if MPRuleset_Rules[_Group][_Subject] then
            MPRuleset_Rules[_Group][_Subject] = MPRuleset_Rules[_Group][_Subject] + _Value;
            if MPRuleset_Rules[_Group][_Subject] < _Min then
                MPRuleset_Rules[_Group][_Subject] = _Max;
            end
            if MPRuleset_Rules[_Group][_Subject] > _Max then
                MPRuleset_Rules[_Group][_Subject] = _Min;
            end
        end
    end
end

-- -------------------------------------------------------------------------- --

--
-- Default Rules. DO NOT CHANGE THEM!!!
--
-- Copy this table and rename it to MPRuleset_Rules. Paste it into your
-- mapscript or load it from an extern file. If you consider using EMS
-- then you can not use this configuration. Use EMS configuration instead.
--
MultiplayerRules_Default = {
    -- Rules can be changed
    Changeable = true,

    Callbacks = {
        -- After the map has been loaded on all machines.
        OnMapLoaded = function()
        end,

        -- After configuration has been loaded
        OnMapConfigured = function()
        end,

        -- After peacetime ended (no peacetime means immediate execution after
        -- configuration is loaded)
        OnPeacetimeOver = function()
        end,
    },

    Resources = {
        -- Amount of resources in resource heaps
        ResourceHeapSize    = 2000,
        -- Choosen resource preset
        Choosen = 1,

        [1] = {
            Gold            = 1000,
            Clay            = 1500,
            Wood            = 1200,
            Stone           = 800,
            Iron            = 250,
            Sulfur          = 250,
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

    Fixes = {
        -- Crush building glitch fixed. Buildings will deselect the building
        -- and then destroy it right away without warning. (0 = off)
        CrushBuilding       = 1,

        -- Formation tech fix (0 = off)
        -- Formations will only require GT_StandingArmy researched and not 
        -- GT_Tactics to also be allowed.
        Formaition          = 1,

        -- Find View fix (0 = off)
        -- Buttons in find view appear always for an unit type. Not maching
        -- upgrade levels don't matter anymore.
        FindView            = 1,
    },

    Commandment = {

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
        InvincibleBridges   = 0,

        -- Control worker amount in workplaces (0 = off)
        Workplace           = 1,

        -- Seconds the weather can not be changed again after a change was
        -- triggered by the weather tower. (0 = off)
        WeatherChangeDelay  = 5 * 60,

        -- Seconds a player must wait between two blesses. (0 = off)
        BlessDelay          = 120,
    },

    Limits = {
        -- Limit of heroes the player can buy
        Hero         = 3,

        -- Building Limit  (-1 = off)
        Market       = 1,
        Tower        = 5,
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
};

