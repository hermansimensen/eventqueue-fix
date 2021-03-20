#if defined _eventqueuefix_included
	#endinput
#endif
#define _eventqueuefix_included

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

