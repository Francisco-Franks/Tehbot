objectdef obj_CombatComputer inherits obj_StateQueue
{
	; This will be the DB where our character specific ship info lives.
	variable sqlitedb CombatData
	; This will be our query 
	variable sqlitequery GetCurrentData
	; Need another query for our Ship2 DB
	variable sqlitequery GetShipInfo
	; Another query, for Cache generation
	variable sqlitequery GetTypeCache
	; Index for CurrentData Transactions
	variable index:string CurrentDataTransactionIndex
	; Index for AmmoTable Transactions
	variable index:string AmmoTableTransactionIndex
	; Index for Cache Generation Transactions
	variable index:string CacheTransactionIndex
	
	; This will be a collection containing the available Ammo Type IDs, Key will be the Ammo Name, Value will be Type ID of the ammo
	variable collection:int64 AmmoCollection
	; This int will describe the minimum amount of ammo to be considered for the Ammo stuff.
	variable int MinAmmoAmount
	; This float is the time it takes to reload your weapon.
	variable float64 ChangeTime
	
	variable queue:int64 ActiveNPCQueue
	variable queue:int64 AmmoTableQueue
	
	variable queue:int64 CleanupQueue
	
	; To keep track of what entities we have batch processed. An index of int64.
	variable index:int64 EntriesProcessedIndex
	;;;
	;;;;;


	;;; NOT IMPLEMENTED YET, BUT SOON
	; This int will not be configurable by the user, but just here to make my life simpler.
	; We use this to decide how many rows to update at a time, doing all of them simultaneously is a real performance killer dontchaknow.
	; We will start with 10 entities at a time.
	;;; Addendum, now 6. Also soon to be irrelevant if the CCTH crap pans out.
	variable int UpdateBatchSize = 15
	
	method Initialize()
	{
		Turbo 1000
		This[parent]:Initialize
		This.PulseFrequency:Set[2000]
		;This.NonGameTiedPulse:Set[TRUE]
		;CombatData:Set[${SQLite.OpenDB["CombatData",":memory:"]}]
		;;; Going to try making this DB reside in memory instead. We are going to be writing and reading to this fucker a gazillion times a second probably. Also the information is meant to be destroyed at the end
		;;; not going to be pulling any stats from this specific DB.
		;;; Addendum, at first I need to see the results of this table, lets see how poorly this goes.
		CombatData:Set[${SQLite.OpenDB["${Me.Name}CombatData","${Script.CurrentDirectory}/Data/${Me.Name}CombatData.sqlite3"]}]
		CombatData:ExecDML["PRAGMA journal_mode=WAL;"]
		CombatData:ExecDML["PRAGMA main.mmap_size=64000000"]
		CombatData:ExecDML["PRAGMA main.cache_size=-64000;"]
		CombatData:ExecDML["PRAGMA synchronous = normal;"]
		CombatData:ExecDML["PRAGMA temp_store = memory;"]	
		
		if !${CombatData.TableExists["CurrentData"]}
		{
			echo DEBUG - CombatComputer - Creating CurrentData Table
			CombatData:ExecDML["create table CurrentData (EntityID INTEGER PRIMARY KEY, NPCName TEXT, NPCTypeID INTEGER, CurDist REAL, FtrDist REAL, CurVel REAL, MaxVel REAL, CruiseVel REAL, NeutRng REAL, NeutStr REAL, EWARType TEXT, EWARStr REAL, EWARRng REAL, WebRng REAL, WrpDisRng REAL, WrpScrRng REAL, EffNPCDPS REAL, ThreatLevel INTEGER, LastUpdate INTEGER, UpdateType TEXT);"]
		}
		; This table will relate our ammo effectiveness against each NPC. 
		if !${CombatData.TableExists["AmmoTable"]}
		{
			echo DEBUG - CombatComputer - Creating AmmoTable
			CombatData:ExecDML["create table AmmoTable (EntityID INTEGER NOT NULL, AmmoTypeID INTEGER NOT NULL, AmmoName TEXT, ExpectedShotDmg REAL, ShotsToKill REAL, TimeToKill REAL, OurDamageEff REAL, ChangeTime REAL, LastUpdate INTEGER, PRIMARY KEY(EntityID, AmmoTypeID));"]
		}
		; This table will store cached information about NPC types that generally remains static so that we can soften the blow on some of this horseshit.
		if !${CombatData.TableExists["TypeCache"]}
		{
			echo DEBUG - CombatComputer - Creating NPCTypeCache Table
			CombatData:ExecDML["create table TypeCache (NPCTypeID INTEGER PRIMARY KEY, NPCName TEXT, NeutRng REAL, NeutStr REAL, EWARType TEXT, EWARStr REAL, EWARRng REAL, WebRng REAL, WrpDisRng REAL, WrpScrRng REAL, LastUpdate INTEGER);"]
		}
		This:QueueState["CombatComputerHub", 3000]
	}
 
	method Shutdown()
	{
		CombatData:ExecDML["Vacuum;"]	
		CombatData:Close
	}
	
	;;; This object (CombatComputer) will exist to crunch some math for us. Numbers derived from obj_NPCData and obj_Ship2 as well as actual real time information will be used to
	;;; help the new TargetManager make better combat decisions.
	;;; Basically we will look at the NPCs on grid, do our lookups in NPCData and Ship2, and from that we can quickly formulate a plan after we math out the following:
	;;; Shots to kill, ability to kill at this moment, ability to kill in the future (in the case of small targets that move too close), ability of the enemy to debilitate us.
	;;; NPCs are fairly static and predictable things, excepting some abyssal enemies and a few of the more wily new NPCs.
	;;; Positioning makes that kinda annoying though. ArchiveData idea is shelved for now.
	;;; We will have a table for Current Enemy Data, this will be about the enemies currently on grid with us.
	;;; NPC Entity ID, NPC Name, NPC TypeID, Current Distance, Future Distance (this will be where the NPC wants to orbit at), Current Velocity, Maximum Velocity (MWDing/ABing towards its desired orbit), Cruise Velocity (how fast it moves when it gets there),
	;;; Energy Neut Range (if applicable), Energy Neut Strength (if applicable)
	;;; EWAR Type (if applicable), EWAR Strength (if relevant), EWAR Range (if applicable), Stasis Web Range (if it does), Warp Disruptor Range (same), Warp Scrambler Range (same), Effective Enemy DPS Output,some kind of number estimating the enemy's overall Threat.
	;;; The following will be done once per ammo available ammo type. This will reside in a second table.
	;;; Entity ID, Ammo Type ID, Expected Shot Damage (effective, after resists), Predicted Shots to Kill, Predicted Time to Kill, Estimated % Of our Damage that will Land, Time to change ammo.
	;;; 
	;;; This info is going to be a tall order, but I think I can manage.

	; Going to convert this object to use the state queue, so we can go through our processing queue in discreet portions.
	member:bool CombatComputerHub()
	{
		if !${Client.InSpace} || ${MyShip.ToEntity.Mode} == MOVE_WARPING
			return FALSE
		if ${ActiveNPCQueue.Peek} < 1
			return FALSE

		; Lets clean up our tables
		This:CleanupTables
		; The argument is how many entities we want to process at a time.
		This:UpsertCurrentData[${UpdateBatchSize}]

		return FALSE
		
	}
	; This method will prefill the table with info so we can update in discrete chunks and keep track of when we last touched a given row.
	; This one will just pass along the BatchCount argument. This prefill shouldnt include anything too resource heavy.
	method UpsertCurrentData(int BatchCount)
	{

		variable int64 ProcessedCount

		if ${ActiveNPCQueue.Peek} > 0
		{
			do
			{
				if !${Entity[${ActiveNPCQueue.Peek}](exists)} || ${Entity[${ActiveNPCQueue.Peek}].IsMoribund}
				{
					ActiveNPCQueue:Dequeue
					continue
				}
				This:GenerateTypeCache[${ActiveNPCQueue.Peek}]
				
				CurrentDataTransactionIndex:Insert["insert into CurrentData (EntityID, NPCName, NPCTypeID, CurDist, FtrDist, CurVel, MaxVel, CruiseVel, NeutRng, NeutStr, EWARType, EWARStr, EWARRng, WebRng, WrpDisRng, WrpScrRng, EffNPCDPS, ThreatLevel, LastUpdate, UpdateType) values (${ActiveNPCQueue.Peek}, '${This.NPCName[${ActiveNPCQueue.Peek}].ReplaceSubstring[','']}', ${This.NPCTypeID[${ActiveNPCQueue.Peek}]}, ${This.NPCCurrentDist[${ActiveNPCQueue.Peek}]}, 0, ${This.NPCCurrentVel[${ActiveNPCQueue.Peek}]}, 0, 0, ${This.NPCNeutRange[${ActiveNPCQueue.Peek}]}, ${This.NPCNeutAmount[${ActiveNPCQueue.Peek}]}, '${This.NPCEWARType[${ActiveNPCQueue.Peek}]}', ${This.NPCEWARStrength[${ActiveNPCQueue.Peek}]}, ${This.NPCEWARRange[${ActiveNPCQueue.Peek}]}, ${This.NPCWebRange[${ActiveNPCQueue.Peek}]}, ${This.NPCDisruptRange[${ActiveNPCQueue.Peek}]}, ${This.NPCScramRange[${ActiveNPCQueue.Peek}]}, ${This.NPCDPSOutput[${ActiveNPCQueue.Peek}]}, ${This.NPCThreatLevel[${ActiveNPCQueue.Peek}]}, ${Time.Timestamp}, 'Maintain') ON CONFLICT (EntityID) DO UPDATE SET CurDist=excluded.CurDist, CurVel=excluded.CurVel, EffNPCDps=excluded.EffNPCDPS, ThreatLevel=excluded.ThreatLevel, LastUpdate=excluded.LastUpdate, UpdateType=excluded.UpdateType;"]
				AmmoTableQueue:Queue[${ActiveNPCQueue.Peek}]
				ActiveNPCQueue:Dequeue
				ProcessedCount:Inc[1]
			}
			while (${ActiveNPCQueue.Peek} > 0) && (${ProcessedCount} <= ${BatchCount})
		}
		
		if ${CurrentDataTransactionIndex.Used} > 0
		{
			CombatData:ExecDMLTransaction[CurrentDataTransactionIndex]
			CurrentDataTransactionIndex:Clear
		}
		
		if ${AmmoTableQueue.Peek} > 0
		{
			This:UpsertAmmoTable
		}
	}
	
	; I lied, another table exists.
	method UpsertAmmoTable()
	{
		variable int64 TempEntID
		; We will process the entries from the previous method.
		echo DEBUG COMBAT COMPUTER UAT ${AmmoTableQueue.Used}

		if ${AmmoTableQueue.Peek} > 0
		{
			do
			{
				if !${Entity[${AmmoTableQueue.Peek}](exists)}
				{
					AmmoTableQueue:Dequeue
					continue
				}
				variable iterator AmmoCollectionIterator
				echo ${AmmoCollection.Size} AMMO COLLECTION SIZE
				if ${AmmoCollection.Size} < 1
					break
				AmmoCollection:GetIterator[AmmoCollectionIterator]
				if ${AmmoCollectionIterator:First(exists)}
				{
					do
					{
						AmmoTableTransactionIndex:Insert["insert into AmmoTable (EntityID, AmmoTypeID, AmmoName, ExpectedShotDmg, ShotsToKill, TimeToKill, OurDamageEff, ChangeTime, LastUpdate) values (${AmmoTableQueue.Peek}, ${AmmoCollectionIterator.Value}, '${AmmoCollectionIterator.Key.ReplaceSubstring[','']}', ${This.ExpectedShotDmg[${AmmoTableQueue.Peek}, ${AmmoCollectionIterator.Value}, "ExpectedShotDmg"]}, ${This.ExpectedShotDmg[${AmmoTableQueue.Peek}, ${AmmoCollectionIterator.Value}, "ShotsToKill"]}, ${This.ExpectedShotDmg[${AmmoTableQueue.Peek}, ${AmmoCollectionIterator.Value}, "TimeToKill"]} ,${This.ExpectedShotDmg[${AmmoTableQueue.Peek}, ${AmmoCollectionIterator.Value}, "OurDamageEff"]}, ${ChangeTime}, ${Time.Timestamp}) ON CONFLICT (EntityID, AmmoTypeID) DO UPDATE SET ExpectedShotDmg=excluded.ExpectedShotDmg, ShotsToKill=excluded.ShotsToKill, TimeToKill=excluded.TimeToKill, OurDamageEff=excluded.OurDamageEff, LastUpdate=excluded.LastUpdate;"]
						echo AmmoTableTransactionIndex:Insert["insert into AmmoTable (EntityID, AmmoTypeID, AmmoName, ExpectedShotDmg, ShotsToKill, TimeToKill, OurDamageEff, ChangeTime, LastUpdate) values (${AmmoTableQueue.Peek}, ${AmmoCollectionIterator.Value}, '${AmmoCollectionIterator.Key.ReplaceSubstring[','']}', ${This.ExpectedShotDmg[${AmmoTableQueue.Peek}, ${AmmoCollectionIterator.Value}, "ExpectedShotDmg"]}, ${This.ExpectedShotDmg[${AmmoTableQueue.Peek}, ${AmmoCollectionIterator.Value}, "ShotsToKill"]}, ${This.ExpectedShotDmg[${AmmoTableQueue.Peek}, ${AmmoCollectionIterator.Value}, "TimeToKill"]} ,${This.ExpectedShotDmg[${AmmoTableQueue.Peek}, ${AmmoCollectionIterator.Value}, "OurDamageEff"]}, ${ChangeTime}, ${Time.Timestamp}) ON CONFLICT (EntityID, AmmoTypeID) DO UPDATE SET ExpectedShotDmg=excluded.ExpectedShotDmg, ShotsToKill=excluded.ShotsToKill, TimeToKill=excluded.TimeToKill, OurDamageEff=excluded.OurDamageEff, LastUpdate=excluded.LastUpdate;"]

					}
					while ${AmmoCollectionIterator:Next(exists)}
				}
				AmmoTableQueue:Dequeue
			}
			while ${AmmoTableQueue.Peek} > 0
		}
		if ${AmmoTableTransactionIndex.Used} > 0
		{
			CombatData:ExecDMLTransaction[AmmoTableTransactionIndex]
			AmmoTableTransactionIndex:Clear
		}
		This:CleanupTables
		
	}
	
	; And a method to remove things that don't belong here anymore.
	; We won't be employing this just yet. Also it isn't built yet.
	; Addendum, ultimately this DB will reside entirely within memory (after I get everything working) so this doesn't really need to exist at all.
	;; ADDENDUM - We will clean up.
	method CleanupTables()
	{
		GetCurrentData:Set[${CombatData.ExecQuery["SELECT * FROM AmmoTable;"]}]
		if ${GetCurrentData.NumRows} > 0
		{
			do
			{
				if !${Entity[${GetCurrentData.GetFieldValue["EntityID"]}](exists)} 
					CleanupQueue:Queue[${GetCurrentData.GetFieldValue["EntityID"]}]
					
				GetCurrentData:NextRow
			}
			while !${GetCurrentData.LastRow}
			GetCurrentData:Finalize
		}
		if ${CleanupQueue.Peek}
		{
			do
			{
				CombatData:ExecDML["Delete FROM AmmoTable WHERE EntityID=${CleanupQueue.Peek};"]
				CleanupQueue:Dequeue
			}
			while ${CleanupQueue.Peek}
		}
		GetCurrentData:Finalize
		GetCurrentData:Set[${CombatData.ExecQuery["SELECT * FROM CurrentData;"]}]
		if ${GetCurrentData.NumRows} > 0
		{
			do
			{
				if !${Entity[${GetCurrentData.GetFieldValue["EntityID"]}](exists)} 
					CleanupQueue:Queue[${GetCurrentData.GetFieldValue["EntityID"]}]
					
				GetCurrentData:NextRow
			}
			while !${GetCurrentData.LastRow}
			GetCurrentData:Finalize
		}
		if ${CleanupQueue.Peek}
		{
			do
			{
				CombatData:ExecDML["Delete FROM CurrentData WHERE EntityID=${CleanupQueue.Peek};"]
				CleanupQueue:Dequeue
			}
			while ${CleanupQueue.Peek}
		}
	}
	; One more Method. I need to be able to populate that cache of values that are always going to be the same so we can maybe speed this crap up a little.
	method GenerateTypeCache(int64 EntityID)
	{
		if !${This.NPCTypeIsCached[${EntityID}]}
		{
			echo DEBUGDEBUGDEBUG Generate Type CACHED
			echo ["insert into TypeCache (NPCTypeID, NPCName, NeutRng, NeutStr, EWARType, EWARStr, EWARRng, WebRng, WrpDisRng, WrpScrRng, LastUpdate) values (${This.NPCTypeID[${EntityID}]}, '${This.NPCName[${EntityID}].ReplaceSubstring[','']}', ${This.NPCNeutRange[${EntityID}]}, ${This.NPCNeutAmount[${EntityID}]}, '${This.NPCEWARType[${EntityID}]}', ${This.NPCEWARStrength[${EntityID}]}, ${This.NPCEWARRange[${EntityID}]}, ${This.NPCWebRange[${EntityID}]}, ${This.NPCDisruptRange[${EntityID}]}, ${This.NPCScramRange[${EntityID}]}, ${Time.Timestamp}) ON CONFLICT (NPCTypeID) DO UPDATE SET LastUpdate=excluded.LastUpdate;"]
			CombatData:ExecDML["insert into TypeCache (NPCTypeID, NPCName, NeutRng, NeutStr, EWARType, EWARStr, EWARRng, WebRng, WrpDisRng, WrpScrRng, LastUpdate) values (${This.NPCTypeID[${EntityID}]}, '${This.NPCName[${EntityID}].ReplaceSubstring[','']}', ${This.NPCNeutRange[${EntityID}]}, ${This.NPCNeutAmount[${EntityID}]}, '${This.NPCEWARType[${EntityID}]}', ${This.NPCEWARStrength[${EntityID}]}, ${This.NPCEWARRange[${EntityID}]}, ${This.NPCWebRange[${EntityID}]}, ${This.NPCDisruptRange[${EntityID}]}, ${This.NPCScramRange[${EntityID}]}, ${Time.Timestamp}) ON CONFLICT (NPCTypeID) DO UPDATE SET LastUpdate=excluded.LastUpdate;"]	
		}
		else
			echo DEBUG DEBUG DEBUG COMBAT COMPUTER ITS ALREADY CACHED 
	}
	; This member will tell me if the NPCType is cached or not for a given ENTITY ID
	member:bool NPCTypeIsCached(int64 EntityID)
	{
		GetTypeCache:Set[${CombatData.ExecQuery["SELECT * FROM TypeCache WHERE NPCTypeID=${This.NPCTypeID[${EntityID}]};"]}]
		if ${GetTypeCache.NumRows} > 0
		{
			; It is present in the cache
			GetTypeCache:Finalize
			return TRUE
		}	
		else
			return FALSE
	
	}
	; This member will return the Name of the given enemy.
	member:string NPCName(int64 EntityID)
	{
		variable string FinalValue
		
		FinalValue:Set[${Entity[${EntityID}].Name}]
		return "${FinalValue}"
	}
	
	; This member will return the TypeID of the given enemy.
	member:int64 NPCTypeID(int64 EntityID)
	{
		variable int64 FinalValue
		
		FinalValue:Set[${Entity[${EntityID}].TypeID}]
		return ${FinalValue}	
	}
	
	; This member will return the Current Distance of a given enemy.
	member:float64 NPCCurrentDist(int64 EntityID)
	{
		variable float64 FinalValue
		
		FinalValue:Set[${Entity[${EntityID}].Distance}]
		return ${FinalValue}
	}
	
	; This member will return the Future Distance of the given enemy.
	member:float64 NPCFutureDist(int64 EntityID)
	{
		variable float64 FinalValue
		
		FinalValue:Set[${NPCData.EnemyOrbitDistance[${This.NPCTypeID[${EntityID}]}]}]
		return ${FinalValue}
	
	}
	
	; This member will return the Current Velocity of the given enemy.
	member:float64 NPCCurrentVel(int64 EntityID)
	{
		variable float64 FinalValue
		
		FinalValue:Set[${Entity[${EntityID}].Velocity}]
		return ${FinalValue}
	}
	
	; This member will return the Maximum Velocity of a given enemy
	member:float64 NPCMaximumVel(int64 EntityID)
	{
		variable float64 FinalValue
		
		FinalValue:Set[${NPCData.EnemyMaximumVelocity[${This.NPCTypeID[${EntityID}]}]}]
		return ${FinalValue}
	}
	
	; This member will return the Cruise Velocity of a given enemy
	member:float64 NPCCruiseVel(int64 EntityID)
	{
		variable float64 FinalValue
		
		FinalValue:Set[${NPCData.EnemyCruiseVelocity[${This.NPCTypeID[${EntityID}]}]}]
		return ${FinalValue}
	}
	
	; This member will return the Energy Neut Range of a given Enemy
	member:float64 NPCNeutRange(int64 EntityID)
	{
		variable float64 FinalValue
		if !${This.NPCTypeIsCached[${EntityID}]}
			FinalValue:Set[${NPCData.EnemyEnergyNeutRange[${This.NPCTypeID[${EntityID}]}]}]
		else
		{
			GetTypeCache:Set[${CombatData.ExecQuery["SELECT * FROM TypeCache WHERE NPCTypeID=${This.NPCTypeID[${EntityID}]};"]}]
			FinalValue:Set[${GetTypeCache.GetFieldValue["NeutRng"]}]
			GetTypeCache:Finalize
		}
		return ${FinalValue}
	}
	
	; This member will return the Energy Neut Strength of a given Enemy
	member:float64 NPCNeutAmount(int64 EntityID)
	{
		variable float64 FinalValue
		if !${This.NPCTypeIsCached[${EntityID}]}
			FinalValue:Set[${NPCData.EnemyEnergyNeutPerSecond[${This.NPCTypeID[${EntityID}]}]}]
		else
		{
			GetTypeCache:Set[${CombatData.ExecQuery["SELECT * FROM TypeCache WHERE NPCTypeID=${This.NPCTypeID[${EntityID}]};"]}]
			FinalValue:Set[${GetTypeCache.GetFieldValue["NeutStr"]}]
			GetTypeCache:Finalize
		}
		return ${FinalValue}
	}
	
	; This member will return the EWAR Type of a given enemy.
	member:string NPCEWARType(int64 EntityID)
	{
		variable string FinalValue
		if !${This.NPCTypeIsCached[${EntityID}]}
		{
			if ${NPCData.EnemyUsesECM[${This.NPCTypeID[${EntityID}]}]}
				FinalValue:Concat["ECM"]
			if ${NPCData.EnemyUsesPainters[${This.NPCTypeID[${EntityID}]}]}
				FinalValue:Concat["Painter"]
			if ${NPCData.EnemyUsesGuidanceDisruption[${This.NPCTypeID[${EntityID}]}]} && ${Ship.ModuleList_MissileLauncher.Count} > 0
				FinalValue:Concat["Guidance"]
			if ${NPCData.EnemyUsesTrackingDisruption[${This.NPCTypeID[${EntityID}]}]} && ${Ship.${WeaponSwitch}.Count} > 0 && ${Ship.ModuleList_MissileLauncher.Count} > 0
				FinalValue:Concat["Tracking"]
			if ${NPCData.EnemySensorDampRange[${This.NPCTypeID[${EntityID}]}]} > 0
				FinalValue:Concat["Damp"]
			if !${FinalValue.NotNULLOrEmpty}
				return NONE
		}
		else
		{
			GetTypeCache:Set[${CombatData.ExecQuery["SELECT * FROM TypeCache WHERE NPCTypeID=${This.NPCTypeID[${EntityID}]};"]}]
			FinalValue:Set[${GetTypeCache.GetFieldValue["EWARType"]}]
			GetTypeCache:Finalize
		}
		
		return "${FinalValue}"
	}

	; This member will return the EWAR Strength of a given enemy.
	member:float64 NPCEWARStrength(int64 EntityID)
	{
		variable float64 FinalValue
		if !${This.NPCTypeIsCached[${EntityID}]}
		{
			if ${NPCData.EnemySensorDampRange[${This.NPCTypeID[${EntityID}]}]} > 0
				FinalValue:Set[${NPCData.EnemySensorDampStrength[${This.NPCTypeID[${EntityID}]}]}]
			else
				FinalValue:Set[0]
		}
		else
		{
			GetTypeCache:Set[${CombatData.ExecQuery["SELECT * FROM TypeCache WHERE NPCTypeID=${This.NPCTypeID[${EntityID}]};"]}]
			FinalValue:Set[${GetTypeCache.GetFieldValue["EWARStr"]}]
			GetTypeCache:Finalize
		}
		return ${FinalValue}		
	}
	
	; This member will return EWAR range of a given enemy
	member:float64 NPCEWARRange(int64 EntityID)
	{
		variable float64 FinalValue
		if !${This.NPCTypeIsCached[${EntityID}]}
		{
			if ${NPCData.EnemySensorDampRange[${This.NPCTypeID[${EntityID}]}]} > 0
				FinalValue:Set[${NPCData.EnemySensorDampRange[${This.NPCTypeID[${EntityID}]}]}]
			else
				FinalValue:Set[0]
		}
		else
		{
			GetTypeCache:Set[${CombatData.ExecQuery["SELECT * FROM TypeCache WHERE NPCTypeID=${This.NPCTypeID[${EntityID}]};"]}]
			FinalValue:Set[${GetTypeCache.GetFieldValue["EWARRng"]}]
			GetTypeCache:Finalize
		}
		return ${FinalValue}
	}
	
	; This member will return the Stasis Web Range of a given enemy
	member:float64 NPCWebRange(int64 EntityID)
	{
		variable float64 FinalValue
		if !${This.NPCTypeIsCached[${EntityID}]}
			FinalValue:Set[${NPCData.EnemyStasisWebRange[${This.NPCTypeID[${EntityID}]}]}]
		else
		{
			GetTypeCache:Set[${CombatData.ExecQuery["SELECT * FROM TypeCache WHERE NPCTypeID=${This.NPCTypeID[${EntityID}]};"]}]
			FinalValue:Set[${GetTypeCache.GetFieldValue["WebRng"]}]
			GetTypeCache:Finalize
		}
		return ${FinalValue}	
	}
	
	; This member will return the Warp Disruptor Range of a given enemy.
	member:float64 NPCDisruptRange(int64 EntityID)
	{
		variable float64 FinalValue
		if !${This.NPCTypeIsCached[${EntityID}]}
			FinalValue:Set[${NPCData.EnemyWarpDisruptorRange[${This.NPCTypeID[${EntityID}]}]}]
		else
		{
			GetTypeCache:Set[${CombatData.ExecQuery["SELECT * FROM TypeCache WHERE NPCTypeID=${This.NPCTypeID[${EntityID}]};"]}]
			FinalValue:Set[${GetTypeCache.GetFieldValue["WrpDisRng"]}]
			GetTypeCache:Finalize
		}
		return ${FinalValue}		
	}
	
	; This member will return the Warp Scrambler Range of a given enemy.
	member:float64 NPCScramRange(int64 EntityID)
	{
		variable float64 FinalValue
		if !${This.NPCTypeIsCached[${EntityID}]}
			FinalValue:Set[${NPCData.EnemyWarpScramblerRange[${This.NPCTypeID[${EntityID}]}]}]
		else
		{
			GetTypeCache:Set[${CombatData.ExecQuery["SELECT * FROM TypeCache WHERE NPCTypeID=${This.NPCTypeID[${EntityID}]};"]}]
			FinalValue:Set[${GetTypeCache.GetFieldValue["WrpScrRng"]}]
			GetTypeCache:Finalize
		}
		return ${FinalValue}		
	}
	
	; This member will return the Effective DPS Output for a given enemy.
	member:float64 NPCDPSOutput(int64 EntityID)
	{
		variable float64 FinalValue
		variable bool HasTurrets
		variable bool HasMissiles
		
		; Enemy Turret DPS by Damage Type, Before Modifiers
		variable float64 NPCTurretEM 
		NPCTurretEM:Set[${NPCData.EnemyTurretEMDPS[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCTurretExp 
		NPCTurretExp:Set[${NPCData.EnemyTurretExplosiveDPS[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCTurretKin 
		NPCTurretKin:Set[${NPCData.EnemyTurretKineticDPS[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCTurretTherm 
		NPCTurretTherm:Set[${NPCData.EnemyTurretThermalDPS[${This.NPCTypeID[${EntityID}]}]}]
		
		if ${NPCTurretEM} > 0 || ${NPCTurretExp} > 0 || ${NPCTurretKin} > 0 || ${NPCTurretTherm} > 0
		{
			echo NPCDPSOUTPUT[" NPCDPSOUTPUT ${NPCTurretEM} ${NPCTurretExp} ${NPCTurretKin} ${NPCTurretTherm}"]
			HasTurrets:Set[TRUE]
		}
		; Enemy Missile DPS by Damage Type, Before Modifiers
		variable float64 NPCMslEM 
		NPCMslEM:Set[${NPCData.EnemyMissileEMDPS[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCMslExp 
		NPCMslExp:Set[${NPCData.EnemyMissileExplosiveDPS[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCMslKin 
		NPCMslKin:Set[${NPCData.EnemyMissileKineticDPS[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCMslTherm 
		NPCMslTherm:Set[${NPCData.EnemyMissileThermalDPS[${This.NPCTypeID[${EntityID}]}]}]
		
		if ${NPCMslEM} > 0 || ${NPCMslExp} > 0 || ${NPCMslKin} > 0 || ${NPCMslTherm} > 0
		{
			echo NPCDPSOUTPUT[" NPCDPSOUTPUT ${NPCMslEM} ${NPCMslExp} ${NPCMslKin} ${NPCMslTherm}"]
			HasMissiles:Set[TRUE]
		}
		if !${HasTurrets} && !${HasMissiles}
			return 0
		; Enemy Turret Damage Application Parameters
		variable float64 NPCTrackingSpd
		variable float64 NPCOptimal
		variable float64 NPCFalloff
		variable float64 NPCChanceToHit
		; Normalized DPS=0.5 × min(Hit chance^2 + 0.98 × Hit chance + 0.0501, 6 × Hit chance)
		variable float64 NPCTurretDPSMod
		if ${HasTurrets}
		{
			NPCTrackingSpd:Set[${NPCData.EnemyTurretTrackingSpeed[${This.NPCTypeID[${EntityID}]}]}]
			NPCOptimal:Set[${NPCData.EnemyTurretOptimalRange[${This.NPCTypeID[${EntityID}]}]}]
			NPCFalloff:Set[${NPCData.EnemyTurretFalloffRange[${This.NPCTypeID[${EntityID}]}]}]
			NPCChanceToHit:Set[${This.TurretChanceToHit[${EntityID},${NPCTrackingSpd},${NPCOptimal},${NPCFalloff},TRUE]}]
			NPCTurretDPSMod:Set[${Math.Calc[0.5 * (${Utility.MinFloat[${Math.Calc[(${NPCChanceToHit}^^2) + (0.98 * ${NPCChanceToHit}) + 0.0501]}, ${Math.Calc[${NPCChanceToHit}*6]}]})]}]
			echo NPCDPSOUTPUT[" NPCDPSOUTPUT CHANCETOHIT ${NPCChanceToHit}"]
			echo NPCDPSOUTPUT[" NPCDPSOUTPUT  NPCTurretDPSMod ${Math.Calc[0.5 * (${Utility.MinFloat[${Math.Calc[(${NPCChanceToHit}^^2) + (0.98 * ${NPCChanceToHit}) + 0.0501]}, ${Math.Calc[${NPCChanceToHit}*6]}]})]}]"]
			;TurretDmgMod:Set[${Math.Calc[0.5 * (${Utility.MinFloat[${Math.Calc[(${ChanceToHit}^^2) + (0.98 * ${ChanceToHit}) + 0.0501]}, ${Math.Calc[${ChanceToHit}*6]}]})]}]
		}
		; Enemy Missile Damage Application paramters
		variable float64 NPCExpRad 
		NPCExpRad:Set[${NPCData.EnemyMissileExplosionRadius[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCExpVel 
		NPCExpVel:Set[${NPCData.EnemyMissileExplosionVelocity[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 PlayerSigRad 
		PlayerSigRad:Set[${MyShip.SignatureRadius}]
		variable float64 PlayerVel 
		PlayerVel:Set[${MyShip.ToEntity.Velocity}]
		variable float64 drf
		variable float64 RadiusFactor
		variable float64 VelocityFactor
		variable float64 NPCMissileDPSMod
		if ${HasMissiles}
		{
			drf:Set[${NPCData.EnemyMissileDRF[${This.NPCTypeID[${EntityID}]}]}]
			if ${NPCExpRad} > 0
				RadiusFactor:Set[${Math.Calc[${PlayerSigRad} / ${NPCExpRad}]}]
			if !${PlayerVel.Equal[0]}
				VelocityFactor:Set[${Math.Calc[(${RadiusFactor} * ${NPCExpVel} / ${PlayerVel}) ^^ ${drf}]}]
			else
				VelocityFactor:Set[1]
			NPCMissileDPSMod:Set[${Utility.MinFloat[${RadiusFactor}, ${VelocityFactor}]}]
			NPCMissileDPSMod:Set[${Utility.MinFloat[1, ${NPCMissileDPSMod}]}]
			echo DPSOUTPUT NPCMISSILEDPSMOD ${NPCMissileDPSMod}
		}
		; Our Ship's tanking layer resists.
		; Going to have to manually config these, we can't actually read the resists of our ship? Ugh.
		variable float64 TankLayerEMRes 
		TankLayerEMRes:Set[${Math.Calc[(100 - ${MissionTargetManager.Config.TankLayerEMResist})/100]}]
		;TankLayerEMRes:Set[0.28]
		variable float64 TankLayerExpRes 
		TankLayerExpRes:Set[${Math.Calc[(100 - ${MissionTargetManager.Config.TankLayerExpResist})/100]}]
		;TankLayerExpRes:Set[0.3]
		variable float64 TankLayerKinRes 
		TankLayerKinRes:Set[${Math.Calc[(100 - ${MissionTargetManager.Config.TankLayerKinResist})/100]}]
		;TankLayerKinRes:Set[0.3]
		variable float64 TankLayerThermRes 
		TankLayerThermRes:Set[${Math.Calc[(100 - ${MissionTargetManager.Config.TankLayerThermResist})/100]}]
		;TankLayerThermRes:Set[0.28]
		echo NPCDPSOUTPUT ${TankLayerEMRes} ${TankLayerExpRes} ${TankLayerKinRes} ${TankLayerThermRes}
		
		; And now to get the Turret DPS Post Resistance and Damage Modification
		variable float64 NPCTurretEMPR 
		NPCTurretEMPR:Set[${Math.Calc[${NPCTurretEM}*${TankLayerEMRes}*${NPCTurretDPSMod}*1000]}]
		variable float64 NPCTurretExpPR 
		NPCTurretExpPR:Set[${Math.Calc[${NPCTurretExp}*${TankLayerExpRes}*${NPCTurretDPSMod}*1000]}]
		variable float64 NPCTurretKinPR 
		NPCTurretKinPR:Set[${Math.Calc[${NPCTurretKin}*${TankLayerKinRes}*${NPCTurretDPSMod}*1000]}]
		variable float64 NPCTurretThermPR
		NPCTurretThermPR:Set[${Math.Calc[${NPCTurretTherm}*${TankLayerThermRes}*${NPCTurretDPSMod}*1000]}]
		echo NPCDPSOUTPUT POST RESISTS TURRET ${NPCTurretEMPR} ${NPCTurretExpPR} ${NPCTurretKinPR} ${NPCTurretThermPR}
		; And now the same, but for missiles
		variable float64 NPCMslEMPR 
		NPCMslEMPR:Set[${Math.Calc[${NPCMslEM}*${TankLayerEMRes}*${NPCMissileDPSMod}]}]
		variable float64 NPCMslExpPR 
		NPCMslExpPR:Set[${Math.Calc[${NPCMslExp}*${TankLayerExpRes}*${NPCMissileDPSMod}]}]
		variable float64 NPCMslKinPR 
		NPCMslKinPR:Set[${Math.Calc[${NPCMslKin}*${TankLayerKinRes}*${NPCMissileDPSMod}]}]
		variable float64 NPCMslThermPR 
		NPCMslThermPR:Set[${Math.Calc[${NPCMslTherm}*${TankLayerThermRes}*${NPCMissileDPSMod}]}]
		echo NPCDPSOUTPUT POST RESISTS MSL ${NPCMslEMPR} ${NPCMslExpPR} ${NPCMslKinPR} ${NPCMslThermPR}
		; And finally, to Sum.
		
		FinalValue:Set[${Math.Calc[${NPCTurretEMPR}+${NPCTurretExpPR}+${NPCTurretKinPR}+${NPCTurretThermPR}+${NPCMslEMPR}+${NPCMslExpPR}+${NPCMslKinPR}+${NPCMslThermPR}]}]
		echo FinalValue:Set${NPCTurretEMPR}+${NPCTurretExpPR}+${NPCTurretKinPR}+${NPCTurretThermPR}+${NPCMslEMPR}+${NPCMslExpPR}+${NPCMslKinPR}+${NPCMslThermPR}
		 echo DEBUG - CombatComputer - Entity ${EntityID} DPS Output ${FinalValue}
		if ${FinalValue} > 0 && ${FinalValue} < 1
			FinalValue:Set[1]
		return ${FinalValue}
	}
	
	; This member, if I can get it done, will return the Threat Level of a given enemy.
	member:int64 NPCThreatLevel(int64 EntityID)
	{
		variable int64 FinalValue
		
		FinalValue:Inc[${This.NPCThreatLevelWebs[${EntityID}]}]
		FinalValue:Inc[${This.NPCThreatLevelDisrupt[${EntityID}]}]
		FinalValue:Inc[${This.NPCThreatLevelScram[${EntityID}]}]
		FinalValue:Inc[${This.NPCThreatLevelPainting[${EntityID}]}]
		FinalValue:Inc[${This.NPCThreatLevelECM[${EntityID}]}]
		FinalValue:Inc[${This.NPCThreatLevelDamps[${EntityID}]}]
		FinalValue:Inc[${This.NPCThreatLevelTrackDis[${EntityID}]}]
		FinalValue:Inc[${This.NPCThreatLevelGuideDis[${EntityID}]}]
		FinalValue:Inc[${This.NPCThreatLevelNeuts[${EntityID}]}]
		FinalValue:Inc[${This.NPCThreatLevelBaseline[${EntityID}]}]
		FinalValue:Inc[${This.NPCThreatLevelProximityHitChance[${EntityID}]}]
		if ${FinalValue} > 0
			FinalValue:Inc[${Math.Calc[${FinalValue}/(((.01)+(${Entity[${EntityID}].StructurePct})+(${Entity[${EntityID}].ArmorPct})+(${Entity[${EntityID}].ShieldPct}))/300)]}]
		
		return ${FinalValue}
		
	}
	;FinalValue:Inc[${This.NPCThreatLevelProximityDPS[${EntityID}]}]
	
	;;; The following members will be involved in formulating the actual ThreatLevel of the enemy.
	; This member will return an integer representing the threat value presented by webs.
	member:int64 NPCThreatLevelWebs(int64 EntityID)
	{
		variable int64 FinalValue
	
		; Does this enemy use webs?
		; Are we in a ship that even cares? Most ships care at least a little, except marauders. If you are in a marauder this is a 0.

		if ${MyShip.ToEntity.Group.Equals[Marauder]}
			return 0
			
		GetCurrentData:Set[${CombatData.ExecQuery["SELECT * FROM CurrentData WHERE WebRng>0 AND EntityID=${EntityID};"]}]
		if ${GetCurrentData.NumRows} > 0
		{
			; It webs, add some threat. Expect this to get more complicated in the future, if I ever get there.
			FinalValue:Set[10]
			GetCurrentData:Finalize
		}
		return ${FinalValue}

	}
	; This member will return an integer representing the threat value presented by Warp Disruption (not scrams)
	member:int64 NPCThreatLevelDisrupt(int64 EntityID)
	{
		variable int64 FinalValue
	
		; Does this enemy use warp disruptors. The thing that doesn't turn off an mwd.
		; If you are in 0.0 or lowsec or wormholes this is a problem.
		; Otherwise, this is literally less than nothing. Returns a 0.
	
		GetCurrentData:Set[${CombatData.ExecQuery["SELECT * FROM CurrentData WHERE WarpDisRng>0 AND EntityID=${EntityID};"]}]
		if ${GetCurrentData.NumRows} > 0
		{
			; Are we somewhere that this actually matters?
			if ${Universe[${Me.SolarSystemID}].Security} < 0.5
			{
				FinalValue:Set[200]
			}
			else
				FinalValue:Set[0]
			GetCurrentData:Finalize
		}
		return ${FinalValue}
	}
	; This member will return an integer representing the threat value presented by Warp Scrambling (not warp disruptors)
	member:int64 NPCThreatLevelScram(int64 EntityID)
	{
		variable int64 FinalValue
		
		; Does this enemy use WARP SCRAMBLERS. The things that stop you warping and also MWDing.
		; If you are in a ship with an MWD that isn't a marauder and keeps the MWD going then this is a problem.
		; If you are in 0.0 this is also a problem.
		; Otherwise its a threat value of 0.

		if ${MyShip.ToEntity.Group.Equals[Marauder]}
			return 0
			
		GetCurrentData:Set[${CombatData.ExecQuery["SELECT * FROM CurrentData WHERE WarpScrRng>0 AND EntityID=${EntityID};"]}]
		if ${GetCurrentData.NumRows} > 0
		{
			; Are we somewhere that this actually matters?
			if ${Universe[${Me.SolarSystemID}].Security} < 0.5
			{
				FinalValue:Inc[200]
			}
			elseif ${Ship.ModuleList_MWD.Count} > 0
			{
				; Are we using an MWD?
				FinalValue:Inc[200]
			}
			else
				FinalValue:Set[0]
			GetCurrentData:Finalize
		}
		return ${FinalValue}		
	}
	; This member will return an integer representing the threat value presented by Target Painting
	member:int64 NPCThreatLevelPainting(int64 EntityID)
	{
		variable int64 FinalValue
		
		; Does this enemy apply target painting? Do we even care about that?
		; A battleship hull probably doesn't care. If you have an MWD you also probably don't care. Returns 0 in those cases.

		if ${MyShip.ToEntity.Group.Equals[Marauder]} || ${MyShip.ToEntity.Group.Equals[Battleship]}
			return 0
			
		if ${Ship.ModuleList_MWD.Count} > 0
		{
			; Are we using an MWD?
			FinalValue:Inc[0]
		}
		
		GetCurrentData:Set[${CombatData.ExecQuery["SELECT * FROM CurrentData WHERE EWARType LIKE '%Painter%' AND EntityID=${EntityID};"]}]
		if ${GetCurrentData.NumRows} > 0
		{
			FinalValue:Inc[20]
			GetCurrentData:Finalize
		}
		return ${FinalValue}		
	
	}
	; This member will return an integer representing the threat value presented by ECM
	member:int64 NPCThreatLevelECM(int64 EntityID)
	{
		variable int64 FinalValue
		
		; Does this enemy use ECM? ECM will keep us from killing what we actually want to kill.
		; This gets the highest threat level except for a couple other edge cases (we literally can't hit this enemy / some other super urgent thing is going on).
		
		GetCurrentData:Set[${CombatData.ExecQuery["SELECT * FROM CurrentData WHERE EWARType LIKE '%ECM%' AND EntityID=${EntityID};"]}]
		if ${GetCurrentData.NumRows} > 0
		{
			FinalValue:Set[1000]
			GetCurrentData:Finalize
		}
		return ${FinalValue}	
	}
	; This member will return an integer representing the threat value presented by Sensor Damps
	member:int64 NPCThreatLevelDamps(int64 EntityID)
	{
		variable int64 FinalValue
	
		; Does this enemy use Sensor Damps? Are they particularly strong? Is our sensor range already kinda awful?
		; This member will be a higher threat gen than most others, sensor damps are really debilitating (usually).

		GetCurrentData:Set[${CombatData.ExecQuery["SELECT * FROM CurrentData WHERE EWARType LIKE '%Damp%' AND EntityID=${EntityID};"]}]
		if ${GetCurrentData.NumRows} > 0
		{
			; Are we somewhere that this actually matters?
			FinalValue:Set[5000]
			GetCurrentData:Finalize
		}
		return ${FinalValue}	
	}
	; This member will return an integer representing the threat value presented by Tracking Disruption
	member:int64 NPCThreatLevelTrackDis(int64 EntityID)
	{
		variable int64 FinalValue
		
		; Does this enemy use tracking disruption? Are our weapons borderline as far as application is concerned (range is short or tracking is poor already.)?
		; Are we using missiles? If yes this returns a 0.
		; Are you a maniac using a drone boat or something like some kind of a fucking monster? It also returns a 0.
		
		if ${Ship.${WeaponSwitch}.Count} == 0
			return 0
		
		GetCurrentData:Set[${CombatData.ExecQuery["SELECT * FROM CurrentData WHERE EWARType LIKE '%Tracking%' AND EntityID=${EntityID};"]}]
		if ${GetCurrentData.NumRows} > 0
		{
			; Going to just consider the distance of the tracking disruptor user itself for now. This isn't going to work quite right at the moment.
			if ${Entity[${EntityID}].Distance} > ${Math.Calc[${Ship.${WeaponSwitch}.Range} * 0.75]}
				FinalValue:Inc[600]
			else
				FinalValue:Inc[400]
			GetCurrentData:Finalize
		}
		return ${FinalValue}	
	}
	; This member will return an integer representing the threat value presented by Guidance Disruption
	member:int64 NPCThreatLevelGuideDis(int64 EntityID)
	{
		variable int64 FinalValue
		
		; Does this enemy use guidance disruptors? Are we using weaponry that is inordinately affected by Guidance Disruption (our range is bad or our application is mediocre.)?
		; Are we a turret ship? If yes this returns 0.
		; Are you a maniac using a drone boat or something like some kind of a fucking monster? It also returns a 0.
		
		if ${Ship.ModuleList_MissileLauncher.Count} == 0
			return 0
		
		GetCurrentData:Set[${CombatData.ExecQuery["SELECT * FROM CurrentData WHERE EWARType LIKE '%Guidance%' AND EntityID=${EntityID};"]}]
		if ${GetCurrentData.NumRows} > 0
		{
			if ${Entity[${EntityID}].Distance} > ${Math.Calc[${Ship.ModuleList_MissileLauncher.Range} * 0.75]}
				FinalValue:Inc[500]
			else
				FinalValue:Inc[250]
			GetCurrentData:Finalize
		}
		return ${FinalValue}	
	}
	; This member will return an integer representing the threat value presented by Energy Neutralizers
	member:int64 NPCThreatLevelNeuts(int64 EntityID)
	{
		variable int64 FinalValue
		variable float64 NeutRng
		variable float64 NeutStr
		
		; Is this enemy capable of neuting? Are they in range to neut? Are the neuts of a significant strength? Are we in a ship that even cares about neuting?
		; That last one is going to be kinda hard to rectify, tbh. Maybe we will leave that off for now. 
		
		; We are using missiles, or projectiles (no cap use), and no active reps. If you are using a remote repping rattlesnake or something you can go to hell.
		if (${Ship.ModuleList_MissileLauncher.Count} > 0 || ${Ship.ModuleList_Projectiles.Count} > 0 && ( ${Ship.ModuleList_Regen_Armor.Count} == 0 && ${Ship.ModuleList_Regen_Shield.Count} == 0)
			return 0
		
		GetCurrentData:Set[${CombatData.ExecQuery["SELECT * FROM CurrentData WHERE NeutRng>0 AND EntityID=${EntityID};"]}]
		if ${GetCurrentData.NumRows} > 0
		{
			NeutRng:Set[${GetCurrentData.GetFieldValue["NeutRng"]}]
			NeutStr:Set[${GetCurrentData.GetFieldValue["NeutStr"]}]
			; Is this thing actually in range to neut?
			if ${Entity[${EntityID}].Distance} < ${NeutRng}
				FinalValue:Inc[200]
			; If we lose more than 4% of our capacitor per second, that is a significant threat.
			if ${Math.Calc[${NeutStr}/${MyShip.MaxCapacitor}]} > 0.04
				FinalValue:Inc[1000]
			else
				FinalValue:Inc[50]
			GetCurrentData:Finalize
		}
		return ${FinalValue}	
	
	}
	;;;;;;;;;;;;;;;;;; These will be done in the future, perhaps ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; This member will return an integer representing the threat value presented by Proximity and its relation to enemy DPS output.
	;member:int64 NPCThreatLevelProximityDPS(int64 EntityID)
	;{
	;	variable int64 FinalValue
		
		; Is this enemy in the optimal range zone required for them to do their maximum dps to you? Then they get a higher number.
		; If this enemy is not at that range yet, they get a lower number.
		; Might get fancier with this, some day.
	
	
	;}

	; This member will return an integer representing the threat value presented by Proximity and its relation to our ability to actually hit an enemy.
	member:int64 NPCThreatLevelProximityHitChance(int64 EntityID)
	{
		variable int64 FinalValue
		
		; Alright so the basic premise here is, if we are in a missile ship this always returns 0. Close or far (but not too far) makes 0 difference.
		; Otherwise, we will assign a larger value for enemies that WILL at some point in the future arrive at an orbit where we literally can not hit them.
		; I think I can pipe the ultimate orbit/speed/sig numbers into our turret hitchance stuff below and arrive at an accurate number, probably. 
		; If an enemy can be hit (adquately) at any range then this number is 0.
		; ADDENDUM - Too complicated, we are just going to throw some numbers at the wall and see what sticks.
		
		if ${Ship.ModuleList_MissileLauncher.Count} > 0 || (${Ship.ModuleList_MissileLauncher.Count} == 0 && ${Ship.${WeaponSwitch}.Count} == 0)
			return  0
		if ${Entity[${EntityID}].Group.Find["Frigate"]}
		{
			if ${Entity[${EntityID}].Distance} < 14000
			{
				return 0
			}
			if ${Entity[${EntityID}].Distance} > 14000 && ${Entity[${EntityID}].Velocity} < 50
			{
				return 1500
			}
			if ${Entity[${EntityID}].Distance} > 14000
			{
				return 1000
			}			
		}
		if ${Entity[${EntityID}].Group.Find["Destroyer"]}
		{
			if ${Entity[${EntityID}].Distance} < 14000
			{
				return 0
			}
			if ${Entity[${EntityID}].Distance} > 14000 && ${Entity[${EntityID}].Velocity} < 100
			{
				return 1500
			}
			if ${Entity[${EntityID}].Distance} > 14000
			{
				return 1000
			}			
		}
		if ${Entity[${EntityID}].Group.Find["Cruiser"]}
		{
			if ${Entity[${EntityID}].Distance} < 14000
			{
				return 0
			}
			if ${Entity[${EntityID}].Distance} > 14000 && ${Entity[${EntityID}].Velocity} < 150
			{
				return 1500
			}
			if ${Entity[${EntityID}].Distance} > 14000
			{
				return 1000
			}			
		}
	}

	; This member will return an integer representing the threat value presented by all enemies, as a baseline.
	member:int64 NPCThreatLevelBaseline(int64 EntityID)
	{
		variable int64 FinalValue
		variable float64 EffNPCDPS
		
		; The baseline threat level will primarily be based upon damage output. These numbers probably won't be particularly large.
		; The threat level increases from other sources will generally greatly outweigh these.
		; There will be minor increases included for existing NPC damage.
	
		GetCurrentData:Set[${CombatData.ExecQuery["SELECT * FROM CurrentData WHERE EffNPCDPS>0 AND EntityID=${EntityID};"]}]
		if ${GetCurrentData.NumRows} > 0
		{
			; If you are curious, we pull these values back out as strings and I don't feel like dealing with Lavishscript nonsense so we will make it a float then use it as such. This is probably pointless.
			EffNPCDPS:Set[${GetCurrentData.GetFieldValue["EffNPCDPS"]}]
			FinalValue:Set[${Math.Calc[${EffNPCDPS}*4]}]
			GetCurrentData:Finalize
		}
		else
			FinalValue:Set[1]
		return ${FinalValue}
	}

	;;; These members will end up in the AmmoTable.
	; This member will return the damage one single shot will do to the given enemy after resists, after sig radius and everything.
	; ADDENDUM - This member will be changed to do 2 more things depending on the input. Shots to Kill and Time to Kill.
	; Those things require basically the same info that is already here so no sense in making 3 members that are mostly the same.
	; Four things, damage application can also be here.
	member:float64 ExpectedShotDmg(int64 EntityID, int64 AmmoID, string ReqInfo)
	{
		variable float64 FinalValue
		variable bool Missl
		variable bool Precision
		variable collection:string DmgPMCollection
		; Need this for the Shots to Kill return
		variable int ShotCounter
		; Need these for both the Shots to Kill return and the Time to Kill return. This is seconds between shots.
		variable float64 TimeBetweenShots
		echo EXPECTEDSHOTDMG ${EntityID} ${AmmoID} ${ReqInfo}
		if ${Ship.${WeaponSwitch}.Count} > 0
		{
			echo EXPECTEDSHOTDMG NOT MISSL
			GetShipInfo:Set[${Ship2.MyShipInfo.ExecQuery["Select * FROM ShipAmmunitionTurret WHERE AmmoTypeID=${AmmoID};"]}]
			Missl:Set[FALSE]
		}
		if ${Ship.ModuleList_MissileLauncher.Count} > 0
		{
			echo EXPECTEDSHOTDMG MISSL
			GetShipInfo:Set[${Ship2.MyShipInfo.ExecQuery["Select * FROM ShipAmmunitionMissile WHERE AmmoTypeID=${AmmoID};"]}]
			; We need precisions to show as having ever so slightly less damage so that we will prefer normal missiles if the difference is very little.
			if ${GetShipInfo.GetFieldValue["AmmoType"].Find[Precision]}
				Precision:Set[TRUE]
				
			Missl:Set[TRUE]
		}
		echo DEBUG EXPECTEDSHOTDMG GETSHIPINFO NUMROWS ${GetShipInfo.NumRows}
		; Our ammunition's single hit damage, after local modifiers.
		variable float64 AmmoDmgEM
		AmmoDmgEM:Set[${GetShipInfo.GetFieldValue["EMDamage"]}]
		variable float64 AmmoDmgExp 
		AmmoDmgExp:Set[${GetShipInfo.GetFieldValue["ExpDamage"]}]
		variable float64 AmmoDmgKin 
		AmmoDmgKin:Set[${GetShipInfo.GetFieldValue["KinDamage"]}]
		variable float64 AmmoDmgTherm
		AmmoDmgTherm:Set[${GetShipInfo.GetFieldValue["ThermDamage"]}]
		if ${Precision} && ${Missl}
		{
			AmmoDmgEM:Set[${Math.Calc[${AmmoDmgEM}*.95]}]
			AmmoDmgExp:Set[${Math.Calc[${AmmoDmgExp}*.95]}]
			AmmoDmgKin:Set[${Math.Calc[${AmmoDmgKin}*.95]}]
			AmmoDmgTherm:Set[${Math.Calc[${AmmoDmgTherm}*.95]}]
		}
		echo DEBUG PRE-MOD AMMO DMG EM ${AmmoDmgEM} Exp ${AmmoDmgExp} Kin ${AmmoDmgKin} Therm ${AmmoDmgTherm}
		; Our ammunition's Turret Damage Application Parameters
		variable float64 TurretTrack
		variable float64 TurretOpt
		variable float64 TurretFall
		; Our ammunition's Missile Damage Application Parameters
		variable float64 MisslExpRad
		variable float64 MisslExpVel
		variable float64 MisslDRF
		if !${Missl}
		{
			TurretTrack:Set[${GetShipInfo.GetFieldValue["TrackingSpd"]}]
			echo ${TurretTrack} TRACKING SPEED
			TurretOpt:Set[${GetShipInfo.GetFieldValue["OptimalRng"]}]
			echo ${TurretOpt} TURRET OPTIMAL
			TurretFall:Set[${GetShipInfo.GetFieldValue["FalloffRng"]}]
			echo ${TurretFall} TURRET FALLOFF
		}
		else
		{
			MisslExpRad:Set[${GetShipInfo.GetFieldValue["ExpRadius"]}]
			MisslExpVel:Set[${GetShipInfo.GetFieldValue["ExpVel"]}]
			MisslDRF:Set[${NPCData.PlayerMissileDRF[${AmmoID}]}]
		}
		GetShipInfo:Finalize
		; Enemy velocity, sig radius, distance.
		variable float64 NPCSigRad
		variable float64 SigRadMod1
		variable float64 SigRadMod2
		NPCSigRad:Set[${Entity[${EntityID}].Radius}]
		if ${Ship.ModuleList_TargetPainter.Count} > 0
		{
			;We'll make this not hardcoded some day.
			SigRadMod1:Set[1.5]
			if ${Ship.ModuleList_TargetPainter.Count} > 1
			{
				SigRadMod2:Set[1.29]
			}
			else
				SigRadMod2:Set[1]
			NPCSigRad:Set[${Math.Calc[${NPCSigRad}*${SigRadMod1}*${SigRadMod2}]}]
		}
		variable float64 NPCVel
		NPCVel:Set[${Entity[${EntityID}].Velocity}]
		variable float64 NPCDist 
		NPCDist:Set[${Entity[${EntityID}].Distance}]
		; Turret Calcs
		variable float64 ChanceToHit
		; Normalized DPS=0.5 × min(Hit chance^2 + 0.98 × Hit chance + 0.0501, 6 × Hit chance)
		variable float64 TurretDmgMod
		if !${Missl}
		{
			ChanceToHit:Set[${This.TurretChanceToHit[${EntityID},${TurretTrack},${TurretOpt},${TurretFall},FALSE]}]
			echo ${ChanceToHit} CHANCETOHIT
			TurretDmgMod:Set[${Math.Calc[0.5 * (${Utility.MinFloat[${Math.Calc[(${ChanceToHit}^^2) + (0.98 * ${ChanceToHit}) + 0.0501]}, ${Math.Calc[${ChanceToHit}*6]}]})]}]
			if ${TurretDmgMod} < 0.03
				TurretDmgMod:Set[0]
			echo ${TurretDmgMod} TURRETDMGMOD
		}
		if ${ReqInfo.Equals["OurDamageEff"]} && !${Missl}
		{
			echo OURDAMAGEEFF TURRET ${TurretDmgMod}
			return ${TurretDmgMod}
		}
		; Missile Calcs
		variable float64 RadiusFactor
		variable float64 VelocityFactor
		variable float64 MissileDmgMod
		if ${Missl}
		{
			RadiusFactor:Set[${Math.Calc[${NPCSigRad} / ${MisslExpRad}]}]
			echo NPCEXPECTEDDAMAGE MISSL ${NPCSigRad} RADIUS FACTOR ${RadiusFactor} RAD ${MisslExpRad} VEL ${MisslExpVel} DRF ${MisslDRF}
			if !${NPCVel.Equal[0]}
			{
				VelocityFactor:Set[${Math.Calc[(${RadiusFactor} * ${MisslExpVel} / ${NPCVel}) ^^ ${MisslDRF}]}]
			}
			else
			{
				VelocityFactor:Set[1]
			}
			MissileDmgMod:Set[${Utility.MinFloat[${RadiusFactor}, ${VelocityFactor}]}]
			echo NPC EXPECTEDDAMAGE MISSL MISSL MISSL MISSL RADIUS FACTOR ${RadiusFactor} VELOCITY FACTOR ${VelocityFactor}
			MissileDmgMod:Set[${Utility.MinFloat[1, ${MissileDmgMod}]}]
			echo NPC EXPECTATRATORNSD MISSL MISSL MISSL MISSSSSLLLLL ${MissileDmgMod} 
		}
		if ${ReqInfo.Equals["OurDamageEff"]} && ${Missl}
		{
			echo OURDAMAGEEFF MISSILES ${MissileDmgMod}
			return ${MissileDmgMod}
		}
		; Our Ammo Damages post modifications, before resists.
		variable float64 AmmoDmgEMPM 
		variable float64 AmmoDmgExpPM 
		variable float64 AmmoDmgKinPM 
		variable float64 AmmoDmgThermPM
		if !${Missl}
		{
			DmgPMCollection:Set[${Math.Calc[${AmmoDmgEM}*${TurretDmgMod}].Int.LeadingZeroes[8]},EM]
			AmmoDmgEMPM:Set[${Math.Calc[${AmmoDmgEM}*${TurretDmgMod}].Int.LeadingZeroes[8]}]
			echo ${AmmoDmgEMPM} ${Math.Calc[${AmmoDmgEM}*${TurretDmgMod}].Int.LeadingZeroes[8]}
			DmgPMCollection:Set[${Math.Calc[${AmmoDmgExp}*${TurretDmgMod}].Int.LeadingZeroes[8]},Exp]
			AmmoDmgExpPM:Set[${Math.Calc[${AmmoDmgExp}*${TurretDmgMod}].Int.LeadingZeroes[8]}]
			echo ${AmmoDmgExpPM} ${Math.Calc[${AmmoDmgExp}*${TurretDmgMod}].Int.LeadingZeroes[8]}
			DmgPMCollection:Set[${Math.Calc[${AmmoDmgKin}*${TurretDmgMod}].Int.LeadingZeroes[8]},Kin]
			AmmoDmgKinPM:Set[${Math.Calc[${AmmoDmgKin}*${TurretDmgMod}].Int.LeadingZeroes[8]}]
			echo ${AmmoDmgKinPM} ${Math.Calc[${AmmoDmgKin}*${TurretDmgMod}].Int.LeadingZeroes[8]}
			DmgPMCollection:Set[${Math.Calc[${AmmoDmgTherm}*${TurretDmgMod}].Int.LeadingZeroes[8]},Therm]
			AmmoDmgThermPM:Set[${Math.Calc[${AmmoDmgTherm}*${TurretDmgMod}].Int.LeadingZeroes[8]}]
			echo ${AmmoDmgThermPM} ${Math.Calc[${AmmoDmgTherm}*${TurretDmgMod}].Int.LeadingZeroes[8]}
		}
		else
		{
			DmgPMCollection:Set[${Math.Calc[${AmmoDmgEM}*${MissileDmgMod}].Int.LeadingZeroes[8]},EM]
			AmmoDmgEMPM:Set[${Math.Calc[${AmmoDmgEM}*${MissileDmgMod}].Int.LeadingZeroes[8]}]
			echo ${Math.Calc[${AmmoDmgEM}*${MissileDmgMod}].Int.LeadingZeroes[8]},EM
			DmgPMCollection:Set[${Math.Calc[${AmmoDmgExp}*${MissileDmgMod}].Int.LeadingZeroes[8]},Exp]
			AmmoDmgExpPM:Set[${Math.Calc[${AmmoDmgExp}*${MissileDmgMod}].Int.LeadingZeroes[8]}]
			echo ${Math.Calc[${AmmoDmgExp}*${MissileDmgMod}].Int.LeadingZeroes[8]},Exp
			DmgPMCollection:Set[${Math.Calc[${AmmoDmgKin}*${MissileDmgMod}].Int.LeadingZeroes[8]},Kin]
			AmmoDmgKinPM:Set[${Math.Calc[${AmmoDmgKin}*${MissileDmgMod}].Int.LeadingZeroes[8]}]
			echo ${Math.Calc[${AmmoDmgKin}*${MissileDmgMod}].Int.LeadingZeroes[8]},Kin
			DmgPMCollection:Set[${Math.Calc[${AmmoDmgTherm}*${MissileDmgMod}].Int.LeadingZeroes[8]},Therm]
			AmmoDmgThermPM:Set[${Math.Calc[${AmmoDmgTherm}*${MissileDmgMod}].Int.LeadingZeroes[8]}]
			echo ${Math.Calc[${AmmoDmgTherm}*${MissileDmgMod}].Int.LeadingZeroes[8]},Therm
		}
		; Need these for ROF kinda stuff. We have a Bastion Module and it is On, or we don't have one at all, use the current ROF.
		if ${Ship.ModuleList_Siege.ActiveCount} > 0 || ${Ship.ModuleList_Siege.Count} == 0
		{
			TimeBetweenShots:Set[${Ship.${WeaponSwitch}.RateOfFire}]
		}
		; We have a bastion module and it is off. Pretend it is on. It is supposedly stacking penalized but from the numbers I'm looking at it doesn't seem to be. ROF Cuts in half.
		if ${Ship.ModuleList_Siege.ActiveCount} == 0 && ${Ship.ModuleList_Siege.Count} > 0
			{
				TimeBetweenShots:Set[${Math.Calc[${Ship.${WeaponSwitch}.RateOfFire} * 0.5]}]
			}
		; Need to calculate how much rep/s an NPC can do and for what layer.
		variable float64 NPCShieldRep 
		NPCShieldRep:Set[${NPCData.EnemyShieldRepSecond[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCArmorRep 
		NPCArmorRep:Set[${NPCData.EnemyArmorRepSecond[${This.NPCTypeID[${EntityID}]}]}]
		;;; These resist numbers are stored in the DB as the % thats get through ,not the % blocked. We can straight multiply these with damage.
		; Enemy Hull Resists + HP
		variable float64 NPCHullEMRes	
		NPCHullEMRes:Set[${NPCData.EnemyHullEMRes[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCHullExpRes	
		NPCHullExpRes:Set[${NPCData.EnemyHullExpRes[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCHullKinRes	
		NPCHullKinRes:Set[${NPCData.EnemyHullKinRes[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCHullThermRes 
		NPCHullThermRes:Set[${NPCData.EnemyHullThermRes[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCHullHP 
		NPCHullHP:Set[${NPCData.EnemyHullHP[${This.NPCTypeID[${EntityID}]}]}]
		NPCHullHP:Set[${Math.Calc[${NPCHullHP}*(${Entity[${EntityID}].StructurePct}/100)]}]
		; Enemy Armor Resists + HP
		variable float64 NPCArmorEMRes	
		NPCArmorEMRes:Set[${NPCData.EnemyArmorEMRes[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCArmorExpRes	
		NPCArmorExpRes:Set[${NPCData.EnemyArmorExpRes[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCArmorKinRes	
		NPCArmorKinRes:Set[${NPCData.EnemyArmorKinRes[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCArmorThermRes 
		NPCArmorThermRes:Set[${NPCData.EnemyArmorThermRes[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCArmorHP 
		NPCArmorHP:Set[${NPCData.EnemyArmorHP[${This.NPCTypeID[${EntityID}]}]}]
		NPCArmorHP:Set[${Math.Calc[${NPCArmorHP}*(${Entity[${EntityID}].ArmorPct}/100)]}]
		; Enemy Shield Resists + HP
		variable float64 NPCShieldEMRes	
		NPCShieldEMRes:Set[${NPCData.EnemyShieldEMRes[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCShieldExpRes 
		NPCShieldExpRes:Set[${NPCData.EnemyShieldExpRes[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCShieldKinRes 
		NPCShieldKinRes:Set[${NPCData.EnemyShieldKinRes[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCShieldThermRes 
		NPCShieldThermRes:Set[${NPCData.EnemyShieldThermRes[${This.NPCTypeID[${EntityID}]}]}]
		variable float64 NPCShieldHP 
		NPCShieldHP:Set[${NPCData.EnemyShieldHP[${This.NPCTypeID[${EntityID}]}]}]
		NPCShieldHP:Set[${Math.Calc[${NPCShieldHP}*(${Entity[${EntityID}].ShieldPct}/100)]}]
		; Need to store those HP values twice.
		variable float64 NPCShieldHPStart 
		NPCShieldHPStart:Set[${NPCShieldHP}]
		variable float64 NPCArmorHPStart 
		NPCArmorHPStart:Set[${NPCArmorHP}]
		variable float64 NPCHullHPStart 
		NPCHullHPStart:Set[${NPCHullHP}]
		; I'm not sure anymore.
		variable float64 LowestDmgNmbr
		if ${DmgPMCollection.FirstKey(exists)}
		{
			echo ${DmgPMCollection.FirstKey}			DMGPMCOLLECTION FIRSTKEY
			do
			{
				if ${DmgPMCollection.CurrentKey} == 0
				{
					continue
				}
				if ${DmgPMCollection.CurrentKey} > 0
				{
					LowestDmgNmbr:Set[${DmgPMCollection.CurrentKey}]
					break
				}
			}
			while ${DmgPMCollection.NextKey(exists)}
		}
		; You know, missiles never ever come with multiple damage types so lets just divide it by fucking 50 and call it a god damn day.
		if ${Missl}
		{
			LowestDmgNmbr:Set[10]
		}
		; Our decrement number will be made larger so that ExpectedShotDmg will take fewer loops. We maintain the proportionality, we just apply a larger slice of our damage per iteration now.
		if ${Missl} || (${TurretDmgMod} > 0.01)
		{
			variable float64 EMDec
			EMDec:Set[${Math.Calc[${AmmoDmgEMPM}]}]
			variable float64 EMDecTurbo
			EMDecTurbo:Set[${AmmoDmgEMPM}]
			variable float64 ExpDec 
			ExpDec:Set[${Math.Calc[${AmmoDmgExpPM}]}]
			variable float64 ExpDecTurbo
			ExpDecTurbo:Set[${AmmoDmgExpPM}]
			variable float64 KinDec 
			KinDec:Set[${Math.Calc[${AmmoDmgKinPM}]}]
			variable float64 KinDecTurbo
			KinDecTurbo:Set[${AmmoDmgKinPM}]
			variable float64 ThermDec 
			ThermDec:Set[${Math.Calc[${AmmoDmgThermPM}]}]
			variable float64 ThermDecTurbo
			ThermDecTurbo:Set[${AmmoDmgThermPM}]
		}
		variable float64 ShotPctDmgShld
		variable float64 ShotPctDmgArm
		variable float64 ShotPctDmgHull
		; Did we kill it in a single shot? Would we have killed it in two?
		variable bool OneShot = FALSE
		variable bool SecondShotAttempted = FALSE
		variable bool TwoShot = FALSE
		; Now, some math... I don't know what I'm doing here exactly so I'm going to be reinventing math as we go.
		; Need a case switch here now that this member has 4 purposes, 1 purpose completed above so 3 cases below.
		; Shots to kill may be a little inaccurate, if we don't factor in the enemy's repair ability...
		; Going to forgo that for the moment.
		if ${ReqInfo.Equals[ExpectedShotDmg]} || ${ReqInfo.Equals[ShotsToKill]} || ${ReqInfo.Equals[TimeToKill]}
		{
			if (${TurretDmgMod} <= 0.01) && !${Missl}
			{
				return 0
			}
			while ${NPCShieldHP} > 0 && (${AmmoDmgEMPM} > 0 || ${AmmoDmgExpPM} > 0 || ${AmmoDmgKinPM} > 0 || ${AmmoDmgThermPM} > 0)
			{
				NPCShieldHP:Set[${Math.Calc[${NPCShieldHP} - ((${EMDec} * ${NPCShieldEMRes}) + (${ExpDec} * ${NPCShieldExpRes}) + (${KinDec} * ${NPCShieldKinRes}) + (${ThermDec} * ${NPCShieldThermRes}))]}]
				AmmoDmgEMPM:Set[${Math.Calc[${AmmoDmgEMPM} - ${EMDec}]}]
				AmmoDmgExpPM:Set[${Math.Calc[${AmmoDmgExpPM} - ${ExpDec}]}]
				AmmoDmgKinPM:Set[${Math.Calc[${AmmoDmgKinPM} - ${KinDec}]}]
				AmmoDmgThermPM:Set[${Math.Calc[${AmmoDmgThermPM} - ${ThermDec}]}]
				if !${SecondShotAttempted} && (${NPCShieldHP} > 0 && (${AmmoDmgEMPM} <= 0 && ${AmmoDmgExpPM} <= 0 && ${AmmoDmgKinPM} <= 0 && ${AmmoDmgThermPM} <= 0)) && (${ReqInfo.Equals[ShotsToKill]} || ${ReqInfo.Equals[TimeToKill]})
				{
					SecondShotAttempted:Set[TRUE]
					AmmoDmgEMPM:Set[${Math.Calc[${AmmoDmgEMPM} + ${EMDecTurbo}]}]
					AmmoDmgExpPM:Set[${Math.Calc[${AmmoDmgExpPM} + ${ExpDecTurbo}]}]
					AmmoDmgKinPM:Set[${Math.Calc[${AmmoDmgKinPM} + ${KinDecTurbo}]}]
					AmmoDmgThermPM:Set[${Math.Calc[${AmmoDmgThermPM} + ${ThermDecTurbo}]}]					
				}
			}
			if ${NPCShieldHP} > 0 && ${ReqInfo.Equals[ExpectedShotDmg]}
				return ${Math.Calc[${NPCShieldHPStart} - ${NPCShieldHP}]}
			while ${NPCArmorHP} > 0 && (${AmmoDmgEMPM} > 0 || ${AmmoDmgExpPM} > 0 || ${AmmoDmgKinPM} > 0 || ${AmmoDmgThermPM} > 0)
			{
				NPCArmorHP:Set[${Math.Calc[${NPCArmorHP} - ((${EMDec} * ${NPCArmorEMRes}) + (${ExpDec} * ${NPCArmorExpRes}) + (${KinDec} * ${NPCArmorKinRes}) + (${ThermDec} * ${NPCArmorThermRes}))]}]
				AmmoDmgEMPM:Set[${Math.Calc[${AmmoDmgEMPM} - ${EMDec}]}]
				AmmoDmgExpPM:Set[${Math.Calc[${AmmoDmgExpPM} - ${ExpDec}]}]
				AmmoDmgKinPM:Set[${Math.Calc[${AmmoDmgKinPM} - ${KinDec}]}]
				AmmoDmgThermPM:Set[${Math.Calc[${AmmoDmgThermPM} - ${ThermDec}]}]
				if !${SecondShotAttempted} && (${NPCArmorHP} > 0 && (${AmmoDmgEMPM} <= 0 && ${AmmoDmgExpPM} <= 0 && ${AmmoDmgKinPM} <= 0 && ${AmmoDmgThermPM} <= 0)) && (${ReqInfo.Equals[ShotsToKill]} || ${ReqInfo.Equals[TimeToKill]})
				{
					SecondShotAttempted:Set[TRUE]
					AmmoDmgEMPM:Set[${Math.Calc[${AmmoDmgEMPM} + ${EMDecTurbo}]}]
					AmmoDmgExpPM:Set[${Math.Calc[${AmmoDmgExpPM} + ${ExpDecTurbo}]}]
					AmmoDmgKinPM:Set[${Math.Calc[${AmmoDmgKinPM} + ${KinDecTurbo}]}]
					AmmoDmgThermPM:Set[${Math.Calc[${AmmoDmgThermPM} + ${ThermDecTurbo}]}]					
				}
			}
			if ${NPCArmorHP} > 0 && ${ReqInfo.Equals[ExpectedShotDmg]}
				return ${Math.Calc[(${NPCArmorHPStart} - ${NPCArmorHP}) + ${NPCShieldHPStart}]}
			while ${NPCHullHP} > 0 && (${AmmoDmgEMPM} > 0 || ${AmmoDmgExpPM} > 0 || ${AmmoDmgKinPM} > 0 || ${AmmoDmgThermPM} > 0)
			{
				NPCHullHP:Set[${Math.Calc[${NPCHullHP} - ((${EMDec} * ${NPCHullEMRes}) + (${ExpDec} * ${NPCHullExpRes}) + (${KinDec} * ${NPCHullKinRes}) + (${ThermDec} * ${NPCHullThermRes}))]}]
				AmmoDmgEMPM:Set[${Math.Calc[${AmmoDmgEMPM} - ${EMDec}]}]
				AmmoDmgExpPM:Set[${Math.Calc[${AmmoDmgExpPM} - ${ExpDec}]}]
				AmmoDmgKinPM:Set[${Math.Calc[${AmmoDmgKinPM} - ${KinDec}]}]
				AmmoDmgThermPM:Set[${Math.Calc[${AmmoDmgThermPM} - ${ThermDec}]}]
				if !${SecondShotAttempted} && (${NPCHullHP} > 0 && (${AmmoDmgEMPM} <= 0 && ${AmmoDmgExpPM} <= 0 && ${AmmoDmgKinPM} <= 0 && ${AmmoDmgThermPM} <= 0)) && (${ReqInfo.Equals[ShotsToKill]} || ${ReqInfo.Equals[TimeToKill]})
				{
					SecondShotAttempted:Set[TRUE]
					AmmoDmgEMPM:Set[${Math.Calc[${AmmoDmgEMPM} + ${EMDecTurbo}]}]
					AmmoDmgExpPM:Set[${Math.Calc[${AmmoDmgExpPM} + ${ExpDecTurbo}]}]
					AmmoDmgKinPM:Set[${Math.Calc[${AmmoDmgKinPM} + ${KinDecTurbo}]}]
					AmmoDmgThermPM:Set[${Math.Calc[${AmmoDmgThermPM} + ${ThermDecTurbo}]}]					
				}
			}
			if ${NPCHullHP} > 0 && ${ReqInfo.Equals[ExpectedShotDmg]}
				return ${Math.Calc[(${NPCHullHPStart} - ${NPCHullHP}) + ${NPCArmorHPStart} + ${NPCShieldHPStart}]}
			; If we got here it means it died, and we had damage to spare. Overkill, if you will.
			if (${AmmoDmgEMPM} > 0 || ${AmmoDmgExpPM} > 0 || ${AmmoDmgKinPM} > 0 || ${AmmoDmgThermPM} > 0) && ${ReqInfo.Equals[ExpectedShotDmg]}
				echo ["Entity ${Entity[${EntityID}].Name} will be destroyed with ${Math.Calc[(${AmmoDmgEMPM} + ${AmmoDmgExpPM} + ${AmmoDmgKinPM} + ${AmmoDmgThermPM})]} Excess Damage"]
			if ${ReqInfo.Equals[ExpectedShotDmg]}
				return ${Math.Calc[${NPCHullHPStart} + ${NPCArmorHPStart} + ${NPCShieldHPStart}]}
			if (${ReqInfo.Equals[ShotsToKill]} || ${ReqInfo.Equals[TimeToKill]}) && ${NPCHullHP} <= 0
			{
				if !${SecondShotAttempted}
					OneShot:Set[TRUE]
				else
					TwoShot:Set[TRUE]
			}
			if (${ReqInfo.Equals[ShotsToKill]} || ${ReqInfo.Equals[TimeToKill]}) && ${NPCHullHP} > 0
			{
				OneShot:Set[FALSE]
				TwoShot:Set[FALSE]
			}
		}
		if ${ReqInfo.Equals[ShotsToKill]}
		{
			if (${TurretDmgMod} <= 0.01) && !${Missl}
			{
				return 9999999
			}
			if ${OneShot}
			{
				echo ["Entity ${Entity[${EntityID}].Name} will be destroyed with 1 Shot"]
				return 1
			}
			if ${TwoShot}
			{
				echo ["Entity ${Entity[${EntityID}].Name} will be destroyed with 2 Shots"]
				return 2		
			}
			; These should return the % of damage we will do to the particular layer after Modifiers and Resists. 
			; Shield is annoying some enemies don't have a shield layer...
			if ${NPCShieldHPStart} > 0
			{
				ShotPctDmgShld:Set[${Math.Calc[(1-(${NPCShieldHPStart} - ((${EMDecTurbo} * ${NPCShieldEMRes}) + (${ExpDecTurbo} * ${NPCShieldExpRes}) + (${KinDecTurbo} * ${NPCShieldKinRes}) + (${ThermDecTurbo} * ${NPCShieldThermRes})))/${NPCShieldHPStart})]}]
				if ${ShotPctDmgShld} < 0
					ShotPctDmgShld:Set[1]
				echo SHOTPCDTDMGSHLD ${Math.Calc[(${NPCShieldHPStart} - ((${EMDecTurbo} * ${NPCShieldEMRes}) + (${ExpDecTurbo} * ${NPCShieldExpRes}) + (${KinDecTurbo} * ${NPCShieldKinRes}) + (${ThermDecTurbo} * ${NPCShieldThermRes})))/${NPCShieldHPStart}]} [(${NPCShieldHPStart} - ((${EMDecTurbo} * ${NPCShieldEMRes}) + (${ExpDecTurbo} * ${NPCShieldExpRes}) + (${KinDecTurbo} * ${NPCShieldKinRes}) + (${ThermDecTurbo} * ${NPCShieldThermRes})))/${NPCShieldHPStart}]
			}
			ShotPctDmgArm:Set[${Math.Calc[(1-(${NPCArmorHPStart} - ((${EMDecTurbo} * ${NPCArmorEMRes}) + (${ExpDecTurbo} * ${NPCArmorExpRes}) + (${KinDecTurbo} * ${NPCArmorKinRes}) + (${ThermDecTurbo} * ${NPCArmorThermRes})))/${NPCArmorHPStart})]}]
			if ${ShotPctDmgArm} < 0
				ShotPctDmgArm:Set[1]
			echo SHOTPCDTDMGARM ${Math.Calc[(1-(${NPCArmorHPStart} - ((${EMDecTurbo} * ${NPCArmorEMRes}) + (${ExpDecTurbo} * ${NPCArmorExpRes}) + (${KinDecTurbo} * ${NPCArmorKinRes}) + (${ThermDecTurbo} * ${NPCArmorThermRes})))/${NPCArmorHPStart})]} [(${NPCArmorHPStart} - ((${EMDecTurbo} * ${NPCArmorEMRes}) + (${ExpDecTurbo} * ${NPCArmorExpRes}) + (${KinDecTurbo} * ${NPCArmorKinRes}) + (${ThermDecTurbo} * ${NPCArmorThermRes})))/${NPCArmorHPStart}]
			ShotPctDmgHull:Set[${Math.Calc[(1-(${NPCHullHPStart} - ((${EMDecTurbo} * ${NPCHullEMRes}) + (${ExpDecTurbo} * ${NPCHullExpRes}) + (${KinDecTurbo} * ${NPCHullKinRes}) + (${ThermDecTurbo} * ${NPCHullThermRes})))/${NPCHullHPStart})]}]
			if ${ShotPctDmgArm} < 0
				ShotPctDmgArm:Set[1]
			echo SHOTPCDTDMGHULL${Math.Calc[(1-(${NPCHullHPStart} - ((${EMDecTurbo} * ${NPCHullEMRes}) + (${ExpDecTurbo} * ${NPCHullExpRes}) + (${KinDecTurbo} * ${NPCHullKinRes}) + (${ThermDecTurbo} * ${NPCHullThermRes})))/${NPCHullHPStart})]} [(${NPCHullHPStart} - ((${EMDecTurbo} * ${NPCHullEMRes}) + (${ExpDecTurbo} * ${NPCHullExpRes}) + (${KinDecTurbo} * ${NPCHullKinRes}) + (${ThermDecTurbo} * ${NPCHullThermRes})))/${NPCHullHPStart}]

			if ${ShotPctDmgShld} > 0 && ${NPCShieldHPStart} > 0
			{
				ShotCounter:Inc[${Math.Calc[1/${ShotPctDmgShld}].Ceil}]
			}
			if ${ShotPctDmgArm} > 0
			{
				ShotCounter:Inc[${Math.Calc[1/${ShotPctDmgArm}].Ceil}]
			}
			if ${ShotPctDmgHull} > 0
			{
				ShotCounter:Inc[${Math.Calc[1/${ShotPctDmgHull}].Ceil}]
			}
			echo ["Entity ${Entity[${EntityID}].Name} will be destroyed with ${ShotCounter} Shots"]
			return ${ShotCounter}
		}
		if ${ReqInfo.Equals[TimeToKill]}
		{
			if (${TurretDmgMod} <= 0.01) && !${Missl}
			{
				return 9999999
			}
			if ${OneShot}
			{
				echo ["Entity ${Entity[${EntityID}].Name} will be destroyed in ${Math.Calc[1*${TimeBetweenShots}]} Seconds"]
				return 1
			}
			if ${TwoShot}
			{
				echo ["Entity ${Entity[${EntityID}].Name} will be destroyed in ${Math.Calc[2*${TimeBetweenShots}]} Seconds"]
				return 2		
			}
			if ${NPCShieldHPStart} > 0
			{
				ShotPctDmgShld:Set[${Math.Calc[(1-(${NPCShieldHPStart} - ((${EMDecTurbo} * ${NPCShieldEMRes}) + (${ExpDecTurbo} * ${NPCShieldExpRes}) + (${KinDecTurbo} * ${NPCShieldKinRes}) + (${ThermDecTurbo} * ${NPCShieldThermRes})))/${NPCShieldHPStart})]}]
			}
			ShotPctDmgArm:Set[${Math.Calc[(1-(${NPCArmorHPStart} - ((${EMDecTurbo} * ${NPCArmorEMRes}) + (${ExpDecTurbo} * ${NPCArmorExpRes}) + (${KinDecTurbo} * ${NPCArmorKinRes}) + (${ThermDecTurbo} * ${NPCArmorThermRes})))/${NPCArmorHPStart})]}]
			ShotPctDmgHull:Set[${Math.Calc[(1-(${NPCHullHPStart} - ((${EMDecTurbo} * ${NPCHullEMRes}) + (${ExpDecTurbo} * ${NPCHullExpRes}) + (${KinDecTurbo} * ${NPCHullKinRes}) + (${ThermDecTurbo} * ${NPCHullThermRes})))/${NPCHullHPStart})]}]
			if ${ShotPctDmgShld} > 0 && ${NPCShieldHPStart} > 0
			{
				ShotCounter:Inc[${Math.Calc[1/${ShotPctDmgShld}].Ceil}]
			}
			if ${ShotPctDmgArm} > 0
			{
				ShotCounter:Inc[${Math.Calc[1/${ShotPctDmgArm}].Ceil}]
			}
			if ${ShotPctDmgHull} > 0
			{
				ShotCounter:Inc[${Math.Calc[1/${ShotPctDmgHull}].Ceil}]
			}
			echo ["Entity ${Entity[${EntityID}].Name} will be destroyed in ${Math.Calc[${ShotCounter}*${TimeBetweenShots}]} Seconds "]
			return ${Math.Calc[${ShotCounter}*${TimeBetweenShots}]}
		}	
	}

	
	;;;;;;;;;;;;;;;
	;;; Borrowing these from obj_Module
	member:float64 _turretRangeDecayFactor(int64 targetID, float64 NPCOpt, float64 NPCFall)
	{
		variable float64 X
		variable float64 Y
		variable float64 Z
		X:Set[${Math.Calc[${Entity[${targetID}].X} - ${MyShip.ToEntity.X}]}]
		Y:Set[${Math.Calc[${Entity[${targetID}].Y} - ${MyShip.ToEntity.Y}]}]
		Z:Set[${Math.Calc[${Entity[${targetID}].Z} - ${MyShip.ToEntity.Z}]}]

		variable float64 targetDistance
		targetDistance:Set[${Math.Distance[${X}, ${Y}, ${Z}, 0, 0, 0]}]
		if ${targetDistance} == 0
		targetDistance:Set[${Entity[${targetID}].Distance}]

		variable float64 turretOptimalRange
		turretOptimalRange:Set[${NPCOpt}]

		variable float64 turretFalloff
		turretFalloff:Set[${NPCFall}]

		variable float64 decay
		decay:Set[${Math.Calc[${targetDistance} - ${turretOptimalRange}]}]
		decay:Set[${Utility.Max[0, ${decay}]}]

		variable float64 rangeFactor
		rangeFactor:Set[${Math.Calc[(${decay} / ${turretFalloff}) ^^ 2]}]
		;This:LogDebug["rangeFactor: \ao ${turretOptimalRange} ${turretFalloff} ${decay} -> ${rangeFactor}"]

		return ${rangeFactor}
	}

	member:float64 _turretTrackingDecayFactor(int64 targetID, float64 NPCTrack, bool Player)
	{
		variable float64 X
		variable float64 Y
		variable float64 Z
		variable float64 vX
		variable float64 vY
		variable float64 vZ
		X:Set[${Math.Calc[${Entity[${targetID}].X} - ${MyShip.ToEntity.X}]}]
		Y:Set[${Math.Calc[${Entity[${targetID}].Y} - ${MyShip.ToEntity.Y}]}]
		Z:Set[${Math.Calc[${Entity[${targetID}].Z} - ${MyShip.ToEntity.Z}]}]
		vX:Set[${Math.Calc[${Entity[${targetID}].vX} - ${MyShip.ToEntity.vX}]}]
		vY:Set[${Math.Calc[${Entity[${targetID}].vY} - ${MyShip.ToEntity.vY}]}]
		vZ:Set[${Math.Calc[${Entity[${targetID}].vZ} - ${MyShip.ToEntity.vZ}]}]

		
		variable float64 dotProduct
		dotProduct:Set[${Math.Calc[${vX} * ${X} + ${vY} * ${Y} + ${vZ} * ${Z}]}]

		variable float64 targetDistance
		targetDistance:Set[${Math.Distance[${X}, ${Y}, ${Z}, 0, 0, 0]}]
		if ${targetDistance} == 0
		targetDistance:Set[${Entity[${targetID}].Distance}]

		variable float64 norm
		norm:Set[${Math.Calc[${targetDistance} * ${targetDistance}]}]

		; Orthogonal(radical) velocity ratio.
		variable float64 ratio
		ratio:Set[${Math.Calc[${dotProduct} / ${norm}]}]

		; Tangent velocity.
		variable float64 projectionvX
		variable float64 projectionvY
		variable float64 projectionvZ
		projectionvX:Set[${Math.Calc[${vX} - ${ratio} * ${X}]}]
		projectionvY:Set[${Math.Calc[${vY} - ${ratio} * ${Y}]}]
		projectionvZ:Set[${Math.Calc[${vZ} - ${ratio} * ${Z}]}]

		; Tangent velocity scalar.
		variable float64 Vt
		Vt:Set[${Math.Sqrt[${projectionvX} * ${projectionvX} + ${projectionvY} * ${projectionvY} + ${projectionvZ} * ${projectionvZ}]}]

		variable float64 angularVelocity
		angularVelocity:Set[${Math.Calc[${Vt} / ${targetDistance}]}]
		This:LogDebug["Target angular velocity: \ao ${projectionvX} ${projectionvY} ${projectionvZ} -> ${angularVelocity}"]

		variable float64 trackingSpeed
		trackingSpeed:Set[${NPCTrack}]

		variable float64 targetSignatureRadius
		if !${Player}
			targetSignatureRadius:Set[${Entity[${targetID}].Radius}]
		else
			targetSignatureRadius:Set[${MyShip.SignatureRadius}]

		variable float64 trackingFactor
		trackingFactor:Set[${Math.Calc[(${angularVelocity} * 40000 / ${trackingSpeed} / ${targetSignatureRadius}) ^^ 2]}]
		;This:LogDebug["trackingFactor: \ao ${trackingSpeed} ${targetSignatureRadius} -> ${trackingFactor}"]

		return ${trackingFactor}
	}

	member:float64 TurretChanceToHit(int64 targetID, float64 NPCTrack, float64 NPCOpt, float64 NPCFall, bool Player)
	{
		variable float64 trackingFactor
		trackingFactor:Set[${This._turretTrackingDecayFactor[${targetID},${NPCTrack},${Player}]}]

		variable float64 rangeFactor
		rangeFactor:Set[${This._turretRangeDecayFactor[${targetID},${NPCOpt},${NPCFall}]}]

		variable float64 chanceToHit
		chanceToHit:Set[${Math.Calc[0.5 ^^ (${trackingFactor} + ${rangeFactor})]}]

		;This:LogDebug["chanceToHit: \ao ${rangeFactor} ${trackingFactor} -> ${chanceToHit}"]

		return ${chanceToHit}
	}
}
