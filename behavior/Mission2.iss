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
	; It is implied you know what you are doing with this.
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
	variable int LastItemUnits
	variable float LastItemVolume
	variable bool LastLowsec
	variable string LastDropoff
	variable string LastPickup
	
	; Storage variables for our Current (selected) Agent
	variable int64 CurrentAgentID
	variable int64 CurrentAgentIndex
	variable string CurrentAgentLocation
	
	
	; Recycled variables from the original
	variable string ammo
	variable string secondaryAmmo
	variable obj_Configuration_Mission2 Config
	variable obj_Configuration_Agents2 Agents
	variable obj_MissionUI2 LocalUI
	variable bool reload = TRUE
	variable bool halt = FALSE
	
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
			; MissionName (string). MissionType (string). MissionStatus (int). Re-using those.
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
				CharacterSQLDB:ExecDML["create table MissionLogCombat (RunNumber INTEGER PRIMARY KEY, StartingTimestamp DATETIME, MissionName TEXT, MissionType TEXT, MissionStatus INTEGER, RoomNumber INTEGER, KilledTarget BOOLEAN, Vanquisher BOOLEAN, ContainerLooted BOOLEAN, HaveItems BOOLEAN, TechnicalCompletion BOOLEAN, TrueCompletion BOOLEAN, FinalTimestamp DATETIME, Historical BOOLEAN);"]
			}
			
			; This table is for keeping track of what we've done during our Courier/Trade missions.
			; RunNumber (int). MissionName (string). StartingTimestamp (int64). MissionType (string). MissionStatus (int). Re-using.
			; To keep track of how many trips we have made. TripNumber (int). To keep track of how many trips we are expected to make. ExpectedTrips (int).
			; To keep track of the dropoff location. DropoffLocation (string). And Pickup Location. PickupLocation (string).
			; To keep track of total units to move. TotalUnits (int). Same but for volume. TotalVolume (float).
			; To keep track of the units we have moved already. UnitsMoved (int). Same but for volume. VolumeMoved (float).
			; Re-using FinalTimestamp (int).
			; Lastly, re-use historical.
			
			if !${CharacterSQLDB.TableExists["MissionLogCourier"]}
			{
				echo DEBUG - Creating Mission Log Courier
				CharacterSQLDB:ExecDML["create table MissionLogCourier (RunNumber INTEGER PRIMARY KEY, StartingTimestamp DATETIME, MissionName TEXT, MissionType TEXT, MissionStatus INTEGER, TripNumber INTEGER, ExpectedTrips INTEGER, DropoffLocation TEXT, PickupLocation TEXT,, TotalUnits INTEGER, TotalVolume REAL, UnitsMoved INTEGER, VolumeMoved REAL, FinalTimestamp DATETIME, Historical BOOLEAN);"]
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
					This:LogInfo["Ignoring Lowsec Mission Offer"]
					GetDBJournalInfo:NextRow
					continue
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
				if ( ${GetDBJournalInfo.GetFieldValue["ItemVolume",float]} > 1000 ) && !${Config.CourierShipName.NotNULLOrEmpty}
				{	
					This:LogInfo["High Volume and No Hauler Configured - Declining"]
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
			CurrentAgentID:Set[${GetDBJournalInfo.GetFieldValue["AgentID",int64]}]
			CurrentAgentLocation:Set[${GetDBJournalInfo.GetFieldValue["AgentLocation",string]}]
			CurrentAgentIndex:Set[${EVE.Agent[id,${CurrentAgentID}].Index}]
			GetDBJournalInfo:Finalize
			This:QueueState["Go2Agent", 5000]
			return TRUE
		}
		GetDBJournalInfo:Finalize
		; Everything else.
		GetDBJournalInfo:Set${CharacterSQLDB.ExecQuery["SELECT * FROM MissionJournal;"]}]
		if ${GetDBJournalInfo.NumRows} > 0
		{
			CurrentAgentID:Set[${GetDBJournalInfo.GetFieldValue["AgentID",int64]}]
			CurrentAgentLocation:Set[${GetDBJournalInfo.GetFieldValue["AgentLocation",string]}]
			CurrentAgentIndex:Set[${EVE.Agent[id,${CurrentAgentID}].Index}]			
			GetDBJournalInfo:Finalize
			This:QueueState["Go2Agent", 5000]
			return TRUE
		}
		else
		{
			This:LogInfo["No Valid Offered Missions - Default to Datafile Agent"]
			CurrentAgentID:Set[${EVE.Agent[${AgentList.Get[1]}].ID}]
			CurrentAgentLocation:Set[${EVE.Agent[${AgentList.Get[1]}].Station}]
			CurrentAgentIndex:Set[${EVE.Agent[${AgentList.Get[1]}].Index}]
			This:QueueState["Go2Agent", 5000]
			return TRUE
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
			This:QueueState["InitialAgentInteraction", 5000]
			return TRUE
		}
		else
		{
			;Already there I guess.
			This:QueueState["InitialAgentInteraction", 5000]
			return TRUE		
		}
	}
	; This state will be where we interact with our Agents outside of the little we did to achieve databasification. This will be the initial interaction.
	; This state will also be where, after accepting a mission, we put our initial MissionLog entry in whatever table it belongs.
	member:bool InitialAgentInteraction()
	{
	
		if ${GetDBJournalInfo.GetFieldValue["PickupLocation",string].NotNULLOrEmpty}
	}
	; This state will be where we prep our ship for the mission. Load ammo/drones, etc.
	member:bool MissionPrep()
	{
	
	
	}
	; This state will be the primary logic for a Combat Mission
	member:bool CombatMission()
	{
		GetMissionLogCombat:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionLogCombat WHERE Historical=FALSE;"]}]
	
	
	}
	; This state will be the primary logic for a Courier Mission. I say courier mission, but I really mean Non-Combat Mission
	; Trade missions will also be included here.
	member:bool CourierMission()
	{
		GetMissionLogCourier:Set[${CharacterSQLDB.ExecQuery["SELECT * FROM MissionLogCourier WHERE Historical=FALSE;"]}]
	
	
	}
	; This state will be where we do our finishing interaction with our Agent. This comes at mission completion.
	; This is also where we, when we turn in the mission, do our final MissionLog entry in whatever table it belongs to.
	; We will set that row to Historical, update any final details that need to be updated, clean up any variables that need cleaning up.
	member:bool FinishAgentInteraction()
	{
	
	
	}
	; This state will be where we kick off our station interaction stuff. Repairs, loot dropoff, etc.
	; After this state we should go back to CheckForWork.
	member:bool BeginCleanup()
	{
	
	
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
			LasItemVolume:Set[0]
	
	}
	; This method will be for inserting information into the MissionJournal table. This will naturally be an Upsert.
	; (AgentID INTEGER PRIMARY KEY, MissionName TEXT, MissionType TEXT, MissionStatus INTEGER, AgentLocation TEXT, MissionLocation TEXT, DropoffLocation TEXT, PickupLocation TEXT, Lowsec BOOLEAN, JumpDistance INTEGER, ExpectedItems TEXT, ItemUnits INTEGER, ItemVolume REAL,
	;   VolumePer REAL, DestroyTarget TEXT, LootTarget TEXT, Damage2Deal TEXT);"]
	method MissionJournalUpsert(int64 AgentID, string MissionName, string MissionType, int MissionStatus, string AgentLocation, string MissionLocation, string DropoffLocation, string PickupLocation, bool Lowsec, int JumpDistance, string ExpectedItems, int ItemUnits, float ItemVolume, float VolumePer, string DestroyTarget, string LootTarget, string Damage2Deal)
	{
		DML:Insert["insert into MissionJournal (AgentID,MissionName,MissionType,MissionStatus,AgentLocation,MissionLocation,DropoffLocation,PickupLocation,Lowsec,JumpDistance,ExpectedItems,ItemUnits,ItemVolume,VolumePer,DestroyTarget,LootTarget,Damage2Deal) values (${AgentID}, '${MissionName}', '${MissionType}', ${MissionStatus}, '${AgentLocation}', '${MissionLocation}', '${DropoffLocation}', '${PickupLocation}', ${Lowsec}, ${JumpDistance}, '${ExpectedItems}', ${ItemUnits}, ${ItemVolume}, ${VolumePer}, '${DestroyTarget}','${Damage2Deal}') ON CONFLICT (AgentID) DO UPDATE SET MissionName=excluded.MissionName, MissionType=excluded.MissionType, MissionStatus=excluded.MissionStatus, AgentLocation=excluded.AgentLocation, MissionLocation=excluded.MissionLocation, DropoffLocation=excluded.DropoffLocation, PickupLocation=excluded.PickupLocation, Lowsec=excluded.Lowsec, Jumpdistance=excluded.JumpDistance, ExpectedItems=excluded.ExpectedItems, ItemUnits=excluded.ItemUnits, ItemVolume=excluded.ItemVolume, VolumePer=excluded.VolumePer, DestroyTarget=excluded.DestroyTarget, LootTarget=excluded.LootTarget, Damage2Deal=excluded.Damage2Deal;"]
		; Execute transaction 
		CharacterSQLDB:ExecDMLTransaction[DML]	
	}
	; This method will be for inserting information into the MissionLogCombat table. This will also be an upsert.
	; (RunNumber INTEGER PRIMARY KEY, StartingTimestamp DATETIME, MissionName TEXT, MissionType TEXT, MissionStatus INTEGER, RoomNumber INTEGER, KilledTarget BOOLEAN, Vanquisher BOOLEAN, ContainerLooted BOOLEAN, HaveItems BOOLEAN, TechnicalCompletion BOOLEAN, 
	;   TrueCompletion BOOLEAN, FinalTimestamp DATETIME, Historical BOOLEAN);"]
	method MissionLogCombatUpsert()
	{
	
	
	}
	; This method will be for inserting information into the MissionLogCourier table. This will also be an upsert.
	; (RunNumber INTEGER PRIMARY KEY, StartingTimestamp DATETIME, MissionName TEXT, MissionType TEXT, MissionStatus INTEGER, TripNumber INTEGER, ExpectedTrips INTEGER,
	;  DropoffLocation TEXT, PickupLocation TEXT, TotalUnits INTEGER, TotalVolume REAL, UnitsMoved INTEGER, VolumeMoved REAL, FinalTimestamp DATETIME, Historical BOOLEAN);"]
	method MissionLogCourierUpsert()
	{
	
	
	}
	; This method will be for inserting information into the WatchDogMonitoring table. This will also be an upsert.
	; (CharID INTEGER PRIMARY KEY, RunNumber INTEGER, MissionName TEXT, MissionType TEXT, RoomNumber INTEGER, TripNumber INTEGER, TimeStamp DATETIME, CurrentTarget INTEGER, CurrentDestination TEXT, UnitsMoved INTEGER);"]
	method WatchDogMonitoringUpsert()
	{
	
	
	
	}
	; This method will be for inserting information into the MissioneerStats table. This will be a normal insert, no upserts here.
	; (Timestamp DATETIME, CharName TEXT, CharID INTEGER, RunNumber INTEGER, RoomNumber INTEGER, TripNumber INTEGER, MissionName TEXT, MissionType TEXT, EventType TEXT, RoomBounties REAL, RoomFactionSpawn BOOLEAN,
	;   RoomDuration DATETIME, RunLP INTEGER, RunISK REAL, RunDuration DATETIME, ShipType TEXT);"]
	method MissioneerStatsInsert()
	{
	
	
	}
	; This method will be for inserting information into the SalvageBMTable table. I don't anticipate this ever needing to be an Upsert.
	; (BMID INTEGER PRIMARY KEY, BMName TEXT, WreckCount INTEGER, BMSystem TEXT, ExpectedExpiration DATETIME, ClaimedByCharID INTEGER, SalvageTime DATETIME, Historical BOOLEAN);"]
	method SalvageBMTableInser()
	{
	
	
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


	; I have absofuckinglutely no idea what this is or does. I'm 98% sure it is never called by anything, so let's leave it here
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