objectdef obj_TargetingDatabase inherits obj_StateQueue
{
	; This will be our DB for the object. There will be many of them, in fact. One per MainMode or MiniMode that will be using targeting of some kind.
	; Who knows if this will prove successful or not.
	variable sqlitedb TargetingDatabase
	
	; These queries will be for our tables, I don't know why I bother making two different queries, they all get finalized and re-used immediately.
	variable sqlitequery GetPrimaryTableInfo
	variable sqlitequery GetOtherTableInfo
	; I lied, sometimes I might need to initiate a second query alongside the first one
	variable sqlitequery GetMoreTableInfo
	; Need to grab stuff from CombatComputer for the mission specific priority update.
	variable sqlitequery GetCCInfo
	; Need a query to grab a column from MTMDB
	variable sqlitequery GetMTMDBInfo
	
	; This will be our string index for SQL Transactions (big inserts, lots of rows, big money, oh yeah)
	variable index:string PendingTransaction
	
	variable queue:int64 LockQueue
	
	; This queue will be used for deleting rows of things that don't exist anymore from our Tables.
	variable queue:int64 TableDeletionQueue

	variable collection:int TargetReservationCollection 
	
	; This is just so we can know what our nominal max number of locked targets is.
	variable int MaxTarget = ${MyShip.MaxLockedTargets}
	
	method Initialize()
	{
		
		This[parent]:Initialize
		;TargetingDatabase:Set[${SQLite.OpenDB["TargetingDatabase",":memory:"]}]
		TargetingDatabase:Set[${SQLite.OpenDB["${Me.Name}TargetingDatabase","${Script.CurrentDirectory}/Data/${Me.Name}TDBTEST.sqlite3"]}]
		TargetingDatabase:ExecDML["PRAGMA journal_mode=WAL;"]
		TargetingDatabase:ExecDML["PRAGMA main.mmap_size=64000000"]
		TargetingDatabase:ExecDML["PRAGMA main.cache_size=-64000;"]
		PulseFrequency:Set[750]
		;This.NonGameTiedPulse:Set[FALSE]
		RandomDelta:Set[250]		
		This:QueueState["TargetingHub"]
		
		if !${TargetingDatabase.TableExists["Origin"]}
		{
			; This will be our default table. It will be a table where we keep track of what tables we have, the EXACT QUERY STRING USED to populate the table, the minimum lock count
			; for the table, and when it was last updated. Two more things, TableUpdateInterval (we won't update this table unless it has been at least this many milliseconds)
			; and lastly we have QueryChanged, a bool to indicate if the query string has changed (we will throw out the contents of the table and rebuild it if true).
			echo DEBUG - OBJ Targeting Database - Creating Primary Table
			TargetingDatabase:ExecDML["create table Origin (TableName TEXT PRIMARY KEY, TableQueryString TEXT,  MinimumLocks INTEGER, TableLastUpdate INTEGER, TableUpdateInterval INTEGER, QueryChanged BOOLEAN);"]
		}
	}
 
	method Shutdown()
	{

		TargetingDatabase:Close
	}
	
	; This will be our starting point, the TargetingHub. This will our primary state for the object.
	member:bool TargetingHub()
	{
		; This is here in case you end up in one of them triglavian systems that eats your fucking max target count. Or if you have bad skills.
		if ${Me.MaxLockedTargets} < ${MyShip.MaxLockedTargets}
		{
			MaxTarget:Set[${Me.MaxLockedTargets}]
		}
		
		; Nothing to target in a station, nor while in warp.
		if !${Client.InSpace} || ${Me.ToEntity.Mode} == MOVE_WARPING
			return FALSE
		This:UpdateMissionTargetPriorities[WeaponTargets]
		This:UpdateTargetAmmoPref[WeaponTargets]
		; Prep for Targeting Table Maintenance. We need to see if any of our tables need to be updated (are we after the interval), and see if the Query has changed.
		GetPrimaryTableInfo:Set[${TargetingDatabase.ExecQuery["SELECT * FROM Origin WHERE (TableLastUpdate+TableUpdateInterval+500) < ${Time.Timestamp} ORDER BY TableLastUpdate DESC;"]}]
		if ${GetPrimaryTableInfo.NumRows} == 0
			return FALSE
		else
		{
			; Time to queue them up.
			do
			{
				This:QueueState["MaintainTargetingTables",500,"${GetPrimaryTableInfo.GetFieldValue["TableName"]},${GetPrimaryTableInfo.GetFieldValue["TableQueryString"]},${GetPrimaryTableInfo.GetFieldValue["QueryChanged"]}"]
				echo ["Requesting Update for ${GetPrimaryTableInfo.GetFieldValue["TableName"]} Table"]
				GetPrimaryTableInfo:NextRow
			}
			while !${GetPrimaryTableInfo.LastRow}
			GetPrimaryTableInfo:Finalize
		}
		GetPrimaryTableInfo:Set[${TargetingDatabase.ExecQuery["SELECT * FROM Origin;"]}]
		if ${GetPrimaryTableInfo.NumRows} == 0
			return FALSE
		else
		{
			; Time to queue them up.
			do
			{
				This:QueueState["MaintainTargetingLocks",500,"${GetPrimaryTableInfo.GetFieldValue["TableName"]}"]
				echo ["Requesting Lock Management for ${GetPrimaryTableInfo.GetFieldValue["TableName"]} Table"]
				GetPrimaryTableInfo:NextRow
			}
			while !${GetPrimaryTableInfo.LastRow}
			GetPrimaryTableInfo:Finalize
		}
		This:QueueState["TargetingHub"]
		return TRUE	
	}
	
	; This state will be where we maintain our TargetingTables. Adding and removing entities based on our criteria, also removing things that no longer exist.
	member:bool MaintainTargetingTables(string TableName, string TableQueryString, bool QueryChanged)
	{
		variable index:entity EntityIndex
		variable iterator EntityIterator
		
		; Could come up, I guess.
		if !${Client.InSpace}
		{
			This:QueueState["TargetingHub"]
			return TRUE
		}
		; If the query string changed, we are dumping all the rows, so lets do that first
		;if ${QueryChanged}
		;	TargetingDatabase:ExecDML["delete FROM ${TableName};"]
		
		; Next up, lets toss out things that don't exist.
		This:TargetListCleanup[${TableName}]
		; Next up we need to establish the column values for each row (entity)
		if !${TableQueryString.NotNULLOrEmpty}
		{
			This:LogCritical["Empty query string passed over, thats bad"]
			This:QueueState["TargetingHub"]
			return TRUE			
		}
		
		EVE:QueryEntities[EntityIndex, "${TableQueryString.Escape}"]
		EntityIndex:GetIterator[EntityIterator]
		
		if ${EntityIterator:First(exists)}
		{
			do
			{
				PendingTransaction:Insert["insert into ${TableName} (EntityID, Distance, LockStatus, Priority,  PreferredAmmo, RowLastUpdate) values (${EntityIterator.Value.ID}, ${EntityIterator.Value.Distance}, 'Unlocked', 1, 'ACME', ${Time.Timestamp}) ON CONFLICT (EntityID) DO UPDATE SET Distance=excluded.Distance, RowLastUpdate=excluded.RowLastUpdate;"]
			}
			while ${EntityIterator:Next(exists)}
		}
		if ${PendingTransaction.Used} > 0
		{
			TargetingDatabase:ExecDMLTransaction[PendingTransaction]
			PendingTransaction:Clear
		}
		return TRUE
	}
	
	; This state will be where we maintain our Locks.
	;;; ADDENDUM - This got very messy while I was flailing around trying to figure out what was going wrong. It works, but there are things in here that don't actually do anything at all.
	member:bool MaintainTargetingLocks(string TableName)
	{
		; Two ints, one for the table we are working on, one for all of them in general
		variable int OurReservation
		variable int TotalReservation

		; This will be how many targets we have available as extra which can be used by any targeting table, except for a DroneTargetingTable.
		variable int SpareLocks
		variable int LockedHowMany
		; This will be how many locks we have attempted to begin this loop.
		variable int InitiatedLocks
		
		variable int RecentlyUnlocked

		; Could come up, I guess.
		if !${Client.InSpace}
		{
			This:QueueState["TargetingHub"]
			return TRUE
		}		
		;;; Next up we will prep for our Lock Maintenance states. If we need locks, we will get them. Basically, if we have less than the minimum locks for a table, and there are targets available for targeting, we will target them.
		;;; Anyways, we need to establish what each table desires for its number of locks. Things might get sketchy if another minimode, say, Salvaging, also desires locks. We will use a global collection for this purpose.
		;;; Each table on instantiation will reserve a number of slots.
		echo TARGDAT CHECKPOINT 1 ${This.TableReservedLocks[${TableName}]} ${TableName}
		; Lets check that Collection then. I don't know how this collection could feasibly end up empty but who knows.

		SpareLocks:Set[${Math.Calc[${MaxTarget} - ${TotalReservation}]}]
		; Where do we start with this? I guess we will go through our table and look at what is LOCKED or LOCKING. If a Locking target is Locked, we will update its entry. If a Locked target is no longer locked, but still exists
		; (which it should, unless it died in the like 10 milliseconds between Cleanup in the last state and this one), we will mark it as Unlocked.
		
		; Actually lets run this through one more time.
		This:TargetListCleanup[${TableName}]
		
		; Locking status confirmation/update/etc.
		GetOtherTableInfo:Set[${TargetingDatabase.ExecQuery["SELECT * FROM ${TableName} WHERE LockStatus='Locking';"]}]
		if ${GetOtherTableInfo.NumRows} > 0
		{
			do
			{
				echo TARGDAT CHECKPOINT 2
				; If it is still being targeted, just skip it.
				if ${Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}].BeingTargeted}
					PendingTransaction:Insert["update ${TableName} SET RowLastUpdate=${Time.Timestamp} WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]
				; We completed locking the target, reflect that.
				if ${Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}].IsLockedTarget}
					PendingTransaction:Insert["update ${TableName} SET LockStatus='Locked', RowLastUpdate=${Time.Timestamp} WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]
				; We lost the target, ECM / damps / whatever, reflect that.
				if !${Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}].IsLockedTarget} && !${Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}].BeingTargeted}
					PendingTransaction:Insert["update ${TableName} SET LockStatus='Unlocked', RowLastUpdate=${Time.Timestamp} WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]
					
				GetOtherTableInfo:NextRow
			}
			while !${GetOtherTableInfo.LastRow}
		}
		GetOtherTableInfo:Finalize
		; Lets get those updates through.
		if ${PendingTransaction.Used} > 0
		{
			TargetingDatabase:ExecDMLTransaction[PendingTransaction]
			PendingTransaction:Clear
		}
		; Now lets verify our Locked status targets and update as needed.
		GetOtherTableInfo:Set[${TargetingDatabase.ExecQuery["SELECT * FROM ${TableName} WHERE LockStatus='Locked';"]}]
		if ${GetOtherTableInfo.NumRows} > 0
		{
			do
			{
				; If it is now unlocked, see if it should be relocked, priority, etc.
				if !${Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}].IsLockedTarget}
				{
					GetMoreTableInfo:Set[${TargetingDatabase.ExecQuery["SELECT * FROM ${TableName} WHERE LockStatus='Unlocked' AND Priority>${GetOtherTableInfo.GetFieldValue["Priority"]};"]}]
					if ${GetMoreTableInfo.NumRows} > 0
					{
						; We have bigger fish to fry, apparently.
						PendingTransaction:Insert["update ${TableName} SET LockStatus='Unlocked', RowLastUpdate=${Time.Timestamp} WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]
					}
					else
					{
						; I want to always have a threshold of one extra lock, hence the greater than 1. If our max number of targets minus our current locks is greater than 1, then relock the target.
						if ${Math.Calc[${MaxTarget}-${This.TotalCurrentLocks}]} > 1 && ( !${MissionTargetManager.PresentInTable[MissionTarget,${GetOtherTableInfo.GetFieldValue["EntityID"]}]} || (${MissionTargetManager.PresentInTable[MissionTarget,${GetOtherTableInfo.GetFieldValue["EntityID"]}]} && ${This.TableOwnedLocks[WeaponTargets]} == ${This.TableOwnedLocks[MissionTarget]}))
						{
							PendingTransaction:Insert["update ${TableName} SET LockStatus='Locking', RowLastUpdate=${Time.Timestamp} WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]
							;LockQueue:Queue[{GetOtherTableInfo.GetFieldValue["EntityID"]}]
							Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}]:LockTarget
						}
						else
						{
							; Not sure how we end up at this contingency here but
							PendingTransaction:Insert["update ${TableName} SET LockStatus='Unlocked', RowLastUpdate=${Time.Timestamp} WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]
						}
					}
					GetMoreTableInfo:Finalize
				}
				; If it is still locked, see if it SHOULD still be locked. This will involve looking at Priorities, and probably other complicated things. Heck.
				;;; ADDENDUM - Need two versions for this, one for lasers one for not.
				if ${Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}].IsLockedTarget} && (${TableName.Equal[MissionTarget]} || ${TableName.Equal[WeaponTargets]}) && !${Ship.ModuleList_Weapon.Type.Find["Laser"]}
				{
					GetMoreTableInfo:Set[${TargetingDatabase.ExecQuery["SELECT * FROM ${TableName} WHERE LockStatus='Unlocked' AND PreferredAmmo='${Ship.ModuleList_Weapon.ChargeType}' AND Priority>${GetOtherTableInfo.GetFieldValue["Priority", int]};"]}]
					if ${GetMoreTableInfo.NumRows} > 0
					{
						; We have bigger fish to fry, apparently. But do we need to actually free up a lock for this?
						if ${Math.Calc[(${This.TableReservedLocks[${TableName}]}-${This.TableOwnedLocks[${TableName}]})+${RecentlyUnlocked}]} < 1
						{
							; If we have less than 1 available lock right now, drop this target.
							PendingTransaction:Insert["update ${TableName} SET LockStatus='Unlocked', RowLastUpdate=${Time.Timestamp} WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]
							Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}]:UnlockTarget
							RecentlyUnlocked:Inc[1]
						}
					}
					else
					{
						GetMoreTableInfo:Finalize
						GetMoreTableInfo:Set[${TargetingDatabase.ExecQuery["SELECT * FROM ${TableName} WHERE LockStatus='Unlocked' AND Priority>${GetOtherTableInfo.GetFieldValue["Priority", int]};"]}]
						if ${GetMoreTableInfo.NumRows} > 0
						{
							; We have bigger fish to fry, apparently. But do we need to actually free up a lock for this?
							if ${Math.Calc[(${This.TableReservedLocks[${TableName}]}-${This.TableOwnedLocks[${TableName}]})+${RecentlyUnlocked}]} < 1
							{
								; If we have less than 1 available lock right now, drop this target.
								PendingTransaction:Insert["update ${TableName} SET LockStatus='Unlocked', RowLastUpdate=${Time.Timestamp} WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]
								Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}]:UnlockTarget
								RecentlyUnlocked:Inc[1]
							}
						}						
						else
						{
							; Nope no need to change course on this one. Just update its last update time and continue.
							PendingTransaction:Insert["update ${TableName} SET RowLastUpdate=${Time.Timestamp} WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]
						}
						GetMoreTableInfo:Finalize
					}
				}
				if ${Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}].IsLockedTarget} && (${TableName.Equal[MissionTarget]} || ${TableName.Equal[WeaponTargets]} || ${TableName.Equal[DroneTargets]})
				{
					GetMoreTableInfo:Set[${TargetingDatabase.ExecQuery["SELECT * FROM ${TableName} WHERE LockStatus='Unlocked' AND Priority>${GetOtherTableInfo.GetFieldValue["Priority", int]};"]}]
					if ${GetMoreTableInfo.NumRows} > 0
					{
						; We have bigger fish to fry, apparently. But do we need to actually free up a lock for this?
						if ${Math.Calc[(${This.TableReservedLocks[${TableName}]}-${This.TableOwnedLocks[${TableName}]})+${RecentlyUnlocked}]} < 1
						{
							; If we have less than 1 available lock right now, drop this target.
							PendingTransaction:Insert["update ${TableName} SET LockStatus='Unlocked', RowLastUpdate=${Time.Timestamp} WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]
							Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}]:UnlockTarget
							RecentlyUnlocked:Inc[1]
						}
					}
					; If we have a locked target, and that target is the mission target, and there are things other than the mission target, please unlock this fucking mission target.
					if ${Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}].IsLockedTarget} && ${MissionTargetManager.PresentInTable[MissionTarget,${GetOtherTableInfo.GetFieldValue["EntityID"]}]} && ${This.TableOwnedLocks[WeaponTargets]} > ${This.TableOwnedLocks[MissionTarget]}
					{
						PendingTransaction:Insert["update ${TableName} SET LockStatus='Unlocked', RowLastUpdate=${Time.Timestamp} WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]
						Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}]:UnlockTarget
						RecentlyUnlocked:Inc[1]				
					}
					else
					{
						; Nope no need to change course on this one. Just update its last update time and continue.
						PendingTransaction:Insert["update ${TableName} SET RowLastUpdate=${Time.Timestamp} WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]
					}
					GetMoreTableInfo:Finalize					
				}
				GetOtherTableInfo:NextRow
			}
			while !${GetOtherTableInfo.LastRow}
		}
		GetOtherTableInfo:Finalize
		; Lets get those updates through.
		if ${PendingTransaction.Used} > 0
		{
			TargetingDatabase:ExecDMLTransaction[PendingTransaction]
			PendingTransaction:Clear
		}
		; And now we get to the good stuff, Unlocked Targets.
		;;; Addendum, still the same but now we need 2, one for laser ships and everything that isnt a WeaponTargets table, and then one for WeaponTargets table without lasers.
		if (${TableName.Equal[MissionTarget]} || ${TableName.Equal[WeaponTargets]}) && !${Ship.ModuleList_Weapon.Type.Find["Laser"]}
		{
			GetOtherTableInfo:Set[${TargetingDatabase.ExecQuery["SELECT * FROM ${TableName} WHERE LockStatus='Unlocked' AND PreferredAmmo='${Ship.ModuleList_Weapon.ChargeType}' ORDER BY Priority DESC;"]}]
			
		}
		else
			GetOtherTableInfo:Set[${TargetingDatabase.ExecQuery["SELECT * FROM ${TableName} WHERE LockStatus='Unlocked' ORDER BY Priority DESC;"]}]
		if ${GetOtherTableInfo.NumRows} > 0
		{
			do
			{
				; Zeroth up, is this row's entity out of our lock range or dead? Skip this row.
				if ${Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}].IsMoribund} || !${Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}](exists)} || (${Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}].Distance} > ${Math.Calc[${MyShip.MaxTargetRange} * .95]})
				{
					GetOtherTableInfo:NextRow
					continue
				}
				; Zeroth and a half up. If this is a MissionTarget AND we have more than 1 WeaponsTarget, we don't want to lock it
				if (${MissionTargetManager.PresentInTable[MissionTarget,${GetOtherTableInfo.GetFieldValue["EntityID"]}]} && ${This.TableOwnedLocks[WeaponTargets]} > ${This.TableOwnedLocks[MissionTarget]})
				{
					GetOtherTableInfo:NextRow
					continue				
				}
				; First up, do we NEED more locks? If we have as many locks as we reserve, or more, then...
				if (${This.TableOwnedLocks[${TableName}]} >= ${This.TableReservedLocks[${TableName}]}) || (${Math.Calc[${MaxTarget}-${This.TotalCurrentLocks}]} <= 1) || (${LockedHowMany} > ${Math.Calc[${This.TableReservedLocks[${TableName}]}+${This.TableOwnedLocks[${TableName}]}]})
				{
					; No locks for now. May as well exit the loop. In the future we may have a bypass for when we NEED A LOCK RIGHT NOW.
					break
				}
				elseif (${This.TableOwnedLocks[${TableName}]} < ${This.TableReservedLocks[${TableName}]}) && ${Math.Calc[${MaxTarget}-${This.TotalCurrentLocks}]} > 1
				{
					; Well, this should have been sorted by Priority, so uh, we'll just lock these things up in order.
					PendingTransaction:Insert["update ${TableName} SET LockStatus='Locking', RowLastUpdate=${Time.Timestamp} WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]
					Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}]:LockTarget
					LockedHowMany:Inc[1]
					TotalCurrentLocks:Inc[1]					
				}
				GetOtherTableInfo:NextRow
			}
			while !${GetOtherTableInfo.LastRow} && (${This.TableOwnedLocks[${TableName}]} < ${This.TableReservedLocks[${TableName}]}) && (${Math.Calc[${MaxTarget}-${This.TotalCurrentLocks}]} > 1) && (${LockedHowMany} <= ${Math.Calc[${This.TableReservedLocks[${TableName}]}-${This.TableOwnedLocks[${TableName}]}]})
			GetOtherTableInfo:Finalize
		}
		if (${TableName.Equal[MissionTarget]} || ${TableName.Equal[WeaponTargets]}) && !${Ship.ModuleList_Weapon.Type.Find["Laser"]} && (${LockedHowMany} <= ${This.TableReservedLocks[${TableName}]})
		{
			GetOtherTableInfo:Finalize
			GetOtherTableInfo:Set[${TargetingDatabase.ExecQuery["SELECT * FROM ${TableName} WHERE LockStatus='Unlocked' ORDER BY Priority DESC;"]}]
		}
		if ${GetOtherTableInfo.NumRows} > 0
		{
			do
			{
				; Zeroth up, is this row's entity out of our lock range or dead? Skip this row.
				if ${Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}].IsMoribund} || !${Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}](exists)} || (${Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}].Distance} > ${Math.Calc[${MyShip.MaxTargetRange} * .95]})
				{
					GetOtherTableInfo:NextRow
					continue
				}
				; Zeroth and a half up. If this is a MissionTarget AND we have more than 1 WeaponsTarget, we don't want to lock it
				if  (${MissionTargetManager.PresentInTable[MissionTarget,${GetOtherTableInfo.GetFieldValue["EntityID"]}]} && ${This.TableOwnedLocks[WeaponTargets]} > ${This.TableOwnedLocks[MissionTarget]})
				{
					GetOtherTableInfo:NextRow
					continue				
				}
				; First up, do we NEED more locks? If we have as many locks as we reserve, or more, then...
				if (${This.TableOwnedLocks[${TableName}]} >= ${This.TableReservedLocks[${TableName}]}) || (${Math.Calc[${MaxTarget}-${This.TotalCurrentLocks}]} <= 1) || (${LockedHowMany} > ${Math.Calc[${This.TableReservedLocks[${TableName}]}+${This.TableOwnedLocks[${TableName}]}]})
				{
					; No locks for now. May as well exit the loop. In the future we may have a bypass for when we NEED A LOCK RIGHT NOW.
					break
				}
				elseif (${This.TableOwnedLocks[${TableName}]} < ${This.TableReservedLocks[${TableName}]}) && ${Math.Calc[${MaxTarget}-${This.TotalCurrentLocks}]} > 1
				{
					; Well, this should have been sorted by Priority, so uh, we'll just lock these things up in order.
					PendingTransaction:Insert["update ${TableName} SET LockStatus='Locking', RowLastUpdate=${Time.Timestamp} WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]
					Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}]:LockTarget
					LockedHowMany:Inc[1]
					TotalCurrentLocks:Inc[1]					
				}
				GetOtherTableInfo:NextRow
			}
			while !${GetOtherTableInfo.LastRow} && (${This.TableOwnedLocks[${TableName}]} < ${This.TableReservedLocks[${TableName}]}) && (${Math.Calc[${MaxTarget}-${This.TotalCurrentLocks}]} > 1) && (${LockedHowMany} <= ${Math.Calc[${This.TableReservedLocks[${TableName}]}-${This.TableOwnedLocks[${TableName}]}]})
		}
		GetOtherTableInfo:Finalize
		; Lets get those updates through.
		if ${PendingTransaction.Used} > 0
		{
			TargetingDatabase:ExecDMLTransaction[PendingTransaction]
			PendingTransaction:Clear
		}
		if ${LockQueue.Peek} > 0
		{
			do
			{
				Entity[${LockQueue.Peek}]:LockTarget
				LockedHowMany:Inc[1]
				LockQueue:Dequeue
			}
			while (${LockQueue.Peek} > 0) && ${LockedHowMany} <= 2
		
		}
		return TRUE
	}
	
	; This member will return the number of locked targets that are in a given TableName.
	member:int TableOwnedLocks(string TableName)
	{
		variable int FinalValue
		
		GetMoreTableInfo:Set[${TargetingDatabase.ExecQuery["SELECT * FROM ${TableName} WHERE LockStatus='Locked' OR LockStatus='Locking';"]}]
		if ${GetMoreTableInfo.NumRows} > 0
		{
			; We have things that are supposedly locked and/or locking
			do
			{
				if ${Entity[${GetMoreTableInfo.GetFieldValue["EntityID"]}].BeingTargeted} || ${Entity[${GetMoreTableInfo.GetFieldValue["EntityID"]}].IsLockedTarget}
					FinalValue:Inc[1]
				GetMoreTableInfo:NextRow
			}
			while !${GetMoreTableInfo.LastRow}
			return ${FinalValue}
		}
		else
			return 0
	}
	member:int TotalCurrentLocks()
	{
		return ${Math.Calc[${Me.TargetCount} + ${Me.TargetingCount}]}
	}
	; Need a different way to recover our Minimum Locks
	member:int TableReservedLocks(string TableName)
	{
		variable int FinalValue = 0
		
		GetMoreTableInfo:Set[${TargetingDatabase.ExecQuery["SELECT * FROM Origin WHERE TableName='${TableName}';"]}]
		if ${GetMoreTableInfo.NumRows} > 0
			FinalValue:Inc[${GetMoreTableInfo.GetFieldValue["MinimumLocks"]}]
			
		return ${FinalValue}
		

	}	
	; This member will be so we can tell if a table has been made already or not, elsewhere.
	member:bool TableCreated(string TableName)
	{
		if ${TargetingDatabase.TableExists["${TableName}"]}
			return TRUE
		else
			return FALSE
	}
	
	; This method will be used to create a new TargetingTable within our DB.
	; TableQueryString will be the actual entities Query String we use to populate the table. Min locks are explained elsewhere.
	method InstantiateTargetingTable(string TableName, int64 TableUpdateInterval, string TableQueryString, int64 MinimumLocks)
	{
		; Creating the table. Entity ID (obviously), Distance to it (from us), LockStatus (whether it is unlocked, being locked, already locked, or should not be locked)
		; its Priority (going to use a number here, higher number means higher priority), and when the row was last updated.
		TargetingDatabase:ExecDML["create table ${TableName} (EntityID INTEGER PRIMARY KEY, Distance REAL, LockStatus TEXT, Priority INTEGER, PreferredAmmo TEXT, RowLastUpdate INTEGER);"]
		; Adding a row to Primary, to keep track of the tables we have. This doesn't need to be an upsert, there should never be a conflict. We do this exactly once per startup.
		TargetingDatabase:ExecDML["insert into Origin (TableName, TableQueryString, MinimumLocks, TableLastUpdate, TableUpdateInterval, QueryChanged) values ('${TableName}', '${TableQueryString.ReplaceSubstring[','']}', ${MinimumLocks}, 000000000, ${TableUpdateInterval}, 1);"]
		
		; Registering this table's minimum targets reserve. Basically guaranteeing the table however many slots MinimumLocks is set to.
		TargetReservationCollection:Set[${TableName},${MinimumLocks}]
	}
	
	; This method will be used to change a given field's value, for a given entity, within a given table.
	; Not sure why I made this yet. Maybe will prove useful.
	method ModifyTargetingTableFieldValue(string TableName, string FieldName, int64 EntityID, string Input)
	{
		
	
	}
	
	; This method will be used to update the QueryString for a given table, in our primary table (which will then be reflected to the given table after the next update)
	method UpdateTargetingTableQueryString(string TableName, string NewQueryString)
	{
		; Need to track if the incoming query string is actually different or not.
		variable int DidItActuallyChange
		
		GetPrimaryTableInfo:Set[${TargetingDatabase.ExecQuery["SELECT * FROM Origin WHERE TableName=${TableName};"]}]
		if ${GetPrimaryTableInfo.NumRows} > 0
		{	
			if ${NewQueryString.Escape.Equal[${GetPrimaryTableInfo.GetFieldValue["TableQueryString"].Escape}]}
				DidItActuallyChange:Set[0]
			else
				DidItActuallyChange:Set[1]
		}
		TargetingDatabase:ExecDML["update Origin SET TableQueryString='${NewQueryString.ReplaceSubstring[','']}', QueryChanged=${DidItActuallyChange} WHERE TableName='${TableName}';"]
	}
	
	; This method will be used to populate the priorities of a given table, for Mission Target Manager specifically. I'll work on the others later.
	method UpdateMissionTargetPriorities(string TableName)
	{
		GetOtherTableInfo:Set[${TargetingDatabase.ExecQuery["SELECT * FROM ${TableName};"]}]
		if ${GetOtherTableInfo.NumRows} > 0
		{
			do
			{
				GetCCInfo:Set[${CombatComputer.CombatData.ExecQuery["Select * FROM CurrentData WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]}]
				if ${GetCCInfo.NumRows} > 0
				{
					PendingTransaction:Insert["update ${TableName} SET Priority=${GetCCInfo.GetFieldValue["ThreatLevel"]}, RowLastUpdate=${Time.Timestamp} WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]
					echo PendingTransaction:Insert["update ${TableName} SET Priority=${GetCCInfo.GetFieldValue["ThreatLevel"]}, RowLastUpdate=${Time.Timestamp} WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]

				}
				GetCCInfo:Finalize
				GetOtherTableInfo:NextRow
			}
			while !${GetOtherTableInfo.LastRow}
		}
		GetOtherTableInfo:Finalize
		; Lets get those updates through.
		if ${PendingTransaction.Used} > 0
		{
			TargetingDatabase:ExecDMLTransaction[PendingTransaction]
			PendingTransaction:Clear
		}
	}
	; This method will be used to place our PreferredAmmo for a given entity into our given Table 
	method UpdateTargetAmmoPref(string TableName)
	{
		GetOtherTableInfo:Set[${TargetingDatabase.ExecQuery["SELECT * FROM ${TableName};"]}]
		if ${GetOtherTableInfo.NumRows} > 0
		{
			do
			{
				GetMTMDBInfo:Set[${MissionTargetManager.MTMDB.ExecQuery["Select * FROM Targeting WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]}]
				if ${GetMTMDBInfo.NumRows} > 0
				{
					PendingTransaction:Insert["update ${TableName} SET PreferredAmmo='${GetMTMDBInfo.GetFieldValue["OurNeededAmmo"]}', RowLastUpdate=${Time.Timestamp} WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]
					echo PendingTransaction:Insert["update ${TableName} SET PreferredAmmo='${GetMTMDBInfo.GetFieldValue["OurNeededAmmo"]}', RowLastUpdate=${Time.Timestamp} WHERE EntityID=${GetOtherTableInfo.GetFieldValue["EntityID"]};"]

				}
				GetMTMDBInfo:Finalize
				GetOtherTableInfo:NextRow
			}
			while !${GetOtherTableInfo.LastRow}
		}
		GetOtherTableInfo:Finalize
		; Lets get those updates through.
		if ${PendingTransaction.Used} > 0
		{
			TargetingDatabase:ExecDMLTransaction[PendingTransaction]
			PendingTransaction:Clear
		}		
	
	}
	
	; This method will be used to cleanup non-existent entities from the DB
	method TargetListCleanup(string TableName)
	{
		GetOtherTableInfo:Set[${TargetingDatabase.ExecQuery["SELECT * FROM ${TableName};"]}]
		if ${GetOtherTableInfo.NumRows} > 0
		{
			do
			{
				if !${Entity[${GetOtherTableInfo.GetFieldValue["EntityID"]}](exists)}
					TableDeletionQueue:Queue[${GetOtherTableInfo.GetFieldValue["EntityID"]}]
					
				GetOtherTableInfo:NextRow
			}
			while !${GetOtherTableInfo.LastRow}
		}
		GetOtherTableInfo:Finalize
		if ${TableDeletionQueue.Peek}
		{
			do
			{
				TargetingDatabase:ExecDML["DELETE From ${TableName} WHERE EntityID=${TableDeletionQueue.Peek};"]
				TableDeletionQueue:Dequeue
			}
			while ${TableDeletionQueue.Peek}
		}
	}
	
}
