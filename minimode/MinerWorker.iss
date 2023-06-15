objectdef obj_Configuration_MinerWorker inherits obj_Configuration_Base
{
	
	method Initialize()
	{
		This[parent]:Initialize["MinerWorker"]
		
		This.ConfigRef:AddSetting[BezdnacinePriority, 1]
		This.ConfigRef:AddSetting[CobaltitePriority, 1]
		This.ConfigRef:AddSetting[AmberCytoserocinPriority, 1]
	}
	

	method Set_Default_Values()
	{
		This.ConfigRef:AddSetting[LogLevelBar, LOG_INFO]
	}


	Setting(bool, ExpectCommandBursts, SetExpectCommandBursts)

	; Section for Asteroid Ore Priorities
	Setting(int, ArkonorPriority, SetArkonorPriority)	
	Setting(int, BezdnacinePriority, SetBezdnacinePriority)
	Setting(int, BistotPriority, SetBistotPriority)
	Setting(int, CrokitePriority, SetCrokitePriority)
	Setting(int, DarkOchrePriority, SetDarkOchrePriority)
	Setting(int, DuciniumPriority, SetDuciniumPriority)
	Setting(int, EifyriumPriority, SetEifyriumPriority)
	Setting(int, GneissPriority, SetGneissPriority)
	Setting(int, HedbergitePriority, SetHedbergitePriority)
	Setting(int, HemorphitePriority, SetHemorphitePriority)
	Setting(int, JaspetPriority, SetJaspetPriority)
	Setting(int, KernitePriority, SetKernitePriority)
	Setting(int, MercoxitPriority, SetMercoxitPriority)
	Setting(int, MorduniumPriority, SetMorduniumPriority)
	Setting(int, OmberPriority, SetOmberPriority)
	Setting(int, PlagioclasePriority, SetPlagioclasePriority)
	Setting(int, PyroxeresPriority, SetPyroxeresPriority)
	Setting(int, RakovenePriority, SetRakovenePriority)
	Setting(int, ScorditePriority, SetScorditePriority)
	Setting(int, SpodumainPriority, SetSpodumainPriority)
	Setting(int, TalassonitePriority, SetTalassonitePriority)
	Setting(int, VeldsparPriority, SetVeldsparPriority)
	Setting(int, YtiriumPriority, SetYtiriumPriority)

	; Section for Moon Ore Priorities
	Setting(int, CobaltitePriority, SetCobaltitePriority)
	Setting(int, EuxenitePriority, SetEuxenitePriority)
	Setting(int, TitanitePriority, SetTitanitePriority)
	Setting(int, ScheelitePriority, SetScheelitePriority)
	
	Setting(int, BitumensPriority, SetBitumensPriority)
	Setting(int, CoesitePriority, SetCoesitePriority)
	Setting(int, SylvitePriority, SetSylvitePriority)
	Setting(int, ZeolitesPriority, SetZeolitesPriority)
	
	Setting(int, ChromitePriority, SetChromitePriority)
	Setting(int, OtavitePriority, SetOtavitePriority)
	Setting(int, SperrylitePriority, SetSperrylitePriority)
	Setting(int, VanadinitePriority, SetVanadinitePriority)
	
	Setting(int, CarnotitePriority, SetCarnotitePriority)
	Setting(int, CinnabarPriority, SetCinnabarPriority)
	Setting(int, PollucitePriority, SetPollucitePriority)
	Setting(int, ZirconPriority, SetZirconPriority)

	Setting(int, LoparitePriority, SetLoparitePriority)
	Setting(int, MonazitePriority, SetMonazitePriority)
	Setting(int, XenotimePriority, SetXenotimePriority)
	Setting(int, YtterbitePriority, SetYtterbitePriority)

	; Section for Gas Priorities
	Setting(int, AmberCytoserocinPriority, SetAmberCytoserocinPriority)
	Setting(int, AmberMykoserocinPriority, SetAmberMykoserocinPriority)
	Setting(int, AzureCytoserocinPriority, SetAzureCytoserocinPriority)
	Setting(int, AzureMykoserocinPriority, SetAzureMykoserocinPriority)
	Setting(int, CeladonCytoserocinPriority, SetCeladonCytoserocinPriority)
	Setting(int, CeladonMykoserocinPriority, SetCeladonMykoserocinPriority)
	Setting(int, GoldenCytoserocinPriority, SetGoldenCytoserocinPriority)
	Setting(int, GoldenMykoserocinPriority, SetGoldenMykoserocinPriority)
	Setting(int, LimeCytoserocinPriority, SetLimeCytoserocinPriority)
	Setting(int, LimenMykoserocinPriority, SetLimeMykoserocinPriority)
	Setting(int, MalachiteCytoserocinPriority, SetMalachiteCytoserocinPriority)
	Setting(int, MalachiteMykoserocinPriority, SetMalachiteMykoserocinPriority)	
	Setting(int, VermillionCytoserocinPriority, SetVermillionCytoserocinPriority)
	Setting(int, VermillionMykoserocinPriority, SetVermillionMykoserocinPriority)
	Setting(int, ViridianCytoserocinPriority, SetViridianCytoserocinPriority)
	Setting(int, ViridianMykoserocinPriority, SetViridianMykoserocinPriority)
	
	Setting(int, Fullerite-C28Priority, SetFullerite-C28Priority)
	Setting(int, Fullerite-C32Priority, SetFullerite-C32Priority)
	Setting(int, Fullerite-C320Priority, SetFullerite-C320Priority)
	Setting(int, Fullerite-C50Priority, SetFullerite-C50Priority)
	Setting(int, Fullerite-C540Priority, SetFullerite-C540Priority)
	Setting(int, Fullerite-C60Priority, SetFullerite-C60Priority)
	Setting(int, Fullerite-C70Priority, SetFullerite-C70Priority)
	Setting(int, Fullerite-C72Priority, SetFullerite-C72Priority)
	Setting(int, Fullerite-C84Priority, SetFullerite-C84Priority)
	
	
	
	Setting(int, LogLevelBar, SetLogLevelBar)
}

objectdef obj_MinerWorker inherits obj_StateQueue
{
	; Avoid name conflict with common config.
	variable obj_Configuration_MinerWorker Config
	
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
	; This will be Asteroids without a distance limitation
	variable obj_TargetList AsteroidsDistant
	; This will be Ice without a distance limitation
	variable obj_TargetList IceDistant
	; This will be Gas without a distance limitation
	variable obj_TargetList GasDistant
	
	; This collection is to help create the sets below. Key is the name of the mineable
	; Value is the priority number assigned.
	variable collection:int PriorityCollection
	; This set is for Ignored Mineables
	variable set IgnoredMineables
	; This set is for Highest Priority Mineables
	variable set HighPriorityMineables
	; This set is for Medium Priority Mineables
	variable set MediumPriorityMineables
	; This set is for Lowest Priority Mineables
	variable set LowPriorityMineables
	
	; This is going to be 
	
	; This string is for creating our prioritization query for Asteroids
	variable string PrioAst = ""
	
	; This string is for creating our prioritization query for Gas Stuff
	variable string PrioGas = ""
	
	; This string is so I can do stupid crap to modify the query string the way I need to.
	variable string PrioSeperator = ""
	
	; This string is for a large string of all allowable mineables
	variable string SuperAllowablesList = ""
	
	; Lets not create these queries over and over
	variable bool TargetQueriesCreated = FALSE
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
	; If this is true, we should request compression from our Foreman
	variable bool NeedCompression
	; This bool exists to trigger priority list recalculating
	variable bool ReCalculatePriorities = FALSE
	; Need to close the UI element we have to force open, but without making it unusable in the future
	; and this is the stupidest way I could think of to do it.
	variable int YouOnlyRunTwice
	; This collection will be used in my travel corridor thing. Key is ID, int64 is also entity ID, don't ask
	variable collection:int64 MineablesCollection

	; This will all be so I can sort the stuff by distance.
	; First up, 3 collections, one for each mineable category. Key is DISTANCE, value is entity ID.
	variable collection:int64 AsteroidSort
	variable collection:int64 IceSort
	variable collection:int64 GasSort
	
	; Next up, 3 queues, so we can sort ascending.
	variable queue:int64 AsteroidSortAscend
	variable queue:int64 IceSortAscend
	variable queue:int64 GasSortAscend
	
	; Next up, 3 stacks, so we can sort descending
	variable stack:int64 AsteroidSortDescend
	variable stack:int64 IceSortDescend
	variable stack:int64 GasSortDescend
	
	; Next up, two variables for storing the IDs of the current furthest and closest MineableSorting
	variable int64 ClosestMineable
	variable int64 FurthestMineable
	
	; Next up, a bool that uses our distant target list combined with the LavishNavTest minimode to 
	; See if we have any mineables within 5 minutes (for now) of us on our current path of movement.
	; Intended to be used with AlignHomeStructure.
	variable bool MineablesAhead
	; This int is the threshold for mineables ahead where we consider it "worth it" to continue
	

	; This timer will be used to limit the refresh speed on updating our mineables list and checking our travel corridor for mineables.
	variable int64 UpdateTimer	
	; This int will define how often in seconds we want to update the above. Lets start with a hardcoded 30.
	variable int UpdateFrequency = 30

	method Initialize()
	{
		This[parent]:Initialize

		DynamicAddMiniMode("MinerWorker", "MinerWorker")
		This.PulseFrequency:Set[5000]

		This.NonGameTiedPulse:Set[TRUE]
		
		if !${PriorityCollection.FirstValue} && ${CommonConfig.Tehbot_Mode.Equal["Mining"]}
		{
			timedcommand 0 "ui -load \"${Script.CurrentDirectory}/minimode/MinerWorker.xml\""
			
			timedcommand 30 "ui -unload \"${Script.CurrentDirectory}/minimode/MinerWorker.xml\""
		}
		This.LogLevelBar:Set[${Config.LogLevelBar}]
		ActiveNPCs.NeedUpdate:Set[FALSE]
		FleetPCs.NeedUpdate:Set[FALSE]
		PCs.NeedUpdate:Set[FALSE]
		Asteroids.NeedUpdate:Set[FALSE]
		Ice.NeedUpdate:Set[FALSE]
		Gas.NeedUpdate:Set[FALSE]
		AsteroidsDistant.NeedUpdate:Set[FALSE]
		IceDistant.NeedUpdate:Set[FALSE]
		GasDistant.NeedUpdate:Set[FALSE]
	}

	method Start()
	{
		AttackTimestamp:Clear

		if ${This.IsIdle}
		{
			This:LogInfo["Starting"]
			This:QueueState["MinerWorker"]
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
		; Maybe not, lets see what happens eh.
		; ActiveNPCs:ClearQueryString
		; FleetPCs:ClearQueryString
		; PCs:ClearQueryString
		; Asteroids:ClearQueryString
		; Ice:ClearQueryString
		; Gas:ClearQueryString
		
		; First up, All NPCs, filtering out the ones we really don't want to mess with.
		ActiveNPCs:AddAllNPCs
		; That was difficult, next up we will get our fleet members on grid.
		FleetPCs:AddAllFleetPC
		; Next up, non fleet member players on grid.
		PCs:AddAllPC
		; Is there mineable stuff in range of our mining equipment?
		; We are using prioritization and ARE the fleetboss. Range is hardcoded for now.
		if !${Mining.Config.JustMineIt} && ${Mining.Config.FleetBoss}
		{
			Asteroids:AddQueryString["CategoryID = 25 && GroupID != 465 && Distance < 40000 && (${PrioAst})"]
			AsteroidsDistant:AddQueryString["CategoryID = 25 && GroupID != 465 && (${PrioAst})"]
			Ice:AddQueryString["CategoryID = 25 && GroupID = 465 && Distance < 40000"]
			IceDistant:AddQueryString["CategoryID = 25 && GroupID = 465"]
			Gas:AddQueryString["GroupID = 711 && Distance < 40000 && (${PrioGas})"]
			GasDistant:AddQueryString["GroupID = 711 && (${PrioGas})"]
		}
		; We are using prioritization and aren't the fleetboss.
		elseif !${Mining.Config.JustMineIt} && !${Mining.Config.FleetBoss}
		{
			Asteroids:AddQueryString["CategoryID = 25 && GroupID != 465 && Distance < ${Ship.ModuleList_OreMining.Range} && (${PrioAst})"]
			AsteroidsDistant:AddQueryString["CategoryID = 25 && GroupID != 465 && (${PrioAst})"]
			Ice:AddQueryString["CategoryID = 25 && GroupID = 465 && Distance < ${Ship.ModuleList_IceMining.Range}"]
			IceDistant:AddQueryString["CategoryID = 25 && GroupID = 465"]
			Gas:AddQueryString["GroupID = 711 && Distance < ${Ship.ModuleList_GasMining.Range} && (${PrioGas})"]
			GasDistant:AddQueryString["GroupID = 711 && (${PrioGas})"]
		}
		else
		{
			Asteroids:AddQueryString["CategoryID = 25 && GroupID != 465 && Distance < ${Ship.ModuleList_OreMining.Range}"]
			AsteroidsDistant:AddQueryString["CategoryID = 25 && GroupID != 465"]
			Ice:AddQueryString["CategoryID = 25 && GroupID = 465 && Distance < ${Ship.ModuleList_IceMining.Range}"]
			IceDistant:AddQueryString["CategoryID = 25 && GroupID = 465"]
			Gas:AddQueryString["GroupID = 711 && Distance < ${Ship.ModuleList_GasMining.Range}"]
			GasDistant:AddQueryString["GroupID = 711"]
		}
		TargetQueriesCreated:Set[TRUE]
	}
	
	; This method will be so I can get that ore/gas/ice sort/reverse sort thing going. Wonder how expensive this will be CPU wise.
	
	method MineableSorting()
	{
		; This will all be so I can sort the stuff by distance.
		; First up, 3 collections, one for each mineable category. Key is DISTANCE, value is entity ID.
		variable collection:int64 AsteroidSort
		variable collection:int64 IceSort
		variable collection:int64 GasSort
		
		; Next up, 3 queues, so we can sort ascending.
		variable queue:int64 AsteroidSortAscend
		variable queue:int64 IceSortAscend
		variable queue:int64 GasSortAscend
		
		; Next up, 3 stacks, so we can sort descending
		variable stack:int64 AsteroidSortDescend
		variable stack:int64 IceSortDescend
		variable stack:int64 GasSortDescend		
		
		variable index:entity Mineables
		variable iterator MineablesIterator
		

		
		EVE:QueryEntities[Mineables, "CategoryID = 25 || CategoryID = 711"]
		echo ${Mineables.Used}
		if ${Mineables.Used} == 0
		{
			MineablesCollection:Set[0]
		}
		Mineables:GetIterator[MineablesIterator]

		if !${Mining.Config.JustMineIt}
		{
			Mineables:RemoveByQuery[${LavishScript.CreateQuery["(${SuperAllowablesList})"]}, FALSE]
		}
		if ${MineablesIterator:First(exists)}
		{
			do
			{
				if ${MineablesIterator.Value.CategoryID} == 25 && !${MineablesIterator.Value.Name.Find[Ice]}
				{
					AsteroidSort:Set[${MineablesIterator.Value.Distance.Int.LeadingZeroes[16]}, ${MineablesIterator.Value.ID}]
					MineablesCollection:Set[${MineablesIterator.Value.ID}, ${MineablesIterator.Value.ID}]
					;echo - DEBUG - Adding ${MineablesIterator.Value.Name} to ASTSORT				
				}
				if ${MineablesIterator.Value.CategoryID} == 25 && ${MineablesIterator.Value.Name.Find[Ice]}
				{
					IceSort:Set[${MineablesIterator.Value.Distance.Int.LeadingZeroes[16]}, ${MineablesIterator.Value.ID}]
					MineablesCollection:Set[${MineablesIterator.Value.ID}, ${MineablesIterator.Value.ID}]
					;echo - DEBUG - Adding ${MineablesIterator.Value.Name} to ICESORT
				}
				if ${MineablesIterator.Value.CategoryID} == 711
				{
					GasSort:Set[${MineablesIterator.Value.Distance.Int.LeadingZeroes[16]}, ${MineablesIterator.Value.ID}]
					MineablesCollection:Set[${MineablesIterator.Value.ID}, ${MineablesIterator.Value.ID}]
					;echo - DEBUG - Adding ${MineablesIterator.Value.Name} to GASSORT			
				}
			}
			while ${MineablesIterator:Next(exists)}
		}
		if ${Mineables.Used} <= 0
		{
			MinerWorker.MineablesCollection:Erase
		}
		if ${AsteroidSort.FirstKey}
		{
			do
			{
				AsteroidSortAscend:Queue[${AsteroidSort.CurrentValue}]
				AsteroidSortDescend:Push[${AsteroidSort.CurrentValue}]
			}
			while ${AsteroidSort.NextKey(exists)}
		}
		if ${IceSort.FirstKey}
		{
			do
			{
				IceSortAscend:Queue[${IceSort.CurrentValue}]
				IceSortDescend:Push[${IceSort.CurrentValue}]
			}
			while ${IceSort.NextKey(exists)}
		}
		if ${GasSort.FirstKey}
		{
			do
			{
				GasSortAscend:Queue[${GasSort.CurrentValue}]
				GasSortDescend:Push[${GasSort.CurrentValue}]
			}
			while ${GasSort.NextKey(exists)}
		}
		if ${AsteroidSortAscend.Used}
		{
			ClosestMineable:Set[${AsteroidSortAscend.Peek}]
		}
		if ${AsteroidSortDescend.Used}
		{
			FurthestMineable:Set[${AsteroidSortDescend.Top}]
		}
		if ${IceSortAscend.Used}
		{
			ClosestMineable:Set[${IceSortAscend.Peek}]
		}
		if ${IceSortDescend.Used}
		{
			FurthestMineable:Set[${IceSortDescend.Top}]
		}
		if ${GasSortAscend.Used}
		{
			ClosestMineable:Set[${GasSortAscend.Peek}]
		}
		if ${GasSortDescend.Used}
		{
			FurthestMineable:Set[${GasSortDescend.Top}]
		}
		echo DEBUG - ${Entity[${FurthestMineable}].Name} ${Entity[${FurthestMineable}].Distance.Int.LeadingZeroes[16]} ${Entity[${FurthestMineable}].ID}
		echo DEBUG - ${Entity[${ClosestMineable}].Name} ${Entity[${ClosestMineable}].Distance.Int.LeadingZeroes[16]} ${Entity[${ClosestMineable}].ID}
	}
	
	method CheckOreHold()
	{
		if !${Client.Inventory}
		{
			echo inventory not open
		}
		if !${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipGeneralMiningHold](exists)}
		{
			return FALSE
		}
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipGeneralMiningHold].UsedCapacity} / ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipGeneralMiningHold].Capacity} > 0.8
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold]:StackAll
			if ${Mining.Config.UseCompressor}
			{
				if ${FullOfCompressed}
				{
					Mining.ReturnToStation:Set[TRUE]
					This:LogInfo["Full - Too Much Compressed Mineables - Return to Station to Unload"]
					return FALSE
				}
				elseif ${Mining.CompressionActive}
				{
					This:LogInfo["Compression Active - Compressing Ore"]
					
					variable index:item OreBayContents
					variable iterator OreIterator
		
					MyShip:GetOreHoldCargo[OreBayContents]
					OreBayContents:GetIterator[OreIterator]
		
					if ${OreIterator:First(exists)}
					do
					{
						if (${OreIterator.Value.CategoryID} == 25 && !${OreIterator.Value.Name.Find["Compressed"]}) || (${OreIterator.Value.GroupID} == 711)
						{
							OreIterator.Value:Compress
						}
					}
					while ${OreIterator:Next(exists)}
					
					if ${EVEWindow[compression_window](exists)}
					{
						
						timedcommand 20 "EVEWindow[compression_window].Button[2]:Press"
						timedcommand 30 EVEWindow[compression_window]:Close
					}
				}
				else
				{
					relay all -event CompressorRequest TRUE
					This:LogInfo["Requesting Compression"]
				}
			}	
			else
			{
				Mining.ReturnToStation:Set[TRUE]
				This:LogInfo["Full - No Compression - Return to Station to Unload"]
			}

		}
		else
		{
			if ${Mining.Config.UseCompressor} && !${Mining.Config.FleetBoss}
			{
				relay all -event CompressorRequest FALSE
				This:LogInfo["No need for compression at this time."]
			}
		}
	}
	
	; This will hopefully, if I can code it, return a bool. True if we have too much compressed stuff. False if we do not.
	; Will tinker with the ratio later.
	member:bool FullOfCompressed()
	{
		variable float CompressedOreVolume=0
		variable index:int64 OreBayContents
		variable iterator OreIterator
		
		MyShip:GetOreHoldCargo[OreBayContents]
		OreBayContents:GetIterator[OreIterator]
		
		if ${OreIterator:First(exists)}
		do
		{
			if (${OreIterator.Value.CategoryID} == 25 && ${OreIterator.Value.Name.Find["Compressed"]}) || (${OreIterator.Value.GroupID} == 4168)
			{
				CompressedOreVolume:Inc[${Math.Calc[${OreIterator.Value.Quantity} * ${Ore.Value.Volume}]}]
			}
		}
		while ${OreIterator:Next(exists)}
		
		if ${CompressedOreVolume} >= ${Math.Calc[${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipGeneralMiningHold].Capacity} * 0.75]}
		{
			return TRUE
		}
		else
		{
			return FALSE
		}
		
	}
	; Use TargetList to see if we have anything to mine here
	method CheckForMineables()
	{
		Asteroids:RequestUpdate
		AsteroidsDistant:RequestUpdate
		Ice:RequestUpdate
		IceDistant:RequestUpdate
		Gas:RequestUpdate
		GasDistant:RequestUpdate
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
	; Here is where we will take our PriorityCollection and sort it out into the Priority Sets
	method ReCalcPriorities()
	{
		IgnoredMineables:Clear
		HighPriorityMineables:Clear
		MediumPriorityMineables:Clear
		LowPriorityMineables:Clear
		
		if ${PriorityCollection.FirstValue}
		{
			do
			{
				if ${PriorityCollection.CurrentValue} == 0
				{
					IgnoredMineables:Add[${PriorityCollection.CurrentKey}]
					echo DEBUG - Adding ${PriorityCollection.CurrentKey} to Ignore List
				}
				if ${PriorityCollection.CurrentValue} == 1
				{
					HighPriorityMineables:Add[${PriorityCollection.CurrentKey}]
					echo DEBUG - Adding ${PriorityCollection.CurrentKey} to Highest Priority List
				}
				if ${PriorityCollection.CurrentValue} == 2
				{
					MediumPriorityMineables:Add[${PriorityCollection.CurrentKey}]
					echo DEBUG - Adding ${PriorityCollection.CurrentKey} to Medium Priority List
				}
				if ${PriorityCollection.CurrentValue} == 3
				{
					LowPriorityMineables:Add[${PriorityCollection.CurrentKey}]
					echo DEBUG - Adding ${PriorityCollection.CurrentKey} to Low Priority List
				}
			}
			while ${PriorityCollection.NextKey(exists)}
		}
		
		ReCalculatePriorities:Set[FALSE]
	}
	
	; Here is where we will utilize my prioritization crap I spent all this time on.
	method CommencePrioritization()
	{
		PrioAst:Set["Name =- ThisSpaceForRent"]
		PrioGas:Set["Name =- ThisSpaceForRent"]
		SuperAllowablesList:Set["Name =- ThisSpaceForRent"]
		
		; Need this block to make the master allowed mineables list
		if ${HighPriorityMineables.Used} > 0
		{
			HighPriorityMineables:ForEach["SuperAllowablesList:Concat[\" || Name =- \"\${ForEach.Value}\"\"]"]
		}
		if ${MediumPriorityMineables.Used} > 0
		{
			MediumPriorityMineables:ForEach["SuperAllowablesList:Concat[\" || Name =- \"\${ForEach.Value}\"\"]"]
		}
		if ${LowPriorityMineables.Used} > 0
		{
			LowPriorityMineables:ForEach["SuperAllowablesList:Concat[\" || Name =- \"\${ForEach.Value}\"\"]"]
		}
		
		if ${HighPriorityMineables.Used} > 0
		{
			HighPriorityMineables:ForEach["PrioAst:Concat[\" || Name =- \"\${ForEach.Value}\"\"]"]
			HighPriorityMineables:ForEach["PrioGas:Concat[\" || Name =- \"\${ForEach.Value}\"\"]"]
			This:CheckForMineables
			echo DEBUG - High Priority Mineables Filter Applied
		}
		if ${MediumPriorityMineables.Used} > 0 && (!${Asteroids.TargetList.Used} && !${Ice.TargetList.Used} && !${Gas.TargetList.Used})
		{
			MediumPriorityMineables:ForEach["PrioAst:Concat[\" || Name =- \"\${ForEach.Value}\"\"]"]
			MediumPriorityMineables:ForEach["PrioGas:Concat[\" || Name =- \"\${ForEach.Value}\"\"]"]
			echo DEBUG - Medium Priority Mineables Filter Applied
			This:CheckForMineables
		}
		if ${LowPriorityMineables.Used} > 0 && (!${Asteroids.TargetList.Used} && !${Ice.TargetList.Used} && !${Gas.TargetList.Used})
		{
			LowPriorityMineables:ForEach["PrioAst:Concat[\" || Name =- \"\${ForEach.Value}\"\"]"]
			LowPriorityMineables:ForEach["PrioGas:Concat[\" || Name =- \"\${ForEach.Value}\"\"]"]
			echo DEBUG - Low Priority Mineables Filter Applied
			This:CheckForMineables
		}
	
	}
	; This is the method where we use that lavishnav shit I just suffered through to determine if our VALID MINEABLES are in a box shaped corridor ahead of us
	; Defined by being 300 * our current velocity meters long, and 80% of our mining equipment range across. Pointed ahead of us, naturally. It will set a bool that Mining
	; Mainmode will read to decide whether to leave its current location or not.
	method LookAhead()
	{
		variable int ValidMineablesAhead
		if ${MineablesCollection.FirstValue}
		{
			; Yep its another do while loop sorry.
			do
			{
				if ${LNavRegion[Corridor.TheGrid](exists)}
				{
					if ${LNavRegion[Corridor.TheGrid].Contains[${Entity[${MineablesCollection.CurrentValue}].X},${Entity[${MineablesCollection.CurrentValue}].Y},${Entity[${MineablesCollection.CurrentValue}].Z}]}
					{
						ValidMineablesAhead:Inc[1]
					}
				}
			}
			while ${MineablesCollection.NextValue(exists)}
		}
		; We're going to start with a hardcoded 0 here for now
		if ${ValidMineablesAhead} > 0
		{
			MineablesAhead:Set[TRUE]
		}
		else
		{
			MineablesAhead:Set[FALSE]
		}
	}
	; Main loop for this minimode.
	member:bool MinerWorker()
	{
		if ${Me.InStation}
		{
			return FALSE
		}
		if !${Client.InSpace}
		{
			return FALSE
		}
		if ${Me.ToEntity.Mode} == MOVE_WARPING
		{
			return FALSE
		}
		;echo ${PriorityCollection.FirstValue} Prio Debug
		;echo ${Config.BezdnacinePriority} Bez Debug
		if ${YouOnlyRunTwice} < 2
		{
			YouOnlyRunTwice:Inc[1]
			if ${PriorityCollection.FirstValue}
			{
				timedcommand 0 "ui -unload \"${Script.CurrentDirectory}/minimode/MinerWorker.xml\""
				ReCalculatePriorities:Set[TRUE]
				This:CreateTargetQueries
			}
		}
		; This bool will be set by a UI button. You click it and it sorts priority collection into lists. It will also be triggered once automatically
		; When we start the bot.
		if ${ReCalculatePriorities}
		{
			TargetQueriesCreated:Set[FALSE]
			This:ReCalcPriorities
		}
		if !${Mining.Config.JustMineIt} 
		{
			This:CommencePrioritization
		}
		;if !${Mining.ClearToMine}
		;{
		;	return FALSE
		;}
		if !${TargetQueriesCreated}
		{
			This:CreateTargetQueries
		}
		if (${LavishScript.RunningTime} > ${UpdateTimer})
		{
			UpdateTimer:Set[${Math.Calc[${LavishScript.RunningTime} + ${Math.Calc[${UpdateFrequency} * 1000 ]}]}]
			This:CheckForMineables
			LavishNavTest.TimeForOrb:Set[TRUE]
		}
		This:CheckForHostiles
		This:CheckForFriendlies

		; DEBUG this will be removed after I make sure it god damn works.
		This:LookAhead
		
		
		echo ${Asteroids.TargetList.Used} Asteroid Targets
		echo ${Asteroids.LockedTargetList.Used} Locked Asteroid Targets
		echo ${Ice.TargetList.Used} Ice Targets
		echo ${Ice.LockedTargetList.Used} Locked Ice Targets
		echo ${Asteroids.TargetList.Used} Distant Asteroid Targets
		echo ${IceDistant.TargetList.Used} Distant Ice Targets
		;Asteroids.TargetList:ForEach["echo ${Entity[${ForEach.Value}].X} ${Entity[${ForEach.Value}].Y} ${Entity[${ForEach.Value}].Z}"]
		
		; Alright, lets get down to business here. This minimode exists for the actual miners to do actual mining.
		; This is the mining equivalent of TargetManager, really. What does that mean?
		; We need to do like literally exactly 2 things, find targets (or their absense), apply our modules to those targets.
		; All navigation is being handled by the mainmode, we don't care about local. We don't care about NPCs or other players, none of
		; That shit even matters AT ALL here because hey this is a minimode, it can do whatever it wants while whatever else is going on.
		
		if (${Asteroids.TargetList.Used} || ${Ice.TargetList.Used} || ${Gas.TargetList.Used}) && !${Mining.Config.FleetBoss}
		{
			if ${Asteroids.TargetList.Used}
			{
				Asteroids.AutoLock:Set[TRUE]
			}
			if ${Ice.TargetList.Used}
			{
				Ice.AutoLock:Set[TRUE]
			}
			if ${Gas.TargetList.Used}
			{
				Gas.AutoLock:Set[TRUE]
			}
		}
		
		; We have locked targets of the appropriate type
		if (${Asteroids.LockedTargetList.Used} || ${Ice.LockedTargetList.Used} || ${Gas.LockedTargetList.Used}) 
		{
			if ${Asteroids.LockedTargetList.Used} && ${Ship.ModuleList_OreMining.InactiveCount} > 0
			{
				if ${Asteroids.LockedTargetList.Used} > 1 && ${Ship.ModuleList_OreMining.InactiveCount} > 1
				{
					Ship.ModuleList_OreMining:ActivateOne[${Asteroids.LockedTargetList.Get[1]}]
					Ship.ModuleList_OreMining:ActivateOne[${Asteroids.LockedTargetList.Get[2]}]
				}
				else
				{
					Ship.ModuleList_OreMining:ActivateOne[${Asteroids.LockedTargetList.Get[1]}]
				}
			}
			if ${Ice.LockedTargetList.Used} && ${Ship.ModuleList_IceMining.InactiveCount} > 0
			{
				if ${Ice.LockedTargetList.Used} > 1 && ${Ship.ModuleList_IceMining.InactiveCount} > 1
				{
					Ship.ModuleList_Iceining:ActivateOne[${Ice.LockedTargetList.Get[1]}]
					Ship.ModuleList_IceMining:ActivateOne[${Ice.LockedTargetList.Get[2]}]
				}
				else
				{
					Ship.ModuleList_IceMining:ActivateOne[${Ice.LockedTargetList.Get[1]}]
				}
			}
			if ${Gas.LockedTargetList.Used} && ${Ship.ModuleList_GasMining.InactiveCount} > 0
			{
				if ${Gas.LockedTargetList.Used} > 1 && ${Ship.ModuleList_GasMining.InactiveCount} > 1
				{
					Ship.ModuleList_Gasining:ActivateOne[${Gas.LockedTargetList.Get[1]}]
					Ship.ModuleList_GasMining:ActivateOne[${Gas.LockedTargetList.Get[2]}]
				}
				else
				{
					Ship.ModuleList_GasMining:ActivateOne[${Gas.LockedTargetList.Get[1]}]
				}
			}
		}
		This:MineableSorting
		This:CheckOreHold
		echo DEBUG - MINEABLES COLLECTION ${MineablesCollection.Used}
		; This is where we see if our mineables fall within a region defined by our travel path, using that minimode I made.
		if ${Mining.Config.AlignHomeStructure} && (${LavishScript.RunningTime} > ${UpdateTimer})
		{
			if ${MineablesCollection.Used}
			{
				echo DEBUG - MINERWORKER LOOK AHEAD TRIGGER
				This:LookAhead
			}
			
		}
		if (!${Asteroids.TargetList.Used} && !${Ice.TargetList.Used} && !${Gas.TargetList.Used})
		{
			Asteroids.AutoLock:Set[FALSE]
			Ice.AutoLock:Set[FALSE]
			Gas.AutoLock:Set[FALSE]
			if (!${AsteroidsDistant.TargetList.Used} && !${IceDistant.TargetList.Used} && !${GasDistant.TargetList.Used}) && ${MiningTime}
			{
				This:LogInfo["Mining Location Depleted"]
				Mining.LocationDepleted:Set[TRUE]
				if ${Mining.Config.MineAtBookmark} && ${Mining.MiningBookmarkQueue.Peek.NotNULLOrEmpty}
				{
					This:LogInfo["Removing Mining Bookmark"]
					EVE.Bookmark[${Mining.MiningBookmarkQueue.Peek}]:Remove
					Mining.MiningBookmarkQueue:Dequeue
				}
				if ${Mining.Config.MineAtLocalBelt} && ${Mining.BeltStack.Top}
				{
					This:LogInfo["Adding belt to Empty Belts List"]
					EmptyBelts:Add[${Entity[${Mining.MiningBookmarkQueue.Peek}].Name}]
					Mining.BeltStack:Pop		
				}
			}
		}
	
		
		return FALSE
	}
}