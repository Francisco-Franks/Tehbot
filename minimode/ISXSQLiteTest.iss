objectdef obj_Configuration_ISXSQLiteTest inherits obj_Configuration_Base
{
	
	method Initialize()
	{
		This[parent]:Initialize["ISXSQLiteTest"]
	}

	method Set_Default_Values()
	{
		ConfigManager.ConfigRoot:AddSet[${This.SetName}]
		This.ConfigRef:AddSetting[SQLDBName, "TestDB"]
	}
	; Use ISXSQLite extension.
	Setting(bool, UseISXSQLite, SetUseISXSQLite)
	; SQL DB Name
	Setting(string, SQLDBName, SetSQLDBName)

}

objectdef obj_ISXSQLiteTest inherits obj_StateQueue
{

	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
		This.PulseFrequency:Set[2000]
		DynamicAddMiniMode("ISXSQLiteTest", "ISXSQLiteTest")

		Event[isxSQLite_onErrorMsg]:AttachAtom[isxSQLite_onErrorMsg]
		Event[isxSQLite_onStatusMsg]:AttachAtom[isxSQLite_onStatusMsg]	
		Event[isxGames_onHTTPResponse]:AttachAtom[isxGames_onHTTPResponse]

		This.LogLevelBar:Set[${CommonConfig.LogLevelBar}]
	}

	method Start()
	{
		Event[isxSQLite_onErrorMsg]:AttachAtom[isxSQLite_onErrorMsg]
		Event[isxSQLite_onStatusMsg]:AttachAtom[isxSQLite_onStatusMsg]	
		Event[isxGames_onHTTPResponse]:AttachAtom[isxGames_onHTTPResponse]

		This:QueueState["ISXSQLiteTest"]
	}

	method Stop()
	{
		Event[isxSQLite_onErrorMsg]:DetachAtom[isxSQLite_onErrorMsg]
		Event[isxSQLite_onStatusMsg]:DetachAtom[isxSQLite_onStatusMsg]	
		Event[isxGames_onHTTPResponse]:DetachAtom[isxGames_onHTTPResponse]		
		
		
		TheSQLDatabase:Close
		This:Clear
	}
	
	method Shutdown()
	{
		; Close our DB when we are done dontchaknow.
		TheSQLDatabase:Close
	
	}

	variable obj_Configuration_ISXSQLiteTest Config
	variable sqlitedb TheSQLDatabase
	variable bool WalAssurance = FALSE

	; Elusif notes, I have no idea if this is how this specific thing works. Just welding atoms in here like this. Whatever.
	; Update - You can't do this this way, it works fine for Amadeus canned demonstration script.
	; Lets see if just converting these to methods works.
	method isxSQLite_onErrorMsg(int ErrorNum, string ErrorMsg)
	{
		;;;;
		;;(NOTE:  Not all errors have a unique ErrorNum.  In these cases, it will be -1.   However, ALL errors will have a unique "ErrorMsg".)
		;;;;
		
		if (${ErrorNum} > 0)
			echo "[sqlite] <ERROR> (${ErrorNum}) ${ErrorMsg}"
		else
			echo "[sqlite] <ERROR> ${ErrorMsg}"
	}

	method isxSQLite_onStatusMsg(string StatusMsg)
	{
		;;;;
		;; Any 'spew' from isxSQLite which is not an error, will be echoed through this event (i.e., results from SQLiteDB:Close)
		;;;;
		  
		;; 'Status' updates that go through this event are typically only needed for debugging purposes.  So feel free to comment out this echo to reduce
		;; unecessary spam
		echo "[sqlite] <STATUS> ${StatusMsg}"
	}

	; I won't lie to you, I (elusif) have no idea why this is here, or in the original demonstration script. Maybe amadeus really wants to advertise
	; its existence.
	method isxGames_onHTTPResponse(int Size, string URL, string IPAddress, int ResponseCode, float TransferTime, string ResponseText, string ParsedBody)
	{
		;; ~ This event only fires for responses that occur due to the "GetURL" command being utilized
		;; ~ "Size" is in bytes
		;; ~ "URL" should match the URL issued with the "GetURL" command (unless modified by the server)
		;; ~ "ResponseText" is the entire response text unparsed (ie, including all html/xml tags)
		;; ~ "ParsedBody" will return the plain text of the <body> section of an html document.  However, at this time it only works for simple documents
		;; with only plain text between the <body></body> tags.  I will be improving upon this in the future.
	}	
	
	; Main loop for the minimode, Not sure if this will even really do anything. I just want the functions easily accessible
	; and I am too cool to make a core obj for this.
	; Update - Yeah this should work fine. Main loop will just See if you are configged to use ISXSQLite, run the extension if so, make sure it is loaded, then load up the DB.
	member:bool ISXSQLiteTest()
	{
		if !${Config.UseISXSQLite} || !${ISXSQLite.IsReady}
		{
			return FALSE
		}
		if ${Config.SQLDBName.NotNULLOrEmpty} && !${TheSQLDatabase.ID(exists)}
		{
			TheSQLDatabase:Set[${SQLite.OpenDB["${Config.SQLDBName}","${Config.SQLDBName}.sqlite3"]}]
				
			if (${TheSQLDatabase.ID(exists)})
				echo "[sqlite] Database '${TheSQLDatabase.ID}' opened."
			else
			{
				echo "[sqlite] <ERROR> Failure to open database...ending script."
				This:Stop
			}
			if !${WalAssurance}
			{
				This:EnsureWAL
			}
		}
	return FALSE
	}
	
	method EnsureWAL()
	{
		; This will be used to Set WAL. WAL is persistent but I don't know how to read our current journal state sooo.
		TheSQLDatabase:ExecDML["PRAGMA journal_mode=WAL;"]
		WalAssurance:Set[TRUE]
	}
	;function AddRecordsViaTransaction(string DatabaseID)
	;{
	;	variable sqlitedb DB = ${DatabaseID}
	;	if (!${DB.ID(exists)})
	;	{
	;		echo "[sqlite] <ERROR>  'AddRecordsViaTransaction' called with an invalid Database ID (${DatabaseID})"
	;		return
	;	}
	;	
	;	;;;;;
	;	;; See http://www.sqlite.org/lang_insert.html
	;	;;;;;
	;	variable index:string DML
	;	DML:Insert["insert into Amadeus_Friends (name,level,age,notes) values ('Cybertech', 100, 123543.25, 'CyberTech works on isxeve');"]
	;;	DML:Insert["insert into Amadeus_Friends (name,level,age,notes) values ('Lax', 13, 123.65, 'Lax owns Lavishsoft');"]
	;	DML:Insert["insert into Amadeus_Friends (name,level,age,notes) values ('Doctor Who', 13, 995.1, 'The Doctor');"]
	;
	;	DML:Insert["insert into Amadeus_Inventory (name,mass,value) values ('iPad', 1.35, 0.053);"]
	;	DML:Insert["insert into Amadeus_Inventory (name,mass,value) values ('Titan(EVE)',2278125000.0,70000000000.0);"]
	;	DML:Insert["insert into Amadeus_Inventory (name,mass,value) values ('Public Opinion', 234234653245.254, 0.0);"]
	;	
	;	DB:ExecDMLTransaction[DML]
	;	
	;	;; The "ExecDMLTransaction" METHOD of the 'sqlitedb' datatype inserts the the DML statement
	;	;; "BEGIN TRANSACTION;" prior to the ones you submit, and then includes "END TRANSACTION;" 
	;	;; after all of your statements have been submitted.   In other words, you do *NOT* need to 
	;	;; include these directives when using the "ExecDMLTransaction" method.	
	;}

	;function AddRecords(string DatabaseID)
	;{
		;variable sqlitedb DB = ${DatabaseID}
		;if (!${DB.ID(exists)})
		;{
		;	echo "[sqlite] <ERROR>  'AddRecords' called with an invalid Database ID (${DatabaseID})"
		;	return
		;}
		
		;;;;;
		;; See http://www.sqlite.org/lang_insert.html
		;;;;;
		;DB:ExecDML["insert into Amadeus_Friends (name,level,age,notes) values ('Cybertech', 100, 123543.25, 'CyberTech works on isxeve');"]
		;DB:ExecDML["insert into Amadeus_Friends (name,level,age,notes) values ('Lax', 13, 123.65, 'Lax owns Lavishsoft');"]
		;DB:ExecDML["insert into Amadeus_Friends (name,level,age,notes) values ('Doctor Who', 13, 995.1, 'The Doctor');"]
		
		;DB:ExecDML["insert into Amadeus_Inventory (name,mass,value) values ('iPad', 1.35, 0.0);"]
		;DB:ExecDML["insert into Amadeus_Inventory (name,mass,value) values ('Titan (EVE)',2278125000.0,70000000000.0);"]
		;DB:ExecDML["insert into Amadeus_Inventory (name,mass,value) values ('Public Opinion', 234234653245.254, 0.0);"]
	;}

	; Alright so this is where I, Elusif, will attempt to make a function so the Observers can slot their observations directly into a single DB
	; I wonder how IO/CPU intensive all this nonsense will be.
	function AddRecordsTransaction(string DatabaseID, string InsertStatement)
	{
		variable sqlitedb DB = ${DatabaseID}
		if (!${DB.ID(exists)})
		{
			echo "[sqlite] <ERROR>  'AddRecords' called with an invalid Database ID (${DatabaseID})"
			return
		}
		
		;;;;;
		;; See http://www.sqlite.org/lang_insert.html
		;;;;;
		variable index:string DML
		DML:Insert["${InsertStatement};"]
		DB:ExecDMLTransaction[DML]
	}

	function SpewTable(string DatabaseID, string TableName)
	{
		variable int fCount = 0
		variable int rCount = 0
		variable sqlitedb DB = ${DatabaseID}
		if (!${DB.ID(exists)})
		{
			echo "[sqlite] <ERROR>  'AddRecords' called with an invalid Database ID (${DatabaseID})"
			return
		}
		if (!${DB.TableExists[${TableName}]})
		{
			echo "[sqlite] <ERROR>  'SpewTable' called with an invalid table name (${TableName})"
			return
		}
		
		declare Table sqlitetable ${DB.GetTable[${TableName}]}
		if (!${Table.ID(exists)})
		{
			echo "[sqlite] <ERROR>  'SpewTable' encountered an odd error where a table exists...but 'GetTable' was unable to retrieve it!"
			return
		}
		
		if (${Table.NumRows} > 0)
		{
			for (rCount:Set[0] ; ${rCount} < ${Table.NumRows} ; rCount:Inc)
			{
					Table:SetRow[${rCount}]
				
					for (fCount:Set[0] ; ${fCount} < ${Table.NumFields} ; fCount:Inc)
					{
							if (${Table.FieldIsNULL[${fCount}]})
								continue
								
							;; Since all we're doing is spewing contents, we can simply retrieve and print everything as a string type.  In other words, for 
							;; this particular routine, there is no 'type' argument necessary as we do not care if whether the return value is a string, int,
							;; float, etc..
							
							echo "[sqlite] -- ${rCount}. ${Table.GetFieldName[${fCount}]}: ${Table.GetFieldValue[${fCount}]}"
					}
			}
		}
			
		
		Table:Finalize
		;;
		;; It is very important to "Finalize" the table once you're done using it.   Feel free to keep it around as long as you need it; however, to leave it "hanging"
		;; once you're done with it will create a memory leak.  Even if you decide to re-use an sqlitetable variable, you should "Finalize" it before setting it to 
		;; the results of a new sqlitedb.GetTable[].
		;;;;;;;
	}	
}