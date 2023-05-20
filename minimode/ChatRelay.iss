objectdef obj_Configuration_ChatRelay inherits obj_Configuration_Base
{
	
	method Initialize()
	{
		This[parent]:Initialize["ChatRelay"]
	}

	method Set_Default_Values()
	{
		ConfigManager.ConfigRoot:AddSet[${This.SetName}]
	}
	; Use IRC for our chat relaying.
	Setting(bool, UseIRC, SetUseIRC)
	; IRC Server
	Setting(string, IRCServer, SetIRCServer)
	; IRC Port Number
	Setting(int, IRCPort, SetIRCPort)
	; IRC Username
	Setting(string, IRCUsername, SetIRCUsername)
	; IRC Password
	Setting(string, IRCPassword, SetIRCPassword)
	; IRC Channel
	Setting(string, IRCChannel, SetIRCChannel)
	; Use Discord for our chat relaying. HELP I DON'T UNDERSTAND THIS YET
	Setting(bool, UseDiscord, SetUseDiscord)
	; Discord Settings
	; Will Go
	; Somewhere Here
}

objectdef obj_ChatRelay inherits obj_StateQueue
{
	variable obj_Configuration_ChatRelay Config
	variable bool IsConnected = FALSE
	variable queue:string Buffer
	variable bool Throttle = FALSE
	
	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
		This.PulseFrequency:Set[2000]
		DynamicAddMiniMode("ChatRelay", "ChatRelay")

		This.LogLevelBar:Set[${CommonConfig.LogLevelBar}]
		PCs:ClearQueryString
	}

	method Start()
	{
		Event[IRC_ReceivedNotice]:AttachAtom[This:IRC_ReceivedNotice]
		Event[IRC_ReceivedChannelMsg]:AttachAtom[This:IRC_ReceivedChannelMsg]
		Event[IRC_ReceivedPrivateMsg]:AttachAtom[This:IRC_ReceivedPrivateMsg]
		Event[IRC_KickedFromChannel]:AttachAtom[This:IRC_KickedFromChannel]
		Event[IRC_PRIVMSGErrorResponse]:AttachAtom[This:IRC_PRIVMSGErrorResponse]
		Event[IRC_JOINErrorResponse]:AttachAtom[This:IRC_JOINErrorResponse]
		Event[IRC_UnhandledEvent]:AttachAtom[This:IRC_UnhandledEvent]

		;Event[EVENT_ONFRAME]:AttachAtom[This:Pulse]
		This:QueueState["ChatRelay"]
	}

	method Stop()
	{
		This:Clear

		Event[IRC_ReceivedNotice]:DetachAtom[This:IRC_ReceivedNotice]
		Event[IRC_ReceivedChannelMsg]:DetachAtom[This:IRC_ReceivedChannelMsg]
		Event[IRC_ReceivedPrivateMsg]:DetachAtom[This:IRC_ReceivedPrivateMsg]
		Event[IRC_KickedFromChannel]:DetachAtom[This:IRC_KickedFromChannel]
		Event[IRC_PRIVMSGErrorResponse]:DetachAtom[This:IRC_PRIVMSGErrorResponse]
		Event[IRC_JOINErrorResponse]:DetachAtom[This:IRC_JOINErrorResponse]
		Event[IRC_UnhandledEvent]:DetachAtom[This:IRC_UnhandledEvent]
	}
	
	method Shutdown()
	{
		if ${IRCUser[${Config.IRCUsername}].IsConnected}
		{
			IRCUser[${Config.IRCUsername}]:Disconnect
		}	
	}
	
	; Let's see how much bullshit I have to go through to make this behave in Tehbot. I'm not expecting much trouble
	; but who the hell knows.
	member:bool ChatRelay()
	{
		if ${Config.UseIRC} && !${Extension[ISXIM]}
		{
			ext -require ISXIM
		}
		if !${Config.UseIRC}
		{
			return FALSE
		}
		
		if ${IRC.NumUsers} < 1
		{
			call This.Connect
		}
		if ${IRCUser[${Config.IRCUsername}].IsConnecting}
		{
			return FALSE
		}
		if (${IRCUser[${Config.IRCUsername}](exists)} && ${IRCUser[${Config.IRCUsername}].IsConnected})
		{
			if ${IRCUser[${Config.IRCUsername}].NumChannelsIn} < 1
			{
				IRCUser[${Config.IRCUsername}]:Join[${Config.IRCChannel}]
			}

		
			if ${This.Buffer.Peek(exists)}
			{
				This:SendMessage["${This.Buffer.Peek}"]
				This.Buffer:Dequeue
			}
		}	
	return FALSE
	}
	
	method IRC_ReceivedNotice(string User, string From, string To, string Message)
	{
		; This event is fired every time that an IRCUser that you have connected
		; receives a NOTICE.  You can do anything fancy you want with this, but,
		; for now, we're just going to echo it to the console window.

		; Deal with Nickserv:
		if (${From.Equal[Nickserv]})
		{
			if (${Message.Find[This nickname is registered and protected]})
			{
				; Send the password to Nickserv.  You might want to do this
				; more elegantly by saving passwords in the script via variables or XML
				if (${To.Equal[${Config.IRCUsername}]})
				{
					IRCUser[${Config.IRCUsername}]:PM[Nickserv,"identify ${Config.IRCPassword}"]
				}
				return
			}
			elseif (${Message.Find[Password accepted]})
			{
				echo "[${To.Escape}] Identify with Nickserv successful"

				; if this was an attempt to register the nick after having been
				; denied access to a channel, we want to indicate that it was
				; successful by resetting the number of attempts to zero
				if (${RegisteredChannelRetryAttempts} > 0)
				{
					RegisteredChannelRetryAttempts:Set[0]
				}
				return
			}
			elseif (${Message.Find[Password incorrect]})
			{
				echo "Incorrect password while attempting to identify ${To.Escape} with Nickserv"
				return
			}
			elseif (${Message.Find[Password authentication required]})
			{
				echo "Password authentication is required before you can issue commands to Nickserv"
				return
			}
			elseif (${Message.Find[nick, type]})
			{
				; Junk message we don't need to see
				return
			}
			elseif (${Message.Find[please choose a different]})
			{
				; Junk message we don't need to see
				return
			}
		}

		if (${Message.Find[DCC Send]})
		{
			; This is handled by the CTCP event -- I'm not sure why clients send both
			; a NOTICE and a CTCP when they're dcc'ing files
			return
		}
		  elseif (${Message.Find[DCC Chat]})
		{
			; This is handled by the CTCP event -- I'm not sure why clients send both
			; a NOTICE and a CTCP when they're dcc'ing files
			return
		}

		echo "[${User.Escape}] ${To.Escape} just received a NOTICE from ${From.Escape} :: ${Message.Escape}"
	}

	method IRC_ReceivedChannelMsg(string User, string Channel, string From, string Message)
	{
		; This event is fired every time that an IRCUser that you have connected
		; receives a Channel Message.  You can do anything fancy you want with this,
		; but, for now, we're just going to echo it to the console window.

		echo "[${User.Escape} - ${Channel.Escape}] -- (${From.Escape}) ${Message.Escape}"
	}

	method IRC_ReceivedPrivateMsg(string User, string From, string To, string Message)
	{
		; This event is fired every time that an IRCUser that you have connected
		; receives a Private Message.  You can do anything fancy you want with this,
		; but, for now, we're just going to echo it to the console window.

		; NOTE: ${User} should always be the same as ${To} in this instance.  However, it is
		; included for continuity's sake.

		echo "[Private Message -> ${To.Escape}] (${From.Escape}) ${Message.Escape}"
	}

	method IRC_KickedFromChannel(string User, string Channel, string WhoKicked, string KickedBy, string Reason)
	{
		; This event is fired every time that one of your IRCUsers are kicked from a
		; channel.  You can do anything fancy you want to do with this, but, for now, we're
		; just going to echo the information to the console window

		echo "[${User.Escape}] ${WhoKicked} has been KICKED from ${Channel.Escape}!"
		echo "Reason: "${Reason.Escape}" (by ${KickedBy.Escape})"

		; Auto rejoin! :)
		IRCUser[${WhoKicked}]:Join[${Channel.Escape}]
	}

	method IRC_PRIVMSGErrorResponse(string User, string ErrorType, string To, string Response)
	{
		; This event is fired whenever an IRCUser that you have connected receives an
		; error response while trying to send a PM.
		; NOTE: The IRC protocol considers a message sent to a channel to be a "PM" to
		; that channel.

		; Possible ${ErrorType} include: "NO_SUCH_NICKORCHANNEL", "NO_EXTERNAL_MSGS_ALLOWED"

		if (${ErrorType.Equal[NO_SUCH_NICKORCHANNEL]})
		{
			echo "[${User.Escape}] Sorry, '${To.Escape}' does not exist."
			return
		}
		elseif (${ErrorType.Equal[NO_EXTERNAL_MSGS_ALLOWED]})
		{
			echo "[${User.Escape}] Sorry, ${To.Escape} does not allow for external messages."
			echo "[${User.Escape}] You will need to join ${To.Escape} in order to send messages to the channel."
			return
		}
	}

	method IRC_JOINErrorResponse(string User, string ErrorType, string Channel, string Response)
	{
		; This event is fired whenever an IRCUser that you have connected receives an
		; error response while trying to join a channel.

		; Possible ${ErrorType} include: "BANNED", "MUST_BE_REGISTERED"

		if (${ErrorType.Equal[BANNED]})
		{
			echo "[${User.Escape}] Sorry, you have been banned from ${Channel.Escape}!"
			return
		}
		elseif (${ErrorType.Equal[REQUIRES_KEY]})
		{
			echo "[${User.Escape}] Sorry, this channel requires a password."
			return
		}
		elseif (${ErrorType.Equal[MUST_BE_REGISTERED]})
		{
			echo "[${User.Escape}] Received a message that we were not identified/registered."

			; We will try and identify with nickserv and rejoin a total of 5 times before giving up.
			; This is necessary because sometimes the script will try and join a registered channel
			; before nickserv has a chance to acknowledge identification.  Again, this method is
			; not very elegant because the passwords are hardcoded; however, it proves the point.
			if (${RegisteredChannelRetryAttempts} <= 5)
			{
				echo "[${User.Escape}] Identifying with Nickserv now."
				if (${UserName.Equal[${Config.IRCUsername}]})
				{
					IRCUser[${Config.IRCUsername}]:PM[Nickserv,"identify ${Config.IRCPassword}"]
				}
				IRCUser[${User}]:Join[${Channel}]
				RegisteredChannelRetryAttempts:Inc
				return
			}
		}
	}

	method IRC_UnhandledEvent(string User, string Command, string Param, string Rest)
	{
		; This event is here to handle any events that are not handled otherwise by the
		; the extension.  There will probably be a lot of spam here, so you won't want to
		; echo everything.  The best thing to do is only use this event when there is something
		; that is happening with the client that you want added as a feature to isxIM and need
		; the data to tell Amadeus.

		; However, we do want any ERROR messages!
		if (${Command.Equal[ERROR]})
		{
			echo "CRITICAL IRC ERROR: ${Rest.Escape}"
			if ${Rest.Find[Throttled: Reconnecting too fast]}
			{
				Throttle:Set[TRUE]
			}
		}
	}

	member:bool Connected()
	{
		if ${IRC.NumUsers} > 0
		{
			return TRUE
		}

		return FALSE
	}

	function Connect()
	{
		Logger:Log["Connecting to IRC"]

		if ${Throttle}
		{
			IRCUser[${Config.IRCUsername}]:Disconnect
		}
		Throttle:Set[FALSE]

		IRC:Connect[${Config.IRCServer},${Config.IRCUsername},${Config.IRCPort},${Config.IRCPassword}]

		;do
		;{
		;	wait 5
		;}
		;while (${IRCUser[${Config.IRCUsername}](exists)} && ${IRCUser[${Config.IRCUsername}].IsConnecting})
	}

	function Disconnect()
	{
		if ${This.IsConnected}
		{
			echo DEBUG: Disconnecting...
			;Call This.Say "Disconnecting"
			;wait 5

			IRCUser[${Config.IRCUsername}]:Disconnect
			This.IsConnected:Set[FALSE]
		}
	}

	method QueueMessage(string msg)
	{
		This.Buffer:Queue["${msg}"]
	}

	; This should not be called by users of this object.
	method SendMessage(string msg)
	{
		if ${IRCUser[${Config.IRCUsername}].IsConnected}
		{
			IRCUser[${Config.IRCUsername}].Channel[${Config.IRCChannel}]:Say["${msg}"]
		}
	}

	function Say(string msg)
	{
		This:QueueMessage["${msg}"]
		if !${IRCUser[${Config.IRCUsername}].IsConnected}
		{
			call This.Connect
		}
	}
}