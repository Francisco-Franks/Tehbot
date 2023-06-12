objectdef obj_Configuration_MinerForeman inherits obj_Configuration_Base
{
	
	method Initialize()
	{
		This[parent]:Initialize["MinerForeman"]

	}
	

	method Set_Default_Values()
	{
		This.ConfigRef:AddSetting[LogLevelBar, LOG_INFO]
	}

	Setting(bool, IndustrialCoreOnDemand, SetIndustrialCoreOnDemand)
	
	Setting(bool, UsingCommandBursts, SetUsingCommandBursts)	

	
	Setting(int, LogLevelBar, SetLogLevelBar)
}

objectdef obj_MinerForeman inherits obj_StateQueue
{
	; Avoid name conflict with common config.
	variable obj_Configuration_MinerForeman Config
	
	variable int MaxTarget = ${MyShip.MaxLockedTargets}


	
	; This will literally just be all (hostile) NPCs within 300km or so.
	variable obj_TargetList ActiveNPCs
	; This will be our Fleet Members on grid.
	variable obj_TargetList FleetPCs
	; This will be Other Players not in the fleet, on grid.
	variable obj_TargetList PCs
	; This will be Asteroids
	variable obj_TargetList Asteroids
	; This will be Ice
	variable obj_TargetList Ice
	; This will be Gas
	variable obj_TargetList Gas
	
	

	
	; Is it in fact, time to mine?
	variable bool MiningTime
	; Is it time to activate the industrial core?
	variable bool CoreGreen
	; Is it time to activate the Compressor?
	variable bool CompressorGreen
	; Is it time to move on to the next Location? (warp)
	variable bool ChangeVenue
	; Do we need to start moving to a different area in the current location? (burn)
	variable bool MoveAlong
	; Are we inhibiting our Command Burst Usage (we need to dock soon, for instance)
	variable bool InhibitBursts
	
	variable bool TargetQueriesCreated = FALSE
	
	variable int64 BurstTimer

	method Initialize()
	{
		This[parent]:Initialize

		DynamicAddMiniMode("MinerForeman", "MinerForeman")
		This.PulseFrequency:Set[5000]

		This.NonGameTiedPulse:Set[TRUE]


		This.LogLevelBar:Set[${Config.LogLevelBar}]
		
		
	}

	method Start()
	{
		AttackTimestamp:Clear

		if ${This.IsIdle}
		{
			This:LogInfo["Starting"]
			This:QueueState["MinerForeman"]
		}
	}
	
	method Stop()
	{
		This:Clear
	}
	
	; This exists to tell TargetList what exactly each Target List should be looking for.
	method CreateTargetQueries()
	{
		; I'm not sure why I am clearing and re-entering the queries for these over and over. I'm sure there is a reason.
		ActiveNPCs:ClearQueryString
		FleetPCs:ClearQueryString
		PCs:ClearQueryString
		Asteroids:ClearQueryString
		Ice:ClearQueryString
		Gas:ClearQueryString
		
		; First up, All NPCs, filtering out the ones we really don't want to mess with.
		ActiveNPCs:AddAllNPCs
		; That was difficult, next up we will get our fleet members on grid.
		FleetPCs:AddAllFleetPC
		; Next up, non fleet member players on grid.
		PCs:AddAllPC
		; Ok now things get funkier. These will be query strings instead of canned TargetList stuff. For the purposes of THIS minimode
		; We only really care about the existence of these things and how far they are.
		Asteroids:AddQueryString["CategoryID = 25 && Group !~ Ice && Distance < 100000"]
		Ice:AddQueryString["CategoryID = 25 && Group == Ice && Distance < 100000"]
		Gas:AddQueryString["GroupID = 711 && Distance < 50000"]
		TargetQueriesCreated:Set[TRUE]
		
	}
	
	; Use TargetList to see if we have anything to mine here
	method CheckForMineables()
	{
		Asteroids:RequestUpdate
		Ice:RequestUpdate
		Gas:RequestUpdate
	}

	; Use TargetList to see if we have anything to run away from here
	method CheckForHostiles()
	{
		ActiveNPCs:RequestUpdate
		PCs:RequestUpdate
	}

	; Use TargetList to see if we have anything to mine here
	method CheckForFriendlies()
	{
		FleetPCs:RequestUpdate
		PCs:RequestUpdate
	}
	; Main loop for this minimode.
	member:bool MinerForeman()
	{
		if ${Me.InStation}
		{
			return FALSE
		}
		if !${Client.InSpace}
		{
			return FALSE
		}
		;if !${Mining.ClearToMine}
		;{
		;	return FALSE
		;}
		if !${TargetQueriesCreated}
		{
			This:CreateTargetQueries
		}
		This:CheckForMineables
		This:CheckForHostiles
		This:CheckForFriendlies
		
		; We are set to not fight npcs, and there are npcs, no more bursts, no more mining. Mainmode should pull us out of here.
		if ${ActiveNPCs.TargetList.Used} && !${Mining.Config.FightNPCs}
		{
			MiningTime:Set[FALSE]
			InhibitBursts:Set[TRUE]
			CoreGreen:Set[FALSE]
		}
		
		if (${Asteroids.TargetList.Used} || ${Ice.TargetList.Used} || ${Gas.TargetList.Used})
		{
			if ((${ActiveNPCs.TargetList.Used} && ${Mining.Config.FightNPCs}) || !${ActiveNPCs.TargetList.Used})
			{
				MiningTime:Set[TRUE]
				InhibitBursts:Set[FALSE]
				CoreGreen:Set[TRUE]
			}
			if !${FriendlyLocal} && ${Mining.Config.RunFromBads}
			{
				MiningTime:Set[FALSE]
				InhibitBursts:Set[TRUE]
				CoreGreen:Set[FALSE]
			}
			; Not ready yet
			;if ${Mining.Config.RunFromSuspicious}
			;{
			;	if ${PCs.TargetList.Used}
			;	{
			;		do
			;		{
			;			
			;		}
			;		while 
			;	}
			;}
		}
		
		; There is nothing mineable here. Turn off the stuff and wait for Mainmode to move us out of here.
		if (!${Asteroids.TargetList.Used} && !${Ice.TargetList.Used} && !${Gas.TargetList.Used})
		{
			MiningTime:Set[FALSE]
			InhibitBursts:Set[TRUE]
			CoreGreen:Set[FALSE]
			MoveAlong:Set[TRUE]
		}
		; We are good to activate the core, and someone has requested compression.Oh also we have a core, and a compressor. Activate them.
		if ${CoreGreen} && ${Mining.CompressionRequest} && ${Ship.ModuleList_Siege.Count} > 0 && ${Ship.ModuleList_Compressors.Count} > 0
		{
			Ship.ModuleList_Siege:ActivateOne
			Ship.ModuleList_Compressors:ActivateOne
			Ship.ModuleList_Siege:DeactivateAll
			Ship.ModuleList_Compressors:DeactivateAll
			CompressorGreen:Set[FALSE]
		}
		if ${Ship.ModuleList_Compressors.ActiveCount} > 0
		{
			relay all -event CompressionActive TRUE
		}
		if ${Ship.ModuleList_Compressors.ActiveCount} == 0
		{
			relay all -event CompressionActive FALSE
		}		
		if ${Ship.ModuleList_CommandBurst.Count} > 0 && !${InhibitBursts} && ${LavishScript.RunningTime} >= ${BurstTimer} && ${FleetPCs.TargetList.Used} > 1
		{
			Ship.ModuleList_CommandBurst:ActivateAll
			BurstTimer:Set[${Math.Calc[${LavishScript.RunningTime} + 115000]}]
		}

		
		return FALSE
	}
}