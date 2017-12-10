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

#include <assert.h>

#import "MSServerController.h"
#import "MSNetworkTool.h"
#import "MSPreferences.h"

#import "proxy.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Prototypes
*/
#pragma mark - Prototypes

static void * _Nullable server_thread(void *ud);



/*
** SCProxyParameters
*/
#pragma mark - SCProxyParameters

@interface SCProxyParameters : NSObject

@property (nonatomic) NSString	*ipWan;
@property (nonatomic) NSString	*ipLan;
@property (nonatomic) uint16_t	port;

@property (nonatomic, weak) MSServerController	*ctrl;

@end

@implementation SCProxyParameters
@end



/*
** 3proxy
*/
#pragma mark - 3proxy

// Module main.
int MODULEMAINFUNC(int argc, char** argv);

// Functions needed.
int mainfunc(int argc, char** argv) { return -1; }

void dumpcounters(struct trafcount *tlin, int counterd) { }

// Globals needed.
struct schedule *schedule;

int wday = 0;

time_t basetime = 0;



/*
** ServerController
*/
#pragma mark - ServerController

@interface MSServerController ()
{
	BOOL _serverRunning;
	
	NSUInteger _clientsCount;
}

@property (nonatomic) IBOutlet UILabel	*titleLabel;
@property (nonatomic) IBOutlet UILabel	*ipLanLabel;
@property (nonatomic) IBOutlet UILabel	*ipWanLabel;

@property (nonatomic) IBOutlet UILabel	*status;
@property (nonatomic) IBOutlet UILabel	*childCount;

@property (nonatomic) IBOutlet UIButton	*bStartStop;

@end


@implementation MSServerController


/*
** ServerController - NSViewController
*/
#pragma mark - ServerController - NSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	// Add tap gesture to label.
	UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(labelTap)];
	
	[_titleLabel addGestureRecognizer:tapGesture];
	
	// Reload the inet table
	SCProxyParameters *parameters = [self proxyParameters];
	
	if (parameters.ipLan)
		[_ipLanLabel setText:parameters.ipLan];
	else
		[_ipLanLabel setText:@"-"];
	
	if (parameters.ipWan)
		[_ipWanLabel setText:parameters.ipWan];
	else
		[_ipWanLabel setText:@"-"];
	
	// Ignore pipe broken
	signal(SIGPIPE, SIG_IGN);
	
	// Init 3proxy mutexes
	pthread_mutex_init(&config_mutex, NULL);
	pthread_mutex_init(&bandlim_mutex, NULL);
	pthread_mutex_init(&hash_mutex, NULL);
	pthread_mutex_init(&tc_mutex, NULL);
	pthread_mutex_init(&pwl_mutex, NULL);
	pthread_mutex_init(&log_mutex, NULL);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
	// Stop the SOCKS server
	conf.paused++;
}



/*
** ServerController - IBActions
*/
#pragma mark - ServerController - IBActions

- (void)labelTap
{
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ModSocks" message:@"by Julien-Pierre Avérous\n© 2008 SourceMac" preferredStyle:UIAlertControllerStyleAlert];
	
	[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
	
	[self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)doToggleServer:(id)sender
{
	if (_serverRunning)
	{
		// Stop the server by increamenting a global value
		// 3proxy is really insane, but it work...
		conf.paused++;
	}
	else	
	{
		// Do run
		pthread_t thread;
		
		// Fech proxy parameters.
		SCProxyParameters *thrPar = [self proxyParameters];
		
		if (!thrPar)
		{
			_status.text = @"No IP Lan or IP Wan";
			return;
		}
			
		// Mark as running.
		_serverRunning = YES;
		
		// Update action button.
		NSString *txt = @"Stop";
		
		[_bStartStop setTitle:txt forState:UIControlStateNormal];
		[_bStartStop setTitle:txt forState:UIControlStateHighlighted];
		[_bStartStop setTitle:txt forState:UIControlStateDisabled];
		[_bStartStop setTitle:txt forState:UIControlStateSelected];
		
		// Clean the user & password
		if (conf.pwl)
		{
			if (conf.pwl->user)
				free(conf.pwl->user);
			if (conf.pwl->password)
				free(conf.pwl->password);
			myfree(conf.pwl);
			conf.pwl = NULL;
			
			// Deactivate user & password checking
			conf.authfunc = doconnect;
		}
		
		// If secure SOCKS, configure 3proxy (taken from config file parsing)
		if ([[MSPreferences sharedInstance] boolForKey:@"socks_secure" default:NO])
		{
			// Allocate and init a password structure
			conf.pwl = myalloc(sizeof(struct passwords));
			memset(conf.pwl, 0, sizeof(struct passwords));
			
			// Get the user & pass from preferences
			NSString *user = [[MSPreferences sharedInstance] stringForKey:@"socks_username" default:@"user"];
			NSString *password = [[MSPreferences sharedInstance] stringForKey:@"socks_password" default:@"pass"];
			
			// Set the user & pass
			conf.pwl->user = (unsigned char *)strdup([user UTF8String] ?: "");
			conf.pwl->password = (unsigned char *)strdup([password UTF8String] ?: "");
			conf.pwl->pwtype = CL;
			
			// Set the access to strong (ignore ACL)
			conf.authfunc = strongauth;
		}
		
		pthread_create(&thread, NULL, server_thread, (__bridge_retained void *)thrPar);

	}
}


/*
** ServerController - Helpers
*/
#pragma mark - ServerController - Helpers

- (void)serverSocksStopped:(NSString *)reason
{
	NSString *txt = @"Start";

	dispatch_async(dispatch_get_main_queue(), ^{
		
		[_bStartStop setTitle:txt forState:UIControlStateNormal];
		[_bStartStop setTitle:txt forState:UIControlStateHighlighted];
		[_bStartStop setTitle:txt forState:UIControlStateDisabled];
		[_bStartStop setTitle:txt forState:UIControlStateSelected];
		
		if (reason)
			_status.text = reason;
		
		_serverRunning = NO;
	});
}

- (void)serverSocksStatus:(NSString *)status
{
	dispatch_async(dispatch_get_main_queue(), ^{
	
		if (status)
			_status.text = status;
	});
}

- (void)serverClientConnected
{
	dispatch_async(dispatch_get_main_queue(), ^{

		_clientsCount++;

		_childCount.text = [NSString stringWithFormat:@"%llu", (uint64_t)_clientsCount];
	});
}

- (void)serverClientDisconnected
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		if (_clientsCount == 0)
			return;
	
		_clientsCount--;
		
		_childCount.text = [NSString stringWithFormat:@"%llu", (uint64_t)_clientsCount];
	});
}

- (SCProxyParameters *)proxyParameters
{
	NSDictionary	*lan = nil, *wan = nil;
	NSString		*ipLan = nil, *ipWan = nil;
	
	NSDictionary 		*inetTable = [MSNetworkTool inetTable];
	SCProxyParameters	*parameters = [[SCProxyParameters alloc] init];
	
	// Search the LAN ip
	lan = inetTable[@"en0"];
	ipLan = lan[@"ip"];
	
	// Search the WAN ip
	wan = inetTable[@"pdp_ip0"];
	ipWan = wan[@"ip"];
	
	// If we have not IP on pdp_ip0, check pdp_ip1
	if (!ipWan)
	{
		wan = [inetTable objectForKey:@"pdp_ip1"];
		ipWan = [wan objectForKey:@"ip"];
	}
	
	// Set IP Lan.
	if (ipLan)
		parameters.ipLan = ipLan;
	else
		return nil;
	
	// Set IP Wan.
	if (ipWan)
		parameters.ipWan = ipWan;
	else
		return nil;

	// Set port.
	parameters.port = [[MSPreferences sharedInstance] intForKey:@"socks_port" default:8888];

	// Set myself.
	parameters.ctrl = self;

	return parameters;
}

@end


/*
** ServerController - Callbacks
*/
#pragma mark - ServerController - Callbacks

static void * f_open(void *idata, struct srvparam *param)
{
	return idata;
}

static FILTER_ACTION f_client(void *fo, struct clientparam *param, void **fc)
{
	assert(fo);
	
	MSServerController *ctrl = (__bridge MSServerController *)fo;

	[ctrl serverClientConnected];
	
	*fc = fo;
	
	return CONTINUE;
}

static void f_clear(void *fo)
{
	assert(fo);

	MSServerController *ctrl = (__bridge MSServerController *)fo;

	[ctrl serverClientDisconnected];
}

static void * _Nullable server_thread(void *ud)
{
	SCProxyParameters *parm = (__bridge_transfer SCProxyParameters *)ud;
	
	// Server setup.
	childdef.pf = sockschild;
	childdef.port = parm.port;
	childdef.isudp = 0;
	childdef.service = S_SOCKS;
	
	//conf.logfunc = f_log;
	
	struct filter filter = {
		.next = NULL,
		.instance = NULL,
		.data = (__bridge_retained void *)parm.ctrl,
		
		.filter_open = f_open,
		.filter_client = f_client,
		.filter_clear = f_clear,
	};
	
	conf.filters = &filter;
	
	// Mark as running.
	[parm.ctrl serverSocksStatus:@"Server running"];
	
	// Run server loop.
	const char *argv[] = {
		"mod-socks",
		[NSString stringWithFormat:@"-i%@", parm.ipLan].UTF8String,
		[NSString stringWithFormat:@"-e%@", parm.ipWan].UTF8String,
	};
	
	proxy_main(sizeof(argv) / sizeof(argv[0]), (char **)argv);
	
	// Mark as stopped.
	[parm.ctrl serverSocksStopped:@"Server stopped"];
	
	// Release.
	MSServerController *ctrl = (__bridge_transfer MSServerController *)filter.data;
	
	(void)ctrl;
	
	return NULL;
}


NS_ASSUME_NONNULL_END

