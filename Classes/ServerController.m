/*
 *  ServerController.m
 *
 *  Copyright 2008 Avérous Julien-Pierre
 *
 *  This file is part of ModSocks.
 *
 *  ModSocks is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  ModSocks is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with ModSocks.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "ServerController.h"
#import "NetworkTool.h"
#import "MSPrefs.h"
#import "proxy.h"

// C prototypes
void *server_thread(void *ud);
void socks_stoped(ServerController *sc, const char *reason);
void socks_status(ServerController *sc, const char *status);
void socks_children(ServerController *sc, int childcount);

// C Struct
typedef struct _threadParameters
{
	const char			*ipWan;
	const char			*ipLan;
	unsigned			port;
	ServerController	*sc;
} threadParameters;

@interface ServerController ()
- (void)_serverSocksStoped:(NSString *)reason;
- (void)_serverSocksStatus:(NSString *)stat;
- (void)_reloadInetTable;
@end


@implementation ServerController

#pragma mark ViewController Functions

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	// Add tap gesture to label.
	UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(labelTap)];
	
	[titleLabel addGestureRecognizer:tapGesture];
	
	// Reload the inet table
	[self _reloadInetTable];
	
	// Ignore pipe broken
	signal(SIGPIPE, SIG_IGN);
	
	// Init 3proxy mutexes
	pthread_mutex_init(&acl_mutex, NULL);
	pthread_mutex_init(&tc_mutex, NULL);
	pthread_mutex_init(&bandlim_mutex, NULL);
	pthread_mutex_init(&hash_mutex, NULL);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    
	// Stop the SOCKS server
	paused++;
}

#pragma mark IB Actions

- (void)labelTap
{
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ModSocks" message:@"by Julien-Pierre Avérous\n© 2008 SourceMac" preferredStyle:UIAlertControllerStyleAlert];
	
	[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
	
	[self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)socks_start_stop:(id)sender
{
	threadParameters *cThrPar = (threadParameters *)thrPar;
	
	if (serverRunning)
	{
		// Do stop
		
		// Stop the server by increamenting a global value
		// 3proxy is really insane, but it work...
		paused++;
	}
	else	
	{
		// Do run
		pthread_t thread;
		
		// Check that we have an local IP and a wide IP
		if (cThrPar && cThrPar->ipLan && cThrPar->ipWan)
		{
			serverRunning = YES;
			
			NSString *txt = @"Stop";
			
			// The setTitle function boring me !
			[bStartStop setTitle:txt forState:UIControlStateNormal];
			[bStartStop setTitle:txt forState:UIControlStateHighlighted];
			[bStartStop setTitle:txt forState:UIControlStateDisabled];
			[bStartStop setTitle:txt forState:UIControlStateSelected];
			
			// Set the listen port
			cThrPar->port = [[MSPrefs shared] getIntForKey:@"socks_port" def:8888];

			// Set an access to myself
			cThrPar->sc = self;
			
			// Clean the user & password
			if (conf.pwl)
			{
				if (conf.pwl->user)
					free(conf.pwl->user);
				if (conf.pwl->password)
					free(conf.pwl->password);
				myfree(conf.pwl);
				conf.pwl = NULL;
				
				// Seactivate user & password checking
				conf.authfunc = doconnect;
			}
			
			// If secure SOCKS, configure 3proxy (taken from config file parsing)
			if ([[MSPrefs shared] getBoolForKey:@"socks_secure" def:NO])
			{
				// Allocate and init a password structure
				conf.pwl = myalloc(sizeof(struct passwords));
				memset(conf.pwl, 0, sizeof(struct passwords));
				
				// Get the user & pass from preferences
				NSString *user = [[MSPrefs shared] getStringForKey:@"socks_username" def:@"user"];
				NSString *password = [[MSPrefs shared] getStringForKey:@"socks_password" def:@"pass"];
				
				// Set the user & pass
				conf.pwl->user = (unsigned char *)strdup([user UTF8String] ?: "");
				conf.pwl->password = (unsigned char *)strdup([password UTF8String] ?: "");
				conf.pwl->pwtype = CL;
			
				// Set the access to strong (ignore ACL)
				conf.authfunc = strongauth;
			}

			pthread_create(&thread, NULL, server_thread, cThrPar);
		}
		else
			status.text = @"No IP Lan or IP Wan";
	}
}


#pragma mark Server Functions

// Main thread function : the server was stoped, update status and show why
- (void)_serverSocksStoped:(NSString *)reason
{
	serverRunning = NO;
	
	NSString *txt = @"Start";
	[bStartStop setTitle:txt forState:UIControlStateNormal];
	[bStartStop setTitle:txt forState:UIControlStateHighlighted];
	[bStartStop setTitle:txt forState:UIControlStateDisabled];
	[bStartStop setTitle:txt forState:UIControlStateSelected];
	
	if (reason)
		status.text = reason;
}

// Main thread function : the status change, update the interface
- (void)_serverSocksStatus:(NSString *)stat
{
	if (stat)
		status.text = stat;
}

// Main thread function : the number of opened socket change, update the interface
- (void)_serverChildChange:(NSNumber *)count
{
	childCount.text = [NSString stringWithFormat:@"%i", [count intValue]];
}

// Load the network table, choose the LAN and WAN IP, and show them
- (void)_reloadInetTable
{
	NSDictionary	*tmp;
	NSDictionary	*lan = nil, *wan = nil;
	NSString		*ipLan = nil, *ipWan = nil;
	
	// Get the inet table
	tmp = [NetworkTool inetTable];
	
	// Release / retain
	[tmp retain];
	[inetTable release];
	inetTable = tmp;
	
	// Free / alloc a new thread parameter (for the SOCKS server thread)
	if (thrPar)
		free(thrPar);
	thrPar = malloc(sizeof(threadParameters));
	
	// Search the LAN ip
	lan = [inetTable objectForKey:@"en0"];
	ipLan = [lan objectForKey:@"ip"];
	
	// Search the WAN ip
	wan = [inetTable objectForKey:@"pdp_ip0"];
	ipWan = [wan objectForKey:@"ip"];
	
	// If we have not IP on pdp_ip0, check pdp_ip1
	if (!ipWan)
	{
		wan = [inetTable objectForKey:@"pdp_ip1"];
		ipWan = [wan objectForKey:@"ip"];
	}
	
	// Show the ip LAN to the user
	if (ipLan)
	{
		[ipLanLabel setText:ipLan];
		
		if (thrPar)
			((threadParameters *)thrPar)->ipLan = [ipLan UTF8String];
	}
	else
	{
		[ipLanLabel setText:@"-"];
		
		if (thrPar)
			((threadParameters *)thrPar)->ipLan = NULL;
	}
	
	
	// Show the ip WAN to the user
	if (ipWan)
	{
		[ipWanLabel setText:ipWan];
		
		if (thrPar)
			((threadParameters *)thrPar)->ipWan = [ipWan UTF8String];
	}
	else
	{
		[ipWanLabel setText:@"-"];
		
		if (thrPar)
			((threadParameters *)thrPar)->ipWan = NULL;
	}
}


- (void)dealloc {
	[titleLabel release];
	[super dealloc];
}
@end

#pragma mark Main Socks thread

// The thread of the SOCKS server. A big part is taken from the proxymain.c file of 3proxy
void *server_thread(void *ud)
{
	struct extparam		myconf;
	struct clientparam	defparam;
	struct pollfd		fds;
	struct linger		lg;
	struct clientparam	*newparam;
	int					childcount = 0;
	int					new_sock = INVALID_SOCKET;
	int					maxchild;
	SOCKET				sock = INVALID_SOCKET;
	int					opt = 1;
	SASIZETYPE			size;
	int					nlog = 5000;
	int					error = 0;
	unsigned			sleeptime;
	pthread_t			thread;
	pthread_mutex_t		counter_mutex;
	threadParameters	*parm = (threadParameters *)ud;
	
	
	// Reset my configuration (config file), and my parameters (client parameters)
	memcpy(&myconf, &conf, sizeof(myconf));
	memset(&defparam, 0, sizeof(struct clientparam));
	
	// Init client parameters
	defparam.version = paused;
	defparam.childcount = &childcount;
	defparam.logfunc = myconf.logfunc;
	defparam.authfunc = myconf.authfunc;
	defparam.aclnum = myconf.aclnum;
	defparam.service = S_SOCKS;
	defparam.usentlm = 1;
	defparam.stdlog = NULL;
	defparam.time_start = time(NULL);
	defparam.logformat = myconf.logformat;
	
	maxchild = myconf.maxchild;
	
	// A little bit useless for me, because I have just one service : SOCKS
	if(!conf.services)
		conf.services = &defparam;
	else
	{
		defparam.next = conf.services;
		conf.services = conf.services->prev = &defparam;
	}
	
	// Init mutex
	pthread_mutex_init(defparam.counter_mutex = &counter_mutex, NULL);
	
	// Init thread
	pthread_attr_init(&pa);
	pthread_attr_setstacksize(&pa, PTHREAD_STACK_MIN + 16384);
	pthread_attr_setdetachstate(&pa, PTHREAD_CREATE_DETACHED);
	
	// Set the IP to 3proxy
	myconf.intip = getip((unsigned char *)(parm->ipLan));
	myconf.extip = getip((unsigned char *)(parm->ipWan));
	
	// Set the port to 3proxy
	myconf.intport = parm->port;
	
	// Continue to initialise client parameters
	defparam.sinc.sin_addr.s_addr = defparam.intip = myconf.intip;
	defparam.sinc.sin_port = defparam.intport = htons(myconf.intport);
	defparam.sins.sin_addr.s_addr = defparam.extip = myconf.extip;
	defparam.sins.sin_port = defparam.extport = htons(myconf.extport);
	defparam.remsock = defparam.clisock = defparam.ctrlsock = INVALID_SOCKET;
	defparam.sins.sin_family = defparam.sinc.sin_family = AF_INET;
	defparam.singlepacket = myconf.singlepacket;
	defparam.bufsize = myconf.bufsize;
	defparam.countfunc = (void (*)(void *, int))socks_children;
	defparam.countsc = parm->sc;
	
	// I don't knwo what it is
	lg.l_onoff = 1;
	lg.l_linger = conf.timeouts[STRING_L];
	
	// Build a socket for client listening
	if((sock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)) == INVALID_SOCKET)
	{
		perror("socket()");
		socks_stoped(parm->sc, "Error : can't build socket");
		
		return NULL;
	}
	fcntl(sock, F_SETFL, O_NONBLOCK);
	
	// Force the socket to re-use the port (the port is not always released when we close a socket)
	defparam.srvsock = sock;
	if(setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, (unsigned char *)&opt, sizeof(int)))
	{
		perror("setsockopt()");
		socks_stoped(parm->sc, "Warn : can't set socket options");
	}
	
	// Try to bind the socket with the parameters (interface, port, etc.)
	size = sizeof(defparam.sinc);
	for(sleeptime = SLEEPTIME * 100; bind(sock, (struct sockaddr*)&defparam.sinc, size) == -1; usleep(sleeptime))
	{
		sleeptime = (sleeptime << 1);	
		if(!sleeptime)
		{
			perror("bind()");
			closesocket(sock);
			socks_stoped(parm->sc, "Error : can't bind socket");
			return NULL;
		}
	}
	
	// Configure the socket as a listening socket
	if(listen (sock, 1 + (maxchild>>4)) == -1)
	{
		perror("listen()");
		socks_stoped(parm->sc, "Error : can't listen");
		return NULL;
	}
	
	defparam.sinc.sin_addr.s_addr = defparam.sins.sin_addr.s_addr = 0;
	defparam.sinc.sin_port = defparam.sins.sin_port = 0;
	
	fds.fd = sock;
	fds.events = POLLIN;
	
	socks_status(parm->sc, "Server listening");
	
	// Server loop
	for (;;)
	{
		for(;;)
		{
			// Wait for children release if there is too much children
			while((paused == defparam.version && childcount >= myconf.maxchild))
			{
				nlog++;
				
				if(nlog > 5000)
				{
					socks_status(parm->sc, "Too much childs");
					nlog = 0;
				}
				usleep(SLEEPTIME);
			}
			
			// If exit asked, then stop
			if (paused != defparam.version)
				break;
			
			// Check that there is something (a new client ?) in poll
			if (fds.events & POLLIN)
				error = poll(&fds, 1, 1000);
			else
			{
				usleep(SLEEPTIME);
				continue;
			}
			
			// If item available in poll, accept a client
			if (error >= 1)
				break;
			
			// If no items in poll, wait
			if (error == 0)
				continue;
			
			perror("pool()");
			socks_status(parm->sc, "Warn : pool error");
			if(errno != EAGAIN)
				break;
			continue;
		}
		
		// If exit asked, then stop
		if(paused != defparam.version)
			break;

		// Accept a client (get the socket of the client)
		size = sizeof(defparam.sinc);
		new_sock = accept(sock, (struct sockaddr*)&defparam.sinc, &size);
		if (new_sock == INVALID_SOCKET)
		{
			perror("accept()");
			socks_status(parm->sc, "Warn : can't accept child");
			
			continue;
		}
		fcntl(new_sock, F_SETFL, O_NONBLOCK);

		setsockopt(new_sock, SOL_SOCKET, SO_LINGER, (unsigned char *)&lg, sizeof(lg));
		setsockopt(new_sock, SOL_SOCKET, SO_OOBINLINE, (unsigned char *)&opt, sizeof(int));
		
		// Alloc a socks children parameters structure
		if(!(newparam = myalloc(sizeof(defparam))))
		{
			closesocket(new_sock);
			defparam.res = 21;
			perror("alloc()");
			socks_status(parm->sc, "Warn : alloc error");
			usleep(SLEEPTIME);
			continue;
		}
		
		// Copy the initialized client parameter structure, and configure it for this client
		memcpy(newparam, &defparam, sizeof(defparam));
		clearstat(newparam);
		newparam->clisock = new_sock;
		newparam->child = newparam->prev = newparam->next = NULL;
		newparam->parent = &defparam;
		
		// Add the children in the linked list of children
		pthread_mutex_lock(&counter_mutex);
		if(!defparam.child)
			defparam.child = newparam;
		else
		{
			newparam->next = defparam.child;
			defparam.child = defparam.child->prev = newparam;
		}
		
		// Build a new thread for this new children, and start the SOCKS protocol
		if((error = pthread_create(&thread, &pa, &sockschild, (void *)newparam)))
		{
			perror("pthread_create()");
			socks_status(parm->sc, "Warn : can't create child thread");
			freeparam(newparam);
		}
		else 
		{
			childcount++;
			newparam->threadid = (unsigned)thread;
			socks_children(parm->sc, childcount);
		}
		
		pthread_mutex_unlock(&counter_mutex);
		memset(&defparam.sinc, 0, sizeof(defparam.sinc));
		
		while(!fds.events)
			usleep(SLEEPTIME);
	}
	
	// Close the server socket
	if(defparam.srvsock != INVALID_SOCKET)
		closesocket(defparam.srvsock);
	
	// Close the clients socket
	pthread_mutex_lock(defparam.counter_mutex);
	struct clientparam *child = defparam.child;
	while (child)
	{
		if(child->clisock != INVALID_SOCKET)
		{
			shutdown(child->clisock, SHUT_RDWR);
			closesocket(child->clisock);
		}
		child = child->next;
	}
	pthread_mutex_unlock(defparam.counter_mutex);
	
	// We don't serve something anymore
	defparam.service = S_ZOMBIE;
	
	// Wait for child end
	while(defparam.child)
		usleep(SLEEPTIME * 100);
	
	defparam.threadid = 0;
	
	// Free
	if(defparam.target)
		myfree(defparam.target);
	if(defparam.logtarget)
		myfree(defparam.logtarget);
	if(defparam.logformat)
		myfree(defparam.logformat);
	if(defparam.nonprintable)
	   myfree(defparam.nonprintable);
	
	if(defparam.next)
		defparam.next->prev = defparam.prev;
	if(defparam.prev)
		defparam.prev->next = defparam.next;
	else
		conf.services = defparam.next;
	
	socks_stoped(parm->sc, "Server stoped");
	return NULL;
}

#pragma mark Facility Call method
void socks_stoped(ServerController *sc, const char *reason)
{
	if (!sc)
		return;
	
	NSString *str = [[NSString alloc] initWithCString:reason encoding:NSUTF8StringEncoding];
	
	// str is retained until the function exit
	[sc performSelectorOnMainThread:@selector(_serverSocksStoped:) withObject:str waitUntilDone:NO];
	
	[str release];
}


void socks_status(ServerController *sc, const char *status)
{
	if (!sc)
		return;
	
	NSString *str = [[NSString alloc] initWithCString:status encoding:NSUTF8StringEncoding];
	
	[sc performSelectorOnMainThread:@selector(_serverSocksStatus:) withObject:str waitUntilDone:NO];
	
	[str release];
}

void socks_children(ServerController *sc, int childcount)
{
	if (!sc)
		return;
	
	NSNumber *number = [[NSNumber alloc] initWithInt:childcount];
	
	[sc performSelectorOnMainThread:@selector(_serverChildChange:) withObject:number waitUntilDone:NO];
	
	[number release];
}
