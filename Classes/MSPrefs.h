/*
 *  MSPrefs.h
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

#import <UIKit/UIKit.h>


@interface MSPrefs : NSObject
{
	NSUserDefaults *_usr;
}

+ (MSPrefs *)shared;

- (int)getIntForKey:(NSString *)key def:(int)value;
- (void)setInt:(int)value forKey:(NSString *)key;

- (BOOL)getBoolForKey:(NSString *)key def:(BOOL)value;
- (void)setBool:(BOOL)value forKey:(NSString *)key;

- (NSString *)getStringForKey:(NSString *)key def:(NSString *)value;
- (void)setString:(NSString *)value forKey:(NSString *)key;

@end
