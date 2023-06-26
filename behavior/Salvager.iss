objectdef obj_Configuration_Salvager inherits obj_Configuration_Base
{
	method Initialize()
	{
		This[parent]:Initialize["Salvager"]
	}

	member:settingsetref SafeBookmarksRef()
	{
		if !${ConfigManager.ConfigRoot.FindSet[${This.SetName}].FindSet[SafeBookmarks](exists)}
		{
			This.ConfigRef:AddSet[SafeBookmarks]
		}
		return ${ConfigManager.ConfigRoot.FindSet[${This.SetName}].FindSet[SafeBookmarks]}
	}

	method Set_Default_Values()
	{
		ConfigManager.ConfigRoot:AddSet[${This.SetName}]
		This.ConfigRef:AddSet[SafeBookmarks]

		This.ConfigRef:AddSetting[MunitionStorage, Personal Hangar]
		This.ConfigRef:AddSetting[Prefix,Salvage:]
		This.ConfigRef:AddSetting[Dropoff,""]
	}

	Setting(string, Prefix, SetPrefix)
	Setting(string, Dropoff, SetDropoff)
	Setting(string, MunitionStorage, SetMunitionStorage)
	Setting(string, MunitionStorageFolder, SetMunitionStorageFolder)
	
	; This will be the network path for the Extremely Shared DB. I will use this for my off-machine salvagers to work. Most people will never ever use this.
	Setting(string, ExtremelySharedDBPath, SetExtremelySharedDBPath)
	; This will be a prefix slapped onto the DB filename in the above path.
	Setting(string, ExtremelySharedDBPrefix, SetExtremelySharedDBPrefix)	
	
	; This will indicate that this salvager is going to be salvaging for a non-local Missioneer. That is to say, it will be on another computer entirely.
	Setting(bool, NetworkedSalvager, SetNetworkedSalvager)
	
}

objectdef obj_Salvager inherits obj_StateQueue
{
	variable obj_Configuration_Salvager Config
	variable obj_SalvageUI LocalUI
	
	; This DB will be Extremely Shared, that is to say it will be a network location.
	variable sqlitedb ExtremelySharedSQLDB
	; This DB will be Shared by all clients on this machine.
	variable sqlitedb SharedSQLDB
	; This DB will reside in memory and be used to do some optimization
	variable sqlitedb MySalvageBMs
	; These will be the variables for our queries
	variable sqlitequery GetSalvageBM
	variable sqlitequery GetSalvageBM2
	
	variable index:string TempDBInsert

	
	; Borrowing from Missioneer, this will be your cargo bay in this instance. I am too lazy to find replace it.
	variable bool LargestBayRefreshed
	
	; Runningtime holder so we can know when we last checked our BMs and not spam the shit out of it.
	variable int64 LastBMCheck
	
	; Queue where we will hold the Labels of the BMs we are going to claim.
	variable queue:string SalvageBMPrepQueue
	; Queue where we will hold the Labels of the BMs we are going to salvage at.
	variable queue:string SalvageBMQueue
	; Queue where we will hold the IDs of BMs we are going to mark as historical as part of cleanup.
	variable queue:int64 SalvageBMCleanupQueue
	; Queue where we will hold the Labels of BMs we are going to delete as part of cleanup.
	variable queue:string SalvageBMDeletionQueue
	
	method Initialize()
	{
		This[parent]:Initialize
		DynamicAddBehavior("Salvager", "Dedicated Salvager")
	}

	method Start()
	{
		This:LogInfo["obj_Salvage", "Starting", "g"]
		if ${This.IsIdle}
		{
			This:QueueState["SalvagerHub", 500]
		}
	}

	method Stop()
	{
		This:DeactivateStateQueueDisplay
		This:Clear
		SharedSQLDB:Close
		ExtremelySharedSQLDB:Close
		MySalvageBMs:Close
	}
	
	method Shutdown()
	{
		SharedSQLDB:Close
		ExtremelySharedSQLDB:Close
		MySalvageBMs:Close
	}

	; This will be our central loop, where we jump off to other states.
	member:bool SalvagerHub()
	{
		if !${SharedSQLDB.ID(exists)}
		{
			SharedSQLDB:Set[${SQLite.OpenDB["MissionSharedDB","MissionSharedDB.sqlite3"]}]

		}
		if (${Config.ExtremelySharedDBPath.NotNULLOrEmpty} && ${Config.ExtremelySharedDBPrefix.NotNULLOrEmpty}) && !${ExtremelySharedSQLDB.ID(exists)}
		{
			;ExtremelySharedSQLDB:Set[${SQLite.OpenDB["${Config.ExtremelySharedDBPrefix}SharedDB","\\\\${Config.ExtremelySharedDBPath.ReplaceSubstring[\\,\\\\]}${Config.ExtremelySharedDBPrefix}SharedDB.sqlite3"]}]
			;echo DEBUG - SALVAGER - "${Config.ExtremelySharedDBPrefix}SharedDB","\\\\${Config.ExtremelySharedDBPath.ReplaceSubstring[\\,\\\\]}${Config.ExtremelySharedDBPrefix}SharedDB.sqlite3"
			ExtremelySharedSQLDB:Set[${SQLite.OpenDB["${Config.ExtremelySharedDBPrefix}SharedDB","${Config.ExtremelySharedDBPath.ReplaceSubstring[\\,\\\\]}${Config.ExtremelySharedDBPrefix}SharedDB.sqlite3"]}]
			echo "${Config.ExtremelySharedDBPrefix}SharedDB","${Config.ExtremelySharedDBPath.ReplaceSubstring[\\,\\\\]}${Config.ExtremelySharedDBPrefix}SharedDB.sqlite3"
		}		
		if !${MySalvageBMs.ID(exists)}
		{
			; This DB will reside in memory. It is temporary.
			MySalvageBMs:Set[${SQLite.OpenDB["MySalvageBMs",":memory:"]}]
			;MySalvageBMs:Set[${SQLite.OpenDB["MySalvageBMs","MySalvageBMs.sqlite3"]}]
		}
		if !${MySalvageBMs.TableExists["TempBMTable"]}
		{
			echo DEBUG - Creating Temp Salvage BM Table
			MySalvageBMs:ExecDML["create table TempBMTable (BMID INTEGER PRIMARY KEY, BMName TEXT, BMSystem TEXT, BMJumpsTo INTEGER, ExpectedExpiration INTEGER);"]
			;MySalvageBMs:ExecDML["PRAGMA journal_mode=WAL;"]
		}
		; We started in space, return to station and restart this state.
		if ${Client.InSpace}
		{
			This:InsertState["SalvagerHub", 2500]
			This:InsertState["SalvagerNavigateToStation",3000]
			return TRUE		
		}
		; Is it time to halt? Or are we close to downtime? Only goes off when we are in a station.
		if ${Me.InStation} && (${Config.Halt} || ${halt} || ${Utility.DowntimeClose})
		{
			This:QueueState["HaltBot"]
			return TRUE
		}
		; Are we full or have an invalid ship cargo (we're on the wrong inventory window).
		if ${Me.InStation} && ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].UsedCapacity} < 0
		{
			This:InsertState["CheckCargoHold",3000]
			This:InsertState["RefreshCargoBayState",3000]
			return TRUE
		}
		if ${Me.InStation} && ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].UsedCapacity} > 1 
		{
			This:InsertState["SalvagerHub",3000]
			This:InsertState["Traveling",5000]
			This:InsertState["Offload",3000]
			return TRUE		
		}
		; We are not full, check for valid bookmarks in the DB. We don't want to hit this too terribly often. I will never be convinced that reads are non-blocking no matter what.
		; If we find BMs we will not return to this state directly.
		if ${Me.InStation} && ${LastBMCheck} < ${LavishScript.RunningTime}
		{
			This:InsertState["SalvagerCheckBookmarks",1000]
			return TRUE
		}
		; We did not find BMs, let us idle for a little while
		This:InsertState["SalvagerHub",5000]
		This:InsertState["Idle",10000]
		return TRUE
	}
	
	; Here is where we will check either our Local SharedDB or our Network SharedDB.
	member:bool SalvagerCheckBookmarks()
	{
		; Need to do some BM cleanup.
		if !${ExtremelySharedSQLDB.ID(exists)}
		{
			GetSalvageBM:Set[${SharedSQLDB.ExecQuery["SELECT * FROM SalvageBMTable WHERE Historical=0 AND BMName LIKE '%${Config.Prefix}%';"]}]
		}
		else
		{
			GetSalvageBM:Set[${ExtremelySharedSQLDB.ExecQuery["SELECT * FROM SalvageBMTable WHERE Historical=0 AND BMName LIKE '%${Config.Prefix}%';"]}]
		}
		if ${GetSalvageBM.NumRows} > 0
		{
			This:LogInfo["${GetSalvageBM.NumRows} BMs Found, Cleaning up Old BMs."]
			do
			{
				echo (${GetSalvageBM.GetFieldValue["ExpectedExpiration",int64]} < ${EVETime.AsInt64}) && ${EVE.Bookmark[${GetSalvageBM.GetFieldValue["BMName",string]}](exists)}
				if (${GetSalvageBM.GetFieldValue["ExpectedExpiration",int64]} < ${EVETime.AsInt64}) && ${EVE.Bookmark[${GetSalvageBM.GetFieldValue["BMName",string]}](exists)}
				{
					; DB entries that are expired but also have a corresponding BM
					SalvageBMDeletionQueue:Queue[${EVE.Bookmark[${GetSalvageBM.GetFieldValue["BMName",string]}]}]
				}
				if (${GetSalvageBM.GetFieldValue["ExpectedExpiration",int64]} < ${EVETime.AsInt64}) && !${EVE.Bookmark[${GetSalvageBM.GetFieldValue["BMName",string]}](exists)}
				{
					; DB entries that are expired but do not have a corresponding BM
					SalvageBMCleanupQueue:Queue[${EVE.Bookmark[${GetSalvageBM.GetFieldValue["BMName",string]}].ID}]
				}
				GetSalvageBM:NextRow
			}
			while !${GetSalvageBM.LastRow}
			GetSalvageBM:Finalize
		}
		; Process those queues, hopefully this won't go too fast. Actually lets just process that deletion queue and use other methods to make sure later stuff behaves.
		if ${SalvageBMDeletionQueue.Used} > 0
		{
			do
			{
				if ${EVE.Bookmark[${SalvageBMDeletionQueue.Peek}](exists)}
				{
					EVE.Bookmark[${SalvageBMDeletionQueue.Peek}]:Remove
					This:LogInfo["Deleting BM ${SalvageBMDeletionQueue.Peek}"]
					SalvageBMDeletionQueue:Dequeue
				}
				if !${EVE.Bookmark[${SalvageBMDeletionQueue.Peek}](exists)}
				{
					SalvageBMDeletionQueue:Dequeue
				}
			}
			while ${SalvageBMDeletionQueue.Size} > 0
			return FALSE
		}
		; Oh right we can process them in bulk, I should pay more attention.
		if ${SalvageBMCleanupQueue.Used} > 0
		{
			This:LogInfo["Marking old DB entries as Historical."]
			if ${ExtremelySharedSQLDB.ID(exists)}
				ExtremelySharedSQLDB:ExecDML["update SalvageBMTable SET Historical=1 WHERE ExpectedExpiration<${EVETime.AsInt64};"]
			else
				SharedSQLDB:ExecDML["update SalvageBMTable SET Historical=1 WHERE ExpectedExpiration<${EVETime.AsInt64};"]
			SalvageBMCleanupQueue:Clear
			return FALSE
		}
		; On to actually getting our BMs for real use.
		echo DEBUG - SALVAGER - CHECKPOINT 1
		if !${ExtremelySharedSQLDB.ID(exists)}
		{
			GetSalvageBM:Set[${SharedSQLDB.ExecQuery["SELECT * FROM SalvageBMTable WHERE Historical=0 AND BMName LIKE '%${Config.Prefix}%' AND (ClaimedByCharID=0 OR ClaimedByCharID=${Me.CharID});"]}]
		}
		else
		{
			GetSalvageBM:Set[${ExtremelySharedSQLDB.ExecQuery["SELECT * FROM SalvageBMTable WHERE Historical=0 AND BMName LIKE '%${Config.Prefix}%' AND (ClaimedByCharID=0 OR ClaimedByCharID=${Me.CharID});"]}]
		}
		if ${GetSalvageBM.NumRows} > 0
		{
			This:LogInfo["${GetSalvageBM.NumRows} BMs Found"]
			do
			{
				; Let us make sure we only grab BMs that actually exist.
				if ${EVE.Bookmark[${GetSalvageBM.GetFieldValue["BMName",string]}](exists)}
				{
					;TempBMTable (BMID INTEGER PRIMARY KEY, BMName TEXT, BMSystem TEXT, BMJumpsTo INTEGER, ExpectedExpiration DATETIME)
					echo (${GetSalvageBM.GetFieldValue["BMID",int64]},'${GetSalvageBM.GetFieldValue["BMName",string]}','${GetSalvageBM.GetFieldValue["BMSystem",string]}',${EVE.Bookmark[${GetSalvageBM.GetFieldValue["BMName",string]}].JumpsTo},${GetSalvageBM.GetFieldValue["ExpectedExpiration",int64]})
					TempDBInsert:Insert["insert into TempBMTable (BMID,BMName,BMSystem,BMJumpsTo,ExpectedExpiration) values (${GetSalvageBM.GetFieldValue["BMID",int64]},'${GetSalvageBM.GetFieldValue["BMName",string].ReplaceSubstring[','']}','${GetSalvageBM.GetFieldValue["BMSystem",string].ReplaceSubstring[','']}',${EVE.Bookmark[${GetSalvageBM.GetFieldValue["BMName",string]}].JumpsTo},${GetSalvageBM.GetFieldValue["ExpectedExpiration",int64]}) ON CONFLICT (BMID) DO UPDATE SET BMName=excluded.BMName;"]
				}
				GetSalvageBM:NextRow
			}
			while !${GetSalvageBM.LastRow}
			GetSalvageBM:Finalize
			MySalvageBMs:ExecDMLTransaction[TempDBInsert]
			TempDBInsert:Clear
			This:InsertState["SalvagerPostFilterBM",5000]
			return TRUE
		}
		else
		{
			This:LogInfo["No BMs Found, Idling 60 seconds"]
			LastBMCheck:Set[${Math.Calc[${LavishScript.RunningTime} + 60000]}]
			This:InsertState["SalvagerHub",5000]
			return TRUE
		}
	}
	; Might be SQLing too fast, lets break the last segment of SalvagerHub into its own thing.
	; Basically we have taken our table and filtered it then moved the values to a new temp table that resides in memory. We will now sort by how many jumps, what system.
	member:bool SalvagerPostFilterBM()
	{
		echo DEBUG - SALVAGER - CHECKPOINT 2
		GetSalvageBM2:Set[${MySalvageBMs.ExecQuery["SELECT * FROM TempBMTable ORDER BY BMJumpsTo ASC, BMSystem DESC;"]}]
		if ${GetSalvageBM2.NumRows} > 0
		{
			This:LogInfo["Post-Filtering ${GetSalvageBM2.NumRows} BMs Found"]
			do
			{
				SalvageBMPrepQueue:Queue[${GetSalvageBM2.GetFieldValue["BMName",string]}]
				GetSalvageBM2:NextRow
			}
			while !${GetSalvageBM2.LastRow} && ${SalvageBMPrepQueue.Used} < 5
			GetSalvageBM2:Finalize
		
			if ${SalvageBMPrepQueue.Used} > 0
			{
				do
				{
					This:ClaimedByCharID[${Me.CharID},${EVE.Bookmark[${SalvageBMPrepQueue.Peek}].ID}]
					This:LogInfo["Claiming ${SalvageBMPrepQueue.Peek}"]
					SalvageBMQueue:Queue[${SalvageBMPrepQueue.Peek}]
					SalvageBMPrepQueue:Dequeue
				}
				while ${SalvageBMPrepQueue.Used} > 0
			}
			else
			{
				echo DEBUG - SALVAGER - SOMETHING WENT INSANELY WRONG HERE
				This:Stop
				return TRUE
			}
			This:InsertState["SalvagerMoveToBM",5000]
			This:InsertState["Idle",5000]
			return TRUE
		}
		else
		{
			echo DEBUG - SALVAGER - SOMETHING WENT INSANELY WRONG HERE
			This:Stop
			return TRUE
		}
	}	
	; This is where we will travel to our BM
	member:bool SalvagerMoveToBM()
	{
		if !${Client.InSpace}
		{
			This:LogInfo["We need to be undocked for this part"]
			Move:Undock
			return FALSE
		}
		if ${SalvageBMQueue.Peek.NotNULLOrEmpty}
		{
			Move:Bookmark[${SalvageBMQueue.Peek},TRUE]
		}
		else
		{
			This:LogInfo["All dressed up with nowhere to go"]
			This:InsertState["SalvagerHub", 2500]
			This:InsertState["SalvagerNavigateToStation",3000]
			return TRUE
		}
		This:InsertState["SalvagerOnSiteNavigation",5000]
		This:InsertState["Traveling",5000]
		return TRUE
	}
	
	; This is where we will do our On Site Navigation
	member:bool SalvagerOnSiteNavigation()
	{
		if ${Me.ToEntity.Mode} == MOVE_WARPING
			return FALSE
		if ${Move.Traveling}
			return FALSE
		if !${Client.Inventory}
			return FALSE
			
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].UsedCapacity} / ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].Capacity} > 0.925
		{
			This:LogInfo["Salvage", "Unload trip required", "g"]
			This:InsertState["SalvagerMoveToBM",3000]
			This:InsertState["Traveling",3000]
			This:InsertState["Offload",5000]
			return TRUE
		}
		
		if ${Salvage.WrecksToLock.TargetList.Used} == 0
		{
			This:LogInfo["Area cleared. Marking BM as Historical and Dequeuing"]
			This:MarkBMAsHistorical[${EVE.Bookmark[${SalvageBMQueue.Peek}].ID}]
			SalvageBMQueue:Dequeue
			This:InsertState["SalvagerMoveToBM",5000]
			return TRUE
		}
		else
		{
			variable float MaxRange = ${Ship.ModuleList_TractorBeams.Range}
			if ${MaxRange} > ${MyShip.MaxTargetRange}
			{
				MaxRange:Set[${MyShip.MaxTargetRange}]
			}

			variable iterator TargetIterator
			Salvage.WrecksToLock.TargetList:GetIterator[TargetIterator]
			if ${TargetIterator:First(exists)}
			{
				do
				{
					if ${TargetIterator.Value.ID(exists)}
					{
						if	${TargetIterator.Value.Distance} > ${MaxRange} && ${Me.ToEntity.Mode} != MOVE_APPROACHING
						{
							Move:Approach[${TargetIterator.Value.ID}]
							return FALSE
						}
					}
				}
				while ${TargetIterator:Next(exists)}
			}
		}
		return FALSE
	}
	
	; This is where we will navigate back to our Home Structure
	member:bool SalvagerNavigateToStation()
	{
		if ${Config.Dropoff.NotNULLOrEmpty}
		{
			Move:Bookmark[${Config.Dropoff}]
			This:InsertState["Traveling",5000]
			return TRUE
		}
		else
		{
			This:LogInfo["No Home Structure BM, thats bad. Stopping."]
			This:Stop
			return TRUE
		}
	}
	
	
	member:bool RefreshCargoBayState()
	{
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipCargo"](exists)} && !${LargestBayRefreshed}
		{
			EVEWindow[Inventory].ChildWindow[${MyShip.ID},"ShipCargo"]:MakeActive			
			LargestBayRefreshed:Set[TRUE]
			This:InsertState["RefreshCargoBayState",${Math.Calc[(3000) * ${Config.InventoryPulseRateModifier}].Int}]
			return TRUE
		}
		LargestBayRefreshed:Set[FALSE]
		This:LogInfo["ShipCargo Refreshed"]
		return TRUE
	}
	
	member:bool Traveling()
	{
		if ${Cargo.Processing} || ${Move.Traveling} || ${Me.ToEntity.Mode} == MOVE_WARPING
		{
			return FALSE
		}
		return TRUE
	}

	member:bool DeleteBookmark( int Removed=-1)
	{
		echo deletebookmark
		variable index:bookmark Bookmarks
		variable iterator BookmarkIterator
		EVE:GetBookmarks[Bookmarks]
		Bookmarks:GetIterator[BookmarkIterator]
		if ${BookmarkIterator:First(exists)}
		do
		{
			if ${BookmarkIterator.Value.Label.Find[${Config.Prefix}]}
			{
				if ${BookmarkIterator.Value.JumpsTo} == 0
				{
					if ${BookmarkIterator.Value.Distance} < 150000
					{
						if ${Removed} != ${BookmarkIterator.Value.ID}
						{
							This:LogInfo["obj_Salvage", "Finished Salvaging ${BookmarkIterator.Value.Label} - Deleting", "g"]
							This:InsertState["DeleteBookmark", 1000, "${BookmarkIterator.Value.ID}"]
							BookmarkIterator.Value:Remove
							return TRUE
						}
						else
						{
							UsedBookmarks:Add[${BookmarkIterator.Value.ID}]
							return TRUE
						}
					}
				}
			}
		}
		while ${BookmarkIterator:Next(exists)}
		return TRUE
	}

	member:bool CheckCargoHold()
	{
		if !${Client.Inventory}
		{
			return FALSE
		}
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].UsedCapacity} / ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].Capacity} > 0.75
		{
			This:LogInfo["obj_Salvage", "Unload trip required", "g"]
			This:QueueState["Offload"]
			This:QueueState["Traveling"]
		}
		else
		{
			This:LogInfo["obj_Salvage", "Unload trip not required", "g"]
		}
		This:QueueState["SalvagerHub", 3000]
		return TRUE
	}

	member:bool RefreshBookmarks(bool refreshdone=FALSE)
	{
		if !${refreshdone}
		{
			This:LogInfo["obj_Salvage", "Refreshing bookmarks", "g"]
			EVE:RefreshBookmarks
			This:InsertState["RefreshBookmarks", 2000, "TRUE"]
			return TRUE
		}

		This:ReportOldestBookmark
		return TRUE
	}

	member:bool Offload()
	{
		switch ${Config.MunitionStorage}
		{
			case Personal Hangar
				Cargo:At[${Config.Dropoff}]:Unload
				break
			default
				Cargo:At[${Config.Dropoff},${Config.MunitionStorage},${Config.MunitionStorageFolder},${Config.DropoffContainer}]:Unload
				break
		}
		return TRUE
	}
	
	; This method is just so a salvager can claim a salvage BM. If you have more than one salvager it is kinda needed.
	method SalvageBMTableClaim(int64 CharID, int64 BMID)
	{
		if ${ExtremelySharedSQLDB.ID(exists)}
			ExtremelySharedSQLDB:ExecDML["update SalvageBMTable SET ClaimedByCharID=${CharID} WHERE BMID=${BMID};"]
		else
			SharedSQLDB:ExecDML["update SalvageBMTable SET ClaimedByCharID=${CharID} WHERE BMID=${BMID};"]
	}
	
	
	method MarkBMAsHistorical(int64 BMID)
	{
		if ${ExtremelySharedSQLDB.ID(exists)}
			ExtremelySharedSQLDB:ExecDML["update SalvageBMTable SET Historical=1 WHERE BMID=${BMID};"]
		else
			SharedSQLDB:ExecDML["update SalvageBMTable SET Historical=1 WHERE BMID=${BMID};"]
	}	

}

objectdef obj_SalvageUI inherits obj_StateQueue
{


	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
	}

	method Start()
	{
		This:QueueState["UpdateBookmarkLists", 5]
	}

	method Stop()
	{
		This:Clear
	}

	member:bool UpdateBookmarkLists()
	{
		variable index:bookmark Bookmarks
		variable iterator BookmarkIterator

		EVE:GetBookmarks[Bookmarks]
		Bookmarks:GetIterator[BookmarkIterator]

		UIElement[DropoffList@DropoffFrame@Tehbot_DedicatedSalvager_Frame@Tehbot_DedicatedSalvager]:ClearItems
		if ${BookmarkIterator:First(exists)}
			do
			{
				if ${UIElement[Dropoff@DropoffFrame@Tehbot_DedicatedSalvager_Frame@Tehbot_DedicatedSalvager].Text.Length}
				{
					if ${BookmarkIterator.Value.Label.Left[${Salvager.Config.Dropoff.Length}].Equal[${Salvager.Config.Dropoff}]}
						UIElement[DropoffList@DropoffFrame@Tehbot_DedicatedSalvager_Frame@Tehbot_DedicatedSalvager]:AddItem[${BookmarkIterator.Value.Label.Escape}]
				}
				else
				{
					UIElement[DropoffList@DropoffFrame@Tehbot_DedicatedSalvager_Frame@Tehbot_DedicatedSalvager]:AddItem[${BookmarkIterator.Value.Label.Escape}]
				}
			}
			while ${BookmarkIterator:Next(exists)}


		return FALSE
	}

}