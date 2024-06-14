; This is a template for writing mission configs. One thing to keep in mind: For some reason CCP has added a space after some mission names.

function main()
{
	; One agent only, please
	Script[Tehbot].VariableScope.Mission.AgentList:Insert["Guy"]

	; Add the factions you don't want to fight against so missions with their logos will be declined.
	; Missions without faction logo won't be declined because they don't hurt faction standing.
	; The names don't need to be full names as long as they are not ambiguious.
	;
	Script[Tehbot].VariableScope.Mission.DontFightFaction:Insert["Amarr"]
	Script[Tehbot].VariableScope.Mission.DontFightFaction:Insert["Minmatar"]
	Script[Tehbot].VariableScope.Mission.DontFightFaction:Insert["Gallente"]
	Script[Tehbot].VariableScope.Mission.DontFightFaction:Insert["Caldari"]

	;
	; For most missions, all you need to do is use the DamageType collection to specify the mission name and the damage type.
	; Thus, the bot knows the mission is valid and what type of ammo to load.
	; For missions with faction logo in the journal, you can set the damage type to 'auto' and the bot will detect damage type automatically.
	; The bot will fly to the mission location, kill everything, and follow gates until it sees the mission is done.
	;
	Script[Tehbot].VariableScope.Mission.DamageType:Set["The Blockade", "Auto"]

	;
	; For missions without faction logo or when you want to force the damage type, you need to set the damage type manually.
	;
	Script[Tehbot].VariableScope.Mission.DamageType:Set["Attack of the Drones", "EM"]

	;
	; Some missions also require that you kill a target. To configure these, use the TargetToDestroy collection.
	; This collection requires the mission name and a search string. Most of these use the Name member. Note the single equal and the \ escaped quotes!
	;
	Script[Tehbot].VariableScope.Mission.DamageType:Set["The Right Hand Of Zazzmatazz", "Kinetic"]
	Script[Tehbot].VariableScope.Mission.TargetToDestroy:Set["The Right Hand Of Zazzmatazz", "Outpost Headquarters"]

	;
	; For some missions, you must loot an item. To configure these, use the ContainerToLoot collections.
	; This collection requires the mission name and a search string. Most of these use the Name member, but also empty wrecks need to be excluded. Note the single equal and the \ escaped quotes!
	;
	Script[Tehbot].VariableScope.Mission.DamageType:Set["Worlds Collide", "EM"]
	Script[Tehbot].VariableScope.Mission.ContainerToLoot:Set["Worlds Collide", "Damaged Heron"]
	; Script[Tehbot].VariableScope.Mission.AquireItem:Set["Worlds Collide", "Ship's Crew"]	<-- Not required anymore

	;
	; For some missions, you need a gate key to activate the acceleration gate.
	; The gate key item can either be obtained in the mission or brought to the mission.
	; Set the gate key item as below. If you already have the gate key, the bot will bring it to the mission, OTHERWISE it will search for the key in the specified container.
	;
	Script[Tehbot].VariableScope.Mission.DamageType:Set["Dread Pirate Scarlet", "Kinetic"]
	Script[Tehbot].VariableScope.Mission.GateKey:Set["Dread Pirate Scarlet", "Gate Key"]
	Script[Tehbot].VariableScope.Mission.GateKeyContainer:Set["Dread Pirate Scarlet", "Cargo Container"]
	;
	; Finally, use the BlackListedMission set to specify mission the bot should skip. TAKE NOTE, this is NOT a collection like all the above tools.
	; It only takes one argument (the name of the mission) and uses the "Add" method instead of the "Set" method.
	;
	Script[Tehbot].VariableScope.Mission.BlackListedMission:Add["Surprise Surprise"]

	echo done
}