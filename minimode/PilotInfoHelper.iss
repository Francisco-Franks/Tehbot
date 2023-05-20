;CharacterName = excluded.CharacterName, CorporationID = excluded.CorporationID, AllianceID = excluded.AllianceID, CorpName = excluded.CorpName, CorpTicker = excluded.CorpTicker, AllianceName = excluded.CorpTicker, AllianceTicker = excluded.AllianceTicker 
; Storing this here
objectdef obj_Configuration_PilotInfoHelper inherits obj_Configuration_Base
{
	method Initialize()
	{
		This[parent]:Initialize["PilotInfoHelper"]
	}

	method Set_Default_Values()
	{
		ConfigManager.ConfigRoot:AddSet[${This.SetName}]
	}

}

objectdef obj_PilotInfoHelper inherits obj_StateQueue
{
	; index where we place our strings for SQL execution
	variable index:string DML
	; Need this collection so we don't operate on the same person over and over and over (in the same session at least)
	variable collection:bool CheckedCollection
	; this int64 will help us keep the time since our last execution
	variable int64 LastExecute
	variable queue:int64 CharIDQueue
	variable sqlitequery GetCharacterInfoByID
	
	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
		This.PulseFrequency:Set[5000]
		DynamicAddMiniMode("PilotInfoHelper", "PilotInfoHelper")

		This.LogLevelBar:Set[${CommonConfig.LogLevelBar}]
	}

	method Start()
	{
		This:QueueState["PilotInfoHelper", 2000]
	}

	method Stop()
	{
		This:Clear
	}

	; Here we go, my first using of SQL ever. Maybe this will work or maybe it wont.
	; This minimode exists to look at local pilots, see if certain info is not available either already or from the DB
	; and fill in that information in the DB for future usage. 
	member:bool PilotInfoHelper()
	{
		variable index:pilot LocalPilots
		variable iterator LocalPilotsIterator
		
		if !${ISXSQLite.IsReady}
		{
			echo not sure how you got here without isxSQLite but it isn't optional
			return FALSE
		}
		if !${ISXSQLiteTest.TheSQLDatabase.ID(exists)}
		{
			echo make sure ISXSQLiteTest minimode is enabled.
			return FALSE
		}
		; Lets make sure the pre-requisite table for this minimode exists
		if !${ISXSQLiteTest.TheSQLDatabase.TableExists["PilotInfo"]}
		{
			echo DEBUG - Creating pilot info table
			ISXSQLiteTest.TheSQLDatabase:ExecDML["create table PilotInfo (CharID INTEGER PRIMARY KEY, CharacterName TEXT, CorporationID INTEGER, AllianceID INTEGER, CorpName TEXT, CorpTicker TEXT, AllianceName TEXT, AllianceTicker TEXT);"]
		}
		if (${LastExecute} < ${LavishScript.RunningTime}) && ${DML.Used}
		{
			This:ExecuteStatementIndex
		}
		if !${CharIDQueue.Peek}
		{
			EVE:GetLocalPilots[LocalPilots]
			LocalPilots:GetIterator[LocalPilotsIterator]
			if !${LocalPilots.Used} 
			{
				This:LogInfo["Problem populating local pilots index. Local is broken or doesn't exist"]
			}
			if ${LocalPilotsIterator:First(exists)}
			{
				do
				{	
					if !${CheckedCollection.Element[${LocalPilotsIterator.Value.Name}](exists)} && ${LocalPilotsIterator.Value.Name.NotNULLOrEmpty}
					{
						; Here is where we pre-empty people we have already checked IN THE PAST
						; Maybe this will behave as a query. Idk
						GetCharacterInfoByID:Set[${ISXSQLiteTest.TheSQLDatabase.ExecQuery["SELECT * FROM PilotInfo where CharID=${LocalPilotsIterator.Value.ID};"]}]
						; If we return a number of rows then that means the Character ID is in the table. Due to the setup on this table it shouldnt be possible
						; to have more than 1 row return but who knows.
						if ${GetCharacterInfoByID.NumRows} > 0
						{
							; if both the Corp ID and the Alliance ID match stored values then we don't need to check them
							if ${GetCharacterInfoByID.GetFieldValue["CorporationID",int64]} == ${LocalPilotsIterator.Value.Corp} && ${GetCharacterInfoByID.GetFieldValue["AllianceID",int64]} == ${LocalPilotsIterator.Value.AllianceID}
							{
								echo DEBUG - FOUND CharID in DB and CORPID / ALLIANCE ID Still Valid - Skipping
								CheckedCollection:Set[${LocalPilotsIterator.Value.Name}, TRUE]
								GetCharacterInfoByID:Finalize
								continue
							}
						}
						; Why did I do less than or equal to 0, either it returns something or it returns nothing. How can you have negative rows.
						if ${GetCharacterInfoByID.NumRows} <= 0 || ${GetCharacterInfoByID.NumRows} == NULL
						{
							; So we returned no rows or null rows (dunno if possible). This means that the Character ID isn't contained in the table.
							; Did I even need to bother with this code block? If this circumstance comes up then we want them to be inspected normally. 
						}
					}
					; Here is where we pre-empt people we have already checked in THIS SESSION
					if !${CheckedCollection.Element[${LocalPilotsIterator.Value.Name}](exists)} && ${LocalPilotsIterator.Value.Name.NotNULLOrEmpty}
					{
						;if !${Local[${LocalPilotsIterator.Value.Name}].Corp.Ticker.NotNULLOrEmpty} || !${Local[${LocalPilotsIterator.Value.Name}].Corp.Name.NotNULLOrEmpty}
						;{
						;	Local[${LocalPilotsIterator.Value.Name}]:OpenShowInfo
						;}
						
						;EVEWindow[ByCaption, "Character: Information"]:Close
						CharIDQueue:Queue[${LocalPilotsIterator.Value.ID}]
						CheckedCollection:Set[${LocalPilotsIterator.Value.Name}, TRUE]
					}
					; I'm supposing that Finalize is what clears out a query string so we can make a new one?
					GetCharacterInfoByID:Finalize
				}
				while ${LocalPilotsIterator:Next(exists)}
			}
		}
		if ${CharIDQueue.Peek} && !${EVEWindow[ByCaption, "Character: Information"](exists)}
		{
			Local[${CharIDQueue.Peek}]:OpenShowInfo
		}
		This:ProcessingQueue
		EVEWindow[infowindow]:Close
		
	}
	; This do while shit isn't going to fly. Lets queue up people and process them, one person per loop instead of 30 people in .8 seconds.
	method ProcessingQueue()
	{

		if !${CharIDQueue.Peek}
		{
			EVEWindow[infowindow]:Close
			return FALSE
		}
		echo DEBUG - CURRENTLY PROCESSING ${Local[${CharIDQueue.Peek}].Name}
		if !${Local[${CharIDQueue.Peek}](exists)}
		{
			echo DEBUG - Looks like they left local?
			CharIDQueue:Dequeue
		}
		 if ( ${Local[${CharIDQueue.Peek}].Name.NotNULLOrEmpty} && ${Local[${CharIDQueue.Peek}].Corp} && ${Local[${CharIDQueue.Peek}].AllianceID} && ${Local[${CharIDQueue.Peek}].Corp.Name.NotNULLOrEmpty} && ${Local[${CharIDQueue.Peek}].Corp.Ticker.NotNULLOrEmpty} && ${Local[${CharIDQueue.Peek}].Alliance.NotNULLOrEmpty} && ${Local[${CharIDQueue.Peek}].AllianceTicker.NotNULLOrEmpty} ) ||\
		( ${Local[${CharIDQueue.Peek}].Name.NotNULLOrEmpty} && ${Local[${CharIDQueue.Peek}].Corp} && ${Local[${CharIDQueue.Peek}].AllianceID} == -1 && ${Local[${CharIDQueue.Peek}].Corp.Name.NotNULLOrEmpty} && ${Local[${CharIDQueue.Peek}].Corp.Ticker.NotNULLOrEmpty} && !${Local[${CharIDQueue.Peek}].Alliance.NotNULLOrEmpty} && !${Local[${CharIDQueue.Peek}].AllianceTicker.NotNULLOrEmpty} )		
		{
			EVEWindow[ByCaption, "Character: Information"]:Close
			This:CreateUpsertStatement[${CharIDQueue.Peek}, ${Local[${CharIDQueue.Peek}].Name.ReplaceSubstring[','']}, ${Local[${CharIDQueue.Peek}].Corp}, ${Local[${CharIDQueue.Peek}].AllianceID}, ${Local[${CharIDQueue.Peek}].Corp.Name.ReplaceSubstring[','']}, ${Local[${CharIDQueue.Peek}].Corp.Ticker}, ${Local[${CharIDQueue.Peek}].Alliance.ReplaceSubstring[','']}, ${Local[${CharIDQueue.Peek}].AllianceTicker}]
			CharIDQueue:Dequeue
		}
	}
	; This is where our insert statement will be generated
	method CreateUpsertStatement(int64 CharID, string CharName, int64 CorpID, int64 AllianceID, string CorpName, string CorpTicker, string AllianceName, string AllianceTicker)
	{
		DML:Insert["insert into PilotInfo (CharID,CharacterName,CorporationID,AllianceID,CorpName,CorpTicker,AllianceName,AllianceTicker) values (${CharID}, '${CharName}', ${CorpID}, ${AllianceID}, '${CorpName}', '${CorpTicker}', '${AllianceName}','${AllianceTicker}') ON CONFLICT (CharID) DO UPDATE SET CharacterName = excluded.CharacterName, CorporationID = excluded.CorporationID, AllianceID = excluded.AllianceID, CorpName = excluded.CorpName, CorpTicker = excluded.CorpTicker, AllianceName = excluded.AllianceName, AllianceTicker = excluded.AllianceTicker;"]
	}
	; This is where our insert statement will actually be utilized.
	method ExecuteStatementIndex()
	{
		ISXSQLiteTest.TheSQLDatabase:ExecDMLTransaction[DML]
		; 10 seconds sounds good
		LastExecute:Set[${Math.Calc[${LavishScript.RunningTime} + 10000]}]
	}
}



;echo ${Local[${Me.CharID}].Name} && ${Local[${Me.CharID}].Corp} && ${Local[${Me.CharID}].AllianceID} && ${Local[${Me.CharID}].Corp.Name} && ${Local[${Me.CharID}].Corp.Ticker} && ${Local[${Me.CharID}].Alliance} && ${Local[${Me.CharID}].AllianceTicker} 