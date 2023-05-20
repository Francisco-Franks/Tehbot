
objectdef obj_Configuration_Observer inherits obj_Configuration_Base
{
	method Initialize()
	{
		This[parent]:Initialize["Observer"]
	}

	method Set_Default_Values()
	{
		ConfigManager.ConfigRoot:AddSet[${This.SetName}]

	}

	Setting(bool, Halt, SetHalt)
	; We intend to do nothing more than watch local.
	Setting(bool, LocalWatchOnly, SetLocalWatchOnly)
	; This is the Bookmark we intend to watch local from.
	Setting(string, LocalWatchOnlyName, SetLocalWatchOnlyName)
	; We intend to watch local from within a station
	Setting(bool, StationPost, SetStationPost)
	; We intend to watch a Structure
	Setting(bool, StructureWatch, SetStructureWatch)
	; Name of the Structure (Bookmark)
	Setting(string, StructureWatchName, SetStructureWatchName)
	; We intend to watch a specific Grid (Bookmark)
	Setting(bool, GridWatch, SetGridWatch)
	; Name of that Grid (Bookmark)
	Setting(string, GridWatchName, SetGridWatchName)
	; We intend to watch Wormholes in a Single Wormhole System. This implies A) We are running multiple watchers
	; on a single machine and B) We want the observers to move to new wormholes as they exist / leave bookmarks as
	; they expire.
	Setting(bool, WormholeSystemWatch, SetWormholeSystemWatch)
	; We intend to watch a Gate
	Setting(bool, GateWatch, SetGateWatch)
	; Gate name (Bookmark)
	Setting(string, GateWatchName, SetGateWatchName)
	; Relay information to Chat Minimode
	Setting(bool, RelayToChat, SetRelayToChat)
	; This bool will have us relay more information about things to the chat relay.
	Setting(bool, SPORTSMode, SetSPORTSMode)
	; This string will be for your HomeBase bookmarks
	Setting(string, HomeBase, SetHomeBase)
	; How far should we orbit from our Observed Object? Doesn't apply for Grid Watch / Station Watch.
	; This integer is in Meters, and you can actually make this an absurdly huge number if you want.
	; Keep in mind that grids are only so far across. Also I can't guarantee that CCP doesn't look at this.
	; There is no normal way to make a client start orbiting at 5,000KM except by already being at 5,000KM.
	Setting(int, OrbitDistance, SetOrbitDistance)	
	; This string will be your prefix for Evasive bookmarks. The things we go to when we get decloaked during observation. I recommend having at least 4.
	Setting(string, EvasiveBookmarkPrefix, SetEvasiveBookmarkPrefix)
	; This bool indicates we want to use SQLite integration. More information tracking will be available and displayed. If I can figure it out.
	Setting(bool, SQLiteIntegration, SetSQLiteIntegration)


}

objectdef obj_Observer inherits obj_StateQueue
{


	variable obj_Configuration_Observer Config
	variable obj_ObserverUI LocalUI
	; This is used to figure out if multiple observers are on the same WH bm
	variable int64 MyCurrentBMID
	; This is used to figure out if we need to leave our current position.
	variable bool NeedToScram
	; This bool says we are currently in evasion mode
	variable bool InEvasion
	
	; This collection will hold the bookmarks that aren't filtered out immediately. Key is label, value is BookmarkID.
	variable collection:int64 LargeBookmarkCollection
	; This collection will hold the bookmarks that are Claimed. Key is Bookmark ID, value is CharID
	variable collection:int64 ClaimedBookmarkCollection
	; This will be the timer for the holding pattern
	variable int64 HoldingPatternTimer
	; This will hold the entity ID of the thing we need to orbit at our observation point
	variable int64 EntityIDToOrbit
	
	; This collection will hold the highest standing (alliance to alliance, corp to corp, person to corp, etc) that a local pilot has relative to us.
	; Key will be the Character ID (if I can get away with cramming an int64 into a string type field) and the Value INT will be the highest standing we have to them.
	variable collection:int HighestLocalStandingCollection

	; This collection will hold the highest standing of on grid entities
	; Key will be the Character ID, INT value will be the highest standing.
	variable collection:int HighestOnGridStandingCollection
	
	; This collection will hold the current people in local for tracking entrances and exits. Key will be Name, Int64 will be a timestamp of when they arrived(ish)
	variable collection:int64 CurrentLocalPopCollection

	; This collection will hold current on-grid entities. Key is Pilot Name, int64 will be a timestamp of when they arrived(ish).
	variable collection:int64 OnGridEntitiesCollection
	
	; This string will contain the name of either the bookmark we are observing or the name of the entity we are orbiting.
	variable string LocationSet

	; This string will contain Supplementary Information provided by SQL Integration for our chat messages.
	variable string SupplementaryInfo
	
	; index where we place our strings for SQL execution
	variable index:string DML
	; might need this here again
	variable sqlitequery GetCharacterInfoByID
	variable sqlitequery GetCharacterInfoByName
	variable int64 LastExecute
	


	method Initialize()
	{
		This[parent]:Initialize

		DynamicAddBehavior("Observer", "Observer")
		This.PulseFrequency:Set[3500]

		This.LogInfoColor:Set["g"]
		This.LogLevelBar:Set[${Config.LogLevelBar}]

		LavishScript:RegisterEvent[Tehbot_ScheduleHalt]
		Event[Tehbot_ScheduleHalt]:AttachAtom[This:ScheduleHalt]
		
		LavishScript:RegisterEvent[Tehbot_ScheduleResume]
		Event[Tehbot_ScheduleResume]:AttachAtom[This:ScheduleResume]
		
		LavishScript:RegisterEvent[ClaimBookmark]
		Event[ClaimBookmark]:AttachAtom[This:ClaimBookmarkEvent]		

		LavishScript:RegisterEvent[UnClaimBookmark]
		Event[UnClaimBookmark]:AttachAtom[This:UnClaimBookmarkEvent]

		LavishScript:RegisterEvent[CurrentlyObservingBM]
		Event[CurrentlyObservingBM]:AttachAtom[This:CurrentlyObservingBMEvent]		
		
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

	; Why did I make 2 events that do the exact same goddamn thing?
	method ClaimBookmarkEvent(int64 ClaimKey, int64 ClaimValue)
	{
		ClaimedBookmarkCollection:Set[${ClaimKey},${ClaimValue}]
	}
	
	method UnClaimBookmarkEvent(int64 UnClaimKey, int64 UnClaimValue)
	{
		ClaimedBookmarkCollection:Set[${ClaimKey},${ClaimValue}]
	}
	
	method CurrentlyObservingBMEvent(int64 BMID, int64 CharacterID)
	{
		if ${BMID} == ${MyCurrentBMID}
		{
			if ${CharacterID} != ${Me.CharID}
			{
				if ${CharacterID} > ${Me.CharID}
				{
				NeedToScram:Set[TRUE]
				}
			}
		}
	}
	
	
	method Start()
	{

		EVE:RefreshStandings
		
		if ${This.IsIdle}
		{
			This:LogInfo["Starting"]
			This:QueueState["CheckForWork", 5000]
			EVE:RefreshBookmarks
		}
		if ${ISXSQLite.IsReady}
		{
			if !${ISXSQLiteTest.TheSQLDatabase.TableExists["WatcherFiles"]}
			{
				echo DEBUG - Creating The Watcher Files
				ISXSQLiteTest.TheSQLDatabase:ExecDML["create table WatcherFiles (CharID INTEGER, IncidentType TEXT, CharacterName TEXT, CorporationID INTEGER, AllianceID INTEGER, CorpName TEXT, CorpTicker TEXT, AllianceName TEXT, AllianceTicker TEXT, Timestamp DATETIME, ShipType TEXT, LocationSystem TEXT, LocationNearest TEXT);"]
			}		
		
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

	}


	; Subverting this old chestnut for my own purposes. In here is where our direction mostly comes from.
	; Where are we, whats our current state, what should we do next.
	member:bool CheckForWork()
	{
		; We are in space, and in warp, return false so we can wait for the warp to end.
		if ${Client.InSpace} && ${Me.ToEntity.Mode} == MOVE_WARPING
		{
			return FALSE
		}
		; We are in space, in a pod. Might figure out something more complicated for this later.
		if ${Client.InSpace} && ${MyShip.ToEntity.Type.Equal[Capsule]}
		{
			This:LogInfo["We dead"]
			This:InsertState["GoToStation"]
			This:Stop
		}
		; We are in station, in a pod. Might figure out something more complicated for this later.
		if ${Me.InStation} && ${MyShip.ToItem.Type.Equal[Capsule]}
		{
			This:LogInfo["We dead"]
			This:Stop
		}
		; We are in station, and at our post. We are doing Local Observation Only.
		if ${Me.InStation} && ${This.AtPost}
		{
			This:LogInfo["Commence Watch from Station"]
			This:QueueState["BeginObservation", 5000]
			return TRUE
		}
		; We are in space, but not at our post.
		if ${Client.InSpace} && !${This.AtPost}
		{
			This:LogInfo["Status Check"]
			This:InsertState["FindPost", 5000]
			return TRUE
		}
		; We are at our observation point, begin the observation
		if ${Client.InSpace} && ${This.AtPost}
		{
			This:LogInfo["We appear to be at the right place"]
			This:QueueState["BeginObservation", 5000]
			return TRUE
		}
		; We have hit the halt button, might want to like, stop the bot or something.
		if ${Me.InStation} && (${Config.Halt} || ${Halt})
		{
			This:LogInfo["Halt Requested"]
			This:InsertState["HaltBot"]
			return TRUE
		}
	}

	; We need to go to station
	member:bool GoToStation()
	{
		if ${Config.HomeBase.NotNULLOrEmpty}
		{
			Move:Bookmark["${Config.HomeBase}"]
			return TRUE
		}
		else
		{
			This:LogInfo["HomeBase BM not found, stopping"]
			This:Stop
		}
	}
	; We will use this to get to our Observation Post
	member:bool FindPost()
	{	
		; We are here just to watch local and report on pilot entries and exits. If you are somewhere without local I am not doing
		; A sanity check for that.
		if ${Config.LocalWatchOnly}
		{
			if ${Config.LocalWatchOnlyName.NotNULLOrEmpty}
			{
				This:LogInfo["Moving to ${Config.LocalWatchOnlyName}"]
				EVE.Bookmark[${Config.LocalWatchOnlyName}]:WarpTo[100000]
				return TRUE
			}
			else
			{
				This:LogInfo["Local Watch BM Not Found, stopping"]
				This:Stop				
			}
		}
		; We are here to watch a specific Structure, and its grid. We will report on pilots on grid.
		if ${Config.StructureWatch}
		{
			if ${Config.StructureWatchName.NotNULLOrEmpty}
			{
				This:LogInfo["Moving to ${Config.StructureWatchName}"]			
				EVE.Bookmark[${Config.StructureWatchName}]:WarpTo[100000]
				return TRUE
			}
			else
			{
				This:LogInfo["Structure Watch BM Not Found, stopping"]
				This:Stop					
			}
		}
		; We are here to watch an entire wormhole system, we will shuffle between bookmarks and watch the grids at them
		; This is going to be substantially more complicated, or is it? So basically, we will have a large set of prefixes
		; C1,C2,Etc. If your bookmark contains one of those and it is in your current solar system then it is put in the large
		; bookmark collection. Then we will run the IDs of those bookmarks against a second collection which defines which
		; client on the machine owns that bookmark (if any). If it either matches your own char ID, or is 0, we will claim it
		; then warp to it. It will be up to other code to release claims as we go, that basically never comes up though.
		if ${Config.WormholeSystemWatch}
		{
			variable index:bookmark WormholeBookmarks
			variable iterator BookmarkIterator
			EVE:GetBookmarks[WormholeBookmarks]
			
			WormholeBookmarks:RemoveByQuery[${LavishScript.CreateQuery[SolarSystemID != "${Me.SolarSystemID}"]}, TRUE]	
			WormholeBookmarks:Collapse
			WormholeBookmarks:GetIterator[BookmarkIterator]
			
			
			if ${BookmarkIterator:First(exists)}
			{
				do
				{	
					; We are adding all bookmarks with the genericest wormhole identifier prefixes I can think of.
					; If these don't match what you need then change em yourself.
					if ${BookmarkIterator.Value.Label.Find["C1"]}
					{
						LargeBookmarkCollection:Set[${BookmarkIterator.Value.Label},${BookmarkIterator.Value.ID}]
						This:LogInfo["Adding Bookmark to Collection - ${BookmarkIterator.Value.Label}"]
					}
					if ${BookmarkIterator.Value.Label.Find["C2"]}
					{
						LargeBookmarkCollection:Set[${BookmarkIterator.Value.Label},${BookmarkIterator.Value.ID}]
						This:LogInfo["Adding Bookmark to Collection - ${BookmarkIterator.Value.Label}"]
					}
					if ${BookmarkIterator.Value.Label.Find["C3"]}
					{
						LargeBookmarkCollection:Set[${BookmarkIterator.Value.Label},${BookmarkIterator.Value.ID}]
						This:LogInfo["Adding Bookmark to Collection - ${BookmarkIterator.Value.Label}"]
					}
					if ${BookmarkIterator.Value.Label.Find["C4"]}
					{
						LargeBookmarkCollection:Set[${BookmarkIterator.Value.Label},${BookmarkIterator.Value.ID}]
						This:LogInfo["Adding Bookmark to Collection - ${BookmarkIterator.Value.Label}"]
					}
					if ${BookmarkIterator.Value.Label.Find["C5"]}
					{
						LargeBookmarkCollection:Set[${BookmarkIterator.Value.Label},${BookmarkIterator.Value.ID}]
						This:LogInfo["Adding Bookmark to Collection - ${BookmarkIterator.Value.Label}"]
					}
					if ${BookmarkIterator.Value.Label.Find["C6"]}
					{
						LargeBookmarkCollection:Set[${BookmarkIterator.Value.Label},${BookmarkIterator.Value.ID}]
						This:LogInfo["Adding Bookmark to Collection - ${BookmarkIterator.Value.Label}"]
					}
					if ${BookmarkIterator.Value.Label.Find["C12"]}
					{
						LargeBookmarkCollection:Set[${BookmarkIterator.Value.Label},${BookmarkIterator.Value.ID}]
						This:LogInfo["Adding Bookmark to Collection - ${BookmarkIterator.Value.Label}"]
					}
					if ${BookmarkIterator.Value.Label.Find["C13"]}
					{
						LargeBookmarkCollection:Set[${BookmarkIterator.Value.Label},${BookmarkIterator.Value.ID}]
						This:LogInfo["Adding Bookmark to Collection - ${BookmarkIterator.Value.Label}"]
					}
					if ${BookmarkIterator.Value.Label.Find["TR"]}
					{
						LargeBookmarkCollection:Set[${BookmarkIterator.Value.Label},${BookmarkIterator.Value.ID}]
						This:LogInfo["Adding Bookmark to Collection - ${BookmarkIterator.Value.Label}"]
					}
					if ${BookmarkIterator.Value.Label.Find["NS"]}
					{
						LargeBookmarkCollection:Set[${BookmarkIterator.Value.Label},${BookmarkIterator.Value.ID}]
						This:LogInfo["Adding Bookmark to Collection - ${BookmarkIterator.Value.Label}"]
					}
					if ${BookmarkIterator.Value.Label.Find["NS"]}
					{
						LargeBookmarkCollection:Set[${BookmarkIterator.Value.Label},${BookmarkIterator.Value.ID}]
						This:LogInfo["Adding Bookmark to Collection - ${BookmarkIterator.Value.Label}"]
					}
					if ${BookmarkIterator.Value.Label.Find["LS"]}
					{
						LargeBookmarkCollection:Set[${BookmarkIterator.Value.Label},${BookmarkIterator.Value.ID}]
						This:LogInfo["Adding Bookmark to Collection - ${BookmarkIterator.Value.Label}"]
					}
				}
				while ${BookmarkIterator:Next(exists)}
			}			
			; And now we will take our Large Bookmark Collection and remove anything that is claimed, but not claimed by us.
			if ${LargeBookmarkCollection.FirstKey(exists)}
				do
				{
					; I lied, first we will see if we are already sitting on a wormhole. 
					if ${EVE.Bookmark[${LargeBookmarkCollection.CurrentKey}].ToEntity.Distance} < ${Math.Calc[${Config.OrbitDistance} * 2]}
					{
						This:LogInfo["We appear to already be at a Wormhole Bookmark."]
						if ${Entity[GroupID == 988](exists)} && ${Entity[GroupID == 988].Distance} < ${Math.Calc[${Config.OrbitDistance} * 2]}
						{
							Move:Orbit[${Entity[GroupID == 988]},${Script[Tehbot].VariableScope.Observer.Config.OrbitDistance}]
							This:LogInfo["Orbiting Wormhole"]
							LocationSet:Set[${EVE.Bookmark[${LargeBookmarkCollection.CurrentKey}].Label}]
							relay all "Event[ClaimBookmark]:Execute[${LargeBookmarkCollection.CurrentValue},${Me.CharID}]"
							This:InsertState["CheckForWork", 5000]
							return TRUE
						}
						elseif !${Entity[GroupID == 988](exists)}
						{
							This:LogInfo["Nothing here"]
							; We will just have the BM be claimed by whoever char ID 9999999999999999999999999999 is. To hell with that guy.
							relay all "Event[ClaimBookmark]:Execute[${LargeBookmarkCollection.CurrentValue},999999999999999999999999999999999999]"
						}
					}
					; Heres where I get the chance to mess up this logic. If we have a bookmark in the large collection, we want to compare
					; its current value to a key in ClaimedBookmarkCollection. If there is a match, see if the Char ID is ours, or 0. If it is
					; then we will still go to it, otherwise we stop considering it.
					if ${ClaimedBookmarkCollection.Element[${LargeBookmarkCollection.CurrentValue}](exists)} && (${ClaimedBookmarkCollection.Element[${LargeBookmarkCollection.CurrentValue}].AsJSON} == ${Me.CharID} || \
					${ClaimedBookmarkCollection.Element[${LargeBookmarkCollection.CurrentValue}].AsJSON} == 0)
					{
						EVE.Bookmark[${LargeBookmarkCollection.CurrentKey}]:WarpTo[100000]
						This:LogInfo["Moving to ${LargeBookmarkCollection.CurrentKey}"]
						relay all "Event[ClaimBookmark]:Execute[${LargeBookmarkCollection.CurrentValue},${Me.CharID}]"
						This:InsertState["CheckForWork", 5000]
						return TRUE						
					}
					
				}
				while ${LargeBookmarkCollection.NextKey(exists)}
			; Alright so if we ended up here, there are no BMs, or no unclaimed BMs. We will instead enter a holding pattern somewhere awaiting a new unclaimed bookmark.
			HoldingPatternTimer:Set[${Math.Calc[${LavishScript.RunningTime} + ${Math.Rand[30000]:Inc[30000]}]}]
			This:InsertState["HoldingPattern", 5000]
			return TRUE
		}
		; We are here to watch a specific gate, and its grid. We will report on pilots on grid.
		if ${Config.GateWatch}
		{
			if ${Config.GateWatchName.NotNULLOrEmpty}
			{
				This:LogInfo["Moving to ${Config.GateWatchName}"]				
				EVE.Bookmark[${Config.GateWatchName}]:WarpTo[100000]
				This:InsertState["CheckForWork", 5000]
				return TRUE
			}
			else
			{
				This:LogInfo["Gate Watch BM Not Found, stopping"]
				This:Stop					
			}
		}
		This:InsertState["CheckForWork", 5000]
		return TRUE
	}
	
	; This is where the bulk of observer logic will go.
	member:bool BeginObservation()
	{
		; We are in space, and in warp, return false so we can wait for the warp to end.
		if !${Me.InStation}
		{
			if ${Client.InSpace} && ${Me.ToEntity.Mode} == MOVE_WARPING
			{
				return FALSE
			}
		}
		if ${NeedToScram}
		{
			LocationSet:Set[""]
			This:InsertState["CheckForWork", 5000]
			return TRUE
		}
		; Something went wrong here
		if !${This.AtPost} && !${InEvasion}
		{
			This:QueueState["CheckForWork", 10000]
			return TRUE
		}
		; Execute those DB inserts
		if (${LastExecute} < ${LavishScript.RunningTime}) && ${DML.Used}
		{
			This:ExecuteTransactionIndex
		}
		; We have suddenly become decloaked while doing observation. Thats bad.
		if !${Me.InStation}
		{
			if ${Client.InSpace} && !${Me.ToEntity.IsCloaked} && !${InEvasion} 
			{
				InEvasion:Set[TRUE]
				This:InsertState["GoEvasive", 1000]
				return TRUE
			}
		}
		; Observe in station, local only OR Observe in space, local only OR we are on evasion and still want to keep a local watch. No case for wormholes, it can't happen.
		if ( ${Me.InStation} && ${Config.StationPost} ) || ( ${Client.InSpace} && ${Config.LocalWatchOnly} ) || ${InEvasion}
		{
			if !${Me.InStation}
			{
				if ${Me.ToEntity.IsCloaked}
				{
					InEvasion:Set[FALSE]
				}
			}
			; No maneuvering worries here
			This:UpdateLocalStandingCollection
			This:UpdateLocalPopCollection
		}
		; Observe a grid, local and grid
		if ${Client.InSpace} && ${Config.GridWatch}
		{
			; We are on grid and not maneuvering because no need to.
			LocationSet:Set[${Config.GridWatchName}]
			This:UpdateLocalStandingCollection
			This:UpdateLocalPopCollection
			This:UpdateOnGridCollection
		}
		; Observe a gate, local and grid
		if ${Client.InSpace} && ${Config.GateWatch}
		{
			; We should establish an orbit around the Stargate.
			if ${Entity[GroupID == 10 && Distance < ${Math.Calc[${Config.OrbitDistance} * 2]}](exists)} && ${Me.ToEntity.Mode} != MOVE_ORBITING
			{
				Move:Orbit[${Entity[GroupID == 10 && Distance < ${Math.Calc[${Script[Tehbot].VariableScope.Observer.Config.OrbitDistance} * 2]}]}, ${Script[Tehbot].VariableScope.Observer.Config.OrbitDistance}]
				LocationSet:Set[${Config.GateWatchName}]
			}
			This:UpdateLocalStandingCollection
			This:UpdateLocalPopCollection
			This:UpdateOnGridCollection
			
		}
		; Observe a structure, local and grid
		if ${Client.InSpace} && ${Config.StructureWatch}
		{
			; We should establish an orbit around the Structure.
			if ${Entity[(CategoryID == 3 || CategoryID == 65) && Distance < 5000000](exists)} && ${Me.ToEntity.Mode} != MOVE_ORBITING
			{
				Move:Orbit[${Entity[(CategoryID == 3 || CategoryID == 65) && Distance < 2500000]}, ${Script[Tehbot].VariableScope.Observer.Config.OrbitDistance}]
				LocationSet:Set[${Entity[(CategoryID == 3 || CategoryID == 65) && Distance < 2500000].Name}
			}
			This:UpdateLocalStandingCollection
			This:UpdateLocalPopCollection
			This:UpdateOnGridCollection
		}
		; Observe a wormhole, grid only
		if ${Client.InSpace} && ${Config.WormholeSystemWatch}
		{
			; Orbit should already be established
			This:UpdateOnGridCollection
			relay all "Event[CurrentlyObservingBM]:Execute[${EVE.Bookmark[${LocationSet}].ID},${Me.CharID}]"
			if !${Entity[GroupID == 988](exists)}
			{
				This:LogInfo["Wormhole @ ${LocationSet} has expired"]
				relay all "Event[UnClaimBookmark]:Execute[${EVE.Bookmark[${LocationSet}].ID},999999999999999999]"
				LocationSet:Set[""]
				This:InsertState["CheckForWork", 5000]
				return TRUE
			}
		}

		return FALSE
	}
	
	; This is where we enter a holding pattern from the Wormhole Bookmark Finder if we can't find anything unclaimed.
	; We will periodically check to see if the number of bookmarks in system has increased. If yes then we will go back to
	; Find Post. Actually theres no real gain to be had by checking bookmark numbers that way. Its almost exactly as expensive to just kick
	; over to Find Post. So lets just have a random 30 to 60 second wait do the job for us.
	member:bool HoldingPattern()
	{
		if ${LavishScript.RunningTime} < ${HoldingPatternTimer}
		{
			return FALSE
		}
		else
		{
			This:InsertState["FindPost", 5000]
			return TRUE
		}
	
	}
	; Alright so, remembering that mobile observatory things exist. If for whatever reason we suddenly become decloaked we will immediately take off on a warp.
	member:bool GoEvasive()
	{
		if ${Config.EvasiveBookmarkPrefix.NotNULLOrEmpty}
		{
			variable index:bookmark EvasiveBookmarks
			variable iterator BookmarkIterator
			EVE:GetBookmarks[EvasiveBookmarks]
			EvasiveBookmarks:RemoveByQuery[${LavishScript.CreateQuery[SolarSystemID != "${Me.SolarSystemID}"]}, TRUE]	
			EvasiveBookmarks:Collapse		
			EvasiveBookmarks:GetIterator[BookmarkIterator]

			if ${BookmarkIterator:First(exists)}
			{
				do
				{	
					if ${BookmarkIterator.Value.Label.Find[${Config.EvasiveBookmarkPrefix}]}
					{
						EVE.Bookmark[${BookmarkIterator.Value}]:WarpTo[100000]
						This:LogInfo["Warping to Evasion BM"]
						This:InsertState["BeginObservation", 5000]
						return TRUE
					}
				}
				while ${BookmarkIterator:Next(exists)}
			}		
		}
		else
		{
			echo you really need to set up the prefix yo
			variable int ShitGarbage
			ShitGarbage:Set[${Math.Rand[5]}]
			if ${ShitGarbage} == 0
			{
				Move:Entity[${Entity[Name =- "Sun"]},100000,FALSE]
				This:InsertState["BeginObservation", 5000]
				return TRUE
			}
			if ${ShitGarbage} == 1
			{
				Move:Entity[${Entity[Name =- "Planet"]},100000,FALSE]
				This:InsertState["BeginObservation", 5000]
				return TRUE
			}
			if ${ShitGarbage} == 2
			{
				Move:Entity[${Entity[Name =- "Moon"]},100000,FALSE]
				This:InsertState["BeginObservation", 5000]
				return TRUE
			}
			if ${ShitGarbage} == 3
			{
				Move:Entity[${Entity[Name =- "Belt"]},100000,FALSE]
				This:InsertState["BeginObservation", 5000]
				return TRUE
			}
			if ${ShitGarbage} == 4
			{
				Move:Entity[${Entity[Name =- "Moon"]},100000,FALSE]
				This:InsertState["BeginObservation", 5000]
				return TRUE
			}
		}
	}
	; Are we at our observation post? NOT A STATE. Just a bool.
	member:bool AtPost()
	{
		if ${Me.InStation} && ${Config.StationPost}
		{
			return TRUE
		}
		if !${Client.InSpace} && !${Config.StationPost}
		{
			return FALSE
		}
		; We hang around near our local watch BM.
		if ${Config.LocalWatchOnly}
		{
			if ${Config.LocalWatchOnlyName.NotNULLOrEmpty}
			{
				; If the BM is within 1,000KM we are in position.
				if ${EVE.Bookmark[${Config.StructureWatchName}].ToEntity.Distance} < 1000000
				{
					return TRUE
				}
				else
				{
					return FALSE
				}
			}
			else
			{
				This:LogInfo["Local Watch BM Not Found, stopping"]
				This:Stop				
			}
		}
		; We are watching a structure BM, are we near the structure BM.
		if ${Config.StructureWatch}
		{
			if ${Config.StructureWatchName.NotNULLOrEmpty}
			{
				; If the BM is within 2x our orbit distance we are in position
				if ${EVE.Bookmark[${Config.StructureWatchName}].ToEntity.Distance} < ${Math.Calc[${Config.OrbitDistance} * 2]}
				{
					return TRUE
				}
				else
				{
					return FALSE
				}
			}
			else
			{
				This:LogInfo["Structure Watch BM Not Found, stopping"]
				This:Stop					
			}
		}
		; Are we near a wormhole?
		if ${Config.WormholeSystemWatch}
		{
			if ${Entity[GroupID == 988](exists)} && ${Entity[GroupID == 988].Distance} < ${Math.Calc[${Config.OrbitDistance} * 2]}
			{
				return TRUE
			}
			if !${Entity[GroupID == 988](exists)}
			{
				return FALSE
			}
			
		}
		; We are here to watch a specific gate, are we near the BM defining that Gate?
		if ${Config.GateWatch}
		{
			if ${Config.GateWatchName.NotNULLOrEmpty}
			{
				; If the BM is within 2x our orbit distance we are in position
				if ${EVE.Bookmark[${Config.GateWatchName}].ToEntity.Distance} < ${Math.Calc[${Config.OrbitDistance} * 2]}
				{
					LocationSet:Set["${Config.GateWatchName}"]
					return TRUE
				}
				else
				{
					return FALSE
				}
			}
			else
			{
				This:LogInfo["Gate Watch BM Not Found, stopping"]
				This:Stop					
			}
		}
		
	}

	; This method will be used to build our local based standings collection
	method UpdateLocalStandingCollection()
	{
		variable index:pilot LocalPilots
		EVE:GetLocalPilots[LocalPilots]
		variable iterator LocalPilotsIterator
		
		if ${LocalPilots.Used} <= 0
		{
			This:LogInfo["Problem populating local pilots index. Local is broken or doesn't exist"]
		}
		LocalPilots:GetIterator[LocalPilotsIterator]
		
		if ${LocalPilotsIterator:First(exists)}
		{
			variable int highestStanding
			do
			{
				highestStanding:Set[0]
				if ${Local[${LocalPilotsIterator.Value.ID}].Standing.AllianceToAlliance} > ${highestStanding}
				{
					highestStanding:Set[${Local[${LocalPilotsIterator.Value.ID}].Standing.AllianceToAlliance}]
				}
				if ${Local[${LocalPilotsIterator.Value.ID}].Standing.AllianceToCorp} > ${highestStanding}
				{
					highestStanding:Set[${Local[${LocalPilotsIterator.Value.ID}].Standing.AllianceToCorp}]
				}
				if ${Local[${LocalPilotsIterator.Value.ID}].Standing.AllianceToPilot} > ${highestStanding}
				{
					highestStanding:Set[${Local[${LocalPilotsIterator.Value.ID}].Standing.AllianceToPilot}]
				}
				if ${Local[${LocalPilotsIterator.Value.ID}].Standing.CorpToAlliance} > ${highestStanding}
				{
					highestStanding:Set[${Local[${LocalPilotsIterator.Value.ID}].Standing.CorpToAlliance}]
				}
				if ${Local[${LocalPilotsIterator.Value.ID}].Standing.CorpToCorp} > ${highestStanding}
				{
					highestStanding:Set[${Local[${LocalPilotsIterator.Value.ID}].Standing.CorpToCorp}]
				}
				if ${Local[${LocalPilotsIterator.Value.ID}].Standing.CorpToPilot} > ${highestStanding}
				{
					highestStanding:Set[${Local[${LocalPilotsIterator.Value.ID}].Standing.CorpToPilot}]
				}
				if ${Local[${LocalPilotsIterator.Value.ID}].Alliance.Equal[${Me.Alliance}]}
				{
					highestStanding:Set[11]
				}
				HighestLocalStandingCollection:Set[${LocalPilotsIterator.Value.ID},${highestStanding}]
				echo ${LocalPilotsIterator.Value.ID} , ${highestStanding} 
			}
			while ${LocalPilotsIterator:Next(exists)}
		}
	}
	; This method is used to build the collection of people on grid and their standings.
	method UpdateOnGridStandingCollection(int64 CharID, int64 CorpID, int64 AllianceID)
	{
		variable int highestStanding
		highestStanding:Set[-10]
		if ${Me.StandingTo[${CharID},${CorpID},${AllianceID}].MeToPilot} > ${highestStanding}
			highestStanding:Set[${Me.StandingTo[${CharID},${CorpID},${AllianceID}].MeToPilot}]
		if ${Me.StandingTo[${CharID},${CorpID},${AllianceID}].MeToCorp} > ${highestStanding}
			highestStanding:Set[${Me.StandingTo[${CharID},${CorpID},${AllianceID}].MeToCorp}]
		if ${Me.StandingTo[${CharID},${CorpID},${AllianceID}].MeToAlliance} > ${highestStanding}
			highestStanding:Set[${Me.StandingTo[${CharID},${CorpID},${AllianceID}].MeToAlliance}]
		if ${Me.StandingTo[${CharID},${CorpID},${AllianceID}].CorpToPilot} > ${highestStanding}
			highestStanding:Set[${Me.StandingTo[${CharID},${CorpID},${AllianceID}].CorpToPilot}]
		if ${Me.StandingTo[${CharID},${CorpID},${AllianceID}].CorpToCorp} > ${highestStanding}
			highestStanding:Set[${Me.StandingTo[${CharID},${CorpID},${AllianceID}].CorpToCorp}]
		if ${Me.StandingTo[${CharID},${CorpID},${AllianceID}].CorpToAlliance} > ${highestStanding}
			highestStanding:Set[${Me.StandingTo[${CharID},${CorpID},${AllianceID}].CorpToAlliance}]
		if ${Me.StandingTo[${CharID},${CorpID},${AllianceID}].AllianceToPilot} > ${highestStanding}
			highestStanding:Set[${Me.StandingTo[${CharID},${CorpID},${AllianceID}].AllianceToPilot}]
		if ${Me.StandingTo[${CharID},${CorpID},${AllianceID}].AllianceToCorp} > ${highestStanding}
			highestStanding:Set[${Me.StandingTo[${CharID},${CorpID},${AllianceID}].AllianceToCorp}]
		if ${Me.StandingTo[${CharID},${CorpID},${AllianceID}].AllianceToAlliance} > ${highestStanding}
			highestStanding:Set[${CharID},${CorpID},${AllianceID}].AllianceToAlliance}]
		
		echo DEBUG Entity CharID = ${CharID} - ${highestStanding} Standing
		HighestOnGridStandingCollection:Set[${CharID},${highestStanding}]
		
	}
	; This method is used to build the collection of people in local, to add/remove them as they enter/leave.
	method UpdateLocalPopCollection()
	{
		variable index:pilot LocalPilots
		EVE:GetLocalPilots[LocalPilots]
		variable iterator LocalPilotsIterator
			
		
		if ${LocalPilots.Used} <= 0
		{
			This:LogInfo["Problem populating local pilots index. Local is broken or doesn't exist"]
		}
		LocalPilots:GetIterator[LocalPilotsIterator]
		
		if ${LocalPilotsIterator:First(exists)}
		{
			do
			{
				; If they are a blue, we don't care to track them
				if ${HighestLocalStandingCollection.Element[${LocalPilotsIterator.Value.ID}].AsJSON} > 0 || ${HighestOnGridStandingCollection.Element[${LocalPilotsIterator.Value.ID}].AsJSON} > 0
				{
					continue
				}
				; This is where SQL related stuff will end up, probably.
				if ${Config.SQLiteIntegration} && !${CurrentLocalPopCollection.Element[${LocalPilotsIterator.Value.Name}](exists)}
				{
					This:CreateInsertStatement[${LocalPilotsIterator.Value.ID}, "Local Arrival", ${Local[${LocalPilotsIterator.Value.ID}].Name.ReplaceSubstring[','']}, ${Local[${LocalPilotsIterator.Value.ID}].Corp}, ${Local[${LocalPilotsIterator.Value.ID}].AllianceID}, ${Local[${LocalPilotsIterator.Value.ID}].Corp.Name.ReplaceSubstring[','']}, ${Local[${LocalPilotsIterator.Value.ID}].Corp.Ticker}, ${Local[${LocalPilotsIterator.Value.ID}].Alliance.ReplaceSubstring[','']}, ${Local[${LocalPilotsIterator.Value.ID}].AllianceTicker}, ${Time.Timestamp}, "Unknown", ${Universe[${Me.SolarSystemID}].Name.ReplaceSubstring[','']}, ${LocationSet.ReplaceSubstring[','']}]
				}
				if ${HighestLocalStandingCollection.Element[${LocalPilotsIterator.Value.ID}].AsJSON} <= 0 || ${HighestOnGridStandingCollection.Element[${LocalPilotsIterator.Value.ID}].AsJSON} <= 0
				{
					if !${CurrentLocalPopCollection.Element[${LocalPilotsIterator.Value.Name}](exists)} && ${LocalPilotsIterator.Value.Name.NotNULLOrEmpty}
					{
						CurrentLocalPopCollection:Set[${LocalPilotsIterator.Value.Name}, ${LavishScript.RunningTime}]
						echo ${LocalPilotsIterator.Value.Name} entered local at ${LavishScript.RunningTime}
						

						if ${Config.RelayToChat}
						{
							; Interesting story here, a lot of these things will not populate because they can't be populated until you A) run into someone in space or B) show info on them. Fuck!
							This:CreateMessageLocal[${LocalPilotsIterator.Value.Name}, ${LocalPilotsIterator.Value.CharID}, ${Local[${LocalPilotsIterator.Value.CharID}].Corp.Name}, ${Local[${LocalPilotsIterator.Value.CharID}].Corp.Ticker}, ${LocalPilotsIterator.Value.Alliance}, ${LocalPilotsIterator.Value.AllianceTicker}]
							;call ChatRelay.Say "__${Universe[${Me.SolarSystemID}].Name}__ **Arrival** @ <t:${Time.Timestamp}:R>: ${LocalPilotsIterator.Value.Name} - ${Local["${LocalPilotsIterator.Value.Name}"].Corp.Name} - [${LocalPilotsIterator.Value.Corp.Ticker}] - ${Local["${LocalPilotsIterator.Value.Name}"].Alliance} - ${Local["${LocalPilotsIterator.Value.Name}"].AllianceTicker} In Local"
							if ${SupplementaryInfo.NotNULLOrEmpty}
							{
								call ChatRelay.Say "${SupplementaryInfo}"
								SupplementaryInfo:Set[""]
							}
						}
					}
				}
			}
			while ${LocalPilotsIterator:Next(exists)}
			
			if ${CurrentLocalPopCollection.FirstKey(exists)}
			{
				do
				{
					if !${Local["${CurrentLocalPopCollection.CurrentKey}"](exists)}
					{
						echo ${CurrentLocalPopCollection.CurrentKey} left local at ${LavishScript.RunningTime}
						; This is where SQL related stuff will end up, probably.
						if ${Config.SQLiteIntegration}
						{
							GetCharacterInfoByName:Set[${ISXSQLiteTest.TheSQLDatabase.ExecQuery["SELECT * FROM PilotInfo where CharacterName='${CurrentLocalPopCollection.CurrentKey.ReplaceSubstring[','']}';"]}]
							if ${GetCharacterInfoByName.NumRows} > 0
							{
								echo DEBUG - DB HIT
							}
							;if ${GetCharacterInfoByName.GetFieldValue["CorporationID",int64]} == ${LocalPilotsIterator.Value.Corp} && ${GetCharacterInfoByName.GetFieldValue["AllianceID",int64]} == ${LocalPilotsIterator.Value.AllianceID}
							This:CreateInsertStatement[${GetCharacterInfoByName.GetFieldValue["CharID",int64]}, "Local Departure", ${CurrentLocalPopCollection.CurrentKey.ReplaceSubstring[','']}, ${GetCharacterInfoByName.GetFieldValue["CorporationID",int64]}, ${GetCharacterInfoByName.GetFieldValue["AllianceID",int64]}, ${GetCharacterInfoByName.GetFieldValue["CorpName",string].ReplaceSubstring[','']}, ${GetCharacterInfoByName.GetFieldValue["CorpTicker",string]}, ${GetCharacterInfoByName.GetFieldValue["AllianceName",string].ReplaceSubstring[','']}, ${GetCharacterInfoByName.GetFieldValue["AllianceTicker",string]}, ${Time.Timestamp}, "Unknown", ${Universe[${Me.SolarSystemID}].Name.ReplaceSubstring[','']}, ${LocationSet.ReplaceSubstring[','']}]
							GetCharacterInfoByName:Finalize
						}	
						if ${Config.RelayToChat}
						{
							call ChatRelay.Say "__${Universe[${Me.SolarSystemID}].Name}__ **Departure** @ <t:${Time.Timestamp}:R>: ${CurrentLocalPopCollection.CurrentKey} From Local Present For ${Math.Calc[(((${LavishScript.RunningTime} - ${CurrentLocalPopCollection.CurrentValue}) / 1000) \\ 60)].Int}m ${Math.Calc[(((${LavishScript.RunningTime} - ${CurrentLocalPopCollection.CurrentValue}) / 1000) % 60 \\ 1)].Int}s"
						}
						
						CurrentLocalPopCollection:Erase[${CurrentLocalPopCollection.CurrentKey}]						
					}
					else
					{
						continue
					}
				}
				while ${CurrentLocalPopCollection.NextKey(exists)}
			}
		}	
	}
	
	; This method is used to build the collection of on grid entities, to add/remove them as they enter/leave
	; We can't filter out entities by standings without a Local Channel until Amadeus makes that possible
	; So you will be reporting anyone not in your corp or alliance.
	; Update, this might in fact be possible.
	method UpdateOnGridCollection()
	{
		variable index:entity Entities
		variable iterator Entitiez
		EVE:QueryEntities[Entities, "IsPC = 1 && Distance > 0 && IsOwnedByCorpMember = FALSE && IsOwnedByAllianceMember = FALSE"]
		if ${Entities.Used} > 0
		{
			Entities:GetIterator[Entitiez]
			if ${Entitiez:First(exists)}
			{
				do
				{ 
					if ${Entitiez.Value.OwnerID} >= 1 
					{
						This:UpdateOnGridStandingCollection[${Entitiez.Value.OwnerID},${Entitiez.Value.Corp},${Entitiez.Value.AllianceID}]
					}	
					; If they are a blue, we don't care to track them - This won't fire off for wormhole observation, because it doesn't work.
					; It works now, good work erekyu
					if ${HighestLocalStandingCollection.FirstKey(exists)} 
					{
						if ${HighestLocalStandingCollection.Element[${Entitiez.Value.OwnerID}].AsJSON} > 0 || ${HighestOnGridStandingCollection.Element[${Entitiez.Value.OwnerID}].AsJSON} > 0
						{
							continue
						}
					}	
					if !${OnGridEntitiesCollection.Element[${Entitiez.Value.Name}](exists)} && ${Entitiez.Value.Name.NotNULLOrEmpty} && ( ${HighestOnGridStandingCollection.Element[${Entitiez.Value.OwnerID}].AsJSON} <= 0 || \
					${HighestLocalStandingCollection.Element[${Entitiez.Value.OwnerID}].AsJSON} <= 0 )
					{
						echo Detected Pilot ${Entitiez.Value.Name} Corp Ticker ${Entitiez.Value.Corp.Ticker} Flying Ship ${Entitiez.Value.Type} Near Bookmark ${LocationSet}
						; This is where SQL related stuff will end up, probably.
						if ${Config.SQLiteIntegration} && !${OnGridEntitiesCollection.Element[${Entitiez.Value.Name}](exists)}
						{
							This:CreateInsertStatement[${Entitiez.Value.OwnerID}, "Grid Arrival", ${Entitiez.Value.Name.ReplaceSubstring[','']}, ${Entitiez.Value.Corp}, ${Entitiez.Value.AllianceID}, ${Entitiez.Value.Corp.Name.ReplaceSubstring[','']}, ${Entitiez.Value.Corp.Ticker}, ${Entitiez.Value.Alliance.ReplaceSubstring[','']}, "Unknown", ${Time.Timestamp}, ${Entitiez.Value.Type.ReplaceSubstring[','']}, ${Universe[${Me.SolarSystemID}].Name.ReplaceSubstring[','']}, ${LocationSet.ReplaceSubstring[','']}]
						}	
						if ${Config.RelayToChat}
						{
							call ChatRelay.Say "__${Universe[${Me.SolarSystemID}].Name}__ **Arrival** @ <t:${Time.Timestamp}:R>: ${Entitiez.Value.Name} [${Entitiez.Value.Corp.Ticker}] - ${Entitiez.Value.Type} Near ${LocationSet}"
							if ${SupplementaryInfo.NotNULLOrEmpty}
							{
								call ChatRelay.Say "${SupplementaryInfo}"
								SupplementaryInfo:Set[""]
							}
						}
						OnGridEntitiesCollection:Set[${Entitiez.Value.Name},${LavishScript.RunningTime}]
					}
				}
				while ${Entitiez:Next(exists)}
			}	
			
		}
		
		if ${OnGridEntitiesCollection.FirstValue(exists)}
		{
			do
			{
				if !${Entity[Name == "${OnGridEntitiesCollection.CurrentKey}"]}
				{
					; This is where SQL related stuff will end up, probably.
					if ${Config.SQLiteIntegration}
					{
						GetCharacterInfoByName:Set[${ISXSQLiteTest.TheSQLDatabase.ExecQuery["SELECT * FROM PilotInfo where CharacterName='${OnGridEntitiesCollection.CurrentKey.ReplaceSubstring[','']}';"]}]
						if ${GetCharacterInfoByName.NumRows} > 0
						{
							echo DEBUG - DB HIT
						}						
						This:CreateInsertStatement[${GetCharacterInfoByName.GetFieldValue["CharID",int64]}, "Grid Departure", ${OnGridEntitiesCollection.CurrentKey.ReplaceSubstring[','']}, ${GetCharacterInfoByName.GetFieldValue["CorporationID",int64]}, ${GetCharacterInfoByName.GetFieldValue["AllianceID",int64]}, ${GetCharacterInfoByName.GetFieldValue["CorpName",string].ReplaceSubstring[','']}, ${GetCharacterInfoByName.GetFieldValue["CorpTicker",string]}, ${GetCharacterInfoByName.GetFieldValue["AllianceName",string].ReplaceSubstring[','']}, ${GetCharacterInfoByName.GetFieldValue["AllianceTicker",string]}, ${Time.Timestamp}, "Unknown", ${Universe[${Me.SolarSystemID}].Name.ReplaceSubstring[','']}, ${LocationSet.ReplaceSubstring[','']}]
						;This:CreateInsertStatement[${Entity[Name == "${OnGridEntitiesCollection.CurrentKey}"].OwnerID}, "Grid Departure", ${OnGridEntitiesCollection.CurrentKey.ReplaceSubstring[','']}, ${Entity[Name == "${OnGridEntitiesCollection.CurrentKey}"].Corp}, ${Entity[Name == "${OnGridEntitiesCollection.CurrentKey}"].AllianceID}, ${Entity[Name == "${OnGridEntitiesCollection.CurrentKey}"].Corp.Name.ReplaceSubstring[','']}, ${Entity[Name == "${OnGridEntitiesCollection.CurrentKey}"].Corp.Ticker}, ${Entity[Name == "${OnGridEntitiesCollection.CurrentKey}"].Alliance.ReplaceSubstring[','']}, "Unknown", ${Time.Timestamp}, ${Entity[Name == "${OnGridEntitiesCollection.CurrentKey}"].Type}, ${Universe[${Me.SolarSystemID}].Name.ReplaceSubstring[','']}, ${LocationSet.ReplaceSubstring[','']}]
						GetCharacterInfoByName:Finalize
					}	
					if ${Config.RelayToChat}
					{
						call ChatRelay.Say "__${Universe[${Me.SolarSystemID}].Name}__ **Departure** @ <t:${Time.Timestamp}:R>: ${OnGridEntitiesCollection.CurrentKey} Near ${LocationSet} Present For ${Math.Calc[(((${LavishScript.RunningTime} - ${OnGridEntitiesCollection.CurrentValue}) / 1000) \\ 60)].Int}m ${Math.Calc[(((${LavishScript.RunningTime} - ${OnGridEntitiesCollection.CurrentValue}) / 1000) % 60 \\ 1)].Int}s"
					}
					OnGridEntitiesCollection:Erase[${OnGridEntitiesCollection.CurrentKey}]
				}
			}
			while ${OnGridEntitiesCollection.NextKey(exists)}
		}	
	}
	
	; This mode needs more complication so lets use concatenation to construct a message from discrete components.
	method CreateMessageLocal(string Name, int64 CharID, string Corp, string CorpTicker, string Alliance, string AllianceTicker)
	{
		echo begin making message
		variable string MessageToReturn = "__${Universe[${Me.SolarSystemID}].Name}__ **Arrival** @ <t:${Time.Timestamp}:R>: "
		variable string Sep = " "
		; I'm not sure what circumstance could lead us here but what the hell ever.
		if !${Name.NotNULLOrEmpty}
		{
			return NULL
		}
		; If the things we are concatenating here look weird, remember spaces have to be added somewhere.
		; Next in the message is the pilot's name.
		MessageToReturn:Concat["${Name}${Sep}"]
		; Next in the message is their Corp's Name if it isn't NULL somehow.
		if ${Corp.NotNULLOrEmpty}
		{
			MessageToReturn:Concat["-${Sep}${Corp}${Sep}-"]
		}
		; Next up is their Corp Ticker surrounded with extra brackets? No idea if we have to escape that. Also it won't happen if its NULL
		if ${CorpTicker.NotNULLOrEmpty}
		{
			MessageToReturn:Concat["\[${CorpTicker}\]${Sep}"]
		}
		; Next up is the Alliance Name, null etc
		if ${Alliance.NotNULLOrEmpty}
		{
			MessageToReturn:Concat["${Sep}${Alliance}${Sep}-"]
		}
		; Next up is Alliance Ticker, null etc
		if ${AllianceTicker.NotNULLOrEmpty}
		{
			MessageToReturn:Concat["\[${AllianceTicker}\]"]
		}
		MessageToReturn:Concat["${Sep}In Local"]
		if ${MessageToReturn.NotNULLOrEmpty}
		{
			call ChatRelay.Say "${MessageToReturn}"
		}
	}

	; Next up insert statement stuff
	method CreateInsertStatement(int64 CharID, string IncidentType, string CharName, int64 CorpID, int64 AllianceID, string CorpName, string CorpTicker, string AllianceName, string AllianceTicker, int64 Timestamp, string ShipType, string LocationSystem, string LocationNearest)
	{
		DML:Insert["insert into WatcherFiles (CharID,IncidentType,CharacterName,CorporationID,AllianceID,CorpName,CorpTicker,AllianceName,AllianceTicker,Timestamp,ShipType,LocationSystem,LocationNearest) values (${CharID}, '${IncidentType}', '${CharName}', ${CorpID}, ${AllianceID}, '${CorpName}', '${CorpTicker}', '${AllianceName}','${AllianceTicker}', ${Timestamp}, '${ShipType}', '${LocationSystem}', '${LocationNearest}');"]
	}
	
	; Next up, execute the transaction index
	method ExecuteTransactionIndex()
	{
		echo DEBUG - TWF Insert Exec
		ISXSQLiteTest.TheSQLDatabase:ExecDMLTransaction[DML]
		; 10 seconds sounds good
		LastExecute:Set[${Math.Calc[${LavishScript.RunningTime} + 10000]}]	
		DML:Clear
	}
	member:bool RefreshBookmarks()
	{
		This:LogInfo["Refreshing bookmarks"]
		EVE:RefreshBookmarks
		return TRUE
	}


	member:bool HaltBot()
	{
		This:Stop
		return TRUE
	}
}


objectdef obj_ObserverUI inherits obj_State
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