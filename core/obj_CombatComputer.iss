objectdef obj_CombatComputer
{
	; This will be the DB where our character specific ship info lives.
	variable sqlitedb CombatData
	; This will be our query 
	variable sqlitequery GetCurrentData
	; Need another query for our Ship2 DB
	variable sqlitequery GetShipInfo
	; Index for CurrentData Transactions
	variable index:string CurrentDataTransactionIndex
	; Index for AmmoTable Transactions
	variable index:string AmmoTableTransactionIndex	
	
	; This will be a collection containing the available Ammo Type IDs, Key will be the Ammo Name, Value will be Type ID of the ammo
	variable collection:int64 AmmoCollection
	; This int will describe the minimum amount of ammo to be considered for the Ammo stuff.
	variable int MinAmmoAmount
	; This float is the time it takes to reload your weapon.
	variable float64 ChangeTime
	
	variable index:int64 ActiveNPCIndex

	
	
	method Initialize()
	{
		;CombatData:Set[${SQLite.OpenDB["CombatData",":memory:"]}]
		;;; Going to try making this DB reside in memory instead. We are going to be writing and reading to this fucker a gazillion times a second probably. Also the information is meant to be destroyed at the end
		;;; not going to be pulling any stats from this specific DB.
		;;; Addendum, at first I need to see the results of this table, lets see how poorly this goes.
		CombatData:Set[${SQLite.OpenDB["${Me.Name}CombatData","${Script.CurrentDirectory}/Data/${Me.Name}CombatData.sqlite3"]}]
		CombatData:ExecDML["PRAGMA journal_mode=WAL;"]
		if !${CombatData.TableExists["CurrentData"]}
		{
			echo DEBUG - CombatComputer - Creating CurrentData Table
			CombatData:ExecDML["create table CurrentData (EntityID INTEGER PRIMARY KEY, NPCName TEXT, NPCTypeID INTEGER, CurDist REAL, FtrDist REAL, CurVel REAL, MaxVel REAL, CruiseVel REAL, NeutRng REAL, NeutStr REAL, EWARType TEXT, EWARStr REAL, EWARRng REAL, WebRng REAL, WrpDisRng REAL, WrpScrRng REAL, EffNPCDPS REAL, ThreatLevel INTEGER);"]
		}
		; This table will relate our ammo effectiveness against each NPC. 
		if !${CombatData.TableExists["AmmoTable"]}
		{
			echo DEBUG - CombatComputer - Creating AmmoTable
			CombatData:ExecDML["create table AmmoTable (EntityID INTEGER NOT NULL, AmmoTypeID INTEGER NOT NULL, AmmoName TEXT, ExpectedShotDmg REAL, ShotsToKill REAL, TimeToKill REAL, OurDamageEff REAL, ChangeTime REAL, PRIMARY KEY(EntityID, AmmoTypeID));"]
		}
	}
 
	method Shutdown()
	{
	
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
	
	; One DB method to rule them all
	method UpsertCurrentData()
	{
		echo DEBUG COMBAT COMPUTER UCD ${ActiveNPCIndex.Used}
		
		if !${ActiveNPCIndex.Used}
			return
		variable iterator EntityIDIterator
		ActiveNPCIndex:GetIterator[EntityIDIterator]
		if ${EntityIDIterator:First(exists)}
		do
		{
			if !${Entity[${EntityIDIterator.Value}](exists)}
				continue
			;echo (${EntityIDIterator.Value}, '${This.NPCName[${EntityIDIterator.Value}].ReplaceSubstring[','']}', ${This.NPCTypeID[${EntityIDIterator.Value}]}, ${This.NPCCurrentDist[${EntityIDIterator.Value}]}, ${This.NPCFutureDist[${EntityIDIterator.Value}]}, ${This.NPCCurrentVel[${EntityIDIterator.Value}]}, ${This.NPCMaximumVel[${EntityIDIterator.Value}]}, ${This.NPCCruiseVel[${EntityIDIterator.Value}]}, ${This.NPCNeutRange[${EntityIDIterator.Value}]}, ${This.NPCNeutAmount[${EntityIDIterator.Value}]}, '${This.NPCEWARType[${EntityIDIterator.Value}]}', ${This.NPCEWARStrength[${EntityIDIterator.Value}]}, ${This.NPCEWARRange[${EntityIDIterator.Value}]}, ${This.NPCWebRange[${EntityIDIterator.Value}]}, ${This.NPCDisruptRange[${EntityIDIterator.Value}]}, ${This.NPCScramRange[${EntityIDIterator.Value}]}, ${This.NPCDPSOutput[${EntityIDIterator.Value}]}, ${This.NPCThreatLevel[${EntityIDIterator.Value}]})	
			;echo ${This.NPCDPSOutput[${EntityIDIterator.Value}]}
			CurrentDataTransactionIndex:Insert["insert into CurrentData (EntityID, NPCName, NPCTypeID, CurDist, FtrDist, CurVel, MaxVel, CruiseVel, NeutRng, NeutStr, EWARType, EWARStr, EWARRng, WebRng, WrpDisRng, WrpScrRng, EffNPCDPS, ThreatLevel) values (${EntityIDIterator.Value}, '${This.NPCName[${EntityIDIterator.Value}].ReplaceSubstring[','']}', ${This.NPCTypeID[${EntityIDIterator.Value}]}, ${This.NPCCurrentDist[${EntityIDIterator.Value}]}, ${This.NPCFutureDist[${EntityIDIterator.Value}]}, ${This.NPCCurrentVel[${EntityIDIterator.Value}]}, ${This.NPCMaximumVel[${EntityIDIterator.Value}]}, ${This.NPCCruiseVel[${EntityIDIterator.Value}]}, ${This.NPCNeutRange[${EntityIDIterator.Value}]}, ${This.NPCNeutAmount[${EntityIDIterator.Value}]}, '${This.NPCEWARType[${EntityIDIterator.Value}]}', ${This.NPCEWARStrength[${EntityIDIterator.Value}]}, ${This.NPCEWARRange[${EntityIDIterator.Value}]}, ${This.NPCWebRange[${EntityIDIterator.Value}]}, ${This.NPCDisruptRange[${EntityIDIterator.Value}]}, ${This.NPCScramRange[${EntityIDIterator.Value}]}, ${This.NPCDPSOutput[${EntityIDIterator.Value}]}, ${This.NPCThreatLevel[${EntityIDIterator.Value}]}) ON CONFLICT (EntityID) DO UPDATE SET CurDist=excluded.CurDist, CurVel=excluded.CurVel, EffNPCDps=excluded.EffNPCDPS, ThreatLevel=excluded.ThreatLevel;"]
		}
		while ${EntityIDIterator:Next(exists)}
		
		CombatData:ExecDMLTransaction[CurrentDataTransactionIndex]
		CurrentDataTransactionIndex:Clear
		This:UpsertAmmoTable
	}
	
	; I lied, another table exists.
	method UpsertAmmoTable()
	{
		echo DEBUG COMBAT COMPUTER UAT
		if !${ActiveNPCIndex.Used}
			return
		variable iterator EntityIDIterator
		ActiveNPCIndex:GetIterator[EntityIDIterator]
		if ${EntityIDIterator:First(exists)}
		do
		{
			if !${Entity[${EntityIDIterator.Value}](exists)}
				continue
			variable iterator AmmoCollectionIterator
			echo ${AmmoCollection.Size} AMMO COLLECTION SIZE
			if ${AmmoCollection.Size} < 1
				return
			AmmoCollection:GetIterator[AmmoCollectionIterator]
			if ${AmmoCollectionIterator:First(exists)}
			{
				do
				{
					echo DEBUG AMMOTABLE (${EntityIDIterator.Value}, ${AmmoCollectionIterator.Value}, '${AmmoCollectionIterator.Key.ReplaceSubstring[','']}', ${This.ExpectedShotDmg[${EntityIDIterator.Value}, ${AmmoCollectionIterator.Value}, "ExpectedShotDmg"]}, ${This.ExpectedShotDmg[${EntityIDIterator.Value}, ${AmmoCollectionIterator.Value}, "ShotsToKill"]}, ${This.ExpectedShotDmg[${EntityIDIterator.Value}, ${AmmoCollectionIterator.Value}, "TimeToKill"]} ,${This.ExpectedShotDmg[${EntityIDIterator.Value}, ${AmmoCollectionIterator.Value}, "OurDamageEff"]}, ${ChangeTime})
					AmmoTableTransactionIndex:Insert["insert into AmmoTable (EntityID, AmmoTypeID, AmmoName, ExpectedShotDmg, ShotsToKill, TimeToKill, OurDamageEff, ChangeTime) values (${EntityIDIterator.Value}, ${AmmoCollectionIterator.Value}, '${AmmoCollectionIterator.Key.ReplaceSubstring[','']}', ${This.ExpectedShotDmg[${EntityIDIterator.Value}, ${AmmoCollectionIterator.Value}, "ExpectedShotDmg"]}, ${This.ExpectedShotDmg[${EntityIDIterator.Value}, ${AmmoCollectionIterator.Value}, "ShotsToKill"]}, ${This.ExpectedShotDmg[${EntityIDIterator.Value}, ${AmmoCollectionIterator.Value}, "TimeToKill"]} ,${This.ExpectedShotDmg[${EntityIDIterator.Value}, ${AmmoCollectionIterator.Value}, "OurDamageEff"]}, ${ChangeTime}) ON CONFLICT (EntityID, AmmoTypeID) DO UPDATE SET ExpectedShotDmg=excluded.ExpectedShotDmg, ShotsToKill=excluded.ShotsToKill, TimeToKill=excluded.TimeToKill, OurDamageEff=excluded.OurDamageEff;"]
					;echo plz hold
				}
				while ${AmmoCollectionIterator:Next(exists)}
			}
		}
		while ${EntityIDIterator:Next(exists)}
		
		CombatData:ExecDMLTransaction[AmmoTableTransactionIndex]
		AmmoTableTransactionIndex:Clear
		ActiveNPCIndex:Clear
	}
	
	; And a method to remove things that don't belong here anymore.
	; We won't be employing this just yet. Also it isn't built yet.
	method CleanupTables()
	{
		; Well, if it doesn't exist, kick it from the Table and move on.
		if !${Entity[${EntityID}](exists)}
		{
			This:LogInfo["CombatComputer - Removing Entity ${EntityID} From Table"]
			CombatData:ExecDML["Delete FROM AmmoTable WHERE EntityID=${EntityID};"]
			return
		}
		if !${Entity[${EntityID}](exists)}
		{
			This:LogInfo["CombatComputer - Removing Entity ${EntityID} From Table"]
			CombatData:ExecDML["Delete FROM CurrentData WHERE EntityID=${EntityID};"]
			return
		}
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
		
		FinalValue:Set[${NPCData.EnemyEnergyNeutRange[${This.NPCTypeID[${EntityID}]}]}]
		return ${FinalValue}
	}
	
	; This member will return the Energy Neut Strength of a given Enemy
	member:float64 NPCNeutAmount(int64 EntityID)
	{
		variable float64 FinalValue
		
		FinalValue:Set[${NPCData.EnemyEnergyNeutAmount[${This.NPCTypeID[${EntityID}]}]}]
		return ${FinalValue}
	}
	
	; This member will return the EWAR Type of a given enemy.
	member:string NPCEWARType(int64 EntityID)
	{
		variable string FinalValue
		
		if ${NPCData.EnemyUsesECM[${This.NPCTypeID[${EntityID}]}]}
			FinalValue:Concat["ECM"]
		if ${NPCData.EnemyUsesPainters[${This.NPCTypeID[${EntityID}]}]}
			FinalValue:Concat["Painter"]
		if ${NPCData.EnemyUsesGuidanceDisruption[${This.NPCTypeID[${EntityID}]}]} && ${Ship.ModuleList_MissileLauncher.Count} > 0
			FinalValue:Concat["Guidance"]
		if ${NPCData.EnemyUsesTrackingDisruption[${This.NPCTypeID[${EntityID}]}]} && ${Ship.ModuleList_Turret.Count} > 0
			FinalValue:Concat["Tracking"]
		if ${NPCData.EnemySensorDampRange[${This.NPCTypeID[${EntityID}]}]} > 0
			FinalValue:Concat["Damp"]
		if !${FinalValue.NotNULLOrEmpty}
			return NONE
		else
			return "${FinalValue}"
	}

	; This member will return the EWAR Strength of a given enemy.
	member:float64 NPCEWARStrength(int64 EntityID)
	{
		variable float64 FinalValue
		
		if ${NPCData.EnemySensorDampRange[${This.NPCTypeID[${EntityID}]}]} > 0
			FinalValue:Set[${NPCData.EnemySensorDampStrength[${This.NPCTypeID[${EntityID}]}]}]
		else
			FinalValue:Set[0]
		return ${FinalValue}		
	}
	
	; This member will return EWAR range of a given enemy
	member:float64 NPCEWARRange(int64 EntityID)
	{
		variable float64 FinalValue
		
		if ${NPCData.EnemySensorDampRange[${This.NPCTypeID[${EntityID}]}]} > 0
			FinalValue:Set[${NPCData.EnemySensorDampRange[${This.NPCTypeID[${EntityID}]}]}]
		else
			FinalValue:Set[0]
		return ${FinalValue}
	}
	
	; This member will return the Stasis Web Range of a given enemy
	member:float64 NPCWebRange(int64 EntityID)
	{
		variable float64 FinalValue
		
		FinalValue:Set[${NPCData.EnemyStasisWebRange[${This.NPCTypeID[${EntityID}]}]}]
		return ${FinalValue}	
	}
	
	; This member will return the Warp Disruptor Range of a given enemy.
	member:float64 NPCDisruptRange(int64 EntityID)
	{
		variable float64 FinalValue
		
		FinalValue:Set[${NPCData.EnemyWarpDisruptorRange[${This.NPCTypeID[${EntityID}]}]}]
		return ${FinalValue}		
	}
	
	; This member will return the Warp Scrambler Range of a given enemy.
	member:float64 NPCScramRange(int64 EntityID)
	{
		variable float64 FinalValue
		
		FinalValue:Set[${NPCData.EnemyWarpScramblerRange[${This.NPCTypeID[${EntityID}]}]}]
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
			NPCTurretDPSMod:Set[${Math.Calc[0.5 * (${Utility.Min[${Math.Calc[(${NPCChanceToHit}^^2) + (0.98 * ${NPCChanceToHit}) + 0.0501]}, ${Math.Calc[${NPCChanceToHit}*6]}]})]}]
			echo NPCDPSOUTPUT[" NPCDPSOUTPUT CHANCETOHIT ${NPCChanceToHit}"]
			echo NPCDPSOUTPUT[" NPCDPSOUTPUT  NPCTurretDPSMod ${Math.Calc[0.5 * (${Utility.Min[${Math.Calc[(${NPCChanceToHit}^^2) + (0.98 * ${NPCChanceToHit}) + 0.0501]}, ${Math.Calc[${NPCChanceToHit}*6]}]})]}]"]
			;TurretDmgMod:Set[${Math.Calc[0.5 * (${Utility.Min[${Math.Calc[(${ChanceToHit}^^2) + (0.98 * ${ChanceToHit}) + 0.0501]}, ${Math.Calc[${ChanceToHit}*6]}]})]}]
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
			NPCMissileDPSMod:Set[${Utility.Min[${RadiusFactor}, ${VelocityFactor}]}]
			NPCMissileDPSMod:Set[${Utility.Min[1, ${NPCMissileDPSMod}]}]
			echo DPSOUTPUT NPCMISSILEDPSMOD ${NPCMissileDPSMod}
		}
		; Our Ship's tanking layer resists.
		; Going to have to manually config these, we can't actually read the resists of our ship? Ugh.
		variable float64 TankLayerEMRes 
		TankLayerEMRes:Set[${Math.Calc[1 - ${MissionTargetManager.Config.TankLayerEMResist}]}]
		TankLayerEMRes:Set[0.28]
		variable float64 TankLayerExpRes 
		TankLayerExpRes:Set[${Math.Calc[1 - ${MissionTargetManager.Config.TankLayerExpResist}]}]
		TankLayerExpRes:Set[0.3]
		variable float64 TankLayerKinRes 
		TankLayerKinRes:Set[${Math.Calc[1 - ${MissionTargetManager.Config.TankLayerKinResist}]}]
		TankLayerKinRes:Set[0.3]
		variable float64 TankLayerThermRes 
		TankLayerThermRes:Set[${Math.Calc[1 - ${MissionTargetManager.Config.TankLayerThermResist}]}]
		TankLayerThermRes:Set[0.28]
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
		return ${FinalValue}
	}
	
	; This member, if I can get it done, will return the Threat Level of a given enemy.
	member:int64 NPCThreatLevel(int64 EntityID)
	{
		variable int64 FinalValue
		
		return 9999
		
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
		variable collection:string DmgPMCollection
		; Need this for the Shots to Kill return
		variable int ShotCounter
		; Need these for both the Shots to Kill return and the Time to Kill return
		variable float64 TimeBetweenShots
		echo EXPECTEDSHOTDMG ${EntityID} ${AmmoID} ${ReqInfo}
		if ${Ship.ModuleList_Turret.Count} > 0
		{
			echo EXPECTEDSHOTDMG NOT MISSL
			GetShipInfo:Set[${Ship2.MyShipInfo.ExecQuery["Select * FROM ShipAmmunitionTurret WHERE AmmoTypeID=${AmmoID};"]}]
			Missl:Set[FALSE]
		}
		if ${Ship.ModuleList_MissileLauncher.Count} > 0
		{
			echo EXPECTEDSHOTDMG MISSL
			GetShipInfo:Set[${Ship2.MyShipInfo.ExecQuery["Select * FROM ShipAmmunitionMissile WHERE AmmoTypeID=${AmmoID};"]}]
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
		NPCSigRad:Set[${Entity[${EntityID}].Radius}]
		variable float64 NPCVeloc
		NPCVeloc:Set[${Entity[${EntityID}].Velocity}]
		variable float64 NPCDist 
		NPCDist:Set[${Entity[${EntityID}].Distance}]
		; Turret Calcs
		variable float64 ChanceToHit
		; Normalized DPS=0.5 × min(Hit chance^2 + 0.98 × Hit chance + 0.0501, 6 × Hit chance)
		variable float64 TurretDmgMod
		if !${Missl}
		{
			ChanceToHit:Set[${This.TurretChanceToHit[${EntityID},${TurretTrack},${TurretOpt},${TurretFall},TRUE]}]
			echo ${ChanceToHit} CHANCETOHIT
			TurretDmgMod:Set[${Math.Calc[0.5 * (${Utility.Min[${Math.Calc[(${ChanceToHit}^^2) + (0.98 * ${ChanceToHit}) + 0.0501]}, ${Math.Calc[${ChanceToHit}*6]}]})]}]
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
			if !${NPCVel.Equal[0]}
				VelocityFactor:Set[${Math.Calc[(${RadiusFactor} * ${MisslExpVel} / ${NPCVel}) ^^ ${MisslDRF}]}]
			else
				VelocityFactor:Set[1]
			MissileDmgMod:Set[${Utility.Min[${RadiusFactor}, ${VelocityFactor}]}]
			MissileDmgMod:Set[${Utility.Min[1, ${MissileDmgMod}]}]
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
			echo ${Math.Calc[${AmmoDmgEM}*${MissileDmgMod}].Int.LeadingZeroes[8]},EM
			DmgPMCollection:Set[${Math.Calc[${AmmoDmgExp}*${MissileDmgMod}].Int.LeadingZeroes[8]},Exp]
			echo ${Math.Calc[${AmmoDmgExp}*${MissileDmgMod}].Int.LeadingZeroes[8]},Exp
			DmgPMCollection:Set[${Math.Calc[${AmmoDmgKin}*${MissileDmgMod}].Int.LeadingZeroes[8]},Kin]
			echo ${Math.Calc[${AmmoDmgKin}*${MissileDmgMod}].Int.LeadingZeroes[8]},Kin
			DmgPMCollection:Set[${Math.Calc[${AmmoDmgTherm}*${MissileDmgMod}].Int.LeadingZeroes[8]},Therm]
			echo ${Math.Calc[${AmmoDmgTherm}*${MissileDmgMod}].Int.LeadingZeroes[8]},Therm
		}
		; Need these for ROF kinda stuff. We have a Bastion Module and it is On, or we don't have one at all, use the current ROF.
		if ${Ship.ModuleList_Siege.ActiveCount} > 0 || ${Ship.ModuleList_Siege.Count} < 1
			TimeBetweenShots:Set[${Ship.ModuleList_Weapon.RateOfFire}]
		; We have a bastion module and it is off. Pretend it is on. It is supposedly stacking penalized but from the numbers I'm looking at it doesn't seem to be. ROF Cuts in half.
		if ${Ship.ModuleList_Siege.ActiveCount} == 0 && ${Ship.ModuleList_Siege.Count} > 0
			TimeBetweenShots:Set[${Math.Calc[${Ship.ModuleList_Weapon.RateOfFire} * 0.5]}]
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
		; Need to store those HP values twice.
		variable float64 NPCShieldHPStart 
		NPCShieldHPStart:Set[${NPCShieldHP}]
		variable float64 NPCArmorHPStart 
		NPCArmorHP:Set[${NPCArmorHP}]
		variable float64 NPCHullHPStart 
		NPCHullHPStart:Set[${NPCHullHP}]
		; I'm not sure anymore.
		variable float64 LowestDmgNmbr
		
		if ${DmgPMCollection.FirstKey(exists)}
		{
			echo ${DmgPMCollection.FirstKey) DMGPMCOLLECTION FIRSTKEY
			do
			{
				LowestDmgNmbr:Set[${DmgPMCollection.CurrentKey}]
			}
			while ${LowestDmgNmbr} == 0 && ${DmgPMCollection.NextKey(exists)}
		}
		variable float64 EMDec 
		EMDec:Set[${Math.Calc[${AmmoDmgEMPM}/${LowestDmgNmbr}]}]
		variable float64 ExpDec 
		ExpDec:Set[${Math.Calc[${AmmoDmgExpPM}/${LowestDmgNmbr}]}]
		variable float64 KinDec 
		KinDec:Set[${Math.Calc[${AmmoDmgKinPM}/${LowestDmgNmbr}]}]
		variable float64 ThermDec 
		ThermDec:Set[${Math.Calc[${AmmoDmgThermPM}/${LowestDmgNmbr}]}]
		; Now, some math... I don't know what I'm doing here exactly so I'm going to be reinventing math as we go.
		; Need a case switch here now that this member has 4 purposes, 1 purpose completed above so 3 cases below.
		; Shots to kill may be a little inaccurate, if we don't factor in the enemy's repair ability...
		; Going to forgo that for the moment.
		switch ${ReqInfo}
		{
			case ExpectedShotDmg
			{
				while ${NPCShieldHP} > 0 && (${AmmoDmgEMPM} > 0 || ${AmmoDmgExpPM} > 0 || ${AmmoDmgKinPM} > 0 || ${AmmoDmgThermPM} > 0)
				{
					NPCShieldHP:Set[${Math.Calc[${NPCShieldHP} - ((${EMDec} * ${NPCShieldEMRes}) + (${ExpDec} * ${NPCShieldExpRes}) + (${KinDec} * ${NPCShieldKinRes}) + (${ThermDec} * ${NPCShieldThermRes}))]}]
					AmmoDmgEMPM:Set[${Math.Calc[${AmmoDmgEMPM} - ${EMDec}]}]
					AmmoDmgExpPM:Set[${Math.Calc[${AmmoDmgExpPM} - ${ExpDec}]}]
					AmmoDmgKinPM:Set[${Math.Calc[${AmmoDmgKinPM} - ${KinDec}]}]
					AmmoDmgThermPM:Set[${Math.Calc[${AmmoDmgThermPM} - ${ThermDec}]}]
				}
				if ${NPCShieldHP} > 0
					return ${Math.Calc[${NPCShieldHPStart} - ${NPCShieldHP}]}
				while ${NPCArmorHP} > 0 && (${AmmoDmgEMPM} > 0 || ${AmmoDmgExpPM} > 0 || ${AmmoDmgKinPM} > 0 || ${AmmoDmgThermPM} > 0)
				{
					NPCArmorHP:Set[${Math.Calc[${NPCArmorHP} - ((${EMDec} * ${NPCArmorEMRes}) + (${ExpDec} * ${NPCArmorExpRes}) + (${KinDec} * ${NPCArmorKinRes}) + (${ThermDec} * ${NPCArmorThermRes}))]}]
					AmmoDmgEMPM:Set[${Math.Calc[${AmmoDmgEMPM} - ${EMDec}]}]
					AmmoDmgExpPM:Set[${Math.Calc[${AmmoDmgExpPM} - ${ExpDec}]}]
					AmmoDmgKinPM:Set[${Math.Calc[${AmmoDmgKinPM} - ${KinDec}]}]
					AmmoDmgThermPM:Set[${Math.Calc[${AmmoDmgThermPM} - ${ThermDec}]}]
				}
				if ${NPCArmorHP} > 0
					return ${Math.Calc[(${NPCArmorHPStart} - ${NPCArmorHP}) + ${NPCShieldHPStart}]}
				while ${NPCHullHP} > 0 && (${AmmoDmgEMPM} > 0 || ${AmmoDmgExpPM} > 0 || ${AmmoDmgKinPM} > 0 || ${AmmoDmgThermPM} > 0)
				{
					NPCHullHP:Set[${Math.Calc[${NPCHullHP} - ((${EMDec} * ${NPCHullEMRes}) + (${ExpDec} * ${NPCHullExpRes}) + (${KinDec} * ${NPCHullKinRes}) + (${ThermDec} * ${NPCHullThermRes}))]}]
					AmmoDmgEMPM:Set[${Math.Calc[${AmmoDmgEMPM} - ${EMDec}]}]
					AmmoDmgExpPM:Set[${Math.Calc[${AmmoDmgExpPM} - ${ExpDec}]}]
					AmmoDmgKinPM:Set[${Math.Calc[${AmmoDmgKinPM} - ${KinDec}]}]
					AmmoDmgThermPM:Set[${Math.Calc[${AmmoDmgThermPM} - ${ThermDec}]}]
				}
				if ${NPCHullHP} > 0
					return ${Math.Calc[(${NPCHullHPStart} - ${NPCHullHP}) + ${NPCArmorHPStart} + ${NPCShieldHPStart}]}
				; If we got here it means it died, and we had damage to spare. Overkill, if you will.
				if (${AmmoDmgEMPM} > 0 || ${AmmoDmgExpPM} > 0 || ${AmmoDmgKinPM} > 0 || ${AmmoDmgThermPM} > 0)
					This:LogDebug["Entity ${Entity[${EntityID}].Name} will be destroyed with ${Math.Calc[(${AmmoDmgEMPM} + ${AmmoDmgExpPM} + ${AmmoDmgKinPM} + ${AmmoDmgThermPM})]} Excess Damage"]
				return ${Math.Calc[${NPCHullHPStart} + ${NPCArmorHPStart} + ${NPCShieldHPStart}]}
			}
			case ShotsToKrill
			{
				; Adding the Damage checks back in here to ensure we don't get looped forever.
				while ${NPCShieldHP} > 0 && (${AmmoDmgEMPM} > 0 || ${AmmoDmgExpPM} > 0 || ${AmmoDmgKinPM} > 0 || ${AmmoDmgThermPM} > 0)
				{
					NPCShieldHP:Set[${Math.Calc[${NPCShieldHP} - ((${EMDec} * ${NPCShieldEMRes}) + (${ExpDec} * ${NPCShieldExpRes}) + (${KinDec} * ${NPCShieldKinRes}) + (${ThermDec} * ${NPCShieldThermRes}))]}]
					ShotCounter:Inc[1]
				}
				while ${NPCArmorHP} > 0 && (${AmmoDmgEMPM} > 0 || ${AmmoDmgExpPM} > 0 || ${AmmoDmgKinPM} > 0 || ${AmmoDmgThermPM} > 0)
				{
					NPCArmorHP:Set[${Math.Calc[${NPCArmorHP} - ((${EMDec} * ${NPCArmorEMRes}) + (${ExpDec} * ${NPCArmorExpRes}) + (${KinDec} * ${NPCArmorKinRes}) + (${ThermDec} * ${NPCArmorThermRes}))]}]
					ShotCounter:Inc[1]
				}
				while ${NPCHullHP} > 0 && (${AmmoDmgEMPM} > 0 || ${AmmoDmgExpPM} > 0 || ${AmmoDmgKinPM} > 0 || ${AmmoDmgThermPM} > 0)
				{
					NPCHullHP:Set[${Math.Calc[${NPCHullHP} - ((${EMDec} * ${NPCHullEMRes}) + (${ExpDec} * ${NPCHullExpRes}) + (${KinDec} * ${NPCHullKinRes}) + (${ThermDec} * ${NPCHullThermRes}))]}]
					ShotCounter:Inc[1]
				}
				This:LogDebug["Entity ${Entity[${EntityID}].Name} will be destroyed with ${ShotCounter} Shots"]
				return ${ShotCounter}
			}
			case TimeToKrill
			{
				; Adding the Damage checks back in here to ensure we don't get looped forever.
				while ${NPCShieldHP} > 0 && (${AmmoDmgEMPM} > 0 || ${AmmoDmgExpPM} > 0 || ${AmmoDmgKinPM} > 0 || ${AmmoDmgThermPM} > 0)
				{
					NPCShieldHP:Set[${Math.Calc[${NPCShieldHP} - ((${EMDec} * ${NPCShieldEMRes}) + (${ExpDec} * ${NPCShieldExpRes}) + (${KinDec} * ${NPCShieldKinRes}) + (${ThermDec} * ${NPCShieldThermRes}))]}]
					ShotCounter:Inc[1]
				}
				while ${NPCArmorHP} > 0 && (${AmmoDmgEMPM} > 0 || ${AmmoDmgExpPM} > 0 || ${AmmoDmgKinPM} > 0 || ${AmmoDmgThermPM} > 0)
				{
					NPCArmorHP:Set[${Math.Calc[${NPCArmorHP} - ((${EMDec} * ${NPCArmorEMRes}) + (${ExpDec} * ${NPCArmorExpRes}) + (${KinDec} * ${NPCArmorKinRes}) + (${ThermDec} * ${NPCArmorThermRes}))]}]
					ShotCounter:Inc[1]
				}
				while ${NPCHullHP} > 0 && (${AmmoDmgEMPM} > 0 || ${AmmoDmgExpPM} > 0 || ${AmmoDmgKinPM} > 0 || ${AmmoDmgThermPM} > 0)
				{
					NPCHullHP:Set[${Math.Calc[${NPCHullHP} - ((${EMDec} * ${NPCHullEMRes}) + (${ExpDec} * ${NPCHullExpRes}) + (${KinDec} * ${NPCHullKinRes}) + (${ThermDec} * ${NPCHullThermRes}))]}]
					ShotCounter:Inc[1]
				}
				This:LogDebug["Entity ${Entity[${EntityID}].Name} will be destroyed in ${Math.Calc[${ShotCounter}*${TimeBetweenShots}]} Seconds "]
				return ${Math.Calc[${ShotCounter}*${TimeBetweenShots}]}
			}	
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
