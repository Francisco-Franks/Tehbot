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
	
	
	method Initialize()
	{

		; We shouldnt need WAL on this, it is a DB intended to be accessed by a singular client.
		
		MyShipInfo:Set[${SQLite.OpenDB["${Me.Name}ShipDB","${Script.CurrentDirectory}/${Me.Name}ShipDB.sqlite3"]}]

		;;; These are where we will store our modules and pertinent information about each module. A module can be in more than one table.
		; General modules, and general information. Generally speaking.
		;if !${MyShipInfo.TableExists["ShipGeneralModuleTable"]}
		;{
		;	echo DEBUG - Ship2 - Creating ShipGeneralModuleTable
		;	MyShipInfo:ExecDML["create table ShipGeneralModuleTable;"]
		;}
		; Weapons, specifically. Damage types, damage modifiers, range, falloff, explosion velocity, explosion radius, etc.
		;if !${MyShipInfo.TableExists["ShipWeaponsModuleTable"]}
		;{
		;	echo DEBUG - Ship2 - Creating ShipWeaponsModuleTable
		;	MyShipInfo:ExecDML["create table ShipWeaponsModuleTable;"]
		;}
		; Defenses, hardeners and reps, etc. 
		;if !${MyShipInfo.TableExists["ShipDefensiveModuleTable"]}
		;{
		;;	echo DEBUG - Ship2 - Creating ShipDefensiveModuleTable
		;	MyShipInfo:ExecDML["create table ShipDefensiveModuleTable;"]
		;}
		
		
		; Ammunition table for turrets.
		; What belongs in this table?
		;  Ammo Type ID (Integer Primary Key), Ammo Type (String), Ship's Item Type (String), Turret Item Type (String), Turret Tracking (Real), Turret Optimal (Real), Turret Falloff (Real), EM Damage (Real), Explosive Damage (Real), Kinetic Damage (Real), Thermal Damage (Real).
		;if !${MyShipInfo.TableExists["ShipAmmunitionTurret"]}
		;{
		;	echo DEBUG - Ship2 - Creating ShipAmmunitionTurret
		;	MyShipInfo:ExecDML["create table ShipAmmunitionAndDrones ;"]
		;}
		; Ammunition table for missiles.
		; Ammo Type ID (Integer Primary Key), Ammo Type (String), Ship's Item Type (String), Launcher Item Type (String), Missile Explosion Velocity (Real), Missile Explosion Radius (Real), Missile Range (Real), EM Damage (Real), Explosive Damage (Real), Kinetic Damage (Real), Thermal Damage (Real).
		;if !${MyShipInfo.TableExists["ShipAmmunitionMissile"]}
		;{
		;	echo DEBUG - Ship2 - Creating ShipAmmunitionMissile
		;	MyShipInfo:ExecDML["create table ShipAmmunitionAndDrones ;"]
		;}

		
		;;; This is where we will store our baseline stats about the actual ship itself. Basically our ships parameters AFTER skills but BEFORE any modules are activated.
		; How fast does our ship go, whats our sensor range, whats our sig radius, general information that might be of use, at some point. Doesn't really change much for target manager tbh.
		;if !${MyShipInfo.TableExists["ShipBaselineParameters"]}
		;{
		;	echo DEBUG - Ship2 - Creating ShipBaselineParameters
		;	MyShipInfo:ExecDML["create table ShipBaselineParameters;"]
		;}
		;;; This is where we will store our Expanded Paramteres. After skills, after modules, after ammo swaps, what is the max we can push any given parameter in any direction with what we have available.
		; This is where most of our work will live. We will keep track of our different hypothetical shipstates.
		; Ship state 1 - Golem, with Bastion On, with Torpedo Launchers, with 2 guidance computers, with 2 range scripts, with javelin ammunition.
		; Ship state 2 - Golem, with Bastion on, with Torpedo Launchers, with 2 guidance computers, with 2 precision scripts, with rage ammunition.
		; Ship state 3 - Golem, with Bastion on, with Torpedo Launchers, with 2 guidance computers, with 2 precision scripts, with t1 ammunition.
		; Record the parameters of those 3 states, in the table.
		; We encounter an enemy with x y z characteristics, which ship state will be able to apply damage best? Will switching states be Expensive 
		; (waste too much time? reset a weapon spoolup on a disintegrator? not make any effective difference whatsoever?)
		;if !${MyShipInfo.TableExists["ShipExpandedParameters"]}
		;{
		;	echo DEBUG - Ship2 - Creating ShipExpandedParameters
		;	MyShipInfo:ExecDML["create table ShipExpandedParameters;"]
		;}		
	}

	method Shutdown()
	{
	
		MyShipInfo:Close
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
	;;; And this is what it means to go beyond, I call this Ship 2.
	;;; Alright so heres the gist of it, this Object is going to be used in conjunction with information from obj_NPCData in another object or minimode
	;;; So that we can make some decisions based on our paramters vs the NPCs parameters. This will let us accomplish a great deal more I should imagine.
	;;; Also, we might be able to accomplish things against not NPCs but I'm not quite there yet. One thing at a time.
	;;; Anywho, within this object we will maintain a DB of our ships configuration, and its basic attributes. Why am I using a DB for this? A great question
	;;; SQL goes on everything, but more correctly, some of this information is going to be either A) hard to arrive at or B) costly to arrive at (in processing power)
	;;; Your character, in a ship, with a fit, is a relatively static object. Excepting external forces like EWAR or whatever, if you undock your Myrmidon, dock, log off, log on
	;;; and undock again, it will be the same ship before and after. Its weapons will be the same, its defenses the same. Maybe things might get weird if a skill finishes training
	;;; but for the most part, we should be able to undock and define in certain terms every parameter that will form the baseline performance of your ship.
	;;; If we know what modules we have, what scripts are available, what weapons we have, what ammunition is available, we will be able to calculate and record
	;;; its ability to deal with any npc that we have in the DB (which is every NPC). 
	;;; This NPC is going to be orbiting at x distance at y speed and it has z signature radius.
	;;; We can't hit it with our short range t2 ammo due to the tracking speed malus, even with tracking speed scripts or webification applied. If we switch to ammo with better tracking
	;;; we can hit it. 
	;;; This sort of example is what I hope to accomplish here. I want to undock, pull my info from this DB, ensure it hasn't changed significantly, then use its values against
	;;; the values we pull out of obj_NPCData and know immediately the correct order to destroy all the enemies. Who can be damaged by turrets right now vs
	;;; who will be effectively invulnerable if allowed to reach their preferred orbit. That however, is a story for the new targetmanager. On to the work at hand, here in this object.
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;
	;;;
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
		; This can only be done correctly in a ship, in space.
		if !${Client.InSpace}
			return FALSE
		; No pacifists plz
		if ${Ship.ModuleList_Weapon.Count} <= 0
			return FALSE
		; Turrets. We want the four damage types/amounts, tracking, optimal, and falloff with the ammo. I think thats all.
		; Ammo Type ID (Integer Primary Key), Ammo Type (String), Ship's Item Type (String), Turret Item Type (String), Turret Tracking (Real), Turret Optimal (Real), Turret Falloff (Real), EM Damage (Real), Explosive Damage (Real), Kinetic Damage (Real), Thermal Damage (Real).
		if ${Ship.ModuleList_Turret.Count} > 0
		{
			MyShip.Module[${Ship.ModuleList_Turret.ID}]:GetAvailableAmmo[AvailableAmmoIndex]
			if ${AvailableAmmoIndex.Size} > 0
			AvailableAmmoIndex:GetIterator[AvailableAmmoIterator]
			if ${AvailableAmmoIterator:First(exists)}
			{
				do
				{
					EMDamage:Set[${Math.Calc[${NPCData.PlayerAmmoEM[${AvailableAmmoIterator.Value.TypeID}]}*${Ship.ModuleList_Turret.DamageModifier}]}]
					ExpDamage:Set[${Math.Calc[${NPCData.PlayerAmmoExp[${AvailableAmmoIterator.Value.TypeID}]}*${Ship.ModuleList_Turret.DamageModifier}]}]
					KinDamage:Set[${Math.Calc[${NPCData.PlayerAmmoKin[${AvailableAmmoIterator.Value.TypeID}]}*${Ship.ModuleList_Turret.DamageModifier}]}]
					ThermDamage:Set[${Math.Calc[${NPCData.PlayerAmmoTherm[${AvailableAmmoIterator.Value.TypeID}]}*${Ship.ModuleList_Turret.DamageModifier}]}]
					TrackingSpd:Set[${Math.Calc[${NPCData.PlayerTrackingMult[${AvailableAmmoIterator.Value.TypeID}]}*${Ship.ModuleList_Turret.TrackingSpeed}]}]
					OptimalRng:Set[${Math.Calc[${NPCData.PlayerRangeMult[${AvailableAmmoIterator.Value.TypeID}]}*${Ship.ModuleList_Turret.OptimalRange}]}]
					FalloffRng:Set[${Math.Calc[${NPCData.PlayerRangeMult[${AvailableAmmoIterator.Value.TypeID}]}*${Ship.ModuleList_Turret.AccuracyFalloff}]}]
				
					echo ${EMDamage} ${ExpDamage} ${KinDamage} ${ThermDamage} ${TrackingSpd} ${OptimalRng} ${FalloffRng}
				
				}
				while ${AvailableAmmoIterator:Next(exists)}
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
				}
				while ${AvailableAmmoIterator:Next(exists)}
			}
		}			
	}
}
