objectdef obj_Configuration_FightOrFlight inherits obj_Configuration_Base
{
	method Initialize()
	{
		This[parent]:Initialize["FightOrFlight"]
	}

	method Set_Default_Values()
	{
		This.ConfigRef:AddSetting[FleeShieldThreshold, 0]
		This.ConfigRef:AddSetting[FleeArmorThreshold, 50]
		This.ConfigRef:AddSetting[FleeHullThreshold, 100]
		This.ConfigRef:AddSetting[FleeCapacitorThreshold, 10]
		This.ConfigRef:AddSetting[FleeLocalRedThreshold, 7]
		This.ConfigRef:AddSetting[LogLevelBar, LOG_INFO]
	}

	Setting(int, FleeShieldThreshold, SetFleeShieldThreshold)
	Setting(int, FleeArmorThreshold, SetFleeArmorThreshold)
	Setting(int, FleeHullThreshold, SetFleeHullThreshold)
	Setting(int, FleeCapacitorThreshold, SetFleeCapacitorThreshold)
	Setting(int, FleeLocalRedThreshold, SetFleeLocalRedThreshold)
	Setting(int, LogLevelBar, SetLogLevelBar)
}

objectdef obj_FightOrFlight inherits obj_StateQueue
{
	; Avoid name conflict with common config.
	variable obj_Configuration_FightOrFlight Config

	variable bool IsWarpScrambled = FALSE
	variable bool IsOtherPilotsDetected = FALSE
	variable bool IsAttackedByGankers = FALSE
	variable bool IsEngagingGankers = FALSE

	variable bool BotRunningFlag = FALSE

	variable obj_TargetList PCs
	variable obj_TargetList NPCs
	variable collection:int AttackTimestamp
	variable int64 currentTarget = 0

	method Initialize()
	{
		This[parent]:Initialize

		DynamicAddMiniMode("FightOrFlight", "FightOrFlight")
		This.PulseFrequency:Set[500]

		This.NonGameTiedPulse:Set[TRUE]

		This:BuildPC
		;NPCs:AddAllNPCs

		This.LogLevelBar:Set[${Config.LogLevelBar}]
	}

	method Start()
	{
		AttackTimestamp:Clear

		if ${This.IsIdle}
		{
			This:LogInfo["Starting"]
			This:QueueState["FightOrFlight"]
		}
	}

	method BuildPC()
	{
		PCs:ClearQueryString
		PCs:AddPCTargetingMe
		PCs:AddAllPC
	}

	method DetectOtherPilots(int threshold)
	{
		This:BuildPC
		PCs:RequestUpdate

		variable iterator pilotIterator
		PCs.TargetList:GetIterator[pilotIterator]
		variable int detected = 0
		; This:LogDebug[${threshold} total ${PCs.TargetList.Used}]
		if ${pilotIterator:First(exists)}
		{
			do
			{
				; Oh it's me.
				if ${pilotIterator.Value.ID.Equal[${MyShip.ID}]}
				{
					continue
				}

				; ${pilotIterator.Value.Mode} == MOVE_WARPING
				; No longer ignore warping pilots for they can still shoot me and the last one may cause the bot start/stop repeatly.

				; Lock and destroy everything only in vigilant mode.
				if (${threshold} > 1) && (${pilotIterator.Value.Type.Equal["Capsule"]} || ${pilotIterator.Value.Type.Find["Shuttle"]})
				{
					; This:LogDebug[${threshold} skipping ${pilotIterator.Value.Type}]
					continue
				}

				detected:Inc[1]
				; This:LogDebug["${detected} - ${pilotIterator.Value.Name} - ${pilotIterator.Value.Type} - ${pilotIterator.Value.IsTargetingMe} - ${pilotIterator.Value.IsLockedTarget} - ${pilotIterator.Value.ToAttacker.IsCurrentlyAttacking}"]

			}
			while ${pilotIterator:Next(exists)}
		}

		if ${detected} >= ${threshold}
		{
			This:LogDebug["Detected ${detected} other pilot nearby."]
		}

		if ${detected} >= ${threshold}
		{
			IsOtherPilotsDetected:Set[TRUE]
		}
		else
		{
			IsOtherPilotsDetected:Set[FALSE]
		}
	}

	method DetectGankers()
	{
		variable index:attacker attackers
		variable iterator attackerIterator
		Me:GetAttackers[attackers]
		attackers:GetIterator[attackerIterator]
		variable bool detected = FALSE
		if ${attackerIterator:First(exists)}
		{
			do
			{
				if ${attackerIterator.Value.IsPC}
				{
					This:LogCritical["Being attacked by player: \ar${attackerIterator.Value.Name} in a ${attackerIterator.Value.Type}"]

					; if ${AttackTimestamp.Element[${attackerIterator.Value.Name.Escape}](exists)}
					; {
					; 	variable int lastAttackTimestamp
					; 	lastAttackTimestamp:Set[${AttackTimestamp.Element[${attackerIterator.Value.Name.Escape}]}]
					; 	This:LogDebug["lastattacktimestamp ${lastAttackTimestamp}"]
					; 	variable int secondsSinceAttacked
					; 	secondsSinceAttacked:Set[${Math.Calc[${Utility.EVETimestamp} - ${lastAttackTimestamp}]}]
					; 	This:LogDebug["secondsSinceAttacked ${secondsSinceAttacked}"]
					; }

					AttackTimestamp:Set[${attackerIterator.Value.Name.Escape}, ${Utility.EVETimestamp}]
					This:LogDebug["Update attack timer ${attackerIterator.Value.Name.Escape} -- ${Utility.EVETimestamp}"]
					detected:Set[TRUE]
				}
			}
			while ${attackerIterator:Next(exists)}
		}

		IsAttackedByGankers:Set[${detected}]
	}

	; From either PC or NPC.
	method DetectWarpScrambleStatus()
	{
		variable index:jammer jammers
		variable iterator jammerIterator
		Me:GetJammers[jammers]
		jammers:GetIterator[jammerIterator]
		variable bool detected = FALSE
		if ${jammerIterator:First(exists)}
		{
			do
			{
				variable index:string jams
				variable iterator jamsIterator
				jammerIterator.Value:GetJams[jams]
				jams:GetIterator[jamsIterator]
				if ${jamsIterator:First(exists)}
				{
					do
					{
						; Either scramble or disrupt.
						if ${jamsIterator.Value.Lower.Find["warp"]}
						{
							detected:Set[TRUE]
						}
					}
					while ${jamsIterator:Next(exists)}
				}
			}
			while ${jammerIterator:Next(exists)}
		}

		IsWarpScrambled:Set[${detected}]
	}

	member:bool FightOrFlight()
	{
		; Do not disturb manual operation.
		if ${${CommonConfig.Tehbot_Mode}.IsIdle}
		{
			This:LogDebug["Bot is not running."]
			BotRunningFlag:Set[FALSE]
			return FALSE
		}
		else
		{
			BotRunningFlag:Set[TRUE]
		}

		IsEngagingGankers:Set[FALSE]

		if ${Me.InStation} && !${This.LocalSafe}
		{
			This:LogInfo["Detected many hostile pilots in local, wait until they are gone."]
			${CommonConfig.Tehbot_Mode}:Stop
			Move:Stop
			This:QueueState["LocalSafe"]
			This:QueueState["ResumeBot"]
			This:QueueState["FightOrFlight"]
			return TRUE
		}
		elseif ${Me.InStation}
		{
			return FALSE
		}

		; While currently jumping, Me.InSpace is false and status numbers will be null.
		if !${Client.InSpace}
		{
			This:LogDebug["Not in space, jumping?"]
			return FALSE
		}

		This:DetectGankers
		; When attacked, enter Engage phase
		if ${IsAttackedByGankers}
		{
			This:LogCritical["Entering engage ganker stage."]
			${CommonConfig.Tehbot_Mode}:Stop
			Ship.ModuleList_Siege:ActivateOne
			This:QueueState["EngageGankers", 500, FALSE]
			return TRUE
		}

		This:DetectOtherPilots[69]
		if ${IsOtherPilotsDetected}
		{
			This:UnlockNPCsAndLockPCs
			; Disable this until we can reload weapon and ancillary repairers seperately.
			; Ship.ModuleList_Weapon:ReloadDefaultAmmo
		}
		else
		{
			;Mission.NPCs.AutoLock:Set[TRUE]
			;Mission.ActiveNPCs.AutoLock:Set[TRUE]
		}

		; Flee to a station in the system if not warpscrambled && (in egg or (low hp && not pvp fight) or module offline)
		; ${Me.ToEntity.IsWarpScrambled} is bugged.
		This:DetectWarpScrambleStatus
		if ${IsWarpScrambled}
		{
			This:LogDebug["IsWarpScrambled"]
			return FALSE
		}

		if ${MyShip.ToEntity.Type.Equal["Capsule"]}
		{
			This:LogInfo["I am in egg, I should flee."]
			Move:Stop
			This:QueueState["FleeToStation"]
			This:QueueState["FightOrFlight"]
			return TRUE
		}
		elseif ${MyShip.ShieldPct.Int} < ${Config.FleeShieldThreshold} || \
			${MyShip.ArmorPct.Int} < ${Config.FleeArmorThreshold} || \
			${MyShip.StructurePct.Int} < ${Config.FleeHullThreshold} || \
			${MyShip.CapacitorPct.Int} < ${Config.FleeCapacitorThreshold}
		{
			; TODO align and 75% speed before entering flee status, in case last second.
			This:LogInfo["PVE Low HP - Shield: ${MyShip.ShieldPct.Int}%, Armor: ${MyShip.ArmorPct.Int}%, Hull: ${MyShip.StructurePct.Int}%, Capacitor: ${MyShip.CapacitorPct.Int}%, I should flee."]
			Move:Stop
			This:QueueState["FleeToStation"]
			This:QueueState["Repair"]
			This:QueueState["LocalSafe"]
			This:QueueState["ResumeBot"]
			This:QueueState["FightOrFlight"]
			return TRUE
		}
		elseif !${Move.Traveling} && !${This.LocalSafe}
		{
			This:LogInfo["Detected many red in local, I should flee."]
			Move:Stop
			This:QueueState["FleeToStation"]
			This:QueueState["Repair"]
			This:QueueState["LocalSafe"]
			This:QueueState["ResumeBot"]
			This:QueueState["FightOrFlight"]
			return TRUE
		}
		; TODO flee when module offline.(put online).

		return FALSE
	}

	member:bool EngageGankers(bool allowResume)
	{
		if ${Me.InStation}
		{
			; Pod killed.
			This:LogCritical["Pod killed."]
			IsEngagingGankers:Set[FALSE]
			This:QueueState["FightOrFlight"]
			return TRUE
		}

		if !${Client.InSpace}
		{
			; Ship Destroyed?
			return FALSE
		}

		IsEngagingGankers:Set[TRUE]

		; Overload modules.
		Ship.ModuleList_Weapon:SetOverloadHPThreshold[50]
		Ship.ModuleList_ActiveResists:SetOverloadHPThreshold[50]
		Ship.ModuleList_Regen_Shield:SetOverloadHPThreshold[50]
		Ship.ModuleList_Ancillary_Shield_Booster:SetOverloadHPThreshold[50]
		Ship.ModuleList_Repair_Armor:SetOverloadHPThreshold[50]

		This:DetectWarpScrambleStatus
		if ${IsWarpScrambled}
		{
			This:LogDebug["WarpScrambled by gankers."]
		}

		if !${IsWarpScrambled} && ${MyShip.ToEntity.Type.Equal["Capsule"]}
		{
			This:LogInfo["I am in egg, I should flee."]
			This:QueueState["FleeToStation"]
			This:QueueState["FightOrFlight"]
			return TRUE
		}

		; if !${MyShip.ToEntity.Type.Equal["Capsule"]} && FindMineWreck
		; {
		; 	Destroy or loot my wreck
		; 	Then warpoff
		;	TODO add detection in Traveling status when
		;			scrambled when ships shows aligned but not really in warp.
		; 	and do something.
		; }

		This:UnlockNPCsAndLockPCs

		Ship.ModuleList_Siege:ActivateOne

		This:DetectGankers
		;;;;;;;;;;;;;;;;;;;;PickTarget;;;;;;;;;;;;;;;;;;;;
		if !${Entity[${currentTarget}]} || ${Entity[${currentTarget}].IsMoribund} || !(${Entity[${currentTarget}].IsLockedTarget} || ${Entity[${currentTarget}].BeingTargeted})
		{
			currentTarget:Set[0]
		}

		variable iterator lockedTargetIterator
		variable iterator activeNeuterIterator
		Ship:BuildActiveNeuterList

		if ${currentTarget} != 0
		{
			if ${Ship.ActiveNeuterList.Used}
			{
				if !${Ship.ActiveNeuterSet.Contains[${currentTarget}]}
				{
					; The only jammer we want to priortize is energy neutralizer.
					Ship.ActiveNeuterList:GetIterator[activeNeuterIterator]
					do
					{
						if ${Entity[${activeNeuterIterator.Value}].IsLockedTarget}
						{
							currentTarget:Set[${activeNeuterIterator.Value}]
							This:LogInfo["Switching target to active neutralizer \ar${Entity[${currentTarget}].Name}"]
							break
						}
					}
					while ${activeNeuterIterator:Next(exists)}
				}
			}
		}
		elseif ${PCs.LockedTargetList.Used}
		{
			; Need to re-pick from locked target
			if ${Ship.ActiveNeuterList.Used}
			{
				Ship.ActiveNeuterList:GetIterator[activeNeuterIterator]
				do
				{
					if ${Entity[${activeNeuterIterator.Value}].IsLockedTarget}
					{
						currentTarget:Set[${activeNeuterIterator.Value}]
						This:LogInfo["Targeting active neutralizer \ar${Entity[${currentTarget}].Name}"]
						break
					}
				}
				while ${activeNeuterIterator:Next(exists)}
			}

			if ${currentTarget} == 0
			{
				; Priortize the slowest target which is not capsule.
				variable int64 CapsuleTarget = 0
				PCs.LockedTargetList:GetIterator[lockedTargetIterator]
				do
				{
					variable int lastAttackTimestamp
					lastAttackTimestamp:Set[${AttackTimestamp.Element[${lockedTargetIterator.Value.Name.Escape}]}]
					variable int secondsSinceAttacked
					secondsSinceAttacked:Set[${Math.Calc[${Utility.EVETimestamp} - ${lastAttackTimestamp}]}]
					This:LogDebug["Seconds since attacker last attacked: \ar${secondsSinceAttacked}"]
					if ${secondsSinceAttacked} >= 300
					{
						continue
					}

					if ${lockedTargetIterator.Value.Type.Equal["Capsule"]}
					{
						CapsuleTarget:Set[${lockedTargetIterator.Value}]
					}
					elseif ${currentTarget} == 0 || ${Entity[${currentTarget}].Velocity} > ${Entity[${lockedTargetIterator.Value}].Velocity}
					{
						currentTarget:Set[${lockedTargetIterator.Value}]
					}
				}
				while ${lockedTargetIterator:Next(exists)}

				if ${currentTarget} == 0
				{
					currentTarget:Set[${CapsuleTarget}]
				}
			}
			This:LogInfo["Primary target: \ar${Entity[${currentTarget}].Name}, effciency ${Math.Calc[${Ship.ModuleList_Weapon.DamageEfficiency[${currentTarget}]} * 100].Deci}%."]
		}

		;;;;;;;;;;;;;;;;;;;;Shoot;;;;;;;;;;;;;;;;;;;;;
		if ${currentTarget} != 0 && ${Entity[${currentTarget}]} && !${Entity[${currentTarget}].IsMoribund}
		{
			Ship.ModuleList_Siege:ActivateOne
			if ${Ship.ModuleList_Weapon.Range} > ${Entity[${currentTarget}].Distance}
			{
				; This:LogDebug["Pew Pew: \ar${Entity[${currentTarget}].Name}"]
				Ship.ModuleList_Weapon:ActivateAll[${currentTarget}]
				Ship.ModuleList_TrackingComputer:ActivateFor[${currentTarget}]
			}
			if ${Entity[${currentTarget}].Distance} <= ${Ship.ModuleList_TargetPainter.Range}
			{
				Ship.ModuleList_TargetPainter:ActivateAll[${currentTarget}]
			}
			; 'Effectiveness Falloff' is not read by ISXEVE, but 20km is a generally reasonable range to activate the module
			if ${Entity[${currentTarget}].Distance} <= ${Math.Calc[${Ship.ModuleList_StasisGrap.Range} + 20000]}
			{
				Ship.ModuleList_StasisGrap:ActivateAll[${currentTarget}]
			}
			if ${Entity[${currentTarget}].Distance} <= ${Ship.ModuleList_StasisWeb.Range}
			{
				Ship.ModuleList_StasisWeb:ActivateAll[${currentTarget}]
			}
		}

		This:DetectOtherPilots[69]
		if ${IsOtherPilotsDetected}
		{
			; Remain vigilant once entered engage stage.
			return FALSE
		}
		; not detected

		if ${allowResume}
		{
			; Reset overload.
			Ship.ModuleList_Weapon:SetOverloadHPThreshold[100]
			Ship.ModuleList_ActiveResists:SetOverloadHPThreshold[100]
			Ship.ModuleList_Regen_Shield:SetOverloadHPThreshold[100]
			Ship.ModuleList_Ancillary_Shield_Booster:SetOverloadHPThreshold[100]
			Ship.ModuleList_Repair_Armor:SetOverloadHPThreshold[100]

			This:QueueState["ResumeBot"]
			This:QueueState["FightOrFlight"]
			IsEngagingGankers:Set[FALSE]
			PCs.AutoLock:Set[FALSE]
			return TRUE
		}
		else
		{
			; There is a short time after ship destruction that pod is not detected, we may overlook the
			; last pod. detect twice to avoid this. (No big deal anyway)
			This:QueueState["EngageGankers", 3000, TRUE]
			return TRUE
		}
	}

	member:int LocalHostilePilots()
	{
		variable index:pilot pilotIndex
		EVE:GetLocalPilots[pilotIndex]

		if ${pilotIndex.Used} < ${Config.FleeLocalRedThreshold}
		{
			return 0
		}

		variable int count = 0
		variable iterator pilotIterator
		pilotIndex:GetIterator[pilotIterator]

		if ${pilotIterator:First(exists)}
		{
			do
			{
				if ${Me.CharID} == ${pilotIterator.Value.CharID} || ${pilotIterator.Value.ToFleetMember(exists)}
				{
					continue
				}
				; echo ${pilotIterator.Value.Name} ${pilotIterator.Value.CharID} ${pilotIterator.Value.Corp.ID} ${pilotIterator.Value.AllianceID}
				; echo ${pilotIterator.Value.Standing.MeToPilot}
				; echo ${pilotIterator.Value.Standing.MeToCorp}
				; echo ${pilotIterator.Value.Standing.MeToAlliance}
				if ${pilotIterator.Value.Standing.MeToPilot} < 0 || ${pilotIterator.Value.Standing.MeToCorp} < 0 || ${pilotIterator.Value.Standing.MeToAlliance}
				{
					count:Inc[1]
				}
			}
			while ${pilotIterator:Next(exists)}

		}

		return ${count}
	}

    ; Both a boolean member and a state.
	member:bool LocalSafe()
	{
		if ${This.LocalHostilePilots} < 8
		{
			return TRUE
		}
		return FALSE
	}

	member:bool Repair()
	{
		if ${Me.InStation} && ${Utility.Repair}
		{
			This:InsertState["Repair", 2000]
			return TRUE
		}

		return TRUE
	}

	member:bool ResumeBot(bool Undock = FALSE)
	{
		if ${BotRunningFlag}
		{
			This:LogInfo["Resuming bot."]

			; To avoid going back to agent to reload ammos.
			if ${Undock}
			{
				Move:Undock
			}

			Ship.ModuleList_Siege.Allowed:Set[TRUE]
			${CommonConfig.Tehbot_Mode}:Start
		}

		return TRUE
	}

	member:bool FleeToStation()
	{
		if ${Me.InStation}
		{
			This:LogInfo["Dock called, but we're already instation!"]
			return TRUE
		}

		Ship.ModuleList_Siege.Allowed:Set[FALSE]
		if ${Ship.ModuleList_Siege.ActiveCount}
		{
			Ship.ModuleList_Siege:DeactivateAll
		}

		variable int64 StationID
		StationID:Set[${Entity["CategoryID = CATEGORYID_STATION"].ID}]
		if ${Entity[${StationID}](exists)}
		{
			This:LogInfo["Fleeing to station ${Entity[${StationID}].Name}."]
			Move.Traveling:Set[FALSE]
			Move:Entity[${StationID}]
			This:InsertState["Traveling"]
			return TRUE
		}
		else
		{
			This:LogCritical["No stations in this system!"]
			return TRUE
		}
	}

	member:bool Traveling()
	{
		if ${Me.InSpace}
		{
			if ${Cargo.Processing} || ${Move.Traveling} || ${Me.ToEntity.Mode} == MOVE_WARPING
			{
				if ${Ship.ModuleList_Siege.ActiveCount}
				{
					Ship.ModuleList_Siege:DeactivateAll
				}

				if ${Ship.ModuleList_Regen_Shield.InactiveCount} && (${MyShip.ShieldPct.Int} < 100 && ${MyShip.CapacitorPct.Int} > 15)
				{
					Ship.ModuleList_Regen_Shield:ActivateAll
				}
				if ${Ship.ModuleList_Regen_Shield.ActiveCount} && (${MyShip.ShieldPct.Int} == 100 || ${MyShip.CapacitorPct.Int} < 15) /* Deactivate to prevent hardener off */
				{
					Ship.ModuleList_Regen_Shield:DeactivateAll
				}
				if ${Ship.ModuleList_Repair_Armor.InactiveCount} && (${MyShip.ArmorPct.Int} < 100 && ${MyShip.CapacitorPct.Int} > 15)
				{
					Ship.ModuleList_Repair_Armor:ActivateAll
				}
				if ${Ship.ModuleList_Repair_Armor.ActiveCount} && (${MyShip.ArmorPct.Int} == 100 || ${MyShip.CapacitorPct.Int} < 15) /* Deactivate to prevent hardener off */
				{
					Ship.ModuleList_Repair_Armor:DeactivateAll
				}
			}

			This:DetectWarpScrambleStatus
			if ${IsWarpScrambled}
			{
				This:LogCritical["Warp Scrambled while trying to warp"]
				return FALSE
			}
			elseif ${MyShip.ToEntity.Velocity} < 10000
			{
				; Haven't entered real warp stage and not scrambled, can scoop drones.
				DroneControl:Recall
			}
			elseif !${${CommonConfig.Tehbot_Mode}.IsIdle}
			{
				; Only stop bot after entered real warping, in case ship got scrambled in the last second.
				This:LogInfo["Stopping bot at velocity ${MyShip.ToEntity.Velocity}"]
				${CommonConfig.Tehbot_Mode}:Stop
			}

			return FALSE
		}

		if !${Me.InStation}
		{
			return FALSE
		}

		return TRUE
	}

	method UnlockNPCsAndLockPCs()
	{
		Mission.NPCs.AutoLock:Set[FALSE]
		Mission.ActiveNPCs.AutoLock:Set[FALSE]

		variable iterator npcIterator
		;NPCs:AddAllNPCs
		;NPCs:RequestUpdate
		;NPCs.LockedTargetList:GetIterator[npcIterator]
		if ${npcIterator:First(exists)}
		{
			do
			{
				if ${npcIterator.Value.ID(exists)} && ${npcIterator.Value.IsNPC} && ${npcIterator.Value.IsLockedTarget}
				{
					This:LogDebug["Unlocking NPC ${npcIterator.Value.Name}."]
					Entity[${npcIterator.Value.ID}]:UnlockTarget
				}
			}
			while ${npcIterator:Next(exists)}
		}

		variable int MaxTarget
		MaxTarget:Set[${Utility.Min[${Me.MaxLockedTargets}, ${MyShip.MaxLockedTargets}]}]

		This:BuildPC
		PCs:RequestUpdate
		PCs.MinLockCount:Set[${MaxTarget}]
		PCs.AutoLock:Set[TRUE]
	}
}