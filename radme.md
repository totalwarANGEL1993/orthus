# Introduction

This little project should help the new mapper to create missions for the game "THE SETTLERS - Heritage of kings". It contains a quest
system inspired from the quest system from "THE SETTLERS - Rise of an empire". You can take the example mapscript in the projects 
subfolder "lua" and ajust it to your needs. After the work is done you simply run the build.bat or build.sh and pass your map and
your mapscript as arguments.

Quests can have 3 different states (inactive, active, over) and 4 different results (undecided, succes, failure, interrupted). If a quest
is won, the rewards will be triggered. If a quest fails, the reprisals instead.
 
# Editing the map
 
## Basic settings

When you open the template you see a section called *Settings*. Some ajustments can be done here by changing the variables. For example,
you can deactivate the debug by setting UseQuestTrace, UseDebugCheats and UseDebugShell to `false`.

## Quest system behavior

Your mission needs some quests! Otherwise it would be really boring. Quests are created by the function `CreateQuest`. A quest contains
a name `Name`, receiver `Receiver`, a time `Time` until it ends automatically, a description `Description` with quest type `Type`, 
quest name `Title` and quest text `Text` and finally the behaviors.

Behaviors are attached by calling their constructor. Here is an example:
```
CreateQuest {
	Name		= "ExampleQuest",
	Receiver	= 1,
	Time		= -1,
	Description = {
		Info  = 1,
		Type  = MAINQUEST_OPEN,
		Title = "Title",
		Text  = "Some text to describe the mission."
	},
	
	Goal_InstantSuccess(),
	Reward_Victory(),
	Trigger_Time(5)
}
```
For a list of behaviors look at the documentation.

The fields `Receiver`, `Time` and `Description` are optional and can be left out. If `Description` is set the quest will be automatically
add to the quest book. If the quest is won it will be marked as done. If the quest fails it is removed from the quest book. If `Time` is not
set the quest as no time limit like if it were -1. If `Receiver` is not set the receiver will be the gui player at creation time.

## Briefings

Briefings are created inside functions. The method `StartBriefing` returns the unique briefing id of the briefing when it is started.
The function the briefing is in must return this id to connect a briefing to a quest. When a briefing is connected to a quest some
behavior can be applied:

```
Trigger_Briefing("QuestWithABriefing")
```
Checks if the briefing connected to the given quest is finished. If so, the quest this behavior is attached to will be triggered.

```
Reward_Briefing("BriefingFunction")
Reprisal_Briefing("AnotherBriefingFunction")
```
Connects a briefing to a quest. It can only be one briefing connected to a quest! There is currently no way to check if the briefing was
added by a reward or a reprisal.

# Debug mode

## The shell

The debug is the most powerfull feature of the orthus quest library. You can manipulate the quest flow by typing the names of the quests
you want to change. Possible commands are `win`, `fail`, `start`, `stop` and `restart`. Each command takes an quest name.
```
win ExampleQuest
```
It is possible to manipulate multiple quests.
```
win QuestA && QuestB && QuestC
```
It is also possible to do differend commands.
```
win QuestA && QuestB & fail QuestC
```
In addition you can show the status of a quest with the command `show` and it's subcommands `names`, `active`, `detail`.

## The cheats

You can also use a variety of cheats like gaining resources and a free camera. To show the cheats use the command `help cheats`.
All cheat categories are shown. Use `help` on one ore more categories to show the actual cheats.

You can clean the ouput by using the command `clear`.
