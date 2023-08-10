objectdef obj_Configuration_MissionTargetManager inherits obj_Configuration_Base
{
	
	method Initialize()
	{
		This[parent]:Initialize["MissionTargetManager"]


	}
	

	method Set_Default_Values()
	{
		This.ConfigRef:AddSetting[TankLayerEMResist, 50]
		This.ConfigRef:AddSetting[TankLayerExpResist, 50]
		This.ConfigRef:AddSetting[TankLayerKinResist, 50]
		This.ConfigRef:AddSetting[TankLayerThermResist, 50]
		This.ConfigRef:AddSetting[WeaponCount, 4]
	}
	
	Setting(float, TankLayerEMResist, SetTankLayerEMResist)
	Setting(float, TankLayerExpResist, SetTankLayerExpResist)
	Setting(float, TankLayerKinResist, SetTankLayerKinResist)
	Setting(float, TankLayerThermResist, SetTankLayerThermResist)
	Setting(int,	WeaponCount,	SetWeaponCount)
}

objectdef obj_MissionTargetManager inherits obj_StateQueue
{
	; Avoid name conflict with common config.
	variable obj_Configuration_MissionTargetManager Config
	
	variable int MaxTarget = ${MyShip.MaxLockedTargets}


	
	variable obj_TargetingDatabase ActiveNPCDB

	; Query for our combat computer DB
	variable sqlitequery GetCCInfo
	; Query for our ammo table DB
	variable sqlitequery GetATInfo
	; Query for our Mission Target Manager DB
	variable sqlitequery GetMTMInfo
	; Query for our TargetList Replacement
	variable sqlitequery GetActiveNPCs
	variable sqlitequery GetActiveNPCs2
	; Surprise, I want a DB up in this place.
	variable sqlitedb MTMDB

	variable int MaxTarget = ${MyShip.MaxLockedTargets}
	variable int64 BurstTimer
	variable int64 CombatComputerTimer
	
	; Queue for removal from DB of things that don't exist anymore
	variable queue:int64 CleanupQueue
	
	variable int ValidPrimaryWeapTargets
	variable int ValidDroneTargets
	variable int ValidMissionTargets
	variable int ValidIgnoreTargets
	
	; Going to need this for constructing our Query.
	variable string DBQueryString

	method Initialize()
	{
		This[parent]:Initialize

		DynamicAddMiniMode("MissionTargetManager", "MissionTargetManager")
		This.PulseFrequency:Set[750]

		This.NonGameTiedPulse:Set[TRUE]


		This.LogLevelBar:Set[${Config.LogLevelBar}]

		;MTMDB:Set[${SQLite.OpenDB["${Me.Name}MTMDB",":memory:"]}]
		MTMDB:Set[${SQLite.OpenDB["${Me.Name}MTMDB","${Script.CurrentDirectory}/Data/${Me.Name}MTMDB.sqlite3"]}]
		MTMDB:ExecDML["PRAGMA journal_mode=WAL;"]
		MTMDB:ExecDML["PRAGMA main.mmap_size=64000000"]
		MTMDB:ExecDML["PRAGMA main.cache_size=-64000;"]
		if !${MTMDB.TableExists["Targeting"]}
		{
			echo DEBUG - MissionTargetManager - Creating Targeting Table
			MTMDB:ExecDML["create table Targeting (EntityID INTEGER PRIMARY KEY, TargetingCategory TEXT, HullHPPercent REAL, ArmorHPPercent REAL, ShieldHPPercent REAL, EffNPCDPS REAL, OurDamageEff REAL, ExpectedShotDmg REAL, OurNeededAmmo TEXT, ThreatLevel INTEGER);"]
		}		
		

	}

	method Start()
	{
		AttackTimestamp:Clear

		if ${This.IsIdle}
		{
			This:LogInfo["Starting"]
			This:QueueState["MissionTargetManager"]
		}
	}
	
	method Stop()
	{
		This:Clear
		
		
		MTMDB:Close
	}
	
	method Shutdown()
	{
		MTMDB:Close
		ActiveNPCDB.TargetingDatabase:Close
	}
	
	; This member is the primary loop for the minimode.
	member:bool MissionTargetManager()
	{
		variable int64 TempEntID
		
		; Well let's do the usual, throw our auto-return FALSE conditions out there.
		; If we aren't in space we aren't targeting.
		if !${Client.InSpace}
			return FALSE
		; Since this targetmanager is expected SPECIFICALLY for missions, if we aren't in mission mode, return false.
		if !${CommonConfig.Tehbot_Mode.Equal["Mission"]}
			return FALSE
		; Don't need to be doing this while in warp.
		if ${MyShip.ToEntity.Mode} == MOVE_WARPING
			return FALSE
		if !${Entity[${CurrentOffenseTarget}](exists)}
			CurrentOffenseTarget:Set[0]
		; This will kick off a series of events which will populate a table in a DB object attached to this mode.
		This:TargetListPreManagement
		
		This:TargetListCleanup
		
		; Combat Computer will take those entities returned (if any) and databasify them. 
		if ${LavishScript.RunningTime} >= ${CombatComputerTimer}
		{
			Ship2:GetAmmoInformation
			Ship2:GetReloadTime
			Ship2:CleanupAmmoTable

			GetActiveNPCs:Set[${ActiveNPCDB.TargetingDatabase.ExecQuery["SELECT * From ActiveNPCs UNION SELECT * From MissionTarget;"]}]

			if ${GetActiveNPCs.NumRows} > 0
			{
				do
				{
					echo DEBUG TARGET MANAGER INSERT INTO INDEX ${GetActiveNPCs.GetFieldValue["EntityID"]}
					TempEntID:Set[${GetActiveNPCs.GetFieldValue["EntityID"]}]
					if ${TempEntID} > 0
						CombatComputer.ActiveNPCQueue:Queue[${TempEntID}]
					CombatComputerTimer:Set[${Math.Calc[${LavishScript.RunningTime} + 20000]}]
					GetActiveNPCs:NextRow
				}
				while !${GetActiveNPCs.LastRow}
				GetActiveNPCs:Finalize
			}
		}
		This:TargetListManagement
		; With that done, let's get locking.
		if ${This.DBRowCount[ActiveNPCs]} > 0 || ((${This.TDBRowCount[WeaponTargets]} == 0) && (${This.TDBRowCount[MissionTarget]} > 0))
			This:LockManagement
			
		
		if ((${CurrentOffenseTarget} < 1 || !${Entity[${CurrentOffenseTarget}](exists)}) && ${This.DBRowCount[ActiveNPCs]} < 1 && ${This.DBRowCount[WeaponTargets]} < 1) || (${This.TableWithinRange[WeaponTargets]} == 0 || ${This.TableWithinRange[ActiveNPCs]} == 0)
		{
			echo DEBUG MTM TARGET DEAD DEACTIVATE SIEGE
			AllowSiegeModule:Set[FALSE]
			Ship.ModuleList_CommandBurst:DeactivateAll
		}
		if (${This.DBRowCount[WeaponTargets]} > 0 || ${This.TDBRowCount[WeaponTargets]} > 0 || (${This.DBRowCount[WeaponTargets]} == 0 && ${This.TDBRowCount[MissionTarget]} > 0)) && (${This.TableWithinRange[WeaponTargets]} > 0 || ${This.TableWithinRange[ActiveNPCs]} > 0)
		{
			echo ALLOWING SIEGE ${This.TableWithinRange[WeaponTargets]} ${This.TableWithinRange[ActiveNPCs]}
			AllowSiegeModule:Set[TRUE]
		}
		if ${AllowSiegeModule} && \
		${Ship.ModuleList_Siege.Allowed} && \
		${Ship.ModuleList_Siege.Count} && \
		!${Ship.RegisteredModule.Element[${Ship.ModuleList_Siege.ModuleID.Get[1]}].IsActive}
		{
			Ship.ModuleList_Siege:ActivateOne
		}
		if !${AllowSiegeModule}
		{
			Ship.ModuleList_Siege:DeactivateAll
		}
		; For when I inevitably make this for all modes not just mission, it will need to control its own siege allowance.
		if !${CommonConfig.Tehbot_Mode.Find["Mission"]} && ${CurrentOffenseTarget} > 0 && (${This.TableWithinRange[WeaponTargets]} > 0)
		{
			AllowSiegeModule:Set[TRUE]
		}
		; With that done, kick off the Primary Weapon method.
		if ${This.DBRowCount[WeaponTargets]} > 0 || ${This.TDBRowCount[WeaponTargets]} > 0
		{
			This:PrimaryWeapons
		}
		if ${This.DBRowCount[WeaponTargets]} == 0 && ${This.DBRowCount[DroneTargets]} > 0 && ${Entity[${This.GetFirstRowEntity[DroneTargets]}](exists)}
		{
			if ${Ship.ModuleList_StasisGrap.InactiveCount} > 0 && ${Entity[${This.GetFirstRowEntity[DroneTargets]}].Distance} < 19500 
			{
				Ship.ModuleList_StasisGrap:ActivateOne[${This.GetFirstRowEntity[DroneTargets]}]
			}
			if ${Ship.ModuleList_StasisWeb.InactiveCount} > 0 && ${Entity[${This.GetFirstRowEntity[DroneTargets]}].Distance} <= ${Ship.ModuleList_StasisWeb.Range}
			{
				Ship.ModuleList_StasisWeb:ActivateOne[${This.GetFirstRowEntity[DroneTargets]}]
			}
			if ${Entity[${This.GetFirstRowEntity[DroneTargets]}].Distance} <= 140000
			{
				Ship.ModuleList_TargetPainter:ActivateAll[${This.GetFirstRowEntity[DroneTargets]}]
			}		
		}
		if ${ValidDroneTargets} > 0 && ${DroneControl.CurrentTarget} == 0
			DroneControl.CurrentTarget:Set[${This.GetFirstRowEntity[DroneTargets]}]
		if ${This.DBRowCount[WeaponTargets]} > 0 && ${This.DBRowCount[DroneTargets]} == 0 && ${Entity[${This.GetFirstRowEntity[WeaponTargets]}](exists)}
		{
			DroneControl.CurrentTarget:Set[${This.GetFirstRowEntity[WeaponTargets]}]
		}
		if (!${Move.Traveling} && !${MyShip.ToEntity.Approaching.ID.Equal[${This.GetClosestEntity[ActiveNPCs]}]}) && ${Entity[${This.GetClosestEntity[ActiveNPCs]}](exists)} && ${This.TableWithinRange[ActiveNPCs]} == 0
		{
			AllowSiegeModule:Set[FALSE]
			Ship.ModuleList_Siege:DeactivateAll
			This:LogInfo["Approaching out of range target: \ar${Entity[${This.GetClosestEntity[ActiveNPCs]}].Name}"]
			Entity[${This.GetClosestEntity[ActiveNPCs]}]:Approach		
		}
		; Well, if all that is left are drone targets, may as well approach our mission objective or orbit the next gate or something.
		if (${This.DBRowCount[ActiveNPCs]} > 0 && ${This.DBRowCount[WeaponTargets]} < 1 && ${This.DBRowCount[DroneTargets]} > 1) && !${Move.Traveling} && ${MyShip.ToEntity.Mode} != MOVE_APPROACHING && ${MyShip.ToEntity.Mode} != MOVE_APPROACHING && ${MyShip.ToEntity.Mode} != MOVE_ORBITING
		{
			AllowSiegeModule:Set[FALSE]
			Ship.ModuleList_Siege:DeactivateAll		
			if ${Mission.CurrentAgentLoot.NotNULLOrEmpty} && ${Entity[Name =- "${Mission.CurrentAgentLoot}"](exists)}
				Move:Orbit[${Entity[Name =- "${Mission.CurrentAgentLoot}"]}, 2500]
			elseif ${Mission.CurrentAgentDestroy.NotNULLOrEmpty} && ${Entity[Name =- "${Mission.CurrentAgentDestroy}"](exists)}
				Move:Orbit[${Entity[Name =- "${Mission.CurrentAgentDestroy}"]}, 2500]
			elseif ${Entity[Type = "Acceleration Gate"](exists)}
				Move:Orbit[${Entity[Type = "Acceleration Gate"]}]
		}
		; Debug time
		echo DEBUG MISSION TARGET MANAGER PRIMARY LIST ${This.DBRowCount[WeaponTargets]} DRONE LIST ${This.DBRowCount[DroneTargets]} ACTIVE NPCS ${This.DBRowCount[ActiveNPCs]}

		return FALSE
	}
	; This method will handle the management of our TargetLists
	;; ADDENDUM - Targetlists will be replaced with SQLite. Except for the TargetList ActiveNPCs.
	;;; Even more addendum, ActiveNPCs will also be replaced with SQLite.
	method TargetListManagement()
	{	
		; Storage variables 
		variable float64 EffNPCDPS
		variable float64 OurDamageEff
		variable float64 ExpectedShotDmg
		variable int64 ThreatLevel
		variable string OurNeededAmmo
		variable string TargetingCategory
		; Index for bulk transaction.
		variable index:string TargetingUpsertIndex
		GetActiveNPCs:Set[${ActiveNPCDB.TargetingDatabase.ExecQuery["SELECT * From ActiveNPCs;"]}]

		if ${GetActiveNPCs.NumRows} > 0
		{
			do
			{
				; If somehow the NPC stopped existing before we got the original index and iterated it, we should discard it. OR if it is already in our MTM DB we should remove it.
				if !${Entity[${GetActiveNPCs.GetFieldValue["EntityID"]}](exists)}
				{
					GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE EntityID=${GetActiveNPCs.GetFieldValue["EntityID"]};"]}]
					if ${GetMTMInfo.NumRows} > 0
					{
						GetMTMInfo:Finalize
						MTMDB:ExecDML["DELETE From Targeting WHERE EntityID=${GetActiveNPCs.GetFieldValue["EntityID"]};"]
					}
					else
					{
						GetActiveNPCs:NextRow
						continue
					}
				}
				; Ok so it is now time to categorize this target.
				; (EntityID INTEGER PRIMARY KEY, TargetingCategory TEXT, HullHPPercent REAL, ArmorHPPercent REAL, ShieldHPPercent REAL, EffNPCDPS REAL, OurDamageEff REAL, ExpectedShotDmg REAL, OurNeededAmmo TEXT, ThreatLevel INTEGER)
				GetCCInfo:Set[${CombatComputer.CombatData.ExecQuery["Select * FROM CurrentData WHERE EntityID=${GetActiveNPCs.GetFieldValue["EntityID"]};"]}]
				if ${GetCCInfo.NumRows} > 0
				{
					EffNPCDPS:Set[${GetCCInfo.GetFieldValue["EffNPCDPS"]}]
					ThreatLevel:Set[${GetCCInfo.GetFieldValue["ThreatLevel"]}]
					GetCCInfo:Finalize
				}
				GetATInfo:Set[${CombatComputer.CombatData.ExecQuery["SELECT * FROM AmmoTable WHERE EntityID=${GetActiveNPCs.GetFieldValue["EntityID"]} AND ExpectedShotDmg = (SELECT MAX(ExpectedShotDmg) FROM AmmoTable WHERE EntityID=${GetActiveNPCs.GetFieldValue["EntityID"]});"]}]
				if ${GetATInfo.NumRows} > 0
				{
					ExpectedShotDmg:Set[${GetATInfo.GetFieldValue["ExpectedShotDmg"]}]
					OurDamageEff:Set[${GetATInfo.GetFieldValue["OurDamageEff"]}]
					OurNeededAmmo:Set[${GetATInfo.GetFieldValue["AmmoName"]}]
					GetATInfo:Finalize
				}
				;;; These will be for TargetingCategory. Categories are : PrimaryWeapon(Primary Weapon can hit adequately), PrimaryWeaponLow(Primary weapon can hit Poorly), DroneTarget (for turret ships we don't shoot these, for missile ships we shoot these if we have nothing
				;;; better to do), IgnoreTarget (It is out of range or otherwise a waste to attack this), MissionTarget (this is our mission objective, we kill this when we have nothing else to kill).
				; This would be things we can barely damage, but can in fact still damage. Going to set the threshold on this at 20%
				if ${OurDamageEff} >= .2
				{
					TargetingCategory:Set[PrimaryWeapon]
				}
				if ${OurDamageEff} < .2 && ${OurDamageEff} > .05
				{
					TargetingCategory:Set[PrimaryWeaponLow]
				}
				; This would be things we can not apply damage to (less than 5% efficiency), depending on range we will employ a different category. Things within drone control range can be drone targets, things outside that are treated out of range.
				if ${OurDamageEff} <= .05
				{
					if ${Entity[${GetActiveNPCs.GetFieldValue["EntityID"]}].Distance} < ${Me.DroneControlDistance}
					{
						TargetingCategory:Set[DroneTarget] 
					}
					else
					{
						TargetingCategory:Set[IgnoreTarget] 
					}
				}
				if ${Mission.CurrentAgentDestroy.NotNULLOrEmpty}
				{
					if ${Entity[${GetActiveNPCs.GetFieldValue["EntityID"]}].Name.Find["${Mission.CurrentAgentDestroy}"]}
					{
						TargetingCategory:Set[MissionTarget] 
					}
				}
				TargetingUpsertIndex:Insert["insert into Targeting (EntityID, TargetingCategory, HullHPPercent, ArmorHPPercent, ShieldHPPercent, EffNPCDPS, OurDamageEff, ExpectedShotDmg, OurNeededAmmo, ThreatLevel) values (${GetActiveNPCs.GetFieldValue["EntityID"]}, '${TargetingCategory}', ${Entity[${GetActiveNPCs.GetFieldValue["EntityID"]}].StructurePct},  ${Entity[${GetActiveNPCs.GetFieldValue["EntityID"]}].ArmorPct},  ${Entity[${GetActiveNPCs.GetFieldValue["EntityID"]}].ShieldPct}, ${EffNPCDPS}, ${OurDamageEff}, ${ExpectedShotDmg}, '${OurNeededAmmo}', ${ThreatLevel}) ON CONFLICT (EntityID) DO UPDATE SET TargetingCategory=excluded.TargetingCategory, HullHPPercent=excluded.HullHPPercent, ArmorHPPercent=excluded.ArmorHPPercent, ShieldHPPercent=excluded.ShieldHPPercent, EffNPCDPS=excluded.EffNPCDPS, OurDamageEff=excluded.OurDamageEff, ExpectedShotDmg=excluded.ExpectedShotDmg, OurNeededAmmo=excluded.OurNeededAmmo, ThreatLevel=excluded.ThreatLevel;"]
				GetActiveNPCs:NextRow
			}
			while !${GetActiveNPCs.LastRow}
			GetActiveNPCs:Finalize
		}
		; If we have anything to upsert, upsert.
		if ${TargetingUpsertIndex.Used} > 0
		{
			MTMDB:ExecDMLTransaction[TargetingUpsertIndex]
			TargetingUpsertIndex:Clear
		}
		; We have our basic categorization down, let us cleanup things that do not exist.
		This:TargetListCleanup
		
	}
	
	; This method will be used to cleanup non-existent entities from the DB
	method TargetListCleanup()
	{
		GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting;"]}]
		if ${GetMTMInfo.NumRows} > 0
		{
			do
			{
				if !${Entity[${GetMTMInfo.GetFieldValue["EntityID"]}](exists)}
					CleanupQueue:Queue[${GetMTMInfo.GetFieldValue["EntityID"]}]
					
				GetMTMInfo:NextRow
			}
			while !${GetMTMInfo.LastRow}
		}
		GetMTMInfo:Finalize
		if ${CleanupQueue.Size} > 0
		{
			do
			{
				MTMDB:ExecDML["DELETE From Targeting WHERE EntityID=${CleanupQueue.Peek};"]
				CleanupQueue:Dequeue
			}
			while ${CleanupQueue.Size} > 0
		}
	}

	; This method gets us our initial, and only TargetList, to make the DBs with.
	;;; ADDENDUM - We SQL now, this gets us our initial tables and possibly updates ones that have their query change.
	method TargetListPreManagement()
	{
		if !${ActiveNPCDB.TableCreated[ActiveNPCs]}
		{
			This:BuildQueryForDB[None]
			ActiveNPCDB:InstantiateTargetingTable[ActiveNPCs,1000,${DBQueryString.Escape},0]
			DBQueryString:Set[""]
		}
		if !${ActiveNPCDB.TableCreated[DroneTargets]}
		{
			ActiveNPCDB:InstantiateTargetingTable[DroneTargets,1000,"ID == -111111111111111111",2]
		}
		if !${ActiveNPCDB.TableCreated[WeaponTargets]}
		{
			ActiveNPCDB:InstantiateTargetingTable[WeaponTargets,1000,"ID == -111111111111111111",4]
		}
		if !${ActiveNPCDB.TableCreated[MissionTarget]}
		{
			ActiveNPCDB:InstantiateTargetingTable[MissionTarget,5000,"ID == -111111111111111111",1]
		}
		if ${Mission.CurrentAgentDestroy.NotNULLOrEmpty}
		{
			ActiveNPCDB:UpdateTargetingTableQueryString[MissionTarget,"Name == "${Mission.CurrentAgentDestroy}""]
		}
			;ActiveNPCDB:UpdateTargetingTableQueryString[MissionTarget,${DBQueryString.Escape}]
			;ActiveNPCDB:UpdateTargetingTableQueryString[WeaponTargets,${DBQueryString.Escape}]
			;ActiveNPCDB:UpdateTargetingTableQueryString[DroneTargets,${DBQueryString.Escape}]

		
	}
	; This method will handle the locking for both PrimaryWeapons and CombatDronery.
	; We are going to use 2 additional TargetLists because the lock management is just too handy to leave behind.
	;;; ADDENDUM - What a nightmare TargetList really is, we are SQL now. 
	method LockManagement()
	{

		variable int64 TargetEntityID
		
		; Time to determine how many Primary Weapon Targets we have
		GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE TargetingCategory LIKE '%Primary%';"]}]
		ValidPrimaryWeapTargets:Set[${GetMTMInfo.NumRows}]
		GetMTMInfo:Finalize
		; and How many Valid Drone Targets we have
		GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE TargetingCategory LIKE '%Drone%';"]}]
		ValidDroneTargets:Set[${GetMTMInfo.NumRows}]
		GetMTMInfo:Finalize	
		; and how many Mission Objective Targets we have
		GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE TargetingCategory='MissionTarget';"]}]
		ValidMissionTargets:Set[${GetMTMInfo.NumRows}]
		GetMTMInfo:Finalize
		; and how many IgnoreTarget we have
		GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE TargetingCategory='IgnoreTarget';"]}]
		ValidIgnoreTargets:Set[${GetMTMInfo.NumRows}]
		GetMTMInfo:Finalize	
		
		echo DEBUG MISSION TARGET MANAGER Valid Primary Targets ${ValidPrimaryWeapTargets} Valid Drone Targets ${ValidDroneTargets} Valid Mission Ojective Targets ${ValidMissionTargets}
		echo DEBUG ROWCOUNT ${This.DBRowCount[WeaponTargets]}
		; Need to kick things out of the TargetingTables and back into ActiveNPCs if they are ignore targets.
		if (${ValidIgnoreTargets} > 0)
		{
			GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE TargetingCategory LIKE '%Ignore%';"]}]
			if ${GetMTMInfo.NumRows} > 0
			{
				do
				{
					TargetEntityID:Set[${GetMTMInfo.GetFieldValue["EntityID"]}]
					GetActiveNPCs:Set[${ActiveNPCDB.TargetingDatabase.ExecQuery["SELECT * From WeaponTargets WHERE EntityID=${TargetEntityID};"]}]
					if ${GetActiveNPCs.NumRows} > 0
					{
						ActiveNPCDB.TargetingDatabase:ExecDML["DELETE FROM WeaponTargets WHERE EntityID=${TargetEntityID};"]
						GetActiveNPCs:Finalize
					}
					else
					{
						GetActiveNPCs:Finalize					
					}
					; We should check if this already exists in the wrong Table while we are here.
					GetActiveNPCs:Set[${ActiveNPCDB.TargetingDatabase.ExecQuery["SELECT * From DroneTargets WHERE EntityID=${TargetEntityID};"]}]
					if ${GetActiveNPCs.NumRows} > 0
					{
						ActiveNPCDB.TargetingDatabase:ExecDML["DELETE FROM DroneTargets WHERE EntityID=${TargetEntityID};"]
						GetActiveNPCs:Finalize
					}
					GetMTMInfo:NextRow
				}
				while !${GetMTMInfo.LastRow}
				GetActiveNPCs:Finalize
			}
		}
		if (${ValidPrimaryWeapTargets} > 0)
		{
			GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE TargetingCategory LIKE '%Primary%';"]}]
			if ${GetMTMInfo.NumRows} > 0
			{
				do
				{
					TargetEntityID:Set[${GetMTMInfo.GetFieldValue["EntityID"]}]
					GetActiveNPCs:Set[${ActiveNPCDB.TargetingDatabase.ExecQuery["SELECT * From WeaponTargets WHERE EntityID=${TargetEntityID};"]}]
					if ${GetActiveNPCs.NumRows} > 0
					{
						; Already present in the destination Table.
						GetActiveNPCs:Finalize
					}
					else
					{
						GetActiveNPCs:Finalize
						ActiveNPCDB.TargetingDatabase:ExecDML["INSERT INTO WeaponTargets SELECT * FROM ActiveNPCs WHERE EntityID=${TargetEntityID};"]					
					}
					; We should check if this already exists in the wrong Table while we are here.
					GetActiveNPCs:Set[${ActiveNPCDB.TargetingDatabase.ExecQuery["SELECT * From DroneTargets WHERE EntityID=${TargetEntityID};"]}]
					if ${GetActiveNPCs.NumRows} > 0
					{
						; In the wrong Table, delete it
						ActiveNPCDB.TargetingDatabase:ExecDML["DELETE FROM DroneTargets WHERE EntityID=${TargetEntityID};"]
						GetActiveNPCs:Finalize
					}
					GetMTMInfo:NextRow
				}
				while !${GetMTMInfo.LastRow}
				GetMTMInfo:Finalize
			}			
		}
		if (${ValidDroneTargets} > 0)
		{
			GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE TargetingCategory LIKE '%Drone%';"]}]
			if ${GetMTMInfo.NumRows} > 0
			{
				do
				{
					TargetEntityID:Set[${GetMTMInfo.GetFieldValue["EntityID"]}]
					GetActiveNPCs:Set[${ActiveNPCDB.TargetingDatabase.ExecQuery["SELECT * From DroneTargets WHERE EntityID=${TargetEntityID};"]}]
					if ${GetActiveNPCs.NumRows} > 0
					{
						; Already present in the destination Table.
						GetActiveNPCs:Finalize
					}
					else
					{
						GetActiveNPCs:Finalize
						ActiveNPCDB.TargetingDatabase:ExecDML["INSERT INTO DroneTargets SELECT * FROM ActiveNPCs WHERE EntityID=${TargetEntityID};"]					
					}
					; We should check if this already exists in the wrong Table while we are here.
					GetActiveNPCs:Set[${ActiveNPCDB.TargetingDatabase.ExecQuery["SELECT * From DroneTargets WHERE EntityID=${TargetEntityID};"]}]
					if ${GetActiveNPCs.NumRows} > 0
					{
						; In the wrong Table, delete it
						ActiveNPCDB.TargetingDatabase:ExecDML["DELETE FROM WeaponTargets WHERE EntityID=${TargetEntityID};"]
						GetActiveNPCs:Finalize
					}
					GetMTMInfo:NextRow
				}
				while !${GetMTMInfo.LastRow}
				GetMTMInfo:Finalize
			}
			GetMTMInfo:Finalize			
		}
		if (${This.TDBRowCount[WeaponTargets]} == 0) && (${This.TDBRowCount[MissionTarget]} > 0) 
		{
			; I need to be able to port these rows back into the ActiveNPCs list. Idk why. Don't ask.
			
			GetActiveNPCs:Set[${ActiveNPCDB.TargetingDatabase.ExecQuery["SELECT * From MissionTarget ORDER BY Priority DESC;"]}]
			if ${GetActiveNPCs.NumRows} > 0
			{
				do
				{
					TargetEntityID:Set[${GetActiveNPCs.GetFieldValue["EntityID"]}]
					GetActiveNPCs2:Set[${ActiveNPCDB.TargetingDatabase.ExecQuery["SELECT * From WeaponTargets WHERE EntityID=${TargetEntityID};"]}]
					if ${GetActiveNPCs2.NumRows} > 0
					{
						; Already present in the destination Table.
						GetActiveNPCs2:Finalize
					}
					else
					{
						GetActiveNPCs2:Finalize
						ActiveNPCDB.TargetingDatabase:ExecDML["INSERT INTO WeaponTargets SELECT * FROM MissionTarget WHERE EntityID=${TargetEntityID};"]					
					}
					GetActiveNPCs:NextRow
				}
				while !${GetActiveNPCs.LastRow}
			}
			GetActiveNPCs:Finalize		
		}
		if (${ValidPrimaryWeapTargets} == 0) && (${ValidMissionTargets} > 0)
		{
			GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE TargetingCategory='MissionTarget';"]}]
			if ${GetMTMInfo.NumRows} > 0
			{
				do
				{
					TargetEntityID:Set[${GetMTMInfo.GetFieldValue["EntityID"]}]
					GetActiveNPCs:Set[${ActiveNPCDB.TargetingDatabase.ExecQuery["SELECT * From MissionTarget WHERE EntityID=${TargetEntityID};"]}]
					if ${GetActiveNPCs.NumRows} > 0
					{
						; Already present in the destination Table.
						GetMTMInfo:NextRow
						GetActiveNPCs:Finalize
						continue
					}
					else
					{
						ActiveNPCDB.TargetingDatabase:ExecDML["INSERT INTO MissionTarget SELECT * FROM ActiveNPCs WHERE EntityID=${TargetEntityID};"]
						GetMTMInfo:NextRow
						GetActiveNPCs:Finalize
						continue							
					}
				}
				while !${GetMTMInfo.LastRow}
			}		
		}
	}
	;;; ADDENDUN - This might not actually be needed? If the previous method removes from wrong and adds to right, thats enough? Right?
	; This method will be used to shuffle between our TargetManagement tables. This will be quite similar to the method just before this one.
	; Except it will be for moving items between the actionable tables, not from the source table. 
	;method TargetingTableChecking()
	;{
	;	; Guess we will start off by looking at WeaponTargets.
	;	
	;
	;
	;}
	
	; This method will handle distribution of Primary Weapons Systems (guns/launchers)
	method PrimaryWeapons()
	{
		; First up, do we have a weapon active on something it shouldn't be active on? May happen if an enemy changes category in the middle of us shooting it.
		GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE TargetingCategory='DroneTarget' OR TargetingCategory='IgnoreTarget';"]}]
		if ${GetMTMInfo.NumRows} > 0
		{
			do
			{
				if ${Ship.ModuleList_Weapon.IsActiveOn[${GetMTMInfo.GetFieldValue["EntityID"]}]}
					Ship.ModuleList_Weapon:DeactivateOn[${GetMTMInfo.GetFieldValue["EntityID"]}]
				GetMTMInfo:NextRow
			}
			while !${GetMTMInfo.LastRow}
			GetMTMInfo:Finalize
		}
		; Secondly, let us choose our CurrentOffenseTarget.
		if ${CurrentOffenseTarget} == 0 || !${Entity[${CurrentOffenseTarget}](exists)} || !${Entity[${CurrentOffenseTarget}].IsLockedTarget}
		{
			; Well, I mean, the stuff placed in here was already pre-sorted and whatnot. Do I need to do anything more complex than just pick the first thing in the index?
			if (${This.GetFirstRowEntity[WeaponTargets]} > 0 && ${Entity[${This.GetFirstRowEntity[WeaponTargets]}](exists)}) || (${This.DBRowCount[WeaponTargets]} == 0 && ${This.GetFirstRowEntity[MissionTarget]} > 0 )
			{
				if ${WatchDog.WaitAndSee}
				{
					CurrentOffenseTarget:Set[0]
					WatchDog.WaitAndSee:Set[FALSE]
				}
				elseif (${This.DBRowCount[WeaponTargets]} == 0 && ${This.GetFirstRowEntity[MissionTarget]} > 0 )
					CurrentOffenseTarget:Set[${This.GetFirstRowEntity[MissionTarget]}]
				else
					CurrentOffenseTarget:Set[${This.GetFirstRowEntity[WeaponTargets]}]
				; If we have no other targets (other than drone targets), set current offense target to the MissionTarget
				if ${ValidPrimaryWeapTargets} < 1 && ${ValidMissionTargets} > 0
					CurrentOffenseTarget:Set[${This.GetFirstRowEntity[MissionTarget]}]
				; If we end up attacking the mission target early, let us not do that.
				if (${CurrentOffenseTarget} == ${This.GetFirstRowEntity[MissionTarget]}) && ${ValidWeapTargets} > 0
					CurrentOffenseTarget:Set[${This.GetFirstRowEntity[WeaponTargets]}]
				
				Ship.ModuleList_TrackingComputer:ActivateFor[${CurrentOffenseTarget}]
				
				GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE EntityID=${CurrentOffenseTarget};"]}]
				if ${GetMTMInfo.NumRows} > 0
				{
						AmmoOverride:Set[${GetMTMInfo.GetFieldValue["OurNeededAmmo"]}]
						This:LogInfo["Setting AmmoOverride to ${AmmoOverride} for ${Entity[${CurrentOffenseTarget}].Name}"]
				}
				GetMTMInfo:Finalize
				GetATInfo:Set[${CombatComputer.CombatData.ExecQuery["SELECT * FROM AmmoTable WHERE EntityID=${CurrentOffenseTarget} AND AmmoTypeID=${NPCData.TypeIDByName[${AmmoOverride}]};"]}]
				CurrentOffenseTargetExpectedShots:Set[${Math.Calc[${GetATInfo.GetFieldValue["ShotsToKill",int64]}/${Config.WeaponCount}].Ceil}]
				GetATInfo:Finalize
				if ${Entity[${CurrentOffenseTarget}].Name.Find[${Mission.CurrentAgentDestroy}]} && ${Mission.CurrentAgentDestroy.NotNULLOrEmpty}
					CurrentOffenseTargetExpectedShots:Set[9999999]
				if ${NPCData.EnemyArmorRepSecond[${Entity[${CurrentOffenseTarget}].TypeID}]} > 50 || ${NPCData.EnemyShieldRepSecond[${Entity[${CurrentOffenseTarget}].TypeID}]} > 50
					CurrentOffenseTargetExpectedShots:Set[9999999]
				This:LogInfo["${Entity[${CurrentOffenseTarget}].Name} is expected to require ${CurrentOffenseTargetExpectedShots} Salvos to kill with current ammo"]
			}
			
		}
		; Second and a halfly, we will periodically recheck the categorization of our CurrentOffenseTarget
		if ${CurrentOffenseTarget} > 0 && ${Entity[${CurrentOffenseTarget}](exists)}
		{
			if ${This.PresentInTable[WeaponTargets,${CurrentOffenseTarget}]} || (${This.PresentInTable[MissionTarget,${CurrentOffenseTarget}]} && ${This.DBRowCount[WeaponTargets]} == 0)
			{
				; zzzz
			}
			else
			{
				This:LogInfo["Shooting at something that ought not be shot, resetting current offense target"]
				if (${This.GetFirstRowEntity[WeaponTargets]} > 0 && ${Entity[${This.GetFirstRowEntity[WeaponTargets]}](exists)})
					CurrentOffenseTarget:Set[${This.GetFirstRowEntity[WeaponTargets]}]
				else
					CurrentOffenseTarget:Set[0]
			}
		}
		if ${CurrentOffenseTarget} > 0 && ${Entity[${CurrentOffenseTarget}].IsLockedTarget}
		{
			; Periodic Ammo Override re-evaluation
			GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE EntityID=${CurrentOffenseTarget};"]}]
			if ${GetMTMInfo.NumRows} > 0
			{
					AmmoOverride:Set[${GetMTMInfo.GetFieldValue["OurNeededAmmo"]}]
					This:LogInfo["Setting AmmoOverride to ${AmmoOverride} for ${Entity[${CurrentOffenseTarget}].Name}"]
			}
			GetMTMInfo:Finalize
			Ship.ModuleList_TrackingComputer:ActivateFor[${CurrentOffenseTarget}]
			; Thirdly, do we have any inactive combat utility modules? Target painter, web, grapple.
			if ${Ship.ModuleList_StasisGrap.InactiveCount} > 0 && ${Entity[${CurrentOffenseTarget}].Distance} < 19500 
			{
				Ship.ModuleList_StasisGrap:ActivateOne[${CurrentOffenseTarget}]
			}
			if ${Ship.ModuleList_StasisWeb.InactiveCount} > 0 && ${Entity[${CurrentOffenseTarget}].Distance} <= ${Ship.ModuleList_StasisWeb.Range}
			{
				Ship.ModuleList_StasisWeb:ActivateOne[${CurrentOffenseTarget}]
			}
			if ${Entity[${CurrentOffenseTarget}].Distance} <= 140000
			{
				Ship.ModuleList_TargetPainter:ActivateAll[${CurrentOffenseTarget}]
			}
			; Fourthly, do we have any inactive weapons?
			if ${Ship.ModuleList_Weapon.InactiveCount} > 0
			{
				Ship.ModuleList_Weapon:ActivateAll[${CurrentOffenseTarget}]		
			}
		}
	
	}
	; This method will handle combat dronery, someday. For now we will just fork over the target lists to DroneControl. 
	method CombatDronery()
	{
	
	
	}
	; This method will be used to construct our Query for our TargetingDatabase.
	method BuildQueryForDB()
	{
		variable string QueryString="CategoryID = CATEGORYID_ENTITY && IsNPC && !IsMoribund && !("

		
		;Exclude Groups here
		QueryString:Concat["GroupID = GROUP_CONCORDDRONE ||"]
		QueryString:Concat["GroupID = GROUP_CONVOYDRONE ||"]
		QueryString:Concat["GroupID = GROUP_CONVOY ||"]
		QueryString:Concat["GroupID = GROUP_LARGECOLLIDABLEOBJECT ||"]
		QueryString:Concat["GroupID = GROUP_LARGECOLLIDABLESHIP ||"]
		QueryString:Concat["GroupID = GROUP_SPAWNCONTAINER ||"]
		QueryString:Concat["GroupID = CATEGORYID_ORE ||"]
		QueryString:Concat["GroupID = GROUP_DEADSPACEOVERSEERSSTRUCTURE ||"]
		QueryString:Concat["GroupID = GROUP_LARGECOLLIDABLESTRUCTURE ||"]
		; Somehow the non hostile Orca and Drone ship in the Anomaly mission is in this group
		QueryString:Concat["GroupID = 288 ||"]		
		QueryString:Concat["GroupID = 446 ||"]		
		QueryString:Concat["GroupID = 182 ||"]	
		QueryString:Concat["GroupID = 4028 ||"]
		QueryString:Concat["GroupID = 4034 ||"]
		QueryString:Concat["GroupID = 1803 ||"]
		QueryString:Concat["GroupID = 1896 ||"]
		QueryString:Concat["GroupID = 1765 ||"]
		QueryString:Concat["GroupID = 1766 ||"]
		QueryString:Concat["GroupID = 1764 ||"]
		QueryString:Concat["GroupID = 1767 ||"]
		QueryString:Concat["GroupID = 99 ||"]
		QueryString:Concat["TypeID = 48253 ||"]
		QueryString:Concat["TypeID = 54579 ||"]
		QueryString:Concat["TypeID = 54580 ||"]
		QueryString:Concat["GroupID = 1307 ||"]
		QueryString:Concat["GroupID = 4035 ||"]
		QueryString:Concat["GroupID = 1310 ||"]
		QueryString:Concat["GroupID = 1956 ||"]	
		QueryString:Concat["GroupID = 4036 ||"]	
		QueryString:Concat["GroupID = 323 ||"]
		QueryString:Concat["GroupID = GROUP_ANCIENTSHIPSTRUCTURE ||"]
		QueryString:Concat["GroupID = GROUP_PRESSURESOLO)"]
			
		DBQueryString:Set[${QueryString.Escape}]
	}

	; This member will provide a quick way for me to get a row count from our MTMDB
	member:int DBRowCount(string LookingFor)
	{
		variable int FinalValue
		if ${LookingFor.Equal[ActiveNPCs]}
		{
			GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting;"]}]
			if ${GetMTMInfo.NumRows} > 0
			{
				FinalValue:Set[${GetMTMInfo.NumRows}]
			}
			else
				FinalValue:Set[0]
		}
		if ${LookingFor.Equal[DroneTargets]}
		{
			GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE TargetingCategory LIKE '%Drone%';"]}]
			if ${GetMTMInfo.NumRows} > 0
			{
				FinalValue:Set[${GetMTMInfo.NumRows}]
			}
			else
				FinalValue:Set[0]
		}
		if ${LookingFor.Equal[WeaponTargets]}
		{
			GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE TargetingCategory LIKE '%Primary%';"]}]
			if ${GetMTMInfo.NumRows} > 0
			{
				FinalValue:Set[${GetMTMInfo.NumRows}]
			}
			else
				FinalValue:Set[0]
		}
		GetMTMInfo:Finalize
		return ${FinalValue}
	}
	; This member is like the previous one, but for a rowcount from our obj_TargetingDatabase DB.
	member:int TDBRowCount(string TableName)
	{
		variable int FinalValue
		
		GetActiveNPCs:Set[${ActiveNPCDB.TargetingDatabase.ExecQuery["SELECT * FROM ${TableName};"]}]
		if ${GetActiveNPCs.NumRows} > 0
		{
			FinalValue:Set[${GetActiveNPCs.NumRows}]
		}
		else
			FinalValue:Set[0]

		GetMTMInfo:Finalize
		return ${FinalValue}
	}	
	; This member will provide a quick way to grab the first (valid, living and locked) entity ID from a given table in our TargetingDatabase.
	member:int64 GetFirstRowEntity(string TableName)
	{
		variable int64 FinalValue = 0
		
		if (${TableName.Equal[MissionTarget]} || ${TableName.Equal[WeaponTargets]}) && !${Ship.ModuleList_Weapon.Type.Find["Laser"]}
			GetActiveNPCs:Set[${ActiveNPCDB.TargetingDatabase.ExecQuery["SELECT * From ${TableName} WHERE PreferredAmmo='${Ship.ModuleList_Weapon.ChargeType}' ORDER BY PreferredAmmo ASC, Priority DESC;"]}]
		else
			GetActiveNPCs:Set[${ActiveNPCDB.TargetingDatabase.ExecQuery["SELECT * From ${TableName} ORDER BY Priority DESC;"]}]
		if ${GetActiveNPCs.NumRows} > 0
		{
			do
			{
				; 
				if !${Entity[${GetActiveNPCs.GetFieldValue["EntityID"]}].IsLockedTarget} || !${Entity[${GetActiveNPCs.GetFieldValue["EntityID"]}](exists)} || ${Entity[${GetActiveNPCs.GetFieldValue["EntityID"]}].IsMoribund}
				{
					GetActiveNPCs:NextRow
					continue
				}
				else
					FinalValue:Set[${GetActiveNPCs.GetFieldValue["EntityID"]}]
			}
			while !${GetActiveNPCs.LastRow} && ${FinalValue} == 0
			GetActiveNPCs:Finalize
		}
		elseif (${TableName.Equal[MissionTarget]} || ${TableName.Equal[WeaponTargets]}) && !${Ship.ModuleList_Weapon.Type.Find["Laser"]} && ${FinalValue} == 0
		{
			GetActiveNPCs:Finalize
			GetActiveNPCs:Set[${ActiveNPCDB.TargetingDatabase.ExecQuery["SELECT * From ${TableName} ORDER BY Priority DESC;"]}]
		}
		if ${GetActiveNPCs.NumRows} > 0
		{
			do
			{
				; 
				if !${Entity[${GetActiveNPCs.GetFieldValue["EntityID"]}].IsLockedTarget} || !${Entity[${GetActiveNPCs.GetFieldValue["EntityID"]}](exists)} || ${Entity[${GetActiveNPCs.GetFieldValue["EntityID"]}].IsMoribund}
				{
					GetActiveNPCs:NextRow
					continue
				}
				else
					FinalValue:Set[${GetActiveNPCs.GetFieldValue["EntityID"]}]
			}
			while !${GetActiveNPCs.LastRow} && ${FinalValue} == 0
		}
		GetActiveNPCs:Finalize
		return ${FinalValue}
	}
	; This member will return whether a given entity is present in a given TargetingDatabase DB table.
	member:bool PresentInTable(string TableName, int64 EntityID)
	{
		variable bool FinalValue
		
		GetActiveNPCs:Set[${ActiveNPCDB.TargetingDatabase.ExecQuery["SELECT * From ${TableName} WHERE EntityID=${EntityID};"]}]
		if ${GetActiveNPCs.NumRows} > 0
		{
			FinalValue:Set[TRUE]
		}
		else
			FinalValue:Set[FALSE]
			
		GetActiveNPCs:Finalize
		return ${FinalValue}	
	
	
	}
	; This member will return how many valid targets in a given table are within our ships lock range * 0.95
	member:int TableWithinRange(string TableName)
	{
		variable int FinalValue
		
		GetActiveNPCs:Set[${ActiveNPCDB.TargetingDatabase.ExecQuery["SELECT * From ${TableName} WHERE Distance<${Math.Calc[${MyShip.MaxTargetRange} * .95]};"]}]
		if ${GetActiveNPCs.NumRows} > 0
		{
			FinalValue:Set[${GetActiveNPCs.NumRows}]
		}
		else
			FinalValue:Set[0]
			
		GetActiveNPCs:Finalize
		return ${FinalValue}			
	
	}
	; This member will return the closest entity from a given table
	member:int64 GetClosestEntity(string TableName)
	{
		variable int64 FinalValue
		
		GetActiveNPCs:Set[${ActiveNPCDB.TargetingDatabase.ExecQuery["SELECT * From ${TableName} ORDER BY Distance DESC;"]}]
		if ${GetActiveNPCs.NumRows} > 0
		{
			FinalValue:Set[${GetActiveNPCs.GetFieldValue["EntityID"]}]
		}
		else
			FinalValue:Set[0]
			
		GetActiveNPCs:Finalize
		return ${FinalValue}			
	
	}
}