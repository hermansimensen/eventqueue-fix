
//#define DEBUG
//#define CSGO_WIN

#define PLUGIN_NAME           "EventQueue fix"
#define PLUGIN_AUTHOR         "carnifex"
#define PLUGIN_DESCRIPTION    ""
#define PLUGIN_VERSION        "1.0"
#define PLUGIN_URL            ""

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <eventqueuefix>

#pragma semicolon 1

#define FLT_EPSILON 1.192092896e-07
// How many bits to use to encode an edict.
#define    MAX_EDICT_BITS                11            // # of bits needed to represent max edicts
// Max # of edicts in a level
#define    MAX_EDICTS                    (1<<MAX_EDICT_BITS)

// Used for networking ehandles.
#define NUM_ENT_ENTRY_BITS        (MAX_EDICT_BITS + 1)
#define NUM_ENT_ENTRIES            (1 << NUM_ENT_ENTRY_BITS)
#define ENT_ENTRY_MASK            (NUM_ENT_ENTRIES - 1)
#define INVALID_EHANDLE_INDEX    0xFFFFFFFF

//bhoptimer natives.
native int Shavit_GetBhopStyle(int client);
native float Shavit_GetStyleSettingFloat(int style, const char[] key);
native float Shavit_GetClientTimescale(int client);

ArrayList g_aPlayerEvents[MAXPLAYERS+1];
ArrayList g_aOutputWait[MAXPLAYERS+1];
bool g_bLateLoad;
Handle g_hFindEntityByName;
int g_iRefOffset;

bool g_bBhopTimer;
float g_fTimescale[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	LoadDHooks();
	HookEntityOutput("trigger_multiple", "OnTrigger", OnTrigger);
}

public void OnAllPluginsLoaded()
{
	if(GetFeatureStatus(FeatureType_Native, "Shavit_GetBhopStyle") != FeatureStatus_Unknown)
	{
		g_bBhopTimer = true;
	} else g_bBhopTimer = false;
	
	if(GetFeatureStatus(FeatureType_Native, "Shavit_GetClientTimescale") != FeatureStatus_Unknown)
	{
		g_bBhopTimer = true;
	} else g_bBhopTimer = false;
	
	//This is the latest added native, so we check this one last.
	if(GetFeatureStatus(FeatureType_Native, "Shavit_GetStyleSettingFloat") != FeatureStatus_Unknown)
	{
		g_bBhopTimer = true;
	} else g_bBhopTimer = false;
	
	if(g_bBhopTimer)
	{
		PrintToServer("[EventQueueFix] Found compatible timer: Bhoptimer.");
	} 
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("GetClientEvents", Native_GetClientEvents);
	CreateNative("SetClientEvents", Native_SetClientEvents);
	CreateNative("ClearClientEvents", Native_ClearClientEvents);
	CreateNative("SetEventsTimescale", Native_SetEventsTimescale);
	g_bLateLoad = late;
	
	RegPluginLibrary("eventqueuefix");
	
	return APLRes_Success;
}

public void OnMapStart()
{
	if(g_bLateLoad)
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				OnClientPutInServer(client);
			}
		}
	}
}

public void OnClientPutInServer(int client)
{
	g_fTimescale[client] = 1.0;
	
	if(g_aPlayerEvents[client] == null)
	{
		g_aPlayerEvents[client] = new ArrayList(sizeof(event_t));
	} 
	else
	{
		g_aPlayerEvents[client].Clear();
	}
	
	if(g_aOutputWait[client] == null)
	{
		g_aOutputWait[client] = new ArrayList(sizeof(entity_t));
	}
	else
	{
		g_aOutputWait[client].Clear();
	}
}

public void OnClientDisconnect(int client)
{
	if(g_aPlayerEvents[client] != null)
	{
		g_aPlayerEvents[client].Clear();
	}
	
	if(g_aOutputWait[client] != null)
	{
		g_aOutputWait[client].Clear();
		delete g_aOutputWait[client];
	}
}

void LoadDHooks()
{
	GameData gamedataConf = LoadGameConfigFile("eventfix.games");

	if(gamedataConf == null)
	{
		SetFailState("Failed to load eventfix gamedata");
	}
	
	int m_RefEHandleOff = gamedataConf.GetOffset("m_RefEHandle");
	int ibuff = gamedataConf.GetOffset("m_angRotation");
	g_iRefOffset = ibuff + m_RefEHandleOff;
	
	#if defined CSGO_WIN
		StartPrepSDKCall(SDKCall_Static);
	#else
		StartPrepSDKCall(SDKCall_EntityList);
	#endif
	
	PrepSDKCall_SetFromConf(gamedataConf, SDKConf_Signature, "FindEntityByName");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue); 
	g_hFindEntityByName = EndPrepSDKCall();
	
	Handle addEventThree = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_Ignore);
	DHookSetFromConf(addEventThree, gamedataConf, SDKConf_Signature, "AddEventThree");
	DHookAddParam(addEventThree, HookParamType_CharPtr);
	DHookAddParam(addEventThree, HookParamType_CharPtr);
	DHookAddParam(addEventThree, HookParamType_Object, 20, DHookPass_ByVal|DHookPass_ODTOR|DHookPass_OCTOR|DHookPass_OASSIGNOP);
	DHookAddParam(addEventThree, HookParamType_Float);
	DHookAddParam(addEventThree, HookParamType_Int);
	DHookAddParam(addEventThree, HookParamType_Int);
	DHookAddParam(addEventThree, HookParamType_Int);
	if(!DHookEnableDetour(addEventThree, false, DHook_AddEventThree))
		SetFailState("Couldn't enable AddEventThree detour.");

	delete gamedataConf;
}

//Credits to gammacase for this workaround.
int EntityToBCompatRef(Address player)
{
	if(player == Address_Null)
		return INVALID_EHANDLE_INDEX;
	
	int m_RefEHandle = LoadFromAddress(player + view_as<Address>(g_iRefOffset), NumberType_Int32);
	
	if(m_RefEHandle == INVALID_EHANDLE_INDEX)
		return INVALID_EHANDLE_INDEX;
	
	// https://github.com/perilouswithadollarsign/cstrike15_src/blob/29e4c1fda9698d5cebcdaf1a0de4b829fa149bf8/public/basehandle.h#L137
	int entry_idx = m_RefEHandle & ENT_ENTRY_MASK;
	
	if(entry_idx >= MAX_EDICTS)
		return m_RefEHandle | (1 << 31);
	
	return entry_idx;
}

public MRESReturn DHook_AddEventThree(Handle hParams)
{
	event_t event;
	DHookGetParamString(hParams, 1, event.target, 64);
	DHookGetParamString(hParams, 2, event.targetInput, 64);
	DHookGetParamObjectPtrString(hParams, 3, 0, ObjectValueType_String, event.variantValue, sizeof(event.variantValue));
	int ticks = RoundToCeil((view_as<float>(DHookGetParam(hParams, 4)) - FLT_EPSILON) / GetTickInterval());
	event.delay = float(ticks);
	event.activator = EntRefToEntIndex(EntityToBCompatRef(view_as<Address>(DHookGetParam(hParams, 5))));
	event.caller = EntRefToEntIndex(EntityToBCompatRef(view_as<Address>(DHookGetParam(hParams, 6))));
	event.outputID = DHookGetParam(hParams, 7);

	#if defined DEBUG
		PrintToChatAll("AddEventThree: %s, %s, %s, %f, %i, %i, %i, time: %f", event.target, event.targetInput, event.variantValue, event.delay, event.activator, event.caller, event.outputID, GetGameTime());
	#endif
	
	if((event.activator < 65 && event.activator > 0))
	{
		g_aPlayerEvents[event.activator].PushArray(event);
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

public Action OnTrigger(const char[] output, int caller, int activator, float delay)
{
	if(activator <= MAXPLAYERS && activator > 0)
	{
		float m_flWait = GetEntPropFloat(caller, Prop_Data, "m_flWait");
		
		bool bFound;
		entity_t ent;
		for(int i = 0; i < g_aOutputWait[activator].Length; i++)
		{
			g_aOutputWait[activator].GetArray(i, ent);
			
			if(caller == ent.caller)
			{
				bFound = true;
				break;
			}
		}
		
		if(!bFound)
		{
			ent.caller = caller;
			int ticks = RoundToCeil((m_flWait - FLT_EPSILON) / GetTickInterval());
			ent.waitTime = float(ticks);
			g_aOutputWait[activator].PushArray(ent);	
			return Plugin_Continue;
		}
		else
		{
			return Plugin_Handled;
		}
	} 
	return Plugin_Continue;
}

int FindEntityByName(int startEntity, char[] targetname, int searchingEnt, int activator, int caller)
{
	if(!IsValidEntity(activator) || !IsValidEntity(caller) || !IsValidEntity(searchingEnt))
		return -1; 
		
	Address targetEntityAddr = SDKCall(g_hFindEntityByName, startEntity, targetname, searchingEnt, activator, caller, 0);
	
	if(targetEntityAddr == Address_Null)
		return -1;
		
	return EntRefToEntIndex(EntityToBCompatRef(targetEntityAddr));
}

public void ServiceEvent(event_t event)
{
	int targetEntity = -1;
	
	// In the context of the event, the searching entity is also the caller
	while ((targetEntity = FindEntityByName(targetEntity, event.target, event.caller, event.activator, event.caller)) != -1)
	{
		SetVariantString(event.variantValue);
		AcceptEntityInput(targetEntity, event.targetInput, event.activator, event.caller, event.outputID);
		
		#if defined DEBUG
			PrintToChat(event.activator, "Performing output: %s, %i, %i, %s %s, %i, %f", event.target, targetEntity, event.caller, event.targetInput, event.variantValue, event.outputID, GetGameTime());
		#endif
	} 
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	float timescale = 1.0;
	
	if(g_bBhopTimer)
		timescale = Shavit_GetClientTimescale(client) != -1.0 ? Shavit_GetClientTimescale(client) : Shavit_GetStyleSettingFloat(Shavit_GetBhopStyle(client), "speed");
	else timescale = g_fTimescale[client];
	
	for(int i = 0; i < g_aOutputWait[client].Length; i++)
	{
		entity_t ent;
		g_aOutputWait[client].GetArray(i, ent);
		
		ent.waitTime -= 1.0 * timescale;
		g_aOutputWait[client].SetArray(i, ent);
		
		if(ent.waitTime <= 1.0 * timescale)
		{
			g_aOutputWait[client].Erase(i);
			i--;
		}
	}
	
	for(int i = 0; i < g_aPlayerEvents[client].Length; i++)
	{
		event_t event;
		g_aPlayerEvents[client].GetArray(i, event);
		
		event.delay -= 1.0 * timescale;
		
		g_aPlayerEvents[client].SetArray(i, event);
		if(event.delay <= -1.0 * timescale)
		{
			ServiceEvent(event);
			g_aPlayerEvents[client].Erase(i);
			i--;
		}
	}
}

public any Native_GetClientEvents(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client))
		return false;
		
	eventpack_t ep;
	ep.playerEvents = g_aPlayerEvents[client].Clone();
	ep.outputWaits = g_aOutputWait[client].Clone();
	
	SetNativeArray(2, ep, sizeof(eventpack_t));
	return true;
}

public any Native_SetClientEvents(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if(client < 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client))
		return false;
		
	eventpack_t ep;
	GetNativeArray(2, ep, sizeof(eventpack_t));
	
	delete g_aPlayerEvents[client];
	delete g_aOutputWait[client];
	
	g_aPlayerEvents[client] = ep.playerEvents.Clone();
	g_aOutputWait[client] = ep.outputWaits.Clone();
	
	return true;
}

public any Native_SetEventsTimescale(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if(client < 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client))
		return false;
	
	g_fTimescale[client] = GetNativeCell(2);
	
	return true;
}

public any Native_ClearClientEvents(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if(client < 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client))
		return false;
	
	g_aOutputWait[client].Clear();
	g_aPlayerEvents[client].Clear();
	
	return true;
}