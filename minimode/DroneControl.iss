objectdef obj_Configuration_DroneControl inherits obj_Configuration_Base
{
	method Initialize()
	{
		This[parent]:Initialize["DroneControl"]
	}

	method Set_Default_Values()
	{
		This.ConfigRef:AddSetting[Sentries, FALSE]
		This.ConfigRef:AddSetting[SentryRange, 30]
		This.ConfigRef:AddSetting[MaxDroneCount, 5]
		This.ConfigRef:AddSetting[ArmorDrones, FALSE]
		This.ConfigRef:AddSetting[ShieldDrones, FALSE]
	}

	Setting(bool, Sentries, SetSentries)
	Setting(int, SentryRange, SetSentryRange)
	Setting(int, MaxDroneCount, SetDroneCount)
	Setting(bool, UseIPC, SetUseIPC)
	Setting(bool, ArmorDrones, SetArmorDrones)
	Setting(bool, ShieldDrones, SetShieldDrones)
}

objectdef obj_DroneControl inherits obj_StateQueue
{
	variable obj_Configuration_DroneControl Config
	variable obj_TargetList ActiveNPCs
	variable obj_TargetList NPC
	
	variable obj_TargetList Marshal
	variable obj_TargetList RemoteRepJerkz
	variable obj_TargetList StarvingJerks
	variable obj_TargetList Leshaks
	variable obj_TargetList Kikimoras
	variable obj_TargetList Damaviks
	variable obj_TargetList Vedmaks
	variable obj_TargetList Drekavacs
	variable obj_TargetList Cynabals
	variable obj_TargetList Dramiels
	
	variable int64 currentTarget = 0
	variable bool IsBusy
	variable int droneEngageRange = 60000
	variable bool RecallActive=FALSE

	method Initialize()
	{
		This[parent]:Initialize
		PulseFrequency:Set[1000]
		This.NonGameTiedPulse:Set[TRUE]
		DynamicAddMiniMode("DroneControl", "DroneControl")
		
		 Marshal.NeedUpdate:Set[FALSE]
		 RemoteRepJerkz.NeedUpdate:Set[FALSE]
		 StarvingJerks.NeedUpdate:Set[FALSE]
		 Leshaks.NeedUpdate:Set[FALSE]
		 Kikimoras.NeedUpdate:Set[FALSE]
		 Damaviks.NeedUpdate:Set[FALSE]
		 Vedmaks.NeedUpdate:Set[FALSE]
		 Drekavacs.NeedUpdate:Set[FALSE]
		 Cynabals.NeedUpdate:Set[FALSE]
		 Dramiels.NeedUpdate:Set[FALSE]
	}
	
	member:bool JerkzPresent()
	{
		if ${Entity[(Group =- "Abyssal Spaceship Entities" || Group =- "Abyssal Drone Entities") && !IsMoribund && Name !~ "Vila Swarmer"](exists)}
		{
			return TRUE
		}
		else
		{
			return FALSE
		}
	}

	member:int FindBestType(int TargetGroupID)
	{
		variable string TargetClass
		variable int DroneType
		TargetClass:Set[${NPCData.NPCType[${TargetGroupID}]}]
		switch ${TargetClass}
		{
			case Frigate
			case Destroyer
				if ${MyShip.ToEntity.Type.Find[Rattlesnake]} || ${MyShip.ToEntity.Type.Find[Ishtar]}
				{
					DroneType:Set[${Drones.Data.FindType["Heavy Attack Drones"]}]
					{
					if ${DroneType} != -1
						{
							return ${DroneType}
						}
					}
				}
				DroneType:Set[${Drones.Data.FindType["Light Scout Drones"]}]
				if ${DroneType} != -1
				{
					return ${DroneType}
				}

				DroneType:Set[${Drones.Data.FindType["Medium Scout Drones"]}]
				if ${DroneType} != -1
				{
					return ${DroneType}
				}				

			case Cruiser
			case BattleCruiser
				if ${MyShip.ToEntity.Type.Find[Rattlesnake]} || ${MyShip.ToEntity.Type.Find[Ishtar]}
				{
					DroneType:Set[${Drones.Data.FindType["Heavy Attack Drones"]}] 
					{
					if ${DroneType} != -1
						{
							return ${DroneType}
						}
					}
				}
				DroneType:Set[${Drones.Data.FindType["Fighters"]}]
				if ${DroneType} != -1
				{
					return ${DroneType}
				}

				DroneType:Set[${Drones.Data.FindType["Medium Scout Drones"]}]
				if ${DroneType} != -1
				{
					return ${DroneType}
				}

				DroneType:Set[${Drones.Data.FindType["Light Scout Drones"]}]
				if ${DroneType} != -1
				{
					return ${DroneType}
				}


			case Battleship

				DroneType:Set[${Drones.Data.FindType["Fighters"]}]
				if ${DroneType} != -1
				{
					return ${DroneType}
				}

				DroneType:Set[${Drones.Data.FindType["Heavy Attack Drones"]}]
				if ${DroneType} != -1
				{
					return ${DroneType}
				}

				DroneType:Set[${Drones.Data.FindType["Medium Scout Drones"]}]
				if ${DroneType} != -1
				{
					return ${DroneType}
				}

				DroneType:Set[${Drones.Data.FindType["Light Scout Drones"]}]
				if ${DroneType} != -1
				{
					return ${DroneType}
				}
		}

		; Fallback for PVP
		DroneType:Set[${Drones.Data.FindType["Light Scout Drones"]}]
		if ${DroneType} != -1
		{
			return ${DroneType}
		}

		DroneType:Set[${Drones.Data.FindType["Medium Scout Drones"]}]
		if ${DroneType} != -1
		{
			return ${DroneType}
		}
	}

	member:int SentryCount()
	{
		variable iterator typeIterator
		variable string types = ""
		variable string seperator = ""

		seperator:Set[""]
		types:Set[""]
		Drones.Data.BaseRef.FindSet["Sentry Drones"]:GetSettingIterator[typeIterator]
		if ${typeIterator:First(exists)}
		{
			do
			{
				types:Concat["${seperator}TypeID = ${typeIterator.Key}"]
				seperator:Set[" || "]
			}
			while ${typeIterator:Next(exists)}
		}
		return ${Drones.ActiveDroneCount["${types}"]}
	}

	method RecallAllSentry()
	{
		variable iterator typeIterator
		variable string types = ""
		variable string seperator = ""

		seperator:Set[""]
		types:Set[""]
		Drones.Data.BaseRef.FindSet["Sentry Drones"]:GetSettingIterator[typeIterator]
		if ${typeIterator:First(exists)}
		{
			do
			{
				types:Concat["${seperator}TypeID = ${typeIterator.Key}"]
				seperator:Set[" || "]
			}
			while ${typeIterator:Next(exists)}
		}
		Drones:Recall["${types}", ${Drones.ActiveDroneCount["${types}"]}]
	}

	member:int NonSentryCount()
	{
		variable iterator typeIterator
		variable string types = ""
		variable string seperator = ""

		seperator:Set[""]
		types:Set[""]
		Drones.Data.BaseRef.FindSet["Sentry Drones"]:GetSettingIterator[typeIterator]
		if ${typeIterator:First(exists)}
		{
			do
			{
				types:Concat["${seperator}TypeID != ${typeIterator.Key}"]
				seperator:Set[" && "]
			}
			while ${typeIterator:Next(exists)}
		}
		return ${Drones.ActiveDroneCount["(ToEntity.GroupID = GROUP_SCOUT_DRONE || ToEntity.GroupID = GROUP_COMBAT_DRONE) && (${types})"]}
	}

	method RecallAllNonSentry()
	{
		variable iterator typeIterator
		variable string types = ""
		variable string seperator = ""

		seperator:Set[""]
		types:Set[""]
		Drones.Data.BaseRef.FindSet["Sentry Drones"]:GetSettingIterator[typeIterator]
		if ${typeIterator:First(exists)}
		{
			do
			{
				types:Concat["${seperator}TypeID != ${typeIterator.Key}"]
				seperator:Set[" && "]
			}
			while ${typeIterator:Next(exists)}
		}
		Drones:Recall["(ToEntity.GroupID = GROUP_SCOUT_DRONE || ToEntity.GroupID = GROUP_COMBAT_DRONE) && (${types})", ${Drones.ActiveDroneCount["ToEntity.GroupID = GROUP_SCOUT_DRONE && (${types})"]}]
	}

	method Start()
	{
		if ${This.IsIdle}
		{
			This:LogInfo["Starting."]
			if ${CommonConfig.Tehbot_Mode.Equal["Abyssal"]}
			{
				Dramiels.AutoLock:Set[TRUE]			
				Cynabals.AutoLock:Set[TRUE]			
				Drekavacs.AutoLock:Set[TRUE]			
				Vedmaks.AutoLock:Set[TRUE]		
				Damaviks.AutoLock:Set[TRUE]		
				Kikimoras.AutoLock:Set[TRUE]	
				Leshaks.AutoLock:Set[TRUE]			
				StarvingJerks.AutoLock:Set[TRUE]
				Marshal.AutoLock:Set[TRUE]
				RemoteRepJerkz.AutoLock:Set[TRUE]
			}
			ActiveNPCs.MaxRange:Set[${droneEngageRange}]
			variable int MaxTarget = ${MyShip.MaxLockedTargets}
			if ${Me.MaxLockedTargets} < ${MyShip.MaxLockedTargets}
				MaxTarget:Set[${Me.MaxLockedTargets}]
			MaxTarget:Dec[2]

			ActiveNPCs.MinLockCount:Set[${MaxTarget}]
			ActiveNPCs.AutoLock:Set[TRUE]
			This:QueueState["DroneControl"]
		}
	}

	method Stop()
	{
		This:LogInfo["Stopping."]
		Marshal.AutoLock:Set[FALSE]
		ActiveNPCs.AutoLock:Set[FALSE]
		RemoteRepJerkz.AutoLock:Set[FALSE]
		StarvingJerks.AutoLock:Set[FALSE]
		Dramiels.AutoLock:Set[FALSE]			
		Cynabals.AutoLock:Set[FALSE]			
		Drekavacs.AutoLock:Set[FALSE]			
		Vedmaks.AutoLock:Set[FALSE]		
		Damaviks.AutoLock:Set[FALSE]		
		Kikimoras.AutoLock:Set[FALSE]	
		Leshaks.AutoLock:Set[FALSE]	
		This:Clear
	}

	method Recall()
	{
		if ${This.RecallActive}
		{
			return
		}
		This.RecallActive:Set[TRUE]

		variable bool DontResume=${This.IsIdle}

		This:Clear

		if ${Drones.DronesInSpace}
		{
			Busy:SetBusy["DroneControl"]
			Drones:RecallAll
			This:QueueState["Idle", 2000]
			This:QueueState["RecallCheck"]
		}
		else
		{
			Busy:UnsetBusy["DroneControl"]
		}

		This:QueueState["Idle", 20000]
		This:QueueState["ResetRecall", 50]

		if !${DontResume}
		{
			This:QueueState["DroneControl"]
		}
	}

	member:bool RecallCheck()
	{
		if ${Drones.DronesInSpace}
		{
			Drones:RecallAll
			This:InsertState["RecallCheck"]
			This:InsertState["Idle", 2000]
		}
		else
		{
			Busy:UnsetBusy["DroneControl"]
		}
		return TRUE
	}

	member:bool ResetRecall()
	{
		This.RecallActive:Set[FALSE]
		return TRUE
	}

	method BuildActiveNPCs()
	{
		variable iterator classIterator
		variable iterator groupIterator
		variable string groups = ""
		variable string seperator = ""

		ActiveNPCs:ClearQueryString
		if ${CommonConfig.Tehbot_Mode.Equal["Abyssal"]}
		{
			Marshal:ClearQueryString
			RemoteRepJerkz:ClearQueryString
			StarvingJerks:ClearQueryString
			Dramiels:ClearQueryString
			Cynabals:ClearQueryString
			Drekavacs:ClearQueryString
			Vedmaks:ClearQueryString
			Damaviks:ClearQueryString
			Kikimoras:ClearQueryString
			Leshaks:ClearQueryString
		}
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
			RemoteRepJerkz:AddQueryString["Name =- \"Renewing\" || Name =- \"Fieldweaver\" || Name =- \"Plateforger\" || Name =- \"Burst\"|| Name =- \"Preserver\" && !IsMoribund"]
			Marshal:AddQueryString["(TypeID == 56177 || TypeID == 56176 || TypeID == 56178) && !IsMoribund"]
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
					else
					{
						This:LogInfo["Mission", "unknown EW ${jamsIterator.Value}", "r"]
					}
				}
				while ${jamsIterator:Next(exists)}
			}
		}
		while ${attackerIterator:Next(exists)}

		ActiveNPCs:AddQueryString["Distance < ${droneEngageRange} && IsNPC && !IsMoribund && (${groups})"]
		ActiveNPCs:AddQueryString["Distance < ${droneEngageRange} && IsNPC && !IsMoribund && IsWarpScramblingMe"]

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
		ActiveNPCs:AddQueryString["Distance < ${droneEngageRange} && IsNPC && !IsMoribund && (${groups})"]

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
		ActiveNPCs:AddQueryString["Distance < ${droneEngageRange} && IsNPC && !IsMoribund && (${groups})"]

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
		ActiveNPCs:AddQueryString["Distance < ${droneEngageRange} && IsNPC && !IsMoribund && (${groups})"]

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
				ActiveNPCs:AddQueryString["Distance < ${droneEngageRange} && IsNPC && !IsMoribund && (${groups})"]
			}
			while ${classIterator:Next(exists)}
		}

		ActiveNPCs:AddAllNPCs
		
	}

	member:bool DroneControl()
	{
		variable index:activedrone ActiveDrones
		variable iterator DroneIterator
		variable float CurrentDroneHealth
		variable iterator DroneTypesIter
		variable int MaxDroneCount = ${Config.MaxDroneCount}

		This:BuildActiveNPCs
		if ${CommonConfig.Tehbot_Mode.Equal["Abyssal"]}
		{
			ActiveNPCs:RequestUpdate
			Marshal:RequestUpdate
			RemoteRepJerkz:RequestUpdate
			StarvingJerks:RequestUpdate
		}
		if ${CommonConfig.Tehbot_Mode.Equal["Mining"]}
		{
			ActiveNPCs.MaxRange:Set[${droneEngageRange}]
			variable int MaxTarget = ${MyShip.MaxLockedTargets}
			if ${Me.MaxLockedTargets} < ${MyShip.MaxLockedTargets}
				MaxTarget:Set[${Me.MaxLockedTargets}]
			MaxTarget:Dec[2]
			ActiveNPCs:RequestUpdate
			ActiveNPCs.MinLockCount:Set[${MaxTarget}]
			ActiveNPCs.AutoLock:Set[TRUE]
		}
		ActiveNPCs.MinLockCount:Set[${Config.LockCount}]

		if !${Client.InSpace}
		{
			return FALSE
		}
		
		if ${MaxDroneCount} > ${Me.MaxActiveDrones} && !${MyShip.ToEntity.Type.Find[Rattlesnake]} && !${MyShip.ToEntity.Type.Find[Gila]}
		{
			MaxDroneCount:Set[${Me.MaxActiveDrones}]
		}

		if ${MyShip.ToEntity.Type.Find[Rattlesnake]} || ${MyShip.ToEntity.Type.Find[Gila]}
		{
			MaxDroneCount:Set[2]
		}

		if ${Me.ToEntity.Mode} == MOVE_WARPING
		{
			if ${Drones.ActiveCount["ToEntity.GroupID = GROUP_SCOUT_DRONE || ToEntity.GroupID = GROUP_COMBAT_DRONE"]} > 0
			{
				Drones:Recall["ToEntity.GroupID = GROUP_SCOUT_DRONE || ToEntity.GroupID = GROUP_COMBAT_DRONE"]
			}
			return FALSE
		}

		if ${Drones.DronesInBay.Equal[0]} && ${Drones.DronesInSpace.Equal[0]}
		{
			Busy:UnsetBusy["DroneControl"]
			return FALSE
		}

		if ${IsBusy}
		{
			if ${Drones.DronesInSpace.Equal[0]}
			{
				Busy:UnsetBusy["DroneControl"]
				IsBusy:Set[FALSE]
			}
		}

		Me:GetActiveDrones[ActiveDrones]
		ActiveDrones:GetIterator[DroneIterator]
		if ${DroneIterator:First(exists)}
		{
			do
			{
				; If someone didn't set either of the new configs in DroneControl then we use the original setup for drone recalls. Alternatively, some joker checked both boxes.
				if (!${Config.ArmorDrones} && !${Config.ShieldDrones}) || ( ${Config.ArmorDrones} && ${Config.ShieldDrones} )
				{
					CurrentDroneHealth:Set[${Math.Calc[${DroneIterator.Value.ToEntity.ShieldPct.Int} + ${DroneIterator.Value.ToEntity.ArmorPct.Int} + ${DroneIterator.Value.ToEntity.StructurePct.Int}]}]
					;This is for abyss, if we've got edencom lightning blasters we need drones to ignore more damage or we will get looped.
					if ${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]} && ${CurrentDroneHealth} < ${Math.Calc[${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]} - 30]} && \
					${Entity[Name =- "Skybreaker" || Name =- "Stormbringer" || Name =- "Thunderchild"](exists)}
					{
						;echo recalling ID ${DroneIterator.Value.ID}
						Drones:Recall["ID = ${DroneIterator.Value.ID}", 1]
					}
					if ${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]} && ${CurrentDroneHealth} < ${Math.Calc[${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]} - 15]} && \
					!${Entity[Name =- "Skybreaker" || Name =- "Stormbringer" || Name =- "Thunderchild"](exists)}
					{
						;echo recalling ID ${DroneIterator.Value.ID}
						Drones:Recall["ID = ${DroneIterator.Value.ID}", 1]
					}
					Drones.DroneHealth:Set[${DroneIterator.Value.ID}, ${CurrentDroneHealth.Int}]
					;echo drone refreshed cached health ${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]}
				}
				; We are using my new configs, this denotes we have drones that are primarily Armor HP heavy - We will mostly ignore shield damage because otherwise we will recall our drones nonstop.
				if ${Config.ArmorDrones}
				{
					CurrentDroneHealth:Set[${Math.Calc[( ${DroneIterator.Value.ToEntity.ShieldPct.Int} * 0.175 ) + ${DroneIterator.Value.ToEntity.ArmorPct.Int} + ${DroneIterator.Value.ToEntity.StructurePct.Int}]}]
					;This is for abyss, if we've got edencom lightning blasters we need drones to ignore more damage or we will get looped.
					if ${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]} && ${CurrentDroneHealth} < ${Math.Calc[${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]} - 30]} && \
					${Entity[Name =- "Skybreaker" || Name =- "Stormbringer" || Name =- "Thunderchild"](exists)}
					{
						;echo recalling ID ${DroneIterator.Value.ID}
						Drones:Recall["ID = ${DroneIterator.Value.ID}", 1]
					}
					if ${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]} && ${CurrentDroneHealth} < ${Math.Calc[${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]} - 15]} && \
					!${Entity[Name =- "Skybreaker" || Name =- "Stormbringer" || Name =- "Thunderchild"](exists)}
					{
						;echo recalling ID ${DroneIterator.Value.ID}
						Drones:Recall["ID = ${DroneIterator.Value.ID}", 1]
					}
					Drones.DroneHealth:Set[${DroneIterator.Value.ID}, ${CurrentDroneHealth.Int}]
					;echo drone refreshed cached health ${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]}
				}
				; We are using my new configs, this denotes we have drones that are primarily Shield HP heavy - We will allow slightly more shield HP damage per loop, less recalling.
				if ${Config.ShieldDrones}
				{
					CurrentDroneHealth:Set[${Math.Calc[(${DroneIterator.Value.ToEntity.ShieldPct.Int} *1.25) + ${DroneIterator.Value.ToEntity.ArmorPct.Int} + ${DroneIterator.Value.ToEntity.StructurePct.Int}]}]
					;This is for abyss, if we've got edencom lightning blasters we need drones to ignore more damage or we will get looped.
					if ${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]} && ${CurrentDroneHealth} < ${Math.Calc[${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]} - 30]} && \
					${Entity[Name =- "Skybreaker" || Name =- "Stormbringer" || Name =- "Thunderchild"](exists)}
					{
						;echo recalling ID ${DroneIterator.Value.ID}
						Drones:Recall["ID = ${DroneIterator.Value.ID}", 1]
					}
					if ${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]} && ${CurrentDroneHealth} < ${Math.Calc[${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]} - 15]} && \
					!${Entity[Name =- "Skybreaker" || Name =- "Stormbringer" || Name =- "Thunderchild"](exists)}
					{
						;echo recalling ID ${DroneIterator.Value.ID}
						Drones:Recall["ID = ${DroneIterator.Value.ID}", 1]
					}
					Drones.DroneHealth:Set[${DroneIterator.Value.ID}, ${CurrentDroneHealth.Int}]
					;echo drone refreshed cached health ${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]}
				}	
			}
			while ${DroneIterator:Next(exists)}
		}


		if !${Entity[${currentTarget}](exists)} || ${Entity[${currentTarget}].IsMoribund} || (!${Entity[${currentTarget}].IsLockedTarget} && !${Entity[${currentTarget}].BeingTargeted}) || ${Entity[${currentTarget}].Distance} > ${droneEngageRange}
		{
			finalizedDC:Set[FALSE]
			currentTarget:Set[0]
		}

		variable iterator lockedTargetIterator
		variable iterator activeJammerIterator
		Ship:BuildActiveJammerList

		if ${currentTarget} != 0
		{
			

			if ${Marshal.TargetList.Used}
			{
				This:LogInfo["Debug - Marshal - DC"]
				if ${Marshal.LockedTargetList.Used}
				{
					currentTarget:Set[${Marshal.LockedTargetList.Get[1]}]
					This:LogInfo["Kill The Damn Marshals"]
					finalizedDC:Set[TRUE]
				}
			}
			
			if ${RemoteRepJerkz.TargetList.Used} && !${Marshal.TargetList.Used}
			{
				This:LogInfo["Debug - RRJerks - DC"]
				if ${RemoteRepJerkz.LockedTargetList.Used}
				{
					currentTarget:Set[${RemoteRepJerkz.LockedTargetList.Get[1]}]
					This:LogInfo["Kill RemoteReppers"]
					finalizedDC:Set[TRUE]
				}
			}

			if ${StarvingJerks.TargetList.Used} && !${Marshal.TargetList.Used} && !${RemoteRepJerkz.TargetList.Used}
			{
				This:LogInfo["Debug - Neuting Jerks - DC"]
				if ${StarvingJerks.LockedTargetList.Used}
				{
					currentTarget:Set[${StarvingJerks.LockedTargetList.Get[1]}]
					This:LogInfo["Kill Neuts"]
					finalizedDC:Set[TRUE]
				}
			}				

			if ${Leshaks.TargetList.Used} && !${Marshal.TargetList.Used} && !${RemoteRepJerkz.TargetList.Used} && !${StarvingJerks.TargetList.Used}
			{
				This:LogInfo["Debug - Leshaks - DC"]
				if ${Leshaks.LockedTargetList.Used}
				{
					currentTarget:Set[${Leshaks.LockedTargetList.Get[1]}]
					This:LogInfo["Kill The Leshaks"]
					finalizedDC:Set[TRUE]
				}
			}
			
			if ${Kikimoras.TargetList.Used} && !${Marshal.TargetList.Used} && !${RemoteRepJerkz.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used}
			{
				This:LogInfo["Debug - Kikimoras - DC"]
				if ${Kikimoras.LockedTargetList.Used}
				{
					currentTarget:Set[${Kikimoras.LockedTargetList.Get[1]}]
					This:LogInfo["Kill The Kikimoras"]
					finalizedDC:Set[TRUE]
				}
			}

			if ${Damaviks.TargetList.Used} && !${Marshal.TargetList.Used} && !${RemoteRepJerkz.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
			!${Kikimoras.TargetList.Used}
			{
				This:LogInfo["Debug - Damaviks - DC"]
				if ${Damaviks.LockedTargetList.Used}
				{
					currentTarget:Set[${Damaviks.LockedTargetList.Get[1]}]
					This:LogInfo["Kill The Damaviks"]
					finalizedDC:Set[TRUE]
				}
			}
			
			if ${Vedmaks.TargetList.Used} && !${Marshal.TargetList.Used} && !${RemoteRepJerkz.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
			!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used}
			{
				This:LogInfo["Debug - Vedmaks - DC"]
				if ${Vedmaks.LockedTargetList.Used}
				{
					currentTarget:Set[${Vedmaks.LockedTargetList.Get[1]}]
					This:LogInfo["Kill The Vedmaks"]
					finalizedDC:Set[TRUE]
				}
			}

			if ${Drekavacs.TargetList.Used} && !${Marshal.TargetList.Used} && !${RemoteRepJerkz.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
			!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used} && !${Vedmaks.TargetList.Used}
			{
				This:LogInfo["Debug - Drekavacs - DC"]
				if ${Drekavacs.LockedTargetList.Used}
				{
					currentTarget:Set[${Drekavacs.LockedTargetList.Get[1]}]
					This:LogInfo["Kill The Drekavacs"]
					finalizedDC:Set[TRUE]
				}
			}			
			
			if ${Cynabals.TargetList.Used} && !${Marshal.TargetList.Used} && !${RemoteRepJerkz.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
			!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used} && !${Vedmaks.TargetList.Used} && !${Drekavacs.TargetList.Used}
			{
				This:LogInfo["Debug - Cynabals - DC"]
				if ${Cynabals.LockedTargetList.Used}
				{
					currentTarget:Set[${Cynabals.LockedTargetList.Get[1]}]
					This:LogInfo["Kill The Cynabals"]
					finalizedDC:Set[TRUE]
				}
			}

			if ${Dramiels.TargetList.Used} && !${Marshal.TargetList.Used} && !${RemoteRepJerkz.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
			!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used} && !${Vedmaks.TargetList.Used} && !${Drekavacs.TargetList.Used} && !${Cynabals.TargetList.Used}
			{
				This:LogInfo["Debug - Dramiels - DC"]
				if ${Dramiels.LockedTargetList.Used}
				{
					currentTarget:Set[${Dramiels.LockedTargetList.Get[1]}]
					This:LogInfo["Kill The Dramiels"]
					finalizedDC:Set[TRUE]
				}
			}			
			if ${FightOrFlight.IsEngagingGankers} && !${FightOrFlight.currentTarget.Equal[0]} && !${FightOrFlight.currentTarget.Equal[${currentTarget}]}
			{
				currentTarget:Set[${FightOrFlight.currentTarget}]
				This:LogInfo["Switching target to ganker \ar${Entity[${currentTarget}].Name}"]
				finalizedDC:Set[TRUE]
			}

			if !${finalizedDC} && ${Ship.ActiveJammerList.Used}
			{
				if !${Ship.ActiveJammerSet.Contains[${currentTarget}]}
				{
					; Being jammed but the jammer is not the current target
					Ship.ActiveJammerList:GetIterator[activeJammerIterator]
					do
					{
						if ${Entity[${activeJammerIterator.Value}].IsLockedTarget} && ${Entity[${activeJammerIterator.Value}].Distance} < ${droneEngageRange}
						{
							currentTarget:Set[${activeJammerIterator.Value}]
							This:LogInfo["Switching target to activate jammer \ar${Entity[${currentTarget}].Name}"]
							finalizedDC:Set[TRUE]
							break
						}
					}
					while ${activeJammerIterator:Next(exists)}
				}
				else
				{
					finalizedDC:Set[TRUE]
				}
			}
			; May switch target more than once so use this flag to avoid log spamming.
			variable bool switched
			if !${finalizedDC} && !${Ship.IsHardToDealWithTarget[${currentTarget}]} && ${ActiveNPCs.LockedTargetList.Used}
			{
				; Switch to difficult target for the ship
				switched:Set[FALSE]
				ActiveNPCs.LockedTargetList:GetIterator[lockedTargetIterator]
				do
				{
					if ${Entity[${lockedTargetIterator.Value}].Distance} < ${droneEngageRange} && ${Ship.IsHardToDealWithTarget[${lockedTargetIterator.Value}]} && \
					(!${Ship.IsHardToDealWithTarget[${currentTarget}]} || ${Entity[${currentTarget}].Distance} > ${Entity[${lockedTargetIterator.Value}].Distance})
					{
						currentTarget:Set[${lockedTargetIterator.Value}]
						switched:Set[TRUE]
					}
				}
				while ${lockedTargetIterator:Next(exists)}
				if ${switched}
				{
					This:LogInfo["Switching to target skipped by ship: \ar${Entity[${currentTarget}].Name}"]
				}
			}
		}
		elseif ${FightOrFlight.IsEngagingGankers} && !${FightOrFlight.currentTarget.Equal[0]} && ${Entity[${FightOrFlight.currentTarget}](exists)}
		{
			currentTarget:Set[${FightOrFlight.currentTarget}]
			This:LogInfo["Engaging ganker \ar${Entity[${currentTarget}].Name}"]
		}
		elseif ${Marshal.TargetList.Used}
		{
			This:LogInfo["Debug - Marshal - DC"]
			if ${Marshal.LockedTargetList.Used}
			{
				currentTarget:Set[${Marshal.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Damn Marshals"]
				finalizedDC:Set[TRUE]
			}
		}
		elseif ${RemoteRepJerkz.TargetList.Used} && !${Marshal.TargetList.Used} 
		{
			This:LogInfo["Debug - RRJerks - DC"]
			if ${RemoteRepJerkz.LockedTargetList.Used}
			{
				currentTarget:Set[${RemoteRepJerkz.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Damn Remote Reps"]
				finalizedDC:Set[TRUE]
			}
		}
		elseif ${StarvingJerks.TargetList.Used} && !${Marshal.TargetList.Used} && !${RemoteRepJerkz.TargetList.Used}
		{
			This:LogInfo["Debug - Neuting Jerks - DC"]
			if ${StarvingJerks.LockedTargetList.Used}
			{
				currentTarget:Set[${StarvingJerks.LockedTargetList.Get[1]}]
				This:LogInfo["Kill Neuts"]
				finalizedDC:Set[TRUE]
			}
		}	
		elseif ${Leshaks.TargetList.Used} && !${Marshal.TargetList.Used} && !${RemoteRepJerkz.TargetList.Used} && !${StarvingJerks.TargetList.Used}
		{
			This:LogInfo["Debug - Leshaks - DC"]
			if ${Leshaks.LockedTargetList.Used}
			{
				currentTarget:Set[${Leshaks.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Leshaks"]
				finalizedDC:Set[TRUE]
			}
		}
			
		elseif ${Kikimoras.TargetList.Used} && !${Marshal.TargetList.Used} && !${RemoteRepJerkz.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used}
		{
			This:LogInfo["Debug - Kikimoras - DC"]
			if ${Kikimoras.LockedTargetList.Used}
			{
				currentTarget:Set[${Kikimoras.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Kikimoras"]
				finalizedDC:Set[TRUE]
			}
		}
		elseif ${Damaviks.TargetList.Used} && !${Marshal.TargetList.Used} && !${RemoteRepJerkz.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
		!${Kikimoras.TargetList.Used}
		{
			This:LogInfo["Debug - Damaviks - DC"]
			if ${Damaviks.LockedTargetList.Used}
			{
				currentTarget:Set[${Damaviks.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Damaviks"]
				finalizedDC:Set[TRUE]
			}
		}
			
		elseif ${Vedmaks.TargetList.Used} && !${Marshal.TargetList.Used} && !${RemoteRepJerkz.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
		!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used}
		{
			This:LogInfo["Debug - Vedmaks - DC"]
			if ${Vedmaks.LockedTargetList.Used}
			{
				currentTarget:Set[${Vedmaks.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Vedmaks"]
				finalizedDC:Set[TRUE]
			}
		}

		elseif ${Drekavacs.TargetList.Used} && !${Marshal.TargetList.Used} && !${RemoteRepJerkz.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
		!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used} && !${Vedmaks.TargetList.Used}
		{
			This:LogInfo["Debug - Drekavacs - DC"]
			if ${Drekavacs.LockedTargetList.Used}
			{
				currentTarget:Set[${Drekavacs.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Drekavacs"]
				finalizedDC:Set[TRUE]
			}
		}			
		
		elseif ${Cynabals.TargetList.Used} && !${Marshal.TargetList.Used} && !${RemoteRepJerkz.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
		!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used} && !${Vedmaks.TargetList.Used} && !${Drekavacs.TargetList.Used}
		{
			This:LogInfo["Debug - Cynabals - DC"]
			if ${Cynabals.LockedTargetList.Used}
			{
				currentTarget:Set[${Cynabals.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Cynabals"]
				finalizedDC:Set[TRUE]
			}
		}

		elseif ${Dramiels.TargetList.Used} && !${Marshal.TargetList.Used} && !${RemoteRepJerkz.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
		!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used} && !${Vedmaks.TargetList.Used} && !${Drekavacs.TargetList.Used} && !${Cynabals.TargetList.Used}
		{
			This:LogInfo["Debug - Dramiels - DC"]
			if ${Dramiels.LockedTargetList.Used}
			{
				currentTarget:Set[${Dramiels.LockedTargetList.Get[1]}]
				This:LogInfo["Kill The Dramiels"]
				finalizedDC:Set[TRUE]
			}
		}

		elseif ${ActiveNPCs.LockedTargetList.Used} && !${Marshal.TargetList.Used} && !${RemoteRepJerkz.TargetList.Used} && !${StarvingJerks.TargetList.Used} && !${Leshaks.TargetList.Used} && \
		!${Kikimoras.TargetList.Used} && !${Damaviks.TargetList.Used} && !${Vedmaks.TargetList.Used} && !${Drekavacs.TargetList.Used} && !${Cynabals.TargetList.Used}
		{
			; Need to re-pick from locked target
			if ${Ship.ActiveJammerList.Used}
			{
				Ship.ActiveJammerList:GetIterator[activeJammerIterator]
				do
				{
					if ${Entity[${activeJammerIterator.Value}].IsLockedTarget} && ${Entity[${activeJammerIterator.Value}].Distance} < ${droneEngageRange}
					{
						currentTarget:Set[${activeJammerIterator.Value}]
						This:LogInfo["Targeting activate jammer \ar${Entity[${currentTarget}].Name}"]
						break
					}
				}
				while ${activeJammerIterator:Next(exists)}
			}

			if ${currentTarget} == 0
			{
				ActiveNPCs.LockedTargetList:GetIterator[lockedTargetIterator]
				do
				{
					if ${Entity[${lockedTargetIterator.Value}].Distance} < ${droneEngageRange} && \
					(!${Entity[${currentTarget}](exists)} || \
					(!${Ship.IsHardToDealWithTarget[${currentTarget}]} && (${Ship.IsHardToDealWithTarget[${lockedTargetIterator.Value}]} || ${Entity[${currentTarget}].Distance} > ${Entity[${lockedTargetIterator.Value}].Distance})))
					{
						currentTarget:Set[${lockedTargetIterator.Value}]
					}
				}
				while ${lockedTargetIterator:Next(exists)}
			}

			if ${currentTarget} != 0
			{
				This:LogInfo["Primary target: \ar${Entity[${currentTarget}].Name}"]
			}
		}

		if ${currentTarget} != 0
		{
			if ${Drones.ActiveDroneCount["ToEntity.GroupID = GROUP_SCOUT_DRONE || ToEntity.GroupID = GROUP_COMBAT_DRONE"]} > 0 && \
			   ${Entity[${currentTarget}].Distance} < ${Me.DroneControlDistance}
			{
				;echo ${MaxDroneCount} drones engaging
				Drones:Engage["ToEntity.GroupID = GROUP_SCOUT_DRONE || ToEntity.GroupID = GROUP_COMBAT_DRONE", ${currentTarget}]
			}

			if ${MaxDroneCount} > ${Drones.ActiveDroneCount}
			{
				if ${MyShip.ToEntity.Type.Find[Rattlesnake]} || ${MyShip.ToEntity.Type.Find[Ishtar]}
				{
					Drones:Deploy["TypeID = ${Drones.Data.FindType[Heavy Attack Drones]}", ${Math.Calc[${MaxDroneCount} - ${Drones.ActiveDroneCount}]}]
				}
				if ${Entity[${currentTarget}].Distance} > ${Me.DroneControlDistance}
				{
					Drones:Deploy["TypeID = ${Drones.Data.FindType[Fighters]}", ${Math.Calc[${MaxDroneCount} - ${Drones.ActiveDroneCount}]}]
				}
				elseif ${Entity[${currentTarget}].Distance} > (${Config.SentryRange} * 1000) && ${Config.Sentries}
				{
					Drones:Deploy["TypeID = ${Drones.Data.FindType[Sentry Drones]}", ${Math.Calc[${MaxDroneCount} - ${Drones.ActiveDroneCount}]}]
				}
				else
				{
					Drones:Deploy["TypeID = ${This.FindBestType[${Entity[${currentTarget}].GroupID}]}", ${Math.Calc[${MaxDroneCount} - ${Drones.ActiveDroneCount}]}]
				}
				IsBusy:Set[TRUE]
				Busy:SetBusy["DroneControl"]
			}

			Drones:RefreshActiveTypes
		}

		if ${CommonConfig.Tehbot_Mode.Equal["Abyssal"]}
		{
			if (${currentTarget} == 0 && ${Drones.ActiveDroneCount["ToEntity.GroupID = GROUP_SCOUT_DRONE || ToEntity.GroupID = GROUP_COMBAT_DRONE"]} > 0) && !${This.JerkzPresent}
			{
				Drones:Recall["ToEntity.GroupID = GROUP_SCOUT_DRONE || ToEntity.GroupID = GROUP_COMBAT_DRONE"]
				This:QueueState["Idle", 5000]
				This:QueueState["DroneControl"]
				return TRUE
			}
		}
		else
		{
			if (${currentTarget} == 0 && ${Drones.ActiveDroneCount["ToEntity.GroupID = GROUP_SCOUT_DRONE || ToEntity.GroupID = GROUP_COMBAT_DRONE"]} > 0)
			{
				Drones:Recall["ToEntity.GroupID = GROUP_SCOUT_DRONE || ToEntity.GroupID = GROUP_COMBAT_DRONE"]
				This:QueueState["Idle", 5000]
				This:QueueState["DroneControl"]
				return TRUE
			}		
		}
		return FALSE
	}

}
