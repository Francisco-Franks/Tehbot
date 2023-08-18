
objectdef obj_Configuration_CombatAnoms inherits obj_Configuration_Base
{
	method Initialize()
	{
		This[parent]:Initialize["CombatAnoms"]
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
		This.ConfigRef:AddSetting[HomeStructure, ""]
		This.ConfigRef:AddSetting[FilamentSite, ""]
		This.ConfigRef:AddSetting[LogLevelBar, LOG_INFO]
	}

	Setting(bool, Halt, SetHalt)
	; Use a second type of ammo
	Setting(bool, UseSecondaryAmmo, SetSecondary)
	; Use a third type of ammo
	Setting(bool, UseTertiaryAmmo, SetTertiary)
	; Use Drones
	Setting(bool, UseDrones, SetDrones)
	; Deploy an MTU
	Setting(bool, UseMTU, SetUseMTU)
	; What kind of MTU
	Setting(string, MTUType, SetMTUType)
	; Drop off your loot to a container in station
	Setting(bool, DropOffToContainer, SetDropOffToContainer)
	; What is the name of that container
	Setting(string, DropOffContainerName, SetDropOffContainerName)
	; Not used
	Setting(bool, OverloadThrust, SetOverloadThrust)
	; Overheat your weapon - This only applies to vortons for now
	Setting(bool, Overheat, SetOverheat)
	; Use combat drugs - Only defensive drugs are coded
	Setting(bool, UseDrugs, SetUseDrugs)
	; First drug you are using
	Setting(string, DrugsToUse, SetDrugsToUse)
	; Second drug you are using
	Setting(string, DrugsToUse2, SetDrugsToUse2)
	; How many nanites should we carry with us
	Setting(int, NanitesToLoad, SetNanitesToLoad)
	; What structure are we basing out of
	Setting(string, HomeStructure, SetHomeStructure)
	; Are we using our personal hangar or a corp hangar?
	Setting(string, MunitionStorage, SetMunitionStorage)
	; What folder in the corp hangar?
	Setting(string, MunitionStorageFolder, SetMunitionStorageFolder)
	; What kind of drone are we loading up
	Setting(string, DroneType, SetDroneType)
	; What type is our primary ammo
	Setting(string, SRAmmo, SetSRAmmo)
	; What type is our secondary ammo
	Setting(string, LRAmmo, SetLRAmmo)
	; What type is our tertiary ammo
	Setting(string, XLRAmmo, SetXLRAmmo)
	; How much ammo will we load, each type loads this amount
	Setting(int, AmmoAmountToLoad, SetAmmoAmountToLoad)
	
	; Do we run from shitheads, based on LocalCheck minimode + standings
	Setting(bool, RunFromBads, SetRunFromBads)
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
	; We want to always be aligned towards our home station
	Setting(bool, AlignHomeStructure, SetAlignHomeStructure)

	; I am going to attempt to make things more random by taking the number from the setting after this one, and using it to control a delay before
	; We undertake certain actions. Tehbot naturally adds delta to things but with enough clients and a small enough pulse time, things will begin
	; To overlap anyways. Maybe this will work, maybe I will get frustrated and give up, who knows.
	Setting(bool, UseExperimentalCountermeasures, SetUseExperimentalCountermeasures)
	; This number will be used as stated above, and to do a few other things to help the different clients behave more differently in the field.
	; Integer is a single number. Nobody should be rolling more than ten clients per machine. Hell nobody should be rolling more than SIX clients per machine.
	; Also we will need to ensure that the same numbers aren't chosen.
	Setting(int, SingleDigitNumber, SetSingleDigitNumber)

	; This is going to be a LONG ASS LIST OF COMBAT ANOMALIES. FUCK.
	; This is going to be a 0 - 3 priorities list like in MinerWorker.
	; 0 is ignore, 1 is highest priority, 2  is middle, 3 is lowest.
	; We ignore the 0s, if there are any 1s we do those, any 2s (but no 1s) we do those, any 3s (but no 1s or 2s) we do those.
	; Angels Section
	Setting(int, AngelHideawayPriority, SetAngelHideawayPriority)
	Setting(int, AngelHiddenHideawayPriority, SetAngelHiddenHideawayPriority)	
	Setting(int, AngelForsakenHideawayPriority, SetAngelForsakenHideawayPriority)	
	Setting(int, AngelForlornHideawayPriority, SetAngelForlornHideawayPriority)	
	Setting(int, AngelBurrowPriority, SetAngelBurrowPriority)	
	Setting(int, AngelRefugePriority, SetAngelRefugePriority)	
	Setting(int, AngelDenPriority, SetAngelDenPriority)	
	Setting(int, AngelHiddenDenPriority, SetAngelHiddenDenPriority)	
	Setting(int, AngelForsakenDenPriority, SetAngelForsakenDenPriority)	
	Setting(int, AngelForlornDenPriority, SetAngelForlornDenPriority)	
	Setting(int, AngelYardPriority, SetAngelYardPriority)	
	Setting(int, AngelRallyPointPriority, SetAngelRallyPointPriority)
	Setting(int, AngelHiddenRallyPointPriority, SetAngelHiddenRallyPointPriority)	
	Setting(int, AngelForsakenRallyPointPriority, SetAngelForsakenRallyPointPriority)	
	Setting(int, AngelForlornRallyPointPriority, SetAngelForlornRallyPointPriority)	
	Setting(int, AngelPortPriority, SetAngelPortPriority)
	Setting(int, AngelHubPriority, SetAngelHubPriority)	
	Setting(int, AngelHiddenHubPriority, SetAngelHiddenHubPriority)	
	Setting(int, AngelForsakenHubPriority, SetAngelForsakenHubPriority)	
	Setting(int, AngelForlornHubPriority, SetAngelForlornHubPriority)	
	Setting(int, AngelHavenPriority, SetAngelHavenPriority)	
	Setting(int, AngelSanctumPriority, SetAngelSanctumPriority)	
	; Blood Raiders Section
	Setting(int, BloodHideawayPriority, SetBloodHideawayPriority)
	Setting(int, BloodHiddenHideawayPriority, SetBloodHiddenHideawayPriority)	
	Setting(int, BloodForsakenHideawayPriority, SetBloodForsakenHideawayPriority)	
	Setting(int, BloodForlornHideawayPriority, SetBloodForlornHideawayPriority)	
	Setting(int, BloodBurrowPriority, SetBloodBurrowPriority)	
	Setting(int, BloodRefugePriority, SetBloodRefugePriority)	
	Setting(int, BloodDenPriority, SetBloodDenPriority)	
	Setting(int, BloodHiddenDenPriority, SetBloodHiddenDenPriority)	
	Setting(int, BloodForsakenDenPriority, SetBloodForsakenDenPriority)	
	Setting(int, BloodForlornDenPriority, SetBloodForlornDenPriority)	
	Setting(int, BloodYardPriority, SetBloodYardPriority)	
	Setting(int, BloodRallyPointPriority, SetBloodRallyPointPriority)
	Setting(int, BloodHiddenRallyPointPriority, SetBloodHiddenRallyPointPriority)	
	Setting(int, BloodForsakenRallyPointPriority, SetBloodForsakenRallyPointPriority)	
	Setting(int, BloodForlornRallyPointPriority, SetBloodForlornRallyPointPriority)	
	Setting(int, BloodPortPriority, SetBloodPortPriority)
	Setting(int, BloodHubPriority, SetBloodHubPriority)	
	Setting(int, BloodHiddenHubPriority, SetBloodHiddenHubPriority)	
	Setting(int, BloodForsakenHubPriority, SetBloodForsakenHubPriority)	
	Setting(int, BloodForlornHubPriority, SetBloodForlornHubPriority)	
	Setting(int, BloodHavenPriority, SetBloodHavenPriority)	
	Setting(int, BloodSanctumPriority, SetBloodSanctumPriority)	
	; Guristas Section
	Setting(int, GuristasHideawayPriority, SetGuristasHideawayPriority)
	Setting(int, GuristasHiddenHideawayPriority, SetGuristasHiddenHideawayPriority)	
	Setting(int, GuristasForsakenHideawayPriority, SetGuristasForsakenHideawayPriority)	
	Setting(int, GuristasForlornHideawayPriority, SetGuristasForlornHideawayPriority)	
	Setting(int, GuristasBurrowPriority, SetGuristasBurrowPriority)	
	Setting(int, GuristasRefugePriority, SetGuristasRefugePriority)	
	Setting(int, GuristasDenPriority, SetGuristasDenPriority)	
	Setting(int, GuristasHiddenDenPriority, SetGuristasHiddenDenPriority)	
	Setting(int, GuristasForsakenDenPriority, SetGuristasForsakenDenPriority)	
	Setting(int, GuristasForlornDenPriority, SetGuristasForlornDenPriority)	
	Setting(int, GuristasYardPriority, SetGuristasYardPriority)	
	Setting(int, GuristasRallyPointPriority, SetGuristasRallyPointPriority)
	Setting(int, GuristasHiddenRallyPointPriority, SetGuristasHiddenRallyPointPriority)	
	Setting(int, GuristasForsakenRallyPointPriority, SetGuristasForsakenRallyPointPriority)	
	Setting(int, GuristasForlornRallyPointPriority, SetGuristasForlornRallyPointPriority)	
	Setting(int, GuristasPortPriority, SetGuristasPortPriority)
	Setting(int, GuristasHubPriority, SetGuristasHubPriority)	
	Setting(int, GuristasHiddenHubPriority, SetGuristasHiddenHubPriority)	
	Setting(int, GuristasForsakenHubPriority, SetGuristasForsakenHubPriority)	
	Setting(int, GuristasForlornHubPriority, SetGuristasForlornHubPriority)	
	Setting(int, GuristasHavenPriority, SetGuristasHavenPriority)	
	Setting(int, GuristasSanctumPriority, SetGuristasSanctumPriority)	
	; Sansha Section
	Setting(int, SanshaHideawayPriority, SetSanshaHideawayPriority)
	Setting(int, SanshaHiddenHideawayPriority, SetSanshaHiddenHideawayPriority)	
	Setting(int, SanshaForsakenHideawayPriority, SetSanshaForsakenHideawayPriority)	
	Setting(int, SanshaForlornHideawayPriority, SetSanshaForlornHideawayPriority)	
	Setting(int, SanshaBurrowPriority, SetSanshaBurrowPriority)	
	Setting(int, SanshaRefugePriority, SetSanshaRefugePriority)	
	Setting(int, SanshaDenPriority, SetSanshaDenPriority)	
	Setting(int, SanshaHiddenDenPriority, SetSanshaHiddenDenPriority)	
	Setting(int, SanshaForsakenDenPriority, SetSanshaForsakenDenPriority)	
	Setting(int, SanshaForlornDenPriority, SetSanshaForlornDenPriority)	
	Setting(int, SanshaYardPriority, SetSanshaYardPriority)	
	Setting(int, SanshaRallyPointPriority, SetSanshaRallyPointPriority)
	Setting(int, SanshaHiddenRallyPointPriority, SetSanshaHiddenRallyPointPriority)	
	Setting(int, SanshaForsakenRallyPointPriority, SetSanshaForsakenRallyPointPriority)	
	Setting(int, SanshaForlornRallyPointPriority, SetSanshaForlornRallyPointPriority)	
	Setting(int, SanshaPortPriority, SetSanshaPortPriority)
	Setting(int, SanshaHubPriority, SetSanshaHubPriority)	
	Setting(int, SanshaHiddenHubPriority, SetSanshaHiddenHubPriority)	
	Setting(int, SanshaForsakenHubPriority, SetSanshaForsakenHubPriority)	
	Setting(int, SanshaForlornHubPriority, SetSanshaForlornHubPriority)	
	Setting(int, SanshaHavenPriority, SetSanshaHavenPriority)	
	Setting(int, SanshaSanctumPriority, SetSanshaSanctumPriority)	
	; Serpentis Section
	Setting(int, SerpentisHideawayPriority, SetSerpentisHideawayPriority)
	Setting(int, SerpentisHiddenHideawayPriority, SetSerpentisHiddenHideawayPriority)	
	Setting(int, SerpentisForsakenHideawayPriority, SetSerpentisForsakenHideawayPriority)	
	Setting(int, SerpentisForlornHideawayPriority, SetSerpentisForlornHideawayPriority)	
	Setting(int, SerpentisBurrowPriority, SetSerpentisBurrowPriority)	
	Setting(int, SerpentisRefugePriority, SetSerpentisRefugePriority)	
	Setting(int, SerpentisDenPriority, SetSerpentisDenPriority)	
	Setting(int, SerpentisHiddenDenPriority, SetSerpentisHiddenDenPriority)	
	Setting(int, SerpentisForsakenDenPriority, SetSerpentisForsakenDenPriority)	
	Setting(int, SerpentisForlornDenPriority, SetSerpentisForlornDenPriority)	
	Setting(int, SerpentisYardPriority, SetSerpentisYardPriority)	
	Setting(int, SerpentisRallyPointPriority, SetSerpentisRallyPointPriority)
	Setting(int, SerpentisHiddenRallyPointPriority, SetSerpentisHiddenRallyPointPriority)	
	Setting(int, SerpentisForsakenRallyPointPriority, SetSerpentisForsakenRallyPointPriority)	
	Setting(int, SerpentisForlornRallyPointPriority, SetSerpentisForlornRallyPointPriority)	
	Setting(int, SerpentisPortPriority, SetSerpentisPortPriority)
	Setting(int, SerpentisHubPriority, SetSerpentisHubPriority)	
	Setting(int, SerpentisHiddenHubPriority, SetSerpentisHiddenHubPriority)	
	Setting(int, SerpentisForsakenHubPriority, SetSerpentisForsakenHubPriority)	
	Setting(int, SerpentisForlornHubPriority, SetSerpentisForlornHubPriority)	
	Setting(int, SerpentisHavenPriority, SetSerpentisHavenPriority)	
	Setting(int, SerpentisSanctumPriority, SetSerpentisSanctumPriority)	
	; Drone Section 
	Setting(int, DroneClusterPriority, SetDroneClusterPriority)
	Setting(int, DroneCollectionPriority, SetDroneCollectionPriority)	
	Setting(int, DroneAssemblyPriority, SetDroneAssemblyPriority)	
	Setting(int, DroneGatheringPriority, SetDroneGatheringPriority)	
	Setting(int, DroneSurveillancePriority, SetDroneSurveillancePriority)	
	Setting(int, DroneMenageriePriority, SetDroneMenageriePriority)	
	Setting(int, DroneHerdPriority, SetDroneHerdPriority)	
	Setting(int, DroneSquadPriority, SetDroneSquadPriority)	
	Setting(int, DronePatrolPriority, SetDronePatrolPriority)	
	Setting(int, DroneHordePriority, SetDroneHordePriority)
	
	; Need to keep track of what Anom we are running in a way that persists 
	Setting(int64, PersistentAnomID, setPersistentAnomID)
	
	; To keep track of Da Boss, persistently
	Setting(int64, DaBossID, SetDaBossID)	

	;;; Fleet stuff may or may not be implemented. Idk.
	; Are we going to fleet up?
	Setting(bool, FleetUp, SetFleetUp)
	; Are we Da Boss?
	Setting(bool, FleetBoss, SetFleetBoss)	
	
	
	Setting(int, LogLevelBar, SetLogLevelBar)
}

objectdef obj_CombatAnoms inherits obj_StateQueue
{


	variable string targetToDestroy
	variable string ammo
	variable string secondaryAmmo
	variable string tertiaryAmmo
	variable string containerToLoot


	;;;;;;;;;; Used when performing mission.
	; If a target can't be killed within 2 minutes, something is going wrong.
	variable int maxAttackTime
	variable int switchTargetAfter = 120


	; Used to see if we need to manually recalculate our combat anom priority list
	; Should only be done after you make a change
	variable bool ReCalculatePriorities

	variable obj_TargetList PCs
	variable obj_TargetList NPCs
	variable obj_TargetList ActiveNPCs
	variable obj_TargetList Lootables

	variable obj_Configuration_CombatAnoms Config
	variable obj_Configuration_Agents Agents
	variable obj_CombatAnomsUI LocalUI

	variable bool reload = TRUE
	variable bool halt = FALSE
	
	variable bool StatusGreen
	variable bool StatusChecked
	variable bool OverheatSetup
	variable bool AbandonMTU
	variable bool GrabbedLoot = FALSE
	variable bool InitialTry
	
	; This collection is to help create the sets below. Key is the name of the Anomaly
	; Value is the priority number assigned.
	variable collection:int PriorityCollection
	; This set is for Ignored Anomalies
	variable set IgnoredAnomalies
	; This set is for Highest Priority Anomalies
	variable set HighPriorityAnomalies
	; This set is for Medium Priority Anomalies
	variable set MediumPriorityAnomalies
	; This set is for Lowest Priority Anomalies
	variable set LowPriorityAnomalies
	
	; This is an exit condition, sends the Anom Runners back home and has them warp back when the boss says to.
	variable bool ScramYaMooks
	
	; This is a bool that MinerWorker will use to say that it has depleted the area.
	variable bool LocationDepleted

	; This will be used for timekeeping after a fleeing event.
	variable int64 ClearToAnom
	; This bool will be set by an event triggered ostensibly by Da Boss. It says to come out and mine its time.
	variable bool LeaderSummons

	;  If true it will send us back to station.
	variable bool ReturnToStation
	
	; We store the coordinates of our chosen Anom here, so we can do math because .Distance was simply too
	; God damn hard to implement apparently.
	variable point3f CurrentAnomCoords
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

	method Initialize()
	{
		This[parent]:Initialize

		DynamicAddBehavior("CombatAnoms", "CombatAnoms Runner")
		This.PulseFrequency:Set[3500]

		This.LogInfoColor:Set["g"]
		This.LogLevelBar:Set[${Config.LogLevelBar}]

		LavishScript:RegisterEvent[Tehbot_ScheduleHalt]
		Event[Tehbot_ScheduleHalt]:AttachAtom[This:ScheduleHalt]
		LavishScript:RegisterEvent[Tehbot_ScheduleResume]
		Event[Tehbot_ScheduleResume]:AttachAtom[This:ScheduleResume]

		Lootables:AddQueryString["(GroupID = GROUP_WRECK || GroupID = GROUP_CARGOCONTAINER) && !IsMoribund"]

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
		Ship.${WeaponSwitch}:ConfigureAmmo[${ammo}, ${secondaryAmmo}, ${tertiaryAmmo}]
		;Ship.ModuleList_Ancillary_Shield_Booster:ConfigureAmmo[${Config.BatteryToBring}]
		
		; We are running CombatAnoms, our weapons are vortons (edencom), we should set up for overheat.
		if ${Client.InSpace} && ${Ship.ModuleList_VortonWeapon.Count} > 0 && ${Config.Overheat} && !${OverheatSetup}
		{
			This:LogInfo["Setting Vorton Overload HP Limit"] 
			Ship.ModuleList_VortonWeapon:SetOverloadHPThreshold[15]
			OverheatSetup:Set[TRUE]
		}
		; We are running CombatAnomss, our weapons are disintegration orbs, love orbs, anyways, overload the orbs.
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
		; People with neutral standings or worse are in local, and we are configured to run. Run.
		if !${FriendlyLocal} && ${Config.RunFromBads} && !${Me.InStation} && !${Bookmark[${Config.POSBookmarkName}].Distance} < 50000
		{
			This:LogInfo["Jerks in Local, lets get out of here"]
			; If we are set to run to a POS
			if ${Config.UsePOSHidingSpot} && ${Config.POSBookmarkName.NotNULLOrEmpty}
			{
				if ${Config.HideHowLong} == 0
				{
					ClearToAnom:Set[${Math.Calc[${LavishScript.RunningTime} + 999999999999999999999999999999999999]}]	
				}
				else
				{
					ClearToAnom:Set[${Math.Calc[${LavishScript.RunningTime} + (${Config.HideHowLong} * 60000)]}]
				}
				This:LogInfo["Hope there is actually a POS here"]
				This:InsertState["FleeToPOS"]
				return TRUE
			}
			if ${Config.UseWeirdNavigation} && ${Config.WeirdBookmarkPrefix.NotNULLOrEmpty}
			{
				if ${Config.HideHowLong} == 0
				{
					ClearToAnom:Set[${Math.Calc[${LavishScript.RunningTime} + 999999999999999999999999999999999999]}]	
				}
				else
				{
					ClearToAnom:Set[${Math.Calc[${LavishScript.RunningTime} + (${Config.HideHowLong} * 60000)]}]
				}			
				This:LogInfo["Commence Weird Navigation"]
				This:InsertState["WeirdNavigation"]
				return TRUE
			}
			
			if ${Config.HideHowLong} == 0
			{
				ClearToAnom:Set[${Math.Calc[${LavishScript.RunningTime} + 999999999999999999999999999999999999]}]	
			}
			else
			{
				ClearToAnom:Set[${Math.Calc[${LavishScript.RunningTime} + (${Config.HideHowLong} * 60000)]}]
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
				ClearToAnom:Set[${Math.Calc[${LavishScript.RunningTime} + (${Config.HideHowLong} * 60000)]}]
			}			
		}
		; We are in a station, we are still inside the time set by a Fleeing Event
		if ${LavishScript.RunningTime} < ${ClearToAnom}
		{
			return FALSE
		}
		; We are in space, but not the abyss, we have time to see if we need anything.
		if ${Client.InSpace} && !${This.InAnom} && !${StatusChecked}
		{
			This:LogInfo["Status Check"]
			This:InsertState["CheckStatus", 5000]
			return TRUE
		}
		; We are in space, not in an anom, and we have no problems. Lets go to an anom.
		if ${Client.InSpace} && !${This.InAnom} && ${StatusGreen}
		{
			This:LogInfo["Go to CombatAnoms Site]
			This:InsertState["GoToAnom", 5000]
			return TRUE
		}
		; We are in space and need resupply and/or repair, back to base
		if ${Client.InSpace} && !${This.InAnom} && !${StatusGreen}
		{
			This:LogInfo["Go back to the station"]
			This:InsertState["GoToStation"]
			return TRUE
		}
		; We are in a Combat Anomaly, local is safe (if we care about such things), run the anomaly.
		if ${Client.InSpace} && ${This.InAnom}
		{
			This:LogInfo["We appear to be in The Anom"]
			This:QueueState["RunTheAnom"]
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
				This:LogInfo["${Config.MTUType} is Missing"]
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
				This:LogInfo["${Config.DrugsToUse} are out"]
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
		if ${Config.HomeStructure.NotNULLOrEmpty}
		{
			Move:Bookmark["${Config.HomeStructure}"]
			This:InsertState["Traveling"]
			This:QueueState["CheckForWork", 5000]
			return TRUE
		}
		else
		{
			This:LogInfo["HomeStructure BM not found, stopping"]
			This:Stop
		}
	}
	; Here is where we will take our PriorityCollection and sort it out into the Priority Sets
	method ReCalcPriorities()
	{
		IgnoredAnomalies:Clear
		HighPriorityAnomalies:Clear
		MediumPriorityAnomalies:Clear
		LowPriorityAnomalies:Clear
		
		if ${PriorityCollection.FirstValue}
		{
			do
			{
				if ${PriorityCollection.CurrentValue} == 0
				{
					IgnoredAnomalies:Add[${PriorityCollection.CurrentKey}]
					echo DEBUG - Adding ${PriorityCollection.CurrentKey} to Ignore List
				}
				if ${PriorityCollection.CurrentValue} == 1
				{
					HighPriorityAnomalies:Add[${PriorityCollection.CurrentKey}]
					echo DEBUG - Adding ${PriorityCollection.CurrentKey} to Highest Priority List
				}
				if ${PriorityCollection.CurrentValue} == 2
				{
					MediumPriorityAnomalies:Add[${PriorityCollection.CurrentKey}]
					echo DEBUG - Adding ${PriorityCollection.CurrentKey} to Medium Priority List
				}
				if ${PriorityCollection.CurrentValue} == 3
				{
					LowPriorityAnomalies:Add[${PriorityCollection.CurrentKey}]
					echo DEBUG - Adding ${PriorityCollection.CurrentKey} to Low Priority List
				}
			}
			while ${PriorityCollection.NextKey(exists)}
		}
		
		ReCalculatePriorities:Set[FALSE]
	}
	
	; We have all we need, go to the Abyss. We will look at all present anoms
	; Then filter out ignored/unlisted anoms. Then go to anoms based on priority.
	; This will mostly be recycled code from my Miner Mainmode so it should work. Should.
	member:bool GoToAnom()
	{
		This:ReCalculatePriorities
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
					CurrentAnomCoords:Set[${MyAnomalies_Iterator.Value.X},${MyAnomalies_Iterator.Value.Y},${MyAnomalies_Iterator.Value.Z}]
					This:LogInfo["Anomaly Found - ${MyAnomalies_Iterator.Value.Name} - Warping]
					This:InsertState["Traveling", 5000]
					This:QueueState["StartWorking", 5000]
					return TRUE
				
				}
				elseif ${HighPriorityAnomalies.Contains[${MyAnomalies_Iterator.Value.DungeonName}]}
				{
					Script[Tehbot].VariableScope.CombatAnoms.Config:setPersistentAnomID[${MyAnomalies_Iterator.Value.ID}]
					CurrentAnomCoords:Set[${MyAnomalies_Iterator.Value.X},${MyAnomalies_Iterator.Value.Y},${MyAnomalies_Iterator.Value.Z}]
					MyAnomalies_Iterator.Value:WarpTo[${Config.WarpInDistance}, FALSE]
					This:LogInfo["Anomaly Found - ${MyAnomalies_Iterator.Value.Name} - Warping]
					This:InsertState["Traveling", 5000]
					This:QueueState["StartWorking", 5000]
					return TRUE
				}
				elseif ${MediumPriorityAnomalies.Contains[${MyAnomalies_Iterator.Value.DungeonName}]}
				{
					Script[Tehbot].VariableScope.CombatAnoms.Config:setPersistentAnomID[${MyAnomalies_Iterator.Value.ID}]
					CurrentAnomCoords:Set[${MyAnomalies_Iterator.Value.X},${MyAnomalies_Iterator.Value.Y},${MyAnomalies_Iterator.Value.Z}]
					MyAnomalies_Iterator.Value:WarpTo[${Config.WarpInDistance}, FALSE]
					This:LogInfo["Anomaly Found - ${MyAnomalies_Iterator.Value.Name} - Warping]
					This:InsertState["Traveling", 5000]
					This:QueueState["StartWorking", 5000]
					return TRUE
				}
				; Everything else goes here
				elseif ${LowPriorityAnomalies.Contains[${MyAnomalies_Iterator.Value.DungeonName}]}
				{
					Script[Tehbot].VariableScope.CombatAnoms.Config:setPersistentAnomID[${MyAnomalies_Iterator.Value.ID}]
					CurrentAnomCoords:Set[${MyAnomalies_Iterator.Value.X},${MyAnomalies_Iterator.Value.Y},${MyAnomalies_Iterator.Value.Z}]
					MyAnomalies_Iterator.Value:WarpTo[${Config.WarpInDistance}, FALSE]
					This:LogInfo["Anomaly Found - ${MyAnomalies_Iterator.Value.Name} - Warping]
					This:InsertState["Traveling", 5000]
					This:QueueState["StartWorking", 5000]
					return TRUE
				}
				else
				{
					Config.PersistentAnomID:Set[0]
					continue
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
	
	; This is where the logic for actually running and completing the CombatAnoms will go.
	member:bool RunTheAnom()
	{
		; Something went wrong here
		if !${This.InAnom}
		{
			This:QueueState["CheckForWork", 10000]
			return TRUE
		}
		if (!${FriendlyLocal} && ${Config.RunFromBads})
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
					ClearToAnom:Set[${Math.Calc[${LavishScript.RunningTime} + 999999999999999999999999999999999999]}]	
				}
				else
				{
					ClearToAnom:Set[${Math.Calc[${LavishScript.RunningTime} + (${Config.HideHowLong} * 60000)]}]
				}
				This:LogInfo["Hope there is actually a POS here"]
				This:InsertState["FleeToPOS"]
				return TRUE
			}
			if ${Config.UseWeirdNavigation} && ${Config.WeirdBookmarkPrefix.NotNULLOrEmpty}
			{
				if ${Config.HideHowLong} == 0
				{
					ClearToAnom:Set[${Math.Calc[${LavishScript.RunningTime} + 999999999999999999999999999999999999]}]	
				}
				else
				{
					ClearToAnom:Set[${Math.Calc[${LavishScript.RunningTime} + (${Config.HideHowLong} * 60000)]}]
				}			
				This:LogInfo["Commence Weird Navigation"]
				This:InsertState["WeirdNavigation"]
				return TRUE
			}
			
			if ${Config.HideHowLong} == 0
			{
				ClearToAnom:Set[${Math.Calc[${LavishScript.RunningTime} + 999999999999999999999999999999999999]}]	
			}
			else
			{
				ClearToAnom:Set[${Math.Calc[${LavishScript.RunningTime} + (${Config.HideHowLong} * 60000)]}]
			}
			This:InsertState["GoToStation", 3000]
			return TRUE
			
		}
		; We're Stormbringing it up but we didnt have enough time to repair, and waiting for repairs will cost more damage than not overheating. Cancel the repair.
		; Also I swear if you don't put your SINGLE WEAPON in the very first slot you're crazy.
		if ${Config.Overheat} && ${MyShip.Module[HiSlot0].IsBeingRepaired}
		{
			MyShip.Module[HiSlot0]:CancelRepair
		}
		if ${This.JerksPresent} && ${This.InAnom}
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
			; Anom running logic will go here. Going to be two cases here. Warp at 100 km and align to home structure
			; and warp in at some distance and orbit either an MTU or some object.
			; Maybe a third case for just chasing shit around the anom but that sounds rather exceptionally stupid in 0.0
			; So maybe not.
			return FALSE
		}
		
	}
	; This one tells us if another player is present (ignoring fleet members), intended to be used on arriving at an anom.
	member:bool OtherPlayersPresent()
	{
		PCs:AddAllPC
		PCs:RequestUpdate
		
		if ${PCs.TargetList.Used}
		{
			return TRUE
		}
		else
		{
			return FALSE
		}
	
	}

	; This one is for seeing if there are targets present. Returns TRUE if there are hostile NPCs and FALSE if not.
	member:bool JerksPresent()
	{
		if ${TargetManager.ActiveNPCs.TargetList.Used} || ${TargetManager.NPCs.TargetList.Used}
		{
			return TRUE
		}
		else
		{
			return FALSE
		}
	}
	; We use this to flee to a POS and hang out there until the heat is gone.
	member:bool FleeToPOS()
	{
		if !${Config.UseWeirdNavigation}
		{
			Move:Bookmark["${POSBookmarkName}"]
			This:InsertState["Traveling"]
			This:InsertState["CheckForWork", 5000]
		}
		
	}
	; This is Weird Navigation, we use it to bounce around a bit before going to our fleeing destination
	; Not done yet.
	member:bool WeirdNavigation()
	{
		
	
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
				This:InsertState["RunTheAnom"]
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
					This:InsertState["RunTheAnom"]
					return TRUE
				}
			}
			if !${This.MTUDeployed} && !${Entity[Name == "Cargo Container"](exists)}
			{
				This:InsertState["RunTheAnom"]
				return TRUE				
			}
		}
	This:QueueState["PickupMTU", 5000]
	return TRUE
	}
	
	; Just returns a bool for if we are in an Anom currently. Going to be a little weird to figure out. Distance To anoms doesn't work.
	; Not sure why we can't just easily do distance when we have X,Y,Z coords but fine we'll do the math instead. 
	member:bool InAnom()
	{
		if !${Client.InSpace}
		{
			return FALSE
		}
		if ${Math.Distance[${Me.ToEntity.X},${Me.ToEntity.Y},${Me.ToEntity.Z},${CurrentAnomCoords.X},${CurrentAnomCoords.Y},${CurrentAnomCoords.Z}] < 200000}
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
				   !${itemIterator.Value.Name.Equal[${Ship.${WeaponSwitch}.FallbackAmmo}]} && \
				   !${itemIterator.Value.Name.Equal[${Ship.${WeaponSwitch}.FallbackLongRangeAmmo}]} && \
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
				if ((${Ship.${WeaponSwitch}.Count} && \
					!${itemIterator.Value.Name.Equal[${Ship.${WeaponSwitch}.FallbackAmmo}]} && \
					!${itemIterator.Value.Name.Equal[${Ship.${WeaponSwitch}.FallbackLongRangeAmmo}]} && \
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
					Ship.${WeaponSwitch}:ConfigureAmmo[${ammo}, ${secondaryAmmo}, ${tertiaryAmmo}]
				}

				if ${Config.BatteryToBring.NotNULLOrEmpty}
				{
					Ship.ModuleList_Ancillary_Shield_Booster:ConfigureAmmo[${Config.BatteryToBring}]
				}

				Ship.${WeaponSwitch}:ReloadDefaultAmmo

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


objectdef obj_CombatAnomsUI inherits obj_State
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