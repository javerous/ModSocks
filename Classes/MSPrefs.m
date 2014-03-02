/*
 *  MSPrefs.m
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

#import "MSPrefs.h"


@implementation MSPrefs

+ (MSPrefs *)shared
{
	static dispatch_once_t	onceToken;
	static MSPrefs			*shr = nil;

	dispatch_once(&onceToken, ^{
		shr = [[MSPrefs alloc] init];
	});
	
	return shr;
}

- (id)init
{
	if (self = [super init])
	{
		_usr = [[NSUserDefaults standardUserDefaults] retain];
	}
	
	return self;
}

- (void)dealloc
{
	[_usr release];
	
	[super dealloc];
}




- (int)getIntForKey:(NSString *)key def:(int)value
{
	NSNumber *kvalue = [_usr objectForKey:key];
	
	if (!kvalue)
		return value;
	
	return [kvalue intValue];
}

- (void)setInt:(int)value forKey:(NSString *)key
{
	NSNumber *kvalue = [NSNumber numberWithInt:value];
	
	[_usr setObject:kvalue forKey:key];
}

- (BOOL)getBoolForKey:(NSString *)key def:(BOOL)value
{
	NSNumber *kvalue = [_usr objectForKey:key];
	
	if (!kvalue)
		return value;
	
	return [kvalue boolValue];
}

- (void)setBool:(BOOL)value forKey:(NSString *)key
{
	NSNumber *kvalue = [NSNumber numberWithBool:value];
	
	[_usr setObject:kvalue forKey:key];
}

- (NSString *)getStringForKey:(NSString *)key def:(NSString *)value
{
	NSString *kvalue = [_usr objectForKey:key];
	
	if (!kvalue)
		return value;
	
	return kvalue;
}

- (void)setString:(NSString *)value forKey:(NSString *)key
{	
	[_usr setObject:value forKey:key];
}

@end
