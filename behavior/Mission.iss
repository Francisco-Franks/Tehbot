objectdef obj_Configuration_Agents inherits obj_Configuration_Base
{
	method Initialize()
	{
		This[parent]:Initialize["Agents"]
	}

	member:settingsetref AgentRef(string name)
	{
		return ${This.ConfigRef.FindSet[${name}]}
	}

	method Set_Default_Values()
	{
		ConfigManager.ConfigRoot:AddSet[${This.SetName}]
	}

}

objectdef obj_Configuration_Mission inherits obj_Configuration_Base
{
	method Initialize()
	{
		This[parent]:Initialize["Mission"]
	}

	method Set_Default_Values()
	{
		ConfigManager.ConfigRoot:AddSet[${This.SetName}]
		This.ConfigRef:AddSetting[RunNumberInt, 1]
		This.ConfigRef:AddSetting[InventoryPulseRateModifier, 1.0]
		This.ConfigRef:AddSetting[WreckBMThreshold, 7]
	}
	Setting(bool, Halt, SetHalt)
	; This bool indicates we want to repeatedly Decline missions despite the standings damage
	; It is implied you know what you are doing with this. We won't be running multiple agents in this Tehbot fork.
	Setting(bool, RepeatedlyDecline, SetRepeatedlyDecline)
	; This bool indicates we want to run Combat Missions.
	Setting(bool, DoCombat, SetDoCombat)
	; This bool indicates we want to run courier Missions. If the above is selected as well
	; then it is implied you are running combat missions and also the occasional courier missions that crop up.
	Setting(bool, DoCourier, SetDoCourier)
	; This bool indicates we want to do Storyline missions that meet our other set criteria.
	; This implies you want to do Combat missions (if selected), Courier Missions (if selected), and Trade Mission Turnins (no selection) of the Storyline type.
	; If a combat mission isn't configured, but selected, we will just ignore it. If courier is selected, be damn well sure you have a ship that can do it efficiently.
	; If you have this checked, and since trade missions are implied, you SHOULD have a hauler of some type configured. If you have no hauler configured then Trade type storylines will be ignored.
	; If we are set to avoid lowsec, and there is lowsec at the source, destination, or anywhere in between, we will ignore the storyline.
	Setting(bool, DoStoryline, SetDoStoryline)
	; Do storyline combat missions
	Setting(bool, DoStorylineCombat, SetDoStorylineCombat)
	; The literal names of your combat and courier ships. In case we need to swap between them.
	Setting(string, CombatShipType, SetCombatShipType)
	Setting(string, CourierShipType, SetCourierShipType)
	; Literal name of your ore hauler for trade missions
	Setting(string, TradeShipType, SetTradeShipType)
	; Literal name of a fast, low volume courier ship.
	Setting(string, FastCourierShipType, SetFastCourierShipType)
	; These will be settings taken from the original that still go on page 1 of the UIElement
	Setting(bool, IgnoreNPCSentries, SetIgnoreNPCSentries)
	; This is just what we name our Salvage BMs. If we are going to use the new salvager that I am supposedly making
	; this is kinda superfluous. But whatever. Maybe its good for backwards compat.
	Setting(string, SalvagePrefix, SetSalvagePrefix)	
	; What is the name of the folder your salvage bookmarks should be placed in. MAKE SURE THIS EXISTS
	; I don't remember what sanity checks exist on the isxeve side of things here, so lets assume the worst and that if you fuck this up the world will literally end.
	Setting(string, SalvageBMFolderName, SetSalvageBMFolderName)
	; This is the name of the XML in Data with your mission info in it.
	Setting(string, MissionFile, SetMissionFile)	
	; This bool indicates we want to stay out of Lowsec
	Setting(bool, DeclineLowSec, SetDeclineLowSec)
	

	
	
	; Page 2 of the UI  Begins
	; Ammo and drone stuff
	Setting(bool, UseSecondaryAmmo, SetSecondary)
	Setting(bool, UseDrones, SetDrones)
	Setting(string, DroneType, SetDroneType)
	Setting(string, MissionFile, SetMissionFile)
	Setting(string, KineticAmmo, SetKineticAmmo)
	Setting(string, ThermalAmmo, SetThermalAmmo)
	Setting(string, EMAmmo, SetEMAmmo)
	Setting(string, ExplosiveAmmo, SetExplosiveAmmo)
	Setting(string, KineticAmmoSecondary, SetKineticAmmoSecondary)
	Setting(string, ThermalAmmoSecondary, SetThermalAmmoSecondary)
	Setting(string, EMAmmoSecondary, SetEMAmmoSecondary)
	Setting(string, ExplosiveAmmoSecondary, SetExplosiveAmmoSecondary)
	Setting(int, AmmoAmountToLoad, SetAmmoAmountToLoad)
	
	; Page 3 of the UI begins
	; Storage and Misc
	
	Setting(bool, DropOffToContainer, SetDropOffToContainer)	
	Setting(string, DropOffContainerName, SetDropOffContainerName)	
	Setting(string, MunitionStorage, SetMunitionStorage)
	Setting(string, MunitionStorageFolder, SetMunitionStorageFolder)
	; No guarantee that I will get this working but, this setting indicates that you are going to be helping a different bot with their missions
	Setting(bool, SidekickMode, SetSidekickMode)
	; Literal character name of whoever you are helping as a sidekick.
	Setting(string, PrimaryName, SetPrimaryName)
	; This will be the network path for the Extremely Shared DB. I will use this for my off-machine salvagers to work. Most people will never ever use this.
	Setting(string, ExtremelySharedDBPath, SetExtremelySharedDBPath)
	; This will be a prefix slapped onto the DB filename in the above path.
	Setting(string, ExtremelySharedDBPrefix, SetExtremelySharedDBPrefix)
	
	; Since inventory is so wildly fucking variable per client, I will need to create a way to modify the pulse on inventory actions.
	; This will be multiplier with the pulse for inventory actions. Higher number means slower actions.
	Setting(float, InventoryPulseRateModifier, SetInventoryPulseRateModifier)
	
	; Threshold for Salvage BM Creation. Its an int. If this many wrecks or more exist, a salvage BM will be created. If there are any navy wrecks around we will ignore this and BM regardless.
	Setting(int, WreckBMThreshold, SetWreckBMThreshold)

	; This won't go in the UI anywhere, just need a persistent storage for our Run Number because I'm lazy.
	; To be honest, mostly just need this to initialize the number the first time around. This will be incremented after each mission completion.
	Setting(int, RunNumberInt, SetRunNumberInt)

}

objectdef obj_Mission inherits obj_StateQueue
{
	; This DB will be specific to the particular character
	variable sqlitedb CharacterSQLDB
	; This DB will be Shared by all clients on this machine.
	variable sqlitedb SharedSQLDB
	; This DB will be Extremely Shared, that is to say it will be a network location.
	variable sqlitedb ExtremelySharedSQLDB
	; Bool so we don't spam WAL all day
	variable bool WalAssurance = FALSE	
	
	; SQLite Queries
	; For getting general info from the MissionJournal Table
	variable sqlitequery GetDBJournalInfo
	; For getting info about our current combat mission
	variable sqlitequery GetMissionLogCombat
	; For getting info about our current courier mission
	variable sqlitequery GetMissionLogCourier
	; Multi-purpose query for using less lines to do a mid-run recovery
	variable sqlitequery GetMissionLogCombined
	; RoomNPCInfo lookup query
	variable sqlitequery GetRoomNPCInfo

	; This queue will store the AgentIDs of agents we need to contact to decline their missions as part of CurateMissions state.
	variable queue:int64 AgentDeclineQueue

	; Have we checked our mission logs?
	variable bool CheckedMissionLogs
	; Have we completed our Databasification? This bool indicates such.
	variable bool DatabasificationComplete = FALSE
	; index where we place our strings for SQL execution
	variable index:string DML

	; These are needed to store what comes out of my HTML parsing method. Because I can't remember if the method has its own scope, inherits scope from where it is called, or takes the entire scripts scope.
	variable string LastAgentLocation
	variable string LastMissionLocation
	variable string LastExpectedItems
	variable int	LastItemUnits
	variable int64	LastItemVolume
	variable bool	LastLowsec
	variable string LastDropoff
	variable string LastPickup
	variable string LastLPReward
	variable int64	LastPickupID
	variable int64	LastDropoffID

	
	; Storage variables for our Current (selected) Agent / Mission
	variable int64	CurrentAgentID
	variable int64	CurrentAgentIndex
	variable string CurrentAgentLocation
	variable string CurrentAgentShip
	variable string CurrentAgentItem
	variable int	CurrentAgentItemUnits
	variable int64	CurrentAgentVolumePer
	variable int64	CurrentAgentVolumeTotal
	variable string CurrentAgentPickup
	variable int64	CurrentAgentPickupID
	variable string CurrentAgentDropoff
	variable int64	CurrentAgentDropoffID
	variable string CurrentAgentDamage
	variable string CurrentAgentDestroy
	variable string CurrentAgentLoot
	variable string	CurrentAgentMissionName
	variable string CurrentAgentMissionType
	variable int	CurrentAgentLPReward
	
	; Storage variables for our Current Run
	variable int	CurrentRunNumber
	variable int	CurrentRunRoomNumber
	variable int64	CurrentRunStartTimestamp
	variable bool	CurrentRunKilledTarget
	variable bool	CurrentRunVanquisher
	variable bool	CurrentRunContainerLooted
	variable bool	CurrentRunHaveItems
	variable bool	CurrentRunTechnicalComplete
	variable bool	CurrentRunTrueComplete
	variable int64	CurrentRunFinalTimestamp
	variable int	CurrentRunTripNumber
	variable int	CurrentRunExpectedTrips
	variable int	CurrentRunItemUnitsMoved
	variable int64	CurrentRunVolumeMoved
	variable int64	CurrentRunISKReward
	; Going to try an advanced tactic here. This will be a collection of Acceleration Gates we have used during the current mission.
	; Key is the Name of the Gate. Value is the Entity ID (int64)
	variable collection:int64 CurrentRunGatesUsed
	
	; Courier Mission State Specific Variables
	variable int	CourierMissionShipItems
	variable int 	CourierMissionStationItems
	; Not sure if I need to get this granular
	;variable int	CourierMissionPickupStationItems
	;variable int	CourierMissionDropoffStationItems
	variable string	CourierMissionTravelState

	; Combat Mission Stat Specific Variables
	variable collection:int64 CombatMissionCloseTargets
	variable collection:int64 CombatMissionMidrangeTargets
	variable collection:int64 CombatMissionDistantTargets
	variable bool	CombatMissionDestroyTargetSeen

	; Some variable for our current room
	variable int64	CurrentRoomStartTime
	variable int64	CurrentRoomEndTime
	
	; Some variables about our current hauler, either for courier or for trade. Whatever we are flying at the moment.
	variable string	HaulerLargestBayType
	variable int64	HaulerLargestBayCapacity
	variable bool	HaulerLargestBayOreLimited
	variable string	HaulerLargestBayLocationFlag
	
	; Need an index of strings so we can handle the NPC databasification more easily.
	variable index:string NPCDBDML
	; Need this bool in case we go to change ships, and fail to do so.
	variable bool	FailedToChangeShip = FALSE
	; More bespoke bools
	variable bool	ShipCargoChecked
	variable bool	ShipFleetHangarChecked
	variable bool	ShipOreBayChecked
	variable bool	LargestBayRefreshed
	variable bool	CorpHangarRefreshed
	variable bool	StationHangarRefreshed

	; Two more variables so we can record our wallet just BEFORE we complete a mission, and again just AFTER.
	; Doing this so we can get the isk reward for the mission quantified without dealing with parsing HTML.
	variable int64 ISKBeforeCompletion
	variable int64 ISKAfterCompletion

	; These had to be pulled out of Databasification due to do:while complications
	variable index:agentmission missions
	variable iterator missionIterator
	
	; Recycled variables from the original
	variable string ammo
	variable string secondaryAmmo
	variable int	useDroneRace = 0
	variable obj_Configuration_Mission Config
	variable obj_Configuration_Agents Agents
	variable obj_MissionUI2 LocalUI
	variable bool 	reload = TRUE
	variable bool	halt = FALSE

	
	variable index:string AgentList	
	variable set BlackListedMission
	variable collection:string DamageType
	variable collection:string TargetToDestroy
	variable collection:string ContainerToLoot
	variable collection:int64 CapacityRequired
	variable collection:string RequiredItems
	
	; Target list(s)
	; TargetList for DatabasifyNPCs method.
	variable obj_TargetList DatabasifyNPC
	variable obj_TargetList Lootables
	
	; Timer for last NPC databasification
	variable int64 LastNPCDatabasification

	; Need to set our Primary Agent's Index. Primary Agent is the first agent in your mission datafile.
	variable int64 PrimaryAgentIndex
	
	; Need to store this somewhere
	variable int64 ObjectiveID
	
	; Annoying as hell, I hate gate moves
	variable bool HaveGated
	
	method Initialize()
	{
		This[parent]:Initialize

		DynamicAddBehavior("Mission", "Missioneer 2")
		This.PulseFrequency:Set[3500]

		This.LogInfoColor:Set["g"]
		This.LogLevelBar:Set[${Config.LogLevelBar}]

		LavishScript:RegisterEvent[Tehbot_ScheduleHalt]
		Event[Tehbot_ScheduleHalt]:AttachAtom[This:ScheduleHalt]
		LavishScript:RegisterEvent[Tehbot_ScheduleResume]
		Event[Tehbot_ScheduleResume]:AttachAtom[This:ScheduleResume]
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
		AgentList:Clear
		DamageType:Clear
		ContainerToLoot:Clear
		BlackListedMission:Clear
		DontFightFaction:Clear
		TargetToDestroy:Clear
		GateKey:Clear
		GateKeyContainer:Clear

		if !${Config.MissionFile.NotNULLOrEmpty}
		{
			This:LogCritical["You need to specify a Mission file!"]
			return
		}
		variable filepath MissionData = "${Script[Tehbot].CurrentDirectory}/data/${Config.MissionFile}"
		runscript "${MissionData}"
		
		This:QueueState["CheckForWork",5000]
		UIElement[Run@TitleBar@Tehbot]:SetText[Stop]
		DatabasifyNPC:AddAllNPCs
		Lootables:AddQueryString["(GroupID = GROUP_WRECK || GroupID = GROUP_CARGOCONTAINER) && !IsMoribund"]
	}

	method Stop()
	{
		This:LogInfo["Stopping."]
		This:Clear
		Tehbot.Paused:Set[TRUE]
		UIElement[Run@TitleBar@Tehbot]:SetText[Run]
		CharacterSQLDB:Close
		SharedSQLDB:Close
		ExtremelySharedSQLDB:Close
		
	}

	method Shutdown()
	{
		CharacterSQLDB:Close
		SharedSQLDB:Close
		ExtremelySharedSQLDB:Close
	}
	
	; Vaguely useful.
	member:bool Repair()
	{
		if ${Me.InStation} && ${Utility.Repair}
		{
			This:InsertState["Repair", 2000]
			return TRUE
		}

		return TRUE
	}

	; Well, here we are again. Instead of making something new I will be taking the Missioneer and making it (hopefully) better.
	; Addendum - My ambitions and hubris increased so the core logic of the missioneer will be new. I am stealing some ancillary stuff from the old missioneer
	; namely station interaction related stuff. It works enough.
	; Integrating all of the things I have learned so far. So here we begin as usual at CheckForWork. The central hub from which we do everything
	; else in this main mode. SQL integration is mandatory. We live in an SQL revolution now. 
	member:bool CheckForWork()
	{
		if ${PrimaryAgentIndex} < 1
		{
			PrimaryAgentIndex:Set[${EVE.Agent[${AgentList.Get[1]}].Index}]
		}		
		; SQL DB related stuff.
		if !${CharacterSQLDB.ID(exists)} || !${SharedSQLDB.ID(exists)} || ( !${ExtremelySharedSQLDB.ID(exists)} && ( ${Config.ExtremelySharedDBPath.NotNULLOrEmpty} && ${Config.ExtremelySharedDBPrefix.NotNULLOrEmpty} ))
		{
			; Setting our character specific and shared DBs.
			CharacterSQLDB:Set[${SQLite.OpenDB["${Me.Name}DB","${Me.Name}DB.sqlite3"]}]
			SharedSQLDB:Set[${SQLite.OpenDB["MissionSharedDB","MissionSharedDB.sqlite3"]}]
			if ${Config.ExtremelySharedDBPath.NotNULLOrEmpty} && ${Config.ExtremelySharedDBPrefix.NotNULLOrEmpty}
            {
                ExtremelySharedSQLDB:Set[${SQLite.OpenDB["${Config.ExtremelySharedDBPrefix}SharedDB","${Config.ExtremelySharedDBPath.ReplaceSubstring[\\,\\\\]}${Config.ExtremelySharedDBPrefix}SharedDB.sqlite3"]}]
            }
			if !${WalAssurance}
			{
				This:EnsureWAL
			}
		}
		if ${CharacterSQLDB.ID(exists)} && ${SharedSQLDB.ID(exists)} && ( ${ExtremelySharedSQLDB.ID(exists)} || ( !${Config.ExtremelySharedDBPath.NotNULLOrEmpty} && !${Config.ExtremelySharedDBPrefix.NotNULLOrEmpty} ))
		{
			; Let us initialize our tables if they don't already exist.
			; Hopefully, I can remember all the brilliant ideas I had yesterday.
			; First up, Character specific DB tables.
			
			; This table will be for keeping track of our Journal stuff.
			; Agent ID is our primary key (integer). An agent can't have more than one active mission so that should be fine.
			; Then we will get Mission Name (string), Mission Type (string), Mission Status (int). These are the things we can pull directly.
			; It would be useful to have some more meta information available about the mission though.
			; I also want to know where is this agent located, and if it is in Lowsec. So we will have AgentLocation (string) and MissionLocation (string). I also want to know if Lowsec exists between the two. Thus Lowsec (bool).
			; After deliberation we should also keep track of Dropoff Location and Pickup Location for couriers because sometimes you go the opposite way and bring stuff TO your agent. Ultrashit.
			; After even more deliberation, I need the IDs for Pickup and Dropoff locations because its hard to get an ID from a name. Fuck!
			; I also want to know how many jumps exist between the two locations. JumpDistance (int).
			; Next up will be some item specific information. ExpectedItems (string) for what the item is called. ItemUnits (integer) for how many items are expected. ItemVolume (int64) for its total volume. VolumePer (int64) for the Volume of each unit.
			; Next up will be target specific information. DestroyTarget (string) for what must die. LootTarget (string) for what must be looted.
			; Lastly, Damage type info. Damage2Deal (string). Think that covers anything, you may note that the last 3 things are all from the mission data xml. I may or may not
			; get absurdly ambitious with this.
			; Addendum, tacking on LP reward for the mission because I need to be able to recover it later if we crash or whatever. Ugh.
			if !${CharacterSQLDB.TableExists["MissionJournal"]}
			{
				echo DEBUG - Creating Mission Journal Table
				CharacterSQLDB:ExecDML["create table MissionJournal (AgentID INTEGER PRIMARY KEY, MissionName TEXT, MissionType TEXT, MissionStatus INTEGER, AgentLocation TEXT, MissionLocation TEXT, DropoffLocation TEXT, DropoffLocationID INTEGER, PickupLocation TEXT, PickupLocationID Integer, Lowsec BOOLEAN, JumpDistance INTEGER, ExpectedItems TEXT, ItemUnits INTEGER, ItemVolume INTEGER, MissionLPReward INTEGER, VolumePer INTEGER, DestroyTarget TEXT, LootTarget TEXT, Damage2Deal TEXT);"]
			}
			
			; This table is for keeping track of what we've done during our combat missions.
			; We will use a generated integer as our primary key. Run number or some such thing. StartingTimestamp (int64)
			; MissionName (string). MissionType (string). Re-using those.
			; Next up what room are we in. RoomNumber (int). 
			; Next up combat mission specific things. Have we killed our target? KilledTarget (bool). Have we killed everything? Vanquisher (bool).
			; Have we looted our target? ContainerLooted (bool).
			; Do we have the item we came here for? HaveItems (bool).
			; Have we technically completed the mission? TechnicalCompletion (bool). Have we truely completed the mission, that is to say have we gone to every single room and killed every single thing? TrueCompletion (bool).
			; Timestamp at the end, taken right as we turn in the mission. FinalTimestamp (int64)
			; Lastly, is this row historical? That is to say, is it for a mission that has expired, been turned in, been cancelled? Historical (bool).
			if !${CharacterSQLDB.TableExists["MissionLogCombat"]}
			{
				echo DEBUG - Creating Mission Log Combat
				CharacterSQLDB:ExecDML["create table MissionLogCombat (RunNumber INTEGER PRIMARY KEY, StartingTimestamp INTEGER, MissionName TEXT, MissionType TEXT, RoomNumber INTEGER, KilledTarget BOOLEAN, Vanquisher BOOLEAN, ContainerLooted BOOLEAN, HaveItems BOOLEAN, TechnicalCompletion BOOLEAN, TrueCompletion BOOLEAN, FinalTimestamp INTEGER, Historical BOOLEAN);"]
			}
			
			; This table is for keeping track of what we've done during our Courier/Trade missions.
			; RunNumber (int). MissionName (string). StartingTimestamp (int64). MissionType (string). Re-using.
			; To keep track of how many trips we have made. TripNumber (int). To keep track of how many trips we are expected to make. ExpectedTrips (int).
			; To keep track of the dropoff location. DropoffLocation (string). And Pickup Location. PickupLocation (string).
			; To keep track of total units to move. TotalUnits (int). Same but for volume. TotalVolume (int64).
			; To keep track of the units we have moved already. UnitsMoved (int). Same but for volume. VolumeMoved (int64).
			; Re-using FinalTimestamp (int).
			; Lastly, re-use historical.
			
			if !${CharacterSQLDB.TableExists["MissionLogCourier"]}
			{
				echo DEBUG - Creating Mission Log Courier
				CharacterSQLDB:ExecDML["create table MissionLogCourier (RunNumber INTEGER PRIMARY KEY, StartingTimestamp INTEGER, MissionName TEXT, MissionType TEXT, TripNumber INTEGER, ExpectedTrips INTEGER, DropoffLocation TEXT, PickupLocation TEXT, TotalUnits INTEGER, TotalVolume INTEGER, UnitsMoved INTEGER, VolumeMoved INTEGER, FinalTimestamp INTEGER, Historical BOOLEAN);"]
			}			

			; This table is so we can databasify a few things about the NPCs in a given combat mission room. I need this, ultimately, to get the bounties from them.
			; Primary key will be EntityID (int64).
			; Then we record the RunNumber (int). RoomNumber (int).
			; Then the NPCName (string), NPCGroup (string), NPCBounty (int64). Fairly simple stuff tbh.
			if !${CharacterSQLDB.TableExists["RoomNPCInfo"]}
			{
				echo DEBUG - Creating Per Room NPC Info Table
				CharacterSQLDB:ExecDML["create table RoomNPCInfo (EntityID INTEGER PRIMARY KEY, RunNumber INTEGER, RoomNumber INTEGER, NPCName TEXT, NPCGroup TEXT, NPCBounty INTEGER);"]
			}				
			; This next table exists so that the watchdog can try and quantify whether "progress" is being made. I'm tired of bots just getting stuck in weird states. Sure it is rare, but it is also wasteful.
			; Integer Primary Key shall be Character ID. Then RunNumber (int). Then we shall have CharName (string). Then MissionName (string). MissionType (string). RoomNumber (int). TripNumber (int). All re-used from before.
			; We will have a timestamp, this is basically just when the last update from that client was. TimeStamp (int64)
			; We will then have the bot's current target's entity ID. CurrentTarget (int). Then its current autopilot Destination (if its a courier). CurrentDestination (string).
			; Then we will have the units it has completed couriering on this run. UnitsMoved (int). That should be enough info to get a good idea whether progress is occurring or not.
			if !${SharedSQLDB.TableExists["WatchDogMonitoring"]}
			{
				echo DEBUG - Creating Watchdog Monitoring Table
				SharedSQLDB:ExecDML["create table WatchDogMonitoring (CharID INTEGER PRIMARY KEY, RunNumber INTEGER, MissionName TEXT, MissionType TEXT, RoomNumber INTEGER, TripNumber INTEGER, TimeStamp INTEGER, CurrentTarget INTEGER, CurrentDestination TEXT, UnitsMoved INTEGER);"]
			}
			
			; This, hopefully final table, exists so that we can gather meaningful statistics about our mission rewards.
			; Each row is going to represent exactly one complete mission run. We will not be looking at loot values here. It would be very very hard
			; for me to quantify loot values. We will be looking at straight isk mission rewards. LP rewards. Bounty rewards. Also, Mission duration beginning to end, room to room timing, the mission name obviously, what ship we are using.
			; There will be no primary key, this will be kinda like our observer bots, its just going to be a series of events.
			; First up we will have Timestamp (int64) CharName (string) CharID (int) RunNumber (int) RoomNumber (int) TripNumber (int)  MissionName (string) MissionType (string). All obvious.
			; Next we will have what type of event this row represents, Room completion, Trip Completion, Run Completion, Mission Decline. EventType (string). Room/Trip/Run/Decline are the valid strings.
			; Next up we will have a Bounty value, if applicable. Going to just add up the bounties of everything that we kill and Sum it up and throw it here. RoomBounties (int64).
			; Next up, did we see a faction spawn (cruiser, battlecruiser, or battleship) in this room? RoomFactionSpawn (bool).
			; Next up we will have a Duration for the time it took to complete the room. RoomDuration (int64).
			; Next up we will have a mission turnin LP/ISK value to put on a Run completion EventType. RunLP (int) and RunISK (int64) respectively.
			; Next up, Duration for time to complete the entire run. RunDuration (int64). Also, total bounties for the entire run.
			; Last meaningful thing I can think to put here, what ship are we in? ShipType (string).
			if !${SharedSQLDB.TableExists["MissioneerStats"]}
			{
				echo DEBUG - Creating Missioner Stats Table
				SharedSQLDB:ExecDML["create table MissioneerStats (Timestamp INTEGER, CharName TEXT, CharID INTEGER, RunNumber INTEGER, RoomNumber INTEGER, TripNumber INTEGER, MissionName TEXT, MissionType TEXT, EventType TEXT, RoomBounties INTEGER, RoomFactionSpawn BOOLEAN, RoomDuration INTEGER, RunLP INTEGER, RunISK INTEGER, RunDuration INTEGER, RunTotalBounties INTEGER, ShipType TEXT);"]
			}			
			
			; I lied, one more shared table remains. The shared table that the Salvagers will use.
			; First off, our primary key integer will be the BM ID. BMID (int64).
			; Next up, the name of the BM. BMName (string). Then the number of wrecks present. WreckCount (int). What system is it in? BMSystem (string).
			; Next up, approximately when the first wreck is expected to expire (should correspond approximately with the room beginning). ExpectedExpiration (int64)
			; Next up, which salvager claims the bookmark as theirs. ClaimedByCharID (int64). Next, How long did it take to salvage the site beginning to end? SalvageTime (int64)
			; Last up, is this row Historical, that is to say, it represents something completed? Historical (bool)
			if !${SharedSQLDB.TableExists["SalvageBMTable"]}
			{
				echo DEBUG - Creating Salvage Bookmark Table
				SharedSQLDB:ExecDML["create table SalvageBMTable (BMID INTEGER PRIMARY KEY, BMName TEXT, WreckCount INTEGER, BMSystem TEXT, ExpectedExpiration INTEGER, ClaimedByCharID INTEGER, SalvageTime INTEGER, Historical BOOLEAN);"]
			}
			; Well, that was time consuming and exhausting.
			; But wait, there's more, mostly for me the author though. I have off-machine salvagers operating and I would like them to be able to utilize this wonderful
			; technology so we need a NETWORK SHARED SQLDB. It will contain one table that looks identical to the one above.
			if !${ExtremelySharedSQLDB.TableExists["SalvageBMTable"]} && (${Config.ExtremelySharedDBPath.NotNULLOrEmpty} && ${Config.ExtremelySharedDBPrefix.NotNULLOrEmpty})
			{
				echo DEBUG - Creating Extremely Shared Salvage Bookmark Table
				ExtremelySharedSQLDB:ExecDML["create table SalvageBMTable (BMID INTEGER PRIMARY KEY, BMName TEXT, WreckCount INTEGER, BMSystem TEXT, ExpectedExpiration INTEGER, ClaimedByCharID INTEGER, SalvageTime INTEGER, Historical BOOLEAN);"]
			}			
		}
		else
		{
			This:LogCritical["Something has gone wrong here."]
			return FALSE
		}
		; DBs are loaded, lets roll.
		; Is it time to halt? Or are we close to downtime? Only goes off when we are in a station.
		if ${Me.InStation} && (${Config.Halt} || ${halt} || ${Utility.DowntimeClose})
		{
			This:QueueState["HaltBot"]
		}
		; First off we will check against our own character DB to figure out exactly where we left off last time.
		; Did we disconnect mid mission? Did we stop in station with no mission at all? Why use context clues from our immediate
		; situation when we can use an overly complicated DB lookup. Free will is an illusion.
		; Todo - The shit I said above this. We would basically be looking at the character specific mission log tables, find a row that ISN'T historic, and pick that up as what we
		; are currently working on. We would use the information recorded in that row to return to where we left off more or less.
		if !${CheckedMissionLogs}
		{
			GetMissionLogCombat:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionLogCombat WHERE Historical=0;"]}]
			echo DEBUG - First Query
			if ${GetMissionLogCombat.NumRows} > 0
			{
				This:LogInfo["Found running combat mission."]
				echo DEBUG - GOING TO MID RUN RECOVERY - NONCOMBAT
				This:MidRunRecovery["Combat"]				
				if !${Me.InStation}
				{
					if !${EVEWindow[AgentConversation_${CurrentAgentID}](exists)}
					{
						;missionIterator.Value:GetDetails
						EVE.Agent[${CurrentAgentIndex}]:StartConversation
						return FALSE
					}
					if ${MissionParser.IsComplete}
					{
						CurrentRunTechnicalComplete:Set[TRUE]
						This:QueueState["CombatMissionFinish",3000]
					}
					else
					{
						This:QueueState["Go2Mission", 3000]		
					}
				}
				else
				{
					if !${EVEWindow[AgentConversation_${CurrentAgentID}](exists)}
					{
						;missionIterator.Value:GetDetails
						EVE.Agent[${CurrentAgentIndex}]:StartConversation
						return FALSE
					}
					if ${EVEWindow[AgentConversation_${AgentDeclineQueue.Peek}].Button["View Mission"](exists)}
					{
						EVEWindow[AgentConversation_${AgentDeclineQueue.Peek}].Button["View Mission"]:Press
						return FALSE
					}
					if ${MissionParser.IsComplete}
					{
						CurrentRunTechnicalComplete:Set[TRUE]
						This:QueueState["CombatMissionFinish",3000]
					}
					else
					{
						This:QueueState["MissionPrep", 3000]
					}
				}
				EVEWindow[ByCaption, Agent Conversation - ${EVE.Agent[${CurrentAgentIndex}].Name}]:Close
				GetMissionLogCombat:Finalize
				return TRUE
			}
			GetMissionLogCourier:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionLogCourier WHERE Historical=0;"]}]
			echo DEBUG - Second Query
			if ${GetMissionLogCourier.NumRows} > 0
			{
				This:LogInfo["Found running courier mission."]
				GetMissionLogCourier:Finalize
				echo DEBUG - GOING TO MID RUN RECOVERY - NONCOMBAT
				This:MidRunRecovery["Noncombat"]
				This:QueueState["CourierMission", 3000]
				This:InsertState["CourierMissionCheckStation", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				This:InsertState["CourierMissionCheckShip", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				This:InsertState["GetHaulerDetails",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]

				return TRUE
			}
			; Found nothing currently being "run". On to databasification.
			CheckedMissionLogs:Set[TRUE]
			This:LogInfo["No running missions found."]
		}
		
		; Assuming the above doesn't immediately take us into a mission running state of some kind
		; then next we will databasify our Mission Journal.
		;if !${DatabasificationComplete}
		;{
		;	This:LogInfo["Begin Databasification"]
		;	This:QueueState["Databasification", 5000]
		;	return TRUE
		;}
		; Now that our Journal is Databasificated we can look through it for acceptable missions to run.
		;if ${DatabasificationComplete}
		;{
			This:LogInfo["Begin Mission Choice"]
			This:QueueState["CurateMissions", 3000]
			This:InsertState["GetHaulerDetails",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE		
		;}
		
	}
	; In this state we will Curate our missions. Lowsec missions will not be removed, but all other missions we do not want will
	; be removed from our mission journal. Due to how finnicky agent interactions can be, we will queue up AgentIDs and decline missions
	; in another state with a slow pulse rate.
	member:bool CurateMissions()
	{
		GetDBJournalInfo:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal;"]}]
		echo DEBUG - THIRD QUERY
		if ${GetDBJournalInfo.NumRows} > 0
		{
			do
			{
				if ${GetDBJournalInfo.GetFieldValue["Lowsec",bool]} && ${Config.DeclineLowSec}
				{
					; We won't actually decline the ones in lowsec if we don't want to do lowsec missions.
					; Because any lowsec storyline agent that already has an offer can't have another one. Declining it would just waste the next storyline mission.
					; Addendum. We will want to reject lowsec offers from our Datafile Configured Agent.
					if ${GetDBJournalInfo.GetFieldValue["AgentID",int64]} == ${EVE.Agent[${AgentList.Get[1]}].ID}
					{
						This:LogInfo["Declining Lowsec Offer from Primary Agent"]
						AgentDeclineQueue:Queue[${GetDBJournalInfo.GetFieldValue["AgentID",int64]}]
						GetDBJournalInfo:NextRow
						continue						
					}
					else
					{
						This:LogInfo["Ignoring Lowsec Mission Offer"]
						GetDBJournalInfo:NextRow
						continue
					}
				}
				if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Storyline"]} && !${Config.DoStoryline}
				{
					This:LogInfo["Adding to Decline List - Storyline"]
					AgentDeclineQueue:Queue[${GetDBJournalInfo.GetFieldValue["AgentID",int64]}]
					GetDBJournalInfo:NextRow
					continue
				}
				if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Courier"]} && !${Config.DoCourier}
				{
					This:LogInfo["Adding to Decline List - Courier"]
					AgentDeclineQueue:Queue[${GetDBJournalInfo.GetFieldValue["AgentID",int64]}]
					GetDBJournalInfo:NextRow
					continue
				}
				if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Encounter"]} && !${Config.DoCombat}
				{	
					This:LogInfo["Adding to Decline List - Encounter"]
					AgentDeclineQueue:Queue[${GetDBJournalInfo.GetFieldValue["AgentID",int64]}]
					GetDBJournalInfo:NextRow
					continue
				}
				if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Storyline"]} && ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Encounter"]} && !${Config.DoStorylineCombat}
				{	
					This:LogInfo["Adding to Decline List - Storyline Encounter"]
					AgentDeclineQueue:Queue[${GetDBJournalInfo.GetFieldValue["AgentID",int64]}]
					GetDBJournalInfo:NextRow
					continue
				}
				if ${GetDBJournalInfo.GetFieldValue["ItemVolume",int64]} > 1000 && !${Config.CourierShipType.NotNULLOrEmpty} && !${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Trade"]}
				{	
					This:LogInfo["High Volume and No Hauler Configured - Declining"]
					AgentDeclineQueue:Queue[${GetDBJournalInfo.GetFieldValue["AgentID",int64]}]
					GetDBJournalInfo:NextRow
					continue
				}
				if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Trade"]} && !${Config.TradeShipType.NotNULLOrEmpty}
				{	
					This:LogInfo["Trade Mission and No Trade Ship Configured - Declining"]
					AgentDeclineQueue:Queue[${GetDBJournalInfo.GetFieldValue["AgentID",int64]}]
					GetDBJournalInfo:NextRow
					continue
				}
				if ${BlackListedMission.Contains[${GetDBJournalInfo.GetFieldValue["MissionName",string]}]}
				{	
					This:LogInfo["Mission in our Avoid List - Declining"]
					AgentDeclineQueue:Queue[${GetDBJournalInfo.GetFieldValue["AgentID",int64]}]
					GetDBJournalInfo:NextRow
					continue
				}
				
				GetDBJournalInfo:NextRow
			}
			while !${GetDBJournalInfo.LastRow}
			GetDBJournalInfo:Finalize
		}
		if ${AgentDeclineQueue.Peek}
		{
			This:InsertState["DeclineMissions", 3000]
			return TRUE
		}
		This:InsertState["ChooseMission", 3000]
		return TRUE
	}
	; This state is needed so we can reliably Decline missions that don't meet our criteria.
	; Agent interactions don't enjoy going at mach speed such as found in a do while loop. So we will use this state to process a queue generated by CurateMissions state.
	member:bool DeclineMissions()
	{
		if ${AgentDeclineQueue.Peek}
		{
			if !${EVEWindow[AgentConversation_${AgentDeclineQueue.Peek}](exists)}
			{
				EVE.Agent[id,${AgentDeclineQueue.Peek}]:StartConversation
				return FALSE
			}
			if ${EVEWindow[AgentConversation_${AgentDeclineQueue.Peek}].Button["View Mission"](exists)}
			{
				EVEWindow[AgentConversation_${AgentDeclineQueue.Peek}].Button["View Mission"]:Press
				return FALSE
			}
			if ${EVEWindow[AgentConversation_${AgentDeclineQueue.Peek}].Button["Decline"](exists)}
			{
				EVEWindow[AgentConversation_${AgentDeclineQueue.Peek}].Button["Decline"]:Press
				return FALSE
			}
			echo DEBUG - Decline Deletion
			CharacterSQLDB:ExecDML["Delete FROM MissionJournal WHERE AgentID=${AgentDeclineQueue.Peek};"]
			if ${EVEWindow[AgentConversation_${AgentDeclineQueue.Peek}](exists)}
			{
				EVEWindow[AgentConversation_${AgentDeclineQueue.Peek}]:Close
			}
			This:LogInfo["Declining mission from ${AgentDeclineQueue.Peek}"]
			AgentDeclineQueue:Dequeue
			return FALSE				
		}
		else
		{
			This:QueueState["ChooseMission", 2000]
			return TRUE
		}
	}
	; This state will be where we choose our mission. Curate Missions state will have already done the heavy lifting for us.
	; The reason the two states aren't one is because deleting rows while iterating them is a bad idea.
	member:bool ChooseMission()
	{	
		; Storylines first.
		if ${Config.DeclineLowSec}
		{
			GetDBJournalInfo:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal WHERE MissionType LIKE '%Storyline%' AND Lowsec=0;"]}]
		}
		else
		{
			GetDBJournalInfo:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal WHERE MissionType LIKE '%Storyline%';"]}]
		}
		echo DEBUG - FIFTH QUERY
		if ${GetDBJournalInfo.NumRows} > 0
		{
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Encounter"]}
			{
				This:LogInfo["Encounter - Combat Ship Needed"]
				CurrentAgentShip:Set[${Config.CombatShipType}]

			}
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Courier"]} && ( ${GetDBJournalInfo.GetFieldValue["ItemVolume",int64]} > 10 )
			{	
				This:LogInfo["Large Courier - Hauler Needed"]
				CurrentAgentShip:Set[${Config.CourierShipType}]
			}
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Courier"]} && ( ${GetDBJournalInfo.GetFieldValue["ItemVolume",int64]} <= 10 )
			{
				This:LogInfo["Small Courier - Shuttle Needed"]
				if ${Config.FastCourierShipType.NotNULLOrEmpty}
					CurrentAgentShip:Set[${Config.FastCourierShipType}]
				else
					CurrentAgentShip:Set[${Config.CourierShipType}]
			}
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Trade"]}
			{
				This:LogInfo["Trade Mission - Ore Hauler Needed"]
				CurrentAgentShip:Set[${Config.TradeShipType}]
			}
			; Pulling our current (agent) variables back out.
			if ${GetDBJournalInfo.GetFieldValue["ExpectedItems",string].NotNULLOrEmpty}
				CurrentAgentItem:Set[${GetDBJournalInfo.GetFieldValue["ExpectedItems",string]}]
			if ${GetDBJournalInfo.GetFieldValue["ItemUnits",int]} >= 1
				CurrentAgentItemUnits:Set[${GetDBJournalInfo.GetFieldValue["ItemUnits",int]}]
			if ${GetDBJournalInfo.GetFieldValue["VolumePer",int64]} > 0
				CurrentAgentVolumePer:Set[${GetDBJournalInfo.GetFieldValue["VolumePer",int64]}]
			if ${GetDBJournalInfo.GetFieldValue["ItemVolume",int64]} > 0
				CurrentAgentVolumeTotal:Set[${GetDBJournalInfo.GetFieldValue["ItemVolume",int64]}]				
			if ${GetDBJournalInfo.GetFieldValue["PickupLocation",string].NotNULLOrEmpty}
				CurrentAgentPickup:Set[${GetDBJournalInfo.GetFieldValue["PickupLocation",string]}]
			if ${GetDBJournalInfo.GetFieldValue["PickupLocationID",int64]} > 0
				CurrentAgentPickupID:Set[${GetDBJournalInfo.GetFieldValue["PickupLocationID",int64]}]					
			if ${GetDBJournalInfo.GetFieldValue["DropoffLocation",string].NotNULLOrEmpty}
				CurrentAgentDropoff:Set[${GetDBJournalInfo.GetFieldValue["DropoffLocation",string]}]
			if ${GetDBJournalInfo.GetFieldValue["DropoffLocationID",int64]} > 0
				CurrentAgentDropoffID:Set[${GetDBJournalInfo.GetFieldValue["DropoffLocationID",int64]}]						
			if ${GetDBJournalInfo.GetFieldValue["Damage2Deal",string].NotNULLOrEmpty}
				CurrentAgentDamage:Set[${GetDBJournalInfo.GetFieldValue["Damage2Deal",string]}]
			if ${GetDBJournalInfo.GetFieldValue["DestroyTarget",string].NotNULLOrEmpty}
				CurrentAgentDestroy:Set[${GetDBJournalInfo.GetFieldValue["DestroyTarget",string]}]
			if ${GetDBJournalInfo.GetFieldValue["LootTarget",string].NotNULLOrEmpty}
				CurrentAgentLoot:Set[${GetDBJournalInfo.GetFieldValue["LootTarget",string]}]	
			CurrentAgentID:Set[${GetDBJournalInfo.GetFieldValue["AgentID",int64]}]
			CurrentAgentLocation:Set[${GetDBJournalInfo.GetFieldValue["AgentLocation",string]}]
			CurrentAgentIndex:Set[${EVE.Agent[id,${CurrentAgentID}].Index}]
			GetDBJournalInfo:Finalize
			This:QueueState["MissionPrePrep", 2000]
			if ${Config.MunitionStorage.Equal[Corporation Hangar]}
			{
				This:InsertState["RefreshCorpHangarState",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				This:InsertState["PrepHangars"]			
			}
			if ${Config.MunitionStorage.Equal[Personal Hangar]}
				This:InsertState["RefreshStationItemsState",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
		}
		GetDBJournalInfo:Finalize
		; Everything else.
		if ${Config.DeclineLowSec}
		{
			GetDBJournalInfo:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal WHERE Lowsec=0 AND MissionType NOT LIKE '%Storyline%';"]}]
		}
		else
		{
			GetDBJournalInfo:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal WHERE MissionType NOT LIKE '%Storyline%';"]}]
		}
		echo DEBUG - SIXTH QUERY
		if ${GetDBJournalInfo.NumRows} > 0
		{
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Encounter"]}
			{
				This:LogInfo["Encounter - Combat Ship Needed"]
				CurrentAgentShip:Set[${Config.CombatShipType}]
			}
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Courier"]} && ( ${GetDBJournalInfo.GetFieldValue["ItemVolume",int64]} > 10 )
			{	
				This:LogInfo["Large Courier - Hauler Needed"]
				CurrentAgentShip:Set[${Config.CourierShipType}]
			}
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Courier"]} && ( ${GetDBJournalInfo.GetFieldValue["ItemVolume",int64]} <= 10 )
			{
				This:LogInfo["Small Courier - Shuttle Needed"]
				if ${Config.FastCourierShipType.NotNULLOrEmpty}
					CurrentAgentShip:Set[${Config.FastCourierShipType}]
				else
					CurrentAgentShip:Set[${Config.CourierShipType}]
			}
			; Pulling our current (agent) variables back out.
			if ${GetDBJournalInfo.GetFieldValue["MissionLPReward",int]} > 0
				CurrentAgentLPReward:Set[${GetDBJournalInfo.GetFieldValue["MissionLPReward",int]}]
			if ${GetDBJournalInfo.GetFieldValue["ExpectedItems",string].NotNULLOrEmpty}
				CurrentAgentItem:Set[${GetDBJournalInfo.GetFieldValue["ExpectedItems",string]}]
			if ${GetDBJournalInfo.GetFieldValue["ItemUnits",int]} >= 1
				CurrentAgentItemUnits:Set[${GetDBJournalInfo.GetFieldValue["ItemUnits",int]}]
			if ${GetDBJournalInfo.GetFieldValue["VolumePer",int64]} > 0
				CurrentAgentVolumePer:Set[${GetDBJournalInfo.GetFieldValue["VolumePer",int64]}]
			if ${GetDBJournalInfo.GetFieldValue["ItemVolume",int64]} > 0
				CurrentAgentVolumeTotal:Set[${GetDBJournalInfo.GetFieldValue["ItemVolume",int64]}]		
			if ${GetDBJournalInfo.GetFieldValue["PickupLocation",string].NotNULLOrEmpty}
				CurrentAgentPickup:Set[${GetDBJournalInfo.GetFieldValue["PickupLocation",string]}]
			if ${GetDBJournalInfo.GetFieldValue["PickupLocationID",int64]} > 0
				CurrentAgentPickupID:Set[${GetDBJournalInfo.GetFieldValue["PickupLocationID",int64]}]				
			if ${GetDBJournalInfo.GetFieldValue["DropoffLocation",string].NotNULLOrEmpty}
				CurrentAgentDropoff:Set[${GetDBJournalInfo.GetFieldValue["DropoffLocation",string]}]
			if ${GetDBJournalInfo.GetFieldValue["DropoffLocationID",int64]} > 0
				CurrentAgentDropoffID:Set[${GetDBJournalInfo.GetFieldValue["DropoffLocationID",int64]}]				
			if ${GetDBJournalInfo.GetFieldValue["Damage2Deal",string].NotNULLOrEmpty}
				CurrentAgentDamage:Set[${GetDBJournalInfo.GetFieldValue["Damage2Deal",string]}]
			if ${GetDBJournalInfo.GetFieldValue["DestroyTarget",string].NotNULLOrEmpty}
				CurrentAgentDestroy:Set[${GetDBJournalInfo.GetFieldValue["DestroyTarget",string]}]
			if ${GetDBJournalInfo.GetFieldValue["LootTarget",string].NotNULLOrEmpty}
				CurrentAgentLoot:Set[${GetDBJournalInfo.GetFieldValue["LootTarget",string]}]		
			CurrentAgentID:Set[${GetDBJournalInfo.GetFieldValue["AgentID",int64]}]
			CurrentAgentLocation:Set[${GetDBJournalInfo.GetFieldValue["AgentLocation",string]}]
			CurrentAgentIndex:Set[${EVE.Agent[id,${CurrentAgentID}].Index}]	
			echo DEBUG - ${CurrentAgentVolumeTotal} CAVT
			GetDBJournalInfo:Finalize
			This:QueueState["MissionPrePrep", 2000]
			if ${Config.MunitionStorage.Equal[Corporation Hangar]}
			{
				This:InsertState["RefreshCorpHangarState",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				This:InsertState["PrepHangars"]				
			}
			if ${Config.MunitionStorage.Equal[Personal Hangar]}
				This:InsertState["RefreshStationItemsState",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
		}
		else
		{
			This:LogInfo["No Valid Offered Missions - Default to Datafile Agent"]
			CurrentAgentID:Set[${EVE.Agent[${AgentList.Get[1]}].ID}]
			CurrentAgentLocation:Set[${EVE.Agent[${AgentList.Get[1]}].Station}]
			CurrentAgentIndex:Set[${EVE.Agent[${AgentList.Get[1]}].Index}]
			This:QueueState["MissionPrePrep", 2000]
			if ${Config.MunitionStorage.Equal[Corporation Hangar]}
			{
				This:InsertState["RefreshCorpHangarState",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				This:InsertState["PrepHangars"]				
			}
			if ${Config.MunitionStorage.Equal[Personal Hangar]}
			This:InsertState["RefreshStationItemsState",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
			This:InsertState["GetHaulerDetails",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
		}
	}
	; Addendum - For trade missions, you need to either have the items already there, or bring the items with you. Market interactions are toast so we won't be doing that.
	; Ugh, more work. So we also need to ensure we are in the correct ship, with the correct needed trade item, before we travel to the agent. Pisssssss. This also means we need
	; to code in another case for returning to our Primary Agent Station to swap back to other ships for other missions before we go to those missions.
	; This state thus exists to ensure we have the right ship for the job, also if its a trade mission, the right ore.
	;;;; EXTREMELY IMPORTANT NOTE - WE ARE ASSUMING YOU WILL KEEP YOUR ALTERNATE SHIPS IN YOUR PRIMARY AGENT STATION
	;;;; THAT IS TO SAY, THE STATION WHERE YOUR MAIN MISSION AGENT IS LOCATED. PLEASE DO SO
	; Addendum - Going to need to break this state up even more.
	member:bool MissionPrePrep()
	{
		; Tired of having 15,000 traveling states queued up after a long trip.
		if ${Move.Traveling}
		{
			return FALSE
		}
		; Need a variable to decrement to figure out if we have enough of our trade item
		variable int InStock
		; Need another for loading that trade item
		variable int TradeItemNeeded
		
		; Inventory variables
		variable index:item items
		variable iterator itemIterator
		
		
		GetDBJournalInfo:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal WHERE AgentID=${CurrentAgentID};"]}]
		echo DEBUG - SEVENTH QUERY
		if ${GetDBJournalInfo.NumRows} < 1
		{
			This:LogInfo["No Valid Offered Missions - Go To Agent"]
			; This case is that we are already going back to our Primary Agent Station, and we have no valid missions in our journal. Or we could already be there, but thats outside the scope of this state.
			; Basically we are just bypassing this state.
			This:InsertState["Go2Agent", 2000]
			return TRUE			
		}
		; We need to figure out if we are already flying what we need, and carrying what we need, if we need anything.
		; We determined WHAT we need in the previous state.
		if ${Me.StationID} != ${EVE.Agent[${PrimaryAgentIndex}].StationID}
		{
			; We aren't at our Primary Agent Station. Move there.
			Move:Agent[${PrimaryAgentIndex}]
			This:InsertState["Traveling"]
			return FALSE
		}
		; Need to add yet another state, need to have a trigger to jump to that state.
		if ${Me.StationID} == ${EVE.Agent[${PrimaryAgentIndex}].StationID}
		{
			This:LogInfo["At Primary Agent Station - Get Ship And/Or Ore"]
			This:InsertState["GetShip",6000]
			return TRUE
		}
		return FALSE
	}
	; We needed to break PrePrep up because there are two parts to this. Going to our PRIMARY AGENT STATION (not current agent station). Switching ships, grabbing ore if needed, then heading to our (presumably) storyline mission agent
	; (who would actually be our CurrentAgent).
	; Addendum, going to need to break this up into 2 states. Inventory is hell. First state we verify/change ship. Second state, if the mission is a trade mission, we will get ore. If not we skip it.
	member:bool GetShip(bool ShipHangar)
	{
		if ${Me.StationID} == ${EVE.Agent[${PrimaryAgentIndex}].StationID}
		{
			; We are already at our Primary Agent Station. Here we will A) Ensure that our ship is the ship called for in the last state and B) (optional) ensure that we have the Ore needed for a trade mission, if thats what is next.
			echo DEBUG - ${CurrentAgentShip}
			if !${MyShip.ToItem.Type.Find[${CurrentAgentShip}]}
			{
				; Ship isn't right. Let's see if we can switch our ship with isxeve still.
				if !${ShipHangar}
				{
					EVEWindow[Inventory].ChildWindow[StationShips]:MakeActive
					This:InsertState["GetShip",5000,"TRUE"]
					return TRUE
				}
				This:ActivateShip[${CurrentAgentShip}]
				This:InsertState["GetShip",6000,"FALSE"]
				return TRUE
				; Presumably, we are in the right ship now.
			}
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Trade"]}
			{
				GetDBJournalInfo:Finalize
				This:InsertState["GetOre",4000]
				This:InsertState["RefreshCorpHangarState",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				This:InsertState["PrepHangars"]
				This:InsertState["GetHaulerDetails",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				return TRUE
			}
			else
			{
				GetDBJournalInfo:Finalize
				This:QueueState["Go2Agent", 2000]
				return TRUE		
			}
		}
	}
	; This state is the second half of the original GetShipAndOrOre. If Trade mission, we get ore. If not, we skipped this. If no ore available, we stop.
	; The argument is how many times we've cycled through that initial CheckInventoryValid member. If we go through 18 seconds worth of that something is fucked or there are genuinely no items in the inventory.
	member:bool GetOre(int Cycles)
	{
		; Need a variable to decrement to figure out if we have enough of our trade item
		variable int InStock
		; Need another for loading that trade item
		variable int TradeItemNeeded
		
		; Inventory variables
		variable index:item items
		variable iterator itemIterator
		if ${This.CheckInventoryValid} < 1 && ${Cycles} <= 5
		{
			This:InsertState["GetOre",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int},"${Math.Calc[${Cycles} + 1]}"]
			return TRUE	
		}
		InStock:Inc[${CurrentAgentItemUnits}]
		TradeItemNeeded:Set[${CurrentAgentItemUnits}]
		This:LogInfo["Checking for ${CurrentAgentItem} for Trade Mission"]
		InStock:Dec[${This.TradeItemInStock[${CurrentAgentItem}]}]
		; This will reduce the number we need by the number we have, supposedly. Jury is still out on if my tampering will break it.
		if ${InStock} > 0
		{
			GetDBJournalInfo:Finalize
			This:LogCritical["Insufficient Quantity of ${CurrentAgentItem}, Stopping."]
			This:Stop
			return TRUE					
		}
		else
		{
			; We presumably have enough of the item, let us try and load it into our ship. But first, need to know some stuff about this ship.
			This:LogCritical["DEBUG - ${HaulerLargestBayCapacity} HLBC ${CurrentAgentVolumeTotal} CAVT"]
			if ${HaulerLargestBayCapacity} >= ${CurrentAgentVolumeTotal}
			{
				if ${Config.MunitionStorage.Equal[Corporation Hangar]}
				{
					if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
					{
						EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
						This:InsertState["GetOre",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
						return TRUE
					}
					EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:GetItems[items]
					items:GetIterator[itemIterator]
					do
					{
						if ${itemIterator.Value.Name.Find[${CurrentAgentItem}]}
						{
							if ${itemIterator.Value.Quantity} >= ${TradeItemNeeded}
							{
								itemIterator.Value:MoveTo[${MyShip.ID}, ${HaulerLargestBayLocationFlag}, ${TradeItemNeeded}]
								break
							}
							else
							{
								itemIterator.Value:MoveTo[${MyShip.ID}, ${HaulerLargestBayLocationFlag}, ${itemIterator.Value.Quantity}]
								TradeItemNeeded:Dec[${itemIterator.Value.Quantity}]
								continue
							}
						}
					}
					while ${itemIterator:Next(exists)}
				}
				if ${Config.MunitionStorage.Equal[Personal Hangar]}
				{
					if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
					{
						EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
						This:InsertState["GetOre",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
						return TRUE
					}
					EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[items]
					items:GetIterator[itemIterator]
					do
					{
						if ${itemIterator.Value.Name.Find[${CurrentAgentItem}]}
						{
							if ${itemIterator.Value.Quantity} >= ${TradeItemNeeded}
							{
								itemIterator.Value:MoveTo[${MyShip.ID}, ${HaulerLargestBayLocationFlag}, ${TradeItemNeeded}]
								break
							}
							else
							{
								itemIterator.Value:MoveTo[${MyShip.ID}, ${HaulerLargestBayLocationFlag}, ${itemIterator.Value.Quantity}]
								TradeItemNeeded:Dec[${itemIterator.Value.Quantity}]
								continue
							}
						}
					}
					while ${itemIterator:Next(exists)}
				}
			}
			else
			{
				This:LogCritical["Picked a ship that can't haul ${CurrentAgentVolumeTotal} ore. I suggest a Miasmos."]
				This:Stop
				return TRUE
			}
			This:LogInfo["Ore Loaded, Headed out"]
			This:QueueState["Go2Agent",${Math.Calc[(4000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
		}
	}
	

	; This state exists to get us to wherever our agent is. We will use 3 variables about our Current Agent to make this easier, probably. Actually... We only need their location.
	; The other 2 are for other things later. Idk, I'm tired.
	member:bool Go2Agent()
	{
		if ${Move.Traveling}
		{
			return FALSE
		}
		if ${Me.StationID} != ${EVE.Agent[${CurrentAgentIndex}].StationID}
		{
			; This calls a state in Move, we need to call Traveling or we will start doing shit while en route. That's no good.
			Move:Agent[${CurrentAgentIndex}]
			This:InsertState["Traveling"]
			return FALSE
		}
		else
		{
			; Already there I guess. May as well open that Agent Conversation window and commence Databasification.
			This:LogInfo["At Agent Station"]
			This:QueueState["InitialAgentPreInteraction",2000]
			This:InsertState["PrepHangars"]		
			return TRUE
		}
	}
	; This exists to bridge the gap between Go2Agent and InitialAgentInteraction
	member:bool InitialAgentPreInteraction()
	{
		GetDBJournalInfo:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal WHERE AgentID=${CurrentAgentID};"]}]
		DEBUG - EIGHTH QUERY
		if ${GetDBJournalInfo.NumRows} < 1
		{
			if !${EVEWindow[AgentConversation_${CurrentAgentID}](exists)}
			{
				GetDBJournalInfo:Finalize
				EVE.Agent[${CurrentAgentIndex}]:StartConversation
				return FALSE
			}
			if ${EVEWindow[AgentConversation_${CurrentAgentID}].Button["Request Mission"](exists)}
			{
				GetDBJournalInfo:Finalize
				EVEWindow[AgentConversation_${CurrentAgentID}].Button["Request Mission"]:Press
				return FALSE
			}	
			This:LogInfo["Begin Databasification"]		
			This:InsertState["Databasification",2000, "1, TRUE"]
			return TRUE
		}
		else
		{
			GetDBJournalInfo:Finalize
			This:QueueState["InitialAgentInteraction", 5000]
			return TRUE
		}
	}
	; This state will be where we interact with our Agents outside of the little we did to achieve databasification. This will be the initial interaction.
	; This state will also be where, after accepting a mission, we put our initial MissionLog entry in whatever table it belongs.
	; As such, this is going to be a somewhat long state because we need to assemble all the pieces that go into that MissionLog table(s).
	; Addendum, I made the state shorter by calling methods further down.
	member:bool InitialAgentInteraction()
	{
		; Open a conversation window, again.
		if !${EVEWindow[AgentConversation_${CurrentAgentID}](exists)}
		{
			This:LogInfo["Opening Conversation Window."]
			EVE.Agent[${CurrentAgentIndex}]:StartConversation

			return FALSE
		}
		if ${EVEWindow[AgentConversation_${CurrentAgentID}].Button["View Mission"](exists)}
		{
			EVEWindow[AgentConversation_${CurrentAgentID}].Button["View Mission"]:Press
			return FALSE
		}
		if ${EVEWindow[AgentConversation_${CurrentAgentID}].Button["Request Mission"](exists)}
		{
			EVEWindow[AgentConversation_${CurrentAgentID}].Button["Request Mission"]:Press
			return FALSE
		}
		GetDBJournalInfo:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal WHERE AgentID=${CurrentAgentID};"]}]
		echo DEBUG NINTH QUERY
		; Is this mission unconfigured, and also a combat mission? We no do that.
		if !${DamageType.Element[${GetDBJournalInfo.GetFieldValue["MissionName",string]}](exists)} && ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Encounter"]}
		{
			This:LogCritical["We have hit an unconfigured combat mission - Stopping."]
			GetDBJournalInfo:Finalize
			This:Stop
			return TRUE
		}
		; Let us accept the mission and close the window. 
		if ${EVEWindow[AgentConversation_${CurrentAgentID}].Button["Accept"](exists)}
		{
			GetDBJournalInfo:Finalize
			This:LogInfo["Accepting mission from Agent"]
			EVEWindow[AgentConversation_${CurrentAgentID}].Button["Accept"]:Press
			return FALSE
		}
		This:MissionJournalUpdateStatus[${CurrentAgentID},2]
		CurrentAgentMissionName:Set[${GetDBJournalInfo.GetFieldValue["MissionName",string]}]
		CurrentAgentMissionType:Set[${GetDBJournalInfo.GetFieldValue["MissionType",string]}]
		MissionParser.AgentName:Set[${EVE.Agent[${CurrentAgentIndex}].Name}]
		; We have a journal row, as expected. This should have already been curated, so this mission should, without fail, be one we want.
		; Let us establish the mission parameters, so we can put it in the correct mission log table.
		; (RunNumber INTEGER PRIMARY KEY, StartingTimestamp INTEGER, MissionName TEXT, MissionType TEXT, TripNumber INTEGER, ExpectedTrips INTEGER,
		;  DropoffLocation TEXT, PickupLocation TEXT, TotalUnits INTEGER, TotalVolume INTEGER, UnitsMoved INTEGER, VolumeMoved INTEGER, FinalTimestamp INTEGER, Historical BOOLEAN);"]
		if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Courier"]} || ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Trade"]}
		{
			; Gotta do this again, we might have swapped ships going from a trade mission to a courier.
			;This:InsertState["GetHaulerDetails",5000]
			; The following method is basically just to initialize our Current Run stats.
			; First argument on this will be the capacity of our largest bay, second argument will be the total volume of mission
			This:SetCurrentRunDetails[${HaulerLargestBayCapacity},${CurrentAgentVolumeTotal}]
			This:MissionLogCourierUpsert[${CurrentRunNumber},${Time.Timestamp},${CurrentAgentMissionName.ReplaceSubstring[','']},${CurrentAgentMissionType},${CurrentRunTripNumber},${CurrentRunExpectedTrips},${CurrentAgentDropoff},${CurrentAgentPickup},${CurrentAgentItemUnits},${CurrentAgentVolumeTotal},${CurrentRunItemUnitsMoved},${CurrentRunVolumeMoved},${CurrentRunFinalTimestamp},FALSE]
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Trade"]}
			{
				GetDBJournalInfo:Finalize
				EVEWindow[AgentConversation_${CurrentAgentID}]:Close
				CurrentRunTripNumber:Inc[1]
				This:QueueState["TradeMission",5000]
				return TRUE
			}
			else
			{
				GetDBJournalInfo:Finalize
				EVEWindow[AgentConversation_${CurrentAgentID}]:Close
				This:QueueState["CourierMission",5000]
				This:InsertState["CourierMissionCheckStation", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				This:InsertState["RefreshStationItemsState", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				This:InsertState["CourierMissionCheckShip", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				This:InsertState["RefreshLargestBayState", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				This:InsertState["GetHaulerDetails",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]

				return TRUE
			}
		}
		; (RunNumber INTEGER PRIMARY KEY, StartingTimestamp INTEGER, MissionName TEXT, MissionType TEXT, RoomNumber INTEGER, KilledTarget BOOLEAN, Vanquisher BOOLEAN, ContainerLooted BOOLEAN, HaveItems BOOLEAN, TechnicalCompletion BOOLEAN, 
		;   TrueCompletion BOOLEAN, FinalTimestamp INTEGER, Historical BOOLEAN);"]
		if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Encounter"]}
		{
			This:SetCurrentRunDetails[${HaulerLargestBayCapacity},${CurrentAgentVolumeTotal}]
			This:MissionLogCombatUpsert[${CurrentRunNumber},${Time.Timestamp},${CurrentAgentMissionName.ReplaceSubstring[','']},${CurrentAgentMissionType},${CurrentRunRoomNumber},${CurrentRunKilledTarget},${CurrentRunVanquisher},${CurrentRunContainerLooted},${CurrentRunHaveItems},${CurrentRunTechnicalComplete},${CurrentRunTrueComplete},${CurrentRunFinalTimestamp},FALSE]
			GetDBJournalInfo:Finalize
			EVEWindow[AgentConversation_${CurrentAgentID}]:Close
			This:QueueState["MissionPrep",5000]
			return TRUE
		}
	
	}
	; This state will be where we prep our ship for the mission. Load ammo/drones, etc. This will be bypassed for Courier and Trade missions.
	; Courier missions will do their own loading, trade missions have already done their loading. 
	member:bool MissionPrep()
	{
		; Need to do this so we can move the stuff correctly. A combat mission ship should have a cargo bay, probably.
		HaulerLargestBayLocationFlag:Set[${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipCargo"].LocationFlag}]
		; First up, we need to establish exactly what damage type, and hence ammo and drones, we need.
		This:ResolveDamageType[${CurrentAgentDamage.Lower}]
		; Queue up the state that handles station inventory management for this scenario.
		This:QueueState["Go2Mission",4000]
		This:InsertState["ReloadAmmoAndDrones", 4000]
		if ${RequiredItems.Element[${CurrentAgentMissionName}](exists)}
		{
			This:InsertState["CombatMissionLoadShip",3000,"${RequiredItems.Element[${CurrentAgentMissionName}]}"]
		}
		return TRUE
	}
	; This state will be for loading a specific required item as seen in some mission chains. If we need to load an item we will end up here. 
	member:bool CombatMissionLoadShip(string RequiredItem)
	{
		variable index:item itemIndex
		variable iterator	itemIterator
		variable int		wholeUnits
		echo HAULER LARGEST ${HaulerLargestBayType} ${HaulerLargestBayCapacity}
		if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
		{
			EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
			This:InsertState["CombatMissionLoadShip",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
		}
		if ${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
		{
			EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[itemIndex]
			if ${itemIndex.Used} < 1
			{
				; Theoretically, for Load and Unload, we wouldn't have gotten here if there wasn't something to move.
				This:LogInfo["Returned Empty Index - Cycling"]
				return FALSE
			}
			itemIndex:GetIterator[itemIterator]
			if ${itemIterator:First(exists)}
			{
				do
				{
					if ${itemIterator.Value.Name.Find[${RequiredItem}]}
					{
						wholeUnits:Set[${Math.Calc[${HaulerLargestBayCapacity}/${itemIterator.Value.Volume}].Int}]
						if ${itemIterator.Value.Quantity} > ${wholeUnits}
						{
							itemIterator.Value:MoveTo[${Me.ShipID}, ${HaulerLargestBayLocationFlag}, ${wholeUnits}]
							This:LogInfo["${wholeUnits} x ${RequiredItem} @ ${Math.Calc[${wholeUnits}*${itemIterator.Value.Volume}]}m3 moved FROM Station TO ${HaulerLargestBayType}"]
						}
						else
						{
							itemIterator.Value:MoveTo[${Me.ShipID}, ${HaulerLargestBayLocationFlag}, ${itemIterator.Value.Quantity}]
							This:LogInfo["${itemIterator.Value.Quantity} x ${RequiredItem} @ ${Math.Calc[${itemIterator.Value.Quantity}*${itemIterator.Value.Volume}]}m3 moved FROM Station TO ${HaulerLargestBayType}"]						
						}
					}
				}
				while ${itemIterator:Next(exists)}
			}
		}
		return TRUE
	}
	; This state will take us to our Mission Bookmark
	member:bool Go2Mission()
	{
		variable index:agentmission missions
		variable iterator missionIterator	
		EVE:GetAgentMissions[missions]
		missions:GetIterator[missionIterator]
		if ${missionIterator:First(exists)}
		{
			do
			{	
				if ${missionIterator.Value.AgentID} != ${CurrentAgentID}
				{
					continue
				}	
				
				variable index:bookmark missionBookmarks
				variable iterator bookmarkIterator
				missionIterator.Value:GetBookmarks[missionBookmarks]
				missionBookmarks:GetIterator[bookmarkIterator]
				if ${bookmarkIterator:First(exists)}
				{
					do
					{
						if ${bookmarkIterator.Value.LocationType.Equal[dungeon]}
						{
							Move:Undock
							Move:AgentBookmark[${bookmarkIterator.Value.ID}]
							TargetManager.ActiveNPCs.AutoLock:Set[FALSE]
							TargetManager.NPCs.AutoLock:Set[FALSE]
							This:InsertState["Traveling", 5000]
							reload:Set[TRUE]
							This:QueueState["CombatMission", 4000]
							return TRUE
						}
					}
					while ${bookmarkIterator:Next(exists)}
				}	
			}
			while ${missionIterator:Next(exists)}
		}
	}
	; This state will be the start of Primary Logic for Combat Missions.Basically this state here will be our hub for combat missions.
	member:bool CombatMission(int Cycles)
	{
		variable index:bookmark BookmarkIndex
		variable index:bookmark BookmarkIndex2
		variable iterator		BookmarkIterator2
		; Considering we have all of the information contained here as live variables already, no need to touch this thing below.
		;GetMissionLogCombat:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionLogCombat WHERE Historical=FALSE;"]}]
		
		; Ok so we are at this point. Theoretically we should have a mission, we should be in the correct Ship, it should be loaded with the right Ammo and Drones.
		; We should already be at the bookmark for the mission itself, in space.
		; TargetManager and DroneControl will do all the work here. They will manage locks, targets, shooting, bastion, etc.
		; All this needs to do here is navigation. We will want to linger about until all enemies are dead. Then we will Shoot
		; and or Loot things that need to be shot and looted (if any exist). Then we take a gate to the next room and repeat.
		; I am thinking we will want to keep track of gates that we have passed through as well.
		; So, this particular state being our Hub, it will dispatch other states and also check for completion criteria. It will also handle
		; submitting information to the DB for stats/watchdog purposes.
		; I envision 3 more states being required. CombatMissionFight (fighting). CombatMissionTransition (changing rooms, also will handle creating the Salvage Bookmark). CombatMissionObjectives (dealing with our mission objectives if any exist in the mission and the room).
		; We jump between those states, and if we are done we kick out to a final mini-state CombatMissionFinish (which will handle final stats/watchdog updates and bring us back to station).
		; Addendum, 6th state required. CheckForCompletion might not behave as a method.
		; Alright, let us begin.
		; If we are in warp, loop. If Move is Moving us, Loop.
		if ${Me.ToEntity.Mode} == MOVE_WARPING || ${Move.Traveling}
		{
			return FALSE
		}
		; Initial watchdog update for the Combat mode.
		This:UpdateWatchDog
		This:MissionLogCombatUpdate[${CurrentRunNumber},${CurrentRunRoomNumber},${CurrentRunKilledTarget},${CurrentRunVanquisher},${CurrentRunContainerLooted},${CurrentRunHaveItems},${CurrentRunTechnicalComplete},${CurrentRunTrueComplete},${Time.Timestamp},0]
		; Check to see if we've completed the mission, completely
		if (${CurrentRunTechnicalComplete} && ${Config.BlitzMissions}) || ${CurrentRunTrueComplete}
		{
			This:LogInfo["Mission Completed - Transition to CombatMissionFinish"]
			This:InsertState["CombatMissionFinish", 4000]
			return TRUE				
		}
		; Need a check now to tell me if we are actually at the Mission Site. How will that work exactly?
		; How will we know we are at the mission site? Well we can compare coordinates, I suppose. If we are within say,
		; 1 million kilometers of the mission bookmark we are probably there...
		; Actually, lets try what the original Missioneer does. Lets have mid run recovery dump us out earlier.
		
		if ${This.JerksPresent}
		{
			; Jerks Present means bad NPCs are around as determined by TargetManager.		
			This:LogInfo["Enemies Present - Going to Fight State"]
			This:InsertState["CombatMissionFight", 4000]
			return TRUE		
		}
		else
		{
			; Things get a little tricky here. Sometimes it takes a bit for the enemies to Appear. We will cycle through this a few times before we determine a room is Done.
			if ${Cycles} <= 3
			{
				This:LogInfo["Awaiting next spawn wave (if it exists). Cycle Number ${Cycles}."]
				This:InsertState["CombatMission", 4000,"${Math.Calc[${Cycles} + 1]}"]
				return TRUE
			}
			; We waited for a spawn and nothing happened, proceed.
			if ${CurrentAgentDestroy.NotNULLOrEmpty} && !${CurrentRunKilledTarget}
			{
				; If we have a target to Destroy and it hasn't already died. Look for it in this room.
				This:LogInfo["Checking room for ${CurrentAgentDestroy} to Destroy."]
				if ${Entity[Name == "${CurrentAgentDestroy.Escape}"](exists)}
				{
					This:LogInfo["${CurrentAgentDestroy} detected. Destroy."]
					This:InsertState["CombatMissionObjectives",5000,"Destroy, ${Entity[Name == \"${CurrentAgentDestroy.Escape}\"]}"}]
					return TRUE
				}
			}
			elseif !${CurrentAgentDestroy.NotNULLOrEmpty} || ${CurrentRunKilledTarget}
			{
				; Target was already destroyed, skip.
			}
			if ${CurrentAgentLoot.NotNULLOrEmpty} && !${CurrentRunContainerLooted}
			{
				; If we have a target to Loot and it hasn't already been looted. Look for it in this room.
				This:LogInfo["Checking room for ${CurrentAgentLoot} to Loot."]
				if ${Entity[Name == \"${CurrentAgentLoot.Escape}\"](exists)}
				{
					This:LogInfo["${CurrentAgentLoot} detected. Loot."]
					if ${CurrentAgentLoot.Find[Wreck]}
					{
						echo ${CurrentAgentLoot} ${Entity[Name == "${CurrentAgentLoot}"]}
						ObjectiveID:Set[${Entity[Name == "${CurrentAgentLoot}" && IsWreckEmpty = FALSE]}]
						This:InsertState["CombatMissionObjectives",5000,"LootWreck, ${Entity[Name == ${CurrentAgentLoot.Escape} && IsWreckEmpty = FALSE]}"]
					}
					if !${CurrentAgentLoot.Find[Wreck]}
					{
						echo ${CurrentAgentLoot} ${Entity[Name == "${CurrentAgentLoot}"]}
						ObjectiveID:Set[${Entity[Name == "${CurrentAgentLoot}"]}]
						This:InsertState["CombatMissionObjectives",5000,"LootContainer, ${Entity[Name == ${CurrentAgentLoot.Escape}]}"]
					}
					return TRUE
				}				
			}
			elseif !${CurrentAgentLoot.NotNULLOrEmpty} || ${CurrentRunContainerLooted}
			{
				; Target was already looted, skip.
			}
			; Either there was no Target here, or we already handled it. Check for another gate.
			if ${Entity[Type = "Acceleration Gate"](exists)}
			{
				; There is a gate lets pass it off to CombatMissionTransition after we Check for Technical Completion (for stats purposes and maybe a future Blitz mode)
				This:LogInfo["Gate Detected"]
				This:InsertState["CombatMissionTransition",4000]
				This:InsertState["CheckForCompletion",5000]
				return TRUE				
			}
			else
			{
				; Need to do this somewhere. We are making a Salvage BM and also placing an entry in the SalvageBM DB.
				Lootables:RequestUpdate
				if (${Lootables.TargetList.Used} >= ${Config.WreckBMThreshold} && ${Config.SalvagePrefix.NotNULLOrEmpty}) || ((${Lootables.TargetList.Used} > 1 && ${Entity[Name =- "Imperial"](exists)}) || (${Lootables.TargetList.Used} > 1 && ${Entity[Name =- "State"](exists)}) && ${Config.SalvagePrefix.NotNULLOrEmpty} )
				{
					EVE:GetBookmarks[BookmarkIndex]
					BookmarkIndex:RemoveByQuery[${LavishScript.CreateQuery[SolarSystemID == ${Me.SolarSystemID}]}, FALSE]
					BookmarkIndex:RemoveByQuery[${LavishScript.CreateQuery[Distance < 200000]}, FALSE]
					BookmarkIndex:Collapse

					if !${BookmarkIndex.Used}
					{
						Lootables.TargetList.Get[1]:CreateBookmark["${Config.SalvagePrefix} ${Lootables.TargetList.Used} ${EVETime.Time.Left[5]}", "", "${Config.SalvageBMFolderName}", 1]		
						This:InsertState["CombatMission", 5000,"3"]
						EVE:RefreshBookmarks
						return TRUE
					}
				}
				; (BMID INTEGER PRIMARY KEY, BMName TEXT, WreckCount INTEGER, BMSystem TEXT, ExpectedExpiration INTEGER, ClaimedByCharID INTEGER, SalvageTime INTEGER, Historical BOOLEAN);"]
				; There is no gate here, let's check for both completion types (technical and true).
				This:LogInfo["Checking for Completion"]
				This:InsertState["CombatMission", 4000]
				This:InsertState["CheckForCompletion",5000]
				return TRUE	
			}
		}
		return FALSE
	}
	; This state will handle the fighting in a room in a combat mission site.
	member:bool CombatMissionFight()
	{
		variable index:bookmark BookmarkIndex
		variable index:bookmark BookmarkIndex2
		variable iterator		BookmarkIterator2
		
		variable iterator CombatIterator
		TargetManager.ActiveNPCs.TargetList:GetIterator[CombatIterator]
		echo CMF ${TargetManager.ActiveNPCs.TargetList.Used}
		;if ${CombatIterator:First(exists)}
		;{
		;	do
		;	{
				; Need to track if we've killed our Destroy Target while clearing the room.Other than Anire Scarlet who runs through all the rooms.
				; Addendum - This didn't work as anticipated
				;if ${CombatIterator.Value.Name.Find["${CurrentAgentDestroy}"]} && !${CurrentAgentDestroy.Equal["Anire Scarlet"]}
				;{
				;	CombatMissionDestroyTargetSeen:Set[TRUE]
				;}
				; Things that are too far for us
				;if ${CombatIterator.Value.Distance} > ${CurrentOffenseRange} || ${CombatIterator.Value.Distance} > ${MyShip.MaxTargetRange}
				;{
				;	CombatMissionDistantTargets:Set[${CombatIterator.Value.Name},${CombatIterator.Value.ID}]
				;	CombatMissionMidrangeTargets:Erase[${CombatIterator.Value.Name}]
				;	CombatMissionCloseTargets:Erase[${CombatIterator.Value.Name}]
				;}
				; Things at an acceptable range
				;if ( ${CombatIterator.Value.Distance} < ${CurrentOffenseRange} && (${CombatIterator.Value.Distance} > 20000) ) || ((${CombatIterator.Value.Distance} < ${CurrentOffenseRange}) && ${Ship.ModuleList_MJD.Count} < 1 )
				;{
				;	CombatMissionMidrangeTargets:Set[${CombatIterator.Value.Name},${CombatIterator.Value.ID}]
				;	CombatMissionDistantTargets:Erase[${CombatIterator.Value.Name}]
				;	CombatMissionCloseTargets:Erase[${CombatIterator.Value.Name}]
				;}
				; Things that are too close (if we are in a turret based ship AND have a MJD). This information might be used for MJD usage, if I code it.
				;if (${CombatIterator.Value.Distance} < 20000) && ${Ship.ModuleList_Turret.Count} && ${Ship.ModuleList_MJD.Count}
				;{
				;	CombatMissionCloseTargets:Set[${CombatIterator.Value.Name},${CombatIterator.Value.ID}]
				;	CombatMissionDistantTargets:Erase[${CombatIterator.Value.Name}]
				;	CombatMissionMidrangeTargets:Erase[${CombatIterator.Value.Name}]
				;}				
		;	}
		;	while ${CombatIterator:Next(exists)}
		;}
		; Ostensibly, this bot is intended to be used by a Marauder. However, the Blaster Kronos and the AC Vargur can require some
		; maneuvering. TargetManager has had its movement disabled, and it can also put us in Bastion Mode, so this might be kinda difficult.
		; I might also want to do something tricky with MJDs at some point.	
		if ${This.JerksPresent}
		{
			; Databasify NPCs on each loop. They will be added to the SQL DB so we can know things about the mission.
			;This:DatabasifyNPCs
			if ${LavishScript.RunningTime} > ${LastNPCDatabasification}
			{
				This:InsertState["CombatMissionFight",3000]
				This:InsertState["DatabasifyNPCs",1500]
				return TRUE
			}
			;This:MissionLogCombatUpdate[${CurrentRunNumber},${CurrentRunRoomNumber},${CurrentRunKilledTarget},${CurrentRunVanquisher},${CurrentRunContainerLooted},${CurrentRunHaveItems},${CurrentRunTechnicalComplete},${CurrentRunTrueComplete},${Time.Timestamp},0]
			This:UpdateWatchDog
			; Bad guys still here. Fighting loop.
			if ${MyShip.ToEntity.Group.Find[Marauder]}
			{
				;;; This will be implemented in the future.
				; Marauders play by much different rules. We don't move, we bastion and obliterate. Unless you are a Blaster Kronos.
				;if ${CombatMissionMidrangeTargets.Used} > ${CombatMissionDistantTargets}
				;{
				;	; More enemies are in range than are not.
				;	AllowSiegeModule:Set[TRUE]
				;	
				;}
				;if (${CombatMissionMidrangeTargets.Used} < ${CombatMissionDistantTargets})
				;{
				;	; More enemies are out of range than in range.
				;	AllowSiegeModule:Set[FALSE]
				;	
				;}	
				;if ${CombatMissionCloseTargets.Used} > ${CombatMissionMidrangeTargets.Used}
				;{
				;	; MJD usage will go here. If too many enemies are close we will MJD away, again, only if we are a Turret based ship and if we have an MJD.
				;	AllowSiegeModule:Set[FALSE]
				;}
				if ${Entity[${CurrentOffenseTarget}](exists)}
				{
					TargetManager:RegisterCurrentPrimaryWeaponRange
					if ${Entity[${CurrentOffenseTarget}].Distance} < ${CurrentOffenseRange} 
					{
						; In range, Bastion.
						echo DEBUG ALLOW SIEGE
						AllowSiegeModule:Set[TRUE]
					}
					if (${Entity[${CurrentOffenseTarget}].Distance} > ${CurrentOffenseRange}) || (${Entity[${CurrentOffenseTarget}].Distance} > ${MyShip.MaxTargetRange})
					{
						; Out of target or offense range. Orbit Target
						echo DEBUG DISALLOW SIEGE
						AllowSiegeModule:Set[FALSE]
						Move:Orbit[${CurrentOffenseTarget},5000]
					}
				}
			}
			else
			{
				; Why aren't you using a Marauder, god damn you.
				if (${Entity[${CurrentOffenseTarget}].Distance} > ${CurrentOffenseRange}) || (${Entity[${CurrentOffenseTarget}].Distance} > ${MyShip.MaxTargetRange})
				{
					; Out of target or offense range. Orbit Target
					Move:Orbit[${CurrentOffenseTarget},5000]
					echo DEBUG NOT MARAUDER
				}				
			}
		}
		else
		{
			; Exit condition
			; If we saw the destroy target, and it wasn't Anire Scarlet, they died in this room.
			;if ${CombatMissionDestroyTargetSeen}
			;{
			;	This:LogInfo["Destroyed Target - ${CurrentAgentDestroy}."]
			;	CurrentRunKilledTarget:Set[TRUE]
			;}
			if !${Entity[TypeID == 17831](exists)}
			{
				This:LogInfo["Room is Gateless, We have Vanquished all Enemies."]
				CurrentRunVanquisher:Set[TRUE]
			}
			if ${CurrentRunGatesUsed.Used} >= 4 && ${CurrentRunGatesUsed.Element["Gate To The Research Outpost"](exists)} > 0
			{
				This:LogInfo["Went through all gates in World's Collide, We have Vanquished all Enemies."]
				CurrentRunVanquisher:Set[TRUE]			
			}
			; Really want the salvage BM to work properly...
			Lootables:RequestUpdate
			if (${Lootables.TargetList.Used} >= ${Config.WreckBMThreshold} && ${Config.SalvagePrefix.NotNULLOrEmpty}) || ((${Lootables.TargetList.Used} > 1 && ${Entity[Name =- "Imperial"](exists)}) || (${Lootables.TargetList.Used} > 1 && ${Entity[Name =- "State"](exists)}) && ${Config.SalvagePrefix.NotNULLOrEmpty} )
			{
				EVE:GetBookmarks[BookmarkIndex]
				BookmarkIndex:RemoveByQuery[${LavishScript.CreateQuery[SolarSystemID == ${Me.SolarSystemID}]}, FALSE]
				BookmarkIndex:RemoveByQuery[${LavishScript.CreateQuery[Distance < 200000]}, FALSE]
				BookmarkIndex:Collapse
				if !${BookmarkIndex.Used}
				{
					Lootables.TargetList.Get[1]:CreateBookmark["${Config.SalvagePrefix} ${Lootables.TargetList.Used} ${EVETime.Time.Left[5]}", "", "${Config.SalvageBMFolderName}", 1]
					This:InsertState["CombatMissionTransition",6000]
					return TRUE
				}
			}
			This:LogInfo["Enemies destroyed in room ${CurrentRunRoomNumber}."]
			This:InsertState["CombatMission", 4000]
			return TRUE
		}
	
	}
	; This state will handle room transitions in a combat mission site.
	member:bool CombatMissionTransition()
	{
		if ${Move.Traveling}
		{
			return FALSE
		}
		if ${This.JerksPresent}
		{
			This:InsertState["CombatMission",4000]
			return TRUE
		}
		variable index:bookmark BookmarkIndex
		variable index:bookmark BookmarkIndex2
		variable iterator		BookmarkIterator2
		; The Salvage BM thing also has to go here. We either are changing rooms, or we are in a room with no gate so the one in the main CombatMission state will get it on exit.
		Lootables:RequestUpdate
		if (${Lootables.TargetList.Used} >= ${Config.WreckBMThreshold} && ${Config.SalvagePrefix.NotNULLOrEmpty}) || ((${Lootables.TargetList.Used} > 1 && ${Entity[Name =- "Imperial"](exists)}) || (${Lootables.TargetList.Used} > 1 && ${Entity[Name =- "State"](exists)}) && ${Config.SalvagePrefix.NotNULLOrEmpty} )
		{
			EVE:GetBookmarks[BookmarkIndex]
			BookmarkIndex:RemoveByQuery[${LavishScript.CreateQuery[SolarSystemID == ${Me.SolarSystemID}]}, FALSE]
			BookmarkIndex:RemoveByQuery[${LavishScript.CreateQuery[Distance < 200000]}, FALSE]
			BookmarkIndex:Collapse
			if !${BookmarkIndex.Used}
			{
				Lootables.TargetList.Get[1]:CreateBookmark["${Config.SalvagePrefix} ${Lootables.TargetList.Used} ${EVETime.Time.Left[5]}", "", "${Config.SalvageBMFolderName}", 1]
				EVE:RefreshBookmarks
			}
		}
		; We're going to examine the available gates. If the gate hasn't been taken before in this run (excluding a disconnect/crash) we will use it IF THERE IS ANOTHER GATE TO USE.
		; If there is only one gate then we will ignore that used gate list. This is going to be a shitload of work for the like, 1? 2? mission(s) with branches.
		; There are next to no checks in this because we shouldn't be here unless Combat Missioneer has ordered a room transition.
		if !${HaveGated}
		{
			echo ${CurrentRunGatesUsed.Used}
			variable index:entity GateIndex
			variable iterator GateIterator
			
			EVE:QueryEntities[GateIndex, "TypeID = 17831"]
			GateIndex:GetIterator[GateIterator]	
			if ${GateIndex.Used} > 1
			{
				; This should mean that we have entered the gate into the collecition already, meaning we used it.
				if ${CurrentRunGatesUsed.Element[${GateIterator.Value.Name}](exists)} > 0
				{
					This:LogInfo["We've used this gate before, trying the other one."]
					GateIterator:Next
				}
			}
			CurrentRunGatesUsed:Set[${GateIterator.Value.Name},${GateIterator.Value.ID}]
			Move:Gate[${GateIterator.Value.ID}]
			HaveGated:Set[TRUE]
			This:InsertState["CombatMissionTransition",2000]
			This:InsertState["Traveling",2000]
			This:InsertState["Idle",3000]
			return TRUE
		}
		; Theoretically if we are here we went through the gate to a new room. If this doesn't hold true then I will make a coordinate based detection method.
		This:UpdateMissioneerStats["RoomComplete"]
		CurrentRunRoomNumber:Inc[1]
		; MissionLogCombatUpdate(int RunNumber, int RoomNumber, bool KilledTarget, bool Vanquisher, bool ContainerLooted, bool HaveItems, bool TechnicalCompletion, bool TrueCompletion, int64 FinalTimestamp, int Historical)
		This:MissionLogCombatUpdate[${CurrentRunNumber},${CurrentRunRoomNumber},${CurrentRunKilledTarget},${CurrentRunVanquisher},${CurrentRunContainerLooted},${CurrentRunHaveItems},${CurrentRunTechnicalComplete},${CurrentRunTrueComplete},${Time.Timestamp},0]
		This:UpdateWatchDog
		HaveGated:Set[FALSE]
		This:InsertState["CombatMission", 4000]
		return TRUE		
	}
	; This state will handle the mission Objectives. String will be what we should do.
	member:bool CombatMissionObjectives(string ObjectiveAction)
	{
		echo ${ObjectiveID} OBJECTIVE ID
		if ${CurrentAgentLoot.NotNULLOrEmpty}
		{
			; Check our cargo for the stupid item.
			if ${MyShip.Cargo[${CurrentAgentItem}](exists)} && ${MyShip.Cargo[${CurrentAgentItem}].Quantity} >= ${CurrentAgentItemUnits}
			{
				CurrentRunContainerLooted:Set[TRUE]
				CurrentRunHaveItems:Set[TRUE]
				This:LogInfo["Acquired ${CurrentAgentItemUnits} of ${CurrentAgentItem}"]
				This:InsertState["CombatMission", 4000]
				return TRUE							
			}
			elseif ${MyShip.Cargo[${CurrentAgentItem}](exists)} && ${MyShip.Cargo[${CurrentAgentItem}].Quantity} < ${CurrentAgentItemUnits}
			{
				This:LogInfo["Acquired ${CurrentAgentItemUnits} of ${CurrentAgentItem}, More Remain"]
				This:InsertState["CombatMission", 4000]
				return TRUE						
			}
		}
		if ${ObjectiveAction.Equal["Destroy"]}
		{
			if ${Entity[Name == "${CurrentAgentDestroy.Escape}"].Distance} > ${CurrentOffenseRange}
			{
				Move:Approach[${Entity[Name == "${CurrentAgentDestroy.Escape}"]},2500]
				TargetManager.ActiveNPCs:AddQueryString[Name == "${CurrentAgentDestroy.Escape}"]
				CurrentOffenseTarget:Set[${Entity[Name == "${CurrentAgentDestroy.Escape}"]}]
			}
			elseif ${Entity[Name == "${CurrentAgentDestroy.Escape}"].Distance} < ${CurrentOffenseRange}
			{
				TargetManager.ActiveNPCs:AddQueryString[Name == "${CurrentAgentDestroy.Escape}"]
				CurrentOffenseTarget:Set[${Entity[Name == "${CurrentAgentDestroy.Escape}"]}]
			}
			if !${Entity[Name == "${CurrentAgentDestroy.Escape}"](exists)}
			{
				This:LogInfo["Destroyed Target - ${CurrentAgentDestroy}"]
				CurrentRunKilledTarget:Set[TRUE]
				This:InsertState["CombatMission", 4000]
				return TRUE						
			}
		}
		if ${ObjectiveAction.Equal["LootWreck"]}
		{
			if ${Entity[${ObjectiveID}].IsLockedTarget} && !${Ship.ModuleList_TractorBeams.IsActiveOn[${ObjectiveID}]}
			{
				if ${Ship.ModuleList_TractorBeams.InactiveCount} > 0
				{
					Ship.ModuleList_TractorBeams:ActivateOne[${ObjectiveID}]
				}
				else
				{
					Ship.ModuleList_TractorBeams:ForceActivateOne[${ObjectiveID}]
				}
			}
			if ${Entity[${ObjectiveID}].Distance} > 2500
			{
				Move:Approach[${Entity[${ObjectiveID}]},2000]
			}
			if ${Entity[${ObjectiveID}].Distance} < 2500
			{
				Entity[${ObjectiveID}]:Open
				EVEWindow[Inventory]:LootAll
				CurrentRunContainerLooted:Set[TRUE]
				return FALSE
			}			
			if ${CurrentRunContainerLooted}
			{
				; Check our cargo for the stupid item.
				if ${MyShip.Cargo[${CurrentAgentItem}](exists)} && ${MyShip.Cargo[${CurrentAgentItem}].Quantity} >= ${CurrentAgentItemUnits}
				{
					CurrentRunHaveItems:Set[TRUE]
					This:LogInfo["Acquired ${CurrentAgentItemUnits} of ${CurrentAgentItem}"]
					This:InsertState["CombatMission", 4000]
					return TRUE							
				}
				elseif ${MyShip.Cargo[${CurrentAgentItem}](exists)} && ${MyShip.Cargo[${CurrentAgentItem}].Quantity} < ${CurrentAgentItemUnits}
				{
					This:LogInfo["Acquired ${CurrentAgentItemUnits} of ${CurrentAgentItem}, More Remain"]
					This:InsertState["CombatMission", 4000]
					return TRUE						
				}
				else
				{
					; Dunno 
				}
			}
			if ${Entity[Name == \"${CurrentAgentLoot.Escape}\" && IsWreckEmpty == FALSE](exists)}
			{
				if ${Entity[Name == \"${CurrentAgentLoot.Escape}\" && IsWreckEmpty == FALSE].Distance} > 2500
				{
					Move:Approach[${ObjectiveTarget},2000]
				}
				if ${Entity[Name == \"${CurrentAgentLoot.Escape}\" && IsWreckEmpty == FALSE].Distance} < 2500
				{
					Entity[${ObjectiveTarget}]:Open
					EVEWindow[Inventory]:LootAll
					return FALSE
				}			
			}
		}
		if ${ObjectiveAction.Equal["LootContainer"]}
		{
			if ${Entity[Name == "${CurrentAgentLoot}"].IsLockedTarget} && !${Ship.ModuleList_TractorBeams.IsActiveOn[${Entity[Name == "${CurrentAgentLoot}"]}]}
			{
				if ${Ship.ModuleList_TractorBeams.InactiveCount} > 0
				{
					Ship.ModuleList_TractorBeams:ActivateOne[${Entity[Name == "${CurrentAgentLoot}"]}]
				}
				else
				{
					Ship.ModuleList_TractorBeams:ForceActivateOne[${Entity[Name == "${CurrentAgentLoot}"]}]
				}
			}
			; So uh, this can be awkward if the container is a Cargo Container. I think I will disable the Salvage Minimode's ability to Salvage things for the couple missions where this hapens.
			if ${Entity[Name == "${CurrentAgentLoot}"].Distance} > 2500
			{
				Move:Approach[${Entity[Name == "${CurrentAgentLoot}"]},2000]
			}
			if ${Entity[Name == "${CurrentAgentLoot}"].Distance} < 2500
			{
				Entity[Name == "${CurrentAgentLoot}" && Distance <= 2500]:Open
				EVEWindow[Inventory]:LootAll
				return FALSE
			}
			; Check our cargo for the stupid item.
			if ${MyShip.Cargo[${CurrentAgentItem}](exists)} && ${MyShip.Cargo[${CurrentAgentItem}].Quantity} >= ${CurrentAgentItemUnits}
			{
				CurrentRunContainerLooted:Set[TRUE]
				CurrentRunHaveItems:Set[TRUE]
				This:LogInfo["Acquired ${CurrentAgentItemUnits} of ${CurrentAgentItem}"]
				This:InsertState["CombatMission", 4000]
				return TRUE							
			}
			elseif ${MyShip.Cargo[${CurrentAgentItem}](exists)} && ${MyShip.Cargo[${CurrentAgentItem}].Quantity} < ${CurrentAgentItemUnits}
			{
				This:LogInfo["Acquired ${CurrentAgentItemUnits} of ${CurrentAgentItem}, More Remain"]
				This:InsertState["CombatMission", 4000]
				return TRUE						
			}
			elseif !${Entity[Name == "Cargo Container"](exists)}
			{
				This:LogInfo["Something went wrong, looping back to CombatMission loop"]
				This:InsertState["CombatMission", 4000]
				return TRUE		
			}		
		}
		return FALSE
	}
	; This state will be used to see if we have Technically Completed a mission (we can turn it in, but there are rooms left) or Truely Completed a mission
	; (everything is dead, objectives done). 
	member:bool CheckForCompletion()
	{
		; What defines Technical Completion? We can use the Original Mission Parser to figure it out easily. I think I will do that.
		if !${EVEWindow[AgentConversation_${CurrentAgentID}](exists)}
		{
			;missionIterator.Value:GetDetails
			EVE.Agent[${CurrentAgentIndex}]:StartConversation
			return FALSE
		}
		if ${MissionParser.IsComplete}
		{
			CurrentRunTechnicalComplete:Set[TRUE]
		}
		; What defines True Completion? We have seen every room, Killed every enemy, and accomplished Technical Completion.
		if ${CurrentRunTechnicalComplete}
		{
			; Vanquisher will be set either A) when we are in the last room without a gate and everything is dead or B) Have a full list of traversed gates for Worlds Collide.
			if ${CurrentRunVanquisher}
			{
				CurrentRunTrueComplete:Set[TRUE]
				This:MissionLogCombatUpdate[${CurrentRunNumber},${CurrentRunRoomNumber},${CurrentRunKilledTarget},${CurrentRunVanquisher},${CurrentRunContainerLooted},${CurrentRunHaveItems},${CurrentRunTechnicalComplete},${CurrentRunTrueComplete},${Time.Timestamp},0]
				This:UpdateWatchDog
			}
			; Extravaganzas yo. I'll bother with this more at a later date
			if ${CurrentAgentMissionName.Find["Extravaganza"]}
			{
				CurrentRunTrueComplete:Set[TRUE]
				This:MissionLogCombatUpdate[${CurrentRunNumber},${CurrentRunRoomNumber},${CurrentRunKilledTarget},${CurrentRunVanquisher},${CurrentRunContainerLooted},${CurrentRunHaveItems},${CurrentRunTechnicalComplete},${CurrentRunTrueComplete},${Time.Timestamp},0]
				This:UpdateWatchDog			
			}
		}
		if ${EVEWindow[AgentConversation_${CurrentAgentID}](exists)}
		{
			EVEWindow[ByCaption, Agent Conversation - ${EVE.Agent[${CurrentAgentIndex}].Name}]:Close
		}
		return TRUE
	}
	; This state will handle the bridge between CombatMission and FinishingAgentInteraction
	member:bool CombatMissionFinish()
	{
		; Literally forgot what I was going to put here. Oh right, we should go to the Agent's station before the next thing.
		if ${Move.Traveling}
		{
			return FALSE
		}
		if !${Me.InStation}
		{
			Move:Agent[${CurrentAgentIndex}]
			This:InsertState["Traveling"]
			return FALSE			
		}
		This:QueueState["FinishingAgentInteraction",5000]
		return TRUE	
	}
	; This state will be the Start of Primary Logic for Courier Missions. Basically this state here will be our hub for courier missions.
	; We need to figure out where we are, whether we have our cargo loaded, how much cargo remains, where are we going, etc. We also need to
	; have a recovery method in place in case of disconnect or what have you. Luckily, the DB has all we need.
	member:bool CourierMission()
	{
	
		echo DEBUG CMSHIPITEMS ${CourierMissionShipItems}
		echo DEBUG CMSTATIONITEMS ${CourierMissionStationItems}
		echo DEBUG CurrentAgentPickupID ${CurrentAgentPickupID}
		; Considering we have all of the information contained here as live variables already, no need to touch this thing below.
		; Addendum, somewhere we keep losing our freakin CurrentAgentPickupID, I'm tired of that.
		if ${CurrentAgentPickupID} == 0
		{
			GetDBJournalInfo:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal WHERE AgentID=${CurrentAgentID};"]}]
			if ${GetMissionLogCourier.NumRows} > 0
			{
				if ${GetDBJournalInfo.GetFieldValue["PickupLocationID",int64]} > 0
					CurrentAgentPickupID:Set[${GetDBJournalInfo.GetFieldValue["PickupLocationID",int64]}]	
				if ${GetDBJournalInfo.GetFieldValue["DropoffLocationID",int64]} > 0
					CurrentAgentDropoffID:Set[${GetDBJournalInfo.GetFieldValue["DropoffLocationID",int64]}]						
				GetDBJournalInfo:Finalize
			}
		}
		; Alright so, my first attempt at this didn't go so well. Using members to get inventory info was a bad call. Whatever amadeus did at some point
		; to slow down how quickly you can get inventory info is coming back to haunt me. Basically, this is going to go from taking 4 states (Start, dropoff, pickup, finish)
		; to something like 7 (start, check station inventory, check ship inventory, load, travel, unload, finish).
		
		; First up, are we in station or are we in space.
		if ${Me.InStation}
		{
			; Check both inventories, we are in a station.

			;Are we in the pickup station or dropoff station, or somewhere else entirely?
			if ${Me.StationID} == ${CurrentAgentPickupID}
			{
				echo DEBUG IN AGENT PICKUP STATION
				; We are in the Pickup station, have we already loaded the items?
				if ${CourierMissionShipItems} > 0
				{
					; We have loaded the items
					This:LogInfo["Courier Start - Dropoff - ${CurrentAgentDropoff}"]
					CourierMissionTravelState:Set["Dropoff"]
					CurrentRunTripNumber:Inc[1]
					This:UpdateWatchDog
					This:MissionLogCourierUpdate[${CurrentRunNumber},${CurrentRunTripNumber},${CurrentRunItemUnitsMoved},${CurrentRunVolumeMoved},${Time.Timestamp},FALSE}]
					This:InsertState["CourierMissionTravel",5000]
					return TRUE
					
				}
				if ${CourierMissionStationItems} > 0 && ${CourierMissionShipItems} == 0
				{
					; We have not loaded the items
					This:LogInfo["Courier Start - Loading"]					
					This:InsertState["CourierMissionLoadShip",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
					return TRUE
				}
				if ${CourierMissionStationItems} == 0 && ${CourierMissionShipItems} == 0
				{
					; The items have phased out of existence.
					echo DEBUG - END OF THE LINE
					This:QueueState["CourierMission",5000]
					This:InsertState["CourierMissionCheckStation", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
					This:InsertState["RefreshStationItemsState", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
					This:InsertState["CourierMissionCheckShip", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
					This:InsertState["RefreshLargestBayState", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
					;This:InsertState["GetHaulerDetails",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
					return TRUE
				}
			}
			elseif ${Me.StationID} == ${CurrentAgentDropoffID}
			{
				; we are in the Dropoff Station, have we already unloaded the items?
				if ${CourierMissionShipItems} > 0
				{
					; We have not unloaded the items
					This:LogInfo["Courier Start - Unloading"]					
					This:InsertState["CourierMissionUnloadShip",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
					return TRUE					
				}
				if ${CourierMissionStationItems} > 0 && ${CourierMissionShipItems} == 0
				{
					; We have unloaded the item, are all the items here at the dropoff?
					if ${CourierMissionStationItems} == ${CurrentAgentItemUnits}
					{
						; All of the items are here, go to finish.
						This:LogInfo["Courier Start - Complete Mission"]
						This:UpdateWatchDog
						This:MissionLogCourierUpdate[${CurrentRunNumber},${CurrentRunTripNumber},${CurrentRunItemUnitsMoved},${CurrentRunVolumeMoved},${Time.Timestamp},FALSE}]						
						This:InsertState["CourierMissionFinish",5000]
						return TRUE
					}
					else
					{
						; The items are not all here, go back to pickup
						This:LogInfo["Courier Start - Pickup - ${CurrentAgentPickup}"]
						CourierMissionTravelState:Set["Pickup"]
						This:UpdateWatchDog
						This:MissionLogCourierUpdate[${CurrentRunNumber},${CurrentRunTripNumber},${CurrentRunItemUnitsMoved},${CurrentRunVolumeMoved},${Time.Timestamp},FALSE}]
						This:InsertState["CourierMissionTravel",5000]
						return TRUE						
					}
					
				}
				if ${CourierMissionStationItems} == 0 && ${CourierMissionShipItems} == 0 && ${Me.StationID} == ${CurrentAgentDropoffID}
				{
					; The items have phased out of existence.
					This:LogInfo["Items missing, or Dropoff Location is Agent Location - Go to Pickup"]
					CourierMissionTravelState:Set["Pickup"]
					This:InsertState["CourierMissionTravel",5000]					
					return TRUE
				}
				else
				{
					; Edge case I haven't figured out yet
				
				}
			}
			else
			{
				; We are in some other station that is neither our dropoff nor our pickup, somehow
			}
		}
		else
		{
			; We are in space, check our ship to see if we have the items or not.
			if ${CourierMissionShipItems} > 0
			{
				; We have the goods, we must be headed to our dropoff station
				This:LogInfo["Courier Travel - Dropoff - ${CurrentAgentDropoff}"]
				CourierMissionTravelState:Set["Dropoff"]
				This:InsertState["CourierMissionTravel",5000]
				return TRUE
			}
			elseif ${CourierMissionShipItems} == 0
			{
				; We do not have the goods, we must be headed to the pickup.
				This:LogInfo["Courier Travel - Pickup - ${CurrentAgentPickup}"]
				CourierMissionTravelState:Set["Pickup"]
				This:InsertState["CourierMissionTravel",5000]
				return TRUE
			}
			This:InsertState["CourierMission",5000]
			This:InsertState["CourierMissionCheckShip",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
		}
	}
	; This state will be for checking the station inventory.
	member:bool CourierMissionCheckStation(int Cycles)
	{
		variable index:item itemIndex
		variable iterator itemIterator
		; in case you somehow ended up moving multiple stacks of the item, no idea
		variable int itemtotal = 0
		echo DEBUG CMCSTATION
		if ${Client.InSpace}
		{
			return TRUE
		}
		if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
		{
			EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
			This:InsertState["CourierMissionCheckStation",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
		}
		
		if ${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
		{
			EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[itemIndex]
			if ${itemIndex.Used} < 1 && ${Cycles} < 3
			{
				; Theoretically, for Load and Unload, we wouldn't have gotten here if there wasn't something to move.
				This:LogInfo["Returned Empty Index - Cycling"]
				This:InsertState["CourierMissionCheckStation",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int},"${Math.Calc[${Cycles} + 1]}"]
				return TRUE
			}			
			itemIndex:GetIterator[itemIterator]
			if ${itemIterator:First(exists)}
			{
				do
				{
					if ${itemIterator.Value.Name.Find[${CurrentAgentItem}]}
					{
						itemtotal:Inc[${itemIterator.Value.Quantity}]
					}
				}
				while ${itemIterator:Next(exists)}
			}
			;;; Not sure if we need to get this granular
			;if ${Me.StationID} == ${CurrentAgentDropoffID}
			;{
			;	CourierMissionDropoffStationItems:Set[${itemtotal}]
			;	This:LogInfo["${itemtotal} x ${CurrentAgentItem} located in Dropoff Station Hangar"]
			;}
			;if ${Me.StationID} == ${CurrentAgentPickupID}
			;{
			;	CourierMissionPickupStationItems:Set[${itemtotal}]
			;	This:LogInfo["${itemtotal} x ${CurrentAgentItem} located in Pickup Station Hangar"]			
			;}
			CourierMissionStationItems:Set[${itemtotal}]
			This:LogInfo["${itemtotal} x ${CurrentAgentItem} located in Station Hangar"]				
			return TRUE
		}			
	}
	; This state will be for checking your ship's inventory.
	member:bool CourierMissionCheckShip(int Cycles)
	{
		variable index:item itemIndex
		variable iterator itemIterator
		; in case you somehow ended up moving multiple stacks of the item, no idea
		variable int itemtotal = 0
		echo DEBUG CMCSHIP
		echo ${HaulerLargestBayType}
		if !${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"${HaulerLargestBayType}"](exists)}
		{
			EVEWindow[Inventory].ChildWindow[${MyShip.ID},"${HaulerLargestBayType}"]:MakeActive
			This:InsertState["CourierMissionCheckShip",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
		}
		
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"${HaulerLargestBayType}"](exists)}
		{
			EVEWindow[Inventory].ChildWindow[${MyShip.ID},"${HaulerLargestBayType}"]:GetItems[itemIndex]
			if ${itemIndex.Used} < 1 && ${Cycles} < 3
			{
				; Theoretically, for Load and Unload, we wouldn't have gotten here if there wasn't something to move.
				This:LogInfo["Returned Empty Index - Cycling"]
				This:InsertState["CourierMissionCheckShip",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int},"${Math.Calc[${Cycles} + 1]}"]
				return TRUE
			}
			itemIndex:GetIterator[itemIterator]
			if ${itemIterator:First(exists)}
			{
				do
				{
					if ${itemIterator.Value.Name.Find[${CurrentAgentItem}]}
					{
						itemtotal:Inc[${itemIterator.Value.Quantity}]
						echo DWHIAHM ${itemtotal}
					}
				}
				while ${itemIterator:Next(exists)}
			}
			This:LogInfo["${itemtotal} x ${CurrentAgentItem} located in ${HaulerLargestBayType}"]
			CourierMissionShipItems:Set[${itemtotal}]
			return TRUE
		}		
	}
	; This state will be for loading.
	member:bool CourierMissionLoadShip()
	{
		variable index:item itemIndex
		variable iterator	itemIterator
		variable int		wholeUnits
		echo HAULER LARGEST ${HaulerLargestBayType} ${HaulerLargestBayCapacity}
		if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
		{
			EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
			This:InsertState["CourierMissionLoadShip",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
		}
		if ${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
		{
			EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[itemIndex]
			if ${itemIndex.Used} < 1
			{
				; Theoretically, for Load and Unload, we wouldn't have gotten here if there wasn't something to move.
				This:LogInfo["Returned Empty Index - Cycling"]
				return FALSE
			}
			itemIndex:GetIterator[itemIterator]
			if ${itemIterator:First(exists)}
			{
				do
				{
					if ${itemIterator.Value.Name.Find[${CurrentAgentItem}]}
					{
						wholeUnits:Set[${Math.Calc[${HaulerLargestBayCapacity}/${itemIterator.Value.Volume}].Int}]
						if ${itemIterator.Value.Quantity} > ${wholeUnits}
						{
							itemIterator.Value:MoveTo[${Me.ShipID}, ${HaulerLargestBayLocationFlag}, ${wholeUnits}]
							This:LogInfo["${wholeUnits} x ${CurrentAgentItem} @ ${Math.Calc[${wholeUnits}*${itemIterator.Value.Volume}]}m3 moved FROM Station TO ${HaulerLargestBayType}"]
						}
						else
						{
							itemIterator.Value:MoveTo[${Me.ShipID}, ${HaulerLargestBayLocationFlag}, ${itemIterator.Value.Quantity}]
							This:LogInfo["${itemIterator.Value.Quantity} x ${CurrentAgentItem} @ ${Math.Calc[${itemIterator.Value.Quantity}*${itemIterator.Value.Volume}]}m3 moved FROM Station TO ${HaulerLargestBayType}"]						
						}
					}
				}
				while ${itemIterator:Next(exists)}
			}
		}
		This:InsertState["CourierMission",5000]
		This:InsertState["CourierMissionCheckStation", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
		This:InsertState["RefreshStationItemsState", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
		This:InsertState["CourierMissionCheckShip", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
		This:InsertState["RefreshLargestBayState", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
		return TRUE
	}
	; This state will be for unloading.
	member:bool CourierMissionUnloadShip()
	{
		variable index:item itemIndex
		variable iterator itemIterator
		
		if !${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"${HaulerLargestBayType}"](exists)}
		{
			EVEWindow[Inventory].ChildWindow[${MyShip.ID},"${HaulerLargestBayType}"]:MakeActive
			This:InsertState["CourierMissionUnloadShip",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
		}
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"${HaulerLargestBayType}"](exists)}
		{
			EVEWindow[Inventory].ChildWindow[${MyShip.ID},"${HaulerLargestBayType}"]:GetItems[itemIndex]
			itemIndex:GetIterator[itemIterator]
			if ${itemIndex.Used} < 1
			{
				; Theoretically, for Load and Unload, we wouldn't have gotten here if there wasn't something to move.
				This:LogInfo["Returned Empty Index - Cycling"]
				return FALSE
				
			}
			if ${itemIterator:First(exists)}
			{
				do
				{
					if ${itemIterator.Value.Name.Find[${CurrentAgentItem}]}
					{
						itemIterator.Value:MoveTo[MyStationHangar, Hangar]
						CurrentRunItemUnitsMoved:Inc[${itemIterator.Value.Quantity}]
						CurrentRunVolumeMoved:Inc[${Math.Calc[${itemIterator.Value.Quantity}*${itemIterator.Value.Volume}]}]
						This:LogInfo["${itemIterator.Value.Quantity} x ${CurrentAgentItem} @ ${Math.Calc[${itemIterator.Value.Quantity}*${itemIterator.Value.Volume}]}m3 moved FROM ${HaulerLargestBayType} TO Station"]
					}
				}
				while ${itemIterator:Next(exists)}
			}
			
		}
		This:InsertState["CourierMission",5000]
		This:InsertState["CourierMissionCheckStation", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
		This:InsertState["RefreshStationItemsState", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
		This:InsertState["CourierMissionCheckShip", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
		This:InsertState["RefreshLargestBayState", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
		return TRUE
	
	}
	; This state will be for travelling, outbound or inbound.
	member:bool CourierMissionTravel()
	{
		; Ok so we get called to this state, a variable is already set that says what this state will be doing, we do what it says
		; and then we set that variable to blank.
		if ${Me.InStation}
		{
			; We are docked, we need to not be, undock and restart state.
			This:LogInfo["We need to be undocked for this part"]
			Move:Undock
			return FALSE
		}
		else
		{
			;if ${CourierMissionTravelState.Equal["Dropoff"]}
			;{
				; State of dropoff, therefore travel to the dropoff station, then return to the initial courier state.
				;Move:TravelToStation[${CurrentAgentDropoffID}]
				; Nope, TravelToStation is broken as hell, guess we are doing a Move:AgentBookmark instead.
				; That means we get to iterate through our bookmarks and find the right one woo.
				;Move:AgentBookmark[${This.CourierMissionDestination}]
				; Mot sure if we are capable of escaping the traveling state while this is all going on. TravelToStation is a goddamn mystery ass relic piece of code. I don't know
				; if you get captured by that state or not.
				;if ${Me.StationID} == ${CurrentAgentDropoffID}
				;{
				;	CourierMissionTravelState:Set[""]
				;	This:InsertState["CourierMissionCheckStation", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				;	This:InsertState["RefreshStationItemsState", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				;	This:InsertState["CourierMissionCheckShip", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				;	This:InsertState["RefreshLargestBayState", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				;	return TRUE
				;}
				;else
				;{
				;	return FALSE
				;}
			;}
			;if ${CourierMissionTravelState.Equal["Pickup"]}
			;{
				; State of pickup, therefore travel to the pickup station, then return to the initial courier state.		
				;Move:TravelToStation[${CurrentAgentPickupID}]
				;Move:AgentBookmark[${This.CourierMissionDestination}]
				; Mot sure if we are capable of escaping the traveling state while this is all going on. TravelToStation is a goddamn mystery ass relic piece of code. I don't know
				; if you get captured by that state or not.
				;if ${Me.StationID} == ${CurrentAgentPickupID}
				;{
				;	CourierMissionTravelState:Set[""]
				;	This:InsertState["CourierMissionCheckStation", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				;	This:InsertState["RefreshStationItemsState", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				;	This:InsertState["CourierMissionCheckShip", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				;	This:InsertState["RefreshLargestBayState", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				;	return TRUE 
				;}
				;else
				;{
				;	return FALSE
				;}
			;}
			Move:AgentBookmark[${This.CourierMissionDestination}]
			This:InsertState["CourierMission",5000]
			This:InsertState["CourierMissionCheckStation", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
			This:InsertState["RefreshStationItemsState", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
			This:InsertState["CourierMissionCheckShip", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
			This:InsertState["RefreshLargestBayState", ${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
			This:InsertState["Traveling"]
			return TRUE
		}
	}
	; This state is for CourierMissionFinish. If we are in this state it means we are at the dropoff location, and all the items are in the station. We will record some final information
	; and reset some variables, then go to FinishingAgentInteraction.
	member:bool CourierMissionFinish()
	{
			This:MissionLogCourierUpdate[${CurrentRunNumber},${CurrentRunTripNumber},${CurrentRunItemUnitsMoved},${CurrentRunVolumeMoved},${Time.Timestamp},0]
			This:UpdateWatchDog
			This:QueueState["FinishingAgentInteraction",5000]
			return TRUE

	}
	; This uh, state, will be for Trade mission turnins. Its probably going to be like, 3 lines. Most of the work is done before here.
	member:bool TradeMission()
	{
		; We SHOULD already have our items. We should also already be at the dropoff station, because that is the agent's location...
		; Guess we will just verify we are in the right place. Also, can you do the turnin with the items in an ore bay or ship fleet hangar? Dunno. Guess we will find out.
		if ${Me.StationID} != ${EVE.Agent[${CurrentAgentIndex}].StationID}
		{
			This:LogCritical["Something went wrong with this trade mission - Stopping"]
			This:Stop
			return TRUE			
		}
		; MissionLogCourierUpdate(int RunNumber, int TripNumber, int UnitsMoved, int64 VolumeMoved, int64 FinalTimestamp, int Historical)
		This:MissionLogCourierUpdate[${CurrentRunNumber},${CurrentRunTripNumber},${CurrentAgentItemUnits},${CurrentAgentVolumeTotal},${Time.Timestamp},'FALSE'}]
		This:QueueState["FinishingAgentInteraction",5000]
		return TRUE
	}
	; This state will be where we do our finishing interaction with our Agent. This comes at mission completion.
	; This is also where we, when we turn in the mission, do our final MissionLog entry in whatever table it belongs to.
	; We will set that row to Historical, update any final details that need to be updated, clean up any variables that need cleaning up.
	member:bool FinishingAgentInteraction()
	{
		; Storing our wallet just before we hit complete button.
		ISKBeforeCompletion:Set[${Me.Wallet.Balance.Int}]
		; Open a conversation window, again.
		if !${EVEWindow[AgentConversation_${CurrentAgentID}](exists)}
		{
			This:LogInfo["Opening Conversation Window."]
			EVE.Agent[${CurrentAgentIndex}]:StartConversation
			This:InsertState["Idle", 2000]
			return FALSE
		}	
		if ${EVEWindow[AgentConversation_${CurrentAgentID}].Button["View Mission"](exists)}
		{
			EVEWindow[AgentConversation_${CurrentAgentID}].Button["View Mission"]:Press
			This:InsertState["Idle", 2000]
			return FALSE
		}
		if ${EVEWindow[AgentConversation_${CurrentAgentID}].Button["Complete Mission"](exists)}
		{
			EVEWindow[AgentConversation_${CurrentAgentID}].Button["Complete Mission"]:Press
			This:InsertState["Idle", 2000]
			return FALSE
		}
		; Storing our wallet just after we hit the complete button.
		ISKAfterCompletion:Set[${Me.Wallet.Balance.Int}]
		; Mission Completion MissioneerStats Update
		This:UpdateMissioneerStats["RunComplete"]
		This:BackupSalvageBMTableMethod
		;We can be fairly sure the mission completed correctly.
		if ${CurrentAgentMissionType.Find[Courier]}
		{
			This:MissionLogCourierUpdate[${CurrentRunNumber},${CurrentRunTripNumber},${CurrentRunItemUnitsMoved},${CurrentRunVolumeMoved},${Time.Timestamp},1}]
			This:LogInfo["Mission complete - Finalizing Courier Log Entry"]
		}
		elseif ${CurrentAgentMissionType.Find[Trade]}
		{
			This:MissionLogCourierUpdate[${CurrentRunNumber},${CurrentRunTripNumber},${CurrentAgentItemUnits},${CurrentAgentVolumeTotal},${Time.Timestamp},1}]
			This:LogInfo["Mission complete - Finalizing Trade Log Entry"]
		}
		else
		{
			; MissionLogCombatUpdate(int RunNumber, int RoomNumber, bool KilledTarget, bool Vanquisher, bool ContainerLooted, bool HaveItems, bool TechnicalCompletion, bool TrueCompletion, int64 FinalTimestamp, int Historical)
			This:MissionLogCombatUpdate[${CurrentRunNumber},${CurrentRunRoomNumber},${CurrentRunKilledTarget},${CurrentRunVanquisher},${CurrentRunContainerLooted},${CurrentRunHaveItems},${CurrentRunTechnicalComplete},${CurrentRunTrueComplete},${Time.Timestamp},1}]
			This:LogInfo["Mission complete - Finalizing Combat Log Entry"]				
		}
		CurrentRunNumber:Inc[1]
		Script[Tehbot].VariableScope.Mission.Config:SetRunNumberInt[${CurrentRunNumber}]
		This:QueueState["BeginCleanup",5000]
		return TRUE
	}
	; This state will be where we kick off our station interaction stuff. Repairs, loot dropoff, etc.
	; After this state we should go back to CheckForWork.
	member:bool BeginCleanup()
	{
		if ${CurrentAgentMissionType.Find["Encounter"]}
		{
			relay "all" -event Tehbot_SalvageBookmark ${Me.ID}
			CurrentRunGatesUsed:Clear
			This:InsertState["DropOffLoot", 10000]			
			This:InsertState["Repair"]
		}
		; Delete the row now that the mission is gone.
		CharacterSQLDB:ExecDML["DELETE From MissionJournal WHERE AgentID=${CurrentAgentID};"]
		EVEWindow[AgentConversation_${CurrentAgentID}]:Close
		This:ClearCurrentAgentVariables
		DatabasificationComplete:Set[FALSE]
		CheckedMissionLogs:Set[FALSE]
		This:QueueState["CheckForWork",4000]
		return TRUE
	}
	; This is a great name for a state. Anyways, here in Databasification we will take our Mission Journal, go through all of the missions
	; Then we will place the information in the SQL database for easier consumption presumably. I won't lie, it has been more than one day
	; Since I worked on this, so I've somewhat lost the plot. Each mission will be placed into the Character Specific MissionJournal Table.
	; From there we can use that information to accomplish something, surely. I am fairly sure that in order to accomplish this I will have to touch the mission parser
	; at least a little bit. Also we will need to get some info from that mission data file.
	; Addendum, the do-while loop is being really stupid so we are going to have to do stupid bullshit again.
	; DesiredIterator will be the iterator we want to go to. We are assuming the iterator doesn't change order magically somehow.
	; RefreshMissionsRequested will indicate we want to redo the GetAgentMissions and iteration of such.
	member:bool Databasification(int DesiredIterator, bool RefreshMissionsRequested, bool ParseCompleted)
	{
		; Oh god where do I even begin. Well let us look at that MissionJournal Table I made and how its rows are set up.
		; (AgentID INTEGER PRIMARY KEY, MissionName TEXT, MissionType TEXT, MissionStatus INTEGER, AgentLocation TEXT, MissionLocation TEXT, DropoffLocation TEXT, PickupLocation TEXT, Lowsec BOOLEAN, JumpDistance INTEGER, 
		;  ExpectedItems TEXT, ItemUnits INTEGER, ItemVolume INTEGER, VolumePer INTEGER, DestroyTarget TEXT, LootTarget TEXT, Damage2Deal TEXT);"]
		; Basically we want to assemble all of this information from what we can pull from the Mission Journal, the Mission Details, and our Mission Data XML, and then finally from some minor calculations from those 3 sources.\
		; We take that information and fork it over to MissionJournalUpsert method. And hence, it is databasificated.
		; Guess we should get our limited scope variables in a row here.
		; These we can pull directly from the mission journal
		variable int64 AgentID
		variable string MissionName
		variable string MissionType
		variable int MissionStatus
		; These we get from our mission data file
		variable string DestroyTarget
		variable string LootTarget
		variable string Damage2Deal
		; These we can pull when we get mission details and parse them. This was extreme hubris by the way. 
		variable string AgentLocation
		variable string MissionLocation
		variable string ExpectedItems
		variable int ItemUnits
		variable int64 ItemVolume
		variable string PickupLocation
		variable string DropoffLocation
		variable bool Lowsec
		variable int LPReward
		variable int64 PickupLocationID
		variable int64 DropoffLocationID
		; These will be derived from the above.
		; JumpDistance is how many jumps to the Agent from where we are, then from the agent to the mission location. Volume per is just total volume / units.
		; Aaaactually, I can't think of a great way to get JumpDistance, the pathing won't behave correctly. It ignores autopilot settings and whatnot.
		variable int JumpDistance
		variable int64 VolumePer
		
		; Begin the work. Lets get all our current missions.
		; Either we requested a refresh of our agentmissions index, or it is empty.
		if ${RefreshMissionsRequested} || !${missionIterator.IsValid}
		{
			This:LogInfo["Refreshing AgentMissions index and Iterator."]
			EVE:GetAgentMissions[missions]
			missions:GetIterator[missionIterator]
		}
		while ${missionIterator.Key} < ${DesiredIterator} && ${missionIterator.Key} < ${missions.Used}
		{
			missionIterator:Next
		}
		if ${missionIterator.Key} == ${DesiredIterator}
		{
			echo ${missionIterator.Value.AgentID} ID
			; Lets get a convo window open with this agent.
			if ${EVEWindow[AgentConversation_${missionIterator.Value.AgentID}].BriefingHTML.AsJSON.Find["Sorry, but I only work with people I trust."]}
			{
				EVEWindow[ByCaption, Agent Conversation]:Close
				This:LogInfo["Old Agent Window Detected - Skipping"]
				This:QueueState["Databasification", 2000, "${Math.Calc[${missionIterator.Key} + 1]}, FALSE"]
				return TRUE
			}
			if !${EVEWindow[AgentConversation_${missionIterator.Value.AgentID}](exists)}
			{
				echo start conversation
				EVE.Agent[id,${missionIterator.Value.AgentID}]:StartConversation
				This:LogInfo["Opening Agent Window - Restarting Current Loop"]
				This:QueueState["Databasification", 2000, "${missionIterator.Key}, FALSE"]
				return TRUE
			}
			if ${EVEWindow[AgentConversation_${missionIterator.Value.AgentID}].Button["View Mission"](exists)}
			{
				echo press view mission
				EVEWindow[AgentConversation_${missionIterator.Value.AgentID}].Button["View Mission"]:Press
				This:LogInfo["View Mission Press - Restarting Current Loop"]
				This:QueueState["Databasification", 2000, "${missionIterator.Key}, FALSE"]
				return TRUE
			}
			if !${EVEWindow[AgentConversation_${missionIterator.Value.AgentID}].ObjectivesHTML.AsJSON.Find["The following rewards will be yours if you complete this mission"]}
			{
				This:LogInfo["Incomplete HTML Grab - Restarting Current Loop"]
				This:QueueState["Databasification", 2000, "${missionIterator.Key}, FALSE"]
				return TRUE
			}
			; I guess we will want to skip checking things that are in the Table but haven't changed.
			GetDBJournalInfo:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal WHERE AgentID=${missionIterator.Value.AgentID} AND MissionName='${missionIterator.Value.Name}' AND MissionStatus=${missionIterator.Value.State};"]}]
			echo DEBUG TENTH QUERY
			if ${GetDBJournalInfo.NumRows} > 0
			{
				; If it already exists in the DB, in the same state, the same mission name, from the same agent, it is safe to say it is already there. Skip it.
				This:LogInfo["Entry Already Exists - Skipping"]
				EVEWindow[ByCaption, Agent Conversation]:Close
				EVEWindow[ByCaption, Agent Conversation]:Close
				This:QueueState["Databasification", 2000, "${Math.Calc[${missionIterator.Key} + 1]}, FALSE"]
				return TRUE
			}
			if ${missionIterator.Value.State} == 3
			{
				; If it is an expired mission, don't databasify it.
				This:LogInfo["Expired Mission - Skipping"]
				EVEWindow[AgentConversation_${AgentID}]:Close
				This:QueueState["Databasification", 2000, "${Math.Calc[${missionIterator.Key} + 1]}, FALSE"]
				return TRUE				
			}
			GetDBJournalInfo:Finalize
			; To hell with that Mission Parser, why use that when I can make my own thing that might work once in a while.
			;This:ParseMissionDetails[${missionIterator.Value.AgentID}, ${missionIterator.Value.Type}]
			if !${ParseCompleted}
			{
				; Clear last parse variables
				LastAgentLocation:Set[""]
				LastMissionLocation:Set[""]
				LastExpectedItems:Set[""]
				LastItemUnits:Set[0]
				LastItemVolume:Set[0]
				LastLowsec:Set[FALSE]
				LastDropoff:Set[""]
				LastPickup:Set[""]
				LastLPReward:Set[0]
				LastPickupID:Set[0]
				LastDropoffID:Set[0]
				This:InsertState["ParseMissionDetails",4000,"${missionIterator.Value.AgentID},${missionIterator.Value.Type},${DesiredIterator}"]
				return TRUE
			}
			; Simple stuff
			AgentID:Set[${missionIterator.Value.AgentID}]
			MissionName:Set[${missionIterator.Value.Name}]
			MissionType:Set[${missionIterator.Value.Type}]
			MissionStatus:Set[${missionIterator.Value.State}]
			; Data file
			DestroyTarget:Set[""]
			if ${TargetToDestroy.Element[${MissionName}](exists)}
			{
				This:LogInfo["Destroy target: \ao${TargetToDestroy.Element[${MissionName}]}"]
				DestroyTarget:Set[${TargetToDestroy.Element[${MissionName}]}]
			}
			LootTarget:Set[""]
			if ${ContainerToLoot.Element[${MissionName}](exists)}
			{
			This:LogInfo["Loot container: \ao${ContainerToLoot.Element[${MissionName}]}"]
				LootTarget:Set[${ContainerToLoot.Element[${MissionName}]}]
			}
			Damage2Deal:Set[${DamageType.Element[${MissionName}].Lower}]
			; Info from parsing the mission details
			AgentLocation:Set[${LastAgentLocation}]
			MissionLocation:Set[${LastMissionLocation}]
			ExpectedItems:Set[${LastExpectedItems}]
			ItemUnits:Set[${LastItemUnits}]
			ItemVolume:Set[${LastItemVolume}]
			PickupLocation:Set[${LastPickup}]
			PickupLocationID:Set[${LastPickupID}]
			echo PickupLocationID ${PickupLocationID}
			DropoffLocation:Set[${LastDropoff}]
			DropoffLocationID:Set[${LastDropoffID}]
			echo DropoffLocationID ${DropoffLocationID}
			echo ${LastDropoffID}
			echo ${DropoffLocationID.Equal[${LastDropoffID}]}
			Lowsec:Set[${LastLowsec}]
			LPReward:Set[${LastLPReward}]
			; Derived information
			if ${LastItemUnits} > 0
				VolumePer:Set[${Math.Calc[${LastItemVolume} / ${LastItemUnits}]}]
			; Assemble information and prepare to Insert into Table
			; MissionJournalUpsert(int64 AgentID, string MissionName, string MissionType, int MissionStatus, string AgentLocation, string MissionLocation, string DropoffLocation, int64 DropOffLocationID, string PickupLocation, int64 PickupLocationID, bool Lowsec, int JumpDistance, string ExpectedItems, int ItemUnits, int64 ItemVolume, int MissionLPReward, int64 VolumePer, string DestroyTarget, string LootTarget, string Damage2Deal)
			echo ${AgentID},${MissionName.ReplaceSubstring[','']}, ${MissionType.ReplaceSubstring[',''].ReplaceSubstring[UI/Agents/MissionTypes/,].ReplaceSubstring[\},]}, ${MissionStatus}, ${AgentLocation.ReplaceSubstring[','']}, ${MissionLocation.ReplaceSubstring[','']}, ${DropoffLocation.ReplaceSubstring[','']}, ${DropoffLocationID}, ${PickupLocation.ReplaceSubstring[','']}, ${PickupLocationID}, ${Lowsec}, ${JumpDistance}, ${ExpectedItems.ReplaceSubstring[','']}, ${ItemUnits}, ${ItemVolume}, ${LPReward}, ${VolumePer}, ${DestroyTarget.ReplaceSubstring[','']},${LootTarget.ReplaceSubstring[','']},${Damage2Deal}
			This:MissionJournalUpsert[${AgentID},${MissionName.ReplaceSubstring[','']}, ${MissionType.ReplaceSubstring[',''].ReplaceSubstring[UI/Agents/MissionTypes/,].ReplaceSubstring[\},]}, ${MissionStatus}, ${AgentLocation.ReplaceSubstring[','']}, ${MissionLocation.ReplaceSubstring[','']}, ${DropoffLocation.ReplaceSubstring[','']}, ${DropoffLocationID}, ${PickupLocation.ReplaceSubstring[','']}, ${PickupLocationID}, ${Lowsec}, ${JumpDistance}, ${ExpectedItems.ReplaceSubstring[','']}, ${ItemUnits}, ${ItemVolume}, ${LPReward}, ${VolumePer}, ${DestroyTarget.ReplaceSubstring[','']}, ${LootTarget.ReplaceSubstring[','']}, ${Damage2Deal}]
			if ${EVEWindow[AgentConversation_${AgentID}](exists)}
			{
				This:LogInfo["Entry Processed, closing window"]
				EVEWindow[AgentConversation_${AgentID}]:Close
			}				
			if ${missionIterator.Key} < ${missions.Used}
			{
				This:LogInfo["Unprocessed Entries Remain - Looping"]
				This:QueueState["Databasification", 2000, "${Math.Calc[${missionIterator.Key} + 1]}, FALSE, FALSE"]
				return TRUE
			}
			else
				This:LogInfo["All Entries Processed - Leaving Databasification"]
		}
		; Next up, lets run a quick deletion on all Expired Mission Offers
		echo DEBUG - Databasification Deletion
		CharacterSQLDB:ExecDML["Delete FROM MissionJournal WHERE MissionStatus=3;"]
		DatabasificationComplete:Set[TRUE]
		This:ClearCurrentAgentVariables
		This:QueueState["CurateMissions",2000]
		return TRUE

	}
	; This method will be used to do our Agent Conversation HTML parsing. Because the existing stuff is just too damn easy.
	; We will also be using Agent ID instead of Index, because I'm a rebel. This can't possibly come back to haunt me.
	; Addendum, need to make this a state rather than method because, once again, it is moving too fast. Fuck.
	member:bool ParseMissionDetails(string AgentID, string MissionType, int ReturnIterator)
	{
		; VERY FIRST THING. Let us make sure the stupid HTML is all loaded eh?
		if !${EVEWindow[AgentConversation_${AgentID}].BriefingHTML.AsJSON.Find[</html>]}
		{
			; Briefing not loaded, looping
			return FALSE
		}
		if !${EVEWindow[AgentConversation_${AgentID}].ObjectivesHTML.AsJSON.Find[</html>]}
		{
			; Objectives not loaded, looping
			return FALSE
		}
		; Temp storage strings for jsonified HTML trash.
		variable string JSONObjective
		variable string JSONBriefing
		; Record the location of the first <br><br>
		variable int FirstBRBR
		; Then we are going to take a substring from that position for the next idk, 2000 characters?
		variable string JSONBriefingString1
		; Then we are going to take the location of the first //
		variable int FirstSlashSlash
		; Substring from there...
		variable string JSONBriefingString2
		; Then we are going to take the location of the first >
		variable int FirstAngleBracket
		; And then we have the ID of the station, after all that crap. What the hell.
		variable int64 StationID
		; For combat/mining missions we start by looking for dungeon>
		variable int Firstdungeon
		; Then we will substring off of that.
		variable string JSONObjectiveString1
		; Then we will look for the first  </a>
		variable int FirstSlashA
		; Pickup and dropoff location stuff
		; First find will be for <td>Pickup Location</td>
		variable int FindPickup
		; Second find will be for <td>Drop-off Location</td>
		variable int FindDropoff
		; Storage for substring
		variable string JSONObjectiveString2
		variable string JSONObjectiveString3
		; Next find will be for double slash again
		variable int SecondSlashSlash
		variable int ThirdSlashSlash
		; Storage for substring
		variable string JSONObjectiveString2B
		variable string JSONObjectiveString3B
		; Now we need to find the > at the end
		variable int SecondAngleBracket
		variable int ThirdAngleBracket
		; Two more temp storages for StationIDs
		variable int64 StationID2
		variable int64 StationID3
		; Onward to the Item Specific Stuff. First up, What will be our marker? Dunno. 
		; First up, find locations for Item and Cargo
		variable int FindItem
		variable int FindCargo
		; Storage for substring
		variable string JSONObjectiveString4
		variable string JSONObjectiveString5
		; Find more of >
		variable int FindPointyThing
		variable int FindPointyThing2
		; Even more substring storage
		variable string JSONObjectiveString4B
		variable string JSONObjectiveString5B		
		; Find the x		
		variable int FindX1
		variable int FindX2
		; Storage for substring
		variable string JSONObjectiveString6
		variable string JSONObjectiveString7
		; Find the )
		variable int FindParenth1
		variable int FindParenth2
		; Storage for substring
		variable string JSONObjectiveString6B
		variable string JSONObjectiveString7B
		; Find the m3
		variable int Findm3A
		variable int Findm3B
		; Our last deal, we need to get the Loyalty Point reward from this garbage fire.
		; Find "Loyalty Points"
		variable int FindLP
		; Storage substring
		variable string JSONObjectiveString8
		; Find the > again
		variable int FindPointyThing3
		; Last storage substring I hope
		variable string JSONObjectiveString8B

		; Lets get the Briefing into its JSONified String
		JSONObjective:Set[${EVEWindow[AgentConversation_${AgentID}].ObjectivesHTML.AsJSON}]
		; Lets get the Objectives into its JSONified String
		JSONBriefing:Set[${EVEWindow[AgentConversation_${AgentID}].BriefingHTML.AsJSON}]
		; Lets get the easy one out of the way, is this declared lowsec.
		if ${JSONBriefing.AsJSON.Find["Low Sec Warning"]} || ${JSONObjective.AsJSON.Find["Low Sec Warning"]} || ${JSONObjective.AsJSON.Find["contains low security"]}
			LastLowsec:Set[TRUE]
		else
			LastLowsec:Set[FALSE]
		
		; Ok next, lets get the Location of the Agent, but from the HTML, instead of looking it up. Dunno why. Just go with it.
		; First we get the location of the first <br><br>, take that location get a substring from it, take that substring and find the first //, this // comes before the station ID. Station ID number ends at a >. Find that >.
		; We will now have a position where the number starts and where it ends.
		FirstBRBR:Set[${JSONBriefing.AsJSON.Find[<br><br>]}]
		JSONBriefingString1:Set[${JSONBriefing.AsJSON.Mid[${FirstBRBR},2000].AsJSON}]
		FirstSlashSlash:Set[${Math.Calc[${JSONBriefingString1.AsJSON.Find[//]} + 2]}]
		JSONBriefingString2:Set[${JSONBriefingString1.AsJSON.Mid[${FirstSlashSlash},2000].AsJSON}]
		FirstAngleBracket:Set[${Math.Calc[${JSONBriefingString2.AsJSON.Find[>]} - 2]}]
		StationID:Set[${JSONBriefingString2.AsJSON.Mid[2,${FirstAngleBracket}].AsJSON}]
		echo StationID ${StationID}
		; Ok so we have a stationID, didn't we want the station name?
		LastAgentLocation:Set[${EVE.Station[${StationID}].Name}]
		; After that, we want the Mission Location. Mission Location is either Where the dungeon is located or where the item pickup/dropoff (whichever is not at your agent's location) is supposed to happen.
		; If we are doing a mission that isn't a courier, the Location will be a system. If it is a courier, it will be a station. Thanks to the wonkiness of courier missions, I have to pull TWO pieces of info here
		; Then we get to use some logic to eliminate one of the locations. 
		; Lets get to work, Mining / Combat missions will have a destination location of a dungeon. So a solar system as far as I care for this. Sidenote, I will not be setting up mining missions unless I get Extremely Bored Yo. They pay like trash garbage.
		; Look for dungeon> after this will be the system name then a </a>.
		if ${MissionType.Find[Encounter]} || ${MissionType.Find[Mining]}
		{
			Firstdungeon:Set[${Math.Calc[${JSONObjective.AsJSON.Find[dungeon>]} + 8]}]
			JSONObjectiveString1:Set[${JSONObjective.AsJSON.Mid[${Firstdungeon},100].AsJSON}]
			FirstSlashA:Set[${Math.Calc[${JSONObjectiveString1.AsJSON.Find[</a>]}-2]}]
			LastMissionLocation:Set[${JSONObjectiveString1.AsJSON.Mid[2,${FirstSlashA}]}]
			echo LML ${LastMissionLocation}
		}
				; Courier mission, The location is whatever location we scrape that isn't the agent's location. I think I am going to have to bite the bullet
		; and parse both the pickup and the dropoff location. I also will need to adjust the tables and crap above. RIP.
		if ${MissionType.Find[Courier]}
		{
			FindPickup:Set[${JSONObjective.AsJSON.Find[<td>Pickup Location</td>]}]
			JSONObjectiveString2:Set[${JSONObjective.AsJSON.Mid[${FindPickup},1000].AsJSON}]
			SecondSlashSlash:Set[${Math.Calc[${JSONObjectiveString2.AsJSON.Find[//]} + 2]}]
			JSONObjectiveString2B:Set[${JSONObjectiveString2.AsJSON.Mid[${SecondSlashSlash},2000].AsJSON}]
			SecondAngleBracket:Set[${Math.Calc[${JSONObjectiveString2B.AsJSON.Find[>]} - 2]}]
			StationID2:Set[${JSONObjectiveString2B.AsJSON.Mid[2,${SecondAngleBracket}]}]
			echo StationID2 ${StationID2}
			
			FindDropoff:Set[${JSONObjective.AsJSON.Find[<td>Drop-off Location</td>]}]
			JSONObjectiveString3:Set[${JSONObjective.AsJSON.Mid[${FindDropoff},1000].AsJSON}]
			ThirdSlashSlash:Set[${Math.Calc[${JSONObjectiveString3.AsJSON.Find[//]} + 2]}]
			JSONObjectiveString3B:Set[${JSONObjectiveString3.AsJSON.Mid[${ThirdSlashSlash},2000].AsJSON}]
			ThirdAngleBracket:Set[${Math.Calc[${JSONObjectiveString3B.AsJSON.Find[>]} - 2]}]
			StationID3:Set[${JSONObjectiveString3B.AsJSON.Mid[2,${ThirdAngleBracket}]}]
			echo StationID3 ${StationID3}
			; And now to make both of those Station IDs into names
			LastPickup:Set[${EVE.Station[${StationID2}].Name}]
			echo LP ${LastPickup}
			LastPickupID:Set[${StationID2}]
			echo LPID ${LastPickupID}
			LastDropoff:Set[${EVE.Station[${StationID3}].Name}]
			echo LD ${LastDropoff}
			LastDropoffID:Set[${StationID3}]
			echo LDID ${LastDropoffID}
		}
		; Trade mission, the location is the agent location, always.
		if ${MissionType.Find[Trade]}
		{
			LastMissionLocation:Set[${EVE.Station[${StationID}].Name}]
			echo LML ${LastMissionLocation}
		}
		; On to Item specifics
		; First up ItemUnits. This is how many units of the Item are expected. As with above, if there is no item, there is no this.
		if ${JSONObjective.AsJSON.Find["these goods:"]}
		{
			if ${JSONObjective.AsJSON.Find[<td>Item</td>]}
			{
				FindItem:Set[${Math.Calc[${JSONObjective.AsJSON.Find[<td>Item</td>]} + 13]}]
				JSONObjectiveString4:Set[${JSONObjective.AsJSON.Mid[${FindItem},1000].AsJSON}]
				FindPointyThing:Set[${Math.Calc[${JSONObjectiveString4.AsJSON.Find[d>]} + 2]}]
				JSONObjectiveString4B:Set[${JSONObjectiveString4.AsJSON.Mid[${FindPointyThing},1000].AsJSON}]
				FindX1:Set[${Math.Calc[${JSONObjectiveString4B.AsJSON.Find[x]} - 2]}]
				LastItemUnits:Set[${JSONObjectiveString4B.AsJSON.Mid[2,${FindX1}].ReplaceSubstring[\,,].Trim.AsJSON}]
				echo LIU ${LastItemUnits}
			}
			elseif ${JSONObjective.AsJSON.Find[<td>Cargo</td>]}
			{
				FindCargo:Set[${Math.Calc[${JSONObjective.AsJSON.Find[<td>Cargo</td>]} + 14]}]
				JSONObjectiveString5:Set[${JSONObjective.AsJSON.Mid[${FindCargo},1000].AsJSON}]
				FindPointyThing2:Set[${Math.Calc[${JSONObjectiveString5.AsJSON.Find[d>]} + 2]}]
				JSONObjectiveString5B:Set[${JSONObjectiveString5.AsJSON.Mid[${FindPointyThing2},1000].AsJSON}]
				FindX2:Set[${Math.Calc[${JSONObjectiveString5B.AsJSON.Find[x]} - 2]}]
				LastItemUnits:Set[${JSONObjectiveString5B.AsJSON.Mid[2,${FindX2}].ReplaceSubstring[\,,].Trim.AsJSON}]
				echo LIU ${LastItemUnits}
			}
			
		}
		else
			LastItemUnits:Set[0]
		; Next up, ExpectedItems. This is going to be the Name of the Item you are picking up. Also, might not be an item involved at all.
		; Ok so building off the last set there where we grabbed what was BEFORE the X, now we will grab what is between the X and the (
		if ${JSONObjective.AsJSON.Find["these goods:"]}
		{
			if ${JSONObjective.AsJSON.Find[<td>Item</td>]}
			{
				JSONObjectiveString6:Set[${JSONObjectiveString4B.AsJSON.Mid[${Math.Calc[${FindX1} + 3]},1000].Trim.AsJSON}]
				FindParenth1:Set[${Math.Calc[${JSONObjectiveString6.AsJSON.Find[\(]} - 2]}]
				LastExpectedItems:Set[${JSONObjectiveString6.AsJSON.Mid[2,${FindParenth1}].Trim.AsJSON}]
				echo LEI ${LastExpectedItems}
				JSONObjectiveString6B:Set[${JSONObjectiveString6.AsJSON.Mid[${Math.Calc[${FindParenth1} + 3]},1000].Trim.AsJSON}]
			}
			elseif ${JSONObjective.AsJSON.Find[<td>Cargo</td>]}
			{
				JSONObjectiveString7:Set[${JSONObjectiveString5B.AsJSON.Mid[${Math.Calc[${FindX2} + 3]},1000].Trim.AsJSON}]
				FindParenth2:Set[${Math.Calc[${JSONObjectiveString7.AsJSON.Find[\(]} - 2]}]
				LastExpectedItems:Set[${JSONObjectiveString7.AsJSON.Mid[2,${FindParenth2}].Trim.AsJSON}]
				echo LEI ${LastExpectedItems}
				JSONObjectiveString7B:Set[${JSONObjectiveString7.AsJSON.Mid[${Math.Calc[${FindParenth2} + 3]},1000].Trim.AsJSON}]
			}			
		}
		else
			LastExpectedItems:Set[""]
		; Next up ItemVolume, which is actually the total volume of all the items. May as well grab it here. If no item, then no this. 
		if ${JSONObjective.AsJSON.Find["these goods:"]}
		{
			if ${JSONObjective.AsJSON.Find[<td>Item</td>]}
			{
				Findm3A:Set[${Math.Calc[${JSONObjectiveString6B.AsJSON.Find[m³]} - 2]}]
				LastItemVolume:Set[${JSONObjectiveString6B.AsJSON.Mid[2,${Findm3A}].Trim.AsJSON}]
				echo LIV ${LastItemVolume}
			}
			elseif ${JSONObjective.AsJSON.Find[<td>Cargo</td>]}
			{
				Findm3B:Set[${Math.Calc[${JSONObjectiveString7B.AsJSON.Find[m³]} - 2]}]
				LastItemVolume:Set[${JSONObjectiveString7B.AsJSON.Mid[2,${Findm3B}].Trim.AsJSON}]
				echo LIV ${LastItemVolume}
			}			
		}
		else
			LastItemVolume:Set[0]
		; Final goddamn thing, we need to parse the LP reward for this mission.
		if ${JSONObjective.AsJSON.Find["Loyalty Points"]}
		{
			FindLP:Set[${Math.Calc[${JSONObjective.AsJSON.Find["Loyalty Points"]} - 10]}]
			JSONObjectiveString8:Set[${JSONObjective.AsJSON.Mid[${FindLP},10].AsJSON}]
			FindPointyThing3:Set[${Math.Calc[${JSONObjectiveString8.AsJSON.Find[2>]} + 2]}]
			JSONObjectiveString8B:Set[${JSONObjectiveString8.AsJSON.Mid[${FindPointyThing3},10].AsJSON}]
			LastLPReward:Set[${JSONObjectiveString8B.ReplaceSubstring[\",].ReplaceSubstring[\,,].Trim}]
			echo Last LP ${LastLPReward}
		
		}
		else
			LastLPReward:Set[0]
		This:InsertState["Databasification", 2000, "${ReturnIterator}, FALSE, TRUE"]
		return TRUE
	}
	; This method will be for clearing all Current Agent information when we are done.
	method ClearCurrentAgentVariables()
	{
		CurrentAgentID:Set[0]
		CurrentAgentIndex:Set[0]
		CurrentAgentLocation:Set[0]
		CurrentAgentShip:Set[""]
		CurrentAgentItem:Set[""]
		CurrentAgentItemUnits:Set[0]
		CurrentAgentVolumePer:Set[0]
		CurrentAgentVolumeTotal:Set[0]
		CurrentAgentPickup:Set[""]
		CurrentAgentPickupID:Set[0]
		CurrentAgentDropoff:Set[""]
		CurrentAgentDropoffID:Set[0]
		CurrentAgentDamage:Set[""]
		CurrentAgentDestroy:Set[""]
		CurrentAgentLoot:Set[""]
		CurrentAgentMissionName:Set[""]
		CurrentAgentMissionType:Set[""]
		CurrentAgentLPReward:Set[0]
	}
	; This method will be used to databasify NPCs in a mission room, or when new NPCs appear during a mission.
	;	 RoomNPCInfoInsert(int64 EntityID, int RunNumber, int RoomNumber, string NPCName, string NPCGroup, int64 NPCBounty)
	; ADDENDUM, this has to be a state, this can take a very long time (in computer script time) so lets just stop those collisions ahead of time eh?
	;method DatabasifyNPCs()
	member:bool DatabasifyNPCs()
	{
		
		variable iterator DBNPC
		; Lets just use TargetList to make this easier.
		DatabasifyNPC:RequestUpdate
		if ${DatabasifyNPC.TargetList.Used} > 0
		{
			DatabasifyNPC.TargetList:GetIterator[DBNPC]
			if ${DBNPC:First(exists)}
			{
				do
				{	
					; Going to try breaking this up into chunks by only processing things we currently have locked?
					; ADDENDUM - No longer required.
					;if ${Entity[${DBNPC.Value}].IsLockedTarget}
					;{
					;	echo DEBUG - Unlocked Target, Skipping
					;	continue
					;}
					; We're assuming entity IDs never ever get recycled Storing this for later ---> AND RoomNumber=${CurrentRunRoomNumber} AND RunNumber=${CurrentRunNumber}
					GetRoomNPCInfo:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM RoomNPCInfo WHERE EntityID=${DBNPC.Value};"]}]
					echo DEBUG ELEVENTH QUERY
					if ${GetRoomNPCInfo.NumRows} == 0
					{
						This:RoomNPCInfoInsert[${DBNPC.Value},${CurrentRunNumber},${CurrentRunRoomNumber},${Entity[${DBNPC.Value}].Name.ReplaceSubstring[','']},${Entity[${DBNPC.Value}].Group.ReplaceSubstring[','']},${Entity[${DBNPC.Value}].Bounty}]
						echo DATABASIFY NPCS ${DBNPC.Value},${CurrentRunNumber},${CurrentRunRoomNumber},${Entity[${DBNPC.Value}].Name.ReplaceSubstring[','']},${Entity[${DBNPC.Value}].Group.ReplaceSubstring[','']},${Entity[${DBNPC.Value}].Bounty}
						GetRoomNPCInfo:Finalize
					}
					else
						echo DEBUG - ALREADY IN DB
						GetRoomNPCInfo:Finalize
				}
				while ${DBNPC:Next(exists)}
			}
			;CharacterSQLDB:ExecDMLTransaction[NPCDBDML]
			NPCDBML:Clear
			echo DEBUG - DBNPC
		}
		; Only run this every 20 seconds.
		LastNPCDatabasification:Set[${Math.Calc[${LavishScript.RunningTime} + 20000]}]
		return TRUE
	}
	; This method will be to help us generate appropriate Status Reports for WatchDogMonitoring
	;	WatchDogMonitoringUpsert(int64 CharID, int RunNumber, string MissionName, string MissionType, int RoomNumber, int TripNumber, int64 TimeStamp, int64 CurrentTarget, string CurrentDestination, int UnitsMoved)	
	method UpdateWatchDog()
	{
		variable int64 CT
		variable int64 CD
		variable index:int WaypointIndex
		EVE:GetWaypoints[WaypointIndex]
		
		if ${Client.InSpace}
		{
			if ${Entity[IsActiveTarget = TRUE](exists)}
				CT:Set[${Entity[IsActiveTarget = TRUE]}]
			else
				CT:Set[-1]
		}
		else
			CT:Set[-1]
			
		if ${WaypointIndex.Get[1]} != NULL
			CD:Set[${WaypointIndex.Get[1]}]
		else
			CD:Set[-1]

		This:WatchDogMonitoringUpsert[${Me.CharID},${CurrentRunNumber},${CurrentAgentMissionName.ReplaceSubstring[','']},${CurrentAgentMissionType.ReplaceSubstring[','']},${CurrentRunRoomNumber},${CurrentRunTripNumber},${Time.Timestamp},${CT},${CD},${CurrentRunItemUnitsMoved}]
	
	}
	; This method will help us generate an appropriate Missioneer Stats entry.
	;	MissioneerStatsInsert(int64 Timestamp, string CharName, int64 CharID, int RunNumber, int RoomNumber, int TripNumber, string MissionName, string MissionType, string EventType, int64 RoomBounties, bool RoomFactionSpawn, int64 RoomDuration,
	;		 					int RunLP, int64 RunISK, int64 RunDuration, int64 RunTotalBounties, string ShipType)
	method UpdateMissioneerStats(string EventType)
	{
		; ISK, LP, Total Duration, Total Bounties
		variable int64 	CRISK = 0
		variable int 	CRLP = 0
		variable int64 	CRTD = 0
		variable int64	CRTB = 0
		
		variable string ST
		if ${Client.InSpace}
			ST:Set[${MyShip.ToEntity.Type}]
		else
			ST:Set[${MyShip.ToItem.Type}]
		
		; So we don't record the mission ISK/LP reward over and over and over and over. We will record this only on mission completion I guess.
		echo DEBUG - UPDATEMISSIONEER STATS ${CurrentAgentLPReward} ${This.RunDuration} ${This.TotalBounties}
		if ${EventType.Equal[RunComplete]}
		{
			CRISK:Set[${This.RunISK}]
			CRLP:Set[${CurrentAgentLPReward}]
			CRTD:Set[${This.RunDuration}]
			CRTB:Set[${This.TotalBounties}]
		}
		echo DEBUG - UPDATE MISSIONEER STATS ${Time.Timestamp},${Me.Name.ReplaceSubstring[','']},${Me.CharID},${CurrentRunNumber},${CurrentRunRoomNumber},${CurrentRunTripNumber},${CurrentAgentMissionName.ReplaceSubstring[','']},${CurrentAgentMissionType.ReplaceSubstring[','']},${EventType},${This.RoomBounties},${This.RoomFactionSpawn},${This.RoomDuration},${CRISK},${CRLP},${CRTD},${CRTB},${ST.ReplaceSubstring[','']}
		This:MissioneerStatsInsert[${Time.Timestamp},${Me.Name.ReplaceSubstring[','']},${Me.CharID},${CurrentRunNumber},${CurrentRunRoomNumber},${CurrentRunTripNumber},${CurrentAgentMissionName.ReplaceSubstring[','']},${CurrentAgentMissionType.ReplaceSubstring[','']},${EventType},${This.RoomBounties},${This.RoomFactionSpawn},${This.RoomDuration},${CRISK},${CRLP},${CRTD},${CRTB},${ST.ReplaceSubstring[','']}]
	}
	; These members will be for the MissionerStatsInsert, just to make getting the information simpler.
	; First member will be for tallying up the total Bounties in a mission room/area. This will return a Float.
	; HMMM, I forgot something, some rooms the enemies show up in waves. This is gonna get rather complicated.
	member:int64 RoomBounties()
	{
		variable int64 bounties
		; No bounties in the station, yo.
		if ${Me.InStation}
			return 0
			
		GetRoomNPCInfo:Set[${CharacterSQLDB.ExecQuery["SELECT Total(NPCBounty) FROM RoomNPCInfo WHERE RunNumber=${CurrentRunNumber} AND RoomNumber=${CurrentRunRoomNumber};"]}]
		echo DEBUG TWELFTH QUERY
		if ${GetRoomNPCInfo.NumRows} > 0
		{
			echo DEBUG - ROOM BOUNTIES ${GetRoomNPCInfo.GetFieldValue["Total(NPCBounty)",int64]}
			bounties:Set[${GetRoomNPCInfo.GetFieldValue["Total(NPCBounty)",int64]}]
			GetRoomNPCInfo:Finalize
			return ${bounties}
		}
		else
		{	
			echo DEBUG - NO BOUNTIES?
			return 0
		}
	}
	; Second member will be for identifying whether there has been a faction spawn or not. Going to limit these to faction spawns that are cruiser or larger. A few missions
	; have things that are technically faction spawns but literally never have anything good, and those are generally frigates. This will return a bool.
	member:bool RoomFactionSpawn()
	{
		GetRoomNPCInfo:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM RoomNPCInfo WHERE (RunNumber=${CurrentRunNumber} AND RoomNumber=${CurrentRunRoomNumber}) AND (NPCGroup LIKE '%Commander Cruiser%' OR NPCGroup LIKE '%Commander Battlecruiser%' OR NPCGroup LIKE '%Commander Battleship%');"]}]
		echo DEBUG THIRTEENTH QUERY
		if ${GetRoomNPCInfo.NumRows} > 0
		{
			GetRoomNPCInfo:Finalize
			return TRUE
		}
		else
			return FALSE

	}
	; Third member will be for how long the current room has lasted. This will return a number of milliseconds as an int64.
	member:int64 RoomDuration()
	{
		; I technically could restore this variable from DB information but meh.
		if ${CurrentRoomStartTime} == 0
			return 0
		else
			return ${Math.Calc[${CurrentRoomEndTime}-${CurrentRoomStartTime}]}
	}
	; Fourth member will be for getting the ISK reward for doing this mission. Reward + bonus. Returns a int64.
	; This will also include parsing HTML so fuckin kill me now.
	; Addendum, we can do this without parsing. Record wallet balance just before mission completion and then again just after. Boom, isk difference was the mission reward, probably.
	member:int64 RunISK()
	{
		return ${Math.Calc[${ISKAfterCompletion}-${ISKBeforeCompletion}]}
	}
	; Fifth and final member in this area will be for returning how long the entire run has taken, beginning to end. Returns milliseconds as an int64.
	member:int64 RunDuration()
	{
		echo DEBUG - RUN DURATION ${Time.Timestamp} - ${CurrentRunStartTimestamp}
		; This shouldn't come up, because this variable IS restored from DB.
		if ${CurrentRunStartTimestamp} == 0
			return 0
		else
			return ${Math.Calc[${Time.Timestamp} - ${CurrentRunStartTimestamp}]}		
	
	}
	; Sixth and actual final member in this area will be for the total bounties for the entire run.
	member:int64 TotalBounties()
	{
		variable int64 bounties
		GetRoomNPCInfo:Set[${CharacterSQLDB.ExecQuery["SELECT Total(NPCBounty) FROM RoomNPCInfo WHERE RunNumber=${CurrentRunNumber};"]}]
		echo DEBUG FOURTEENTH QUERY
		if ${GetRoomNPCInfo.NumRows} > 0
		{
			bounties:Set[${GetRoomNPCInfo.GetFieldValue["Total(NPCBounty)",int64]}]
			echo DEBUG - MISSION TOTAL BOUNTIES ${bounties}
			GetRoomNPCInfo:Finalize
			return ${bounties}
		}
		else
			return 0	
	}
	; This method is going to be my second attempt at making it apparent to the Salvagers that there are Salvage BMs available to be salvaged.
	method BackupSalvageBMTableMethod()
	{
		variable index:bookmark BookmarkIndex
		variable iterator BookmarkIterator
		
		EVE:GetBookmarks[BookmarkIndex]
		;BookmarkIndex:RemoveByQuery[${LavishScript.CreateQuery[Label =- "${Config.SalvagePrefix}"]}, TRUE]
		echo ${BookmarkIndex.Used} TOTAL BMS FOUND
		BookmarkIndex:GetIterator[BookmarkIterator]
		if ${BookmarkIterator:First(exists)}
		{
			do
			{
				if ${BookmarkIterator.Value.Label.Find["${Config.SalvagePrefix}"]}
				{
					This:SalvageBMTableInsert[${BookmarkIterator.Value.ID},${BookmarkIterator.Value.Label.ReplaceSubstring[','']},69,${Universe[${BookmarkIterator.Value.SolarSystemID}].Name.ReplaceSubstring[','']},${Math.Calc[${BookmarkIterator.Value.Created.AsInt64} + 71000000000]},0,0,0}]
					if ${Config.ExtremelySharedDBPath.NotNULLOrEmpty} && ${Config.ExtremelySharedDBPrefix.NotNULLOrEmpty}
					{
						This:NetworkSalvageBMTableInsert[${BookmarkIterator.Value.ID},${BookmarkIterator.Value.Label.ReplaceSubstring[','']},69,${Universe[${BookmarkIterator.Value.SolarSystemID}].Name.ReplaceSubstring[','']},${Math.Calc[${BookmarkIterator.Value.Created.AsInt64} + 71000000000]},0,0,0}]
					}
					echo ${BookmarkIterator.Value.ID},${BookmarkIterator.Value.Label.ReplaceSubstring[','']},69,${Universe[${BookmarkIterator.Value.SolarSystemID}].Name.ReplaceSubstring[','']},${Math.Calc[${BookmarkIterator.Value.Created.AsInt64} + 71000000000]}
				}
			}
			while ${BookmarkIterator:Next(exists)}
		}
	}
	; This method will be for resolving our damage type. So we know what ammo and drones to load for a combat mission.
	method ResolveDamageType(string DmgType)
	{
		switch ${damageType}
		{
			case kinetic
				ammo:Set[${Config.KineticAmmo}]
				if ${Config.UseSecondaryAmmo}
					secondaryAmmo:Set[${Config.KineticAmmoSecondary}]
				else
					secondaryAmmo:Set[""]
				useDroneRace:Set[DRONE_RACE_CALDARI]
				break
			case em
				ammo:Set[${Config.EMAmmo}]
				if ${Config.UseSecondaryAmmo}
					secondaryAmmo:Set[${Config.EMAmmoSecondary}]
				else
					secondaryAmmo:Set[""]
				useDroneRace:Set[DRONE_RACE_AMARR]
				break
			case thermal
				ammo:Set[${Config.ThermalAmmo}]
				if ${Config.UseSecondaryAmmo}
					secondaryAmmo:Set[${Config.ThermalAmmoSecondary}]
				else
					secondaryAmmo:Set[""]
				useDroneRace:Set[DRONE_RACE_GALLENTE]
				break
			case explosive
				ammo:Set[${Config.ExplosiveAmmo}]
				if ${Config.UseSecondaryAmmo}
					secondaryAmmo:Set[${Config.ExplosiveAmmoSecondary}]
				else
					secondaryAmmo:Set[""]
				useDroneRace:Set[DRONE_RACE_MINMATAR]
				break
			default
				ammo:Set[${Config.KineticAmmo}]
				if ${Config.UseSecondaryAmmo}
					secondaryAmmo:Set[${Config.KineticAmmoSecondary}]
				else
					secondaryAmmo:Set[""]
				break
		}
		Ship.ModuleList_Weapon:ConfigureAmmo[${ammo}, ${secondaryAmmo}]	
	}
	; This method will be for a Mid-Run Information Recovery. Client crashed / you disconnected / etc. This will be called to set the CurrentRun and CurrentAgent variables from values stored in the DBs
	method MidRunRecovery(string Case)
	{
		if ${Case.Equal[Combat]}
		{
			GetMissionLogCombined:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionLogCombat WHERE Historical=FALSE;"]}]
			echo DEBUG FIFTEENTH QUERY
		}
		if ${Case.Equal[Noncombat]}
		{
			GetMissionLogCombined:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionLogCourier WHERE Historical=FALSE;"]}]
			echo DEBUG SIXTEENTH QUERY
		}
		; Pulling our current (run) variables back out. There is no way for this to not return a row, or we wouldn't have gotten here.
		if ${GetMissionLogCombined.NumRows} > 0 && ${Case.Equal[Combat]}
		{
			CurrentRunNumber:Set[${GetMissionLogCombined.GetFieldValue["RunNumber",int]}]
			CurrentRunRoomNumber:Set[${GetMissionLogCombined.GetFieldValue["RoomNumber",int]}]
			CurrentRunStartTimestamp:Set[${GetMissionLogCombined.GetFieldValue["StartingTimestamp",int64]}]
			CurrentRunKilledTarget:Set[${GetMissionLogCombined.GetFieldValue["KilledTarget",bool]}]
			CurrentRunVanquisher:Set[${GetMissionLogCombined.GetFieldValue["Vanquisher",bool]}]
			CurrentRunContainerLooted:Set[${GetMissionLogCombined.GetFieldValue["ContainerLooted",bool]}]
			CurrentRunHaveItems:Set[${GetMissionLogCombined.GetFieldValue["HaveItems",bool]}]
			CurrentRunTechnicalComplete:Set[${GetMissionLogCombined.GetFieldValue["TechnicalCompletion",bool]}]
			CurrentRunTrueComplete:Set[${GetMissionLogCombined.GetFieldValue["TrueCompletion",bool]}]
		}
		if ${GetMissionLogCombined.NumRows} > 0 && ${Case.Equal[Noncombat]}
		{
			CurrentRunNumber:Set[${GetMissionLogCombined.GetFieldValue["RunNumber",int]}]
			CurrentRunStartTimestamp:Set[${GetMissionLogCombined.GetFieldValue["StartingTimestamp",int64]}]
			CurrentRunTripNumber:Set[${GetMissionLogCombined.GetFieldValue["TripNumber",int]}]
			CurrentRunExpectedTrips:Set[${GetMissionLogCombined.GetFieldValue["ExpectedTrips",int]}]
			CurrentRunItemUnitsMoved:Set[${GetMissionLogCombined.GetFieldValue["UnitsMoved",int]}]
			CurrentRunVolumeMoved:Set[${GetMissionLogCombined.GetFieldValue["VolumeMoved",int64]}]
		}			
		; Presumably you will only have one active mission at a time. But lets make sure the mission names are the same.
		GetDBJournalInfo:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal WHERE MissionStatus=2 AND MissionName='${GetMissionLogCombined.GetFieldValue["MissionName",string].ReplaceSubstring[','']}';"]}]
		echo DEBUG SEVENTEENTH QUERY
		if ${GetDBJournalInfo.NumRows} > 0
		{
			; Pulling our current (agent) variables back out.
			if ${GetDBJournalInfo.GetFieldValue["MissionLPReward",int]} > 0
				CurrentAgentLPReward:Set[${GetDBJournalInfo.GetFieldValue["MissionLPReward",int]}]
			if ${GetDBJournalInfo.GetFieldValue["ExpectedItems",string].NotNULLOrEmpty}
				CurrentAgentItem:Set[${GetDBJournalInfo.GetFieldValue["ExpectedItems",string]}]
			if ${GetDBJournalInfo.GetFieldValue["ItemUnits",int]} >= 1
				CurrentAgentItemUnits:Set[${GetDBJournalInfo.GetFieldValue["ItemUnits",int]}]
			if ${GetDBJournalInfo.GetFieldValue["VolumePer",int64]} > 0
				CurrentAgentVolumePer:Set[${GetDBJournalInfo.GetFieldValue["VolumePer",int64]}]
			if ${GetDBJournalInfo.GetFieldValue["ItemVolume",int64]} > 0
				CurrentAgentVolumeTotal:Set[${GetDBJournalInfo.GetFieldValue["ItemVolume",int64]}]		
			if ${GetDBJournalInfo.GetFieldValue["PickupLocation",string].NotNULLOrEmpty}
				CurrentAgentPickup:Set[${GetDBJournalInfo.GetFieldValue["PickupLocation",string]}]
			if ${GetDBJournalInfo.GetFieldValue["PickupLocationID",int64]}
				CurrentAgentPickupID:Set[${GetDBJournalInfo.GetFieldValue["PickupLocationID",int64]}]				
			if ${GetDBJournalInfo.GetFieldValue["DropoffLocation",string].NotNULLOrEmpty}
				CurrentAgentDropoff:Set[${GetDBJournalInfo.GetFieldValue["DropoffLocation",string]}]
			if ${GetDBJournalInfo.GetFieldValue["DropoffLocationID",int64]}
				CurrentAgentDropoffID:Set[${GetDBJournalInfo.GetFieldValue["DropoffLocationID",int64]}]				
			if ${GetDBJournalInfo.GetFieldValue["Damage2Deal",string].NotNULLOrEmpty}
				CurrentAgentDamage:Set[${GetDBJournalInfo.GetFieldValue["Damage2Deal",string]}]
			if ${GetDBJournalInfo.GetFieldValue["DestroyTarget",string].NotNULLOrEmpty}
				CurrentAgentDestroy:Set[${GetDBJournalInfo.GetFieldValue["DestroyTarget",string]}]
			if ${GetDBJournalInfo.GetFieldValue["LootTarget",string].NotNULLOrEmpty}
				CurrentAgentLoot:Set[${GetDBJournalInfo.GetFieldValue["LootTarget",string]}]		
			CurrentAgentID:Set[${GetDBJournalInfo.GetFieldValue["AgentID",int64]}]
			CurrentAgentLocation:Set[${GetDBJournalInfo.GetFieldValue["AgentLocation",string]}]
			CurrentAgentIndex:Set[${EVE.Agent[id,${CurrentAgentID}].Index}]
			CurrentAgentMissionName:Set[${GetDBJournalInfo.GetFieldValue["MissionName",string]}]
			CurrentAgentMissionType:Set[${GetDBJournalInfo.GetFieldValue["MissionType",string]}]
		}
		GetMissionLogCombined:Finalize	
		GetDBJournalInfo:Finalize
		echo DEBUG - DID WE COMPLETE THE MRR?
		MissionParser.AgentName:Set[${EVE.Agent[${CurrentAgentIndex}].Name}]
		This:ResolveDamageType[${CurrentAgentDamage.Lower}]
		echo AMMO TYPES ${ammo} ${secondaryAmmo}
		return TRUE
	}
	; This method will Set/Reset our Current Run information (the crap that goes into the mission log db entries). Initial entry basically.
	method SetCurrentRunDetails(int64 OurCapacity, int64 TotalVolume)
	{
		CurrentRunNumber:Set[${Config.RunNumberInt}]
		CurrentRunRoomNumber:Set[1]
		CurrentRunStartTimestamp:Set[${Time.Timestamp}]
		CurrentRunKilledTarget:Set[FALSE]
		CurrentRunVanquisher:Set[FALSE]
		CurrentRunContainerLooted:Set[FALSE]
		CurrentRunHaveItems:Set[FALSE]
		CurrentRunTechnicalComplete:Set[FALSE]
		CurrentRunTrueComplete:Set[FALSE]
		CurrentRunFinalTimestamp:Set[0]
		CurrentRunTripNumber:Set[0]
		if ${OurCapacity} > 0
			CurrentRunExpectedTrips:Set[${Math.Calc[${TotalVolume}/${OurCapacity}].Ceil}]
		else
			CurrentRunExpectedTrips:Set[-1]
		CurrentRunItemUnitsMoved:Set[0]
		CurrentRunVolumeMoved:Set[0]
	}
	; This method will be for gathering some details about our current Hauler ship. What kind of bays does it have, how much can it carry. 
	; ADDENDUM - Have to make this into a state because goddamn.
	member:bool GetHaulerDetails()
	{	
		variable int64 TempStorage1
		echo DEBUG BEGIN HAULERDETAILS
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipCargo"](exists)} && !${ShipCargoChecked}
		{
			EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipCargo"]:MakeActive
			ShipCargoChecked:Set[TRUE]
			echo DEBUG GHD1
			This:InsertState["GetHaulerDetails",${Math.Calc[(4000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
			
		}
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipCargo"].Capacity} < 0 && ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipCargo"](exists)}
		{
			echo DEBUG GHD2
			This:InsertState["GetHaulerDetails",${Math.Calc[(4000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
		}
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipCargo"].Capacity} > 0 && ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipCargo"](exists)}
		{
			HaulerLargestBayCapacity:Set[${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipCargo"].Capacity}]
			TempStorage1:Set[${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipCargo"].Capacity}]
			HaulerLargestBayType:Set["ShipCargo"]
			HaulerLargestBayLocationFlag:Set[${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipCargo"].LocationFlag}]
			HaulerLargestBayOreLimited:Set[FALSE]
		}
		else
		{
			; Something went wrong here
		}	
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipFleetHangar"](exists)} && !${ShipFleetHangarChecked}
		{
			EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipFleetHangar"]:MakeActive
			ShipFleetHangarChecked:Set[TRUE]
			echo DEBUG GHD4
			This:InsertState["GetHaulerDetails",${Math.Calc[(4000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
		}
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipFleetHangar"].Capacity} < 0 && ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipFleetHangar"](exists)}
		{
			echo DEBUG GHD5
			This:InsertState["GetHaulerDetails",${Math.Calc[(4000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
		}
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipFleetHangar"].Capacity} > 0 && ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipFleetHangar"](exists)}
		{
			HaulerLargestBayCapacity:Set[${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipFleetHangar"].Capacity}]
			TempStorage1:Set[${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipFleetHangar"].Capacity}]
			HaulerLargestBayType:Set["ShipFleetHangar"]
			;HaulerLargestBayLocationFlag:Set[${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipFleetHangar"].LocationFlag}]
			HaulerLargestBayLocationFlag:Set["FleetHold"]
			HaulerLargestBayOreLimited:Set[FALSE]
			echo DEBUG GHD6
		}
		else
		{
			; Something went wrong here
		}
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipGeneralMiningHold"](exists)} && !${ShipOreBayChecked}
		{
			EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipGeneralMiningHold"]:MakeActive
			ShipOreBayChecked:Set[TRUE]
			echo DEBUG GHD7
			This:InsertState["GetHaulerDetails",${Math.Calc[(4000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
		}
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipGeneralMiningHold"].Capacity} < 0 && ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipGeneralMiningHold"](exists)}
		{
			echo DEBUG GHD8
			This:InsertState["GetHaulerDetails",${Math.Calc[(4000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
		}
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipGeneralMiningHold"].Capacity} > ${HaulerLargestBayCapacity} && ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipGeneralMiningHold"](exists)}
		{
			HaulerLargestBayCapacity:Set[${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipGeneralMiningHold"].Capacity}]
			HaulerLargestBayType:Set["ShipGeneralMiningHold"]
			;HaulerLargestBayLocationFlag:Set[${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipGeneralMiningHold"].LocationFlag}]
			HaulerLargestBayLocationFlag:Set["OreHold"]
			HaulerLargestBayOreLimited:Set[TRUE]
			echo DEBUG GHD8
		}
		else
		{
			; Something went wrong here
		}
		ShipCargoChecked:Set[FALSE]
		ShipFleetHangarChecked:Set[FALSE]
		ShipOreBayChecked:Set[FALSE]
		return TRUE
		; Now that I think about it, is there even a situation where the normal cargo hold will be larger than the fleet hangar or the ore bay if a ship has either one of those???
	}
	; This member will return the ID of the destination bookmark for our courier mission
	member:int64 CourierMissionDestination()
	{
		variable index:agentmission missions
		variable iterator missionIterator	
		EVE:GetAgentMissions[missions]
		missions:GetIterator[missionIterator]
		echo CMD BEGIN
		if ${missionIterator:First(exists)}
		{
			do
			{	
				if ${missionIterator.Value.AgentID} != ${CurrentAgentID}
				{
					continue
				}	
				
				variable index:bookmark missionBookmarks
				variable iterator bookmarkIterator
				missionIterator.Value:GetBookmarks[missionBookmarks]
				missionBookmarks:GetIterator[bookmarkIterator]
				if ${bookmarkIterator:First(exists)}
				{
					do
					{
						if ${bookmarkIterator.Value.Label.Find["Objective (Drop Off)"]} && ${CourierMissionTravelState.Equal[Dropoff]}
						{
							echo DEBUG CMD ${bookmarkIterator.Value.ID}
							return "${bookmarkIterator.Value.ID}"
						}
						if ${bookmarkIterator.Value.Label.Find["Objective (Pick Up)"]} && ${CourierMissionTravelState.Equal[Pickup]}
						{
							echo DEBUG CMD ${bookmarkIterator.Value.ID}
							return "${bookmarkIterator.Value.ID}"
						}
					}
					while ${bookmarkIterator:Next(exists)}
				}	
			}
			while ${missionIterator:Next(exists)}
		}
	}
	; This method will be for inserting information into the MissionJournal table. This will naturally be an Upsert.
	; (AgentID INTEGER PRIMARY KEY, MissionName TEXT, MissionType TEXT, MissionStatus INTEGER, AgentLocation TEXT, MissionLocation TEXT, DropoffLocation TEXT, DropoffLocationID INTEGER, PickupLocation TEXT, PickupLocationID INTEGER, Lowsec BOOLEAN, JumpDistance INTEGER, ExpectedItems TEXT, ItemUnits INTEGER, ItemVolume INTEGER, MissionLPReward int
	;   VolumePer INTEGER, DestroyTarget TEXT, LootTarget TEXT, Damage2Deal TEXT);"]
	method MissionJournalUpsert(int64 AgentID, string MissionName, string MissionType, int MissionStatus, string AgentLocation, string MissionLocation, string DropoffLocation, int64 DropoffLocationID, string PickupLocation, int64 PickupLocationID, bool Lowsec, int JumpDistance, string ExpectedItems, int ItemUnits, int64 ItemVolume, int MissionLPReward, int64 VolumePer, string DestroyTarget, string LootTarget, string Damage2Deal)
	{	
		;variable index:string MJUDML
		;MJUDML:Insert
		CharacterSQLDB:ExecDML["insert into MissionJournal (AgentID,MissionName,MissionType,MissionStatus,AgentLocation,MissionLocation,DropoffLocation,DropoffLocationID,PickupLocation,PickupLocationID,Lowsec,JumpDistance,ExpectedItems,ItemUnits,ItemVolume,MissionLPReward,VolumePer,DestroyTarget,LootTarget,Damage2Deal) values (${AgentID}, '${MissionName}', '${MissionType}', ${MissionStatus}, '${AgentLocation}', '${MissionLocation}', '${DropoffLocation}', ${DropoffLocationID}, '${PickupLocation}', ${PickupLocationID}, ${Lowsec}, ${JumpDistance}, '${ExpectedItems}', ${ItemUnits}, ${ItemVolume}, ${MissionLPReward}, ${VolumePer}, '${DestroyTarget}', '${LootTarget}','${Damage2Deal}') ON CONFLICT (AgentID) DO UPDATE SET MissionName=excluded.MissionName, MissionType=excluded.MissionType, MissionStatus=excluded.MissionStatus, AgentLocation=excluded.AgentLocation, MissionLocation=excluded.MissionLocation, DropoffLocation=excluded.DropoffLocation, DropoffLocationID=excluded.DropoffLocationID, PickupLocation=excluded.PickupLocation, PickupLocationID=excluded.PickupLocationID, Lowsec=excluded.Lowsec, Jumpdistance=excluded.JumpDistance, ExpectedItems=excluded.ExpectedItems, ItemUnits=excluded.ItemUnits, ItemVolume=excluded.ItemVolume, MissionLPReward=excluded.MissionLPReward, VolumePer=excluded.VolumePer, DestroyTarget=excluded.DestroyTarget, LootTarget=excluded.LootTarget, Damage2Deal=excluded.Damage2Deal;"]
		;Transaction[MJUDML]
		echo ${AgentID}, '${MissionName}', '${MissionType}', ${MissionStatus}, '${AgentLocation}', '${MissionLocation}', '${DropoffLocation}', ${DropoffLocationID}, '${PickupLocation}', ${PickupLocationID}, ${Lowsec}, ${JumpDistance}, '${ExpectedItems}', ${ItemUnits}, ${ItemVolume}, ${MissionLPReward}, ${VolumePer}, '${LootTarget}', '${DestroyTarget}','${Damage2Deal}
	}
	; Need to update MissionJournal when we accept a mission or things break.
	method MissionJournalUpdateStatus(int64 AgentID, int MissionStatus)
	{
		CharacterSQLDB:ExecDML["update MissionJournal SET MissionStatus=${MissionStatus} WHERE AgentID=${AgentID};"]
	}
	; This method will be for inserting information into the MissionLogCombat table. This will also be an upsert.
	; (RunNumber INTEGER PRIMARY KEY, StartingTimestamp INTEGER, MissionName TEXT, MissionType TEXT, RoomNumber INTEGER, KilledTarget BOOLEAN, Vanquisher BOOLEAN, ContainerLooted BOOLEAN, HaveItems BOOLEAN, TechnicalCompletion BOOLEAN, 
	;   TrueCompletion BOOLEAN, FinalTimestamp INTEGER, Historical BOOLEAN);"]
	method MissionLogCombatUpsert(int RunNumber, int64 StartingTimestamp, string MissionName, string MissionType, int RoomNumber, bool KilledTarget, bool Vanquisher, bool ContainerLooted, bool HaveItems, bool TechnicalCompletion, bool TrueCompletion, int64 FinalTimestamp, int Historical)
	{
		CharacterSQLDB:ExecDML["insert into MissionLogCombat (RunNumber,StartingTimestamp,MissionName,MissionType,RoomNumber,KilledTarget,Vanquisher,ContainerLooted,HaveItems,TechnicalCompletion,TrueCompletion,FinalTimestamp,Historical) values (${RunNumber},${StartingTimestamp},'${MissionName}','${MissionType}',${RoomNumber},${KilledTarget},${Vanquisher},${ContainerLooted},${HaveItems},${TechnicalCompletion},${TrueCompletion},${FinalTimestamp},${Historical}) ON CONFLICT (RunNumber) DO UPDATE SET StartingTimestamp=excluded.StartingTimestamp, MissionName=excluded.MissionName, MissionType=excluded.MissionType, RoomNumber=excluded.RoomNumber, KilledTarget=excluded.KilledTarget, Vanquisher=excluded.Vanquisher, ContainerLooted=excluded.ContainerLooted, HaveItems=excluded.HaveItems, TechnicalCompletion=excluded.TechnicalCompletion, TrueCompletion=excluded.TrueCompletion, FinalTimestamp=excluded.FinalTimestamp, Historical=excluded.Historical;"]
	}
	; This method will be for Mid-Combat-Mission Updates
	method MissionLogCombatUpdate(int RunNumber, int RoomNumber, bool KilledTarget, bool Vanquisher, bool ContainerLooted, bool HaveItems, bool TechnicalCompletion, bool TrueCompletion, int64 FinalTimestamp, int Historical)
	{
		CharacterSQLDB:ExecDML["update MissionLogCombat SET RoomNumber=${RoomNumber}, KilledTarget=${KilledTarget}, Vanquisher=${Vanquisher}, ContainerLooted=${ContainerLooted}, HaveItems=${HaveItems}, TechnicalCompletion=${TechnicalCompletion}, TrueCompletion=${TrueCompletion}, FinalTimestamp=${FinalTimestamp}, Historical=${Historical} WHERE RunNumber=${CurrentRunNumber};"]
	}
	; This method will be for inserting information into the MissionLogCourier table. This will also be an upsert.
	; (RunNumber INTEGER PRIMARY KEY, StartingTimestamp INTEGER, MissionName TEXT, MissionType TEXT, TripNumber INTEGER, ExpectedTrips INTEGER,
	;  DropoffLocation TEXT, PickupLocation TEXT, TotalUnits INTEGER, TotalVolume INTEGER, UnitsMoved INTEGER, VolumeMoved INTEGER, FinalTimestamp INTEGER, Historical BOOLEAN);"]
	method MissionLogCourierUpsert(int RunNumber, int64 StartingTimestamp, string MissionName, string MissionType, int TripNumber, int ExpectedTrips, string DropoffLocation, string PickupLocation, int TotalUnits, int64 TotalVolume, int UnitsMoved, int64 VolumeMoved, int64 FinalTimestamp, int Historical)
	{
		CharacterSQLDB:ExecDML["insert into MissionLogCourier (RunNumber,StartingTimestamp,MissionName,MissionType,TripNumber,ExpectedTrips,DropoffLocation,PickupLocation,TotalUnits,TotalVolume,UnitsMoved,VolumeMoved,FinalTimestamp,Historical) values (${RunNumber},${StartingTimestamp},'${MissionName}','${MissionType}',${TripNumber},${ExpectedTrips},'${DropoffLocation}','${PickupLocation}',${TotalUnits},${TotalVolume},${UnitsMoved},${VolumeMoved},${FinalTimestamp},${Historical}) ON CONFLICT (RunNumber) DO UPDATE SET StartingTimestamp=excluded.StartingTimestamp, MissionName=excluded.MissionName, MissionType=excluded.MissionType, TripNumber=excluded.TripNumber, ExpectedTrips=excluded.ExpectedTrips, DropoffLocation=excluded.DropoffLocation, PickupLocation=excluded.PickupLocation, TotalUnits=excluded.TotalUnits, TotalVolume=excluded.TotalVolume, UnitsMoved=excluded.UnitsMoved, VolumeMoved=excluded.VolumeMoved, FinalTimestamp=excluded.FinalTimestamp, Historical=excluded.Historical;"]
	}
	; This method will be for Mid-CourierMission Updates
	method MissionLogCourierUpdate(int RunNumber, int TripNumber, int UnitsMoved, int64 VolumeMoved, int64 FinalTimestamp, int Historical)
	{
		CharacterSQLDB:ExecDML["update MissionLogCourier SET TripNumber=${TripNumber}, UnitsMoved=${UnitsMoved}, VolumeMoved=${VolumeMoved}, FinalTimestamp=${FinalTimestamp}, Historical=${Historical} WHERE RunNumber=${CurrentRunNumber};"]
	}
	; This method will be for filling out our RoomNPCInfo table. Just an insert, none of the values will ever change.
	; (EntityID INTEGER PRIMARY KEY, RunNumber INTEGER, RoomNumber INTEGER, NPCName TEXT, NPCGroup TEXT, NPCBounty INTEGER)
	method RoomNPCInfoInsert(int64 EntityID, int RunNumber, int RoomNumber, string NPCName, string NPCGroup, int64 NPCBounty)
	{
		CharacterSQLDB:ExecDML["insert into RoomNPCInfo (EntityID,RunNumber,RoomNumber,NPCName,NPCGroup,NPCBounty) values (${EntityID},${RunNumber},${RoomNumber},'${NPCName}','${NPCGroup}',${NPCBounty}) ON CONFLICT (EntityID) DO UPDATE SET RunNumber=excluded.RunNumber, RoomNumber=excluded.RoomNumber;"]
		;NPCDBDML:Insert
	}
	; This method will be for inserting information into the WatchDogMonitoring table. This will also be an upsert.
	; (CharID INTEGER PRIMARY KEY, RunNumber INTEGER, MissionName TEXT, MissionType TEXT, RoomNumber INTEGER, TripNumber INTEGER, TimeStamp INTEGER, CurrentTarget INTEGER, CurrentDestination TEXT, UnitsMoved INTEGER);"]
	method WatchDogMonitoringUpsert(int64 CharID, int RunNumber, string MissionName, string MissionType, int RoomNumber, int TripNumber, int64 TimeStamp, int64 CurrentTarget, string CurrentDestination, int UnitsMoved)
	{
		SharedSQLDB:ExecDML["insert into WatchDogMonitoring (CharID,RunNumber,MissionName,MissionType,RoomNumber,TripNumber,Timestamp,CurrentTarget,CurrentDestination,UnitsMoved) values (${CharID},${RunNumber},'${MissionName}','${MissionType}',${RoomNumber},${TripNumber},${Timestamp},${CurrentTarget},'${CurrentDestination}',${UnitsMoved})  ON CONFLICT (CharID) DO UPDATE SET RunNumber=excluded.RunNumber, MissionName=excluded.MissionName, MissionType=excluded.MissionType, RoomNumber=excluded.RoomNumber, TripNumber=excluded.TripNumber, Timestamp=excluded.Timestamp, CurrentTarget=excluded.CurrentTarget, CurrentDestination=excluded.CurrentDestination, UnitsMoved=excluded.UnitsMoved;"]
	}
	; This method will be for inserting information into the MissioneerStats table. This will be a normal insert, no upserts here.
	; (Timestamp INTEGER, CharName TEXT, CharID INTEGER, RunNumber INTEGER, RoomNumber INTEGER, TripNumber INTEGER, MissionName TEXT, MissionType TEXT, EventType TEXT, RoomBounties INTEGER, RoomFactionSpawn BOOLEAN,
	;   RoomDuration INTEGER, RunLP INTEGER, RunISK INTEGER, RunDuration INTEGER, RunTotalBounties INTEGER, ShipType TEXT);"]
	method MissioneerStatsInsert(int64 Timestamp, string CharName, int64 CharID, int RunNumber, int RoomNumber, int TripNumber, string MissionName, string MissionType, string EventType, int64 RoomBounties, bool RoomFactionSpawn, int64 RoomDuration, int64 RunISK, int RunLP, int64 RunDuration, int64 RunTotalBounties, string ShipType)
	{
		SharedSQLDB:ExecDML["insert into MissioneerStats (Timestamp,CharName,CharID,RunNumber,RoomNumber,TripNumber,MissionName,MissionType,EventType,RoomBounties,RoomFactionSpawn,RoomDuration,RunISK,RunLP,RunDuration,RunTotalBounties,ShipType) values (${Timestamp},'${CharName}',${CharID},${RunNumber},${RoomNumber},${TripNumber},'${MissionName}','${MissionType}','${EventType}',${RoomBounties},${RoomFactionSpawn},${RoomDuration},${RunISK},${RunLP},${RunDuration},${RunTotalBounties},'${ShipType}');"]
	}
	; This method will be for inserting information into the SalvageBMTable table. I don't anticipate this ever needing to be an Upsert.
	; (BMID INTEGER PRIMARY KEY, BMName TEXT, WreckCount INTEGER, BMSystem TEXT, ExpectedExpiration INTEGER, ClaimedByCharID INTEGER, SalvageTime INTEGER, Historical BOOLEAN);"]
	; ADDENDUM - This will now be an upsert as we are going to just dump all our valid BMs at the end of the mission instead of on the fly.
	method SalvageBMTableInsert(int64 BMID, string BMName, int WreckCount, string BMSystem, int64 ExpectedExpiration, int64 ClaimedByCharID, int64 SalvageTime, int Historical)
	{
		echo SALVAGEBMTABLE ${BMID},'${BMName}',${WreckCount},'${BMSystem}',${ExpectedExpiration},${ClaimedByCharID},${SalvageTime},${Historical}
		SharedSQLDB:ExecDML["insert into SalvageBMTable (BMID,BMName,WreckCount,BMSystem,ExpectedExpiration,ClaimedByCharID,SalvageTime,Historical) values (${BMID},'${BMName}',${WreckCount},'${BMSystem}',${ExpectedExpiration},${ClaimedByCharID},${SalvageTime},${Historical}) ON CONFLICT (BMID) DO UPDATE SET BMName=excluded.BMName;"]
	}
	; The same but for our networkly located DB
	method NetworkSalvageBMTableInsert(int64 BMID, string BMName, int WreckCount, string BMSystem, int64 ExpectedExpiration, int64 ClaimedByCharID, int64 SalvageTime, int Historical)
	{
		echo NETWORKSALVAGEBMTABLE ${BMID},'${BMName}',${WreckCount},'${BMSystem}',${ExpectedExpiration},${ClaimedByCharID},${SalvageTime},${Historical}
		ExtremelySharedSQLDB:ExecDML["insert into SalvageBMTable (BMID,BMName,WreckCount,BMSystem,ExpectedExpiration,ClaimedByCharID,SalvageTime,Historical) values (${BMID},'${BMName}',${WreckCount},'${BMSystem}',${ExpectedExpiration},${ClaimedByCharID},${SalvageTime},${Historical}) ON CONFLICT (BMID) DO UPDATE SET BMName=excluded.BMName;"]
	}
	; This method is just so a salvager can claim a salvage BM. If you have more than one salvager it is kinda needed.
	method SalvageBMTableClaim(int64 CharID, int64 BMID)
	{
		SharedSQLDB:ExecDML["update SalvageBMTable SET ClaimedByCharID=${CharID} WHERE BMID=${BMID};"]
	}
	; The same, but for the network located DB.
	method NetworkSalvageBMTableClaim(int64 CharID, int64 BMID)
	{
		ExtremelySharedSQLDB:ExecDML["update SalvageBMTable SET ClaimedByCharID=${CharID} WHERE BMID=${BMID};"]
	}	
	;;;;;;;;;;;;;;;;;;;;; Below this point is stuff I just grabbed from the original Missioneer ;;;;;;;;;;;;;;;;;
	
	; I've always wondered why this is even here.
	member:bool ReloadWeapons()
	{
		EVE:Execute[CmdReloadAmmo]
		return TRUE
	}

	; Also wondered what the hell this is for. Is it ever even used? Dunno
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

	; Pretty self-explanatory tbh
	member:bool StackShip()
	{
		EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:StackAll
		return TRUE
	}

	; This doesn't work correctly in a player structure but uh, you don't run Missions from those so who cares.
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
				return FALSE
			}

			if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
			{
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
				return FALSE
			}


			EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:StackAll

			
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
				return FALSE
			}

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
						return FALSE
					}

					EVEWindow[Inventory].ChildWindow[${dropOffContainerID}]:StackAll
					break
				}
			}
			while ${itemIterator:Next(exists)}
		}
		return TRUE
	}
	; Who knows.
	member:bool PrepHangars()
	{
		;variable index:eveinvchildwindow InvWindowChildren
		;variable iterator Iter
		;EVEWindow[Inventory]:GetChildren[InvWindowChildren]
		;InvWindowChildren:GetIterator[Iter]
		;if ${Iter:First(exists)}
		;	do
		;	{
		;		if ${Iter.Value.Name.Equal[StationCorpHangars]}
		;		{
		;			Iter.Value:MakeActive
		;		}
		;	}
		;	while ${Iter:Next(exists)}
		;return TRUE
		
		; To hell with that noise.
		if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
		{
			EVEWindow[Inventory].ChildWindow[StationCorpHangars,StationCorpHangar]:MakeActive
			return TRUE
		}
		return TRUE
	}

	; Who knows.
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
	
	; This is actually fairly efficient so we're keeping it.
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
		Client:Wait[500]
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
					Client:Wait[500]
					return FALSE
				}

				if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
				{

					EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
					Client:Wait[500]
					return FALSE
				}
				Client:Wait[500]
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:GetItems[items]
			}
			elseif ${Config.MunitionStorage.Equal[Personal Hangar]}
			{
				if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
				{
					EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
					Client:Wait[500]
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
							Client:Wait[500]
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
			Client:Wait[500]
			return FALSE
		}
		Client:Wait[500]
		EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:GetItems[items]
		items:GetIterator[itemIterator]
		if ${itemIterator:First(exists)}
		{
			do
			{
				if !${itemIterator.Value.Name.Equal[${Config.KineticAmmo}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.ThermalAmmo}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.EMAmmo}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.ExplosiveAmmo}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.KineticAmmoSecondary}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.ThermalAmmoSecondary}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.EMAmmoSecondary}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.ExplosiveAmmoSecondary}]} && \
				   !${itemIterator.Value.Name.Equal[${Ship.ModuleList_Weapon.FallbackAmmo}]} && \
				   !${itemIterator.Value.Name.Equal[${Ship.ModuleList_Weapon.FallbackLongRangeAmmo}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.BatteryToBring}]} && \
				   ; Anomaly gate key
				   !${itemIterator.Value.Name.Equal["Oura Madusaari"]} && \
				   !${itemIterator.Value.Group.Equal["Acceleration Gate Keys"]} && \
				   !${itemIterator.Value.Name.Find["Script"]} && \
				   ; Insignias for Extravaganza missions
				   !${itemIterator.Value.Name.Find["Diamond"]} && \
				   ; Gimmick trash for idiot hell fuckers, why do missions need bespoke garbage items?
				   !${itemIterator.Value.Name.Find["Imperial Navy Gate Permit"]}
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
							Client:Wait[500]
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
						{
							EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
							Client:Wait[500]
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
							Client:Wait[500]
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

	; This doesn't behave entirely correctly, and probably never has. But whatever, let us re-use it
	member:bool ReloadAmmoAndDrones()
	{
		if ${Config.AmmoAmountToLoad} <= 0
			return TRUE

		variable index:item items
		variable iterator itemIterator
		variable int defaultAmmoAmountToLoad = ${Config.AmmoAmountToLoad}
		variable int secondaryAmmoAmountToLoad = ${Config.AmmoAmountToLoad}
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

		if ${Config.UseDrones}
		{
			if (!${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} < 0)
			{
				EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay]:MakeActive
				Client:Wait[500]
				return FALSE
			}

			variable int64 specifiedDroneVolume = ${Drones.Data.GetVolume[${Config.DroneType}]}
			preferredDroneType:Set[${Config.DroneType}]
			if !${preferredDroneType.Equal[${Config.DroneType}]}
			{
				fallbackDroneType:Set[${Config.DroneType}]
			}
			
			Client:Wait[500]
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
							Client:Wait[500]
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
						{

							EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
							Client:Wait[500]
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
							Client:Wait[500]
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

			variable int64 remainingDroneSpace = ${Math.Calc[${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} - ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].UsedCapacity}]}

			if ${specifiedDroneVolume} > 0
			{
				droneAmountToLoad:Set[${Math.Calc[${remainingDroneSpace} / ${specifiedDroneVolume}].Int}]
			}
		}

		if !${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo].Capacity} < 0
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:MakeActive
			Client:Wait[500]
			return FALSE
		}

		defaultAmmoAmountToLoad:Dec[${This.InventoryItemQuantity[${ammo}, ${Me.ShipID}, "ShipCargo"]}]
		secondaryAmmoAmountToLoad:Dec[${This.InventoryItemQuantity[${secondaryAmmo}, ${Me.ShipID}, "ShipCargo"]}]
		batteryToLoad:Dec[${This.InventoryItemQuantity[${batteryType}, ${Me.ShipID}, "ShipCargo"]}]

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
						Client:Wait[500]
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
					!${itemIterator.Value.Name.Equal[${secondaryAmmo}]}) && \
					(${itemIterator.Value.Name.Equal[${Config.KineticAmmo}]} || \
					${itemIterator.Value.Name.Equal[${Config.ThermalAmmo}]} || \
					${itemIterator.Value.Name.Equal[${Config.EMAmmo}]} || \
					${itemIterator.Value.Name.Equal[${Config.ExplosiveAmmo}]} || \
				 	${itemIterator.Value.Name.Equal[${Config.KineticAmmoSecondary}]} || \
				 	${itemIterator.Value.Name.Equal[${Config.ThermalAmmoSecondary}]} || \
					${itemIterator.Value.Name.Equal[${Config.EMAmmoSecondary}]} || \
					${itemIterator.Value.Name.Equal[${Config.ExplosiveAmmoSecondary}]})) || \
					${itemIterator.Value.Name.Equal[${fallbackDroneType}]}
				{
					if ${Config.MunitionStorage.Equal[Corporation Hangar]}
					{
						if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
						{
							EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
							Client:Wait[500]
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
						{

							EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
							Client:Wait[500]
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
							Client:Wait[500]
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
			if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
			{
				EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
				Client:Wait[500]
				return FALSE
			}

			if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
			{
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
				Client:Wait[500]
				return FALSE
			}

			EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:GetItems[items]
		}
		elseif ${Config.MunitionStorage.Equal[Personal Hangar]}
		{
			if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
			{
				EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
				Client:Wait[500]
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
			}
			while ${itemIterator:Next(exists)}
		}

		if (!${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} < 0)
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay]:MakeActive
			Client:Wait[500]
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
		else
		{
			This:InsertState["StackShip"]
			return TRUE
		}
	}

	; Guess I'll keep this.
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
					Ship.ModuleList_Weapon:ConfigureAmmo[${ammo}, ${secondaryAmmo}]
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

			if ${EVEWindow[AgentConversation_${CurrentAgentID}](exists)}
			{
				EVEWindow[AgentConversation_${CurrentAgentID}]:Close
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
	
	; 93% sure this doesn't actually help anymore. I've never refreshed bookmarks and look where I am now
	; rich, successful, spending a hundred hours screwing around with scripts for no good reason.
	member:bool RefreshBookmarks()
	{
		This:LogInfo["Refreshing bookmarks"]
		EVE:RefreshBookmarks
		return TRUE
	}

	; This is vaguely useful, I guess. I'll hold onto it.
	member:int InventoryItemQuantity(string itemName, string inventoryID, string subFolderName = "")
	{
		variable index:item items
		variable iterator itemIterator

		if !${EVEWindow[Inventory].ChildWindow[${inventoryID}, ${subFolderName}](exists)} || ${EVEWindow[Inventory].ChildWindow[${inventoryID}, ${subFolderName}].Capacity} < 0
		{
			echo must open inventory window before calling this function
			; I really like how tehtsuo decided that if you did this wrong it should just crash the fuckin bot.
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


	; I have absolutely no idea what this is or does. I'm 98% sure it is never called by anything, so let's leave it here
	; to mystify future code historians.
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

	; What a weird thing to make. I presume we wanted to keep drones from attacking something that gives off
	; damage on destruction. No other idea why this exists. Let's leave it as a tribute to hubris.
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
	;;;;;;;;;;;;;;;;;;;;; Above this point is stuff I just grabbed from the original Missioneer ;;;;;;;;;;;;;;;;;
	; This is how we ensure Write Ahead Logging.
	method EnsureWAL()
	{
		; This will be used to Set WAL. WAL is persistent but I don't know how to read our current journal state sooo.
		CharacterSQLDB:ExecDML["PRAGMA journal_mode=WAL;"]
		SharedSQLDB:ExecDML["PRAGMA journal_mode=WAL;"]
		if ${Config.ExtremelySharedDBPath.NotNULLOrEmpty} && ${Config.ExtremelySharedDBPrefix.NotNULLOrEmpty}
        {
            ExtremelySharedSQLDB:ExecDML["PRAGMA journal_mode=WAL;"]
        }
		WalAssurance:Set[TRUE]
	}
	; Stealing this function from evebot and making it into a method instead.
	method ActivateShip(string TheType)
	{
		variable index:item hsIndex
		variable iterator hsIterator
		variable string shipType

		if ${Me.InStation}
		{
			Me:GetHangarShips[hsIndex]
			hsIndex:GetIterator[hsIterator]
			
			shipType:Set[${MyShip.ToItem.Type}]
			if ${shipType.NotEqual[${TheType}]} && ${hsIterator:First(exists)}
			{
				do
				{
					if ${hsIterator.Value.Type.Equal[${TheType}]}
					{
						This:LogInfo["Switching to ship of Type ${hsIterator.Value.Type}."]
						hsIterator.Value:MakeActive
						break
					}
					echo DEBUG WRONG SHIP ${hsIterator.Value.Type}
				}
				while ${hsIterator:Next(exists)}
			}
			else
			{
				This:LogInfo["We seem to not have... Any ships? I don't think this can happen tbh"]
				FailedToChangeShip:Set[TRUE]
			}
		}
	}
	; Need a State where we can refresh the contents of our inventory windows, because what the hell.
	; This will just open our station inventory, and then our largest bay as determined by some other crap I threw together somewhere else
	; might also refresh our specific corp hangar folder at some point. Fine I'll just do that now.
	; ADDENDUM - Have to make one of these fucking states for each of the three, ugh.
	member:bool RefreshCorpHangarState()
	{
		if ${Config.MunitionStorage.Equal[Corporation Hangar]}
		{
			if ${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)} && !${CorpHangarRefreshed}
			{
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
				CorpHangarRefreshed:Set[TRUE]
				This:InsertState["RefreshCorpHangarState",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
				return TRUE
			}
		}
		CorpHangarRefreshed:Set[FALSE]
		This:LogInfo["Corp Hangar Refreshed"]
		return TRUE
	}
	member:bool RefreshLargestBayState()
	{
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"${HaulerLargestBayType}"](exists)} && !${LargestBayRefreshed}
		{
			EVEWindow[Inventory].ChildWindow[${MyShip.ID},"${HaulerLargestBayType}"]:MakeActive			
			LargestBayRefreshed:Set[TRUE]
			This:InsertState["RefreshLargestBayState",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
		}
		LargestBayRefreshed:Set[FALSE]
		This:LogInfo["${HaulerLargestBayType} Refreshed"]
		return TRUE
	}
	member:bool RefreshStationItemsState()
	{
		if ${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)} && !${StationHangarRefreshed}
		{
			EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
			StationHangarRefreshed:Set[TRUE]
			This:InsertState["RefreshStationItemsState",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
		}
		StationHangarRefreshed:Set[FALSE]
		This:LogInfo["Station Items Refreshed"]
		return TRUE
	}
	; Item Quantity from above has failed me, time to make my own member that will work gooder, possibly. Returns the total number of the current needed trade item from either
	; personal hangar or corp hangar.
	member:int TradeItemInStock(string NeededItem)
	{
		variable index:item itemIndex
		variable iterator itemIterator
		; in case you somehow ended up moving multiple stacks of the item, no idea
		variable int itemtotal = 0
		if ${Config.MunitionStorage.Equal[Corporation Hangar]}
		{

			if ${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
			{
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:GetItems[itemIndex]
				itemIndex:GetIterator[itemIterator]
				if ${itemIterator:First(exists)}
				{
					do
					{
						if ${itemIterator.Value.Name.Equal[${NeededItem}]}
						{
							itemtotal:Inc[${itemIterator.Value.Quantity}]
						}
					}
					while ${itemIterator:Next(exists)}
				}
				This:LogInfo["${itemtotal} x ${CurrentAgentItem} located in Corp Hangar"]				
				return ${itemtotal}
			}
		}
		if ${Config.MunitionStorage.Equal[Personal Hangar]}
		{
			if ${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
			{
				EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[itemIndex]
				itemIndex:GetIterator[itemIterator]
				if ${itemIterator:First(exists)}
				{
					do
					{
						if ${itemIterator.Value.Name.Equal[${NeededItem}]}
						{
							itemtotal:Inc[${itemIterator.Value.Quantity}]
						}
					}
					while ${itemIterator:Next(exists)}
				}
				This:LogInfo["${itemtotal} x ${CurrentAgentItem} located in Corp Hangar"]				
				return ${itemtotal}
			}		
		}
	}
	; This member is so I can tell if the FUCKING INVENTORY WILL INDEX YET HOLY SHIT. How can this be so fucked up? I'm seeing like 15 second waits required for some of these!
	member:int CheckInventoryValid()
	{
		variable index:item itemIndex
		
		if ${Config.MunitionStorage.Equal[Corporation Hangar]}
		{

			if ${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
			{
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:GetItems[itemIndex]
				if ${itemIndex.Used}
				{
					This:LogInfo["Items Present in Inventory Index!"]
					return ${itemIndex.Used}
				}
				else
				{
					This:LogInfo["Returned an empty index"]
					return 0
				}
			}
		}
		if ${Config.MunitionStorage.Equal[Personal Hangar]}
		{
			if ${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
			{
				EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[itemIndex]
				if ${itemIndex.Used}
				{
					This:LogInfo["Items Present in Inventory Index!"]
					return ${itemIndex.Used}
				}
				else
				{
					This:LogInfo["Returned an empty index"]
					return 0
				}
			}		
		}	
	}
	; This member will be used by Combat Missioneer to tell if there are bad guys around.
	member:bool JerksPresent()
	{
		if ${Script[Tehbot].VariableScope.TargetManager.ActiveNPCs.TargetList.Used} > 0
		{
			return TRUE
		}
		else
		{
			return FALSE
		}
	}
}


; 	Once again, no clue what purpose this serves. Might be load bearing I guess. Let's leave it be shall we.
objectdef obj_MissionUI2 inherits obj_State
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