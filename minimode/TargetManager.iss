objectdef obj_Configuration_TargetManager inherits obj_Configuration_Base
{
	
	method Initialize()
	{
		This[parent]:Initialize["TargetManager"]
		
		LavishSettings[StandingsData]:Clear
		LavishSettings[ThreatLevel]:Clear
		LavishSettings:AddSet[StandingsData]
		LavishSettings:AddSet[ThreatLevel]

		if ${CONFIG_PATH.FileExists["${CONFIG_FILE}"]}
		{
			LavishSettings[StandingsData]:Import["${CONFIG_PATH}/${CONFIG_FILE}"]
			LavishSettings[ThreatLevel]:Import["${CONFIG_PATH}/${CONFIG_FILE2}"]
		}

	}
	

	method Set_Default_Values()
	{
		This.ConfigRef:AddSetting[RemoteRepTargetSlots, 2]
		This.ConfigRef:AddSetting[EWARTargetSlots, 2]
		This.ConfigRef:AddSetting[OffenseTargetSlots, 2]
		This.ConfigRef:AddSetting[PriorityTargetSlots, 1]
		This.ConfigRef:AddSetting[BroadcastPriorityTargets, FALSE]
		This.ConfigRef:AddSetting[IgnoreNPCTargets, FALSE]
		This.ConfigRef:AddSetting[IgnorePCTargets, TRUE]
		This.ConfigRef:AddSetting[AggressiveMode, TRUE]
		This.ConfigRef:AddSetting[RangeLimit, TRUE]
		This.ConfigRef:AddSetting[LogLevelBar, LOG_INFO]
	}


	Setting(int, RemoteRepTargetSlots, SetRemoteRepTargetSlots)
	Setting(int, EWARTargetSlots, SetEWARTargetSlotsd)
	Setting(int, OffenseTargetSlots, SetOffenseTargetSlots)
	Setting(int, OffenseTargetSlots, SetPriorityTargetSlots)
	Setting(bool, BroadcastPriorityTargets, SetBroadcastPriorityTargets)
	Setting(bool, IgnoreNPCTargets, SetIgnoreNPCTargets)
	Setting(bool, IgnorePCTargets, SetIgnorePCTargets)
	Setting(bool, AggressiveMode, SetAggressiveMode)
	Setting(bool, RangeLimit, SetRangeLimit)

	
	Setting(int, LogLevelBar, SetLogLevelBar)
}

objectdef obj_TargetManager inherits obj_StateQueue
{
	; Avoid name conflict with common config.
	variable obj_Configuration_TargetManager Config
	
	variable int MaxTarget = ${MyShip.MaxLockedTargets}

	
	;Going to go back to using Tehbot's built in targeting because my own isn't working out too well.
	variable obj_TargetList NPCs
	variable obj_TargetList ActiveNPCs
	variable obj_TargetList PCs
	variable obj_TargetList Marshalz
	variable obj_TargetList RemoteRepJerks
	variable obj_TargetList StarvingJerks
	variable obj_TargetList Leshaks
	variable obj_TargetList Kikimoras
	variable obj_TargetList Damaviks
	variable obj_TargetList Vedmaks
	variable obj_TargetList Drekavacs
	variable obj_TargetList Cynabals
	variable obj_TargetList Dramiels


	variable int maxAttackTime
	variable int switchTargetAfter = 120
	variable int64 BurstTimer

	method Initialize()
	{
		This[parent]:Initialize

		DynamicAddMiniMode("TargetManager", "TargetManager")
		This.PulseFrequency:Set[1000]

		This.NonGameTiedPulse:Set[TRUE]


		This.LogLevelBar:Set[${Config.LogLevelBar}]
		
		NPCs.NeedUpdate:Set[FALSE]
		ActiveNPCs.NeedUpdate:Set[FALSE]
		PCs.NeedUpdate:Set[FALSE]
		Marshalz.NeedUpdate:Set[FALSE]
		RemoteRepJerks.NeedUpdate:Set[FALSE]
		StarvingJerks.NeedUpdate:Set[FALSE]
		Leshaks.NeedUpdate:Set[FALSE]
		Kikimoras.NeedUpdate:Set[FALSE]
		Damaviks.NeedUpdate:Set[FALSE]
		Vedmaks.NeedUpdate:Set[FALSE]
		Drekavacs.NeedUpdate:Set[FALSE]
		Cynabals.NeedUpdate:Set[FALSE]
		Dramiels.NeedUpdate:Set[FALSE]
		
	}

	method Start()
	{
		AttackTimestamp:Clear

		if ${This.IsIdle}
		{
			This:LogInfo["Starting"]
			This:QueueState["TargetManager"]
		}
	}
	
	method Stop()
	{
		This:Clear
	}
	
	;Welp, time to just reuse a bunch of existing stuff I barely understand.
	;Update - 5 months later, I now understand all of this quite well.
	member:bool UpdateNPCs()
	{
		NPCs:RequestUpdate
		return TRUE
	}
	
	method BuildNpcQueries()
	{
		variable iterator classIterator
		variable iterator groupIterator
		variable string groups = ""
		variable string seperator = ""

		if ${CommonConfig.Tehbot_Mode.Equal["Abyssal"]}
		{
			Dramiels:ClearQueryString
			Cynabals:ClearQueryString
			Drekavacs:ClearQueryString
			Vedmaks:ClearQueryString
			Damaviks:ClearQueryString
			Kikimoras:ClearQueryString
			Leshaks:ClearQueryString
			StarvingJerks:ClearQueryString
			RemoteRepJerks:ClearQueryString
			Marshalz:ClearQueryString
		}
		ActiveNPCs:ClearQueryString
		


		if ${CommonConfig.Tehbot_Mode.Equal["Abyssal"]}
		{
			Dramiels:AddQueryString["Name =- \"Dramiel\" && !IsMoribund"]
			Cynabals:AddQueryString["Name =- \"Cynabal\" && !IsMoribund"]
			Drekavacs:AddQueryString["Name =- \"Drekavac\" && !IsMoribund"]
			Vedmaks:AddQueryString["Name =- \"Vedmak\" && !IsMoribund"]
			Damaviks:AddQueryString["Name =- \"Damavik\" && !IsMoribund"]
			Kikimoras:AddQueryString["Name =- \"Kikimora\" && !IsMoribund"]
			Leshaks:AddQueryString["Name =- \"Leshak\" && !IsMoribund"]	
			StarvingJerks:AddQueryString["Name =- \"Starving\" && !IsMoribund"]
			Marshalz:AddQueryString["TypeID == 56177 || TypeID == 56176 || TypeID == 56178 && !IsMoribund"]
			RemoteRepJerks:AddQueryString["Name =- \"Renewing\" || Name =- \"Fieldweaver\" || Name =- \"Plateforger\" || Name =- \"Burst\"|| Name =- \"Preserver\" && !IsMoribund"]
		}

		variable int range = ${Math.Calc[${MyShip.MaxTargetRange} * .95]}

		; Add ongoing jammers.
		variable index:jammer attackers
		variable iterator attackerIterator
		Me:GetJammers[attackers]
		attackers:GetIterator[attackerIterator]
		if ${attackerIterator:First(exists)}
		do
		{
			variable index:string jams
			variable iterator jamsIterator
			attackerIterator.Value:GetJams[jams]
			jams:GetIterator[jamsIterator]
			if ${jamsIterator:First(exists)}
			{
				do
				{
					; Both scramble and disrupt
					if ${jamsIterator.Value.Lower.Find["warp"]}
					{
						groups:Concat[${seperator}ID =- "${attackerIterator.Value.ID}"]
						seperator:Set[" || "]
					}
					elseif ${jamsIterator.Value.Lower.Find["trackingdisrupt"]}
					{
						groups:Concat[${seperator}ID =- "${attackerIterator.Value.ID}"]
						seperator:Set[" || "]
					}
					elseif ${jamsIterator.Value.Lower.Find["electronic"]}
					{
						groups:Concat[${seperator}ID =- "${attackerIterator.Value.ID}"]
						seperator:Set[" || "]
					}
					; Energy drain and neutralizer
					elseif ${jamsIterator.Value.Lower.Find["energy"]}
					{
						groups:Concat[${seperator}ID =- "${attackerIterator.Value.ID}"]
						seperator:Set[" || "]
					}
					elseif ${jamsIterator.Value.Lower.Find["remotesensordamp"]}
					{
						groups:Concat[${seperator}ID =- "${attackerIterator.Value.ID}"]
						seperator:Set[" || "]
					}
					elseif ${jamsIterator.Value.Lower.Find["webify"]}
					{
						groups:Concat[${seperator}ID =- "${attackerIterator.Value.ID}"]
						seperator:Set[" || "]
					}
					elseif ${jamsIterator.Value.Lower.Find["targetpaint"]}
					{
						groups:Concat[${seperator}ID =- "${attackerIterator.Value.ID}"]
						seperator:Set[" || "]
					}
					elseif ${jamsIterator.Value.Lower.Find["ewGuidanceDisrupt"]}
					{
						groups:Concat[${seperator}ID =- "${attackerIterator.Value.ID}"]
						seperator:Set[" || "]
					}					
					else
					{
						This:LogCritical["unknown EW ${jamsIterator.Value}"]
					}
				}
				while ${jamsIterator:Next(exists)}
			}
		}
		while ${attackerIterator:Next(exists)}

		ActiveNPCs:AddQueryString["IsNPC && !IsMoribund && (${groups})"]
		ActiveNPCs:AddQueryString["IsNPC && !IsMoribund && IsWarpScramblingMe"]

		; Add potential jammers.
		seperator:Set[""]
		groups:Set[""]
		PrioritizedTargets.Scramble:GetIterator[groupIterator]
		if ${groupIterator:First(exists)}
		{
			do
			{
				groups:Concat[${seperator}Name =- "${groupIterator.Value}"]
				seperator:Set[" || "]
			}
			while ${groupIterator:Next(exists)}
		}
		ActiveNPCs:AddQueryString["IsNPC && !IsMoribund && (${groups})"]

		seperator:Set[""]
		groups:Set[""]
		PrioritizedTargets.Neut:GetIterator[groupIterator]
		if ${groupIterator:First(exists)}
		{
			do
			{
				groups:Concat[${seperator}Name =- "${groupIterator.Value}"]
				seperator:Set[" || "]
			}
			while ${groupIterator:Next(exists)}
		}
		ActiveNPCs:AddQueryString["IsNPC && !IsMoribund && (${groups})"]

		seperator:Set[""]
		groups:Set[""]
		PrioritizedTargets.ECM:GetIterator[groupIterator]
		if ${groupIterator:First(exists)}
		{
			do
			{
				groups:Concat[${seperator}Name =- "${groupIterator.Value}"]
				seperator:Set[" || "]
			}
			while ${groupIterator:Next(exists)}
		}
		ActiveNPCs:AddQueryString["IsNPC && !IsMoribund && (${groups})"]

		NPCData.BaseRef:GetSetIterator[classIterator]
		if ${classIterator:First(exists)}
		{
			do
			{
				seperator:Set[""]
				groups:Set[""]
				classIterator.Value:GetSettingIterator[groupIterator]
				if ${groupIterator:First(exists)}
				{
					do
					{
						groups:Concat["${seperator}GroupID = ${groupIterator.Key}"]
						seperator:Set[" || "]
					}
					while ${groupIterator:Next(exists)}
				}
				ActiveNPCs:AddQueryString["IsNPC  && !IsMoribund && (${groups})"]
			}
			while ${classIterator:Next(exists)}
		}

		;ActiveNPCs:AddTargetingMe

		if ${Config.AggressiveMode}
		{
			ActiveNPCs:AddAllNPCs
			if ${targetToDestroy.NotNULLOrEmpty}
			{
				ActiveNPCs:AddQueryString[${targetToDestroy.Escape}]
			}
		}

		NPCs:ClearQueryString
		NPCs:AddAllNPCs
		NPCs:AddQueryString["GroupID = 4033"]

		if ${Mission.Config.IgnoreNPCSentries}
		{
			ActiveNPCs:AddTargetExceptionByPartOfName["Battery"]
			ActiveNPCs:AddTargetExceptionByPartOfName["Batteries"]
			ActiveNPCs:AddTargetExceptionByPartOfName["Sentry Gun"]
			ActiveNPCs:AddTargetExceptionByPartOfName["Tower Sentry"]

			NPCs:AddTargetExceptionByPartOfName["Battery"]
			NPCs:AddTargetExceptionByPartOfName["Batteries"]
			NPCs:AddTargetExceptionByPartOfName["Sentry Gun"]
			NPCs:AddTargetExceptionByPartOfName["Tower Sentry"]
		}
		;echo ${ActiveNPCs.LockedTargetList.Used} activenpcs
		;echo ${NPCs.LockedTargetList.Used} npcs
	}
	
	method PlagiarisedOffense()
	{
		variable bool allowSiegeModule
		; Mission controls this itself.
		if !${CommonConfig.Tehbot_Mode.Equal["Mission"]}
		{
			allowSiegeModule:Set[TRUE]
		}
		
		if !${Entity[${CurrentOffenseTarget}]} || ${Entity[${CurrentOffenseTarget}].IsMoribund} || !(${Entity[${CurrentOffenseTarget}].IsLockedTarget} || ${Entity[${CurrentOffenseTarget}].BeingTargeted})
		{
			finalizedTM:Set[FALSE]
			CurrentOffenseTarget:Set[0]
			maxAttackTime:Set[0]
		}
		elseif (${maxAttackTime} > 0 && ${LavishScript.RunningTime} > ${maxAttackTime})
		{
			This:LogInfo["Resseting target for the current one is taking too long."]
			CurrentOffenseTarget:Set[0]
			maxAttackTime:Set[0]
		}


		
		variable iterator lockedTargetIterator
		variable iterator activeJammerIterator
		Ship:BuildActiveJammerList
		; May switch target more than once so use this flag to avoid log spamming.
		variable bool switched
		
		if ${CurrentOffenseTarget} != 0
		{
			if ${Marshalz.TargetList.Used}
			{
				This:LogInfo["Debug - Marshal - TM"]
				if ${Marshalz.LockedTargetList.Used}
				{
					CurrentOffenseTarget:Set[${Marshalz.LockedTargetList.Get[1]}]
					This:LogInfo["Kill The Damn Marshals"]
					finalizedTM:Set[TRUE]
				}
			}
			
			if ${RemoteRepJerks.TargetList.Used} && !${Marshalz.TargetList.Used}
			{
				This:LogInfo["Debug - RRJerks - TM"]
				if ${RemoteRepJerks.LockedTargetList.Used}
				{
					CurrentOffenseTarget:Set[${RemoteRepJerks.LockedTargetList.Get[1]}]
					This:LogInfo["Kill The Damn Remote Reppers"]
					finalizedTM:Set[TRUE]
				}
			}
			
			if ${StarvingJerks.TargetList.Used} && !${Marshalz.TargetList.Used} && !${RemoteRepJerks.TargetList.Used}
			{
				This:LogInfo["Debug - Neuting Jerks - TM"]
				if ${StarvingJerks.LockedTargetList.Used}
				{
					CurrentOffenseTarget:Set[${StarvingJerks.LockedTargetList.Get[1]}]
					This:LogInfo["Kill The Neuting Rats"]
					finalizedTM:Set[TRUE]
				}
			}
			
			if ${Leshaks.TargetList.Used} && !${Marshalz.TargetList.Used} && !${RemoteRepJerks.TargetList.Used} && !${StarvingJerks.TargetList.Used}
			{
				This:LogInfo["Debug - Leshaks - TM"]
				if ${Leshaks.LockedTargetList.Used}
				{
					CurrentOffenseTarget:Set[${Leshaks.LockedTargetList.Get[1]}]
					This:LogInfo["Kill The Leshaks"]
					finalizedTM:Set[TRUE]
				}
			}
			
			if ${Kikimoras.TargetList.Used} && !${Marshalz.TargetList.Used} && !${RemoteRepJerks.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used}
			{
				This:LogInfo["Debug - Kikimoras - TM"]
				if ${Kikimoras.LockedTargetList.Used}
				{
					CurrentOffenseTarget:Set[${Kikimoras.LockedTargetList.Get[1]}]
					This:LogInfo["Kill The Kikimoras"]
					finalizedTM:Set[TRUE]
				}
			}

			if ${Damaviks.TargetList.Used} && !${Marshalz.TargetList.Used} && !${RemoteRepJerks.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
			!${Kikimoras.TargetList.Used}
			{
				This:LogInfo["Debug - Damaviks - TM"]
				if ${Damaviks.LockedTargetList.Used}
				{
					CurrentOffenseTarget:Set[${Damaviks.LockedTargetList.Get[1]}]
					This:LogInfo["Kill The Damaviks"]
					finalizedTM:Set[TRUE]
				}
			}
			
			if ${Vedmaks.TargetList.Used} && !${Marshalz.TargetList.Used} && !${RemoteRepJerks.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
			!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used}
			{
				This:LogInfo["Debug - Vedmaks - TM"]
				if ${Vedmaks.LockedTargetList.Used}
				{
					CurrentOffenseTarget:Set[${Vedmaks.LockedTargetList.Get[1]}]
					This:LogInfo["Kill The Vedmaks"]
					finalizedTM:Set[TRUE]
				}
			}

			if ${Drekavacs.TargetList.Used} && !${Marshalz.TargetList.Used} && !${RemoteRepJerks.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
			!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used} && !${Vedmaks.TargetList.Used}
			{
				This:LogInfo["Debug - Drekavacs - TM"]
				if ${Drekavacs.LockedTargetList.Used}
				{
					CurrentOffenseTarget:Set[${Drekavacs.LockedTargetList.Get[1]}]
					This:LogInfo["Kill The Drekavacs"]
					finalizedTM:Set[TRUE]
				}
			}			
			
			if ${Cynabals.TargetList.Used} && !${Marshalz.TargetList.Used} && !${RemoteRepJerks.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
			!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used} && !${Vedmaks.TargetList.Used} && !${Drekavacs.TargetList.Used}
			{
				This:LogInfo["Debug - Cynabals - TM"]
				if ${Cynabals.LockedTargetList.Used}
				{
					CurrentOffenseTarget:Set[${Cynabals.LockedTargetList.Get[1]}]
					This:LogInfo["Kill The Cynabals"]
					finalizedTM:Set[TRUE]
				}
			}

			if ${Dramiels.TargetList.Used} && !${Marshalz.TargetList.Used} && !${RemoteRepJerks.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
			!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used} && !${Vedmaks.TargetList.Used} && !${Drekavacs.TargetList.Used} && !${Cynabals.TargetList.Used}
			{
				This:LogInfo["Debug - Dramiels - TM"]
				if ${Dramiels.LockedTargetList.Used}
				{
					CurrentOffenseTarget:Set[${Dramiels.LockedTargetList.Get[1]}]
					This:LogInfo["Kill The Dramiels"]
					finalizedTM:Set[TRUE]
				}
			}
			
			if ${Ship.ActiveJammerList.Used} && !${Marshalz.TargetList.Used} && !${RemoteRepJerks.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
			!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used} && !${Vedmaks.TargetList.Used} && !${Drekavacs.TargetList.Used} && !${Cynabals.TargetList.Used} && !${Dramiels.TargetList.Used}
			{
				if !${Ship.ActiveJammerSet.Contains[${CurrentOffenseTarget}]}
				{
					; Being jammed but the jammer is not the current target
					Ship.ActiveJammerList:GetIterator[activeJammerIterator]
					do
					{
						if ${Entity[${activeJammerIterator.Value}].IsLockedTarget}
						{
							CurrentOffenseTarget:Set[${activeJammerIterator.Value}]
							if ${Ship.ModuleList_Disintegrator.Count} == 0
							{
								maxAttackTime:Set[${Math.Calc[${LavishScript.RunningTime} + (${switchTargetAfter} * 1000)]}]
							}
							This:LogInfo["Switching target to activate jammer \ar${Entity[${CurrentOffenseTarget}].Name}"]
							finalizedTM:Set[TRUE]
							break
						}
					}
					while ${activeJammerIterator:Next(exists)}
				}
				else
				{
					finalizedTM:Set[TRUE]
				}
			}

			if !${finalizedTM} && ${ActiveNPCs.LockedTargetList.Used} && (${Ship.IsHardToDealWithTarget[${CurrentOffenseTarget}]} || ${This.IsStructure[${CurrentOffenseTarget}]})
			{
				ActiveNPCs.LockedTargetList:GetIterator[lockedTargetIterator]
				if ${lockedTargetIterator:First(exists)}
				{
					do
					{
						if ${This.IsStructure[${CurrentOffenseTarget}]} && !${This.IsStructure[${lockedTargetIterator.Value}]}
						{
							This:LogInfo["Pritorizing non-structure targets."]
							CurrentOffenseTarget:Set[0]
							if ${Ship.ModuleList_Disintegrator.Count} == 0
							{
								maxAttackTime:Set[${Math.Calc[${LavishScript.RunningTime} + (${switchTargetAfter} * 1000)]}]
							}
							return FALSE
						}
					}
					while ${lockedTargetIterator:Next(exists)}
				}

				; Switched to easier target.
				switched:Set[FALSE]
				if ${lockedTargetIterator:First(exists)}
				{
					do
					{
						if !${Ship.IsHardToDealWithTarget[${lockedTargetIterator.Value}]} && !${This.IsStructure[${lockedTargetIterator.Value}]} && \
						(${Ship.IsHardToDealWithTarget[${CurrentOffenseTarget}]} || ${Entity[${CurrentOffenseTarget}].Distance} > ${Entity[${lockedTargetIterator.Value}].Distance})
						{
							CurrentOffenseTarget:Set[${lockedTargetIterator.Value}]
							if ${Ship.ModuleList_Disintegrator.Count} == 0
							{
								maxAttackTime:Set[${Math.Calc[${LavishScript.RunningTime} + (${switchTargetAfter} * 1000)]}]
							}
							switched:Set[TRUE]
						}
					}
					while ${lockedTargetIterator:Next(exists)}
				}
				if ${switched}
				{
					This:LogInfo["Switching to easier target: \ar${Entity[${CurrentOffenseTarget}].Name}"]
				}
			}
		}
		elseif ${Marshalz.TargetList.Used}
		{
			This:LogInfo["Debug - Marshal - TM"]
			if ${Marshalz.LockedTargetList.Used}
			{
				CurrentOffenseTarget:Set[${Marshalz.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Damn Marshals"]
				finalizedTM:Set[TRUE]
			}
		}

		elseif ${RemoteRepJerks.TargetList.Used} && !${Marshalz.TargetList.Used}
		{
			This:LogInfo["Debug - Marshal - TM"]
			if ${RemoteRepJerks.LockedTargetList.Used}
			{
				CurrentOffenseTarget:Set[${RemoteRepJerks.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Damn Remote Reppers"]
				finalizedTM:Set[TRUE]
			}
		}
		
		elseif ${StarvingJerks.TargetList.Used} && !${Marshalz.TargetList.Used} && !${RemoteRepJerks.TargetList.Used}
		{
			This:LogInfo["Debug - Neuting Jerks - TM"]
			if ${StarvingJerks.LockedTargetList.Used}
			{
				CurrentOffenseTarget:Set[${StarvingJerks.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Neuting Rats"]
				finalizedTM:Set[TRUE]
			}
		}
		
		elseif ${Leshaks.TargetList.Used} && !${Marshalz.TargetList.Used} && !${RemoteRepJerks.TargetList.Used} && !${StarvingJerks.TargetList.Used}
		{
			This:LogInfo["Debug - Leshaks - TM"]
			if ${Leshaks.LockedTargetList.Used}
			{
				CurrentOffenseTarget:Set[${Leshaks.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Leshaks"]
				finalizedTM:Set[TRUE]
			}
		}
			
		elseif ${Kikimoras.TargetList.Used} && !${Marshalz.TargetList.Used} && !${RemoteRepJerks.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used}
		{
			This:LogInfo["Debug - Kikimoras - TM"]
			if ${Kikimoras.LockedTargetList.Used}
			{
				CurrentOffenseTarget:Set[${Kikimoras.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Kikimoras"]
				finalizedTM:Set[TRUE]
			}
		}
		elseif ${Damaviks.TargetList.Used} && !${Marshalz.TargetList.Used} && !${RemoteRepJerks.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
		!${Kikimoras.TargetList.Used}
		{
			This:LogInfo["Debug - Damaviks - TM"]
			if ${Damaviks.LockedTargetList.Used}
			{
				CurrentOffenseTarget:Set[${Damaviks.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Damaviks"]
				finalizedTM:Set[TRUE]
			}
		}
			
		elseif ${Vedmaks.TargetList.Used} && !${Marshalz.TargetList.Used} && !${RemoteRepJerks.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
		!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used}
		{
			This:LogInfo["Debug - Vedmaks - TM"]
			if ${Vedmaks.LockedTargetList.Used}
			{
				CurrentOffenseTarget:Set[${Vedmaks.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Vedmaks"]
				finalizedTM:Set[TRUE]
			}
		}

		elseif ${Drekavacs.TargetList.Used} && !${Marshalz.TargetList.Used} && !${RemoteRepJerks.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
		!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used} && !${Vedmaks.TargetList.Used}
		{
			This:LogInfo["Debug - Drekavacs - TM"]
			if ${Drekavacs.LockedTargetList.Used}
			{
				CurrentOffenseTarget:Set[${Drekavacs.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Drekavacs"]
				finalizedTM:Set[TRUE]
			}
		}			
		
		elseif ${Cynabals.TargetList.Used} && !${Marshalz.TargetList.Used} && !${RemoteRepJerks.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
		!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used} && !${Vedmaks.TargetList.Used} && !${Drekavacs.TargetList.Used}
		{
			This:LogInfo["Debug - Cynabals - TM"]
			if ${Cynabals.LockedTargetList.Used}
			{
				CurrentOffenseTarget:Set[${Cynabals.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Cynabals"]
				finalizedTM:Set[TRUE]
			}
		}

		elseif ${Dramiels.TargetList.Used} && !${Marshalz.TargetList.Used} && !${RemoteRepJerks.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
		!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used} && !${Vedmaks.TargetList.Used} && !${Drekavacs.TargetList.Used} && !${Cynabals.TargetList.Used}
		{
			This:LogInfo["Debug - Dramiels - TM"]
			if ${Dramiels.LockedTargetList.Used}
			{
				CurrentOffenseTarget:Set[${Dramiels.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Dramiels"]
				finalizedTM:Set[TRUE]
			}
		}

		elseif ${ActiveNPCs.LockedTargetList.Used} && !${Marshalz.TargetList.Used} && !${RemoteRepJerks.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
		!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used} && !${Vedmaks.TargetList.Used} && !${Drekavacs.TargetList.Used} && !${Cynabals.TargetList.Used}
		{
			echo ${ActiveNPCs.LockedTargetList.Used} AT
			; Need to re-pick from locked target
			if ${Ship.ActiveJammerList.Used}
			{
				Ship.ActiveJammerList:GetIterator[activeJammerIterator]
				do
				{
					if ${Entity[${activeJammerIterator.Value}].IsLockedTarget}
					{
						CurrentOffenseTarget:Set[${activeJammerIterator.Value}]
						if ${Ship.ModuleList_Disintegrator.Count} == 0
						{
							maxAttackTime:Set[${Math.Calc[${LavishScript.RunningTime} + (${switchTargetAfter} * 1000)]}]
						}
						This:LogInfo["Targeting activate jammer \ar${Entity[${CurrentOffenseTarget}].Name}"]
						break
					}
				}
				while ${activeJammerIterator:Next(exists)}
			}

			if ${CurrentOffenseTarget} == 0
			{
				; Priortize the closest target which is not hard to deal with to
				; reduce the frequency of switching ammo.
				
				variable int64 lowPriorityTarget = 0
				ActiveNPCs.LockedTargetList:GetIterator[lockedTargetIterator]
				if ${lockedTargetIterator:First(exists)}
				{
					do
					{
						if ${Ship.IsHardToDealWithTarget[${lockedTargetIterator.Value}]} || ${This.IsStructure[${lockedTargetIterator.Value}]}
						{
							; Structure priority is lower than ships.
							if !${This.IsStructure[${lockedTargetIterator.Value}]} || ${lowPriorityTarget.Equal[0]}
							{
								lowPriorityTarget:Set[${lockedTargetIterator.Value}]
							}
						}
						elseif ${CurrentOffenseTarget} == 0 || ${Entity[${CurrentOffenseTarget}].Distance} > ${Entity[${lockedTargetIterator.Value}].Distance}
						{
							; if ${CurrentOffenseTarget} != 0
							; 	This:LogInfo["there is something closer ${Entity[${lockedTargetIterator.Value}].Name}"]
							CurrentOffenseTarget:Set[${lockedTargetIterator.Value}]
							if ${Ship.ModuleList_Disintegrator.Count} == 0
							{
								maxAttackTime:Set[${Math.Calc[${LavishScript.RunningTime} + (${switchTargetAfter} * 1000)]}]
							}
						}
					}
					while ${lockedTargetIterator:Next(exists)}
				}

				if ${CurrentOffenseTarget} == 0
				{
					; This:LogInfo["no easy target"]
					CurrentOffenseTarget:Set[${lowPriorityTarget}]
					if ${Ship.ModuleList_Disintegrator.Count} == 0
					{
						maxAttackTime:Set[${Math.Calc[${LavishScript.RunningTime} + (${switchTargetAfter} * 1000)]}]
					}
				}
			}
			This:LogInfo["Primary target: \ar${Entity[${CurrentOffenseTarget}].Name}, effciency ${Math.Calc[${Ship.ModuleList_Weapon.DamageEfficiency[${CurrentOffenseTarget}]} * 100].Deci}%."]
		}
		echo ${CurrentOffenseTarget} Current Offense Target
		; Nothing is locked.
		if ${ActiveNPCs.TargetList.Used} && \
			${CurrentOffenseTarget.Equal[0]} && \
		 	${ActiveNPCs.TargetList.Get[1].Distance} > ${Math.Calc[${Ship.ModuleList_Weapon.Range} * 0.95]} && \
			!${MyShip.ToEntity.Approaching.ID.Equal[${ActiveNPCs.TargetList.Get[1].ID}]} && \
			!${Move.Traveling}
		{
			if ${Ship.ModuleList_Siege.ActiveCount}
			{
				; This:LogInfo["Deactivate siege module due to no locked target"]
				Ship.ModuleList_Siege:DeactivateAll
			}
			;This:LogInfo["Approaching distanced target: \ar${ActiveNPCs.TargetList.Get[1].Name}"]
			;This:ManageThrusterOverload[${ActiveNPCs.TargetList.Get[1].ID}]
			;ActiveNPCs.TargetList.Get[1]:Approach
			;This:InsertState["PerformMission"]
			;return TRUE
		}

		if ${CurrentOffenseTarget} != 0 && ${Entity[${CurrentOffenseTarget}]} && !${Entity[${CurrentOffenseTarget}].IsMoribund}
		{
			variable string targetClass
			targetClass:Set[${NPCData.NPCType[${Entity[${CurrentOffenseTarget}].GroupID}]}]
			; Avoid using drones against structures which may cause AOE damage when destructed.
			;if !${AllowDronesOnNpcClass.Contains[${targetClass}]}
			;{
			;	DroneControl:Recall
			;}

			echo ${Ship.ModuleList_Weapon.Range} weapon range
			if (${Ship.ModuleList_Weapon.Range} > ${Entity[${CurrentOffenseTarget}].Distance}) 
			{
				Ship.ModuleList_Weapon:ActivateAll[${CurrentOffenseTarget}]
				Ship.ModuleList_TrackingComputer:ActivateFor[${CurrentOffenseTarget}]
				if ${allowSiegeModule}
				{
					Ship.ModuleList_Siege:ActivateOne
				}
			}
			elseif !${Ship.ModuleList_Weapon.IsUsingLongRangeAmmo} && ${Abyssal.Config.UseSecondaryAmmo}
			{
				This:LogDebug["Far switch ammo to long"]
				; Activate weapon to switch ammo to long.
				Ship.ModuleList_Weapon:ActivateAll[${CurrentOffenseTarget}]
				Ship.ModuleList_TrackingComputer:ActivateFor[${CurrentOffenseTarget}]
			}
			elseif ${allowSiegeModule} && \
				${Ship.ModuleList_Siege.Allowed} && \
				${Ship.ModuleList_Siege.Count} && \
				!${Ship.RegisteredModule.Element[${Ship.ModuleList_Siege.ModuleID.Get[1]}].IsActive} && \
			 	(${Math.Calc[${Entity[${CurrentOffenseTarget}].Distance} / (${Ship.ModuleList_Weapon.Range} + 1)]} < 1.2)
			{
				This:LogDebug["Far need siege"]
				; Using long range ammo and within range if siege module is on.
				Ship.ModuleList_Siege:ActivateOne
				; Switch target
				Ship.ModuleList_Weapon:ActivateAll[${CurrentOffenseTarget}]
				Ship.ModuleList_TrackingComputer:ActivateFor[${CurrentOffenseTarget}]
			}
			;elseif !${Entity[${CurrentOffenseTarget}].IsTargetingMe}
			;{
			;	This:LogDebug["Far trigger"]
				; Shoot at out of range target to trigger them.
			;	Ship.ModuleList_Weapon:ActivateAll[${CurrentOffenseTarget}]
			;	Ship.ModuleList_TrackingComputer:ActivateFor[${CurrentOffenseTarget}]
			;}
			else
			{
				This:LogDebug["Far approach"]
				Ship.ModuleList_Weapon:DeactivateAll[${CurrentOffenseTarget}]
				Ship.ModuleList_Siege:DeactivateAll

				if !${MyShip.ToEntity.Approaching.ID.Equal[${CurrentOffenseTarget}]} && !${Move.Traveling}
				{
					This:LogInfo["Approaching out of range target: \ar${Entity[${CurrentOffenseTarget}].Name}"]
					This:ManageThrusterOverload[${Entity[${CurrentOffenseTarget}].ID}]
					;Entity[${CurrentOffenseTarget}]:Approach
				}
			}

			if ${Entity[${CurrentOffenseTarget}].Distance} <= 140000
			{
				Ship.ModuleList_TargetPainter:ActivateAll[${CurrentOffenseTarget}]
			}
			; 'Effectiveness Falloff' is not read by ISXEVE, but 20km is a generally reasonable range to activate the module
			if ${Entity[${CurrentOffenseTarget}].Distance} <= ${Math.Calc[${Ship.ModuleList_StasisGrap.Range} + 20000]}
			{
				Ship.ModuleList_StasisGrap:ActivateAll[${CurrentOffenseTarget}]
			}
			if ${Entity[${CurrentOffenseTarget}].Distance} <= ${Ship.ModuleList_StasisWeb.Range}
			{
				Ship.ModuleList_StasisWeb:ActivateAll[${CurrentOffenseTarget}]
			}
		}
		NPCs.MinLockCount:Set[4]

		if ${NPCs.TargetList.Used}
		{
			if ${NPCs.TargetList.Get[1].Distance} > ${Math.Calc[${Ship.ModuleList_Weapon.Range} * .95]} && ${MyShip.ToEntity.Mode} != MOVE_APPROACHING && !${Move.Traveling}
			{
				if ${Ship.ModuleList_Siege.ActiveCount}
				{
					; This:LogInfo["Deactivate siege module due to approaching"]
					Ship.ModuleList_Siege:DeactivateAll
				}

				This:ManageThrusterOverload[${NPCs.TargetList.Get[1].ID}]
				;NPCs.TargetList.Get[1]:Approach
			}

			if ${CurrentOffenseTarget} == 0 || ${Entity[${CurrentOffenseTarget}].IsMoribund} || !${Entity[${CurrentOffenseTarget}]}
			{
				if ${NPCs.LockedTargetList.Used}
					CurrentOffenseTarget:Set[${NPCs.LockedTargetList.Get[1]}]
				else
					CurrentOffenseTarget:Set[0]
			}
			;This:InsertState["PerformMission"]
			return TRUE
		}
		if ${Entity[${targetToDestroy}]}
		{
			if ${Entity[${targetToDestroy}].Distance} > ${Math.Calc[${Ship.ModuleList_Weapon.Range} * .95]} && ${MyShip.ToEntity.Mode} != MOVE_APPROACHING && !${Move.Traveling}
			{
				if ${Ship.ModuleList_Siege.ActiveCount}
				{
					; This:LogInfo["Deactivate siege module due to approaching"]
					Ship.ModuleList_Siege:DeactivateAll
				}

				This:ManageThrusterOverload[${Entity[${targetToDestroy}].ID}]
				;Entity[${targetToDestroy}]:Approach
			}

			if !${Entity[${targetToDestroy}].IsLockedTarget} && !${Entity[${targetToDestroy}].BeingTargeted} && \
				${Entity[${targetToDestroy}].Distance} < ${MyShip.MaxTargetRange}
			{
				This:LogInfo["Locking Target To Destroy"]
				This:LogInfo[" ${Entity[${targetToDestroy}].Name}", "o"]
				Entity[${targetToDestroy}]:LockTarget
			}
			elseif ${Entity[${targetToDestroy}].IsLockedTarget} && (${Entity[${targetToDestroy}].Distance} < ${Math.Calc[${Ship.ModuleList_Weapon.Range} * .95]})
			{
				Ship.ModuleList_Weapon:ActivateAll[${Entity[${targetToDestroy}].ID}]
				if ${AutoModule.Config.TrackingComputers}
				{
					Ship.ModuleList_TrackingComputer:ActivateAll[${CurrentOffenseTarget}]
				}
			}
			;This:InsertState["PerformMission"]
			return TRUE
		}
	}

	method RegisterCurrentPrimaryWeaponRange()
	{
		CurrentOffenseRange:Set[${Math.Calc[${Ship.ModuleList_Weapon.Range} * .95]}]
	}
	
	member:bool TargetManager()
	{
		if ${Me.InStation}
		{
			return FALSE
		}
		if !${Client.InSpace}
		{
			return FALSE
		}
		if ${CurrentOffenseRange} <= 1
		{
			This:RegisterCurrentPrimaryWeaponRange
		}
		if ${CurrentOffenseTarget} < 1
		{
			allowSiegeModule:Set[FALSE]
			Ship.ModuleList_Siege:DeactivateAll
			Ship.ModuleList_CommandBurst:DeactivateAll
		}
		if ${Ship.ModuleList_CommandBurst.Count} > 0 && ${CurrentOffenseTarget} > 1 && ${LavishScript.RunningTime} >= ${BurstTimer}
		{
			Ship.ModuleList_CommandBurst:ActivateAll
			BurstTimer:Set[${Math.Calc[${LavishScript.RunningTime} + 115000]}]
		}

		This:BuildNpcQueries
		if ${CommonConfig.Tehbot_Mode.Equal["Abyssal"]}
		{
			Marshalz.AutoLock:Set[TRUE]
			Marshalz:RequestUpdate
			RemoteRepJerks.AutoLock:Set[TRUE]
			RemoteRepJerks:RequestUpdate
			StarvingJerks.AutoLock:Set[TRUE]
			StarvingJerks:RequestUpdate
			Leshaks.Autolock:Set[TRUE]
			Leshaks:RequestUpdate
			Kikimoras.Autolock:Set[TRUE]
			Kikimoras:RequestUpdate
			Damaviks.Autolock:Set[TRUE]
			Damaviks:RequestUpdate
			Vedmaks.Autolock:Set[TRUE]
			Vedmaks:RequestUpdate
			Drekavacs.Autolock:Set[TRUE]
			Drekavacs:RequestUpdate
			Cynabals.Autolock:Set[TRUE]
			Cynabals:RequestUpdate
			Dramiels.Autolock:Set[TRUE]
			Dramiels:RequestUpdate
		}
		NPCs.AutoLock:Set[TRUE]
		ActiveNPCs.AutoLock:Set[TRUE]
		ActiveNPCs:RequestUpdate
		This:PlagiarisedOffense
		
		return FALSE
	}
}