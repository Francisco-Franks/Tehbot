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

	variable obj_TargetList DistantNPCs
	variable obj_TargetList ActiveNPCs
	variable obj_TargetList PrimaryWeap
	variable obj_TargetList DroneTargets
	

	; Query for our combat computer DB
	variable sqlitequery GetCCInfo
	; Query for our ammo table DB
	variable sqlitequery GetATInfo
	; Query for our Mission Target Manager DB
	variable sqlitequery GetMTMInfo
	
	; Surprise, I want a DB up in this place.
	variable sqlitedb MTMDB

	variable int MaxTarget = ${MyShip.MaxLockedTargets}
	variable int64 BurstTimer
	variable int64 CombatComputerTimer
	
	; Queue for removal from DB of things that don't exist anymore
	variable queue:int64 CleanupQueue

	method Initialize()
	{
		This[parent]:Initialize

		DynamicAddMiniMode("MissionTargetManager", "MissionTargetManager")
		This.PulseFrequency:Set[1000]

		This.NonGameTiedPulse:Set[TRUE]


		This.LogLevelBar:Set[${Config.LogLevelBar}]
		
		DistantNPCs.NeedUpdate:Set[FALSE]
		DistantNPCs.AutoLock:Set[FALSE]
		DistantNPCs.MaxRange:Set[200000]
		ActiveNPCs.NeedUpdate:Set[FALSE]
		PrimaryWeap.NeedUpdate:Set[FALSE]
		DroneTargets.NeedUpdate:Set[FALSE]
		
		DroneTargets.MaxRange:Set[${Me.DroneControlDistance}]
		PrimaryWeap.AutoLock:Set[TRUE]
		DroneTargets.AutoLock:Set[TRUE]
		PrimaryWeap.MaxLockCount:Set[4]
		DroneTargets.MaxLockCount:Set[2]
		
		PrimaryWeap.MinLockCount:Set[4]
		DroneTargets.MinLockCount:Set[2]
		
		MTMDB:Set[${SQLite.OpenDB["${Me.Name}MTMDB","${Script.CurrentDirectory}/Data/${Me.Name}MTMDB.sqlite3"]}]
		MTMDB:ExecDML["PRAGMA journal_mode=WAL;"]
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
		
		DistantNPCs.NeedUpdate:Set[FALSE]
		ActiveNPCs.NeedUpdate:Set[FALSE]
		PrimaryWeap.NeedUpdate:Set[FALSE]
		DroneTargets.NeedUpdate:Set[FALSE]
		PrimaryWeap.AutoLock:Set[FALSE]
		DroneTargets.AutoLock:Set[FALSE]
		
		MTMDB:Close
	}
	
	method Shutdown()
	{
		MTMDB:Close
	}
	
	; This member is the primary loop for the minimode.
	member:bool MissionTargetManager()
	{
		; Well let's do the usual, throw our auto-return FALSE conditions out there.
		; If we aren't in space we aren't targeting.
		if !${Client.InSpace}
			return FALSE
		; Since this targetmanager is expected SPECIFICALLY for missions, if we aren't in mission mode, return false.
		if !${CommonConfig.Tehbot_Mode.Equal["Mission"]}
			return FALSE
		; TargetManager can be inhibited when we are in transit, hopefully this won't break
		if ${TargetManagerInhibited}
		{
			ActiveNPCs.AutoLock:Set[FALSE]		
			return FALSE
		}
		; Don't need to be doing this while in warp.
		if ${MyShip.ToEntity.Mode} == MOVE_WARPING
			return FALSE
			
		; This will kick off a targelist query for ActiveNPCs which will basically cover absolutely everything we would ever want to target in a mission.
		This:TargetListPreManagement
		ActiveNPCs.AutoLock:Set[FALSE]	
		; Combat Computer will take those entities returned (if any) and databasify them. 
		if ${LavishScript.RunningTime} >= ${CombatComputerTimer}
		{
			Ship2:GetAmmoInformation
			Ship2:GetReloadTime
			variable iterator ActiveNPCIterator
			ActiveNPCs.TargetList:GetIterator[ActiveNPCIterator]
			if ${ActiveNPCIterator:First(exists)}
			{
				do
				{
					echo DEBUG TARGET MANAGER INSERT INTO INDEX ${ActiveNPCIterator.Value}
					CombatComputer.ActiveNPCIndex:Insert[${ActiveNPCIterator.Value}]
					
				}
				while ${ActiveNPCIterator:Next(exists)}
			}
			if ${CombatComputer.ActiveNPCIndex.Used} > 0
			{
				CombatComputer:UpsertCurrentData
				CombatComputerTimer:Set[${Math.Calc[${LavishScript.RunningTime} + 20000]}]
			}
		}
		This:TargetListManagement
		; With that done, let's get locking.
		if ${ActiveNPCs.TargetList.Used} > 0
		{
			This:LockManagement
		}
		if (${CurrentOffenseTarget} < 1 || !${Entity[${CurrentOffenseTarget}](exists)}) && ${ActiveNPCs.TargetList.Used} < 1
		{
			echo DEBUG MTM TARGET DEAD DEACTIVATE SIEGE
			AllowSiegeModule:Set[FALSE]
			Ship.ModuleList_CommandBurst:DeactivateAll
		}
		if ${PrimaryWeap.LockedTargetList.Used} > 0
		{
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
		if !${CommonConfig.Tehbot_Mode.Find["Mission"]} && ${CurrentOffenseTarget} > 0
		{
			AllowSiegeModule:Set[TRUE]
		}
		; With that done, kick off the Primary Weapon method.
		if ${PrimaryWeap.LockedTargetList.Used} > 0
		{
			This:PrimaryWeapons
		}
		if ${PrimaryWeap.LockedTargetList.Used} == 0 && ${DroneTargets.LockedTargetList.Used} > 0
		{
			if ${Ship.ModuleList_StasisGrap.InactiveCount} > 0 && ${Entity[${DroneTargets.LockedTargetList.Get[1]}].Distance} < 19500
			{
				Ship.ModuleList_StasisGrap:ActivateAll[${DroneTargets.LockedTargetList.Get[1]}]
			}
			if ${Ship.ModuleList_StasisWeb.InactiveCount} > 0 && ${Entity[${DroneTargets.LockedTargetList.Get[1]}].Distance} <= ${Ship.ModuleList_StasisWeb.Range}
			{
				Ship.ModuleList_StasisWeb:ActivateAll[${DroneTargets.LockedTargetList.Get[1]}]
			}
			if ${Entity[${CurrentOffenseTarget}].Distance} <= 140000
			{
				Ship.ModuleList_TargetPainter:ActivateAll[${DroneTargets.LockedTargetList.Get[1]}]
			}		
		}
		if ${PrimaryWeap.LockedTargetList.Used} > 0 && ${DroneTargets.LockedTargetList.Used} == 0
		{
			DroneTargets:AddQueryString["ID == ${PrimaryWeap.LockedTargetList.Get[1]}"]
		}
		; Need a way to deal with enemies that are just too far away.
		if (${ActiveNPCs.TargetList.Used} > 0 && ${PrimaryWeap.LockedTargetList.Used} < 1 && ${DroneTargets.LockedTargetList.Used} < 1) && !${Move.Traveling} && !${MyShip.ToEntity.Approaching.ID.Equal[${ActiveNPCs.TargetList.Get[1]}]} 
		{
			AllowSiegeModule:Set[FALSE]
			Ship.ModuleList_Siege:DeactivateAll
			This:LogInfo["Approaching out of range target: \ar${Entity[${ActiveNPCs.TargetList.Get[1]}].Name}"]
			Entity[${ActiveNPCs.TargetList.Get[1]}]:Approach		
		}
		; Well, if all that is left are drone targets, may as well approach our mission objective or orbit the next gate or something.
		if (${ActiveNPCs.TargetList.Used} > 0 && ${PrimaryWeap.LockedTargetList.Used} < 1 && ${DroneTargets.LockedTargetList.Used} > 1) && !${Move.Traveling} && ${MyShip.ToEntity.Mode} != MOVE_APPROACHING
		{
			if ${Mission.CurrentAgentLoot.NotNULLOrEmpty} && ${Entity[Name =- ${Mission.CurrentAgentLoot}](exists)}
				Move:Orbit[${Entity[Name =- ${Mission.CurrentAgentLoot}]}, 2500]
			elseif ${Mission.CurrentAgentDestroy.NotNULLOrEmpty} && ${Entity[Name =- ${Mission.CurrentAgentDestroy}](exists)}
				Move:Orbit[${Entity[Name =- ${Mission.CurrentAgentDestroy}]}, 2500]
			elseif ${Entity[Type = "Acceleration Gate"](exists)}
				Move:Orbit[${Entity[Type = "Acceleration Gate"]}]
		}
		; Debug time
		echo DEBUG MISSION TARGET MANAGER PRIMARY LIST ${PrimaryWeap.TargetList.Used} DRONE LIST ${DroneTargets.TargetList.Used} ACTIVE NPCS ${ActiveNPCs.TargetList.Used} DistantNPCs ${DistantNPCs.TargetList.Used}
		
		PrimaryWeap:RequestUpdate
		DroneTargets:RequestUpdate	

		
		return FALSE
	}
	; This method will handle the management of our TargetLists
	;; ADDENDUM - Targetlists will be replaced with SQLite. Except for the TargetList ActiveNPCs.
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
		; If there are not ActiveNPCs then there is no point in doing this.
		if ${ActiveNPCs.TargetList.Used} == 0
			return FALSE
		; Next up we need to iterate through our TargetList. This will be used different from the above section.
		variable iterator ActiveNPCIterator
		ActiveNPCs.TargetList:GetIterator[ActiveNPCIterator]	
		if ${ActiveNPCIterator:First(exists)}
		{
			do
			{
				; If somehow the NPC stopped existing before we got the original index and iterated it, we should discard it. OR if it is already in our MTM DB we should remove it.
				if !${Entity[${ActiveNPCIterator.Value}](exists)}
				{
					GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE EntityID=${ActiveNPCIterator.Value};"]}]
					if ${GetMTMInfo.NumRows} > 0
					{
						GetMTMInfo:Finalize
						MTMDB:ExecDML["DELETE From Targeting WHERE EntityID=${ActiveNPCIterator.Value};"]
					}
					else
						continue
				}
				; Ok so it is now time to categorize this target.
				; (EntityID INTEGER PRIMARY KEY, TargetingCategory TEXT, HullHPPercent REAL, ArmorHPPercent REAL, ShieldHPPercent REAL, EffNPCDPS REAL, OurDamageEff REAL, ExpectedShotDmg REAL, OurNeededAmmo TEXT, ThreatLevel INTEGER)
				GetCCInfo:Set[${CombatComputer.CombatData.ExecQuery["Select * FROM CurrentData WHERE EntityID=${ActiveNPCIterator.Value};"]}]
				if ${GetCCInfo.NumRows} > 0
				{
					EffNPCDPS:Set[${GetCCInfo.GetFieldValue["EffNPCDPS"]}]
					ThreatLevel:Set[${GetCCInfo.GetFieldValue["ThreatLevel"]}]
					GetCCInfo:Finalize
				}
				GetATInfo:Set[${CombatComputer.CombatData.ExecQuery["SELECT * FROM AmmoTable WHERE EntityID=${ActiveNPCIterator.Value} AND ExpectedShotDmg = (SELECT MAX(ExpectedShotDmg) FROM AmmoTable WHERE EntityID=${ActiveNPCIterator.Value});"]}]
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
				if ${OurDamageEff} < .2 && ${OurDamageEff} > .02
				{
					TargetingCategory:Set[PrimaryWeaponLow]
				}
				; This would be things we can not apply damage to (less than 5% efficiency), depending on range we will employ a different category. Things within drone control range can be drone targets, things outside that are treated out of range.
				if ${OurDamageEff} < .02
				{
					if ${Entity[${ActiveNPCIterator.Value}].Distance} < ${Me.DroneControlDistance}
					{
						TargetingCategory:Set[DroneTarget] 
					}
					elseif !${Ship.ModuleList_Weapon.IsUsingLongRangeAmmo}
					{
						TargetingCategory:Set[PrimaryWeaponLow]
					}
					else
					{
						TargetingCategory:Set[IgnoreTarget] 
					}
				}
				if ${Mission.CurrentAgentDestroy.NotNULLOrEmpty}
				{
					if ${Entity[${ActiveNPCIterator.Value}].Name.Find["${Mission.CurrentAgentDestroy}"]}
					{
						TargetingCategory:Set[MissionTarget] 
					}
				}
				TargetingUpsertIndex:Insert["insert into Targeting (EntityID, TargetingCategory, HullHPPercent, ArmorHPPercent, ShieldHPPercent, EffNPCDPS, OurDamageEff, ExpectedShotDmg, OurNeededAmmo, ThreatLevel) values (${ActiveNPCIterator.Value}, '${TargetingCategory}', ${Entity[${ActiveNPCIterator.Value}].StructurePct},  ${Entity[${ActiveNPCIterator.Value}].ArmorPct},  ${Entity[${ActiveNPCIterator.Value}].ShieldPct}, ${EffNPCDPS}, ${OurDamageEff}, ${ExpectedShotDmg}, '${OurNeededAmmo}', ${ThreatLevel}) ON CONFLICT (EntityID) DO UPDATE SET TargetingCategory=excluded.TargetingCategory, HullHPPercent=excluded.HullHPPercent, ArmorHPPercent=excluded.ArmorHPPercent, ShieldHPPercent=excluded.ShieldHPPercent, EffNPCDPS=excluded.EffNPCDPS, OurDamageEff=excluded.OurDamageEff, ExpectedShotDmg=excluded.ExpectedShotDmg, OurNeededAmmo=excluded.OurNeededAmmo, ThreatLevel=excluded.ThreatLevel;"]
			}
			while ${ActiveNPCIterator:Next(exists)}
		}
		; If we have anything to upsert, upsert.
		if ${TargetingUpsertIndex.Size} > 0
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
	method TargetListPreManagement()
	{
		ActiveNPCs:ClearQueryString
		
		ActiveNPCs:AddAllNPCs
		ActiveNPCs.MaxRange:Set[${Math.Calc[${MyShip.MaxTargetRange} * .95]}]
		
		; This specifically can be very much simplified now. 
		if ${Mission.CurrentAgentDestroy.NotNULLOrEmpty}
				ActiveNPCs:AddQueryString["Name == \"${Mission.CurrentAgentDestroy}\""]
		; These cargo containers can prove massively time wasting.
		if ${Mission.Config.IgnoreNPCSentries} || ${Mission.CurrentAgentLoot.Equal["Cargo Container"]}
		{
			ActiveNPCs:AddTargetExceptionByPartOfName["Battery"]
			ActiveNPCs:AddTargetExceptionByPartOfName["Batteries"]
			ActiveNPCs:AddTargetExceptionByPartOfName["Sentry Gun"]
			ActiveNPCs:AddTargetExceptionByPartOfName["Tower Sentry"]
		}
		ActiveNPCs:AddTargetExceptionByPartOfName["EDENCOM"]
		ActiveNPCs:AddTargetExceptionByPartOfName["Tyrannos"]
		ActiveNPCs:AddTargetExceptionByPartOfName["Drifter"]
		ActiveNPCs:AddTargetExceptionByPartOfName["Sleeper"]
		
		
		ActiveNPCs:RequestUpdate
		DistantNPCs:AddAllNPCs
		DistantNPCs:RequestUpdate
	
	}
	; This method will handle the locking for both PrimaryWeapons and CombatDronery.
	; We are going to use 2 additional TargetLists because the lock management is just too handy to leave behind.
	method LockManagement()
	{
		variable int ValidPrimaryWeapTargets
		variable int ValidDroneTargets
		variable int ValidMissionTargets
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
		
		PrimaryWeap:ClearQueryString
		DroneTargets:ClearQueryString	
		
		echo DEBUG MISSION TARGET MANAGER Valid Primary Targets ${ValidPrimaryWeapTargets} Valid Drone Targets ${ValidDroneTargets} Valid Mission Ojective Targets ${ValidMissionTargets}
		if (${ValidPrimaryWeapTargets} > ${PrimaryWeap.TargetList.Used}) && (${PrimaryWeap.TargetList.Used} < 4)
		{
			if ${Ship.ModuleList_Weapon.Type.Find["Laser"]}
			{
				GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE TargetingCategory LIKE '%Primary%' ORDER BY TargetingCategory ASC, ThreatLevel DESC;"]}]
				if ${GetMTMInfo.NumRows} > 0
				{
					do
					{
						TargetEntityID:Set[${GetMTMInfo.GetFieldValue["EntityID"]}]
						PrimaryWeap:AddQueryString["ID == ${TargetEntityID}"]
						GetMTMInfo:NextRow
					}
					while !${GetMTMInfo.LastRow} && (${PrimaryWeap.TargetList.Used} < 4)
					GetMTMInfo:Finalize
				}
			}
			else
			{
				GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE OurNeededAmmo='${Ship.ModuleList_Weapon.ChargeName}' AND TargetingCategory LIKE '%Primary%' ORDER BY TargetingCategory ASC, ThreatLevel DESC;"]}]
				if ${GetMTMInfo.NumRows} > 0
				{
					do
					{
						TargetEntityID:Set[${GetMTMInfo.GetFieldValue["EntityID"]}]
						PrimaryWeap:AddQueryString["ID == ${TargetEntityID}"]
						GetMTMInfo:NextRow
					}
					while !${GetMTMInfo.LastRow} && (${PrimaryWeap.TargetList.Used} < 4)
					GetMTMInfo:Finalize
				}
				else
				{
					GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE TargetingCategory LIKE '%Primary%' ORDER BY TargetingCategory ASC, ThreatLevel DESC;"]}]
					if ${GetMTMInfo.NumRows} > 0
					{
						do
						{
							TargetEntityID:Set[${GetMTMInfo.GetFieldValue["EntityID"]}]
							PrimaryWeap:AddQueryString["ID == ${TargetEntityID}"]
							GetMTMInfo:NextRow
						}
						while !${GetMTMInfo.LastRow} && (${PrimaryWeap.TargetList.Used} < 4)
						GetMTMInfo:Finalize
					}				
				}
			}			
		}
		if (${ValidDroneTargets} > ${DroneTargets.TargetList.Used}) && (${DroneTargets.TargetList.Used} < 2)
		{
			GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE TargetingCategory LIKE '%Drone%' ORDER BY ThreatLevel DESC;"]}]
			if ${GetMTMInfo.NumRows} > 0
			{
				do
				{
					TargetEntityID:Set[${GetMTMInfo.GetFieldValue["EntityID"]}]
					DroneTargets:AddQueryString["ID == ${TargetEntityID}"]
					GetMTMInfo:NextRow
				}
				while !${GetMTMInfo.LastRow} && (${DroneTargets.TargetList.Used} < 2)
			}
			GetMTMInfo:Finalize			
		}
		if (${ValidPrimaryWeapTargets} == 0) && (${ValidMissionTargets} > 0)
		{
			GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE TargetingCategory='MissionTarget';"]}]
			if ${GetMTMInfo.NumRows} > 0
			{
				do
				{
					TargetEntityID:Set[${GetMTMInfo.GetFieldValue["EntityID"]}]
					PrimaryWeap:AddQueryString["ID == ${TargetEntityID}"]
					GetMTMInfo:NextRow
				}
				while !${GetMTMInfo.LastRow} && (${PrimaryWeap.TargetList.Used} < 4)
				GetMTMInfo:Finalize
			}		
		}
		PrimaryWeap:RequestUpdate
		DroneTargets:RequestUpdate
	}
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
			if ${PrimaryWeap.LockedTargetList.Get[1]} > 0 && ${Entity[${PrimaryWeap.LockedTargetList.Get[1]}](exists)}
			{
				CurrentOffenseTarget:Set[${PrimaryWeap.LockedTargetList.Get[1]}]
				GetATInfo:Set[${CombatComputer.CombatData.ExecQuery["SELECT * FROM AmmoTable WHERE EntityID=${CurrentOffenseTarget} AND AmmoTypeID=${Ship.ModuleList_Weapon.ChargeTypeID};"]}]
				CurrentOffenseTargetExpectedShots:Set[${Math.Calc[${GetATInfo.GetFieldValue["ShotsToKill",int64]}/${Config.WeaponCount}]}]
				if ${Entity[${CurrentOffenseTarget}].Name.Find[${Mission.CurrentAgentDestroy}]} && ${Mission.CurrentAgentDestroy.NotNULLOrEmpty}
					CurrentOffenseTargetExpectedShots:Set[9999999]
				This:LogInfo["${Entity[${CurrentOffenseTarget}].Name} is expected to require ${CurrentOffenseTargetExpectedShots} Salvos to kill with current ammo"]
			}
		
		}
		; Second and a halfly, we will periodically recheck the categorization of our CurrentOffenseTarget
		if ${CurrentOffenseTarget} > 0 && ${Entity[${CurrentOffenseTarget}](exists)}
		{
			GetMTMInfo:Set[${MTMDB.ExecQuery["SELECT * FROM Targeting WHERE EntityID=${CurrentOffenseTarget} AND TargetingCategory LIKE '%Primary%' OR TargetingCategory LIKE '%MissionTarget%';"]}]
			if ${GetMTMInfo.NumRows} > 0
			{
				; We have a row, that means this entity is still in a valid category for PrimaryWeaps
				GetMTMInfo:Finalize
			}
			else
			{
				; No row, probably means this entity is now in a different category. Kick it out of the TargetList and reset CurrentOffenseTarget to 0
				This:LogInfo["Wrong Category removing ${Entity[${CurrentOffenseTarget}].Name} from PrimaryWeap TargetList."]
				PrimaryWeap.TargetList:Remove[${CurrentOffenseTarget}]
				CurrentOffenseTarget:Set[0]
			}
		}
		if ${CurrentOffenseTarget} > 0 && ${Entity[${CurrentOffenseTarget}].IsLockedTarget}
		{
			; Thirdly, do we have any inactive combat utility modules? Target painter, web, grapple.
			if ${Ship.ModuleList_StasisGrap.InactiveCount} > 0 && ${Entity[${CurrentOffenseTarget}].Distance} < 19500
			{
				Ship.ModuleList_StasisGrap:ActivateAll[${CurrentOffenseTarget}]
			}
			if ${Ship.ModuleList_StasisWeb.InactiveCount} > 0 && ${Entity[${CurrentOffenseTarget}].Distance} <= ${Ship.ModuleList_StasisWeb.Range}
			{
				Ship.ModuleList_StasisWeb:ActivateAll[${CurrentOffenseTarget}]
			}
			if ${Entity[${CurrentOffenseTarget}].Distance} <= 140000
			{
				Ship.ModuleList_TargetPainter:ActivateAll[${CurrentOffenseTarget}]
			}
			; Fourthly, do we have any inactive weapons?
			if ${Ship.ModuleList_Weapon.InactiveCount} > 0
			{
				Ship.ModuleList_Weapon:ActivateAll[${CurrentOffenseTarget}]
				Ship.ModuleList_TrackingComputer:ActivateFor[${CurrentOffenseTarget}]			
			}
		}
	
	}
	; This method will handle combat dronery, someday. For now we will just fork over the target lists to DroneControl. 
	method CombatDronery()
	{
	
	
	}

}