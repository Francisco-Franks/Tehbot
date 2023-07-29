objectdef obj_Configuration_WatchDog inherits obj_Configuration_Base
{
	method Initialize()
	{
		This[parent]:Initialize["WatchDog"]
	}

	method Set_Default_Values()
	{
		ConfigManager.ConfigRoot:AddSet[${This.SetName}]
	}

}

objectdef obj_WatchDog inherits obj_StateQueue
{
	;;; DB related variables ;;;
	variable sqlitequery WatchDogDBQuery
	variable sqlitequery StatsDBQuery

	;;; Stats related variables ;;;
	; Total Enemies Vanquished Today
	variable int64 TEVT
	; Total Bounties for Today
	variable int64 TBFT
	; Average Bounty Per NPC Today
	variable float ABPNPCT
	; Average Bounty Per Hour Today
	variable float ABPHT
	; Total Missions Completed Today
	variable int64 TMCT
	; Current Mission Runtime
	variable int64 CMR
	; Average Mission Runtime Today
	variable float AMRT
	; Current Mission Expected LP
	variable int64 CMELP
	; Average LP Per Mission Today
	variable int64 ALPPMT
	; Total Enemies Vanquished From Beginning
	variable int64 TEVFB
	; Total Faction Spawns Vanquished From Beginning
	variable int64 TFSVFB
	; Total Bounties From Beginning
	variable int64 TBFB
	; Total Missions Completed From Beginning
	variable int64 TMCFB
	; Total Time Spent Missioning
	variable int64 TTSM
	; Average Time Per Mission From Beginning
	variable float ATPMFB
	; Average Bounty Per Mission From Beginning
	variable float ABPMFB
	

	;;; WatchDog specific variables ;;;
	; This collection will store average mission runtimes by mission name. Key is mission name, value is seconds.
	variable collection:int64 CurrentMissionNameAverageRuntime
	; This int64 will be a timestamp used to measure how long we have been sitting still doing nothing.IN SPAAAAACE.
	variable int64 SittingInSpaceBeginsTimestamp
	; This int64 will be the same but in station.
	variable int64 SittingInStationBeginsTimestamp
	; This int64 will be for the starting time when we started shooting our current target.
	variable int64 WhenDidWeStartShootingThisTarget
	; This collection will store the Entity ID and the total health value of that entity, for the current TargetManager target. Key will be the EntityID, value will be HP %s added together and integerized.
	variable collection:int TargetManagerTargetHealthCache
	; This will be the same as above but for DroneControl
	variable collection:int DroneControlTargetHealthCache
	
	; This timestamp will be used to control removing target exceptions periodically.
	variable int64 LastTargetException
	; This timestamp will be used to track for how we haven't made progress on a target.
	variable int64 TargetManagerNoProgressTimestamp
	; The same but for DroneControl
	variable int64 DroneControlNoProgressTimestamp
	
	
	;;; Utility crap
	; For tracking how many salvos of missiles we have launched at a specific entity. Key is EntityID, value is Salvos.
	variable collection:int64 SalvosLaunchedCollection
	; What was the count of the ammo in our weapons last time we looked?
	variable int64 LastAmmoQuantity
	; For tracking targets we've put exceptions on, and when we did so. Key is the EntityID, Value is the timestamp for when we did it.
	variable collection:int64 TargetExceptionCollection
	; If I want this to be useful more than once, I will need another collection. This one correlates EntityIDs with what targetlist they were excluded from
	; Key is the Entity ID, Value is the TargetList
	variable collection:string TargetExceptionSourceCollection
	; I like to use queues when we need to remove things mid iteration.
	variable queue:int64 TargetExceptionClearQueue
	
	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
		This.PulseFrequency:Set[1000]
		DynamicAddMiniMode("WatchDog", "WatchDog")

		This.LogLevelBar:Set[${CommonConfig.LogLevelBar}]
	}

	method Start()
	{
		This:QueueState["WatchDog", 1000]
	}

	method Stop()
	{
		This:Clear
	}
	; Alright so this will be our main loop. This minimode's existence is to gather statistics from our DBs, and update variables
	; These variables will be displayed in some form or another in the UI for this minimode, it will be designed to opened and left opened
	; So that you can see your stats at a glance. Reading the DBs shouldnt be blocking so there should be no issues there. This Minimode
	; Will NOT do any writes to the DB of any kind.
	; Furthermore, this mode will, when I stop being lazy, handle getting a bot "unstuck" if it detects a lack of progress over some arbitrary amount of time.
	; For reference we have Mission.CharacterSQLDB , Mission.SharedSQLDB as our DBs we will be looking at.
	; The tables we care about in Mission.CharacterSQLDB will be MissionLogCombat, MissionLogCourier, and NPCInfo
	; The tables we care about in Mission.SharedSQLDB will be WatchDogMonitoring, MissioneerStats, and SalvageBMTable.
	; From MissionLogCombat and MissionLogCourier we will be able to identify what kinds of missions we get and how often. We will also be able to identify average mission duration.
	; From NPCInfo we can see what kinds of enemies we face, how many enemies are in each mission, etc.
	; From WatchDogMonitoring we will only really just be doing a baseline check to see if a client has stopped updating.
	; From MissioneerStats we will be able to see the average bounties per run, per day, and overall. Same for LP rewards
	; From SalvageBMTable we can determine if the salvagers have disconnected/died/gotten stuck. Also if we are outpacing the salvagers so we can do some adjusting.
	; For the moment this minimode is going to be mostly about displaying information. Later on I will work on the WatchDog functionality.
	member:bool WatchDog()
	{
		; Now uh, as optimistic as I want to be here, I suspect attempting to get ALL of the database reliant members resolved in one pulse will be an insanely bad idea. Going to need to
		; get slightly fancy to try and mitigate the dangers there. 

		
		;;;;;;;;;;;;;;;;;;; THESE DONT ACTUALLY WORK, also with new targetmanager in the works they are pointless. I'll leave them here for hubris and posterity reasons.
		; WatchDog stuff
		;if !${This.AreWeMakingProgressDC}
		;{
			;if ${Math.Calc[${DroneControlNoProgressTimestamp} + 30]} < ${Time.Timestamp}
			;{
			;	echo DEBUG - WATCHDOG RESET DRONE CONTROL
			;	This:ResetDroneControl
			;}
		;}
		
		;if !${This.AreWeMakingProgressTM}
		;{
			;if ${Math.Calc[${TargetManagerNoProgressTimestamp} + 30]} < ${Time.Timestamp}
			;{
			;	echo DEBUG - WATCHDOG RESET TARGET MANAGER
			;	This:ResetTargetManager
			;}		
		;}
		
		;if ${Math.Calc[${LastTargetException} + 30]} < ${Time.Timestamp}
		;{
		;	TargetManager.ActiveNPCs:ClearExcludeTargetID
			;DroneControl.ActiveNPCs:ClearExcludeTargetID
		;	LastTargetException:Set[99999999999999999999999999999]
		;	echo DEBUG - WATCHDOG CLEAR TARGET EXCEPTIONS
		;}
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;;; Going to do some Utility stuff in here for our TargetManagers when it comes to missile usage.
		if ${Client.InSpace}
		{
			if ${Ship.ModuleList_MissileLauncher.Count} > 0
			{
				if ${This.SalvosLaunchedAtCurrentTarget} > ${Math.Calc[${CurrentOffenseTargetExpectedShots} + 1]}
				{
					; We've fired more missiles at this target than it SHOULD take to destroy. Lets deactivate the weapons, put the current offense target in a targeting exclusion thing, and zero out the current offense target.
					; ADDENDUM - We should set its salvo tracking to 0 because next time we get back to the target we need to start from 0.
					Ship.ModuleList_MissileLauncher:DeactivateAll
					MissionTargetManager.PrimaryWeap.TargetList:Remove[${CurrentOffenseTarget}]
					;This:InstantiateTargetException[${CurrentOffenseTarget}, "MissionTargetManager.PrimaryWeap",10000]
					MissionTargetManager.PrimaryWeap.TargetList:Remove[${CurrentOffenseTarget}]
					SalvosLaunchedCollection:Set[${CurrentOffenseTarget},0]
					CurrentOffenseTarget:Set[0]
				}
			}
			; This is where we will check if we have target exceptions, and if we do have they expired, and if they have then we remove them.
			if ${TargetExceptionCollection.Used} > 0
			{
				if ${TargetExceptionCollection.FirstKey(exists)}
				{
					do
					{
						; Has the time for the exception Expired?
						if ${TargetExceptionCollection.CurrentValue} > ${LavishScript.RunningTime}
						{
							; Clear the exception from the appropriate list.
							${TargetExceptionSourceCollection.Element[${TargetExceptionCollection.CurrentKey}]}:ClearSpecificExclusion[${TargetExceptionCollection.CurrentKey}]
							This:LogInfo["Removing ${Entity[${TargetExceptionCollection.CurrentKey}].Name} from ${TargetExceptionSourceCollection.Element[${TargetExceptionCollection.CurrentKey}]} Exclusion"]
							; Queue it up for collection removal after we're done.
							TargetExceptionClearQueue:Queue[${TargetExceptionCollection.CurrentKey}]
						}
					
					}
					while ${TargetExceptionCollection.NextKey(exists)}
				}
				if ${TargetExceptionClearQueue.Peek} > 0
				{
					do
					{
						if ${TargetExceptionCollection.Element[${TargetExceptionClearQueue.Peek}](exists)}
							TargetExceptionCollection:Erase[${TargetExceptionClearQueue.Peek}]
						if ${TargetExceptionSourceCollection.Element[${TargetExceptionClearQueue.Peek}](exists)}
							TargetExceptionSourceCollection:Erase[${TargetExceptionClearQueue.Peek}]		
						
						TargetExceptionClearQueue:Dequeue
					}
					while ${TargetExceptionClearQueue.Peek} > 0
				}
			}
		}
		; I need the inventory window kept open at all goddamn times.
		; Something keeps closing it and I have no idea what, and its pissing me off.
		; Open the inventory, stop closing the inventory, never close your inventory.
		if (!${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo].Capacity} < 0) && ${Client.InSpace}
		{
			; Please keep your inventory open at all times, please. We have to use a freakin keyboard hotkey for this because I cant figure out an isxeve command to do it. The default is ALT + C
			echo OPENING INVENTORY
			EVE:Execute[OpenInventory]
		}
		return FALSE
	}

	;;; This member will be for our salvo management thing for targetmanager
	;;; Basically we are going to keep track of how many missile salvos we have launched at a target, and use information from CombatComputer to determine
	;;; If we have launched enough missiles to destroy a target, and if we have we will deactivate the weapons and zero out the CurrentOffenseTarget.
	member:int64 SalvosLaunchedAtCurrentTarget()
	{
		variable int64 AmmoQuantityDelta
		; Going to need to store our ammo quantity, won't have a number to compare to for the first shot dontchaknow.
		if ${Ship.ModuleList_MissileLauncher.InactiveCount} > 0
		{
			LastAmmoQuantity:Set[${Ship.ModuleList_MissileLauncher.ChargeQuantity}]
			return 0			
		
		}
		if ${CurrentOffenseTarget} == 0 || !${Entity[${CurrentOffenseTarget}](exists)}
			return 0
		else
		{
			; Currently reloading, make no changes to the collection for now
			if ${Ship.ModuleList_MissileLauncher.ChargeQuantity} == 0 || ${Ship.ModuleList_MissileLauncher.IsReloading}
				return 0
			else 
			{
				; Conventionally speaking, ammo doesn't typically go up when it is being fired. Set Last Ammo Quantity to whatever it is currently.
				if ${Ship.ModuleList_MissileLauncher.ChargeQuantity} > ${LastAmmoQuantity}
				{
					LastAmmoQuantity:Set[${Ship.ModuleList_MissileLauncher.ChargeQuantity}]
					return 0
				}
				else
				{
					; Get the difference then update the persistent stored quantity.
					AmmoQuantityDelta:Set[${Math.Calc[${LastAmmoQuantity}-${Ship.ModuleList_MissileLauncher.ChargeQuantity}]}]
					LastAmmoQuantity:Set[${Ship.ModuleList_MissileLauncher.ChargeQuantity}]
				}
				; Check in the collection to see if this entity is already in it.
				if !${SalvosLaunchedCollection.Element[${CurrentOffenseTarget}](exists)}
				{
					SalvosLaunchedCollection:Set[${CurrentOffenseTarget},${AmmoQuantityDelta}]
					return ${SalvosLaunchedCollection.Element[${CurrentOffenseTarget}]}
				}
				else
				{
					SalvosLaunchedCollection:Set[${CurrentOffenseTarget},${Math.Calc[${SalvosLaunchedCollection.Element[${CurrentOffenseTarget}]}+${AmmoQuantityDelta}]}]
					return ${SalvosLaunchedCollection.Element[${CurrentOffenseTarget}]}
				}
			}
		}
	}

	;;; This method will be used for adding things to our TargetExceptionCollection so that WatchDog can maintain it. Making this a method in case I want to use this elsewhere.
	method InstantiateTargetException(int64 EntityID, string FromTargetList, int64 HowManyMilliseconds)
	{
		${FromTargetList}:AddTargetExceptionByID[${EntityID}]
		
		TargetExceptionCollection:Set[${EntityID},${Math.Calc[${LavishScript.RunningTime} + ${HowManyMilliseconds}]}]
		TargetExceptionSourceCollection:Set[${EntityID},${FromTargetList}]
	}

	;;;; These members will all be for easier stats returns for our UI;;;;
	; This will return an int64, the int64 will be how many enemies this particular character has destroyed since the previous downtime.
	member:int64 TotalEnemiesVanquishedToday()
	{
	
	}
	
	; This will return an int64, the int64 will be the total bounties we have earned since the previous downtime.
	member:int64 TotalBountiesForToday()
	{
	
	}
	
	; This will return a float, the float will be the average bounties the character has earned since the previous downtime.
	member:float AverageBountyPerNPCToday()
	{
	
	}
	
	; This will return a float, the float will be the average bounties per hour since the previous downtime.
	member:float AverageBountyPerHourToday()
	{
	
	}
	
	; This will return an int64, the int64 will be the number of missions this character has completed since the previous downtime
	member:int64 TotalMissionsCompletedToday()
	{
	
	}
	
	; This will return an int64, the int64 will be the number of seconds this current mission has taken so far.
	member:int64 CurrentMissionRuntime()
	{
	
	}
	
	; This will return a float, the float will be the average number of seconds per mission completion since the previous downtime.
	member:float AverageMissionRuntimeToday()
	{
	
	}
	
	; This will return an int64, the int64 will be the amount of LP the current mission is expected to earn.
	member:int64 CurrentMissionExpectedLP()
	{
	
	}
	
	; This will return an int64, the int64 will be the (rounded) average LP per mission since the previous downtime.
	member:int64 AverageLPPerMissionToday()
	{
	
	}
	
	; This will return an int64, the int64 will be the total number of NPCs this character has destroyed since the beginning.
	member:int64 TotalEnemiesVanquishedFromBeginning()
	{
	
	}
	
	; This will return an int64, the int64 will be the total number of Faction Spawns this character has destroyed since the beginning.
	member:int64 TotalFactionSpawnsVanquishedFromBeginning()
	{
	
	}
	
	; This will return an int64, the int64 will be the total amount of ISK this character has earned from bounties since the beginning of the DB.
	member:int64 TotalBountiesFromBeginning()
	{
	
	}
	
	; This will return an int64, the int64 will be the total number of (combat) missions run since the beginning of the DB.
	member:int64 TotalMissionsCompletedFromBeginning()
	{
	
	}
	
	; This will return an int64, the int64 will be the total time this character has spent in missions since the beginning of the DB.
	member:int64 TotalTimeSpentMissioning()
	{
	
	}
	
	; This will return a float, the float will be the average time per mission since the begimnning of the DB.
	member:float AverageTimePerMissionFromBeginning()
	{
	
	}
	
	; This will return a float, the float will be the average bounties this character has earned per mission since the beginning of the DB.
	member:float AverageBountyPerMissionFromBeginning()
	{
	
	}
	
	
	;;;;; Below this point will be members related to our WatchDog functions ;;;;;
	
	; This will return an int64, this int64 will be the (rounded) average for how many seconds a run takes for the CURRENT SPECIFIC MISSION TYPE. How many seconds does Worlds Collide take for this character, on average.
	; This will be used to set a collection storage variable once per session, per mission name.
	member:int64 AverageRuntimeForThisMissionType()
	{
		if !${CurrentMissionNameAverageRuntime.Element[${Mission.CurrentAgentMissionName}](exists)}
		{
			WatchDogDBQuery:Set[${Mission.SharedSQLDB.ExecQuery["SELECT * FROM MissioneerStats WHERE CharID=${Me.CharID} AND MissionName='${Mission.CurrentAgentMissionName}' AND RunDuration>0;"]}]
			if ${WatchDogDBQuery.NumRows} > 0
			{
				echo AverageRuntimeForThisMission ${WatchDogDBQuery.GetFieldValue["avg(RunDuration)",float]}
				CurrentMissionNameAverageRuntime:Set[${Mission.CurrentAgentMissionName},${WatchDogDBQuery.GetFieldValue["avg(RunDuration)",float].Int}]
				WatchDogDBQuery:Finalize
				return ${CurrentMissionNameAverageRuntime.Element[${Mission.CurrentAgentMissionName}]}
			}
		}
		else
		{
			return ${CurrentMissionNameAverageRuntime.Element[${Mission.CurrentAgentMissionName}]}
		}
		return 
	}
	
	; This will return an int64, this int64 will be my attempt to measure how long we have been sitting absofuckinglutely still doing god damn nothing.
	; Basically, we will register a timestamp when we first are A) our velocity is 0 or very near 0 AND B) we have no current target, no active weapons
	; If A or B are no longer true then we update the timestamp to the current time.
	member:int64 HowLongHaveWeBeenSittingHere()
	{
		if ${Me.InStation}
		{
			SittingInSpaceBeginsTimestamp:Set[0]
			return 0
		}
		if ${MyShip.ToEntity.Velocity} >= 1 || ${Ship.ModuleList_Weapon.ActiveCount} >= 1
		{
			SittingInSpaceBeginsTimestamp:Set[0]
			return 0
		}
		elseif ${SittingInSpaceBeginsTimestamp} == 0
		{
			SittingInSpaceBeginsTimestamp:Set[${Time.Timestamp}]
			return 0
		}
		else
		{
			return ${Math.Calc[${Time.Timestamp} - ${SittingInSpaceBeginsTimestamp}]}
		}		
	}
	
	; This will return an int64, this int64 will attempt to measure how long we have been sitting in a station, doing nothing.
	; If we are in a station, and the timestamp storage variable is 0, we set the current timestamp. Then we use that to compare against
	; the current timestamp to get how many seconds. When we leave station then the timestamp storage variable is zeroed and we leave it as such.
	member:int64 HowLongHaveWeBeenInThisStation()
	{
		if ${Client.InSpace}
		{
			SittingInStationBeginsTimestamp:Set[0]
			return 0
		}
		elseif ${SittingInStationBeginsTimestamp} == 0 
		{
			SittingInStationBeginsTimestamp:Set[${Time.Timestamp}]
			return 0
		}
		else
		{
			return ${Math.Calc[${Time.Timestamp} - ${SittingInStationBeginsTimestamp}]}
		}
	}
	
	; This will return an int64, this int64 will be my attempt to measure how long we have been shooting the same target.
	; Basically, we will register a timestamp when CurrentOffenseTarget and DroneControl's target are set.
	; If the targets change then a new timestamp is registered.
	; Is this really needed, we want to know if we are making any progress, the next 2 bools should do a better job.
	;member:int64 HowLongHaveWeBeenShootingThisThing()
	;{
	;	if !${Client.InSpace}
	;		return 0
	;	
	;}
	
	; This will return a Bool, this bool will attempt to quantify if we are making "Progress" with the current target for TARGETMANAGER.
	; This will be sort of similar to the drone health cache thing. We will add up the 3 healthbars percentages (as integers) of the CURRENT TARGET.
	; We will record that in a variable and compare the change over time. If we are making "Progress" the bool will return TRUE. If the enemy isn't dying it will return FALSE.
	member:bool AreWeMakingProgressTM()
	{
		; If it doesn't exist, that is progress.
		if !${Entity[${CurrentOffenseTarget}](exists)}
		{
			echo DEBUG - WATCHDOG - AWMPTM1
			TargetManagerNoProgressTimestamp:Set[0]
			return TRUE
		}
		elseif !${TargetManagerTargetHealthCache.Element[${CurrentOffenseTarget}](exists)}
		{
			TargetManagerTargetHealthCache:Set[${CurrentOffenseTarget},${Math.Calc[${Entity[${CurrentOffenseTarget}].ShieldPct.Int} + ${Entity[${CurrentOffenseTarget}].ArmorPct.Int} + ${Entity[${CurrentOffenseTarget}].StructurePct.Int}]}]
			echo DEBUG - WATCHDOG - TM CACHE ${Math.Calc[${Entity[${CurrentOffenseTarget}].ShieldPct.Int} + ${Entity[${CurrentOffenseTarget}].ArmorPct.Int} + ${Entity[${CurrentOffenseTarget}].StructurePct.Int}]}
		}
		elseif ${Math.Calc[${Entity[${CurrentOffenseTarget}].ShieldPct.Int} + ${Entity[${CurrentOffenseTarget}].ArmorPct.Int} + ${Entity[${CurrentOffenseTarget}].StructurePct.Int}]} >= ${TargetManagerTargetHealthCache.Element[${CurrentOffenseTarget}]} && ${TargetManagerNoProgressTimestamp} == 0
		{
			echo DEBUG - WATCHDOG - PROGRESS NOT BEING MADE ON TARGETMANAGER TARGET
			TargetManagerTargetHealthCache:Set[${CurrentOffenseTarget},${Math.Calc[${Entity[${CurrentOffenseTarget}].ShieldPct.Int} + ${Entity[${CurrentOffenseTarget}].ArmorPct.Int} + ${Entity[${CurrentOffenseTarget}].StructurePct.Int}]}]
			echo DEBUG - WATCHDOG - TM CACHE2 ${Math.Calc[${Entity[${CurrentOffenseTarget}].ShieldPct.Int} + ${Entity[${CurrentOffenseTarget}].ArmorPct.Int} + ${Entity[${CurrentOffenseTarget}].StructurePct.Int}]}			
			TargetManagerNoProgressTimestamp:Set[${Time.Timestamp}]
			return FALSE
		}
		elseif ${Math.Calc[${Entity[${CurrentOffenseTarget}].ShieldPct.Int} + ${Entity[${CurrentOffenseTarget}].ArmorPct.Int} + ${Entity[${CurrentOffenseTarget}].StructurePct.Int}]} < ${TargetManagerTargetHealthCache.Element[${CurrentOffenseTarget}]}
		{
			TargetManagerNoProgressTimestamp:Set[0]
			return TRUE
		}
		return TRUE
	}
	
	; This will return a Bool, this bool will be the same as above but for DRONE CONTROL instead. Are our drones making progress? TRUE or FALSE.
	member:bool AreWeMakingProgressDC()
	{
		; If it doesn't exist, that is progress.
		if !${Entity[${DroneControl.CurrentTarget}](exists)}
		{
			DroneControlNoProgressTimestamp:Set[0]
			echo DEBUG - WATCHDOG - AWMPDC1
			return TRUE
		}
		elseif !${DroneControlTargetHealthCache.Element[${DroneControl.CurrentTarget}](exists)}
		{
			DroneControlTargetHealthCache:Set[${DroneControl.CurrentTarget},${Math.Calc[${Entity[${DroneControl.CurrentTarget}].ShieldPct.Int} + ${Entity[${DroneControl.CurrentTarget}].ArmorPct.Int} + ${Entity[${DroneControl.CurrentTarget}].StructurePct.Int}]}]
			echo DEBUG - WATCHDOG - DC CACHE1 ${Math.Calc[${Entity[${DroneControl.CurrentTarget}].ShieldPct.Int} + ${Entity[${DroneControl.CurrentTarget}].ArmorPct.Int} + ${Entity[${DroneControl.CurrentTarget}].StructurePct.Int}]}	
		}
		elseif ${Math.Calc[${Entity[${DroneControl.CurrentTarget}].ShieldPct.Int} + ${Entity[${DroneControl.CurrentTarget}].ArmorPct.Int} + ${Entity[${DroneControl.CurrentTarget}].StructurePct.Int}]} >= ${DroneControlTargetHealthCache.Element[${DroneControl.CurrentTarget}]} && ${DroneControlNoProgressTimestamp} == 0
		{
			echo DEBUG - WATCHDOG - PROGRESS NOT BEING MADE ON DRONECONTROL TARGET
			DroneControlTargetHealthCache:Set[${DroneControl.CurrentTarget},${Math.Calc[${Entity[${DroneControl.CurrentTarget}].ShieldPct.Int} + ${Entity[${DroneControl.CurrentTarget}].ArmorPct.Int} + ${Entity[${DroneControl.CurrentTarget}].StructurePct.Int}]}]
			echo DEBUG - WATCHDOG - DC CACHE2 ${Math.Calc[${Entity[${DroneControl.CurrentTarget}].ShieldPct.Int} + ${Entity[${DroneControl.CurrentTarget}].ArmorPct.Int} + ${Entity[${DroneControl.CurrentTarget}].StructurePct.Int}]}				
			DroneControlNoProgressTimestamp:Set[${Time.Timestamp}]
			return FALSE
		}
		elseif ${Math.Calc[${Entity[${DroneControl.CurrentTarget}].ShieldPct.Int} + ${Entity[${DroneControl.CurrentTarget}].ArmorPct.Int} + ${Entity[${DroneControl.CurrentTarget}].StructurePct.Int}]} < ${DroneControlTargetHealthCache.Element[${DroneControl.CurrentTarget}]}
		{
			DroneControlNoProgressTimestamp:Set[0]
			return TRUE
		}
		echo DEBUG - WATCHDOG - AWMPDC2
		return TRUE
	}

	;;;;; Below this point will be methods related to our WatchDog functions ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; This method will be used to make DroneControl's current target forbidden, it will be undone later. 
	; This will be triggered by information from AreWeMakingProgressDC
	method ResetDroneControl()
	{
		DroneControl.ActiveNPCs:AddTargetExceptionByID["${DroneControl.CurrentTarget}"]
		LastTargetException:Set[${Time.Timestamp}]
		echo DEBUG - WATCHDOG - RESETDRONECONTROL
	}
	; This method will be similar but for TargetManager's targets.
	method ResetTargetManager()
	{
		TargetManager.ActiveNPCs:AddTargetExceptionByID["${CurrentOffenseTarget}"]
		LastTargetException:Set[${Time.Timestamp}]	
		echo DEBUG - WATCHDOG - RESETTARGETMANAGER
	}

}



