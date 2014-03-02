/*
 *  NetworkTool.m
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

#import "NetworkTool.h"

#include <sys/param.h>
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <sys/time.h>

#include <net/ethernet.h>
#include <net/if.h>
#include <net/if_var.h>
#include <net/if_dl.h>

#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

#include <ctype.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// Not available in iPhone OS Headers, so imported from net/route.h
#define RTAX_GATEWAY	1	/* gateway sockaddr present */
#define RTAX_NETMASK	2	/* netmask sockaddr present */
#define RTAX_IFA		5	/* interface addr sockaddr present */
#define RTAX_BRD		7	/* for NEWADDR, broadcast or p-p dest addr */
#define RTAX_MAX		8	/* size of array to allocate */
struct rt_addrinfo {
	int	rti_addrs;
	struct	sockaddr *rti_info[RTAX_MAX];
};


// C helpers
void rt_xaddrs(caddr_t cp, caddr_t cplim, struct rt_addrinfo *rtinfo);


@implementation NetworkTool

+ (NSDictionary *)inetTable
{
	// This code is inspired from ifconfig sources
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:5];
	
	int		mib[6];
	size_t	needed;
	char	*buf, *lim, *next;
	struct	if_msghdr *ifm, *nextifm;
	struct	sockaddr_dl *sdl;
	struct	ifa_msghdr *ifam;
	struct	rt_addrinfo info;
	int		flags;
	int		addrcount;
	char	name[32];
	
	// Init system network table request
	mib[0] = CTL_NET;
	mib[1] = PF_ROUTE;
	mib[2] = 0;
	mib[3] = 0;
	mib[4] = NET_RT_IFLIST;
	mib[5] = 0;
	
	// Get the network table size
	if (sysctl(mib, 6, NULL, &needed, NULL, 0) < 0)
		return result;
	
	// Alloc space for the table
	if ((buf = malloc(needed)) == NULL)
		return result;
	
	// Retrieve the table
	if (sysctl(mib, 6, buf, &needed, NULL, 0) < 0)
	{
		free(buf);
		return result;
	}
	
	// Compute the pointer to the end of the buffer
	lim = buf + needed;
	
	// Go throught items on table
	next = buf;
	while (next < lim)
	{
		ifm = (struct if_msghdr *)next;
		
		if (ifm->ifm_type == 0xe /*RTM_IFINFO*/)
		{
			sdl = (struct sockaddr_dl *)(ifm + 1);
			flags = ifm->ifm_flags;
		}
		else
		{
			free(buf);
			return result;
		}
		
		// Go to the next item
		next += ifm->ifm_msglen;
		
		// Init some vars
		ifam = NULL;
		addrcount = 0;
		
		while (next < lim)
		{
			nextifm = (struct if_msghdr *)next;
			
			if (nextifm->ifm_type != 0xc /*RTM_NEWADDR*/)
				break;
			
			if (ifam == NULL)
				ifam = (struct ifa_msghdr *)nextifm;
			
			addrcount++;
			next += nextifm->ifm_msglen;
		}
		
		// Get the name of the network port (en0, en1, etc.)
		strncpy(name, sdl->sdl_data, sdl->sdl_nlen);
		name[sdl->sdl_nlen] = '\0';
		
		NSMutableDictionary *port = [NSMutableDictionary dictionaryWithCapacity:3];
		
		// Parse addresses
		while (addrcount > 0)
		{
			info.rti_addrs = ifam->ifam_addrs;
		
			// Expand the compacted addresses
			rt_xaddrs((char *)(ifam + 1), ifam->ifam_msglen + (char *)ifam, &info);
			
			// We retrieve only inet addresses
			if(info.rti_info[RTAX_IFA]->sa_family == AF_INET)
			{
				struct sockaddr_in *sin;
				
				// IP
				sin = (struct sockaddr_in *)info.rti_info[RTAX_IFA];
				if (sin)
					[port setObject:[NSString stringWithCString:inet_ntoa(sin->sin_addr) encoding:NSASCIIStringEncoding] forKey:@"ip"];
				
				// NetMask
				sin = (struct sockaddr_in *)info.rti_info[RTAX_NETMASK];
				if (sin)
					[port setObject:[NSString stringWithCString:inet_ntoa(sin->sin_addr) encoding:NSASCIIStringEncoding] forKey:@"mask"];
				
				// Broadcast
				if (flags & IFF_BROADCAST)
				{
					sin = (struct sockaddr_in *)info.rti_info[RTAX_BRD];
					if (sin && sin->sin_addr.s_addr != 0)
						[port setObject:[NSString stringWithCString:inet_ntoa(sin->sin_addr) encoding:NSASCIIStringEncoding] forKey:@"broadcast"];
				}
			}
			
			addrcount--;
			ifam = (struct ifa_msghdr *)((char *)ifam + ifam->ifam_msglen);
		}
		
		// Add the port an its property on the dictionary
		[result setObject:port forKey:[NSString stringWithCString:name encoding:NSASCIIStringEncoding]];
	}
	
	free(buf);
	return result;
}

@end

/*
 * Expand the compacted form of addresses as returned via the
 * configuration read via sysctl().
 */
void rt_xaddrs(caddr_t cp, caddr_t cplim, struct rt_addrinfo *rtinfo)
{
	#define ROUNDUP(a) \
	((a) > 0 ? (1 + (((a) - 1) | (sizeof(long) - 1))) : sizeof(long))
	#define ADVANCE(x, n) (x += ROUNDUP((n)->sa_len))
	
	struct	sockaddr *sa;
	int		i;
	
	memset(rtinfo->rti_info, 0, sizeof(rtinfo->rti_info));
	
	for (i = 0; (i < RTAX_MAX) && (cp < cplim); i++)
	{
		if ((rtinfo->rti_addrs & (1 << i)) == 0)
			continue;
		rtinfo->rti_info[i] = sa = (struct sockaddr *)cp;
		ADVANCE(cp, sa);
	}
}
