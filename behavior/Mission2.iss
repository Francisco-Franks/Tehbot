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

objectdef obj_Configuration_Mission2 inherits obj_Configuration_Base
{
	method Initialize()
	{
		This[parent]:Initialize["Mission2"]
	}

	method Set_Default_Values()
	{
		ConfigManager.ConfigRoot:AddSet[${This.SetName}]
	}
	Setting(bool, Halt, SetHalt)
	; This bool indicates we want to repeatedly Decline missions despite the standings damage
	; It is implied you know what you are doing with this. We won't be running multiple agents in this Tehbot fork.
	Setting(bool, RepeatedlyDecline, SetRepeatedlyDecline
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
	Setting(string, CombatShipName, SetCombatShipName)
	Setting(string, CourierShipName, SetCourierShipName)
	; Literal name of your ore hauler for trade missions
	Setting(string, TradeShipName, SetTradeShipName)
	; Literal name of a fast, low volume courier ship.
	Setting(string, FastCourierShipName, SetFastCourierShipName)
	; These will be settings taken from the original that still go on page 1 of the UIElement
	Setting(bool, IgnoreNPCSentries, SetIgnoreNPCSentries)
	; This is just what we name our Salvage BMs. If we are going to use the new salvager that I am supposedly making
	; this is kinda superfluous. But whatever. Maybe its good for backwards compat.
	Setting(string, SalvagePrefix, SetSalvagePrefix)	
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
	; What is the name of the folder your salvage bookmarks should be placed in. MAKE SURE THIS EXISTS
	; I don't remember what sanity checks exist on the isxeve side of things here, so lets assume the worst and that if you fuck this up the world will literally end.
	Setting(string, SalvageBMFolderName, SetSalvageBMFolderName)

	; This won't go in the UI anywhere, just need a persistent storage for our Run Number because I'm lazy.
	; To be honest, mostly just need this to initialize the number the first time around. This will be incremented after each mission completion.
	Setting(int, RunNumberInt, SetRunNumberInt)

}

objectdef obj_Mission2 inherits obj_StateQueue
{
	; This DB will be specific to the particular character
	variable sqlitedb CharacterSQLDB
	; This DB will be Shared by all clients on this machine.
	variable sqlitedb SharedSQLDB
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

	; This queue will store the AgentIDs of agents we need to contact to decline their missions as part of CurateMissions state.
	variable queue:int64 AgentDeclineQueue

	; Have we checked our mission logs?
	variable bool CheckedMissionLogs
	; Have we completed our Databasification? This bool indicates such.
	variable bool DatabasificationComplete
	; index where we place our strings for SQL execution
	variable index:string DML

	; These are needed to store what comes out of my HTML parsing method. Because I can't remember if the method has its own scope, inherits scope from where it is called, or takes the entire scripts scope.
	variable string LastAgentLocation
	variable string LastMissionLocation
	variable string LastExpectedItems
	variable int	LastItemUnits
	variable float	LastItemVolume
	variable bool	LastLowsec
	variable string LastDropoff
	variable string LastPickup
	
	; Storage variables for our Current (selected) Agent / Mission
	variable int64	CurrentAgentID
	variable int64	CurrentAgentIndex
	variable string CurrentAgentLocation
	variable string CurrentAgentShip
	variable string CurrentAgentItem
	variable int	CurrentAgentItemUnits
	variable float	CurrentAgentVolumePer
	variable float	CurrentAgentVolumeTotal
	variable string CurrentAgentPickup
	variable string CurrentAgentDropoff
	variable string CurrentAgentDamage
	variable string CurrentAgentDestroy
	variable string CurrentAgentLoot
	variable string	CurrentAgentMissionName
	variable string CurrentAgentMissionType
	
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
	variable float	CurrentRunVolumeMoved
	
	; Some variables about our current hauler, either for courier or for trade. Whatever we are flying at the moment.
	variable string	HaulerLargestBayType
	variable float	HaulerLargestBayCapacity
	variable bool	HaulerLargestBayOreLimited
	

	; Need this bool in case we go to change ships, and fail to do so.
	variable bool	FailedToChangeShip = FALSE
	
	; Recycled variables from the original
	variable string ammo
	variable string secondaryAmmo
	variable int	useDroneRace = 0
	variable obj_Configuration_Mission2 Config
	variable obj_Configuration_Agents2 Agents
	variable obj_MissionUI2 LocalUI
	variable bool 	reload = TRUE
	variable bool	halt = FALSE

	
	variable index:string AgentList	
	variable set BlackListedMission
	variable collection:string DamageType
	variable collection:string TargetToDestroy
	variable collection:string ContainerToLoot
	variable collection:float64 CapacityRequired	
	
	method Initialize()
	{
		This[parent]:Initialize

		DynamicAddBehavior("Mission2", "Combat Missions 2")
		This.PulseFrequency:Set[3500]

		This.LogInfoColor:Set["g"]
		This.LogLevelBar:Set[${Config.LogLevelBar}]

		LavishScript:RegisterEvent[Tehbot_ScheduleHalt]
		Event[Tehbot_ScheduleHalt]:AttachAtom[This:ScheduleHalt]
		LavishScript:RegisterEvent[Tehbot_ScheduleResume]
		Event[Tehbot_ScheduleResume]:AttachAtom[This:ScheduleResume]
		; Initializing the Run Number.
		if ${Script[Tehbot].VariableScope.Mission2.Config.RunNumberInt} < 1
		{
			Script[Tehbot].VariableScope.Mission2.Config.RunNumberInt:SetRunNumberInt[1]
		}
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
		if !${ISXSQLiteTest.TheSQLDatabase.ID(exists)}
		{
			This:LogCritical["SQL is not optional. Check the readme for how to get the extension. It is free."]
			This:LogCritical["If you have the extension. Enable ISXSQLiteTest on the minimodes tab."]
			return 
		}
		
		variable filepath MissionData = "${Script[Tehbot].CurrentDirectory}/data/${Config.MissionFile}"
		runscript "${MissionData}"

		UIElement[Run@TitleBar@Tehbot]:SetText[Stop]
	}

	method Stop()
	{
		This:LogInfo["Stopping."]
		This:Clear
		Tehbot.Paused:Set[TRUE]
		UIElement[Run@TitleBar@Tehbot]:SetText[Run]
		CharacterSQLDB:Close
		SharedSQLDB:Close
		
	}

	method Shutdown()
	{
		CharacterSQLDB:Close
		SharedSQLDB:Close
		
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
		; SQL DB related stuff.
		if !${CharacterSQLDB.ID(exists)} || !${SharedSQLDB.ID(exists)}
		{
			; Setting our character specific and shared DBs.
			CharacterSQLDB:Set[${SQLite.OpenDB["${Me.Name}DB","${Me.Name}DB.sqlite3"]}]
			SharedSQLDB:Set[${SQLite.OpenDB["MissionSharedDB","MissionSharedDB.sqlite3"]}]
			if !${WalAssurance}
			{
				This:EnsureWAL
			}
		}
		if ${CharacterSQLDB.ID(exists)} && ${SharedSQLDB.ID(exists)}
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
			; I also want to know how many jumps exist between the two locations. JumpDistance (int).
			; Next up will be some item specific information. ExpectedItems (string) for what the item is called. ItemUnits (integer) for how many items are expected. ItemVolume (float) for its total volume. VolumePer (float) for the Volume of each unit.
			; Next up will be target specific information. DestroyTarget (string) for what must die. LootTarget (string) for what must be looted.
			; Lastly, Damage type info. Damage2Deal (string). Think that covers anything, you may note that the last 3 things are all from the mission data xml. I may or may not
			; get absurdly ambitious with this.
			if !${CharacterSQLDB.TableExists["MissionJournal"]}
			{
				echo DEBUG - Creating Mission Journal Table
				CharacterSQLDB:ExecDML["create table MissionJournal (AgentID INTEGER PRIMARY KEY, MissionName TEXT, MissionType TEXT, MissionStatus INTEGER, AgentLocation TEXT, MissionLocation TEXT, DropoffLocation TEXT, PickupLocation TEXT, Lowsec BOOLEAN, JumpDistance INTEGER, ExpectedItems TEXT, ItemUnits INTEGER, ItemVolume REAL, VolumePer REAL, DestroyTarget TEXT, LootTarget TEXT, Damage2Deal TEXT);"]
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
				CharacterSQLDB:ExecDML["create table MissionLogCombat (RunNumber INTEGER PRIMARY KEY, StartingTimestamp DATETIME, MissionName TEXT, MissionType TEXT, RoomNumber INTEGER, KilledTarget BOOLEAN, Vanquisher BOOLEAN, ContainerLooted BOOLEAN, HaveItems BOOLEAN, TechnicalCompletion BOOLEAN, TrueCompletion BOOLEAN, FinalTimestamp DATETIME, Historical BOOLEAN);"]
			}
			
			; This table is for keeping track of what we've done during our Courier/Trade missions.
			; RunNumber (int). MissionName (string). StartingTimestamp (int64). MissionType (string). Re-using.
			; To keep track of how many trips we have made. TripNumber (int). To keep track of how many trips we are expected to make. ExpectedTrips (int).
			; To keep track of the dropoff location. DropoffLocation (string). And Pickup Location. PickupLocation (string).
			; To keep track of total units to move. TotalUnits (int). Same but for volume. TotalVolume (float).
			; To keep track of the units we have moved already. UnitsMoved (int). Same but for volume. VolumeMoved (float).
			; Re-using FinalTimestamp (int).
			; Lastly, re-use historical.
			
			if !${CharacterSQLDB.TableExists["MissionLogCourier"]}
			{
				echo DEBUG - Creating Mission Log Courier
				CharacterSQLDB:ExecDML["create table MissionLogCourier (RunNumber INTEGER PRIMARY KEY, StartingTimestamp DATETIME, MissionName TEXT, MissionType TEXT, TripNumber INTEGER, ExpectedTrips INTEGER, DropoffLocation TEXT, PickupLocation TEXT,, TotalUnits INTEGER, TotalVolume REAL, UnitsMoved INTEGER, VolumeMoved REAL, FinalTimestamp DATETIME, Historical BOOLEAN);"]
			}			
			
			; This next table exists so that the watchdog can try and quantify whether "progress" is being made. I'm tired of bots just getting stuck in weird states. Sure it is rare, but it is also wasteful.
			; Integer Primary Key shall be Character ID. Then RunNumber (int). Then we shall have CharName (string). Then MissionName (string). MissionType (string). RoomNumber (int). TripNumber (int). All re-used from before.
			; We will have a timestamp, this is basically just when the last update from that client was. TimeStamp (int64)
			; We will then have the bot's current target's entity ID. CurrentTarget (int). Then its current autopilot Destination (if its a courier). CurrentDestination (string).
			; Then we will have the units it has completed couriering on this run. UnitsMoved (int). That should be enough info to get a good idea whether progress is occurring or not.
			if !${SharedSQLDB.TableExists["WatchDogMonitoring"]}
			{
				echo DEBUG - Creating Watchdog Monitoring Table
				SharedSQLDB:ExecDML["create table WatchDogMonitoring (CharID INTEGER PRIMARY KEY, RunNumber INTEGER, MissionName TEXT, MissionType TEXT, RoomNumber INTEGER, TripNumber INTEGER, TimeStamp DATETIME, CurrentTarget INTEGER, CurrentDestination TEXT, UnitsMoved INTEGER);"]
			}
			
			; This, hopefully final table, exists so that we can gather meaningful statistics about our mission rewards.
			; Each row is going to represent exactly one complete mission run. We will not be looking at loot values here. It would be very very hard
			; for me to quantify loot values. We will be looking at straight isk mission rewards. LP rewards. Bounty rewards. Also, Mission duration beginning to end, room to room timing, the mission name obviously, what ship we are using.
			; There will be no primary key, this will be kinda like our observer bots, its just going to be a series of events.
			; First up we will have Timestamp (int64) CharName (string) CharID (int) RunNumber (int) RoomNumber (int) TripNumber (int)  MissionName (string) MissionType (string). All obvious.
			; Next we will have what type of event this row represents, Room completion, Trip Completion, Run Completion, Mission Decline. EventType (string). Room/Trip/Run/Decline are the valid strings.
			; Next up we will have a Bounty value, if applicable. Going to just add up the bounties of everything that we kill and Sum it up and throw it here. RoomBounties (float).
			; Next up, did we see a faction spawn (cruiser, battlecruiser, or battleship) in this room? RoomFactionSpawn (bool).
			; Next up we will have a Duration for the time it took to complete the room. RoomDuration (int64).
			; Next up we will have a mission turnin LP/ISK value to put on a Run completion EventType. RunLP (int) and RunISK (float) respectively.
			; Next up, Duration for time to complete the entire run. RunDuration (int64).
			; Last meaningful thing I can think to put here, what ship are we in? ShipType (string).
			if !${SharedSQLDB.TableExists["MissioneerStats"]}
			{
				echo DEBUG - Creating Missioner Stats Table
				SharedSQLDB:ExecDML["create table MissioneerStats (Timestamp DATETIME, CharName TEXT, CharID INTEGER, RunNumber INTEGER, RoomNumber INTEGER, TripNumber INTEGER, MissionName TEXT, MissionType TEXT, EventType TEXT, RoomBounties REAL, RoomFactionSpawn BOOLEAN, RoomDuration DATETIME, RunLP INTEGER, RunISK REAL, RunDuration DATETIME, ShipType TEXT);"]
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
				SharedSQLDB:ExecDML["create table SalvageBMTable (BMID INTEGER PRIMARY KEY, BMName TEXT, WreckCount INTEGER, BMSystem TEXT, ExpectedExpiration DATETIME, ClaimedByCharID INTEGER, SalvageTime DATETIME, Historical BOOLEAN);"]
			}
			; Well, that was time consuming and exhausting.
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
			GetMissionLogCombat:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionLogCombat WHERE Historical=FALSE;"]}]
			if ${GetMissionLogCombat.NumRows} > 0
			{
				This:LogInfo["Found running combat mission."]
				This:QueueState["CombatMission", 3000]
				GetMissionLogCombat:Finalize
				return TRUE
			}
			GetMissionLogCourier:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionLogCourier WHERE Historical=FALSE;"]}]
			if ${GetMissionLogCourier.NumRows} > 0
			{
				This:LogInfo["Found running courier mission."]
				This:QueueState["CourierMission", 3000]
				GetMissionLogCourier:Finalize
				return TRUE
			}
			; Found nothing currently being "run". On to databasification.
			CheckedMissionLogs:Set[TRUE]
			This:LogInfo["No running missions found."]
		}
		
		; Assuming the above doesn't immediately take us into a mission running state of some kind
		; then next we will databasify our Mission Journal.
		if !${DatabasificationComplete}
		{
			This:LogInfo["Begin Databasification"]
			This:QueueState["Databasification", 5000]
			return TRUE
		}
		; Now that our Journal is Databasificated we can look through it for acceptable missions to run.
		if ${DatabasificationComplete}
		{
			This:LogInfo["Begin Mission Choice"]
			This:QueueState["CurateMissions", 5000]
			return TRUE		
		}
		
	}
	; In this state we will Curate our missions. Lowsec missions will not be removed, but all other missions we do not want will
	; be removed from our mission journal. Due to how finnicky agent interactions can be, we will queue up AgentIDs and decline missions
	; in another state with a slow pulse rate.
	member:bool CurateMissions()
	{
		GetDBJournalInfo:Set${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal;"]}]
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
				if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Storyline - Encounter"]} && !${Config.DoStorylineCombat}
				{	
					This:LogInfo["Adding to Decline List - Storyline Encounter"]
					AgentDeclineQueue:Queue[${GetDBJournalInfo.GetFieldValue["AgentID",int64]}]
					GetDBJournalInfo:NextRow
					continue
				}
				if ( ${GetDBJournalInfo.GetFieldValue["ItemVolume",float]} > 1000 ) && !${Config.CourierShipName.NotNULLOrEmpty} && !${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Trade"]}
				{	
					This:LogInfo["High Volume and No Hauler Configured - Declining"]
					AgentDeclineQueue:Queue[${GetDBJournalInfo.GetFieldValue["AgentID",int64]}]
					GetDBJournalInfo:NextRow
					continue
				}
				if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Trade"]} && !${Config.TradeShipName.NotNULLOrEmpty}
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
			This:QueueState["DeclineMissions", 6000]
			return TRUE
		}
		This:QueueState["ChooseMission", 5000]
		return TRUE
	}
	; This state is needed so we can reliably Decline missions that don't meet our criteria.
	; Agent interactions don't enjoy going at mach speed such as found in a do while loop. So we will use this state to process a queue generated by CurateMissions state.
	member:bool DeclineMissions()
	{
		if ${AgentDeclineQueue.Peek}
		{
			EVE.Agent[id,${AgentDeclineQueue.Peek}]:StartConversation
			if !${EVEWindow[AgentConversation_${AgentDeclineQueue.Peek}](exists)}
			{
				This:LogInfo["Waiting on Conversation Window"]
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
				CharacterSQLDB:ExecDMLTransaction["Delete FROM MissionJournal WHERE AgentID=${AgentDeclineQueue.Peek}"]
				EVEWindow[AgentConversation_${AgentDeclineQueue.Peek}]:Close
				This:LogInfo["Declining mission from ${AgentDeclineQueue.Peek}"]
				AgentDeclineQueue:Dequeue
				return FALSE
			}				
		}
		else
		{
			This:QueueState["ChooseMission", 5000]
			return TRUE
		}
	}
	; This state will be where we choose our mission. Curate Missions state will have already done the heavy lifting for us.
	; The reason the two states aren't one is because deleting rows while iterating them is a bad idea.
	member:bool ChooseMission()
	{	
		; Storylines first.
		GetDBJournalInfo:Set${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal WHERE MissionType LIKE %Storyline%;"]}]
		if ${GetDBJournalInfo.NumRows} > 0
		{
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Encounter"]}
			{
				This:LogInfo["Encounter - Combat Ship Needed"]
				CurrentAgentShip:Set[${Config.CombatShipName}]

			}
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Courier"]} && ( ${GetDBJournalInfo.GetFieldValue["ItemVolume",float]} > 10 )
			{	
				This:LogInfo["Large Courier - Hauler Needed"]
				CurrentAgentShip:Set[${Config.CourierShipName}]
			}
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Courier"]} && ( ${GetDBJournalInfo.GetFieldValue["ItemVolume",float]} <= 10 )
			{
				This:LogInfo["Small Courier - Shuttle Needed"]
				if ${Config.FastCourierShipName.NotNULLOrEmpty}
					CurrentAgentShip:Set[${Config.FastCourierShipName}]
				else
					CurrentAgentShip:Set[${Config.CourierShipName}]
			}
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Trade"]}
			{
				This:LogInfo["Trade Mission - Ore Hauler Needed"]
				CurrentAgentShip:Set[${Config.TradeShipName}]
			}
			; Pulling our current (agent) variables back out.
			if ${GetDBJournalInfo.GetFieldValue["ExpectedItems",string].NotNULLOrEmpty}
				CurrentAgentItem:Set[${GetDBJournalInfo.GetFieldValue["ExpectedItems",string]}]
			if ${GetDBJournalInfo.GetFieldValue["ItemUnits",int]} >= 1
				CurrentAgentItemUnits:Set[${GetDBJournalInfo.GetFieldValue["ItemUnits",int]}]
			if ${GetDBJournalInfo.GetFieldValue["VolumePer",float]} > 0
				CurrentAgentVolumePer:Set[${GetDBJournalInfo.GetFieldValue["VolumePer",float]}]
			if ${GetDBJournalInfo.GetFieldValue["ItemVolume",float]} > 0
				CurrentAgentVolumeTotal:Set[${GetDBJournalInfo.GetFieldValue["ItemVolume",float]}]				
			if ${GetDBJournalInfo.GetFieldValue["PickupLocation",string].NotNULLOrEmpty}
				CurrentAgentPickup:Set[${GetDBJournalInfo.GetFieldValue["PickupLocation",string]}]
			if ${GetDBJournalInfo.GetFieldValue["DropoffLocation",string].NotNULLOrEmpty}
				CurrentAgentDropoff:Set[${GetDBJournalInfo.GetFieldValue["DropoffLocation",string]}]
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
			This:QueueState["MissionPrePrep", 5000]
			return TRUE
		}
		GetDBJournalInfo:Finalize
		; Everything else.
		GetDBJournalInfo:Set${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal;"]}]
		if ${GetDBJournalInfo.NumRows} > 0
		{
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Encounter"]}
			{
				This:LogInfo["Encounter - Combat Ship Needed"]
				CurrentAgentShip:Set[${Config.CombatShipName}]
			}
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Courier"]} && ( ${GetDBJournalInfo.GetFieldValue["ItemVolume",float]} > 10 )
			{	
				This:LogInfo["Large Courier - Hauler Needed"]
				CurrentAgentShip:Set[${Config.CourierShipName}]
			}
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Courier"]} && ( ${GetDBJournalInfo.GetFieldValue["ItemVolume",float]} <= 10 )
			{
				This:LogInfo["Small Courier - Shuttle Needed"]
				if ${Config.FastCourierShipName.NotNULLOrEmpty}
					CurrentAgentShip:Set[${Config.FastCourierShipName}]
				else
					CurrentAgentShip:Set[${Config.CourierShipName}]
			}
			; Pulling our current (agent) variables back out.
			if ${GetDBJournalInfo.GetFieldValue["ExpectedItems",string].NotNULLOrEmpty}
				CurrentAgentItem:Set[${GetDBJournalInfo.GetFieldValue["ExpectedItems",string]}]
			if ${GetDBJournalInfo.GetFieldValue["ItemUnits",int]} >= 1
				CurrentAgentItemUnits:Set[${GetDBJournalInfo.GetFieldValue["ItemUnits",int]}]
			if ${GetDBJournalInfo.GetFieldValue["VolumePer",float]} > 0
				CurrentAgentVolumePer:Set[${GetDBJournalInfo.GetFieldValue["VolumePer",float]}]
			if ${GetDBJournalInfo.GetFieldValue["ItemVolume",float]} > 0
				CurrentAgentVolumeTotal:Set[${GetDBJournalInfo.GetFieldValue["ItemVolume",float]}]		
			if ${GetDBJournalInfo.GetFieldValue["PickupLocation",string].NotNULLOrEmpty}
				CurrentAgentPickup:Set[${GetDBJournalInfo.GetFieldValue["PickupLocation",string]}]
			if ${GetDBJournalInfo.GetFieldValue["DropoffLocation",string].NotNULLOrEmpty}
				CurrentAgentDropoff:Set[${GetDBJournalInfo.GetFieldValue["DropoffLocation",string]}]
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
			This:QueueState["MissionPrePrep", 5000]
			return TRUE
		}
		else
		{
			This:LogInfo["No Valid Offered Missions - Default to Datafile Agent"]
			CurrentAgentID:Set[${EVE.Agent[${AgentList.Get[1]}].ID}]
			CurrentAgentLocation:Set[${EVE.Agent[${AgentList.Get[1]}].Station}]
			CurrentAgentIndex:Set[${EVE.Agent[${AgentList.Get[1]}].Index}]
			This:QueueState["MissionPrePrep", 5000]
			return TRUE
		}
	}
	; Addendum - For trade missions, you need to either have the items already there, or bring the items with you. Market interactions are toast so we won't be doing that.
	; Ugh, more work. So we also need to ensure we are in the correct ship, with the correct needed trade item, before we travel to the agent. Pisssssss. This also means we need
	; to code in another case for returning to our Primary Agent Station to swap back to other ships for other missions before we go to those missions.
	; This state thus exists to ensure we have the right ship for the job, also if its a trade mission, the right ore.
	;;;; EXTREMELY IMPORTANT NOTE - WE ARE ASSUMING YOU WILL KEEP YOUR ALTERNATE SHIPS IN YOUR PRIMARY AGENT STATION
	;;;; THAT IS TO SAY, THE STATION WHERE YOUR MAIN MISSION AGENT IS LOCATED. PLEASE DO SO
	member:bool MissionPrePrep()
	{
		; Need a variable to decrement to figure out if we have enough of our trade item
		variable int InStock
		; Need another for loading that trade item
		variable int TradeItemNeeded
		
		; Inventory variables
		variable index:item items
		variable iterator itemIterator
		
		
		GetDBJournalInfo:Set${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal WHERE AgentID=${CurrentAgentID};"]}]
		if ${GetDBJournalInfo.NumRows} < 1
		{
			; This case is that we are already going back to our Primary Agent Station, and we have no valid missions in our journal. Or we could already be there, but thats outside the scope of this state.
			; Basically we are just bypassing this state.
			This:QueueState["Go2Agent", 5000]
			return TRUE			
		}
		; We need to figure out if we are already flying what we need, and carrying what we need, if we need anything.
		; We determined WHAT we need in the previous state.
		if ${Me.StationID} != ${EVE.Agent[${AgentList.Get[1]}].StationID}
		{
			; We aren't at our Primary Agent Station. Move there.
			Move:Agent[${EVE.Agent[${AgentList.Get[1]}].Index}]
			This:InsertState["Traveling"]
		}
		if ${Me.StationID} == ${EVE.Agent[${AgentList.Get[1]}].StationID}
		{
			; We are already at our Primary Agent Station. Here we will A) Ensure that our ship is the ship called for in the last state and B) (optional) ensure that we have the Ore needed for a trade mission, if thats what is next.
			if !${MyShip.Name.Find[${CurrentAgentShip}]}
			{
				; Ship isn't right. Let's see if we can switch our ship with isxeve still.
				This:ActivateShip[${CurrentAgentShip}]
				if ${FailedToChangeShip}
				{
					GetDBJournalInfo:Finalize
					This:LogInfo["Ship doesn't exist here, awooga, stopping"]
					This:Stop
					return TRUE
				}
				; Presumably, we are in the right ship now.
			}
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Trade"]}
			{
				InStock:Inc[${CurrentAgentItemUnits}]
				TradeItemNeeded:Set[${CurrentAgentItemUnits}]
				This:LogInfo["Checking for ${CurrentAgentItem} for Trade Mission"]
				if ${Config.MunitionStorage.Equal[Corporation Hangar]}
					InStock:Dec[${This.InventoryItemQuantity[${CurrentAgentItem}, "StationCorpHangar", "${Config.MunitionStorageFolder}"]}]
				if ${Config.MunitionStorage.Equal[Personal Hangar]}
					InStock:Dec[${This.InventoryItemQuantity[${CurrentAgentItem}, ${Me.Station.ID}, "StationItems"]}]
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
					This:GetHaulerDetails
					if ${HaulerLargestBayCapacity} >= ${CurrentAgentVolumeTotal}
					{
						if ${Config.MunitionStorage.Equal[Corporation Hangar]}
						{
							if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
							{
								EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
								GetDBJournalInfo:Finalize
								return FALSE
							}
							EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:GetItems[items]
							items:GetIterator[itemIterator]
							do
							{
								if ${itemIterator.Value.Name.Equal[${CurrentAgentItem}]}
								{
									if ${itemIterator.Value.Quantity} >= ${TradeItemNeeded}
									{
										itemIterator.Value:MoveTo[${MyShip.ID}, ${HaulerLargestBayType}, ${TradeItemNeeded}]
										break
									}
									else
									{
										itemIterator.Value:MoveTo[${MyShip.ID}, ${HaulerLargestBayType}, ${itemIterator.Value.Quantity}]
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
								return FALSE
							}
							EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[items]
							items:GetIterator[itemIterator]
							do
							{
								if ${itemIterator.Value.Name.Equal[${CurrentAgentItem}]}
								{
									if ${itemIterator.Value.Quantity} >= ${TradeItemNeeded}
									{
										itemIterator.Value:MoveTo[${MyShip.ID}, ${HaulerLargestBayType}, ${TradeItemNeeded}]
										break
									}
									else
									{
										itemIterator.Value:MoveTo[${MyShip.ID}, ${HaulerLargestBayType}, ${itemIterator.Value.Quantity}]
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
						GetDBJournalInfo:Finalize
						This:Stop
						return TRUE
					}
				}
				GetDBJournalInfo:Finalize
				This:LogInfo["Ore Loaded, Headed out"]
				This:QueueState["Go2Agent",5000]
				return TRUE
			}
			
		}
	}
	; This state exists to get us to wherever our agent is. We will use 3 variables about our Current Agent to make this easier, probably. Actually... We only need their location.
	; The other 2 are for other things later. Idk, I'm tired.
	member:bool Go2Agent()
	{
		if ${Me.StationID} != ${EVE.Agent[${CurrentAgentIndex}].StationID}
		{
			; This calls a state in Move, we need to call Traveling or we will start doing shit while en route. That's no good.
			Move:Agent[${CurrentAgentIndex}]
			This:InsertState["Traveling"]
		}
		else
		{
			; Already there I guess. May as well open that Agent Conversation window and commence Databasification.
			This:LogInfo["At Agent Station"]
		}
		GetDBJournalInfo:Set${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal WHERE AgentID=${CurrentAgentID};"]}]
		if ${GetDBJournalInfo.NumRows} < 1
		{
			This:LogInfo["Begin Databasification"]
			EVE.Agent[${CurrentAgentIndex}]:StartConversation
			This:InsertState["Databasification", 5000]
			This:QueueState["CurateMissions", 5000]
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
		if $EVEWindow[AgentConversation_${CurrentAgentID}].Button["View Mission"](exists)}
		{
			EVEWindow[AgentConversation_${CurrentAgentID}].Button["View Mission"]:Press
		}
		if ${EVEWindow[AgentConversation_${CurrentAgentID}].Button["Request Mission"](exists)}
		{
			EVEWindow[AgentConversation_${CurrentAgentID}].Button["Request Mission"]:Press
		}
		if !${EVEWindow[AgentConversation_${CurrentAgentID}].Button["Accept"](exists)}
		{
			This:LogInfo["Don't see the accept button"]
			return FALSE
		}
		GetDBJournalInfo:Set${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal WHERE AgentID=${CurrentAgentID};"]}]
		if ${GetDBJournalInfo.NumRows} < 1
		{
			; We somehow don't have a journal DB row for this agent, the one we are talking to RIGHT NOW, what. Kick back to initial state.
			This:LogInfo["Something went incredibly wrong here."]
			DatabasificationComplete:Set[FALSE]
			This:QueueState["CheckForWork", 5000]
			return TRUE
		}
		else
		{
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
				This:LogInfo["Accepting mission from Agent"]
				EVEWindow[AgentConversation_${CurrentAgentID}].Button["Accept"]:Press
			}
			CurrentAgentMissionName:Set[${GetDBJournalInfo.GetFieldValue["MissionName",string]}]
			CurrentAgentMissionType:Set[${GetDBJournalInfo.GetFieldValue["MissionType",string]}]
			; We have a journal row, as expected. This should have already been curated, so this mission should, without fail, be one we want.
			; Let us establish the mission parameters, so we can put it in the correct mission log table.
			; (RunNumber INTEGER PRIMARY KEY, StartingTimestamp DATETIME, MissionName TEXT, MissionType TEXT, TripNumber INTEGER, ExpectedTrips INTEGER,
			;  DropoffLocation TEXT, PickupLocation TEXT, TotalUnits INTEGER, TotalVolume REAL, UnitsMoved INTEGER, VolumeMoved REAL, FinalTimestamp DATETIME, Historical BOOLEAN);"]
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Courier"]} || ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Trade"]}
			{
				; Gotta do this again, we might have swapped ships going from a trade mission to a courier.
				This:GetHaulerDetails
				; The following method is basically just to initialize our Current Run stats.
				; First argument on this will be the capacity of our largest bay, second argument will be the total volume of mission
				This:SetCurrentRunDetails[${HaulerLargestBayCapacity},${CurrentAgentTotalVolume}]
				This:MissionLogCourierUpsert[${CurrentRunNumber},${CurrentStartTimestamp},${CurrentAgentMissionName.ReplaceSubstring[','']},${CurrentAgentMissionType},${CurrentRunTripNumber},${CurrentRunExpectedTrips},${CurrentAgentDropoff},${CurrentAgentPickup},${CurrentAgentItemUnits},${CurrentAgentTotalVolume},${CurrentRunItemUnitsMoved},${CurrentRunVolumeMoved},${CurrentRunFinalTimestamp},FALSE]
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
					return TRUE
				}
			}
			; (RunNumber INTEGER PRIMARY KEY, StartingTimestamp DATETIME, MissionName TEXT, MissionType TEXT, RoomNumber INTEGER, KilledTarget BOOLEAN, Vanquisher BOOLEAN, ContainerLooted BOOLEAN, HaveItems BOOLEAN, TechnicalCompletion BOOLEAN, 
			;   TrueCompletion BOOLEAN, FinalTimestamp DATETIME, Historical BOOLEAN);"]
			if ${GetDBJournalInfo.GetFieldValue["MissionType",string].Find["Encounter"]}
			{
				; Don't ask, no idea why I did this.
				This:GetHaulerDetails
				; Do know why I did this.
				This:SetCurrentRunDetails[${HaulerLargestBayCapacity},${CurrentAgentTotalVolume}]
				This:MissionLogCombatUpsert[${CurrentRunNumber},${CurrentStartTimestamp},${CurrentAgentMissionName.ReplaceSubstring[','']},${CurrentAgentMissionType},${CurrentRunRoomNumber},${CurrentRunKilledTarget},${CurrentRunVanquisher},${CurrentRunContainerLooted},${CurrentRunHaveItems},${CurrentRunTechnicalComplete},${CurrentRunTrueComplete},${CurrentRunFinalTimestamp},FALSE]
				GetDBJournalInfo:Finalize
				EVEWindow[AgentConversation_${CurrentAgentID}]:Close
				This:QueueState["MissionPrep",5000]
				return TRUE
			}
		}
	}
	; This state will be where we prep our ship for the mission. Load ammo/drones, etc. This will be bypassed for Courier and Trade missions.
	; Courier missions will do their own loading, trade missions have already done their loading. 
	member:bool MissionPrep()
	{
		; First up, we need to establish exactly what damage type, and hence ammo and drones, we need.
		This:ResolveDamageType[${CurrentAgentDamage.Lower}]
		; Queue up the state that handles station inventory management for this scenario.
		This:InsertState["ReloadAmmoAndDrones", 4000]
		This:QueueState["Go2Mission",4000]
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
			if ${missionIterator.Value.AgentID} != ${CurrentAgentID}
			{
				continue
			}
			do
			{		
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
							Move:AgentBookmark[${bookmarkIterator.Value.ID}]
							;ActiveNPCs.AutoLock:Set[FALSE]
							;NPCs.AutoLock:Set[FALSE]
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
	; This state will be the primary logic for a Combat Mission
	member:bool CombatMission()
	{
		; We may have gotten here via a mid-mission bot launch, lets check that and if true then set our Current Agent/Mission Variables
		if !${CurrentAgentMissionType.NotNULLOrEmpty} && !${CurrentAgentMissionName.NotNULLOrEmpty}
			This:MidRunRecovery["Combat"]
			
		GetMissionLogCombat:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionLogCombat WHERE Historical=FALSE;"]}]
	
	
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
		; MissionLogCourierUpdate(int RunNumber, int TripNumber, int UnitsMoved, float VolumeMoved, int64 FinalTimestamp, bool Historical)
		This:MissionLogCourierUpdate[${CurrentRunNumber},${CurrentRunTripNumber},${CurrentAgentItemUnits},${CurrentAgentVolumeTotal},${Time.Timestamp},FALSE}]
		This:QueueState["FinishingAgentInteraction",5000]
	}
	; This state will be the primary logic for a Courier Mission.
	member:bool CourierMission()
	{
		if !${CurrentAgentMissionType.NotNULLOrEmpty} && !${CurrentAgentMissionName.NotNULLOrEmpty}
			This:MidRunRecovery["Noncombat"]
			
		GetMissionLogCourier:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionLogCourier WHERE Historical=FALSE;"]}]
	
	
	}
	; This state will be where we do our finishing interaction with our Agent. This comes at mission completion.
	; This is also where we, when we turn in the mission, do our final MissionLog entry in whatever table it belongs to.
	; We will set that row to Historical, update any final details that need to be updated, clean up any variables that need cleaning up.
	member:bool FinishingAgentInteraction()
	{
		; Open a conversation window, again.
		if !${EVEWindow[AgentConversation_${CurrentAgentID}](exists)}
		{
			This:LogInfo["Opening Conversation Window."]
			EVE.Agent[${CurrentAgentIndex}]:StartConversation
			return FALSE
		}	
		if $EVEWindow[AgentConversation_${CurrentAgentID}].Button["View Mission"](exists)}
		{
			EVEWindow[AgentConversation_${CurrentAgentID}].Button["View Mission"]:Press
			return FALSE
		}
		if $EVEWindow[AgentConversation_${CurrentAgentID}].Button["Complete Mission"](exists)}
		{
			EVEWindow[AgentConversation_${CurrentAgentID}].Button["Complete Mission"]:Press
			return FALSE
		}
		if $EVEWindow[AgentConversation_${CurrentAgentID}].Button["Request Mission"](exists)}
		{
			;We can be fairly sure the mission completed correctly.
			if !${CurrentAgentMissionType.Find[Encounter]}
			{
				This:MissionLogCourierUpdate[${CurrentRunNumber},${CurrentRunTripNumber},${CurrentAgentItemUnits},${CurrentAgentVolumeTotal},${Time.Timestamp},TRUE}]
				This:LogInfo["Mission complete - Finalizing Log Entry"]
			}
			else
			{
				; MissionLogCombatUpdate(int RunNumber, int RoomNumber, bool KilledTarget, bool Vanquisher, bool ContainerLooted, bool HaveItems, bool TechnicalCompletion, bool TrueCompletion, int64 FinalTimestamp, bool Historical)
				This:MissionLogCourierUpdate[${CurrentRunNumber},${CurrentRunRoomNumber},${CurrentRunKilledTarget},${CurrentRunVanquisher},${CurrentRunContainerLooted},${CurrentRunHaveItems},${CurrentRunTechnicalComplete},${CurrentRunTrueComplete},${Time.Timestamp},TRUE}]
				This:LogInfo["Mission complete - Finalizing Log Entry"]				
			}
		}
		This:QueueState["BeginCleanup",5000]
		return TRUE
	}
	; This state will be where we kick off our station interaction stuff. Repairs, loot dropoff, etc.
	; After this state we should go back to CheckForWork.
	member:bool BeginCleanup()
	{
	
	
		This:QueueState["CheckForWork",4000]
		return TRUE
	}
	
	; This is a great name for a state. Anyways, here in Databasification we will take our Mission Journal, go through all of the missions
	; Then we will place the information in the SQL database for easier consumption presumably. I won't lie, it has been more than one day
	; Since I worked on this, so I've somewhat lost the plot. Each mission will be placed into the Character Specific MissionJournal Table.
	; From there we can use that information to accomplish something, surely. I am fairly sure that in order to accomplish this I will have to touch the mission parser
	; at least a little bit. Also we will need to get some info from that mission data file.
	member:bool Databasification()
	{
		; Oh god where do I even begin. Well let us look at that MissionJournal Table I made and how its rows are set up.
		; (AgentID INTEGER PRIMARY KEY, MissionName TEXT, MissionType TEXT, MissionStatus INTEGER, AgentLocation TEXT, MissionLocation TEXT, DropoffLocation TEXT, PickupLocation TEXT, Lowsec BOOLEAN, JumpDistance INTEGER, 
		;  ExpectedItems TEXT, ItemUnits INTEGER, ItemVolume REAL, VolumePer REAL, DestroyTarget TEXT, LootTarget TEXT, Damage2Deal TEXT);"]
		; Basically we want to assemble all of this information from what we can pull from the Mission Journal, the Mission Details, and our Mission Data XML, and then finally from some minor calculations from those 3 sources.\
		; We take that information and fork it over to MissionJournalUpsert method. And hence, it is databasificated.
		; Guess we should get our limited scope variables in a row here.
		; These make the mission journal stuff work
		variable index:agentmission missions
		variable iterator missionIterator
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
		variable float ItemVolume
		variable string PickupLocation
		variable string DropoffLocation
		variable bool Lowsec
		; These will be derived from the above.
		; JumpDistance is how many jumps to the Agent from where we are, then from the agent to the mission location. Volume per is just total volume / units.
		; Aaaactually, I can't think of a great way to get JumpDistance, the pathing won't behave correctly. It ignores autopilot settings and whatnot.
		variable int JumpDistance
		variable float VolumePer
		
		; Begin the work. Lets get all our current missions.
		EVE:GetAgentMissions[missions]
		missions:GetIterator[missionIterator]
		if ${missionIterator:First(exists)}
		{
			do
			{	
				; Lets get a convo window open with this agent.
				EVE.Agent[id,${missionIterator.Value.AgentID}]:StartConversation
				; I guess we will want to skip checking things that are in the Table but haven't changed.
				GetDBJournalInfo:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal WHERE AgentID=${missionIterator.Value.AgentID} AND MissionName=${missionIterator.Value.Name} AND MissionStatus=${missionIterator.Value.State};"]}]
				if ${GetDBJournalInfo.NumRows} > 0
				{
					; If it already exists in the DB, in the same state, the same mission name, from the same agent, it is safe to say it is already there. Skip it.
					continue
				}
				if ${missionIterator.Value.State} == 3
				{
					; If it is an expired mission, don't databasify it.
					continue
				}
				GetDBJournalInfo:Finalize
				; To hell with that Mission Parser, why use that when I can make my own thing that might work once in a while.
				This:ParseMissionDetails[${missionIterator.Value.AgentID}, ${missionIterator.Value.Type}]
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
				DropoffLocation:Set[${LastDropoff}]
				Lowsec:Set[${LastLowsec}]
				; Derived information
				if ${LastItemUnits} > 0
					VolumePer:Set[${Math.Calc[${LastItemVolume} / ${LastItemUnits}]}]
				; Assemble information and prepare to Insert into Table
				; (AgentID INTEGER PRIMARY KEY, MissionName TEXT, MissionType TEXT, MissionStatus INTEGER, AgentLocation TEXT, MissionLocation TEXT, DropoffLocation TEXT, PickupLocation TEXT, Lowsec BOOLEAN, JumpDistance INTEGER, ExpectedItems TEXT, ItemUnits INTEGER, ItemVolume REAL,
				;   VolumePer REAL, DestroyTarget TEXT, LootTarget TEXT, Damage2Deal TEXT);"]
				This:MissionJournalUpsert[${AgentID},${MissionName.ReplaceSubstring[','']}, ${MissionType}, ${MissionStatus}, ${AgentLocation.ReplaceSubstring[','']}, ${MissionLocation.ReplaceSubstring[','']}, ${DropoffLocation.ReplaceSubstring[','']}, ${PickupLocation.ReplaceSubstring[','']}, ${Lowsec},${JumpDistance}, ${ExpectedItems.ReplaceSubstring[','']}, ${ItemUnits}, ${ItemVolume}]
				if ${EVEWindow[AgentConversation_${AgentID}](exists)}
				{
					This:LogInfo["Entry Processed, closing window"]
					EVEWindow[AgentConversation_${AgentID}]:Close
				}				
			}
			while ${missionIteration:Next(exists)}
			; Next up, lets run a quick deletion on all Expired Mission Offers
			CharacterSQLDB:ExecDMLTransaction["Delete FROM MissionJournal WHERE MissionStatus=3"]
			; So we know we've completed this.
			DatabasificationComplete:Set[TRUE]
		}
		
	
	}
	; This method will be used to do our Agent Conversation HTML parsing. Because the existing stuff is just too damn easy.
	; We will also be using Agent ID instead of Index, because I'm a rebel. This can't possibly come back to haunt me.
	method ParseMissionDetails(string AgentID, string MissionType)
	{
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
		variable SecondSlashSlash
		variable ThirdSlashSlash
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

		; Lets make sure the agent conversation window actually opened... I doubt this will actually work as a recovery method...
		if !${EVEWindow[AgentConversation_${AgentID}](exists)}
		{
			This:LogInfo["Conversation window failure. Opening again."]
			EVE.Agent[id,${AgentID}]:StartConversation
		}
		; Lets get the Briefing into its JSONified String
		JSONObjective:Set[${EVEWindow[AgentConversation_${AgentID}].BriefingHTML.AsJSON}]
		; Lets get the Objectives into its JSONified String
		JSONBriefing:Set[${EVEWindow[AgentConversation_${AgentID}].ObjectivesHTML.AsJSON}]
		; Lets get the easy one out of the way, is this declared lowsec.
		if ${JSONObjective.AsJSON.Find["low security system"]}
			LastLowsec:Set[TRUE]
		else
			LastLowsec:Set[FALSE]
		; Ok next, lets get the Location of the Agent, but from the HTML, instead of looking it up. Dunno why. Just go with it.
		; First we get the location of the first <br><br>, take that location get a substring from it, take that substring and find the first //, this // comes before the station ID. Station ID number ends at a >. Find that >.
		; We will now have a position where the number starts and where it ends.
		FirstBRBR:Set[${JSONBriefing.AsJSON.Find[<br><br>]}]
		JSONBriefingString1:Set[${JSONBriefing.AsJSON.Mid[${FirstBRBR},2000].AsJSON}]
		FirstSlashSlash:Set[${Math.Calc[${JSONBriefingString1.AsJSON.Find[//]} + 2]}]
		JSONBriefingString2:Set[${JSONBriefing.AsJSON.Mid[${FirstSlashSlash},2000].AsJSON}]
		FirstAngleBracket:Set[${Math.Calc[${JSONBriefingString2.AsJSON.Find[>]} - 2]}]
		StationID:Set[${JSONBriefingString2.AsJSON.Mid[2,${FirstAngleBracket}].AsJSON}]
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
			FirstSlashA:Set[${Math.Calc[${JSONObjectiveString1.AsJSON.Find[</a>]}-2]}
			LastMissionLocation:Set[${JSONObjectiveString1.AsJSON.Mid[2,${FirstSlashA}]}]
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
			StationID2:Set[${JSONObjectiveString2B.AsJSON.Mid[2,${SecondAngleBracket}].AsJSON}]
			
			FindDropoff:Set[${JSONObjective.AsJSON.Find[<td>Drop-off Location</td>]}]
			JSONObjectiveString3:Set[${JSONObjective.AsJSON.Mid[${FindDropoff},1000].AsJSON}]
			ThirdSlashSlash:Set[${Math.Calc[${JSONObjectiveString3.AsJSON.Find[//]} + 2]}]
			JSONObjectiveString3B:Set[${JSONObjectiveString3.AsJSON.Mid[${ThirdSlashSlash},2000].AsJSON}]
			ThirdAngleBracket:Set[${Math.Calc[${JSONObjectiveString3B.AsJSON.Find[>]} - 2]}]
			StationID3:Set[${JSONObjectiveString3B.AsJSON.Mid[2,${ThirdAngleBracket}].AsJSON}]
			; And now to make both of those Station IDs into names
			LastPickup:Set[${EVE.Station[${StationID2}].Name}]
			LastDropoff:Set[${EVE.Station[${StationID3}].Name}]
		}
		; Trade mission, the location is the agent location, always.
		if ${MissionType.Find[Trade]}
		{
			LastMissionLocation:Set[${EVE.Station[${StationID}].Name}]
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
				LastItemUnits:Set[${JSONObjectiveString4B.AsJSON.Mid[2,${FindX1}].Trim.AsJSON}]
			}
			elseif ${JSONObjective.AsJSON.Find[<td>Cargo</td>]}
			{
				FindCargo:Set[${Math.Calc[${JSONObjective.AsJSON.Find[<td>Cargo</td>]} + 14]}]
				JSONObjectiveString5:Set[${JSONObjective.AsJSON.Mid[${FindCargo},1000].AsJSON}]
				FindPointyThing2:Set[${Math.Calc[${JSONObjectiveString5.AsJSON.Find[d>]} + 2]}]
				JSONObjectiveString5B:Set[${JSONObjectiveString5.AsJSON.Mid[${FindPointyThing2},1000].AsJSON}]
				FindX2:Set[${Math.Calc[${JSONObjectiveString5B.AsJSON.Find[x]} - 2]}]
				LastItemUnits:Set[${JSONObjectiveString5B.AsJSON.Mid[2,${FindX2}].Trim.AsJSON}]
			}
			
		}
		else
			LastExpectedItems:Set[""]

		; Next up, ExpectedItems. This is going to be the Name of the Item you are picking up. Also, might not be an item involved at all.
		; Ok so building off the last set there where we grabbed what was BEFORE the X, now we will grab what is between the X and the (
		if ${JSONObjective.AsJSON.Find["these goods:"]}
		{
			if ${JSONObjective.AsJSON.Find[<td>Item</td>]}
			{
				JSONObjectiveString6:Set[${JSONObjectiveString4B.AsJSON.Mid[${Math.Calc[${FindX1} + 3]},1000].Trim.AsJSON}]
				FindParenth1:Set[${Math.Calc[${JSONObjectiveString6.AsJSON.Find[\(]} - 2]}]
				LastExpectedItems:Set[${JSONObjectiveString6.AsJSON.Mid[2,${FindParenth1}].Trim.AsJSON}]
				JSONObjectiveString6B:Set[${JSONObjectiveString6.AsJSON.Mid[${Math.Calc[${FindParenth1} + 3]},1000].Trim.AsJSON}]
			}
			elseif ${JSONObjective.AsJSON.Find[<td>Cargo</td>]}
			{
				JSONObjectiveString7:Set[${JSONObjectiveString5B.AsJSON.Mid[${Math.Calc[${FindX2} + 3]},1000].Trim.AsJSON}]
				FindParenth2:Set[${Math.Calc[${JSONObjectiveString7.AsJSON.Find[\(]} - 2]}]
				LastExpectedItems:Set[${JSONObjectiveString6.AsJSON.Mid[2,${FindParenth1}].Trim.AsJSON}]
				JSONObjectiveString7B:Set[${JSONObjectiveString7.AsJSON.Mid[${Math.Calc[${FindParenth2} + 3]},1000].Trim.AsJSON}]
			}			
		}
		else
			LastItemUnits:Set[0]
		; Next up ItemVolume, which is actually the total volume of all the items. May as well grab it here. If no item, then no this. 
		if ${JSONObjective.AsJSON.Find["these goods:"]}
		{
			if ${JSONObjective.AsJSON.Find[<td>Item</td>]}
			{
				Findm3A:Set[${Math.Calc[${JSONObjectiveString6B.AsJSON.Find[m³]} - 2]}]
				LastItemVolume:Set[${JSONObjectiveString6B.AsJSON.Mid[2,${Findm3A}].Trim.AsJSON}]
			}
			elseif ${JSONObjective.AsJSON.Find[<td>Cargo</td>]}
			{
				Findm3B:Set[${Math.Calc[${JSONObjectiveString7B.AsJSON.Find[m³]} - 2]}]
				LastItemVolume:Set[${JSONObjectiveString7B.AsJSON.Mid[2,${Findm3B}].Trim.AsJSON}]
			}			
		}
		else
			LastItemVolume:Set[0]
	
	}
	; This method will be to help us generate appropriate Status Reports for WatchDogMonitoring
	method UpdateWatchDog()
	{
	
	
	}
	; This method will help us generate an appropriate Missioneer Stats entry.
	method UpdateMissioneerStats()
	{
	
	
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
			GetMissionLogCombined:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionLogCombat WHERE Historical=FALSE;"]}]
		if ${Case.Equal[Noncombat]}
			GetMissionLogCombined:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionLogCourier WHERE Historical=FALSE;"]}]
		; Pulling our current (run) variables back out. There is no way for this to not return a row, or we wouldn't have gotten here.
		if ${GetMissionLogCombined.NumRows} > 0
		{
			${GetMissionLogCombined.GetFieldValue["RoomNumber",int]}
			CurrentRunNumber:Set[${GetMissionLogCombined.GetFieldValue["RunNumber",int]}]
			CurrentRunRoomNumber:Set[${GetMissionLogCombined.GetFieldValue["RoomNumber",int]}]
			CurrentRunStartTimestamp:Set[${GetMissionLogCombined.GetFieldValue["StartingTimestamp",int]}]
			CurrentRunKilledTarget:Set[${GetMissionLogCombined.GetFieldValue["KilledTarget",bool]}]
			CurrentRunVanquisher:Set[${GetMissionLogCombined.GetFieldValue["Vanquisher",bool]}]
			CurrentRunContainerLooted:Set[${GetMissionLogCombined.GetFieldValue["ContainerLooted",bool]}]
			CurrentRunHaveItems:Set[${GetMissionLogCombined.GetFieldValue["HaveItems",bool]}]
			CurrentRunTechnicalComplete:Set[${GetMissionLogCombined.GetFieldValue["TechnicalCompletionr",bool]}]
			CurrentRunTrueComplete:Set[${GetMissionLogCombined.GetFieldValue["TrueCompletion",bool]}]
			CurrentRunTripNumber:Set[${GetMissionLogCombined.GetFieldValue["TripNumber",int]}]
			CurrentRunExpectedTrips:Set[${GetMissionLogCombined.GetFieldValue["ExpectedTrips",int]}]
			CurrentRunItemUnitsMoved:Set[${GetMissionLogCombined.GetFieldValue["UnitsMoved",int]}]
			CurrentRunVolumeMoved:Set[${GetMissionLogCombined.GetFieldValue["VolumeMoved",float]}]
		}	
		; Presumably you will only have one active mission at a time. But lets make sure the mission names are the same.
		GetDBJournalInfo:Set${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal WHERE MissionStatus=2 AND MissionName='${GetDBJournalInfo.GetFieldValue["MissionName",string]}';"]}]
		if ${GetDBJournalInfo.NumRows} > 0
		{
			; Pulling our current (agent) variables back out.
			if ${GetDBJournalInfo.GetFieldValue["ExpectedItems",string].NotNULLOrEmpty}
				CurrentAgentItem:Set[${GetDBJournalInfo.GetFieldValue["ExpectedItems",string]}]
			if ${GetDBJournalInfo.GetFieldValue["ItemUnits",int]} >= 1
				CurrentAgentItemUnits:Set[${GetDBJournalInfo.GetFieldValue["ItemUnits",int]}]
			if ${GetDBJournalInfo.GetFieldValue["VolumePer",float]} > 0
				CurrentAgentVolumePer:Set[${GetDBJournalInfo.GetFieldValue["VolumePer",float]}]
			if ${GetDBJournalInfo.GetFieldValue["ItemVolume",float]} > 0
				CurrentAgentVolumeTotal:Set[${GetDBJournalInfo.GetFieldValue["ItemVolume",float]}]		
			if ${GetDBJournalInfo.GetFieldValue["PickupLocation",string].NotNULLOrEmpty}
				CurrentAgentPickup:Set[${GetDBJournalInfo.GetFieldValue["PickupLocation",string]}]
			if ${GetDBJournalInfo.GetFieldValue["DropoffLocation",string].NotNULLOrEmpty}
				CurrentAgentDropoff:Set[${GetDBJournalInfo.GetFieldValue["DropoffLocation",string]}]
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
	This:GetHaulerDetails
	}
	; This method will Set/Reset our Current Run information (the crap that goes into the mission log db entries). Initial entry basically.
	method SetCurrentRunDetails(float OurCapacity, float TotalVolume)
	{
		CurrentRunNumber:Set[${Config.RunNumberInt}]
		CurrentRunRoomNumber:Set[0]
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
	method GetHaulerDetails()
	{	
		variable float TempStorage1
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipCargo"](exists)}
		{
			EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipCargo"]:MakeActive
			{
				if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipCargo"].Capacity} < 0
				{
					This:InsertState["Idle", 2000]
					if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipCargo"].Capacity} > 0
					{
						HaulerLargestBayCapacity:Set[${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipCargo"].Capacity}]
						TempStorage1:Set[${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipCargo"].Capacity}]
						HaulerLargestBayType:Set["ShipCargo"]
						HaulerLargestBayOreLimited:Set[FALSE]
					}
					else
					{
						; Something went wrong here
					}
				}
			}
		}		
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipFleetHangar"](exists)}
		{
			EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipFleetHangar"]:MakeActive
			{
				if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipFleetHangar"].Capacity} < 0
				{
					This:InsertState["Idle", 2000]
					if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipFleetHangar"].Capacity} > 0
					{
						HaulerLargestBayCapacity:Set[${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipFleetHangar"].Capacity}]
						TempStorage1:Set[${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipFleetHangar"].Capacity}]
						HaulerLargestBayType:Set["ShipFleetHangar"]
						HaulerLargestBayOreLimited:Set[FALSE]
					}
					else
					{
						; Something went wrong here
					}
				}
			}
		}
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipGeneralMiningHold"](exists)}
		{
			EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipGeneralMiningHold"]:MakeActive
			{
				if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipGeneralMiningHold"].Capacity} < 0
				{
					This:InsertState["Idle", 2000]
					if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipGeneralMiningHold"].Capacity} > 0 &&  (${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipGeneralMiningHold"].Capacity} > ${TempStorage1})
					{
						HaulerLargestBayCapacity:Set[${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipGeneralMiningHold"].Capacity}]
						HaulerLargestBayType:Set["ShipGeneralMiningHold"]
						HaulerLargestBayOreLimited:Set[TRUE]
					}
					else
					{
						; Something went wrong here
					}
				}
			}
		}
		; Now that I think about it, is there even a situation where the normal cargo hold will be larger than the fleet hangar or the ore bay if a ship has either one of those???
	}
	; This method will be for inserting information into the MissionJournal table. This will naturally be an Upsert.
	; (AgentID INTEGER PRIMARY KEY, MissionName TEXT, MissionType TEXT, MissionStatus INTEGER, AgentLocation TEXT, MissionLocation TEXT, DropoffLocation TEXT, PickupLocation TEXT, Lowsec BOOLEAN, JumpDistance INTEGER, ExpectedItems TEXT, ItemUnits INTEGER, ItemVolume REAL,
	;   VolumePer REAL, DestroyTarget TEXT, LootTarget TEXT, Damage2Deal TEXT);"]
	method MissionJournalUpsert(int64 AgentID, string MissionName, string MissionType, int MissionStatus, string AgentLocation, string MissionLocation, string DropoffLocation, string PickupLocation, bool Lowsec, int JumpDistance, string ExpectedItems, int ItemUnits, float ItemVolume, float VolumePer, string DestroyTarget, string LootTarget, string Damage2Deal)
	{
		CharacterSQLDB:ExecDMLTransaction["insert into MissionJournal (AgentID,MissionName,MissionType,MissionStatus,AgentLocation,MissionLocation,DropoffLocation,PickupLocation,Lowsec,JumpDistance,ExpectedItems,ItemUnits,ItemVolume,VolumePer,DestroyTarget,LootTarget,Damage2Deal) values (${AgentID}, '${MissionName}', '${MissionType}', ${MissionStatus}, '${AgentLocation}', '${MissionLocation}', '${DropoffLocation}', '${PickupLocation}', ${Lowsec}, ${JumpDistance}, '${ExpectedItems}', ${ItemUnits}, ${ItemVolume}, ${VolumePer}, '${DestroyTarget}','${Damage2Deal}') ON CONFLICT (AgentID) DO UPDATE SET MissionName=excluded.MissionName, MissionType=excluded.MissionType, MissionStatus=excluded.MissionStatus, AgentLocation=excluded.AgentLocation, MissionLocation=excluded.MissionLocation, DropoffLocation=excluded.DropoffLocation, PickupLocation=excluded.PickupLocation, Lowsec=excluded.Lowsec, Jumpdistance=excluded.JumpDistance, ExpectedItems=excluded.ExpectedItems, ItemUnits=excluded.ItemUnits, ItemVolume=excluded.ItemVolume, VolumePer=excluded.VolumePer, DestroyTarget=excluded.DestroyTarget, LootTarget=excluded.LootTarget, Damage2Deal=excluded.Damage2Deal;"]
	}
	; This method will be for inserting information into the MissionLogCombat table. This will also be an upsert.
	; (RunNumber INTEGER PRIMARY KEY, StartingTimestamp DATETIME, MissionName TEXT, MissionType TEXT, RoomNumber INTEGER, KilledTarget BOOLEAN, Vanquisher BOOLEAN, ContainerLooted BOOLEAN, HaveItems BOOLEAN, TechnicalCompletion BOOLEAN, 
	;   TrueCompletion BOOLEAN, FinalTimestamp DATETIME, Historical BOOLEAN);"]
	method MissionLogCombatUpsert(int RunNumber, int64 StartingTimestamp, string MissionName, string MissionType, int RoomNumber, bool KilledTarget, bool Vanquisher, bool ContainerLooted, bool HaveItems, bool TechnicalCompletion, bool TrueCompletion, int64 FinalTimestamp, bool Historical)
	{
		CharacterSQLDB:ExecDMLTransaction["insert into MissionLogCombat (RunNumber,StartingTimestamp,MissionName,MissionType,RoomNumber,KilledTarget,Vanquisher,ContainerLooted,HaveItems,TechnicalCompletion,TrueCompletion,FinalTimestamp,Historical) values (${RunNumber},${StartingTimestamp},'${MissionName}','${MissionType}',${RoomNumber},${KilledTarget},${Vanquisher},${ContainerLooted},${HaveItems},${TechnicalCompletion},${TrueCompletion},${FinalTimestamp},${Historical}) ON CONFLICT (RunNumber) DO UPDATE SET StartingTimestamp=excluded.StartingTimestamp, MissionName=excluded.MissionName, MissionType=excluded.MissionType, RoomNumber=excluded.RoomNumber, KilledTarget=excluded.KilledTarget, Vanquisher=excluded.Vanquisher, ContainerLooted=excluded.ContainerLooted, HaveItems=excluded.HaveItems, TechnicalCompletion=excluded.TechnicalCompletion, TrueCompletion=excluded.TrueCompletion, FinalTimestamp=excluded.FinalTimestamp, Historical=excluded.Historical;"]
	}
	; This method will be for Mid-Combat-Mission Updates
	method MissionLogCombatUpdate(int RunNumber, int RoomNumber, bool KilledTarget, bool Vanquisher, bool ContainerLooted, bool HaveItems, bool TechnicalCompletion, bool TrueCompletion, int64 FinalTimestamp, bool Historical)
	{
		CharacterSQLDB:ExecDMLTransaction["update MissionLogCombat SET RoomNumber=${RoomNumber}, KilledTarget=${KilledTarget}, Vanquisher=${Vanquisher}, ContainerLooted=${ContainerLooted}, HaveItems=${HaveItems}, TechnicalCompletion=${TechnicalCompletion}, TrueCompletion=${TrueCompletion}, FinalTimestamp=${FinalTimestamp}, Historical=${Historical} WHERE RunNumber=${CurrentRunNumber};"]
	}
	; This method will be for inserting information into the MissionLogCourier table. This will also be an upsert.
	; (RunNumber INTEGER PRIMARY KEY, StartingTimestamp DATETIME, MissionName TEXT, MissionType TEXT, TripNumber INTEGER, ExpectedTrips INTEGER,
	;  DropoffLocation TEXT, PickupLocation TEXT, TotalUnits INTEGER, TotalVolume REAL, UnitsMoved INTEGER, VolumeMoved REAL, FinalTimestamp DATETIME, Historical BOOLEAN);"]
	method MissionLogCourierUpsert(int RunNumber, int64 StartingTimestamp, string MissionName, string MissionType, int TripNumber, int ExpectedTrips, string DropoffLocation, string PickupLocation, int TotalUnits, float TotalVolume, int UnitsMoved, float VolumeMoved, int64 FinalTimestamp, bool Historical)
	{
		CharacterSQLDB:ExecDMLTransaction["insert into MissionLogCourier (RunNumber,StartingTimestamp,MissionName,MissionType,TripNumber,ExpectedTrips,DropoffLocation,PickupLocation,TotalUnits,TotalVolume,UnitsMoved,VolumeMoved,FinalTimestamp,Historical) values (${RunNumber},${StartingTimestamp},'${MissionName}','${MissionType}',${TripNumber},${ExpectedTrips},'${DropoffLocation}','${PickupLocation}',${TotalUnits},${TotalVolume},${UnitsMoved},${VolumeMoved},${FinalTimestamp},${Historical}) ON CONFLICT (RunNumber) DO UPDATE SET StartingTimestamp=excluded.StartingTimestamp, MissionName=excluded.MissionName, MissionType=excluded.MissionType, TripNumber=excluded.TripNumber, ExpectedTrips=excluded.ExpectedTrips, DropoffLocation=excluded.DropoffLocation, PickupLocation=excluded.PickupLocation, TotalUnits=excluded.TotalUnits, TotalVolume=excluded.TotalVolume, UnitsMoved=excluded.UnitsMoved, VolumeMoved=excluded.VolumeMoved, FinalTimestamp=excluded.FinalTimestamp, Historical=excluded.Historical;"]
	}
	; This method will be for Mid-CourierMission Updates
	method MissionLogCourierUpdate(int RunNumber, int TripNumber, int UnitsMoved, float VolumeMoved, int64 FinalTimestamp, bool Historical)
	{
		CharacterSQLDB:ExecDMLTransaction["update MissionLogCourier SET TripNumber=${TripNumber}, UnitsMoved=${UnitsMoved}, VolumeMoved=${VolumeMoved}, FinalTimestamp=${FinalTimestamp}, Historical=${Historical} WHERE RunNumber=${CurrentRunNumber};"]
	}
	; This method will be for inserting information into the WatchDogMonitoring table. This will also be an upsert.
	; (CharID INTEGER PRIMARY KEY, RunNumber INTEGER, MissionName TEXT, MissionType TEXT, RoomNumber INTEGER, TripNumber INTEGER, TimeStamp DATETIME, CurrentTarget INTEGER, CurrentDestination TEXT, UnitsMoved INTEGER);"]
	method WatchDogMonitoringUpsert(int64 CharID, int RunNumber, string MissionName, string MissionType, int RoomNumber, int TripNumber, int64 TimeStamp, int64 CurrentTarget, string CurrentDestination, int UnitsMoved)
	{
		SharedSQLDB:ExecDMLTransaction["insert into WatchDogMonitoring (CharID,RunNumber,MissionName,MissionType,RoomNumber,TripNumber,Timestamp,CurrentTarget,CurrentDestination,UnitsMoved) values (${CharID},${RunNumber},'${MissionName}','${MissionType}',${RoomNumber},${TripNumber},${Timestamp},${CurrentTarget},'${CurrentDestination}',${UnitsMoved})  ON CONFLICT (CharID) DO UPDATE SET RunNumber=excluded.RunNumber, MissionName=excluded.MissionName, MissionType=excluded.MissionType, RoomNumber=excluded.RoomNumber, TripNumber=excluded.TripNumber, Timestamp=excluded.Timestamp, CurrentTarget=excluded.CurrentTarget, CurrentDestination=excluded.CurrentDestination, UnitsMoved=excluded.UnitsMoved;"]
	}
	; This method will be for inserting information into the MissioneerStats table. This will be a normal insert, no upserts here.
	; (Timestamp DATETIME, CharName TEXT, CharID INTEGER, RunNumber INTEGER, RoomNumber INTEGER, TripNumber INTEGER, MissionName TEXT, MissionType TEXT, EventType TEXT, RoomBounties REAL, RoomFactionSpawn BOOLEAN,
	;   RoomDuration DATETIME, RunLP INTEGER, RunISK REAL, RunDuration DATETIME, ShipType TEXT);"]
	method MissioneerStatsInsert(int64 Timestamp, string CharName, int64 CharID, int RunNumber, int RoomNumber, int TripNumber, string MissionName, string MissionType, string EventType, float RoomBounties, bool RoomFactionSpawn, int64 RoomDuration, int RunLP, float RunISK, int64 RunDuration, string ShipType)
	{
		SharedSQLDB:ExecDMLTransaction["insert into MissioneerStats (CharName,CharID,RunNumber,RoomNumber,TripNumber,MissionName,MissionType,EventType,RoomBounties,RoomFactionSpawn,RoomDuration,RunLP,RunISK,RunDuration,ShipType) values ('${CharName}',${CharID},${RunNumber},${RoomNumber},${TripNumber},'${MissionName}','${MissionType}','${EventType}',${RoomBounties},${RoomFactionSpawn},${RoomDuration},${RunLP},${RunISK},${RunDuration},'${ShipType}')
	}
	; This method will be for inserting information into the SalvageBMTable table. I don't anticipate this ever needing to be an Upsert.
	; (BMID INTEGER PRIMARY KEY, BMName TEXT, WreckCount INTEGER, BMSystem TEXT, ExpectedExpiration DATETIME, ClaimedByCharID INTEGER, SalvageTime DATETIME, Historical BOOLEAN);"]
	method SalvageBMTableInsert(int64 BMID, string BMName, int WreckCount, string BMSystem, int64 ExpectedExpiration, int64 ClaimedByCharID, int64 SalvageTime, bool Historical)
	{
		SharedSQLDB:ExecDMLTransaction["insert into SalvageBMTable (BMID,BMName,WreckCount,BMSystem,ExpectedExpiration,ClaimedByCharID,SalvageTime,Historical) values (${BMID},'${BMName}',${WreckCount},'${BMSystem}',${ExpectedExpiration},${ClaimedByCharID},${SalvageTime},${Historical};"]
	}
	; This method is just so a salvager can claim a salvage BM. If you have more than one salvager it is kinda needed.
	method SalvageBMTableClaim(int64 CharID, int64 BMID)
	{
		CharacterSQLDB:ExecDMLTransaction["update SalvageBMTable SET ClaimedByCharID=${CharID} WHERE BMID=${BMID};"]
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
				}
			}
			while ${Iter:Next(exists)}
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
				   !${itemIterator.Value.Name.Find["Script"]} 
				   ; Insignias for Extravaganza missions
				   ;!${itemIterator.Value.Name.Find["Diamond"]}
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

			variable float specifiedDroneVolume = ${Drones.Data.GetVolume[${Config.DroneType}]}
			preferredDroneType:Set[${Drones.Data.SearchSimilarDroneFromRace[${Config.DroneType}, ${useDroneRace}]}]
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

			variable float remainingDroneSpace = ${Math.Calc[${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} - ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].UsedCapacity}]}

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
		WalAssurance:Set[TRUE]
	}
	; Stealing this function from evebot and making it into a method instead.
	method ActivateShip(string name)
	{
		variable index:item hsIndex
		variable iterator hsIterator
		variable string shipName

		if ${Me.InStation}
		{
			Me:GetHangarShips[hsIndex]
			hsIndex:GetIterator[hsIterator]

			shipName:Set[${MyShip.Name}]
			if ${shipName.NotEqual[${name}]} && ${hsIterator:First(exists)}
			{
				do
				{
					if ${hsIterator.Value.Name.Equal[${name}]}
					{
						This:LogInfo["Switching to ship named ${hsIterator.Value.Name}."]
						hsIterator.Value:MakeActive
						break
					}
				}
				while ${hsIterator:Next(exists)}
				if ${shipName.NotEqual[${name}]}
				{
					This:LogInfo["We were unable to change to the correct ship. Failure state."]
					FailedToChangeShip:Set[TRUE]
				}
			}
			else
			{
				This:LogInfo["We seem to not have... Any ships? I don't think this can happen tbh"]
				FailedToChangeShip:Set[TRUE]
			}
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