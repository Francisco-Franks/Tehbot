objectdef obj_DimensionalNavigation inherits obj_StateQueue
{
	; A variable to indicate we are in the middle of an MJD procedure (the entire thing beginning to end)
	variable bool MJDInProgress
	; Going to store a timestamp for when we last used our MJD.
	variable int64 LastMJDTime
	; Bool indicates something has invoked an MJD use
	variable bool MJDInvoked
	; Bool indicates we have actually activated our MJDUsable
	variable bool MJDActivated
	; Bool indicates the jump has actually concluded.
	variable bool JumpCompleted
	
	; Going to store our pre jump coords
	variable float64 PreJumpCoordX
	variable float64 PreJumpCoordY
	variable float64 PreJumpCoordZ
	
	; Going to store our current jump's coords and our current jump's entity. If either.
	variable float64 CurrentJumpCoordX
	variable float64 CurrentJumpCoordY
	variable float64 CurrentJumpCoordZ
	variable int64 CurrentJumpEntityID
	variable bool CurrentJumpReturnTrip
	
	
	method Initialize()
	{
		This[parent]:Initialize
		PulseFrequency:Set[2000]
		;This.NonGameTiedPulse:Set[TRUE]

		This:QueueState["DimensionHub"]


	}

	method Shutdown()
	{
	
		
	}

	;;; This object will be responsible, at first, for enabling me to use the MJD correctly. Using the MJD involves a bunch of 3d math bullshit that I should put into
	;;; and object instead of just doing a one off method or something.
	;;; I would also like to do some other 3d space related crap later, maybe even some LavishNav crap. We'll settle for the MJD stuff for now.
	;;; 
	
	member:bool DimensionHub()
	{
		if !${Client.InSpace}
			return FALSE
		
		if ${MJDInvoked} && ${This.MJDUsable}
		{
			; Something has invoked an MJD usage. If it can be used and the alignment method was used, we will go to our MJD use state.
			This:InsertState["UsingMJD",5000]
			return TRUE
		}
			
	
		return FALSE
	}
	
	; This state is where we wait for our MJD alignment, active the MJD, wait for the spool up and landing, and leave when we are done.
	member:bool UsingMJD()
	{
		if !${Client.InSpace}
		{
			; I have absolutely no idea what set of circumstances could get you here but whatever.
			This:InsertState["DimensionHub",5000]
			return TRUE	
		}
		if ${This.AreWeAligned} && !${MJDActivated}
		{
			LastMJDTime:Set[${Time.Timestamp}]
			; At this point either our aligning is complete or we don't need to align to anything.
			PreJumpCoordX:Set[${MyShip.ToEntity.X}]
			PreJumpCoordY:Set[${MyShip.ToEntity.Y}]
			PreJumpCoordZ:Set[${MyShip.ToEntity.Z}]
			
			Ship.ModuleList_MJD:ActivateAll
			MJDActivated:Set[TRUE]
		}
		else
			return FALSE
			
		if ${MJDActivated} && !${JumpCompleted}
		{
			; If we are now further than 80km from our starting coords, then we have jumped.
			if ${Math.Distance[${PreJumpCoordX}, ${PreJumpCoordY}, ${PreJumpCoordZ}, ${MyShip.ToEntity.X}, ${MyShip.ToEntity.Y}, ${MyShip.ToEntity.Z}]} > 80000
			{
				JumpCompleted:Set[TRUE]
			}
			else
				return FALSE
		}
		
		if ${JumpCompleted}
		{
			; Jump is complete.
			EVE:Execute[CmdStopShip]
			MJDInProgress:Set[FALSE]
			CurrentJumpCoordX:Set[0]
			CurrentJumpCoordY:Set[0]
			CurrentJumpCoordZ:Set[0]
			CurrentJumpEntityID:Set[0]
			This:InsertState["DimensionHub",5000]
			return TRUE	
		}
		else
			return FALSE
	}
	
	; This method will be called from mainmodes/minimodes to invoke the usage of a MJD.
	; This will entail : Checking to see that we actually have an MJD. Making sure it is actually usable at this moment. Recording the position we had before activation, recording the position we have after activation (to ensure we actually moved).
	; We will have arguments, a set of 3d coordinates that we are trying to reach (or a 0,0,0 coord indicates we aren't trying to reach anything specific).
	; An entity ID will indicate we are trying to MJD towards a specific entity. A bool to indicate whether we want to go TOWARDS a thing or AWAY from it, which will be ignored for coordinate specific jumps.
	method InvokeMJD(TargetX float64, TargetY float64, TargetZ float64, EntityID int64, JumpAway bool)
	{
		MJDActivated:Set[FALSE]
		JumpCompleted:Set[FALSE]
		MJDInvoked:Set[FALSE]
		
		; If we aren't in space, return. If the MJD isn't usable, return.
		if !{$Client.InSpace} || ${MJDInProgress}
			return
		if !${This.MJDUsable}
		{
			MJDInProgress:Set[FALSE]
			return
		}
		MJDInProgress:Set[TRUE]
		; Ok what are we jumping towards? If anything?
		if (${TargetX} == 0 && ${TargetY} == 0 && ${TargetZ} == 0) && ${EntityID} == 0
		{
			; We are just jumping, it doesn't matter towards what.
			CurrentJumpCoordX:Set[0]
			CurrentJumpCoordY:Set[0]
			CurrentJumpCoordZ:Set[0]
			CurrentJumpEntityID:Set[0]
			
		}
		elseif (${TargetX} != 0 && ${TargetY} != 0 && ${TargetZ} != 0)
		{
			; We are jumping towards a specific coordinate. This won't work unless amadeus can get me a way to fly towards an arbitrary point.
			CurrentJumpCoordX:Set[${TargetX}]
			CurrentJumpCoordY:Set[${TargetY}]
			CurrentJumpCoordZ:Set[${TargetZ}]
			CurrentJumpEntityID:Set[0]			
		}
		elseif ${EntityID} != 0
		{
			; Our MJD involves a specific entity. If we are jumping away, we keep at range it with a 1,000 to 2,000 km distance which will force us away from it. This might be dangerous to do, but you only live twice.
			; If we are not jumping away, then we just 
			CurrentJumpCoordX:Set[0]
			CurrentJumpCoordY:Set[0]
			CurrentJumpCoordZ:Set[0]
			CurrentJumpEntityID:Set[${EntityID}]
			if !${JumpAway}
				Entity[${EntityID}]:AlignTo
			else
				Entity[${EntityID}]:KeepAtRange[${Math.Calc[${Math.Rand[1000000]}+1000000]
		}
		
		MJDInvoked:Set[TRUE]
	}
	
	
	; This member will return whether our MJD is currently able to be used. Are we scrammed? Do we have enough cap? Is the MJD cooling down still? Are we bastioned? 
	member:bool MJDUsable()
	{
	
	
	}
	
	; This member will be used to tell whether we are aligned towards a specific target or coordinate (maybe).
	member:bool AreWeAligned(TargetX float64, TargetY float64, TargetZ float64, EntityID int64)
	{
		if ${EntityID} != 0
		{
			
		
		}
		elseif (${TargetX} != 0 && ${TargetY} != 0 && ${TargetZ} != 0)
		{
		
		}
		else
			return TRUE
	}
	
	
}
