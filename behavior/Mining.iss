
objectdef obj_Configuration_Mining inherits obj_Configuration_Base
{
	method Initialize()
	{
		This[parent]:Initialize["Mining"]
	}

	method Set_Default_Values()
	{
		ConfigManager.ConfigRoot:AddSet[${This.SetName}]
		This.ConfigRef:AddSetting[GroupMining, FALSE]
		This.ConfigRef:AddSetting[FleetUp, FALSE]
		This.ConfigRef:AddSetting[FleetBoss, FALSE]
		This.ConfigRef:AddSetting[HomeStructure, ""]
		This.ConfigRef:AddSetting[LogLevelBar, LOG_INFO]
		This.ConfigRef:AddSetting[PersistentAnomID, ""]
		This.ConfigRef:AddSetting[DaBossID, ""]
		This.ConfigRef:AddSetting[WarpBackToName, ""]		
	}

	Setting(bool, Halt, SetHalt)

	; I sure am making a lot of UI work for myself here.

	; For elements I just grabbed from the Missioneer UI.
	Setting(bool, DropOffToContainer, SetDropOffToContainer)
	Setting(string, DropOffContainerName, SetDropOffContainerName)
	Setting(string, MunitionStorage, SetMunitionStorage)
	Setting(string, MunitionStorageFolder, SetMunitionStorageFolder)

	; Self explanatory. This is where you begin and end your mining runs.
	Setting(string, HomeStructure, SetHomeStructure)
	; Is it a citadel, or a normal station. No support for POS for now.
	Setting(bool, HomeStructureIsCitadel, SetHomeStructureIsCitadel)

	; Are we mining with friends, or alone?
	Setting(bool, GroupMining, SetGroupMining)
	; Are we going to fleet up, regardless of whether we are with friends or alone?
	Setting(bool, FleetUp, SetFleetUp)
	; Are we Da Boss?
	Setting(bool, FleetBoss, SetFleetBoss)
	; We need a number for the expected participants
	Setting(int, ExpectedParticipants, SetExpectedParticipants)

	; Use Mining Crystals
	Setting(bool, UseMiningCrystals, SetUseMiningCrystals)
	; What Mining Crystals
	Setting(string, WhatMiningCrystal, SetWhatMiningCrystal)
	; How Many Crystals Should We Carry?
	Setting(int, HowManyMiningCrystals, SetHowManyMiningCrystals)
	; Use First Command Burst Charge Type
	Setting(bool, UseCommandBurstOne, SetUseCommandBurstOne)
	; What Kind of Command Burst Charges (if we are a booster)
	Setting(string, CommandBurstOne, SetCommandBurstOne)
	; Use Second Command Burst Charge Type
	Setting(bool, UseCommandBurstTwo, SetUseCommandBurstTwo)
	; What Kind of Command Burst Charges (if we are a booster)
	Setting(string, CommandBurstTwo, SetCommandBurstTwo)
	; Use Third Command Burst Charge Type
	Setting(bool, UseCommandBurstThree, SetUseCommandBurstThree)
	; What Kind of Command Burst Charges (if we are a booster)
	Setting(string, CommandBurstThree, SetCommandBurstThree)
	; How Many of each Command Burst Charge should we carry?
	Setting(int, CommandBurstAmount, SetCommandBurstAmount)
	
	; Will we be using drones? Undecided whether I want to bother with mining drones. I hate mining drones.
	Setting(bool, UseDrones, SetUseDrones)
	; What kind of drones will we be using?
	Setting(string, DroneType, SetDroneType)
	
	; Do we take breaks? Breaks will be controlled by Da Boss if there is one.
	Setting(bool, TakeBreaks, SetTakeBreaks)
	; How often do we take breaks? Integer in Minutes.
	Setting(int, BreakHowOften, SetBreakHowOften)
	; How long do we break for? Integer in Minutes.
	Setting(int, BreakHowLong, SetBreakHowLong)

	; Are we going to Fight the NPCs? Alternative is run from them, or ignore them, I'll deal with that later.
	Setting(bool, FightNPCs, SetFightNPCs)
	; Do we run from anyone that we have standings set to 0.0 or lower? This works off of Local, and off of on grid entities (if I can make that work correctly).
	Setting(bool, RunFromBads, SetRunFromBads)
	; Do we run from people that seem to just be hanging around doing Weird Shit?
	Setting(bool, RunFromSuspicious, SetRunFromSuspicious)
	; Do we run to a POS like it is the year 2008?
	Setting(bool, UsePOSHidingSpot, SetUsePOSHidingSpot)
	; What is the Name of our POS Bookmark Hiding Place?
	Setting(string, POSBookmarkName, SetPOSBookmarkName)
	; Do we use Weird Navigation when running? This will warp to one or more Bookmarks, in system, prefixed with
	; whatever you put into the box. Then it will warp to the hiding location.
	Setting(bool, UseWeirdNavigation, SetUseWeirdNavigation)
	; Prefix for the bookmark names that will be used for Weird Navigation.
	Setting(string, WeirdBookmarkPrefix, SetWeirdBookmarkPrefix)
	; How long shall we hide for? Integer in minutes. If blank or 0, we will never resume unless done so manually.
	Setting(int, HideHowLong, SetHideHowLong)	


	; Do we use an Industrial Core? This is mostly here for fuel management. The MinerForeman minimode should handle the actual usage.
	Setting(bool, UseIndustrialCore, SetUseIndustrialCore)
	; Do we use a compressor? I forget why this is here. The MinerForeman and MinerWorker should be the ones handling ALL compressor usage.
	Setting(bool, UseCompressor, SetUseCompressor)
	; How many units of Heavy Water should we carry in our fuel bay? I recommend a number that isn't more than you can hold.
	Setting(int, UnitsHeavyWater, SetUnitsHeavyWater)

	; We should do our mining wherever Da Leader is. 
	Setting(bool, MineAtLeader, SetMineAtLeader)
	; We should do our mining at Bookmarks.
	Setting(bool, MineAtBookmark, SetMineAtBookmark)
	; What prefix signifies a mining Bookmark?
	Setting(string, MineAtBookmarkPrefix, SetMineAtBookmarkPrefix)
	; We are mining, alone or without Da Leader, at an ore anom.
	Setting(bool, MineAtOreAnom, SetMineAtOreAnom)
	; We are mining, alone or without Da Leader, at an asteroid belt, like its freakin 2006 yo.
	Setting(bool, MineAtLocalBelt, SetMineAtLocalBelt)
	
	; How far away are we willing to go for our Mineables. Integer is in Meters
	Setting(int, WanderRangeLimit, SetWanderRangeLimit)
	; Should we orbit Da Rocks?
	Setting(bool, OrbitRocks, SetOrbitRocks)
	; How far should we orbit from Da Rocks? Integer is in Meters
	Setting(int, OrbitRocksDistance, SetOrbitRocksDistance)
	; Should we orbit Da Boss?
	Setting(bool, OrbitBoss, SetOrbitBoss)
	; How far should we orbit from Da Boss? Integer is in Meters
	Setting(int, OrbitBossDistance, SetOrbitBossDistance)
	; Should we be mining in such a way that we always maintain alignment on our home structure?
	; If we happen to get out of mining range while doing this we will warp back to the Fleet Boss or a random asteroid then align again.
	; The orbit settings will be ignored if this setting is true.
	Setting(bool, AlignHomeStructure, SetAlignHomeStructure)
	; Use experimental anti-stuck technology. If we go to warp, and fail to enter warp within 30 seconds, and we are not warp scrambled, we will attempt to warp to
	; bookmarks prefixed with whatever is in the box in the setting after this one. If there are no bookmarks we will try the star first. If that fails we will try
	; a random planet. Then another random planet. Eventually we will get unstuck, or we will die.
	Setting(bool, UseExperimentalAntiStick, SetUseExperimentalAntiStick)
	; The bookmark prefix for the above.
	Setting(bool, ExperimentalAntiStickBookmarkPrefix, SetExperimentalAntiStickBookmarkPrefix)
	; What distance in meters do we warp to the mining site at?
	Setting(int, WarpInDistance, SetWarpInDistance)

	; I am going to attempt to make things more random by taking the number from the setting after this one, and using it to control a delay before
	; We undertake certain actions. Tehbot naturally adds delta to things but with enough clients and a small enough pulse time, things will begin
	; To overlap anyways. Maybe this will work, maybe I will get frustrated and give up, who knows.
	Setting(bool, UseExperimentalCountermeasures, SetUseExperimentalCountermeasures)
	; This number will be used as stated above, and to do a few other things to help the different clients behave more differently in the field.
	; Integer is a single number. Nobody should be rolling more than ten clients per machine. Hell nobody should be rolling more than SIX clients per machine.
	; Also we will need to ensure that the same numbers aren't chosen.
	Setting(int, SingleDigitNumber, SetSingleDigitNumber)
	
	; This bool indicates that you just want it to mine whatever is available in the correct category
	; If this bool is FALSE, then we use the complicated looking prioritization crap on the MinerWorker UI element.
	Setting(bool, JustMineIt, SetJustMineIt)

	; Here comes a huge list of all mining anomalies that exist by name. Hopefully I don't miss any.
	; Ore Anoms
	Setting(bool, AverageDarkOchreandGneissDeposit, setAverageDarkOchreandGneissDeposit)
	Setting(bool, AverageFrontierDeposit, setAverageFrontierDeposit)
	Setting(bool, AverageGneissDeposit, setAverageGneissDeposit)
	Setting(bool, AverageHedbergiteHemorphiteandJaspetDeposit, setAverageHedbergiteHemorphiteandJaspetDeposit)
	Setting(bool, AverageHemorphiteJaspetandKerniteDeposit, setAverageHemorphiteJaspetandKerniteDeposit)
	Setting(bool, AverageJaspetKerniteandOmberDeposit, setAverageJaspetKerniteandOmberDeposit)
	Setting(bool, AverageKerniteandOmberDeposit, setAverageKerniteandOmberDeposit)
	Setting(bool, AverageOmberDeposit, setAverageOmberDeposit)
	Setting(bool, AverageSpodumainCrokiteandDarkOchrerDeposit, setAverageSpodumainCrokiteandDarkOchrerDeposit)
	Setting(bool, ColossalAsteroidCluster, setColossalAsteroidCluster)
	Setting(bool, CommonPerimeterDeposit, setCommonPerimeterDeposit)
	Setting(bool, EnormousAsteroidCluster, setEnormousAsteroidCluster)
	Setting(bool, ExceptionalCoreDeposit, setExceptionalCoreDeposit)
	Setting(bool, InfrequentCoreDeposit, setInfrequentCoreDeposit)
	Setting(bool, IsolatedCoreDeposit, setIsolatedCoreDeposit)
	Setting(bool, LargeAsteroidCluster, setLargeAsteroidCluster)
	Setting(bool, LargeDarkOchreandGneissDeposit, setLargeDarkOchreandGneissDeposit)
	Setting(bool, LargeGneissDeposit, setLargeGneissDeposit)
	Setting(bool, LargeHedbergiteHemorphiteandJaspetDeposit, setLargeHedbergiteHemorphiteandJaspetDeposit)
	Setting(bool, LargeHemorphiteJaspetandKerniteDeposit, setLargeHemorphiteJaspetandKerniteDeposit)
	Setting(bool, LargeJaspetKerniteandOmberDeposit, setLargeJaspetKerniteandOmberDeposit)
	Setting(bool, LargeKerniteandOmberDeposit, setLargeKerniteandOmberDeposit)
	Setting(bool, LargeOmberDeposit, setLargeOmberDeposit)
	Setting(bool, MediumAsteroidCluster, setMediumAsteroidCluster)
	Setting(bool, OrdinaryPerimeterDeposit, setOrdinaryPerimeterDeposit)
	Setting(bool, RarifiedCoreDeposit, setRarifiedCoreDeposit)
	Setting(bool, ShatteredDebrisField, setShatteredDebrisField)
	Setting(bool, SmallArkonorandBistotDeposit, setSmallArkonorandBistotDeposit)
	Setting(bool, SmallAsteroidCluster, setSmallAsteroidCluster)
	Setting(bool, SmallDarkOchreandGneissDeposit, setSmallDarkOchreandGneissDeposit)
	Setting(bool, SmallGneissDeposit, setSmallGneissDeposit)
	Setting(bool, SmallHedbergiteHemorphiteandJaspetDeposit, setSmallHedbergiteHemorphiteandJaspetDeposit)
	Setting(bool, SmallHemorphiteJaspetandKerniteDeposit, setSmallHemorphiteJaspetandKerniteDeposit)
	Setting(bool, SmallJaspetKerniteandOmberDeposit, setSmallJaspetKerniteandOmberDeposit)
	Setting(bool, SmallKerniteandOmberDeposit, setSmallKerniteandOmberDeposit)
	Setting(bool, SmallOmberDeposit, setSmallOmberDeposit)
	Setting(bool, SmallSpodumainCrokieandDarkOchreDeposit, setSmallSpodumainCrokieandDarkOchreDeposit)
	Setting(bool, UncommonCoreDeposit, setUncommonCoreDeposit)
	Setting(bool, UnexceptionalFrontierDeposit, setUnexceptionalFrontierDeposit)
	Setting(bool, UnusualCoreDeposit, setUnusualCoreDeposit)

	; Ice Anoms
	Setting(bool, BlueIceBelt, setBlueIceBelt)
	Setting(bool, ClearIcicleBelt, setClearIcicleBelt)
	Setting(bool, WhiteGlazeBelt, setWhiteGlazeBelt)
	Setting(bool, GlacialMassBelt, setGlacialMassBelt)
	Setting(bool, GlareCrustBelt, setGlareCrustBelt)
	Setting(bool, DarkGlitterBelt, setDarkGlitterBelt)
	Setting(bool, GelidusBelt, setGelidusBelt)
	Setting(bool, KrystallosBelt, setKrystallosBelt)
	Setting(bool, ShatteredIceField, setShatteredIceField)
	
	; There are so many Gas Sites I am not even going to bother with all of them. They all have the word Nebula or Reservoir. Deal with it.
	Setting(bool, Nebula, setNebula)
	Setting(bool, Reservoir, setReservoir)
	
	; Need to keep track of what Anom we are running in a way that persists 
	Setting(int64, PersistentAnomID, setPersistentAnomID)
	
	; To keep track of Da Boss, persistently
	Setting(int64, DaBossID, SetDaBossID)
	
	; To keep track of our warp back to mineables
	Setting(string, WarpBackToName, SetWarpBackToName)

	
	
	
}

objectdef obj_Mining inherits obj_StateQueue
{


	variable set AllowDronesOnNpcClass
	variable obj_TargetList NPCs
	variable obj_TargetList ActiveNPCs


	variable obj_Configuration_Mining Config
	variable obj_MiningUI LocalUI

	variable bool reload = TRUE
	variable bool halt = FALSE

	; MinerWorker or MinerForeman can trigger this. If true it will send us back to station.
	variable bool ReturnToStation

	variable bool StatusGreen
	variable bool StatusChecked	
	variable bool CompressionRequest
	variable bool CompressionActive
	; This will be used for timekeeping after a fleeing event.
	variable int64 ClearToMine
	; This bool will be set by an event triggered ostensibly by Da Boss. It says to come out and mine its time.
	variable bool LeaderSummons
	; This int64 will store the entity ID of the boss so we can goddamn orbit them, fuck.
	variable int64 DaBossEntityID
	
	; Needed for anomaly integration
	variable index:systemanomaly MyAnomalies
	variable iterator MyAnomalies_Iterator
	; This is basically the same as the trash I did in MinerWorker. Key is the name, Value is bool.
	variable collection:bool AnomalyMasterCollection
	; This set will contain only the Anamlies we want to run.
	variable set ValidAnomalies
	; This is the unique ID of the anom we are currently running.
	variable int64 CurrentAnomID
	; This bool is set by the UI button that says to rebuild the allowed anomaly list.
	variable bool RebuildAnomList
	
	; This collection will be used by the WhoIsOutThere event. key is character name and int64 is char id.
	variable collection:int64 CurrentParticipants
	
	; This queue will contain all the valid bookmark names we turn up by looking for mining bookmarks.
	variable queue:string MiningBookmarkQueue
	
	; Belt related trash
	variable index:entity beltIndex
	variable iterator beltIterator
	variable set EmptyBelts
	variable stack:int64 BeltStack
	
	; This is an exit condition, sends the Miners back home and has them warp back when the boss says to.
	variable bool ScramYaMooks
	
	; This is a bool that MinerWorker will use to say that it has depleted the area.
	variable bool LocationDepleted
	
	; This string holds the name of the BM we are warping back to
	variable string WarpBackery
	
	

	method Initialize()
	{
		This[parent]:Initialize
		

		DynamicAddBehavior("Mining", "Mining Mainmode")
		This.PulseFrequency:Set[3500]

		This.LogInfoColor:Set["g"]
		This.LogLevelBar:Set[${Config.LogLevelBar}]
		
		LavishScript:RegisterEvent[CompressorRequest]
		Event[CompressorRequest]:AttachAtom[This:CompressorRequestEvent]
	
		LavishScript:RegisterEvent[CompressionActive]
		Event[CompressionActive]:AttachAtom[This:CompressionActiveEvent]

		LavishScript:RegisterEvent[LeaderSummoning]
		Event[LeaderSummoning]:AttachAtom[This:LeaderSummoningEvent]
		
		LavishScript:RegisterEvent[WhoIsOutThere]
		Event[WhoIsOutThere]:AttachAtom[This:WhoIsOutThereEvent]
		
		LavishScript:RegisterEvent[WhoIsDaBoss]
		Event[WhoIsDaBoss]:AttachAtom[This:WhoIsDaBossEvent]

		LavishScript:RegisterEvent[TimeToScram]
		Event[TimeToScram]:AttachAtom[This:TimeToScramEvent]			

		LavishScript:RegisterEvent[Tehbot_ScheduleHalt]
		Event[Tehbot_ScheduleHalt]:AttachAtom[This:ScheduleHalt]
		LavishScript:RegisterEvent[Tehbot_ScheduleResume]
		Event[Tehbot_ScheduleResume]:AttachAtom[This:ScheduleResume]
	
		if ${CommonConfig.Tehbot_Mode.Equal["Mining"]}
		{
			timedcommand 0 "ui -load \"${Script.CurrentDirectory}/behavior/Mining.xml\""
			
			timedcommand 30 "ui -unload \"${Script.CurrentDirectory}/behavior/Mining.xml\""		
		
		}

	}

	method CompressorRequestEvent(bool Help)
	{
		echo DEBUG - Compressor Request Event ${Help}
		CompressionRequest:Set[${Help}]
	}
	
	method CompressionActiveEvent(bool Help2)
	{
		echo DEBUG - Compression Active Event ${Help2}
		CompressionActive:Set[${Help2}]
	}	

	method LeaderSummoningEvent(bool Help3)
	{
		echo DEBUG - Leader Summoning Event ${Help3}
		LeaderSummons:Set[${Help3}]
	}
	
	method WhoIsDaBossEvent(int64 BossID)
	{
		echo DEBUG - Who Is Da Boss Event ${BossID}
		Script[Tehbot].VariableScope.Mining.Config:SetDaBossID[${BossID}]
	}	
	
	method WhoIsOutThereEvent(string Name, int64 CharID)
	{
		echo Debug - Who Is Out There Event ${Name} is ${CharID}
		CurrentParticipants:Set[${Name}, ${CharID}]
	}
	
	method TimeToScramEvent(bool Scram)
	{
		echo Debug - Time To Scram Event ${Scram}
		ScramYaMooks:Set[${Scram}]
	}
	
	method ScheduleHalt()
	{
		halt:Set[TRUE]
	}

	method ScheduleResume()
	{
		halt:Set[FALSE]
		if ${This.IsIdle}
		{
			This:Start
		}
	}

	method Start()
	{


		if ${This.IsIdle}
		{
			This:LogInfo["Starting"]
			This:InsertState["BuildAnomaliesList", 5000]
			This:QueueState["CheckForWork", 5000]
			EVE:RefreshBookmarks
		}


		Tehbot.Paused:Set[FALSE]
		UIElement[Run@TitleBar@Tehbot]:SetText[Stop]
	}

	method Stop()
	{
		This:LogInfo["Stopping."]
		This:Clear
		Tehbot.Paused:Set[TRUE]
		UIElement[Run@TitleBar@Tehbot]:SetText[Run]
	}

	member:bool Repair()
	{
		if ${Me.InStation} && ${Utility.Repair}
		{
			This:InsertState["Repair", 5000]
			return TRUE
		}

		return TRUE
	}

	; Subverting this old chestnut for my own purposes. In here is where our direction mostly comes from.
	; Where are we, whats our current state, what should we do next.
	member:bool CheckForWork()
	{

		if ${Config.WhatMiningCrystal}
		{
			ammo:Set[${Config.WhatMiningCrystal}]
		}

		;You know, I don't think this actually does anything... Well maybe it does.
		Ship.ModuleList_OreMining:ConfigureAmmo[${ammo}, , ]
			
		; We are in space, in a pod. Might figure out something more complicated for this later.
		if ${Client.InSpace} && ${MyShip.ToEntity.Type.Equal[Capsule]}
		{
			This:LogInfo["We dead, Go back to Station"]
			This:InsertState["GoToStation"]
			This:Stop
		}
		; We are in station, in a pod. Might figure out something more complicated for this later.
		if ${Me.InStation} && ${MyShip.ToItem.Type.Equal[Capsule]}
		{
			This:LogInfo["We dead"]
			This:Stop
		}
		; People with neutral standings or worse are in local, and we are configured to run. Run.
		if !${FriendlyLocal} && ${Config.RunFromBads} && !${Me.InStation} && !${Bookmark[${Config.POSBookmarkName}].Distance} < 50000
		{
			This:LogInfo["Jerks in Local, lets get out of here"]
			; If we are set to run to a POS
			if ${Config.UsePOSHidingSpot} && ${Config.POSBookmarkName.NotNULLOrEmpty}
			{
				if ${Config.HideHowLong} == 0
				{
					ClearToMine:Set[${Math.Calc[${LavishScript.RunningTime} + 999999999999999999999999999999999999]}]	
				}
				else
				{
					ClearToMine:Set[${Math.Calc[${LavishScript.RunningTime} + (${Config.HideHowLong} * 60000)]}]
				}
				This:LogInfo["Hope there is actually a POS here"]
				This:InsertState["FleeToPOS"]
				return TRUE
			}
			if ${Config.UseWeirdNavigation} && ${Config.WeirdBookmarkPrefix.NotNULLOrEmpty}
			{
				if ${Config.HideHowLong} == 0
				{
					ClearToMine:Set[${Math.Calc[${LavishScript.RunningTime} + 999999999999999999999999999999999999]}]	
				}
				else
				{
					ClearToMine:Set[${Math.Calc[${LavishScript.RunningTime} + (${Config.HideHowLong} * 60000)]}]
				}			
				This:LogInfo["Commence Weird Navigation"]
				This:InsertState["WeirdNavigation"]
				return TRUE
			}
			
			if ${Config.HideHowLong} == 0
			{
				ClearToMine:Set[${Math.Calc[${LavishScript.RunningTime} + 999999999999999999999999999999999999]}]	
			}
			else
			{
				ClearToMine:Set[${Math.Calc[${LavishScript.RunningTime} + (${Config.HideHowLong} * 60000)]}]
			}
			Move:Bookmark["${Config.HomeStructure}"]
			This:InsertState["Traveling"]
			return TRUE
		}
		; We are in a station (or in a POS), there are jerks, and we are set to run. Update the wait timer.
		if (!${FriendlyLocal} && ${Config.RunFromBads}) && (${Me.InStation} || ${Bookmark[${Config.POSBookmarkName}].Distance} < 50000)
		{
			if ${Config.HideHowLong} == 0
			{
				This:Stop
				return TRUE
			}
			else
			{
				ClearToMine:Set[${Math.Calc[${LavishScript.RunningTime} + (${Config.HideHowLong} * 60000)]}]
			}			
		}
		; We are in a station, we are still inside the time set by a Fleeing Event
		if ${LavishScript.RunningTime} < ${ClearToMine}
		{
			return FALSE
		}
		; We are in station, and ore holds are a pain in the ass, make active.
		if ${Me.InStation} && ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold](exists)} && ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold].UsedCapacity} < 0
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold]:MakeActive
			return FALSE
		}		
		; We are in space and ore holds are a pain in the ass, make active.
		if ${Client.InSpace} && ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold](exists)} && ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold].UsedCapacity} < 0
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold]:MakeActive
			return FALSE
		}
		; We are in space, we have time to see if we need anything.
		if ${Client.InSpace} && !${StatusChecked}
		{
			This:LogInfo["Status Check"]
			This:InsertState["CheckStatus", 5000]
			return TRUE
		}
		; We are in station and we haven't checked status. Do so.
		if ${Me.InStation} && !${StatusChecked}
		{
			This:LogInfo["Status Check"]
			This:InsertState["CheckStatus", 5000]
			return TRUE
		}
		; We are in station and need repairs or resupply.
		if ${Me.InStation} && !${StatusGreen} && ${StatusChecked}
		{
			if ${Config.UseMiningCrystals}
			{
				This:LogInfo["Loading \ao${ammo}", "o"]
			}
			StatusGreen:Set[TRUE]
			ReturnToStation:Set[FALSE]
			This:QueueState["Repair"]
			This:QueueState["DropOffLoot", 5000]
			This:InsertState["LoadSupplies", 3000]
			return TRUE
		}
		; We are in space,  and we have no problems. Lets establish our mining location.
		if ${Client.InSpace} && ${StatusGreen} && ${StatusChecked}
		{
			ReturnToStation:Set[FALSE]
			This:LogInfo["Figure out mining location"]
			This:InsertState["EstablishMiningLocation", 5000]
			return TRUE
		}
		; We are in station and everything is good, lets establish our mining location.
		if ${Me.InStation} && ${StatusGreen} && ${StatusChecked}
		{
			ReturnToStation:Set[FALSE]
			This:LogInfo["Figure out mining location"]
			This:QueueState["EstablishMiningLocation", 5000]
			return TRUE
		}
		; We are in space and need resupply and/or repair, back to base
		if ${Client.InSpace} && !${StatusGreen}
		{
			This:LogInfo["Go back to the station"]
			This:InsertState["GoToStation"]
			return TRUE
		}
		; We have hit the halt button, might want to like, stop the bot or something.
		if ${Me.InStation} && (${Config.Halt} || ${Halt})
		{
			This:LogInfo["Halt Requested"]
			This:InsertState["HaltBot"]
			return TRUE
		}
		echo DEBUG - HOW THE SHIT DID WE GET HERE
	}
	
	; We should see if we need ammo, filaments, etc. This is in case the bot gets stopped in space after a few runs or whatever.
	member:bool CheckStatus()
	{
		;If we are low on crystals, and are using them (obviously), we go back to station.
		if ${Config.UseMiningCrystals}
		{
			if !${MyShip.Cargo[${Config.WhatMiningCrystal}](exists)} || ( ${MyShip.Cargo[${Config.WhatMiningCrystal}].Quantity} < ${Math.Calc[${Config.HowManyMiningCrystals} * .2]} )
			{
				This:LogInfo["Short on ${Config.WhatMiningCrystal}"]
				StatusGreen:Set[FALSE]
				StatusChecked:Set[TRUE]
				This:InsertState["CheckForWork", 5000]
				return TRUE
			}
		}
		; If we are using Command Burst Charge 1
		if ${Config.UseCommandBurstOne}
		{
			if !${MyShip.Cargo[${Config.CommandBurstOne}](exists)} || ( ${MyShip.Cargo[${Config.CommandBurstOne}].Quantity} < ${Math.Calc[${Config.CommandBurstAmount} * .2]} )
			{
				This:LogInfo["Short on ${Config.CommandBurstOne}"]
				StatusGreen:Set[FALSE]
				StatusChecked:Set[TRUE]
				This:InsertState["CheckForWork", 5000]
				return TRUE
			}
		}
		; If we are using Command Burst Charge 2
		if ${Config.UseCommandBurstTwo}
		{
			if !${MyShip.Cargo[${Config.CommandBurstTwo}](exists)} || ( ${MyShip.Cargo[${Config.CommandBurstTwo}].Quantity} < ${Math.Calc[${Config.CommandBurstAmount} * .2]} )
			{
				This:LogInfo["Short on ${Config.CommandBurstTwo}"]
				StatusGreen:Set[FALSE]
				StatusChecked:Set[TRUE]
				This:InsertState["CheckForWork", 5000]
				return TRUE
			}
		}
		; If we are using Command Burst Charge 3
		if ${Config.UseCommandBurstThree}
		{
			if !${MyShip.Cargo[${Config.CommandBurstThree}](exists)} || ( ${MyShip.Cargo[${Config.CommandBurstThree}].Quantity} < ${Math.Calc[${Config.CommandBurstAmount} * .2]} )
			{
				This:LogInfo["Short on ${Config.CommandBurstThree}"]
				StatusGreen:Set[FALSE]
				StatusChecked:Set[TRUE]
				This:InsertState["CheckForWork", 5000]
				return TRUE
			}
		}
		; If we are low on Heavy Water
		;if ${Config.UseIndustrialCore}
		;{
		;	if !${MyShip.Cargo["Heavy Water"](exists)} || ( ${MyShip.Cargo["Heavy Water"].Quantity} < ${Math.Calc[${Config.UnitsHeavyWater} * .2]} )
		;	{
		;		This:LogInfo["Short on Heavy Water"]
		;		StatusGreen:Set[FALSE]
		;		StatusChecked:Set[TRUE]
		;		This:InsertState["CheckForWork", 5000]
		;		return TRUE
		;	}
		;}
		; Drones, I guess? Not gonna be very complicated. I lied it will be slightly more complicated as I think up dumb edgecases.
		; If your drone bay capacity is 25m3 or less, missing 10m3 of drones triggers a reload. If it is 30 to 50, missing 20m3 triggers a reload. If it is greater than 50, triggers on 30m3.
		if ${Config.UseDrones}
		{
			if (!${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} < 0)
			{
				; Please keep your inventory open at all times, please.
				EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay]:MakeActive
				Client:Wait[1000]
			}
			
			if ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} == 0
			{
				This:LogInfo["Look at this mook, configged to use drones on a ship without a drone bay. Stopping, fix your config."]
				return FALSE
				This:Stop
			}
			
			if ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} > 0 && ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} <= 25
			{
				if (${Math.Calc[${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} - ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].UsedCapacity}]}) > 10
				{
					This:LogInfo["Short on drones"]
					StatusGreen:Set[FALSE]
					StatusChecked:Set[TRUE]
					This:InsertState["CheckForWork", 5000]
					return TRUE
				}
			}
			
			if ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} > 25 && ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} <= 50
			{
				if (${Math.Calc[${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} - ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].UsedCapacity}]}) > 20
				{
					This:LogInfo["Short on drones"]
					StatusGreen:Set[FALSE]
					StatusChecked:Set[TRUE]
					This:InsertState["CheckForWork", 5000]
					return TRUE
				}
			}
			if ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} > 50
			{
				if (${Math.Calc[${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} - ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].UsedCapacity}]}) > 30
				{
					This:LogInfo["Short on drones"]
					StatusGreen:Set[FALSE]
					StatusChecked:Set[TRUE]
					This:InsertState["CheckForWork", 5000]
					return TRUE
				}
			}
		
		}
		; If we are in structure or armor, thats probably bad.
		if ${MyShip.StructurePct} < 100 || ${MyShip.ArmorPct} < 100
		{
			This:LogInfo["Need repairs"]
			StatusGreen:Set[FALSE]
			StatusChecked:Set[TRUE]
			This:InsertState["CheckForWork", 5000]
			return TRUE
		}
		; Open the inventory, stop closing the inventory, never close your inventory.
		if (!${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo].Capacity} < 0)
		{
			; Please keep your inventory open at all times, please.
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:MakeActive
			return FALSE
		}
		; Ore bay is rude af
		if ${Client.InSpace} && ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold](exists)} && ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold].UsedCapacity} < 0
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold]:MakeActive
			return FALSE
		}
		; We're in station and have anything in the ore hold, unload it.
		if ${Me.InStation} && ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold].UsedCapacity} > 1
		{
			This:LogInfo["Cargo is too full"]
			StatusGreen:Set[FALSE]
			StatusChecked:Set[TRUE]
			This:InsertState["CheckForWork", 5000]
			return TRUE		
		}
		
		; Looks like we're full.
		if (${Math.Calc[${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold].Capacity} - ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold].UsedCapacity}]}) < 999
		{
			This:LogInfo["Cargo is too full, returning"]
			StatusGreen:Set[FALSE]
			StatusChecked:Set[TRUE]
			This:InsertState["CheckForWork", 5000]
			return TRUE
		}
		; If we made it down here we are probably (but not certainly) good
		StatusGreen:Set[TRUE]
		StatusChecked:Set[TRUE]
		This:InsertState["CheckForWork", 5000]
		return TRUE
	}
	
	; We need to go to station to dropoff or repair or refill consumables
	member:bool GoToStation()
	{
		if ${Config.HomeStructure.NotNULLOrEmpty}
		{
			Move:Bookmark["${Config.HomeStructure}"]
			This:InsertState["Traveling"]
			This:InsertState["CheckForWork", 5000]
			return TRUE
		}
		else
		{
			This:LogInfo["HomeBase BM not found, stopping"]
			This:Stop
		}
	}
	
	; Everything looks good, lets figure out where we are going.
	member:bool EstablishMiningLocation()
	{
		ReCalculatePriorities:Set[TRUE]
		; We are the fleet boss, we mine in a fleet
		if ${Config.FleetBoss} && ${Config.FleetUp}
		{	
			echo Boss + Fleet
			relay all -event WhoIsDaBoss ${Me.CharID}
			; We aren't in a fleet yet, lets fix that.
			if !${Me.Fleet}
			{
				This:LogInfo["Not actually fleeted up, attempt to fleet"]
				Me:InviteToFleet
				This:InsertState["StartFleetDance", 5000]
				return TRUE
			}
			if ${Me.Fleet.Size} <= 1
			{
				This:InsertState["StartFleetDance", 10000]
				return TRUE			
			}
			; Hey clowno, if you are the leader and yet you mine at the leader, how do you think that is gonna work?
			elseif ${Config.MineAtLeader}
			{
				This:LogInfo["Bad Config - Can't mine at leader while also being the leader."]
				This:Stop
			}
			elseif ${Config.WarpBackToName.NotNULLOrEmpty}
			{
				This:QueueState["StartBookmarkDance", 5000]
				return TRUE			
			}
			; Mine at bookmark
			elseif ${Config.MineAtBookmark} && ${Config.MineAtBookmarkPrefix.NotNULLOrEmpty}
			{
				This:QueueState["StartBookmarkDance", 5000]
				return TRUE
			}
			; Mine at bookmark but we misconfigured something.
			elseif !${Config.MineAtBookmarkPrefix.NotNULLOrEmpty} && ${Config.MineAtBookmark}
			{
				This:LogInfo["Set to mine at bookmark, yet no prefix defined, stopping"]
				Move:Bookmark["${Config.HomeStructure}"]
				This:InsertState["Traveling"]
				This:Stop
			}
			; Mine at Anom
			elseif ${Config.MineAtOreAnom}
			{
				This:QueueState["StartAnomDance", 5000]
				return TRUE
			}
			; Mine at a local belt, unbelievable
			elseif ${Config.MineAtLocalBelt}
			{
				This:QueueState["StartBeltDance", 5000]
				return TRUE
			}
		}
	
		; We are not Da Boss, but we do Fleet Up.
		if !${Config.FleetBoss} && ${Config.FleetUp}
		{	
			echo NOT Boss + Fleet
			; We aren't in a fleet, lets fix that
			if !${Me.Fleet}
			{
				This:LogInfo["Not in a fleet, awaiting invite from Da Boss"]
				Move:Bookmark["${Config.HomeStructure}]
				This:QueueState["WaitForFleetInvite", 10000]
				return TRUE
			}
			; We mine at the leader, and we've been summoned
			elseif ${Config.MineAtLeader} && ${LeaderSummons}
			{
				This:LogInfo["Leader has summoned us"]
				This:QueueState["TravelToLeader", 5000]
				return TRUE
			}
			; We mine at the leader, and we've NOT been summoned
			elseif ${Config.MineAtLeader} && !${LeaderSummons}
			{
				This:LogInfo["Waiting for Leader Summons"]
				This:QueueState["EstablishMiningLocation", 15000]
				return TRUE
			}
		}
		
		; We do not fleet up, we do not meet up, we mine solo.
		if !${Config.FleetUp} && !${Config.GroupMining}
		{
			echo NOT Boss + NOT Fleet
			if ${Config.WarpBackToName.NotNULLOrEmpty}
			{
				This:QueueState["StartBookmarkDance", 5000]
				return TRUE			
			}
			; Mine at bookmark
			elseif ${Config.MineAtBookmark} && ${Config.MineAtBookmarkPrefix.NotNULLOrEmpty}
			{
				This:QueueState["StartBookmarkDance", 5000]
				return TRUE
			}
			; Mine at bookmark but we misconfigured something.
			elseif !${Config.MineAtBookmarkPrefix.NotNULLOrEmpty} && ${Config.MineAtBookmark}
			{
				This:LogInfo["Set to mine at bookmark, yet no prefix defined, stopping"]
				Move:Bookmark["${Config.HomeStructure}"]
				This:InsertState["Traveling"]
				This:Stop
			}
			; Mine at Anom
			elseif ${Config.MineAtOreAnom}
			{
				This:QueueState["StartAnomDance", 5000]
				return TRUE
			}
			; Mine at a local belt, unbelievable
			elseif ${Config.MineAtLocalBelt}
			{
				This:QueueState["StartBeltDance", 5000]
				return TRUE
			}
		}
		; We do not fleet up, but we do meet up. We mine with friends but not in a fleet. This isn't programmed yet and may never be programmed.
		if ${Config.GroupMining} && !${Config.FleetUp}
		{
			echo sad trombone how did you get here
		}
		; We fell through all this BS and landed here, something is wrong
		else
		{
			This:LogInfo["Misconfiguration - EstablishMiningLocation - Stopping"]
			Move:Bookmark["${Config.HomeStructure}"]
			This:InsertState["Traveling"]
			This:Stop		
		}
	}
	
	; This is how we will pick a mining bookmark to go to.
	member:bool StartBookmarkDance()
	{
		variable index:bookmark MiningBookmarks
		variable iterator BookmarkIterator
		EVE:GetBookmarks[MiningBookmarks]
		
		MiningBookmarks:RemoveByQuery[${LavishScript.CreateQuery[SolarSystemID != "${Me.SolarSystemID}"]}, TRUE]	

		;if ${Config.WarpBackToName.NotNULLOrEmpty}
		;{
		;	MiningBookmarks:RemoveByQuery[${LavishScript.CreateQuery[Name =- "${Config.WarpBackToName}"]}, FALSE]	
		;}
		MiningBookmarks:Collapse		
		

		MiningBookmarks:GetIterator[BookmarkIterator]

		;if !${BookmarkIterator:First(exists)}
		;{
		;	This:LogInfo["No valid bookmarks found - Stopping"]
		;	Move:Bookmark["${Config.HomeStructure}"]
		;	This:InsertState["Traveling"]
		;	This:Stop
		;}
		; Going to shove every valid bookmark into a queue because queues are fun hell yeah lets use
		; a container I haven't really used for no good reason.
		if ${BookmarkIterator:First(exists)}
		{
			do
			{	
				if ${BookmarkIterator.Value.Label.Find[${Config.WarpBackToName}]}
				{
					WarpBackery:Set[${Config.WarpBackToName}]
				}
				if ${BookmarkIterator.Value.Label.Find[${Config.MineAtBookmarkPrefix}]}
				{
					MiningBookmarkQueue:Queue[${BookmarkIterator.Value.Label}]
					This:LogInfo["Queueing up Mining Bookmark ${BookmarkIterator.Value.Label}"]
				}
			}
			while ${BookmarkIterator:Next(exists)}
		}
		This:LogInfo["Mining Bookmark List Assembled - ${MiningBookmarkQueue.Used} Bookmarks Found"]
		This:LogInfo["Need to be Undocked for this part"]
		Move:Undock
		This:QueueState["NavigateToMiningLocation", 5000]
		return TRUE
	}
	; This is how we will pick an anom to go to.
	member:bool StartAnomDance()
	{
		if ${Me.InStation}
		{
			This:LogInfo["Need to be Undocked for this part"]
			Move:Undock
		}
		if ${Client.InSpace} && ${ValidAnomalies.Used} > 0
		{
			This:LogInfo["Updating Anomalies"]
			This:QueueState["UpdateAnoms"]
			return TRUE
		}
		if ${Client.InSpace} && ${ValidAnomalies.Used} <= 0
		{
			This:LogInfo["Building Anoms List"]
			This:InsertState["BuildAnomaliesList", 5000]
			return FALSE
		}
	}
	; This is how we will pick an asteroid belt, still cant believe this.
	member:bool StartBeltDance()
	{
		variable int NumberBelts
		if ${Me.InStation}
		{
			This:LogInfo["Need to be Undocked for this part"]
			Move:Undock
		}
		
		if !${Client.InSpace}
		{
			return FALSE
		}
		
		if ${Client.InSpace} && ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold](exists)} && ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold].UsedCapacity} < 0
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold]:MakeActive
			return FALSE
		}
		
		EVE:QueryEntities[beltIndex, "GroupID = 9"]
		beltIndex:GetIterator[beltIterator]
		
		if !${beltIterator:First(exists)}
		{
			This:LogInfo["We seem to not have any belts here? Stopping."]
			Move:Bookmark["${Config.HomeStructure}"]
			This:InsertState["Traveling"]
			This:Stop		
		}
		if ${beltIterator:First(exists)}
		{
			do
			{
				if !${EmptyBelts.Contains[${beltIterator.Value.Name}]}
				{
					BeltStack:Push[${beltIterator.Value.ID}]
					This:LogInfo["Adding Belt ${beltIterator.Value.Name} to Stack"]
					NumberBelts:Inc[1]
				}
			}
			while ${beltIterator:Next(exists)}
		}
		This:LogInfo["Belt List Built - ${NumberBelts} Belts Found"]
		This:QueueState["NavigateToMiningLocation", 5000]
		return TRUE			
	}
	; This is where Da Boss manages sending out fleet invites.
	member:bool StartFleetDance()
	{
		This:LogInfo["Triggering who is out there event"]
		relay all "Event[WhoIsOutThere]:Execute[${Me.Name},${Me.CharID}]"
		echo DEBUG - ${CurrentParticipants.Used} participants answered 
		
		if ${Me.Fleet.Size} < ${CurrentParticipants.Used}
		{
			if ${CurrentParticipants.FirstKey(exists)}
			{
				do
				{
					; Lets see if this behaves with local torn asunder
					if ${Me.Fleet.Member[${CurrentParticipants.CurrentValue}](exists)}
					{
						continue
					}
					if ${Being[${CurrentParticipants.CurrentValue}](exists)}
					{
						Being[${CurrentParticipants.CurrentValue}]:InviteToFleet
					}
				}
				while ${CurrentParticipants.NextKey(exists)}
			}
		}
		This:QueueState["EstablishMiningLocation"]
		return TRUE
	
	}
	; This is where we wait for our fleet invite at, hopefully I remembered to take you somewhere safe before we end up here.
	member:bool WaitForFleetInvite()
	{
		if !${Me.Fleet}
		{
			This:LogInfo["Triggering who is out there event"]
			relay all "Event[WhoIsOutThere]:Execute[${Me.Name},${Me.CharID}]"
		}
		if ${CurrentParticipants.FirstKey(exists)} && ${EVEWindow[ByName,modal](exists)}
		{
			do
			{
				if ${EVEWindow[ByName,modal].Text.Find[${CurrentParticipants.CurrentKey}]}
				{
					EVEWindow[ByName,modal]:ClickButtonYes
					This:QueueState["EstablishMiningLocation"]
					return TRUE
				}
			}
			while ${CurrentParticipants.NextKey(exists)}
		}
		This:QueueState["WaitForFleetInvite", 15000]
		return TRUE
	}
	; This is where we travel to our mining location. Fleet members that aren't Da Boss will not touch this normally.
	member:bool NavigateToMiningLocation()
	{
		MinerWorker.MineablesCollection:Erase
		MinerWorker.ReCalculatePriorities:Set[TRUE]
		if ${Client.InSpace} && ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold](exists)} && ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold].UsedCapacity} < 0
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold]:MakeActive
			return FALSE
		}
		This:LogInfo["Begin Navigation to Mining Location"]
		if ${WarpBackery.NotNULLOrEmpty}
		{
			This:LogInfo["Moving back to where we left off"]
			Move:Bookmark[${WarpBackery}, FALSE, ${Config.WarpInDistance}, FALSE]
			This:InsertState["Traveling"]
			Script[Tehbot].VariableScope.Mining.Config:SetWarpBackToName[""]
			This:QueueState["StartWorking", 4000]
			return TRUE
		}
		if ${MiningBookmarkQueue.Peek.NotNULLOrEmpty}
		{
			This:LogInfo["Moving to Bookmark"]
			Move:Bookmark[${MiningBookmarkQueue.Peek}, FALSE, ${Config.WarpInDistance}, FALSE]
			This:InsertState["Traveling"]
			This:QueueState["StartWorking", 4000]
			return TRUE
		}
		if ${BeltStack.Top}
		{
			This:LogInfo["Moving to Belt"]
			Move:Entity[${BeltStack.Top}, ${Config.WarpInDistance}, FALSE]
			This:InsertState["Traveling"]
			This:QueueState["StartWorking", 4000]
			return TRUE
		}
	}
	; This is where we travel to Da Boss.
	member:bool TravelToLeader()
	{
		if !${Me.Fleet}
		{
			This:LogInfo["Dunno how we got here honestly - Stopping"]
			Move:Bookmark["${Config.HomeStructure}"]
			This:InsertState["Traveling"]
			This:Stop
		}
		if !${Config.DaBossID}
		{
			This:LogInfo["Considering this is supposed to be set each time you start the bot, and it persists, what the hell"]
			This:Stop
		}
		if ${Me.InStation}
		{
			This:LogInfo["Need to be Undocked for this part"]
			Move:Undock
		}
		if !${Client.InSpace}
		{
			return FALSE
		}
		if ${Client.InSpace}
		{
			MinerWorker.ReCalculatePriorities:Set[TRUE]
			This:LogInfo["Moving to Da Boss"]
			Move:Fleetmember[${Config.DaBossID}, FALSE, ${Config.WarpInDistance}]
			This:InsertState["Traveling"]
			This:QueueState["StartWorking", 4000]
			return TRUE
		}
		This:LogInfo["Dunno how we got here honestly - Stopping"]
		Move:Bookmark["${Config.HomeStructure}"]
		This:InsertState["Traveling"]
		This:Stop
	}
	; We are at the mining location, commence the minings.
	member:bool StartWorking()
	{	
		MinerWorker.MiningTime:Set[TRUE]
		; People with neutral standings or worse are in local, (or npcs and we don't fight npcs) and we are configured to run. Run.
		if (!${FriendlyLocal} && ${Config.RunFromBads}) || (${MinerWorker.ActiveNPCs.TargetList.Used} && !${Config.FightNPCs})
		{
			MinerForeman.InhibitBursts:Set[TRUE]
			MinerWorker.MiningTime:Set[FALSE]
			relay all -event LeaderSummoning FALSE
			This:LogInfo["Jerks in Local, lets get out of here"]
			; If we are set to run to a POSBookmarkName
			if ${Config.UsePOSHidingSpot} && ${Config.POSBookmarkName.NotNULLOrEmpty}
			{
				if ${Config.HideHowLong} == 0
				{
					ClearToMine:Set[${Math.Calc[${LavishScript.RunningTime} + 999999999999999999999999999999999999]}]	
				}
				else
				{
					ClearToMine:Set[${Math.Calc[${LavishScript.RunningTime} + (${Config.HideHowLong} * 60000)]}]
				}
				This:LogInfo["Hope there is actually a POS here"]
				This:InsertState["FleeToPOS"]
				return TRUE
			}
			if ${Config.UseWeirdNavigation} && ${Config.WeirdBookmarkPrefix.NotNULLOrEmpty}
			{
				if ${Config.HideHowLong} == 0
				{
					ClearToMine:Set[${Math.Calc[${LavishScript.RunningTime} + 999999999999999999999999999999999999]}]	
				}
				else
				{
					ClearToMine:Set[${Math.Calc[${LavishScript.RunningTime} + (${Config.HideHowLong} * 60000)]}]
				}			
				This:LogInfo["Commence Weird Navigation"]
				This:InsertState["WeirdNavigation"]
				return TRUE
			}
			
			if ${Config.HideHowLong} == 0
			{
				ClearToMine:Set[${Math.Calc[${LavishScript.RunningTime} + 999999999999999999999999999999999999]}]	
			}
			else
			{
				ClearToMine:Set[${Math.Calc[${LavishScript.RunningTime} + (${Config.HideHowLong} * 60000)]}]
			}
			This:InsertState["GoToStation", 3000]
			return TRUE
			
		}
		; This is an exit condition triggered by MinerForeman or MinerWorker. Usually due to a full ore bay or running out of
		; supplies.
		if ${ReturnToStation}
		{
			MinerForeman.InhibitBursts:Set[TRUE]
			MinerWorker.MiningTime:Set[FALSE]
			This:LogInfo["Need to dropoff or load supplies, back to base"]
			StatusGreen:Set[FALSE]
			StatusChecked:Set[FALSE]
			This:InsertState["GoToStation", 3000]
			return TRUE
		}
		; This is a temporary exit condition Da Boss can call, we use it if the boss needs to reposition at the site
		; and repositioning with them is foolish and dangerous. 
		if ${ScramYaMooks} && !${Config.FleetBoss}
		{
			MinerWorker.MiningTime:Set[FALSE]
			This:LogInfo["Boss says its time to beat it, lets scram"]
			This:InsertState["GoToStation", 3000]
			return TRUE
		}
		; Our current mining location is depleted, find another.
		if ${LocationDepleted} && (${Config.FleetBoss} || !${Config.FleetUp})
		{
			MinerWorker.MiningTime:Set[FALSE]
			if ${Config.FleetBoss}
			{
				relay all -event TimeToScram TRUE
				relay all -event LeaderSummoning FALSE
				MinerForeman.InhibitBursts:Set[TRUE]
				
			}
			This:InsertState["CheckForWork"]
			return TRUE
		}
		; We are the fleet boss
		if ${Config.FleetBoss}
		{
			if ${Me.Fleet.Size} < ${Config.ExpectedParticipants}
			{
				if ${CurrentParticipants.FirstKey(exists)}
				{
					do
					{
						; Lets see if this behaves with local torn asunder
						if ${Me.Fleet.Member[${CurrentParticipants.CurrentValue}](exists)}
						{
							continue
						}
						if ${Being[${CurrentParticipants.CurrentValue}](exists)}
						{
							Being[${CurrentParticipants.CurrentValue}]:InviteToFleet
						}
					}
					while ${CurrentParticipants.NextKey(exists)}
				}
			}
			MinerForeman.InhibitBursts:Set[FALSE]
			; We want to stay aligned at all times.
			; Not done yet, math.
			;if ${Config.AlignHomeStructure}
			;{
			;
			
			;}
			; We want to keep our mooks in range of the mineables without any other considerations.
			if !${Config.AlignHomeStructure}
			{
				; We want to wander the mining site, searching for meaning. (Asteroid case)
				if ${MinerWorker.Asteroids.TargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.Asteroids.TargetList.Get[1]}]}
				{
					relay all -event LeaderSummoning TRUE
					relay all -event TimeToScram FALSE
					Move:Approach[${MinerWorker.Asteroids.TargetList.Get[1]},10000]
					return FALSE
				}
				if ${MinerWorker.AsteroidsDistant.TargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.AsteroidsDistant.TargetList.Get[1]}]} && !${MinerWorker.Asteroids.TargetList.Get[1]}
				{
					relay all -event LeaderSummoning TRUE
					relay all -event TimeToScram FALSE
					Move:Approach[${MinerWorker.AsteroidsDistant.TargetList.Get[1]},10000]}]
					return FALSE	
				}
				; We want to wander the mining site, searching for meaning. (Ice case)
				if ${MinerWorker.Ice.TargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.Ice.TargetList.Get[1]}]}
				{
					relay all -event LeaderSummoning TRUE
					relay all -event TimeToScram FALSE
					Move:Approach[${MinerWorker.Ice.TargetList.Get[1]},10000]
					return FALSE
				}
				if ${MinerWorker.IceDistant.TargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.IceDistant.TargetList.Get[1]}]} && !${MinerWorker.Ice.TargetList.Get[1]}
				{
					relay all -event LeaderSummoning TRUE
					relay all -event TimeToScram FALSE
					Move:Approach[${MinerWorker.IceDistant.TargetList.Get[1]},10000]
					return FALSE	
				}
				; We want to wander the mining site, searching for meaning. (Gas case)
				if ${MinerWorker.Gas.TargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.Gas.TargetList.Get[1]}]}
				{
					relay all -event LeaderSummoning TRUE
					relay all -event TimeToScram FALSE
					Move:Approach[${MinerWorker.Gas.TargetList.Get[1]},10000]
					return FALSE
				}
				if ${MinerWorker.GasDistant.TargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.GasDistant.TargetList.Get[1]}]} && !${MinerWorker.Gas.TargetList.Get[1]}
				{
					relay all -event LeaderSummoning TRUE
					relay all -event TimeToScram FALSE
					Move:Approach[${MinerWorker.GasDistant.TargetList.Get[1]},10000]
					return FALSE	
				}

			}
		}
		
		; We are in a fleet but not the boss
		if ${Config.FleetUp} && !${Config.FleetBoss}
		{
			; We want to orbit the boss, it is up to the boss to keep us in range of mineables.
			if ${Config.OrbitBoss}
			{
				if ${DaBossEntityID} == 0
				{
					if ${Entity[CharID == ${Config.DaBossID}](exists)}
					{
						echo DEBUG - Found Da Boss Entity ID ${Entity[CharID == ${Config.DaBossID}].ID}
						DaBossEntityID:Set[${Entity[CharID == ${Config.DaBossID}].ID}]
					}
				}
				if !${MyShip.ToEntity.Approaching.ID.Equal[${DaBossEntityID}]}
				{
					Move:Orbit[${DaBossEntityID},${Script[Tehbot].VariableScope.Mining.Config.OrbitBossDistance}]
					return FALSE
				}
				return FALSE
			}
			; We want to stay within boost/compression range of the boss. There will be no setup for not staying near the boss.
			; Incomplete for now, need to think up a good way to keep the miners within range of their chosen mineables but also
			; Within range of Da Boss
			if !${Config.OrbitBoss}
			{
				; We want to orbit rocks, which is fine provided they are near the boss.
				if ${Config.OrbitRocks}
				{
					; We want to orbit rocks (Asteroid case)
					if ${MinerWorker.AsteroidsDistant.TargetList.Get[1]}
					{
						if ${MinerWorker.Asteroids.LockedTargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.Asteroids.LockedTargetList.Get[1]}]} && ${Me.ToEntity.Mode} != MOVE_ORBITING
						{
							Move:Orbit[${MinerWorker.Asteroids.LockedTargetList.Get[1]}, ${Config.OrbitRocksDistance}]
							return FALSE
						}
						if ${MinerWorker.AsteroidsDistant.TargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.AsteroidsDistant.TargetList.Get[1]}]} && !${MinerWorker.Asteroids.LockedTargetList.Get[1]} && ${Me.ToEntity.Mode} != MOVE_ORBITING
						{
							Move:Orbit[${MinerWorker.AsteroidsDistant.TargetList.Get[1]}, ${Config.OrbitRocksDistance}]
							return FALSE	
						}			
					}
					; We want to orbit rocks (Ice case)
					if ${MinerWorker.IceDistant.TargetList.Get[1]}
					{
						if ${MinerWorker.Ice.LockedTargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.Ice.LockedTargetList.Get[1]}]} && ${Me.ToEntity.Mode} != MOVE_ORBITING
						{
							Move:Orbit[${MinerWorker.Ice.LockedTargetList.Get[1]}, ${Config.OrbitRocksDistance}]
							return FALSE
						}
						if ${MinerWorker.IceDistant.TargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.IceDistant.TargetList.Get[1]}]} && !${MinerWorker.Ice.LockedTargetList.Get[1]} && ${Me.ToEntity.Mode} != MOVE_ORBITING
						{
							Move:Orbit[${MinerWorker.IceDistant.TargetList.Get[1]}, ${Config.OrbitRocksDistance}]
							return FALSE	
						}			
					}
					; We want to orbit rocks (Gas case)
					if ${MinerWorker.GasDistant.TargetList.Get[1]}
					{
						if ${MinerWorker.Gas.LockedTargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.Gas.LockedTargetList.Get[1]}]} && ${Me.ToEntity.Mode} != MOVE_ORBITING
						{
							Move:Orbit[${MinerWorker.Gas.LockedTargetList.Get[1]}, ${Config.OrbitRocksDistance}]
							return FALSE
						}
						if ${MinerWorker.GasDistant.TargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.GasDistant.TargetList.Get[1]}]} && !${MinerWorker.Gas.LockedTargetList.Get[1]} && ${Me.ToEntity.Mode} != MOVE_ORBITING
						{
							Move:Orbit[${MinerWorker.GasDistant.TargetList.Get[1]}, ${Config.OrbitRocksDistance}]
							return FALSE	
						}			
					}				
				}
				; We want to maintain alignment to the Home Structure, which is fine if we are near the boss and also the mineables.
				; Not done, math.
				;if ${Config.AlignHomeStructure}
				;{
				;	
				;
				;}
				; We are a clown and we chose both aligning structure and orbiting rocks
				if ${Config.OrbitRocks} && ${Config.AlignHomeStructure}
				{
					This:LogInfo["Do not set both orbit rocks and align structure - Stopping"]
					Move:Bookmark["${Config.HomeStructure}"]
					This:InsertState["Traveling"]
					This:Stop
				}
			}
		}
		
		; We are flying solo
		if !${Config.FleetUp}
		{	
			; We want to stay aligned at all times. This is gonna take some real math yo.
			if ${Config.AlignHomeStructure} && !${Config.OrbitRocks}
			{
				if ${Config.HomeStructure.NotNULLOrEmpty} 
				{
					if ${Me.ToEntity.Mode} != MOVE_ALIGNED
					{
						This:LogInfo["Aligning To ${Config.HomeStructure}"]
						EVE.Bookmark[${Config.HomeStructure}]:AlignTo
					}
					if  ${MinerWorker.MineablesAhead}
					{
						; I spent so long making that bool work I forgot what I was doing
						return false
					}
					; Ensure we actually are at half our max speed before we check for this.	
					if !${MinerWorker.MineablesAhead} && ${Math.Calc[${Me.ToEntity.Velocity} / ${Me.ToEntity.MaxVelocity}]} >= 0.5
					{
						echo DEBUG - NO MINEABLES AHEAD
						; No mineables ahead, need a change of venue
						if  ${Entity[${MinerWorker.FurthestMineable}](exists)}
						{
							; Just a simple bookmarking, Using its distance for now.
							Entity[${MinerWorker.FurthestMineable}]:CreateBookmark["${Entity[${MinerWorker.FurthestMineable}].Distance.Int}", "", "", 1]
							Script[Tehbot].VariableScope.Mining.Config:SetWarpBackToName[${Entity[${MinerWorker.FurthestMineable}].Distance.Int}]
							; Just a simple return to station set
							ReturnToStation:Set[TRUE]
							return FALSE
						}
					}
				
					
					return FALSE
				}
				else
				{
					This:LogInfo["Don't know how you made it this far with Home Structure unset - Stopping"]
					This:Stop				
				}
				return FALSE
			}
			; We want to orbit rocks (Asteroid case)
			if ${Config.OrbitRocks} && !${Config.AlignHomeStructure} && ${MinerWorker.AsteroidsDistant.TargetList.Get[1]}
			{
				if ${MinerWorker.Asteroids.LockedTargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.Asteroids.LockedTargetList.Get[1]}]}
				{
					Move:Orbit[${MinerWorker.Asteroids.LockedTargetList.Get[1]}, ${Config.OrbitRocksDistance}]
					return FALSE
				}
				if ${MinerWorker.AsteroidsDistant.TargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.AsteroidsDistant.TargetList.Get[1]}]} && !${MinerWorker.Asteroids.LockedTargetList.Get[1]}
				{
					Move:Orbit[${MinerWorker.AsteroidsDistant.TargetList.Get[1]}, ${Config.OrbitRocksDistance}]
					return FALSE	
				}			
			}
			; We want to orbit rocks (Ice case)
			if ${Config.OrbitRocks} && !${Config.AlignHomeStructure} && ${MinerWorker.IceDistant.TargetList.Get[1]}
			{
				if ${MinerWorker.Ice.LockedTargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.Ice.LockedTargetList.Get[1]}]}
				{
					Move:Orbit[${MinerWorker.Ice.LockedTargetList.Get[1]}, ${Config.OrbitRocksDistance}]
					return FALSE
				}
				if ${MinerWorker.IceDistant.TargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.IceDistant.TargetList.Get[1]}]} && !${MinerWorker.Ice.LockedTargetList.Get[1]}
				{
					Move:Orbit[${MinerWorker.IceDistant.TargetList.Get[1]}, ${Config.OrbitRocksDistance}]
					return FALSE	
				}			
			}
			; We want to orbit rocks (Gas case)
			if ${Config.OrbitRocks} && !${Config.AlignHomeStructure} && ${MinerWorker.GasDistant.TargetList.Get[1]}
			{
				if ${MinerWorker.Gas.LockedTargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.Gas.LockedTargetList.Get[1]}]}
				{
					Move:Orbit[${MinerWorker.Gas.LockedTargetList.Get[1]}, ${Config.OrbitRocksDistance}]
					return FALSE
				}
				if ${MinerWorker.GasDistant.TargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.GasDistant.TargetList.Get[1]}]} && !${MinerWorker.Gas.LockedTargetList.Get[1]}
				{
					Move:Orbit[${MinerWorker.GasDistant.TargetList.Get[1]}, ${Config.OrbitRocksDistance}]
					return FALSE	
				}			
			}
			; We are a clown and we chose both aligning structure and orbiting rocks
			if ${Config.OrbitRocks} && ${Config.AlignHomeStructure}
			{
				This:LogInfo["Do not set both orbit rocks and align structure - Stopping"]
				Move:Bookmark["${Config.HomeStructure}"]
				This:InsertState["Traveling"]
				This:Stop
			}
			; We want to wander the mining site, searching for meaning. (Asteroid case)
			if ${MinerWorker.Asteroids.LockedTargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.Asteroids.LockedTargetList.Get[1]}]}
			{
				Move:Approach[${MinerWorker.Asteroids.LockedTargetList.Get[1]},${Math.Calc[${Ship.ModuleList_OreMining.Range} * .5]}]
				return FALSE
			}
			if ${MinerWorker.AsteroidsDistant.TargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.AsteroidsDistant.TargetList.Get[1]}]} && !${MinerWorker.Asteroids.LockedTargetList.Get[1]}
			{
				Move:Approach[${MinerWorker.AsteroidsDistant.TargetList.Get[1]}, ${Math.Calc[${Ship.ModuleList_OreMining.Range} * .5]}]
				return FALSE	
			}
			; We want to wander the mining site, searching for meaning. (Ice case)
			if ${MinerWorker.Ice.LockedTargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.Ice.LockedTargetList.Get[1]}]}
			{
				Move:Approach[${MinerWorker.Ice.LockedTargetList.Get[1]},${Math.Calc[${Ship.ModuleList_IceMining.Range} * .5]}]
				return FALSE
			}
			if ${MinerWorker.IceDistant.TargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.IceDistant.TargetList.Get[1]}]} && !${MinerWorker.Ice.LockedTargetList.Get[1]}
			{
				Move:Approach[${MinerWorker.IceDistant.TargetList.Get[1]}, ${Math.Calc[${Ship.ModuleList_IceMining.Range} * .5]}]
				return FALSE	
			}
			; We want to wander the mining site, searching for meaning. (Gas case)
			if ${MinerWorker.Gas.LockedTargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.Gas.LockedTargetList.Get[1]}]}
			{
				Move:Approach[${MinerWorker.Gas.LockedTargetList.Get[1]},${Math.Calc[${Ship.ModuleList_GasMining.Range} * .5]}]
				return FALSE
			}
			if ${MinerWorker.GasDistant.TargetList.Get[1]} && !${MyShip.ToEntity.Approaching.ID.Equal[${MinerWorker.GasDistant.TargetList.Get[1]}]} && !${MinerWorker.Gas.LockedTargetList.Get[1]}
			{
				Move:Approach[${MinerWorker.GasDistant.TargetList.Get[1]}, ${Math.Calc[${Ship.ModuleList_GasMining.Range} * .5]}]
				return FALSE	
			}
		}
		return FALSE
	}

	; We use this to flee to a POS and hang out there until the heat is gone.
	member:bool FleeToPOS()
	{
		if !${Config.UseWeirdNavigation}
		{
			Move:Bookmark["${Config.POSBookmarkName}"]
			This:InsertState["Traveling"]
			This:InsertState["CheckForWork", 5000]
		}
		
	}
	; This is Weird Navigation, we use it to bounce around a bit before going to our fleeing destination
	; Not done yet.
	member:bool WeirdNavigation()
	{
		
	
	}
	; We use this to build our list of valid anomalies we are allowed to run. We will do this once
	; on starting the bot, and on demand with a button in the UI.
	member:bool BuildAnomaliesList()
	{
		ValidAnomalies:Clear
		echo ${AnomalyMasterCollection.Used} Anomaly Master Collection
		
		if ${AnomalyMasterCollection.FirstValue}
		{
			do
			{
				if ${AnomalyMasterCollection.CurrentValue} == TRUE
				{
					ValidAnomalies:Add[${AnomalyMasterCollection.CurrentKey}]
					echo DEBUG - ADDING ${AnomalyMasterCollection.CurrentKey} TO VALID LIST
				}
				else
				{
					continue
				}
			}
			while ${AnomalyMasterCollection.NextKey(exists)}
		}
		return TRUE
	}
	; We use this to update our anomalies. This will be triggered by some criteria I haven't thought up yet.
	member:bool UpdateAnoms()
	{
	
		MyShip.Scanners.System:GetAnomalies[MyAnomalies]
		MyAnomalies:GetIterator[MyAnomalies_Iterator]	
		if ${MyAnomalies_Iterator:First(exists)}
		{
			do
			{
				; Check to see if the currently being run site still exists, this should work even if you disconnect via XML storage.
				if ${MyAnomalies_Iterator.Value.ID} == ${Config.PersistentAnomID}
				{
					MyAnomalies_Iterator.Value:WarpTo[${Config.WarpInDistance}, FALSE]
					This:LogInfo["Anomaly Found - ${MyAnomalies_Iterator.Value.Name} - Warping]
					This:InsertState["Traveling", 5000]
					This:QueueState["StartWorking", 5000]
					return TRUE
				
				}
				; I'm too lazy to add like 50 gas sites to this sorry
				elseif ${ValidAnomalies.Contains[Nebula]} && ${MyAnomalies_Iterator.Value.DungeonName.Find["Nebula"]} && ${MyAnomalies_Iterator.Value.ID} != ${Config.PersistentAnomID}
				{
					Script[Tehbot].VariableScope.Mining.Config:SetPersistentAnomID[${MyAnomalies_Iterator.Value.ID}]
					MyAnomalies_Iterator.Value:WarpTo[${Config.WarpInDistance}, FALSE]
					This:LogInfo["Anomaly Found - ${MyAnomalies_Iterator.Value.Name} - Warping]
					This:InsertState["Traveling", 5000]
					This:QueueState["StartWorking", 5000]
					return TRUE
				}
				elseif ${ValidAnomalies.Contains[Reservoir]} && ${MyAnomalies_Iterator.Value.DungeonName.Find["Reservoir"]} && ${MyAnomalies_Iterator.Value.ID} != ${Config.PersistentAnomID}
				{
					Script[Tehbot].VariableScope.Mining.Config:SetPersistentAnomID[${MyAnomalies_Iterator.Value.ID}]
					MyAnomalies_Iterator.Value:WarpTo[${Config.WarpInDistance}, FALSE]
					This:LogInfo["Anomaly Found - ${MyAnomalies_Iterator.Value.Name} - Warping]
					This:InsertState["Traveling", 5000]
					This:QueueState["StartWorking", 5000]
					return TRUE
				}
				; Everything else goes here
				elseif ${ValidAnomalies.Contains[${MyAnomalies_Iterator.Value.DungeonName}]} && ${MyAnomalies_Iterator.Value.ID} != ${Config.PersistentAnomID}
				{
					Script[Tehbot].VariableScope.Mining.Config:SetPersistentAnomID[${MyAnomalies_Iterator.Value.ID}]
					MyAnomalies_Iterator.Value:WarpTo[${Config.WarpInDistance}, FALSE]
					This:LogInfo["Anomaly Found - ${MyAnomalies_Iterator.Value.Name} - Warping]
					This:InsertState["Traveling", 5000]
					This:QueueState["StartWorking", 5000]
					return TRUE
				}
				else
				{
					Config.PersistentAnomID:Set[0]
				}
			
			}
			while ${MyAnomalies_Iterator:Next(exists)}
			
			This:LogInfo["DEBUG - Present Anoms Filtered Out - Stopping"]
			Move:Bookmark["${Config.HomeStructure}"]
			This:InsertState["Traveling"]
			This:Stop
		}
		else
		{
			This:LogInfo["DEBUG - No Anoms Present - Stopping"]
			Move:Bookmark["${Config.HomeStructure}"]
			This:InsertState["Traveling"]
			This:Stop
			
		}
	}
	
	
	; Alright so, if we are going to be always aligned we need to know when to warp out for non-emergencies.
	; Either we get lazy and go strictly by distance from the central point of the mining site, or we go by
	; Some crazy bullshit math garbage that I don't entirely understand and will be making it up as I go.
	; If this fails I'll leave the guts here as a testament to my hubris.
	;method HubristicPathAnalysis()
	;{
	
	
	;}
	
	; Load up required items. If you are Foreman: load up Heavy Water, Command Burst Charges, Drones.
	; If you are a Miner Worker: load up Mining Crystals and Drones.
	; Stolen mostly wholesale from the Mission Mode
	member:bool LoadSupplies()
	{
		;if ${Config.HowManyMiningCrystals} <= 0

		variable index:item items
		variable iterator itemIterator
		variable int crystalsToLoad = ${Config.HowManyMiningCrystals}
		variable string firstBurstCharge = ${Config.CommandBurstOne}
		variable int firstBurstToLoad = ${Config.CommandBurstAmount}
		variable string secondBurstCharge = ${Config.CommandBurstTwo}
		variable int secondBurstToLoad = ${Config.CommandBurstAmount}
		variable string thirdBurstCharge = ${Config.CommandBurstThree}
		variable int thirdBurstToLoad = ${Config.CommandBurstAmount}
		variable int heavywaterToLoad = ${Config.UnitsHeavyWater}
		variable int droneAmountToLoad = -1
		variable int loadingDroneNumber = 0
		variable string preferredDroneType
		variable string fallbackDroneType

		variable string batteryType
		batteryType:Set[${Config.BatteryToBring}]
		variable int batteryToLoad
		batteryToLoad:Set[${Config.BatteryAmountToBring}]
		; echo load ${batteryToLoad} X ${batteryType}

		if (!${EVEWindow[Inventory](exists)})
		{
			EVE:Execute[OpenInventory]
			return FALSE
		}
		
		if ${Config.UseIndustrialCore}
		{
			if (!${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipFuelBay](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipFuelBay].Capacity} < 0)
			{
				EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipFuelBay]:MakeActive
			}
		}

		if ${Config.UseDrones}
		{
			if (!${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} < 0)
			{
				EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay]:MakeActive
				Client:Wait[2000]
				This:LogInfo["Checkpoint 1"]
				return FALSE
			}

			variable float specifiedDroneVolume = ${Drones.Data.GetVolume[${Config.DroneType}]}
			echo DEBUG - PREFERRED DRONE SET TO ${Config.DroneType}
			preferredDroneType:Set[${Config.DroneType}]
			
			Client:Wait[2000]
			This:LogInfo["Checkpoint 2"]
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay]:GetItems[items]
			items:GetIterator[itemIterator]
			if ${itemIterator:First(exists)}
			{
				do
				{
					if ${Config.MunitionStorage.Equal[Corporation Hangar]}
					{
						if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)} && !${Config.HomeStructureIsCitadel}
						{
							EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 3"]
							return FALSE
						}
						
						if !${EVEWindow[Inventory].ChildWindow[StructureCorpHangar](exists)} && ${Config.HomeStructureIsCitadel}
						{
							EVEWindow[Inventory].ChildWindow[StructureCorpHangar]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 3"]
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)} && !${Config.HomeStructureIsCitadel}
						{

							EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 4"]
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow["StructureCorpHangar", ${Config.MunitionStorageFolder}](exists)} && ${Config.HomeStructureIsCitadel}
						{

							EVEWindow[Inventory].ChildWindow["StructureCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 4"]
							return FALSE
						}
						
						
						if !${itemIterator.Value.Name.Equal[${preferredDroneType}]} 
						{
							itemIterator.Value:MoveTo[MyStationCorporateHangar, StationCorporateHangar, ${itemIterator.Value.Quantity}, ${This.CorporationFolder}]
							return FALSE
						}
					}
					elseif ${Config.MunitionStorage.Equal[Personal Hangar]}
					{
						if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)} && !${Config.HomeStructureIsCitadel}
						{
							EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 5"]
							return FALSE
						}
						
						if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StructureItemHangar](exists)} && ${Config.HomeStructureIsCitadel}
						{
							EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StructureItemHangar]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 5"]
							return FALSE
						}

						if !${itemIterator.Value.Name.Equal[${preferredDroneType}]} && \
							(!${itemIterator.Value.Name.Equal[${fallbackDroneType}]} || !${isLoadingFallbackDrones})
						{
							itemIterator.Value:MoveTo[MyStationHangar, Hangar]
							return FALSE
						}
					}

				}
				while ${itemIterator:Next(exists)}
			}

			variable float remainingDroneSpace = ${Math.Calc[${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} - ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].UsedCapacity}]}

			if ${specifiedDroneVolume} > 0
			{
				droneAmountToLoad:Set[${Math.Calc[${remainingDroneSpace} / ${specifiedDroneVolume}].Int}]
			}
		}

		if !${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo].Capacity} < 0
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:MakeActive
			Client:Wait[2000]
			This:LogInfo["Checkpoint 6"]
			return FALSE
		}

		crystalsToLoad:Dec[${This.InventoryItemQuantity[${ammo}, ${Me.ShipID}, "ShipCargo"]}]
		firstBurstToLoad:Dec[${This.InventoryItemQuantity[${firstBurstCharge}, ${Me.ShipID}, "ShipCargo"]}]
		secondBurstToLoad:Dec[${This.InventoryItemQuantity[${secondBurstCharge}, ${Me.ShipID}, "ShipCargo"]}]		
		thirdBurstToLoad:Dec[${This.InventoryItemQuantity[${thirdBurstCharge}, ${Me.ShipID}, "ShipCargo"]}]	

		if ${Config.UseIndustrialCore}
		{
			heavywaterToLoad:Dec[${This.InventoryItemQuantity["Heavy Water", ${Me.ShipID}, "ShipFuelBay"]}]
		}
		
		
		batteryToLoad:Dec[${This.InventoryItemQuantity[${batteryType}, ${Me.ShipID}, "ShipCargo"]}]
		
		echo - DEBUG - DECREMENTING BULLSHIT

		EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:GetItems[items]
		items:GetIterator[itemIterator]
		if ${itemIterator:First(exists)}
		{
			do
			{
				if ${droneAmountToLoad} > 0 && ${itemIterator.Value.Name.Equal[${preferredDroneType}]}
				{
					if (!${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} < 0)
					{
						EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay]:MakeActive
						Client:Wait[2000]
						This:LogInfo["Checkpoint 7"]
						return FALSE
					}

					if ${itemIterator.Value.Name.Equal[${preferredDroneType}]}
					{
						loadingDroneNumber:Set[${droneAmountToLoad}]
						if ${itemIterator.Value.Quantity} < ${droneAmountToLoad}
						{
							loadingDroneNumber:Set[${itemIterator.Value.Quantity}]
						}
						This:LogInfo["Loading ${loadingDroneNumber} \ao${preferredDroneType}\aws."]
						itemIterator.Value:MoveTo[${MyShip.ID}, DroneBay, ${loadingDroneNumber}]
						droneAmountToLoad:Dec[${loadingDroneNumber}]
						return FALSE
					}
					continue
				}

				; Move fallback drones together(to station hanger) before moving them to drone bay to ensure preferred type is loaded before fallback type.
				; Also move ammos not in use to release cargo space.
				if ((${Ship.ModuleList_MiningLaser.Count} && \
					!${itemIterator.Value.Name.Equal[${Ship.ModuleList_Weapon.FallbackAmmo}]} && \
					!${itemIterator.Value.Name.Equal[${Ship.ModuleList_Weapon.FallbackLongRangeAmmo}]} && \
					!${itemIterator.Value.Name.Equal[${ammo}]} && \
					!${itemIterator.Value.Name.Equal[${secondaryAmmo}]}) && \
					(${itemIterator.Value.Name.Equal[${Config.KineticAmmo}]} || \
					${itemIterator.Value.Name.Equal[${firstBurstCharge}]} || \
					${itemIterator.Value.Name.Equal[${secondBurstCharge}]} || \
					${itemIterator.Value.Name.Equal[${thirdBurstCharge}]} || \
					${itemIterator.Value.Name.Equal[${fallbackDroneType}]}
				{
					if ${Config.MunitionStorage.Equal[Corporation Hangar]}
					{
						if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)} && !${Config.HomeStructureIsCitadel}
						{
							EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 8"]
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow[StructureCorpHangar](exists)} && ${Config.HomeStructureIsCitadel}
						{
							EVEWindow[Inventory].ChildWindow[StructureCorpHangars]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 8"]
							return FALSE
						}
						
						if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)} && !${Config.HomeStructureIsCitadel}
						{

							EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 9"]
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow["StructureCorpHangar", ${Config.MunitionStorageFolder}](exists)} && ${Config.HomeStructureIsCitadel}
						{

							EVEWindow[Inventory].ChildWindow["StructureCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 9"]
							return FALSE
						}
						
						itemIterator.Value:MoveTo[MyStationCorporateHangar, StationCorporateHangar, ${itemIterator.Value.Quantity}, ${This.CorporationFolder}]
						; return FALSE
					}
					elseif ${Config.MunitionStorage.Equal[Personal Hangar]} 
					{
						if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)} && !${Config.HomeStructureIsCitadel}
						{
							EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 10"]
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StructureItemHangar](exists)} && ${Config.HomeStructureIsCitadel}
						{
							EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StructureItemHangar]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 10"]
							return FALSE
						}
						
						itemIterator.Value:MoveTo[MyStationHangar, Hangar]
						; return FALSE
					}
					continue
				}
			}
			while ${itemIterator:Next(exists)}
		}

		if ${Config.MunitionStorage.Equal[Corporation Hangar]}
		{
			if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)} !${Config.HomeStructureIsCitadel}
			{
				EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
				Client:Wait[2000]
				This:LogInfo["Checkpoint 11"]
				return FALSE
			}

			if !${EVEWindow[Inventory].ChildWindow[StructureCorpHangar](exists)} && ${Config.HomeStructureIsCitadel}
			{
				EVEWindow[Inventory].ChildWindow[StructureCorpHangars]:MakeActive
				Client:Wait[2000]
				This:LogInfo["Checkpoint 11"]
				return FALSE
			}
			
			if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)} !${Config.HomeStructureIsCitadel}
			{
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
				Client:Wait[2000]
				This:LogInfo["Checkpoint 12"]
				return FALSE
			}
			
			if !${EVEWindow[Inventory].ChildWindow["StructureCorpHangar", ${Config.MunitionStorageFolder}](exists)} && ${Config.HomeStructureIsCitadel}
			{
				EVEWindow[Inventory].ChildWindow["StructureCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
				Client:Wait[2000]
				This:LogInfo["Checkpoint 12"]
				return FALSE
			}
			
			if !${Config.HomeStructureIsCitadel}
			{
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:GetItems[items]
			}
			if ${Config.HomeStructureIsCitadel}
			{
				EVEWindow[Inventory].ChildWindow["StructureCorpHangar", ${Config.MunitionStorageFolder}]:GetItems[items]
			}			
		}
		elseif ${Config.MunitionStorage.Equal[Personal Hangar]}
		{
			if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)} && !${Config.HomeStructureIsCitadel}
			{
				EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
				Client:Wait[2000]
				This:LogInfo["Checkpoint 13"]
				return FALSE
			}
			
			if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StructureItemHangar](exists)} && ${Config.HomeStructureIsCitadel}
			{
				EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StructureItemHangar]:MakeActive
				Client:Wait[2000]
				This:LogInfo["Checkpoint 13"]
				return FALSE
			}
			
			if !${Config.HomeStructureIsCitadel}
			{
				EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[items]
			}
			if ${Config.HomeStructureIsCitadel}
			{
				EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StructureItemHangar]:GetItems[items]
			}
		}

		; Load ammos
		items:GetIterator[itemIterator]
		if ${itemIterator:First(exists)}
		{
			do
			{
				if ${crystalsToLoad} > 0 && ${itemIterator.Value.Name.Equal[${WhatMiningCrystal}]}
				{
					if ${itemIterator.Value.Quantity} >= ${crystalsToLoad}
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${crystalsToLoad}]
						crystalsToLoad:Set[0]
						return FALSE
					}
					else
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${itemIterator.Value.Quantity}]
						crystalsToLoad:Dec[${itemIterator.Value.Quantity}]
						return FALSE
					}
				}

				if ${firstBurstToLoad} > 0 && ${itemIterator.Value.Name.Equal[${firstBurstCharge}]}
				{
					if ${itemIterator.Value.Quantity} >= ${firstBurstToLoad}
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${firstBurstToLoad}]
						firstBurstToLoad:Set[0]
						return FALSE
					}
					else
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${itemIterator.Value.Quantity}]
						firstBurstToLoad:Dec[${itemIterator.Value.Quantity}]
						return FALSE
					}
				}

				if ${secondBurstToLoad} > 0 && ${itemIterator.Value.Name.Equal[${secondBurstCharge}]}
				{
					if ${itemIterator.Value.Quantity} >= ${secondBurstToLoad}
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${secondBurstToLoad}]
						secondBurstToLoad:Set[0]
						return FALSE
					}
					else
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${itemIterator.Value.Quantity}]
						secondBurstToLoad:Dec[${itemIterator.Value.Quantity}]
						return FALSE
					}
				}

				if ${thirdBurstToLoad} > 0 && ${itemIterator.Value.Name.Equal[${thirdBurstCharge}]}
				{
					if ${itemIterator.Value.Quantity} >= ${thirdBurstToLoad}
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${thirdBurstToLoad}]
						thirdBurstToLoad:Set[0]
						return FALSE
					}
					else
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${itemIterator.Value.Quantity}]
						thirdBurstToLoad:Dec[${itemIterator.Value.Quantity}]
						return FALSE
					}
				}


				if ${heavywaterToLoad} > 0 && ${itemIterator.Value.Name.Equal["Heavy Water"]}
				{
					if ${itemIterator.Value.Quantity} >= ${heavywaterToLoad}
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${heavywaterToLoad}]
						heavywaterToLoad:Set[0]
						return FALSE
					}
					else
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, ShipFuelBay, ${itemIterator.Value.Quantity}]
						heavywaterToLoad:Dec[${itemIterator.Value.Quantity}]
						return FALSE
					}
				}
			}
			while ${itemIterator:Next(exists)}
		}
		if ${Config.UseDrones}
		{
			if (!${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} < 0)
			{
				EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay]:MakeActive
				Client:Wait[2000]
				This:LogInfo["Checkpoint 14"]
				return FALSE
			}

			; Load preferred type of drones
			items:GetIterator[itemIterator]
			if ${droneAmountToLoad} > 0 && ${itemIterator:First(exists)}
			{
				do
				{
					if ${droneAmountToLoad} > 0 && ${itemIterator.Value.Name.Equal[${preferredDroneType}]}
					{
						loadingDroneNumber:Set[${droneAmountToLoad}]
						if ${itemIterator.Value.Quantity} < ${droneAmountToLoad}
						{
							loadingDroneNumber:Set[${itemIterator.Value.Quantity}]
						}
						This:LogInfo["Loading ${loadingDroneNumber} \ao${preferredDroneType}\aws."]
						itemIterator.Value:MoveTo[${MyShip.ID}, DroneBay, ${loadingDroneNumber}]
						droneAmountToLoad:Dec[${loadingDroneNumber}]
						return FALSE
					}
				}
				while ${itemIterator:Next(exists)}
			}

			; Out of preferred type of drones, load fallback(configured) type
			;if ${droneAmountToLoad} > 0 && ${fallbackDroneType.NotNULLOrEmpty}
			;{
			;	isLoadingFallbackDrones:Set[TRUE]
			;	items:GetIterator[itemIterator]
			;	if ${itemIterator:First(exists)}
			;	{
			;		do
			;		{
			;			if ${droneAmountToLoad} > 0 && ${itemIterator.Value.Name.Equal[${fallbackDroneType}]}
			;			{
			;				loadingDroneNumber:Set[${droneAmountToLoad}]
			;				if ${itemIterator.Value.Quantity} < ${droneAmountToLoad}
			;				{
			;					loadingDroneNumber:Set[${itemIterator.Value.Quantity}]
			;				}
			;				This:LogInfo["Loading ${loadingDroneNumber} \ao${fallbackDroneType}\aws for having no \ao${preferredDroneType}\aw."]
			;				itemIterator.Value:MoveTo[${MyShip.ID}, DroneBay, ${loadingDroneNumber}]
			;				droneAmountToLoad:Dec[${loadingDroneNumber}]
			;				return FALSE
			;			}
			;		}
			;		while ${itemIterator:Next(exists)}
			;	}
			;}
		}
		if ${crystalsToLoad} > 0 && ${Config.UseMiningCrystals}
		{
			This:LogCritical["You're out of ${ammo}, halting."]
			This:Stop
			return TRUE
		}
		elseif ${firstBurstToLoad} > 0 && ${Config.UseCommandBurstOne}
		{
			This:LogCritical["You're out of ${firstBurstCharge}, halting."]
			This:Stop
			return TRUE
		}
		elseif ${secondBurstToLoad} > 0 && ${Config.UseCommandBurstTwo}
		{
			This:LogCritical["You're out of ${secondBurstCharge}, halting."]
			This:Stop
			return TRUE
		}	
		elseif ${thirdBurstToLoad} > 0 && ${Config.UseCommandBurstThree}
		{
			This:LogCritical["You're out of ${thirdBurstCharge}, halting."]
			This:Stop
			return TRUE
		}			
		elseif ${Config.UseDrones} && ${droneAmountToLoad} > 0
		{
			This:LogCritical["You're out of drones, halting."]
			This:Stop
			return TRUE
		}
		elseif ${heavywaterToLoad} > 0
		{
			This:LogCritical["You're out of Heavy Water, halting."]
			This:Stop
			return TRUE
		}
		else
		{
			This:LogInfo["Checkpoint 2, loading complete"]
			This:QueueState["CheckForWork"]
			This:InsertState["StackShip"]
			return TRUE
		}
	}
	
	
	
	
	
	member:bool RefreshBookmarks()
	{
		This:LogInfo["Refreshing bookmarks"]
		EVE:RefreshBookmarks
		return TRUE
	}
	
	member:bool StackShip()
	{
		EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:StackAll
		return TRUE
	}
	
	member:bool StackHangars()
	{
		if !${Me.InStation}
		{
			return TRUE
		}

		if !${EVEWindow[Inventory](exists)}
		{
			EVE:Execute[OpenInventory]
			return FALSE
		}

		variable index:item items
		variable iterator itemIterator
		variable int64 dropOffContainerID = 0;

		if ${Config.MunitionStorage.Equal[Corporation Hangar]} 
		{
			if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)} && !${Config.HomeStructureIsCitadel}
			{
				EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
				Client:Wait[2000]
				This:LogInfo["Checkpoint 15"]
				return FALSE
			}
			if !${EVEWindow[Inventory].ChildWindow[StructureCorpHangar](exists)} && ${Config.HomeStructureIsCitadel}
			{
				EVEWindow[Inventory].ChildWindow[StructureCorpHangars]:MakeActive
				Client:Wait[2000]
				This:LogInfo["Checkpoint 15"]
				return FALSE
			}			

			if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)} && !${Config.HomeStructureIsCitadel}
			{
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
				Client:Wait[2000]
				This:LogInfo["Checkpoint 16"]
				return FALSE
			}

			if !${EVEWindow[Inventory].ChildWindow["StructureCorpHangar", ${Config.MunitionStorageFolder}](exists)} && ${Config.HomeStructureIsCitadel}
			{
				EVEWindow[Inventory].ChildWindow["StructureCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
				Client:Wait[2000]
				This:LogInfo["Checkpoint 16"]
				return FALSE
			}
			; Bug: IsRepackable and Repackage are not working
			; Repackage unloaded drones.
			; EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[items]
			; items:GetIterator[itemIterator]
			; if ${itemIterator:First(exists)}
			; {
			; 	do
			; 	{
			; 		This:LogInfo[ ${itemIterator.Value.Name} ${itemIterator.Value.Group} is repackageable ${itemIterator.Value.IsRepackable}]
			; 		if ${itemIterator.Value.Group.Find[Drone]}
			; 		{
			; 			echo repackaging ${itemIterator.Value.Name}
			; 			itemIterator.Value:Repackage
			; 			return FALSE
			; 		}
			; 	}
			; 	while ${itemIterator:Next(exists)}
			; }
			Client:Wait[2000]
			This:LogInfo["Checkpoint 17"]
			if !${Config.HomeStructureIsCitadel}
			{
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:StackAll
			}
			if ${Config.HomeStructureIsCitadel}
			{
				EVEWindow[Inventory].ChildWindow["StructureCorpHangar", ${Config.MunitionStorageFolder}]:StackAll
			}
			Client:Wait[2000]
			This:LogInfo["Checkpoint 18"]
			
			;if ${Config.DropOffToContainer} && ${Config.DropOffContainerName.NotNULLOrEmpty}
			;{
			;	EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:GetItems[items]
			;}
		}
		elseif ${Config.MunitionStorage.Equal[Personal Hangar]}
		{
			if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
			{

				EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
				Client:Wait[2000]
				This:LogInfo["Checkpoint 19"]
				return FALSE
			}

			; Bug: IsRepackable and Repackage are not working
			; Repackage unloaded drones.
			; EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[items]
			; items:GetIterator[itemIterator]
			; if ${itemIterator:First(exists)}
			; {
			; 	do
			; 	{
			; 		This:LogInfo[ ${itemIterator.Value.Name} ${itemIterator.Value.Group} is repackageable ${itemIterator.Value.IsRepackable}]
			; 		if ${itemIterator.Value.Group.Find[Drone]}
			; 		{
			; 			echo repackaging ${itemIterator.Value.Name}
			; 			itemIterator.Value:Repackage
			; 			return FALSE
			; 		}
			; 	}
			; 	while ${itemIterator:Next(exists)}
			; }
			
			EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:StackAll

			;if ${Config.DropOffToContainer} && ${Config.DropOffContainerName.NotNULLOrEmpty}
			;{
			;	EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[items]
			;}
		}

		items:GetIterator[itemIterator]
		if ${itemIterator:First(exists)}
		{
			do
			{
				if ${itemIterator.Value.Name.Equal[${Config.DropOffContainerName}]} && ${itemIterator.Value.Type.Equal["Station Container"]}
				{
					dropOffContainerID:Set[${itemIterator.Value.ID}]
					itemIterator.Value:Open

					if !${EVEWindow[Inventory].ChildWindow[${dropOffContainerID}](exists)} || \
						!${EVEWindow[Inventory].ActiveChild.ItemID.Equal[${dropOffContainerID}]} || \
						!${EVEWindow[Inventory].ChildWindow[${dropOffContainerID}].Capacity(exists)} || \
						(${EVEWindow[Inventory].ChildWindow[${dropOffContainerID}].Capacity} < 0)
					{
						EVEWindow[Inventory].ChildWindow[${dropOffContainerID}]:MakeActive
						Client:Wait[2000]
						This:LogInfo["Checkpoint 20"]
						return FALSE
					}

					EVEWindow[Inventory].ChildWindow[${dropOffContainerID}]:StackAll
					break
				}
			}
			while ${itemIterator:Next(exists)}
		}
		This:LogInfo["Stacked Hangar"]
		This:QueueState["CheckForWork", 5000]
		return TRUE
	}

	member:bool PrepHangars()
	{
		variable index:eveinvchildwindow InvWindowChildren
		variable iterator Iter
		EVEWindow[Inventory]:GetChildren[InvWindowChildren]
		InvWindowChildren:GetIterator[Iter]
		if ${Iter:First(exists)}
			do
			{
				if ${Iter.Value.Name.Equal[StationCorpHangars]}
				{
					Iter.Value:MakeActive
					Client:Wait[2000]
					This:LogInfo["Checkpoint 21"]
				}
			}
			while ${Iter:Next(exists)}
		return TRUE
	}

	member:string CorporationFolder()
	{
		variable string folder
		switch ${Config.MunitionStorageFolder}
		{
			case Folder1
				folder:Set[Corporation Folder 1]
				break
			case Folder2
				folder:Set[Corporation Folder 2]
				break
			case Folder3
				folder:Set[Corporation Folder 3]
				break
			case Folder4
				folder:Set[Corporation Folder 4]
				break
			case Folder5
				folder:Set[Corporation Folder 5]
				break
			case Folder6
				folder:Set[Corporation Folder 6]
				break
			case Folder7
				folder:Set[Corporation Folder 7]
				break
		}

		return ${folder}
	}

	member:bool DropOffLoot()
	{
		if !${Me.InStation}
		{
			return TRUE
		}

		if !${EVEWindow[Inventory](exists)}
		{
			EVE:Execute[OpenInventory]
			return FALSE
		}
		Client:Wait[2000]
		This:LogInfo["Checkpoint 22"]
		variable index:item items
		variable iterator itemIterator
		variable int64 dropOffContainerID = 0;
		; Find the container item id first
		if ${Config.DropOffToContainer} && ${Config.DropOffContainerName.NotNULLOrEmpty}
		{
			if ${Config.MunitionStorage.Equal[Corporation Hangar]}
			{
				if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)} && !${Config.HomeStructureIsCitadel}
				{
					EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
					Client:Wait[2000]
					This:LogInfo["Checkpoint 23"]
					return FALSE
				}

				if !${EVEWindow[Inventory].ChildWindow[StructureCorpHangar](exists)} && ${Config.HomeStructureIsCitadel}
				{
					EVEWindow[Inventory].ChildWindow[StructureCorpHangar]:MakeActive
					Client:Wait[2000]
					This:LogInfo["Checkpoint 23"]
					return FALSE
				}

				if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)} && !${Config.HomeStructureIsCitadel}
				{

					EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
					Client:Wait[2000]
					This:LogInfo["Checkpoint 24"]
					return FALSE
				}

				if !${EVEWindow[Inventory].ChildWindow["StructureCorpHangar", ${Config.MunitionStorageFolder}](exists)} && ${Config.HomeStructureIsCitadel}
				{

					EVEWindow[Inventory].ChildWindow["StructureCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
					Client:Wait[2000]
					This:LogInfo["Checkpoint 24"]
					return FALSE
				}
				
				Client:Wait[2000]
				This:LogInfo["Checkpoint 25"]
				if !${Config.HomeStructureIsCitadel}
				{
					EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:GetItems[items]
				}
				
				if ${Config.HomeStructureIsCitadel}
				{
					EVEWindow[Inventory].ChildWindow["StructureCorpHangar", ${Config.MunitionStorageFolder}]:GetItems[items]
				}
				
			}
			elseif ${Config.MunitionStorage.Equal[Personal Hangar]}
			{
				if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)} && !${Config.HomeStructureIsCitadel}
				{
					EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
					Client:Wait[2000]
					This:LogInfo["Checkpoint 26"]
					return FALSE
				}
				if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StructureItemHangar](exists)} && ${Config.HomeStructureIsCitadel}
				{
					EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StructureItemHangar]:MakeActive
					Client:Wait[2000]
					This:LogInfo["Checkpoint 26"]
					return FALSE
				}
				if !${Config.HomeStructureIsCitadel}
				{
					EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[items]
				}
				
				if ${Config.HomeStructureIsCitadel}
				{
					EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StructureItemHangar]:GetItems[items]
				}	
				
			}

			items:GetIterator[itemIterator]
			if ${itemIterator:First(exists)}
			{
				do
				{
					if ${itemIterator.Value.Name.Equal[${Config.DropOffContainerName}]} && \
						${itemIterator.Value.Type.Equal["Station Container"]}
					{
						dropOffContainerID:Set[${itemIterator.Value.ID}]
						itemIterator.Value:Open

						if !${EVEWindow[Inventory].ChildWindow[${dropOffContainerID}](exists)} || \
							!${EVEWindow[Inventory].ActiveChild.ItemID.Equal[${dropOffContainerID}]} || \
							!${EVEWindow[Inventory].ChildWindow[${dropOffContainerID}].Capacity(exists)} || \
							(${EVEWindow[Inventory].ChildWindow[${dropOffContainerID}].Capacity} < 0)
						{
							EVEWindow[Inventory].ChildWindow[${dropOffContainerID}]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 27"]
							return FALSE
						}
						break
					}
				}
				while ${itemIterator:Next(exists)}
			}
		}

		if ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold](exists)} && ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold].UsedCapacity} < 0
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold]:MakeActive
			Client:Wait[2000]
			This:LogInfo["Checkpoint 28"]
			return FALSE
		}
		Client:Wait[2000]
		This:LogInfo["Checkpoint 29"]
		EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipGeneralMiningHold]:GetItems[items]
		items:GetIterator[itemIterator]
		if ${itemIterator:First(exists)}
		{
			do
			{
				if !${itemIterator.Value.Name.Equal[${Config.WhatMiningCrystal}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.CommandBurstOne}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.CommandBurstTwo}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.CommandBurstThree}]}
				{
					if ${Config.DropOffToContainer} && ${Config.DropOffContainerName.NotNULLOrEmpty} && ${dropOffContainerID} > 0
					{
						itemIterator.Value:MoveTo[${dropOffContainerID}, CargoHold]
						; return FALSE
					}
					elseif ${Config.MunitionStorage.Equal[Corporation Hangar]} 
					{
						if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)} && !${Config.HomeStructureIsCitadel}
						{
							EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 30"]
							return FALSE
						}
						
						if !${EVEWindow[Inventory].ChildWindow[StructureCorpHangar](exists)} && ${Config.HomeStructureIsCitadel}
						{
							EVEWindow[Inventory].ChildWindow[StructureCorpHangar]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 30"]
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)} && !${Config.HomeStructureIsCitadel}
						{
							EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 31"]
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow["StructureCorpHangar", ${Config.MunitionStorageFolder}](exists)} && ${Config.HomeStructureIsCitadel}
						{
							EVEWindow[Inventory].ChildWindow["StructureCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 31"]
							return FALSE
						}

						itemIterator.Value:MoveTo[MyStationCorporateHangar, StationCorporateHangar, ${itemIterator.Value.Quantity}, ${This.CorporationFolder}]
						; return FALSE
					}
					elseif ${Config.MunitionStorage.Equal[Personal Hangar]}
					{
						if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)} && !${Config.HomeStructureIsCitadel}
						{
							EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 32"]
							return FALSE
						}
						if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StructureItemHangar](exists)} && ${Config.HomeStructureIsCitadel}
						{
							EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StructureItemHangar]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 32"]
							return FALSE
						}
						itemIterator.Value:MoveTo[MyStationHangar, Hangar]
						; return FALSE
					}
				}
			}
			while ${itemIterator:Next(exists)}
		}
		items:Clear
		itemsIterator:Clear
		if ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, CargoHold](exists)} && ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, CargoHold].UsedCapacity} < 0
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, CargoHold]:MakeActive
			Client:Wait[2000]
			This:LogInfo["Checkpoint 33"]
			return FALSE
		}
		EVEWindow[Inventory].ChildWindow[${Me.ShipID}, CargoHold]:GetItems[items]
		items:GetIterator[itemIterator]
		if ${itemIterator:First(exists)}
		{
			do
			{
				if !${itemIterator.Value.Name.Equal[${Config.WhatMiningCrystal}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.CommandBurstOne}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.CommandBurstTwo}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.CommandBurstThree}]}
				{
					if ${Config.DropOffToContainer} && ${Config.DropOffContainerName.NotNULLOrEmpty} && ${dropOffContainerID} > 0
					{
						itemIterator.Value:MoveTo[${dropOffContainerID}, CargoHold]
						; return FALSE
					}
					elseif ${Config.MunitionStorage.Equal[Corporation Hangar]}
					{
						if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
						{
							EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 34"]
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
						{
							EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 35"]
							return FALSE
						}

						itemIterator.Value:MoveTo[MyStationCorporateHangar, StationCorporateHangar, ${itemIterator.Value.Quantity}, ${This.CorporationFolder}]
						; return FALSE
					}
					elseif ${Config.MunitionStorage.Equal[Personal Hangar]}
					{
						if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
						{
							EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
							Client:Wait[2000]
							This:LogInfo["Checkpoint 36"]
							return FALSE
						}
						itemIterator.Value:MoveTo[MyStationHangar, Hangar]
						; return FALSE
					}
				}
			}
			while ${itemIterator:Next(exists)}
		}
		This:QueueState["StackHangars", 3000]
		This:QueueState["CheckForWork"]
		return TRUE
	}

	member:bool Traveling()
	{
		if ${Move.Traveling} || ${Me.ToEntity.Mode} == MOVE_WARPING
		{
			if ${Me.InSpace} && ${Me.ToEntity.Mode} == MOVE_WARPING
			{
				if ${Ship.ModuleList_Siege.ActiveCount}
				{
					Ship.ModuleList_Siege:DeactivateAll
				}

				if ${ammo.NotNULLOrEmpty}
				{
					Ship.ModuleList_Weapon:ConfigureAmmo[${ammo}, ${secondaryAmmo}, ${tertiaryAmmo}]
				}

				if ${Config.BatteryToBring.NotNULLOrEmpty}
				{
					Ship.ModuleList_Ancillary_Shield_Booster:ConfigureAmmo[${Config.BatteryToBring}]
				}

				Ship.ModuleList_Weapon:ReloadDefaultAmmo

				if ${Ship.ModuleList_Regen_Shield.InactiveCount} && ((${MyShip.ShieldPct.Int} < 100 && ${MyShip.CapacitorPct.Int} > ${AutoModule.Config.ActiveShieldCap}) || ${AutoModule.Config.AlwaysShieldBoost})
				{
					Ship.ModuleList_Regen_Shield:ActivateAll
				}
				if ${Ship.ModuleList_Regen_Shield.ActiveCount} && (${MyShip.ShieldPct.Int} == 100 || ${MyShip.CapacitorPct.Int} < ${AutoModule.Config.ActiveShieldCap}) && !${AutoModule.Config.AlwaysShieldBoost}
				{
					Ship.ModuleList_Regen_Shield:DeactivateAll
				}
				if ${Ship.ModuleList_Repair_Armor.InactiveCount} && ((${MyShip.ArmorPct.Int} < 100 && ${MyShip.CapacitorPct.Int} > ${AutoModule.Config.ActiveArmorCap}) || ${AutoModule.Config.AlwaysArmorRepair})
				{
					Ship.ModuleList_Repair_Armor:ActivateAll
				}
				if ${Ship.ModuleList_Repair_Armor.ActiveCount} && (${MyShip.ArmorPct.Int} == 100 || ${MyShip.CapacitorPct.Int} < ${AutoModule.Config.ActiveArmorCap}) && !${AutoModule.Config.AlwaysArmorRepair}
				{
					Ship.ModuleList_Repair_Armor:DeactivateAll
				}

			}

			if ${EVEWindow[ByCaption, Agent Conversation - ${EVE.Agent[${currentAgentIndex}].Name}](exists)}
			{
				EVEWindow[ByCaption, Agent Conversation - ${EVE.Agent[${currentAgentIndex}].Name}]:Close
				return FALSE
			}
			if ${EVEWindow[ByCaption, Mission journal](exists)}
			{
				EVEWindow[ByCaption, Mission journal]:Close
				return FALSE
			}

			return FALSE
		}

		return TRUE
	}

	member:int InventoryItemQuantity(string itemName, string inventoryID, string subFolderName = "")
	{
		variable index:item items
		variable iterator itemIterator

		if !${EVEWindow[Inventory].ChildWindow[${inventoryID}, ${subFolderName}](exists)} || ${EVEWindow[Inventory].ChildWindow[${inventoryID}, ${subFolderName}].Capacity} < 0
		{
			echo must open inventory window before calling this function
			echo ${Math.Calc[1 / 0]}
		}

		EVEWindow[Inventory].ChildWindow[${inventoryID}, ${subFolderName}]:GetItems[items]
		items:GetIterator[itemIterator]

		variable int itemQuantity = 0
		if ${itemIterator:First(exists)}
		{
			do
			{
				if ${itemIterator.Value.Name.Equal[${itemName}]}
				{
					itemQuantity:Inc[${itemIterator.Value.Quantity}]
				}
			}
			while ${itemIterator:Next(exists)}
		}

		return ${itemQuantity}
	}


	method DeepCopyIndex(string From, string To)
	{
		variable iterator i
		${From}:GetIterator[i]
		if ${i:First(exists)}
		{
			do
			{
				${To}:Insert[${i.Value}]
			}
			while ${i:Next(exists)}
		}
	}

	member:bool IsStructure(int64 targetID)
	{
		variable string targetClass
		targetClass:Set[${NPCData.NPCType[${Entity[${targetID}].GroupID}]}]
		if ${AllowDronesOnNpcClass.Contains[${targetClass}]}
		{
			return FALSE
		}

		return TRUE
	}


	member:bool HaltBot()
	{
		This:Stop
		return TRUE
	}

	method ManageThrusterOverload(int64 targetID)
	{
		if !${Entity[${targetID}](exists)}
		{
			; keep current status.
			return
		}

		if !${Config.OverloadThrust} || \
			${Ship.ModuleList_Siege.IsActiveOn[TARGET_ANY]} || \
			${Ship.RegisteredModule.Element[${Ship.ModuleList_Siege.ModuleID.Get[1]}].IsActive} || \
			(${Entity[${targetID}].Distance} <= 10000)
		{
			; turn off
			; This:LogDebug["turn off ${Ship.ModuleList_Siege.IsActiveOn[TARGET_ANY]} ${Ship.RegisteredModule.Element[${Ship.ModuleList_Siege.ModuleID.Get[1]}].IsActive} ${Entity[${targetID}].Name} ${Entity[${targetID}].Distance}"]
			Ship.ModuleList_AB_MWD:SetOverloadHPThreshold[100]
		}

		if ${Config.OverloadThrust} && \
			${Entity[${targetID}].Distance} > 10000 && \
			!${Ship.ModuleList_Siege.IsActiveOn[TARGET_ANY]} && \
			!${Ship.RegisteredModule.Element[${Ship.ModuleList_Siege.ModuleID.Get[1]}].IsActive}
		{
			; turn on
			; This:LogDebug["turn on ${Entity[${targetID}].Name} ${Entity[${targetID}].Distance}"]
			Ship.ModuleList_AB_MWD:SetOverloadHPThreshold[50]
		}
	}
}


objectdef obj_MiningUI inherits obj_State
{
	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
	}

	method Start()
	{
		if ${This.IsIdle}
		{
			This:QueueState["Update", 5]
		}
	}

	method Stop()
	{
		This:Clear
	}

}