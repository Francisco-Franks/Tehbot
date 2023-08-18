objectdef obj_Ship2
{
	; This will be the DB where our character specific ship info lives.
	variable sqlitedb MyShipInfo
	; This will be our query 
	variable sqlitequery GetShipInfo
	
	; Storage for AvailableAmmo Return
	variable index:item AvailableAmmoIndex
	variable iterator AvailableAmmoIterator
	
	; Storage for pre-insert variables
	variable float64 EMDamage
	variable float64 ThermDamage
	variable float64 KinDamage
	variable float64 ExpDamage
	
	variable float64 TrackingSpd
	variable float64 OptimalRng
	variable float64 FalloffRng
	
	variable float64 ExpRadius
	variable float64 ExpVel
	variable float64 FlightRange
	
	; Storage index for bulk DB insert
	variable index:string DBInsertIndex
	
	method Initialize()
	{
		Turbo 5000
		; We shouldnt need WAL on this, it is a DB intended to be accessed by a singular client.
		;;; Addendum, lies, lies, everything is a lie.
		
		MyShipInfo:Set[${SQLite.OpenDB["${Me.Name}ShipDB","${Script.CurrentDirectory}/Data/${Me.Name}ShipDB.sqlite3"]}]
		MyShipInfo:ExecDML["PRAGMA journal_mode=WAL;"]
		MyShipInfo:ExecDML["PRAGMA main.mmap_size=64000000"]
		MyShipInfo:ExecDML["PRAGMA main.cache_size=-64000;"]
		MyShipInfo:ExecDML["PRAGMA synchronous = normal;"]
		MyShipInfo:ExecDML["PRAGMA temp_store = memory;"]		
		
		
		; Ammunition table for turrets.
		; What belongs in this table?
		;  Ammo Type ID (Integer Primary Key), Ammo Type (String), Ship's Item Type (String), Turret Item Type (String), Turret Tracking (Real), Turret Optimal (Real), Turret Falloff (Real), EM Damage (Real), Explosive Damage (Real), Kinetic Damage (Real), Thermal Damage (Real).
		if !${MyShipInfo.TableExists["ShipAmmunitionTurret"]}
		{
			echo DEBUG - Ship2 - Creating ShipAmmunitionTurret
			MyShipInfo:ExecDML["create table ShipAmmunitionTurret (AmmoTypeID INTEGER PRIMARY KEY, AmmoType TEXT, ShipType TEXT, TurretType TEXT, EMDamage REAL, ExpDamage REAL, KinDamage REAL, ThermDamage REAL, TrackingSpd REAL, OptimalRng REAL, FalloffRng REAL);"]
		}
		; Ammunition table for missiles.
		; Ammo Type ID (Integer Primary Key), Ammo Type (String), Ship's Item Type (String), Launcher Item Type (String), Missile Explosion Velocity (Real), Missile Explosion Radius (Real), Missile Range (Real), EM Damage (Real), Explosive Damage (Real), Kinetic Damage (Real), Thermal Damage (Real).
		if !${MyShipInfo.TableExists["ShipAmmunitionMissile"]}
		{
			echo DEBUG - Ship2 - Creating ShipAmmunitionMissile
			MyShipInfo:ExecDML["create table ShipAmmunitionMissile (AmmoTypeID INTEGER PRIMARY KEY, AmmoType TEXT, ShipType TEXT, LauncherType TEXT, EMDamage REAL, ExpDamage REAL, KinDamage REAL, ThermDamage REAL, ExpRadius REAL, ExpVel REAL, FlightRange REAL);"]
		}

	}

	method Shutdown()
	{
	
		MyShipInfo:Close
	}
	;;; For now, I need a somewhat comprehensive solution very quickly. So I will return to my flights of fancy later.
	;;; Lets get some practical members in here. This first set of members is going to be about looking at our available ammunition, Taking the names and getting TypeIDs, then
	;;; feeding the TypeIDs to NPCData to get some information about the ammunition types. Things are going to be vaguely awkward for missiles, but turrets shouldn't be too bad. Probably.
	;;; We are looking to determine a few things here, how many shots from one SINGLE one of our weapons it will take to destroy an enemy, with each ammunition type. 
	;;; We are also looking to determine if we can even hit an enemy at all, with each ammunition type.
	;;; What do we need for these two things? We need to know Enemy EHP for each resist (we have that in obj_NPCData), we need to know how fast it is going currently (entity return), how fast it WILL be going
	;;; (obj_NPCData again), how far away it is (entity return), how far away it will be ultimately (obj_NPCData again), what our outgoing damage profile looks like (combination of Module returns and obj_NPCData) for each ammunition type.
	;;; We will be using one of the tables above, ShipAmmunitionTurret and ShipAmmunitionMissile to keep track of these things.
	;;; But first, a method.
	; This method will be responsible for the whole ammo info dump thing.
	method GetAmmoInformation()
	{
		WeaponSwitch:Set[${Ship.WeaponSwitch}]
		; This can only be done correctly in a ship, in space.
		if !${Client.InSpace}
			return FALSE
		; No pacifists plz
		if ${Ship.${WeaponSwitch}.Count} <= 0
			return FALSE
		This:SetMinimumAmmoAmount
		; Turrets. We want the four damage types/amounts, tracking, optimal, and falloff with the ammo. I think thats all.
		; Ammo Type ID (Integer Primary Key), Ammo Type (String), Ship's Item Type (String), Turret Item Type (String), Turret Tracking (Real), Turret Optimal (Real), Turret Falloff (Real), EM Damage (Real), Explosive Damage (Real), Kinetic Damage (Real), Thermal Damage (Real).
		if ${Ship.${WeaponSwitch}.Count} > 0 && ${Ship.ModuleList_MissileLauncher.Count} == 0
		{
			MyShip.Module[${Ship.${WeaponSwitch}.ID}]:GetAvailableAmmo[AvailableAmmoIndex]
			if ${AvailableAmmoIndex.Size} > 0
			AvailableAmmoIndex:GetIterator[AvailableAmmoIterator]
			if ${AvailableAmmoIterator:First(exists)}
			{
				do
				{
					if ${AvailableAmmoIterator.Value.Quantity} < ${CombatComputer.MinAmmoAmount}
						continue
					EMDamage:Set[${Math.Calc[${NPCData.PlayerAmmoEM[${AvailableAmmoIterator.Value.TypeID}]}*${Ship.${WeaponSwitch}.DamageModifier}]}]
					ExpDamage:Set[${Math.Calc[${NPCData.PlayerAmmoExp[${AvailableAmmoIterator.Value.TypeID}]}*${Ship.${WeaponSwitch}.DamageModifier}]}]
					KinDamage:Set[${Math.Calc[${NPCData.PlayerAmmoKin[${AvailableAmmoIterator.Value.TypeID}]}*${Ship.${WeaponSwitch}.DamageModifier}]}]
					ThermDamage:Set[${Math.Calc[${NPCData.PlayerAmmoTherm[${AvailableAmmoIterator.Value.TypeID}]}*${Ship.${WeaponSwitch}.DamageModifier}]}]
					TrackingSpd:Set[${Math.Calc[${NPCData.PlayerTrackingMult[${AvailableAmmoIterator.Value.TypeID}]}*${Ship.${WeaponSwitch}.TrackingSpeed}]}]
					OptimalRng:Set[${Math.Calc[${NPCData.PlayerRangeMult[${AvailableAmmoIterator.Value.TypeID}]}*${Ship.${WeaponSwitch}.OptimalRange}]}]
					FalloffRng:Set[${Math.Calc[${NPCData.PlayerRangeMult[${AvailableAmmoIterator.Value.TypeID}]}*${Ship.${WeaponSwitch}.AccuracyFalloff}]}]
				
					echo ${EMDamage} ${ExpDamage} ${KinDamage} ${ThermDamage} ${TrackingSpd} ${OptimalRng} ${FalloffRng}
					DBInsertIndex:Insert["insert into ShipAmmunitionTurret (AmmoTypeID, AmmoType, ShipType, TurretType, EMDamage, ExpDamage, KinDamage, ThermDamage, TrackingSpd, OptimalRng, FalloffRng) values (${AvailableAmmoIterator.Value.TypeID}, '${AvailableAmmoIterator.Value.Type.ReplaceSubstring[','']}', '${MyShip.ToEntity.Type.ReplaceSubstring[','']}', '${Ship.${WeaponSwitch}.Type.ReplaceSubstring[','']}', ${EMDamage}, ${ExpDamage}, ${KinDamage}, ${ThermDamage}, ${TrackingSpd}, ${OptimalRng}, ${FalloffRng}) ON CONFLICT (AmmoTypeID) DO UPDATE SET ShipType=excluded.ShipType, TurretType=excluded.TurretType, EMDamage=excluded.EMDamage, ExpDamage=excluded.ExpDamage, KinDamage=excluded.KinDamage, ThermDamage=excluded.ThermDamage, TrackingSpd=excluded.TrackingSpd, OptimalRng=excluded.OptimalRng, FalloffRng=excluded.FalloffRng;"]
					CombatComputer.AmmoCollection:Set[${AvailableAmmoIterator.Value.Name},${AvailableAmmoIterator.Value.TypeID}]
				}
				while ${AvailableAmmoIterator:Next(exists)}
			}
			if ${Ship.${WeaponSwitch}.Charge.Type.NotNULLOrEmpty}
			{
				if ${MyShip.Cargo[${Ship.${WeaponSwitch}.Charge.Type}](exists)}
				{
					EMDamage:Set[${Math.Calc[${NPCData.PlayerAmmoEM[${MyShip.Cargo[${Ship.${WeaponSwitch}.Charge.Type}].TypeID}]}*${Ship.${WeaponSwitch}.DamageModifier}]}]
					ExpDamage:Set[${Math.Calc[${NPCData.PlayerAmmoExp[${MyShip.Cargo[${Ship.${WeaponSwitch}.Charge.Type}].TypeID}]}*${Ship.${WeaponSwitch}.DamageModifier}]}]
					KinDamage:Set[${Math.Calc[${NPCData.PlayerAmmoKin[${MyShip.Cargo[${Ship.${WeaponSwitch}.Charge.Type}].TypeID}]}*${Ship.${WeaponSwitch}.DamageModifier}]}]
					ThermDamage:Set[${Math.Calc[${NPCData.PlayerAmmoTherm[${MyShip.Cargo[${Ship.${WeaponSwitch}.Charge.Type}].TypeID}]}*${Ship.${WeaponSwitch}.DamageModifier}]}]
					TrackingSpd:Set[${Math.Calc[${NPCData.PlayerTrackingMult[${MyShip.Cargo[${Ship.${WeaponSwitch}.Charge.Type}].TypeID}]}*${Ship.${WeaponSwitch}.TrackingSpeed}]}]
					OptimalRng:Set[${Math.Calc[${NPCData.PlayerRangeMult[${MyShip.Cargo[${Ship.${WeaponSwitch}.Charge.Type}].TypeID}]}*${Ship.${WeaponSwitch}.OptimalRange}]}]
					FalloffRng:Set[${Math.Calc[${NPCData.PlayerRangeMult[${MyShip.Cargo[${Ship.${WeaponSwitch}.Charge.Type}].TypeID}]}*${Ship.${WeaponSwitch}.AccuracyFalloff}]}]
				
					echo ${EMDamage} ${ExpDamage} ${KinDamage} ${ThermDamage} ${TrackingSpd} ${OptimalRng} ${FalloffRng}
					DBInsertIndex:Insert["insert into ShipAmmunitionTurret (AmmoTypeID, AmmoType, ShipType, TurretType, EMDamage, ExpDamage, KinDamage, ThermDamage, TrackingSpd, OptimalRng, FalloffRng) values (${MyShip.Cargo[${Ship.${WeaponSwitch}.Charge.Type}].TypeID}, '${AvailableAmmoIterator.Value.Type.ReplaceSubstring[','']}', '${MyShip.ToEntity.Type.ReplaceSubstring[','']}', '${Ship.${WeaponSwitch}.Type.ReplaceSubstring[','']}', ${EMDamage}, ${ExpDamage}, ${KinDamage}, ${ThermDamage}, ${TrackingSpd}, ${OptimalRng}, ${FalloffRng}) ON CONFLICT (AmmoTypeID) DO UPDATE SET ShipType=excluded.ShipType, TurretType=excluded.TurretType, EMDamage=excluded.EMDamage, ExpDamage=excluded.ExpDamage, KinDamage=excluded.KinDamage, ThermDamage=excluded.ThermDamage, TrackingSpd=excluded.TrackingSpd, OptimalRng=excluded.OptimalRng, FalloffRng=excluded.FalloffRng;"]
					CombatComputer.AmmoCollection:Set[${Ship.${WeaponSwitch}.Charge.Type},${MyShip.Cargo[${Ship.${WeaponSwitch}.Charge.Type}].TypeID}]
				}
			}
		}
		; Missiles. We want the four damage types/amounts and your skills, the explosion velocity, the explosion radius, the approximate range.
		; This is going to be slightly worse because I have to just make up multipliers here, if your skills differ you will have different results. Going to try and keep it reasonable
		; no "all fives" stuff. Hopefully the slight discrepancy won't drastically alter things.
		; Ammo Type ID (Integer Primary Key), Ammo Type (String), Ship's Item Type (String), Launcher Item Type (String), Missile Explosion Velocity (Real), Missile Explosion Radius (Real), Missile Range (Real), EM Damage (Real), Explosive Damage (Real), Kinetic Damage (Real), Thermal Damage (Real).
		if ${Ship.ModuleList_MissileLauncher.Count} > 0
		{
			MyShip.Module[${Ship.ModuleList_MissileLauncher.ID}]:GetAvailableAmmo[AvailableAmmoIndex]
			if ${AvailableAmmoIndex.Size} > 0
			AvailableAmmoIndex:GetIterator[AvailableAmmoIterator]
			if ${AvailableAmmoIterator:First(exists)}
			{
				do
				{
					if ${AvailableAmmoIterator.Value.Quantity} < ${CombatComputer.MinAmmoAmount}
						continue
					; These damage estimates are going to be based on both of my golem archtypes, both cruise and torp with 3 damage mods
					; and mostly level 4 skills yields around 4x damage, so we're going with that until amadeus gives me what i need.
					EMDamage:Set[${Math.Calc[${NPCData.PlayerAmmoEM[${AvailableAmmoIterator.Value.TypeID}]}*(4)]}]
					ExpDamage:Set[${Math.Calc[${NPCData.PlayerAmmoExp[${AvailableAmmoIterator.Value.TypeID}]}*(4)]}]
					KinDamage:Set[${Math.Calc[${NPCData.PlayerAmmoKin[${AvailableAmmoIterator.Value.TypeID}]}*(4)]}]
					ThermDamage:Set[${Math.Calc[${NPCData.PlayerAmmoTherm[${AvailableAmmoIterator.Value.TypeID}]}*(4)]}]				
					ExpRadius:Set[${NPCData.PlayerMissileExplosionRadius[${AvailableAmmoIterator.Value.TypeID}]}]
					ExpVel:Set[${NPCData.PlayerMissileExplosionVelocity[${AvailableAmmoIterator.Value.TypeID}]}]
					FlightRange:Set[${NPCData.PlayerMissileMaxRange[${AvailableAmmoIterator.Value.TypeID}]}]
				
					echo ${EMDamage} ${ExpDamage} ${KinDamage} ${ThermDamage} ${ExpRadius} ${ExpVel} ${FlightRange}
					DBInsertIndex:Insert["insert into ShipAmmunitionMissile (AmmoTypeID, AmmoType, ShipType, LauncherType, EMDamage, ExpDamage, KinDamage, ThermDamage, ExpRadius, ExpVel, FlightRange) values (${AvailableAmmoIterator.Value.TypeID}, '${AvailableAmmoIterator.Value.Type.ReplaceSubstring[','']}', '${MyShip.ToEntity.Type.ReplaceSubstring[','']}', '${Ship.ModuleList_MissileLauncher.Type.ReplaceSubstring[','']}', ${EMDamage}, ${ExpDamage}, ${KinDamage}, ${ThermDamage}, ${ExpRadius}, ${ExpVel}, ${FlightRange}) ON CONFLICT (AmmoTypeID) DO UPDATE SET ShipType=excluded.ShipType, LauncherType=excluded.LauncherType, EMDamage=excluded.EMDamage, ExpDamage=excluded.ExpDamage, KinDamage=excluded.KinDamage, ThermDamage=excluded.ThermDamage, ExpRadius=excluded.ExpRadius, ExpVel=excluded.ExpVel, FlightRange=excluded.FlightRange;"]
					CombatComputer.AmmoCollection:Set[${AvailableAmmoIterator.Value.Name},${AvailableAmmoIterator.Value.TypeID}]
				}
				while ${AvailableAmmoIterator:Next(exists)}
			}
			if ${Ship.ModuleList_MissileLauncher.Charge.Type.NotNULLOrEmpty}
			{
				if ${MyShip.Cargo[${Ship.ModuleList_MissileLauncher.Charge.Type}](exists)} 
				{
					EMDamage:Set[${Math.Calc[${NPCData.PlayerAmmoEM[${MyShip.Cargo[${Ship.ModuleList_MissileLauncher.Charge.Type}].TypeID}]}*(4)]}]
					ExpDamage:Set[${Math.Calc[${NPCData.PlayerAmmoExp[${MyShip.Cargo[${Ship.ModuleList_MissileLauncher.Charge.Type}].TypeID}]}*(4)]}]
					KinDamage:Set[${Math.Calc[${NPCData.PlayerAmmoKin[${MyShip.Cargo[${Ship.ModuleList_MissileLauncher.Charge.Type}].TypeID}]}*(4)]}]
					ThermDamage:Set[${Math.Calc[${NPCData.PlayerAmmoTherm[${MyShip.Cargo[${Ship.ModuleList_MissileLauncher.Charge.Type}].TypeID}]}*(4)]}]				
					ExpRadius:Set[${NPCData.PlayerMissileExplosionRadius[${MyShip.Cargo[${Ship.ModuleList_MissileLauncher.Charge.Type}].TypeID}]}]
					ExpVel:Set[${NPCData.PlayerMissileExplosionVelocity[${MyShip.Cargo[${Ship.ModuleList_MissileLauncher.Charge.Type}].TypeID}]}]
					FlightRange:Set[${NPCData.PlayerMissileMaxRange[${MyShip.Cargo[${Ship.ModuleList_MissileLauncher.Charge.Type}].TypeID}]}]
				
					echo ${EMDamage} ${ExpDamage} ${KinDamage} ${ThermDamage} ${ExpRadius} ${ExpVel} ${FlightRange}
					DBInsertIndex:Insert["insert into ShipAmmunitionMissile (AmmoTypeID, AmmoType, ShipType, LauncherType, EMDamage, ExpDamage, KinDamage, ThermDamage, ExpRadius, ExpVel, FlightRange) values (${MyShip.Cargo[${Ship.ModuleList_MissileLauncher.Charge.Type}].TypeID}, '${AvailableAmmoIterator.Value.Type.ReplaceSubstring[','']}', '${MyShip.ToEntity.Type.ReplaceSubstring[','']}', '${Ship.ModuleList_MissileLauncher.Type.ReplaceSubstring[','']}', ${EMDamage}, ${ExpDamage}, ${KinDamage}, ${ThermDamage}, ${ExpRadius}, ${ExpVel}, ${FlightRange}) ON CONFLICT (AmmoTypeID) DO UPDATE SET ShipType=excluded.ShipType, LauncherType=excluded.LauncherType, EMDamage=excluded.EMDamage, ExpDamage=excluded.ExpDamage, KinDamage=excluded.KinDamage, ThermDamage=excluded.ThermDamage, ExpRadius=excluded.ExpRadius, ExpVel=excluded.ExpVel, FlightRange=excluded.FlightRange;"]
					CombatComputer.AmmoCollection:Set[${Ship.ModuleList_MissileLauncher.Charge.Type},${MyShip.Cargo[${Ship.ModuleList_MissileLauncher.Charge.Type}].TypeID}]
				}
			}
		}
		MyShipInfo:ExecDMLTransaction[DBInsertIndex]
		DBInsertIndex:Clear
	}
	; This method will set the minimum amount of ammo to be considered for the previous method.
	method SetMinimumAmmoAmount()
	{
		
		if ${Ship.ModuleList_MissileLauncher.Count} > 0
			CombatComputer.MinAmmoAmount:Set[301]

		if ${Ship.ModuleList_Projectiles.Count} > 0 || ${Ship.ModuleList_Hybrids.Count} > 0
			CombatComputer.MinAmmoAmount:Set[301]
		; Energy Weapons specifically, 4 or more crystals.
		if ${Ship.ModuleList_Lasers.Count} > 0
			CombatComputer.MinAmmoAmount:Set[4]	

			
	}
	; This method will set the Reload Time for our weapon.
	method GetReloadTime()
	{
		CombatComputer.ChangeTime:Set[${NPCData.PlayerReloadTime[${Ship.${WeaponSwitch}.TypeID}]}]
		echo DEBUG - Ship 2 - Change Ammo Time ${NPCData.PlayerReloadTime[${Ship.${WeaponSwitch}.TypeID}]}
	}
	; This method will clean up the Ammo Table.
	method CleanupAmmoTable()
	{
		WeaponSwitch:Set[${Ship.WeaponSwitch}]
		GetShipInfo:Set[${MyShipInfo.ExecQuery["Select * FROM ShipAmmunitionMissile;"]}]
		if ${GetShipInfo.NumRows} > 0
		{
			do
			{
				if ${MyShip.Cargo[${GetShipInfo.GetFieldValue["AmmoType"]}].Quantity} == 0 && !(${Ship.${WeaponSwitch}.ChargeType.Equal[${GetShipInfo.GetFieldValue["AmmoType"]}]} && ${Ship.${WeaponSwitch}.ChargeQuantity} > 0)
				{
					MyShipInfo:ExecDML["DELETE From ShipAmmunitionMissile WHERE AmmoType='${GetShipInfo.GetFieldValue["AmmoType"]}';"]
				}
				GetShipInfo:NextRow
			}
			while !${GetShipInfo.LastRow}
			GetShipInfo:Finalize
		}
		else
		{
			GetShipInfo:Finalize
		}
		
		GetShipInfo:Set[${MyShipInfo.ExecQuery["Select * FROM ShipAmmunitionTurret;"]}]
		if ${GetShipInfo.NumRows} > 0
		{
			do
			{
				if ${MyShip.Cargo[${GetShipInfo.GetFieldValue["AmmoType"]}].Quantity} == 0 && !(${Ship.${WeaponSwitch}.ChargeType.Equal[${GetShipInfo.GetFieldValue["AmmoType"]}]} && ${Ship.${WeaponSwitch}.ChargeQuantity} > 0)
				{
					MyShipInfo:ExecDML["DELETE From ShipAmmunitionTurret WHERE AmmoType='${GetShipInfo.GetFieldValue["AmmoType"]}';"]
				}
				GetShipInfo:NextRow
			}
			while !${GetShipInfo.LastRow}
			GetShipInfo:Finalize
		}
		else
		{
			GetShipInfo:Finalize
		}		
	
	}
}
