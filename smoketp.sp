#include <sourcemod>
#include <sdktools>

public Plugin:myinfo =
{
	name = "[D3S] Smoke Teleport",
	author = "Mateusz Dukat d3s",
	description = "Teleport by smoke grenades.",
	version = "1.1",
	url = ""
}

// Smoke variables
public smoke_id[100];		// Smoke stack
public int smoke_i;			// Smoke stack index
public int smokes_on_map;	// How many smokes are on map right now
public Float:smoke_f_Pos[100][3];	// Smoke stack positions
public float smoke_tp_cooldown;	// Cooldown in seconds before next teleport
public int smokes_per_round;	// How many smoke grenades can player have per round (pickup)

// Players variables
public player_id[64];	// Player stack
public int player_smokes[64];	// Player smokes in round
public int player_i;	// Player stack index
public bool player_teleportable[64];	// Is player in cooldown or not

// Settings
public bool debug_mode;
public bool pingtp_enable;
public bool tp_on_bind;		// Teleport with command bind
public bool tp_on_entry;	// Teleport when player enters smoke


// --------------------------------------- FORWARDS
public OnPluginStart()
{
	// Settings
	pingtp_enable = false;
	debug_mode = false;
	tp_on_bind = false;
	tp_on_entry = true;
	
	// Global smoke variables
	smoke_i = 0;
	smokes_on_map = 0;
	smoke_tp_cooldown = 5.0;
	smokes_per_round = 3;
	
	for(int i = 0; i<100; i++){
		smoke_id[i] = 0;
		smoke_f_Pos[i][0] = 0.0;
		smoke_f_Pos[i][1] = 0.0;
		smoke_f_Pos[i][2] = 0.0;
	}
	
	// Global player variables
	player_i = 0;
	for(int i = 0; i<64; i++){
		player_id[i] = 0;
		player_teleportable[i] = true;
		player_smokes[i] = 0;
	}
	
	HookEvent("smokegrenade_detonate", addsmoketp);	// Create teleport in smoke
	HookEvent("smokegrenade_expired", rmsmoketp);	// Remove teleport in smoke
	HookEvent("round_start", clearsmoketp);	// Remove all teleports
	HookEvent("grenade_thrown", smokegiver);	// Give next smoke for player (multiple smokes)
	HookEvent("player_spawned", addplayer);	// Add player to stack
	HookEvent("round_start", setroundsmokes);	// Set how much smokes players have
	
	if(tp_on_bind){
		RegConsoleCmd("tpme", smoketp); // bind `tpme` to any button, to teleport in smoke
	}
	
	if(pingtp_enable){
		HookEvent("player_ping", pingtp);
	}
	
}

public OnGameFrame(){
	if(tp_on_entry){
		// Position for players
		new Float:f_Pos[3];
		
		// For each player
		for(int i = 0; i<player_i; i++){
			GetClientAbsOrigin(player_id[i], f_Pos);
	
			for(int x = 0; x<smoke_i; x++){ // For each smoke
				if(isPlayerInSmokeI(f_Pos, x)){
					
					if(debug_mode){
						PrintToChatAll("Player %N in smoke", player_id[i]);
					}
					
					// Teleport player in smoke
					smoketpf(player_id[i], x, i);
					
				}
			}
		}
	}
}

// -------------------------------------------------- TIMER FUNCTIONS
public Action cooldownOff(Handle timer, int p_i)
{
	player_teleportable[p_i] = true;
	
	if(debug_mode){
		PrintToChatAll("Player %N cooldown off", player_id[p_i]);
	}
}

// -------------------------------------------------- TELEPORT FUNCTIONS

public pingtp(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	
	new Float:f_Pos[3];
	f_Pos[0] = GetEventFloat(event, "x");
	f_Pos[1] = GetEventFloat(event, "y");
	f_Pos[2] = GetEventFloat(event, "z")+20;
	
	TeleportEntity(client, f_Pos, NULL_VECTOR, NULL_VECTOR);
}

// This is function for tp_on_entry
public void smoketpf(int client, int smoke_il, int player_idl)
{
	new Float:f_Pos[3];
	GetClientAbsOrigin(client, f_Pos);
	
	if(debug_mode){
		PrintToChatAll("Trying to teleport at %f %f %f", f_Pos[0], f_Pos[1], f_Pos[2]);
	}
	

	int i = smoke_il;
	// Find bottom of smoke_id stack
	int nmin = 0;
	for(int x = 0; x<smoke_i; x++){
		if(smoke_id[x] != 0){
			nmin = x;
			break;
		}
	}
	
	// If there are more than 1 smokes, get random and teleport
	if(smokes_on_map > 1 && player_teleportable[player_idl]){
		int irand = GetRandomInt(nmin, smoke_i-1);

		while(irand == i){
			// Thats a really bad while loop, don't do it.
			// HOWEVER, for whatever reason, conditional switching does not work
			irand = GetRandomInt(nmin, smoke_i-1);
		}
		
		// Teleport slightly higher than smoke, unclips from ground (but not enough to step)
		float local_smoke_f_Pos[3];
		local_smoke_f_Pos = smoke_f_Pos[irand];
		local_smoke_f_Pos[2] += 20;
		
		TeleportEntity(client, local_smoke_f_Pos, NULL_VECTOR, NULL_VECTOR);
		
		// Add cooldown to player
		player_teleportable[player_idl] = false;
		CreateTimer(smoke_tp_cooldown, cooldownOff, player_idl);
		if(debug_mode){
			PrintToChatAll("Player %N cooldown start", player_id[player_idl]);
			PrintToChatAll("Teleported %N", player_id[player_idl]);
		}
	}else{
		if(debug_mode){
			PrintToChatAll("Nowhere to teleport");
		}
	}
}

// This is function for tp_on_bind
public Action smoketp(int client, int args)
{
	new Float:f_Pos[3];
	GetClientAbsOrigin(client, f_Pos);
	
	if(debug_mode){
		PrintToChatAll("Trying to teleport at %f %f %f", f_Pos[0], f_Pos[1], f_Pos[2]);
	}
	
	// Find in which smoke player is
	for(int i = 0; i<smoke_i; i++){
		if(isPlayerInSmokeI(f_Pos, i)){
			// Find bottom of smoke_id stack
			int nmin = 0;
			for(int x = 0; x<smoke_i; x++){
				if(smoke_id[x] != 0){
					nmin = x;
					break;
				}
			}
			
			// If there are more than 1 smokes, get random and teleport
			if(smokes_on_map > 1){
				int irand = GetRandomInt(nmin, smoke_i-1);

				while(irand == i){
					// Thats a really bad while loop, don't do it.
					// HOWEVER, for whatever reason, conditional switching does not work
					irand = GetRandomInt(nmin, smoke_i-1);
				}
				
				// Teleport slightly higher than smoke, unclips from ground (but not enough to step)
				float local_smoke_f_Pos[3];
				local_smoke_f_Pos = smoke_f_Pos[irand];
				local_smoke_f_Pos[2] += 20;
				
				TeleportEntity(client, local_smoke_f_Pos, NULL_VECTOR, NULL_VECTOR);
				
				// Add cooldown to player
				player_teleportable[i] = false;
				CreateTimer(smoke_tp_cooldown, cooldownOff, i);
				if(debug_mode){
					PrintToChatAll("Player %N cooldown start", player_id[i]);
					PrintToChatAll("Teleported %N", player_id[i]);
				}
			}else{
				if(debug_mode){
					PrintToChatAll("Nowhere to teleport");
				}
			}
			break;
		}
	}
}

// ---------------------------------------------------------- STACK FUNCTIONS

public addplayer(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	player_id[player_i] = GetClientOfUserId(userid);
	player_i += 1;
	
	if(debug_mode){
		PrintToChatAll("Player %d spawned %N", player_i-1, player_id[player_i-1]);
	}
}

public clearsmoketp(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(int i = 0; i<smoke_i; i++){
		smoke_id[i] = 0;
		smoke_f_Pos[i][0] = 0.0;
		smoke_f_Pos[i][1] = 0.0;
		smoke_f_Pos[i][2] = 0.0;
	}
	smoke_i = 0;
	smokes_on_map = 0;

	if(debug_mode){
		PrintToChatAll("Round clear smoke");
	}
}


public addsmoketp(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Some data
	smokes_on_map += 1;
	
	// Grab entityid
	new entityid = GetEventInt(event, "entityid");
	smoke_id[smoke_i] = entityid;
	
	// Grab entity position
	new Float:f_Pos[3];
	f_Pos[0] = GetEventFloat(event, "x");
	f_Pos[1] = GetEventFloat(event, "y");
	f_Pos[2] = GetEventFloat(event, "z");
	smoke_f_Pos[smoke_i] = f_Pos;
	smoke_i += 1;
	
	// DEBUG
	if(debug_mode){
		PrintToChatAll("Smoke boom");
		PrintToChatAll("%f %f %f", f_Pos[0], f_Pos[1], f_Pos[2]);
		PrintToChatAll("All Smokes:");
		for(int i = 0; i<smoke_i; i++)
		{
			if(smoke_id[i] != 0){
				PrintToChatAll("%f %f %f", smoke_f_Pos[i][0], smoke_f_Pos[i][1], smoke_f_Pos[i][2]);
			}
		}
	}
}

public rmsmoketp(Handle:event, const String:name[], bool:dontBroadcast)
{
	smokes_on_map -= 1;
	
	new entityid = GetEventInt(event, "entityid");
	int this_i = 0;
	for(int i = 0; i<smoke_i; i++){ // Find smoke
		if(smoke_id[i] == entityid){
			this_i = i;
			break;
		}
	}
	
	if(debug_mode){
		PrintToChatAll("Cleared smoke %f %f %f", smoke_f_Pos[this_i][0], smoke_f_Pos[this_i][1], smoke_f_Pos[this_i][2]);
	}
	
	smoke_id[this_i] = 0;
	smoke_f_Pos[this_i][0] = 0.0;
	smoke_f_Pos[this_i][1] = 0.0;
	smoke_f_Pos[this_i][2] = 0.0;
}

// --------------------------------------------------------------------- MISC FUNCTIONS

public bool isPlayerInSmokeI(float f_Pos[3], int lsmoke_i)
{
	int square_side = 233;
	if(f_Pos[0] > smoke_f_Pos[lsmoke_i][0]-(square_side/2) && f_Pos[0] < smoke_f_Pos[lsmoke_i][0]+(square_side/2)){ //	X	// This basically checks if
	if(f_Pos[1] > smoke_f_Pos[lsmoke_i][1]-(square_side/2) && f_Pos[1] < smoke_f_Pos[lsmoke_i][1]+(square_side/2)){ //	Y	// player is in a little box in smoke
	if(f_Pos[2] > smoke_f_Pos[lsmoke_i][2]-10 && f_Pos[2] < smoke_f_Pos[lsmoke_i][2]+150){ 							//	Z
		return true;
	}}}
	return false;
}

// --------------------------------------------------------------------- PER PLAYER SMOKE CALCULATION FUNCTIONS

// If player throws first smoke in round, we know he bought it, or someone dropped it.
// So we only check if player throwed a smoke.
public smokegiver(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	
	int player_il = 0;
	for(int i = 0; i<player_i; i++){	// Find player from event
		if(player_id[i] == client){
			player_il = i;
			break;
		}
	}
	
	char weapon[50];
	GetEventString(event, "weapon", weapon, 50);
	
	if(strcmp(weapon, "weapon_smokegrenade") && player_smokes[player_il] > 0){ // If thrown weapon is smoke, and player still has smokes, give next one
		GivePlayerItem(client, "weapon_smokegrenade");
		player_smokes[player_il] -= 1;
		
		if(debug_mode){
			PrintToChatAll("Given %N next smoke, %d remain", client, player_smokes[player_il]);
		}
	}
}

public setroundsmokes(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	
	for(int i = 0; i<player_i; i++){
		player_smokes[i] = smokes_per_round-1;
		
		if(debug_mode){
			PrintToChatAll("Set %N %d smokes", client, smokes_per_round-1);
		}
	}
}
