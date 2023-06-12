
objectdef obj_Configuration_Abyssal inherits obj_Configuration_Base
{
	method Initialize()
	{
		This[parent]:Initialize["Abyssal"]
	}

	method Set_Default_Values()
	{
		ConfigManager.ConfigRoot:AddSet[${This.SetName}]
		This.ConfigRef:AddSetting[AmmoAmountToLoad, 500]
		This.ConfigRef:AddSetting[FilamentType, ""]
		This.ConfigRef:AddSetting[FilamentAmount, 1]
		This.ConfigRef:AddSetting[UseDrugs, FALSE]
		This.ConfigRef:AddSetting[DrugsToUse, ""]
		This.ConfigRef:AddSetting[DrugsToUse2, ""]
		This.ConfigRef:AddSetting[UseMTU, FALSE]
		This.ConfigRef:AddSetting[MTUType, ""]
		This.ConfigRef:AddSetting[OverloadThrust, FALSE]
		This.ConfigRef:AddSetting[Overheat, FALSE]
		This.ConfigRef:AddSetting[NanitesToLoad, 100]
		This.ConfigRef:AddSetting[HomeBase, ""]
		This.ConfigRef:AddSetting[FilamentSite, ""]
		This.ConfigRef:AddSetting[LogLevelBar, LOG_INFO]
	}

	Setting(bool, Halt, SetHalt)
	Setting(bool, UseSecondaryAmmo, SetSecondary)
	Setting(bool, UseTertiaryAmmo, SetTertiary)	
	Setting(bool, UseDrones, SetDrones)
	Setting(bool, UseMTU, SetUseMTU)
	Setting(string, MTUType, SetMTUType)
	Setting(bool, DropOffToContainer, SetDropOffToContainer)
	Setting(string, DropOffContainerName, SetDropOffContainerName)
	Setting(bool, OverloadThrust, SetOverloadThrust)
	Setting(bool, Overheat, SetOverheat)
	Setting(bool, UseDrugs, SetUseDrugs)
	Setting(string, DrugsToUse, SetDrugsToUse)
	Setting(string, DrugsToUse2, SetDrugsToUse2)
	Setting(int, NanitesToLoad, SetNanitesToLoad)	
	Setting(string, HomeBase, SetHomeBase)
	Setting(string, FilamentSite, SetFilamentSite)
	Setting(string, MunitionStorage, SetMunitionStorage)
	Setting(string, MunitionStorageFolder, SetMunitionStorageFolder)
	Setting(string, DroneType, SetDroneType)
	Setting(string, SRAmmo, SetSRAmmo)
	Setting(string, LRAmmo, SetLRAmmo)
	Setting(string, XLRAmmo, SetXLRAmmo)
	Setting(int, AmmoAmountToLoad, SetAmmoAmountToLoad)
	Setting(string, FilamentType, SetFilamentType)
	Setting(int, FilamentAmount, SetFilamentAmount)
	Setting(int, LogLevelBar, SetLogLevelBar)
}

objectdef obj_Abyssal inherits obj_StateQueue
{

	variable collection:string TargetToDestroy


	;;;;;;;;;; current mission data.
	variable string targetToDestroy
	variable string ammo
	variable string secondaryAmmo
	variable string tertiaryAmmo
	variable string containerToLoot


	;;;;;;;;;; Used when performing mission.
	; If a target can't be killed within 2 minutes, something is going wrong.
	variable int maxAttackTime
	variable int switchTargetAfter = 120


	variable set AllowDronesOnNpcClass
	variable obj_TargetList NPCs
	variable obj_TargetList ActiveNPCs
	variable obj_TargetList Lootables
	variable obj_TargetList Marshals

	variable obj_Configuration_Abyssal Config
	variable obj_Configuration_Agents Agents
	variable obj_AbyssalUI LocalUI

	variable bool reload = TRUE
	variable bool halt = FALSE
	
	variable bool StatusGreen
	variable bool StatusChecked
	variable bool OverheatSetup
	variable bool AbandonMTU
	variable bool GrabbedLoot = FALSE
	variable bool InitialTry

	method Initialize()
	{
		This[parent]:Initialize

		DynamicAddBehavior("Abyssal", "Abyssal Runner")
		This.PulseFrequency:Set[3500]

		This.LogInfoColor:Set["g"]
		This.LogLevelBar:Set[${Config.LogLevelBar}]

		LavishScript:RegisterEvent[Tehbot_ScheduleHalt]
		Event[Tehbot_ScheduleHalt]:AttachAtom[This:ScheduleHalt]
		LavishScript:RegisterEvent[Tehbot_ScheduleResume]
		Event[Tehbot_ScheduleResume]:AttachAtom[This:ScheduleResume]

		Lootables:AddQueryString["(GroupID = GROUP_WRECK || GroupID = GROUP_CARGOCONTAINER) && !IsMoribund"]

		AllowDronesOnNpcClass:Add["Frigate"]
		AllowDronesOnNpcClass:Add["Destroyer"]
		AllowDronesOnNpcClass:Add["Cruiser"]
		AllowDronesOnNpcClass:Add["BattleCruiser"]
		AllowDronesOnNpcClass:Add["Battleship"]
		AllowDronesOnNpcClass:Add["Sentry"]
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
			This:QueueState["UpdateNPCs"]
			This:QueueState["Repair"]
			This:QueueState["CheckForWork", 5000]
			EVE:RefreshBookmarks
		}


		Tehbot.Paused:Set[FALSE]
		UIElement[Run@TitleBar@Tehbot]:SetText[Stop]
		;We need to disable the ISXEVE entity cache because going to the abyss and back makes it buggy apparently?
		;Correction, cache rules everything around me
		;I lied, cache must be disabled
		ISXEVE:Debug_SetEntityCacheDisabled[TRUE]
	}

	method Stop()
	{
		This:LogInfo["Stopping."]
		This:Clear
		Tehbot.Paused:Set[TRUE]
		UIElement[Run@TitleBar@Tehbot]:SetText[Run]
		ISXEVE:Debug_SetEntityCacheDisabled[FALSE]
	}

	member:bool test()
	{
		echo ${Config.Halt}
	}

	member:bool UpdateNPCs()
	{
		NPCs:RequestUpdate
		return TRUE
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

		ammo:Set[${Config.SRAmmo}]
		if ${Config.UseSecondaryAmmo}
		{
			secondaryAmmo:Set[${Config.LRAmmo}]
		}
		else
		{
			secondaryAmmo:Set[""]
		}
		if ${Config.UseTertiaryAmmo}
		{
			tertiaryAmmo:Set[${Config.XLRAmmo}]
		}
		else
		{
			tertiaryAmmo:Set[""]
		}

		;You know, I don't think this actually does anything... Well maybe it does.
		Ship.ModuleList_Weapon:ConfigureAmmo[${ammo}, ${secondaryAmmo}, ${tertiaryAmmo}]
		Ship.ModuleList_Ancillary_Shield_Booster:ConfigureAmmo[${Config.BatteryToBring}]
		
		; We are running abyssals, our weapons are vortons (edencom), we should set up for overheat. Maybe this still works.
		if ${Client.InSpace} && ${Ship.ModuleList_VortonWeapon.Count} > 0 && ${Config.Overheat} && !${OverheatSetup}
		{
			This:LogInfo["Setting Vorton Overload HP Limit"] 
			Ship.ModuleList_VortonWeapon:SetOverloadHPThreshold[15]
			OverheatSetup:Set[TRUE]
		}
		; We are running abyssals, our weapons are disintegration orbs, love orbs, anyways, overload the orbs.
		; DO NOT OVERHEAT THE ORBS HOLY SHIT THAT IS EXPENSIVE TO REPAIR
		;if ${Client.InSpace} && ${Ship.ModuleList_Disintegrator.Count} > 0 && ${Config.Overheat} && !${OverheatSetup}
		;{
		;	This:LogInfo["Setting Disintegrator Overload HP Limit"] 
		;	Ship.ModuleList_Disintegrator:SetOverloadHPThreshold[15]
		;	OverheatSetup:Set[TRUE]
		;}		
		; We are in space, in a pod. Might figure out something more complicated for this later.
		if ${Client.InSpace} && ${MyShip.ToEntity.Type.Equal[Capsule]}
		{
			This:LogInfo["We dead"]
			This:Stop
		}
		; We are in station, in a pod. Might figure out something more complicated for this later.
		if ${Me.InStation} && ${MyShip.ToItem.Type.Equal[Capsule]}
		{
			This:LogInfo["We dead"]
			This:Stop
		}
		; We are in space, but not the abyss, we have time to see if we need anything.
		if ${Client.InSpace} && !${This.InAbyss} && !${StatusChecked}
		{
			This:LogInfo["Status Check"]
			This:InsertState["CheckStatus", 5000]
			return TRUE
		}
		; We are in space, not the abyss, and we have no problems. Lets go to the abyss.
		if ${Client.InSpace} && !${This.InAbyss} && ${StatusGreen}
		{
			This:LogInfo["Go to Abyssal Site]
			This:InsertState["GoToAbyss", 5000]
			return TRUE
		}
		; We are in space and need resupply and/or repair, back to base
		if ${Client.InSpace} && !${This.InAbyss} && !${StatusGreen}
		{
			This:LogInfo["Go back to the station"]
			This:InsertState["GoToStation"]
			return TRUE
		}
		; We are in abyssal space, no time to see if we are good or not. If we aren't good we are already dead.
		if ${Client.InSpace} && ${This.InAbyss}
		{
			This:LogInfo["We appear to be in The Abyss"]
			This:QueueState["RunTheAbyss"]
			return TRUE
		}
		; We are in station and need repairs or resupply.
		if ${Me.InStation} && !${StatusGreen}
		{
			This:LogInfo["Loading Ammo \ao${ammo}"]
			if ${Config.UseSecondaryAmmo}
			{
				This:LogInfo["Loading Secondary Ammo \ao${secondaryAmmo}", "o"]
			}
			if ${Config.UseTertiaryAmmo}
			{
				This:LogInfo["Loading Tertiary Ammo \ao${tertiaryAmmo}", "o"]
			}
			if ${Config.BatteryToBring.NotNULLOrEmpty} && ${Config.BatteryAmountToBring}
			{
				This:LogInfo["Loading Charge \ao${Config.BatteryToBring}", "o"]
			}
			StatusGreen:Set[TRUE]
			This:QueueState["Repair"]
			This:QueueState["DropOffLoot", 5000]
			This:InsertState["ReloadAmmoAndDrones", 3000]
			return TRUE
		}
		; We have hit the halt button, might want to like, stop the bot or something.
		if ${Me.InStation} && (${Config.Halt} || ${Halt})
		{
			This:LogInfo["Halt Requested"]
			This:InsertState["HaltBot"]
			return TRUE
		}
		; We are in station and everything is good, time to go.
		if ${Me.InStation} && ${StatusGreen}
		{
			This:LogInfo["Undocking"]
			Move:Undock
			This:QueueState["CheckForWork", 5000]
			return TRUE
		}

	}
	
	; We should see if we need ammo, filaments, etc. This is in case the bot gets stopped in space after a few runs or whatever.
	member:bool CheckStatus()
	{
		;If we don't have any ammo, or we have less than 40% of the amount of configured ammo, need to go back to reload.
		if !${MyShip.Cargo[${Config.SRAmmo}](exists)} || ( ${MyShip.Cargo[${Config.SRAmmo}].Quantity} < ${Math.Calc[${Config.AmmoAmountToLoad} * .4]} )
		{
			This:LogInfo["Short on ${Config.SRAmmo}"]
			StatusGreen:Set[FALSE]
			StatusChecked:Set[TRUE]
			This:InsertState["CheckForWork", 5000]
			return TRUE
		}
		; Same thing but for LR ammo, if we are using LR ammo
		if ${Config.UseSecondaryAmmo}
		{
			if !${MyShip.Cargo[${Config.LRAmmo}](exists)} || ( ${MyShip.Cargo[${Config.LRAmmo}].Quantity} < ${Math.Calc[${Config.AmmoAmountToLoad} * .4]} )
			{
				This:LogInfo["Short on ${Config.LRAmmo}"]
				StatusGreen:Set[FALSE]
				StatusChecked:Set[TRUE]
				This:InsertState["CheckForWork", 5000]
				return TRUE
			}
		}
		; Same thing but for XLR ammo, if we are using XLR ammo
		if ${Config.UseTertiaryAmmo}
		{
			if !${MyShip.Cargo[${Config.XLRAmmo}](exists)} || ( ${MyShip.Cargo[${Config.XLRAmmo}].Quantity} < ${Math.Calc[${Config.AmmoAmountToLoad} * .4]} )
			{
				This:LogInfo["Short on ${Config.XLRAmmo}"]
				StatusGreen:Set[FALSE]
				StatusChecked:Set[TRUE]
				This:InsertState["CheckForWork", 5000]
				return TRUE
			}
		}
		; If we are out of filaments entirely we go back to base.
		if !${MyShip.Cargo[${Config.FilamentType}](exists)}
		{
			This:LogInfo["Short on ${Config.FilamentType}"]
			StatusGreen:Set[FALSE]
			StatusChecked:Set[TRUE]
			This:InsertState["CheckForWork", 5000]
			return TRUE
		}
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
		; Check to see if we lost our MTU somewhere along the way.
		if ${Config.UseMTU}
		{
			if !${MyShip.Cargo[${Config.MTUType}](exists)}
			{
				This:LogInfo["${Config.MTUType is Missing"]
				StatusGreen:Set[FALSE]
				StatusChecked:Set[TRUE]
				This:InsertState["CheckForWork", 5000]
				return TRUE
			}
		}
		; Check to see if we have our drugs
		if ${Config.UseDrugs}
		{
			if !${MyShip.Cargo[${Config.DrugsToUse}](exists)}
			{
				This:LogInfo["${Config.DrugsToUse} are out"]
				StatusGreen:Set[FALSE]
				StatusChecked:Set[TRUE]
				This:InsertState["CheckForWork", 5000]
				return TRUE
			}
			if !${MyShip.Cargo[${Config.DrugsToUse2}](exists)}
			{
				This:LogInfo["${Config.DrugsToUse}2 are out"]
				StatusGreen:Set[FALSE]
				StatusChecked:Set[TRUE]
				This:InsertState["CheckForWork", 5000]
				return TRUE
			}
		}
		; Check to see if we have our nanite paste, at least 40% of the initial amount.
		if ${Config.Overheat}
		{
			if !${MyShip.Cargo[Nanite Repair Paste](exists)} || ( ${MyShip.Cargo[Nanite Repair Paste].Quantity} < ${Math.Calc[${Config.NanitesToLoad} * .4]} )
			{
				This:LogInfo["Nanite Repair Paste too low"]
				StatusGreen:Set[FALSE]
				StatusChecked:Set[TRUE]
				This:InsertState["CheckForWork", 5000]
				return TRUE
			}
		}
		; If we are in structure, or if our (ostensibly first weapon) is damaged by overheat, go back.
		if ${MyShip.StructurePct} < 100 || ${MyShip.Module[HiSlot0].Damage} > 25
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
			Client:Wait[1000]
		}
		; Is our inventory nearly full? How often does this happen??? If we have less than 100 m3 left, back to base.
		if (${Math.Calc[${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo].Capacity} - ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo].UsedCapacity}]}) < 100
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
		if ${Config.HomeBase.NotNULLOrEmpty}
		{
			Move:Bookmark["${Config.HomeBase}"]
			This:InsertState["Traveling"]
			This:QueueState["CheckForWork", 5000]
			return TRUE
		}
		else
		{
			This:LogInfo["HomeBase BM not found, stopping"]
			This:Stop
		}
	}
	
	; We have all we need, go to the Abyss
	member:bool GoToAbyss()
	{
		if ${Config.FilamentSite.NotNULLOrEmpty}
		{
			Move:Bookmark["${Config.FilamentSite}"]
			This:InsertState["Traveling"]
			This:QueueState["ActivateFilament", 5000]
			return TRUE
		}
		else
		{
			This:LogInfo["Filament Site BM not found, stopping"]
			This:Stop
		}
	}
	; We are at the BM (hopefully), use the filament
	member:bool ActivateFilament()
	{
		if ${Config.FilamentType.NotNULLOrEmpty}
		{
			; If we aren't in a cruiser we need to be in a fleet.
			if !${Me.Fleet} && (${MyShip.ToEntity.Group.Find[Frigate]} || ${MyShip.ToEntity.Group.Find[Destroyer]})
			{
				Me:InviteToFleet
			}
			
			;The filament is up, we are running duos/trios.
			if ${Entity[Name == "Abyssal Trace" && Distance < 10000](exists)} && ${Me.Fleet}
			{
				This:LogInfo["Entering Filament"]			
				Entity[Name == "Abyssal Trace" && Distance < 10000]:Activate
				This:QueueState["RunTheAbyss"]
				return TRUE
			}
			; If we have a filament, use it
			if ${MyShip.Cargo[${Config.FilamentType}](exists)}
			{
				if !${EVEWindow[KeyActivationWindow](exists)}
				{
					MyShip.Cargo[${Config.FilamentType}]:UseAbyssalFilament
					This:LogInfo["Using Filament"]
				}

			}
			if ${EVEWindow[KeyActivationWindow](exists)}
			{
				This:LogInfo["Traversing Conduit"]
				EVEWindow[KeyActivationWindow].Button[1]:Press
			}
			if ${This.InAbyss}
			{
				This:LogInfo["Abyss run starting."]
				This:QueueState["RunTheAbyss"]
				return TRUE
			}
			This:InsertState["ActivateFilament", 5000]
			return TRUE
		}
	}
	
	; This is where the logic for actually running and completing the abyssal will go. Man, this is gonna be hell.
	member:bool RunTheAbyss()
	{

		; Get this dang window out of my way, if it is even there in the first place.
		if ${Entity[Name == "Transfer Conduit (Triglavian)" && Distance !~ NULL && Distance < 100000](exists)} || ${Entity[Name == "Origin Conduit (Triglavian)" && Distance !~ NULL && Distance < 100000](exists)}
		{
			if ${EVEWindow[KeyActivationWindow](exists)}
			{
				EVEWindow[KeyActivationWindow]:Close
			}
		}

		; Something went wrong here
		if !${This.InAbyss}
		{
			This:QueueState["CheckForWork", 10000]
			return TRUE
		}

		; We're Stormbringing it up but we didnt have enough time to repair, and waiting for repairs will cost more damage than not overheating. Cancel the repair.
		; Also I swear if you don't put your SINGLE WEAPON in the very first slot you're crazy.
		if ${Config.Overheat} && ${MyShip.Module[HiSlot0].IsBeingRepaired}
		{
			MyShip.Module[HiSlot0]:CancelRepair
		}
		
		; First up, I guess we should start moving. We will decide on a plan of action based on a few factors.
		; Are we using an MTU or not? Are the enemies the kind that run away or not? Is this room going to be extremely dangerous?
		; Are we using a ship capable of projecting damage at quite a distance? Do we need speed to tank?
		; Some of these considerations will not be considered for now. For now I am considering that we are
		; Doing T3s in either a Stormbringer or a Missile based cruiser with a good tank and with decent range.
		if ${This.JerksPresent} && ${This.InAbyss}
		{
			; Threshold for defensive shield drugs is 40%, stick to the safe ones so you don't kneecap yourself by removing all your cap or whatever the hell.
			if (${MyShip.ShieldPct} < 40 && ${Ship.ModuleList_Regen_Shield.Count}) || (${MyShip.ArmorPct} < 40 && ${Ship.ModuleList_Repair_Armor.Count})
			{
				if ${MyShip.Cargo[Agency 'Hardshell' TB3 Dose I](exists)} && ${LavishScript.RunningTime} >= ${HardshellTime}
				{
					MyShip.Cargo[Agency 'Hardshell' TB3 Dose I]:ConsumeBooster
					HardshellTime:Set[${Math.Calc[${LavishScript.RunningTime} + 1800000]}]
					This:LogInfo["Using Agency 'Hardshell' TB3 Dose I."]
				}
				if ${MyShip.Cargo[Agency 'Hardshell' TB5 Dose II](exists)} && ${LavishScript.RunningTime} >= ${HardshellTime}
				{
					MyShip.Cargo[Agency 'Hardshell' TB5 Dose II]:ConsumeBooster
					HardshellTime:Set[${Math.Calc[${LavishScript.RunningTime} + 1800000]}]
					This:LogInfo["Using Agency 'Hardshell' TB5 Dose II."]
				}
				if ${MyShip.Cargo[Agency 'Hardshell' TB7 Dose III](exists)} && ${LavishScript.RunningTime} >= ${HardshellTime}
				{
					MyShip.Cargo[Agency 'Hardshell' TB7 Dose III]:ConsumeBooster
					HardshellTime:Set[${Math.Calc[${LavishScript.RunningTime} + 1800000]}]
					This:LogInfo["Using Agency 'Hardshell' TB7 Dose III."]
				}
				if ${MyShip.Cargo[Agency 'Hardshell' TB9 Dose IV](exists)} && ${LavishScript.RunningTime} >= ${HardshellTime}
				{
					MyShip.Cargo[Agency 'Hardshell' TB9 Dose IV]:ConsumeBooster
					HardshellTime:Set[${Math.Calc[${LavishScript.RunningTime} + 1800000]}]
					This:LogInfo["Using Agency 'Hardshell' TB9 Dose IV."]
				}
				if ${MyShip.Cargo[Synth Blue Pill Booster](exists)} && ${LavishScript.RunningTime} >= ${BluePillTime}
				{
					MyShip.Cargo[Synth Blue Pill Booster]:ConsumeBooster
					BluePillTime:Set[${Math.Calc[${LavishScript.RunningTime} + 1800000]}]
					This:LogInfo["Using Synth Blue Pill."]
				}
				if ${MyShip.Cargo[Standard Blue Pill Booster](exists)} && ${LavishScript.RunningTime} >= ${BluePillTime}
				{
					MyShip.Cargo[Standard Blue Pill Booster]:ConsumeBooster
					BluePillTime:Set[${Math.Calc[${LavishScript.RunningTime} + 1800000]}]
					This:LogInfo["Using Standard Blue Pill."]
				}
				if ${MyShip.Cargo[Improved Blue Pill Booster](exists)} && ${LavishScript.RunningTime} >= ${BluePillTime}
				{
					MyShip.Cargo[Improved Blue Pill Booster]:ConsumeBooster
					BluePillTime:Set[${Math.Calc[${LavishScript.RunningTime} + 1800000]}]
					This:LogInfo["Using Improved Blue Pill."]
				}
				if ${MyShip.Cargo[Strong Blue Pill Booster](exists)} && ${LavishScript.RunningTime} >= ${BluePillTime}
				{
					MyShip.Cargo[Strong Blue Pill Booster]:ConsumeBooster
					BluePillTime:Set[${Math.Calc[${LavishScript.RunningTime} + 1800000]}]
					This:LogInfo["Using Strong Blue Pill."]
				}
				
				if ${MyShip.Cargo[Synth Exile Booster](exists)} && ${LavishScript.RunningTime} >= ${BluePillTime}
				{
					MyShip.Cargo[Synth Exile Booster]:ConsumeBooster
					ExileTime:Set[${Math.Calc[${LavishScript.RunningTime} + 1800000]}]
					This:LogInfo["Using Exile ."]
				}
				if ${MyShip.Cargo[Standard Exile Booster](exists)} && ${LavishScript.RunningTime} >= ${BluePillTime}
				{
					MyShip.Cargo[Standard Exile Booster]:ConsumeBooster
					ExileTime:Set[${Math.Calc[${LavishScript.RunningTime} + 1800000]}]
					This:LogInfo["Using Exile."]
				}
				if ${MyShip.Cargo[Improved Exile Booster](exists)} && ${LavishScript.RunningTime} >= ${BluePillTime}
				{
					MyShip.Cargo[Improved Exile Booster]:ConsumeBooster
					ExileTime:Set[${Math.Calc[${LavishScript.RunningTime} + 1800000]}]
					This:LogInfo["Using Exile."]
				}
				if ${MyShip.Cargo[Strong Exile Booster](exists)} && ${LavishScript.RunningTime} >= ${BluePillTime}
				{
					MyShip.Cargo[Strong Exile Booster]:ConsumeBooster
					ExileTime:Set[${Math.Calc[${LavishScript.RunningTime} + 1800000]}]
					This:LogInfo["Using Exile."]
				}
			}
			GrabbedLoot:Set[FALSE]
			; Targets exist, TargetManager will handle weapons, this mode just needs to handle navigation.
			; TargetManager will also quickly kill the main lootable and any others that are at reasonable distance.
			; We will basically have two primary strategies on room entrance.

			; A target that maintains a massive distance exists in the room. If we are deploying an MTU we will go to the next conduit, deploy the MTU roughly near it, then maintain an appropriate
			; Distance from both the enemy and the conduit.
			if ${Config.UseMTU} && ${This.DistantTrash} && !${AbandonMTU}
			{
				if ${Entity[(Name == "Transfer Conduit (Triglavian)" || Name == "Origin Conduit (Triglavian)") && Distance !~ NULL && Distance < 100000](exists)}
				{
					if !${MyShip.ToEntity.Approaching.ID.Equal[${Entity[(Name == "Transfer Conduit (Triglavian)" || Name == "Origin Conduit (Triglavian)") && Distance !~ NULL && Distance < 100000].ID}]} || ${MyShip.ToEntity.Mode} == MOVE_STOPPED
					{
						Move:Approach[${Entity[Name == "Transfer Conduit (Triglavian)" || Name == "Origin Conduit (Triglavian)"]}, 0]
					}
					if ${MyShip.Cargo[${Config.MTUType}](exists)} && ${Entity[Name == "Transfer Conduit (Triglavian)" || Name == "Origin Conduit (Triglavian)"].Distance} < 1000
					{
						MyShip.Cargo[${Config.MTUType}]:LaunchForSelf
						This:LogInfo["MTU Deploying"]
					}
					if ${This.MTUDeployed}
					{
						if ${Entity[Name =- "Overmind" || Name =- "Tyrannos" || Name =- "Thunderchild" || Name =- "Leshak" || Name =- "Deepwatcher"].Distance} > 30000
						{
							Move:Orbit[${Entity[Name =- "Overmind" || Name =- "Tyrannos" || Name =- "Thunderchild" || Name =- "Leshak" || Name =- "Deepwatcher"]}, 15000]
						}
						if ${Entity[Group =- "Mobile Tractor Unit"].Distance} > 30000
						{
							Move:Orbit[${Entity[Group =- "Mobile Tractor Unit"]}, 5000]
						}
					}
				}	
			}
			; Alternatively, we have a normal room full of swarming trash that comes straight for you. If we are deploying an MTU we drop it immediately and begin orbiting it until enemies are gone.
			if ${Config.UseMTU} && !${This.DistantTrash} && !${AbandonMTU}
			{
				if ${MyShip.Cargo[${Config.MTUType}](exists)} && !${This.MTUDeployed}
				{
					MyShip.Cargo[${Config.MTUType}]:LaunchForSelf
					This:LogInfo["MTU Deploying"]
					
				}
				if ${Entity[Group =- "Mobile Tractor Unit"](exists)}
				{
					Move:Orbit[${Entity[Group =- "Mobile Tractor Unit"]}, 5000]
					This:LogInfo["Orbiting MTU"]
				}
			}
			; No MTU logic sucks, dance around between  cache / wreck & enemy if they are running enemy.
			if (!${Config.UseMTU} || ${AbandonMTU}) && ${This.DistantTrash}
			{
				; Different navigation strategy if you are using precursor weapon. No dancing around here, need to go straight for the target in all cases.
				if ${Ship.ModuleList_Disintegrator.Count} > 0 || ${Ship.ModuleList_VortonWeapon.Count} > 0 || ${Ship.ModuleList_Turret.Count}
				{
					if ${CurrentOffenseTarget} && !${MyShip.ToEntity.Approaching.ID.Equal[${CurrentOffenseTarget}]}
					{
						This:LogInfo["Approaching Target"]
						Move:Orbit[${CurrentOffenseTarget}, 5000]
					}
				}
				else
				{
					; Special case for Marshals, Charge right into them. 
					if ${This.MarshalPresent}
					{
						This:LogInfo["${This.MarshalPresent} Marshals"]
						if ${Entity[Name =- "Marshal"].Distance} > 30000
						{
							Move:Orbit[${Entity[Name =- "Marshal"]}, 10000]
						}
					}
					if ${Entity[Name =- "Blinding Leshak" && Distance > 40000](exists)}
					{
						Move:Orbit[${Entity[Name =- "Blinding Leshak" && Distance > 40000]}]
					}
					if ${Entity[(Name =- "Overmind" || Name =- "Tyrannos" || Name =- "Thunderchild" || Name =- "Leshak" || Name =- "Deepwatcher") && ID == ${CurrentOffenseTarget}].Distance} > 27000
					{
						Move:Orbit[${Entity[(Name =- "Overmind" || Name =- "Tyrannos" || Name =- "Thunderchild" || Name =- "Leshak" || Name =- "Deepwatcher") && ID == ${CurrentOffenseTarget}]}, 5000]
					}
					if ${Entity[Name == "Transfer Conduit (Triglavian)" || Name == "Origin Conduit (Triglavian)"].Distance} > 15000 && !${Entity[(Name =- "Blinding Leshak" && Distance > 40000](exists)}
					{
						Move:Orbit[${Entity[Name == "Transfer Conduit (Triglavian)" || Name == "Origin Conduit (Triglavian)"]}, 5000]
					}
				}
			}
			; If we aren't using an MTU and it is just normal trash enemies, orbit the main lootable until everything is dead.
			if (!${Config.UseMTU} || ${AbandonMTU}) && !${This.DistantTrash}
			{
				; Different navigation strategy if you are using precursor weapon.
				if ${Ship.ModuleList_Disintegrator.Count} > 0 || ${Ship.ModuleList_VortonWeapon.Count} > 0 || ${Ship.ModuleList_Turret.Count}
				{
					if ${CurrentOffenseTarget} && !${MyShip.ToEntity.Approaching.ID.Equal[${CurrentOffenseTarget}]}
					{
						This:LogInfo["Approaching Target"]
						Move:Orbit[${CurrentOffenseTarget}, 5000]
					}
				}
				else
				{
					; Special case for Marshals, Charge right into them.
					if ${This.MarshalPresent}
					{
						This:LogInfo["${This.MarshalPresent} Marshals"]
						if ${Entity[Name =- "Marshal"].Distance} > 30000
						{
							Move:Orbit[${Entity[Name =- "Marshal"]}, 10000]
						}
					}
					if ${Entity[Name =- "Triglavian Biocombinative Cache" || Name =- "Triglavian Bioadaptive Cache"](exists)} && ${Me.ToEntity.Mode} != MOVE_ORBITING
					{
						This:LogInfo["Orbiting Cache/Wreck"]
						Move:Orbit[${Entity[Name =- "Triglavian Biocombinative Cache" || Name =- "Triglavian Bioadaptive Cache"]}, 2500]
					}
				}
			}
			This:InsertState["RunTheAbyss"]
			return TRUE
		}
		; Enemies are gone, cleanup and move on to the next room.
		if !${This.JerksPresent} && ${This.InAbyss}
		{
			; Good place to reload, probably.
			EVE:Execute[CmdReloadAmmo]
			
			; Repairing our vorton or disintegrator orb laser.
			if ${MyShip.Module[HiSlot0].Damage} > 0 && ${Config.Overheat} && ${MyShip.Cargo[Nanite Repair Paste](exists)} && !${MyShip.Module[HiSlot0].IsActive} && !${MyShip.Module[HiSlot0].IsBeingRepaired} &&\
			!${Entity[Name == "Triglavian Biocombinative Cache" || Name == "Triglavian Bioadaptive Cache"](exists)}
			{
				This:LogInfo["Repairing our Vorton / Orb"]
				MyShip.Module[HiSlot0]:Repair
			}
			
			; We had a rare disconnect AFTER grabbing the loot but BEFORE going through the gate
			if !${This.MTUDeployed} && ${Entity[Name =- "Cache Wreck" && IsWreckEmpty]}
			{
				GrabbedLoot:Set[TRUE]
			}
			; We were out of range to shoot the cache when the last enemy died, and the cache never died between then and now. Please get to it.
			if ${Entity[Name =- "Triglavian Biocombinative Cache" || Name =- "Triglavian Bioadaptive Cache" && Distance > 30000](exists)} && ${Me.ToEntity.Mode} != MOVE_ORBITING && \
			!${MyShip.ToEntity.Approaching.ID.Equal[${Entity[Name =- "Triglavian Biocombinative Cache" || Name =- "Triglavian Bioadaptive Cache"]}]}
			{
				This:LogInfo["Orbiting Cache/Wreck"]
				Move:Orbit[${Entity[Name == "Triglavian Biocombinative Cache" || Name == "Triglavian Bioadaptive Cache"]}, 2500]
			}
			; If we have an MTU out, but there is still reasonable loot in reach, chillax a bit.
			if ${Config.UseMTU} && ${This.MTUDeployed} && ${This.LootboxesPresent}
			{
				This:LogInfo["Waiting on loot"]
				if !${MyShip.ToEntity.Approaching.ID.Equal[${Entity[Group == "Mobile Tractor Unit"].ID}]} || ${MyShip.ToEntity.Mode} == MOVE_STOPPED || \
				(${MyShip.ToEntity.Mode} == MOVE_ORBITING && ${Entity[Group == "Mobile Tractor Unit"].Distance} > 2000)
				{
					Move:Approach[${Entity[Group == "Mobile Tractor Unit"]}, 1000]
					This:LogInfo["Approaching MTU"]
				}
			}
			; If we have an MTU out, and it has grabbed all the reasonable loot, grab it and lets go.
			if ${Config.UseMTU} && ${This.MTUDeployed} && !${This.LootboxesPresent} && !${AbandonMTU}
			{
				This:LogInfo["Pickup MTU"]
				GrabbedLoot:Set[FALSE]
				This:InsertState["PickupMTU", 5000]
				return TRUE
			}
			; If we use MTUs and there is not one out, and there are no enemies OR we have an MTU out but are set to abandon it, move on.
			if ${Config.UseMTU} && !${This.MTUDeployed} || ( ${Config.UseMTU} && ${This.MTUDeployed} && ${AbandonMTU})
			{
				This:LogInfo["Room Complete, Proceed."]
				EVE:Execute[CmdStopShip]
				This:InsertState["TouchTheConduit", 4000]
				return TRUE
			}
			; If we do not use MTUs, and there is a lootable with stuff in it still, we should go to it to grab it (if it is a reasonable distance away).
			if (!${Config.UseMTU} || ${AbandonMTU}) && ${This.LootboxesPresent}
			{
				This:LogInfo["Going to grab the goods"]
				if ${Entity[Name =- "Cache Wreck" && !IsMoribund && !IsWreckEmpty](exists)}
				{
					This:LogInfo["CONDITION PURPLE"]
					Move:Approach[${Entity[Name =- "Cache Wreck" && !IsMoribund && !IsWreckEmpty]}, 2000]
				}
			}
			if ((!${Config.UseMTU} || ${AbandonMTU}) && ${This.LootboxesPresent} ) && \
			${Entity[Name =- "Cache Wreck" && !IsMoribund && !IsWreckEmpty && Distance < 2500](exists)}
			{
				This:LogInfo["CONDITION GOLD"]
				Entity[Name =- "Cache Wreck"]:Open
				EVEWindow[Inventory]:LootAll
				GrabbedLoot:Set[TRUE]
			}
			; If we do not use MTUs, and there are no valid lootables to grab, we must be done.
			if (!${Config.UseMTU} || ${AbandonMTU}) && !${This.LootboxesPresent} && ${GrabbedLoot}
			{
				This:LogInfo["Room Complete, Proceed."]
				EVE:Execute[CmdStopShip]
				This:InsertState["TouchTheConduit", 4000]
				return TRUE
			}
			This:InsertState["RunTheAbyss"]
			return TRUE
		}
	}

	; This one is for seeing if there are targets present. Returns TRUE if there are hostile NPCs and FALSE if not.
	member:bool JerksPresent()
	{
		if ${Entity[Group =- "Abyssal Spaceship Entities" || Group =- "Abyssal Drone Entities" && !IsMoribund && Name !~ "Vila Swarmer"](exists)}
		{
			return TRUE
		}
		else
		{
			return FALSE
		}
	}
	; Those Marshals are annoying as hell
	member:bool MarshalPresent()
	{
		Marshals:ClearQueryString
		Marshals:AddQueryString["(TypeID == 56177 || TypeID == 56176 || TypeID == 56178) && !IsMoribund"]
		if ${Marshals.Targetlist.Used}
		{
			return ${Marshals.Targetlist.Used}
		}
	
	}
	; This one is for seeing if there are still lootables worth waiting for, either the main one we are orbiting (no MTU being used), or further wrecks that have velocity (they are being tractored).
	; This will return TRUE if we haven't grabbed the loot, and it is reasonable to do so. Hopefully, that is my goal anyways. If we have grabbed all the reasonable wrecks, that is to say they are
	; Empty, then this will return FALSE. Also if the wrecks are simply too far away.
	member:bool LootboxesPresent()
	{
		if !${Entity[Name =- "Wreck" && !IsMoribund && !IsWreckEmpty](exists)}
		{
			return FALSE
		}
		if ${Entity[Name =- "Triglavian Biocombinative Cache Wreck" || Name =- "Triglavian Bioadaptive Cache Wreck" && !IsMoribund && !IsWreckEmpty && Distance > 100000](exists)} && !${Config.UseMTU}
		{
			return FALSE
		}
		if ${Entity[Name =- "Wreck" && !IsMoribund && !IsWreckEmpty && Distance > 50000](exists)} && ${Config.UseMTU}
		{
			return FALSE
		}
		if ${Entity[Name =- "Wreck" && !IsMoribund && !IsWreckEmpty](exists)} && ${Config.UseMTU}
		{
			return TRUE
		}
		if ${Entity[Name =- "Cache Wreck" && !IsMoribund && !IsWreckEmpty](exists)} && !${Config.UseMTU}
		{
			return TRUE
		}
		
	}
	; This one tells us if an MTU is present. Returns TRUE if we have an MTU still out there. Returns FALSE if not.
	member:bool MTUDeployed()
	{
		if !${Config.UseMTU}
		{
			return FALSE
		}
		if ${Entity[Group =- "Mobile Tractor Unit"](exists)}
		{
			return TRUE
		}
		else
		{
			return FALSE
		}
	}
	; This one tells us if enemies that keep their distance are present. Returns TRUE if any enemy that is known to try and move outside your range are present
	; Returns FALSE if not. Might get fancier with this at a later time, basing some of this on your own weapon range.
	member:bool DistantTrash()
	{
		if ${Entity[Name =- "Overmind" || Name =- "Tyrannos" || Name =- "Thunderchild" || Name =- "Leshak" || Name =- "Deepwatcher"](exists)}
		{
			return TRUE
		}
		else
		{
			return FALSE
		}
	}
	; This member is for a state for picking up the MTU, may as well make it a state instead of another chunk of code.
	member:bool PickupMTU()
	{
		
		if !${MyShip.ToEntity.Approaching.ID.Equal[${Entity[Group == "Mobile Tractor Unit"].ID}]} || ${MyShip.ToEntity.Mode} == MOVE_STOPPED || \
		(${MyShip.ToEntity.Mode} == MOVE_ORBITING && ${Entity[Group == "Mobile Tractor Unit"].Distance} > 2000)
		{
			Move:Approach[${Entity[Group == "Mobile Tractor Unit"]}, 1000]
			This:LogInfo["Approaching MTU"]
		}
		if ${Entity[Group == "Mobile Tractor Unit"].Distance} < 2000
		{
			if (${Math.Calc[${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo].Capacity} - ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo].UsedCapacity}]}) < 100
			{
				This:LogInfo["Can't grab the damn MTU, no space!"]
				Entity[Group == "Mobile Tractor Unit"]:Open
				EVEWindow[Inventory]:LootAll
				AbandonMTU:Set[TRUE]
				This:InsertState["RunTheAbyss"]
				return TRUE
			}
			if ${Entity[Group == "Mobile Tractor Unit"].Distance} < 2000
			{
				This:LogInfo["Emptying MTU"]
				Entity[Group == "Mobile Tractor Unit"]:Open
				EVEWindow[Inventory]:LootAll			
				GrabbedLoot:Set[TRUE]
			}
			
			if (${Math.Calc[${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo].Capacity} - ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo].UsedCapacity}]}) > 100 && ${GrabbedLoot}
			{
				This:LogInfo["Grabbing MTU"]
				Entity[Group == "Mobile Tractor Unit"]:ScoopToCargoHold
			}
			if ${Entity[Name == "Cargo Container"](exists)}
			{
				if ${Entity[Name == "Cargo Container"].Distance} > 2500 && !${MyShip.ToEntity.Approaching.ID.Equal[${Entity[Name =- "Cargo Container"].ID}]}
				{
					Move:Approach[${Entity[Name == "Cargo Container"]}, 2000]
				}
				if ${Entity[Name == "Cargo Container"].Distance} < 2500
				{
					Entity[Name == "Cargo Container"]:Open
					EVEWindow[Inventory]:LootAll
					This:InsertState["RunTheAbyss"]
					return TRUE
				}
			}
			if !${This.MTUDeployed} && !${Entity[Name == "Cargo Container"](exists)}
			{
				This:InsertState["RunTheAbyss"]
				return TRUE				
			}
		}
	This:QueueState["PickupMTU", 5000]
	return TRUE
	}
	
	; This will get us close to the conduit because this is getting tedious as hell.
	member:bool TouchTheConduit()
	{
		; Missed our chance at repairing, should begin the repair now if we aren't already.
		if ${MyShip.Module[HiSlot0].Damage} > 0 && ${Config.Overheat} && ${MyShip.Cargo[Nanite Repair Paste](exists)} && !${MyShip.Module[HiSlot0].IsActive} && !${MyShip.Module[HiSlot0].IsBeingRepaired}
		{
			This:LogInfo["Repairing our Vorton"]
			MyShip.Module[HiSlot0]:Repair
		}
		if (${Entity[Name == "Transfer Conduit (Triglavian)"](exists)} && \
		!${MyShip.ToEntity.Approaching.ID.Equal[${Entity[(Name == "Transfer Conduit (Triglavian)" || Name == "Origin Conduit (Triglavian)") && Distance !~ NULL && Distance < 100000]}]}) || \
		${Me.ToEntity.Mode} == MOVE_ORBITING
		{
			This:LogInfo["Heading for Transfer Conduit"]
			Move:Approach[${Entity[Name == "Transfer Conduit (Triglavian)" && Distance !~ NULL && Distance < 100000]}, 2500]
		}
		if (${Entity[Name == "Origin Conduit (Triglavian)"](exists)} && \
		!${MyShip.ToEntity.Approaching.ID.Equal[${Entity[(Name == "Transfer Conduit (Triglavian)" || Name == "Origin Conduit (Triglavian)") && Distance !~ NULL && Distance < 100000]}]}) || \
		${Me.ToEntity.Mode} == MOVE_ORBITING
		{
			This:LogInfo["Heading for Origin Conduit"]
			Move:Approach[${Entity[Name == "Origin Conduit (Triglavian)" && Distance !~ NULL && Distance < 100000]}, 2500]
		}
		; This is probably going to fail
		if ${Entity[(Name == "Transfer Conduit (Triglavian)" || Name == "Origin Conduit (Triglavian)") && Distance !~ NULL && Distance < 100000].Distance} > 3000
		{
			This:QueueState["TouchTheConduit", 5000]
			return TRUE
		}
		if ${Entity[(Name == "Transfer Conduit (Triglavian)" || Name == "Origin Conduit (Triglavian)") && Distance !~ NULL && Distance < 100000].Distance} < 3000
		{
			This:InsertState["ConduitActivation", 3000]
			return TRUE
		}
	}
	; This gets us from one room to another, also out of the abyss at the end.
	member:bool ConduitActivation()
	{
		; This was pretty unreliable, let us hope the other way is better.
		;if ${Entity[Name == "Transfer Conduit (Triglavian)" || Name == "Origin Conduit (Triglavian)"].Distance} > 2000 && \
		;(!${MyShip.ToEntity.Approaching.ID.Equal[${Entity[(Name == "Transfer Conduit (Triglavian)" || Name == "Origin Conduit (Triglavian)") && Distance !~ NULL && Distance < 100000]}]} || ${MyShip.ToEntity.Mode} == MOVE_STOPPED)
		;{
		;	Move:Gate[${Entity[(Name == "Transfer Conduit (Triglavian)" || Name == "Origin Conduit (Triglavian)") && Distance !~ NULL && Distance < 100000]}]
		;	This:LogInfo["Approaching conduit"]
		;}
		if ${Entity[Name == "Transfer Conduit (Triglavian)"](exists)}
		{
			This:LogInfo["Going to Next Room"]
			Entity[Name == "Transfer Conduit (Triglavian)" && Distance !~ NULL && Distance < 100000]:Activate
			GrabbedLoot:Set[FALSE]
			This:QueueState["RunTheAbyss"]
			return TRUE
		}
		if ${Entity[Name == "Origin Conduit (Triglavian)"](exists)}
		{
			Entity[Name == "Origin Conduit (Triglavian)" && Distance !~ NULL && Distance < 100000]:Activate
			This:LogInfo["All done, leaving the abyss."]
			GrabbedLoot:Set[FALSE]
			StatusChecked:Set[FALSE]
			This:QueueState["CheckForWork", 20000]
			return TRUE
		}
		This:QueueState["RunTheAbyss", 4000]
		return TRUE
	}
	; Just returns a bool for if we are in the Abyss or not. Probably works fine unless we end up in an abyss without a conduit somehow.
	member:bool InAbyss()
	{
		if !${Client.InSpace}
		{
			return FALSE
		}
		; Troubleshooting something weird
		;if ${Universe[${Me.SolarSystemID}].Security} !~ NULL
		;{
		;	return FALSE
		;}
		if ${EVE.Bookmark[${Config.HomeBase}](exists)} && ${EVE.Bookmark[${Config.HomeBase}].JumpsTo} < 1000
		{
			return FALSE
		}
		if ${Entity[Name == "Unstable Abyssal Depths" && Distance !~ NULL && Distance < 200000](exists)}
		{
			return TRUE
		}
		if ${Entity[Name == "Transfer Conduit (Triglavian)" && Distance !~ NULL && Distance < 100000](exists)} || ${Entity[Name == "Origin Conduit (Triglavian)" && Distance !~ NULL && Distance < 100000](exists)}
		{
			return TRUE
		}
		else
		{
			return FALSE
		}
		
	}
	member:bool ReloadWeapons()
	{
		EVE:Execute[CmdReloadAmmo]
		return TRUE
	}

	member:bool WaitTill(int timestamp, bool start = TRUE)
	{
		if ${start}
		{
			variable time waitUntil
			waitUntil:Set[${timestamp}]

			variable int hour
			hour:Set[${waitUntil.Time24.Token[1, ":"]}]
			variable int minute
			minute:Set[${waitUntil.Time24.Token[2, ":"]}]

			if ${hour} == 10 && ${minute} >= 30 && ${minute} <= 59
			{
				This:LogInfo["Specified time ${waitUntil.Time24} is close to downtime, just halt."]

				This:InsertState["WaitTill", 5000, ${timestamp:Inc[3600]}]
				return TRUE
			}

			This:LogInfo["Start waiting until ${waitUntil.Date} ${waitUntil.Time24}."]
		}

		if ${Utility.EVETimestamp} < ${timestamp}
		{
			This:InsertState["WaitTill", 5000, "${timestamp}, FALSE"]
			return TRUE
		}

		This:LogInfo["Finished waiting."]
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
			if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
			{
				EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
				Client:Wait[600]
				This:LogInfo["First wait."]
				return FALSE
			}

			if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
			{
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
				Client:Wait[600]
				This:LogInfo["Second wait."]
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
			Client:Wait[600]
			This:LogInfo["Third wait."]
			EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:StackAll
			Client:Wait[600]
			This:LogInfo["4th wait."]
			if ${Config.DropOffToContainer} && ${Config.DropOffContainerName.NotNULLOrEmpty}
			{
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:GetItems[items]
			}
		}
		elseif ${Config.MunitionStorage.Equal[Personal Hangar]}
		{
			if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
			{

				EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
				Client:Wait[600]
				This:LogInfo["Fifth wait."]
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

			if ${Config.DropOffToContainer} && ${Config.DropOffContainerName.NotNULLOrEmpty}
			{
				EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[items]
			}
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
						Client:Wait[600]
						This:LogInfo["6th wait."]
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
					Client:Wait[600]
					This:LogInfo["7th wait."]
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
		Client:Wait[600]
		This:LogInfo["8th wait."]
		variable index:item items
		variable iterator itemIterator
		variable int64 dropOffContainerID = 0;
		; Find the container item id first
		if ${Config.DropOffToContainer} && ${Config.DropOffContainerName.NotNULLOrEmpty}
		{
			if ${Config.MunitionStorage.Equal[Corporation Hangar]}
			{
				if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
				{
					EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
					Client:Wait[600]
					This:LogInfo["9th wait."]
					return FALSE
				}

				if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
				{

					EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
					Client:Wait[600]
					This:LogInfo["10th wait."]
					return FALSE
				}
				Client:Wait[600]
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:GetItems[items]
			}
			elseif ${Config.MunitionStorage.Equal[Personal Hangar]}
			{
				if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
				{
					EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
					Client:Wait[600]
					This:LogInfo["11th wait."]
					return FALSE
				}
				EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[items]
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
							Client:Wait[600]
							This:LogInfo["12th wait."]
							return FALSE
						}
						break
					}
				}
				while ${itemIterator:Next(exists)}
			}
		}

		if !${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo](exists)}
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:MakeActive
			Client:Wait[600]
			This:LogInfo["13th wait."]
			return FALSE
		}
		Client:Wait[600]
		This:LogInfo["14th wait."]
		EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:GetItems[items]
		items:GetIterator[itemIterator]
		if ${itemIterator:First(exists)}
		{
			do
			{
				if !${itemIterator.Value.Name.Equal[${Config.SRAmmo}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.LRAmmo}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.XLRAmmo}]} && \
				   !${itemIterator.Value.Name.Equal[${Ship.ModuleList_Weapon.FallbackAmmo}]} && \
				   !${itemIterator.Value.Name.Equal[${Ship.ModuleList_Weapon.FallbackLongRangeAmmo}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.BatteryToBring}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.FilamentType}]} && \
				   !${itemIterator.Value.Name.Equal["Nanite Repair Paste"]} && \
				   !${itemIterator.Value.Type.Equal["'Packrat' Mobile Tractor Unit"]} && \
				   !${itemIterator.Value.Group.Equal["Booster"]} && \
				   !${itemIterator.Value.Name.Find["Script"]} 
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
							Client:Wait[600]
							This:LogInfo["15th wait."]
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
						{
							EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
							Client:Wait[600]
							This:LogInfo["16th wait."]
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
							Client:Wait[600]
							This:LogInfo["17th wait."]
							return FALSE
						}
						itemIterator.Value:MoveTo[MyStationHangar, Hangar]
						; return FALSE
					}
				}
			}
			while ${itemIterator:Next(exists)}
		}

		This:InsertState["StackHangars", 3000]
		return TRUE
	}



	member:bool ReloadAmmoAndDrones()
	{
		if ${Config.AmmoAmountToLoad} <= 0
			return TRUE

		variable index:item items
		variable iterator itemIterator
		variable int defaultAmmoAmountToLoad = ${Config.AmmoAmountToLoad}
		variable int secondaryAmmoAmountToLoad = ${Config.AmmoAmountToLoad}
		variable int tertiaryAmmoAmountToLoad = ${Math.Calc[${Config.AmmoAmountToLoad} * .5]}
		variable int droneAmountToLoad = -1
		variable int loadingDroneNumber = 0
		variable string preferredDroneType
		variable string fallbackDroneType

		variable string batteryType
		batteryType:Set[${Config.BatteryToBring}]
		variable int batteryToLoad
		batteryToLoad:Set[${Config.BatteryAmountToBring}]
		; echo load ${batteryToLoad} X ${batteryType}
		
		variable string Filamento
		Filamento:Set[${Config.FilamentType}]
		variable int Filamental
		Filamental:Set[${Config.FilamentAmount}]
		
		variable string MTU4U
		MTU4U:Set[${Config.MTUType}]
		variable int MTUNumber
		MTUNumber:Set[1]
		
		variable string NanomachinesSon
		NanomachinesSon:Set[Nanite Repair Paste]
		variable int Nanos
		Nanos:Set[${Config.NanitesToLoad}]
		
		variable string Druggery
		Druggery:Set[${Config.DrugsToUse}]
		variable int Drugz
		; One for now and one for later
		Drugz:Set[2]
		
		variable string Druggery2
		Druggery2:Set[${Config.DrugsToUse2}]
		variable int Drugz2
		; One for now and one for later
		Drugz2:Set[2]

		if (!${EVEWindow[Inventory](exists)})
		{
			EVE:Execute[OpenInventory]
			return FALSE
		}

		if ${Config.UseDrones}
		{
			if (!${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} < 0)
			{
				EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay]:MakeActive
				Client:Wait[600]
				This:LogInfo["18th wait."]
				return FALSE
			}

			variable float specifiedDroneVolume = ${Drones.Data.GetVolume[${Config.DroneType}]}
			preferredDroneType:Set[${Config.DroneType}]
			
			Client:Wait[600]
			This:LogInfo["19th wait."]
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay]:GetItems[items]
			items:GetIterator[itemIterator]
			if ${itemIterator:First(exists)}
			{
				do
				{
					if ${Config.MunitionStorage.Equal[Corporation Hangar]}
					{
						if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
						{
							EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
							Client:Wait[600]
							This:LogInfo["20th wait."]
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
						{

							EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
							Client:Wait[600]
							This:LogInfo["21st wait."]
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
						if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
						{
							EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
							Client:Wait[600]
							This:LogInfo["22nd wait."]
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
			Client:Wait[600]
			This:LogInfo["23rd wait."]
			return FALSE
		}

		defaultAmmoAmountToLoad:Dec[${This.InventoryItemQuantity[${ammo}, ${Me.ShipID}, "ShipCargo"]}]
		secondaryAmmoAmountToLoad:Dec[${This.InventoryItemQuantity[${secondaryAmmo}, ${Me.ShipID}, "ShipCargo"]}]
		tertiaryAmmoAmountToLoad:Dec[${This.InventoryItemQuantity[${tertiaryAmmo}, ${Me.ShipID}, "ShipCargo"]}]
		batteryToLoad:Dec[${This.InventoryItemQuantity[${batteryType}, ${Me.ShipID}, "ShipCargo"]}]
		MTUNumber:Dec[1]
		Filamental:Dec[${This.InventoryItemQuantity[${Filamento}, ${Me.ShipID}, "ShipCargo"]}]
		Nanos:Dec[${This.InventoryItemQuantity[${NanomachinesSon}, ${Me.ShipID}, "ShipCargo"]}]
		Drugz:Dec[${This.InventoryItemQuantity[${Druggery}, ${Me.ShipID}, "ShipCargo"]}]
		Drugz2:Dec[${This.InventoryItemQuantity[${Druggery2}, ${Me.ShipID}, "ShipCargo"]}]
		This:LogInfo["Checkpoint 1"]

		EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:GetItems[items]
		items:RemoveByQuery[${LavishScript.CreateQuery[Category == Deployable]}, FALSE]
		items:Collapse
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
						Client:Wait[600]
						This:LogInfo["24th wait."]
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
				if ((${Ship.ModuleList_Weapon.Count} && \
					!${itemIterator.Value.Name.Equal[${Ship.ModuleList_Weapon.FallbackAmmo}]} && \
					!${itemIterator.Value.Name.Equal[${Ship.ModuleList_Weapon.FallbackLongRangeAmmo}]} && \
					!${itemIterator.Value.Name.Equal[${ammo}]} && \
					!${itemIterator.Value.Name.Equal[${secondaryAmmo}]} && \
					!${itemIterator.Value.Name.Equal[${tertiaryAmmo}]} && \
					!${itemIterator.Value.Group.Equal["Mobile Tractor Unit"]} && \
					!${itemIterator.Value.Type.Find["Mobile Tractor Unit"]} && \
					!${itemIterator.Value.Type.Equal["'Packrat' Mobile Tractor Unit"]} && \
					!${itemIterator.Value.Category.Equal["Deployable"]}) && \
					(${itemIterator.Value.Name.Equal[${Config.SRAmmo}]} || \
				 	${itemIterator.Value.Name.Equal[${Config.LRAmmo}]} || \
					${itemIterator.Value.Name.Equal[${Config.XLRAmmo}]})) || \
					${itemIterator.Value.Name.Equal[${fallbackDroneType}]} 
				{
					if ${Config.MunitionStorage.Equal[Corporation Hangar]}
					{
						if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
						{
							EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
							Client:Wait[600]
							This:LogInfo["25th wait."]
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
						{

							EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
							Client:Wait[600]
							This:LogInfo["26th wait."]
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
							Client:Wait[600]
							This:LogInfo["27th wait."]
							return FALSE
						}
						This:LogInfo["${itemIterator.Value.Type} move to hangar"]	
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
			if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
			{
				EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
				Client:Wait[600]
				This:LogInfo["28th wait."]
				return FALSE
			}

			if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
			{
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
				Client:Wait[600]
				This:LogInfo["29th wait."]
				return FALSE
			}

			EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:GetItems[items]
		}
		elseif ${Config.MunitionStorage.Equal[Personal Hangar]}
		{
			if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
			{
				EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
				Client:Wait[600]
				This:LogInfo["30th wait."]
				return FALSE
			}

			EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[items]
		}

		; Load ammos
		items:GetIterator[itemIterator]
		if ${itemIterator:First(exists)}
		{
			do
			{
				if ${defaultAmmoAmountToLoad} > 0 && ${itemIterator.Value.Name.Equal[${ammo}]}
				{
					if ${itemIterator.Value.Quantity} >= ${defaultAmmoAmountToLoad}
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${defaultAmmoAmountToLoad}]
						defaultAmmoAmountToLoad:Set[0]
						return FALSE
					}
					else
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${itemIterator.Value.Quantity}]
						defaultAmmoAmountToLoad:Dec[${itemIterator.Value.Quantity}]
						return FALSE
					}
				}

				if ${secondaryAmmoAmountToLoad} > 0 && ${itemIterator.Value.Name.Equal[${secondaryAmmo}]}
				{
					if ${itemIterator.Value.Quantity} >= ${secondaryAmmoAmountToLoad}
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${secondaryAmmoAmountToLoad}]
						secondaryAmmoAmountToLoad:Set[0]
						return FALSE
					}
					else
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${itemIterator.Value.Quantity}]
						secondaryAmmoAmountToLoad:Dec[${itemIterator.Value.Quantity}]
						return FALSE
					}
				}
				
				if ${tertiaryAmmoAmountToLoad} > 0 && ${itemIterator.Value.Name.Equal[${tertiaryAmmo}]}
				{
					if ${itemIterator.Value.Quantity} >= ${tertiaryAmmoAmountToLoad}
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${tertiaryAmmoAmountToLoad}]
						tertiaryAmmoAmountToLoad:Set[0]
						return FALSE
					}
					else
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${itemIterator.Value.Quantity}]
						tertiaryAmmoAmountToLoad:Dec[${itemIterator.Value.Quantity}]
						return FALSE
					}
				}

				if ${batteryToLoad} > 0 && ${itemIterator.Value.Name.Equal[${batteryType}]}
				{
					if ${itemIterator.Value.Quantity} >= ${batteryToLoad}
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${batteryToLoad}]
						batteryToLoad:Set[0]
						return FALSE
					}
					else
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${itemIterator.Value.Quantity}]
						batteryToLoad:Dec[${itemIterator.Value.Quantity}]
						return FALSE
					}
				}
				
				if ${MTUNumber} > 0 && ${itemIterator.Value.Type.Equal[${MTU4U}]}
				{
					if ${itemIterator.Value.Quantity} >= ${MTUNumber}
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${MTUNumber}]
						MTUNumber:Set[0]
						return FALSE
					}
					else
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${itemIterator.Value.Quantity}]
						MTUNumber:Dec[${itemIterator.Value.Quantity}]
						return FALSE
					}
				}
				
				if ${Filamental} > 0 && ${itemIterator.Value.Name.Equal[${Filamento}]}
				{
					if ${itemIterator.Value.Quantity} >= ${Filamental}
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${Filamental}]
						Filamental:Set[0]
						return FALSE
					}
					else
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${itemIterator.Value.Quantity}]
						Filamental:Dec[${itemIterator.Value.Quantity}]
						return FALSE
					}
				}
				
				if ${Nanos} > 0 && ${itemIterator.Value.Name.Equal[${NanomachinesSon}]}
				{
					if ${itemIterator.Value.Quantity} >= ${Nanos}
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${Nanos}]
						Nanos:Set[0]
						return FALSE
					}
					else
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${itemIterator.Value.Quantity}]
						Nanos:Dec[${itemIterator.Value.Quantity}]
						return FALSE
					}
				}
				
				if ${Drugz} > 0 && ${itemIterator.Value.Name.Equal[${Druggery}]}
				{
					if ${itemIterator.Value.Quantity} >= ${Drugz}
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${Drugz}]
						Drugz:Set[0]
						return FALSE
					}
					else
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${itemIterator.Value.Quantity}]
						Drugz:Dec[${itemIterator.Value.Quantity}]
						return FALSE
					}
				}
				if ${Drugz2} > 0 && ${itemIterator.Value.Name.Equal[${Druggery2}]}
				{
					if ${itemIterator.Value.Quantity} >= ${Drugz2}
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${Drugz2}]
						Drugz2:Set[0]
						return FALSE
					}
					else
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${itemIterator.Value.Quantity}]
						Drugz2:Dec[${itemIterator.Value.Quantity}]
						return FALSE
					}
				}
			}
			while ${itemIterator:Next(exists)}
		}

		if (!${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} < 0) && ${Config.UseDrones}
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay]:MakeActive
			Client:Wait[600]
			This:LogInfo["31st wait."]
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
		if ${droneAmountToLoad} > 0 && ${fallbackDroneType.NotNULLOrEmpty}
		{
			isLoadingFallbackDrones:Set[TRUE]
			items:GetIterator[itemIterator]
			if ${itemIterator:First(exists)}
			{
				do
				{
					if ${droneAmountToLoad} > 0 && ${itemIterator.Value.Name.Equal[${fallbackDroneType}]}
					{
						loadingDroneNumber:Set[${droneAmountToLoad}]
						if ${itemIterator.Value.Quantity} < ${droneAmountToLoad}
						{
							loadingDroneNumber:Set[${itemIterator.Value.Quantity}]
						}
						This:LogInfo["Loading ${loadingDroneNumber} \ao${fallbackDroneType}\aws for having no \ao${preferredDroneType}\aw."]
						itemIterator.Value:MoveTo[${MyShip.ID}, DroneBay, ${loadingDroneNumber}]
						droneAmountToLoad:Dec[${loadingDroneNumber}]
						return FALSE
					}
				}
				while ${itemIterator:Next(exists)}
			}
		}

		if ${defaultAmmoAmountToLoad} > 0
		{
			This:LogCritical["You're out of ${ammo}, halting."]
			This:Stop
			return TRUE
		}
		elseif ${Config.UseSecondaryAmmo} && ${secondaryAmmoAmountToLoad} > 0
		{
			This:LogCritical["You're out of ${secondaryAmmo}, halting."]
			This:Stop
			return TRUE
		}
		elseif ${Config.UseTertiaryAmmo} && ${tertiaryAmmoAmountToLoad} > 0
		{
			This:LogCritical["You're out of ${tertiaryAmmo}, halting."]
			This:Stop
			return TRUE
		}
		elseif ${Config.UseDrones} && ${droneAmountToLoad} > 0
		{
			This:LogCritical["You're out of drones, halting."]
			This:Stop
			return TRUE
		}
		elseif ${batteryToLoad} > 0
		{
			This:LogCritical["You're out of ${batteryType}, halting."]
			This:Stop
			return TRUE
		}
		elseif ${MTUNumber} > 0 && ${Config.UseMTU}
		{
			This:LogCritical["You're out of ${MTU4U}, halting."]
			This:Stop
			return TRUE
		}
		elseif ${Filamental} > 0
		{
			This:LogCritical["You're out of ${Filamento}, halting."]
			This:Stop
			return TRUE
		}
		elseif ${Nanos} > 0 && ${Config.Overheat}
		{
			This:LogCritical["You're out of ${NanomachinesSon}, halting."]
			This:Stop
			return TRUE
		}
		elseif ${Drugz} > 0 && ${Config.UseDrugs}
		{
			This:LogCritical["You're out of ${Druggery}, halting."]
			This:Stop
			return TRUE
		}
		elseif ${Drugz2} > 0 && ${Config.UseDrugs}
		{
			This:LogCritical["You're out of ${Druggery2}, halting."]
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


objectdef obj_AbyssalUI inherits obj_State
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