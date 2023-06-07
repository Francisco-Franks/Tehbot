Ok, so this version of Tehbot exists so that one might run Abyssals. 
Pre-Reqs - Really should be doing this in a Gila. Please, just use a Gila. Start at tier 1/2 then move up to 3/4. Runs tier 3s great.

Abyssal Runner Mode - The UI is jank as hell but self explanatory. This mainmode is what you want to be using.
MINIMODES - Along with the usual Tehbot minimodes, we have a few extras, and some changes to existing ones.

TargetManager - This minimode will basically shoot at any (NPC) target it feels like shooting at. I have removed most (if not all) targets that will probably get you in trouble. It won't shoot customs ships, or Concord, or EDENCOM (anymore). Otherwise it will just operate the weapons and shoot whatever it thinks is in range. You want this minimode on for the Abyss

RemoteRepManager - This minimode will, after some configuring in its UI, look at the type of remote reps you have available, and attempt to use them on fleet members who need them. Thresholdes are set in the UI. Has some minor code to keep it nearish to whoever is set as "The Leader". This isn't needed for abyssals, but it is something I bothered to make and it is fun. I don't make any guarantees about this minimode, it will probably behave at least a little oddly. It does, however, keep things that need reps, repped.

Drone Control - This is not a new minimode, but you do need this if you want to run Abyssals (in a Gila [USE A GILA]). I have modified this a bit so Gilas and Rattlesnakes (with their 2 drones) won't piss off the bot. Made a few other changes.

Automodule - Also not a new minimode, you absolutely need this though. If you plan on doing lots of abyssals, consider making it so your fit can handle running its rep all the time (and setting that option in this minimode).

Autothrust - No changes here, but you probably want to use a speed module (afterburner, mwd) so you should be using this. Don't forget to configure it or it won't actually do anything.

The UI for the abyssal mainmode is all kinds of weird because I'm bad at LavishUI. We have buttons for a few things. They are labeled. Some buttons don't update the UI unless you close that config window and open it again.
I've done everything in my power to ensure that the bot can handle being started at ANY GIVEN PART in an abyssal run. From in station to in the abyss and back again. An edge case remains where if you happen to start the bot between looting a wreck and going through a conduit it will sit and do nothing. I will fix that eventually, just go through the conduit yourself and it will resume.
The bot will pick up a (defensive) drug to use in the abyss if your tank starts to fall apart. Pick either Hardshell or Synth Blue Pill. It could save your life!
Configure whether it will be using your personal hangar or a corp hangar. If you don't do this the bot will just sit there, forever.
Configure your filament site, and your home base. Literally just type in the names of the two bookmarks exactly in the boxes.
Configure how much ammunition you will carry. Pro tip, carry enough for more runs than you are intending to run between returns to station. A return to station will be triggered if you drop below 40% of that initial amount.
Configure what drone you will use. No second set of drones here.
For the moment, using an MTU is a bad idea. It doesn't gain you much, and the bot will almost certainly grab the MTU and leave the cargo behind. The Nodes/Subnodes an MTU enables you to pick up are awful anyways. Please don't use this configuration until I've pieced together how to make it work correctly.
Configure your primary and secondary ammunition. One is short range, one is long. Do not use Xtra Long configuration, that is so far only configured for a Stormbringer, which I haven't gotten working perfectly yet.
The Overheat Weapons configuration also only applies to the Stormbringer for now.
A return to station will be triggered if you have any structure damage, or your first weapon slot has more than 50% or so heat damage.
A return to station will be triggered if you are missing drones. For a Gila that happens at 3 drones being missing. For smaller ships it scales down. Did I mention that you should be using a Gila.
A return to station will be triggered if you have used up all your available Filaments. The bot will go through more runs if you happen to keep picking up more of the filament you are using while it is running.
A return to station will be triggered if you have used up your drugs (unlikely).
A return to station will be triggered if you are configured to use an MTU and have lost it (don't do it, don't use an MTU yet).

Important sidenote. If you are not going to use a gila (its a really stupid idea to not use a gila) ensure that your ship can hit out to the approximate edge of the safe zone keeping in mind that some of these abyssal rats rather enjoy their EWAR.
Functionality for approaching things outside your range is not implemented except for the case of those battleships that hug the edge of the safe zone. Keep your 10km rocket fits at home.

As always, let me know in the Discord if things don't behave correctly.

_______________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________

I am now working on bringing mining to this fork. As of May 10th it is incomplete.


_______________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________

As of May 13th, most (all?) solo mining usecases are in.
The UI elements for this are numerous.

For solo mining you will want to be in the Mining Mainmode, with Group and Fleet unselected, do not select Da Boss either.
You will want to have the minimodes enabled : AutoThrust, AutoModule, LocalCheck, LavishNavTest, DroneControl (this will not handle mining drones, I hate mining drones), and MinerWorker.
You can mine at a bookmark (it will delete bookmarks when the area is depleted [probably, untested]).
You can mine at a belt like its 2007 all over again (it will add the belt to the empty belt list, does not persist between sessions).
You can mine at an anomaly (untested, for now, I'm fairly sure it works).

You can orbit rocks, you can approach rocks, you can always maintain alignment with your home structure (if you so choose).
You can ignore/fight NPCs, or run from them.
You can ignore local standings, or run based on them (ccp broke local so this is proving very annoying to test).
You can decide how long you want to hide for.

TO DO:
Fleet stuff, most of it is implemented just untested. This includes fleet compression, command bursts, fleet member management.
Implement Breaks, that is to say, taking breaks. How long and how often will be configurable.
I am FAIRLY SURE that if you are in a citadel, the station hangar inventory is called something else so I will fix that at some point.


Look forward to:
I am working on combat anomalies next after this. Using the stuff from the abyssal mode, and what I learned/implemented in the Mining mode, we should be able to slam this out in record time.
_______________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________

May 16th, Mining is pretty well done. We can mine in anoms, as a fleet, by ourselves, whatever you like.  A few UI buttons don't do anything yet. We'll get there some day.

Next up is combat anomalies. Most UI elements and some of the mode are done.
_______________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________

May 17th, my head hurts. Anyways, ISXIM is now a required part of my Tehbot fork. Why? Because IRC integration is where its at baby here in the year 2023.

Grab it at http://updates.isxgames.com/isxim/ISXIM.exe . This is integral to the next main mode I am creating which just observes and reports sightings of pilots (local, or on grid).
The Minimode "ChatRelay" is where the config for the IRC stuff is. Server/Port/Channel/Username/Password. Don't turn that on if you aren't using ISXIM something bad will probably happen.
You can also just leave ISXIM disabled, I guess. in Defines.ISS look at the last line and turn that 1 to a 0. I may be using ISXIM for this mainmode but there is nothing stopping you from using
It to report things to you via IRC if you are into that. I will return to coding the combat anomaly module before too long.

_______________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________

May 18th, 2:50 AM. What if we also wanted the observer(s) to keep track of everyone they see in some kind of persistent database? That might require something horrible like SQL.
Did you know that there is an ISXSQLite extension in existence? Not only that, it actually works? The observer will have a config option for Persistent Database Storage and Lookup
so we can have slightly more information available. Details aren't worked out fully yet but it will be amusing, assuming I have what it takes to code it. Anyways.
https://github.com/isxGames/isxSQLite/releases/tag/20200812.0001  is where the extension can be found. Just download the x64 release there and drop it in the
InnerSpace\x64\Extensions\ISXDK35 folder. Tehbot will do the rest.

_______________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________

May 19th, 12:30 PM. SQL integration will now be compulsory. I will try and make it worth it but as it stands some aspects of the Observer won't behave as expected because some information
will not be available unless you take active actions in game, or we can semi-cheat that and build up our own DB to reference against.
A new mini-mode will come into being. This minimode will get local pilots (assuming you have a local), look up a piece of information that does not get auto-populated against a table in the DB.
If the DB has that info then it will consider that pilot done and move on to the next pilot in the list. If the DB doesn't have that information then it will open the Show Info window on the pilot
(forcing the information to populate), and commit that information to the DB. Corp ID and Alliance ID are always populated as far as I can tell so we will also see if those match the table in the DB
if they do not then we get to update that info.
What other things might we be able to do with SQL? I don't know, what do you do with lots of historical information? Figure it out. We probably  could also use our DB to keep track of slightly more
mundane things like daily increases in ISK and Loyalty Points. Possibly even going as granular as looking at each individual transaction. I like watching number go up.

_______________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________

June 7th, 7:45 AM. My god what hubris this has all been. Observers work quite well, have rather gigantic DBs full of pilot sightings.
Set your main mode of the bot to Observer.
Choose what your Observer will be watching, set the name of the bookmark if applicable, and set the Orbit Distance if it is a mode that Orbits.
Activate the minimodes ISXSQLiteTest, LavishNavTest, AutoModule (make sure you have a cloak or you will go evasive)[it is set up to dart around the system if decloaked].
Also, use the chat relay option and minimode if you want to relay your sightings to IRC, and then use a bot to relay that to discord! Or, after seeing how easy Discord integration
is, wait for me to implement that as an option. It is literally like 3 lines of code, ridiculous.

Onwards. Mission mainmode is being totally reworked. I want to be able to do Combat missions, Courier Missions, Storyline Combat/Courier/Trade missions. Tired
of watching those pile up in my journal. Also tired of breaking mission chains due to one simple easy courier in the middle.

AS OF RIGHT NOW - Courier missions are operational, I need to do a lot of testing to verify that, but it seems to be workable.
Combat missions are not re-implemented yet.
Trade missions should theoretically work.

Coming up in the future: Finishing the Missioneer 2.0 rewrite. Implementing better use of the statistics the missioneers will be generating. Setting up
a new and better watchdog to help you get unstuck, using those stats we are gathering.

Sidenote: I have been pouring shitloads of time into this, but we can't stop now. Be patientish and it will pay off. Or maybe this will all be trash in the end idk.
