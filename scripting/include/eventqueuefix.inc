#if defined _eventqueuefix_included
	#endinput
#endif
#define _eventqueuefix_included

public SharedPlugin __pl_eventqueuefix = 
{
    name = "eventqueuefix",
    file = "eventqueuefix.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

enum struct event_t
{
	char target[64];
	char targetInput[64];
	char variantValue[64];
	float delay;
	int activator;
	int caller;
	int outputID;
}

enum struct eventpack_t
{
	ArrayList playerEvents;
	ArrayList outputWaits;
}

/*
 * Gets the current pending events for a client.
 *
 * @param client					Client index.
 * @param eventpack					Struct containg arrays for pending events and trigger cooldowns.
 *
 * @return 							True if successful, false otherwise.
 */
native any GetClientEvents(int client, any[] eventpack);

/*
 * Sets the current pending events for a client.
 *
 * @param client					Client index.
 * @param eventpack					Struct containg arrays for pending events and trigger cooldowns.
 *
 * @return 							True if successful, false otherwise.
 */
native any SetClientEvents(int client, any[] eventpack);

#if !defined REQUIRE_PLUGIN
public void __pl_eventqueuefix_SetNTVOptional()
{
	MarkNativeAsOptional("GetClientEvents");
	MarkNativeAsOptional("SetClientEvents");
}
#endif